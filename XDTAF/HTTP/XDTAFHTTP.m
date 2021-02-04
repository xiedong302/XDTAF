//
//  XDTAFHTTP.m
//  XDTAF
//
//  Created by xiedong on 2021/2/2.
//
#import <CommonCrypto/CommonDigest.h>

#import "XDTAFHTTP.h"
#import "XDTAFHTTPHeader.h"
#import "XDTAFHTTPCommon.h"

#import "XDTAFNSData.h"
#import "XDTAFNSString.h"
#import "XDTAFHash.h"

#import "SSZipArchive.h"

// MARK: XDTAFHTTPClientTask

typedef void (^XDTAFHTTPDownloadHandler)(BOOL finished, int progress, NSError * error);

@interface XDTAFHTTPClientTask : NSObject

@property (nonatomic, strong) XDTAFHTTPRequest * originRequest;
@property (nonatomic, copy) XDTAFHTTPHandler taskHandler;
@property (nonatomic, strong) NSMutableData * taskData;
@property (nonatomic, assign) NSInteger redirectCount;

@property (nonatomic, assign) BOOL isDownloadTask;
@property (nonatomic, copy) NSString * downloadSavePath;
@property (nonatomic, copy) XDTAFHTTPDownloadHandler downloadHandler;

@end

@implementation XDTAFHTTPClientTask

- (instancetype)init {
    self = [super init];

    if (self) {
        _taskData = [NSMutableData dataWithCapacity:64];
        _redirectCount = 0;

        _isDownloadTask = NO;
    }

    return self;
}

@end

// MARK: XDTAFHTTPClient global config

@interface XDTAFHTTPClientGlobalConfig : NSObject

@property(nonatomic, weak) id<XDTAFHTTPClientURLRewriter> URLRewriter;

@end

@implementation XDTAFHTTPClientGlobalConfig

+(instancetype)sharedInstance {
    static XDTAFHTTPClientGlobalConfig * instance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[XDTAFHTTPClientGlobalConfig alloc] init];
    });
    
    return instance;
}

@end

// MARK: Category

@interface XDTAFHTTPRequest (XDTAFHTTPClient)
@property (nonatomic, strong) XDTAFHTTPHeader * header;
@property (atomic, assign) BOOL alreadyUsed;
@end

@interface XDTAFHTTPResponse (XDTAFHTTPClient)
@property (nonatomic, strong) XDTAFHTTPHeader * header;
@end

// MARK: XDTAFHTTPClient impl

#define MAX_REDIRECT_COUNT (2)

static const void * const kXDTAFHTTPClientTaskRequestKey = &kXDTAFHTTPClientTaskRequestKey;

@interface XDTAFHTTPClient () <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>

@property (nonatomic, strong) dispatch_queue_t handlerQueue;

@property (nonatomic, strong) NSURLSessionConfiguration * configuration;
@property (nonatomic, strong) NSOperationQueue * operationQueue;
@property (nonatomic, strong) NSURLSession * session;

@property (nonatomic, strong) NSMutableDictionary * clientTaskDict;
@property (nonatomic, strong) dispatch_semaphore_t clientTaskDictLock;

@end

@implementation XDTAFHTTPClient

+ (instancetype)defaultHTTPClient {
    XDTAFHTTPClient * client = [[XDTAFHTTPClient alloc] initWithHandlerQueue:nil enableCache:NO];
    client.sslChallengeMode = XDTAFHTTPClientSSLChallengeModeNone;
    return client;
}

+ (void)setURLRewriter:(id<XDTAFHTTPClientURLRewriter>)URLRewriter {
    [XDTAFHTTPClientGlobalConfig sharedInstance].URLRewriter = URLRewriter;
}

