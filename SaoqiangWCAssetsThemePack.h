#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// Original-file export. Available files can be saved even when some entries fail;
// summary.complete is distinct from summary.available. Cancellation/source changes abort.
typedef void (^SaoqiangWCAssetsThemePackCompletion)(NSURL * _Nullable directory, NSDictionary *summary, NSString * _Nullable error);
FOUNDATION_EXPORT NSDictionary *SaoqiangWCAssetsThemePackState(void);
FOUNDATION_EXPORT void SaoqiangWCAssetsExportCurrentTheme(SaoqiangWCAssetsThemePackCompletion completion);
FOUNDATION_EXPORT void SaoqiangWCAssetsCancelThemeExport(void);
FOUNDATION_EXPORT NSDictionary *SaoqiangWCAssetsCurrentThemeReferenceState(void);
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsImportCurrentThemeReference(NSData *data, NSString *expectedThemeID, NSString * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsClearCurrentThemeReference(NSString * _Nullable * _Nullable error);
#if defined(SAOQIANG_WCASSETS_TESTING)
FOUNDATION_EXPORT void SaoqiangWCAssetsExportThemeEngineFixture(Class manager,Class legacyLoader,Class assets,Class _Nullable util,SaoqiangWCAssetsThemePackCompletion completion);
FOUNDATION_EXPORT NSDictionary * _Nullable SaoqiangWCAssetsThemeProviderFixture(Class _Nullable manager, Class _Nullable util, BOOL includeList, NSString * _Nullable * _Nullable error);
FOUNDATION_EXPORT void SaoqiangWCAssetsExportThemeLoaderFixture(Class manager,Class loader,Class _Nullable util,SaoqiangWCAssetsThemePackCompletion completion);
FOUNDATION_EXPORT void SaoqiangWCAssetsExportThemeSourcesFixture(Class manager,Class loader,Class _Nullable util,Class _Nullable bubbleManager,Class _Nullable bubbleAssets,Class _Nullable bubbleConfig,SaoqiangWCAssetsThemePackCompletion completion);
#endif
NS_ASSUME_NONNULL_END
