//
//  XFTAFHandler.m
//  XDTAF
//
//  Created by xiedong on 2021/2/4.
//

#include <sys/sysctl.h>
#include <sys/time.h>

#import "XDTAFHandler.h"

// MARK: XDTAFHandlerMessage

@interface XDTAFHandlerMessage : NSObject

@property (nonatomic, assign) uint64_t msgId;
@property (nonatomic, strong) id object;

// For sendMessage
@property (nonatomic, assign) int what;

// For postBlock
@property (nonatomic, copy) post_block_t block;
@property (nonatomic, copy) NSString * blockKey;

// For postSelector
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL selector;

@property (nonatomic, assign) uint64_t triggerTime;

@property (nonatomic, strong) XDTAFHandlerMessage * next;

@end

@implementation XDTAFHandlerMessage
@end

// MARK: XDTAFHandler

@interface XDTAFHandler ()

@property (nonatomic, weak) id<XDTAFHandlerDelegate> delegate;

// 单向链表结构
@property (nonatomic, strong) XDTAFHandlerMessage * messages;

@property (nonatomic, assign) uint64_t messageId;

@property (nonatomic, strong) dispatch_queue_t myQueue;

@property (nonatomic, strong) dispatch_source_t myTimer;

@property (nonatomic, strong) NSMutableString * reuseLogString;

-(void)log:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

@end

@implementation XDTAFHandler {
    void * myQueueSpecific;
}

+(instancetype)mainHandlerWithDelegate:(id<XDTAFHandlerDelegate>)delegate {
    return [[XDTAFHandler alloc] initWithSerialQueue:dispatch_get_main_queue()
                                            delegate:delegate];
}

-(instancetype)initWithName:(NSString *)name delegate:(id<XDTAFHandlerDelegate>)delegate {
    if(!name || name.length <= 0) {
        name = @"XDTAFHandler";
    }

    return [self initWithSerialQueue:dispatch_queue_create([name UTF8String], DISPATCH_QUEUE_SERIAL)
                            delegate:delegate];
}

-(instancetype)initWithSerialQueue:(dispatch_queue_t)queue delegate:(id<XDTAFHandlerDelegate>)delegate {
    self = [super init];
    
    if (self) {
        self.delegate = delegate;
        
        _messageId = 0;

        _myQueue = queue;

        myQueueSpecific = &myQueueSpecific;

        void * nonNullUnusedPointer = (__bridge void *)self;
        
        dispatch_queue_set_specific(_myQueue, myQueueSpecific, nonNullUnusedPointer, NULL);
        
        _myTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _myQueue);
        
        __weak typeof(self) weakself = self;
        
        dispatch_source_set_event_handler(_myTimer, ^{
            __strong XDTAFHandler * strongSelf = weakself;
            
            if(strongSelf) {
                [strongSelf dequeueMessage];
            }
        });
        dispatch_resume(_myTimer);
        
        _reuseLogString = [NSMutableString stringWithCapacity:256];

        _debugMode = NO;
    }
    
    return self;
}

-(void)dealloc {
    [self log:@"[XDTAFHandler] dealloc"];

    dispatch_source_cancel(self.myTimer);

    if (dispatch_get_specific(myQueueSpecific)) {
        self.messages = nil;
    } else {
        dispatch_sync(self.myQueue, ^{
            self.messages = nil;
        });
    }
}

// MARK: Public

-(void)sendMessage:(int)what {
    [self sendMessageDelayed:what delayMillis:0];
}

-(void)sendMessage:(int)what object:(id)anObject {
    [self sendMessageDelayed:what object:anObject delayMillis:0];
}

-(void)sendMessageDelayed:(int)what delayMillis:(uint64_t)delayTime {
    [self sendMessageDelayed:what object:nil delayMillis:delayTime];
}

-(void)sendMessageDelayed:(int)what object:(id)anObject delayMillis:(uint64_t)delayTime {
    XDTAFHandlerMessage * message = [[XDTAFHandlerMessage alloc] init];
    message.what = what;
    message.object = anObject;
    message.triggerTime = [self getTriggerTime:delayTime];

    [self enqueueMessage:message];
}

-(void)postBlock:(post_block_t)block forKey:(NSString *)key {
    [self postBlockDelayed:block forKey:key delayMillis:0];
}

