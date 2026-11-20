#import "SaoqiangWCAssets.h"
#import "SaoqiangWCAssetsInspector.h"
#import "SaoqiangWCAssetsZIP.h"
#import "SaoqiangWCAssetsTheme.h"
#import <CommonCrypto/CommonDigest.h>
#import <ImageIO/ImageIO.h>
#import <objc/runtime.h>
#import <fcntl.h>
#import <unistd.h>
#import <sys/stat.h>
#import <math.h>
#import <string.h>
#import <os/lock.h>
#import "SaoqiangWCAssetsNames.h"

static _Thread_local unsigned SaoqiangWCAssetsSuppression;
static char SaoqiangWCAssetsOwnImageKey;
static const NSUInteger SaoqiangWCAssetsMaxFile = 8 * 1024 * 1024;
static const NSUInteger SaoqiangWCAssetsMaxTotal = 96 * 1024 * 1024;
BOOL SaoqiangWCAssetsIsSuppressed(void) { return SaoqiangWCAssetsSuppression != 0; }
void SaoqiangWCAssetsPushSuppression(void) { ++SaoqiangWCAssetsSuppression; }
void SaoqiangWCAssetsPopSuppression(void) { if (SaoqiangWCAssetsSuppression) --SaoqiangWCAssetsSuppression; }
void SaoqiangWCAssetsMarkOwnImage(UIImage *image) { if (image) objc_setAssociatedObject(image, &SaoqiangWCAssetsOwnImageKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
BOOL SaoqiangWCAssetsIsOwnImage(UIImage *image) { return image && objc_getAssociatedObject(image, &SaoqiangWCAssetsOwnImageKey) != nil; }
// These predicates run for every hooked image load (WeChat reloads dozens of
// cells per scroll), so they must not allocate. A bounded decision cache turns
// the steady state into one unfair-lock acquisition plus one dictionary lookup.
static const NSUInteger SaoqiangWCAssetsNameCacheLimit = 4096;
static NSMutableDictionary *SaoqiangWCAssetsUINameCache;
static NSMutableDictionary *SaoqiangWCAssetsBubbleNameCache;
static os_unfair_lock SaoqiangWCAssetsNameCacheLock = OS_UNFAIR_LOCK_INIT;

static BOOL SaoqiangWCAssetsNameCacheLookup(NSMutableDictionary * __strong *box, NSString *name, BOOL *found) {
    os_unfair_lock_lock(&SaoqiangWCAssetsNameCacheLock);
    NSMutableDictionary *cache = *box; NSNumber *cached = cache ? cache[name] : nil;
    os_unfair_lock_unlock(&SaoqiangWCAssetsNameCacheLock);
    *found = cached != nil; return cached.boolValue;
}
static void SaoqiangWCAssetsNameCacheStore(NSMutableDictionary * __strong *box, NSString *name, BOOL value) {
    os_unfair_lock_lock(&SaoqiangWCAssetsNameCacheLock);
    if (!*box) *box = [NSMutableDictionary dictionaryWithCapacity:512];
    NSMutableDictionary *cache = *box;
    if (cache.count >= SaoqiangWCAssetsNameCacheLimit) [cache removeAllObjects];
    cache[name] = @(value);
    os_unfair_lock_unlock(&SaoqiangWCAssetsNameCacheLock);
}
BOOL SaoqiangWCAssetsBubbleName(NSString *name) {
    if (![name isKindOfClass:NSString.class] || !name.length) return NO;
    BOOL found = NO; BOOL cached = SaoqiangWCAssetsNameCacheLookup(&SaoqiangWCAssetsBubbleNameCache, name, &found);
    if (found) return cached;
    BOOL result = NO; const char *utf8 = name.UTF8String;
    if (utf8) {
        char buffer[SQNameCapacity];
        size_t length = 0; const char *component = SQNameLastComponent(utf8, strlen(utf8), &length);
        if (length < SQNameCapacity) {
            SQNameLowerCopy(component, length, buffer);
            result = SQNameBubblePrefix(buffer, length);
        }
    }
    SaoqiangWCAssetsNameCacheStore(&SaoqiangWCAssetsBubbleNameCache, name, result);
    return result;
}
BOOL SaoqiangWCAssetsUIName(NSString *name) {
    if (![name isKindOfClass:NSString.class] || !name.length || name.length > 240) return NO;
    BOOL found = NO; BOOL cached = SaoqiangWCAssetsNameCacheLookup(&SaoqiangWCAssetsUINameCache, name, &found);
    if (found) return cached;
    BOOL result = NO; const char *utf8 = name.UTF8String;
    if (utf8) {
        size_t total = strlen(utf8), length = 0;
        const char *component = SQNameLastComponent(utf8, total, &length);
        // ".." and a leading separator are rejected on the full string, as before.
        if (total < SQNameCapacity && length < SQNameCapacity &&
            !SQNameContains(utf8, total, "..") && utf8[0] != '/') {
            char buffer[SQNameCapacity];
            SQNameLowerCopy(component, length, buffer);
            if (!SQNameExcluded(buffer, length)) {
                if (SQNameBubblePrefix(buffer, length)) result = YES;
                else {
                    char stem[SQNameCapacity], base[SQNameCapacity];
                    size_t stemLength = SQNameHasImageExtension(buffer, length) ?
                        (size_t)(strrchr(buffer, '.') - buffer) : length;
                    size_t baseLength = SQNameStripSuffixes(stem, stemLength, base);
                    result = SQNameHasPrefix(base, baseLength, "icons_") ||
                        SQNameHasSuffix(base, baseLength, "_regular") ||
                        SQNameHasSuffix(base, baseLength, "_heavy") ||
                        SQNameHasPrefix(base, baseLength, "fileicon_") ||
                        SQNameHasPrefix(base, baseLength, "tabbar_") ||
                        SQNameHasPrefix(base, baseLength, "navigationbar_") ||
                        SQNameHasPrefix(base, baseLength, "badge") ||
                        // 0.11.41: an actual image file name is always a real
                        // resource name, and most icon assets carry "icon" in
                        // the stem even without the icons_ prefix.
                        SQNameHasImageExtension(buffer, length) ||
                        SQNameContains(base, baseLength, "icon");
                }
            }
        }
    }
    SaoqiangWCAssetsNameCacheStore(&SaoqiangWCAssetsUINameCache, name, result);
    return result;
}
static NSString *SaoqiangWCAssetsHash(NSData *data) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *s = [NSMutableString string]; for (NSUInteger i = 0; i < sizeof(digest); i++) [s appendFormat:@"%02x", digest[i]]; return s;
}
static NSData *SaoqiangWCAssetsRead(NSString *path) {
    int fd = open(path.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW | O_NONBLOCK); if (fd < 0) return nil;
    struct stat st; if (fstat(fd, &st) || !S_ISREG(st.st_mode) || st.st_size <= 0 || st.st_size > (off_t)SaoqiangWCAssetsMaxFile) { close(fd); return nil; }
    NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)st.st_size]; NSUInteger offset = 0;
    while (offset < data.length) { ssize_t n = read(fd, (char *)data.mutableBytes + offset, data.length - offset); if (n <= 0) { close(fd); return nil; } offset += (NSUInteger)n; }
    close(fd); return data;
}
static NSString *SaoqiangWCAssetsKind(NSData *data, NSString *extension) {
    const unsigned char *p = data.bytes;
    if (data.length >= 8 && !memcmp(p, "\x89PNG\r\n\x1a\n", 8)) return @"PNG";
    if (data.length >= 3 && p[0] == 0xff && p[1] == 0xd8 && p[2] == 0xff) return @"JPEG";
    if ([extension.lowercaseString isEqual:@"svg"]) { NSString *xml = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]; if ([xml rangeOfString:@"<svg" options:NSCaseInsensitiveSearch].location != NSNotFound && xml) return @"SVG"; }
    return @"OTHER";
}
static UIImage *SaoqiangWCAssetsThumbnail(NSData *data) {
    if (!data.length) return nil;
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL); if (!source) return nil;
    NSDictionary *options = @{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES, (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@100, (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform:@YES};
    CGImageRef cg = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options); UIImage *image = cg ? [UIImage imageWithCGImage:cg] : nil;
    if (cg) CGImageRelease(cg); CFRelease(source); SaoqiangWCAssetsMarkOwnImage(image); return image;
}
// 0.11.44: draw the row thumbnail straight from the already-decoded image.
// Decoding the stored bytes again only worked for formats ImageIO understands,
// so an SVG icon with its original bytes had no preview at all once we stopped
// re-encoding it as PNG.
static UIImage *SaoqiangWCAssetsThumbnailImage(UIImage *image) {
    if (!image) return nil;
    CGSize point = image.size; CGFloat scale = image.scale > 0 ? image.scale : 1;
    if (!(point.width > 0) || !(point.height > 0)) return nil;
    CGFloat longest = MAX(point.width, point.height) * scale;
    CGFloat ratio = longest > 100 ? 100 / longest : 1;
    CGSize target = CGSizeMake(MAX(1, point.width * ratio), MAX(1, point.height * ratio));
    UIImage *texture = image.CGImage ? [UIImage imageWithCGImage:image.CGImage scale:scale orientation:image.imageOrientation] : image;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1; format.opaque = NO;
    UIImage *thumb = [[[UIGraphicsImageRenderer alloc] initWithSize:target format:format] imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [texture drawInRect:(CGRect){CGPointZero, target}];
    }];
    SaoqiangWCAssetsMarkOwnImage(thumb);
    return thumb;
}
static NSData *SaoqiangWCAssetsRender(UIImage *image) {
    if (!image) return nil; CGFloat w = image.size.width * image.scale, h = image.size.height * image.scale;
    if (!isfinite(w) || !isfinite(h) || w <= 0 || h <= 0 || w*h > 4*1024*1024 || w > 8192 || h > 8192) return nil;
    // Preserve the source texture. Stretchable UIImage capInsets are in points;
    // drawing it into a pixel-sized point rect stretches/tile-repeats it again.
    UIImage *texture=image.CGImage ? [UIImage imageWithCGImage:image.CGImage scale:image.scale orientation:image.imageOrientation] : image;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat]; format.scale = texture.scale; format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:texture.size format:format];
    NSData *data = [renderer PNGDataWithActions:^(UIGraphicsImageRendererContext *context) { [texture drawInRect:(CGRect){CGPointZero,texture.size}]; }]; return data.length <= SaoqiangWCAssetsMaxFile ? data : nil;
}
@implementation SaoqiangWCAssetsRecord
@end

