#import "SaoqiangWCAssetsThemePack.h"
#import "SaoqiangWCAssetsTheme.h"
#import "SaoqiangWCAssetsReference.h"
#import "SaoqiangWCAssetsNative.h"
#import "SaoqiangWCAssetsPackNames.h"
#import "SaoqiangWCAssets.h"
#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>
#import <fcntl.h>
#import <unistd.h>
#import <sys/stat.h>
#import <errno.h>
#import <stdatomic.h>
#import <stdbool.h>
#import <string.h>
#import <ImageIO/ImageIO.h>
#import <limits.h>

static const NSUInteger SQThemeFileLimit=32*1024*1024, SQThemeTotalLimit=512*1024*1024, SQThemeCountLimit=19999;
static NSObject *SaoqiangWCAssetsPackLock(void){static NSObject *x;static dispatch_once_t once;dispatch_once(&once,^{x=[NSObject new];});return x;}
static dispatch_queue_t SaoqiangWCAssetsPackQueue(void){static dispatch_queue_t q;static dispatch_once_t once;dispatch_once(&once,^{q=dispatch_queue_create("com.saoqiang.wcassets.theme-diy",DISPATCH_QUEUE_SERIAL);});return q;}
static atomic_bool SaoqiangWCAssetsPackCancelled;
static NSMutableDictionary *SaoqiangWCAssetsPackProgress;
static BOOL SQCancelled(void){return atomic_load(&SaoqiangWCAssetsPackCancelled);}
static void SQProgress(NSDictionary *values){@synchronized(SaoqiangWCAssetsPackLock()){if(!SaoqiangWCAssetsPackProgress)SaoqiangWCAssetsPackProgress=[NSMutableDictionary new];[SaoqiangWCAssetsPackProgress addEntriesFromDictionary:values];}}
NSDictionary *SaoqiangWCAssetsThemePackState(void){@synchronized(SaoqiangWCAssetsPackLock()){return [SaoqiangWCAssetsPackProgress copy]?:@{@"busy":@NO,@"stage":@"未开始"};}}
void SaoqiangWCAssetsCancelThemeExport(void){atomic_store(&SaoqiangWCAssetsPackCancelled,true);}
static BOOL SQBegin(SaoqiangWCAssetsThemePackCompletion completion){@synchronized(SaoqiangWCAssetsPackLock()){
    if([SaoqiangWCAssetsPackProgress[@"busy"] boolValue]){dispatch_async(dispatch_get_main_queue(),^{completion(nil,@{},@"已有主题导出正在进行");});return NO;}
    atomic_store(&SaoqiangWCAssetsPackCancelled,false);SaoqiangWCAssetsPackProgress=[@{@"busy":@YES,@"stage":@"读取加载器索引",@"processed":@0,@"expected":@0,@"total":@0,@"written":@0,@"failed":@0,@"missing":@0,@"unsupported":@0,@"skipped":@0,@"conflicts":@0} mutableCopy];return YES;
}}
static void SQFinish(NSURL *folder,NSURL *work,NSDictionary *report,NSString *error,SaoqiangWCAssetsThemePackCompletion completion){
    NSDictionary *snapshot=[report copy]?:@{};
    dispatch_async(dispatch_get_main_queue(),^{
        BOOL cancelled=SQCancelled();BOOL available=folder&&!error.length&&!cancelled&&[snapshot[@"written"]unsignedIntegerValue]>0;
        BOOL complete=available&&[snapshot[@"complete"]boolValue];NSMutableDictionary *state=[snapshot mutableCopy];
        for(NSString *key in @[@"expected",@"total",@"processed",@"written",@"failed",@"missing",@"unsupported",@"conflicts",@"skipped",@"bytes",@"itemsVerified",@"warnings"])if(!state[key])state[key]=@0;
        state[@"busy"]=@NO;state[@"cancelled"]=cancelled?@YES:@NO;state[@"available"]=available?@YES:@NO;state[@"complete"]=complete?@YES:@NO;
        state[@"stage"]=cancelled?@"已取消":(available?(complete?@"本次清单已全部导出":@"已导出文件可保存"):@"没有可保存文件");
        NSString *failure=cancelled?@"已取消导出":error;
        if(failure.length){state[@"error"]=failure;state[@"diagnostic"]=failure;}
        if(!available&&work)dispatch_async(SaoqiangWCAssetsPackQueue(),^{[NSFileManager.defaultManager removeItemAtURL:work error:nil];});
        SQProgress(state);completion(available?folder:nil,[state copy],failure?:(!available?@"没有取得可保存的原文件":nil));
    });
}
static BOOL SQObject(const char *t){return t&&(!strcmp(t,"@")||!strncmp(t,"@\"",2));}
static Method SQMethod(id receiver,NSString *name,NSUInteger count){
    Method m=receiver?class_getInstanceMethod(object_getClass(receiver),NSSelectorFromString(name)):NULL;if(!m)return NULL;
    NSMethodSignature *s=[NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)];
    if(s.numberOfArguments!=count||!SQObject(s.methodReturnType)||strcmp([s getArgumentTypeAtIndex:0],"@")||strcmp([s getArgumentTypeAtIndex:1],":"))return NULL;
    for(NSUInteger i=2;i<count;i++)if(!SQObject([s getArgumentTypeAtIndex:i]))return NULL;return m;
}
static id SQGet(id receiver,NSString *name){Method m=SQMethod(receiver,name,2);return m?((id(*)(id,SEL))method_getImplementation(m))(receiver,NSSelectorFromString(name)):nil;}
static id SQCall(id receiver,NSString *name,NSString *file){Method m=SQMethod(receiver,name,3);return m?((id(*)(id,SEL,id))method_getImplementation(m))(receiver,NSSelectorFromString(name),file):nil;}
static BOOL SQHasScalar(id receiver,NSString *name,const char *type,BOOL *value){
    Method m=receiver?class_getInstanceMethod(object_getClass(receiver),NSSelectorFromString(name)):NULL;if(!m)return NO;
    NSMethodSignature *s=[NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)];if(s.numberOfArguments!=2||strcmp(s.methodReturnType,type))return NO;
    if(value)*value=((BOOL(*)(id,SEL))method_getImplementation(m))(receiver,NSSelectorFromString(name));return YES;
}
static NSString *SQPath(id value){NSString *p=nil;if([value isKindOfClass:NSString.class])p=value;else if([value isKindOfClass:NSURL.class]&&[value isFileURL])p=[value path];return p.length&&p.length<=2048&&p.isAbsolutePath?p.stringByStandardizingPath:nil;}
static NSString *SQText(id value,NSString *fallback){return [value isKindOfClass:NSString.class]&&[value length]&&[value length]<=1024?[value copy]:fallback;}
static id SQField(id object,NSString *name){return [object isKindOfClass:NSDictionary.class]?object[name]:SQGet(object,name);}
static NSString *SQHash(NSData *data){unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,digest);NSMutableString *s=[NSMutableString new];for(NSUInteger i=0;i<sizeof(digest);i++)[s appendFormat:@"%02x",digest[i]];return s;}
static NSString *SQName(id value){
    if(![value isKindOfClass:NSString.class]||![value length]||[value length]>1024)return nil;NSString *s=value;
    if(s.isAbsolutePath||[s containsString:@"\\"]||[s containsString:@":"]||[s hasSuffix:@"/"]||[s containsString:@"//"]||[s rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)return nil;
    for(NSString *part in s.pathComponents)if([part isEqual:@"."]||[part isEqual:@".."]||!part.length)return nil;
    return [s copy];
}
static NSString *SQFold(NSString *name){return name.precomposedStringWithCanonicalMapping.lowercaseString;}
static NSString *SQTitle(NSString *s){NSMutableString *t=[NSMutableString new];for(NSUInteger i=0;i<MIN(s.length,80u);i++){unichar c=[s characterAtIndex:i];[t appendFormat:@"%C",(unichar)(c<32||c=='/'||c=='\\'||c==':'?'_':c)];}return t.length?t:@"主题DIY素材";}

@interface SaoqiangWCAssetsDIYXML : NSObject <NSXMLParserDelegate>
@property(nonatomic) BOOL seen;
@property(nonatomic) BOOL valid;
@end
@implementation SaoqiangWCAssetsDIYXML
- (void)parser:(NSXMLParser *)p didStartElement:(NSString *)element namespaceURI:(NSString *)uri qualifiedName:(NSString *)q attributes:(NSDictionary *)a {
    (void)p;(void)q;(void)a;if(!self.seen){self.seen=YES;self.valid=[element isEqual:@"svg"]&&(!uri.length||[uri isEqual:@"http://www.w3.org/2000/svg"]);}
}
@end
static NSString *SQImageExtension(NSData *data){
    if(!data.length||data.length>SQThemeFileLimit)return nil;const unsigned char *p=data.bytes;NSUInteger n=data.length;
    if(n>=8&&!memcmp(p,"\x89PNG\r\n\x1a\n",8)) {
        CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data,NULL);if(!source)return nil;
        NSDictionary *properties=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL));
        CGImageSourceStatus status=CGImageSourceGetStatus(source);size_t count=CGImageSourceGetCount(source);CFRelease(source);
        return count&&status==kCGImageStatusComplete&&[properties[(__bridge NSString *)kCGImagePropertyPixelWidth]doubleValue]>0&&[properties[(__bridge NSString *)kCGImagePropertyPixelHeight]doubleValue]>0?@"png":nil;
    }
    if(n>=3&&p[0]==255&&p[1]==216&&p[2]==255)return @"jpg";
    if(n>=6&&(!memcmp(p,"GIF87a",6)||!memcmp(p,"GIF89a",6)))return @"gif";
    if(n>=12&&!memcmp(p,"RIFF",4)&&!memcmp(p+8,"WEBP",4))return @"webp";
    NSXMLParser *parser=[[NSXMLParser alloc]initWithData:data];SaoqiangWCAssetsDIYXML *delegate=[SaoqiangWCAssetsDIYXML new];parser.delegate=delegate;parser.shouldProcessNamespaces=YES;parser.shouldResolveExternalEntities=NO;
    return [parser parse]&&delegate.valid?@"svg":nil;
}
static BOOL SQMatchesExtension(NSString *name,NSString *kind){
    NSString *ext=name.pathExtension.lowercaseString;if(!ext.length)return YES;
    if([kind isEqual:@"jpg"])return [@[@"jpg",@"jpeg"]containsObject:ext];
    if([kind isEqual:@"png"])return [@[@"png",@"apng"]containsObject:ext];
    return [ext isEqual:kind];
}
static NSData *SQReadFile(NSString *path,NSString **error){
    int fd=open(path.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_NONBLOCK);
    if(fd<0){if(error)*error=@"原文件无法读取";return nil;}
    struct stat a,b;if(fstat(fd,&a)||!S_ISREG(a.st_mode)||a.st_size<=0||(uint64_t)a.st_size>SQThemeFileLimit){close(fd);if(error)*error=@"原文件为空、不是普通文件或超过单文件限制";return nil;}
    NSMutableData *data=[NSMutableData dataWithLength:(NSUInteger)a.st_size];NSUInteger at=0;
    while(at<data.length){if(SQCancelled()){close(fd);if(error)*error=@"已取消";return nil;}ssize_t n=read(fd,(unsigned char *)data.mutableBytes+at,MIN((NSUInteger)65536,data.length-at));if(n<0&&errno==EINTR)continue;if(n<=0){close(fd);if(error)*error=@"原文件读取中断";return nil;}at+=(NSUInteger)n;}
    BOOL same=!fstat(fd,&b)&&a.st_dev==b.st_dev&&a.st_ino==b.st_ino&&a.st_size==b.st_size&&a.st_mtimespec.tv_sec==b.st_mtimespec.tv_sec&&a.st_mtimespec.tv_nsec==b.st_mtimespec.tv_nsec&&a.st_ctimespec.tv_sec==b.st_ctimespec.tv_sec&&a.st_ctimespec.tv_nsec==b.st_ctimespec.tv_nsec;
    unsigned char extra;ssize_t more=read(fd,&extra,1);close(fd);if(!same||more!=0){if(error)*error=@"读取时原文件发生变化";return nil;}return data;
}
static BOOL SQWriteVerified(NSData *data,NSURL *file,NSString **error){
    NSError *e=nil;if(![NSFileManager.defaultManager createDirectoryAtURL:file.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&e]||![data writeToURL:file options:NSDataWritingAtomic error:&e]){if(error)*error=e.localizedDescription?:@"写入失败";return NO;}
    NSData *saved=SQReadFile(file.path,error);if(!saved||![saved isEqualToData:data]){if(error&&!*error)*error=@"写出文件与源数据不一致";return NO;}return YES;
}
static id SQObjectIvar(id object,const char *name){
    Ivar ivar=object?class_getInstanceVariable(object_getClass(object),name):NULL;const char *type=ivar?ivar_getTypeEncoding(ivar):NULL;
    return type&&type[0]=='@'?object_getIvar(object,ivar):nil;
}
static BOOL SQMetadataName(NSString *name){
    NSString *n=name.lastPathComponent.lowercaseString;
    return [@[@"manifest.json",@"config.json",@"theme.json",@"info.json",@"theme.plist",@"info.plist",@"readme.txt",@"readme.md",@".ds_store"]containsObject:n];
}

