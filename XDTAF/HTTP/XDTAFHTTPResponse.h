//
//  XDTAFHTTPResponse.h
//  XDTAF
//
//  Created by xiedong on 2021/2/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XDTAFHTTPResponse : NSObject

@property (nonatomic, readonly, assign) int code;
@property (nonatomic, readonly, copy) NSString *contentType;
@property (nonatomic, readonly, assign) long contentLength;

- (instancetype)initWith:(int)code contentType:(NSString * _Nullable)contentType contentLength:(long)contentLength data:(NSData * _Nullable)data error:(NSError * _Nullable)error;

- (BOOL)isSuccessful;

- (NSError *)error;

- (NSString *)getHeader:(NSString *)name;

- (NSArray *)getHeaders:(NSString *)name;

- (NSDictionary *)allHeaders;

- (NSData *)data;

- (NSString *)string;

@end

NS_ASSUME_NONNULL_END
