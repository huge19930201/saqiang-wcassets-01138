#import "FeatureChecks.h"
#import "ProviderChecks.h"
#import "SaoqiangWCAssetsThemePack.h"
#import <CoreFoundation/CoreFoundation.h>
#import <ImageIO/ImageIO.h>
#import <stdlib.h>
#import <string.h>

static NSURL *FCDocuments(void) {
    return [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
}
static void FCAssert(BOOL value, NSString *message) {
    if (value) return;
    NSLog(@"FEATURE_CHECK_FAILED %@", message);
    [message writeToURL:[FCDocuments() URLByAppendingPathComponent:@"capture-failed.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    abort();
}
static void FCMain(void) { FCAssert(NSThread.isMainThread, @"fixture/getter/completion called off main thread"); }
static NSData *FCBytes(NSString *text) { return [text dataUsingEncoding:NSUTF8StringEncoding]; }
static void FCJSON(id value, NSString *name) {
    NSError *error = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
    FCAssert(json && [json writeToURL:[FCDocuments() URLByAppendingPathComponent:name] options:NSDataWritingAtomic error:&error], error.localizedDescription ?: @"cannot save artifact");
}

// Only exact runtime loader interfaces; no Store/KVC or exporter helper bypass.
static NSString *FCRoot, *FCBoxRoot;
static NSDictionary *FCInfo, *FCRaw, *FCBoxRaw;
static NSArray *FCFiles, *FCBubbleFiles, *FCBoxFiles;
static NSDictionary *FCMap, *FCDIYMap, *FCBoxMap;
static NSData *FCContainer;
static NSMutableDictionary *FCReads;
static NSString *FCMutation;
static BOOL FCMutationFired, FCBubbleEnabled, FCBoxEnabled;
static NSUInteger FCRawCalls, FCBoxCalls, FCBoxSourceCalls;
static CFAbsoluteTime FCStarted;

@interface SaoqiangWCLoaderFixtureManager : NSObject
+ (instancetype)shared;
- (NSDictionary *)currentThemeInfo;
- (NSString *)currentThemePath;
- (NSString *)currentThemeDIYPath;
- (NSString *)currentBubblePath;
- (BOOL)loadTheme;
- (BOOL)loadBubble;
@end
@implementation SaoqiangWCLoaderFixtureManager
+ (instancetype)shared { static id x; static dispatch_once_t once; dispatch_once(&once, ^{ x = [self new]; }); return x; }
- (NSDictionary *)currentThemeInfo { FCMain(); return FCInfo; }
- (NSString *)currentThemePath { FCMain(); return FCRoot; }
- (NSString *)currentThemeDIYPath { FCMain(); return [FCRoot stringByAppendingPathComponent:@"DIY"]; }
- (NSString *)currentBubblePath { FCMain(); return [FCRoot stringByAppendingPathComponent:@"loaded-bubble"]; }
- (BOOL)loadTheme { FCMain(); return YES; }
- (BOOL)loadBubble { FCMain(); return FCBubbleEnabled; }
@end

@interface SaoqiangWCLoaderFixture : NSObject {
@public NSDictionary *_fileIndex; // Real runtime ivar, deliberately no getter.
}
+ (instancetype)shared;
- (NSArray *)themeFiles;
- (NSDictionary *)themeFileMap;
- (NSDictionary *)diyFileMap;
- (NSArray *)bubbleFiles;
- (NSData *)themeData;
- (NSData *)dataWithContentsOfFile:(NSString *)key;
@end
@implementation SaoqiangWCLoaderFixture
+ (instancetype)shared { static id x; static dispatch_once_t once; dispatch_once(&once, ^{ x = [self new]; }); return x; }
- (NSArray *)themeFiles { FCMain(); return FCFiles; }
- (NSDictionary *)themeFileMap { FCMain(); return FCMap; }
- (NSDictionary *)diyFileMap { FCMain(); return FCDIYMap; }
- (NSArray *)bubbleFiles { FCMain(); return FCBubbleFiles; }
- (NSData *)themeData { FCMain(); return FCContainer; }
- (NSData *)dataWithContentsOfFile:(NSString *)key {
    FCMain(); FCAssert([key isKindOfClass:NSString.class], @"raw getter needs exact string key");
    // BubbleBox-only names must never be sent to ThemeBox's raw getter.
    FCAssert(!FCBoxRaw[key] || FCRaw[key], [@"BubbleBox key sent to ThemeBox: " stringByAppendingString:key]);
    ++FCRawCalls;
    NSString *identity = [@"ThemeBox|" stringByAppendingString:key];
    FCReads[identity] = @([FCReads[identity] unsignedIntegerValue] + 1);
    NSData *original = FCRaw[key];
    if (FCMutation.length && !FCMutationFired) {
        FCMutationFired = YES;
        if ([FCMutation isEqual:@"keyset-change"]) {
            NSMutableDictionary *index = [_fileIndex mutableCopy];
            index[@"container/late-added.svg"] = @{@"offset":@0, @"length":@1};
            _fileIndex = [index copy];
        } else if ([FCMutation isEqual:@"theme-change"]) {
            FCRoot = [FCRoot stringByAppendingString:@"-changed"];
            FCInfo = @{@"name":@"另一个主题", @"themeId":@"changed-id", @"path":FCRoot};
        } else if ([FCMutation isEqual:@"raw-bytes-change"]) {
            NSMutableDictionary *raw = [FCRaw mutableCopy];
            raw[key] = FCBytes(@"<svg xmlns=\"http://www.w3.org/2000/svg\"><path id=\"changed\" d=\"M1 1L3 3\"/></svg>");
            FCRaw = [raw copy];
        }
    }
    return original;
}
@end

@interface SaoqiangWCBubbleFixtureManager : NSObject
+ (instancetype)shared;
- (NSString *)currentBubblePath;
@end
@implementation SaoqiangWCBubbleFixtureManager
+ (instancetype)shared { static id x; static dispatch_once_t once; dispatch_once(&once, ^{ x = [self new]; }); return x; }
- (NSString *)currentBubblePath { FCMain(); ++FCBoxSourceCalls; return FCBoxRoot; }
@end
@interface SaoqiangWCBubbleFixtureConfig : NSObject
+ (instancetype)shared;
- (BOOL)enabled; // Scalar BOOL ABI, never NSNumber/id.
@end
@implementation SaoqiangWCBubbleFixtureConfig
+ (instancetype)shared { static id x; static dispatch_once_t once; dispatch_once(&once, ^{ x = [self new]; }); return x; }
- (BOOL)enabled { FCMain(); return FCBoxEnabled; }
@end
@interface SaoqiangWCBubbleFixtureAssets : NSObject
+ (instancetype)shared;
- (NSArray *)bubbleFiles;
- (NSDictionary *)bubbleFileMap;
- (NSData *)dataWithContentsOfFile:(NSString *)key;
@end
@implementation SaoqiangWCBubbleFixtureAssets
+ (instancetype)shared { static id x; static dispatch_once_t once; dispatch_once(&once, ^{ x = [self new]; }); return x; }
- (NSArray *)bubbleFiles { FCMain(); ++FCBoxSourceCalls; return FCBoxFiles; }
- (NSDictionary *)bubbleFileMap { FCMain(); ++FCBoxSourceCalls; return FCBoxMap; }
- (NSData *)dataWithContentsOfFile:(NSString *)key {
    FCMain(); FCAssert(FCBoxEnabled && FCBoxRaw[key], @"inactive/foreign key sent to BubbleBox raw getter");
    ++FCBoxCalls;
    NSString *identity = [@"BubbleBox|" stringByAppendingString:key];
    FCReads[identity] = @([FCReads[identity] unsignedIntegerValue] + 1);
    return FCBoxRaw[key];
}
@end
static NSDictionary *FCIndex(NSDictionary *raw) {
    NSMutableDictionary *index = [NSMutableDictionary new];
    for (NSString *key in raw) index[key] = @{@"offset":@0, @"length":@([raw[key] length])};
    return [index copy];
}
static void FCReset(NSDictionary *raw) {
    FCMain();
    FCRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"NoDiskTheme-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    FCBoxRoot = [FCRoot stringByAppendingString:@"-independent-current-bubble"];
    FCAssert(![NSFileManager.defaultManager fileExistsAtPath:FCRoot], @"fixture has disk originals");
    FCInfo = @{@"name":@"完整原始资源测试", @"themeId":@"arbitrary-version-id", @"path":FCRoot};
    FCRaw = [raw copy]; FCFiles = @[]; FCMap = @{}; FCDIYMap = @{}; FCBubbleFiles = @[];
    FCBoxRaw = @{}; FCBoxFiles = @[]; FCBoxMap = @{}; FCBoxEnabled = NO; FCBubbleEnabled = NO;
    FCContainer = raw.count ? FCBytes(@"opaque container: resources accessible only by exact provider/key") : nil;
    [SaoqiangWCLoaderFixture shared]->_fileIndex = FCIndex(raw);
    FCReads = [NSMutableDictionary new]; FCRawCalls = 0; FCBoxCalls = 0; FCBoxSourceCalls = 0;
    FCMutation = nil; FCMutationFired = NO;
}
static NSDictionary *FCSmallRaw(void) {
    return @{@"container/good.svg":FCBytes(@"<svg xmlns=\"http://www.w3.org/2000/svg\"><path id=\"original\" d=\"M0 0L2 2\"/></svg>")};
}
static NSData *FCPNG(UIColor *color) {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat]; format.scale = 1;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(1, 1) format:format];
    NSData *data = UIImagePNGRepresentation([renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [color setFill]; [context fillRect:CGRectMake(0, 0, 1, 1)];
    }]);
    FCAssert(data.length > 8, @"cannot create tiny PNG"); return data;
}
static NSString *const FCOverlap = @"loadedTheme/PNG/ChatRoom_Bubble_HB_Sender_Handled@2x.png";
static void FCConfigureBox(NSData *png) {
    FCBoxRaw = @{@"current/ChatRoom_Bubble_Sender@2x.png":png,
                 @"current/ChatRoom_Bubble_HB_Receiver_Dark@3x.png":png, FCOverlap:png};
    // Both enumerators contribute, and the overlap between them counts once.
    FCBoxFiles = @[@"current/ChatRoom_Bubble_Sender@2x.png", FCOverlap];
    FCBoxMap = @{@"current/ChatRoom_Bubble_HB_Receiver_Dark@3x.png":[FCBoxRoot stringByAppendingPathComponent:@"red-packet"], FCOverlap:[FCBoxRoot stringByAppendingPathComponent:@"overlap"]};
}

