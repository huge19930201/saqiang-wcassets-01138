#import "SaoqiangWCAssetsNative.h"
#import "SaoqiangWCAssets.h"
#import <dlfcn.h>
#import <string.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>

// Two facts drive this file, both verified against ThemeBox.dylib 3.0.8:
//
// 1. The Rust C ABI (theme_box_read_file &co) is NOT exported. The export trie
//    of ThemeBox.dylib holds only ObjC class names (Renderer, Glass, LensView
//    ...), so dlsym(RTLD_DEFAULT) returns NULL no matter what. The symbols do
//    still exist in LC_SYMTAB as defined external symbols, so we resolve them
//    by walking the loaded image's symbol table and adding the image slide.
//    No hardcoded offsets, no version/UUID lock.
//
// 2. The name table was never empty -- we were reading the wrong object. On a
//    device where +[ThemeBoxUtil enabledNewEngine] is NO the 3.0.8 pack is
//    still served by ThemeBoxImageLoader, so every probe gated behind
//    `newEngine` was skipped and the export stayed at whatever the loaded
//    snapshot happened to hold. ThemeBox exposes far more: ThemeBoxIconMap.maps
//    (the theme's icon -> file table), ThemeBoxImageLoader.fileExistsWithName:
//    / dataForFileName:, ThemeBoxCache.decryptCache, plus the ThemeBoxUtil
//    class-level *FileList. This file probes all of them unconditionally and
//    records what each one actually held.
//
// 3. Two whole name tables were still untouched after that: ThemeBoxImage's
//    class-level fileMaps/bubbleMaps/diyMaps (a different class from
//    ThemeBoxImageLoader, and the one that also owns a class-level
//    fileExistsWithName:, so it can confirm names too), and the per-device
//    table in ThemeBoxImageMap (devicePrefixMap / deviceTypeMapping /
//    fallbackTypeMap). Those class methods are string-keyed dictionaries built
//    at runtime, so they are read, not guessed at -- reading them is what makes
//    the device variants reachable, because the loaded index only ever holds
//    the variant this device asked for.
//
//    ThemeBoxImageMap itself is control-flow flattened (a state-machine
//    dispatcher over obfuscated constants), so its tables are deliberately
//    *not* reverse-engineered from the binary: they are read from the live
//    class at export time and written into the discovery log verbatim. That
//    makes one export enough to see, rather than assume, what the pack names.
//
// We never parse or modify themebox.dat: the provider decrypts it, we only ask
// by name.

// The Rust out-parameter. Defined here only: the header no longer exposes it,
// so this must not be behind a SAOQIANG_WCASSETS_TESTING guard (the simulator
// test compiles this file with that flag and would lose the type).
typedef struct {
    void *bytes;
    size_t length;
} SQNativeBuffer;

typedef void (*SQNAFreeFn)(void *bytes, size_t length);
typedef int (*SQNAReadFn)(const char *name, SQNativeBuffer *out);

static SQNAReadFn SQNARead;
static SQNAFreeFn SQNAFree;
static BOOL SQNAResolved;
static dispatch_once_t SQNAOnce;

// --- symbol resolution ------------------------------------------------------
//
// Resolving `_theme_box_read_file` means reading the image's LC_SYMTAB, and
// that is exactly where a naive implementation crashes: symoff/stroff are FILE
// offsets, and `header + symoff` is only the mapped address when the segments
// were mapped at (vmaddr - fileoff) == 0. Most images satisfy that, plenty do
// not, and reading past __LINKEDIT is an unmapped page away.
//
// So: locate __LINKEDIT, compute the file range it covers, translate that range
// into mapped addresses through the segment that owns it, and refuse to touch a
// single byte outside it. Anything unexpected means "not found", never "read it
// anyway".

// Translate a FILE range to a mapped pointer. LC_SYMTAB's symoff/stroff are
// file offsets, but ``header + symoff'' is only right when every segment has
// vmaddr - fileoff == 0. In ThemeBox.dylib __LINKEDIT is at vmaddr 0x15f0000
// against fileoff 0x15ec000 -- a 0x4000 delta -- so the naive form reads the
// wrong bytes. Locate the owning segment and translate through it; return NULL
// if the range is not fully inside that segment's file extent.
static const uint8_t *SQNAMapFileRange(const struct mach_header_64 *mh, uint64_t fileoff,
                                       uint64_t size) {
    const uint8_t *p = (const uint8_t *)(mh + 1);
    uint64_t textVmaddr = 0;
    BOOL haveText = NO;
    const struct segment_command_64 *segs[64];
    uint32_t nsegs = 0;
    for (uint32_t i = 0; i < mh->ncmds && nsegs < 64; ++i) {
        const struct load_command *lc = (const struct load_command *)p;
        if (lc->cmdsize < sizeof(struct load_command)) break;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *seg = (const struct segment_command_64 *)lc;
            if (!haveText && seg->fileoff == 0 && seg->filesize > 0) {
                textVmaddr = seg->vmaddr;
                haveText = YES;
            }
            segs[nsegs++] = seg;
        }
        p += lc->cmdsize;
    }
    for (uint32_t i = 0; i < nsegs; ++i) {
        const struct segment_command_64 *seg = segs[i];
        if (seg->filesize == 0) continue;
        if (fileoff < seg->fileoff || fileoff + size > seg->fileoff + seg->filesize) continue;
        uint64_t delta = fileoff - seg->fileoff;
        uint64_t vmaddr = seg->vmaddr + delta;
        if (vmaddr < textVmaddr) return NULL;
        return (const uint8_t *)mh + (vmaddr - textVmaddr);
    }
    return NULL;
}

