#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
// Installs passive, ABI/UUID-verified observers. Never calls provider getters.
FOUNDATION_EXPORT void SaoqiangWCAssetsDiscoverTheme(void);
FOUNDATION_EXPORT NSString *SaoqiangWCAssetsThemeDiagnostics(void);
// Compatibility stub: passive capture does not discover a theme directory.
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsIsActiveThemePath(NSString * _Nullable path);
// These helpers only attach metadata. No data-only observation adds a record.
// A scope lives on the calling thread for exactly one original IMP invocation.
FOUNDATION_EXPORT id _Nullable SaoqiangWCAssetsCallNamedSource(NSString *name, NSString *source, BOOL candidateBubble, id _Nullable (^invoke)(void));
FOUNDATION_EXPORT void SaoqiangWCAssetsObserveSourceData(NSString *name, NSData *data);
// 3.0.8 ThemeBox exposes decrypted bytes through runtime cache interfaces.
// These records are bounded, scoped to the active theme root, and never imply
// that the opaque container has a complete public filename enumeration.
FOUNDATION_EXPORT void SaoqiangWCAssetsThemeSetCaptureRoot(NSString * _Nullable root);
FOUNDATION_EXPORT void SaoqiangWCAssetsThemeRefreshCaptureRoot(void);
FOUNDATION_EXPORT void SaoqiangWCAssetsThemeRecordDecodedData(NSString *name, NSData *data, NSString * _Nullable source);
FOUNDATION_EXPORT NSArray<NSDictionary *> *SaoqiangWCAssetsThemeCapturedSnapshot(NSString *root);
NS_ASSUME_NONNULL_END
