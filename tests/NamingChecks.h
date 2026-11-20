#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
// Run once on the main thread, outside suppression / the plugin's own UI.
// Installs the public UIImage hooks; does not capture or alter Store records.
FOUNDATION_EXPORT void SaoqiangWCAssetsRunNamingChecks(void);
// JSON-safe, bounded report. Empty until the checks complete successfully.
FOUNDATION_EXPORT NSDictionary<NSString *, id> *SaoqiangWCAssetsNamingSummary(void);
NS_ASSUME_NONNULL_END