static void *SQNAFindSymbolInImage(const struct mach_header_64 *mh, intptr_t slide,
                                   const char *wanted) {
    const uint8_t *p = (const uint8_t *)(mh + 1);
    for (uint32_t i = 0; i < mh->ncmds; ++i) {
        const struct load_command *lc = (const struct load_command *)p;
        if (lc->cmdsize < sizeof(struct load_command)) return NULL;
        if (lc->cmd == LC_SYMTAB) {
            const struct symtab_command *sc = (const struct symtab_command *)lc;
            if (sc->nsyms == 0 || sc->nsyms > 2000000) return NULL;
            uint64_t symBytes = (uint64_t)sc->nsyms * sizeof(struct nlist_64);
            const struct nlist_64 *syms = (const struct nlist_64 *)SQNAMapFileRange(mh, sc->symoff, symBytes);
            const char *strs = (const char *)SQNAMapFileRange(mh, sc->stroff, sc->strsize);
            if (!syms || !strs) return NULL;
            for (uint32_t s = 0; s < sc->nsyms; ++s) {
                uint32_t strx = syms[s].n_un.n_strx;
                if (strx == 0 || strx >= sc->strsize) continue;
                if ((syms[s].n_type & N_STAB) != 0) continue;
                if ((syms[s].n_type & N_TYPE) != N_SECT) continue;
                // The string table is not guaranteed NUL-terminated at strsize.
                size_t maxLen = (size_t)(sc->strsize - strx);
                if (strlen(wanted) >= maxLen) continue;
                if (strncmp(strs + strx, wanted, maxLen) != 0) continue;
                return (void *)(slide + (intptr_t)syms[s].n_value);
            }
            return NULL;
        }
        p += lc->cmdsize;
    }
    return NULL;
}

static BOOL SQNAImageIsProvider(const char *name) {
    if (!name) return NO;
    // The 3.0.8 provider ships as ThemeBox.dylib under MobileSubstrate or
    // /var/jb; the companion pack reader is BubbleBox. Nothing else in the
    // process carries these symbols, so do not walk unrelated images.
    return strstr(name, "ThemeBox") != NULL || strstr(name, "BubbleBox") != NULL;
}

static void *SQNAResolveSymbol(const char *wanted) {
    // dlsym first: works if a future build does export the ABI.
    void *sym = dlsym(RTLD_DEFAULT, wanted);
    if (sym) return sym;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; ++i) {
        const struct mach_header *h = _dyld_get_image_header(i);
        if (!h || h->magic != MH_MAGIC_64) continue;
        if (!SQNAImageIsProvider(_dyld_get_image_name(i))) continue;
        void *found = SQNAFindSymbolInImage((const struct mach_header_64 *)h,
                                            _dyld_get_image_vmaddr_slide(i), wanted);
        if (found) return found;
    }
    return NULL;
}

static void SQNAResolveOnce(void) {
    SQNARead = (SQNAReadFn)SQNAResolveSymbol("_theme_box_read_file");
    SQNAFree = (SQNAFreeFn)SQNAResolveSymbol("_theme_box_free_buffer");
    if (!SQNARead) SQNARead = (SQNAReadFn)SQNAResolveSymbol("theme_box_read_file");
    if (!SQNAFree) SQNAFree = (SQNAFreeFn)SQNAResolveSymbol("theme_box_free_buffer");
    if (!SQNARead) SQNARead = (SQNAReadFn)SQNAResolveSymbol("_bubble_box_read_file");
    SQNAResolved = SQNARead && SQNAFree;
}

BOOL SaoqiangWCAssetsNativeAvailable(void) {
    dispatch_once(&SQNAOnce, ^{ SQNAResolveOnce(); });
    return SQNAResolved;
}

NSData *SaoqiangWCAssetsNativeRead(NSDictionary *index, NSString *name, NSString **error) {
    (void)index;
    if (![name isKindOfClass:NSString.class] || !name.length || name.length > 1024) {
        if (error) *error = @"资源名为空或超长";
        return nil;
    }
    if (!SaoqiangWCAssetsNativeAvailable()) {
        if (error) *error = @"主题盒子原生解密接口未解析到";
        return nil;
    }
    const char *c = name.UTF8String;
    if (!c) { if (error) *error = @"资源名无法编码"; return nil; }
    SQNativeBuffer buffer = {NULL, 0};
    int status = -1;
    @try { status = SQNARead(c, &buffer); }
    @catch (NSException *exception) {
        if (error) *error = [@"原生解密异常：" stringByAppendingString:(exception.name ?: @"未知")];
        return nil;
    }
    if (status != 0 || !buffer.bytes || buffer.length == 0) {
        if (buffer.bytes && SQNAFree) SQNAFree(buffer.bytes, buffer.length);
        if (error) *error = status != 0 ? @"原生解密返回失败" : @"原生解密返回空数据";
        return nil;
    }
    // Same ceiling the ObjC reader enforces; a bogus length field would
    // otherwise become a multi-gigabyte NSData copy.
    if (buffer.length > (size_t)(32 * 1024 * 1024)) {
        SQNAFree(buffer.bytes, buffer.length);
        if (error) *error = @"原生解密返回长度超出 32MB 上限";
        return nil;
    }
    NSData *data = [NSData dataWithBytes:buffer.bytes length:buffer.length];
    SQNAFree(buffer.bytes, buffer.length);
    return data;
}

// A pack index is a table of file names, so it is text, or a binary plist, or
// JSON. Anything with an image magic (or bytes that are not ~all printable) is a
// resource and not the table: checking the content instead of trusting the name
// is what keeps a theme's "index.png" from being mistaken for its index.
static BOOL SQNALooksLikeIndex(NSData *data) {
    if (data.length < 8) return NO;
    const unsigned char *bytes = data.bytes;
    if (!memcmp(bytes, "bplist00", 8)) return YES;
    if (bytes[0] == '{' || bytes[0] == '[') return YES;
    if (data.length >= 5 && !memcmp(bytes, "<?xml", 5)) return YES;
    NSUInteger sample = MIN(data.length, (NSUInteger)4096), printable = 0;
    for (NSUInteger i = 0; i < sample; i++) {
        unsigned char c = bytes[i];
        if (c == '\n' || c == '\r' || c == '\t' || (c >= 0x20 && c < 0x7f)) ++printable;
    }
    return sample && (printable * 100 / sample) >= 95;
}

