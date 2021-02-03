//
//  NSString+XDTAF.m
//  XDTAF
//
//  Created by xiedong on 2021/2/3.
//

#import "NSString+XDTAF.h"

@implementation NSString (XDTAF)

- (BOOL)xdtaf_hasPrefixIgnoreCase:(NSString *)prefix {
    if (!self || !prefix) {
        return self == prefix;
    }
    
    if (prefix.length > self.length) {
        return NO;
    }
    
    NSRange range = [self rangeOfString:prefix options:NSCaseInsensitiveSearch];
    
    return range.location == 0;
}

- (BOOL)xdtaf_hasSuffixIgnoreCase:(NSString *)suffix {
    if (!self || !suffix) {
        return self == suffix;
    }
    
    if (suffix.length > self.length) {
        return NO;
    }
    
    NSRange range = [self rangeOfString:suffix options:NSCaseInsensitiveSearch];
    
    return range.location == (self.length - suffix.length);
}

- (BOOL)xdtaf_isEqualCase:(NSString *)other {
    if (!self || !other) {
        return self == other;
    }
    
    if (other.length != self.length) {
        return NO;
    }
    
    return [self isEqualToString:other];
}

- (BOOL)xdtaf_isEqualIgnoreCase:(NSString *)other {
    if (!self || !other) {
        return self == other;
    }
    
    if (other.length != self.length) {
        return NO;
    }
    
    return [self compare:other options:NSCaseInsensitiveSearch] == NSOrderedSame;
}

- (BOOL)xdtaf_containsIgnoreCase:(NSString *)other {
    if (!self || !other) {
        return self == other;
    }
    
    if (other.length > self.length) {
        return NO;
    }
    
    NSRange range = [self rangeOfString:other options:NSCaseInsensitiveSearch];
    
    return range.location != NSNotFound;
}

@end
