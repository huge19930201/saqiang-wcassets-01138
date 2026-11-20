#import "SaoqiangWCAssetsTheme.h"
#import "SaoqiangWCAssets.h"
#import "SaoqiangWCAssetsInspector.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach-o/loader.h>
#import <CommonCrypto/CommonDigest.h>
#import <string.h>

static NSArray *SaoqiangWCAssetsThemeLog;
static NSMutableDictionary<NSString *,NSValue *> *SaoqiangWCAssetsThemeReplacements;
static NSMutableDictionary<NSString *,NSDictionary *> *SaoqiangWCAssetsThemeEvidence;
// Hook call counts are per-installed-hook constants, so a plain atomic array
// removes the lock and dictionary write from every observed call.
#define SQThemeCallSlots 96
static int32_t SaoqiangWCAssetsThemeCallCounts[SQThemeCallSlots];
static unsigned SaoqiangWCAssetsThemeCallNext;
static NSMutableDictionary<NSString *,NSNumber *> *SaoqiangWCAssetsThemeCallSlots;
static NSMutableSet *SaoqiangWCAssetsThemeAttempted;
static NSMutableDictionary<NSString *,NSDictionary *> *SaoqiangWCAssetsDecodedThemeData;
static NSString *SaoqiangWCAssetsDecodedThemeRoot;
static NSUInteger SaoqiangWCAssetsDecodedThemeBytes;
static BOOL SaoqiangWCAssetsThemeObject(const char *t);
static NSObject *SaoqiangWCAssetsThemeLock(void) { static NSObject *lock; static dispatch_once_t once; dispatch_once(&once,^{lock=[NSObject new];}); return lock; }
static BOOL SaoqiangWCAssetsThemeLooksLikeImage(NSData *data) {
    if (![data isKindOfClass:NSData.class] || !data.length || data.length > 32 * 1024 * 1024) return NO;
    const unsigned char *p=data.bytes;NSUInteger n=data.length;
    if(n>=8&&!memcmp(p,"\x89PNG\r\n\x1a\n",8))return YES;
    if(n>=3&&p[0]==0xff&&p[1]==0xd8&&p[2]==0xff)return YES;
    if(n>=6&&(!memcmp(p,"GIF87a",6)||!memcmp(p,"GIF89a",6)))return YES;
    if(n>=12&&!memcmp(p,"RIFF",4)&&!memcmp(p+8,"WEBP",4))return YES;
    // Byte scan instead of decoding up to 8 KiB into an NSString on every call.
    NSUInteger end=MIN(n,(NSUInteger)8192);
    for(NSUInteger i=0;i+4<=end;++i)
        if(p[i]=='<'&&(p[i+1]|0x20)=='s'&&(p[i+2]|0x20)=='v'&&(p[i+3]|0x20)=='g')return YES;
    return NO;
}
static NSString *SaoqiangWCAssetsThemeHash(NSData *data) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,digest);
    NSMutableString *result=[NSMutableString new];for(NSUInteger i=0;i<sizeof(digest);i++)[result appendFormat:@"%02x",digest[i]];return result;
}
static NSString *SaoqiangWCAssetsDecodedThemeKey(NSString *name,NSString *root) {
    if(![name isKindOfClass:NSString.class]||!name.length||name.length>2048||[name containsString:@"\\"]||[name containsString:@":"]||[name rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)return nil;
    NSString *key=name;
    if(key.isAbsolutePath){NSString *prefix=[root stringByAppendingString:@"/"];if(![key hasPrefix:prefix])return nil;key=[key substringFromIndex:prefix.length];}
    if(key.isAbsolutePath||[key containsString:@"//"])return nil;
    for(NSString *part in key.pathComponents)if(!part.length||[part isEqual:@"."]||[part isEqual:@".."])return nil;
    NSString *last=key.lastPathComponent.lowercaseString;
    if([last hasSuffix:@".receipt"]||[last isEqual:@"themebox.dat"]||[last isEqual:@"manifest.json"])return nil;
    return key;
}
void SaoqiangWCAssetsThemeSetCaptureRoot(NSString *root) {
    NSString *next=[root isKindOfClass:NSString.class]&&root.isAbsolutePath?root.stringByResolvingSymlinksInPath.stringByStandardizingPath:nil;
    @synchronized(SaoqiangWCAssetsThemeLock()){
        if([SaoqiangWCAssetsDecodedThemeRoot isEqualToString:next])return;
        SaoqiangWCAssetsDecodedThemeRoot=[next copy];SaoqiangWCAssetsDecodedThemeData=[NSMutableDictionary new];SaoqiangWCAssetsDecodedThemeBytes=0;
    }
}
void SaoqiangWCAssetsThemeRefreshCaptureRoot(void) {
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{SaoqiangWCAssetsThemeRefreshCaptureRoot();});return;}
    Class manager=NSClassFromString(@"ThemeBoxMgr");SEL shared=NSSelectorFromString(@"shared"),pathSel=NSSelectorFromString(@"currentThemePath");
    Method sharedMethod=manager?class_getClassMethod(manager,shared):NULL;
    NSMethodSignature *sharedSignature=sharedMethod?[NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(sharedMethod)]:nil;
    if(!sharedSignature||sharedSignature.numberOfArguments!=2||!SaoqiangWCAssetsThemeObject(sharedSignature.methodReturnType))return;
    id object=((id(*)(id,SEL))method_getImplementation(sharedMethod))(manager,shared);
    Method pathMethod=object?class_getInstanceMethod(object_getClass(object),pathSel):NULL;
    NSMethodSignature *pathSignature=pathMethod?[NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(pathMethod)]:nil;
    if(!pathSignature||pathSignature.numberOfArguments!=2||!SaoqiangWCAssetsThemeObject(pathSignature.methodReturnType))return;
    id root=((id(*)(id,SEL))method_getImplementation(pathMethod))(object,pathSel);
    SaoqiangWCAssetsThemeSetCaptureRoot([root isKindOfClass:NSString.class]?root:nil);
}
void SaoqiangWCAssetsThemeRecordDecodedData(NSString *name,NSData *data,NSString *source) {
    if(SaoqiangWCAssetsIsSuppressed()||SaoqiangWCAssetsOwnUIActive()||!SaoqiangWCAssetsThemeLooksLikeImage(data))return;
    @synchronized(SaoqiangWCAssetsThemeLock()){
        NSString *root=SaoqiangWCAssetsDecodedThemeRoot;if(!root.length)return;
        NSString *key=SaoqiangWCAssetsDecodedThemeKey(name,root);if(!key)return;
        if(!SaoqiangWCAssetsDecodedThemeData)SaoqiangWCAssetsDecodedThemeData=[NSMutableDictionary new];
        NSDictionary *previous=SaoqiangWCAssetsDecodedThemeData[key];
        if(previous){
            if([previous[@"data"] isEqualToData:data])return;
            NSMutableDictionary *conflict=[previous mutableCopy];conflict[@"conflict"]=@YES;conflict[@"conflictSource"]=source?:@"unknown";conflict[@"conflictSHA256"]=SaoqiangWCAssetsThemeHash(data);SaoqiangWCAssetsDecodedThemeData[key]=conflict;return;
        }
        if(SaoqiangWCAssetsDecodedThemeData.count>=19999||data.length>96*1024*1024-SaoqiangWCAssetsDecodedThemeBytes)return;
        SaoqiangWCAssetsDecodedThemeData[key]=@{@"data":[data copy],@"source":source?:@"ThemeBox decoded cache",@"conflict":@NO};
        SaoqiangWCAssetsDecodedThemeBytes+=data.length;
    }
}
NSArray<NSDictionary *> *SaoqiangWCAssetsThemeCapturedSnapshot(NSString *root) {
    @synchronized(SaoqiangWCAssetsThemeLock()){
        NSString *canonical=[root isKindOfClass:NSString.class]?root.stringByResolvingSymlinksInPath.stringByStandardizingPath:nil;
        if(!canonical.length||![canonical isEqualToString:SaoqiangWCAssetsDecodedThemeRoot])return @[];
        NSMutableArray *items=[NSMutableArray new];
        for(NSString *key in [SaoqiangWCAssetsDecodedThemeData.allKeys sortedArrayUsingSelector:@selector(compare:)]){
            NSMutableDictionary *item=[SaoqiangWCAssetsDecodedThemeData[key] mutableCopy];item[@"key"]=key;[items addObject:item];
        }
        return [items copy];
    }
}
static BOOL SaoqiangWCAssetsThemeObject(const char *t) { return t && (!strcmp(t,"@") || !strncmp(t,"@\"",2)); }
static BOOL SaoqiangWCAssetsThemeABI(Method method,NSUInteger count) {
    if (!method) return NO;
    NSMethodSignature *s = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    if (s.numberOfArguments != count || !SaoqiangWCAssetsThemeObject(s.methodReturnType) || strcmp([s getArgumentTypeAtIndex:0],"@") || strcmp([s getArgumentTypeAtIndex:1],":")) return NO;
    for (NSUInteger i=2;i<count;i++) if (!SaoqiangWCAssetsThemeObject([s getArgumentTypeAtIndex:i])) return NO;
    return YES;
}
static BOOL SaoqiangWCAssetsThemeVoidABI(Method method,NSUInteger count) {
    if (!method) return NO;
    NSMethodSignature *s=[NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    if(s.numberOfArguments!=count||strcmp(s.methodReturnType,"v")||strcmp([s getArgumentTypeAtIndex:0],"@")||strcmp([s getArgumentTypeAtIndex:1],":"))return NO;
    for(NSUInteger i=2;i<count;i++)if(!SaoqiangWCAssetsThemeObject([s getArgumentTypeAtIndex:i]))return NO;
    return YES;
}
static NSString *SaoqiangWCAssetsThemeUUID(IMP implementation) {
    Dl_info info = {0}; if (!dladdr((const void *)implementation,&info) || !info.dli_fbase) return nil;
    const struct mach_header_64 *header = info.dli_fbase;
    if (header->magic != MH_MAGIC_64 || header->sizeofcmds > 1024*1024 || header->ncmds > 4096) return nil;
    const unsigned char *p = (const unsigned char *)(header+1), *end = p + header->sizeofcmds;
    for (uint32_t i=0;i<header->ncmds && p+sizeof(struct load_command)<=end;i++) {
        const struct load_command *cmd = (const void *)p;
        if (cmd->cmdsize < sizeof(*cmd) || p+cmd->cmdsize > end) return nil;
        if (cmd->cmd==LC_UUID && cmd->cmdsize>=sizeof(struct uuid_command)) return [[NSUUID alloc] initWithUUIDBytes:((const struct uuid_command *)cmd)->uuid].UUIDString;
        p += cmd->cmdsize;
    } return nil;
}
static NSDictionary *SaoqiangWCAssetsThemeOrigin(Class owner, Method method, NSString *expectedUUID) {
    if (!owner || !method) return nil;
    IMP implementation = method_getImplementation(method); Dl_info info = {0};
    const char *classImage = class_getImageName(owner);
    if (!classImage || !dladdr((const void *)implementation, &info) || !info.dli_fname || strcmp(classImage, info.dli_fname)) return nil;
    NSString *uuid = SaoqiangWCAssetsThemeUUID(implementation);
    NSArray *allowed=[expectedUUID componentsSeparatedByString:@"|"];
    if (![allowed containsObject:uuid]) return nil;
    return @{ @"uuid":uuid, @"image":@(info.dli_fname) };
}
static BOOL SaoqiangWCAssetsThemeSizedABI(Method method) {
    if (!method) return NO;
    NSMethodSignature *s = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    return s.numberOfArguments == 5 && SaoqiangWCAssetsThemeObject(s.methodReturnType) &&
        !strcmp([s getArgumentTypeAtIndex:0], "@") && !strcmp([s getArgumentTypeAtIndex:1], ":") &&
        SaoqiangWCAssetsThemeObject([s getArgumentTypeAtIndex:2]) && !strcmp([s getArgumentTypeAtIndex:3], @encode(CGSize)) &&
        SaoqiangWCAssetsThemeObject([s getArgumentTypeAtIndex:4]);
}
static void SaoqiangWCAssetsThemeDidCall(unsigned slot) {
    if (slot < SQThemeCallSlots) __atomic_fetch_add(&SaoqiangWCAssetsThemeCallCounts[slot], 1, __ATOMIC_RELAXED);
}
BOOL SaoqiangWCAssetsIsActiveThemePath(NSString *path) { (void)path; return NO; }
static void SaoqiangWCAssetsInstallPassiveHook(NSMutableArray *log, NSString *ownerName, NSString *name, BOOL classSide, BOOL dataOnly, NSInteger arguments, BOOL sized, BOOL bubble, NSString *uuid) {
    Class owner = NSClassFromString(ownerName), target = classSide ? object_getClass(owner) : owner;
    SEL sel = NSSelectorFromString(name); Method m = target ? class_getInstanceMethod(target, sel) : NULL;
    NSString *key = [NSString stringWithFormat:@"%c[%@ %@]", classSide ? '+' : '-', ownerName, name];
    IMP replacement = [SaoqiangWCAssetsThemeReplacements[key] pointerValue];
    BOOL installed = m && replacement && method_getImplementation(m) == replacement;
    BOOL attempted = [SaoqiangWCAssetsThemeAttempted containsObject:key];
    BOOL abi = sized ? SaoqiangWCAssetsThemeSizedABI(m) : (arguments<0?SaoqiangWCAssetsThemeVoidABI(m,(NSUInteger)(-arguments)):SaoqiangWCAssetsThemeABI(m, arguments));
    NSDictionary *evidence = installed ? SaoqiangWCAssetsThemeEvidence[key] : SaoqiangWCAssetsThemeOrigin(owner, m, uuid);
    if (abi && evidence && !attempted) {
        unsigned slot = SaoqiangWCAssetsThemeCallNext;
        if (slot < SQThemeCallSlots) { ++SaoqiangWCAssetsThemeCallNext;
            if (!SaoqiangWCAssetsThemeCallSlots) SaoqiangWCAssetsThemeCallSlots = [NSMutableDictionary new];
            SaoqiangWCAssetsThemeCallSlots[key] = @(slot); }
        IMP old = method_getImplementation(m); id block=nil;
        if (arguments == -4) block = ^void(id receiver,id data,id cacheKey) {
            ((void(*)(id,SEL,id,id))old)(receiver,sel,data,cacheKey);
            SaoqiangWCAssetsThemeDidCall(slot);
            if([cacheKey isKindOfClass:NSString.class]&&[data isKindOfClass:NSData.class])SaoqiangWCAssetsThemeRecordDecodedData(cacheKey,data,key);
        };
        else if (arguments == -3) block = ^void(id receiver,id data) {
            ((void(*)(id,SEL,id))old)(receiver,sel,data);
            SaoqiangWCAssetsThemeDidCall(slot);
        };
        else if ([ownerName isEqual:@"ThemeBoxMgr"] && [name isEqual:@"currentThemePath"]) block = ^id(id receiver) {
            id result=((id(*)(id,SEL))old)(receiver,sel);
            SaoqiangWCAssetsThemeDidCall(slot);
            SaoqiangWCAssetsThemeSetCaptureRoot([result isKindOfClass:NSString.class]?result:nil);
            return result;
        };
        else if (dataOnly) block = ^id(id receiver, id filename) {
            id result = ((id (*)(id, SEL, id))old)(receiver, sel, filename);
            SaoqiangWCAssetsThemeDidCall(slot);
            if ([filename isKindOfClass:NSString.class] && [result isKindOfClass:NSData.class]) {
                SaoqiangWCAssetsThemeRecordDecodedData(filename,result,key);
                SaoqiangWCAssetsObserveSourceData(filename,result);
                SaoqiangWCAssetsAssociateNamedData(result,[filename isAbsolutePath]?[filename lastPathComponent]:filename,key,bubble);
            }
            return result;
        };
        else if (sized) block = ^id(id receiver, id filename, CGSize size, id config) {
            SaoqiangWCAssetsThemeDidCall(slot);
            return SaoqiangWCAssetsCallNamedSource(filename, key, bubble, ^id {
                return ((id (*)(id, SEL, id, CGSize, id))old)(receiver, sel, filename, size, config);
            });
        };
        else if (arguments == 4) block = ^id(id receiver, id filename, id config) {
            SaoqiangWCAssetsThemeDidCall(slot);
            return SaoqiangWCAssetsCallNamedSource(filename, key, bubble, ^id {
                return ((id (*)(id, SEL, id, id))old)(receiver, sel, filename, config);
            });
        };
        else block = ^id(id receiver, id filename) {
            SaoqiangWCAssetsThemeDidCall(slot);
            return SaoqiangWCAssetsCallNamedSource(filename, key, bubble, ^id {
                return ((id (*)(id, SEL, id))old)(receiver, sel, filename);
            });
        };
        replacement = imp_implementationWithBlock(block);
        if (!class_addMethod(target, sel, replacement, method_getTypeEncoding(m))) method_setImplementation(class_getInstanceMethod(target, sel), replacement);
        SaoqiangWCAssetsThemeReplacements[key] = [NSValue valueWithPointer:replacement];
        SaoqiangWCAssetsThemeEvidence[key] = evidence; [SaoqiangWCAssetsThemeAttempted addObject:key]; installed = YES;
    }
    NSString *status = installed ? (dataOnly ? @"installed; data only feeds current invocation" : @"installed; named return metadata only") :
        (attempted ? @"replaced by another plugin; no repeated wrapper" : (!m ? @"missing selector" : (!abi ? @"ABI mismatch" : @"class/IMP origin or sample UUID mismatch")));
    [log addObject:@{@"owner":key, @"encoding":m ? @(method_getTypeEncoding(m)) : @"missing", @"status":status,
        @"expectedUUID":uuid, @"verifiedOrigin":evidence ?: @{}, @"dataOnly":@(dataOnly)}];
}
void SaoqiangWCAssetsDiscoverTheme(void) {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ SaoqiangWCAssetsDiscoverTheme(); }); return; }
    if (!SaoqiangWCAssetsThemeAttempted) {
        SaoqiangWCAssetsThemeAttempted = [NSMutableSet new]; SaoqiangWCAssetsThemeReplacements = [NSMutableDictionary new];
        SaoqiangWCAssetsThemeEvidence = [NSMutableDictionary new];
    }
    SaoqiangWCAssetsThemeRefreshCaptureRoot();
    NSMutableArray *log = [NSMutableArray new];
    NSString *legacyThemeUUID = @"DAC0AF22-35FF-3A94-889A-FAFEF36F63BF|99F293E2-5816-34E0-9A1C-47ADC9AE1ABA|8D2E7634-0118-3872-8F9E-15E2914D7A44";
    NSString *newThemeUUID = @"8D2E7634-0118-3872-8F9E-15E2914D7A44";
    NSString *bubbleUUID = @"7A8A390F-64A4-369A-A06A-50F7C1A8E643";
    // Class side and ABI are from the supplied 2.3.6/3.0.3/3.0.8 samples.
    for (NSString *name in @[@"imageNamed:", @"themeImageNamed:", @"mapsImageNamed:", @"imageWithContentsOfFile:"])
        SaoqiangWCAssetsInstallPassiveHook(log, @"ThemeBoxImageLoader", name, NO, NO, 3, NO, NO, legacyThemeUUID);
    SaoqiangWCAssetsInstallPassiveHook(log, @"ThemeBoxImageLoader", @"svgImageNamed:config:", NO, NO, 4, NO, NO, legacyThemeUUID);
    SaoqiangWCAssetsInstallPassiveHook(log, @"ThemeBoxImageLoader", @"svgImageNamed:size:config:", NO, NO, 5, YES, NO, legacyThemeUUID);
    for (NSString *name in @[@"dataForFileName:", @"dataWithContentsOfFile:", @"cacheDataForFileName:", @"imageDataWithNamed:", @"svgImageDataWithFileName:", @"svgDataWithName:"])
        SaoqiangWCAssetsInstallPassiveHook(log, @"ThemeBoxImageLoader", name, NO, YES, 3, NO, NO, legacyThemeUUID);
    // 3.0.8's directory map may contain only loose files. These hooks observe
    // the provider and its decrypted cache when the native pack is actually used.
    SaoqiangWCAssetsInstallPassiveHook(log, @"ThemeBoxMgr", @"currentThemePath", NO, NO, 2, NO, NO, legacyThemeUUID);
    for (NSString *name in @[@"imageNamed:", @"imageWithContentsOfFile:", @"imageWithName:"])
        SaoqiangWCAssetsInstallPassiveHook(log, @"ThemeBoxAssets", name, NO, NO, 3, NO, NO, newThemeUUID);
    SaoqiangWCAssetsInstallPassiveHook(log, @"ThemeBoxAssets", @"svgImageNamed:size:config:", NO, NO, 5, YES, NO, newThemeUUID);
    SaoqiangWCAssetsInstallPassiveHook(log, @"ThemeBoxAssets", @"imageNamed:", YES, NO, 3, NO, NO, newThemeUUID);
    SaoqiangWCAssetsInstallPassiveHook(log, @"ThemeBoxAssets", @"svgImageNamed:size:config:", YES, NO, 5, YES, NO, newThemeUUID);
    SaoqiangWCAssetsInstallPassiveHook(log, @"ThemeBoxAssets", @"dataWithContentsOfFile:", NO, YES, 3, NO, NO, newThemeUUID);
    for (NSString *name in @[@"getFile:", @"getThemeFile:", @"getData:"])
        SaoqiangWCAssetsInstallPassiveHook(log, @"ThemeBoxCache", name, NO, YES, 3, NO, NO, newThemeUUID);
    SaoqiangWCAssetsInstallPassiveHook(log, @"ThemeBoxCache", @"setData:key:", NO, NO, -4, NO, NO, newThemeUUID);
    for (NSString *name in @[@"getImageWithName:", @"imageWithName:", @"imageWithContentsOfFile:"])
        SaoqiangWCAssetsInstallPassiveHook(log, @"BubbleBoxAssets", name, NO, NO, 3, NO, YES, bubbleUUID);
    SaoqiangWCAssetsInstallPassiveHook(log, @"BubbleBoxAssets", @"svgImageNamed:fromConfig:", NO, NO, 4, NO, YES, bubbleUUID);
    SaoqiangWCAssetsInstallPassiveHook(log, @"BubbleBoxAssets", @"svgImageNamed:fromConfig:", YES, NO, 4, NO, YES, bubbleUUID);
    for (NSString *name in @[@"fileDataWithName:", @"dataWithContentsOfFile:"])
        SaoqiangWCAssetsInstallPassiveHook(log, @"BubbleBoxAssets", name, NO, YES, 3, NO, YES, bubbleUUID);
    SaoqiangWCAssetsInstallPassiveHook(log,@"BubbleBoxAssets",@"imageNamed:",YES,NO,3,NO,YES,bubbleUUID);
    SaoqiangWCAssetsInstallPassiveHook(log,@"BubbleBoxAssets",@"imageData:",YES,YES,3,NO,YES,bubbleUUID);
    @synchronized (SaoqiangWCAssetsThemeLock()) { SaoqiangWCAssetsThemeLog = [log copy]; }
}
NSString *SaoqiangWCAssetsThemeDiagnostics(void) {
    NSMutableArray *rows = [NSMutableArray new];
    @synchronized (SaoqiangWCAssetsThemeLock()) {
        for (NSDictionary *entry in SaoqiangWCAssetsThemeLog ?: @[]) {
            NSMutableDictionary *row = [entry mutableCopy];
            NSNumber *slot = SaoqiangWCAssetsThemeCallSlots[entry[@"owner"]];
            row[@"observedCalls"] = (slot && slot.unsignedIntValue < SQThemeCallSlots) ?
                @(__atomic_load_n(&SaoqiangWCAssetsThemeCallCounts[slot.unsignedIntValue], __ATOMIC_RELAXED)) : @0;
            [rows addObject:row];
        }
    }
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:rows options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding] ?: @"[]";
}
