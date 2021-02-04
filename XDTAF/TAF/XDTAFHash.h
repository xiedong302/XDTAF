//
//  XDTAFHash.h
//  XDTAF
//
//  Created by xiedong on 2021/2/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XDTAFHash : NSObject

+(NSString *)MD5WithString:(NSString *)str;

+(NSString *)MD5WithData:(NSData *)data;

+(NSString *)MD5WithFile:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