- (instancetype)initWithHandlerQueue:(dispatch_queue_t)queue enableCache:(BOOL)enableCache {
    self = [super init];

    if (self) {
        _handlerQueue = queue;

        if(!_handlerQueue) {
            _handlerQueue = dispatch_get_main_queue();
        }

        // 因为要在回调中拼接数据, 所以这里的Queue只能设置为1
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.maxConcurrentOperationCount = 1;

        _configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _configuration.timeoutIntervalForRequest = 30;
        if(enableCache) {
            _configuration.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
        } else {
            _configuration.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
        }

        _session = [NSURLSession sessionWithConfiguration:_configuration
                                                 delegate:self
                                            delegateQueue:_operationQueue];

        _clientTaskDict = [NSMutableDictionary dictionaryWithCapacity:8];
        _clientTaskDictLock = dispatch_semaphore_create(1);

        _enableRedirect = YES;
        _sslChallengeMode = XDTAFHTTPClientSSLChallengeModeFull;
    }

    return self;
}

- (void)sendRequest:(XDTAFHTTPRequest *)request handler:(XDTAFHTTPHandler)handler {

    if(request.alreadyUsed) {
        @throw [NSException exceptionWithName:NSGenericException
                                       reason:@"Request already used"
                                     userInfo:nil];
    }

    NSURLSessionTask * task = [self makeSessionTask:nil request:request];

    request.alreadyUsed = YES;

    XDTAFHTTPClientTask * clientTask = [[XDTAFHTTPClientTask alloc] init];
    clientTask.originRequest = request;
    clientTask.taskHandler = handler;

    [self putClientTask:task clientTask:clientTask];

    [task resume];
}

- (void)invalidate:(BOOL)cancelPendingTasks {
    if (cancelPendingTasks) {
        [self.session invalidateAndCancel];
    } else {
        [self.session finishTasksAndInvalidate];
    }
}

// MARK: Private

- (NSURLSessionTask *)downloadRequest:(NSString *)downloadURL
                               saveTo:(NSString *)savePath
                              handler:(XDTAFHTTPDownloadHandler)handler {

    NSURL * URL = [NSURL URLWithString:downloadURL];
    URL = [self rewriteURLIfNeeded:URL];

    NSMutableURLRequest * URLRequest = [NSMutableURLRequest requestWithURL:URL];
    URLRequest.HTTPMethod = @"GET";
    URLRequest.timeoutInterval = 30;

    NSURLSessionTask * task = [self.session xdtaf_http_safe_downloadTaskWithRequest:URLRequest];

    XDTAFHTTPClientTask * clientTask = [[XDTAFHTTPClientTask alloc] init];
    clientTask.isDownloadTask = YES;
    clientTask.downloadSavePath = savePath;
    clientTask.downloadHandler = handler;

    [self putClientTask:task clientTask:clientTask];

    [task resume];
    
    return task;
}

- (void)putClientTask:(NSURLSessionTask *)task
           clientTask:(XDTAFHTTPClientTask *)clientTask {

    dispatch_semaphore_wait(self.clientTaskDictLock, DISPATCH_TIME_FOREVER);

    self.clientTaskDict[@(task.taskIdentifier)] = clientTask;

    dispatch_semaphore_signal(self.clientTaskDictLock);
}

- (XDTAFHTTPClientTask *)getClientTask:(NSURLSessionTask *)task {
    XDTAFHTTPClientTask * clientTask = nil;

    dispatch_semaphore_wait(self.clientTaskDictLock, DISPATCH_TIME_FOREVER);

    clientTask = self.clientTaskDict[@(task.taskIdentifier)];

    dispatch_semaphore_signal(self.clientTaskDictLock);

    return clientTask;
}

- (void)removeClientTask:(NSURLSessionTask *)task {
    dispatch_semaphore_wait(self.clientTaskDictLock, DISPATCH_TIME_FOREVER);

    [self.clientTaskDict removeObjectForKey:@(task.taskIdentifier)];

    dispatch_semaphore_signal(self.clientTaskDictLock);
}

- (void)callHandler:(XDTAFHTTPHandler)handler
           response:(XDTAFHTTPResponse *)response {
    if(handler) {
        dispatch_async(self.handlerQueue, ^{
            if(handler) {
                handler(response);
            }
        });
    }
}

