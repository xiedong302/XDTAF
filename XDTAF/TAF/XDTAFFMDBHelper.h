//
//  XDTAFFMDBHelper.h
//  XDTAF
//
//  Created by xiedong on 2021/2/4.
//

#import <Foundation/Foundation.h>
#import <XDTAF/FMDB.h>

NS_ASSUME_NONNULL_BEGIN

@interface XDTAFFMDBHelper : NSObject

/*!
 * @abstract
 * 创建TAFFMDBHelper, 数据库路径为/Documents/databases
 *
 * @param dbName
 * 数据库名字, 不要传路径
 *
 * @param version
 * 数据库版本, 用于做升级、降级
 */
- (instancetype)initWithName:(NSString *)dbName version:(int)version;

/*!
 * @abstract
 * 创建TAFFMDBHelper, 数据库路径为/Documents/databases
 *
 * @param dbName
 * 数据库名字, 不要传路径
 *
 * @param version
 * 数据库版本, 用于做升级、降级
 *
 * @param standalone
 * 数据库是否拥有独立线程, 访问比较频繁或者数据量较大的数据库建议设置为YES
 */
- (instancetype)initWithName:(NSString *)dbName version:(int)version standalone:(BOOL)standalone;

/*!
 * @abstract
 * 子类可选实现
 * 主要用于旧库兼容, 返回旧数据库的版本号, 新数据库不需要实现
 *
 * @param db
 * 数据库
 *
 * @return
 * 旧数据库版本
 */
- (int)databaseOnAdjustVersion:(XDTAFFMDatabase *)db;

/*!
 * @abstract
 * 子类可选实现
 * 新创建数据库, 创建数据库表的操作放在这里, 这个方法在transaction中执行
 *
 * @param db
 * 数据库
 *
 * @return
 * YES 操作成功, NO 操作失败, 操作失败会回滚
 */
- (BOOL)databaseOnCreate:(XDTAFFMDatabase *)db;

/*!
 * @abstract
 * 子类可选实现
 * 数据库升级, 升级操作放在这里, 比如添加新表或者字段, 这个方法在transaction中执行
 *
 * @param db
 * 数据库
 *
 * @param oldVersion
 * 旧版本号
 *
 * @param newVersion
 * 新版本号
 *
 * @return
 * YES 操作成功, NO 操作失败, 操作失败会回滚
 */
- (BOOL)databaseOnUpgrade:(XDTAFFMDatabase *)db oldVersion:(int)oldVersion newVersion:(int)newVersion;

/*!
 * @abstract
 * 子类可选实现
 * 数据库降级, 降级操作放在这里, 一般不会发生, 切记不要在这个里面删除表或者字段, 这个方法在transaction中执行
 *
 * @param db
 * 数据库
 *
 * @param oldVersion
 * 旧版本号
 *
 * @param newVersion
 * 新版本号
 *
 * @return
 * YES 操作成功, NO 操作失败, 操作失败会回滚
 */
- (BOOL)databaseOnDowngrade:(XDTAFFMDatabase *)db oldVersion:(int)oldVersion newVersion:(int)newVersion;

/*!
 * @abstract
 * 子类可选实现
 * 数据库打开失败, 比如数据库损坏等等, 部分特殊场景可能需要自定义操作
 *
 * @param dbPath
 * 数据库全路径
 */
- (void)databaseOnOpenError:(NSString *)dbPath;

/*!
 * @abstract
 * 获取数据库来进行操作
 *
 * @param block
 * db 数据库
 */
- (void)inDatabase:(__attribute__((noescape)) void (^)(XDTAFFMDatabase *db))block;

/*!
 * @abstract
 * 获取数据库来进行操作, 会开启transaction, 需要执行多个数据库操作时需要用这个方法,
 *
 * @param block
 * db 数据库
 * rollback 可以不设置, 如果设置为YES, 则会回滚block中的相关操作
 */
- (void)inTransaction:(__attribute__((noescape)) void (^)(XDTAFFMDatabase *db, BOOL *rollback))block;

/*!
 * @abstract
 * 关闭数据库, 一般不需要主动调用
 */
- (void)close;

/*!
 * @abstract
 * 设置数据库版本, 这个接口目前主要用于旧库兼容
 *
 * @param version
 * 数据库版本
 *
 * @return
 * YES 操作成功, NO 操作失败
 */
- (BOOL)setVersion:(int)version;

@end

NS_ASSUME_NONNULL_END
