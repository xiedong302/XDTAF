//
//  XDTAFHTTP.h
//  XDTAF
//
//  Created by xiedong on 2021/2/2.
//

#import <Foundation/Foundation.h>

#import "XDTAFHTTPRequest.h"
#import "XDTAFHTTPResponse.h"

NS_ASSUME_NONNULL_BEGIN

// MARK: - XDTAFHTTPClientUrlRewriter
@protocol XDTAFHTTPClientUrlRewriter <NSObject>

@optional
- (NSString *)httpClientHandleURL:(NSString *)URLString;

@end

// MARK: - XDTAFHTTPClient
typedef NS_ENUM(NSUInteger, XDTAFHTTPClientSSLChallengeMode) {
    XDTAFHTTPClientSSLChallengeModeNone, // 忽略
    XDTAFHTTPClientSSLChallengeModeSimple, // 不校验host
    XDTAFHTTPClientSSLChallengeModeFull // 正常校验
};

typedef void(^XDTAFHTTPHandler)(XDTAFHTTPResponse *response);

@interface XDTAFHTTPClient : NSObject

@property (nonatomic, assign) BOOL enableRedirect; // 默认YES
@property (nonatomic, assign) XDTAFHTTPClientSSLChallengeMode sslChallengeMode; // 默认XDTAFHTTPClientSSLChallengeModeFull

/**
 @abstract
 返回默认的HTTPClient，handler queue 为 main queue， 禁止缓存， 允许重定向，XDTAFHTTPClientSSLChallengeModeNone
 */
+ (instancetype)defaultHTTPClient;

/**
 @abstract
 设置全局的XDTAFHTTPClientUrlRewriter
 */
+ (void)setURLRewriter:(id<XDTAFHTTPClientUrlRewriter>)URLRewriter;

/**
 @abstract
 使用传入的queue 创建一个HTTPClient
 
 @param queue
 hander queue
 
 @param enableCache
 是否允许缓存
 */
- (instancetype)initWithHandlerQueue:(dispatch_queue_t)queue enableCache:(BOOL)enableCache;

/**
 @abstract
 发送数据请求, 这里有一个要特别注意的限制, 同一个request, 不要sendRequest多次
 这是因为HTTPClient内部目前没有对request做深度copy, 对象就会复用, 部分类型的请求可能会傻逼
 */
- (void)sendRequest:(XDTAFHTTPRequest *)request handler:(XDTAFHTTPHandler)handler;

/**
 @abstract
 HTTPClient不再使用的时候，需要调用一下invalidate，不然可能会蟹柳， NSURLSession的bug
 一般在dealloc里面调用一下就行了，UI组件里面切记要调用
 
 @param cancelPendingTasks
 是否取消还没执行的请求
 */
- (void)invalidate:(BOOL)cancelPendingTasks;

@end

// MARK: XDTAFHTTPDownloader
@class XDTAFHTTPDownloader;
@protocol XDTAFHTTPDownloaderDelegate <NSObject>

@optional

- (void)httpDownloader:(XDTAFHTTPDownloader *)downloader didUpdateProgress:(int)progress;

- (void)httpDownloader:(XDTAFHTTPDownloader *)downloader didFinishWithError:(NSError *)error;

@end

@interface XDTAFHTTPDownloader : NSObject

@property (nonatomic, weak) id<XDTAFHTTPDownloaderDelegate> delegate; // 主线程调用
@property (nonatomic, readonly, copy) NSString *downloadURL; // 下载地址
@property (nonatomic, readonly, copy) NSString *savePath; // 保存路径
@property (nonatomic, readonly, assign) int progress; // 0 ~ 100

@property (nonatomic, copy) NSString *md5; // 下载后校验MD5
@property (nonatomic, copy) NSString *unzipPath; // 下载后解压路径

/**
 @abstract 创建一个XDTAFHTTPDownloader
 
 @param downloadURL 下载地址
 @param savePath 保存路径
 */
- (instancetype)initWithURL:(NSString *)downloadURL toPath:(NSString *)savePath;

- (void)start;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
