#import "SaoqiangWCAssets.h"
#import "SaoqiangWCAssetsInspector.h"
#import "SaoqiangWCAssetsTheme.h"
#import <objc/runtime.h>
#import <string.h>
#import <limits.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

static _Thread_local unsigned SaoqiangWCAssetsHookDepth;
static NSMutableArray<NSDictionary *> *SaoqiangWCAssetsDiagnostics;
static NSMutableSet<NSString *> *SaoqiangWCAssetsInstalled;
static char SaoqiangWCAssetsSVGObjectInfoKey;
// ===== 0.11.42：CGImage → 资源名 备忘 =====
// Two kinds of icon reach the list without a name, and both used to end up as
// 「无原始资源名」:
//   1. icons decoded long before 开始抓取 was tapped (no hooked load any more);
//   2. icons WeChat draws straight into layer.contents, so the sampler only has
//      a raw CGImage and never a UIImage with metadata.
// Record the CGImage each named load produced, even while the capture session is
// off, and let an exact pointer match name a later snapshot. The CGImage is
// retained so its address stays unique; a count/byte budget bounds that memory.
@interface SaoqiangWCAssetsCGMemoEntry : NSObject
@property(nonatomic) CGImageRef cg;
@property(nonatomic, copy) NSString *name;
@end
@implementation SaoqiangWCAssetsCGMemoEntry
- (void)dealloc { if (_cg) CGImageRelease(_cg); }
@end
static NSMutableArray<SaoqiangWCAssetsCGMemoEntry *> *SaoqiangWCAssetsCGMemo;
static size_t SaoqiangWCAssetsCGMemoBytes;
static const NSUInteger SaoqiangWCAssetsCGMemoCount = 160;
static const size_t SaoqiangWCAssetsCGMemoBudget = 8u * 1024u * 1024u;
static NSObject *SaoqiangWCAssetsCGMemoLock(void) {
    static NSObject *lock; static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [NSObject new]; });
    return lock;
}
static void SaoqiangWCAssetsRememberCGName(UIImage *image, NSString *name) {
    if (![image isKindOfClass:UIImage.class] || !SaoqiangWCAssetsSafeRendererName(name)) return;
    // 0.11.43: this now runs on MMThemeManager's hot path. -size/-scale are plain
    // metadata, while -CGImage can force a decode, so reject a big image before
    // ever asking for its bitmap (a big image is never a toolbar icon).
    CGSize logical = image.size; CGFloat scale = image.scale > 0 ? image.scale : 1;
    if (!(logical.width > 0) || !(logical.height > 0) || logical.width * scale > 256 || logical.height * scale > 256) return;
    CGImageRef cg = image.CGImage; if (!cg) return;
    size_t width = CGImageGetWidth(cg), height = CGImageGetHeight(cg);
    // Only the small icons this panel cares about; a big image is never a toolbar icon.
    if (!width || !height || width > 256 || height > 256) return;
    size_t bytes = width * height * 4;
    @synchronized (SaoqiangWCAssetsCGMemoLock()) {
        if (!SaoqiangWCAssetsCGMemo) SaoqiangWCAssetsCGMemo = [NSMutableArray new];
        for (SaoqiangWCAssetsCGMemoEntry *entry in SaoqiangWCAssetsCGMemo)
            if (entry.cg == cg) { if (![entry.name isEqual:name]) entry.name = name; return; }
        while (SaoqiangWCAssetsCGMemo.count && (SaoqiangWCAssetsCGMemo.count >= SaoqiangWCAssetsCGMemoCount ||
               SaoqiangWCAssetsCGMemoBytes + bytes > SaoqiangWCAssetsCGMemoBudget)) {
            SaoqiangWCAssetsCGMemoEntry *old = SaoqiangWCAssetsCGMemo.firstObject;
            size_t oldBytes = old.cg ? CGImageGetWidth(old.cg) * CGImageGetHeight(old.cg) * 4 : 0;
            SaoqiangWCAssetsCGMemoBytes -= MIN(SaoqiangWCAssetsCGMemoBytes, oldBytes);
            [SaoqiangWCAssetsCGMemo removeObjectAtIndex:0];
        }
        SaoqiangWCAssetsCGMemoEntry *entry = [SaoqiangWCAssetsCGMemoEntry new];
        entry.cg = CGImageRetain(cg); entry.name = name;
        [SaoqiangWCAssetsCGMemo addObject:entry];
        SaoqiangWCAssetsCGMemoBytes += bytes;
    }
}
NSString * _Nullable SaoqiangWCAssetsMemoizedNameForCGImage(CGImageRef cg) {
    if (!cg) return nil;
    @synchronized (SaoqiangWCAssetsCGMemoLock()) {
        for (SaoqiangWCAssetsCGMemoEntry *entry in SaoqiangWCAssetsCGMemo)
            if (entry.cg == cg) return entry.name;
    }
    return nil;
}
@interface SaoqiangWCAssetsSVGScope : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, strong) NSData *raw;
@property(nonatomic, copy) NSString *dataName;
@property(nonatomic) BOOL conflicted;
@end
@implementation SaoqiangWCAssetsSVGScope
@end
// A non-owning pointer is safe only while the strong local scope is on-stack.
// Every hook restores it in @finally. No raw lookup/cache is indexed by a name.
static _Thread_local void *SaoqiangWCAssetsCurrentSVGScope;
static _Thread_local unsigned SaoqiangWCAssetsSVGScopeDepth;
static BOOL SaoqiangWCAssetsCanCapture(void) {
    // Master off, or only theme capture on: one relaxed load ends the chain
    // before any TLS or weak read. This predicate is icon naming only.
    return SaoqiangWCAssetsMasterEnabled() && SaoqiangWCAssetsIconCaptureActive() &&
        !SaoqiangWCAssetsIsSuppressed() && !SaoqiangWCAssetsOwnUIActive();
}
static void SaoqiangWCAssetsOfferSVG(SaoqiangWCAssetsSVGScope *scope, NSString *name, NSData *raw) {
    if (!scope || !raw || scope.conflicted || !SaoqiangWCAssetsSameResourceName(scope.name, name)) return;
    if ((scope.dataName && !SaoqiangWCAssetsSameResourceName(scope.dataName,name) && !SaoqiangWCAssetsRequestMatchesFile(scope.dataName,name) && !SaoqiangWCAssetsRequestMatchesFile(name,scope.dataName)) || (scope.raw && ![scope.raw isEqualToData:raw])) {
        scope.raw = nil; scope.conflicted = YES; return;
    }
    if (!scope.dataName || (!SaoqiangWCAssetsSameResourceName(scope.dataName,name) && SaoqiangWCAssetsRequestMatchesFile(scope.dataName,name)) || (!scope.dataName.pathExtension.length && name.pathExtension.length)) scope.dataName = name;
    scope.raw = raw;
}
@interface SaoqiangWCAssetsSourceScope : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *dataName;
@property(nonatomic, copy) NSData *raw;
@property(nonatomic) BOOL conflicted;
@property(nonatomic) BOOL candidateBubble;
@end
@implementation SaoqiangWCAssetsSourceScope
@end
static _Thread_local void *SaoqiangWCAssetsCurrentSourceScope;
static _Thread_local unsigned SaoqiangWCAssetsSourceScopeDepth;
static BOOL SaoqiangWCAssetsSourceName(NSString *name) {
    if (![name isKindOfClass:NSString.class]) return NO;
    if (!name.isAbsolutePath) return SaoqiangWCAssetsSafeRendererName(name);
    // Keep the full observed path while matching; never match by basename alone.
    return name.length <= 2048 && ![name containsString:@".."] && ![name containsString:@"\\"] &&
        [name rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location == NSNotFound && SaoqiangWCAssetsSafeRendererName(name.lastPathComponent);
}
static NSData *SaoqiangWCAssetsSourceBytes(id value) {
    if (![value isKindOfClass:NSData.class] || ![value length] || [value length] > 2 * 1024 * 1024) return nil;
    NSData *data = value; const unsigned char *p = data.bytes;
    if ((data.length >= 8 && !memcmp(p, "\x89PNG\r\n\x1a\n", 8)) || (data.length >= 3 && p[0] == 0xff && p[1] == 0xd8 && p[2] == 0xff)) return [data copy];
    NSUInteger end = MIN(data.length, (NSUInteger)4096);
    for (NSUInteger i = 0; i + 4 <= end; ++i) if (p[i] == '<' && (p[i+1] == 's' || p[i+1] == 'S') && (p[i+2] == 'v' || p[i+2] == 'V') && (p[i+3] == 'g' || p[i+3] == 'G')) return [data copy];
    return nil;
}
static void SaoqiangWCAssetsOfferSource(SaoqiangWCAssetsSourceScope *scope, NSString *name, NSData *raw) {
    if (!scope.name || !raw || scope.conflicted || !SaoqiangWCAssetsRequestMatchesFile(scope.name,name)) return;
    // An extensionless request may observe x.svg OR x.png, never both. Matching
    // both to the request is insufficient: the observed data names must agree.
    if ((scope.dataName && !SaoqiangWCAssetsSameResourceName(scope.dataName,name) && !SaoqiangWCAssetsRequestMatchesFile(scope.dataName,name) && !SaoqiangWCAssetsRequestMatchesFile(name,scope.dataName)) || (scope.raw && ![scope.raw isEqualToData:raw])) {
        scope.raw = nil; scope.conflicted = YES; return;
    }
    if (!scope.dataName || (!SaoqiangWCAssetsSameResourceName(scope.dataName,name) && SaoqiangWCAssetsRequestMatchesFile(scope.dataName,name)) || (!scope.dataName.pathExtension.length && name.pathExtension.length)) scope.dataName = name;
    scope.raw = raw;
}
void SaoqiangWCAssetsObserveSourceData(NSString *name, NSData *data) {
    if (!SaoqiangWCAssetsCanCapture() || !SaoqiangWCAssetsSourceName(name)) return;
    NSData *raw = SaoqiangWCAssetsSourceBytes(data); if (!raw) return;
    SaoqiangWCAssetsSourceScope *scope = (__bridge id)SaoqiangWCAssetsCurrentSourceScope;
    SaoqiangWCAssetsAssociateNamedData(data,name.isAbsolutePath?name.lastPathComponent:name,@"实际命名资源数据",scope.candidateBubble || SaoqiangWCAssetsBubbleName(name));
    SaoqiangWCAssetsOfferSource(scope, name, raw);
    // Feed only the active named SVG invocation; data-only calls do not survive
    // this stack or become records. PNG theme replacements retain their bytes too.
    SaoqiangWCAssetsSVGScope *svgScope = (__bridge id)SaoqiangWCAssetsCurrentSVGScope;
    if (scope.conflicted && SaoqiangWCAssetsSameResourceName(scope.name, svgScope.name)) { svgScope.raw = nil; svgScope.conflicted = YES; }
    else if (!scope || (scope.name && SaoqiangWCAssetsSameResourceName(scope.name, svgScope.name))) SaoqiangWCAssetsOfferSVG(svgScope, name, raw);
}
id SaoqiangWCAssetsCallNamedSource(NSString *name, NSString *source, BOOL candidateBubble, id (^invoke)(void)) {
    if (!SaoqiangWCAssetsMasterEnabled() || !SaoqiangWCAssetsIconCaptureActive()) return invoke();
    SaoqiangWCAssetsSourceScope *parent = (__bridge id)SaoqiangWCAssetsCurrentSourceScope;
    // Fast path for the overwhelming majority of WeChat's own image loads: no
    // enclosing observation can consume this call and the name itself is not
    // recordable, so the scope object, block and TLS swap are all dead weight.
    // A nameless scope would only have blocked those same inner observations,
    // and with no SVG scope active there is nothing for them to feed.
    if (!parent && !SaoqiangWCAssetsCurrentSVGScope && !candidateBubble &&
        !(SaoqiangWCAssetsSourceScopeDepth < 16 && SaoqiangWCAssetsCanCapture() && SaoqiangWCAssetsSourceName(name)))
        return invoke();
    SaoqiangWCAssetsSourceScope *scope = [SaoqiangWCAssetsSourceScope new];
    scope.candidateBubble = candidateBubble || (parent.candidateBubble && SaoqiangWCAssetsRequestMatchesFile(parent.name, name));
    if (SaoqiangWCAssetsSourceScopeDepth < 16 && SaoqiangWCAssetsCanCapture() && SaoqiangWCAssetsSourceName(name)) scope.name = name;
    void *previous = SaoqiangWCAssetsCurrentSourceScope;
    SaoqiangWCAssetsCurrentSourceScope = (__bridge void *)scope; ++SaoqiangWCAssetsSourceScopeDepth;
    id result = nil;
    @try { result = invoke(); }
    @finally { --SaoqiangWCAssetsSourceScopeDepth; SaoqiangWCAssetsCurrentSourceScope = previous; }
    if (scope.name && SaoqiangWCAssetsCanCapture()) {
        if (scope.candidateBubble && SaoqiangWCAssetsRequestMatchesFile(parent.name, scope.name)) parent.candidateBubble = YES;
        if (scope.conflicted && SaoqiangWCAssetsRequestMatchesFile(parent.name, scope.name)) { parent.raw = nil; parent.conflicted = YES; }
        else SaoqiangWCAssetsOfferSource(parent, scope.dataName ?: scope.name, scope.raw);
        if ([result isKindOfClass:UIImage.class]) {
            NSString *actual = scope.conflicted ? scope.name : (scope.dataName ?: scope.name);
            if (actual.isAbsolutePath) SaoqiangWCAssetsAssociateFilePath(result, actual);
            NSString *resource = actual.isAbsolutePath ? actual.lastPathComponent : actual;
            SaoqiangWCAssetsAssociateSourceImage(result, resource, scope.conflicted ? nil : scope.raw, source, scope.candidateBubble);
        }
    }
    return result;
}
static SaoqiangWCAssetsSVGScope *SaoqiangWCAssetsOpenSVGScope(NSString *name) {
    SaoqiangWCAssetsSVGScope *scope = [SaoqiangWCAssetsSVGScope new];
    if (SaoqiangWCAssetsSVGScopeDepth < 16 && SaoqiangWCAssetsCanCapture() && SaoqiangWCAssetsSafeRendererName(name)) scope.name = name;
    return scope;
}
static void SaoqiangWCAssetsCapture(id image, id name, NSString *source, NSString *path, BOOL svg) {
    if (!SaoqiangWCAssetsCanCapture() || ![image isKindOfClass:UIImage.class] || !SaoqiangWCAssetsUIName(name)) return;
    SaoqiangWCAssetsRememberCGName(image, name);
    SaoqiangWCAssetsAssociateNamedImage(image, name, source, path ?: SaoqiangWCAssetsObservedFilePath(image), svg);

}
static UIImage *(*SaoqiangWCAssetsOriginalNamed)(id, SEL, NSString *);
static UIImage *(*SaoqiangWCAssetsOriginalBundle)(id, SEL, NSString *, NSBundle *, UITraitCollection *);
static UIImage *(*SaoqiangWCAssetsOriginalFile)(id, SEL, NSString *);
// A cleanup attribute replaces @try/@finally here: these run for every image
// load in the process, and an exception frame per call is pure overhead when
// nothing throws. Unwinding still runs the cleanup, so the depth stays correct.
static void SaoqiangWCAssetsDepthRelease(unsigned **slot) { if (slot && *slot && **slot) --**slot; }
// Every name-bearing route does the same three things: forward the call inside a
// name scope, record the load when capture is running, and hand the image back.
// Four copies of that body used to drift between the routes; one helper now.
static UIImage *SaoqiangWCAssetsNamedRoute(NSString *scopeName, NSString *recordName, NSString *source,
                                           NSString *path, BOOL svg, UIImage *(^call)(void)) {
    UIImage *image;
    {
        ++SaoqiangWCAssetsHookDepth;
        unsigned *__attribute__((cleanup(SaoqiangWCAssetsDepthRelease))) release = &SaoqiangWCAssetsHookDepth;
        (void)release;
        image = SaoqiangWCAssetsCallNamedSource(scopeName ?: @"", source, NO, call);
    }
    if (!SaoqiangWCAssetsHookDepth && recordName.length) SaoqiangWCAssetsCapture(image, recordName, source, path, svg);
    return image;
}
// Capture idle: still memoise CGImage→name. The icons this panel exists for were
// loaded long before 开始抓取, so this is the only chance to learn their names.
static UIImage *SaoqiangWCAssetsMemoized(UIImage *image, NSString *name) {
    SaoqiangWCAssetsRememberCGName(image, name); return image;
}
static UIImage *SaoqiangWCAssetsNamed(id receiver, SEL cmd, NSString *name) {
    if (!SaoqiangWCAssetsMasterEnabled()) return SaoqiangWCAssetsOriginalNamed(receiver, cmd, name);
    if (!SaoqiangWCAssetsIconCaptureActive()) return SaoqiangWCAssetsMemoized(SaoqiangWCAssetsOriginalNamed(receiver, cmd, name), name);
    return SaoqiangWCAssetsNamedRoute(SaoqiangWCAssetsSafeRendererName(name) ? name : @"", name,
        @"运行时 UIImage imageNamed:", nil, NO, ^UIImage *(void) {
            return SaoqiangWCAssetsOriginalNamed(receiver, cmd, name);
        });
}
static UIImage *SaoqiangWCAssetsBundle(id receiver, SEL cmd, NSString *name, NSBundle *bundle, UITraitCollection *traits) {
    if (!SaoqiangWCAssetsMasterEnabled()) return SaoqiangWCAssetsOriginalBundle(receiver, cmd, name, bundle, traits);
    static NSString *mainPath; static dispatch_once_t once;
    dispatch_once(&once, ^{ mainPath = NSBundle.mainBundle.bundlePath.stringByStandardizingPath; });
    BOOL mainBundle = !bundle || [bundle.bundlePath.stringByStandardizingPath isEqual:mainPath];
    if (!SaoqiangWCAssetsIconCaptureActive()) {
        UIImage *image = SaoqiangWCAssetsOriginalBundle(receiver, cmd, name, bundle, traits);
        return mainBundle ? SaoqiangWCAssetsMemoized(image, name) : image;
    }
    return SaoqiangWCAssetsNamedRoute(mainBundle && SaoqiangWCAssetsSafeRendererName(name) ? name : @"",
        mainBundle ? name : nil, @"运行时 UIImage imageNamed:inBundle:", nil, NO, ^UIImage *(void) {
            return SaoqiangWCAssetsOriginalBundle(receiver, cmd, name, bundle, traits);
        });
}
static UIImage *SaoqiangWCAssetsFile(id receiver, SEL cmd, NSString *path) {
    if (!SaoqiangWCAssetsMasterEnabled()) return SaoqiangWCAssetsOriginalFile(receiver, cmd, path);
    NSString *name = path.lastPathComponent;
    if (!SaoqiangWCAssetsIconCaptureActive()) return SaoqiangWCAssetsMemoized(SaoqiangWCAssetsOriginalFile(receiver, cmd, path), name);
    UIImage *image;
    {
        ++SaoqiangWCAssetsHookDepth;
        unsigned *__attribute__((cleanup(SaoqiangWCAssetsDepthRelease))) release = &SaoqiangWCAssetsHookDepth;
        (void)release;
        image = SaoqiangWCAssetsOriginalFile(receiver, cmd, path);
    }
    // This association alone never creates a record. A verified bubble owner may
    // later prove this exact image is a background, including a theme path.
    SaoqiangWCAssetsAssociateFilePath(image, path);
    if (SaoqiangWCAssetsBubbleName(path) && SaoqiangWCAssetsCanCapture()) SaoqiangWCAssetsAssociateBubbleCandidate(image,name);
    if (!SaoqiangWCAssetsHookDepth) SaoqiangWCAssetsCapture(image, name, @"运行时 UIImage imageWithContentsOfFile:", path, NO);
    SaoqiangWCAssetsRememberBacking(image);
    return image;
}
static void SaoqiangWCAssetsReplace(Class cls, SEL sel, IMP replacement, IMP *original) {
    Method m = class_getInstanceMethod(cls, sel); if (!m) return;
    *original = method_getImplementation(m);
    if (!class_addMethod(cls, sel, replacement, method_getTypeEncoding(m))) *original = method_setImplementation(class_getInstanceMethod(cls, sel), replacement);
}
// Class-origin tests run thousands of times per discovery pass. The old form
// built a fresh NSString for the bundle path and another for every class image
// name, which dominated the launch hitch: cache the prefix once and compare the
// raw C strings.
static BOOL SaoqiangWCAssetsHostImage(const char *image) {
    static char prefix[PATH_MAX]; static size_t length; static dispatch_once_t once;
    dispatch_once(&once, ^{
        const char *path = NSBundle.mainBundle.bundlePath.UTF8String ?: "";
        length = MIN(strlen(path), sizeof(prefix) - 2);
        memcpy(prefix, path, length); prefix[length++] = '/';
    });
    return image && length && !strncmp(image, prefix, length);
}
static BOOL SaoqiangWCAssetsObjectType(const char *t) { return t && (!strcmp(t, "@") || !strncmp(t, "@\"", 2)); }
static BOOL SaoqiangWCAssetsObjectsSignature(NSMethodSignature *s, NSUInteger count) {
    if (!s || s.numberOfArguments != count || !SaoqiangWCAssetsObjectType(s.methodReturnType) || strcmp([s getArgumentTypeAtIndex:0], "@") || strcmp([s getArgumentTypeAtIndex:1], ":")) return NO;
    for (NSUInteger i = 2; i < count; ++i) if (!SaoqiangWCAssetsObjectType([s getArgumentTypeAtIndex:i])) return NO;
    return YES;
}
static BOOL SaoqiangWCAssetsHostClass(Class cls) {
    return cls ? SaoqiangWCAssetsHostImage(class_getImageName(cls)) : NO;
}
static BOOL SaoqiangWCAssetsHostMethod(Method m) {
    if (!m) return NO;
    Dl_info info = {0}; dladdr((const void *)method_getImplementation(m), &info);
    return SaoqiangWCAssetsHostImage(info.dli_fname);
}
static NSData *SaoqiangWCAssetsRawSVG(id value) {
    if (![value isKindOfClass:NSData.class] || ![value length] || [value length] > 512 * 1024) return nil;
    NSData *data = value;
    // Only peek a short XML prolog here. Full validation/classification is done
    // on the serial processing queue. Do not convert arbitrary objects/strings.
    const unsigned char *p = data.bytes; NSUInteger end = MIN(data.length, (NSUInteger)4096);
    for (NSUInteger i=0; i+4<=end; ++i) if (p[i]=='<' && (p[i+1]=='s'||p[i+1]=='S') && (p[i+2]=='v'||p[i+2]=='V') && (p[i+3]=='g'||p[i+3]=='G')) return [data copy];
    return nil;
}
static BOOL SaoqiangWCAssetsSVGWrapper(id value) {
    if (!value) return NO;
    Class cls = object_getClass(value);
    return SaoqiangWCAssetsHostClass(cls) && [@[@"WCSVGImage", @"WCSVGCanvas", @"WeSVGRenderer"] containsObject:NSStringFromClass(cls)];
}
static void SaoqiangWCAssetsBindSVG(id result, NSString *name, NSData *raw, NSString *source) {
    if (!SaoqiangWCAssetsSafeRendererName(name) || !SaoqiangWCAssetsCanCapture()) return;
    if ([result isKindOfClass:UIImage.class]) {
        // 0.11.43: SVG results are rendered into a plain UIImage, so the CGImage
        // memo is the only thing a layer.contents icon can be matched against.
        SaoqiangWCAssetsRememberCGName(result, name);
        SaoqiangWCAssetsSourceScope *scope = (__bridge id)SaoqiangWCAssetsCurrentSourceScope;
        BOOL bubble = scope.candidateBubble && SaoqiangWCAssetsSameResourceName(scope.name, name);
        if (raw || bubble) SaoqiangWCAssetsAssociateSourceImage(result, name, raw, source, bubble);
        else SaoqiangWCAssetsAssociateRenderedSVG(result, name, source, nil);
    } else if (SaoqiangWCAssetsSVGWrapper(result)) {
        @synchronized (result) {
            id old = objc_getAssociatedObject(result, &SaoqiangWCAssetsSVGObjectInfoKey);
            if (old == NSNull.null) return;
            SaoqiangWCAssetsImageInfo *info = old;
            if (info && !SaoqiangWCAssetsSameResourceName(info.SaoqiangWCAssetsName, name)) {
                objc_setAssociatedObject(result, &SaoqiangWCAssetsSVGObjectInfoKey, NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return;
            }
            if (!info) { info = [SaoqiangWCAssetsImageInfo new]; info.SaoqiangWCAssetsName = name; info.SaoqiangWCAssetsSource = source; }
            info.SaoqiangWCAssetsSVG = YES; if (raw) info.SaoqiangWCAssetsRawSVG = raw;
            objc_setAssociatedObject(result, &SaoqiangWCAssetsSVGObjectInfoKey, info, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}
static id SaoqiangWCAssetsCallNamedSVG(NSString *name, NSString *source, NSData *input, id (^invoke)(void)) {
    if (!SaoqiangWCAssetsMasterEnabled() || !SaoqiangWCAssetsIconCaptureActive()) return invoke();
    SaoqiangWCAssetsSVGScope *parent = (__bridge id)SaoqiangWCAssetsCurrentSVGScope;
    SaoqiangWCAssetsSVGScope *scope = SaoqiangWCAssetsOpenSVGScope(name);
    if (scope.name) SaoqiangWCAssetsOfferSVG(scope, name, input);
    void *previous = SaoqiangWCAssetsCurrentSVGScope;
    SaoqiangWCAssetsCurrentSVGScope = (__bridge void *)scope; ++SaoqiangWCAssetsSVGScopeDepth; ++SaoqiangWCAssetsHookDepth;
    id result = nil;
    @try { result = invoke(); }
    @finally { --SaoqiangWCAssetsHookDepth; --SaoqiangWCAssetsSVGScopeDepth; SaoqiangWCAssetsCurrentSVGScope = previous; }
    if (scope.name) {
        if (scope.conflicted && SaoqiangWCAssetsRequestMatchesFile(parent.name, scope.name)) { parent.raw = nil; parent.conflicted = YES; }
        else SaoqiangWCAssetsOfferSVG(parent, scope.name, scope.raw);
        SaoqiangWCAssetsBindSVG(result, scope.name, scope.raw, source);
    }
    return result;
}
// ===== 0.11.43：微信自家图标的主入口是 MMThemeManager，不是 UIKit =====
// Reference review (WeChatUIGrabber): WeChat does not load its toolbar / list /
// settings icons through +[UIImage imageNamed:]. Every one of them is served by
// the theme manager, whose two name-bearing routes are
//   -[MMThemeManager imageNamed:]                                           (raster)
//   -[MMThemeManager svgImageNamed:size:color:alpha:angle:ignoreNotFound:]  (SVG)
// Hooking only UIKit left those loads completely anonymous, so the page sampler
// had nothing to attach and every row fell back to「无原始资源名」. Both routes
// are observe-and-forward: the argument is the resource name, the return value
// is the exact object that later lands in a UIImageView or button.
static IMP SaoqiangWCAssetsOriginalThemeNamed;
static IMP SaoqiangWCAssetsOriginalThemeSVG;
static NSString * const SaoqiangWCAssetsThemeNamedSource = @"运行时 MMThemeManager imageNamed:";
static NSString * const SaoqiangWCAssetsThemeSVGSource = @"运行时 MMThemeManager svgImageNamed:…:ignoreNotFound:";
static UIImage *SaoqiangWCAssetsThemeNamed(id receiver, SEL cmd, NSString *name) {
    UIImage *(*original)(id, SEL, NSString *) = (UIImage *(*)(id, SEL, NSString *))SaoqiangWCAssetsOriginalThemeNamed;
    if (!original) return nil;
    if (!SaoqiangWCAssetsMasterEnabled()) return original(receiver, cmd, name);
    if (!SaoqiangWCAssetsIconCaptureActive()) return SaoqiangWCAssetsMemoized(original(receiver, cmd, name), name);
    UIImage *image = SaoqiangWCAssetsNamedRoute(SaoqiangWCAssetsSafeRendererName(name) ? name : @"", name,
        SaoqiangWCAssetsThemeNamedSource, nil, NO, ^UIImage *(void) {
            return original(receiver, cmd, name);
        });
    // Remember the name even when the record whitelist rejects it: a displayed
    // page icon with a real, checkable name beats another empty row.
    SaoqiangWCAssetsRememberCGName(image, name);
    return image;
}
static id SaoqiangWCAssetsThemeSVG(id receiver, SEL cmd, id name, CGSize size, id color, double alpha, int angle, BOOL ignoreNotFound) {
    id (*original)(id, SEL, id, CGSize, id, double, int, BOOL) = (id (*)(id, SEL, id, CGSize, id, double, int, BOOL))SaoqiangWCAssetsOriginalThemeSVG;
    if (!original) return nil;
    if (![name isKindOfClass:NSString.class] || !SaoqiangWCAssetsSafeRendererName(name))
        return original(receiver, cmd, name, size, color, alpha, angle, ignoreNotFound);
    if (!SaoqiangWCAssetsMasterEnabled()) return original(receiver, cmd, name, size, color, alpha, angle, ignoreNotFound);
    if (!SaoqiangWCAssetsIconCaptureActive()) {
        id image = original(receiver, cmd, name, size, color, alpha, angle, ignoreNotFound);
        if ([image isKindOfClass:UIImage.class]) SaoqiangWCAssetsRememberCGName(image, name);
        return image;
    }
    return SaoqiangWCAssetsCallNamedSVG(name, SaoqiangWCAssetsThemeSVGSource, nil, ^id {
        return original(receiver, cmd, name, size, color, alpha, angle, ignoreNotFound);
    });
}
// Only an exact, locally-owned method with the reviewed ABI is replaced. An
// inherited method is never mutated, and a signature mismatch leaves it alone.
static void SaoqiangWCAssetsInstallThemeRoute(Class cls, SEL sel, IMP replacement, IMP *original, BOOL svg) {
    if (!cls || !sel) return;
    Method m = class_getInstanceMethod(cls, sel); if (!m) return;
    NSMethodSignature *s = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)];
    BOOL valid = svg ? (s.numberOfArguments == 8 && SaoqiangWCAssetsObjectType(s.methodReturnType) &&
                        !strcmp([s getArgumentTypeAtIndex:2], "@") &&
                        !strcmp([s getArgumentTypeAtIndex:3], @encode(CGSize)) &&
                        !strcmp([s getArgumentTypeAtIndex:4], "@"))
                     : SaoqiangWCAssetsObjectsSignature(s, 3);
    if (!valid) return;
    SaoqiangWCAssetsReplace(cls, sel, replacement, original);
}
static void SaoqiangWCAssetsInstallThemeManagerHooks(void) {
    static BOOL installed;
    if (installed) return;
    // The class only exists inside the WeChat binary; retry on the next call
    // instead of latching a failed attempt for the whole process lifetime.
    Class cls = NSClassFromString(@"MMThemeManager");
    if (!SaoqiangWCAssetsHostClass(cls)) return;
    SaoqiangWCAssetsInstallThemeRoute(cls, @selector(imageNamed:), (IMP)SaoqiangWCAssetsThemeNamed, &SaoqiangWCAssetsOriginalThemeNamed, NO);
    SaoqiangWCAssetsInstallThemeRoute(cls, NSSelectorFromString(@"svgImageNamed:size:color:alpha:angle:ignoreNotFound:"),
        (IMP)SaoqiangWCAssetsThemeSVG, &SaoqiangWCAssetsOriginalThemeSVG, YES);
    installed = YES;
}
static void SaoqiangWCAssetsDiscoverRawSVG(void) {
    Class cls = NSClassFromString(@"WCSVGImage"); if (!SaoqiangWCAssetsHostClass(cls)) return;
    Class meta = object_getClass(cls);
    for (NSString *name in @[@"adaptedWeSVGImageWithName:data:config:", @"svgDataWithName:"]) {
        SEL sel = NSSelectorFromString(name); Method m = class_getInstanceMethod(meta,sel); if (!m) continue;
        NSString *key = [@"+[WCSVGImage " stringByAppendingFormat:@"%@]",name];
        NSMethodSignature *s = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)];
        BOOL installed = [SaoqiangWCAssetsInstalled containsObject:key];
        BOOL valid = SaoqiangWCAssetsObjectsSignature(s,[name isEqual:@"svgDataWithName:"] ? 3 : 5) && (installed || SaoqiangWCAssetsHostMethod(m));
        if (valid && !installed) {
            IMP old = method_getImplementation(m); id block;
            if ([name isEqual:@"svgDataWithName:"]) block = ^id(id receiver, id resourceName) {
                id result = ((id (*)(id,SEL,id))old)(receiver,sel,resourceName);
                if (SaoqiangWCAssetsCanCapture() && SaoqiangWCAssetsSafeRendererName(resourceName)) {
                    NSData *raw = SaoqiangWCAssetsRawSVG(result);
                    SaoqiangWCAssetsSVGScope *scope = (__bridge id)SaoqiangWCAssetsCurrentSVGScope;
                    // A data-only lookup never claims that anything was rendered.
                    SaoqiangWCAssetsOfferSVG(scope, resourceName, raw);
                } return result;
            };
            else block = ^id(id receiver, id resourceName, id data, id config) {
                return SaoqiangWCAssetsCallNamedSVG(resourceName, key, SaoqiangWCAssetsCanCapture() ? SaoqiangWCAssetsRawSVG(data) : nil, ^id{
                    return ((id (*)(id,SEL,id,id,id))old)(receiver,sel,resourceName,data,config);
                });
            };
            IMP ignored; SaoqiangWCAssetsReplace(meta,sel,imp_implementationWithBlock(block),&ignored); [SaoqiangWCAssetsInstalled addObject:key];
        }
        [SaoqiangWCAssetsDiagnostics addObject:@{@"owner":key,@"encoding":@(method_getTypeEncoding(m)),@"status":valid ? @"installed" : @"skipped ABI/origin mismatch"}];
    }
}
static void SaoqiangWCAssetsDiscoverSVGGetters(void) {
    // Binary evidence: WCSVGImage has mainCanvas, NOT image. We only observe
    // getters when the host calls them; never send guessed private selectors.
    for (NSArray<NSString *> *row in @[@[@"WCSVGImage", @"mainCanvas"], @[@"WCSVGCanvas", @"image"], @[@"WeSVGRenderer", @"renderImage"]]) {
        Class cls = NSClassFromString(row[0]); SEL sel = NSSelectorFromString(row[1]);
        Method method = cls ? class_getInstanceMethod(cls, sel) : NULL;
        NSString *key = [NSString stringWithFormat:@"-[%@ %@]", row[0], row[1]];
        BOOL installed = [SaoqiangWCAssetsInstalled containsObject:key];
        BOOL valid = SaoqiangWCAssetsHostClass(cls) && method && SaoqiangWCAssetsObjectsSignature([NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)], 2) && (installed || SaoqiangWCAssetsHostMethod(method));
        if (valid && !installed) {
            IMP old = method_getImplementation(method);
            id block = ^id(id receiver) {
                id out = ((id (*)(id,SEL))old)(receiver,sel);
                id value = objc_getAssociatedObject(receiver, &SaoqiangWCAssetsSVGObjectInfoKey);
                if ([value isKindOfClass:SaoqiangWCAssetsImageInfo.class]) {
                    SaoqiangWCAssetsImageInfo *info = value;
                    SaoqiangWCAssetsBindSVG(out, info.SaoqiangWCAssetsName, info.SaoqiangWCAssetsRawSVG, key);
                }
                return out;
            };
            IMP ignored; SaoqiangWCAssetsReplace(cls, sel, imp_implementationWithBlock(block), &ignored); [SaoqiangWCAssetsInstalled addObject:key];
        }
        [SaoqiangWCAssetsDiagnostics addObject:@{@"owner":key, @"encoding":method ? @(method_getTypeEncoding(method)) : @"missing", @"status":valid ? @"installed; observed getters only" : @"unavailable/ABI/origin mismatch"}];
    }
}
static BOOL SaoqiangWCAssetsSVGSignature(NSMethodSignature *s) {
    return s && s.numberOfArguments == 6 && SaoqiangWCAssetsObjectType(s.methodReturnType)
        && !strcmp([s getArgumentTypeAtIndex:0], "@") && !strcmp([s getArgumentTypeAtIndex:1], ":")
        && SaoqiangWCAssetsObjectType([s getArgumentTypeAtIndex:2]) && !strcmp([s getArgumentTypeAtIndex:3], @encode(CGSize))
        && SaoqiangWCAssetsObjectType([s getArgumentTypeAtIndex:4]) && !strcmp([s getArgumentTypeAtIndex:5], @encode(CGFloat));
}
static void SaoqiangWCAssetsDiscoverNamedSVG(void) {
    Class cls = NSClassFromString(@"WCSVGImage"); if (!SaoqiangWCAssetsHostClass(cls)) return;
    Class meta = object_getClass(cls);
    for (NSString *name in @[@"imageNamed:", @"imageNamed:fromConfig:", @"imageNamed:size:color:alpha:rotate:"]) {
        SEL sel = NSSelectorFromString(name); Method m = class_getInstanceMethod(meta, sel);
        NSString *key = [NSString stringWithFormat:@"+[WCSVGImage %@]", name];
        NSMethodSignature *s = m ? [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)] : nil;
        BOOL sized = [name isEqual:@"imageNamed:size:color:alpha:rotate:"];
        BOOL valid = sized ? (s.numberOfArguments == 7 && SaoqiangWCAssetsObjectType(s.methodReturnType) && !strcmp([s getArgumentTypeAtIndex:0], "@") && !strcmp([s getArgumentTypeAtIndex:1], ":") && SaoqiangWCAssetsObjectType([s getArgumentTypeAtIndex:2]) && !strcmp([s getArgumentTypeAtIndex:3], @encode(CGSize)) && SaoqiangWCAssetsObjectType([s getArgumentTypeAtIndex:4]) && !strcmp([s getArgumentTypeAtIndex:5], @encode(CGFloat)) && !strcmp([s getArgumentTypeAtIndex:6], @encode(CGFloat))) : SaoqiangWCAssetsObjectsSignature(s, [name isEqual:@"imageNamed:"] ? 3 : 4);
        BOOL installed = [SaoqiangWCAssetsInstalled containsObject:key]; valid = valid && (installed || SaoqiangWCAssetsHostMethod(m));
        if (valid && !installed) {
            IMP old = method_getImplementation(m); id block;
            if (sized) block = ^id(id receiver, id resource, CGSize size, id color, CGFloat alpha, CGFloat angle) {
                return SaoqiangWCAssetsCallNamedSVG(resource, key, nil, ^id{ return ((id (*)(id,SEL,id,CGSize,id,CGFloat,CGFloat))old)(receiver,sel,resource,size,color,alpha,angle); });
            };
            else if ([name isEqual:@"imageNamed:"]) block = ^id(id receiver, id resource) {
                return SaoqiangWCAssetsCallNamedSVG(resource, key, nil, ^id{ return ((id (*)(id,SEL,id))old)(receiver,sel,resource); });
            };
            else block = ^id(id receiver, id resource, id config) {
                return SaoqiangWCAssetsCallNamedSVG(resource, key, nil, ^id{ return ((id (*)(id,SEL,id,id))old)(receiver,sel,resource,config); });
            };
            IMP ignored; SaoqiangWCAssetsReplace(meta, sel, imp_implementationWithBlock(block), &ignored); [SaoqiangWCAssetsInstalled addObject:key];
        }
        [SaoqiangWCAssetsDiagnostics addObject:@{@"owner":key, @"status":valid ? @"installed" : @"unavailable/ABI/origin mismatch"}];
    }
}
void SaoqiangWCAssetsDiscoverSVG(void) {
    NSCAssert(NSThread.isMainThread, @"SVG discovery on main thread");
    if (!SaoqiangWCAssetsInstalled) SaoqiangWCAssetsInstalled = [NSMutableSet new];
    SaoqiangWCAssetsDiagnostics = [NSMutableArray new]; SaoqiangWCAssetsDiscoverRawSVG(); SaoqiangWCAssetsDiscoverNamedSVG(); SaoqiangWCAssetsDiscoverSVGGetters();
    // The theme manager is the route WeChat actually uses for its own icons;
    // install it here as well because the class may only be visible now.
    SaoqiangWCAssetsInstallThemeManagerHooks();
    // 0.11.44: the sweep below walks every class in the process (~40k in WeChat)
    // and used to run at launch, on didFinishLaunching and on every return to
    // the foreground. New classes can only appear when dyld maps another image,
    // so the image count is a complete and free "did anything change" test.
    static uint32_t scanned;
    uint32_t images = _dyld_image_count();
    if (scanned && scanned == images) return;
    scanned = images;
    unsigned count = 0; Class *classes = objc_copyClassList(&count);
    for (unsigned i=0;i<count;i++) {
        Class owner = classes[i]; const char *imageName = class_getImageName(owner);
        if (owner != UIImage.class && !SaoqiangWCAssetsHostImage(imageName)) continue;
        for (unsigned side=0;side<2;side++) {
            Class target = side ? object_getClass(owner) : owner; unsigned n=0; Method *methods=class_copyMethodList(target,&n);
            for (unsigned j=0;j<n;j++) {
                Method m=methods[j]; SEL sel=method_getName(m);
                // Compare C strings: building an NSString per method in the
                // sweep was a per-launch allocation storm.
                const char *selName=sel_getName(sel);
                if (strcmp(selName,"svgImageNamed:size:color:alpha:") && strcmp(selName,"svgImageNamed:size:color:angle:")) continue;
                NSString *selector=@(selName);
                NSString *key=[NSString stringWithFormat:@"%c[%@ %@]",side?'+':'-',NSStringFromClass(owner),selector];
                const char *types=method_getTypeEncoding(m); NSMethodSignature *signature=types?[NSMethodSignature signatureWithObjCTypes:types]:nil;
                BOOL installed=[SaoqiangWCAssetsInstalled containsObject:key]; BOOL matches=SaoqiangWCAssetsSVGSignature(signature)&&(installed||SaoqiangWCAssetsHostMethod(m));
                if (matches&&!installed) {
                    IMP original=method_getImplementation(m);
                    id block=^id(id receiver,id name,CGSize size,id color,CGFloat scalar) {
                        return SaoqiangWCAssetsCallNamedSVG(name, key, nil, ^id{
                            return ((id (*)(id,SEL,id,CGSize,id,CGFloat))original)(receiver,sel,name,size,color,scalar);
                        });
                    };
                    method_setImplementation(m,imp_implementationWithBlock(block)); [SaoqiangWCAssetsInstalled addObject:key];
                }
                [SaoqiangWCAssetsDiagnostics addObject:@{@"owner":key,@"encoding":types?@(types):@"",@"status":matches?@"installed":@"skipped ABI/origin mismatch"}];
            } free(methods);
        }
    } free(classes);
}
NSString *SaoqiangWCAssetsSVGDiagnostics(void) {
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:SaoqiangWCAssetsDiagnostics?:@[] options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding]?:@"[]";
}
static UIImage *(*SaoqiangWCAssetsOriginalData)(id,SEL,NSData *);
static UIImage *(*SaoqiangWCAssetsOriginalDataScale)(id,SEL,NSData *,CGFloat);
// These are Objective-C init-family IMPs: self is consumed, result is retained.
typedef UIImage *(*SaoqiangWCAssetsInitDataIMP)(__attribute__((ns_consumed)) id,SEL,NSData *) __attribute__((ns_returns_retained));
typedef UIImage *(*SaoqiangWCAssetsInitDataScaleIMP)(__attribute__((ns_consumed)) id,SEL,NSData *,CGFloat) __attribute__((ns_returns_retained));
typedef UIImage *(*SaoqiangWCAssetsInitFileIMP)(__attribute__((ns_consumed)) id,SEL,NSString *) __attribute__((ns_returns_retained));
static SaoqiangWCAssetsInitDataIMP SaoqiangWCAssetsOriginalInitData;
static SaoqiangWCAssetsInitDataScaleIMP SaoqiangWCAssetsOriginalInitDataScale;
static SaoqiangWCAssetsInitFileIMP SaoqiangWCAssetsOriginalInitFile;
// Decoders all shape the same function: forward, then (only while capturing)
// attach the byte stream so a later name can be proven against it.
static UIImage *SaoqiangWCAssetsDecoded(UIImage *image, NSData *data) {
    if (SaoqiangWCAssetsCanCapture()) SaoqiangWCAssetsAssociateDecodedImage(image, data);
    return image;
}
static BOOL SaoqiangWCAssetsDecodeIdle(void) { return !SaoqiangWCAssetsMasterEnabled() || !SaoqiangWCAssetsIconCaptureActive(); }
static UIImage *SaoqiangWCAssetsData(id receiver,SEL cmd,NSData *data) {
    if (SaoqiangWCAssetsDecodeIdle()) return SaoqiangWCAssetsOriginalData(receiver,cmd,data);
    return SaoqiangWCAssetsDecoded(SaoqiangWCAssetsOriginalData(receiver,cmd,data),data);
}
static UIImage *SaoqiangWCAssetsDataScale(id receiver,SEL cmd,NSData *data,CGFloat scale) {
    if (SaoqiangWCAssetsDecodeIdle()) return SaoqiangWCAssetsOriginalDataScale(receiver,cmd,data,scale);
    return SaoqiangWCAssetsDecoded(SaoqiangWCAssetsOriginalDataScale(receiver,cmd,data,scale),data);
}
static UIImage *SaoqiangWCAssetsInitData(__attribute__((ns_consumed)) id receiver,SEL cmd,NSData *data) __attribute__((ns_returns_retained));
static UIImage *SaoqiangWCAssetsInitData(__attribute__((ns_consumed)) id receiver,SEL cmd,NSData *data) {
    if (SaoqiangWCAssetsDecodeIdle()) return SaoqiangWCAssetsOriginalInitData(receiver,cmd,data);
    return SaoqiangWCAssetsDecoded(SaoqiangWCAssetsOriginalInitData(receiver,cmd,data),data);
}
static UIImage *SaoqiangWCAssetsInitDataScale(__attribute__((ns_consumed)) id receiver,SEL cmd,NSData *data,CGFloat scale) __attribute__((ns_returns_retained));
static UIImage *SaoqiangWCAssetsInitDataScale(__attribute__((ns_consumed)) id receiver,SEL cmd,NSData *data,CGFloat scale) {
    if (SaoqiangWCAssetsDecodeIdle()) return SaoqiangWCAssetsOriginalInitDataScale(receiver,cmd,data,scale);
    return SaoqiangWCAssetsDecoded(SaoqiangWCAssetsOriginalInitDataScale(receiver,cmd,data,scale),data);
}
static UIImage *SaoqiangWCAssetsInitFile(__attribute__((ns_consumed)) id receiver,SEL cmd,NSString *path) __attribute__((ns_returns_retained));
static UIImage *SaoqiangWCAssetsInitFile(__attribute__((ns_consumed)) id receiver,SEL cmd,NSString *path) {
    if (!SaoqiangWCAssetsMasterEnabled() || !SaoqiangWCAssetsIconCaptureActive()) return SaoqiangWCAssetsOriginalInitFile(receiver,cmd,path);
    UIImage *result=SaoqiangWCAssetsOriginalInitFile(receiver,cmd,path);
    if (SaoqiangWCAssetsCanCapture()) {
        SaoqiangWCAssetsAssociateFilePath(result,path);
        if (SaoqiangWCAssetsBubbleName(path)) SaoqiangWCAssetsAssociateBubbleCandidate(result,path.lastPathComponent);
        SaoqiangWCAssetsCapture(result,path.lastPathComponent,@"UIImage initWithContentsOfFile:",path,NO);
        SaoqiangWCAssetsRememberBacking(result);
    } return result;
}

