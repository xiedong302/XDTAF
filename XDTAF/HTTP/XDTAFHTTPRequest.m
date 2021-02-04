//
//  XDTAFHTTPRequest.m
//  XDTAF
//
//  Created by xiedong on 2021/2/2.
//

#import "XDTAFHTTPRequest.h"
#import "XDTAFHTTPCommon.h"
#import "XDTAFHTTPAFNHelper.h"
#import "XDTAFHTTPHeader.h"

// MARK: XDTAFHTTPRequestDataBody impl

@interface XDTAFHTTPRequestDataBody ()

@property (nonatomic, strong) NSData * myData;
@property (nonatomic, strong) NSURL * myFile;

@end

@implementation XDTAFHTTPRequestDataBody

+ (instancetype)dataBodyWithData:(NSData *)data {
    return [[XDTAFHTTPRequestDataBody alloc] initWithData:data file:nil];
}

+ (instancetype)dataBodyWithFile:(NSURL *)file {
    return [[XDTAFHTTPRequestDataBody alloc] initWithData:nil file:file];
}

- (instancetype)initWithData:(NSData *)data file:(NSURL *)file {
    self = [super init];

    if(self) {
        _myData = data;
        _myFile = file;
    }

    return self;
}

- (NSURLSessionTask *)createSessionTask:(NSURLSession *)session request:(NSMutableURLRequest *)request {
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];

    NSURLSessionTask * task = nil;

    if(self.myData) {
        task = [session xdtaf_http_safe_uploadTaskWithRequest:request fromData:self.myData];
    } else if(self.myFile) {
        task = [session xdtaf_http_safe_uploadTaskWithRequest:request fromFile:self.myFile];
    }

    return task;
}

@end

// MARK: XDTAFHTTPRequestFormBody impl

@interface XDTAFHTTPRequestFormBody ()

@property (nonatomic, strong) NSMutableDictionary * formDict;

@end

@implementation XDTAFHTTPRequestFormBody

- (instancetype)init {
    self = [super init];

    if(self) {
        _formDict = [[NSMutableDictionary alloc] initWithCapacity:4];
    }

    return self;
}

- (void)add:(NSString *)name value:(NSString *)value {
    if(name && name.length && value && value.length) {
        [self.formDict setObject:XDTAFHTTPEncode(value)
                          forKey:XDTAFHTTPEncode(name)];
    }
}

- (void)addEncoded:(NSString *)name value:(NSString *)value {
    if(name && name.length && value && value.length) {
        [self.formDict setObject:value forKey:name];
    }
}

- (NSURLSessionTask *)createSessionTask:(NSURLSession *)session request:(NSMutableURLRequest *)request {
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

    NSURLSessionTask * task = nil;

    NSData * formData = self.formData;

    if(formData) {
        task = [session xdtaf_http_safe_uploadTaskWithRequest:request fromData:formData];
    }

    return task;
}

- (NSData *)formData {
    NSDictionary * dict = self.formDict;

    if(dict.count > 0) {
        NSMutableString * str = [NSMutableString stringWithCapacity:64];

        [dict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if(str.length > 0) {
                [str appendFormat:@"&"];
            }
            [str appendFormat:@"%@=%@", key, obj];
        }];

        return [str dataUsingEncoding:NSUTF8StringEncoding];
    }

    return nil;
}

@end

// MARK: XDTAFHTTPRequestJSONBody impl

@interface XDTAFHTTPRequestJSONBody ()

@property (nonatomic, strong) NSDictionary * jsonDict;

@end

@implementation XDTAFHTTPRequestJSONBody

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];

    if(self) {
        _jsonDict = dict;
    }

    return self;
}

- (NSURLSessionTask *)createSessionTask:(NSURLSession *)session request:(NSMutableURLRequest *)request {
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSURLSessionTask * task = nil;

    NSData * jsonData = self.jsonData;

    if(jsonData) {
        task = [session xdtaf_http_safe_uploadTaskWithRequest:request fromData:jsonData];
    }

    return task;
}

- (NSData *)jsonData {
    NSDictionary * dict = self.jsonDict;

    if(dict && dict.count > 0) {
        NSError * error;
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];

        if(!error) {
            return jsonData;
        }
    }

    return nil;
}

