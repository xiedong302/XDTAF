//
//  NSString+XDTAF.h
//  XDTAF
//
//  Created by xiedong on 2021/2/3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (XDTAF)

- (BOOL)xdtaf_hasPrefixIgnoreCase:(NSString *)prefix;

- (BOOL)xdtaf_hasSuffixIgnoreCase:(NSString *)suffix;

- (BOOL)xdtaf_isEqualCase:(NSString *)other;

- (BOOL)xdtaf_isEqualIgnoreCase:(NSString *)other;

- (BOOL)xdtaf_containsIgnoreCase:(NSString *)other;

@end

NS_ASSUME_NONNULL_END