static id SQFreeze(id value,NSUInteger depth,BOOL *ok){
    if(depth>12){*ok=NO;return NSNull.null;}
    if(!value||value==NSNull.null)return NSNull.null;
    if([value isKindOfClass:NSString.class]||[value isKindOfClass:NSNumber.class])return [value copy];
    if([value isKindOfClass:NSURL.class])return [value isFileURL]?[value path]:[value absoluteString];
    if([value isKindOfClass:NSData.class])return @{@"length":@([value length]),@"sha256":SQHash(value)};
    if([value isKindOfClass:NSArray.class]||[value isKindOfClass:NSSet.class]){if([value count]>SQThemeCountLimit){*ok=NO;return @[];}NSMutableArray *a=[NSMutableArray new];for(id v in value)[a addObject:SQFreeze(v,depth+1,ok)];if([value isKindOfClass:NSSet.class]){for(id v in a)if(![v isKindOfClass:NSString.class]){*ok=NO;return @[];}[a sortUsingSelector:@selector(compare:)];}return a;}
    if([value isKindOfClass:NSDictionary.class]){if([value count]>SQThemeCountLimit){*ok=NO;return @{};}NSMutableDictionary *d=[NSMutableDictionary new];for(id key in value){if(![key isKindOfClass:NSString.class]){*ok=NO;continue;}d[key]=SQFreeze(value[key],depth+1,ok);}return d;}
    *ok=NO;return NSNull.null;
}
static void SQAddNames(id collection,NSMutableSet *keys,NSString *label,NSMutableArray *issues){
    if(!collection)return;
    if(![collection isKindOfClass:NSArray.class]&&![collection isKindOfClass:NSSet.class]&&![collection isKindOfClass:NSDictionary.class]){[issues addObject:@{@"source":label,@"reason":@"资源索引类型未支持"}];return;}
    if([collection count]>SQThemeCountLimit){[issues addObject:@{@"source":label,@"reason":@"资源数超过安全限制"}];return;}
    for(id item in collection){NSString *key=SQName(item);if(!key){[issues addObject:@{@"source":label,@"reason":@"资源索引包含无效名称"}];continue;}if(!SQMetadataName(key))[keys addObject:key];}
}
// 3.0.8's new engine hides the pack name index inside live provider instances.
// Walk object-typed ivars at runtime and harvest string resource names. Nothing
// is hard-coded: no ivar name, offset, version or UUID. Non-object ivars are
// skipped, traversal is bounded, and a candidate is only a candidate -- the
// existing dataWithContentsOfFile: oracle still decides what is real.
static void SQCollectNameStrings(id value,NSMutableSet *keys,NSUInteger depth,NSUInteger *visited){
    if(!value||depth>4||!visited||*visited>SQThemeCountLimit)return;
    ++*visited;
    if([value isKindOfClass:NSString.class]){
        NSString *name=SQName(value);
        if(name.length&&!SQMetadataName(name))[keys addObject:name];
        return;
    }
    if([value isKindOfClass:NSDictionary.class]){
        NSDictionary *dict=value;
        if(dict.count>SQThemeCountLimit)return;
        for(id key in dict){
            if([key isKindOfClass:NSString.class]){NSString *name=SQName(key);if(name.length&&!SQMetadataName(name))[keys addObject:name];}
            SQCollectNameStrings(dict[key],keys,depth+1,visited);
        }
        return;
    }
    if([value isKindOfClass:NSArray.class]||[value isKindOfClass:NSSet.class]){
        if([value count]>SQThemeCountLimit)return;
        for(id item in value)SQCollectNameStrings(item,keys,depth+1,visited);
    }
}
// Collects into `candidates` only; the caller keeps authoritative `keys`
// separate so a failed candidate never inflates missing/error counters.
static NSUInteger SQCollectIvarNames(id instance,NSMutableSet *candidates,NSMutableArray *issues,NSString *label){
    if(!instance)return 0;
    NSUInteger added=0,visited=0;
    Class cls=object_getClass(instance);
    for(Class c=cls;c&&c!=NSObject.class;c=class_getSuperclass(c)){
        unsigned int count=0;Ivar *ivars=class_copyIvarList(c,&count);
        for(unsigned int i=0;i<count;i++){
            const char *encoding=ivar_getTypeEncoding(ivars[i]);
            if(!encoding||encoding[0]!='@')continue;
            NSUInteger before=candidates.count;
            @try{
                id value=object_getIvar(instance,ivars[i]);
                SQCollectNameStrings(value,candidates,0,&visited);
            }@catch(NSException *exception){
                [issues addObject:@{@"source":label,@"reason":[NSString stringWithFormat:@"读取实例变量 %s 异常，已跳过：%@",ivar_getName(ivars[i]),exception.name?:@"未知"]}];
            }
            added+=candidates.count-before;
        }
        if(ivars)free(ivars);
        if(added>SQThemeCountLimit)break;
    }
    return added;
}
// Only keep candidate strings that look like a resource name: a supported image
// extension, or an extensionless name that contains no spaces/control chars.
static BOOL SQPlausibleResourceName(NSString *name){
    if(!name.length||name.length>1024)return NO;
    if([name rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location!=NSNotFound)return NO;
    NSString *ext=name.pathExtension.lowercaseString;
    if(ext.length)return [@[@"png",@"jpg",@"jpeg",@"gif",@"webp",@"svg",@"apng",@"heic"]containsObject:ext];
    return YES;
}
static NSDictionary *SQManager(Class managerClass,NSString **error){
    if(!managerClass){if(error)*error=@"没有找到主题管理器，请先启用主题盒子";return nil;}
    id manager=SQGet(managerClass,@"shared");if(![manager isKindOfClass:managerClass]){if(error)*error=@"主题管理器接口返回值不兼容";return nil;}
    BOOL enabled=YES;if(SQHasScalar(manager,@"loadTheme",@encode(BOOL),&enabled)&&!enabled){if(error)*error=@"请先开启当前主题再导出";return nil;}
    id info=SQGet(manager,@"currentThemeInfo");NSString *path=SQPath(SQGet(manager,@"currentThemePath"));NSString *pathSource=@"currentThemePath";
    if(!path){path=SQPath(SQField(info,@"path"));pathSource=@"currentThemeInfo.path";}
    if(!path){if(error)*error=@"没有取得当前主题身份/路径，不能用全局目录代替";return nil;}
    return @{@"manager":manager,@"root":path,@"pathSource":pathSource,@"themeName":SQText(SQField(info,@"name"),path.lastPathComponent),@"themeID":SQText(SQField(info,@"themeId"),@""),@"bubbleRoot":SQPath(SQGet(manager,@"currentBubblePath"))?:@"",@"diyRoot":SQPath(SQGet(manager,@"currentThemeDIYPath"))?:@""};
}
// New ThemeBox engines expose a dictionary-backed ThemeBoxAssets instance.
// Select by an ABI-checked capability/active-engine flag, never a version number.
static BOOL SQValidReader(id object,Class cls){return cls&&[object isKindOfClass:cls]&&SQMethod(object,@"dataWithContentsOfFile:",3);}
static id SQSelectThemeReader(Class legacyClass,Class assetsClass,Class utilClass,NSString **engine,BOOL *engineKnown,BOOL *newEnabled,NSString **error){
    BOOL enabled=NO,known=SQHasScalar(utilClass,@"enabledNewEngine",@encode(BOOL),&enabled);
    id legacy=(!known||!enabled)?SQGet(legacyClass,@"shared"):nil;
    id assets=(!known||enabled)&&assetsClass?SQGet(assetsClass,@"shared"):nil;
    BOOL legacyValid=SQValidReader(legacy,legacyClass),assetsValid=SQValidReader(assets,assetsClass);
    if(engineKnown)*engineKnown=known;if(newEnabled)*newEnabled=enabled;
    if(known){
        if(enabled){
            if(!assetsValid){if(error)*error=@"当前启用了新主题引擎，但 ThemeBoxAssets 原文件接口不可用";return nil;}
            id map=SQGet(assets,@"themeFiles");
            if(![map isKindOfClass:NSDictionary.class]){if(error)*error=@"新主题引擎的资源表不是可读取字典";return nil;}
            if(engine)*engine=@"ThemeBoxAssets";return assets;
        }
        if(!legacyValid){if(error)*error=@"当前使用旧主题引擎，但原文件读取接口不可用";return nil;}
        if(engine)*engine=@"ThemeBoxImageLoader";return legacy;
    }
    // Older versions do not have enabledNewEngine. Prefer their established reader.
    if(legacyValid){
        id f=SQGet(legacy,@"themeFiles"),i=SQObjectIvar(legacy,"_fileIndex"),m=SQGet(legacy,@"themeFileMap");
        if(([f respondsToSelector:@selector(count)]&&[f count])||([i isKindOfClass:NSDictionary.class]&&[i count])||([m isKindOfClass:NSDictionary.class]&&[m count])){
            if(engine)*engine=@"ThemeBoxImageLoader";return legacy;
        }
    }
    if(assetsValid&&[SQGet(assets,@"themeFiles") isKindOfClass:NSDictionary.class]){
        if(engine)*engine=@"ThemeBoxAssets";return assets;
    }
    if(legacyValid){if(engine)*engine=@"ThemeBoxImageLoader";return legacy;}
    if(error)*error=@"没有可用的当前主题原文件读取接口";return nil;
}
static NSDictionary *SQCompanionSnapshot(NSString *root,BOOL includeContainer){
    NSMutableArray *names=[@[@"weui_color_new.xml",@"color.css"]mutableCopy];
    if(includeContainer)[names addObject:@"themebox.dat"];
    NSMutableDictionary *files=[NSMutableDictionary new];
    // Resolve the selected theme directory once. Never follow a final-component
    // link or use a sibling/installed-theme directory as a substitute.
    NSString *canonical=root.stringByResolvingSymlinksInPath.stringByStandardizingPath;
    struct stat rs;BOOL directory=canonical.isAbsolutePath&&canonical.length>1&&!lstat(canonical.fileSystemRepresentation,&rs)&&S_ISDIR(rs.st_mode);
    for(NSString *name in names){
        NSString *path=[canonical stringByAppendingPathComponent:name];struct stat st;
        if(!directory||lstat(path.fileSystemRepresentation,&st)){
            files[name]=@{@"name":name,@"path":path?:@"",@"exists":@NO,@"status":directory?@"missing":@"theme-directory-unavailable"};continue;
        }
        BOOL regular=S_ISREG(st.st_mode)&&!S_ISLNK(st.st_mode);
        files[name]=@{@"name":name,@"path":path,@"exists":@YES,@"readable":regular?@YES:@NO,@"status":regular?@"present":@"unsafe-or-nonregular",@"size":@(st.st_size),@"device":@((uint64_t)st.st_dev),@"inode":@((uint64_t)st.st_ino),@"mtimeSec":@(st.st_mtimespec.tv_sec),@"mtimeNano":@(st.st_mtimespec.tv_nsec),@"ctimeSec":@(st.st_ctimespec.tv_sec),@"ctimeNano":@(st.st_ctimespec.tv_nsec),@"rootDevice":@((uint64_t)rs.st_dev),@"rootInode":@((uint64_t)rs.st_ino)};
    }
    return files;
}
static NSData *SQReadCompanion(NSDictionary *source,NSString **error){
    if(![source[@"exists"]boolValue]||![source[@"readable"]boolValue]){if(error)*error=@"当前主题原文件不存在、不是普通文件或是符号链接";return nil;}
    NSString *path=source[@"path"];struct stat st,root;
    if(lstat([path stringByDeletingLastPathComponent].fileSystemRepresentation,&root)||!S_ISDIR(root.st_mode)||(uint64_t)root.st_dev!=[source[@"rootDevice"]unsignedLongLongValue]||(uint64_t)root.st_ino!=[source[@"rootInode"]unsignedLongLongValue]||lstat(path.fileSystemRepresentation,&st)||!S_ISREG(st.st_mode)||(uint64_t)st.st_dev!=[source[@"device"]unsignedLongLongValue]||(uint64_t)st.st_ino!=[source[@"inode"]unsignedLongLongValue]||st.st_size!=[source[@"size"]longLongValue]||st.st_mtimespec.tv_sec!=[source[@"mtimeSec"]longLongValue]||st.st_mtimespec.tv_nsec!=[source[@"mtimeNano"]longLongValue]||st.st_ctimespec.tv_sec!=[source[@"ctimeSec"]longLongValue]||st.st_ctimespec.tv_nsec!=[source[@"ctimeNano"]longLongValue]){if(error)*error=@"当前主题原文件或目录在导出中发生变化";return nil;}
    return SQReadFile(path,error);
}
// The manager exposes one directory per resource category (iconPath, maskPath,
// cardPath, widgetPath, ...). Those are loose files on disk, not entries in the
// pack, so no name table lists them and no provider call can reach them: they
// have to be enumerated. A record in the same shape SQCompanionSnapshot produces
// means SQReadCompanion's inode/mtime/ctime re-validation applies unchanged.
static NSDictionary *SQFileRecord(NSString *path,NSString *rootPath){
    struct stat st,root;
    if(lstat(path.fileSystemRepresentation,&st)||!S_ISREG(st.st_mode)||S_ISLNK(st.st_mode))return nil;
    if(lstat(rootPath.fileSystemRepresentation,&root)||!S_ISDIR(root.st_mode))return nil;
    return @{@"name":path.lastPathComponent,@"path":path,@"exists":@YES,@"readable":@YES,@"status":@"present",@"size":@(st.st_size),@"device":@((uint64_t)st.st_dev),@"inode":@((uint64_t)st.st_ino),@"mtimeSec":@(st.st_mtimespec.tv_sec),@"mtimeNano":@(st.st_mtimespec.tv_nsec),@"ctimeSec":@(st.st_ctimespec.tv_sec),@"ctimeNano":@(st.st_ctimespec.tv_nsec),@"rootDevice":@((uint64_t)root.st_dev),@"rootInode":@((uint64_t)root.st_ino)};
}
// Bounded by count, and by the existing per-file/total size limits downstream.
// Symbolic links and packages are skipped: a theme directory that links out of
// the theme would otherwise let an export walk arbitrary parts of the container.
static NSArray<NSString *> *SQDirectoryImages(NSString *dir,NSUInteger limit){
    NSString *canonical=dir.stringByStandardizingPath;struct stat st;
    if(!canonical.isAbsolutePath||lstat(canonical.fileSystemRepresentation,&st)||!S_ISDIR(st.st_mode))return nil;
    static NSSet *exts;static dispatch_once_t once;dispatch_once(&once,^{exts=[NSSet setWithArray:@[@"png",@"jpg",@"jpeg",@"gif",@"webp",@"svg",@"apng",@"bmp",@"heic"]];});
    NSMutableArray *found=[NSMutableArray new];
    NSDirectoryEnumerator *walk=[NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:canonical isDirectory:YES] includingPropertiesForKeys:@[NSURLIsRegularFileKey,NSURLIsSymbolicLinkKey] options:NSDirectoryEnumerationSkipsHiddenFiles|NSDirectoryEnumerationSkipsPackageDescendants errorHandler:nil];
    // Bounded by visits, not only by matches: a directory full of non-image files
    // would otherwise be walked to the end while `found` stayed empty, and this
    // runs on the main thread.
    NSUInteger visited=0;
    for(NSURL *child in walk){
        if(found.count>=limit||++visited>20000)break;
        NSNumber *regular=nil,*link=nil;
        if(![child getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil]||!regular.boolValue)continue;
        if([child getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil]&&link.boolValue)continue;
        if(![exts containsObject:child.path.pathExtension.lowercaseString])continue;
        [found addObject:child.path];
    }
    [found sortUsingSelector:@selector(compare:)];
    return found;
}
// Flat reader for the engine's category directories (Icons/Masks/Cards/Widgets).
// Those hold the applied theme's images directly -- the same 700-odd base names a
// shipped pack unpacks to -- but they sit beside `Themes/`, not inside the
// applied theme's own folder. Recursing here would be wrong in a different way:
// any per-theme subdirectory would drag a sibling theme in, and the per-theme
// child is already handled before this is called.
static NSArray<NSString *> *SQDirectoryImagesFlat(NSString *dir,NSUInteger limit){
    NSString *canonical=dir.stringByStandardizingPath;struct stat st;
    if(!canonical.isAbsolutePath||lstat(canonical.fileSystemRepresentation,&st)||!S_ISDIR(st.st_mode))return nil;
    static NSSet *exts;static dispatch_once_t once;dispatch_once(&once,^{exts=[NSSet setWithArray:@[@"png",@"jpg",@"jpeg",@"gif",@"webp",@"svg",@"apng",@"bmp",@"heic"]];});
    NSArray *names=[NSFileManager.defaultManager contentsOfDirectoryAtPath:canonical error:nil];
    if(!names)return nil;
    NSMutableArray *found=[NSMutableArray new];
    for(NSString *name in [names sortedArrayUsingSelector:@selector(compare:)]){
        if(found.count>=limit)break;
        if(![exts containsObject:name.pathExtension.lowercaseString])continue;
        NSString *full=[canonical stringByAppendingPathComponent:name];
        struct stat item;
        if(lstat(full.fileSystemRepresentation,&item)||!S_ISREG(item.st_mode))continue;
        [found addObject:full];
    }
    return found;
}
// SQSnapshot re-runs every 64 exported items to prove the theme did not change,
// and re-walking every category directory each time would dominate the export.
// The listing is keyed on the theme root with a short TTL; the per-file inode and
// timestamp checks in SQReadCompanion still run on every single read, so a file
// that changes mid-export is caught where it matters.
static NSArray *SQDirectorySnapshot(NSDictionary *identity,NSMutableArray *lines){
    static NSArray *cache;static NSTimeInterval at;static NSString *cacheRoot;
    NSString *root=identity[@"root"];NSTimeInterval now=NSDate.date.timeIntervalSince1970;
    if(cache&&now-at<5.0&&(cacheRoot==root||[cacheRoot isEqualToString:root]))return cache;
    id manager=identity[@"manager"];
    NSMutableArray *entries=[NSMutableArray new],*report=[NSMutableArray new];
    NSMutableSet *seenPaths=[NSMutableSet new],*seenKeys=[NSMutableSet new];
    // Every path getter either class declares, in the order a human would check.
    NSArray *sels=@[@"iconPath",@"maskPath",@"cardPath",@"widgetPath",@"bubblePath",@"themePath",@"currentBubblePath",@"currentFontPath",@"currentThemeDIYPath",@"baseThemePath",@"currentThemePath"];
    for(NSString *sel in sels){
        NSString *path=SQPath(SQGet(manager,sel));
        if(!path){[report addObject:[NSString stringWithFormat:@"目录 %@：取不到路径",sel]];continue;}
        // A path outside `root` is only read when ownership is still specific: a
        // directory whose last component *is* this theme's own name (DIY lives at
        // Documents/ThemeBox/diy/<theme>), a shared base holding a per-theme child
        // of that name (ThemeBox/Icons/<theme>), or one of the four category
        // getters, read flat. Anything else is a store holding several packs --
        // `themePath`/`bubblePath` under Preferences are exactly that -- and is
        // skipped, which is what stopped the 0.11.7 export from mixing packs.
        NSString *themeName=root.lastPathComponent;
        BOOL insideRoot=[path isEqualToString:root]||[path hasPrefix:[root stringByAppendingString:@"/"]];
        BOOL flatOnly=NO;
        // The four category getters point at the engine's own image store, which
        // lives beside `Themes/` rather than inside it. Those directories are the
        // reason a 2,500-file pack exported as 112: the scope rule added in 0.11.8
        // skipped them wholesale. They are read flat and only for the categories
        // the manager names -- `themePath` and `bubblePath` stay skipped, because
        // those are stores holding several themes at once.
        BOOL category=[@[@"iconPath",@"maskPath",@"cardPath",@"widgetPath"] containsObject:sel];
        NSArray *flatFiles=nil;
        if(!insideRoot&&![path.lastPathComponent isEqualToString:themeName]){
            NSString *scoped=[path stringByAppendingPathComponent:themeName];struct stat child;
            if(lstat(scoped.fileSystemRepresentation,&child)==0&&S_ISDIR(child.st_mode)){
                // Both layouts are real: a category may keep its images flat, or
                // override per theme in a child directory of the theme's name. Read
                // the child, and for categories also the flat siblings, because
                // taking only one of the two is how files go missing quietly.
                if(category)flatFiles=SQDirectoryImagesFlat(path,6000);
                path=scoped;
            }
            else if(category)flatOnly=YES;
            else{[report addObject:[NSString stringWithFormat:@"目录 %@=%@ 既不在当前主题目录内，也没有本主题的子目录，跳过",sel,path]];continue;}
        }
        if([seenPaths containsObject:path]){[report addObject:[NSString stringWithFormat:@"目录 %@=%@（与前项重复，跳过）",sel,path]];continue;}
        [seenPaths addObject:path];
        NSArray *files=flatOnly?SQDirectoryImagesFlat(path,6000):SQDirectoryImages(path,3000);
        if(flatFiles.count)files=files?[flatFiles arrayByAddingObjectsFromArray:files]:flatFiles;
        if(!files){[report addObject:[NSString stringWithFormat:@"目录 %@=%@ 不存在或不是目录",sel,path]];continue;}
        NSString *prefix=sel;
        NSUInteger added=0;
        for(NSString *file in files){
            if(entries.count>=12000)break;
            NSString *relative=[file hasPrefix:[path stringByAppendingString:@"/"]]?[file substringFromIndex:path.length+1]:file.lastPathComponent;
            NSString *key=[[prefix stringByAppendingString:@"/"]stringByAppendingString:relative];
            if([seenKeys containsObject:key])continue;
            NSDictionary *record=SQFileRecord(file,file.stringByDeletingLastPathComponent);
            if(!record)continue;
            [seenKeys addObject:key];
            [entries addObject:@{@"provider":@"ThemeDirectory",@"key":key,@"identity":[@"ThemeDirectory|" stringByAppendingString:key],@"fileSource":record}];
            ++added;
        }
        [report addObject:[NSString stringWithFormat:@"目录 %@=%@ 图片 %lu（收录 %lu%@）",sel,path,(unsigned long)files.count,(unsigned long)added,(flatOnly||flatFiles.count)?@"，分类目录扁平读取":@""]];
    }
    // What else sits beside `Themes/`. Report only, never exported: the point is
    // to see whether a category the four getters do not name is holding images,
    // without walking into `Themes` itself (that one holds every installed pack).
    NSString *base=SQPath(SQGet(manager,@"baseThemePath"));
    if(base){
        NSArray *names=[NSFileManager.defaultManager contentsOfDirectoryAtPath:base error:nil];
        NSMutableArray *parts=[NSMutableArray new];
        for(NSString *name in [names sortedArrayUsingSelector:@selector(compare:)]){
            if(parts.count>=24)break;
            NSString *full=[base stringByAppendingPathComponent:name];struct stat st;
            if(lstat(full.fileSystemRepresentation,&st))continue;
            if(!S_ISDIR(st.st_mode)){[parts addObject:name];continue;}
            NSArray *flat=SQDirectoryImagesFlat(full,4000);
            NSArray *kids=[NSFileManager.defaultManager contentsOfDirectoryAtPath:full error:nil];
            NSUInteger subdirs=0;
            for(NSString *kid in kids){struct stat kst;if(!lstat([full stringByAppendingPathComponent:kid].fileSystemRepresentation,&kst)&&S_ISDIR(kst.st_mode))++subdirs;}
            [parts addObject:[NSString stringWithFormat:@"%@/(%lu 图%@)",name,(unsigned long)flat.count,subdirs?[NSString stringWithFormat:@", %lu 子目录",(unsigned long)subdirs]:@""]];
        }
        [report addObject:[NSString stringWithFormat:@"ThemeBox 根目录（仅统计，不导出）：%@",[parts componentsJoinedByString:@" "]]];
    }
    // localCards/localMasks live on the manager, not on ThemeBoxUtil. Their
    // counts say whether cards and masks are a large category worth chasing.
    for(NSString *sel in @[@"localCards",@"localMasks",@"localBubbles",@"localVideos"]){
        id value=SQGet(manager,sel);
        if([value respondsToSelector:@selector(count)])[report addObject:[NSString stringWithFormat:@"Mgr.%@=%lu",sel,(unsigned long)[value count]]];
    }
    for(NSString *line in report)[lines addObject:line];
    cache=[entries copy];at=now;cacheRoot=[root copy];
    return cache;
}