@end

// MARK: XDTAFHTTPRequestMultipartBody impl

@interface XDTAFHTTPRequestMultipartBody ()

@property (nonatomic, copy) NSString * boundary;
@property (nonatomic, strong) XDTAFAFMultipartBodyStream * bodyStream;

@end

@implementation XDTAFHTTPRequestMultipartBody

- (instancetype)init {
    self = [super init];

    if (self) {
        _boundary = [NSString stringWithFormat:@"Boundary+%08X%08X", arc4random(), arc4random()];
        _bodyStream = [[XDTAFAFMultipartBodyStream alloc] initWithStringEncoding:NSUTF8StringEncoding];
    }

    return self;
}

- (void)add:(NSString *)name value:(NSString *)value {
    if(name && name.length && value && value.length) {
        XDTAFAFHTTPBodyPart *bodyPart = [[XDTAFAFHTTPBodyPart alloc] init];
        bodyPart.stringEncoding = NSUTF8StringEncoding;
        bodyPart.headers = @{
                             @"Content-Disposition" : [NSString stringWithFormat:@"form-data; name=\"%@\"", XDTAFHTTPEncode(name)]
                             };
        bodyPart.body = [value dataUsingEncoding:NSUTF8StringEncoding];
        bodyPart.boundary = self.boundary;

        [self.bodyStream appendHTTPBodyPart:bodyPart];
    }
}

- (void)add:(NSString *)name data:(NSData *)data {
    if(name && name.length && data) {
        NSString * encodedName = XDTAFHTTPEncode(name);

        XDTAFAFHTTPBodyPart *bodyPart = [[XDTAFAFHTTPBodyPart alloc] init];
        bodyPart.stringEncoding = NSUTF8StringEncoding;
        bodyPart.headers = @{
                             @"Content-Disposition" : [NSString stringWithFormat:@"form-data; name=\"%@\"; fileName=\"%@\"", encodedName, encodedName],
                             @"Content-Type" : @"application/octet-stream"
                             };
        bodyPart.body = data;
        bodyPart.boundary = self.boundary;

        [self.bodyStream appendHTTPBodyPart:bodyPart];
    }
}

- (void)add:(NSString *)name file:(NSURL *)file {
    if(name && name.length && file) {
        NSString * encodedName = XDTAFHTTPEncode(name);
        NSString * encodedFileName = encodedName;

        NSString * fileName = [file lastPathComponent];

        if(!fileName || fileName.length == 0) {
            encodedFileName = XDTAFHTTPEncode(fileName);
        }

        XDTAFAFHTTPBodyPart *bodyPart = [[XDTAFAFHTTPBodyPart alloc] init];
        bodyPart.stringEncoding = NSUTF8StringEncoding;
        bodyPart.headers = @{
                             @"Content-Disposition" : [NSString stringWithFormat:@"form-data; name=\"%@\"; fileName=\"%@\"", encodedName, encodedFileName],
                             @"Content-Type" : @"application/octet-stream"
                             };
        bodyPart.body = file;
        bodyPart.boundary = self.boundary;

        [self.bodyStream appendHTTPBodyPart:bodyPart];
    }
}

- (NSURLSessionTask *)createSessionTask:(NSURLSession *)session request:(NSMutableURLRequest *)request {
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", self.boundary] forHTTPHeaderField:@"Content-Type"];

    NSURLSessionTask * task = nil;

    if (![self.bodyStream isEmpty]) {
        [self.bodyStream setInitialAndFinalBoundaries];

        request.HTTPBodyStream = self.bodyStream;

        task = [session xdtaf_http_safe_uploadTaskWithStreamedRequest:request];
    }

    return task;
}

@end

// MARK: XDTAFHTTPRequest impl

@interface XDTAFHTTPRequest ()

@property (nonatomic, copy) NSString * baseURLString;
@property (nonatomic, strong) NSURLComponents * URLComponents;

@property (nonatomic, strong) XDTAFHTTPHeader * header;

@property (atomic, assign) BOOL alreadyUsed;

@end

@implementation XDTAFHTTPRequest

