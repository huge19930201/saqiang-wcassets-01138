#import "SaoqiangWCAssets.h"
#import "SaoqiangWCAssetsInspector.h"
#import "SaoqiangWCAssetsTheme.h"
#import "SaoqiangWCAssetsNames.h"
#import <objc/runtime.h>
#import <os/lock.h>
#import <string.h>
#import <ctype.h>
static char SaoqiangWCAssetsImageInfoKey, SaoqiangWCAssetsOwnViewKey, SaoqiangWCAssetsBubbleCandidateKey;
@interface SaoqiangWCAssetsSVGBytes : NSObject
@property(nonatomic, copy) NSData *data;
@end
@implementation SaoqiangWCAssetsSVGBytes
@end
@interface SaoqiangWCAssetsImageInfo ()
@property(nonatomic, weak) SaoqiangWCAssetsSVGBytes *SaoqiangWCAssetsBytesEntry;
@property(nonatomic) BOOL SaoqiangWCAssetsNamedRenderer;
@property(nonatomic, readwrite) NSUInteger SaoqiangWCAssetsRevision;
@property(nonatomic) BOOL SaoqiangWCAssetsNameAmbiguous;
@end
static NSMutableArray<SaoqiangWCAssetsSVGBytes *> *SaoqiangWCAssetsRawEntries;
static NSUInteger SaoqiangWCAssetsRawTotal;
static NSMapTable<UIImage *, SaoqiangWCAssetsImageInfo *> *SaoqiangWCAssetsKnownImages;
static NSObject *SaoqiangWCAssetsAssociationLock(void) {
    static NSObject *lock; static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [NSObject new]; }); return lock;
}
@implementation SaoqiangWCAssetsImageInfo
- (NSData *)SaoqiangWCAssetsRawSVG {
    @synchronized (SaoqiangWCAssetsAssociationLock()) { return self.SaoqiangWCAssetsBytesEntry.data; }
}
- (NSData *)SaoqiangWCAssetsRawSourceData { return self.SaoqiangWCAssetsRawSVG; }
- (void)setSaoqiangWCAssetsRawSourceData:(NSData *)data { self.SaoqiangWCAssetsRawSVG = data; }
- (void)setSaoqiangWCAssetsRawSVG:(NSData *)data {
    if (data && (![data isKindOfClass:NSData.class] || !data.length || data.length > 2 * 1024 * 1024)) return;
    @synchronized (SaoqiangWCAssetsAssociationLock()) {
        NSData *old = self.SaoqiangWCAssetsBytesEntry.data;
        if (old == data || [old isEqualToData:data]) return;
        // A newly observed source must be allowed through Store's seen-image gate.
        self.SaoqiangWCAssetsIdentity = nil; ++self.SaoqiangWCAssetsRevision;
        self.SaoqiangWCAssetsBytesEntry = nil;
        if (!data) return;
        if (!SaoqiangWCAssetsRawEntries) SaoqiangWCAssetsRawEntries = [NSMutableArray new];
        // Sharing is by the actual NSData object, never by resource name.
        for (SaoqiangWCAssetsSVGBytes *entry in SaoqiangWCAssetsRawEntries) {
            if (entry.data == data) { self.SaoqiangWCAssetsBytesEntry = entry; return; }
        }
        while (SaoqiangWCAssetsRawEntries.count && (SaoqiangWCAssetsRawEntries.count >= 64 || SaoqiangWCAssetsRawTotal + data.length > 8 * 1024 * 1024)) {
            SaoqiangWCAssetsRawTotal -= SaoqiangWCAssetsRawEntries.firstObject.data.length;
            [SaoqiangWCAssetsRawEntries removeObjectAtIndex:0];
        }
        SaoqiangWCAssetsSVGBytes *entry = [SaoqiangWCAssetsSVGBytes new]; entry.data = data;
        [SaoqiangWCAssetsRawEntries addObject:entry]; SaoqiangWCAssetsRawTotal += entry.data.length;
        self.SaoqiangWCAssetsBytesEntry = entry;
    }
}
@end
BOOL SaoqiangWCAssetsSameResourceName(NSString *a, NSString *b) {
    if (![a isKindOfClass:NSString.class] || ![b isKindOfClass:NSString.class]) return NO;
    if ([a isEqualToString:b]) return YES;
    BOOL aext = [@[@"svg",@"png",@"jpg",@"jpeg"] containsObject:a.pathExtension.lowercaseString];
    BOOL bext = [@[@"svg",@"png",@"jpg",@"jpeg"] containsObject:b.pathExtension.lowercaseString];
    if (aext && !b.pathExtension.length) return [a.stringByDeletingPathExtension isEqualToString:b];
    if (bext && !a.pathExtension.length) return [b.stringByDeletingPathExtension isEqualToString:a];
    return NO;
}
static BOOL SaoqiangWCAssetsHasName(NSString *name) { return name.length && ![name isEqual:@"无原始资源名"] && ![name containsString:@"无原名"]; }
static NSString *SaoqiangWCAssetsUnscaledStem(NSString *name) {
    NSString *base=name;
    if ([@[@"png",@"svg",@"jpg",@"jpeg"] containsObject:name.pathExtension.lowercaseString]) base=name.stringByDeletingPathExtension;
    if ([base hasSuffix:@"@2x"] || [base hasSuffix:@"@3x"] || [base hasSuffix:@"@1x"]) base=[base substringToIndex:base.length-3];
    return base;
}
BOOL SaoqiangWCAssetsRequestMatchesFile(NSString *request, NSString *actual) {
    if (![request isKindOfClass:NSString.class] || ![actual isKindOfClass:NSString.class]) return NO;
    if (SaoqiangWCAssetsSameResourceName(request,actual)) return YES;
    NSString *r=request, *a=actual;
    if (actual.isAbsolutePath && !request.isAbsolutePath) {
        // Require the full relative path suffix when the request includes directories.
        if ([request containsString:@"/"] && ![actual hasSuffix:[@"/" stringByAppendingString:request]]) return NO;
        a=actual.lastPathComponent; r=request.lastPathComponent;
    }
    if (request.isAbsolutePath != actual.isAbsolutePath && request.isAbsolutePath) return NO;
    if (![[r stringByDeletingLastPathComponent] isEqual:[a stringByDeletingLastPathComponent]]) return NO;
    if (SaoqiangWCAssetsSameResourceName(r,a)) return YES;
    NSString *rbase=r.pathExtension.length?r.stringByDeletingPathExtension:r;
    // An explicitly requested scale must not match a different actual scale.
    if ([rbase hasSuffix:@"@2x"] || [rbase hasSuffix:@"@3x"] || [rbase hasSuffix:@"@1x"]) return NO;
    if (r.pathExtension.length && ![r.pathExtension.lowercaseString isEqual:a.pathExtension.lowercaseString]) return NO;
    return [SaoqiangWCAssetsUnscaledStem(r) isEqual:SaoqiangWCAssetsUnscaledStem(a)];
}
static NSString *SaoqiangWCAssetsMergeName(NSString *current, NSString *incoming) {
    if (!SaoqiangWCAssetsHasName(current)) return incoming;
    if (!SaoqiangWCAssetsHasName(incoming)) return current;
    if ([current isEqual:incoming]) return current;
    if (SaoqiangWCAssetsSameResourceName(current,incoming)) return current.pathExtension.length ? current : incoming;
    if (SaoqiangWCAssetsRequestMatchesFile(current,incoming)) return incoming;
    if (SaoqiangWCAssetsRequestMatchesFile(incoming,current)) return current;
    return nil;
}
// Called for every hooked image name, so it must stay allocation-free; the
// decision cache makes the steady state a single lock plus one lookup.
static NSMutableDictionary *SaoqiangWCAssetsRendererNameCache;
static os_unfair_lock SaoqiangWCAssetsRendererNameLock = OS_UNFAIR_LOCK_INIT;
BOOL SaoqiangWCAssetsSafeRendererName(NSString *name) {
    if (![name isKindOfClass:NSString.class] || !name.length || name.length > 240 || name.isAbsolutePath) return NO;
    BOOL found = NO; BOOL cached = NO;
    os_unfair_lock_lock(&SaoqiangWCAssetsRendererNameLock);
    NSNumber *entry = SaoqiangWCAssetsRendererNameCache[name];
    os_unfair_lock_unlock(&SaoqiangWCAssetsRendererNameLock);
    if (entry) { found = YES; cached = entry.boolValue; }
    if (found) return cached;
    const char *utf8 = name.UTF8String; BOOL result = NO;
    if (utf8) {
        size_t length = strlen(utf8);
        if (length < SQNameCapacity && !SQNameContains(utf8, length, "..") &&
            !SQNameContains(utf8, length, ":") && !SQNameContains(utf8, length, "\\")) {
            BOOL control = NO;
            for (size_t i = 0; i < length; ++i) {
                unsigned char c = (unsigned char)utf8[i];
                if (c < 0x20 || c == 0x7f) { control = YES; break; }
            }
            if (!control) {
                char buffer[SQNameCapacity];
                SQNameLowerCopy(utf8, length, buffer);
                if (!SQNameExcluded(buffer, length)) {
                    // No extension at all is allowed; any extension must be renderable.
                    size_t componentLength = 0;
                    const char *component = SQNameLastComponent(buffer, length, &componentLength);
                    result = SQNameExtensionLength(component, componentLength) == 0 ||
                        SQNameHasImageExtension(component, componentLength);
                }
            }
        }
    }
    os_unfair_lock_lock(&SaoqiangWCAssetsRendererNameLock);
    if (!SaoqiangWCAssetsRendererNameCache) SaoqiangWCAssetsRendererNameCache = [NSMutableDictionary dictionaryWithCapacity:512];
    if (SaoqiangWCAssetsRendererNameCache.count >= 4096) [SaoqiangWCAssetsRendererNameCache removeAllObjects];
    SaoqiangWCAssetsRendererNameCache[name] = @(result);
    os_unfair_lock_unlock(&SaoqiangWCAssetsRendererNameLock);
    return result;
}
static BOOL SaoqiangWCAssetsTrustedPath(NSString *path) {
    if (!path.length) return YES;
    if (![path isKindOfClass:NSString.class] || !path.isAbsolutePath || path.length > 2048) return NO;
    if (SaoqiangWCAssetsIsActiveThemePath(path)) return YES;
    // Lexical boundary only on the hook thread. Store validates and reads off-main.
    NSString *root = [NSBundle.mainBundle.bundlePath.stringByStandardizingPath stringByAppendingString:@"/"];
    NSString *resolved = path.stringByStandardizingPath;
    if (![resolved hasPrefix:root]) return NO;
    NSArray<NSString *> *components = [[resolved substringFromIndex:root.length] pathComponents];
    for (NSString *part in components) if ([@[@"frameworks", @"plugins", @"flutter_assets", @"documents", @"library", @"caches"] containsObject:part.lowercaseString]) return NO;
    return YES;
}
static void SaoqiangWCAssetsRememberImage(UIImage *image, SaoqiangWCAssetsImageInfo *info) {
    objc_setAssociatedObject(image, &SaoqiangWCAssetsImageInfoKey, info, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @synchronized (SaoqiangWCAssetsAssociationLock()) {
        if (!SaoqiangWCAssetsKnownImages) SaoqiangWCAssetsKnownImages = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsStrongMemory];
        // No strong UIImage or record in metadata: clearing this bounded fallback
        // index does not affect direct associations on still-live UIImage objects.
        if (SaoqiangWCAssetsKnownImages.count >= 512) [SaoqiangWCAssetsKnownImages removeAllObjects];
        [SaoqiangWCAssetsKnownImages setObject:info forKey:image];
    }
}
static void SaoqiangWCAssetsMarkAmbiguous(SaoqiangWCAssetsImageInfo *info) {
    if (!info) return;
    BOOL changed=!info.SaoqiangWCAssetsNameAmbiguous || ![info.SaoqiangWCAssetsName isEqual:@"无原始资源名"];
    info.SaoqiangWCAssetsNameAmbiguous=YES; info.SaoqiangWCAssetsName=@"无原始资源名";
    info.SaoqiangWCAssetsSnapshotOnly=YES; info.SaoqiangWCAssetsPath=nil; info.SaoqiangWCAssetsRawSourceData=nil;
    if (changed) { info.SaoqiangWCAssetsIdentity=nil; ++info.SaoqiangWCAssetsRevision; }
}
static void SaoqiangWCAssetsAssociateName(UIImage *image, NSString *name, NSString *source, NSString *path, BOOL svg, BOOL renderer) {
    if (![image isKindOfClass:UIImage.class] || SaoqiangWCAssetsIsSuppressed() || SaoqiangWCAssetsIsOwnImage(image) || !(renderer?SaoqiangWCAssetsSafeRendererName(name):SaoqiangWCAssetsUIName(name))) return;
    // An exact observed file on this UIImage is allowed; there is no directory scan.
    if (path.length && !SaoqiangWCAssetsTrustedPath(path) && ![path isEqual:SaoqiangWCAssetsObservedFilePath(image)]) return;
    @synchronized(SaoqiangWCAssetsAssociationLock()) {
        id old=objc_getAssociatedObject(image,&SaoqiangWCAssetsImageInfoKey);
        SaoqiangWCAssetsImageInfo *info=[old isKindOfClass:SaoqiangWCAssetsImageInfo.class]?old:[SaoqiangWCAssetsImageInfo new];
        if (old==NSNull.null || info.SaoqiangWCAssetsNameAmbiguous) { SaoqiangWCAssetsMarkAmbiguous(info); SaoqiangWCAssetsRememberImage(image,info); return; }
        NSString *merged=SaoqiangWCAssetsMergeName(info.SaoqiangWCAssetsName,name);
        if (!merged) { SaoqiangWCAssetsMarkAmbiguous(info); SaoqiangWCAssetsRememberImage(image,info); return; }
        BOOL changed=![merged isEqual:info.SaoqiangWCAssetsName];
        if (path.length && ![path isEqual:info.SaoqiangWCAssetsPath]) {
            if (info.SaoqiangWCAssetsPath.length) { SaoqiangWCAssetsMarkAmbiguous(info); SaoqiangWCAssetsRememberImage(image,info); return; }
            info.SaoqiangWCAssetsPath=path; changed=YES;
        }
        if (svg && !info.SaoqiangWCAssetsSVG) changed=YES;
        info.SaoqiangWCAssetsName=merged; info.SaoqiangWCAssetsSource=source;
        info.SaoqiangWCAssetsSnapshotOnly=NO; info.SaoqiangWCAssetsSVG|=svg; info.SaoqiangWCAssetsNamedRenderer|=renderer;
        info.SaoqiangWCAssetsCapInsets=image.capInsets; info.SaoqiangWCAssetsResizingMode=image.resizingMode;
        if (changed) { info.SaoqiangWCAssetsIdentity=nil; ++info.SaoqiangWCAssetsRevision; }
        SaoqiangWCAssetsRememberImage(image,info);
    }
    SaoqiangWCAssetsRememberBacking(image);
}
void SaoqiangWCAssetsAssociateNamedImage(UIImage *image, NSString *name, NSString *source, NSString *path, BOOL svg) {
    SaoqiangWCAssetsAssociateName(image, name, source, path, svg, NO);
}
void SaoqiangWCAssetsAssociateRenderedSVG(UIImage *image, NSString *name, NSString *source, NSData *raw) {
    SaoqiangWCAssetsAssociateName(image, name, source, nil, YES, YES);
    @synchronized (SaoqiangWCAssetsAssociationLock()) {
        SaoqiangWCAssetsImageInfo *info = SaoqiangWCAssetsImageInfoForImage(image);
        if (raw && info && SaoqiangWCAssetsSameResourceName(info.SaoqiangWCAssetsName, name)) info.SaoqiangWCAssetsRawSVG = raw;
    }
}
static char SaoqiangWCAssetsCandidateSourceKey;
void SaoqiangWCAssetsAssociateSourceImage(UIImage *image, NSString *name, NSData *data, NSString *source, BOOL candidateBubble) {
    if (![image isKindOfClass:UIImage.class] || !SaoqiangWCAssetsSafeRendererName(name) || SaoqiangWCAssetsIsSuppressed() || SaoqiangWCAssetsIsOwnImage(image)) return;
    if (data && (![data isKindOfClass:NSData.class] || data.length>2*1024*1024)) data=nil;
    if (candidateBubble) {
        SaoqiangWCAssetsAssociateBubbleCandidate(image,name);
        @synchronized(SaoqiangWCAssetsAssociationLock()) {
            if (data && objc_getAssociatedObject(image,&SaoqiangWCAssetsBubbleCandidateKey)!=NSNull.null) {
                SaoqiangWCAssetsImageInfo *candidate=[SaoqiangWCAssetsImageInfo new]; candidate.SaoqiangWCAssetsName=SaoqiangWCAssetsBubbleCandidateName(image)?:name; candidate.SaoqiangWCAssetsSource=source; candidate.SaoqiangWCAssetsRawSourceData=data;
                objc_setAssociatedObject(image,&SaoqiangWCAssetsCandidateSourceKey,candidate,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            if (SaoqiangWCAssetsImageInfoForImage(image).SaoqiangWCAssetsVerifiedBubble) SaoqiangWCAssetsAssociateBubbleImage(image,name,source);
        }
        SaoqiangWCAssetsRememberBacking(image); return;
    }
    BOOL svg=[name.pathExtension.lowercaseString isEqual:@"svg"];
    if (data.length>=4) { const unsigned char *p=data.bytes; if (p[0]=='<' || (data.length>=3 && p[0]==0xef && p[1]==0xbb && p[2]==0xbf)) svg=YES; }
    SaoqiangWCAssetsAssociateName(image,name,source,nil,svg,YES);
    @synchronized(SaoqiangWCAssetsAssociationLock()) {
        SaoqiangWCAssetsImageInfo *info=SaoqiangWCAssetsImageInfoForImage(image);
        if (info && !info.SaoqiangWCAssetsNameAmbiguous && SaoqiangWCAssetsMergeName(info.SaoqiangWCAssetsName,name)) {
            if (data) info.SaoqiangWCAssetsRawSourceData=data;
        }
    }
    SaoqiangWCAssetsRememberBacking(image);
}
void SaoqiangWCAssetsAssociateBubbleCandidate(UIImage *image, NSString *name) {
    if (![image isKindOfClass:UIImage.class] || SaoqiangWCAssetsIsSuppressed() || SaoqiangWCAssetsIsOwnImage(image) || !SaoqiangWCAssetsSafeRendererName(name)) return;
    @synchronized (SaoqiangWCAssetsAssociationLock()) {
        id old = objc_getAssociatedObject(image, &SaoqiangWCAssetsBubbleCandidateKey);
        if (old == NSNull.null) return;
        NSString *merged=old ? SaoqiangWCAssetsMergeName(old,name) : name;
        if (!merged) {
            objc_setAssociatedObject(image,&SaoqiangWCAssetsBubbleCandidateKey,NSNull.null,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            SaoqiangWCAssetsMarkAmbiguous(SaoqiangWCAssetsImageInfoForImage(image));
        } else {
            objc_setAssociatedObject(image,&SaoqiangWCAssetsBubbleCandidateKey,merged,OBJC_ASSOCIATION_COPY_NONATOMIC);
            SaoqiangWCAssetsImageInfo *info=SaoqiangWCAssetsImageInfoForImage(image);
            if (info.SaoqiangWCAssetsVerifiedBubble) SaoqiangWCAssetsAssociateBubbleImage(image,merged,info.SaoqiangWCAssetsSource?:@"命名气泡加载");
        }
        SaoqiangWCAssetsRememberBacking(image);
    }
}
NSString *SaoqiangWCAssetsBubbleCandidateName(UIImage *image) {
    @synchronized (SaoqiangWCAssetsAssociationLock()) {
        id name = objc_getAssociatedObject(image, &SaoqiangWCAssetsBubbleCandidateKey);
        return [name isKindOfClass:NSString.class] ? name : nil;
    }
}
SaoqiangWCAssetsImageInfo *SaoqiangWCAssetsImageInfoForImage(UIImage *image) {
    if (!image || SaoqiangWCAssetsIsOwnImage(image)) return nil;
    @synchronized (SaoqiangWCAssetsAssociationLock()) {
        id info = objc_getAssociatedObject(image, &SaoqiangWCAssetsImageInfoKey);
        return [info isKindOfClass:SaoqiangWCAssetsImageInfo.class] ? info : nil;
    }
}
void SaoqiangWCAssetsSetImageIdentity(UIImage *image, NSString *identity) {
    @synchronized (SaoqiangWCAssetsAssociationLock()) {
        SaoqiangWCAssetsImageInfo *info = SaoqiangWCAssetsImageInfoForImage(image);
        // Legacy callers cannot prove which metadata version they encoded.
        // After an upgrade, rebuild on demand instead of freezing an old PNG.
        if (!info.SaoqiangWCAssetsRevision) info.SaoqiangWCAssetsIdentity = identity;
    }
}
void SaoqiangWCAssetsSetImageIdentityForRevision(UIImage *image, NSString *identity, NSUInteger revision) {
    @synchronized (SaoqiangWCAssetsAssociationLock()) {
        SaoqiangWCAssetsImageInfo *info = SaoqiangWCAssetsImageInfoForImage(image);
        if (info && info.SaoqiangWCAssetsRevision == revision) info.SaoqiangWCAssetsIdentity = identity;
    }
}
static char SaoqiangWCAssetsFilePathKey;
void SaoqiangWCAssetsAssociateFilePath(UIImage *image, NSString *path) {
    if (!image || SaoqiangWCAssetsIsSuppressed() || SaoqiangWCAssetsIsOwnImage(image) || ![path isKindOfClass:NSString.class] || !path.isAbsolutePath || path.length > 2048) return;
    @synchronized (SaoqiangWCAssetsAssociationLock()) {
        id old = objc_getAssociatedObject(image, &SaoqiangWCAssetsFilePathKey);
        if (old == NSNull.null) return;
        if (old && ![old isEqual:path]) { objc_setAssociatedObject(image, &SaoqiangWCAssetsFilePathKey, NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return; }
        objc_setAssociatedObject(image, &SaoqiangWCAssetsFilePathKey, [path copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
NSString *SaoqiangWCAssetsObservedFilePath(UIImage *image) {
    @synchronized (SaoqiangWCAssetsAssociationLock()) {
        id path = objc_getAssociatedObject(image, &SaoqiangWCAssetsFilePathKey);
        return [path isKindOfClass:NSString.class] ? path : nil;
    }
}
void SaoqiangWCAssetsAssociateBubbleImage(UIImage *image, NSString *name, NSString *source) {
    if (![image isKindOfClass:UIImage.class] || SaoqiangWCAssetsIsSuppressed() || SaoqiangWCAssetsIsOwnImage(image)) return;
    @synchronized(SaoqiangWCAssetsAssociationLock()) {
        id old=objc_getAssociatedObject(image,&SaoqiangWCAssetsImageInfoKey);
        SaoqiangWCAssetsImageInfo *info=[old isKindOfClass:SaoqiangWCAssetsImageInfo.class]?old:[SaoqiangWCAssetsImageInfo new];
        id candidateName=objc_getAssociatedObject(image,&SaoqiangWCAssetsBubbleCandidateKey);
        SaoqiangWCAssetsImageInfo *candidate=objc_getAssociatedObject(image,&SaoqiangWCAssetsCandidateSourceKey);
        BOOL ambiguous=old==NSNull.null || candidateName==NSNull.null || info.SaoqiangWCAssetsNameAmbiguous || candidate.SaoqiangWCAssetsNameAmbiguous;
        NSString *path=SaoqiangWCAssetsObservedFilePath(image) ?: info.SaoqiangWCAssetsPath;
        NSString *best=SaoqiangWCAssetsHasName(info.SaoqiangWCAssetsName)?info.SaoqiangWCAssetsName:nil;
        for (id value in @[name?:@"",[candidateName isKindOfClass:NSString.class]?candidateName:@"",candidate.SaoqiangWCAssetsName?:@"",path.lastPathComponent?:@""]) {
            if (!SaoqiangWCAssetsHasName(value) || !SaoqiangWCAssetsSafeRendererName(value)) continue;
            best=SaoqiangWCAssetsMergeName(best,value); if (!best) { ambiguous=YES; break; }
        }
        NSString *resolved=ambiguous?@"无原始资源名":(best?:@"无原始资源名");
        BOOL changed=![info.SaoqiangWCAssetsName isEqual:resolved] || !info.SaoqiangWCAssetsVerifiedBubble || (path && ![info.SaoqiangWCAssetsPath isEqual:path]);
        info.SaoqiangWCAssetsVerifiedBubble=YES; info.SaoqiangWCAssetsSource=source;
        if (ambiguous) SaoqiangWCAssetsMarkAmbiguous(info);
        else {
            info.SaoqiangWCAssetsName=resolved; info.SaoqiangWCAssetsPath=path; info.SaoqiangWCAssetsSnapshotOnly=NO;
            NSData *raw=candidate.SaoqiangWCAssetsRawSourceData;
            if (raw && (!best || SaoqiangWCAssetsMergeName(best,candidate.SaoqiangWCAssetsName))) info.SaoqiangWCAssetsRawSourceData=raw;
        }
        if (changed) { info.SaoqiangWCAssetsIdentity=nil; ++info.SaoqiangWCAssetsRevision; }
        info.SaoqiangWCAssetsCapInsets=image.capInsets; info.SaoqiangWCAssetsResizingMode=image.resizingMode;
        SaoqiangWCAssetsRememberImage(image,info);
    }
    SaoqiangWCAssetsRememberBacking(image);
}
// ===== 0.11.41 名称恢复 =====
// The icons a user opens the panel for are usually already decoded and cached
// long before 开始抓取 is tapped, so no hooked load ever names them and every row
// came out as「无原始资源名」. UIKit keeps the asset name in the image's private
// storage; read it through KVC (never raw ivar memory, so weak slots are safe),
// validate it exactly like a hooked name, and memoise per image object.
static char SaoqiangWCAssetsRecoveredNameKey;
static NSMutableDictionary<NSString *, NSArray<NSString *> *> *SaoqiangWCAssetsNameIvarCache;
static BOOL SaoqiangWCAssetsNameBearingIvar(const char *name) {
    if (!name) return NO;
    size_t length = strlen(name); char buffer[96];
    if (!length || length >= sizeof(buffer)) return NO;
    SQNameLowerCopy(name, length, buffer);
    if (SQNameContains(buffer, length, "font") || SQNameContains(buffer, length, "class")) return NO;
    // _imageName / _assetName / _cacheKeyName: anything that ends in "name".
    return SQNameHasSuffix(buffer, length, "name");
}
static NSArray<NSString *> *SaoqiangWCAssetsNameIvars(Class cls) {
    if (!cls) return @[];
    NSString *key = NSStringFromClass(cls);
    @synchronized (SaoqiangWCAssetsAssociationLock()) {
        NSArray<NSString *> *cached = SaoqiangWCAssetsNameIvarCache[key];
        if (cached) return cached;
    }
    NSMutableArray<NSString *> *found = [NSMutableArray new];
    Class current = cls; NSUInteger depth = 0;
    while (current && current != NSObject.class && depth++ < 8) {
        unsigned count = 0; Ivar *ivars = class_copyIvarList(current, &count);
        for (unsigned i = 0; i < count; ++i) {
            const char *name = ivar_getName(ivars[i]);
            const char *type = ivar_getTypeEncoding(ivars[i]);
            if (!name || !type || type[0] != '@') continue;
            if (!SaoqiangWCAssetsNameBearingIvar(name)) continue;
            [found addObject:@(name)];
        }
        free(ivars); current = class_getSuperclass(current);
    }
    NSArray<NSString *> *result = found.copy;
    @synchronized (SaoqiangWCAssetsAssociationLock()) {
        if (!SaoqiangWCAssetsNameIvarCache) SaoqiangWCAssetsNameIvarCache = [NSMutableDictionary new];
        SaoqiangWCAssetsNameIvarCache[key] = result;
    }
    return result;
}
static BOOL SaoqiangWCAssetsHexOnly(const char *text, size_t length) {
    if (!length) return NO;
    for (size_t i = 0; i < length; ++i)
        if (!isxdigit((unsigned char)text[i])) return NO;
    return YES;
}
// UIImage/imageAsset sometimes expose a generated identifier (UUID or a plain
// hex digest) instead of a resource name. Those must never become a row name.
static BOOL SaoqiangWCAssetsIdentifierLike(NSString *value) {
    const char *utf8 = value.UTF8String; if (!utf8) return NO;
    size_t length = strlen(utf8);
    if (!length) return NO;
    if (length == 36 && utf8[8] == '-' && utf8[13] == '-' && utf8[18] == '-' && utf8[23] == '-') {
        char hex[36]; size_t written = 0;
        for (size_t i = 0; i < length; ++i) if (i != 8 && i != 13 && i != 18 && i != 23) hex[written++] = utf8[i];
        return SaoqiangWCAssetsHexOnly(hex, written);
    }
    return (length == 32 || length == 40 || length == 64) && SaoqiangWCAssetsHexOnly(utf8, length);
}
static NSString *SaoqiangWCAssetsAcceptableRecoveredName(NSString *value) {
    if (![value isKindOfClass:NSString.class] || !value.length || value.length > 240) return nil;
    if ([value rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound) return nil;
    if (value.isAbsolutePath || [value containsString:@"/"]) return nil;
    for (NSString *junk in @[@"(null)", @"null", @"nil", @"UIImage", @"image", @"NSNull"]) {
        if ([value isEqualToString:junk]) return nil;
    }
    if (SaoqiangWCAssetsIdentifierLike(value)) return nil;
    return SaoqiangWCAssetsSafeRendererName(value) ? value : nil;
}
static NSString *SaoqiangWCAssetsReadNameIvar(id object) {
    if (!object) return nil;
    Class cls = object_getClass(object);
    for (NSString *ivarName in SaoqiangWCAssetsNameIvars(cls)) {
        NSString *key = [ivarName hasPrefix:@"_"] ? [ivarName substringFromIndex:1] : ivarName;
        if (!key.length) continue;
        id value = nil;
        @try { value = [object valueForKey:key]; }
        @catch (__unused NSException *exception) { continue; }
        NSString *accepted = SaoqiangWCAssetsAcceptableRecoveredName(value);
        if (accepted) return accepted;
    }
    return nil;
}
NSString * _Nullable SaoqiangWCAssetsRecoveredImageName(UIImage * _Nullable image) {
    if (![image isKindOfClass:UIImage.class] || SaoqiangWCAssetsIsOwnImage(image)) return nil;
    @synchronized (SaoqiangWCAssetsAssociationLock()) {
        id cached = objc_getAssociatedObject(image, &SaoqiangWCAssetsRecoveredNameKey);
        if (cached) return cached == NSNull.null ? nil : cached;
    }
    NSString *found = nil;
    @try {
        found = SaoqiangWCAssetsReadNameIvar(image);
        if (!found) {
            UIImageAsset *asset = image.imageAsset;
            if (asset) found = SaoqiangWCAssetsReadNameIvar(asset);
        }
        // 0.11.43: CoreUI-backed icons keep the catalog name on a private image
        // provider rather than on the UIImage itself. The reference tweak reads
        // the same object, so mirror it: peel one level and scan its name ivars.
        for (NSString *provider in @[@"_cuiImage", @"cuiImage", @"_CUIImage"]) {
            if (found) break;
            id value = nil;
            @try { value = [image valueForKey:provider]; }
            @catch (__unused NSException *exception) { continue; }
            if (!value || value == image || ![value isKindOfClass:NSObject.class]) continue;
            found = SaoqiangWCAssetsReadNameIvar(value);
        }
    } @catch (__unused NSException *exception) { found = nil; }
    @synchronized (SaoqiangWCAssetsAssociationLock()) {
        objc_setAssociatedObject(image, &SaoqiangWCAssetsRecoveredNameKey, found ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return found;
}
void SaoqiangWCAssetsAssociateVisibleIcon(UIImage *image, NSString *source, NSString *name) {
    if (![image isKindOfClass:UIImage.class] || SaoqiangWCAssetsIsSuppressed() || SaoqiangWCAssetsIsOwnImage(image)) return;
    @synchronized(SaoqiangWCAssetsAssociationLock()) {
        if (SaoqiangWCAssetsImageInfoForImage(image)) return;
        SaoqiangWCAssetsImageInfo *info=[SaoqiangWCAssetsImageInfo new];
        // 0.11.41: a page-rendered icon that was decoded before 开始抓取 has no
        // hook metadata, but UIKit still knows the asset name internally.
        NSString *recovered=SaoqiangWCAssetsRecoveredImageName(image);
        if (recovered.length) {
            info.SaoqiangWCAssetsName=recovered;
            info.SaoqiangWCAssetsSource=@"UIImage imageNamed: · 名称从已缓存图片恢复";
            info.SaoqiangWCAssetsSnapshotOnly=YES;
        } else if (name.length) {
            // 0.11.42: the caller matched this snapshot to a named load or read
            // the owning control's label. Better a real, checkable name than the
            // same「无原始资源名」on every row.
            info.SaoqiangWCAssetsName=name;
            info.SaoqiangWCAssetsSource=source;
            info.SaoqiangWCAssetsSnapshotOnly=YES;
        } else {
            info.SaoqiangWCAssetsName=@"无原始资源名"; info.SaoqiangWCAssetsSource=source;
            info.SaoqiangWCAssetsSnapshotOnly=YES;
        }
        info.SaoqiangWCAssetsCapInsets=image.capInsets; info.SaoqiangWCAssetsResizingMode=image.resizingMode;
        SaoqiangWCAssetsRememberImage(image,info);
    }
}
void SaoqiangWCAssetsPropagateImageInfo(UIImage *input, UIImage *output, NSString *operation) {
    if (!input || !output || input == output || SaoqiangWCAssetsIsSuppressed() || SaoqiangWCAssetsIsOwnImage(input) || SaoqiangWCAssetsIsOwnImage(output)) return;
    @synchronized (SaoqiangWCAssetsAssociationLock()) {
        NSString *path = SaoqiangWCAssetsObservedFilePath(input); if (path) SaoqiangWCAssetsAssociateFilePath(output, path);
        SaoqiangWCAssetsImageInfo *candidateData=objc_getAssociatedObject(input,&SaoqiangWCAssetsCandidateSourceKey);
        if (candidateData) objc_setAssociatedObject(output,&SaoqiangWCAssetsCandidateSourceKey,candidateData,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        id candidate = objc_getAssociatedObject(input, &SaoqiangWCAssetsBubbleCandidateKey);
        if (candidate == NSNull.null) objc_setAssociatedObject(output, &SaoqiangWCAssetsBubbleCandidateKey, NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        else if (candidate) SaoqiangWCAssetsAssociateBubbleCandidate(output, candidate);
        if (objc_getAssociatedObject(input, &SaoqiangWCAssetsImageInfoKey) == NSNull.null) {
            objc_setAssociatedObject(output, &SaoqiangWCAssetsImageInfoKey, NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [SaoqiangWCAssetsKnownImages removeObjectForKey:output]; return;
        }
        SaoqiangWCAssetsImageInfo *old = SaoqiangWCAssetsImageInfoForImage(input); if (!old) return;
        NSString *source = [NSString stringWithFormat:@"%@ · %@", [old.SaoqiangWCAssetsSource componentsSeparatedByString:@" · "].firstObject ?: @"命名图片", operation];
        if (old.SaoqiangWCAssetsVerifiedBubble) SaoqiangWCAssetsAssociateBubbleImage(output, old.SaoqiangWCAssetsName, source);
        else SaoqiangWCAssetsAssociateName(output, old.SaoqiangWCAssetsName, source, old.SaoqiangWCAssetsPath, old.SaoqiangWCAssetsSVG, old.SaoqiangWCAssetsNamedRenderer);
        SaoqiangWCAssetsImageInfo *info = SaoqiangWCAssetsImageInfoForImage(output);
        if (!info) return;
        info.SaoqiangWCAssetsSnapshotOnly = old.SaoqiangWCAssetsSnapshotOnly;
        info.SaoqiangWCAssetsSVG = old.SaoqiangWCAssetsSVG;
        info.SaoqiangWCAssetsNamedRenderer = old.SaoqiangWCAssetsNamedRenderer;
        info.SaoqiangWCAssetsBytesEntry = old.SaoqiangWCAssetsBytesEntry;
        // A derivative has its own capInsets/rendering. Do not reuse the source's
        // record identity: Store must render the actual selected UIImage.
        info.SaoqiangWCAssetsIdentity = nil;
    }
}
void SaoqiangWCAssetsMarkOwnView(UIView *view) { objc_setAssociatedObject(view, &SaoqiangWCAssetsOwnViewKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
BOOL SaoqiangWCAssetsIsOwnView(UIView *view) {
    for (UIView *v = view; v; v = v.superview) if (objc_getAssociatedObject(v, &SaoqiangWCAssetsOwnViewKey)) return YES;
    return NO;
}
@interface SaoqiangWCAssetsDataName : NSObject
@property(nonatomic,copy) NSString *name;
@property(nonatomic,copy) NSString *source;
@property(nonatomic) BOOL bubble;
@property(nonatomic) BOOL ambiguous;
@end
@implementation SaoqiangWCAssetsDataName
@end
static NSMapTable<NSData *,SaoqiangWCAssetsDataName *> *SaoqiangWCAssetsDataSources;
// Any decoded image passes through here, including every avatar. A plain count
// lets the common case (nothing named in flight) skip the lock and the lookup.
static volatile int SaoqiangWCAssetsDataSourcesCount;
void SaoqiangWCAssetsAssociateNamedData(NSData *data, NSString *name, NSString *source, BOOL bubble) {
    if (![data isKindOfClass:NSData.class] || !data.length || data.length>2*1024*1024 || [data isKindOfClass:NSMutableData.class] || !SaoqiangWCAssetsSafeRendererName(name) || SaoqiangWCAssetsIsSuppressed()) return;
    @synchronized(SaoqiangWCAssetsAssociationLock()) {
        if (!SaoqiangWCAssetsDataSources) SaoqiangWCAssetsDataSources=[NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory|NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsStrongMemory];
        SaoqiangWCAssetsDataName *old=[SaoqiangWCAssetsDataSources objectForKey:data]; if (old.ambiguous) return;
        NSString *merged=old?SaoqiangWCAssetsMergeName(old.name,name):name;
        SaoqiangWCAssetsDataName *value=old?:[SaoqiangWCAssetsDataName new]; value.ambiguous=!merged;
        if (merged) {value.name=merged;value.source=source;value.bubble|=bubble;}
        if (!old && SaoqiangWCAssetsDataSources.count>=256) {
            [SaoqiangWCAssetsDataSources removeAllObjects]; SaoqiangWCAssetsDataSourcesCount = 0;
        }
        [SaoqiangWCAssetsDataSources setObject:value forKey:data];
        if (!old) ++SaoqiangWCAssetsDataSourcesCount;
    }
}
void SaoqiangWCAssetsAssociateDecodedImage(UIImage *image, NSData *data) {
    if (!SaoqiangWCAssetsDataSourcesCount) return;
    if (![image isKindOfClass:UIImage.class] || SaoqiangWCAssetsIsSuppressed() || SaoqiangWCAssetsIsOwnImage(image)) return;
    NSString *name=nil,*source=nil;BOOL bubble=NO;
    @synchronized(SaoqiangWCAssetsAssociationLock()) {
        SaoqiangWCAssetsDataName *value=[SaoqiangWCAssetsDataSources objectForKey:data];
        if (value && !value.ambiguous) {name=value.name;source=value.source;bubble=value.bubble;}
    }
    if (name.length) SaoqiangWCAssetsAssociateSourceImage(image,name,data,source?:@"实际命名数据解码",bubble);
}

// Exact pointer identity only; hold the CGImage so an address cannot be recycled.
// This map never owns a source UIImage and keeps <=64 images / 8 MiB decoded cost.
@interface SaoqiangWCAssetsBacking : NSObject
@property(nonatomic,strong) id image;
@property(nonatomic,strong) SaoqiangWCAssetsImageInfo *info;
@property(nonatomic,copy) NSString *candidate;
@property(nonatomic,strong) SaoqiangWCAssetsImageInfo *candidateInfo;
@property(nonatomic) BOOL ambiguous;
@property(nonatomic) NSUInteger cost;
@end
@implementation SaoqiangWCAssetsBacking
@end
static NSMutableArray<SaoqiangWCAssetsBacking *> *SaoqiangWCAssetsBackings;
static NSUInteger SaoqiangWCAssetsBackingCost;
void SaoqiangWCAssetsRememberBacking(UIImage *image) {
    if (!image.CGImage || SaoqiangWCAssetsIsOwnImage(image) || SaoqiangWCAssetsIsSuppressed()) return;
    @synchronized(SaoqiangWCAssetsAssociationLock()) {
        SaoqiangWCAssetsImageInfo *info=SaoqiangWCAssetsImageInfoForImage(image);
        id candidate=objc_getAssociatedObject(image,&SaoqiangWCAssetsBubbleCandidateKey);
        BOOL ambiguous=info.SaoqiangWCAssetsNameAmbiguous || candidate==NSNull.null || objc_getAssociatedObject(image,&SaoqiangWCAssetsImageInfoKey)==NSNull.null;
        NSString *candidateName=[candidate isKindOfClass:NSString.class]?candidate:nil;
        if (!ambiguous && !SaoqiangWCAssetsHasName(info.SaoqiangWCAssetsName) && !candidateName.length) return;
        NSUInteger height=CGImageGetHeight(image.CGImage), stride=CGImageGetBytesPerRow(image.CGImage);
        if (!height || stride>8*1024*1024/height) return;
        NSUInteger cost=height*stride;
        if (!SaoqiangWCAssetsBackings) SaoqiangWCAssetsBackings=[NSMutableArray new];
        SaoqiangWCAssetsBacking *entry=nil;
        for (SaoqiangWCAssetsBacking *e in SaoqiangWCAssetsBackings) if ((__bridge CGImageRef)e.image==image.CGImage) {entry=e;break;}
        if (!entry) {
            while (SaoqiangWCAssetsBackings.count && (SaoqiangWCAssetsBackings.count>=64 || SaoqiangWCAssetsBackingCost+cost>8*1024*1024)) {
                SaoqiangWCAssetsBackingCost-=SaoqiangWCAssetsBackings.firstObject.cost;[SaoqiangWCAssetsBackings removeObjectAtIndex:0];
            }
            entry=[SaoqiangWCAssetsBacking new];entry.image=(__bridge id)image.CGImage;entry.cost=cost;
            [SaoqiangWCAssetsBackings addObject:entry];SaoqiangWCAssetsBackingCost+=cost;
        }
        NSString *oldName=SaoqiangWCAssetsHasName(entry.info.SaoqiangWCAssetsName)?entry.info.SaoqiangWCAssetsName:entry.candidate;
        NSString *newName=SaoqiangWCAssetsHasName(info.SaoqiangWCAssetsName)?info.SaoqiangWCAssetsName:candidateName;
        if (oldName.length && newName.length && !SaoqiangWCAssetsMergeName(oldName,newName)) ambiguous=YES;
        entry.ambiguous|=ambiguous;
        if (entry.ambiguous) return;
        if (info && SaoqiangWCAssetsHasName(info.SaoqiangWCAssetsName)) entry.info=info;
        if (candidateName.length) entry.candidate=SaoqiangWCAssetsMergeName(entry.candidate,candidateName);
        SaoqiangWCAssetsImageInfo *raw=objc_getAssociatedObject(image,&SaoqiangWCAssetsCandidateSourceKey);if (raw) entry.candidateInfo=raw;
    }
}
UIImage *SaoqiangWCAssetsImageForLayer(CALayer *layer) {
    id contents=layer.contents;if (!contents || CFGetTypeID((__bridge CFTypeRef)contents)!=CGImageGetTypeID()) return nil;
    UIImage *found=nil;NSString *name=nil;SaoqiangWCAssetsBacking *entry=nil;
    @synchronized(SaoqiangWCAssetsAssociationLock()) {
        for (SaoqiangWCAssetsBacking *e in SaoqiangWCAssetsBackings) if (e.image==contents) {entry=e;break;}
        if (entry.ambiguous) return nil;
        // Every named image also records a backing entry, so a named entry is
        // authoritative and the O(knownImages) scan below can be skipped. This
        // runs for every layer the page sampler visits.
        if (entry.info && SaoqiangWCAssetsHasName(entry.info.SaoqiangWCAssetsName)) {
            UIImage *image=[UIImage imageWithCGImage:(__bridge CGImageRef)contents scale:MAX(1,layer.contentsScale) orientation:UIImageOrientationUp];
            SaoqiangWCAssetsRememberImage(image,entry.info);
            if (entry.candidate.length) objc_setAssociatedObject(image,&SaoqiangWCAssetsBubbleCandidateKey,entry.candidate,OBJC_ASSOCIATION_COPY_NONATOMIC);
            if (entry.candidateInfo) objc_setAssociatedObject(image,&SaoqiangWCAssetsCandidateSourceKey,entry.candidateInfo,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return image;
        }
        for (UIImage *image in SaoqiangWCAssetsKnownImages.keyEnumerator) {
            if (image.CGImage!=(__bridge CGImageRef)contents) continue;
            SaoqiangWCAssetsImageInfo *info=SaoqiangWCAssetsImageInfoForImage(image);
            if (info.SaoqiangWCAssetsNameAmbiguous) return nil;
            if (!SaoqiangWCAssetsHasName(info.SaoqiangWCAssetsName)) continue;
            NSString *merged=SaoqiangWCAssetsMergeName(name,info.SaoqiangWCAssetsName);if (!merged) return nil;
            name=merged;found=image;
        }
        if (found) return found;
        if (!entry) return nil;
        UIImage *image=[UIImage imageWithCGImage:(__bridge CGImageRef)contents scale:MAX(1,layer.contentsScale) orientation:UIImageOrientationUp];
        if (entry.info) SaoqiangWCAssetsRememberImage(image,entry.info);
        if (entry.candidate.length) objc_setAssociatedObject(image,&SaoqiangWCAssetsBubbleCandidateKey,entry.candidate,OBJC_ASSOCIATION_COPY_NONATOMIC);
        if (entry.candidateInfo) objc_setAssociatedObject(image,&SaoqiangWCAssetsCandidateSourceKey,entry.candidateInfo,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return image;
    }
}

static __weak UINavigationController *SaoqiangWCAssetsInspectorNavigation;
@interface SaoqiangWCAssetsRecordController : UIViewController <UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate>
@property(nonatomic) BOOL SaoqiangWCAssetsOwnUICounted;
@property(nonatomic, strong, nullable) SaoqiangWCAssetsRecord *SaoqiangWCAssetsRecord;
@property(nonatomic, copy, nullable) NSString *SaoqiangWCAssetsFailure;
@property(nonatomic) BOOL SaoqiangWCAssetsBusy;
@end

@implementation SaoqiangWCAssetsRecordController
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!self.SaoqiangWCAssetsOwnUICounted) { self.SaoqiangWCAssetsOwnUICounted = YES; SaoqiangWCAssetsNoteOwnUI(YES); }
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.SaoqiangWCAssetsOwnUICounted) { self.SaoqiangWCAssetsOwnUICounted = NO; SaoqiangWCAssetsNoteOwnUI(NO); }
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = self.SaoqiangWCAssetsRecord ? @"已识别资源" : @"暂未识别";
    self.view.backgroundColor = UIColor.systemBackgroundColor; SaoqiangWCAssetsMarkOwnView(self.view);
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain target:self action:@selector(SaoqiangWCAssetsClose)];
    UIScrollView *scroll = [UIScrollView new]; scroll.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:scroll];
    UIStackView *stack = [UIStackView new]; stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 14; stack.translatesAutoresizingMaskIntoConstraints = NO; [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor], [scroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor], [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:20], [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:20], [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-40]
    ]];
    SaoqiangWCAssetsRecord *record = self.SaoqiangWCAssetsRecord;
    if (record) {
        UIImageView *preview = [UIImageView new]; preview.contentMode = UIViewContentModeScaleAspectFit;
        preview.backgroundColor = UIColor.secondarySystemBackgroundColor; preview.layer.cornerRadius = 12; preview.clipsToBounds = YES;
        preview.image = record.thumbnail; [preview.heightAnchor constraintEqualToConstant:160].active = YES; [stack addArrangedSubview:preview];
        UILabel *name = [UILabel new]; name.text = record.name; name.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; name.numberOfLines = 0; [stack addArrangedSubview:name];
        UILabel *detail = [UILabel new]; detail.font = [UIFont systemFontOfSize:12]; detail.textColor = UIColor.secondaryLabelColor; detail.numberOfLines = 0;
        detail.text = [NSString stringWithFormat:@"%@ · %@ · %.1f KB", record.original ? @"原始文件" : @"渲染快照", record.kind, record.bytes.length / 1024.0]; [stack addArrangedSubview:detail];
        if (record.provenance.length || record.source.length) [self SaoqiangWCAssetsAddButton:@"查看来源" selector:@selector(SaoqiangWCAssetsShowSource) stack:stack];
        if (!record.thumbnail) { UILabel *noPreview = [UILabel new]; noPreview.text = @"未捕获可用的渲染预览；可保存当前实际资源。"; noPreview.numberOfLines = 0; noPreview.font = [UIFont systemFontOfSize:13]; [stack addArrangedSubview:noPreview]; }
        [self SaoqiangWCAssetsAddButton:@"复制资源名" selector:@selector(SaoqiangWCAssetsCopy) stack:stack];
        [self SaoqiangWCAssetsAddButton:record.original ? @"保存原始文件到“文件”" : @"保存渲染 PNG 到“文件”" selector:@selector(SaoqiangWCAssetsSaveCurrent:) stack:stack];
        [self SaoqiangWCAssetsAddButton:record.original ? @"分享原始文件" : @"分享渲染 PNG" selector:@selector(SaoqiangWCAssetsShareCurrent:) stack:stack];
        if (record.original && (![record.kind isEqualToString:@"SVG"] || record.renderedBytes.length)) {
            [self SaoqiangWCAssetsAddButton:@"保存渲染 PNG 到“文件”" selector:@selector(SaoqiangWCAssetsSaveRendered:) stack:stack];
            [self SaoqiangWCAssetsAddButton:@"分享渲染 PNG" selector:@selector(SaoqiangWCAssetsShareRendered:) stack:stack];
        }
    } else {
        UILabel *message = [UILabel new]; message.numberOfLines = 0;
        message.text = self.SaoqiangWCAssetsFailure ?: @"暂无可用资源，请返回列表选择素材。";
        [stack addArrangedSubview:message];
    }
}
- (void)SaoqiangWCAssetsAddButton:(NSString *)title selector:(SEL)selector stack:(UIStackView *)stack {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem]; [button setTitle:title forState:UIControlStateNormal]; button.titleLabel.font = [UIFont systemFontOfSize:16];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside]; [stack addArrangedSubview:button];
}
- (void)SaoqiangWCAssetsClose {
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)SaoqiangWCAssetsShowSource {
    if (self.presentedViewController) return;
    SaoqiangWCAssetsRecord *record = self.SaoqiangWCAssetsRecord;
    NSString *source = [NSString stringWithFormat:@"%@\n%@", record.provenance ?: @"", record.source ?: @""];
    if (source.length > 600) source = [[source substringToIndex:600] stringByAppendingString:@"…"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已取得的来源" message:source preferredStyle:UIAlertControllerStyleAlert];
    SaoqiangWCAssetsMarkOwnView(alert.view); [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)SaoqiangWCAssetsCopy {
    NSString *name=self.SaoqiangWCAssetsRecord.name;
    if (!name.length || [name containsString:@"无原始资源名"] || [name containsString:@"无原名"]) { self.navigationItem.prompt=@"该资源没有原始资源名"; return; }
    UIPasteboard.generalPasteboard.string=name; self.navigationItem.prompt=@"已复制资源名";
}
- (void)SaoqiangWCAssetsSaveCurrent:(UIButton *)button { [self SaoqiangWCAssetsExportRendered:NO share:NO button:button]; }
- (void)SaoqiangWCAssetsShareCurrent:(UIButton *)button { [self SaoqiangWCAssetsExportRendered:NO share:YES button:button]; }
- (void)SaoqiangWCAssetsSaveRendered:(UIButton *)button { [self SaoqiangWCAssetsExportRendered:YES share:NO button:button]; }
- (void)SaoqiangWCAssetsShareRendered:(UIButton *)button { [self SaoqiangWCAssetsExportRendered:YES share:YES button:button]; }
- (void)SaoqiangWCAssetsExportRendered:(BOOL)rendered share:(BOOL)share button:(UIButton *)button {
    if (self.SaoqiangWCAssetsBusy || !self.SaoqiangWCAssetsRecord) return;
    self.SaoqiangWCAssetsBusy = YES; button.enabled = NO; self.navigationItem.prompt = @"准备单项导出…";
    [[SaoqiangWCAssetsStore SaoqiangWCAssetsShared] SaoqiangWCAssetsExport:self.SaoqiangWCAssetsRecord rendered:rendered completion:^(NSURL *url, NSString *error) {
        self.SaoqiangWCAssetsBusy = NO; button.enabled = YES; self.navigationItem.prompt = nil;
        if (!self.view.window || self.presentedViewController) return;
        if (!url) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法导出" message:error preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]]; [self presentViewController:alert animated:YES completion:nil]; return;
        }
        if (share) {
            UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
            activity.popoverPresentationController.sourceView = button; activity.popoverPresentationController.sourceRect = button.bounds;
            [self presentViewController:activity animated:YES completion:nil];
        } else {
            UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[url] asCopy:YES]; picker.delegate = self;
            [self presentViewController:picker animated:YES completion:nil];
        }
    }];
}
@end

// Removed point mode: compatibility entry points never install an overlay.
BOOL SaoqiangWCAssetsInspectorEnabled(void) { return NO; }
void SaoqiangWCAssetsSetInspectorEnabled(BOOL enabled, UIWindow *window) { (void)enabled;(void)window; }
void SaoqiangWCAssetsInspectorAttach(UIWindow *window) { (void)window; }
BOOL SaoqiangWCAssetsInspectorUIActive(void) {
    return NSThread.isMainThread && (SaoqiangWCAssetsInspectorNavigation.presentingViewController != nil || SaoqiangWCAssetsInspectorNavigation.isBeingPresented);
}
void SaoqiangWCAssetsPresentRecord(SaoqiangWCAssetsRecord *record, UIViewController *presenter) {
    if (!NSThread.isMainThread || !record || !presenter.view.window || presenter.isBeingDismissed || presenter.presentedViewController) return;
    SaoqiangWCAssetsPushSuppression();
    @try {
        SaoqiangWCAssetsRecordController *controller=[SaoqiangWCAssetsRecordController new];
        controller.SaoqiangWCAssetsRecord=record;
        UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:controller];
        SaoqiangWCAssetsMarkOwnView(nav.view);SaoqiangWCAssetsInspectorNavigation=nav;
        [presenter presentViewController:nav animated:YES completion:nil];
    } @finally { SaoqiangWCAssetsPopSuppression(); }
}