-(NSURLSessionTask *)makeSessionTask:(NSURL *)requestURL request:(XDTAFHTTPRequest *)request {
    NSURL * URL = requestURL;

    if(!URL) {
        URL = [request getURL];
    }

    URL = [self rewriteURLIfNeeded:URL];

    NSMutableURLRequest * URLRequest = [NSMutableURLRequest requestWithURL:URL];
    URLRequest.HTTPMethod = request.method;
    URLRequest.timeoutInterval = request.timeout;

    [request.header writeTo:URLRequest];

    __block NSURLSessionTask * task = nil;

    task = request.body ? [request.body createSessionTask:self.session request:URLRequest] : nil;

    if(!task) {
        task = [self.session xdtaf_http_safe_dataTaskWithRequest:URLRequest];
    }

    return task;
}

-(NSURL *)rewriteURLIfNeeded:(NSURL *)URL {
    __strong id<XDTAFHTTPClientURLRewriter> URLRewriter = [XDTAFHTTPClientGlobalConfig sharedInstance].URLRewriter;

    if(URLRewriter && [URLRewriter respondsToSelector:@selector(httpClientHandleURL:)]) {
        NSString * rewriteURL = [URLRewriter httpClientHandleURL:URL.absoluteString];

        if(rewriteURL && rewriteURL.length > 0) {
            URL = [NSURL URLWithString:rewriteURL];
        }
    }

    return URL;
}

-(BOOL)needRedirect:(NSInteger)statusCode {
    return statusCode == 300 || // Multiple Choices
        statusCode == 301 || // Moved Permanently
        statusCode == 302 || // Found
        statusCode == 303 || // See Other
        statusCode == 307 || // Temporary Redirect
        statusCode == 308; // Permanent Redirect
}

-(NSURL *)resolveRedirectURL:(NSURL *)origin location:(NSString *)location {
    if([XDTAFNSString hasPrefixIgnoreCase:location prefix:@"http://"] ||
       [XDTAFNSString hasPrefixIgnoreCase:location prefix:@"https://"]) {
        return [NSURL URLWithString:location];
    } else if([XDTAFNSString hasPrefixIgnoreCase:location prefix:@"//"]) {
        return [NSURL URLWithString:[NSString stringWithFormat:@"%@:%@", origin.scheme, location]];
    } else {
        NSURLComponents * componentsOrigin = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
        NSURLComponents * componentsRedirect = [NSURLComponents componentsWithString:location];

        componentsOrigin.percentEncodedPath = componentsRedirect.percentEncodedPath;
        componentsOrigin.percentEncodedQuery = componentsRedirect.percentEncodedQuery;
        componentsOrigin.percentEncodedFragment = componentsRedirect.percentEncodedFragment;

        return componentsOrigin.URL;
    }

    return nil;
}

// MARK: NSURLSessionDelegate

-(void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {

    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    NSURLCredential * credential = nil;

    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if (self.sslChallengeMode == XDTAFHTTPClientSSLChallengeModeNone) {
            disposition = NSURLSessionAuthChallengeUseCredential;
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        } else if(self.sslChallengeMode == XDTAFHTTPClientSSLChallengeModeSimple) {
            SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
            NSArray * policies = @[ (__bridge_transfer id)SecPolicyCreateBasicX509() ];
            SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);
            SecTrustResultType result;
            if(SecTrustEvaluate(serverTrust, &result) == errSecSuccess &&
               (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed)) {
                disposition = NSURLSessionAuthChallengeUseCredential;
                credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            } else {
                disposition = NSURLSessionAuthChallengePerformDefaultHandling;
            }
        } else {
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        }
    } else {
        disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    }

    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}

// MARK: NSURLSessionTaskDelegate

-(void)URLSession:(NSURLSession *)session
             task:(NSURLSessionTask *)task
needNewBodyStream:(void (^)(NSInputStream * _Nullable))completionHandler {

    if (task.originalRequest.HTTPBodyStream && [task.originalRequest.HTTPBodyStream conformsToProtocol:@protocol(NSCopying)]) {
        if (completionHandler) {
            completionHandler([task.originalRequest.HTTPBodyStream copy]);
        }
    }
}

-(void)URLSession:(NSURLSession *)session
             task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
       newRequest:(NSURLRequest *)request
completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {

    if(completionHandler) {
        XDTAFHTTPClientTask * clientTask = [self getClientTask:task];

        if(clientTask && clientTask.isDownloadTask) {
            if(self.enableRedirect && clientTask.redirectCount < MAX_REDIRECT_COUNT) {
                clientTask.redirectCount += 1;

                NSURL * URL = [self rewriteURLIfNeeded:request.URL];

                if(![URL isEqual:request.URL]) {
                    NSMutableURLRequest * newRequest = [request mutableCopy];
                    newRequest.URL = URL;
                    request = [newRequest copy];
                }

                completionHandler(request);
            } else {
                completionHandler(nil);
            }
        } else {
            // 非DownloadTask不在这里处理重定向，有两个问题：
            // 1. 新的request丢失了method、body等信息
            // 2. iOS 12 App在后台发送请求时（比如App启动时），在这里处理task.originalRequest可能导致崩溃
            completionHandler(nil);
        }
    }
}

-(void)URLSession:(NSURLSession *)session
             task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {

    XDTAFHTTPClientTask * clientTask = [self getClientTask:task];

    [self removeClientTask:task];

    if(!clientTask) {
        return;
    }

    if(error) {
        if(clientTask.isDownloadTask) {
            dispatch_async(self.handlerQueue, ^{
                if(clientTask.downloadHandler) {
                    clientTask.downloadHandler(NO, 0, error);
                }
            });
        } else {
            XDTAFHTTPResponse * res = [[XDTAFHTTPResponse alloc] initWith:-1
                                                              contentType:nil
                                                            contentLength:-1
                                                                     data:nil
                                                                    error:error];

            [self callHandler:clientTask.taskHandler response:res];
        }
    } else {
        NSHTTPURLResponse * httpURLResponse = (NSHTTPURLResponse *)task.response;
        NSDictionary * headers = httpURLResponse.allHeaderFields;

        // 手动处理重定向
        if([self needRedirect:httpURLResponse.statusCode] &&
           self.enableRedirect &&
           clientTask.redirectCount < MAX_REDIRECT_COUNT) {

            clientTask.redirectCount += 1;
            // 重定向请求复用clientTask，清空上一次请求的数据
            [clientTask.taskData setLength:0];

            NSURL * redirectURL = [self resolveRedirectURL:[clientTask.originRequest getURL] location:headers[@"Location"]];
            NSURLSessionTask * redirectTask = [self makeSessionTask:redirectURL request:clientTask.originRequest];

            [self putClientTask:redirectTask clientTask:clientTask];

            [redirectTask resume];
        } else {
            NSString * contentType = headers[@"Content-Type"];
            long contentLength = [headers[@"Content-Length"] intValue];

            NSData * data = clientTask.taskData ? [clientTask.taskData copy] : nil;
            // 请求完毕清空
            clientTask.taskData = nil;

            XDTAFHTTPResponse * res = [[XDTAFHTTPResponse alloc] initWith:(int)httpURLResponse.statusCode
                                                              contentType:contentType
                                                            contentLength:contentLength
                                                                     data:data
                                                                    error:nil];

            // 如果一个header有多个值(比如Set-Cookie), NSURLSession会把他们拼接成一个字符串, 用','号分隔
            // 这里暂时不管这种情况, 因为用','来分割有点潜规则, 有些头可能会傻逼
            [headers enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [res.header addEncoded:key value:obj];
            }];

            [self callHandler:clientTask.taskHandler response:res];
        }
    }
}

// MARK: NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {

    XDTAFHTTPClientTask * clientTask = [self getClientTask:dataTask];

    if(clientTask) {
        [clientTask.taskData appendData:data];
    }
}

