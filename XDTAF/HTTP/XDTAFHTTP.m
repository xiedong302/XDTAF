//
//  XDTAFHTTP.m
//  XDTAF
//
//  Created by xiedong on 2021/2/2.
//

#import "XDTAFHTTP.h"
#import "XDTAFHTTPHeader.h"
#import "XDTAFHTTPCommon.h"

typedef void(^XDTAFHTTPDownloadHandler)(BOOL finished, int progress, NSError *error);

// MARK: - XDTAFHTTPClientTasks
@interface XDTAFHTTPClientTask : NSObject

@property (nonatomic, strong) XDTAFHTTPRequest *originRequest;
@property (nonatomic, copy) XDTAFHTTPHandler taskHandler;
@property (nonatomic, strong) NSMutableData *taskData;
@property (nonatomic, assign) NSInteger redirectCount;

@property (nonatomic, assign) BOOL isDownloadTask;
@property (nonatomic, copy) NSString *downloadSavePath;
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

// MARK: - XDTAFHTTPClientGlobalConfig
@interface XDTAFHTTPClientGlobalConfig : NSObject

@property (nonatomic, weak) id<XDTAFHTTPClientUrlRewriter> URLRewriter;

@end

@implementation XDTAFHTTPClientGlobalConfig

+ (instancetype)sharedInstance {
    static XDTAFHTTPClientGlobalConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XDTAFHTTPClientGlobalConfig alloc] init];
    });
    return instance;
}

@end

@interface XDTAFHTTPRequest (XDTAFHTTPClient)

@property (nonatomic, strong) XDTAFHTTPHeader *header;
@property (atomic, assign) BOOL alreadUsed;

@end

@interface XDTAFHTTPResponse (XDTAFHTTPClient)

@property (nonatomic, strong) XDTAFHTTPHeader *header;

@end

//MARK : - XDTAFHTTPClient

static NSInteger const MAX_REDIRECT_COUNT = 2;
static const void * const kXDTAFHTTPClientTaskRequestKey = &kXDTAFHTTPClientTaskRequestKey;

@interface XDTAFHTTPClient () <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>

@property (nonatomic, strong) dispatch_queue_t handlerQueue;

@property (nonatomic, strong) NSURLSessionConfiguration *configuration;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic, strong) NSMutableDictionary *clientTaskDict;
@property (nonatomic, strong) dispatch_semaphore_t clientTaskDictLock;

@end

@implementation XDTAFHTTPClient

+ (instancetype)defaultHTTPClient {
    XDTAFHTTPClient *client = [[XDTAFHTTPClient alloc] initWithHandlerQueue:nil enableCache:NO];
    client.sslChallengeMode = XDTAFHTTPClientSSLChallengeModeNone;
    return client;
}

+ (void)setURLRewriter:(id<XDTAFHTTPClientUrlRewriter>)URLRewriter {
    [XDTAFHTTPClientGlobalConfig sharedInstance].URLRewriter = URLRewriter;
}

- (instancetype)initWithHandlerQueue:(dispatch_queue_t)queue enableCache:(BOOL)enableCache {
    self = [super init];
    
    if (self) {
        _handlerQueue = queue;
        
        if (!_handlerQueue) {
            _handlerQueue = dispatch_get_main_queue();
        }
        
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.maxConcurrentOperationCount = 1;
        
        _configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _configuration.timeoutIntervalForRequest = 30;
        if (enableCache) {
            _configuration.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
        } else {
            _configuration.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
        }
        
        _session = [NSURLSession sessionWithConfiguration:_configuration delegate:self delegateQueue:_operationQueue];
        
        _clientTaskDict = [NSMutableDictionary dictionaryWithCapacity:8];
        _clientTaskDictLock = dispatch_semaphore_create(1);
        
        _enableRedirect = YES;
        _sslChallengeMode = XDTAFHTTPClientSSLChallengeModeFull;
    }
    
    return self;
}

- (void)sendRequest:(XDTAFHTTPRequest *)request handler:(XDTAFHTTPHandler)handler {
    if (request.alreadUsed) {
        @throw [NSException exceptionWithName:NSGenericException reason:@"Request already used" userInfo:nil];
    }
    
    NSURLSessionTask *task = [self makeSessionTask:nil request:request];
    
    request.alreadUsed = YES;
    
    XDTAFHTTPClientTask *clientTask = [[XDTAFHTTPClientTask alloc] init];
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

// MARK: - Private
- (void)putClientTask:(NSURLSessionTask *)task clientTask:(XDTAFHTTPClientTask *)clientTask {
    dispatch_semaphore_wait(self.clientTaskDictLock, DISPATCH_TIME_FOREVER);
    
    self.clientTaskDict[@(task.taskIdentifier)] = clientTask;
    
    dispatch_semaphore_signal(self.clientTaskDictLock);
}

- (XDTAFHTTPClientTask *)getClientTask:(NSURLSessionTask *)task {
    XDTAFHTTPClientTask *clientTask = nil;
    
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

- (void)callHandler:(XDTAFHTTPHandler)handler response:(XDTAFHTTPResponse *)response {
    if (handler) {
        dispatch_async(self.handlerQueue, ^{
            if (handler) {
                handler(response);
            }
        });
    }
}

- (NSURLSessionTask *)makeSessionTask:(NSURL *)requestURL request:(XDTAFHTTPRequest *)request {
    NSURL *URL = requestURL;
    
    if (!URL) {
        URL = [request getURL];
    }
    
    URL = [self rewriteURLIfNeeded:URL];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
    URLRequest.HTTPMethod = request.method;
    URLRequest.timeoutInterval = request.timeout;
    
    [request.header writeTo:URLRequest];
    
    __block NSURLSessionTask *task = nil;
    
    task = request.body ? [request.body createSessionTask:self.session request:URLRequest] : nil;
    
    if (!task) {
        task = [self.session xdtaf_http_safe_dataTaskWithRequest:URLRequest];
    }
    
    return task;
}

- (NSURL *)rewriteURLIfNeeded:(NSURL *)URL {
    __strong id<XDTAFHTTPClientUrlRewriter> URLRewriter = [XDTAFHTTPClientGlobalConfig sharedInstance].URLRewriter;
    
    if (URLRewriter && [URLRewriter respondsToSelector:@selector(httpClientHandleURL:)]) {
        NSString *rewriteURL = [URLRewriter httpClientHandleURL:URL.absoluteString];
        
        if (rewriteURL && rewriteURL.length > 0) {
            URL = [NSURL URLWithString:rewriteURL];
        }
    }
    
    return URL;
}

- (BOOL)needRedirect:(NSInteger)statusCode {
    return statusCode == 300 || // Multiple Choices
        statusCode == 301 || // Moved Permanently
        statusCode == 302 || // Found
        statusCode == 303 || // See Other
        statusCode == 307 || // Temporary Redirect
        statusCode == 308; // Permanent Redirect
}

- (NSURL *)resolveRedirectURL:(NSURL *)origin location:(NSString *)location {
    
    return nil;
}

@end