NSDictionary *SaoqiangWCAssetsNativePackIndex(void) {
    if (!SaoqiangWCAssetsNativeAvailable()) return nil;
    // Ordered from most to least likely. The container's own table has to live
    // under some name the provider can resolve, and these are the names a pack
    // builder would pick; a miss costs one decrypt attempt, not a reinstall.
    NSArray<NSString *> *candidates = @[
        @"theme.json", @"theme.plist", @"index.json", @"index.plist",
        @"manifest.json", @"manifest.plist", @"info.json", @"info.plist",
        @"themeInfo.json", @"theme_index.json", @"filelist.plist", @"files.json",
        @"filemap.json", @"fileMap.plist", @"resources.json", @"resource.plist",
        @"data.json", @"data.plist", @"config.json", @"config.plist",
        @"themebox.json", @"themebox.plist", @"contents.json", @"assets.json",
        @"mapping.json", @"iconmap.json", @"layers.json", @"meta.json",
        @"main.plist", @"index.txt", @"filelist.txt", @"theme.txt",
    ];
    for (NSString *name in candidates) {
        const char *c = name.UTF8String;
        if (!c) continue;
        SQNativeBuffer buffer = {NULL, 0};
        int status = -1;
        @try { status = SQNARead(c, &buffer); }
        @catch (NSException *exception) { continue; }
        NSData *data = nil;
        if (status == 0 && buffer.bytes && buffer.length && buffer.length <= (size_t)(8 * 1024 * 1024))
            data = [NSData dataWithBytes:buffer.bytes length:buffer.length];
        if (buffer.bytes && SQNAFree) SQNAFree(buffer.bytes, buffer.length);
        if (!data || !SQNALooksLikeIndex(data)) continue;
        return @{ @"name": name, @"data": data };
    }
    return nil;
}


// --- ABI-checked ObjC calls ------------------------------------------------

// Call a zero-argument getter. Returns nil unless the method really is
// `- (id)name`, so probing a selector list blindly cannot misfire.
static id SQNAGet(id receiver, NSString *sel) {
    if (!receiver || ![receiver isKindOfClass:NSObject.class]) return nil;
    SEL s = NSSelectorFromString(sel);
    if (![receiver respondsToSelector:s]) return nil;
    Method m = class_getInstanceMethod(object_getClass(receiver), s);
    if (!m) return nil;
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)];
    if (!sig || sig.numberOfArguments != 2) return nil;
    const char *rt = sig.methodReturnType;
    if (!rt || (rt[0] != '@' && rt[0] != '#')) return nil;
    @try { return ((id (*)(id, SEL))method_getImplementation(m))(receiver, s); }
    @catch (NSException *e) { return nil; }
}

// Call `- (BOOL)selector:(id)arg` / `+ (BOOL)selector:(id)arg`. Only
// single-byte returns are accepted, so a pointer-returning method with a
// similar name can never be invoked here.
//
// The ABI decision for a (class, selector) pair cannot change inside a running
// process, and the device-variant pass now makes this call tens of thousands of
// times per snapshot, so it is resolved once and the IMP reused. Building an
// NSMethodSignature per call was the dominant cost of the previous version.
static IMP SQNABoolIMP(id receiver, NSString *sel) {
    Class cls = object_getClass(receiver);
    if (!cls) return NULL;
    static NSMutableDictionary *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary new]; });
    NSString *key = [NSString stringWithFormat:@"%s|%@", class_getName(cls), sel];
    NSValue *hit = cache[key];
    if (hit) return (IMP)hit.pointerValue;
    IMP imp = NULL;
    SEL s = NSSelectorFromString(sel);
    if ([receiver respondsToSelector:s]) {
        Method m = class_getInstanceMethod(cls, s);
        if (m) {
            NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)];
            if (sig && sig.numberOfArguments == 3) {
                const char *rt = sig.methodReturnType;
                if (rt && (rt[0] == 'c' || rt[0] == 'B') && [sig getArgumentTypeAtIndex:2][0] == '@') {
                    imp = method_getImplementation(m);
                }
            }
        }
    }
    cache[key] = [NSValue valueWithPointer:imp];
    return imp;
}

static BOOL SQNACallBool(id receiver, NSString *sel, id arg) {
    if (!receiver || ![receiver isKindOfClass:NSObject.class]) return NO;
    IMP imp = SQNABoolIMP(receiver, sel);
    if (!imp) return NO;
    @try { return ((BOOL (*)(id, SEL, id))imp)(receiver, NSSelectorFromString(sel), arg); }
    @catch (NSException *e) { return NO; }
}

// Declared here because the catalog reader below needs it; the body lives in the
// harvesting section with the rest of the name-shape rules.
static BOOL SQNALooksLikeResource(NSString *name);

// Cached `- (id)selector:(id)a :(id)b`.
static id SQNACallObject2(id receiver, NSString *sel, id first, id second) {
    if (!receiver || ![receiver isKindOfClass:NSObject.class]) return nil;
    Class cls = object_getClass(receiver);
    if (!cls) return nil;
    static NSMutableDictionary *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary new]; });
    NSString *key = [NSString stringWithFormat:@"obj2|%s|%@", class_getName(cls), sel];
    NSValue *hit = cache[key];
    IMP imp = hit ? (IMP)hit.pointerValue : NULL;
    if (!hit) {
        SEL s = NSSelectorFromString(sel);
        if ([receiver respondsToSelector:s]) {
            Method m = class_getInstanceMethod(cls, s);
            if (m) {
                NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)];
                if (sig && sig.numberOfArguments == 4) {
                    const char *rt = sig.methodReturnType;
                    if (rt && rt[0] == '@' && [sig getArgumentTypeAtIndex:2][0] == '@'
                        && [sig getArgumentTypeAtIndex:3][0] == '@') {
                        imp = method_getImplementation(m);
                    }
                }
            }
        }
        cache[key] = [NSValue valueWithPointer:imp];
    }
    if (!imp) return nil;
    @try { return ((id (*)(id, SEL, id, id))imp)(receiver, NSSelectorFromString(sel), first, second); }
    @catch (NSException *e) { return nil; }
}

