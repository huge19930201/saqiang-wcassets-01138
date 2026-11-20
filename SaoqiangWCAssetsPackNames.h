#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// Every base name the two reference packs contain, and the concrete file names a
// shipped pack can spell them as. Used only as a candidate list: the provider's
// decryptor decides which of them actually exist in the applied theme.
FOUNDATION_EXPORT NSArray<NSString *> *SaoqiangWCAssetsPackBaseNames(void);
FOUNDATION_EXPORT NSArray<NSString *> *SaoqiangWCAssetsPackNameCandidates(void);
NS_ASSUME_NONNULL_END