-(void)postBlockDelayed:(post_block_t)block forKey:(NSString *)key delayMillis:(uint64_t)delayTime {
    if(block) {
        XDTAFHandlerMessage * message = [[XDTAFHandlerMessage alloc] init];
        message.block = block;
        message.blockKey = key;
        message.triggerTime = [self getTriggerTime:delayTime];

        [self enqueueMessage:message];
    }
}

-(void)postSelector:(id)target selector:(SEL)selector {
    [self postSelectorDelayed:target selector:selector delayMillis:0];
}

-(void)postSelector:(id)target selector:(SEL)selector object:(id)anObject {
    [self postSelectorDelayed:target selector:selector object:anObject delayMillis:0];
}

-(void)postSelectorDelayed:(id)target selector:(SEL)selector delayMillis:(uint64_t)delayTime {
    [self postSelectorDelayed:target selector:selector object:nil delayMillis:delayTime];
}

-(void)postSelectorDelayed:(id)target selector:(SEL)selector object:(id)anObject delayMillis:(uint64_t)delayTime {
    if(target && selector) {
        XDTAFHandlerMessage * message = [[XDTAFHandlerMessage alloc] init];
        message.target = target;
        message.selector = selector;
        message.object = anObject;
        message.triggerTime = [self getTriggerTime:delayTime];
        
        [self enqueueMessage:message];
    }
}

-(void)removeMessage:(int)what {
    dispatch_async(self.myQueue, ^{
        [self log:@"[XDTAFHandler] removeMessage %i", what];

        XDTAFHandlerMessage * current = self.messages;

        // 移除前面的
        while(current && current.what == what) {
            self.messages = current.next;
            current = current.next;
        }
        
        XDTAFHandlerMessage * next = nil;

        // 移除后面的
        while(current) {
            next = current.next;

            if(next && next.what == what) {
                current.next = next.next;
                continue;
            }

            current = next;
        }

        [self scheduleNextTimer];
    });
}

-(void)removeBlockWithKey:(NSString *)key {
    if(!key) {
        return;
    }

    dispatch_async(self.myQueue, ^{
        [self log:@"[XDTAFHandler] removeBlockWithKey %@", key];

        XDTAFHandlerMessage * current = self.messages;

        // 移除前面的
        while(current && current.blockKey && [current.blockKey isEqualToString:key]) {
            self.messages = current.next;
            current = current.next;
        }

        XDTAFHandlerMessage * next = nil;
        
        // 移除后面的
        while(current) {
            next = current.next;
            
            if(next && next.blockKey && [next.blockKey isEqualToString:key]) {
                current.next = next.next;
                continue;
            }

            current = next;
        }

        [self scheduleNextTimer];
    });
}

-(void)removeSelector:(id)target selector:(SEL)selector {
    if(!target || !selector) {
        return;
    }

    dispatch_async(self.myQueue, ^{
        [self log:@"[XDTAFHandler] removeSelector %s:%s",
         object_getClassName(target),
         sel_getName(selector)];

        XDTAFHandlerMessage * current = self.messages;

        NSString * selectorName = NSStringFromSelector(selector);
        NSString * mySelectorName = nil;

        // 移除前面的
        while(current && current.target && current.selector) {
            mySelectorName = NSStringFromSelector(current.selector);

            if(current.target == target && [mySelectorName isEqualToString:selectorName]) {
                self.messages = current.next;
                current = current.next;
            } else {
                break;
            }
        }
        
        XDTAFHandlerMessage * next = nil;

        // 移除后面的
        while(current) {
            next = current.next;

            if(next && next.target && next.selector) {
                mySelectorName = NSStringFromSelector(next.selector);

                if(next.target == target && [mySelectorName isEqualToString:selectorName]) {
                    current.next = next.next;
                    continue;
                }
            }

            current = next;
        }

        [self scheduleNextTimer];
    });
}

-(void)removeAll {
    dispatch_async(self.myQueue, ^{
        [self log:@"[XDTAFHandler] removeAll"];

        self.messages = nil;
    });
}

// MARK: Private

