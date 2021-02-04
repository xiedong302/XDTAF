//
//  XDTAFHTTPHeader.h
//  XDTAF
//
//  Created by xiedong on 2021/2/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XDTAFHTTPHeader : NSObject

@property (nonatomic, strong) NSMutableArray * encodedNames;
@property (nonatomic, strong) NSMutableArray * encodedValues;

- (void)add:(NSString *)name value:(NSString *)value;
- (void)add:(NSDictionary *)headers;
- (void)addEncoded:(NSString *)name value:(NSString *)value;

- (void)set:(NSString *)name value:(NSString *)value;
- (void)set:(NSDictionary *)headers;
- (void)setEncoded:(NSString *)name value:(NSString *)value;

- (NSString *)get:(NSString *)name;
- (NSArray *)getAll:(NSString *)name;
- (NSDictionary *)all;

- (void)writeTo:(NSMutableURLRequest *)URLRequest;

@end

NS_ASSUME_NONNULL_END
