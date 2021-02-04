//
//  XDTAFNSData.h
//  XDTAF
//
//  Created by xiedong on 2021/2/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XDTAFNSData : NSObject

+ (NSData *)toZippedData:(NSData *)data;

+ (NSData *)toUnzippedData:(NSData *)data;

+ (NSString *)toHexadecimalString:(NSData *)data;

+ (NSData *)fromHexadecimalString:(NSString *)hex;

@end

NS_ASSUME_NONNULL_END
