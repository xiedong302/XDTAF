//
//  XDTAFNSString.m
//  XDTAF
//
//  Created by xiedong on 2021/2/4.
//

#import "XDTAFNSString.h"

@implementation XDTAFNSString

+ (BOOL)hasPrefixIgnoreCase:(NSString *)str prefix:(NSString *)prefix {
    if(!str || !prefix) {
        return str == prefix;
    }
    
    if(prefix.length > str.length) {
        return NO;
    }

    NSRange range = [str rangeOfString:prefix options:NSCaseInsensitiveSearch];

    return range.location == 0;
}

+ (BOOL)hasSuffixIgnoreCase:(NSString *)str suffix:(NSString *)suffix {
    if(!str || !suffix) {
        return str == suffix;
    }

    if(suffix.length > str.length) {
        return NO;
    }

    NSRange range = [str rangeOfString:suffix options:NSCaseInsensitiveSearch];

    return range.location == (str.length - suffix.length);
}

+ (BOOL)isEqual:(NSString *)string other:(NSString *)other {
    if(!string || !other) {
        return string == other;
    }

    if(string.length != other.length) {
        return NO;
    }

    return [string isEqualToString:other];
}

+ (BOOL)isEqualIgnoreCase:(NSString *)string other:(NSString *)other {
    if(!string || !other) {
        return string == other;
    }

    if(string.length != other.length) {
        return NO;
    }

    return [string compare:other options:NSCaseInsensitiveSearch] == NSOrderedSame;
}

+ (BOOL)containsIgnoreCase:(NSString *)string other:(NSString *)other {
    if(!string || !other) {
        return string == other;
    }

    if(other.length > string.length) {
        return NO;
    }

    NSRange range = [string rangeOfString:other options:NSCaseInsensitiveSearch];

    return range.location != NSNotFound;
}
@end
