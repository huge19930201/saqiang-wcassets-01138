#import "SaoqiangWCAssets.h"
#import "SaoqiangWCAssetsInspector.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <stdatomic.h>
#import <objc/runtime.h>
#import "SaoqiangWCAssetsNames.h"

// UIKit observations and these page identities are confined to the main thread.
static BOOL SaoqiangWCAssetsPageCapturing;
static NSString *SaoqiangWCAssetsPageLastState;
static NSUInteger SaoqiangWCAssetsPageOffers;
NSString *SaoqiangWCAssetsPageDiagnostics(void) { return SaoqiangWCAssetsPageLastState ?: @"尚未采样页面"; }
static atomic_flag SaoqiangWCAssetsPageRequestQueued = ATOMIC_FLAG_INIT;
static NSMapTable<UIViewController *, NSString *> *SaoqiangWCAssetsPageKeys;
static NSTimer *SaoqiangWCAssetsPageTimer;
static CFAbsoluteTime SaoqiangWCAssetsPageNextAllowed;
static const NSUInteger SaoqiangWCAssetsPageViewBudget = 1600;
static const NSUInteger SaoqiangWCAssetsPageDepthLimit = 64;

static BOOL SaoqiangWCAssetsPageRectValid(CGRect rect) {
    return !CGRectIsNull(rect) && !CGRectIsInfinite(rect) &&
        isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height) &&
        rect.size.width > 0 && rect.size.height > 0;
}

static BOOL SaoqiangWCAssetsPageOwnController(UIViewController *controller) {
    const char *name = controller ? class_getName(object_getClass(controller)) : NULL;
    return name && !strncmp(name, "SaoqiangWCAssets", 16);
}

static BOOL SaoqiangWCAssetsPageNormalWindow(UIWindow *window) {
    if (!window || !window.isKeyWindow || window.hidden || !isfinite(window.alpha) ||
        window.alpha <= 0.01 || window.windowLevel != UIWindowLevelNormal ||
        !window.rootViewController || !SaoqiangWCAssetsPageRectValid(window.bounds) ||
        SaoqiangWCAssetsIsOwnView(window)) return NO;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = window.windowScene;
        if (scene && scene.activationState != UISceneActivationStateForegroundActive) return NO;
    }
    return YES;
}

static UIWindow *SaoqiangWCAssetsPageWindow(UIApplication *application) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in application.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class] ||
                scene.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (SaoqiangWCAssetsPageNormalWindow(window)) return window;
            }
        }
    }
    // Legacy applications and synthetic UIKit harnesses may have no scene.
    // Still require a key, visible, normal-level window; never choose a keyboard window.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *window in application.windows) {
        if (SaoqiangWCAssetsPageNormalWindow(window)) return window;
    }
#pragma clang diagnostic pop
    return nil;
}

static UIViewController *SaoqiangWCAssetsPageHost(UIWindow *window) {
    UIViewController *controller = window.rootViewController;
    for (NSUInteger depth = 0; controller && depth < SaoqiangWCAssetsPageDepthLimit; ++depth) {
        if (SaoqiangWCAssetsPageOwnController(controller) || controller.isBeingDismissed) return nil;
        UIViewController *next = controller.presentedViewController;
        // Do not change page keys while a presented page is still disappearing.
        if (next && next.isBeingDismissed) return nil;
        if (!next && [controller isKindOfClass:UINavigationController.class])
            next = ((UINavigationController *)controller).visibleViewController;
        if (!next && [controller isKindOfClass:UITabBarController.class])
            next = ((UITabBarController *)controller).selectedViewController;
        if (!next) return controller;
        if (next == controller) return nil;
        controller = next;
    }
    return nil;
}

static BOOL SaoqiangWCAssetsPageHostVisible(UIView *view, UIWindow *window) {
    if (!view || view.window != window) return NO;
    CGRect clip = window.bounds;
    CGFloat alpha = 1;
    NSUInteger depth = 0;
    for (UIView *ancestor = view; ancestor; ancestor = ancestor.superview) {
        if (++depth > SaoqiangWCAssetsPageDepthLimit || ancestor.hidden ||
            SaoqiangWCAssetsIsOwnView(ancestor)) return NO;
        CALayer *layer = ancestor.layer;
        alpha *= MIN(ancestor.alpha, (CGFloat)layer.opacity);
        if (layer.hidden || !isfinite(alpha) || alpha <= 0.01 ||
            !SaoqiangWCAssetsPageRectValid(ancestor.bounds)) return NO;
        CGRect rect = [ancestor convertRect:ancestor.bounds toView:window];
        if (!SaoqiangWCAssetsPageRectValid(rect)) return NO;
        if (ancestor == view || ancestor.clipsToBounds || layer.masksToBounds || ancestor == window)
            clip = CGRectIntersection(clip, rect);
        if (!SaoqiangWCAssetsPageRectValid(clip)) return NO;
        if (ancestor == window) return YES;
    }
    return NO;
}