static NSDictionary *SQSnapshot(Class managerClass,Class loaderClass,Class assetsClass,Class utilClass,Class bubbleManagerClass,Class bubbleAssetsClass,Class bubbleConfigClass,NSString **error){
    NSCAssert(NSThread.isMainThread,@"Loader snapshot on main thread");SaoqiangWCAssetsPushSuppression();
    @try {
        NSDictionary *identity=SQManager(managerClass,error);if(!identity)return nil;
        NSString *engine=nil;BOOL engineKnown=NO,newEnabled=NO;id loader=SQSelectThemeReader(loaderClass,assetsClass,utilClass,&engine,&engineKnown,&newEnabled,error);if(!loader)return nil;
        NSMutableArray *issues=[NSMutableArray new];NSMutableSet *keys=[NSMutableSet new];
        // Successful discovery must NOT go through `issues`: the report counts
        // every issue as a warning and only calls an export complete when
        // issues.count == 0, so an informational line here would mark a healthy
        // export as incomplete. Diagnostics about what the probes found live in
        // this separate channel and are written to _export-info/issues.txt.
        NSMutableArray<NSString *> *discovery=[NSMutableArray new];
        BOOL newEngine=[engine isEqual:@"ThemeBoxAssets"];
        NSDictionary *reference=newEngine?SaoqiangWCAssetsReferenceSnapshot(identity[@"themeID"]):nil;
        NSDictionary *referenceKeys=reference[@"byKey"]?:@{};
        if(reference)[issues addObject:@{@"source":@"reference",@"reason":@"按导入清单主动读取并验收；清单外封包资源仍未知，不将清单验收等同于封包完整性"}];
        // Probe every known index getter on whichever reader is active. SQGet is
        // ABI-checked and returns nil for a selector the object does not really
        // expose, so probing a new-engine object costs nothing. Previously these
        // were hard-gated off for 3.0.8, which hid maps that may still be present.
        id files=SQGet(loader,@"themeFiles"),index=SQObjectIvar(loader,"_fileIndex");
        id map=SQGet(loader,@"themeFileMap"),diy=SQGet(loader,@"diyFileMap"),container=SQGet(loader,@"themeData");
        // The one object that would hold the pack's own decrypted index. Logged
        // with its type and count because "nil" and "an empty dictionary" mean
        // very different things for the next step.
        [discovery addObject:index?[NSString stringWithFormat:@"_fileIndex：%@，count=%@",NSStringFromClass([index class]),[index respondsToSelector:@selector(count)]?[NSString stringWithFormat:@"%lu",(unsigned long)[index count]]:@"无"]:@"_fileIndex：nil"];
        id util=SQGet(utilClass,@"shared");
        if(utilClass&&util&&![util isKindOfClass:utilClass]){[issues addObject:@{@"source":@"ThemeBoxUtil",@"reason":@"资源映射类型不兼容"}];util=nil;}
        id current=SQGet(util,@"currentThemeFileMap"),currentDIY=SQGet(util,@"themeDIYFileMap");
        for(NSArray *part in @[@[@"themeFiles",files?:NSNull.null],@[@"_fileIndex",index?:NSNull.null],@[@"themeFileMap",map?:NSNull.null],@[@"diyFileMap",diy?:NSNull.null],@[@"currentThemeFileMap",current?:NSNull.null],@[@"themeDIYFileMap",currentDIY?:NSNull.null]])if(part[1]!=NSNull.null)SQAddNames(part[1],keys,part[0],issues);
        // Harvest candidate names from the live provider/cache instances' object
        // ivars. Candidates are kept separate from authoritative keys: a candidate
        // that fails every read path is simply dropped (not counted as
        // missing/failed), so a noisy ivar cannot corrupt the export report.
        //
        // New engine only, deliberately. This is the one discovery path with no
        // validation behind it, so anything it invents reaches the loader as a
        // key: an old-engine provider whose ivars hold ordinary state (a dict
        // with a "length" entry is enough) produced exactly that, and the export
        // handed "length" to ThemeBox as a file name. The provider probe below is
        // gated on the provider's own fileExistsWithName:, so it cannot invent a
        // key -- that is the path that has to work on a real 3.0.8 device, and
        // this scan stays as the new-engine fallback it always was.
        NSMutableSet *candidateKeys=[NSMutableSet new];
        NSUInteger ivarRaw=0;
        // Exceptions raised while probing speculative ivars go to their own
        // array: this scan is exploratory, and one unreadable ivar on some
        // provider build must not turn a healthy export into "incomplete".
        NSMutableArray *probeIssues=[NSMutableArray new];
        if(newEngine){
            ivarRaw+=SQCollectIvarNames(loader,candidateKeys,probeIssues,@"当前读取器 ivars");
            id newUtil=SQGet(utilClass,@"shared");
            if(newUtil&&[newUtil isKindOfClass:utilClass])ivarRaw+=SQCollectIvarNames(newUtil,candidateKeys,probeIssues,@"ThemeBoxUtil ivars");
            id boxCache=SQGet(NSClassFromString(@"ThemeBoxCache"),@"shared");
            if(boxCache)ivarRaw+=SQCollectIvarNames(boxCache,candidateKeys,probeIssues,@"ThemeBoxCache ivars");
        }
        for(NSDictionary *note in probeIssues)[discovery addObject:[NSString stringWithFormat:@"ivar-scan %@：%@",note[@"source"]?:@"",note[@"reason"]?:@""]];
        // Never let a candidate displace an authoritative name already collected.
        [candidateKeys minusSet:keys];
        // Signature anchor, taken BEFORE any derived name is merged in. The export
        // re-runs this snapshot every 64 items to prove the theme did not change,
        // and that hash must describe the provider's authoritative tables only:
        // our own reads populate the provider's decrypt cache (one of the probed
        // sources), so hashing the merged list would make a healthy export look
        // like a mid-run theme switch and abort it.
        NSArray *authoritativeNames=[keys.allObjects sortedArrayUsingSelector:@selector(compare:)];
        NSMutableSet *ivarCandidates=[NSMutableSet new];
        for(NSString *name in [candidateKeys.allObjects sortedArrayUsingSelector:@selector(compare:)]){
            if(!SQPlausibleResourceName(name))continue;
            [keys addObject:name];[ivarCandidates addObject:name];
        }
        if(ivarRaw)[discovery addObject:[NSString stringWithFormat:@"ivar-discovery：读取器与缓存实例内发现 %lu 个字符串候选，%lu 个形态合法并入清单（逐项仍需读取验证）",(unsigned long)ivarRaw,(unsigned long)ivarCandidates.count]];
        // Provider-side index: probe every collection ThemeBox exposes (loader
        // maps, ThemeBoxIconMap.maps, decrypt caches, the Util class-level
        // *FileList), expand each entry to concrete file variants, then keep only
        // names the provider itself confirms via fileExistsWithName:.
        // Deliberately NOT gated on `newEngine`: on this device the active reader
        // is ThemeBoxImageLoader, and the previous `newEngine &&` gate skipped the
        // whole discovery, which is why the export stayed at the loaded snapshot.
        NSDictionary *nativeIndex=nil;
        NSArray *probeNames=@[];
        NSUInteger nativeNames=0;
        NSMutableSet *nativeKeys=[NSMutableSet new];
        {
            NSString *nativeError=nil;
            nativeIndex=SaoqiangWCAssetsNativeIndex(identity[@"root"],container,&nativeError);
            NSArray *names=nativeIndex[@"names"];
            if([names isKindOfClass:NSArray.class]){
                for(NSString *name in names){
                    if(![name isKindOfClass:NSString.class])continue;
                    if([ivarCandidates containsObject:name])continue;
                    if([keys containsObject:name])continue;
                    // These came from the provider's own tables and passed its
                    // existence check, but a read can still miss; provenance keeps
                    // such a miss in `skipped` rather than `missing`.
                    [keys addObject:name];[ivarCandidates addObject:name];[nativeKeys addObject:name];++nativeNames;
                }
            }
            // Always record this line, including the zero case: "probed but found
            // nothing" is the most useful signal for the next round, and silence
            // would look like success.
            NSString *nativeNote=nativeError.length?[@"，原因：" stringByAppendingString:nativeError]:@"";
            NSString *indexNote=[nativeIndex[@"note"] isKindOfClass:NSString.class]?nativeIndex[@"note"]:nil;
            if(indexNote.length)nativeNote=[nativeNote stringByAppendingFormat:@"；%@",indexNote];
            [discovery addObject:[NSString stringWithFormat:@"provider-index：新增 %lu 个资源名%@",(unsigned long)nativeNames,nativeNote]];
            // Per-source detail (what each table held, what the device table
            // says, what the container looks like). Separate lines, because the
            // one above is already long enough to get truncated by a reader.
            probeNames=[nativeIndex[@"probe"] isKindOfClass:NSArray.class]?nativeIndex[@"probe"]:@[];
            NSArray *nativeLines=nativeIndex[@"lines"];
            if([nativeLines isKindOfClass:NSArray.class])for(id line in nativeLines)
                if([line isKindOfClass:NSString.class])[discovery addObject:line];
        }
        // Can one export ever cover the whole pack? ThemeBoxInfo carries
        // isParent + themes, and ThemeBoxMgr keeps localThemes: if the applied
        // theme is one child of a bundle, the sibling children's resources are
        // simply not loaded and no amount of name probing will reach them. Log
        // the shape so the answer stops being a guess.
        {
            id manager=identity[@"manager"];
            id localThemes=SQGet(manager,@"localThemes");
            id currentInfo=SQGet(manager,@"currentThemeInfo");
            id children=SQField(currentInfo,@"themes");
            BOOL isParent=NO,isParentKnown=SQHasScalar(currentInfo,@"isParent",@encode(BOOL),&isParent);
            BOOL localKnown=[localThemes respondsToSelector:@selector(count)];
            BOOL childKnown=[children respondsToSelector:@selector(count)];
            [discovery addObject:[NSString stringWithFormat:
                @"theme-set：localThemes=%@, 当前主题 isParent=%@, 子主题=%@（子主题或子条目存在即说明封包含多个主题，单主题导出不可能覆盖全部）",
                localKnown?@([localThemes count]):@"不可读",
                isParentKnown?@(isParent):@"不可读",
                childKnown?@([children count]):@"不可读"]];
        }
        // Category directories: loose files the pack's name table never lists.
        NSArray *dirEntries=SQDirectorySnapshot(identity,discovery);
        if(index&&![index isKindOfClass:NSDictionary.class])[issues addObject:@{@"source":@"_fileIndex",@"reason":@"容器索引不是字典，已保留其他可读清单"}];
        for(id active in @[map?:@{},diy?:@{},current?:@{},currentDIY?:@{}])if(![active isKindOfClass:NSDictionary.class])[issues addObject:@{@"source":@"active-map",@"reason":@"活动映射不是字典"}];
        if(container&&![container isKindOfClass:NSData.class])[issues addObject:@{@"source":@"themeData",@"reason":@"容器对象不是NSData"}];
        if([container isKindOfClass:NSData.class]&&[container length]&&(![index isKindOfClass:NSDictionary.class]||![index count]))[issues addObject:@{@"source":@"themeData",@"reason":@"有容器数据但索引不可用"}];
        BOOL themeBubbleEnabled=NO;BOOL themeBubbleKnown=SQHasScalar(identity[@"manager"],@"loadBubble",@encode(BOOL),&themeBubbleEnabled);
        // Kept gated as before: SQAddNames records an issue for a collection it
        // cannot type, and on the old engine this path is the only source of
        // bubble names. The probe covers loader.bubbleFiles for the new engine,
        // so nothing is lost by leaving this where it was.
        id loadedBubbles=newEngine?nil:SQGet(loader,@"bubbleFiles");SQAddNames(loadedBubbles,keys,@"ThemeBox已加载气泡",issues);
        SaoqiangWCAssetsThemeSetCaptureRoot(identity[@"root"]);
        NSArray *allDecoded=SaoqiangWCAssetsThemeCapturedSnapshot(identity[@"root"]);
        NSMutableArray *retainedDecoded=[NSMutableArray new];
        for(NSDictionary *item in allDecoded)if(!referenceKeys[item[@"key"]])[retainedDecoded addObject:item];
        NSArray *decoded=[retainedDecoded copy];
        NSMutableDictionary *decodedByKey=[NSMutableDictionary new];
        for(NSDictionary *item in decoded)if([item[@"key"] isKindOfClass:NSString.class])decodedByKey[item[@"key"]]=item;
        // The pack's own size is the cheapest evidence of how many entries it can
        // hold, and it settles the question the export count keeps raising: at
        // this theme's ~30 KB per image, 11 MB is not a thousand files. Logged
        // without being exported, so a pack larger than the 32 MB single-file
        // limit cannot turn a healthy export into a failed one.
        unsigned long long packBytes=0;
        {
            NSString *datPath=[identity[@"root"] stringByAppendingPathComponent:@"themebox.dat"];struct stat dat;packBytes=0;
            if(!lstat(datPath.fileSystemRepresentation,&dat)&&S_ISREG(dat.st_mode)){
                packBytes=(unsigned long long)dat.st_size;
                [discovery addObject:[NSString stringWithFormat:@"themebox.dat：%lld 字节（%.2f MB）",(long long)dat.st_size,dat.st_size/1048576.0]];
            }
            else [discovery addObject:@"themebox.dat：当前主题目录下没有该文件"];
        }
        // The pack's own table, if the provider will hand it over by name. This
        // is the only route that can beat the encrypted container: guessing file
        // names has a ceiling around 130 because the loader answers for every
        // installed pack, while its table lists exactly what it contains.
        NSDictionary *packIndex=packBytes?SaoqiangWCAssetsNativePackIndex():nil;
        if([packIndex[@"data"] isKindOfClass:NSData.class]){
            [discovery addObject:[NSString stringWithFormat:@"封包索引：%@ 可读，%@ 字节，内容是文本/plist/JSON（已随导出保存）",packIndex[@"name"],@([packIndex[@"data"] length])]];
        }
        else [discovery addObject:@"封包索引：没有以常见清单名读回内容（表不是可单独寻址的条目）"];
        NSDictionary *companions=SQCompanionSnapshot(identity[@"root"],newEngine);
        NSDictionary *pack=companions[@"themebox.dat"];
        BOOL opaqueContainer=newEngine&&[pack[@"exists"]boolValue];
        if(newEngine&&decoded.count&&!opaqueContainer)[issues addObject:@{@"source":@"ThemeBoxDecoded",@"reason":@"仅包含运行时实际解密/读取到的资源；未证明封包存在完整公开清单"}];
        NSMutableDictionary *colorStatus=[NSMutableDictionary new];
        for(NSString *name in @[@"weui_color_new.xml",@"color.css"])colorStatus[name]=@{@"status":companions[name][@"status"]?:@"missing",@"exists":companions[name][@"exists"]?:@NO};
        // The requested companions always come from the selected theme directory.
        // Do not send them or a receipt through a renderer/native fallback.
        for(NSString *key in [keys.allObjects copy]) {
            NSString *base=key.lastPathComponent.lowercaseString;
            if([base isEqual:@"weui_color_new.xml"]||[base isEqual:@"color.css"]||[base hasSuffix:@".receipt"]||(newEngine&&[base isEqual:@"themebox.dat"]))[keys removeObject:key];
        }
        [keys addObjectsFromArray:referenceKeys.allKeys];
        if(keys.count>SQThemeCountLimit){if(error)*error=@"当前清单与对照清单合计超出19999项";return nil;}
        NSArray *ordered=[keys.allObjects sortedArrayUsingSelector:@selector(compare:)];
        NSString *themeProvider=newEngine?@"ThemeBoxAssets":@"ThemeBox";
        NSMutableArray *entries=[NSMutableArray new];NSMutableSet *entryKeys=[NSMutableSet new];
        for(NSString *key in ordered){
            NSMutableDictionary *entry=[@{@"provider":themeProvider,@"key":key,@"identity":[NSString stringWithFormat:@"%@|%@",themeProvider,key],@"receiver":loader}mutableCopy];
            if([ivarCandidates containsObject:key])entry[@"ivarCandidate"]=@YES;
            if([nativeKeys containsObject:key])entry[@"nativeName"]=key;
            NSDictionary *expected=referenceKeys[key];
            if(expected){entry[@"referenceExpected"]=expected;entry[@"captureSource"]=@"active ThemeBoxAssets exact key; independent reference length/SHA256 verified";}
            NSDictionary *captured=expected?nil:decodedByKey[key];
            if([captured[@"conflict"]boolValue]){[issues addObject:@{@"source":key,@"reason":@"运行时解密缓存同名资源返回了不同原字节，未假定哪一份正确"}];entry[@"captureConflict"]=@YES;}
            else if([captured[@"data"] isKindOfClass:NSData.class]&&[captured[@"data"] length]){entry[@"capturedData"]=captured[@"data"];entry[@"captureSource"]=captured[@"source"]?:@"ThemeBox decoded cache";}
            [entries addObject:entry];[entryKeys addObject:key];
        }
        for(NSDictionary *captured in decoded){
            NSString *key=captured[@"key"];
            if(![key isKindOfClass:NSString.class]||[entryKeys containsObject:key])continue;
            if([captured[@"conflict"]boolValue]){[issues addObject:@{@"source":key,@"reason":@"运行时解密缓存同名资源返回了不同原字节，未导出冲突项"}];continue;}
            NSData *data=captured[@"data"];
            if(![data isKindOfClass:NSData.class]||!data.length)continue;
            NSString *provider=@"ThemeBoxDecoded";
            [entries addObject:@{@"provider":provider,@"key":key,@"identity":[NSString stringWithFormat:@"%@|%@",provider,key],@"capturedData":data,@"captureSource":captured[@"source"]?:@"ThemeBox decoded cache"}];
            [entryKeys addObject:key];
        }
        for(NSString *name in [[companions allKeys]sortedArrayUsingSelector:@selector(compare:)]) {
            NSDictionary *source=companions[name];
            if(![source[@"exists"]boolValue])continue;
            BOOL isPack=[name isEqual:@"themebox.dat"];
            NSString *provider=isPack?@"ThemeSource":@"ThemeColors";
            if(![source[@"readable"]boolValue]){[issues addObject:@{@"source":name,@"reason":@"当前主题配套文件是符号链接或不是普通文件，未读取"}];continue;}
            [entries addObject:@{@"provider":provider,@"key":name,@"identity":[NSString stringWithFormat:@"%@|%@",provider,name],@"fileSource":source}];
        }
        // Directory files are exact originals read straight off disk, so they are
        // added last and never displace a provider key of the same name.
        // Dedupe by folded base name, not just by key: the theme directory holds
        // cover.png and icon.png, which the provider already serves, and keying
        // only on the key exported both again into _duplicates/ with identical
        // bytes. Same name and same file means one entry, whichever path found it.
        NSMutableSet *usedBases=[NSMutableSet new];
        for(NSDictionary *entry in entries)[usedBases addObject:SQFold([entry[@"key"] lastPathComponent])];
        for(NSDictionary *entry in dirEntries){
            NSString *key=entry[@"key"];
            if(![key isKindOfClass:NSString.class]||[entryKeys containsObject:key])continue;
            NSString *base=SQFold(key.lastPathComponent);
            if([usedBases containsObject:base])continue;
            [usedBases addObject:base];
            [entries addObject:entry];[entryKeys addObject:key];
        }
        if(opaqueContainer)[issues addObject:@{@"source":@"themebox.dat",@"reason":@"新引擎封包的全部文件名尚不能可靠枚举；保存封包原件不等于图标已全部展开"}];
        BOOL schema=YES;NSMutableArray *decodedSignature=[NSMutableArray new];
        for(NSDictionary *item in decoded){NSString *key=item[@"key"]?:@"";NSData *data=item[@"data"];[decodedSignature addObject:@{@"key":key,@"sha256":[data isKindOfClass:NSData.class]?SQHash(data):@"",@"conflict":item[@"conflict"]?:@NO}];}
        NSMutableDictionary *state=[@{@"root":identity[@"root"],@"themeID":identity[@"themeID"],@"diyRoot":identity[@"diyRoot"],@"bubbleRoot":identity[@"bubbleRoot"],@"engine":engine?:@"unknown",@"engineFlagKnown":engineKnown?@YES:@NO,@"engineFlag":newEnabled?@YES:@NO,@"names":authoritativeNames,@"decoded":decodedSignature,@"files":SQFreeze(files,0,&schema),@"fileIndex":SQFreeze(index,0,&schema),@"fileMap":SQFreeze(map,0,&schema),@"diyMap":SQFreeze(diy,0,&schema),@"currentMap":SQFreeze(current,0,&schema),@"currentDIY":SQFreeze(currentDIY,0,&schema),@"bubbleFiles":SQFreeze(loadedBubbles,0,&schema),@"loadBubbleKnown":@(themeBubbleKnown),@"loadBubble":@(themeBubbleEnabled),@"companions":companions,@"container":@{@"length":@([container isKindOfClass:NSData.class]?[container length]:0),@"object":[NSString stringWithFormat:@"%p",container]}}mutableCopy];
        state[@"referenceSHA256"]=reference[@"sha256"]?:@"";
        state[@"decodedCount"]=@(decoded.count);
        // Part of the signature: a category directory that gains or loses files
        // mid-export must look like a change, not silently shift the file count.
        state[@"directoryCount"]=@(dirEntries.count);
        // Independent BubbleBox has its own enable state, current path and loader.
        BOOL boxEnabled=NO,boxKnown=NO;id boxLoader=nil;
        if(bubbleConfigClass){id config=SQGet(bubbleConfigClass,@"shared");if([config isKindOfClass:bubbleConfigClass])boxKnown=SQHasScalar(config,@"enabled",@encode(BOOL),&boxEnabled);if(!boxKnown)[issues addObject:@{@"source":@"BubbleBox",@"reason":@"独立气泡启用状态接口不兼容，未假定已启用"}];}
        state[@"bubbleBoxEnableKnown"]=@(boxKnown);state[@"bubbleBoxEnabled"]=@(boxEnabled);
        if(boxKnown&&boxEnabled){
            id boxManager=SQGet(bubbleManagerClass,@"shared");boxLoader=SQGet(bubbleAssetsClass,@"shared");
            NSString *root=[boxManager isKindOfClass:bubbleManagerClass]?SQPath(SQGet(boxManager,@"currentBubblePath")):nil;
            if(!root||![boxLoader isKindOfClass:bubbleAssetsClass]||!SQMethod(boxLoader,@"dataWithContentsOfFile:",3)){
                [issues addObject:@{@"source":@"BubbleBox",@"reason":@"独立气泡当前路径或原始数据接口不可用"}];boxLoader=nil;
            }else{
                id boxFiles=SQGet(boxLoader,@"bubbleFiles"),boxMap=SQGet(boxLoader,@"bubbleFileMap"),boxData=SQGet(boxLoader,@"bubbleData");
                NSMutableSet *boxKeys=[NSMutableSet new];SQAddNames(boxFiles,boxKeys,@"BubbleBox.bubbleFiles",issues);SQAddNames(boxMap,boxKeys,@"BubbleBox.bubbleFileMap",issues);
                if(boxMap&&![boxMap isKindOfClass:NSDictionary.class])[issues addObject:@{@"source":@"BubbleBox.bubbleFileMap",@"reason":@"气泡文件映射类型不支持"}];
                NSArray *boxOrdered=[boxKeys.allObjects sortedArrayUsingSelector:@selector(compare:)];
                if(!boxOrdered.count)[issues addObject:@{@"source":@"BubbleBox",@"reason":@"独立气泡已启用但尚无已加载资源清单"}];
                for(NSString *key in boxOrdered)[entries addObject:@{@"provider":@"BubbleBox",@"key":key,@"identity":[@"BubbleBox|" stringByAppendingString:key],@"receiver":boxLoader}];
                state[@"bubbleBox"]=@{@"root":root,@"files":SQFreeze(boxFiles,0,&schema),@"map":SQFreeze(boxMap,0,&schema),@"keys":boxOrdered,@"data":@{@"object":[NSString stringWithFormat:@"%p",boxData],@"length":@([boxData isKindOfClass:NSData.class]?[boxData length]:0)}};
            }
        }
        if(!schema)[issues addObject:@{@"source":@"loader",@"reason":@"索引含未识别数据类型，完整性未确认"}];
        if(!entries.count){if(error)*error=@"当前加载器没有可导出的资源清单，请应用主题后重试";return nil;}
        if(entries.count>SQThemeCountLimit){if(error)*error=@"资源超过19999项，当前导出尚不支持该数量";return nil;}
        NSData *json=[NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingSortedKeys error:nil];if(!json){if(error)*error=@"资源快照无法验证";return nil;}
        NSMutableDictionary *result=[identity mutableCopy];result[@"loader"]=loader;result[@"entries"]=[entries copy];result[@"issues"]=issues;result[@"discovery"]=[discovery copy];result[@"signature"]=SQHash(json);result[@"expected"]=@(entries.count);result[@"expectedKnown"]=issues.count==0?@YES:@NO;result[@"versionLocked"]=@NO;result[@"provider"]=[engine stringByAppendingString:@" + current enabled BubbleBox"];result[@"engine"]=engine;result[@"colorFiles"]=colorStatus;result[@"opaqueContainer"]=opaqueContainer?@YES:@NO;result[@"decodedCount"]=@(decoded.count);result[@"reference"]=reference?:@{};
        // A second signature that only covers things this export cannot change by
        // reading: the theme's own identity plus the companion files' stats (colour
        // table, css, the pack itself). The full signature hashes the provider's
        // caches, which the by-name scan and the ObjC reader both fill on purpose,
        // so using it mid-write aborts the export on its own side effects. A colour
        // source that changes under the export still moves this one, which is the
        // case the 3.0.8 checks care about.
        //
        // The container's object pointer is deliberately left out: each snapshot
        // builds a fresh NSData, so hashing the pointer would make this signature
        // differ on every read and abort perfectly healthy exports. Its length is
        // the part that says the pack itself changed.
        NSMutableDictionary *stable=[state mutableCopy];
        {
            // Two things in `state` are runtime cache rather than theme state, and
            // this export fills both by reading: the container object itself (a
            // fresh NSData every snapshot, so only its length is meaningful) and
            // the captured-decoded list, which any decryption can extend.
            NSDictionary *boxed=state[@"container"];
            if([boxed isKindOfClass:NSDictionary.class]){
                NSMutableDictionary *trimmed=[boxed mutableCopy];
                [trimmed removeObjectForKey:@"object"];
                stable[@"container"]=trimmed;
            }
            [stable removeObjectForKey:@"decoded"];
        }
        NSData *stableJSON=[NSJSONSerialization dataWithJSONObject:stable options:NSJSONWritingSortedKeys error:nil];
        result[@"stableSignature"]=SQHash(stableJSON?:[NSData data]);
        // Per-key digests, so a mid-export mismatch can name the field that moved
        // instead of only saying "something changed".
        NSMutableDictionary *hashes=[NSMutableDictionary new];
        for(NSString *key in stable){
            NSData *piece=[NSJSONSerialization dataWithJSONObject:@{@"v":stable[key]} options:NSJSONWritingSortedKeys error:nil];
            if(piece)hashes[key]=SQHash(piece);
        }
        result[@"stateHashes"]=hashes;
        result[@"managerClass"]=managerClass;result[@"loaderClass"]=loaderClass;result[@"assetsClass"]=assetsClass?(id)assetsClass:NSNull.null;result[@"utilClass"]=utilClass?(id)utilClass:NSNull.null;
        result[@"bubbleManagerClass"]=bubbleManagerClass?(id)bubbleManagerClass:NSNull.null;result[@"bubbleAssetsClass"]=bubbleAssetsClass?(id)bubbleAssetsClass:NSNull.null;result[@"bubbleConfigClass"]=bubbleConfigClass?(id)bubbleConfigClass:NSNull.null;
        if(boxLoader)result[@"bubbleLoader"]=boxLoader;
        // The first 64KB of the provider's own pack data, kept out of `state`
        // (it is signed and JSON-encoded) and written next to the report as
        // container-head.bin. If the pack's index turns out to be a header
        // table, that file is what makes it readable offline instead of
        // another round of guessing from the device.
        result[@"probeNames"]=probeNames;
        result[@"packBytes"]=@(packBytes);
        if([packIndex[@"data"] isKindOfClass:NSData.class]){
            result[@"packIndexName"]=packIndex[@"name"];
            result[@"packIndex"]=packIndex[@"data"];
        }
        if([container isKindOfClass:NSData.class]&&[container length])
            result[@"containerHead"]=[container subdataWithRange:NSMakeRange(0,MIN([container length],(NSUInteger)65536))];
        return result;
    }@catch(NSException *e){if(error)*error=[@"读取资源索引异常：" stringByAppendingString:e.name];return nil;}
    @finally{SaoqiangWCAssetsPopSuppression();}
}

