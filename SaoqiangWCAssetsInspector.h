#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class SaoqiangWCAssetsRecord;

// Metadata never owns a source UIImage or a Store record. Weak UIImage index:512.
// Original byte cache:8MB/64 entries, 2MB/item. Exact retained CGImage index:64/8MB.
// NSData provenance is weak-key/object-identity based (256 entries), never pixel matching.
@interface SaoqiangWCAssetsImageInfo : NSObject
@property(nonatomic, copy) NSString *SaoqiangWCAssetsName;
@property(nonatomic, copy) NSString *SaoqiangWCAssetsSource;
@property(nonatomic, copy, nullable) NSString *SaoqiangWCAssetsPath;
@property(nonatomic, copy, nullable) NSString *SaoqiangWCAssetsIdentity;
@property(nonatomic, readonly) NSUInteger SaoqiangWCAssetsRevision;
@property(nonatomic) BOOL SaoqiangWCAssetsSVG;
@property(nonatomic) BOOL SaoqiangWCAssetsVerifiedBubble;
@property(nonatomic) BOOL SaoqiangWCAssetsSnapshotOnly;
@property(nonatomic, strong, nullable) NSData *SaoqiangWCAssetsRawSVG;
@property(nonatomic, strong, nullable) NSData *SaoqiangWCAssetsRawSourceData;
@property(nonatomic) UIEdgeInsets SaoqiangWCAssetsCapInsets;
@property(nonatomic) UIImageResizingMode SaoqiangWCAssetsResizingMode;
@end

// Exact stem plus supported extension alias; preserve case, directories, scale and state.
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsSameResourceName(NSString * _Nullable a, NSString * _Nullable b);
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsSafeRendererName(NSString * _Nullable name);
// Only use within one proven named invocation: request -> concrete @2x/@3x file.
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsRequestMatchesFile(NSString * _Nullable request, NSString * _Nullable actual);
FOUNDATION_EXPORT void SaoqiangWCAssetsAssociateNamedData(NSData *data, NSString *name, NSString *source, BOOL bubble);
FOUNDATION_EXPORT void SaoqiangWCAssetsAssociateDecodedImage(UIImage *image, NSData *data);
FOUNDATION_EXPORT void SaoqiangWCAssetsRememberBacking(UIImage *image);
FOUNDATION_EXPORT void SaoqiangWCAssetsAssociateNamedImage(UIImage *image, NSString *name, NSString *source, NSString * _Nullable path, BOOL svg);
// Call only after exact ABI / host-origin validation of a named SVG renderer.
FOUNDATION_EXPORT void SaoqiangWCAssetsAssociateRenderedSVG(UIImage *image, NSString *name, NSString *source, NSData * _Nullable raw);
FOUNDATION_EXPORT void SaoqiangWCAssetsAssociateSourceImage(UIImage *image, NSString *name, NSData * _Nullable data, NSString *source, BOOL candidateBubble);
FOUNDATION_EXPORT UIImage * _Nullable SaoqiangWCAssetsImageForLayer(CALayer *layer);
// These candidates are deliberately separate from trusted/collectable metadata.
FOUNDATION_EXPORT void SaoqiangWCAssetsAssociateBubbleCandidate(UIImage *image, NSString *name);
FOUNDATION_EXPORT NSString * _Nullable SaoqiangWCAssetsBubbleCandidateName(UIImage *image);
FOUNDATION_EXPORT SaoqiangWCAssetsImageInfo * _Nullable SaoqiangWCAssetsImageInfoForImage(UIImage * _Nullable image);
FOUNDATION_EXPORT void SaoqiangWCAssetsSetImageIdentity(UIImage *image, NSString *identity);
// Store may capture info.Revision at enqueue and use this to reject stale writes.
FOUNDATION_EXPORT void SaoqiangWCAssetsSetImageIdentityForRevision(UIImage *image, NSString *identity, NSUInteger revision);
// Observing a file path alone never makes an image trusted or adds a record.
FOUNDATION_EXPORT void SaoqiangWCAssetsAssociateFilePath(UIImage *image, NSString *path);
FOUNDATION_EXPORT NSString * _Nullable SaoqiangWCAssetsObservedFilePath(UIImage *image);
// Only call from a runtime-validated bubble background or an evidenced named owner.
FOUNDATION_EXPORT void SaoqiangWCAssetsAssociateBubbleImage(UIImage *image, NSString * _Nullable name, NSString *source);
// Only a proven toolbar/button icon context may request an unnamed UI snapshot.
FOUNDATION_EXPORT void SaoqiangWCAssetsAssociateVisibleIcon(UIImage *image, NSString *source, NSString * _Nullable name);
// 0.11.42: exact CGImage → resource-name memo filled by the image hooks even
// while the capture session is off. Lets a layer snapshot (WeChat draws many
// icons straight into layer.contents) keep the name it was loaded under.
FOUNDATION_EXPORT NSString * _Nullable SaoqiangWCAssetsMemoizedNameForCGImage(CGImageRef _Nullable cg);
// 0.11.41: images that were decoded before the capture session started carry no
// metadata. UIImage keeps the asset name in its own private storage; recovering
// it lets those already-cached icons keep their real resource name instead of
// showing「无原始资源名」. Read-only, validated, cached per image object.
FOUNDATION_EXPORT NSString * _Nullable SaoqiangWCAssetsRecoveredImageName(UIImage * _Nullable image);
FOUNDATION_EXPORT void SaoqiangWCAssetsDiscoverBubbles(void);
FOUNDATION_EXPORT NSString *SaoqiangWCAssetsBubbleDiagnostics(void);
FOUNDATION_EXPORT void SaoqiangWCAssetsPropagateImageInfo(UIImage *input, UIImage *output, NSString *operation);
FOUNDATION_EXPORT void SaoqiangWCAssetsMarkOwnView(UIView *view);
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsIsOwnView(UIView * _Nullable view);
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsInspectorEnabled(void);
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsInspectorUIActive(void);
// Fast, allocation-free hint for the per-image-load capture gate.
FOUNDATION_EXPORT void SaoqiangWCAssetsNoteOwnUI(BOOL visible);
// An explicit page pass must re-read every bubble: a late-arriving original name
// is attached to metadata, not to layer contents, so caching would hide it.
FOUNDATION_EXPORT void SaoqiangWCAssetsBubbleSetExplicitCapture(BOOL explicitCapture);
FOUNDATION_EXPORT void SaoqiangWCAssetsSetInspectorEnabled(BOOL enabled, UIWindow * _Nullable window);
FOUNDATION_EXPORT void SaoqiangWCAssetsInspectorAttach(UIWindow *window);
FOUNDATION_EXPORT void SaoqiangWCAssetsPresentRecord(SaoqiangWCAssetsRecord *record, UIViewController *presenter);
NS_ASSUME_NONNULL_END
