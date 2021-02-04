//
//  XDTAFNSString.h
//  XDTAF
//
//  Created by xiedong on 2021/2/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XDTAFNSString : NSObject

+ (BOOL)hasPrefixIgnoreCase:(NSString *)str prefix:(NSString *)prefix;

+ (BOOL)hasSuffixIgnoreCase:(NSString *)str suffix:(NSString *)suffix;

+ (BOOL)isEqual:(NSString *)string other:(NSString *)other;

+ (BOOL)isEqualIgnoreCase:(NSString *)string other:(NSString *)other;

+ (BOOL)containsIgnoreCase:(NSString *)string other:(NSString *)other;

@end

NS_ASSUME_NONNULL_END
