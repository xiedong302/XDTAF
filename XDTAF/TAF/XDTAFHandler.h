//
//  XFTAFHandler.h
//  XDTAF
//
//  Created by xiedong on 2021/2/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^post_block_t)(void);

@protocol XDTAFHandlerDelegate <NSObject>

@optional

-(void)handleMessage:(int)what object:(id)anObject;

@end

@interface XDTAFHandler : NSObject

@property (nonatomic, assign) BOOL debugMode;

/*!
 * @abstract
 * 创建一个在main queue上的Handler
 *
 * @param delegate
 * 消息处理delegate
 */
+(instancetype)mainHandlerWithDelegate:(id<XDTAFHandlerDelegate>)delegate;

/*!
 * @abstract
 * 创建一个Handler, 使用内部创建的serial queue
 *
 * @param name
 * queue的名字, 默认为"XDTAFHandler"
 *
 * @param delegate
 * 消息处理delegate
 */
-(instancetype)initWithName:(NSString *)name delegate:(id<XDTAFHandlerDelegate>)delegate;

/*!
 * @abstract
 * 使用自定义的queue创建一个Handler, 必须为serial queue
 *
 * @param queue
 * 自定义的serial queue
 *
 * @param delegate
 * 消息处理delegate
 */
-(instancetype)initWithSerialQueue:(dispatch_queue_t)queue delegate:(id<XDTAFHandlerDelegate>)delegate;

/*!
 * @abstract
 * 发送消息
 *
 * @param what
 * 自定义的消息标识
 */
-(void)sendMessage:(int)what;

/*!
 * @abstract
 * 发送消息
 *
 * @param what
 * 自定义的消息标识
 *
 * @param anObject
 * 附带的参数
 */
-(void)sendMessage:(int)what object:(id)anObject;

/*!
 * @abstract
 * 发送延时执行的消息
 *
 * @param what
 * 自定义的消息标识
 *
 * @param delayTime
 * 延时毫秒数
 */
-(void)sendMessageDelayed:(int)what delayMillis:(uint64_t)delayTime;

/*!
 * @abstract
 * 发送延时执行的消息
 *
 * @param what
 * 自定义的消息标识
 *
 * @param anObject
 * 附带的参数
 *
 * @param delayTime
 * 延时毫秒数
 */
-(void)sendMessageDelayed:(int)what object:(id)anObject delayMillis:(uint64_t)delayTime;

/*!
 * @abstract
 * 发送block消息
 *
 * @param block
 * 执行的block
 *
 * @param key
 * block标识字符串, 用于移除时使用
 */
-(void)postBlock:(post_block_t)block forKey:(NSString *)key;

/*!
 * @abstract
 * 发送延时执行的block消息
 *
 * @param block
 * 执行的block
 *
 * @param key
 * block标识字符串, 用于移除时使用
 *
 * @param delayTime
 * 延时毫秒数
 */
-(void)postBlockDelayed:(post_block_t)block forKey:(NSString *)key delayMillis:(uint64_t)delayTime;

/*!
 * @abstract
 * 发送selector消息
 *
 * @param target
 * target
 *
 * @param selector
 * selector
 */
-(void)postSelector:(id)target selector:(SEL)selector;

/*!
 * @abstract
 * 发送selector消息
 *
 * @param target
 * target
 *
 * @param selector
 * selector
 *
 * @param anObject
 * 附带的参数
 */
-(void)postSelector:(id)target selector:(SEL)selector object:(id)anObject;

/*!
 * @abstract
 * 发送延时执行的selector消息
 *
 * @param target
 * target
 *
 * @param selector
 * selector
 *
 * @param delayTime
 * 延时毫秒数
 */
-(void)postSelectorDelayed:(id)target selector:(SEL)selector delayMillis:(uint64_t)delayTime;

/*!
 * @abstract
 * 发送延时执行的selector消息
 *
 * @param target
 * target
 *
 * @param selector
 * selector
 *
 * @param anObject
 * 附带的参数
 *
 * @param delayTime
 * 延时毫秒数
 */
-(void)postSelectorDelayed:(id)target selector:(SEL)selector object:(id)anObject delayMillis:(uint64_t)delayTime;

/*!
 * @abstract
 * 移除对应标识的所有待执行消息
 *
 * @param what
 * 消息标识
 */
-(void)removeMessage:(int)what;

/*!
 * @abstract
 * 移除对应标识的所有待执行block
 *
 * @param key
 * block标识
 */
-(void)removeBlockWithKey:(NSString *)key;

/*!
 * @abstract
 * 移除待执行selector
 *
 * @param target
 * target
 *
 * @param selector
 * selector
 */
-(void)removeSelector:(id)target selector:(SEL)selector;

/*!
 * @abstract
 * 移除所有待执行的消息和block
 */
-(void)removeAll;

@end

NS_ASSUME_NONNULL_END

