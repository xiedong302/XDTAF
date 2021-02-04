//
//  XDTAFHTTPCommon.h
//  XDTAF
//
//  Created by xiedong on 2021/2/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT BOOL XDTAFHTTPCodeSuccessful(int code);

FOUNDATION_EXPORT NSString * XDTAFHTTPEncode(NSString * str);

FOUNDATION_EXPORT NSError * XDTAFHTTPError(NSString * format, ...) NS_FORMAT_FUNCTION(1,2);

@interface NSURLSession (XDTAFHTTP)

- (NSURLSessionDataTask *)xdtaf_http_safe_dataTaskWithRequest:(NSURLRequest *)request;

- (NSURLSessionUploadTask *)xdtaf_http_safe_uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData;

- (NSURLSessionUploadTask *)xdtaf_http_safe_uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL;

- (NSURLSessionUploadTask *)xdtaf_http_safe_uploadTaskWithStreamedRequest:(NSURLRequest *)request;

- (NSURLSessionDownloadTask *)xdtaf_http_safe_downloadTaskWithRequest:(NSURLRequest *)request;

@end

NS_ASSUME_NONNULL_END