static void SaoqiangWCAssetsInstallHooks(void) {
    Class meta=object_getClass(UIImage.class);
    SaoqiangWCAssetsReplace(meta,@selector(imageNamed:),(IMP)SaoqiangWCAssetsNamed,(IMP *)&SaoqiangWCAssetsOriginalNamed);
    SaoqiangWCAssetsReplace(meta,@selector(imageNamed:inBundle:compatibleWithTraitCollection:),(IMP)SaoqiangWCAssetsBundle,(IMP *)&SaoqiangWCAssetsOriginalBundle);
    SaoqiangWCAssetsReplace(meta,@selector(imageWithContentsOfFile:),(IMP)SaoqiangWCAssetsFile,(IMP *)&SaoqiangWCAssetsOriginalFile);
    SaoqiangWCAssetsReplace(meta,@selector(imageWithData:),(IMP)SaoqiangWCAssetsData,(IMP *)&SaoqiangWCAssetsOriginalData);
    SaoqiangWCAssetsReplace(meta,@selector(imageWithData:scale:),(IMP)SaoqiangWCAssetsDataScale,(IMP *)&SaoqiangWCAssetsOriginalDataScale);
    SaoqiangWCAssetsReplace(UIImage.class,@selector(initWithData:),(IMP)SaoqiangWCAssetsInitData,(IMP *)&SaoqiangWCAssetsOriginalInitData);
    SaoqiangWCAssetsReplace(UIImage.class,@selector(initWithData:scale:),(IMP)SaoqiangWCAssetsInitDataScale,(IMP *)&SaoqiangWCAssetsOriginalInitDataScale);
    SaoqiangWCAssetsReplace(UIImage.class,@selector(initWithContentsOfFile:),(IMP)SaoqiangWCAssetsInitFile,(IMP *)&SaoqiangWCAssetsOriginalInitFile);
    // WeChat's own theme loader. Installed here so the memo starts filling at
    // process start, long before the user opens the panel and taps 开始抓取.
    SaoqiangWCAssetsInstallThemeManagerHooks();
    for (NSString *name in @[@"resizableImageWithCapInsets:",@"resizableImageWithCapInsets:resizingMode:",@"stretchableImageWithLeftCapWidth:topCapHeight:",@"imageWithRenderingMode:"]) {
        SEL sel=NSSelectorFromString(name); Method m=class_getInstanceMethod(UIImage.class,sel); if (!m) continue;
        IMP original=method_getImplementation(m); id block;
        void (^capture)(UIImage *,UIImage *)=^(UIImage *input,UIImage *output) {
            if (SaoqiangWCAssetsCanCapture()) SaoqiangWCAssetsPropagateImageInfo(input,output,name);
        };
        if ([name isEqual:@"resizableImageWithCapInsets:"]) block=^UIImage *(UIImage *image,UIEdgeInsets insets) { UIImage *out=((UIImage *(*)(id,SEL,UIEdgeInsets))original)(image,sel,insets); capture(image,out); return out; };
        else if ([name isEqual:@"resizableImageWithCapInsets:resizingMode:"]) block=^UIImage *(UIImage *image,UIEdgeInsets insets,UIImageResizingMode mode) { UIImage *out=((UIImage *(*)(id,SEL,UIEdgeInsets,UIImageResizingMode))original)(image,sel,insets,mode); capture(image,out); return out; };
        else if ([name isEqual:@"imageWithRenderingMode:"]) block=^UIImage *(UIImage *image,UIImageRenderingMode mode) { UIImage *out=((UIImage *(*)(id,SEL,UIImageRenderingMode))original)(image,sel,mode); capture(image,out); return out; };
        else block=^UIImage *(UIImage *image,NSInteger left,NSInteger top) { UIImage *out=((UIImage *(*)(id,SEL,NSInteger,NSInteger))original)(image,sel,left,top); capture(image,out); return out; };
        IMP ignored; SaoqiangWCAssetsReplace(UIImage.class,sel,imp_implementationWithBlock(block),&ignored);
    }
}
void SaoqiangWCAssetsInstallImageHooks(void) {
    static dispatch_once_t once;
    dispatch_once(&once,^{ SaoqiangWCAssetsMasterLoad(); SaoqiangWCAssetsInstallHooks(); });
}
__attribute__((constructor)) static void SaoqiangWCAssetsInitialize(void) {
    @autoreleasepool {
        if (![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleExecutable"] isEqualToString:@"WeChat"]) return;
        SaoqiangWCAssetsInstallImageHooks();
        dispatch_async(dispatch_get_main_queue(), ^{
            SaoqiangWCAssetsStore *s=[SaoqiangWCAssetsStore SaoqiangWCAssetsShared];
            [s SaoqiangWCAssetsSetAppActive:UIApplication.sharedApplication.applicationState==UIApplicationStateActive];
            // 0.11.44: only cheap class lookups run in this turn. The one full
            // process-wide class sweep is deferred into its own runloop turn so
            // the host's first frame is never behind it.
            SaoqiangWCAssetsDiscoverTheme(); SaoqiangWCAssetsDiscoverBubbles();
            SaoqiangWCAssetsInstallPageCapture(); SaoqiangWCAssetsInstallUI();
            dispatch_async(dispatch_get_main_queue(), ^{ SaoqiangWCAssetsDiscoverSVG(); });
            [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) {
                // Defer beyond private plugins' launch observers / initialization.
                dispatch_async(dispatch_get_main_queue(), ^{
                    [s SaoqiangWCAssetsSetAppActive:UIApplication.sharedApplication.applicationState == UIApplicationStateActive];
                    SaoqiangWCAssetsDiscoverTheme(); SaoqiangWCAssetsDiscoverSVG(); SaoqiangWCAssetsDiscoverBubbles();
                });
            }];
            [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) {
                [s SaoqiangWCAssetsSetAppActive:YES];
                dispatch_async(dispatch_get_main_queue(), ^{ SaoqiangWCAssetsDiscoverTheme(); SaoqiangWCAssetsDiscoverSVG(); SaoqiangWCAssetsDiscoverBubbles(); });
            }];
            [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { [s SaoqiangWCAssetsSetAppActive:NO]; }];
        });
    }
}
