//
//  XDTAFHTTPCommon.m
//  XDTAF
//
//  Created by xiedong on 2021/2/2.
//

#import "XDTAFHTTPCommon.h"
#import "XDTAFHTTPAFNHelper.h"

BOOL XDTAFHTTPCodeSuccessful(int code) {
    if (code < 200 || code >= 300) {
        return NO;
    }
    return YES;
}

NSString *XDTAFHTTPEncode(NSString *str) {
    if (!str.length) {
        str = @"";
    }
    
    return XDTAFAFPercentEscapedStringFromString(str);
}

NSError *XDTAFHTTPError(NSString *format, ...) {
    va_list args;
    
    va_start(args, format);
    
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    
    va_end(args);
    
    NSDictionary *userInfo;
    
    if (message) {
        userInfo = @{NSLocalizedDescriptionKey : message};
    }
    
    return [NSError errorWithDomain:@"XDTAFHTTPError" code:-1 userInfo:userInfo];
}

static dispatch_queue_t xdtaf_url_session_manager_creation_queue() {
    static dispatch_queue_t xdtaf_url_session_manager_creation_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        xdtaf_url_session_manager_creation_queue = dispatch_queue_create("XDTAFHTTPSessionManagerCreationQueue", DISPATCH_QUEUE_SERIAL);
    });
    return xdtaf_url_session_manager_creation_queue;
}

static void xdtaf_url_session_manager_creat_task_safely(dispatch_block_t block) {
    if (@available(iOS 8.0, *)) {
        block();
    } else {
        // Fix of bug
        // Open Radar:http://openradar.appspot.com/radar?id=5871104061079552 (status: Fixed in iOS8)
        // Issue about:https://github.com/AFNetworking/AFNetworking/issues/2093
        dispatch_sync(xdtaf_url_session_manager_creation_queue(), block);
    }
    
}

@implementation NSURLSession (XDTAFHTTP)

- (NSURLSessionDataTask *)xdtaf_http_safe_dataTaskWithRequest:(NSURLRequest *)request {
    __block NSURLSessionDataTask *task = nil;
    
    xdtaf_url_session_manager_creat_task_safely(^{
        task = [self dataTaskWithRequest:request];
    });
    
    return task;
}

- (NSURLSessionUploadTask *)xdtaf_http_safe_uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData {
    __block NSURLSessionUploadTask *task = nil;
    
    xdtaf_url_session_manager_creat_task_safely(^{
        task = [self uploadTaskWithRequest:request fromData:bodyData];
    });
    
    return task;
}

- (NSURLSessionUploadTask *)xdtaf_http_safe_uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)bodyFile {
    __block NSURLSessionUploadTask *task = nil;
    
    xdtaf_url_session_manager_creat_task_safely(^{
        task = [self uploadTaskWithRequest:request fromFile:bodyFile];
    });
    
    return task;
}

- (NSURLSessionUploadTask *)xdtaf_http_safe_uploadTaskWithStreamedRequest:(NSURLRequest *)request {
    __block NSURLSessionUploadTask *task = nil;
    
    xdtaf_url_session_manager_creat_task_safely(^{
        task = [self uploadTaskWithStreamedRequest:request];
    });
    
    return task;
}

- (NSURLSessionDownloadTask *)xdtaf_http_safe_downloadTaskWithRequest:(NSURLRequest *)request {
    __block NSURLSessionDownloadTask *task = nil;
    
    xdtaf_url_session_manager_creat_task_safely(^{
        task = [self downloadTaskWithRequest:request];
    });
    
    return task;
}

@end
