//
//  XDTAFHash.m
//  XDTAF
//
//  Created by xiedong on 2021/2/4.
//

#import "XDTAFHash.h"
#import <CommonCrypto/CommonDigest.h>
#import "XDTAFNSData.h"

@implementation XDTAFHash

+(NSString *)MD5WithString:(NSString *)str {
    return [self MD5WithData:[str dataUsingEncoding:NSUTF8StringEncoding]];
}

+(NSString *)MD5WithData:(NSData *)data {
    unsigned char md[CC_MD5_DIGEST_LENGTH];

    CC_MD5(data.bytes, (CC_LONG)data.length, md);

    // md是分配在栈上的，freeWhenDone为NO
    NSData * mdData = [NSData dataWithBytesNoCopy:md length:CC_MD5_DIGEST_LENGTH freeWhenDone:NO];
    return [XDTAFNSData toHexadecimalString:mdData];
}

+(NSString *)MD5WithFile:(NSString *)path {
    NSString * MD5 = nil;

    CFReadStreamRef readStream = NULL;
    CFURLRef URLRef = NULL;

    @try {
        URLRef = CFURLCreateWithFileSystemPath(
                                               kCFAllocatorDefault,
                                               (CFStringRef)path,
                                               kCFURLPOSIXPathStyle,
                                               NO);

        if(URLRef) {
            readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, URLRef);

            if(readStream && CFReadStreamOpen(readStream)) {
                uint8_t buffer[4 * 1024];
                CFIndex bytesRead = 0;

                CC_MD5_CTX ctx;
                CC_MD5_Init(&ctx);

                while ((bytesRead = CFReadStreamRead(readStream, buffer, sizeof(buffer))) > 0) {
                    CC_MD5_Update(&ctx, buffer, (CC_LONG)bytesRead);
                }

                if(bytesRead == 0) {
                    unsigned char md[CC_MD5_DIGEST_LENGTH];
                    CC_MD5_Final(md, &ctx);

                    // md是分配在栈上的，freeWhenDone为NO
                    NSData * mdData = [NSData dataWithBytesNoCopy:md length:CC_MD5_DIGEST_LENGTH freeWhenDone:NO];
                    MD5 = [XDTAFNSData toHexadecimalString:mdData];
                }
            }
        }
    } @catch (NSException *exception) {
        // Eat
    } @finally {
        if(readStream) {
            CFReadStreamClose(readStream);
            CFRelease(readStream);
        }

        if(URLRef) {
            CFRelease(URLRef);
        }
    }

    return MD5;
}

@end
