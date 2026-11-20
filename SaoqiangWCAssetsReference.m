#import "SaoqiangWCAssetsReference.h"
#import <CommonCrypto/CommonDigest.h>
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>
static NSObject *SQRefLock(void){static NSObject *x;static dispatch_once_t once;dispatch_once(&once,^{x=[NSObject new];});return x;}
static NSMutableDictionary *SQRefCache(void){static NSMutableDictionary *d;static dispatch_once_t once;dispatch_once(&once,^{d=[NSMutableDictionary new];});return d;}
static NSString *SQRefHash(NSData *d){unsigned char b[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,b);NSMutableString *s=[NSMutableString new];for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[s appendFormat:@"%02x",b[i]];return s;}
static NSURL *SQRefURL(NSString *themeID){NSURL *base=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;return [[base URLByAppendingPathComponent:@"SaoqiangWCAssetsReferences" isDirectory:YES]URLByAppendingPathComponent:[SQRefHash([themeID dataUsingEncoding:NSUTF8StringEncoding])stringByAppendingPathExtension:@"json"]];}
static BOOL SQRefFail(NSString **e,NSString *s){if(e)*e=s;return NO;}
static BOOL SQRefID(id value){return [value isKindOfClass:NSString.class]&&[value length]>0&&[value length]<=512;}
static NSDictionary *SQRefParse(NSData *data,NSString *themeID,NSString **error){
 if(!SQRefID(themeID)||!data.length||data.length>8*1024*1024){SQRefFail(error,@"对照清单为空、超过8MB或当前主题ID不可用");return nil;}
 id obj=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
 if(![obj isKindOfClass:NSDictionary.class]||![obj[@"themeID"]isEqual:themeID]){SQRefFail(error,@"对照清单的themeID与当前主题不一致");return nil;}
 id source=obj[@"items"];if(![source isKindOfClass:NSArray.class]||![source count]||[source count]>19999){SQRefFail(error,@"清单需含1至19999个带key、bytes和sha256的条目");return nil;}
 NSMutableDictionary *byKey=[NSMutableDictionary new];NSMutableArray *ordered=[NSMutableArray new];unsigned long long total=0;
 NSCharacterSet *bad=[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"]invertedSet];
 for(id item in source){
  if(![item isKindOfClass:NSDictionary.class]){SQRefFail(error,@"清单条目不是字典");return nil;}
  id key=item[@"key"],hash=item[@"sha256"],size=item[@"bytes"];
  if(![key isKindOfClass:NSString.class]||![key length]||[key length]>1024||[key hasPrefix:@"/"]||[key containsString:@"\\"]||[key containsString:@":"]||[key rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound){SQRefFail(error,@"清单包含无效原始查询键");return nil;}
  for(NSString *part in [key componentsSeparatedByString:@"/"])if(!part.length||[part isEqual:@"."]||[part isEqual:@".."]) {SQRefFail(error,@"清单包含不安全路径");return nil;}
  NSString *base=[key lastPathComponent];
  if([base.lowercaseString isEqual:@"themebox.dat"]||[base.lowercaseString isEqual:@"weui_color_new.xml"]||[base.lowercaseString isEqual:@"color.css"]||[base.lowercaseString hasSuffix:@".receipt"]||[key hasPrefix:@"_export-info/"]||[key hasPrefix:@"_duplicates/"]){SQRefFail(error,@"素材清单不能包含封包、配色、回执或重名输出路径");return nil;}
  if(![hash isKindOfClass:NSString.class]||[hash length]!=64||[hash rangeOfCharacterFromSet:bad].location!=NSNotFound||![size isKindOfClass:NSNumber.class]||CFGetTypeID((__bridge CFTypeRef)size)==CFBooleanGetTypeID()) {SQRefFail(error,@"条目缺少有效长度或SHA-256");return nil;}
  double n=[size doubleValue];if(!isfinite(n)||n<1||n>32*1024*1024||floor(n)!=n){SQRefFail(error,@"条目长度超限");return nil;}
  if(byKey[key]){SQRefFail(error,@"清单包含重复查询键，无法确定字节基准");return nil;}
  total+=(unsigned long long)n;if(total>512ULL*1024*1024){SQRefFail(error,@"清单原始字节合计超过512MB");return nil;}
  NSDictionary *entry=@{@"key":key,@"bytes":@((unsigned long long)n),@"sha256":[hash lowercaseString]};byKey[key]=entry;[ordered addObject:entry];
 }
 [ordered sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"key"]compare:b[@"key"]options:NSLiteralSearch];}];
 NSDictionary *normalized=@{@"schema":@1,@"themeID":themeID,@"items":ordered};NSData *canonical=[NSJSONSerialization dataWithJSONObject:normalized options:NSJSONWritingSortedKeys error:nil];
 return @{@"themeID":themeID,@"items":ordered,@"byKey":byKey,@"count":@(ordered.count),@"sha256":SQRefHash(canonical),@"canonical":canonical};
}
BOOL SaoqiangWCAssetsReferenceImport(NSData *data,NSString *themeID,NSString **error){@synchronized(SQRefLock()){
 NSDictionary *r=SQRefParse(data,themeID,error);if(!r)return NO;NSURL *url=SQRefURL(themeID);NSError *e=nil;
 if(![NSFileManager.defaultManager createDirectoryAtURL:url.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&e]||![r[@"canonical"]writeToURL:url options:NSDataWritingAtomic error:&e])return SQRefFail(error,e.localizedDescription?:@"清单保存失败");
 SQRefCache()[themeID]=r;return YES;
}}
NSDictionary *SaoqiangWCAssetsReferenceSnapshot(NSString *themeID){@synchronized(SQRefLock()){
 if(!SQRefID(themeID))return nil;NSDictionary *r=SQRefCache()[themeID];if(r)return r;
 NSURL *url=SQRefURL(themeID);NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:nil];if([attrs[NSFileSize]unsignedLongLongValue]>8*1024*1024)return nil;
 NSData *d=[NSData dataWithContentsOfURL:url];if(!d)return nil;r=SQRefParse(d,themeID,nil);if(r)SQRefCache()[themeID]=r;return r;
}}
BOOL SaoqiangWCAssetsReferenceClear(NSString *themeID,NSString **error){@synchronized(SQRefLock()){
 if(!SQRefID(themeID))return SQRefFail(error,@"当前主题ID不可用");NSURL *url=SQRefURL(themeID);NSError *e=nil;
 if([NSFileManager.defaultManager fileExistsAtPath:url.path]&&![NSFileManager.defaultManager removeItemAtURL:url error:&e])return SQRefFail(error,e.localizedDescription?:@"无法移除清单");[SQRefCache()removeObjectForKey:themeID];return YES;
}}
