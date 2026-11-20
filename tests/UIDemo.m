#import <UIKit/UIKit.h>
#import "SaoqiangWCAssets.h"
#import "SaoqiangWCAssetsInspector.h"
#import "SaoqiangWCAssetsTheme.h"
#import "NamingChecks.h"
#import "FeatureChecks.h"
#import "Engine308Checks.h"
// Synthetic host: only our test declares this class. No user app binary is uploaded.
@interface CommonMessageCellView : UIView
@property(nonatomic,strong) UIImageView *backgroundImage;
@property(nonatomic,strong) UIView *plainBackground;
- (UIImageView *)getBgImageView;
- (UIView *)plainBgView;
@end
@implementation CommonMessageCellView
- (UIImageView *)getBgImageView { return self.backgroundImage; }
- (UIView *)plainBgView { return self.plainBackground; }
@end
static UIImage *DemoImage(NSUInteger index) {
    UIGraphicsImageRenderer *r=[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(24,24)];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *c) {
        [UIColor.labelColor setStroke]; UIBezierPath *p=[UIBezierPath bezierPathWithRoundedRect:CGRectMake(2,2,20,20) cornerRadius:index%3+2]; p.lineWidth=1.5; [p stroke];
        [[UIImage systemImageNamed:@[@"waveform",@"mic",@"photo",@"camera",@"folder",@"star"][index%6]] drawInRect:CGRectMake(6,6,12,12)];
    }];
}
static UIImage *DemoBubble(UIColor *color,CGSize size) {
    UIGraphicsImageRenderer *r=[[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *context) { [color setFill]; [[UIBezierPath bezierPathWithRoundedRect:CGRectInset((CGRect){CGPointZero,size},1,1) cornerRadius:6] fill]; }];
}
static UILabel *DemoFindLabel(UIView *view, NSString *text) {
    if ([view isKindOfClass:UILabel.class] && [((UILabel *)view).text isEqualToString:text]) return (UILabel *)view;
    for (UIView *child in view.subviews) { UILabel *found=DemoFindLabel(child,text); if (found) return found; }
    return nil;
}
// Test-only entry point into the gesture card (see SaoqiangWCAssetsUI.m).
extern void SaoqiangWCAssetsPresentPanelForTesting(UIViewController *, NSInteger, BOOL);
static void DemoFailure(NSString *reason) {
    NSLog(@"CAPTURE_TEST_FAILED %@",reason);
    NSURL *d=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    [reason writeToURL:[d URLByAppendingPathComponent:@"capture-failed.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    abort();
}
@interface SaoqiangWCAssetsDemoDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) UIViewController *host;
@property(nonatomic,strong) UIViewController *second;
@property(nonatomic,strong) NSSet *pageAKeys;
@property(nonatomic,copy) NSString *savedSession;
@property(nonatomic,strong) UIImage *firstBubble;
@property(nonatomic,strong) UIImage *layerSource;
@property(nonatomic,strong) UIImage *containerSource;
@end
@implementation SaoqiangWCAssetsDemoDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds]; self.host=[UIViewController new]; self.host.view.backgroundColor=UIColor.systemGray5Color;
    self.window.rootViewController=self.host; [self.window makeKeyAndVisible];
    UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(18,55,350,44)]; label.text=@"合成界面验证 · 非微信真机"; [self.host.view addSubview:label];
    NSArray *names=@[@"voice_circle_regular.svg",@"mike_on_heavy.svg",@"icons_filled_album.svg",@"icons_filled_camera.svg",@"icons_filled_folder.svg",@"icons_filled_favorites.svg"];
    for (NSUInteger i=0;i<names.count;i++) {
        UIImage *image=DemoImage(i); NSData *raw=[[NSString stringWithFormat:@"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\"><circle cx=\"12\" cy=\"12\" r=\"%lu\"/></svg>",(unsigned long)(i+4)] dataUsingEncoding:NSUTF8StringEncoding];
        id result=SaoqiangWCAssetsCallNamedSource(names[i],@"合成命名加载链",NO,^id { SaoqiangWCAssetsObserveSourceData(names[i],raw); return image; });
        if (result!=image || ![SaoqiangWCAssetsImageInfoForImage(image).SaoqiangWCAssetsRawSourceData isEqual:raw]) DemoFailure(@"source bytes lost");
        UIImageView *v=[[UIImageView alloc] initWithImage:image]; v.frame=CGRectMake(24+i*48,125,30,30); [self.host.view addSubview:v];
    }
    // Unnamed chat photo on screen and a named off-screen preload must not enter.
    UIImageView *photo=[[UIImageView alloc] initWithImage:DemoImage(9)]; photo.frame=CGRectMake(230,210,100,100); [self.host.view addSubview:photo];
    UIImage *off=DemoImage(10); SaoqiangWCAssetsAssociateNamedImage(off,@"icons_filled_offscreen",@"offscreen fixture",nil,NO);
    UIImageView *offview=[[UIImageView alloc] initWithImage:off]; offview.frame=CGRectMake(0,3000,40,40); [self.host.view addSubview:offview];
    UIImage *hidden=DemoImage(11); SaoqiangWCAssetsAssociateNamedImage(hidden,@"icons_filled_hidden",@"hidden fixture",nil,NO);
    UIImageView *hiddenview=[[UIImageView alloc] initWithImage:hidden]; hiddenview.frame=CGRectMake(0,200,40,40); hiddenview.hidden=YES; [self.host.view addSubview:hiddenview];
    CommonMessageCellView *cell=[[CommonMessageCellView alloc] initWithFrame:CGRectMake(20,205,170,54)];
    UIGraphicsImageRenderer *bubbleRenderer=[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(40,24)];
    UIImage *bubble=[bubbleRenderer imageWithActions:^(UIGraphicsImageRendererContext *c) { [UIColor.whiteColor setFill]; [UIColor.darkGrayColor setStroke]; UIBezierPath *p=[UIBezierPath bezierPathWithRoundedRect:CGRectMake(1,1,38,22) cornerRadius:6]; [p fill]; [p stroke]; }];
    cell.backgroundImage=[[UIImageView alloc] initWithImage:[bubble resizableImageWithCapInsets:UIEdgeInsetsMake(8,10,8,10)]]; cell.backgroundImage.frame=cell.bounds; self.firstBubble=cell.backgroundImage.image; [cell addSubview:cell.backgroundImage]; [self.host.view addSubview:cell];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{ [self beginWhenReady:0]; }); return YES;
}
- (void)beginWhenReady:(NSUInteger)attempt {
    if (UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) {
        if (attempt>=25) DemoFailure(@"test host never became active");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[self beginWhenReady:attempt+1];}); return;
    }
    [self.window layoutIfNeeded];
    // The master switch is a runtime gate, not a reinstall: toggling it must not
    // disturb the already installed hooks or leak state into the next check.
    if (!SaoqiangWCAssetsMasterEnabled()) DemoFailure(@"test harness master should default on");
    SaoqiangWCAssetsSetMasterEnabled(NO);
    if (SaoqiangWCAssetsMasterEnabled()) DemoFailure(@"master switch did not turn off");
    SaoqiangWCAssetsSetMasterEnabled(YES);
    if (!SaoqiangWCAssetsMasterEnabled()) DemoFailure(@"master switch did not turn on");
    SaoqiangWCAssetsSetIconCaptureEnabled(NO);
    if (SaoqiangWCAssetsIconCaptureEnabled()) DemoFailure(@"icon feature did not turn off");
    SaoqiangWCAssetsSetIconCaptureEnabled(YES);
    if (!SaoqiangWCAssetsIconCaptureEnabled()) DemoFailure(@"icon feature did not turn on");
    SaoqiangWCAssetsSetThemeCaptureEnabled(NO);
    if (SaoqiangWCAssetsThemeCaptureEnabled()) DemoFailure(@"theme feature did not turn off");
    SaoqiangWCAssetsSetThemeCaptureEnabled(YES);
    if (!SaoqiangWCAssetsThemeCaptureEnabled()) DemoFailure(@"theme feature did not turn on");
    // 开始抓取 is an independent session: feature switches alone must not
    // activate the hot path, and toggling the session must be reversible.
    SaoqiangWCAssetsSetIconCapturing(YES);
    if (!SaoqiangWCAssetsIconCaptureActive()) DemoFailure(@"capture session did not activate");
    SaoqiangWCAssetsSetIconCapturing(NO);
    if (SaoqiangWCAssetsIconCaptureActive()) DemoFailure(@"capture session did not stop");
    SaoqiangWCAssetsSetIconCapturing(YES);
    SaoqiangWCAssetsRunNamingChecks();
    void (^resumeCapture)(void)=^{
        // The panel's 开始抓取 session starts off on every launch; the test
        // harness opens it explicitly before exercising the capture path.
        SaoqiangWCAssetsSetIconCapturing(YES);
        SaoqiangWCAssetsStore *store=[SaoqiangWCAssetsStore SaoqiangWCAssetsShared]; [store SaoqiangWCAssetsSetAppActive:YES]; [store SaoqiangWCAssetsSetEnabled:YES]; SaoqiangWCAssetsCaptureVisiblePage();
        [store SaoqiangWCAssetsAfterPending:^{ [self verifyAndPresent]; }];
    };
    NSArray *args = NSProcessInfo.processInfo.arguments;
    BOOL quickUI = [args containsObject:@"tools"] || [args containsObject:@"icons"] ||
        [args containsObject:@"home"] || [args containsObject:@"card"];
    if (quickUI) resumeCapture();
    else SaoqiangWCAssetsRunEngine308Checks(^{ SaoqiangWCAssetsRunFeatureChecks(self.window,resumeCapture); });
}
- (void)verifyAndPresent {
    SaoqiangWCAssetsStore *store=[SaoqiangWCAssetsStore SaoqiangWCAssetsShared]; NSArray *records=[store SaoqiangWCAssetsSnapshot];
    if (records.count!=7) DemoFailure([NSString stringWithFormat:@"page A count %lu expected7 · %@ · %@",(unsigned long)records.count,SaoqiangWCAssetsPageDiagnostics(),[store SaoqiangWCAssetsCollectionState]]);
    NSUInteger svg=0,bubbles=0;
    for (SaoqiangWCAssetsRecord *r in records) { svg+=[r.kind isEqual:@"SVG"]&&r.original; bubbles+=r.bubble&&!r.original; if ([r.name containsString:@"hidden"]||[r.name containsString:@"offscreen"]) DemoFailure(@"offscreen mixed"); }
    if (svg!=6 || bubbles!=1) DemoFailure(@"page A formats or bubble mismatch");
    self.savedSession=[store SaoqiangWCAssetsCollectionState][@"runtimeID"];
    self.pageAKeys=[NSSet setWithArray:[records valueForKey:@"identity"]];
    [store SaoqiangWCAssetsSetEnabled:NO];
    self.second=[UIViewController new]; self.second.view.backgroundColor=UIColor.systemGray6Color;
    UIImage *named=DemoImage(4);
    NSData *raw=[@"<svg xmlns=\"http://www.w3.org/2000/svg\"><rect width=\"12\" height=\"20\"/></svg>" dataUsingEncoding:NSUTF8StringEncoding];
    SaoqiangWCAssetsCallNamedSource(@"page_two_icon.svg",@"页面B真实命名加载",NO,^id{SaoqiangWCAssetsObserveSourceData(@"page_two_icon.svg",raw);return named;});
    UIImageView *icon=[[UIImageView alloc] initWithImage:named]; icon.frame=CGRectMake(20,125,30,30);[self.second.view addSubview:icon];
    UIButton *unknown=[UIButton buttonWithType:UIButtonTypeCustom]; [unknown setImage:DemoImage(8) forState:UIControlStateNormal];unknown.frame=CGRectMake(80,125,44,44);[self.second.view addSubview:unknown];
    // Existing .image=nil, but verified bubble background's layer has CGImage.
    CommonMessageCellView *layerCell=[[CommonMessageCellView alloc] initWithFrame:CGRectMake(20,210,200,48)];
    UIImageView *layerView=[[UIImageView alloc] initWithFrame:layerCell.bounds];
    UIImage *layerImage=DemoBubble(UIColor.systemGreenColor,CGSizeMake(48,26)); self.layerSource=layerImage;
    layerView.layer.contents=(__bridge id)layerImage.CGImage;layerView.layer.contentsScale=layerImage.scale;
    layerCell.backgroundImage=layerView;[layerCell addSubview:layerView];[self.second.view addSubview:layerCell];
    // Another exact background root contains an image child and a text child.
    CommonMessageCellView *containerCell=[[CommonMessageCellView alloc] initWithFrame:CGRectMake(20,290,210,52)];
    UIView *container=[[UIView alloc] initWithFrame:containerCell.bounds];containerCell.plainBackground=container;
    UIImageView *child=[[UIImageView alloc] initWithImage:DemoBubble(UIColor.systemOrangeColor,CGSizeMake(52,28))];self.containerSource=child.image;child.frame=container.bounds;[container addSubview:child];
    UILabel *text=[[UILabel alloc] initWithFrame:container.bounds];text.text=@"THIS MESSAGE MUST NOT BE CAPTURED";[container addSubview:text];
    [containerCell addSubview:container];[self.second.view addSubview:containerCell];
    // Conflicting aliases must not cause a verified unnamed bubble to vanish.
    CommonMessageCellView *conflictCell=[[CommonMessageCellView alloc] initWithFrame:CGRectMake(20,370,190,50)];
    UIImage *conflict=DemoBubble(UIColor.systemBlueColor,CGSizeMake(44,25));
    SaoqiangWCAssetsAssociateNamedImage(conflict,@"icons_filled_first",@"alias fixture",nil,NO);
    SaoqiangWCAssetsAssociateNamedImage(conflict,@"icons_filled_second",@"alias fixture",nil,NO);
    conflictCell.backgroundImage=[[UIImageView alloc] initWithImage:conflict];conflictCell.backgroundImage.frame=conflictCell.bounds;
    [conflictCell addSubview:conflictCell.backgroundImage];[self.second.view addSubview:conflictCell];
    self.window.rootViewController=self.second;[self.window layoutIfNeeded];
    SaoqiangWCAssetsCaptureVisiblePage();
    if ([store SaoqiangWCAssetsSnapshot].count!=7) DemoFailure(@"stop failed to freeze records");
    [store SaoqiangWCAssetsSetEnabled:YES]; SaoqiangWCAssetsCaptureVisiblePage();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[self verifyPageB];});
}
- (void)verifyPageB {
    SaoqiangWCAssetsStore *store=[SaoqiangWCAssetsStore SaoqiangWCAssetsShared];NSArray *records=[store SaoqiangWCAssetsSnapshot];
    if (records.count!=12) DemoFailure([NSString stringWithFormat:@"page B count %lu expected12 · %@ · %@",(unsigned long)records.count,SaoqiangWCAssetsPageDiagnostics(),SaoqiangWCAssetsBubbleDiagnostics()]);
    if (![[store SaoqiangWCAssetsCollectionState][@"runtimeID"] isEqual:self.savedSession]) DemoFailure(@"session reset during navigation");
    NSSet *keys=[NSSet setWithArray:[records valueForKey:@"identity"]];if (![self.pageAKeys isSubsetOfSet:keys]) DemoFailure(@"page A assets disappeared");
    NSUInteger bubble=0;
    for (SaoqiangWCAssetsRecord *r in records) if (r.bubble) {
        ++bubble;if (![r.name isEqual:@"无原始资源名"]||r.original||![r.kind isEqual:@"PNG"]) DemoFailure(@"unnamed background provenance wrong");
        UIImage *decoded=[UIImage imageWithData:r.bytes]; if (!decoded || CGImageGetWidth(decoded.CGImage)>160 || CGImageGetHeight(decoded.CGImage)>100) DemoFailure(@"background capture is not source texture");
    }
    if (bubble!=4) DemoFailure(@"background image/layer/container/conflict coverage");
    self.window.rootViewController=self.host;[self.window layoutIfNeeded];SaoqiangWCAssetsCaptureVisiblePage();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
        NSArray *all=[store SaoqiangWCAssetsSnapshot]; if (all.count!=12) DemoFailure(@"returning to A duplicated or removed assets");
        NSLog(@"PAGE_CAPTURE_PASSED A7 -> B12 -> A12; names and originals preserved; 4 unnamed backgrounds; photo/hidden/offscreen/text excluded; stopped records frozen");
        [self verifyNamingUpgrade];
    });
}
- (void)verifyNamingUpgrade {
    SaoqiangWCAssetsStore *store=[SaoqiangWCAssetsStore SaoqiangWCAssetsShared];
    NSArray *names=@[@"ChatRoom_Bubble_HB_Sender_Dark@2x.png",@"ChatRoom_Bubble_AA_Receiver@3x.png",@"ChatRoom_Bubble_HB_Sender_Handled@2x.png"];
    NSArray *images=@[self.firstBubble,self.layerSource,self.containerSource];
    for (NSUInteger i=0;i<images.count;i++) {
        UIImage *image=images[i];NSData *raw=UIImagePNGRepresentation(image);
        SaoqiangWCAssetsAssociateSourceImage(image,names[i],raw,@"实际气泡原名迟到测试",YES);
    }
    SaoqiangWCAssetsCaptureVisiblePage();
    [store SaoqiangWCAssetsAfterPending:^{
        if ([store SaoqiangWCAssetsSnapshot].count!=12) DemoFailure(@"placeholder upgrade duplicated first bubble");
        self.window.rootViewController=self.second;[self.window layoutIfNeeded];SaoqiangWCAssetsCaptureVisiblePage();
        [store SaoqiangWCAssetsAfterPending:^{
            NSArray *all=[store SaoqiangWCAssetsSnapshot];if (all.count!=12) DemoFailure(@"layer/name upgrade duplicated records");
            NSMutableSet *actual=[NSMutableSet new];NSUInteger unnamed=0;
            for (SaoqiangWCAssetsRecord *r in all) if (r.bubble) {
                if ([r.name isEqual:@"无原始资源名"]) {++unnamed;if(r.original) DemoFailure(@"ambiguous bubble marked original");}
                else { [actual addObject:r.name]; if (!r.original) DemoFailure(@"named bubble lost original PNG"); }
            }
            if (unnamed!=1 || ![actual isEqual:[NSSet setWithArray:names]]) DemoFailure([NSString stringWithFormat:@"named bubble export mismatch %@",actual]);
            NSLog(@"NAMED_PAGE_UPGRADE_PASSED count12 retained, original HB/AA/Handled names restored including cached layer");
            self.window.rootViewController=self.host;[self.window layoutIfNeeded];SaoqiangWCAssetsCaptureVisiblePage();
            [store SaoqiangWCAssetsAfterPending:^{[self exportAndShow:[store SaoqiangWCAssetsSnapshot]];}];
        }];
    }];
}
- (void)presentCardForLayoutCheck {
    SaoqiangWCAssetsSetIconCapturing(NO);
    SaoqiangWCAssetsPresentPanelForTesting(self.host, 1, YES);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        SaoqiangWCAssetsDemoDelegate *me=weakSelf; if (!me) return;
        NSURL *docs=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
        UIViewController *presented=me.host.presentedViewController;
        if (!presented) DemoFailure(@"card panel did not present");
        UIView *card=nil; UINavigationController *nav=nil;
        @try { card=[presented valueForKey:@"SaoqiangWCAssetsCard"]; nav=[presented valueForKey:@"SaoqiangWCAssetsNav"]; }
        @catch (__unused NSException *e) {}
        if (![card isKindOfClass:UIView.class] || ![nav isKindOfClass:UINavigationController.class])
            DemoFailure(@"card host missing card or navigation controller");
        CGFloat windowHeight=MAX(1,CGRectGetHeight(me.window.bounds));
        CGFloat collapsed=CGRectGetHeight(card.bounds)/windowHeight;
        // 0.11.40 spec: 3/5 collapsed, 4.5/5 expanded, top strip of WeChat visible.
        if (collapsed<0.55 || collapsed>0.65)
            DemoFailure([NSString stringWithFormat:@"card collapsed height %.3f is not 3/5",collapsed]);
        UILabel *title=DemoFindLabel(nav.view,@"抓取图标名称");
        if (!title) DemoFailure(@"card: 抓取图标名称 title missing");
        CGFloat titleTop=[title convertPoint:CGPointZero toView:nav.view].y;
        CGFloat barBottom=CGRectGetMaxY([nav.navigationBar convertRect:nav.navigationBar.bounds toView:nav.view]);
        // The 0.11.41 regression: content pinned to a zero safe area slid under
        // the bar and the title was cut in half.
        if (titleTop < barBottom-0.5)
            DemoFailure([NSString stringWithFormat:@"card title sits under the navigation bar: title y=%.1f bar bottom=%.1f",titleTop,barBottom]);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [presented performSelector:NSSelectorFromString(@"SaoqiangWCAssetsExpandForTesting")];
#pragma clang diagnostic pop
        [me.window layoutIfNeeded];
        CGFloat expanded=CGRectGetHeight(card.bounds)/windowHeight;
        if (expanded<0.85 || expanded>0.95)
            DemoFailure([NSString stringWithFormat:@"card expanded height %.3f is not 4.5/5",expanded]);
        [@"done" writeToURL:[docs URLByAppendingPathComponent:@"card-done.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    });
}
- (void)exportAndShow:(NSArray *)records {
    // Screenshots must show the launch default: 开始抓取 black, not green.
    SaoqiangWCAssetsSetIconCapturing(NO);
    SaoqiangWCAssetsStore *store=[SaoqiangWCAssetsStore SaoqiangWCAssetsShared];
    NSArray *exportArgs = NSProcessInfo.processInfo.arguments;
    if (![exportArgs containsObject:@"tools"] && ![exportArgs containsObject:@"icons"] &&
        ![exportArgs containsObject:@"home"] && ![exportArgs containsObject:@"card"]) {
        NSURL *documents=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
        [store SaoqiangWCAssetsExportFolder:records completion:^(NSURL *folder,NSString *failure) {
            if (!folder) DemoFailure(failure);
            NSError *error=nil; [NSFileManager.defaultManager copyItemAtURL:folder toURL:[documents URLByAppendingPathComponent:@"test-folder"] error:&error];
            if (error) DemoFailure(error.localizedDescription);
            SaoqiangWCAssetsRecord *bubble=nil; for (SaoqiangWCAssetsRecord *r in records) if (r.bubble) { bubble=r; break; }
            [store SaoqiangWCAssetsExport:bubble rendered:NO completion:^(NSURL *single,NSString *reason) {
                if (!single) DemoFailure(reason);
                if (bubble.original && ![single.lastPathComponent isEqual:bubble.name]) DemoFailure(@"single bubble filename changed");
                NSError *copyError=nil;[NSFileManager.defaultManager copyItemAtURL:single toURL:[documents URLByAppendingPathComponent:@"single-bubble.png"] error:&copyError];
                if (copyError) DemoFailure(copyError.localizedDescription);
                [store SaoqiangWCAssetsSetEnabled:NO];[store SaoqiangWCAssetsClear];
                if ([store SaoqiangWCAssetsSnapshot].count) DemoFailure(@"clear failed");
                // Restore only the checked synthetic snapshot for layout screenshots.
                NSMutableArray *shown=[NSMutableArray new];NSString *session=[store SaoqiangWCAssetsCollectionState][@"runtimeID"];
                for (SaoqiangWCAssetsRecord *r in records) {r.sessionID=session;[shown addObject:r];}
                [store setValue:shown forKey:@"records"];
                [[NSJSONSerialization dataWithJSONObject:SaoqiangWCAssetsNamingSummary() options:NSJSONWritingPrettyPrinted error:nil] writeToURL:[documents URLByAppendingPathComponent:@"naming-checks.json"] atomically:YES];
                [@"done" writeToURL:[documents URLByAppendingPathComponent:@"exports-done.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
            }];
        }];
    }
    NSArray *pageArgs = NSProcessInfo.processInfo.arguments;
    if ([pageArgs containsObject:@"card"]) { [self presentCardForLayoutCheck]; return; }
    UIViewController *panel=[NSClassFromString(@"SaoqiangWCAssetsController") new];
    panel.modalPresentationStyle=UIModalPresentationFullScreen;
    [self.host presentViewController:panel animated:NO completion:^{
        if ([pageArgs containsObject:@"tools"]) { UIButton *tab=[panel valueForKey:@"SaoqiangWCAssetsThemeTabButton"]; [tab sendActionsForControlEvents:UIControlEventTouchUpInside]; }
        else if ([pageArgs containsObject:@"icons"]) { UIButton *entry=[panel valueForKey:@"SaoqiangWCAssetsIconEntry"]; [entry sendActionsForControlEvents:UIControlEventTouchUpInside]; }
        else if ([pageArgs containsObject:@"home"]) {
            UIButton *entry=[panel valueForKey:@"SaoqiangWCAssetsIconEntry"]; [entry sendActionsForControlEvents:UIControlEventTouchUpInside];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                UIButton *homeBtn=[panel valueForKey:@"SaoqiangWCAssetsHomeButton"];
                if (!homeBtn) DemoFailure(@"返回微信首页 button missing");
                [homeBtn sendActionsForControlEvents:UIControlEventTouchUpInside];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.8*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                    // The panel must be gone; a host with no tab bar makes the unwind a no-op.
                    NSURL *docs=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
                    [@"done" writeToURL:[docs URLByAppendingPathComponent:@"home-done.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
                });
            });
        }
    }];
}
@end
int main(int argc,char *argv[]) { @autoreleasepool {return UIApplicationMain(argc,argv,nil,NSStringFromClass(SaoqiangWCAssetsDemoDelegate.class));} }