static NSMutableDictionary *SQReport(NSDictionary *snapshot){
    NSMutableDictionary *report=[@{@"themeName":snapshot[@"themeName"]?:@"当前主题",@"themeID":snapshot[@"themeID"]?:@"",@"provider":snapshot[@"provider"]?:@"当前加载器",@"engine":snapshot[@"engine"]?:@"unknown",@"colorFiles":snapshot[@"colorFiles"]?:@{},@"opaqueContainer":snapshot[@"opaqueContainer"]?:@NO,@"decodedCount":snapshot[@"decodedCount"]?:@0,@"scope":@"当前主题已加载索引、3.0.8运行时已解密缓存、DIY覆盖和已启用独立气泡资源；未暴露的资源仍需核实",@"expected":snapshot[@"expected"]?:@0,@"total":snapshot[@"expected"]?:@0,@"discovered":snapshot[@"expected"]?:@0,@"expectedKnown":snapshot[@"expectedKnown"]?:@NO,@"written":@0,@"processed":@0,@"failed":@0,@"missing":@0,@"unsupported":@0,@"conflicts":@0,@"skipped":@0,@"warnings":@0,@"itemsVerified":@0,@"bytes":@0,@"available":@NO,@"complete":@NO,@"sourceMode":@"provider-bound-original-data",@"discovery":snapshot[@"discovery"]?:@[],@"layout":@"原文件名平铺；重名另存_duplicates/编号/；记录在_export-info/",@"issues":[NSMutableArray new]} mutableCopy];
    report[@"referenceCount"]=snapshot[@"reference"][@"count"]?:@0;
    report[@"referenceSHA256"]=snapshot[@"reference"][@"sha256"]?:@"";
    report[@"referenceMatched"]=@0;report[@"referenceMismatch"]=@0;report[@"referenceMissing"]=@0;report[@"referenceComplete"]=@NO;report[@"referenceObserved"]=[NSMutableArray new];
    return report;
}
static void SQIssue(NSMutableDictionary *report,NSString *counter,NSString *identity,NSString *reason){
    report[counter]=@([report[counter]unsignedIntegerValue]+1);
    NSMutableArray *issues=report[@"issues"];if(issues.count<20000)[issues addObject:@{@"key":identity?:@"",@"reason":reason?:@"未知问题",@"category":counter}];
}
static NSURL *SQCreateWork(NSDictionary *snapshot,NSURL **work,NSString **error){
    NSURL *cache=[NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *parent=[[cache URLByAppendingPathComponent:@"SaoqiangWCAssetsFileExports" isDirectory:YES]URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
    NSDateFormatter *date=[NSDateFormatter new];date.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"];date.dateFormat=@"yyyyMMdd-HHmmss";
    NSString *label=[NSString stringWithFormat:@"%@-%@",SQTitle(snapshot[@"themeName"]?:@"主题素材"),[date stringFromDate:NSDate.date]];
    NSURL *folder=[parent URLByAppendingPathComponent:label isDirectory:YES];NSError *e=nil;
    if(![NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:&e]){if(error)*error=e.localizedDescription;return nil;}
    if(work)*work=parent;return folder;
}
static BOOL SQStoreItem(NSData *data,NSDictionary *entry,NSURL *folder,NSMutableDictionary *report,NSMutableDictionary *destinations,NSMutableArray *items){
    NSString *key=entry[@"key"],*identity=entry[@"identity"];
    if(![data isKindOfClass:NSData.class]||!data.length){SQIssue(report,@"missing",identity,@"加载器未返回非空原数据");return NO;}
    if(data.length>SQThemeFileLimit){SQIssue(report,@"failed",identity,@"单文件超过32MB");return NO;}
    NSDictionary *expected=entry[@"referenceExpected"];
    if(expected&&(data.length!=[expected[@"bytes"]unsignedIntegerValue]||![SQHash(data)isEqual:expected[@"sha256"]])){
        NSMutableArray *observed=report[@"referenceObserved"];
        if(observed.count<4096)[observed addObject:@{@"key":identity,@"expectedBytes":expected[@"bytes"],@"actualBytes":@(data.length),@"expectedSHA256":expected[@"sha256"],@"actualSHA256":SQHash(data),@"detectedFormat":SQImageExtension(data)?:@"unknown",@"captureSource":entry[@"captureSource"]?:@"ABI-checked dataWithContentsOfFile:"}];
        SQIssue(report,@"referenceMismatch",identity,@"当前读取器返回的数据与对照长度或SHA-256不同；实际长度、SHA与格式见manifest.json的referenceObserved。为保留诊断而拒绝把不符字节当作已验证素材");
        SQIssue(report,@"failed",identity,@"对照字节校验失败");return NO;
    }
    BOOL companion=entry[@"fileSource"]!=nil;
    NSString *kind=companion?key.pathExtension.lowercaseString:SQImageExtension(data),*base=key.lastPathComponent;
    BOOL warning=!companion&&(!kind||!SQMatchesExtension(key,kind));
    if(warning)SQIssue(report,@"unsupported",identity,@"格式未识别或与文件名后缀不符；原始字节已保留，未转换格式");
    if(!base.pathExtension.length)base=[base stringByAppendingPathExtension:kind?:@"bin"];
    NSString *target=base,*folded=SQFold(base);
    BOOL collision=destinations[folded]!=nil||[folded isEqual:@"_export-info"]||[folded isEqual:@"_duplicates"];
    if(collision){
        SQIssue(report,@"conflicts",identity,[NSString stringWithFormat:@"重名文件已分开保留：%@（另一个来源：%@）",base,destinations[folded]?:@"导出记录目录"]);
        target=[NSString stringWithFormat:@"_duplicates/%06lu/%@",(unsigned long)[report[@"conflicts"]unsignedIntegerValue],base];
    }
    NSUInteger total=[report[@"bytes"]unsignedIntegerValue];
    if(data.length>SQThemeTotalLimit-total){SQIssue(report,@"failed",identity,@"文件合计超过512MB，未写入该项目");return NO;}
    NSString *reason=nil;
    if(!SQWriteVerified(data,[folder URLByAppendingPathComponent:target],&reason)){SQIssue(report,@"failed",identity,reason);return NO;}
    if(!collision)destinations[folded]=identity;
    if(expected)report[@"referenceMatched"]=@([report[@"referenceMatched"]unsignedIntegerValue]+1);
    report[@"bytes"]=@(total+data.length);report[@"written"]=@([report[@"written"]unsignedIntegerValue]+1);
    [items addObject:@{@"identity":identity,@"provider":entry[@"provider"],@"key":key,@"name":base,@"file":target,@"bytes":@(data.length),@"sha256":SQHash(data),@"original":@YES,@"snapshot":@NO,@"detectedFormat":kind?:@"unknown",@"formatWarning":@(warning),@"collisionPreserved":@(collision),@"source":companion?@"exact current-theme file, original bytes without rewriting":(entry[@"captureSource"]?:@"exact provider and key; returned NSData without UIImage re-encoding")}];return YES;
}
static Class SQClassValue(id value){return value==NSNull.null?Nil:(Class)value;}
// Re-read the snapshot and compare it with `initial`. When `fresh` is given the
// new snapshot is handed back even on a mismatch, so a caller that changed the
// provider itself can adopt the result as its next baseline instead of aborting.
static BOOL SQSnapshotStill(NSDictionary *initial,NSDictionary **fresh,NSString **error){
    __block NSDictionary *current=nil;__block NSString *reason=nil;
    void (^capture)(void)=^{current=SQSnapshot(initial[@"managerClass"],initial[@"loaderClass"],SQClassValue(initial[@"assetsClass"]),SQClassValue(initial[@"utilClass"]),SQClassValue(initial[@"bubbleManagerClass"]),SQClassValue(initial[@"bubbleAssetsClass"]),SQClassValue(initial[@"bubbleConfigClass"]),&reason);};
    if(NSThread.isMainThread)capture();else dispatch_sync(dispatch_get_main_queue(),capture);
    if(fresh)*fresh=current;
    BOOL same=current&&current[@"loader"]==initial[@"loader"]&&current[@"bubbleLoader"]==initial[@"bubbleLoader"]&&[current[@"signature"]isEqual:initial[@"signature"]];
    if(!same&&error)*error=reason?:@"主题或资源清单在导出中变化，请保持主题不变后重试";return same;
}
static BOOL SQSameSnapshot(NSDictionary *initial,NSString **error){return SQSnapshotStill(initial,NULL,error);}
// Comparison used while writing: theme identity plus `stableSignature`, which
// covers only what this export cannot change by reading (companion file stats and
// the container). The full signature hashes the provider's caches, and the export
// fills them on purpose -- decrypting the pack by name writes decryptCache, and
// serving an asset through the ObjC path can do the same -- so comparing it here
// aborted the run on its own side effects. That is why a first tap produced a few
// hundred files and then refused to save them. A colour table that changes under
// the export still moves the stable signature, which is the case the 3.0.8 checks
// assert on.
static BOOL SQSameTheme(NSDictionary *initial,NSString **error){
    __block NSDictionary *current=nil;__block NSString *reason=nil;
    void (^capture)(void)=^{current=SQSnapshot(initial[@"managerClass"],initial[@"loaderClass"],SQClassValue(initial[@"assetsClass"]),SQClassValue(initial[@"utilClass"]),SQClassValue(initial[@"bubbleManagerClass"]),SQClassValue(initial[@"bubbleAssetsClass"]),SQClassValue(initial[@"bubbleConfigClass"]),&reason);};
    if(NSThread.isMainThread)capture();else dispatch_sync(dispatch_get_main_queue(),capture);
    BOOL same=current&&current[@"loader"]==initial[@"loader"]&&current[@"bubbleLoader"]==initial[@"bubbleLoader"]
        &&[current[@"themeID"]isEqual:initial[@"themeID"]]&&[current[@"root"]isEqual:initial[@"root"]]
        &&[current[@"stableSignature"]isEqual:initial[@"stableSignature"]];
    if(!same&&error){
        NSDictionary *before=initial[@"stateHashes"],*after=current[@"stateHashes"];
        NSMutableArray *moved=[NSMutableArray new];
        if([before isKindOfClass:NSDictionary.class]&&[after isKindOfClass:NSDictionary.class]){
            for(NSString *key in after)if(![before[key]isEqual:after[key]])[moved addObject:key];
            for(NSString *key in before)if(!after[key])[moved addObject:key];
        }
        NSString *what=moved.count?[moved componentsJoinedByString:@","]:@"读取器";
        *error=reason?:[NSString stringWithFormat:@"导出中主题发生变化（%@），请保持主题不变后重试",what];
    }
    return same;
}
static NSData *SQFetch(NSDictionary *entry,NSString **error){
    if([entry[@"captureConflict"]boolValue]){if(error)*error=@"运行时解密缓存存在同名异字节冲突，未选取任意版本";return nil;}
    NSData *captured=entry[@"capturedData"];
    if([captured isKindOfClass:NSData.class]&&captured.length)return [captured copy];
    // Filesystem companion reads run on the export queue, not UIKit's thread.
    if(entry[@"fileSource"])return SQReadCompanion(entry[@"fileSource"],error);
    // Native (Rust) decryptor first: it is the provider's own byte path for the
    // encrypted 3.0.8 pack and needs no UIKit thread. Fall through to the ObjC
    // dataWithContentsOfFile: oracle only when native is unavailable/fails.
    if([entry[@"nativeName"]isKindOfClass:NSString.class]){
        NSString *nativeError=nil;
        NSData *native=SaoqiangWCAssetsNativeRead(@{},entry[@"nativeName"],&nativeError);
        if(native.length)return native;
        // Never treat a native miss as fatal: the ObjC oracle below may still
        // serve the bytes (and its error text is more specific to the caller).
    }
    __block NSData *data=nil;__block NSString *reason=nil;
    dispatch_sync(dispatch_get_main_queue(),^{
        if(SQCancelled()){reason=@"已取消";return;}
        SaoqiangWCAssetsPushSuppression();
        // Try every byte-exact reader the provider exposes. A name enumerated
        // from the icon map may be servable by only one of them:
        //   ThemeBoxImageLoader.dataForFileName:   -> decrypts from themeData (the pack)
        //   ...dataWithContentsOfFile:             -> loose file in the theme dir
        //   ...svgImageDataWithFileName:           -> original SVG bytes
        //   ThemeBoxCache.getThemeFile:/getData:    -> already decrypted cache
        // imageDataWithNamed: is deliberately absent: it returns a decoded
        // UIImage, not the original bytes.
        NSArray *readers=@[entry[@"receiver"]?:NSNull.null,
                           SQGet((id)NSClassFromString(@"ThemeBoxAssets"),@"shared")?:NSNull.null,
                           SQGet((id)NSClassFromString(@"ThemeBoxCache"),@"shared")?:NSNull.null];
        NSArray *selectors=@[@"dataWithContentsOfFile:",@"dataForFileName:",@"svgImageDataWithFileName:",
                             @"getThemeFile:",@"getData:",@"getFile:"];
        for(id reader in readers){
            if(reader==NSNull.null||data)continue;
            for(NSString *selector in selectors){
                @try {id value=SQCall(reader,selector,entry[@"key"]);
                    if(![value isKindOfClass:NSData.class]||![value length])continue;
                    if([value length]>SQThemeFileLimit){reason=@"加载器返回文件超过32MB";break;}
                    data=[value copy];reason=nil;break;
                }@catch(NSException *e){reason=[@"读取原数据异常：" stringByAppendingString:e.name];}
            }
        }
        if(!data&&!reason)reason=@"加载器未返回原始NSData";
        SaoqiangWCAssetsPopSuppression();
    });if(error)*error=reason;return data;
}
static BOOL SQWriteManifest(NSURL *folder,NSMutableDictionary *report,NSArray *items,NSString **error){
    NSURL *info=[folder URLByAppendingPathComponent:@"_export-info" isDirectory:YES];NSError *e=nil;
    if(![NSFileManager.defaultManager createDirectoryAtURL:info withIntermediateDirectories:YES attributes:nil error:&e]){if(error)*error=e.localizedDescription;return NO;}
    NSMutableDictionary *manifest=[report mutableCopy];manifest[@"items"]=[items copy];manifest[@"formatVersion"]=@3;
    NSData *json=[NSJSONSerialization dataWithJSONObject:manifest options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:&e];
    if(!json||!SQWriteVerified(json,[info URLByAppendingPathComponent:@"manifest.json"],error))return NO;
    NSMutableString *text=[NSMutableString stringWithFormat:@"清单 %@ · 已导出 %@ · 未取得 %@ · 失败 %@ · 重名保留 %@ · 格式提示 %@\n\n",report[@"expected"],report[@"written"],report[@"missing"],report[@"failed"],report[@"conflicts"],report[@"unsupported"]];
    // The one number that says whether the export is close to complete. Bytes are
    // the honest measure here: file counts can be inflated by another theme's
    // entries, but a 10.4 MB pack cannot hold 40 MB of them.
    if(report[@"packCoverage"])[text appendFormat:@"封包覆盖率：%@\n（探测项只计字节、不写文件：这些名字由加载器确认、但不在本主题自己的表里，很可能是其他已装主题的资源。两项合计若远超 100%%，就是混入了别的主题；若接近 100%%，说明封包里还有本主题未被列出的资源）\n\n",report[@"packCoverage"]];
    if(report[@"packNamesNote"])[text appendFormat:@"%@\n（解密封包只会取到当前主题自己容器里的东西，别的主题的名字在这里读不出字节，所以这条渠道不会混包）\n\n",report[@"packNamesNote"]];
    if(report[@"packIndexBytes"])[text appendFormat:@"封包索引：%@ 字节，已存 _export-info/pack-index.bin —— 这是封包自己的文件表，按它可以一次列全\n\n",report[@"packIndexBytes"]];
    else if(report[@"packBytes"])[text appendString:@"封包索引：没有按常见清单名读回可用的表，清单外资源仍只能靠猜名字\n\n"];
    for(NSDictionary *issue in report[@"issues"]) [text appendFormat:@"[%@] %@\n%@\n\n",issue[@"category"]?:@"提示",issue[@"key"]?:@"",issue[@"reason"]?:@""];
    // Discovery notes are informational, not warnings: they never count against
    // completeness. Still the first thing to read when the count looks wrong.
    NSArray *discovery=report[@"discovery"];
    if([discovery isKindOfClass:NSArray.class]&&discovery.count){
        [text appendString:@"—— 清单探测（仅记录，不计入告警）——\n"];
        for(id line in discovery) [text appendFormat:@"%@\n",line];
        [text appendString:@"\n"];
    }
    [text appendString:@"原始字节直接保存。大小写及Unicode重名文件独立存放，不互相覆盖。\n不按微信和主题盒子版本号设限；接口或资源格式变化仍需适配。\n"];
    return SQWriteVerified([text dataUsingEncoding:NSUTF8StringEncoding],[info URLByAppendingPathComponent:@"issues.txt"],error);
}
// The pack's index is encrypted and the provider's ObjC tables only list the few
// names the app has already asked for, which is why a 2,500-file theme exported
// as 112. The file names themselves are not secret: every theme overrides the
// same WeChat assets, so a name list harvested from two shipped packs (see
// SaoqiangWCAssetsPackNames.m) works as a key ring.
//
// Each candidate goes to the Rust decryptor, and that is the whole safety
// argument: it reads only the applied theme's container. A name belonging to
// another installed pack returns nothing at all, so this channel cannot repeat
// the 0.11.7 mistake of mixing packs, no matter how long the list is.
static NSArray *SQPackChannel(NSArray *entries,NSDictionary *snapshot,NSMutableDictionary *report){
    unsigned long long packBytes=[snapshot[@"packBytes"]unsignedLongLongValue];
    if(!packBytes||!SaoqiangWCAssetsNativeAvailable()){
        report[@"packNamesNote"]=@"按名字扫描封包：跳过（没有封包体积，或原生解密接口不可用）";
        return @[];
    }
    NSMutableSet *known=[NSMutableSet new];
    for(NSDictionary *entry in entries){
        NSString *key=entry[@"key"];
        if([key isKindOfClass:NSString.class]&&key.lastPathComponent.length)[known addObject:SQFold(key.lastPathComponent)];
    }
    // Warm the container before timing anything. On a cold start the provider
    // initialises its pack on the first read, and that single call costs far more
    // than the ones after it; paying it here is what makes the first tap behave
    // like the second one, where everything was already loaded.
    NSTimeInterval warmMs=0;
    {
        NSDate *warmStart=NSDate.date;
        for(NSDictionary *entry in entries){
            NSString *key=entry[@"key"];
            if(![key isKindOfClass:NSString.class]||!key.lastPathComponent.length)continue;
            if([SaoqiangWCAssetsNativeRead(@{},key.lastPathComponent,nil) length])break;
        }
        warmMs=-[warmStart timeIntervalSinceNow]*1000.0;
    }
    NSArray *candidates=SaoqiangWCAssetsPackNameCandidates();
    // 10% of slack: the container carries its own header and table, so the payload
    // total sits a little under the file size. This is a stop condition, not a
    // safety check -- the decryptor only ever reads the applied theme's container,
    // so a longer list cannot pull another pack in.
    unsigned long long budget=(unsigned long long)((double)packBytes*1.10);
    NSMutableArray *out=[NSMutableArray new],*passes=[NSMutableArray new];
    unsigned long long bytes=0;NSUInteger tried=0,hits=0,passCount=0;BOOL truncated=NO;
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:240.0];
    // Up to three passes. A pass that finds nothing new means the pack is fully
    // drained; a pass that finds more means the provider was still settling, and
    // repeating it here is exactly what the second tap used to do by hand.
    for(NSUInteger pass=1;pass<=3;++pass){
        NSUInteger passHits=0;unsigned long long passBytes=0;
        ++passCount;
        for(NSString *name in candidates){
            if(SQCancelled()){truncated=YES;break;}
            if(bytes>=budget||[deadline timeIntervalSinceNow]<0){truncated=YES;break;}
            NSString *folded=SQFold(name);
            if([known containsObject:folded])continue;
            ++tried;
            NSData *data=SaoqiangWCAssetsNativeRead(@{},name,nil);
            if(![data isKindOfClass:NSData.class]||!data.length)continue;
            [known addObject:folded];
            // Bytes travel with the entry: the verify pass rereads through SQFetch,
            // and a second decrypt of 1,400 files would double the wait for nothing.
            [out addObject:@{@"provider":@"ThemeBoxPack",@"key":name,
                             @"identity":[@"ThemeBoxPack|" stringByAppendingString:name],
                             @"capturedData":data}];
            bytes+=[data length];++hits;++passHits;passBytes+=[data length];
            if((hits%256)==0)SQProgress(@{@"stage":[NSString stringWithFormat:@"按名字扫描封包：第 %lu 轮，命中 %lu 项、%llu 字节",(unsigned long)pass,(unsigned long)hits,bytes]});
        }
        [passes addObject:[NSString stringWithFormat:@"第%lu轮 %lu 项/%llu 字节",(unsigned long)pass,(unsigned long)passHits,passBytes]];
        if(truncated||bytes>=budget)break;
        // An empty pass is retried once: a cold provider can answer nothing on the
        // first sweep and everything on the second, and that is the whole reason a
        // second tap used to find more than the first.
        if(passHits==0){if(pass>=2)break;[NSThread sleepForTimeInterval:0.8];}
    }
    report[@"packNamesTried"]=@(tried);report[@"packNamesHits"]=@(hits);
    report[@"packNamesBytes"]=@(bytes);report[@"packNamesTruncated"]=truncated?@YES:@NO;
    report[@"packNamesPasses"]=@(passCount);
    report[@"packNamesNote"]=[NSString stringWithFormat:
        @"按名字扫描封包：候选 %lu 个，询问 %lu 次、%lu 轮（%@），命中 %lu 项共 %llu 字节 / 封包 %llu 字节（%.1f%%），预热 %.0f ms%@",
        (unsigned long)candidates.count,(unsigned long)tried,(unsigned long)passCount,
        [passes componentsJoinedByString:@"，"],(unsigned long)hits,bytes,packBytes,
        100.0*(double)bytes/(double)packBytes,warmMs,truncated?@"，已到上限停止":@""];
    return out;
}
static void SQRunLoader(NSDictionary *snapshot,SaoqiangWCAssetsThemePackCompletion completion){
    dispatch_async(SaoqiangWCAssetsPackQueue(),^{@autoreleasepool{
        NSMutableDictionary *report=SQReport(snapshot);NSURL *work=nil,*folder=nil;NSString *failure=nil;
        NSMutableArray *items=[NSMutableArray new];NSMutableDictionary *destinations=[NSMutableDictionary new],*byIdentity=[NSMutableDictionary new];
        @try {
            for(NSDictionary *issue in snapshot[@"issues"]?:@[])SQIssue(report,@"warnings",issue[@"source"],issue[@"reason"]);
            if(!SQCancelled())SQSameSnapshot(snapshot,&failure);
            if(!failure&&!SQCancelled())folder=SQCreateWork(snapshot,&work,&failure);
            NSArray *entries=snapshot[@"entries"];
            // Names recovered by decrypting the pack under a candidate name.
            // Merged before the tally so manifest.json counts this source like
            // any other, and before `expected` is reported.
            NSArray *packEntries=(folder&&!failure&&!SQCancelled())?SQPackChannel(entries,snapshot,report):@[];
            if(packEntries.count){
                NSMutableArray *merged=[entries mutableCopy];
                [merged addObjectsFromArray:packEntries];
                entries=[merged copy];
                report[@"expected"]=@(entries.count);report[@"total"]=@(entries.count);report[@"discovered"]=@(entries.count);
            }
            // Per-source composition, in the report and not only in the log: a
            // category that suddenly dominates this table is how "several packs
            // exported at once" looks from the outside, and it should be readable
            // from manifest.json without parsing prose.
            NSMutableDictionary *tally=[NSMutableDictionary new];
            for(NSDictionary *entry in entries){NSString *provider=entry[@"provider"]?:@"unknown";tally[provider]=@([tally[provider]unsignedIntegerValue]+1);}
            report[@"sourceTally"]=tally;
            SQProgress(@{@"themeName":report[@"themeName"],@"expected":@(entries.count),@"total":@(entries.count),@"stage":@"逐项导出原文件"});
            if(folder&&!failure)for(NSDictionary *entry in entries){@autoreleasepool{
                if(SQCancelled())break;
                byIdentity[entry[@"identity"]]=entry;
                NSString *readError=nil;NSData *raw=SQFetch(entry,&readError);
                if(!raw){
                    // A name harvested from an ivar is only a guess. If the real
                    // provider cannot serve bytes for it, drop it quietly instead
                    // of reporting a spurious missing/error to the user.
                    if([entry[@"ivarCandidate"]boolValue])report[@"skipped"]=@([report[@"skipped"]unsignedIntegerValue]+1);
                    else SQIssue(report,@"missing",entry[@"identity"],readError);
                    if(entry[@"referenceExpected"])SQIssue(report,@"referenceMissing",entry[@"identity"],readError);
                }
                else SQStoreItem(raw,entry,folder,report,destinations,items);
                report[@"processed"]=@([report[@"processed"]unsignedIntegerValue]+1);SQProgress(report);
                if(([report[@"processed"]unsignedIntegerValue]%64)==0&&!SQSameTheme(snapshot,&failure))break;
            }}
            if(folder&&!failure&&!SQCancelled()){
                if(SQSameTheme(snapshot,&failure)){
                    SQProgress(@{@"stage":@"核对已导出的源数据"});
                    for(NSDictionary *item in items){@autoreleasepool{
                        if(SQCancelled())break;
                        NSString *reason=nil;NSData *again=SQFetch(byIdentity[item[@"identity"]],&reason);
                        NSData *saved=SQReadFile([[folder URLByAppendingPathComponent:item[@"file"]]path],&reason);
                        // One read only: a retry here would let a source that changes
                        // mid-export pass on the second look, which is the case these
                        // checks exist to catch.
                        if(!again||!saved||again.length!=[item[@"bytes"]unsignedIntegerValue]||![SQHash(again)isEqual:item[@"sha256"]]||![saved isEqualToData:again]){
                            failure=reason?:@"原资源在导出中变化，请保持当前主题后重试";SQIssue(report,@"failed",item[@"identity"],failure);break;
                        }
                        report[@"itemsVerified"]=@([report[@"itemsVerified"]unsignedIntegerValue]+1);
                    }}
                    if(!failure&&!SQCancelled())SQSameTheme(snapshot,&failure);
                }
            }
            BOOL available=folder&&!failure&&!SQCancelled()&&items.count>0&&[report[@"itemsVerified"]unsignedIntegerValue]==items.count;
            BOOL complete=available&&[snapshot[@"expectedKnown"]boolValue]&&items.count==entries.count&&![report[@"failed"]unsignedIntegerValue]&&![report[@"missing"]unsignedIntegerValue]&&![report[@"warnings"]unsignedIntegerValue];
            // Probe accounting, and deliberately nothing else. The names in
            // `probe` are the ones the provider confirmed but this theme's own
            // tables never mention -- exactly what a loader-scoped existence check
            // invents when other packs are installed. Writing them into the folder
            // would reproduce the mixing the user reported, so they are read and
            // summed but never saved: bytes answer the same question as files.
            // 10.4MB of pack cannot contain 40MB of assets, however confidently
            // fileExistsWithName: answered.
            unsigned long long packBytes=[snapshot[@"packBytes"]unsignedLongLongValue];
            unsigned long long mainBytes=[report[@"bytes"]unsignedLongLongValue];
            NSArray *probeNames=snapshot[@"probeNames"];
            NSUInteger probeCount=[probeNames isKindOfClass:NSArray.class]?probeNames.count:0;
            NSUInteger probeRead=0,probeHits=0;unsigned long long probeBytes=0;BOOL probeTruncated=NO;
            if(probeCount&&!SQCancelled()&&SaoqiangWCAssetsNativeAvailable()){
                // The pack itself is the ceiling: once the probes have already
                // totalled what the whole pack weighs, they cannot all belong to
                // this theme and further reads only cost time.
                unsigned long long limit=packBytes?packBytes:(12ULL<<20);
                NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:20.0];
                for(id name in probeNames){
                    if(SQCancelled())break;
                    if(probeRead>=6000||probeBytes>=limit||[deadline timeIntervalSinceNow]<0){probeTruncated=YES;break;}
                    if(![name isKindOfClass:NSString.class]||![name length])continue;
                    ++probeRead;
                    NSData *data=SaoqiangWCAssetsNativeRead(@{},name,nil);
                    if(![data isKindOfClass:NSData.class]||!data.length)continue;
                    ++probeHits;probeBytes+=[data length];
                }
            }
            report[@"probeCount"]=@(probeCount);report[@"probeRead"]=@(probeRead);report[@"probeHits"]=@(probeHits);
            report[@"probeBytes"]=@(probeBytes);report[@"probeTruncated"]=probeTruncated?@YES:@NO;report[@"packBytes"]=@(packBytes);
            if(packBytes)report[@"packCoverage"]=[NSString stringWithFormat:@"主清单 %llu 字节 = 封包的 %.1f%%；探测命中 %@/%@ 项共 %llu 字节%@，两项合计 %llu 字节 = %.1f%%",
                mainBytes,100.0*(double)mainBytes/(double)packBytes,@(probeHits),@(probeCount),probeBytes,probeTruncated?@"（已到上限停止）":@"",
                mainBytes+probeBytes,100.0*(double)(mainBytes+probeBytes)/(double)packBytes];
            report[@"available"]=available?@YES:@NO;report[@"complete"]=complete?@YES:@NO;
            NSUInteger decodedCount=[snapshot[@"decodedCount"]unsignedIntegerValue];
            NSUInteger referenceCount=[report[@"referenceCount"]unsignedIntegerValue];
            report[@"referenceComplete"]=available&&referenceCount&&[report[@"referenceMatched"]unsignedIntegerValue]==referenceCount&&![report[@"referenceMismatch"]unsignedIntegerValue]&&![report[@"referenceMissing"]unsignedIntegerValue]?@YES:@NO;
            if(referenceCount)report[@"diagnostic"]=[NSString stringWithFormat:@"对照清单 %@ 项：原字节一致 %@ 项、未读到 %@ 项、字节不符 %@ 项。仅对导入清单验收；封包是否还有清单外资源仍未知。",@(referenceCount),report[@"referenceMatched"],report[@"referenceMissing"],report[@"referenceMismatch"]];
            else if([snapshot[@"opaqueContainer"]boolValue]) report[@"diagnostic"]=[NSString stringWithFormat:@"已保存目录清单、当前运行时已解密 %@ 项及 themebox.dat 原件；封包完整键名尚未公开，内部图标不能声明全部展开",@(decodedCount)];
            else if(decodedCount) report[@"diagnostic"]=[NSString stringWithFormat:@"已保存当前目录清单及运行时已解密 %@ 项；未证明覆盖封包全部资源",@(decodedCount)];
            else report[@"diagnostic"]=complete?@"本次加载器资源清单已全部导出；GIF、重名文件均原样保留":@"可保存已导出的原文件；未取得的资源与原因见_export-info";
            if(available){
                // Diagnostic only, and declared in the report so the test that
                // counts files in the export folder knows to expect it: a write
                // failure here must never invalidate an otherwise complete
                // export, hence no error propagation into `failure`.
                NSData *head=snapshot[@"containerHead"];
                if([head isKindOfClass:NSData.class]&&head.length)report[@"containerHeadBytes"]=@([head length]);
                // Same rule for the pack's own table: declared when captured, so
                // the file-count check can require it exactly when it exists.
                NSData *packIndex=snapshot[@"packIndex"];
                if([packIndex isKindOfClass:NSData.class]&&packIndex.length)report[@"packIndexBytes"]=@([packIndex length]);
                if(!SQWriteManifest(folder,report,items,&failure))report[@"available"]=@NO;
                NSURL *infoFolder=[folder URLByAppendingPathComponent:@"_export-info" isDirectory:YES];
                if([head isKindOfClass:NSData.class]&&head.length)
                    SQWriteVerified(head,[infoFolder URLByAppendingPathComponent:@"container-head.bin"],NULL);
                if([packIndex isKindOfClass:NSData.class]&&packIndex.length)
                    SQWriteVerified(packIndex,[infoFolder URLByAppendingPathComponent:@"pack-index.bin"],NULL);
            }
            else if(!failure&&!SQCancelled())failure=@"没有取得可保存的原文件，详细原因见诊断";
        }@catch(NSException *e){failure=[@"导出异常：" stringByAppendingString:e.name];SQIssue(report,@"failed",nil,failure);}
        if(failure.length)report[@"diagnostic"]=failure;
        SQFinish(!failure&&[report[@"available"]boolValue]?folder:nil,work,report,failure,completion);
    }});
}
static void SQStartLoader(Class manager,Class loader,Class assets,Class util,Class bubbleManager,Class bubbleAssets,Class bubbleConfig,SaoqiangWCAssetsThemePackCompletion completion){
    if(!SQBegin(completion))return;
    dispatch_async(dispatch_get_main_queue(),^{
        if(SQCancelled()){SQFinish(nil,nil,@{},@"已取消",completion);return;}
        NSString *error=nil;NSDictionary *snapshot=SQSnapshot(manager,loader,assets,util,bubbleManager,bubbleAssets,bubbleConfig,&error);
        if(!snapshot){SQFinish(nil,nil,@{},error?:@"无法取得当前主题资源清单",completion);return;}
        SQRunLoader(snapshot,completion);
    });
}
void SaoqiangWCAssetsExportCurrentTheme(SaoqiangWCAssetsThemePackCompletion completion){
    SQStartLoader(NSClassFromString(@"ThemeBoxMgr"),NSClassFromString(@"ThemeBoxImageLoader"),NSClassFromString(@"ThemeBoxAssets"),NSClassFromString(@"ThemeBoxUtil"),NSClassFromString(@"BubbleBoxMgr"),NSClassFromString(@"BubbleBoxAssets"),NSClassFromString(@"BubbleBoxConfig"),completion);
}
NSDictionary *SaoqiangWCAssetsCurrentThemeReferenceState(void){
    NSCAssert(NSThread.isMainThread,@"reference UI on main thread");NSString *e=nil;NSDictionary *identity=SQManager(NSClassFromString(@"ThemeBoxMgr"),&e);
    if(!identity)return @{@"error":e?:@"当前主题不可用"};NSDictionary *r=SaoqiangWCAssetsReferenceSnapshot(identity[@"themeID"]);
    return @{@"themeID":identity[@"themeID"],@"themeName":identity[@"themeName"],@"count":r[@"count"]?:@0,@"sha256":r[@"sha256"]?:@""};
}
BOOL SaoqiangWCAssetsImportCurrentThemeReference(NSData *data,NSString *expectedThemeID,NSString **error){
    NSCAssert(NSThread.isMainThread,@"reference import on main thread");if([SaoqiangWCAssetsThemePackState()[@"busy"]boolValue]){if(error)*error=@"请先等待导出结束或取消导出";return NO;}
    NSDictionary *identity=SQManager(NSClassFromString(@"ThemeBoxMgr"),error);if(!identity)return NO;
    if(![identity[@"themeID"]isEqual:expectedThemeID]){if(error)*error=@"选择文件期间主题发生变化，请重试";return NO;}
    return SaoqiangWCAssetsReferenceImport(data,expectedThemeID,error);
}
BOOL SaoqiangWCAssetsClearCurrentThemeReference(NSString **error){
    if([SaoqiangWCAssetsThemePackState()[@"busy"]boolValue]){if(error)*error=@"请先结束导出";return NO;}
    NSDictionary *identity=SQManager(NSClassFromString(@"ThemeBoxMgr"),error);return identity&&SaoqiangWCAssetsReferenceClear(identity[@"themeID"],error);
}
#if defined(SAOQIANG_WCASSETS_TESTING)
void SaoqiangWCAssetsExportThemeLoaderFixture(Class manager,Class loader,Class util,SaoqiangWCAssetsThemePackCompletion completion){SQStartLoader(manager,loader,Nil,util,Nil,Nil,Nil,completion);}
void SaoqiangWCAssetsExportThemeSourcesFixture(Class manager,Class loader,Class util,Class bubbleManager,Class bubbleAssets,Class bubbleConfig,SaoqiangWCAssetsThemePackCompletion completion){SQStartLoader(manager,loader,Nil,util,bubbleManager,bubbleAssets,bubbleConfig,completion);}
void SaoqiangWCAssetsExportThemeEngineFixture(Class manager,Class loader,Class assets,Class util,SaoqiangWCAssetsThemePackCompletion completion){SQStartLoader(manager,loader,assets,util,Nil,Nil,Nil,completion);}
NSDictionary *SaoqiangWCAssetsThemeProviderFixture(Class manager,Class util,BOOL includeList,NSString **error){
    (void)util;(void)includeList;if(error)*error=nil;SaoqiangWCAssetsPushSuppression();
    @try{NSDictionary *identity=SQManager(manager,error);if(!identity)return nil;NSMutableDictionary *r=[identity mutableCopy];[r removeObjectForKey:@"manager"];r[@"capabilities"]=@{@"versionLocked":@NO};return r;}
    @catch(NSException *e){if(error)*error=[@"主题身份接口异常：" stringByAppendingString:e.name];return nil;}
    @finally{SaoqiangWCAssetsPopSuppression();}
}
#endif