static NSArray *FCOracleItems(NSDictionary *raw, NSString *provider) {
    NSMutableArray *items = [NSMutableArray new];
    for (NSString *key in [raw.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSData *data = raw[key];
        NSString *name = key.lastPathComponent;
        NSString *kind = @"bin";
        const unsigned char *p = data.bytes;
        if (data.length >= 8 && !memcmp(p, "\x89PNG\r\n\x1a\n", 8)) kind = @"png";
        else if (data.length >= 6 && (!memcmp(p, "GIF89a", 6) || !memcmp(p, "GIF87a", 6))) kind = @"gif";
        else if ([[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] containsString:@"<svg"]) kind = @"svg";
        if (!name.pathExtension.length) name = [name stringByAppendingPathExtension:kind];
        [items addObject:@{@"provider":provider, @"identity":[NSString stringWithFormat:@"%@|%@", provider, key], @"key":key,
                          @"name":name, @"originalName":key.lastPathComponent, @"detected":kind,
                          @"base64":[data base64EncodedStringWithOptions:0]}];
    }
    return items;
}
static NSArray *FCOracle(void) {
    NSMutableArray *items = [FCOracleItems(FCRaw, @"ThemeBox") mutableCopy];
    if (FCBoxEnabled) [items addObjectsFromArray:FCOracleItems(FCBoxRaw, @"BubbleBox")];
    return [items copy];
}
static void FCCheckSummary(NSDictionary *summary, BOOL available, BOOL complete) {
    for (NSString *key in @[@"expected", @"written", @"processed", @"failed", @"missing", @"unsupported", @"conflicts", @"itemsVerified", @"bytes"]) {
        FCAssert([summary[key] isKindOfClass:NSNumber.class] && [summary[key] doubleValue] >= 0, [@"missing/invalid summary count: " stringByAppendingString:key]);
    }
    for (NSString *key in @[@"available", @"complete", @"cancelled"]) {
        FCAssert([summary[key] isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)summary[key]) == CFBooleanGetTypeID(), [@"summary flag must be BOOL: " stringByAppendingString:key]);
    }
    FCAssert([summary[@"available"] boolValue] == available && [summary[@"complete"] boolValue] == complete && ![summary[@"busy"] boolValue],
             [NSString stringWithFormat:@"available/complete/busy contract violated: want available=%d complete=%d, got available=%@ complete=%@ busy=%@ expected=%@ written=%@ verified=%@ failed=%@ missing=%@ warnings=%@ diagnostic=%@",
              available, complete, summary[@"available"], summary[@"complete"], summary[@"busy"],
              summary[@"expected"], summary[@"written"], summary[@"itemsVerified"],
              summary[@"failed"], summary[@"missing"], summary[@"warnings"], summary[@"diagnostic"]]);
}
static void FCCheckReads(NSArray *oracle) {
    for (NSDictionary *item in oracle) FCAssert([FCReads[item[@"identity"]] unsignedIntegerValue] >= 2, [@"original not independently re-fetched: " stringByAppendingString:item[@"identity"]]);
}
static void FCCopyFolder(NSURL *directory, NSString *relative) {
    NSFileManager *fm = NSFileManager.defaultManager; NSError *error = nil;
    NSURL *target = [FCDocuments() URLByAppendingPathComponent:relative isDirectory:YES];
    FCAssert([fm createDirectoryAtURL:target.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&error] && [fm copyItemAtURL:directory toURL:target error:&error], error.localizedDescription ?: @"cannot copy export artifact");
}
static NSArray<NSString *> *FCCases(void) {
    return @[@"missing-raw", @"invalid-raw", @"unsupported-format", @"basename-case-collision",
             @"basename-unicode-collision", @"incompatible-index", @"empty-index", @"metadata-only",
             @"theme-change", @"keyset-change", @"raw-bytes-change", @"cancel", @"bubblebox-disabled"];
}
static void FCConfigureCase(NSString *name) {
    FCReset(FCSmallRaw());
    SaoqiangWCLoaderFixture *loader = [SaoqiangWCLoaderFixture shared];
    if ([name isEqual:@"missing-raw"]) {
        NSMutableDictionary *index = [loader->_fileIndex mutableCopy];
        index[@"hidden/missing_Dark@3x.png"] = @{@"offset":@10, @"length":@16}; loader->_fileIndex = [index copy];
    } else if ([name isEqual:@"invalid-raw"]) {
        NSData *png = FCPNG(UIColor.orangeColor);
        FCReset(@{@"container/broken.PNG":FCBytes(@"these are not PNG bytes"), @"container/no-extension":FCBytes(@"opaque bytes stay unmodified"),
                  @"container/png-without-ext":png, @"container/actualPNG.SvG":png});
    } else if ([name isEqual:@"unsupported-format"]) {
        const unsigned char ktx[] = {0xab,0x4b,0x54,0x58,0x20,0x31,0x31,0xbb,0x0d,0x0a,0x1a,0x0a,0x01,0x02};
        FCReset(@{@"container/texture.ktx":[NSData dataWithBytes:ktx length:sizeof(ktx)]});
    } else if ([name hasPrefix:@"basename-"]) {
        NSData *svg = FCSmallRaw().allValues.firstObject;
        FCReset([name isEqual:@"basename-case-collision"] ? @{@"first/Icon_Dark@2x.svg":svg, @"second/icon_dark@2x.svg":svg}
                : @{@"first/caf\u00e9@3x.svg":svg, @"second/cafe\u0301@3x.svg":svg});
    } else if ([name isEqual:@"incompatible-index"]) {
        FCFiles = @[@"container/good.svg"]; loader->_fileIndex = (id)@[@"container/good.svg"];
    } else if ([name isEqual:@"empty-index"]) FCReset(@{});
    else if ([name isEqual:@"metadata-only"]) FCReset(@{@"manifest.json":FCBytes(@"{}"), @"config.json":FCBytes(@"{}"), @"README.md":FCBytes(@"metadata only")});
    else if ([name hasSuffix:@"change"]) FCMutation = name;
    else if ([name isEqual:@"bubblebox-disabled"]) {
        FCBubbleFiles = @[@"container/good.svg"]; FCFiles = FCBubbleFiles; loader->_fileIndex = @{};
        FCContainer = nil; FCConfigureBox(FCPNG(UIColor.blueColor)); FCBoxEnabled = NO;
    }
}

