#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
// Guard is per-thread: our rendering/UI must never feed back into the hooks.
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsIsSuppressed(void);
FOUNDATION_EXPORT void SaoqiangWCAssetsPushSuppression(void);
FOUNDATION_EXPORT void SaoqiangWCAssetsPopSuppression(void);
FOUNDATION_EXPORT void SaoqiangWCAssetsMarkOwnImage(UIImage *image);
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsIsOwnImage(UIImage *image);
FOUNDATION_EXPORT void SaoqiangWCAssetsInstallUI(void);
FOUNDATION_EXPORT void SaoqiangWCAssetsInstallImageHooks(void);
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsOwnUIActive(void);
// The master switch is persisted and read on every hot path: one relaxed load.
// The dylib stays injected with the switch off; nothing captures, nothing walks
// the view hierarchy, and every hooked method goes straight to its original.
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsMasterEnabled(void);
FOUNDATION_EXPORT void SaoqiangWCAssetsSetMasterEnabled(BOOL enabled);
FOUNDATION_EXPORT void SaoqiangWCAssetsMasterLoad(void);
// Two feature gates under the master switch. Icon naming covers the four list
// tabs; theme capture covers the former 工具 tab, now called 抓取主题.
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsIconCaptureEnabled(void);
FOUNDATION_EXPORT void SaoqiangWCAssetsSetIconCaptureEnabled(BOOL enabled);
// The icon switch only makes the feature available; the in-panel 开始抓取
// button decides whether capture actually runs. Unlike the feature switches,
// this session state is never persisted and starts off on every launch.
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsIconCapturing(void);
FOUNDATION_EXPORT void SaoqiangWCAssetsSetIconCapturing(BOOL capturing);
// Hot-path gate: feature enabled AND a capture session running.
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsIconCaptureActive(void);
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsThemeCaptureEnabled(void);
FOUNDATION_EXPORT void SaoqiangWCAssetsSetThemeCaptureEnabled(BOOL enabled);
// Opens the panel from the plugin list entry. Presenter may be nil.
FOUNDATION_EXPORT void SaoqiangWCAssetsPresentPanel(UIViewController * _Nullable presenter);
// Keep in sync with the Version field in `control`.
#define SAOQIANG_WCASSETS_VERSION @"0.11.45"
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsUIName(NSString * _Nullable name);
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsBubbleName(NSString * _Nullable name);
FOUNDATION_EXPORT void SaoqiangWCAssetsDiscoverSVG(void);
FOUNDATION_EXPORT NSString *SaoqiangWCAssetsSVGDiagnostics(void);
FOUNDATION_EXPORT void SaoqiangWCAssetsCaptureVisiblePage(void);
FOUNDATION_EXPORT void SaoqiangWCAssetsInstallPageCapture(void);
FOUNDATION_EXPORT NSString *SaoqiangWCAssetsPageDiagnostics(void);
FOUNDATION_EXPORT void SaoqiangWCAssetsInspectBubbleCell(UIView *view);

@interface SaoqiangWCAssetsRecord : NSObject
@property(nonatomic, copy) NSString *identity;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *source;
@property(nonatomic, copy) NSString *kind;
@property(nonatomic, copy) NSString *provenance;
@property(nonatomic, copy) NSString *extension;
@property(nonatomic, strong) NSData *bytes;
@property(nonatomic, strong, nullable) NSData *renderedBytes;
@property(nonatomic) BOOL svgResource;
@property(nonatomic, strong, nullable) UIImage *thumbnail;
@property(nonatomic) BOOL original;
@property(nonatomic) BOOL bubble;
@property(nonatomic) UIEdgeInsets capInsets;
@property(nonatomic) UIImageResizingMode resizingMode;
// Captured pixels and package assets stay separate; theme keys prevent mixing themes.
@property(nonatomic, copy) NSString *origin;
@property(nonatomic, copy) NSString *collectionID;
@property(nonatomic, copy) NSString *sessionID;
@property(nonatomic, copy) NSString *themeName;
@property(nonatomic) CGSize pixelSize;
@property(nonatomic) CGSize pointSize;
@property(nonatomic, copy) NSString *captureKey;
@end

@interface SaoqiangWCAssetsStore : NSObject
+ (instancetype)SaoqiangWCAssetsShared;
- (BOOL)SaoqiangWCAssetsEnabled;
- (void)SaoqiangWCAssetsSetEnabled:(BOOL)enabled;
// 0.11.44: monotonic change counter. The panel compares it instead of rebuilding
// the whole row list once a second while nothing has actually changed.
- (NSUInteger)SaoqiangWCAssetsRevision;
- (void)SaoqiangWCAssetsClear;
- (NSArray<SaoqiangWCAssetsRecord *> *)SaoqiangWCAssetsSnapshot;
- (void)SaoqiangWCAssetsAfterPending:(dispatch_block_t)completion;
- (NSString *)SaoqiangWCAssetsStatus;
- (void)SaoqiangWCAssetsEnqueueImage:(UIImage *)image name:(NSString *)name
                            source:(NSString *)source path:(nullable NSString *)path svg:(BOOL)svg;
- (void)SaoqiangWCAssetsEnqueueImage:(UIImage *)image name:(NSString *)name
                            source:(NSString *)source path:(nullable NSString *)path svg:(BOOL)svg
                         completion:(void (^)(NSString * _Nullable identity))completion;
- (void)SaoqiangWCAssetsResolveTrustedImage:(UIImage *)image
                                completion:(void (^)(SaoqiangWCAssetsRecord * _Nullable record, NSString * _Nullable error))completion;
- (void)SaoqiangWCAssetsExportMany:(NSArray<SaoqiangWCAssetsRecord *> *)records completion:(void (^)(NSURL * _Nullable, NSString * _Nullable))completion;
- (void)SaoqiangWCAssetsScanBundle;
- (NSDictionary *)SaoqiangWCAssetsCollectionState;
- (void)SaoqiangWCAssetsCaptureNow;
- (void)SaoqiangWCAssetsRegisterThemeRoot:(NSString *)root name:(NSString *)name source:(NSString *)source;
- (void)SaoqiangWCAssetsClearThemeContext;
- (void)SaoqiangWCAssetsEnqueueThemeData:(NSData *)data name:(NSString *)name source:(NSString *)source;
- (void)SaoqiangWCAssetsExportFolder:(NSArray<SaoqiangWCAssetsRecord *> *)records completion:(void (^)(NSURL * _Nullable, NSString * _Nullable))completion;
- (void)SaoqiangWCAssetsSetAppActive:(BOOL)active;
- (void)SaoqiangWCAssetsSetPageKey:(NSString *)pageKey;
- (void)SaoqiangWCAssetsEnqueueVisibleImage:(UIImage *)image displaySize:(CGSize)size;
- (void)SaoqiangWCAssetsEnqueueVisibleImage:(UIImage *)image displaySize:(CGSize)size name:(nullable NSString *)name source:(nullable NSString *)source;
- (void)SaoqiangWCAssetsEnqueueSVGData:(NSData *)data name:(NSString *)name source:(NSString *)source image:(nullable UIImage *)image;
- (void)SaoqiangWCAssetsExport:(SaoqiangWCAssetsRecord *)record rendered:(BOOL)rendered
                  completion:(void (^)(NSURL * _Nullable, NSString * _Nullable))completion;
@end
NS_ASSUME_NONNULL_END