-(void)enqueueMessage:(XDTAFHandlerMessage *)message {
    dispatch_async(self.myQueue, ^{
        message.msgId = self.messageId++;

        [self log:@"[XDTAFHandler] enqueueMessage %"PRIu64" trigger at %"PRIu64, message.msgId, message.triggerTime];

        XDTAFHandlerMessage * prev = nil;
        XDTAFHandlerMessage * current = self.messages;

        if(!current || message.triggerTime == 0 || message.triggerTime < current.triggerTime) {
            message.next = current;
            self.messages = message;
        } else {
            for(;;) {
                prev = current;
                current = current.next;

                if(!current || message.triggerTime < current.triggerTime) {
                    break;
                }
            }

            prev.next = message;
            message.next = current;
        }

        [self scheduleNextTimer];
    });
}

-(void)dequeueMessage {
    XDTAFHandlerMessage * current = self.messages;

    if(current) {
        [self log:@"[XDTAFHandler] dequeueMessage"];

        uint64_t now = [self systemUptime];

        if(current.triggerTime <= now) {
            [self log:@"[XDTAFHandler] dequeueMessage %"PRIu64, current.msgId];

            if(current.target && current.selector) {
                __strong id strongTarget = current.target;

                if(strongTarget && [strongTarget respondsToSelector:current.selector]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [strongTarget performSelector:current.selector withObject:current.object];
                    #pragma clang diagnostic pop
                }
            } else if(current.block) {
                current.block();
            } else {
                __strong id<XDTAFHandlerDelegate> strongDelegate = self.delegate;

                if(strongDelegate && [strongDelegate respondsToSelector:@selector(handleMessage:object:)]) {
                    [strongDelegate handleMessage:current.what object:current.object];
                }
            }

            self.messages = current.next;
        }

        [self scheduleNextTimer];
    }
}

-(void)scheduleNextTimer {
    [self printQueue];

    XDTAFHandlerMessage * current = self.messages;

    if(current) {
        uint64_t now = [self systemUptime];
        uint64_t delay = MAX(0, current.triggerTime - now);

        // delay值很小的话, 就直接dequeue
        // 这么做的原因是为了避免频繁enqueue导致timer一直被reset, 消息持续无法执行
        if(delay <= 10) {
            dispatch_async(self.myQueue, ^{
                [self dequeueMessage];
            });
        } else {
            dispatch_source_set_timer(self.myTimer,
                                      dispatch_walltime(NULL, delay * NSEC_PER_MSEC),
                                      DISPATCH_TIME_FOREVER,
                                      0);
        }
    }
}

-(void)printQueue {
    if(!self.debugMode) {
        return;
    }

    NSMutableString * queueInfo = self.reuseLogString;

    XDTAFHandlerMessage * current = self.messages;

    [queueInfo setString:@"{ "];

    while(current) {
        if(current.block) {
            [queueInfo appendFormat:@"(id: %"PRIu64" key: %@ time: %"PRIu64")", current.msgId, current.blockKey, current.triggerTime];
        } else {
            [queueInfo appendFormat:@"(id: %"PRIu64" what: %i time: %"PRIu64")", current.msgId, current.what, current.triggerTime];
        }

        current = current.next;

        if(current) {
            [queueInfo appendString:@" -> "];
        }
    }

    [queueInfo appendString:@" }"];

    [self log:@"[XDTAFHandler] %@", queueInfo];
}

-(uint64_t)getTriggerTime:(uint64_t)delay {
    uint64_t now = [self systemUptime];

    return now + delay;
}

- (uint64_t)systemUptime {
    uint64_t uptime = 0;

    struct timeval now;
    struct timezone tz;
    gettimeofday(&now, &tz);

    struct timeval boottime;
    int mib[2] = { CTL_KERN, KERN_BOOTTIME };
    size_t size = sizeof(boottime);

    if(sysctl(mib, 2, &boottime, &size, NULL, 0) != -1 && boottime.tv_sec != 0) {
        uptime = (uint64_t)
            ((now.tv_sec - boottime.tv_sec) * 1000.0 +
            (now.tv_usec - boottime.tv_usec) / 1000.0);
    }

    return uptime;
}

-(void)log:(NSString *)format, ... {
    if(!self.debugMode) {
        return;
    }

    va_list args;
    va_start(args, format);
    
    NSLogv(format, args);
    
    va_end(args);
}

@end