@interface SaoqiangWCAssetsStore () {
    NSLock *_lock; dispatch_queue_t _queue;
    BOOL _enabled, _active;
    NSUInteger _pending, _epoch, _total, _dropped, _revision;
    NSString *_runtimeSession, *_pageKey;
    NSMutableArray<SaoqiangWCAssetsRecord *> *_records;
    NSMapTable<UIImage *,NSDictionary *> *_seen;
}
@end
@implementation SaoqiangWCAssetsStore
+ (instancetype)SaoqiangWCAssetsShared { static SaoqiangWCAssetsStore *s; static dispatch_once_t once; dispatch_once(&once,^{s=[self new];}); return s; }
- (instancetype)init {
    if ((self=[super init])) {
        _lock=[NSLock new]; _records=[NSMutableArray new]; _runtimeSession=NSUUID.UUID.UUIDString;
        _seen=[NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory|NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsStrongMemory];
        _queue=dispatch_queue_create("com.saoqiang.wcassets.page",dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,QOS_CLASS_UTILITY,0));
    } return self;
}
- (BOOL)SaoqiangWCAssetsEnabled { [_lock lock]; BOOL b=_enabled; [_lock unlock]; return b; }
- (void)SaoqiangWCAssetsSetEnabled:(BOOL)enabled {
    // Stop/start invalidates queued work, but must not discard the association
    // between an existing image and its captured row (late names replace it).
    [_lock lock]; _enabled=enabled; ++_epoch; ++_revision; [_lock unlock];
    if (enabled) dispatch_async(dispatch_get_main_queue(),^{SaoqiangWCAssetsCaptureVisiblePage();});
}
- (NSUInteger)SaoqiangWCAssetsRevision { [_lock lock]; NSUInteger r=_revision; [_lock unlock]; return r; }
- (void)SaoqiangWCAssetsSetAppActive:(BOOL)active { [_lock lock]; _active=active; [_lock unlock]; }
- (void)SaoqiangWCAssetsSetPageKey:(NSString *)key {
    if (!key.length) return;
    [_lock lock];
    if (![_pageKey isEqual:key]) {
        // Page navigation starts a new visibility pass; the capture session stays
        // cumulative until the user presses 清空.
        _pageKey=[key copy];
    }
    [_lock unlock];
}
- (void)SaoqiangWCAssetsClear {
    [_lock lock]; ++_epoch; ++_revision; [_records removeAllObjects]; [_seen removeAllObjects]; _total=0; _dropped=0; _runtimeSession=NSUUID.UUID.UUIDString; [_lock unlock];
}
- (NSArray *)SaoqiangWCAssetsSnapshot { [_lock lock]; NSArray *a=[_records copy]; [_lock unlock]; return a; }
- (void)SaoqiangWCAssetsAfterPending:(dispatch_block_t)completion { dispatch_async(_queue,^{dispatch_async(dispatch_get_main_queue(),completion);}); }
- (NSDictionary *)SaoqiangWCAssetsCollectionState {
    [_lock lock]; NSUInteger svg=0,png=0;
    for (SaoqiangWCAssetsRecord *r in _records) { svg += [r.kind isEqual:@"SVG"]; png += [r.kind isEqual:@"PNG"]; }
    NSDictionary *d=@{@"runtimeID":_runtimeSession,@"enabled":@(_enabled),@"collected":@(_records.count),@"png":@(png),@"svg":@(svg),@"dropped":@(_dropped),@"pending":@(_pending),@"epoch":@(_epoch)};
    [_lock unlock]; return d;
}
- (NSString *)SaoqiangWCAssetsStatus {
    NSDictionary *d=[self SaoqiangWCAssetsCollectionState]; return [NSString stringWithFormat:@"%@ · 当前 %@ · SVG %@ · PNG %@ · 跳过 %@",[d[@"enabled"] boolValue]?@"抓取中":@"已停止",d[@"collected"],d[@"svg"],d[@"png"],d[@"dropped"]];
}
- (NSDictionary *)SaoqiangWCAssetsSourceSnapshot:(UIImage *)image {
    SaoqiangWCAssetsImageInfo *i=SaoqiangWCAssetsImageInfoForImage(image); if (!i) return nil;
    NSString *path=i.SaoqiangWCAssetsSnapshotOnly ? nil : (i.SaoqiangWCAssetsPath ?: SaoqiangWCAssetsObservedFilePath(image));
    NSData *raw=i.SaoqiangWCAssetsSnapshotOnly ? nil : i.SaoqiangWCAssetsRawSourceData;
    return @{@"name":i.SaoqiangWCAssetsName?:@"无原始资源名",@"source":i.SaoqiangWCAssetsSource?:@"可见素材",@"path":path?:@"",@"raw":raw?:NSData.data,@"svg":@(i.SaoqiangWCAssetsSVG),@"bubble":@(i.SaoqiangWCAssetsVerifiedBubble),@"revision":@(i.SaoqiangWCAssetsRevision)};
}
- (SaoqiangWCAssetsRecord *)SaoqiangWCAssetsBuild:(UIImage *)image source:(NSDictionary *)info size:(CGSize)size {
    NSData *raw=info[@"raw"]; NSString *path=info[@"path"];
    BOOL fileSource=NO;
    if (!raw.length && path.length && [path isEqual:SaoqiangWCAssetsObservedFilePath(image)]) { raw=SaoqiangWCAssetsRead(path); fileSource=raw.length>0; }
    NSString *kind=SaoqiangWCAssetsKind(raw,@"svg"); if ([kind isEqual:@"OTHER"]) raw=nil;
    // 0.11.44: only encode a PNG when there is no original byte stream. The old
    // code re-rendered every icon unconditionally and then dropped the result
    // whenever `raw` existed — a full UIGraphicsImageRenderer + PNG encode per
    // captured icon, which is exactly the background churn that dropped frames.
    NSData *rendered=raw.length?nil:SaoqiangWCAssetsRender(image); if (!raw.length && !rendered.length) return nil;
    SaoqiangWCAssetsRecord *r=[SaoqiangWCAssetsRecord new]; r.bytes=raw.length?raw:rendered; r.original=raw.length>0;
    r.renderedBytes=raw.length?rendered:nil; r.kind=raw.length?kind:@"PNG"; r.extension=[r.kind isEqual:@"SVG"]?@"svg":([r.kind isEqual:@"JPEG"]?@"jpg":@"png");
    r.name=info[@"name"]; r.source=info[@"source"]; r.svgResource=[info[@"svg"] boolValue]||[r.kind isEqual:@"SVG"]; r.bubble=[info[@"bubble"] boolValue];
    if (!r.name.length) r.name=@"无原始资源名";
    r.provenance=r.original?(fileSource?@"实际加载路径读取的原始文件":@"同一次加载取得的原始数据"):@"只有界面图片，保存为 PNG 快照；原文件未取得";
    r.origin=@"runtime"; r.collectionID=@"page"; r.themeName=@"";
    r.pointSize=size.width>0&&size.height>0?size:image.size; r.pixelSize=CGSizeMake(image.size.width*image.scale,image.size.height*image.scale);
    r.capInsets=image.capInsets; r.resizingMode=image.resizingMode;
    r.thumbnail=SaoqiangWCAssetsThumbnail(rendered?:r.bytes) ?: SaoqiangWCAssetsThumbnailImage(image);
    NSString *key=[NSString stringWithFormat:@"%@|%@|%@|%.2fx%.2f|%@",r.name,r.kind,SaoqiangWCAssetsHash(r.bytes),r.pointSize.width,r.pointSize.height,NSStringFromUIEdgeInsets(r.capInsets)];
    r.identity=SaoqiangWCAssetsHash([key dataUsingEncoding:NSUTF8StringEncoding]); return r;
}
- (void)SaoqiangWCAssetsEnqueueVisibleImage:(UIImage *)image displaySize:(CGSize)size { [self SaoqiangWCAssetsEnqueueVisibleImage:image displaySize:size name:nil source:nil]; }
- (void)SaoqiangWCAssetsEnqueueVisibleImage:(UIImage *)image displaySize:(CGSize)size name:(NSString *)explicitName source:(NSString *)explicitSource {
    if (!image || SaoqiangWCAssetsIsSuppressed() || SaoqiangWCAssetsIsOwnImage(image)) return;
    NSDictionary *info=[self SaoqiangWCAssetsSourceSnapshot:image];
    if (!info && explicitName.length) info=@{@"name":explicitName,@"source":explicitSource?:@"可见资源",@"path":@"",@"raw":NSData.data,@"svg":@NO,@"bubble":@([explicitSource hasPrefix:@"可见消息气泡"]),@"revision":@0};
    if (!info) return;
    if (!isfinite(size.width)||!isfinite(size.height)||size.width<=0||size.height<=0) size=image.size;
    NSString *signature=[NSString stringWithFormat:@"%@|%.2fx%.2f",info[@"revision"],size.width,size.height];
    [_lock lock]; NSDictionary *prior=[_seen objectForKey:image];
    if (!_enabled || _pending>=32 || ([prior[@"signature"] isEqual:signature] && [prior[@"epoch"] unsignedIntegerValue]==_epoch)) { if (_pending>=32) ++_dropped; [_lock unlock]; return; }
    if (_seen.count>1024) [_seen removeAllObjects];
    NSString *captureKey=prior[@"captureKey"]?:NSUUID.UUID.UUIDString;
    if (prior && ![prior[@"size"] isEqual:NSStringFromCGSize(size)]) captureKey=NSUUID.UUID.UUIDString;
    [_seen setObject:@{@"signature":signature,@"captureKey":captureKey,@"size":NSStringFromCGSize(size),@"epoch":@(_epoch)} forKey:image];
    NSUInteger epoch=_epoch; NSString *session=_runtimeSession; ++_pending; [_lock unlock];
    dispatch_async(_queue,^{ @autoreleasepool {
        SaoqiangWCAssetsPushSuppression();
        @try {
            [_lock lock]; BOOL valid=_enabled&&epoch==_epoch; [_lock unlock];
            SaoqiangWCAssetsRecord *r=valid?[self SaoqiangWCAssetsBuild:image source:info size:size]:nil;
            if (r) {
                r.sessionID=session; r.captureKey=captureKey;
                // Keep one record per actual resource bytes/name; page changes only extend the list.
                r.collectionID=[info[@"bubble"] boolValue] ? @"bubble" : @"page";
                [_lock lock]; NSUInteger replace=NSNotFound; BOOL same=NO;
                for (NSUInteger j=0;j<_records.count;j++) {
                    SaoqiangWCAssetsRecord *old=_records[j];
                    if ([old.identity isEqual:r.identity]) {
                        same=YES;
                        NSDictionary *cached=[_seen objectForKey:image];
                        if (old.captureKey.length && [cached[@"signature"] isEqual:signature]) {
                            NSMutableDictionary *updated=[cached mutableCopy];updated[@"captureKey"]=old.captureKey;[_seen setObject:updated forKey:image];
                        }
                        break;
                    }
                    if ([old.captureKey isEqual:captureKey]) replace=j;
                }
                NSUInteger oldBytes=replace==NSNotFound?0:((SaoqiangWCAssetsRecord *)_records[replace]).bytes.length+((SaoqiangWCAssetsRecord *)_records[replace]).renderedBytes.length;
                BOOL room=_records.count<1000 && _total-oldBytes+r.bytes.length+r.renderedBytes.length<=SaoqiangWCAssetsMaxTotal;
                if (_enabled&&epoch==_epoch&&!same&&room) { if (replace!=NSNotFound) {_records[replace]=r; _total-=oldBytes;} else [_records addObject:r]; _total+=r.bytes.length+r.renderedBytes.length; ++_revision; }
                else if (!same&&!room) ++_dropped;
                [_lock unlock];
                SaoqiangWCAssetsSetImageIdentityForRevision(image,r.identity,[info[@"revision"] unsignedIntegerValue]);
            }
        } @finally { SaoqiangWCAssetsPopSuppression(); [_lock lock]; --_pending; [_lock unlock]; }
    } });
}
- (void)SaoqiangWCAssetsEnqueueImage:(UIImage *)image name:(NSString *)name source:(NSString *)source path:(NSString *)path svg:(BOOL)svg {
    // Loading is metadata only; the visible-page sampler decides what enters the list.
}
- (void)SaoqiangWCAssetsEnqueueImage:(UIImage *)image name:(NSString *)name source:(NSString *)source path:(NSString *)path svg:(BOOL)svg completion:(void (^)(NSString *))completion { completion(nil); }
- (void)SaoqiangWCAssetsResolveTrustedImage:(UIImage *)image completion:(void (^)(SaoqiangWCAssetsRecord *,NSString *))completion {
    NSDictionary *info=[self SaoqiangWCAssetsSourceSnapshot:image];
    if (!info) { dispatch_async(dispatch_get_main_queue(),^{completion(nil,@"未识别到这个图标的资源名称，请重新打开该页面后再试。");}); return; }
    NSString *session=[self SaoqiangWCAssetsCollectionState][@"runtimeID"];
    dispatch_async(_queue,^{ @autoreleasepool {
        SaoqiangWCAssetsPushSuppression(); SaoqiangWCAssetsRecord *r=nil;
        @try { r=[self SaoqiangWCAssetsBuild:image source:info size:image.size]; r.sessionID=session; }
        @finally { SaoqiangWCAssetsPopSuppression(); }
        dispatch_async(dispatch_get_main_queue(),^{completion(r,r?nil:@"名称已识别，但图片数据暂时无法保存。");});
    } });
}
// Whole-theme collection is deliberately paused in this page-capture release.
- (void)SaoqiangWCAssetsScanBundle {}
- (void)SaoqiangWCAssetsCaptureNow { [self SaoqiangWCAssetsSetEnabled:YES]; }
- (void)SaoqiangWCAssetsRegisterThemeRoot:(NSString *)root name:(NSString *)name source:(NSString *)source {}
- (void)SaoqiangWCAssetsClearThemeContext {}
- (void)SaoqiangWCAssetsEnqueueThemeData:(NSData *)data name:(NSString *)name source:(NSString *)source {}
- (void)SaoqiangWCAssetsEnqueueSVGData:(NSData *)data name:(NSString *)name source:(NSString *)source image:(UIImage *)image {}
- (NSDictionary *)SaoqiangWCAssetsMetadata:(SaoqiangWCAssetsRecord *)r {
    return @{@"name":r.name?:@"",@"kind":r.kind?:@"",@"original":@(r.original),@"snapshot":@(!r.original),@"bubble":@(r.bubble),@"source":r.source?:@"",@"provenance":r.provenance?:@"",@"pointSize":NSStringFromCGSize(r.pointSize),@"pixelSize":NSStringFromCGSize(r.pixelSize),@"capInsets":NSStringFromUIEdgeInsets(r.capInsets),@"resizingMode":@(r.resizingMode),@"origin":@"runtime"};
}