- (instancetype)initWith:(NSString *)URLString
                  method:(NSString *)method
                    body:(id<XDTAFHTTPRequestBody>)body
                 timeout:(NSTimeInterval)timeout {

    self = [super init];

    if (self) {
        _baseURLString = [URLString copy];
        _URLComponents = nil;

        _header = [[XDTAFHTTPHeader alloc] init];

        _method = [method copy];
        _body = body;
        _timeout = timeout;
    }

    return self;
}

+ (instancetype)get:(NSString *)URLString {
    return [[XDTAFHTTPRequest alloc] initWith:URLString method:@"GET" body:nil timeout:30];
}

+ (instancetype)get:(NSString *)URLString timeout:(NSTimeInterval)timeout {
    return [[XDTAFHTTPRequest alloc] initWith:URLString method:@"GET" body:nil timeout:timeout];
}

+ (instancetype)post:(NSString *)URLString body:(id<XDTAFHTTPRequestBody>)body {
    return [[XDTAFHTTPRequest alloc] initWith:URLString method:@"POST" body:body timeout:30];
}

+ (instancetype)post:(NSString *)URLString body:(id<XDTAFHTTPRequestBody>)body timeout:(NSTimeInterval)timeout {
    return [[XDTAFHTTPRequest alloc] initWith:URLString method:@"POST" body:body timeout:timeout];
}

- (NSURL *)getURL {
    if(self.URLComponents) {
        return [self.URLComponents URL];
    } else {
        return [NSURL URLWithString:self.baseURLString];
    }
}

- (void)addHeader:(NSString *)name value:(NSString *)value {
    [self.header set:name value:value];
}

- (void)addEncodedHeader:(NSString *)name value:(NSString *)value {
    [self.header setEncoded:name value:value];
}

- (void)addHeaders:(NSDictionary *)headers {
    [self.header set:headers];
}

- (void)addPath:(NSString *)pathSegment {
    if(!self.URLComponents) {
        self.URLComponents = [NSURLComponents componentsWithString:self.baseURLString];
    }

    if(self.URLComponents) {
        if(pathSegment && pathSegment.length > 0) {
            NSArray<NSString *> * pathList = [pathSegment componentsSeparatedByString:@"/"];

            if(pathList && pathList.count > 0) {
                NSMutableString * pathString = [NSMutableString stringWithCapacity:pathSegment.length];
                BOOL isFirst = YES;
                
                for (NSString * path in pathList) {
                    if(path.length > 0) {
                        if(!isFirst) {
                            [pathString appendString:@"/"];
                        }

                        [pathString appendFormat:@"%@", XDTAFHTTPEncode(path)];

                        isFirst = NO;
                    }
                }

                NSString * oldPath = self.URLComponents.percentEncodedPath ?: @"";
                NSString * newPath = nil;

                if([oldPath hasSuffix:@"/"]) {
                    newPath = [NSString stringWithFormat:@"%@%@", oldPath, pathString];
                } else {
                    newPath = [NSString stringWithFormat:@"%@/%@", oldPath, pathString];
                }

                self.URLComponents.percentEncodedPath = newPath;
            }
        }
    }
}

- (void)addQueryParameter:(NSString *)name value:(NSString *)value {
    if(!self.URLComponents) {
        self.URLComponents = [NSURLComponents componentsWithString:self.baseURLString];
    }

    if(self.URLComponents) {
        NSString * newQuery = nil;

        if(self.URLComponents.percentEncodedQuery && self.URLComponents.percentEncodedQuery.length > 0) {
            if([self.URLComponents.percentEncodedQuery hasSuffix:@"&"]) {
                newQuery = [NSString stringWithFormat:@"%@%@=%@",
                            self.URLComponents.percentEncodedQuery,
                            XDTAFHTTPEncode(name),
                            XDTAFHTTPEncode(value)];
            } else {
                newQuery = [NSString stringWithFormat:@"%@&%@=%@",
                            self.URLComponents.percentEncodedQuery,
                            XDTAFHTTPEncode(name),
                            XDTAFHTTPEncode(value)];
            }
        } else {
            newQuery = [NSString stringWithFormat:@"%@=%@",
                        XDTAFHTTPEncode(name),
                        XDTAFHTTPEncode(value)];
        }

        self.URLComponents.percentEncodedQuery = newQuery;
    }
}

@end
