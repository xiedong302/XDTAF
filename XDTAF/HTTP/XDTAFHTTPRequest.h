//
//  XDTAFHTTPRequest.h
//  XDTAF
//
//  Created by xiedong on 2021/2/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// MARK: XDTAFHTTPRequestBody

@protocol XDTAFHTTPRequestBody <NSObject>

- (NSURLSessionTask *)createSessionTask:(NSURLSession *)session request:(NSMutableURLRequest *)request;

@end

// MARK: XDTAFHTTPRequestDataBody

@interface XDTAFHTTPRequestDataBody : NSObject <XDTAFHTTPRequestBody>

+ (instancetype)dataBodyWithData:(NSData *)data;

+ (instancetype)dataBodyWithFile:(NSURL *)file;

@end

// MARK: XDTAFHTTPRequestFormBody

@interface XDTAFHTTPRequestFormBody : NSObject <XDTAFHTTPRequestBody>

- (void)add:(NSString *)name value:(NSString *)value;

- (void)addEncoded:(NSString *)name value:(NSString *)value;

@end

// MARK: XDTAFHTTPRequestJSONBody

@interface XDTAFHTTPRequestJSONBody : NSObject <XDTAFHTTPRequestBody>

- (instancetype)initWithDictionary:(NSDictionary *)dict;

@end

// MARK: XDTAFHTTPRequestMultipartBody

@interface XDTAFHTTPRequestMultipartBody : NSObject <XDTAFHTTPRequestBody>

- (void)add:(NSString *)name value:(NSString *)value;

- (void)add:(NSString *)name data:(NSData *)data;

- (void)add:(NSString *)name file:(NSURL *)file;

@end

// MARK: XDTAFHTTPRequest

@interface XDTAFHTTPRequest : NSObject

@property (nonatomic, readonly, copy) NSString * method;
@property (nonatomic, readonly, strong) id<XDTAFHTTPRequestBody> body;
@property (nonatomic, readonly, assign) NSTimeInterval timeout;

+ (instancetype)get:(NSString *)URLString;

+ (instancetype)get:(NSString *)URLString timeout:(NSTimeInterval)timeout;

+ (instancetype)post:(NSString *)URLString body:(id<XDTAFHTTPRequestBody>)body;

+ (instancetype)post:(NSString *)URLString body:(id<XDTAFHTTPRequestBody>)body timeout:(NSTimeInterval)timeout;

- (NSURL *)getURL;

/*!
 * @abstract
 * 添加Header, 会被encode
 */
- (void)addHeader:(NSString *)name value:(NSString *)value;

/*!
 * @abstract
 * 添加已encoded的Header
 */
- (void)addEncodedHeader:(NSString *)name value:(NSString *)value;

/*!
 * @abstract
 * 添加Header, 会被encode
 */
- (void)addHeaders:(NSDictionary *)headers;

/*!
 * @abstract
 * 添加Path, 会被encode, 支持a/b/c这样的多级形式
 */
- (void)addPath:(NSString *)pathSegment;

/*!
 * @abstract
 * 添加query, 会被encode
 */
- (void)addQueryParameter:(NSString *)name value:(NSString *)value;

@end

NS_ASSUME_NONNULL_END
