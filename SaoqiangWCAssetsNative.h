#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// Adapter for the ThemeBox 3.0.8 pack. Does not modify the pack, does not
// initialise or reconfigure the provider: it asks the provider for bytes by
// name, using the Rust C ABI found in ThemeBox.dylib's symbol table. That ABI
// is not in the export trie, so it is resolved through the loaded image
// instead of dlsym.
//
// `container` is the provider's own whole-pack NSData (ThemeBoxImageLoader
// .themeData), and it is optional. When present the adapter records a digest of
// it, which is what lets the export tell "we hold the pack but only enumerated
// part of it" apart from "the pack was never readable in the first place".
FOUNDATION_EXPORT NSDictionary * _Nullable SaoqiangWCAssetsNativeIndex(NSString *root,
                                                                     NSData * _Nullable container,
                                                                     NSString * _Nullable * _Nullable error);
FOUNDATION_EXPORT NSData * _Nullable SaoqiangWCAssetsNativeRead(NSDictionary *index, NSString *name, NSString * _Nullable * _Nullable error);
// The pack's own index, if it can be read back by a plausible name. ThemeBox
// keeps its file table inside the container it decrypts itself, so a name that
// is not an image but plain text (JSON/plist) is that table. Returns nil when
// nothing plausible answered, which is the expected case on a pack whose table
// is not a separately addressable entry.
FOUNDATION_EXPORT NSDictionary * _Nullable SaoqiangWCAssetsNativePackIndex(void);
FOUNDATION_EXPORT BOOL SaoqiangWCAssetsNativeAvailable(void);
NS_ASSUME_NONNULL_END