// MARK: NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {

    XDTAFHTTPClientTask * clientTask = [self getClientTask:downloadTask];

    // 下载的task直接在这里处理完成，不到didCompleteWithError中处理
    [self removeClientTask:downloadTask];

    if(clientTask) {
        NSHTTPURLResponse * httpURLResponse = (NSHTTPURLResponse *)downloadTask.response;
        int code = (int)httpURLResponse.statusCode;

        NSError * error = XDTAFHTTPCodeSuccessful(code) ? nil : XDTAFHTTPError(@"HTTP failed: %d", code);

        if(!error && downloadTask.state != NSURLSessionTaskStateCanceling) {
            NSURL * downloadLocation = [NSURL fileURLWithPath:clientTask.downloadSavePath];
            [NSFileManager.defaultManager removeItemAtURL:downloadLocation error:nil];
            [NSFileManager.defaultManager moveItemAtURL:location toURL:downloadLocation error:&error];
        }

        dispatch_async(self.handlerQueue, ^{
            if(clientTask.downloadHandler) {
                if(error) {
                    clientTask.downloadHandler(NO, 0, error);
                } else {
                    clientTask.downloadHandler(YES, 100, nil);
                }
            }
        });
    }
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {

    XDTAFHTTPClientTask * clientTask = [self getClientTask:downloadTask];

    if(clientTask && clientTask.downloadHandler) {
        NSHTTPURLResponse * httpURLResponse = (NSHTTPURLResponse *)downloadTask.response;
        int code = (int)httpURLResponse.statusCode;

        if(XDTAFHTTPCodeSuccessful(code)) {
            int progress = 0;

            if(totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown && totalBytesExpectedToWrite > 0) {
                progress = (int) ((double) totalBytesWritten / totalBytesExpectedToWrite * 100);
            }

            dispatch_async(self.handlerQueue, ^{
                if(clientTask.downloadHandler) {
                    clientTask.downloadHandler(NO, progress, nil);
                }
            });
        }
    }
}

@end

// MARK: XDTAFHTTPDownloader impl

@implementation XDTAFHTTPDownloader {
    int _progress;
    volatile BOOL _cancel;
    NSURLSessionTask * _downloadTask;
}

- (instancetype)initWithURL:(NSString *)downloadURL toPath:(NSString *)savePath {
    self = [super init];

    if (self) {
        _downloadURL = [downloadURL copy];
        _savePath = [savePath copy];
        _progress = 0;
        _cancel = NO;
    }

    return self;
}

- (int)progress {
    return _progress;
}

- (void)start {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        __strong id<XDTAFHTTPDownloaderDelegate> delegate = self.delegate;

        NSError * error = nil;

        // 下载
        if(!self->_cancel) {
            [self downloadIfNeeded:&error];
        }

        if(!error && !self->_cancel) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if(delegate && [delegate respondsToSelector:@selector(httpDownloader:didUpdateProgress:)]) {
                    [delegate httpDownloader:self didUpdateProgress:90];
                }
            });
        }

        // 校验
        if(!error && !self->_cancel) {
            [self verifyIfNeeded:&error];
        }
        
        if(!error && !self->_cancel) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if(delegate && [delegate respondsToSelector:@selector(httpDownloader:didUpdateProgress:)]) {
                    [delegate httpDownloader:self didUpdateProgress:95];
                }
            });
        }

        // 解压
        if(!error && !self->_cancel) {
            [self unzipIfNeeded:&error];
        }

        if(!error && !self->_cancel) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if(delegate && [delegate respondsToSelector:@selector(httpDownloader:didUpdateProgress:)]) {
                    [delegate httpDownloader:self didUpdateProgress:100];
                }
            });
        }

        // 最终回调
        if(!self->_cancel) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if(delegate && [delegate respondsToSelector:@selector(httpDownloader:didFinishWithError:)]) {
                    [delegate httpDownloader:self didFinishWithError:error];
                }
            });
        }
    });
}

- (void)cancel {
    if(!_cancel) {
        _cancel = YES;
        [_downloadTask cancel];
    }
}

// MARK: Private

