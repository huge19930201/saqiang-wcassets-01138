#import "Engine308Checks.h"
#import "SaoqiangWCAssetsThemePack.h"
#import "SaoqiangWCAssetsTheme.h"
#import "SaoqiangWCAssetsReference.h"
#import <CommonCrypto/CommonDigest.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <string.h>
#import <sys/stat.h>

// Parent adds this TESTING-only entry point; no dependency on host binary classes.
#if !defined(SAOQIANG_WCASSETS_TESTING)
#error Engine308Checks.m must be compiled with SAOQIANG_WCASSETS_TESTING
#endif
FOUNDATION_EXPORT void SaoqiangWCAssetsExportThemeEngineFixture(Class manager, Class legacyLoader, Class assets, Class util, SaoqiangWCAssetsThemePackCompletion completion);

static NSURL *EC308RunRoot, *EC308Artifacts;
static NSString *EC308Root, *EC308Case;
static NSDictionary *EC308Info, *EC308NewRaw, *EC308OldRaw, *EC308NewMap;
static NSArray *EC308OldFiles;
static NSMutableDictionary *EC308Reads;
static BOOL EC308Enabled, EC308Mutate, EC308Mutated, EC308Running;
static NSUInteger EC308NewCalls, EC308OldCalls, EC308FlagCalls, EC308Assertions;
static NSUInteger EC308NewMapCalls, EC308OldIndexCalls;

