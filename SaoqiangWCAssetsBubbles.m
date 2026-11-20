#import "SaoqiangWCAssets.h"
#import "SaoqiangWCAssetsInspector.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import <string.h>
#import <QuartzCore/QuartzCore.h>
#import "SaoqiangWCAssetsNames.h"

static NSMutableArray *SaoqiangWCAssetsBubbleLog;
static NSMutableSet *SaoqiangWCAssetsBubbleInstalled;
static _Thread_local unsigned SaoqiangWCAssetsBubbleDepth;
static BOOL SaoqiangWCAssetsBubbleObject(const char *type) { return type && (!strcmp(type,"@") || !strncmp(type,"@\"",2)); }
static BOOL SaoqiangWCAssetsBubbleABI(Method method, const char *result, NSUInteger arguments, const char *argument) {
    if (!method) return NO;
    NSMethodSignature *s=[NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    if (s.numberOfArguments!=arguments || strcmp([s getArgumentTypeAtIndex:0],"@") || strcmp([s getArgumentTypeAtIndex:1],":")) return NO;
    if (strcmp(result,"@")==0 ? !SaoqiangWCAssetsBubbleObject(s.methodReturnType) : strcmp(s.methodReturnType,result)!=0) return NO;
    if (arguments>2 && (strcmp(argument,"@")==0 ? !SaoqiangWCAssetsBubbleObject([s getArgumentTypeAtIndex:2]) : strcmp([s getArgumentTypeAtIndex:2],argument)!=0)) return NO;
    return YES;
}
static BOOL SaoqiangWCAssetsBubbleHostClass(Class cls) {
    const char *image = cls ? class_getImageName(cls) : NULL;
    return image && [@(image) hasPrefix:[NSBundle.mainBundle.bundlePath stringByAppendingString:@"/"]];
}
static BOOL SaoqiangWCAssetsBubbleOrigin(Method method) {
    if (!method) return NO;
    Dl_info info={0}; dladdr((const void *)method_getImplementation(method),&info);
    return info.dli_fname && [@(info.dli_fname) hasPrefix:[NSBundle.mainBundle.bundlePath stringByAppendingString:@"/"]];
}
static void SaoqiangWCAssetsBubbleReplace(Class cls, SEL selector, IMP newIMP) {
    Method method=class_getInstanceMethod(cls,selector);
    if (!class_addMethod(cls,selector,newIMP,method_getTypeEncoding(method))) method_setImplementation(class_getInstanceMethod(cls,selector),newIMP);
}
static char SaoqiangWCAssetsBubbleLayerImageKey;
static NSUInteger SaoqiangWCAssetsBubbleCellsSeen, SaoqiangWCAssetsBubbleImageCount, SaoqiangWCAssetsBubbleLayerCount, SaoqiangWCAssetsBubbleMissing;
@interface SaoqiangWCAssetsBubbleLayerImage : NSObject
@property(nonatomic,strong) id contents;
@property(nonatomic,strong) UIImage *image;
@end
@implementation SaoqiangWCAssetsBubbleLayerImage
@end
static BOOL SaoqiangWCAssetsBubbleVisible(UIView *view) {
    UIWindow *window=view.window;
    if (!window || ![view isDescendantOfView:window] || SaoqiangWCAssetsIsOwnView(view)) return NO;
    CGRect visible=[view convertRect:view.bounds toView:window];
    for (UIView *a=view;a;a=a.superview) {
        if (a.hidden || a.alpha<0.01 || a.layer.hidden || a.layer.opacity<0.01) return NO;
        if (a.clipsToBounds || a.layer.masksToBounds || a==window) visible=CGRectIntersection(visible,[a convertRect:a.bounds toView:window]);
        if (CGRectIsNull(visible) || CGRectIsEmpty(visible)) return NO;
    }
    return CGRectIntersectsRect(visible,window.bounds);
}
static UIImage *SaoqiangWCAssetsBubbleLayerContents(CALayer *layer) {
    id contents=layer.contents;
    if (!contents || CFGetTypeID((__bridge CFTypeRef)contents)!=CGImageGetTypeID()) return nil;
    SaoqiangWCAssetsBubbleLayerImage *cache=objc_getAssociatedObject(layer,&SaoqiangWCAssetsBubbleLayerImageKey);
    UIImage *known=SaoqiangWCAssetsImageForLayer(layer);
    if (cache.contents==contents) {
        if (known && known!=cache.image) {
            SaoqiangWCAssetsImageInfo *info=SaoqiangWCAssetsImageInfoForImage(known);
            NSString *candidate=SaoqiangWCAssetsBubbleCandidateName(known);
            if (candidate.length) SaoqiangWCAssetsAssociateBubbleCandidate(cache.image,candidate);
            if (info && ![info.SaoqiangWCAssetsName isEqual:@"无原始资源名"]) SaoqiangWCAssetsAssociateSourceImage(cache.image,info.SaoqiangWCAssetsName,info.SaoqiangWCAssetsRawSourceData,info.SaoqiangWCAssetsSource,YES);
            SaoqiangWCAssetsPropagateImageInfo(known,cache.image,@"同一气泡图层来源恢复");
        }
        return cache.image;
    }
    UIImage *image=known ?: [UIImage imageWithCGImage:(__bridge CGImageRef)contents scale:MAX(layer.contentsScale,1) orientation:UIImageOrientationUp];
    cache=[SaoqiangWCAssetsBubbleLayerImage new]; cache.contents=contents; cache.image=image;
    objc_setAssociatedObject(layer,&SaoqiangWCAssetsBubbleLayerImageKey,cache,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return image;
}
static void SaoqiangWCAssetsBubbleOffer(UIImage *image, CGSize size, NSString *source, BOOL layerImage) {
    if (!image || SaoqiangWCAssetsIsOwnImage(image)) return;
    // A name conflict is not a reason to discard a confirmed message background.
    SaoqiangWCAssetsAssociateBubbleImage(image,SaoqiangWCAssetsBubbleCandidateName(image),source);
    if (layerImage) ++SaoqiangWCAssetsBubbleLayerCount; else ++SaoqiangWCAssetsBubbleImageCount;
    [[SaoqiangWCAssetsStore SaoqiangWCAssetsShared] SaoqiangWCAssetsEnqueueVisibleImage:image displaySize:size];
}
static BOOL SaoqiangWCAssetsBubbleLayers(CALayer *layer, UIView *host, CGRect clip, NSString *source, NSUInteger depth, NSUInteger *budget) {
    if (!layer || !*budget || depth>5 || layer.hidden || layer.opacity<0.01) return NO;
    --*budget;
    // Text layers and layers belonging to foreign views are not bubble assets.
    if ([layer isKindOfClass:CATextLayer.class]) return NO;
    id owner=layer.delegate;
    if ([owner isKindOfClass:UIView.class] && owner!=host) return NO;
    CGRect bounds=[layer convertRect:layer.bounds toLayer:host.layer];
    CGRect visible=CGRectIntersection(clip,bounds);
    if (CGRectIsNull(visible)||CGRectIsEmpty(visible)) return NO;
    BOOL found=NO;
    UIImage *image=SaoqiangWCAssetsBubbleLayerContents(layer);
    if (image) { SaoqiangWCAssetsBubbleOffer(image,host.bounds.size,[source stringByAppendingString:@" · 背景图层图片"],YES); found=YES; }
    CGRect childClip=layer.masksToBounds?visible:clip;
    for (CALayer *child in layer.sublayers) found=SaoqiangWCAssetsBubbleLayers(child,host,childClip,source,depth+1,budget)||found;
    return found;
}
static BOOL SaoqiangWCAssetsBubbleViews(UIView *view, NSString *source, NSUInteger depth, NSUInteger *budget) {
    if (!view || !*budget || depth>4 || !SaoqiangWCAssetsBubbleVisible(view)) return NO;
    --*budget;
    if ([view isKindOfClass:UILabel.class] || [view isKindOfClass:UITextView.class] || [view isKindOfClass:UITextField.class] || [view isKindOfClass:UIControl.class]) return NO;
    static const char *const excludedClasses[] = {"headimage","avatar","portrait","emoticon","sticker",NULL};
    if (SQNameClassExcluded(class_getName(object_getClass(view)), excludedClasses)) return NO;
    BOOL found=NO;
    if ([view isKindOfClass:UIImageView.class]) {
        UIImageView *v=(UIImageView *)view; UIImage *image=v.highlighted&&v.highlightedImage?v.highlightedImage:v.image;
        if (image) { SaoqiangWCAssetsBubbleOffer(image,v.bounds.size,source,NO); found=YES; }
    }
    // Only descend within the exact background returned by a verified getter.
    // No whole-cell screenshot and no arbitrary imageView capture.
    if (!found) { NSUInteger layerBudget=24; found=SaoqiangWCAssetsBubbleLayers(view.layer,view,view.bounds,source,0,&layerBudget); }
    for (UIView *child in view.subviews) found=SaoqiangWCAssetsBubbleViews(child,source,depth+1,budget)||found;
    return found;
}
// -layoutSubviews runs for every visible cell on every layout pass. Re-walking
// an unchanged bubble only re-offers bytes the store already holds, so the last
// result is remembered per view and the traversal is skipped while it stands.
static BOOL SaoqiangWCAssetsBubbleExplicit;
void SaoqiangWCAssetsBubbleSetExplicitCapture(BOOL explicitCapture) { SaoqiangWCAssetsBubbleExplicit = explicitCapture; }
static char SaoqiangWCAssetsBubbleVisitKey;
@interface SaoqiangWCAssetsBubbleVisit : NSObject
@property(nonatomic,assign) const void *contents;
@property(nonatomic) CFAbsoluteTime time;
@property(nonatomic) BOOL found;
@end
@implementation SaoqiangWCAssetsBubbleVisit
@end
static void SaoqiangWCAssetsObserveBubbleView(id value, NSString *source) {
    if (!SaoqiangWCAssetsMasterEnabled() || !SaoqiangWCAssetsIconCaptureActive()) return;
    if (!NSThread.isMainThread || SaoqiangWCAssetsIsSuppressed() || SaoqiangWCAssetsOwnUIActive() || ![value isKindOfClass:UIView.class]) return;
    CALayer *layer = ((UIView *)value).layer;
    const void *contents = (__bridge const void *)layer.contents;
    SaoqiangWCAssetsBubbleVisit *visit = objc_getAssociatedObject(value, &SaoqiangWCAssetsBubbleVisitKey);
    CFAbsoluteTime now = 0;
    // Layout passes are throttled, explicit page passes never are: a late
    // original name lives on the image metadata, so identical layer contents can
    // still need a re-read. A layer whose contents produced an image is skipped
    // while the pointer holds; layers without detectable contents are retried on
    // a timer instead.
    if (!SaoqiangWCAssetsBubbleExplicit && visit && visit.contents == contents) {
        // Steady state during a scroll: one pointer compare, no clock read.
        if (contents && visit.found) return;
        now = CFAbsoluteTimeGetCurrent();
        if (!contents && now - visit.time < 1.5) return;
    }
    if (!now) now = CFAbsoluteTimeGetCurrent();
    NSUInteger budget=32; BOOL found=SaoqiangWCAssetsBubbleViews(value,source,0,&budget); if (!found) ++SaoqiangWCAssetsBubbleMissing;
    if (!visit) { visit=[SaoqiangWCAssetsBubbleVisit new];
        objc_setAssociatedObject(value,&SaoqiangWCAssetsBubbleVisitKey,visit,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    visit.contents=contents; visit.time=now; visit.found=found;
}
// Resolving getBgImageView used to build an NSMethodSignature on every layout
// pass, for every visible cell -- the single heaviest thing in this hook. The
// answer only depends on the instance class, so it is cached per class (a
// subclass may override the getter, and each one resolves once).
static IMP SaoqiangWCAssetsBubbleBackgroundIMP(Class cls, SEL getter) {
    static Class cachedClass; static IMP cachedIMP;
    if (!cls) return NULL;
    if (cls == cachedClass) return cachedIMP;
    Method method = class_getInstanceMethod(cls, getter);
    IMP implementation = SaoqiangWCAssetsBubbleABI(method, "@", 2, NULL) ? method_getImplementation(method) : NULL;
    cachedClass = cls; cachedIMP = implementation;
    return implementation;
}
static Class SaoqiangWCAssetsBubbleCellClass(void) {
    static Class cached; static dispatch_once_t once;
    dispatch_once(&once, ^{ cached = NSClassFromString(@"CommonMessageCellView"); });
    return cached;
}
void SaoqiangWCAssetsInspectBubbleCell(UIView *view) {
    if (!SaoqiangWCAssetsMasterEnabled() || !SaoqiangWCAssetsIconCaptureActive()) return;
    if (!NSThread.isMainThread || SaoqiangWCAssetsOwnUIActive() || SaoqiangWCAssetsBubbleDepth) return;
    Class cell=SaoqiangWCAssetsBubbleCellClass();
    if (!cell || ![view isKindOfClass:cell] || !view.window || !SaoqiangWCAssetsBubbleVisible(view)) return;
    ++SaoqiangWCAssetsBubbleCellsSeen; ++SaoqiangWCAssetsBubbleDepth;
    @try {
        // Both zero-argument object getters are present in the supplied WeChat
        // metadata. Runtime instance-class lookup preserves subclass overrides.
        NSMutableSet<NSValue *> *visited=[NSMutableSet new];
        for (NSString *name in @[@"getBgImageView",@"plainBgView"]) {
            SEL selector=NSSelectorFromString(name); Method method=class_getInstanceMethod([view class],selector);
            if (!SaoqiangWCAssetsBubbleABI(method,"@",2,NULL)) continue;
            id background=((id(*)(id,SEL))method_getImplementation(method))(view,selector);
            if (![background isKindOfClass:UIView.class] || background==view || ![(UIView *)background isDescendantOfView:view]) continue;
            NSValue *key=[NSValue valueWithNonretainedObject:background]; if ([visited containsObject:key]) continue; [visited addObject:key];
            SaoqiangWCAssetsObserveBubbleView(background,[@"可见消息气泡背景 · " stringByAppendingString:name]);
        }
    } @catch(NSException *exception) { ++SaoqiangWCAssetsBubbleMissing; }
    @finally { --SaoqiangWCAssetsBubbleDepth; }
}
void SaoqiangWCAssetsDiscoverBubbles(void) {
    NSCAssert(NSThread.isMainThread,@"Bubble discovery on main thread");
    if (!SaoqiangWCAssetsBubbleInstalled) SaoqiangWCAssetsBubbleInstalled=[NSMutableSet new];
    SaoqiangWCAssetsBubbleLog=[NSMutableArray new];
    Class cell=NSClassFromString(@"CommonMessageCellView"); SEL getter=NSSelectorFromString(@"getBgImageView");
    Method gm=cell ? class_getInstanceMethod(cell,getter) : NULL;
    BOOL getterValid=SaoqiangWCAssetsBubbleHostClass(cell) && SaoqiangWCAssetsBubbleABI(gm,"@",2,NULL) && ([SaoqiangWCAssetsBubbleInstalled containsObject:@"-[CommonMessageCellView getBgImageView]"] || SaoqiangWCAssetsBubbleOrigin(gm));
    for (NSString *selectorName in @[@"getBgImageView",@"layoutSubviews",@"initBgImageView",@"updateBgImageView:"]) {
        SEL selector=NSSelectorFromString(selectorName); Method m=cell ? class_getInstanceMethod(cell,selector) : NULL;
        NSString *key=[NSString stringWithFormat:@"-[CommonMessageCellView %@]",selectorName];
        BOOL installed=[SaoqiangWCAssetsBubbleInstalled containsObject:key];
        BOOL get=[selectorName isEqual:@"getBgImageView"], boolean=[selectorName hasSuffix:@":"];
        BOOL valid=getterValid && SaoqiangWCAssetsBubbleABI(m,get?"@":"v",boolean?3:2,boolean?@encode(BOOL):NULL) && (installed||SaoqiangWCAssetsBubbleOrigin(m));
        if (valid&&!installed) {
            IMP original=method_getImplementation(m); id block;
            void (^observe)(id)=^(id receiver) {
                if (SaoqiangWCAssetsBubbleDepth || !NSThread.isMainThread) return;
                IMP background = SaoqiangWCAssetsBubbleBackgroundIMP([receiver class], getter);
                if (!background) return;
                ++SaoqiangWCAssetsBubbleDepth;
                @try { SaoqiangWCAssetsObserveBubbleView(((id (*)(id,SEL))background)(receiver,getter),key); }
                @finally { --SaoqiangWCAssetsBubbleDepth; }
            };
            if (get) block=^id(id receiver) { id view=((id (*)(id,SEL))original)(receiver,selector); if (!SaoqiangWCAssetsBubbleDepth) SaoqiangWCAssetsObserveBubbleView(view,key); return view; };
            else if (boolean) block=^(id receiver,BOOL value) { ((void (*)(id,SEL,BOOL))original)(receiver,selector,value); observe(receiver); };
            else block=^(id receiver) { ((void (*)(id,SEL))original)(receiver,selector); observe(receiver); };
            SaoqiangWCAssetsBubbleReplace(cell,selector,imp_implementationWithBlock(block)); [SaoqiangWCAssetsBubbleInstalled addObject:key];
        }
        [SaoqiangWCAssetsBubbleLog addObject:@{@"owner":key,@"encoding":m?@(method_getTypeEncoding(m)):@"missing",@"status":valid?@"installed":@"unavailable/ABI/origin mismatch"}];
    }
    // BubbleBox asset names are only metadata. Promotion into the material list
    // requires the same UIImage to be observed as a real message background.
    Class assets=NSClassFromString(@"BubbleBoxAssets"); SEL sel=NSSelectorFromString(@"getImageWithName:"); Method m=assets?class_getInstanceMethod(assets,sel):NULL;
    NSString *key=@"-[BubbleBoxAssets getImageWithName:]";
    BOOL installed=[SaoqiangWCAssetsBubbleInstalled containsObject:key]; BOOL valid=SaoqiangWCAssetsBubbleABI(m,"@",3,"@")&&(installed||SaoqiangWCAssetsBubbleOrigin(m));
    if (valid&&!installed) {
        IMP original=method_getImplementation(m);
        id block=^id(id receiver,id name) {
            id image=((id (*)(id,SEL,id))original)(receiver,sel,name);
            if (SaoqiangWCAssetsMasterEnabled() && SaoqiangWCAssetsIconCaptureActive() && !SaoqiangWCAssetsOwnUIActive()) SaoqiangWCAssetsAssociateBubbleCandidate(image, name);
            return image;
        };
        SaoqiangWCAssetsBubbleReplace(assets,sel,imp_implementationWithBlock(block)); [SaoqiangWCAssetsBubbleInstalled addObject:key];
    }
    [SaoqiangWCAssetsBubbleLog addObject:@{@"owner":key,@"status":valid?@"metadata only; requires message background evidence":@"unavailable/ABI/origin mismatch"}];
}
NSString *SaoqiangWCAssetsBubbleDiagnostics(void) {
    NSDictionary *report=@{@"hooks":SaoqiangWCAssetsBubbleLog?:@[],
        @"visibleCellChecks":@(SaoqiangWCAssetsBubbleCellsSeen),@"backgroundImageOffers":@(SaoqiangWCAssetsBubbleImageCount),
        @"backgroundLayerOffers":@(SaoqiangWCAssetsBubbleLayerCount),@"backgroundWithoutImage":@(SaoqiangWCAssetsBubbleMissing)};
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding]?:@"{}";
}
