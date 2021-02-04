//
//  XDTAFHTTPResponse.m
//  XDTAF
//
//  Created by xiedong on 2021/2/2.
//

#import "XDTAFHTTPResponse.h"
#import "XDTAFHTTPHeader.h"
#import "XDTAFHTTPCommon.h"

@interface XDTAFHTTPResponse ()

@property (nonatomic, strong) NSData * httpData;
@property (nonatomic, strong) NSError * httpError;
@property (nonatomic, strong) XDTAFHTTPHeader * header;

@end

@implementation XDTAFHTTPResponse

- (instancetype)initWith:(int)code
             contentType:(NSString *)contentType
           contentLength:(long)contentLength
                    data:(NSData *)data
                   error:(NSError *)error {

    self = [super init];

    if (self) {
        _code = code;
        _contentType = [contentType copy];
        _contentLength = contentLength;

        _httpData = data;

        if(error) {
            _httpError = error;
        } else if(!XDTAFHTTPCodeSuccessful(code)) {
            _httpError = XDTAFHTTPError(@"HTTP failed: %d", code);
        } else {
            _httpError = nil;
        }

        _header = [[XDTAFHTTPHeader alloc] init];
    }

    return self;
}

- (BOOL)isSuccessful {
    return !self.httpError;
}

- (NSError *)error {
    return self.httpError;
}

- (NSString *)getHeader:(NSString *)name {
    return [self.header get:name];
}

- (NSArray *)getHeaders:(NSString *)name {
    return [self.header getAll:name];
}

- (NSDictionary *)allHeaders {
    return [self.header all];
}

- (NSData *)data {
    return self.httpData;
}

- (NSString *)string {
    NSData * data = [self data];

    if(data && data.length > 0) {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }

    return nil;
}

@end
