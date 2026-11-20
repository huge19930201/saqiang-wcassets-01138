#import "NamingChecks.h"
#import "SaoqiangWCAssets.h"
#import "SaoqiangWCAssetsInspector.h"
#import "SaoqiangWCAssetsTheme.h"
#import <QuartzCore/QuartzCore.h>
#import <stdlib.h>

static NSString *const NCSource = @"NamingChecks synthetic source";
static NSString *const NCVisible = @"可见消息气泡背景 · NamingChecks";
static NSDictionary<NSString *, id> *NCReport;
static NSUInteger NCAssertions;

static void NCFail(NSString *reason) __attribute__((noreturn));
static void NCFail(NSString *reason) {
    NSString *message = [@"NAMING_CHECK_FAILED " stringByAppendingString:reason ?: @"unknown failure"];
    NSLog(@"%@", message);
    NSURL *documents = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    if (documents) {
        [NSFileManager.defaultManager createDirectoryAtURL:documents withIntermediateDirectories:YES attributes:nil error:NULL];
        [message writeToURL:[documents URLByAppendingPathComponent:@"capture-failed.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    abort();
}
static void NCRequire(BOOL condition, NSString *reason) {
    ++NCAssertions;
    if (!condition) NCFail(reason);
}
static NSString *NCContext(NSString *test, NSString *detail) {
    return [NSString stringWithFormat:@"%@ · %@", test, detail];
}
static NSArray<NSString *> *NCNames(void) {
    return @[@"ChatRoom_Bubble_HB_Sender_Dark@2x.png",
             @"ChatRoom_Bubble_AA_Receiver@3x.png",
             @"ChatRoom_Bubble_Overtime_Receiver@2x.png",
             @"ChatRoom_Bubble_HB_Sender_Handled@2x.png",
             @"ChatRoom_Bubble_App_Sender@2x.png"];
}
// All fixtures have different dimensions AND pixels. No imageNamed cache, user
// assets, content-hash guesses, or shared PNG data between unrelated cases.
static NSData *NCPNG(NSUInteger index) {
    CGSize size = CGSizeMake(36 + index, 25 + index % 13);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1; format.opaque = YES;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [[UIColor colorWithRed:((index * 29 + 31) % 251) / 255.0 green:((index * 47 + 17) % 251) / 255.0 blue:((index * 71 + 11) % 251) / 255.0 alpha:1] setFill];
        CGContextFillRect(context.CGContext, (CGRect){CGPointZero, size});
        [UIColor.whiteColor setFill];
        CGContextFillRect(context.CGContext, CGRectMake(2 + index % 7, 3, 3, 5 + index % 9));
    }];
    NSData *data = [UIImagePNGRepresentation(image) copy];
    NCRequire(data.length > 8 && data.length < 32768, @"fixture PNG must be small and valid");
    NCRequire(![data isKindOfClass:NSMutableData.class], @"fixture PNG must be immutable");
    return data;
}
static UIImage *NCDecode(NSData *data) {
    UIImage *image = [UIImage imageWithData:data];
    NCRequire(image.CGImage != NULL, @"synthetic PNG must decode through UIKit");
    return image;
}
static SaoqiangWCAssetsImageInfo *NCNamed(UIImage *image, NSString *name, NSData *data, NSString *test) {
    SaoqiangWCAssetsImageInfo *info = SaoqiangWCAssetsImageInfoForImage(image);
    NCRequire(info != nil, NCContext(test, @"missing image metadata"));
    NCRequire([info.SaoqiangWCAssetsName isEqualToString:name], NCContext(test, [NSString stringWithFormat:@"expected %@; got %@", name, info.SaoqiangWCAssetsName]));
    NCRequire(info.SaoqiangWCAssetsVerifiedBubble, NCContext(test, @"bubble promotion lost"));
    NCRequire(!info.SaoqiangWCAssetsSVG, NCContext(test, @"PNG incorrectly classified as SVG"));
    if (data) NCRequire([info.SaoqiangWCAssetsRawSourceData isEqualToData:data], NCContext(test, @"original PNG bytes missing or replaced"));
    return info;
}
static void NCUnnamed(UIImage *image, NSString *test) {
    SaoqiangWCAssetsImageInfo *info = SaoqiangWCAssetsImageInfoForImage(image);
    NCRequire(info && info.SaoqiangWCAssetsVerifiedBubble, NCContext(test, @"confirmed unnamed background disappeared"));
    NCRequire([info.SaoqiangWCAssetsName isEqualToString:@"无原始资源名"], NCContext(test, @"ambiguous/missing name must not be guessed"));
    NCRequire(!info.SaoqiangWCAssetsRawSourceData.length && !info.SaoqiangWCAssetsPath.length, NCContext(test, @"unnamed background borrowed an original source"));
    NSData *png = UIImagePNGRepresentation(image);
    NCRequire(png.length > 8 && [UIImage imageWithData:png].CGImage != NULL, NCContext(test, @"unnamed background must remain PNG-saveable"));
}
static void NCUpgradeCases(NSArray<NSData *> *fixtures, NSMutableArray *rows) {
    NSArray<NSString *> *names = NCNames();
    for (NSUInteger n = 0; n < names.count; ++n) {
        NSString *name = names[n]; NSData *data = fixtures[n]; UIImage *image = NCDecode(data);
        NCRequire(SaoqiangWCAssetsBubbleName(name), NCContext(name, @"real bubble filename family rejected"));
        NCRequire(!SaoqiangWCAssetsImageInfoForImage(image), NCContext(name, @"untagged PNG acquired metadata"));
        SaoqiangWCAssetsAssociateBubbleImage(image, nil, NCVisible);
        NCUnnamed(image, name);
        SaoqiangWCAssetsImageInfo *before = SaoqiangWCAssetsImageInfoForImage(image);
        NSUInteger revision = before.SaoqiangWCAssetsRevision;
        SaoqiangWCAssetsSetImageIdentityForRevision(image, @"stale-unnamed-record", revision);
        NCRequire([before.SaoqiangWCAssetsIdentity isEqualToString:@"stale-unnamed-record"], NCContext(name, @"identity fixture not installed"));
        // Same UIImage was captured unnamed; exact source evidence arrives later.
        SaoqiangWCAssetsAssociateSourceImage(image, name, data, NCSource, YES);
        SaoqiangWCAssetsImageInfo *after = NCNamed(image, name, data, name);
        NCRequire(after.SaoqiangWCAssetsRevision > revision, NCContext(name, @"upgrade did not invalidate revision"));
        NCRequire(!after.SaoqiangWCAssetsIdentity.length, NCContext(name, @"upgrade retained the unnamed record identity"));
        SaoqiangWCAssetsSetImageIdentityForRevision(image, @"late-stale-write", revision);
        NCRequire(!after.SaoqiangWCAssetsIdentity.length, NCContext(name, @"late old-revision completion overwrote upgrade"));
        [rows addObject:@{@"name":name, @"case":@"placeholder-to-exact-source", @"beforeRevision":@(revision), @"afterRevision":@(after.SaoqiangWCAssetsRevision), @"rawBytes":@(data.length)}];
    }
}
static void NCResizableCase(NSData *data) {
    NSString *name = NCNames()[1]; UIImage *input = NCDecode(data);
    SaoqiangWCAssetsAssociateSourceImage(input, name, data, NCSource, YES);
    NCRequire(!SaoqiangWCAssetsImageInfoForImage(input).SaoqiangWCAssetsVerifiedBubble, @"candidate was promoted without a visible background");
    UIEdgeInsets insets = UIEdgeInsetsMake(5, 7, 5, 7);
    UIImage *before = [input resizableImageWithCapInsets:insets];
    NCRequire([SaoqiangWCAssetsBubbleCandidateName(before) isEqualToString:name], @"resizable before promotion lost exact candidate name");
    NCRequire(!SaoqiangWCAssetsImageInfoForImage(before).SaoqiangWCAssetsVerifiedBubble, @"resizable candidate became trusted prematurely");
    SaoqiangWCAssetsAssociateBubbleImage(before, nil, NCVisible);
    SaoqiangWCAssetsImageInfo *info = NCNamed(before, name, data, @"resizable before promotion");
    NCRequire(UIEdgeInsetsEqualToEdgeInsets(info.SaoqiangWCAssetsCapInsets, insets), @"pre-promotion resizable capInsets lost");
    SaoqiangWCAssetsAssociateBubbleImage(input, nil, NCVisible);
    NCNamed(input, name, data, @"original promoted after derivative");
    UIImage *after = [input resizableImageWithCapInsets:insets resizingMode:UIImageResizingModeStretch];
    info = NCNamed(after, name, data, @"resizable after promotion");
    NCRequire(UIEdgeInsetsEqualToEdgeInsets(info.SaoqiangWCAssetsCapInsets, insets) && info.SaoqiangWCAssetsResizingMode == UIImageResizingModeStretch, @"post-promotion resizable settings lost");
}
static void NCSourceScopes(NSArray<NSData *> *fixtures) {
    NSArray<NSString *> *names = NCNames();
    for (NSUInteger n = 0; n < names.count; ++n) {
        NSString *actual = [@"/NamingChecksSynthetic" stringByAppendingPathComponent:names[n]];
        NSString *request = [[names[n] componentsSeparatedByString:@"@"] firstObject];
        NCRequire(SaoqiangWCAssetsRequestMatchesFile(request, actual), NCContext(names[n], @"extensionless request did not resolve to exact file"));
        NCRequire(!SaoqiangWCAssetsRequestMatchesFile(actual, request), @"file resolution must be directed");
        NCRequire(SaoqiangWCAssetsRequestMatchesFile(names[n].stringByDeletingPathExtension, names[n]), @"explicit scale must resolve to that same scale's PNG");
        NCRequire(!SaoqiangWCAssetsSameResourceName(request, names[n]), @"scoped scale resolution must not weaken general resource equality");
        NSData *data = fixtures[5 + n]; UIImage *image = NCDecode(data);
        id result = SaoqiangWCAssetsCallNamedSource(request, NCSource, YES, ^id {
            SaoqiangWCAssetsObserveSourceData(actual, data); return image;
        });
        NCRequire(result == image, @"named source wrapper changed the original return value");
        SaoqiangWCAssetsAssociateBubbleImage(image, nil, NCVisible);
        SaoqiangWCAssetsImageInfo *info = NCNamed(image, names[n], data, @"request to concrete file");
        NCRequire([info.SaoqiangWCAssetsPath isEqualToString:actual] && [SaoqiangWCAssetsObservedFilePath(image) isEqualToString:actual], NCContext(names[n], @"exact observed path lost"));
    }
    NSArray<NSArray<NSString *> *> *mismatches = @[
        @[@"ChatRoom_Bubble_HB_Sender_Dark@2x", @"ChatRoom_Bubble_HB_Sender_Dark@3x.png"],
        @[@"ChatRoom_Bubble_HB_Sender_Dark", @"ChatRoom_Bubble_HB_Receiver_Dark@2x.png"],
        @[@"ChatRoom_Bubble_HB_Sender", @"ChatRoom_Bubble_HB_Sender_Dark@2x.png"],
        @[@"ChatRoom_Bubble_HB_Sender", @"ChatRoom_Bubble_HB_Sender_Handled@2x.png"],
        @[@"ChatRoom_Bubble_HB_Sender_Dark", @"ChatRoom_Bubble_HB_Sender_Handled@2x.png"]
    ];
    for (NSUInteger n = 0; n < mismatches.count; ++n) {
        NSString *request = mismatches[n][0], *actual = mismatches[n][1];
        NCRequire(!SaoqiangWCAssetsRequestMatchesFile(request, actual), NCContext(request, @"scale/direction/state mismatch merged"));
        NCRequire(!SaoqiangWCAssetsRequestMatchesFile(actual, request), @"reverse mismatch unexpectedly merged");
        NSData *data = fixtures[10 + n]; UIImage *image = NCDecode(data);
        SaoqiangWCAssetsCallNamedSource(request, NCSource, YES, ^id {
            SaoqiangWCAssetsObserveSourceData(actual, data); return image;
        });
        SaoqiangWCAssetsAssociateBubbleImage(image, nil, NCVisible);
        SaoqiangWCAssetsImageInfo *info = SaoqiangWCAssetsImageInfoForImage(image);
        NCRequire(![info.SaoqiangWCAssetsName isEqualToString:actual] && !info.SaoqiangWCAssetsRawSourceData.length && !info.SaoqiangWCAssetsPath.length, NCContext(request, @"unrelated observation contaminated the returned image"));
    }
    // Earlier invocations of this same request must not supply a later raw file.
    UIImage *fresh = NCDecode(fixtures[15]);
    SaoqiangWCAssetsCallNamedSource(@"ChatRoom_Bubble_HB_Sender_Dark", NCSource, YES, ^id { return fresh; });
    SaoqiangWCAssetsAssociateBubbleImage(fresh, nil, NCVisible);
    SaoqiangWCAssetsImageInfo *freshInfo = SaoqiangWCAssetsImageInfoForImage(fresh);
    NCRequire(!freshInfo.SaoqiangWCAssetsRawSourceData.length && !freshInfo.SaoqiangWCAssetsPath.length, @"source bytes leaked across separate named invocations");
}
static void NCDataDecoders(NSArray<NSData *> *fixtures) {
    NSArray<NSString *> *names = NCNames();
    for (NSUInteger n = 0; n < 4; ++n) {
        NSData *data = fixtures[16 + n]; NSString *name = names[n];
        SaoqiangWCAssetsAssociateNamedData(data, name, NCSource, YES);
        UIImage *image = nil;
        switch (n) {
            case 0: image = [UIImage imageWithData:data]; break;
            case 1: image = [UIImage imageWithData:data scale:3]; break;
            case 2: image = [[UIImage alloc] initWithData:data]; break;
            default: image = [[UIImage alloc] initWithData:data scale:2]; break;
        }
        NCRequire(image.CGImage != NULL, @"public NSData decoder returned no image");
        NCRequire([SaoqiangWCAssetsBubbleCandidateName(image) isEqualToString:name], NCContext(name, @"public decoder hook lost named NSData"));
        NCRequire(!SaoqiangWCAssetsImageInfoForImage(image).SaoqiangWCAssetsVerifiedBubble, @"NSData candidate prematurely became a verified background");
        SaoqiangWCAssetsAssociateBubbleImage(image, nil, NCVisible);
        NCNamed(image, name, data, @"public UIImage NSData decoder");
        if (n == 1 || n == 3) NCRequire(image.scale == (n == 1 ? 3 : 2), @"decoder hook changed requested scale");
    }
    UIImage *untagged = NCDecode(fixtures[20]);
    NCRequire(!SaoqiangWCAssetsImageInfoForImage(untagged) && !SaoqiangWCAssetsBubbleCandidateName(untagged).length, @"untagged random PNG inherited a name");
    // Identical bytes in a different NSData object are not evidence of its name.
    NSData *tagged = fixtures[16];
    NSData *copy = [[NSData alloc] initWithBytes:tagged.bytes length:tagged.length];
    NCRequire(copy != tagged && [copy isEqualToData:tagged], @"distinct identical-byte fixture was not created");
    UIImage *copied = NCDecode(copy);
    NCRequire(!SaoqiangWCAssetsImageInfoForImage(copied) && !SaoqiangWCAssetsBubbleCandidateName(copied).length, @"decoder guessed name from equal bytes rather than observed data object");
}
static void NCFileDecoder(NSData *data) {
    NSString *name = NCNames()[0];
    NSURL *directory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[@"NamingChecks-" stringByAppendingString:NSUUID.UUID.UUIDString]] isDirectory:YES];
    NSURL *file = [directory URLByAppendingPathComponent:name];
    NSError *error = nil;
    NCRequire([NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&error], NCContext(@"temporary directory", error.localizedDescription));
    @try {
        NCRequire([data writeToURL:file options:NSDataWritingAtomic error:&error], NCContext(@"temporary PNG write", error.localizedDescription));
        UIImage *image = [[UIImage alloc] initWithContentsOfFile:file.path];
        NCRequire(image.CGImage != NULL, @"initWithContentsOfFile could not decode synthetic PNG");
        NCRequire([SaoqiangWCAssetsObservedFilePath(image) isEqualToString:file.path], @"initWithContentsOfFile hook lost exact path");
        SaoqiangWCAssetsAssociateBubbleImage(image, nil, NCVisible);
        SaoqiangWCAssetsImageInfo *info = NCNamed(image, name, nil, @"initWithContentsOfFile");
        NCRequire([info.SaoqiangWCAssetsPath isEqualToString:file.path], @"file-loaded bubble promotion lost full path");
        NCRequire([[NSData dataWithContentsOfURL:file] isEqualToData:data], @"file fixture no longer contains original synthetic PNG");
    } @finally {
        NSError *cleanup = nil;
        NCRequire([NSFileManager.defaultManager removeItemAtURL:directory error:&cleanup], NCContext(@"temporary fixture cleanup", cleanup.localizedDescription));
    }
}
static void NCLayerLifetime(NSData *data, BOOL promoteFirst) {
    NSString *name = promoteFirst ? NCNames()[3] : NCNames()[4];
    CALayer *layer = [CALayer layer]; layer.contentsScale = 2;
    __weak UIImage *weakOriginal = nil;
    @autoreleasepool {
        UIImage *original = [[UIImage alloc] initWithData:data scale:2];
        NCRequire(original.CGImage != NULL, @"layer lifetime fixture decode failed");
        weakOriginal = original;
        SaoqiangWCAssetsAssociateSourceImage(original, name, data, NCSource, YES);
        if (promoteFirst) SaoqiangWCAssetsAssociateBubbleImage(original, nil, NCVisible);
        SaoqiangWCAssetsRememberBacking(original);
        layer.contents = (__bridge id)original.CGImage;
        original = nil;
    }
    NCRequire(weakOriginal == nil, @"backing metadata cache retained the original UIImage");
    UIImage *restored = SaoqiangWCAssetsImageForLayer(layer);
    NCRequire(restored && restored.CGImage == (__bridge CGImageRef)layer.contents, @"layer did not restore its exact retained CGImage");
    NCRequire(restored.scale == 2, @"layer restoration lost contentsScale");
    if (!promoteFirst) {
        NCRequire([SaoqiangWCAssetsBubbleCandidateName(restored) isEqualToString:name], @"layer lost candidate after original UIImage deallocation");
        SaoqiangWCAssetsAssociateBubbleImage(restored, nil, NCVisible);
    }
    NCNamed(restored, name, data, @"retained layer after UIImage deallocation");
    layer.contents = nil;
}
static void NCConflictCases(NSArray<NSData *> *fixtures) {
    NSArray<NSArray<NSString *> *> *pairs = @[
        @[@"ChatRoom_Bubble_HB_Sender_Dark@2x.png", @"ChatRoom_Bubble_HB_Sender_Dark@3x.png"],
        @[@"ChatRoom_Bubble_HB_Sender@2x.png", @"ChatRoom_Bubble_HB_Receiver@2x.png"],
        @[@"ChatRoom_Bubble_HB_Sender_Dark@2x.png", @"ChatRoom_Bubble_HB_Sender_Handled@2x.png"]
    ];
    for (NSUInteger n = 0; n < pairs.count; ++n) {
        NSData *data = fixtures[25 + n]; UIImage *image = NCDecode(data);
        SaoqiangWCAssetsAssociateSourceImage(image, pairs[n][0], data, NCSource, YES);
        SaoqiangWCAssetsAssociateBubbleCandidate(image, pairs[n][1]);
        NCRequire(!SaoqiangWCAssetsBubbleCandidateName(image).length, @"conflicting candidate aliases picked a name");
        SaoqiangWCAssetsAssociateBubbleImage(image, nil, NCVisible);
        NCUnnamed(image, @"conflicting candidate aliases");
        // A repeated earlier name must not erase already proven ambiguity.
        SaoqiangWCAssetsAssociateSourceImage(image, pairs[n][0], data, NCSource, YES);
        NCUnnamed(image, @"conflict remains sticky after another source arrives");
        UIImage *derived = [image resizableImageWithCapInsets:UIEdgeInsetsMake(3, 4, 3, 4)];
        SaoqiangWCAssetsAssociateBubbleImage(derived, nil, NCVisible);
        NCUnnamed(derived, @"resizable conflicting background remains saveable");
    }
    UIImage *namedConflict = NCDecode(fixtures[28]);
    SaoqiangWCAssetsAssociateNamedImage(namedConflict, @"icons_filled_first", NCSource, nil, NO);
    SaoqiangWCAssetsAssociateNamedImage(namedConflict, @"icons_filled_second", NCSource, nil, NO);
    SaoqiangWCAssetsAssociateBubbleImage(namedConflict, nil, NCVisible);
    NCUnnamed(namedConflict, @"conflicting trusted aliases promoted as background");
    NSData *ambiguousData = fixtures[29];
    SaoqiangWCAssetsAssociateNamedData(ambiguousData, pairs[0][0], NCSource, YES);
    SaoqiangWCAssetsAssociateNamedData(ambiguousData, pairs[0][1], NCSource, YES);
    UIImage *decoded = NCDecode(ambiguousData);
    NCRequire(!SaoqiangWCAssetsBubbleCandidateName(decoded).length, @"ambiguous NSData selected one alias during decode");
    SaoqiangWCAssetsAssociateBubbleImage(decoded, nil, NCVisible);
    NCUnnamed(decoded, @"ambiguous NSData remains unnamed and saveable");
    UIImage *unnamed = NCDecode(fixtures[30]);
    SaoqiangWCAssetsAssociateBubbleImage(unnamed, nil, NCVisible);
    NCUnnamed(unnamed, @"genuinely missing name remains saveable");
    CALayer *unrelated = [CALayer layer];
    UIImage *other = NCDecode(fixtures[31]); unrelated.contents = (__bridge id)other.CGImage;
    NCRequire(!SaoqiangWCAssetsImageForLayer(unrelated), @"unrelated layer borrowed a known resource name");
    unrelated.contents = nil;
}
void SaoqiangWCAssetsRunNamingChecks(void) {
    NCRequire(NSThread.isMainThread, @"run naming checks on the main thread");
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NCRequire(!SaoqiangWCAssetsIsSuppressed() && !SaoqiangWCAssetsOwnUIActive(), @"run before presenting the plugin UI and outside suppression");
        @try {
            @autoreleasepool {
                NSMutableArray<NSData *> *fixtures = [NSMutableArray new];
                for (NSUInteger index = 0; index < 32; ++index) [fixtures addObject:NCPNG(index)];
                NCRequire([NSSet setWithArray:fixtures].count == fixtures.count, @"synthetic PNG fixtures must be byte-distinct");
                SaoqiangWCAssetsInstallImageHooks();
                NSMutableArray *rows = [NSMutableArray new];
                NCUpgradeCases(fixtures, rows);
                NCResizableCase(fixtures[21]);
                NCSourceScopes(fixtures);
                NCDataDecoders(fixtures);
                NCFileDecoder(fixtures[22]);
                NCLayerLifetime(fixtures[23], YES);
                NCLayerLifetime(fixtures[24], NO);
                NCConflictCases(fixtures);
                NCReport = @{@"status":@"passed", @"assertions":@(NCAssertions), @"named-cases":[rows copy],
                             @"checks":@[@"placeholder-upgrade", @"stale-revision-rejected", @"resizable-before-and-after-promotion", @"scoped-request-to-exact-file", @"scale-direction-state-isolation", @"four-public-data-decoders", @"untagged-and-equal-byte-isolation", @"initWithContentsOfFile", @"layer-after-UIImage-release", @"conflicting-aliases", @"unnamed-PNG-saveable"]};
            }
        } @catch (NSException *exception) {
            NCFail([NSString stringWithFormat:@"%@ · %@", exception.name, exception.reason]);
        }
        NSLog(@"NAMING_CHECK_PASSED %@", NCReport);
    });
}
NSDictionary<NSString *, id> *SaoqiangWCAssetsNamingSummary(void) {
    return NCReport ?: @{};
}