// A controller can keep a previous stack entry attached during a transition.
// Inspect only the selected branch, without loading any controller's view.
static BOOL SaoqiangWCAssetsPageCurrentBranch(UIView *view) {
    UIResponder *responder = view.nextResponder;
    if (![responder isKindOfClass:UIViewController.class]) return YES;
    UIViewController *child = (UIViewController *)responder;
    for (NSUInteger depth = 0; child && depth < SaoqiangWCAssetsPageDepthLimit; ++depth) {
        if (SaoqiangWCAssetsPageOwnController(child) || child.isBeingDismissed) return NO;
        UIViewController *parent = child.parentViewController;
        if (!parent) return YES;
        if ([parent isKindOfClass:UINavigationController.class] &&
            ((UINavigationController *)parent).visibleViewController != child) return NO;
        if ([parent isKindOfClass:UITabBarController.class] &&
            ((UITabBarController *)parent).selectedViewController != child) return NO;
        child = parent;
    }
    return NO;
}

static NSString *SaoqiangWCAssetsPageKey(UIViewController *controller) {
    if (!SaoqiangWCAssetsPageKeys) {
        SaoqiangWCAssetsPageKeys = [NSMapTable mapTableWithKeyOptions:
            NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality
            valueOptions:NSPointerFunctionsStrongMemory];
    }
    NSString *key = [SaoqiangWCAssetsPageKeys objectForKey:controller];
    if (!key) {
        // UUID follows this visible page controller's lifetime, not its reusable address.
        key = [NSString stringWithFormat:@"%@:%@", NSStringFromClass(controller.class), NSUUID.UUID.UUIDString];
        [SaoqiangWCAssetsPageKeys setObject:key forKey:controller];
    }
    return key;
}

static BOOL SaoqiangWCAssetsPageOffer(UIImage *image, UIView *view, SaoqiangWCAssetsStore *store) {
    if (![image isKindOfClass:UIImage.class] || SaoqiangWCAssetsIsOwnImage(image)) return NO;
    SaoqiangWCAssetsImageInfo *info = SaoqiangWCAssetsImageInfoForImage(image);
    if (!info) {
        BOOL buttonIcon = NO, excluded = NO;
        NSUInteger ancestry = 0;
        static const char *const badAncestors[] = {
            "headimage","avatar","portrait","sticker","emoticon","messagecell",
            "photocell","videocell","webimage",NULL
        };
        for (UIView *a = view; a && ancestry++ < 12; a = a.superview) {
            if ([a isKindOfClass:UIButton.class]) buttonIcon = YES;
            if (SQNameClassExcluded(class_getName(object_getClass(a)), badAncestors)) excluded = YES;
        }
        CGFloat width = image.size.width, height = image.size.height;
        BOOL small = width > 0 && height > 0 && width <= 72 && height <= 72 && width*image.scale <= 288 && height*image.scale <= 288;
        if (!buttonIcon || excluded || !small || view.bounds.size.width > 120 || view.bounds.size.height > 120) return NO;
        SaoqiangWCAssetsAssociateVisibleIcon(image,@"可见按钮图标 · 未取得原始名称");
        info = SaoqiangWCAssetsImageInfoForImage(image);
        if (!info) return NO;
    }
    CGSize size = image.size;
    // Preserve the actual stretched bubble dimensions; Store renders the original image.
    // Ordinary named icons retain their image size, even inside a larger touch target.
    if (info.SaoqiangWCAssetsVerifiedBubble)
        size = view.bounds.size;
    if (!isfinite(size.width) || !isfinite(size.height) || size.width <= 0 || size.height <= 0) return NO;
    ++SaoqiangWCAssetsPageOffers;
    [store SaoqiangWCAssetsEnqueueVisibleImage:image displaySize:size];
    return YES;
}

