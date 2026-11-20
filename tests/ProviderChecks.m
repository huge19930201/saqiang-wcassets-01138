#import "ProviderChecks.h"
#import "SaoqiangWCAssetsThemePack.h"
#import "SaoqiangWCAssetsInspector.h"
#import <stdlib.h>

// Identity tests intentionally make no resource-list/completeness claims.
static id PCPath, PCInfo;
static NSUInteger PCInvalidCalls, PCAssertions;
@interface SaoqiangWCTestManager : NSObject
+ (instancetype)shared;
- (id)currentThemePath;
- (id)currentThemeInfo;
- (BOOL)loadTheme;
@end
@implementation SaoqiangWCTestManager
+ (instancetype)shared { static id instance; static dispatch_once_t once; dispatch_once(&once, ^{ instance = [self new]; }); return instance; }
- (id)currentThemePath { return PCPath; }
- (id)currentThemeInfo { return PCInfo; }
- (BOOL)loadTheme { return YES; }
@end
@interface SaoqiangWCTestInfo : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *themeId;
@property(nonatomic, copy) NSString *path;
@end
@implementation SaoqiangWCTestInfo
@end
@interface SaoqiangWCTestInfoOnly : NSObject
+ (instancetype)shared;
- (id)currentThemeInfo;
@end
@implementation SaoqiangWCTestInfoOnly
+ (instancetype)shared { static id instance; static dispatch_once_t once; dispatch_once(&once, ^{ instance = [self new]; }); return instance; }
- (id)currentThemeInfo { return PCInfo; }
@end
@interface SaoqiangWCTestBadABI : NSObject
+ (instancetype)shared;
- (NSInteger)currentThemePath;
@end
@implementation SaoqiangWCTestBadABI
+ (instancetype)shared { static id instance; static dispatch_once_t once; dispatch_once(&once, ^{ instance = [self new]; }); return instance; }
- (NSInteger)currentThemePath { ++PCInvalidCalls; return 42; }
@end
@interface SaoqiangWCTestThrow : NSObject
+ (instancetype)shared;
- (id)currentThemePath;
@end
@implementation SaoqiangWCTestThrow
+ (instancetype)shared { static id instance; static dispatch_once_t once; dispatch_once(&once, ^{ instance = [self new]; }); return instance; }
- (id)currentThemePath { [NSException raise:@"SyntheticGetterFailure" format:@"fixture"]; return nil; }
@end
static void PCAssert(BOOL valid, NSString *message) {
    ++PCAssertions;
    if (valid) return;
    NSLog(@"PROVIDER_CHECK_FAILED %@", message);
    NSURL *documents = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    [message writeToURL:[documents URLByAppendingPathComponent:@"capture-failed.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    abort();
}
static BOOL PCContainsPointText(UIView *view) {
    if ([view isKindOfClass:UILabel.class] && [((UILabel *)view).text containsString:@"点选图标命名"]) return YES;
    for (UIView *child in view.subviews) if (PCContainsPointText(child)) return YES;
    return NO;
}
NSDictionary *SaoqiangWCAssetsRunProviderChecks(UIWindow *window) {
    PCAssertions = 0;
    PCAssert(NSThread.isMainThread, @"provider checks must run on main");
    NSMutableArray *cases = [NSMutableArray new];
    NSString *error = nil;
    PCPath = @"/fixture/Themes/active";
    PCInfo = @{@"name":@"任意版本主题", @"themeId":@"arbitrary-non-UUID-id"};
    NSDictionary *result = SaoqiangWCAssetsThemeProviderFixture(SaoqiangWCTestManager.class, Nil, YES, &error);
    PCAssert(result && !error.length, @"identity rejected an arbitrary theme version/ID");
    PCAssert([result[@"root"] isEqual:PCPath], @"selected theme root lost");
    PCAssert([result[@"themeName"] isEqual:PCInfo[@"name"]] && [result[@"themeID"] isEqual:PCInfo[@"themeId"]], @"selected name/ID lost");
    PCAssert([result[@"pathSource"] isEqual:@"currentThemePath"], @"identity did not record selected path source");
    PCAssert([result[@"capabilities"] isKindOfClass:NSDictionary.class] && result[@"capabilities"][@"versionLocked"] && ![result[@"capabilities"][@"versionLocked"] boolValue], @"version lock remains active or unspecified");
    [cases addObject:@"no-version-or-UUID-lock"];

    error = nil; PCPath = [NSURL fileURLWithPath:@"/fixture/Themes/active"];
    result = SaoqiangWCAssetsThemeProviderFixture(SaoqiangWCTestManager.class, Nil, NO, &error);
    PCAssert(result && !error.length && [result[@"root"] isEqual:@"/fixture/Themes/active"], @"file URL identity was not normalized");
    [cases addObject:@"file-url-identity"];

    SaoqiangWCTestInfo *info = [SaoqiangWCTestInfo new];
    info.name = @"信息目录"; info.path = @"/fixture/Themes/info"; info.themeId = @"info-id"; PCInfo = info;
    error = nil;
    result = SaoqiangWCAssetsThemeProviderFixture(SaoqiangWCTestInfoOnly.class, Nil, NO, &error);
    PCAssert(result && !error.length && [result[@"root"] isEqual:info.path], @"currentThemeInfo.path object fallback failed");
    PCAssert([result[@"pathSource"] isEqual:@"currentThemeInfo.path"], @"fallback path source lost");
    PCAssert([result[@"themeName"] isEqual:info.name] && [result[@"themeID"] isEqual:info.themeId], @"object metadata identity lost");
    [cases addObject:@"selected-info-path-fallback"];

    PCInfo = @{};
    for (id badPath in @[@42, @"relative/active", [NSURL URLWithString:@"https://example.invalid/theme"]]) {
        error = nil; PCPath = badPath;
        result = SaoqiangWCAssetsThemeProviderFixture(SaoqiangWCTestManager.class, Nil, NO, &error);
        PCAssert(!result && error.length, @"invalid/non-file path returned usable identity");
    }
    [cases addObject:@"invalid-path-rejected"];
    error = nil;
    result = SaoqiangWCAssetsThemeProviderFixture(SaoqiangWCTestInfoOnly.class, Nil, YES, &error);
    PCAssert(!result && error.length, @"missing selected path returned usable identity");
    [cases addObject:@"missing-selected-path"];

    error = nil; PCInvalidCalls = 0;
    result = SaoqiangWCAssetsThemeProviderFixture(SaoqiangWCTestBadABI.class, Nil, YES, &error);
    PCAssert(!result && error.length, @"incompatible getter ABI returned usable identity");
    PCAssert(PCInvalidCalls == 0, @"incompatible scalar getter was invoked as an object getter");
    [cases addObject:@"incompatible-ABI-not-called"];
    error = nil;
    result = SaoqiangWCAssetsThemeProviderFixture(SaoqiangWCTestThrow.class, Nil, YES, &error);
    PCAssert(!result && error.length, @"throwing getter escaped or returned identity");
    [cases addObject:@"exception-contained"];
    error = nil;
    result = SaoqiangWCAssetsThemeProviderFixture(Nil, Nil, YES, &error);
    PCAssert(!result && error.length, @"missing manager returned usable identity");
    [cases addObject:@"missing-provider"];

    NSUInteger views = window.subviews.count;
    SaoqiangWCAssetsSetInspectorEnabled(YES, window);
    SaoqiangWCAssetsInspectorAttach(window);
    PCAssert(!SaoqiangWCAssetsInspectorEnabled() && window.subviews.count == views, @"removed point mode still intercepts touches/adds overlay");
    PCAssert(!NSClassFromString(@"SaoqiangWCAssetsPicker"), @"point picker remains in binary");
    Class controller = NSClassFromString(@"SaoqiangWCAssetsController");
    PCAssert(controller != Nil, @"tool controller missing; point-entry check would be vacuous");
    UIViewController *panel = [controller new]; [panel loadViewIfNeeded];
    PCAssert(!PCContainsPointText(panel.view), @"tool page still offers point naming");
    PCAssert(![panel respondsToSelector:NSSelectorFromString(@"SaoqiangWCAssetsStartNaming")], @"point action remains");
    [cases addObject:@"point-mode-and-entry-removed"];
    return @{@"status":@"passed", @"assertions":@(PCAssertions), @"cases":cases};
}