// The pack replaces WeChat's own assets, so WeChat's asset catalog is the
// universe its keys are drawn from. Every name this export has produced
// ("icons_filled_live@3x.png", "arrow_left_regular@3x.png", "wallet_pdd.png") is
// a catalog name, not an invented one. Enumerating that catalog and asking the
// provider which entries it ships therefore reaches the full set without needing
// the pack to volunteer a name table it does not expose.
//
// CUICatalog is private API but long-stable: initWithName:fromBundle: plus
// allImageNames is how the catalog is read outside UIKit. Both calls are
// ABI-checked, and any failure is "no catalog", never a crash.
static NSArray<NSString *> *SQNACatalogNames(void) {
    Class catalogClass = NSClassFromString(@"CUICatalog");
    if (!catalogClass) return nil;
    id catalog = nil;
    @try {
        id allocated = [catalogClass alloc];
        if (!allocated) return nil;
        catalog = SQNACallObject2(allocated, @"initWithName:fromBundle:", @"Assets", NSBundle.mainBundle);
    } @catch (NSException *e) { return nil; }
    if (!catalog) return nil;
    id names = SQNAGet(catalog, @"allImageNames");
    if (![names isKindOfClass:NSArray.class] || ![names count]) return nil;
    NSMutableArray *out = [NSMutableArray new];
    for (id name in (NSArray *)names) {
        if (![name isKindOfClass:NSString.class]) continue;
        if (!SQNALooksLikeResource(name)) continue;
        [out addObject:name];
        if (out.count >= 20000) break;
    }
    return out;
}

// Cached `- (id)selector:(id)arg`. Return type must be an object and the
// argument an object, so a similarly named method with a different shape
// (svgImageNamed:size:config:) can never be called through it.
static id SQNACallObject(id receiver, NSString *sel, id arg) {
    if (!receiver || ![receiver isKindOfClass:NSObject.class]) return nil;
    Class cls = object_getClass(receiver);
    if (!cls) return nil;
    static NSMutableDictionary *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary new]; });
    NSString *key = [NSString stringWithFormat:@"obj|%s|%@", class_getName(cls), sel];
    NSValue *hit = cache[key];
    IMP imp = hit ? (IMP)hit.pointerValue : NULL;
    if (!hit) {
        SEL s = NSSelectorFromString(sel);
        if ([receiver respondsToSelector:s]) {
            Method m = class_getInstanceMethod(cls, s);
            if (m) {
                NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)];
                if (sig && sig.numberOfArguments == 3) {
                    const char *rt = sig.methodReturnType;
                    if (rt && rt[0] == '@' && [sig getArgumentTypeAtIndex:2][0] == '@') {
                        imp = method_getImplementation(m);
                    }
                }
            }
        }
        cache[key] = [NSValue valueWithPointer:imp];
    }
    if (!imp) return nil;
    @try { return ((id (*)(id, SEL, id))imp)(receiver, NSSelectorFromString(sel), arg); }
    @catch (NSException *e) { return nil; }
}

static id SQNAShared(NSString *className) {
    Class c = NSClassFromString(className);
    return c ? SQNAGet((id)c, @"shared") : nil;
}

// --- name harvesting -------------------------------------------------------

static void SQNAHarvest(id value, NSMutableSet *names, NSUInteger depth) {
    if (!value || depth > 4 || names.count > 60000) return;
    if ([value isKindOfClass:NSString.class]) {
        NSString *s = (NSString *)value;
        if (s.length && s.length <= 1024) [names addObject:s];
        return;
    }
    if ([value isKindOfClass:NSDictionary.class]) {
        for (id key in (NSDictionary *)value) {
            SQNAHarvest(key, names, depth + 1);
            SQNAHarvest(((NSDictionary *)value)[key], names, depth + 1);
        }
        return;
    }
    if ([value isKindOfClass:NSArray.class] || [value isKindOfClass:NSSet.class]) {
        for (id item in value) SQNAHarvest(item, names, depth + 1);
        return;
    }
    if ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSData.class]) return;
    if ([value isKindOfClass:NSObject.class]) {
        // Model object (an icon entry, a file record): probe likely accessors.
        static NSString * const probes[] = {
            @"name", @"fileName", @"fileNames", @"maps", @"list", @"items",
            @"allKeys", @"allValues", @"values", @"path", @"key", @"keys",
        };
        for (size_t i = 0; i < sizeof(probes) / sizeof(probes[0]); ++i) {
            if (names.count > 60000) break;
            id inner = SQNAGet(value, probes[i]);
            if (inner && inner != value) SQNAHarvest(inner, names, depth + 1);
        }
    }
}

// Probe one source and record how much it held, so a single export tells us
// which collection carries the real name table.
static void SQNAProbe(id object, NSString *sel, NSMutableSet *names,
                      NSMutableArray<NSString *> *log, NSString *label) {
    id value = SQNAGet(object, sel);
    if (!value) return;
    SQNAHarvest(value, names, 0);
    NSUInteger held = 1;
    if ([value respondsToSelector:@selector(count)]) held = [value count];
    [log addObject:[NSString stringWithFormat:@"%@.%@=%lu",
                    label, sel, (unsigned long)held]];
}

static BOOL SQNALooksLikeResource(NSString *name) {
    if (![name isKindOfClass:NSString.class] || !name.length || name.length > 512) return NO;
    if ([name rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound) return NO;
    if (name.isAbsolutePath || [name containsString:@".."] || [name containsString:@"/"]) return NO;
    return YES;
}

// One-line rendering of a runtime value for the discovery log. The point is to
// read a dictionary's real keys and values out of a live process, so this stays
// strictly bounded: a table with 4000 entries must not become a 4000-line log.
static NSString *SQNADescribe(id value, NSUInteger limit) {
    if (!value || value == NSNull.null) return @"nil";
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value isKindOfClass:NSNumber.class]) return [(NSNumber *)value stringValue];
    if ([value isKindOfClass:NSDictionary.class]) {
        NSMutableArray *parts = [NSMutableArray new];
        for (id key in (NSDictionary *)value) {
            if (parts.count >= limit) { [parts addObject:@"…"]; break; }
            [parts addObject:[NSString stringWithFormat:@"%@=%@",
                              SQNADescribe(key, 6), SQNADescribe(((NSDictionary *)value)[key], 6)]];
        }
        return [NSString stringWithFormat:@"{%@}", [parts componentsJoinedByString:@", "]];
    }
    if ([value isKindOfClass:NSArray.class] || [value isKindOfClass:NSSet.class]) {
        NSMutableArray *parts = [NSMutableArray new];
        for (id item in value) {
            if (parts.count >= limit) { [parts addObject:@"…"]; break; }
            [parts addObject:SQNADescribe(item, 4)];
        }
        return [NSString stringWithFormat:@"[%@]", [parts componentsJoinedByString:@", "]];
    }
    return [NSString stringWithFormat:@"<%@>", NSStringFromClass([value class]) ?: @"?"];
}