static void FCRunCase(NSUInteger position, NSMutableArray *results, dispatch_block_t completion) {
    if (position == FCCases().count) {
        FCAssert(CFAbsoluteTimeGetCurrent() - FCStarted < 90, @"native feature checks exceeded 90 seconds");
        FCJSON(@{@"status":@"passed", @"cases":results}, @"failures.json");
        FCAssert([@"done\n" writeToURL:[FCDocuments() URLByAppendingPathComponent:@"features-done.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil], @"cannot save completion marker");
        NSLog(@"FEATURE_CHECK_PASSED 1714 ThemeBox + 3 independent BubbleBox originals; 13 regression cases");
        completion(); return;
    }
    NSString *name = FCCases()[position]; FCConfigureCase(name);
    NSArray *oracle = FCOracle(); // Saved independently before invoking the worker.
    BOOL available = [@[@"missing-raw", @"invalid-raw", @"unsupported-format", @"basename-case-collision", @"basename-unicode-collision", @"incompatible-index", @"bubblebox-disabled"] containsObject:name];
    BOOL complete = available && ![@[@"missing-raw", @"incompatible-index"] containsObject:name];
    SaoqiangWCAssetsThemePackCompletion callback = ^(NSURL *directory, NSDictionary *summary, NSString *error) {
        FCMain(); FCCheckSummary(summary, available, complete);
        FCAssert((directory != nil) == available && (available ? !error.length : error.length > 0), [NSString stringWithFormat:@"%@ returned wrong availability/error: %@ %@", name, error, summary]);
        FCAssert([summary[@"cancelled"] boolValue] == [name isEqual:@"cancel"], @"cancellation state leaked/lost");
        if (available) {
            FCAssert([summary[@"written"] unsignedIntegerValue] == oracle.count && [summary[@"itemsVerified"] unsignedIntegerValue] == oracle.count, @"available export lost original files or verification");
            FCCheckReads(oracle);
            FCCopyFolder(directory, [@"case-folders" stringByAppendingPathComponent:name]);
            if ([name isEqual:@"missing-raw"]) FCAssert([summary[@"expected"] unsignedIntegerValue] == 2 && [summary[@"missing"] unsignedIntegerValue] == 1, @"mixed missing resource not counted");
            if ([name isEqual:@"invalid-raw"] || [name isEqual:@"unsupported-format"]) FCAssert([summary[@"unsupported"] unsignedIntegerValue] >= 1 && [summary[@"failed"] unsignedIntegerValue] == 0, @"raw format warnings dropped bytes or became failures");
            if ([name hasPrefix:@"basename-"]) FCAssert([summary[@"conflicts"] unsignedIntegerValue] == 1 && [summary[@"written"] unsignedIntegerValue] == 2, @"collision did not preserve both originals");
        }
        if ([name hasSuffix:@"change"]) FCAssert(FCMutationFired && FCRawCalls > 0, @"source mutation never exercised");
        if ([name isEqual:@"raw-bytes-change"]) FCAssert(FCRawCalls >= 2, @"changed bytes were not re-fetched");
        if ([name isEqual:@"bubblebox-disabled"]) FCAssert(FCBoxCalls == 0 && FCBoxSourceCalls == 0, @"disabled BubbleBox source was accessed");
        [results addObject:@{@"case":name, @"directoryReturned":(directory ? @YES : @NO), @"error":error ?: @"", @"summary":summary,
            @"rawCalls":@(FCRawCalls), @"bubbleRawCalls":@(FCBoxCalls), @"bubbleSourceCalls":@(FCBoxSourceCalls),
            @"mutationApplied":@(FCMutationFired), @"oracle":oracle, @"reads":[FCReads copy]}];
        dispatch_async(dispatch_get_main_queue(), ^{ FCRunCase(position + 1, results, completion); });
    };
    if ([name isEqual:@"bubblebox-disabled"]) {
        SaoqiangWCAssetsExportThemeSourcesFixture(SaoqiangWCLoaderFixtureManager.class, SaoqiangWCLoaderFixture.class, Nil,
            SaoqiangWCBubbleFixtureManager.class, SaoqiangWCBubbleFixtureAssets.class, SaoqiangWCBubbleFixtureConfig.class, callback);
    } else {
        // Old entry point must explicitly use nil bubble classes: never probe host classes.
        SaoqiangWCAssetsExportThemeLoaderFixture(SaoqiangWCLoaderFixtureManager.class, SaoqiangWCLoaderFixture.class, Nil, callback);
    }
    if ([name isEqual:@"cancel"]) SaoqiangWCAssetsCancelThemeExport();
}

void SaoqiangWCAssetsRunFeatureChecks(UIWindow *window, void (^completion)(void)) {
    FCMain(); FCStarted = CFAbsoluteTimeGetCurrent(); NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *name in @[@"capture-failed.txt", @"features-done.txt", @"provider-checks.json", @"theme-full-result.json", @"expected-source.json", @"failures.json", @"test-theme-folder", @"case-folders"]) [fm removeItemAtURL:[FCDocuments() URLByAppendingPathComponent:name] error:nil];
    FCJSON(SaoqiangWCAssetsRunProviderChecks(window), @"provider-checks.json");
    NSMutableDictionary *raw = [NSMutableDictionary new]; NSMutableArray *svgKeys = [NSMutableArray new];
    for (NSUInteger i = 0; i < 1703; ++i) {
        NSString *base = [NSString stringWithFormat:@"icons_item_%04lu%@%@", (unsigned long)i, i % 2 ? @"_Dark@3x" : @"@2x", i == 1702 ? @"" : @".svg"];
        NSString *key = [NSString stringWithFormat:@"loadedTheme/container/group%02lu/%@", (unsigned long)(i % 13), base];
        raw[key] = FCBytes([NSString stringWithFormat:@"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1\" height=\"1\"><path id=\"source_%lu\" d=\"M0 0L1 1\"/></svg>\n", (unsigned long)i]);
        [svgKeys addObject:key];
    }
    NSData *png = FCPNG(UIColor.orangeColor);
    NSArray *pngKeys = @[@"loaded-bubble/ChatRoom_Bubble_HB_Sender_Dark@2x.png", @"loadedTheme/PNG/导航图标@3x.png", FCOverlap];
    for (NSString *key in pngKeys) raw[key] = png;
    FCAssert(raw.count == 1706, @"base fixture must reproduce 1706 previously written originals");
    NSData *gif = [[NSData alloc] initWithBase64EncodedString:@"R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" options:0];
    CGImageSourceRef image = CGImageSourceCreateWithData((__bridge CFDataRef)gif, NULL);
    FCAssert(image && CGImageSourceGetCount(image) == 1 && CGImageSourceGetStatus(image) == kCGImageStatusComplete, @"GIF fixture is not a real 1-pixel GIF");
    CGImageRef pixel = CGImageSourceCreateImageAtIndex(image, 0, NULL);
    FCAssert(pixel && CGImageGetWidth(pixel) == 1 && CGImageGetHeight(pixel) == 1, @"GIF fixture must decode to 1x1");
    CGImageRelease(pixel); CFRelease(image);
    raw[@"loadedTheme/animation/loading@2x.gif"] = gif;
    raw[@"loadedTheme/animation/loading_Dark@3x.GIF"] = gif;
    NSMutableArray *aliasPairs = [NSMutableArray new];
    for (NSUInteger i = 0; i < 6; ++i) {
        NSString *original = svgKeys[i];
        NSString *alias = [@"loadedTheme/case-alias" stringByAppendingPathComponent:original.lastPathComponent.uppercaseString];
        raw[alias] = FCBytes([NSString stringWithFormat:@"<svg xmlns=\"http://www.w3.org/2000/svg\"><path id=\"alias_%lu\" d=\"M1 0L0 1\"/></svg>", (unsigned long)i]);
        [aliasPairs addObject:@[original, alias]];
    }
    FCAssert(raw.count == 1714, @"ThemeBox fixture must contain exactly 1714 keys");
    FCReset(raw);
    NSMutableDictionary *index = [[SaoqiangWCLoaderFixture shared]->_fileIndex mutableCopy];
    for (NSString *key in @[svgKeys[0], svgKeys[1], svgKeys[2], pngKeys[0]]) [index removeObjectForKey:key];
    [SaoqiangWCLoaderFixture shared]->_fileIndex = [index copy];
    FCFiles = @[svgKeys[0], pngKeys[1]];
    FCMap = @{svgKeys[1]:[FCRoot stringByAppendingPathComponent:svgKeys[1]]};
    FCDIYMap = @{svgKeys[2]:[FCRoot stringByAppendingPathComponent:svgKeys[2]]};
    FCBubbleFiles = @[pngKeys[0]]; FCBubbleEnabled = NO;
    FCConfigureBox(FCPNG(UIColor.blueColor)); FCBoxEnabled = YES;
    FCAssert(index.count == 1710 && ![FCRaw[FCOverlap] isEqual:FCBoxRaw[FCOverlap]], @"index or cross-provider bytes fixture changed");
    NSArray *oracle = FCOracle(); FCAssert(oracle.count == 1717, @"combined fixture must contain 1717 provider/key records");
    // Written BEFORE export; neither mapping nor bytes depend on the manifest.
    FCJSON(@{@"schema":@2, @"expected":@1717, @"themeBoxCount":@1714, @"bubbleBoxCount":@3,
             @"baseCount":@1706, @"gifCount":@2, @"caseAliases":aliasPairs, @"overlapKey":FCOverlap,
             @"items":oracle, @"indexCount":@(index.count), @"diskOriginals":@NO,
             @"themeBoxLoadBubble":@NO, @"bubbleBoxEnabled":@YES, @"loadedBubbleKey":pngKeys[0],
             @"sources":@[@"themeFiles", @"_fileIndex", @"themeFileMap", @"diyFileMap", @"ThemeBox.bubbleFiles", @"BubbleBox.bubbleFiles", @"BubbleBox.bubbleFileMap"]}, @"expected-source.json");
    SaoqiangWCAssetsExportThemeSourcesFixture(SaoqiangWCLoaderFixtureManager.class, SaoqiangWCLoaderFixture.class, Nil,
        SaoqiangWCBubbleFixtureManager.class, SaoqiangWCBubbleFixtureAssets.class, SaoqiangWCBubbleFixtureConfig.class,
        ^(NSURL *directory, NSDictionary *summary, NSString *error) {
            FCMain(); FCCheckSummary(summary, YES, YES);
            FCAssert(directory && !error.length, [NSString stringWithFormat:@"happy export unavailable: %@ %@", error, summary]);
            for (NSString *field in @[@"expected", @"written", @"processed", @"itemsVerified"]) FCAssert([summary[field] unsignedIntegerValue] == 1717, [@"happy union count wrong: " stringByAppendingString:field]);
            FCAssert([summary[@"failed"] unsignedIntegerValue] == 0 && [summary[@"missing"] unsignedIntegerValue] == 0 && [summary[@"conflicts"] unsignedIntegerValue] == 7 && ![summary[@"cancelled"] boolValue], @"happy export dropped files or failed to resolve seven collisions");
            FCCheckReads(oracle); FCAssert(FCBoxCalls >= 6 && !FCMutationFired && ![fm fileExistsAtPath:FCRoot] && ![fm fileExistsAtPath:FCBoxRoot], @"wrong active provider or disk originals used");
            FCCopyFolder(directory, @"test-theme-folder"); FCJSON(summary, @"theme-full-result.json");
            dispatch_async(dispatch_get_main_queue(), ^{ FCRunCase(0, [NSMutableArray new], completion); });
        });
}