static NSString *SaoqiangWCAssetsSafeName(NSString *name) {
    NSString *base = name.lastPathComponent;
    if ([@[@"png", @"svg", @"jpg", @"jpeg", @"bin"] containsObject:base.pathExtension.lowercaseString]) base = base.stringByDeletingPathExtension;
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < MIN(base.length, 120); i++) {
        unichar c = [base characterAtIndex:i]; BOOL ok = c >= 32 && c != 127 && c != '/' && c != '\\' && c != ':';
        [out appendFormat:@"%C", (unichar)(ok ? c : '_')];
    }
    while ([out containsString:@".."]) [out replaceOccurrencesOfString:@".." withString:@"_" options:0 range:NSMakeRange(0,out.length)];
    if ([out isEqual:@"."] || !out.length) return @"asset";
    return out;
}
- (NSURL *)SaoqiangWCAssetsExportDirectory:(NSError **)error {
    NSURL *base = [NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = [base URLByAppendingPathComponent:@"SaoqiangWCAssetsExports" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:error]; return dir;
}
- (void)SaoqiangWCAssetsExport:(SaoqiangWCAssetsRecord *)record rendered:(BOOL)rendered completion:(void (^)(NSURL *, NSString *))completion {
    if (!record) { dispatch_async(dispatch_get_main_queue(), ^{ completion(nil,@"没有选中的素材"); }); return; }
    dispatch_async(_queue, ^{ @autoreleasepool {
        NSData *data = rendered ? record.renderedBytes : record.bytes; NSString *ext = rendered ? @"png" : record.extension;
        if (rendered && !data.length && record.original && ![record.kind isEqual:@"SVG"]) data = SaoqiangWCAssetsRender([UIImage imageWithData:record.bytes]);
        if (!data.length || data.length > SaoqiangWCAssetsMaxFile) { dispatch_async(dispatch_get_main_queue(), ^{ completion(nil,@"素材没有可导出的数据"); }); return; }
        NSError *error = nil; NSURL *base = [self SaoqiangWCAssetsExportDirectory:&error];
        NSURL *dir = [base URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
        BOOL made = !error && [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:&error];
        NSURL *url = made ? [dir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", SaoqiangWCAssetsSafeName(record.name), ext]] : nil;
        if (!url || ![data writeToURL:url options:NSDataWritingAtomic error:&error]) url = nil;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(url, error.localizedDescription); });
    } });
}
- (NSData *)SaoqiangWCAssetsExportDiagnostics {
    NSMutableDictionary *d = [NSMutableDictionary new];
    NSDictionary *strings = @{@"svg":SaoqiangWCAssetsSVGDiagnostics(), @"bubbles":SaoqiangWCAssetsBubbleDiagnostics(), @"theme":SaoqiangWCAssetsThemeDiagnostics()};
    for (NSString *key in strings) { NSData *data = [strings[key] dataUsingEncoding:NSUTF8StringEncoding]; d[key] = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil] ?: strings[key]; }
    return [NSJSONSerialization dataWithJSONObject:d options:NSJSONWritingPrettyPrinted error:nil];
}
- (NSDictionary<NSString *, NSData *> *)SaoqiangWCAssetsExportContents:(NSArray<SaoqiangWCAssetsRecord *> *)records diagnostics:(NSData *)diagnostics error:(NSError **)error {
    NSMutableDictionary *files = [NSMutableDictionary new]; NSMutableArray *manifest = [NSMutableArray new]; NSMutableSet *used = [NSMutableSet new];
    NSArray *sorted = [records sortedArrayUsingComparator:^NSComparisonResult(SaoqiangWCAssetsRecord *a,SaoqiangWCAssetsRecord *b) { NSComparisonResult r = [a.name compare:b.name]; return r == NSOrderedSame ? [a.identity compare:b.identity] : r; }];
    for (SaoqiangWCAssetsRecord *r in sorted) {
        if (!r.bytes.length) continue;
        NSString *kind = r.extension.length ? r.extension : @"bin";
        NSString *base = SaoqiangWCAssetsSafeName(r.name), *file = [NSString stringWithFormat:@"%@.%@",base,kind];
        if ([used containsObject:file.lowercaseString]) {
            NSString *hash = [SaoqiangWCAssetsHash(r.bytes) substringToIndex:8]; file = [NSString stringWithFormat:@"%@-%@.%@",base,hash,kind];
            NSUInteger suffix = 1; while ([used containsObject:file.lowercaseString]) file = [NSString stringWithFormat:@"%@-%@-%lu.%@",base,hash,(unsigned long)suffix++,kind];
        }
        [used addObject:file.lowercaseString]; files[file] = r.bytes;
        NSMutableDictionary *row = [[self SaoqiangWCAssetsMetadata:r] mutableCopy]; row[@"file"] = file; row[@"sha256"] = SaoqiangWCAssetsHash(r.bytes);
        row[@"snapshot"] = @(!r.original); row[@"originalNameAvailable"] = @(![r.name containsString:@"无原名"] && ![r.name containsString:@"无原始资源名"]);
        [manifest addObject:row];
    }
    if (!manifest.count) { if (error) *error = [NSError errorWithDomain:@"SaoqiangWCAssets" code:2 userInfo:@{NSLocalizedDescriptionKey:@"没有可导出的素材字节"}]; return nil; }
    NSData *json = [NSJSONSerialization dataWithJSONObject:@{@"format":@"Saoqiang-WeChat-Assets-2", @"purpose":@"所选页面图标及气泡；snapshot=true 是渲染结果，不是原文件", @"count":@(manifest.count), @"items":manifest} options:NSJSONWritingPrettyPrinted error:error];
    if (!json) return nil;
    files[@"manifest.json"] = json; if (diagnostics) files[@"recognition-diagnostic.json"] = diagnostics;
    return files;
}
- (NSString *)SaoqiangWCAssetsExportTitle:(NSArray<SaoqiangWCAssetsRecord *> *)records {
    NSDateFormatter *format = [NSDateFormatter new]; format.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]; format.dateFormat = @"yyyyMMdd-HHmmss";
    return [format stringFromDate:NSDate.date];
}
- (void)SaoqiangWCAssetsExportFolder:(NSArray<SaoqiangWCAssetsRecord *> *)records completion:(void (^)(NSURL *,NSString *))completion {
    NSArray *snapshot = [records copy]; NSData *diagnostics = [self SaoqiangWCAssetsExportDiagnostics];
    dispatch_async(_queue, ^{ @autoreleasepool {
        NSError *error = nil; NSDictionary *files = [self SaoqiangWCAssetsExportContents:snapshot diagnostics:diagnostics error:&error];
        NSURL *base = files ? [self SaoqiangWCAssetsExportDirectory:&error] : nil;
        NSURL *session = [base URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
        NSURL *folder = [session URLByAppendingPathComponent:[self SaoqiangWCAssetsExportTitle:snapshot] isDirectory:YES];
        if (files && !error && [NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:&error]) {
            for (NSString *name in files) {
                NSURL *url = [folder URLByAppendingPathComponent:name];
                if (![NSFileManager.defaultManager createDirectoryAtURL:url.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&error] || ![files[name] writeToURL:url options:NSDataWritingAtomic error:&error]) break;
            }
        }
        if (error || !files) { if (session) [NSFileManager.defaultManager removeItemAtURL:session error:nil]; folder = nil; }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(folder,error.localizedDescription); });
    } });
}
- (void)SaoqiangWCAssetsExportMany:(NSArray<SaoqiangWCAssetsRecord *> *)records completion:(void (^)(NSURL *,NSString *))completion {
    NSArray *snapshot = [records copy]; NSData *diagnostics = [self SaoqiangWCAssetsExportDiagnostics];
    dispatch_async(_queue, ^{ @autoreleasepool {
        NSError *error = nil;
        __attribute__((objc_precise_lifetime)) NSDictionary<NSString *,NSData *> *files = [self SaoqiangWCAssetsExportContents:snapshot diagnostics:diagnostics error:&error];
        __attribute__((objc_precise_lifetime)) NSArray<NSString *> *names = [files.allKeys sortedArrayUsingSelector:@selector(compare:)];
        NSURL *base = files ? [self SaoqiangWCAssetsExportDirectory:&error] : nil;
        NSURL *dir = [base URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
        BOOL made = dir && !error && [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:&error];
        NSURL *url = made ? [dir URLByAppendingPathComponent:[[self SaoqiangWCAssetsExportTitle:snapshot] stringByAppendingPathExtension:@"zip"]] : nil;
        SaoqiangWCAssetsZIPEntry *entries = names.count ? calloc(names.count,sizeof(*entries)) : NULL;
        if (entries) for (NSUInteger i=0;i<names.count;i++) { NSData *data = files[names[i]]; entries[i] = (SaoqiangWCAssetsZIPEntry){names[i].UTF8String,data.bytes,data.length}; }
        char message[256] = {0}; int status = url && entries ? SaoqiangWCAssetsWriteZIP(url.fileSystemRepresentation,entries,names.count,message,sizeof(message)) : -1;
        free(entries);
        if (status) { if (dir) [NSFileManager.defaultManager removeItemAtURL:dir error:nil]; url = nil; error = error ?: [NSError errorWithDomain:@"SaoqiangWCAssets" code:1 userInfo:@{NSLocalizedDescriptionKey:message[0] ? @(message) : @"无法生成素材 ZIP"}]; }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(url,error.localizedDescription); });
    } });
}
@end