// Device prefixes are the *values* of ThemeBoxImageMap.devicePrefixMap: it maps
// a device-class enum to the token a pack puts in front of a file name ("x_",
// "pm_", ...). The keys of deviceTypeMapping are device names ("13ProMax"),
// which are worth logging and useless as file-name prefixes.
//
// Collecting both is what broke the first attempt: 32 device names sorted ahead
// of every real token, filled the whole prefix budget, and all 6528 variant
// probes missed. Only this map's values are harvested now.
static void SQNAPrefixValues(id value, NSMutableSet *out) {
    if (![value isKindOfClass:NSDictionary.class] || out.count > 32) return;
    NSDictionary *map = (NSDictionary *)value;
    for (id key in map) {
        id token = map[key];
        if (![token isKindOfClass:NSString.class]) continue;
        NSString *s = (NSString *)token;
        if (s.length < 1 || s.length > 8) continue;
        if ([s containsString:@"/"] || [s containsString:@"."]) continue;
        if ([s rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound) continue;
        // Either the "x_" shape the pack actually uses, or a bare short token.
        BOOL separator = [s hasSuffix:@"_"];
        BOOL bare = s.length <= 4 && [s rangeOfCharacterFromSet:
            [NSCharacterSet lowercaseLetterCharacterSet].invertedSet].location == NSNotFound;
        if (separator || bare) [out addObject:s];
    }
}

// Every reader we can ask "do you have this name?" -- cheap, no decryption.
// Kept to the classes that actually answer it: probing five objects with three
// selector names each turned into a six-figure call count per snapshot.
// ThemeBoxImage is included because its fileExistsWithName: is a *class* method
// over the same pack; SQNACallBool resolves through object_getClass:, so a class
// object is a valid receiver here.
static NSArray *SQNAExistenceReaders(void) {
    NSMutableArray *readers = [NSMutableArray new];
    for (NSString *cls in @[@"ThemeBoxAssets", @"ThemeBoxImageLoader"]) {
        id r = SQNAShared(cls);
        if (r) [readers addObject:r];
    }
    Class imageClass = NSClassFromString(@"ThemeBoxImage");
    if (imageClass) [readers addObject:(id)imageClass];
    return readers;
}

static BOOL SQNAExists(NSArray *readers, NSString *name) {
    for (id r in readers) {
        if (SQNACallBool(r, @"fileExistsWithName:", name)) return YES;
        if (SQNACallBool(r, @"darkFileExistsWithName:", name)) return YES;
    }
    return NO;
}

// Can any reader actually confirm a name? Without this gate the adapter would
// have to guess, and guessing thousands of names turns the export into
// thousands of doomed reads. On a real 3.0.8 device ThemeBoxAssets,
// ThemeBoxImageLoader and ThemeBoxImage all implement fileExistsWithName:, so
// this is true there. In the simulator harness the provider is a stub without
// that selector, which is exactly the case where adding names would only slow
// the run down.
static BOOL SQNACanConfirmNames(NSArray *readers) {
    for (id r in readers) if (SQNABoolIMP(r, @"fileExistsWithName:")) return YES;
    return NO;
}

// Expand a logical key into the concrete variants the provider uses.
static void SQNAExpand(NSString *base, NSMutableSet *out) {
    if (!base.length) return;
    [out addObject:base];
    static NSArray *imageExts;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        imageExts = @[@"png", @"jpg", @"jpeg", @"gif", @"webp", @"svg", @"apng"];
    });
    NSString *ext = base.pathExtension.lowercaseString;
    if (ext.length) {
        if (![imageExts containsObject:ext]) return;  // not an image name
        NSString *stem = base.stringByDeletingPathExtension;
        for (NSString *e in @[@"png", @"svg", @"gif"]) {
            if ([e isEqualToString:ext]) continue;
            [out addObject:[stem stringByAppendingPathExtension:e]];
        }
        return;
    }
    for (NSString *suffix in @[@"", @"@2x", @"@3x", @"_Dark@2x", @"_Dark@3x"]) {
        for (NSString *e in @[@"png", @"svg", @"gif", @"jpg"]) {
            [out addObject:[[base stringByAppendingString:suffix] stringByAppendingPathExtension:e]];
        }
    }
}

// SQSnapshot re-runs every 64 exported items to prove the theme did not change
// mid-export, and each run would otherwise re-do every probe -- which now means
// tens of thousands of existence checks against the asset catalog.
//
// The TTL is deliberately long: the authoritative getters are still re-read on
// every snapshot (that is what detects a theme switch, and it is what the
// signature hashes), so reusing only this derived name list cannot hide a theme
// change. It only means a list derived from a stale theme would be re-tried;
// those names simply fail to read and land in `skipped`.
// Safe without a lock because every caller is on the main thread by assertion.
static NSDictionary *SQNAIndexCache;
static NSTimeInterval SQNAIndexCacheAt;
static NSString *SQNAIndexCacheRoot;