static void SaoqiangWCAssetsPageWalk(UIView *view, UIWindow *window, UIView *hostView,
                                    CGRect clip, CGFloat inheritedAlpha, NSUInteger depth,
                                    NSUInteger *remaining, BOOL inHost, BOOL inChrome,
                                    BOOL outsideController, SaoqiangWCAssetsStore *store) {
    if (!view || !*remaining || depth > SaoqiangWCAssetsPageDepthLimit) return;
    --*remaining;
    // A UIWindow need not report itself from UIView.window; validate children
    // against their host window, but always enter the already-verified root.
    if ((view != window && view.window != window) || view.hidden || SaoqiangWCAssetsIsOwnView(view) ||
        (view != window && !SaoqiangWCAssetsPageCurrentBranch(view))) return;
    CGRect bounds = view.bounds;
    if (!SaoqiangWCAssetsPageRectValid(bounds)) return;
    CALayer *layer = view.layer;
    CGFloat alpha = inheritedAlpha * MIN(view.alpha, (CGFloat)layer.opacity);
    if (layer.hidden || !isfinite(alpha) || alpha <= 0.01) return;
    CGRect rect = [view convertRect:bounds toView:window];
    if (!SaoqiangWCAssetsPageRectValid(rect)) return;
    CGRect visible = CGRectIntersection(clip, rect);
    BOOL intersects = SaoqiangWCAssetsPageRectValid(visible);
    BOOL clips = view == window || view.clipsToBounds || layer.masksToBounds;
    if (!intersects && clips) return;

    inHost = inHost || view == hostView;
    inChrome = inChrome || [view isKindOfClass:UINavigationBar.class] ||
        [view isKindOfClass:UITabBar.class] || [view isKindOfClass:UIToolbar.class] ||
        [view isKindOfClass:UIInputView.class];
    UIResponder *responder = view.nextResponder;
    if ([responder isKindOfClass:UIViewController.class] &&
        ((UIViewController *)responder).viewIfLoaded == view) {
        outsideController = NO;
        // Keep ancestor containers only to reach the host and their visible bars.
        // This also excludes attached presenting pages behind a modal host.
        if (!inHost && !inChrome && ![hostView isDescendantOfView:view]) return;
    }
    // Unowned window siblings include already-attached input accessories. We do
    // not ask any responder to construct inputAccessoryView or load a view.
    if (intersects && (inHost || inChrome || outsideController)) {
        // Only this existing validator may promote CommonMessageCellView's background.
        // It runs first so descendants can use newly verified bubble metadata.
        SaoqiangWCAssetsInspectBubbleCell(view);
        BOOL offered = NO;
        if ([view isKindOfClass:UIImageView.class]) {
            UIImageView *imageView = (UIImageView *)view;
            UIImage *image = imageView.highlighted ? imageView.highlightedImage : nil;
            if (!image) image = imageView.image;
            offered = SaoqiangWCAssetsPageOffer(image, view, store);
        } else if ([view isKindOfClass:UIButton.class]) {
            UIButton *button = (UIButton *)view;
            UIImage *image = button.currentImage;
            UIImage *background = button.currentBackgroundImage;
            offered = SaoqiangWCAssetsPageOffer(image, view, store);
            if (background != image)
                offered = SaoqiangWCAssetsPageOffer(background, view, store) || offered;
        }
        if (!offered && layer.contents) {
            // Exact, already-known CGImage association only. No image reconstruction,
            // pixel matching, arbitrary sublayer search, or view/screen rendering.
            SaoqiangWCAssetsPageOffer(SaoqiangWCAssetsImageForLayer(layer), view, store);
        }
    }
    if (depth >= SaoqiangWCAssetsPageDepthLimit) return;
    CGRect childClip = clips ? visible : clip;
    // Read the attached subtree only: no controller stacks, reusable-cell caches,
    // animation image arrays, non-current button states, or userInteractionEnabled gate.
    for (UIView *child in view.subviews) {
        if (!*remaining) break;
        SaoqiangWCAssetsPageWalk(child, window, hostView, childClip, alpha, depth + 1,
                                remaining, inHost, inChrome, outsideController, store);
    }
}

