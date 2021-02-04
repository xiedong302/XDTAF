//
//  XDTAFHTTPHeader.m
//  XDTAF
//
//  Created by xiedong on 2021/2/2.
//

#import "XDTAFHTTPHeader.h"
#import "XDTAFHTTPCommon.h"

@implementation XDTAFHTTPHeader
- (instancetype)init {
    self = [super init];

    if (self) {
        _encodedNames = [NSMutableArray arrayWithCapacity:4];
        _encodedValues = [NSMutableArray arrayWithCapacity:4];
    }

    return self;
}

- (void)add:(NSString *)name value:(NSString *)value {
    if(name && name.length && value && value.length) {
        [self addEncoded:XDTAFHTTPEncode(name)
                   value:XDTAFHTTPEncode(value)];
    }
}

- (void)add:(NSDictionary *)headers {
    if(headers && headers.count > 0) {
        for (NSString * name in headers) {
            [self add:name value:headers[name]];
        }
    }
}

- (void)addEncoded:(NSString *)name value:(NSString *)value {
    if(name && name.length && value && value.length) {
        [self.encodedNames addObject:name];
        [self.encodedValues addObject:value];
    }
}

- (void)set:(NSString *)name value:(NSString *)value {
    if(name && name.length && value && value.length) {
        [self setEncoded:XDTAFHTTPEncode(name)
                   value:XDTAFHTTPEncode(value)];
    }
}

- (void)set:(NSDictionary *)headers {
    if(headers && headers.count > 0) {
        for (NSString * name in headers) {
            [self set:name value:headers[name]];
        }
    }
}

- (void)setEncoded:(NSString *)name value:(NSString *)value {
    if(name && name.length && value && value.length) {
        BOOL existed = NO;
        
        NSArray * names = self.encodedNames;
        NSMutableArray * values = self.encodedValues;

        if(names && names.count > 0) {
            for(int i = 0; i < names.count; ++i) {
                if([names[i] caseInsensitiveCompare:name] == NSOrderedSame) {
                    existed = YES;

                    // 替换已经存在的
                    values[i] = value;
                }
            }
        }

        if(!existed) {
            [self.encodedNames addObject:name];
            [self.encodedValues addObject:value];
        }
    }
}

- (NSString *)get:(NSString *)name {
    if(name && name.length) {
        NSArray * names = self.encodedNames;
        NSArray * values = self.encodedValues;

        if(names && names.count > 0) {
            for(int i = 0; i < names.count; ++i) {
                if([names[i] caseInsensitiveCompare:name] == NSOrderedSame) {
                    return values[i];
                }
            }
        }
    }

    return nil;
}

- (NSArray *)getAll:(NSString *)name {
    NSMutableArray * result = nil;

    if(name && name.length) {
        NSArray * names = self.encodedNames;
        NSArray * values = self.encodedValues;

        if(names && names.count > 0) {
            result = [NSMutableArray arrayWithCapacity:2];

            for(int i = 0; i < names.count; ++i) {
                if([names[i] caseInsensitiveCompare:name] == NSOrderedSame) {
                    [result addObject:values[i]];
                }
            }
        }
    }

    return result ?: [result copy];
}

- (NSDictionary *)all {
    NSMutableDictionary * all = nil;

    NSArray * names = self.encodedNames;
    NSArray * values = self.encodedValues;

    if(names && names.count > 0) {
        all = [NSMutableDictionary dictionaryWithCapacity:4];

        for(int i = 0; i < names.count; ++i) {
            [all setObject:values[i] forKey:names[i]];
        }
    }

    return all ?: [all copy];
}

- (void)writeTo:(NSMutableURLRequest *)URLRequest {
    NSArray * names = self.encodedNames;
    NSArray * values = self.encodedValues;

    if(names && names.count > 0) {
        for(int i = 0; i < names.count; ++i) {
            [URLRequest addValue:values[i] forHTTPHeaderField:names[i]];
        }
    }
}

@end