NSDictionary *SaoqiangWCAssetsNativeIndex(NSString *root, NSData *container, NSString **error) {
    (void)error;
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (SQNAIndexCache && now - SQNAIndexCacheAt < 25.0
        && (SQNAIndexCacheRoot == root || [SQNAIndexCacheRoot isEqualToString:root])) {
        return SQNAIndexCache;
    }
    NSMutableSet *names = [NSMutableSet new];
    NSMutableArray *log = [NSMutableArray new];
    NSMutableArray<NSString *> *lines = [NSMutableArray new];

    id util = SQNAShared(@"ThemeBoxUtil");
    id loader = SQNAShared(@"ThemeBoxImageLoader");
    id assets = SQNAShared(@"ThemeBoxAssets");
    id iconMap = SQNAShared(@"ThemeBoxIconMap");
    id cache = SQNAShared(@"ThemeBoxCache");

    // Active-reader collections -- this is where the 29 came from, so the log
    // line shows whether the reader itself ever held more.
    for (NSString *sel in @[@"themeFiles", @"themeFileMap", @"diyFileMap",
                            @"bubbleFiles", @"iconMaps", @"themeData"]) {
        SQNAProbe(loader, sel, names, log, @"Loader");
        SQNAProbe(assets, sel, names, log, @"Assets");
    }
    // Icon map: ThemeBoxIconMap.maps is the theme's icon -> file table.
    SQNAProbe(iconMap, @"maps", names, log, @"IconMap");
    // Decrypted caches: their keys are concrete file names already.
    for (NSString *sel in @[@"decryptCache", @"cache", @"bubbleCache"]) {
        SQNAProbe(cache, sel, names, log, @"Cache");
    }
    // Util: instance maps plus the class-level complete lists.
    for (NSString *sel in @[@"themeFileMap", @"currentThemeFileMap", @"currentBubbleFileMap",
                            @"themeDIYFileMap", @"bubbleFileMap", @"customThemeFileList"]) {
        SQNAProbe(util, sel, names, log, @"Util");
    }
    Class utilClass = NSClassFromString(@"ThemeBoxUtil");
    for (NSString *sel in @[@"themeFileList", @"currentThemeFileList", @"currentBubbleFileList",
                            @"bubbleFileList", @"themeDIYFileList"]) {
        id value = SQNAGet((id)utilClass, sel);
        if (!value) continue;
        SQNAHarvest(value, names, 0);
        [log addObject:[NSString stringWithFormat:@"UtilClass.%@=%@", sel,
                        [value respondsToSelector:@selector(count)] ? @([value count]) : @"1"]];
    }

    // ThemeBoxImage is a different class from ThemeBoxImageLoader, and the one
    // whose name tables are class-level: fileMaps/bubbleMaps/diyMaps. They were
    // never probed before, which is the cheapest possible explanation for a
    // short list -- the loader only holds what the active theme loaded, while
    // these describe the pack itself.
    Class imageClass = NSClassFromString(@"ThemeBoxImage");
    if (imageClass) {
        for (NSString *sel in @[@"fileMaps", @"bubbleMaps", @"diyMaps"]) {
            id value = SQNAGet((id)imageClass, sel);
            if (!value) continue;
            SQNAHarvest(value, names, 0);
            [log addObject:[NSString stringWithFormat:@"Image.%@=%@", sel,
                            [value respondsToSelector:@selector(count)] ? @([value count]) : @"1"]];
        }
    }

    // The per-device table. On a pack that ships one image per device family the
    // loaded index can only ever contain the variant this device asked for, so
    // the rest is reachable only by composing <prefix><name> and asking the
    // provider. Read the table rather than assume its contents: ThemeBoxImageMap
    // is control-flow flattened, and these dictionaries are the ground truth.
    NSMutableSet *prefixes = [NSMutableSet new];
    Class imageMapClass = NSClassFromString(@"ThemeBoxImageMap");
    if (imageMapClass) {
        for (NSString *sel in @[@"currentDeviceType", @"isFullScreen", @"deviceTypeMapping",
                                @"devicePrefixMap", @"fallbackTypeMap"]) {
            id value = SQNAGet((id)imageMapClass, sel);
            if (!value) continue;
            [lines addObject:[NSString stringWithFormat:@"ImageMap.%@=%@", sel, SQNADescribe(value, 40)]];
        }
        // Only devicePrefixMap carries file-name tokens; the other two map a
        // device name to an enum and are logged for context, not harvested.
        SQNAPrefixValues(SQNAGet((id)imageMapClass, @"devicePrefixMap"), prefixes);
        [lines addObject:[NSString stringWithFormat:@"ImageMap 前缀 token（%lu 个）：%@",
                          (unsigned long)prefixes.count,
                          prefixes.count ? [[prefixes.allObjects sortedArrayUsingSelector:@selector(compare:)]
                                            componentsJoinedByString:@" "]
                                         : @"空 —— 机型变体假设不成立"]];
    } else {
        [lines addObject:@"ImageMap：类不存在，跳过设备前缀展开"];
    }

    NSUInteger harvested = names.count;
    // Names that already carry an image extension are concrete file names: keep
    // them as-is and let the read path decide. Only extensionless keys need
    // expansion, and only those get the existence check -- running the whole
    // matrix over every name cost six figures of ObjC calls per snapshot, and
    // SQSnapshot re-runs every 64 exported items.
    NSArray *readers = SQNAExistenceReaders();
    NSMutableArray *valid = [NSMutableArray new];
    NSMutableSet *expanded = [NSMutableSet new];
    NSUInteger concrete = 0, probed = 0, hits = 0;
    BOOL canConfirm = SQNACanConfirmNames(readers);
    if (canConfirm) {
        for (NSString *base in names) {
            if (!SQNALooksLikeResource(base)) continue;
            if (base.pathExtension.length > 0) {
                // A concrete file name still gets confirmed: the provider may
                // still list keys from another theme or version it cannot serve.
                ++probed;
                if (SQNAExists(readers, base)) { [valid addObject:base]; ++concrete; }
                continue;
            }
            SQNAExpand(base, expanded);
            if (expanded.count > 40000) break;
        }
        for (NSString *name in expanded) {
            ++probed;
            if (SQNAExists(readers, name)) { [valid addObject:name]; ++hits; }
        }
    }

    // Ask the provider for its own variant list. candidateFileNamesForName: is
    // ThemeBox's expansion logic: given a bare slot name it answers with the
    // concrete names it would try -- density suffixes, dark variants, device
    // prefixes. Using its answer is strictly better than guessing ours, because
    // it is the same table the pack was written against.
    NSUInteger candidateAsked = 0, candidateChecked = 0, candidateAdded = 0;
    if (canConfirm) {
        NSMutableArray *askers = [NSMutableArray new];
        for (NSString *cls in @[@"ThemeBoxAssets", @"ThemeBoxImageLoader"]) {
            id r = SQNAShared(cls);
            if (r) [askers addObject:r];
        }
        NSMutableSet *fromProvider = [NSMutableSet new];
        for (NSString *base in names) {
            if (candidateAsked >= 600 || fromProvider.count > 20000) break;
            if (!SQNALooksLikeResource(base)) continue;
            if (base.pathExtension.length) continue;   // already a concrete name
            ++candidateAsked;
            for (id asker in askers) {
                id list = SQNACallObject(asker, @"candidateFileNamesForName:", base);
                if (![list isKindOfClass:NSArray.class] && ![list isKindOfClass:NSSet.class]) continue;
                for (id item in list) {
                    if (![item isKindOfClass:NSString.class]) continue;
                    if (!SQNALooksLikeResource(item)) continue;
                    if (fromProvider.count > 20000) break;
                    [fromProvider addObject:item];
                }
            }
        }
        for (NSString *candidate in fromProvider) {
            if (candidateChecked >= 20000) break;
            ++candidateChecked;
            if (SQNAExists(readers, candidate)) { [valid addObject:candidate]; ++candidateAdded; }
        }
        [lines addObject:[NSString stringWithFormat:
            @"provider-candidates：向 provider 询问 %lu 个无扩展名槽位 → 自报候选 %lu 个，校验 %lu 个、存在 %lu 个%@",
            (unsigned long)candidateAsked, (unsigned long)fromProvider.count,
            (unsigned long)candidateChecked, (unsigned long)candidateAdded,
            askers.count ? @"" : @"（无可用 reader，本项未执行）"]];
    }

    // Whether fileExistsWithName: answers for THIS theme or for every pack the
    // loader has open decides whether guessing names is legal at all, so it is
    // measured here rather than assumed.
    //
    // 0.11.7 assumed it was per-theme and walked WeChat's whole asset catalog
    // against it. On a device with four installed packs that exported the union
    // of all four: the check answered "yes" for names the current theme does not
    // ship, so the result was not the current theme plus missing entries, it was
    // several themes mixed together. Nothing from this pass is added any more;
    // it only reports how many non-current names the provider still claims.
    // The catalog pass no longer decides ownership; it collects. Names the
    // provider confirms but this theme's own tables never list go into `probe`,
    // which the export reads and weighs against the pack -- without saving them,
    // because saving them is exactly how another theme's files got mixed in.
    //
    // That byte total is the point. The pack is a fixed 10.4 MB, so a genuine
    // theme's leftover entries can only add up to roughly (pack - already
    // exported): if the probe weighs far more than the pack can hold, it came
    // from other installed themes and nothing about it is trustworthy. The
    // export reports the arithmetic instead of asserting a conclusion.
    NSUInteger catalogCount = 0, catalogProbed = 0, catalogHits = 0, catalogBases = 0;
    NSMutableArray<NSString *> *probeNames = [NSMutableArray new];
    if (canConfirm) {
        NSArray *catalog = SQNACatalogNames();
        catalogCount = catalog.count;
        // Four shapes per name, because a shipped pack stores all four. Asking
        // only for @3x made this measurement read far lower than reality: half of
        // every theme's files are @2x, and half again are the Dark pair.
        NSArray *shapes = @[@"@3x.png", @"@2x.png", @".png",
                            @"_Dark@3x.png", @"_Dark@2x.png", @"_Dark.png"];
        for (NSString *base in catalog) {
            if (catalogProbed >= 12000) break;
            if (!SQNALooksLikeResource(base)) continue;
            ++catalogBases;
            for (NSString *suffix in shapes) {
                if (catalogProbed >= 12000) break;
                NSString *candidate = [base stringByAppendingString:suffix];
                if ([names containsObject:candidate]) continue;
                ++catalogProbed;
                if (!SQNAExists(readers, candidate)) continue;
                ++catalogHits;
                if (probeNames.count < 4000) [probeNames addObject:candidate];
            }
        }
        [lines addObject:[NSString stringWithFormat:
            @"asset-catalog：CUICatalog 图片名 %lu 个；按 @2x/@3x/Dark 六种形态校验 %lu 个本主题清单外的名字（%lu 个基名），provider 称存在 %lu 个 → 只计字节、不写文件（见封包覆盖率）",
            (unsigned long)catalogCount, (unsigned long)catalogProbed, (unsigned long)catalogBases, (unsigned long)catalogHits]];
        if (probeNames.count) {
            NSArray *sample = probeNames.count > 12
                ? [probeNames subarrayWithRange:NSMakeRange(0, 12)] : probeNames;
            [lines addObject:[NSString stringWithFormat:@"asset-catalog 样例（仅记录，不导出）：%@",
                              [sample componentsJoinedByString:@" "]]];
        }
    } else {
        [lines addObject:@"asset-catalog：本轮未探测（provider 不提供存在性判断）"];
    }

    // Per-device variants, derived only from names this theme's own tables
    // confirmed. 0.11.7 drove this from every harvested string on the argument
    // that a slot living only as "x_bg.png" is never seen unprefixed -- but with
    // an existence check that answers across all installed packs, that argument
    // buys foreign files. Narrow input, and the last thing added is the first
    // thing dropped when provenance is in doubt.
    NSUInteger prefixTries = 0, prefixHits = 0;
    NSUInteger prefixCount = 0, stemCount = 0;
    if (canConfirm && prefixes.count && valid.count) {
        NSMutableSet *stems = [NSMutableSet new];
        for (NSString *name in valid) {
            NSString *stem = name.stringByDeletingPathExtension;
            if ([stem hasSuffix:@"@2x"] || [stem hasSuffix:@"@3x"])
                stem = [stem substringToIndex:stem.length - 3];
            if (!stem.length || stem.length > 200) continue;
            [stems addObject:stem];
            if (stems.count >= 400) break;
        }
        stemCount = stems.count;
        NSArray *prefixList = [prefixes.allObjects sortedArrayUsingSelector:@selector(compare:)];
        prefixCount = prefixList.count;
        NSMutableSet *seen = [NSMutableSet setWithArray:valid];
        for (NSString *stem in stems) {
            if (prefixTries >= 40000) break;
            for (NSString *prefix in prefixList) {
                if (prefixTries >= 40000) break;
                if ([stem hasPrefix:prefix]) continue;
                // A shipped pack carries four shapes of every name: @2x and @3x,
                // each in light and Dark. Only @3x was ever asked for, so half of
                // every theme's files (the @2x set) and half again (Dark) could
                // not be reached even when the name was already confirmed.
                for (NSArray *shape in @[@[@"@3x", @"png"], @[@"@2x", @"png"],
                                          @[@"", @"png"], @[@"@3x", @"svg"]]) {
                    if (prefixTries >= 40000) break;
                    NSString *candidate = [[[prefix stringByAppendingString:stem]
                                            stringByAppendingString:shape[0]]
                                           stringByAppendingPathExtension:shape[1]];
                    if ([seen containsObject:candidate]) continue;
                    ++prefixTries;
                    if (SQNAExists(readers, candidate)) { [seen addObject:candidate]; ++prefixHits; }
                }
            }
        }
        // Dark variants are never device-prefixed, so they are asked for without
        // one: "<stem>_Dark@3x.png" and its @2x sibling.
        NSUInteger darkTries = 0, darkHits = 0;
        for (NSString *stem in stems) {
            if (darkTries >= 4000) break;
            if ([stem hasSuffix:@"_Dark"]) continue;
            for (NSArray *shape in @[@[@"_Dark@3x", @"png"], @[@"_Dark@2x", @"png"],
                                      @[@"_Dark", @"png"]]) {
                if (darkTries >= 4000) break;
                NSString *candidate = [[stem stringByAppendingString:shape[0]]
                                       stringByAppendingPathExtension:shape[1]];
                if ([seen containsObject:candidate]) continue;
                ++darkTries;
                if (SQNAExists(readers, candidate)) { [seen addObject:candidate]; ++darkHits; }
            }
        }
        valid = [seen.allObjects mutableCopy];
        [lines addObject:[NSString stringWithFormat:
            @"device-variants：前缀 %lu 个 × 槽位 %lu → 校验 %lu 命中 %lu；Dark 变体 校验 %lu 命中 %lu",
            (unsigned long)prefixCount, (unsigned long)stemCount,
            (unsigned long)prefixTries, (unsigned long)prefixHits,
            (unsigned long)darkTries, (unsigned long)darkHits]];
    } else if (canConfirm) {
        [lines addObject:[NSString stringWithFormat:
            @"device-variants：跳过（前缀 %lu 个，已确认基名 %lu 个）",
            (unsigned long)prefixes.count, (unsigned long)valid.count]];
    }

    [valid sortUsingSelector:@selector(compare:)];
    // Concrete names and expanded names can land on the same file ("x.png" as a
    // key, and "x" expanding to "x.png"). The report counts exactly what it is
    // handed, so hand it a set.
    {
        NSMutableArray *unique = [NSMutableArray arrayWithCapacity:valid.count];
        NSMutableSet *seenNames = [NSMutableSet setWithCapacity:valid.count];
        for (NSString *name in valid) {
            if ([seenNames containsObject:name]) continue;
            [seenNames addObject:name];
            [unique addObject:name];
        }
        valid = unique;
    }
    // Raised from 5000: the catalog pass alone can legitimately contribute
    // thousands, and the export's own ceiling is 19999 entries.
    if (valid.count > 12000) valid = [[valid subarrayWithRange:NSMakeRange(0, 12000)] mutableCopy];

    // Container digest. We still do not parse themebox.dat, but the report has
    // to distinguish "the provider gave us the whole pack and we only named part
    // of it" from "the pack was never in hand". Those used to look identical.
    if ([container isKindOfClass:NSData.class] && container.length) {
        const uint8_t *bytes = container.bytes;
        NSUInteger shown = MIN(container.length, (NSUInteger)24);
        NSMutableString *hex = [NSMutableString new];
        for (NSUInteger i = 0; i < shown; ++i) [hex appendFormat:@"%02x", bytes[i]];
        uint32_t head32 = 0;
        uint64_t head64 = 0;
        if (container.length >= 4) memcpy(&head32, bytes, 4);
        if (container.length >= 8) memcpy(&head64, bytes, 8);
        [lines addObject:[NSString stringWithFormat:
            @"container：%lu 字节，头部 u32=%u u64=%lu，前 %lu 字节 %@",
            (unsigned long)container.length, head32, (unsigned long)head64,
            (unsigned long)shown, hex]];
    } else {
        [lines addObject:@"container：provider 未提供整包 NSData（themeData 为空），只能按名读取"];
    }

    NSString *note;
    if (!canConfirm) {
        note = [NSString stringWithFormat:
            @"采集到 %lu 个字符串，但 provider 未提供 fileExistsWithName:，本轮不新增名字（避免盲目猜测把导出拖死）；来源：%@",
            (unsigned long)harvested,
            log.count ? [log componentsJoinedByString:@" "] : @"全部取不到"];
    } else {
        note = [NSString stringWithFormat:
            @"采集 %lu 个字符串 → 具名确认 %lu + 无扩展名展开 %lu 校验命中 %lu + 设备变体 %lu/前缀%lu → 合计 %lu；来源：%@",
            (unsigned long)harvested, (unsigned long)concrete,
            (unsigned long)probed, (unsigned long)hits,
            (unsigned long)prefixHits, (unsigned long)prefixCount,
            (unsigned long)valid.count,
            log.count ? [log componentsJoinedByString:@" "] : @"全部取不到"];
    }

    NSDictionary *index = @{@"root": root ?: @"", @"names": valid,
                            @"harvested": @(harvested), @"contained": @(valid.count),
                            @"note": note, @"lines": lines, @"probe": probeNames};
    SQNAIndexCache = index;
    SQNAIndexCacheAt = now;
    SQNAIndexCacheRoot = [root copy];
    return index;
}