void SaoqiangWCAssetsCaptureVisiblePage(void) {
    if (!NSThread.isMainThread) {
        // Many background requests share at most one pending main-queue observation.
        if (!atomic_flag_test_and_set_explicit(&SaoqiangWCAssetsPageRequestQueued, memory_order_relaxed)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                atomic_flag_clear_explicit(&SaoqiangWCAssetsPageRequestQueued, memory_order_relaxed);
                SaoqiangWCAssetsCaptureVisiblePage();
            });
        }
        return;
    }
    if (!SaoqiangWCAssetsMasterEnabled() || !SaoqiangWCAssetsIconCaptureActive()) return;
    if (SaoqiangWCAssetsPageCapturing) return;
    SaoqiangWCAssetsPageCapturing = YES;
    @try {
        @autoreleasepool {
            UIApplication *application = UIApplication.sharedApplication;
            SaoqiangWCAssetsPageLastState=[NSString stringWithFormat:@"app=%ld ui=%d picker=%d suppressed=%d",(long)application.applicationState,SaoqiangWCAssetsOwnUIActive(),SaoqiangWCAssetsInspectorEnabled(),SaoqiangWCAssetsIsSuppressed()];
            if (application.applicationState != UIApplicationStateActive ||
                SaoqiangWCAssetsOwnUIActive() || SaoqiangWCAssetsInspectorEnabled() ||
                SaoqiangWCAssetsIsSuppressed()) return;
            SaoqiangWCAssetsStore *store = [SaoqiangWCAssetsStore SaoqiangWCAssetsShared];
            // A stopped capture leaves both its page key and frozen rows untouched.
            if (![store SaoqiangWCAssetsEnabled]) return;
            UIWindow *window = SaoqiangWCAssetsPageWindow(application);
            if (!window) { SaoqiangWCAssetsPageLastState=[SaoqiangWCAssetsPageLastState stringByAppendingString:@" · 无活动主窗口"]; return; }
            UIViewController *host = SaoqiangWCAssetsPageHost(window);
            UIView *hostView = host.viewIfLoaded;
            if (!SaoqiangWCAssetsPageHostVisible(hostView, window)) { SaoqiangWCAssetsPageLastState=[SaoqiangWCAssetsPageLastState stringByAppendingFormat:@" · 页面不可见 host=%@ window=%d size=%@",NSStringFromClass(host.class),hostView.window==window,NSStringFromCGRect(hostView.bounds)]; return; }
            SaoqiangWCAssetsPageOffers=0;
            [store SaoqiangWCAssetsSetPageKey:SaoqiangWCAssetsPageKey(host)];
            NSUInteger remaining = SaoqiangWCAssetsPageViewBudget;
            SaoqiangWCAssetsBubbleSetExplicitCapture(YES);
            @try {
                SaoqiangWCAssetsPageWalk(window, window, hostView, window.bounds, 1, 0,
                                        &remaining, NO, NO, YES, store);
            } @finally { SaoqiangWCAssetsBubbleSetExplicitCapture(NO); }
            SaoqiangWCAssetsPageLastState=[NSString stringWithFormat:@"已检查 %lu 视图 · 可信素材 %lu",(unsigned long)(SaoqiangWCAssetsPageViewBudget-remaining),(unsigned long)SaoqiangWCAssetsPageOffers];
        }
    } @finally {
        SaoqiangWCAssetsPageCapturing = NO;
    }
}

void SaoqiangWCAssetsInstallPageCapture(void) {
    void (^install)(void) = ^{
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            // Default run loop mode only. UITrackingRunLoopMode is in the common
            // modes set, so a common-mode timer walks the whole window hierarchy
            // while the user is scrolling — exactly when that cost is visible.
            // Leaving tracking mode fires one pass immediately afterwards, which
            // sees the same views the user scrolled to.
            SaoqiangWCAssetsPageTimer = [NSTimer timerWithTimeInterval:0.8 repeats:YES block:^(NSTimer *timer) {
                (void)timer;
                // With the master off the timer stays installed but does no work
                // beyond a relaxed load; no clock read and no window walk.
                if (!SaoqiangWCAssetsMasterEnabled() || !SaoqiangWCAssetsIconCaptureActive()) return;
                CFAbsoluteTime started = CFAbsoluteTimeGetCurrent();
                if (started < SaoqiangWCAssetsPageNextAllowed) return;
                SaoqiangWCAssetsCaptureVisiblePage();
                // A pass that costs real main-thread time means a large or busy
                // hierarchy; back off instead of repeating it in the same second.
                CFAbsoluteTime cost = CFAbsoluteTimeGetCurrent() - started;
                SaoqiangWCAssetsPageNextAllowed = CFAbsoluteTimeGetCurrent() +
                    (cost > 0.012 ? 2.4 : (cost > 0.005 ? 1.6 : 0.8));
            }];
            SaoqiangWCAssetsPageTimer.tolerance = 0.4;
            [NSRunLoop.mainRunLoop addTimer:SaoqiangWCAssetsPageTimer forMode:NSDefaultRunLoopMode];
        });
    };
    if (NSThread.isMainThread) install();
    else dispatch_async(dispatch_get_main_queue(), install);
}