static NSURL *EC308Documents(void) {
    return [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
}
static void EC308Assert(BOOL valid, NSString *message) {
    ++EC308Assertions;
    if (valid) return;
    NSString *failure = [NSString stringWithFormat:@"ENGINE308_CHECK_FAILED [%@] %@\n", EC308Case ?: @"setup", message];
    NSLog(@"%@", failure);
    NSFileManager *fm = NSFileManager.defaultManager;
    [fm createDirectoryAtURL:EC308Documents() withIntermediateDirectories:YES attributes:nil error:nil];
    [failure writeToURL:[EC308Documents() URLByAppendingPathComponent:@"capture-failed.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    abort();
}
static void EC308Main(void) { EC308Assert(NSThread.isMainThread, @"fixture/getter/completion called off main thread"); }
static NSData *EC308Bytes(NSString *text) { return [text dataUsingEncoding:NSUTF8StringEncoding]; }
static void EC308Write(NSData *bytes, NSURL *url) {
    NSError *error = nil;
    EC308Assert(bytes != nil && [NSFileManager.defaultManager createDirectoryAtURL:url.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&error] && [bytes writeToURL:url options:NSDataWritingAtomic error:&error], error.localizedDescription ?: @"cannot write fixture/artifact");
}
static void EC308JSON(id object, NSURL *url) {
    NSError *error = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
    EC308Assert(json != nil, error.localizedDescription ?: @"invalid report JSON");
    EC308Write(json, url);
}
static NSData *EC308XML(void) {
    return EC308Bytes(@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n<!-- EC308 RAW XML: retain whitespace -->\r\n<resources>\r\n  <color name=\"EC308Accent\">#123456</color>\r\n</resources>\r\n");
}
static NSData *EC308CSS(void) {
    return EC308Bytes(@"/* EC308 RAW CSS: retain tabs and CRLF */\r\n:root {\r\n\t--EC308-accent: #654321;\r\n}\r\n");
}
static NSData *EC308ChangedXML(void) {
    return EC308Bytes(@"<?xml version=\"1.0\"?><resources><color name=\"EC308Accent\">#fedcba</color><!-- changed source; deliberately different byte length --></resources>\n");
}
static NSData *EC308Donor(void) {
    return EC308Bytes(@"/* EC308_OUTSIDE_ROOT_SECRET_591d2089 */\n:root { --private-donor-color: #badbad; }\n");
}
static void EC308RecordRead(NSString *provider, NSString *key, NSDictionary *raw) {
    EC308Main();
    EC308Assert([key isKindOfClass:NSString.class] && (raw[key] != nil || ([EC308Case hasPrefix:@"reference-"] && [key isEqual:@"missing.svg"])), [NSString stringWithFormat:@"%@ received non-exact or foreign raw key: %@", provider, key]);
    if([EC308Case isEqual:@"reference-theme-switch"])EC308Info=@{@"name":@"switched",@"themeId":@"different-theme-id"};
    NSString *identity = [NSString stringWithFormat:@"%@|%@", provider, key];
    EC308Reads[identity] = @([EC308Reads[identity] unsignedIntegerValue] + 1);
    if (EC308Mutate && !EC308Mutated) {
        EC308Mutated = YES;
        EC308Write(EC308ChangedXML(), [NSURL fileURLWithPath:[EC308Root stringByAppendingPathComponent:@"weui_color_new.xml"]]);
    }
}

@interface SaoqiangWC308Manager : NSObject
+ (instancetype)shared;
- (NSString *)currentThemePath;
- (NSDictionary *)currentThemeInfo;
- (BOOL)loadTheme;
@end
@implementation SaoqiangWC308Manager
+ (instancetype)shared { EC308Main(); static id x; static dispatch_once_t once; dispatch_once(&once, ^{ x = [self new]; }); return x; }
- (NSString *)currentThemePath { EC308Main(); return EC308Root; }
- (NSDictionary *)currentThemeInfo { EC308Main(); return EC308Info; }
- (BOOL)loadTheme { EC308Main(); return YES; }
@end

@interface SaoqiangWC308LegacyLoader : NSObject {
@public NSDictionary *_fileIndex; // Actual legacy ivar, intentionally no KVC/getter.
}
+ (instancetype)shared;
- (NSArray *)themeFiles;
- (NSData *)dataWithContentsOfFile:(NSString *)key;
@end
@implementation SaoqiangWC308LegacyLoader
+ (instancetype)shared { EC308Main(); static id x; static dispatch_once_t once; dispatch_once(&once, ^{ x = [self new]; }); return x; }
- (NSArray *)themeFiles { EC308Main(); ++EC308OldIndexCalls; return EC308OldFiles; }
- (NSData *)dataWithContentsOfFile:(NSString *)key {
    EC308RecordRead(@"ThemeBox", key, EC308OldRaw); ++EC308OldCalls; return EC308OldRaw[key];
}
@end

@interface SaoqiangWC308Assets : NSObject
+ (instancetype)shared;
- (NSDictionary *)themeFiles;
- (NSData *)dataWithContentsOfFile:(NSString *)key;
@end
@implementation SaoqiangWC308Assets
+ (instancetype)shared { EC308Main(); static id x; static dispatch_once_t once; dispatch_once(&once, ^{ x = [self new]; }); return x; }
- (NSDictionary *)themeFiles { EC308Main(); ++EC308NewMapCalls; return EC308NewMap; }
- (NSData *)dataWithContentsOfFile:(NSString *)key {
    EC308RecordRead(@"ThemeBoxAssets", key, EC308NewRaw); ++EC308NewCalls; return EC308NewRaw[key];
}
@end

@interface SaoqiangWC308Util : NSObject
+ (instancetype)shared;
+ (BOOL)enabledNewEngine;
@end
@implementation SaoqiangWC308Util
+ (instancetype)shared { EC308Main(); static id x; static dispatch_once_t once; dispatch_once(&once, ^{ x = [self new]; }); return x; }
+ (BOOL)enabledNewEngine { EC308Main(); ++EC308FlagCalls; return EC308Enabled; }
@end

static void EC308CheckABI(Class cls, SEL selector, BOOL classMethod, const char *returnType, NSUInteger argumentCount) {
    Method method = classMethod ? class_getClassMethod(cls, selector) : class_getInstanceMethod(cls, selector);
    EC308Assert(method != NULL, @"fixture runtime method missing");
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    EC308Assert(signature.numberOfArguments == argumentCount && strcmp(signature.methodReturnType, returnType) == 0, [NSString stringWithFormat:@"fixture ABI mismatch: %@ %@", NSStringFromClass(cls), NSStringFromSelector(selector)]);
    if (argumentCount == 3) EC308Assert(strcmp([signature getArgumentTypeAtIndex:2], @encode(id)) == 0, @"raw getter argument must be an object");
}

static NSDictionary *EC308Icons(NSString *prefix, BOOL legacy) {
    NSData *png = [[NSData alloc] initWithBase64EncodedString:@"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGMQMgn7DwAClAGcHVtGXwAAAABJRU5ErkJggg==" options:0];
    NSData *gif = [[NSData alloc] initWithBase64EncodedString:@"R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" options:0];
    NSData *svg = EC308Bytes(@"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1\" height=\"1\"><path id=\"EC308_original\" d=\"M0 0L1 1\"/></svg>\r\n");
    EC308Assert(png.length > 8 && gif.length > 6, @"invalid embedded image fixture");
    NSMutableDictionary *raw = [@{[prefix stringByAppendingPathComponent:@"EC308_vector_Dark@3x.svg"]:svg,
                                  [prefix stringByAppendingPathComponent:@"EC308_pixel@2x.png"]:png} mutableCopy];
    if (!legacy) raw[[prefix stringByAppendingPathComponent:@"EC308_animation@2x.gif"]] = gif;
    return [raw copy];
}
static NSArray<NSString *> *EC308Cases(void) {
    return @[@"newengine-data-map", @"newengine-path-map-stale-legacy", @"oldengine-stale-assets",
             @"palette-missing-css", @"source-color-mutation", @"symlink-color-css",
             @"newengine-different-theme", @"newengine-opaque-pack-only", @"newengine-decoded-cache-only", @"reference-2547", @"reference-wrong-missing", @"reference-theme-switch", @"reference-other-id"];
}
static void EC308Configure(NSString *name) {
    EC308Main(); EC308Case = name;
    EC308Enabled = ![name isEqual:@"oldengine-stale-assets"];
    EC308Mutate = [name isEqual:@"source-color-mutation"]; EC308Mutated = NO;
    EC308Reads = [NSMutableDictionary new];
    EC308NewCalls = EC308OldCalls = EC308FlagCalls = 0;
    EC308NewMapCalls = EC308OldIndexCalls = 0;
    EC308Root = [[EC308RunRoot URLByAppendingPathComponent:[name stringByAppendingPathComponent:@"current-theme"] isDirectory:YES] path];
    EC308Info = @{@"name":@"ThemeBox 3.0.8 原件检查", @"themeId":[@"engine308-" stringByAppendingString:name], @"path":EC308Root};
    EC308Write(EC308XML(), [NSURL fileURLWithPath:[EC308Root stringByAppendingPathComponent:@"weui_color_new.xml"]]);
    EC308Write(EC308CSS(), [NSURL fileURLWithPath:[EC308Root stringByAppendingPathComponent:@"color.css"]]);
    EC308NewRaw = EC308Icons(EC308Enabled ? @"new/current" : @"stale-assets/never-current", NO);
    if([name isEqual:@"newengine-decoded-cache-only"])EC308NewRaw=@{};
    BOOL withLegacy = !EC308Enabled || [name isEqual:@"newengine-path-map-stale-legacy"];
    EC308OldRaw = withLegacy ? EC308Icons(EC308Enabled ? @"stale-legacy/never-current" : @"old/current", YES) : @{};
    if ([name isEqual:@"newengine-different-theme"]) {
        EC308NewRaw = @{@"different/SecondTheme_OnlyIcon_Dark@3x.svg":EC308Bytes(@"<svg xmlns=\"http://www.w3.org/2000/svg\"><path id=\"second-theme-only\"/></svg>\n")};
    }
    if ([name isEqual:@"newengine-opaque-pack-only"]) {
        EC308NewRaw = @{};
        // Self-made opaque bytes only; never upload the user's pack.
        EC308Write(EC308Bytes(@"EC308_OPAQUE_PACK_ORIGINAL\000\001\002"), [NSURL fileURLWithPath:[EC308Root stringByAppendingPathComponent:@"themebox.dat"]]);
    }
    NSArray *keys = [EC308OldRaw.allKeys sortedArrayUsingSelector:@selector(compare:)];
    // Each legacy enumerator contributes a key, matching the real NSArray/ivar interfaces.
    EC308OldFiles = keys.count ? @[keys[0]] : @[];
    NSMutableDictionary *index = [NSMutableDictionary new];
    if (keys.count > 1) index[keys[1]] = @{@"offset":@0, @"length":@([EC308OldRaw[keys[1]] length])};
    [SaoqiangWC308LegacyLoader shared]->_fileIndex = [index copy];
    if ([name isEqual:@"newengine-data-map"]) EC308NewMap = [EC308NewRaw copy];
    else {
        NSMutableDictionary *paths = [NSMutableDictionary new];
        for (NSString *key in EC308NewRaw) paths[key] = [EC308Root stringByAppendingPathComponent:[@"raw-interface-only" stringByAppendingPathComponent:key]];
        EC308NewMap = [paths copy];
    }
    EC308Assert([[SaoqiangWC308Assets shared] themeFiles] && [EC308NewMap isKindOfClass:NSDictionary.class], @"new themeFiles fixture must return NSDictionary");
    if([name isEqual:@"newengine-decoded-cache-only"]) {
        NSData *decoded=EC308Icons(@"runtime",NO)[@"runtime/EC308_pixel@2x.png"];
        SaoqiangWCAssetsThemeSetCaptureRoot(EC308Root);
        SaoqiangWCAssetsThemeRecordDecodedData(@"runtime/EC308_pixel@2x.png",decoded,@"fixture ThemeBoxCache decoded data");
        NSArray *captured=SaoqiangWCAssetsThemeCapturedSnapshot(EC308Root);
        EC308Assert(captured.count==1, [NSString stringWithFormat:@"decoded cache fixture was not retained: %lu",(unsigned long)captured.count]);
    }
    if([name hasPrefix:@"reference-"]){
        EC308Assert(SaoqiangWCAssetsReferenceClear(EC308Info[@"themeId"],nil),@"reference cleanup failed");
        NSMutableDictionary *raw=[NSMutableDictionary new];NSMutableArray *ref=[NSMutableArray new];
        NSUInteger count=[name isEqual:@"reference-2547"]?2547:3;
        for(NSUInteger i=0;i<count;i++){
            NSString *key=i==0?@"redenvelope_正常.svg":[NSString stringWithFormat:@"ECRef_%04lu.svg",(unsigned long)i];
            NSData *data=EC308Bytes([NSString stringWithFormat:@"<svg xmlns=\"http://www.w3.org/2000/svg\"><path id=\"independent-%lu\"/></svg>",(unsigned long)i]);
            raw[key]=data;unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,digest);NSMutableString *hash=[NSMutableString new];for(NSUInteger j=0;j<sizeof(digest);j++)[hash appendFormat:@"%02x",digest[j]];
            [ref addObject:@{@"key":key,@"bytes":@(data.length),@"sha256":hash}];
        }
        EC308NewMap=@{};EC308NewRaw=raw;
        if([name isEqual:@"reference-wrong-missing"]){NSMutableArray *a=[ref mutableCopy];NSMutableDictionary *bad=[a[1]mutableCopy];bad[@"key"]=@"missing.svg";a[1]=bad;ref=a;NSMutableDictionary *wrong=[raw mutableCopy];wrong[ref[2][@"key"]]=EC308Bytes(@"wrong fallback bytes");EC308NewRaw=wrong;}
        NSDictionary *reference=@{@"themeID":EC308Info[@"themeId"],@"items":ref};NSData *json=[NSJSONSerialization dataWithJSONObject:reference options:0 error:nil];NSString *e=nil;
        EC308Assert(!SaoqiangWCAssetsReferenceImport(json,@"foreign-theme",&e),@"foreign theme reference accepted");
        NSMutableDictionary *malformed=[reference mutableCopy];malformed[@"items"]=@[ref[0],ref[0]];EC308Assert(!SaoqiangWCAssetsReferenceImport([NSJSONSerialization dataWithJSONObject:malformed options:0 error:nil],EC308Info[@"themeId"],&e),@"duplicate key accepted");
        EC308Assert(SaoqiangWCAssetsReferenceImport(json,EC308Info[@"themeId"],&e),e?:@"reference import failed");
        if([name isEqual:@"reference-other-id"]){EC308Info=@{@"name":@"another theme",@"themeId":@"not-the-reference-id"};EC308NewRaw=EC308Icons(@"other-theme",NO);EC308NewMap=EC308NewRaw;}
        // A wrong decoded cache entry for a reference key must never be used.
        if(![name isEqual:@"reference-other-id"])SaoqiangWCAssetsThemeSetCaptureRoot(EC308Root);if(![name isEqual:@"reference-other-id"])SaoqiangWCAssetsThemeRecordDecodedData(ref[0][@"key"],EC308Bytes(@"<svg id=\"stale-runtime\"/>"),@"fixture stale decoded");
    }
    EC308NewMapCalls = 0; // Only exporter activity belongs in the report.
    if([name isEqual:@"reference-2547"])SaoqiangWCAssetsThemeRecordDecodedData(@"extra-cache-only.svg",EC308Bytes(@"<svg id=\"extra-cache-original\"/>"),@"fixture decoded outside reference");
    if ([name isEqual:@"palette-missing-css"]) {
        NSError *error = nil;
        EC308Assert([NSFileManager.defaultManager removeItemAtPath:[EC308Root stringByAppendingPathComponent:@"color.css"] error:&error], error.localizedDescription ?: @"cannot remove optional palette fixture");
    }
    if ([name isEqual:@"symlink-color-css"]) {
        NSURL *donor = [EC308RunRoot URLByAppendingPathComponent:@"outside-current-theme/private-donor.css"];
        EC308Write(EC308Donor(), donor);
        NSString *link = [EC308Root stringByAppendingPathComponent:@"color.css"];
        NSError *error = nil;
        EC308Assert([NSFileManager.defaultManager removeItemAtPath:link error:&error] && [NSFileManager.defaultManager createSymbolicLinkAtPath:link withDestinationPath:donor.path error:&error], error.localizedDescription ?: @"cannot create final-component symlink");
        struct stat status;
        EC308Assert(lstat(link.fileSystemRepresentation, &status) == 0 && S_ISLNK(status.st_mode), @"symlink fixture is not a real symbolic link");
        EC308Assert(![donor.path hasPrefix:[EC308Root stringByAppendingString:@"/"]], @"donor fixture must be outside current theme root");
    }
}
static NSDictionary *EC308Expected(void) {
    NSDictionary *raw = EC308Enabled ? EC308NewRaw : EC308OldRaw;
    NSString *provider = EC308Enabled ? @"ThemeBoxAssets" : @"ThemeBox";
    NSMutableArray *items = [NSMutableArray new];
    for (NSString *key in [raw.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        if([EC308Case isEqual:@"reference-wrong-missing"]&&![key isEqual:@"redenvelope_正常.svg"])continue;
        NSData *bytes = raw[key];
        [items addObject:@{@"provider":provider, @"key":key, @"file":key.lastPathComponent,
                          @"base64":[bytes base64EncodedStringWithOptions:0]}];
    }
    [items addObject:@{@"provider":@"ThemeColors", @"key":@"weui_color_new.xml", @"file":@"weui_color_new.xml", @"base64":[EC308XML() base64EncodedStringWithOptions:0]}];
    if (![EC308Case isEqual:@"palette-missing-css"] && ![EC308Case isEqual:@"symlink-color-css"])
        [items addObject:@{@"provider":@"ThemeColors", @"key":@"color.css", @"file":@"color.css", @"base64":[EC308CSS() base64EncodedStringWithOptions:0]}];
    if ([EC308Case isEqual:@"newengine-opaque-pack-only"]) {
        [items addObject:@{@"provider":@"ThemeSource", @"key":@"themebox.dat", @"file":@"themebox.dat", @"base64":[EC308Bytes(@"EC308_OPAQUE_PACK_ORIGINAL\000\001\002") base64EncodedStringWithOptions:0]}];
    }
    if([EC308Case isEqual:@"newengine-decoded-cache-only"]) {
        NSData *decoded=EC308Icons(@"runtime",NO)[@"runtime/EC308_pixel@2x.png"];
        [items addObject:@{@"provider":@"ThemeBoxDecoded",@"key":@"runtime/EC308_pixel@2x.png",@"file":@"EC308_pixel@2x.png",@"base64":[decoded base64EncodedStringWithOptions:0]}];
    }
    if([EC308Case isEqual:@"reference-2547"])[items addObject:@{@"provider":@"ThemeBoxDecoded",@"key":@"extra-cache-only.svg",@"file":@"extra-cache-only.svg",@"base64":[EC308Bytes(@"<svg id=\"extra-cache-original\"/>")base64EncodedStringWithOptions:0]}];
    NSString *availability = EC308Mutate ? @"abort" : ([EC308Case isEqual:@"symlink-color-css"] ? @"partial-or-abort" : @"folder");
    return @{@"schema":@1, @"case":EC308Case, @"engineEnabled":@(EC308Enabled), @"availability":availability,
             @"currentThemeRoot":EC308Root, @"items":items, @"sourceColorNames":@[@"weui_color_new.xml", @"color.css"],
             @"excludedKeys":[(EC308Enabled ? EC308OldRaw : EC308NewRaw).allKeys sortedArrayUsingSelector:@selector(compare:)],
             @"mutatedXMLBase64":[EC308ChangedXML() base64EncodedStringWithOptions:0],
             @"forbiddenDonorBase64":[EC308Donor() base64EncodedStringWithOptions:0]};
}

static NSDictionary *EC308ReadJSON(NSURL *url) {
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&error];
    id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
    EC308Assert([json isKindOfClass:NSDictionary.class], error.localizedDescription ?: @"missing/invalid JSON artifact");
    return json;
}
static BOOL EC308ColorDiagnostic(id object, BOOL mentionsColor) {
    if ([object isKindOfClass:NSDictionary.class]) {
        NSDictionary *dictionary = object;
        // An issue naming the actual palette is already a useful diagnostic.
        for (NSString *key in @[@"key", @"source", @"identity", @"file", @"path", @"name"])
            if ([dictionary[key] isKindOfClass:NSString.class]) {
                NSString *text = [dictionary[key] lowercaseString];
                if ([text containsString:@"color.css"] || [text containsString:@"weui_color_new.xml"] || [text containsString:@"themecolors"]) mentionsColor = YES;
            }
        if (mentionsColor && (dictionary[@"status"] || dictionary[@"reason"] || dictionary[@"missing"] || dictionary[@"warning"] || dictionary[@"issues"])) return YES;
        for (id key in dictionary) {
            BOOL color = mentionsColor;
            if ([key isKindOfClass:NSString.class]) {
                NSString *name = [key lowercaseString];
                color = color || [name containsString:@"color"] || [name containsString:@"palette"] || [name containsString:@"配色"];
            }
            if (EC308ColorDiagnostic(dictionary[key], color)) return YES;
        }
    } else if ([object isKindOfClass:NSArray.class]) {
        for (id item in object) if (EC308ColorDiagnostic(item, mentionsColor)) return YES;
    } else if ([object isKindOfClass:NSString.class]) {
        NSString *text = [object lowercaseString];
        return (mentionsColor && [text length] > 0) || [text containsString:@"color.css"] || [text containsString:@"weui_color_new.xml"] || [text containsString:@"themecolors"];
    } else if ([object isKindOfClass:NSNumber.class]) return mentionsColor;
    return NO;
}

static void EC308CheckNoDonor(NSURL *folder) {
    NSError *error = nil;
    NSArray *children = [NSFileManager.defaultManager contentsOfDirectoryAtURL:folder includingPropertiesForKeys:nil options:0 error:&error];
    EC308Assert(children != nil, error.localizedDescription ?: @"cannot enumerate export folder");
    NSData *secret = EC308Bytes(@"EC308_OUTSIDE_ROOT_SECRET_591d2089");
    for (NSURL *child in children) {
        struct stat status;
        EC308Assert(lstat(child.path.fileSystemRepresentation, &status) == 0 && !S_ISLNK(status.st_mode), @"export contains an unreadable entry or symbolic link");
        if (S_ISDIR(status.st_mode)) EC308CheckNoDonor(child);
        else {
            EC308Assert(S_ISREG(status.st_mode), @"export contains a non-regular file");
            NSData *bytes = [NSData dataWithContentsOfURL:child options:0 error:&error];
            EC308Assert(bytes != nil && [bytes rangeOfData:secret options:0 range:NSMakeRange(0, bytes.length)].location == NSNotFound, @"outside-root donor content leaked into export");
        }
    }
}
static NSDictionary *EC308CheckFolder(NSURL *folder, NSDictionary *summary, NSDictionary *expected) {
    struct stat status;
    EC308Assert(folder.isFileURL && lstat(folder.path.fileSystemRepresentation, &status) == 0 && S_ISDIR(status.st_mode), @"export must return a real folder, not a ZIP");
    EC308Assert(![folder.path.pathExtension.lowercaseString isEqual:@"zip"] && ![folder.path isEqual:EC308Root], @"export returned ZIP/source root instead of a new output folder");
    NSDictionary *manifest = EC308ReadJSON([folder URLByAppendingPathComponent:@"_export-info/manifest.json"]);
    EC308Assert([manifest[@"items"] isKindOfClass:NSArray.class], @"manifest items missing");
    NSArray *items = manifest[@"items"], *oracle = expected[@"items"];
    if(items.count!=oracle.count){NSMutableArray *actual=[NSMutableArray new],*wanted=[NSMutableArray new];for(NSDictionary *item in items)[actual addObject:item[@"file"]?:@"?"];for(NSDictionary *item in oracle)[wanted addObject:item[@"file"]?:@"?"];EC308Assert(NO,[NSString stringWithFormat:@"manifest item count %lu differs from oracle %lu (decoded %@); actual=%@ expected=%@ issues=%@",(unsigned long)items.count,(unsigned long)oracle.count,summary[@"decodedCount"]?:@"unknown",actual,wanted,manifest[@"issues"]]);}
    EC308Assert([summary[@"written"] unsignedIntegerValue] == oracle.count && [summary[@"itemsVerified"] unsignedIntegerValue] == oracle.count, @"written/verified counts do not match independent oracle");
    NSMutableDictionary *byFile = [NSMutableDictionary new];
    for (id value in items) {
        EC308Assert([value isKindOfClass:NSDictionary.class], @"manifest item is not a dictionary");
        NSDictionary *item = value;
        NSString *file = item[@"file"];
        EC308Assert([file isKindOfClass:NSString.class] && file.length > 0 && !file.isAbsolutePath && ![file.pathComponents containsObject:@".."] && byFile[file] == nil, @"invalid/duplicate artifact path");
        byFile[file] = item;
    }
    NSUInteger colors = 0;
    for (NSDictionary *wanted in oracle) {
        NSString *file = wanted[@"file"];
        NSDictionary *item = byFile[file];
        EC308Assert(item != nil && [item[@"provider"] isEqual:wanted[@"provider"]], [NSString stringWithFormat:@"missing original or wrong provider for %@", file]);
        if ([wanted[@"provider"] isEqual:@"ThemeColors"]) {
            ++colors;
            EC308Assert([[item[@"key"] lastPathComponent] isEqual:wanted[@"key"]], @"color manifest lost exact original filename");
        } else if ([wanted[@"provider"] isEqual:@"ThemeSource"]) {
            EC308Assert([item[@"key"] isEqual:@"themebox.dat"], @"opaque pack was renamed or decoded");
        } else if ([wanted[@"provider"] isEqual:@"ThemeBoxDecoded"]) {
            EC308Assert([item[@"key"] isEqual:wanted[@"key"]], @"decoded runtime key changed");
            EC308Assert([item[@"source"] containsString:@"decoded"], @"decoded runtime source was not recorded");
        } else {
            EC308Assert([item[@"key"] isEqual:wanted[@"key"]], @"raw asset key changed or belongs to stale provider");
            NSString *identity = [NSString stringWithFormat:@"%@|%@", wanted[@"provider"], wanted[@"key"]];
            EC308Assert([EC308Reads[identity] unsignedIntegerValue] >= 2, [@"raw original not re-fetched for verification: " stringByAppendingString:identity]);
        }
        NSData *golden = [[NSData alloc] initWithBase64EncodedString:wanted[@"base64"] options:0];
        NSData *saved = [NSData dataWithContentsOfURL:[folder URLByAppendingPathComponent:file]];
        EC308Assert(golden != nil && [saved isEqualToData:golden], [@"export bytes differ from independent fixture: " stringByAppendingString:file]);
        EC308Assert([item[@"original"] boolValue] && ![item[@"snapshot"] boolValue], @"export item was not recorded as an original");
    }
    EC308Assert(colors == (([EC308Case isEqual:@"palette-missing-css"] || [EC308Case isEqual:@"symlink-color-css"]) ? 1u : 2u), @"wrong number of original color files");
    for (NSString *key in expected[@"excludedKeys"])
        for (NSDictionary *item in items) EC308Assert(![item[@"key"] isEqual:key], @"inactive engine resource included in export");
    EC308CheckNoDonor(folder);
    return manifest;
}
static void EC308Copy(NSURL *source, NSURL *target) {
    NSError *error = nil;
    EC308Assert([NSFileManager.defaultManager copyItemAtURL:source toURL:target error:&error], error.localizedDescription ?: @"cannot retain exported case folder");
}
static void EC308RunCase(NSUInteger position, NSMutableArray *results, dispatch_block_t completion) {
    EC308Main();
    if (position == EC308Cases().count) {
        EC308JSON(@{@"status":@"passed", @"schema":@1, @"assertions":@(EC308Assertions), @"cases":results}, [EC308Documents() URLByAppendingPathComponent:@"engine308-checks.json"]);
        EC308Write(EC308Bytes(@"done\n"), [EC308Documents() URLByAppendingPathComponent:@"engine308-done.txt"]);
        NSError *error = nil;
        EC308Assert([NSFileManager.defaultManager removeItemAtURL:EC308RunRoot error:&error], error.localizedDescription ?: @"cannot remove temporary source fixtures");
        EC308Running = NO;
        NSLog(@"ENGINE308_CHECK_PASSED %lu cases", (unsigned long)results.count);
        completion(); return;
    }
    NSString *name = EC308Cases()[position];
    EC308Configure(name);
    NSURL *caseFolder = [EC308Artifacts URLByAppendingPathComponent:name isDirectory:YES];
    // Freeze and persist our oracle BEFORE exporter execution. Never derive bytes/paths from its manifest.
    NSURL *oracleURL = [caseFolder URLByAppendingPathComponent:@"expected.json"];
    EC308JSON(EC308Expected(), oracleURL);
    NSDictionary *expected = EC308ReadJSON(oracleURL);
    __block BOOL delivered = NO;
    SaoqiangWCAssetsExportThemeEngineFixture(SaoqiangWC308Manager.class, SaoqiangWC308LegacyLoader.class, SaoqiangWC308Assets.class, SaoqiangWC308Util.class,
        ^(NSURL *directory, NSDictionary *summary, NSString *error) {
            EC308Main(); EC308Assert(!delivered, @"export completion called more than once"); delivered = YES;
            EC308Assert([summary isKindOfClass:NSDictionary.class] && ![summary[@"busy"] boolValue] && ![summary[@"cancelled"] boolValue], @"invalid finished export state");
            EC308Assert(EC308FlagCalls > 0, @"enabledNewEngine scalar class method was not consulted");
            EC308Assert(EC308Enabled ? EC308OldCalls == 0 : EC308NewCalls == 0, @"raw getter from inactive engine was used");
            if (EC308Enabled) EC308Assert(EC308NewMapCalls > 0, @"new NSDictionary themeFiles was not enumerated");
            else EC308Assert(EC308OldIndexCalls > 0, @"legacy NSArray themeFiles was not enumerated");
            BOOL mutation = [name isEqual:@"source-color-mutation"], symlink = [name isEqual:@"symlink-color-css"];
            if([name isEqual:@"reference-theme-switch"]){
                EC308Assert(directory==nil&&error.length&&! [summary[@"referenceComplete"]boolValue],@"theme switch was not rejected");
            } else if (mutation) {
                EC308Assert(EC308Mutated && EC308NewCalls > 0, @"source mutation fixture did not run on first raw getter");
                NSData *changed = [NSData dataWithContentsOfFile:[EC308Root stringByAppendingPathComponent:@"weui_color_new.xml"]];
                EC308Assert([changed isEqualToData:EC308ChangedXML()], @"source mutation was not applied");
                EC308Assert(directory == nil && ![summary[@"available"] boolValue] && ![summary[@"complete"] boolValue] && error.length > 0, @"changed current-theme color source must abort export");
            } else if (directory) {
                EC308Assert(!error.length && [summary[@"available"] boolValue], @"returned folder is not available");
                NSDictionary *manifest = EC308CheckFolder(directory, summary, expected);
                if([name isEqual:@"reference-2547"]){
                    EC308Assert([summary[@"referenceCount"]unsignedIntegerValue]==2547&&[summary[@"referenceMatched"]unsignedIntegerValue]==2547&&[summary[@"referenceComplete"]boolValue],@"large reference list not fully read and verified");
                    EC308Assert(![summary[@"complete"]boolValue]&&![summary[@"expectedKnown"]boolValue],@"reference coverage falsely called full pack");
                }else if([name isEqual:@"reference-wrong-missing"]){
                    EC308Assert([summary[@"referenceCount"]unsignedIntegerValue]==3&&[summary[@"referenceMatched"]unsignedIntegerValue]==1&&[summary[@"referenceMissing"]unsignedIntegerValue]==1&&[summary[@"referenceMismatch"]unsignedIntegerValue]==1, @"wrong/missing reference statistics");
                    EC308Assert(![summary[@"referenceComplete"]boolValue]&&![summary[@"complete"]boolValue],@"wrong bytes called complete");
                    NSArray *observed=manifest[@"referenceObserved"];
                    EC308Assert(observed.count==1&&[observed[0][@"actualBytes"]unsignedIntegerValue]>0&&[observed[0][@"actualSHA256"]length]==64&&[observed[0][@"expectedSHA256"]length]==64,@"mismatched source evidence not recorded");
                }else if([name isEqual:@"reference-other-id"]){EC308Assert([summary[@"referenceCount"]unsignedIntegerValue]==0,@"foreign reference reused");
                } else if ([name isEqual:@"palette-missing-css"] || symlink) {
                    EC308Assert(EC308ColorDiagnostic(summary, NO) || EC308ColorDiagnostic(manifest, NO), @"missing/unsafe optional palette requires color status or an issue");
                } else if ([name isEqual:@"newengine-opaque-pack-only"]) {
                    EC308Assert([summary[@"opaqueContainer"] boolValue] && ![summary[@"complete"] boolValue] && ![summary[@"expectedKnown"] boolValue], @"opaque pack was falsely reported as all icons extracted");
                    EC308Assert([summary[@"diagnostic"] containsString:@"不能声明全部展开"], @"opaque pack limitation was not explained");
                } else if ([name isEqual:@"newengine-decoded-cache-only"]) {
                    EC308Assert(![summary[@"complete"] boolValue] && ![summary[@"expectedKnown"] boolValue], @"runtime-only capture was falsely reported complete");
                    EC308Assert([summary[@"warnings"] unsignedIntegerValue] > 0, @"runtime-only coverage warning was not recorded");
                } else {
                    EC308Assert([summary[@"complete"] boolValue], @"all fixture originals are present but export is incomplete");
                    EC308Assert([summary[@"missing"] unsignedIntegerValue] == 0 && [summary[@"failed"] unsignedIntegerValue] == 0, @"healthy engine/color export reported missing or failed items");
                }
                EC308Copy(directory, [caseFolder URLByAppendingPathComponent:@"output" isDirectory:YES]);
            } else {
                EC308Assert(symlink && error.length > 0 && ![summary[@"available"] boolValue] && ![summary[@"complete"] boolValue], @"expected usable originals folder (or safe symlink rejection)");
            }
            if (!mutation && !symlink && ![name isEqual:@"reference-theme-switch"]) EC308Assert(directory != nil, @"normal/missing-optional case did not return a folder");
            NSDictionary *result = @{@"case":name, @"status":@"passed", @"directoryReturned":(directory ? @YES : @NO),
                @"output":directory ? [NSString stringWithFormat:@"engine308-cases/%@/output", name] : @"",
                @"expected":[NSString stringWithFormat:@"engine308-cases/%@/expected.json", name],
                @"error":error ?: @"", @"summary":summary, @"engineEnabled":@(EC308Enabled),
                @"rawReads":[EC308Reads copy], @"newRawCalls":@(EC308NewCalls), @"legacyRawCalls":@(EC308OldCalls),
                @"newMapCalls":@(EC308NewMapCalls), @"legacyIndexCalls":@(EC308OldIndexCalls),
                @"engineFlagCalls":@(EC308FlagCalls), @"mutationApplied":@(EC308Mutated)};
            EC308JSON(result, [caseFolder URLByAppendingPathComponent:@"result.json"]);
            [results addObject:result];
            dispatch_async(dispatch_get_main_queue(), ^{ EC308RunCase(position + 1, results, completion); });
        });
}

void SaoqiangWCAssetsRunEngine308Checks(void (^completion)(void)) {
    EC308Main(); EC308Assert(!EC308Running && completion != nil, @"engine308 checks require a completion and one active run");
    EC308Running = YES; EC308Assertions = 0; EC308Case = @"setup";
    static NSUInteger generation = 0;
    NSUInteger run = ++generation;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(180 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (EC308Running && generation == run) EC308Assert(NO, @"engine308 checks exceeded 180 seconds or completion was never called");
    });
    EC308CheckABI(SaoqiangWC308Util.class, @selector(enabledNewEngine), YES, @encode(BOOL), 2);
    EC308CheckABI(SaoqiangWC308Manager.class, @selector(loadTheme), NO, @encode(BOOL), 2);
    EC308CheckABI(SaoqiangWC308Assets.class, @selector(themeFiles), NO, @encode(id), 2);
    EC308CheckABI(SaoqiangWC308LegacyLoader.class, @selector(themeFiles), NO, @encode(id), 2);
    EC308CheckABI(SaoqiangWC308Assets.class, @selector(dataWithContentsOfFile:), NO, @encode(id), 3);
    EC308CheckABI(SaoqiangWC308LegacyLoader.class, @selector(dataWithContentsOfFile:), NO, @encode(id), 3);
    NSFileManager *fm = NSFileManager.defaultManager;
    // Leave older FeatureChecks/0.11 artifacts, including any failure marker, untouched.
    for (NSString *name in @[@"engine308-checks.json", @"engine308-done.txt", @"engine308-cases"]) {
        NSURL *url = [EC308Documents() URLByAppendingPathComponent:name];
        if ([fm fileExistsAtPath:url.path]) {
            NSError *error = nil;
            EC308Assert([fm removeItemAtURL:url error:&error], error.localizedDescription ?: @"cannot clear previous engine308 artifacts");
        }
    }
    EC308Artifacts = [EC308Documents() URLByAppendingPathComponent:@"engine308-cases" isDirectory:YES];
    EC308RunRoot = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[@"SaoqiangWC308-" stringByAppendingString:NSUUID.UUID.UUIDString]] isDirectory:YES];
    EC308RunCase(0, [NSMutableArray new], completion);
}