- (void)downloadIfNeeded:(NSError **)error {
    NSString * md5 = self.md5;

    // 检查本地文件是否ok
    if(md5.length && [NSFileManager.defaultManager fileExistsAtPath:_savePath]) {
        NSString * fileMD5 = [XDTAFHash MD5WithFile:_savePath];

        if([XDTAFNSString isEqualIgnoreCase:md5 other:fileMD5]) {
            return;
        }
    }

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    __block NSError * downloadError = nil;

    dispatch_queue_t queue = dispatch_queue_create("XDTAFHTTPDownloaderQueue", DISPATCH_QUEUE_SERIAL);

    XDTAFHTTPClient * client = [[XDTAFHTTPClient alloc] initWithHandlerQueue:queue enableCache:NO];
    client.sslChallengeMode = XDTAFHTTPClientSSLChallengeModeNone;

    _downloadTask = [client downloadRequest:_downloadURL
                                     saveTo:_savePath
                                    handler:^(BOOL finished, int progress, NSError * err) {

        if(!self->_cancel) {
            __strong id<XDTAFHTTPDownloaderDelegate> delegate = self.delegate;

            if(err) {
                downloadError = err;
            } else if(!finished) {
                self->_progress = progress * 0.9;

                dispatch_async(dispatch_get_main_queue(), ^{
                    if(delegate && [delegate respondsToSelector:@selector(httpDownloader:didUpdateProgress:)]) {
                        [delegate httpDownloader:self didUpdateProgress:self->_progress];
                    }
                });
            }
        }

        if(self->_cancel || finished || err) {
            dispatch_semaphore_signal(semaphore);
        }
    }];
    [client invalidate:NO];

    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    if(error) *error = downloadError;
}

- (void)verifyIfNeeded:(NSError **)error {
    NSString * md5 = self.md5;

    if(md5.length) {
        CFReadStreamRef readStream = NULL;
        CFURLRef URLRef = NULL;

        @try {
            URLRef = CFURLCreateWithFileSystemPath(
                                                   kCFAllocatorDefault,
                                                   (CFStringRef)self.savePath,
                                                   kCFURLPOSIXPathStyle,
                                                   NO);

            if(URLRef) {
                readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, URLRef);

                if(readStream && CFReadStreamOpen(readStream)) {
                    uint8_t buffer[4 * 1024];
                    CFIndex bytesRead = 0;

                    CC_MD5_CTX ctx;
                    CC_MD5_Init(&ctx);

                    while (!_cancel) {
                        bytesRead = CFReadStreamRead(readStream, buffer, sizeof(buffer));
                        
                        if(bytesRead > 0) {
                            CC_MD5_Update(&ctx, buffer, (CC_LONG)bytesRead);
                        } else {
                            break;
                        }
                    }

                    if(bytesRead == 0) {
                        unsigned char md[CC_MD5_DIGEST_LENGTH];
                        CC_MD5_Final(md, &ctx);

                        // md是分配在栈上的，freeWhenDone为NO
                        NSData * mdData = [NSData dataWithBytesNoCopy:md length:CC_MD5_DIGEST_LENGTH freeWhenDone:NO];
                        NSString * mdString = [XDTAFNSData toHexadecimalString:mdData];

                        if([XDTAFNSString isEqualIgnoreCase:md5 other:mdString]) {
                            return;
                        }
                    }
                }
            }
        } @catch (NSException *exception) {
            // Eat
        } @finally {
            if(readStream) {
                CFReadStreamClose(readStream);
                CFRelease(readStream);
            }

            if(URLRef) {
                CFRelease(URLRef);
            }
        }

        if(error) *error = XDTAFHTTPError(@"verify failed");
    }
}

- (void)unzipIfNeeded:(NSError **)error {
    NSString * unzipPath = self.unzipPath;

    if(unzipPath.length) {
        __block NSError * unzipError = nil;

        [XDTAFSSZipArchive unzipFileAtPath:self.savePath
                             toDestination:unzipPath
                                 overwrite:YES
                                  password:nil
                           progressHandler:^(NSString * _Nonnull entry, unz_file_info zipInfo, long entryNumber, long total, BOOL * _Nonnull canceled) {

            if(self->_cancel) {
                if(canceled) *canceled = YES;
            }

        }
                         completionHandler:^(NSString * _Nonnull path, BOOL succeeded, NSError * _Nullable err) {

            if(!succeeded) {
                unzipError = err;
            }

        }];

        if(unzipError) {
            if(error) *error = unzipError;
        }
    }
}

@end
