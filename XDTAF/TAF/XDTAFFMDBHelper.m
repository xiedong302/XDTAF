//
//  XDTAFFMDBHelper.m
//  XDTAF
//
//  Created by xiedong on 2021/2/4.
//

#import "XDTAFFMDBHelper.h"

// MARK: XDTAFFMDBThread

#define MAX_THREAD_POOL_SIZE (3)

@interface XDTAFFMDBThread : NSObject

@property (nonatomic, readonly, strong) NSThread * thread;
@property (nonatomic, readonly, assign) BOOL standalone;
@property (nonatomic, assign) NSInteger referenceCount;

@end

@implementation XDTAFFMDBThread {
    volatile BOOL _cancelled;
}

- (instancetype)initWithThread:(NSThread *)thread standalone:(BOOL)standalone {
    self = [super init];
    
    if (self) {
        _thread = thread;
        _standalone = standalone;
        _referenceCount = 1;
    }
    
    return self;
}

-(void)dealloc {
    NSLog(@"[XDTAFFMDBThread] Dealloc: %@", self);
}

// MARK: Public

-(void)dispatchAsync:(dispatch_block_t)block {
    if(!_cancelled && _referenceCount > 0) {
        [self performSelector:@selector(runBlock:)
                     onThread:_thread
                   withObject:block
                waitUntilDone:NO
                        modes:[self modes]];
    }
}

-(void)dispatchSync:(dispatch_block_t)block {
    if(!_cancelled && _referenceCount > 0) {
        [self performSelector:@selector(runBlock:)
                     onThread:_thread
                   withObject:block
                waitUntilDone:YES
                        modes:[self modes]];
    }
}

-(void)cancel {
    _cancelled = YES;
    
    [self performSelector:@selector(runBlock:)
                 onThread:_thread
               withObject:^{
                   NSLog(@"[XDTAFFMDBThreadPool] Cancel: %@", self);
                   
                   [NSThread.currentThread cancel];
               }
            waitUntilDone:NO
                    modes:[self modes]];
}

-(NSString *)description {
    return [NSString stringWithFormat:@"%@[%@,%@,%@]", _thread.name, @(_referenceCount), @(_standalone), @(_cancelled)];
}

// MARK: Private

-(void)runBlock:(dispatch_block_t)block {
    if(block) {
        block();
    }
}

-(NSArray *)modes {
    static NSArray * modes;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        modes = @[NSDefaultRunLoopMode];
    });
    
    return modes;
}

@end

// MARK: XDTAFFMDBThreadPool

@interface XDTAFFMDBThreadPool : NSObject
@end

@implementation XDTAFFMDBThreadPool {
    int _threadIndex;
    NSMutableArray * _threads;
    dispatch_semaphore_t _lock;
}

+(XDTAFFMDBThreadPool *)instance {
    static XDTAFFMDBThreadPool * instance;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XDTAFFMDBThreadPool alloc] init];
    });
    
    return instance;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _threadIndex = 0;
        _threads = [NSMutableArray arrayWithCapacity:MAX_THREAD_POOL_SIZE];
        _lock = dispatch_semaphore_create(1);
    }
    
    return self;
}

-(XDTAFFMDBThread *)obtain {
    return [self obtain:NO];
}

-(XDTAFFMDBThread *)obtain:(BOOL)standalone {
    XDTAFFMDBThread * thread = nil;
    
    // 选取策略:
    // 1.线程数<MAX_THREAD_POOL_SIZE, 创建新线程
    // 2.线程数>=MAX_THREAD_POOL_SIZE, 选择referenceCount最少的
    // 3.standalone=YES, 独占模式, 这个线程referenceCount只能为1, 所以总会创建新线程
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    
    if(_threads.count >= MAX_THREAD_POOL_SIZE) {
        for (XDTAFFMDBThread * temp in _threads) {
            if(temp.standalone) {
                continue;
            }
            
            if(!thread || thread.referenceCount > temp.referenceCount) {
                thread = temp;
            }
        }
    }
    
    if(thread) {
        thread.referenceCount += 1;
    }
    
    if(!thread) {
        NSThread * t = [[NSThread alloc] initWithTarget:self selector:@selector(threadStart:) object:nil];
        t.name = [NSString stringWithFormat:@"XDTAFFMDBThread[%d]", _threadIndex++];
        if (@available(iOS 8.0, *)) {
            t.qualityOfService = NSQualityOfServiceBackground;
        } else {
            t.threadPriority = 0.3;
        }
        [t start];
        
        thread = [[XDTAFFMDBThread alloc] initWithThread:t standalone:standalone];
        
        NSLog(@"[XDTAFFMDBThreadPool] Create thread: %@", thread);
        
        [_threads addObject:thread];
        
        NSLog(@"[XDTAFFMDBThreadPool] Obtain pool count: %@", @(_threads.count));
    }
    
    dispatch_semaphore_signal(_lock);
    
    NSLog(@"[XDTAFFMDBThreadPool] Obtain thread: %@", thread);
    
    return thread;
}

-(void)release:(XDTAFFMDBThread *)thread {
    NSLog(@"[XDTAFFMDBThreadPool] Release thread: %@", thread);
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    
    if(thread.referenceCount - 1 <= 0) {
        [thread cancel];
        
        [_threads removeObject:thread];
        
        NSLog(@"[XDTAFFMDBThreadPool] Release pool count: %@", @(_threads.count));
    }
    
    thread.referenceCount -= 1;
    
    dispatch_semaphore_signal(_lock);
}

-(void)threadStart:(id)__unused object {
    @autoreleasepool {
        NSThread * thread = NSThread.currentThread;
        NSRunLoop * runLoop = NSRunLoop.currentRunLoop;
        
        NSLog(@"[XDTAFFMDBThreadPool] Thread start: %@", thread.name);
        
        NSPort * stubPort = [NSMachPort port];
        
        [runLoop addPort:stubPort forMode:NSDefaultRunLoopMode];
        
        while (!thread.isCancelled) {
            NSLog(@"[XDTAFFMDBThreadPool] Thread run: %@", thread.name);
            
            [runLoop runMode:NSDefaultRunLoopMode beforeDate:NSDate.distantFuture];
        }
        
        [runLoop removePort:stubPort forMode:NSDefaultRunLoopMode];
        
        NSLog(@"[XDTAFFMDBThreadPool] Thread quit: %@", thread.name);
    }
}

@end

// MARK: XDTAFFMDBHelper

@interface XDTAFFMDBHelper ()

@property (nonatomic, copy) NSString * dbName;
@property (nonatomic, copy) NSString * dbPath;
@property (nonatomic, assign) int newVersion;

@property (nonatomic, strong) XDTAFFMDatabase * myDatabase;

@end

@implementation XDTAFFMDBHelper {
    XDTAFFMDBThread * _myThread;
}

// MARK: Init

- (instancetype)initWithName:(NSString *)dbName version:(int)version {
    return [self initWithName:dbName version:version standalone:NO];
}

- (instancetype)initWithName:(NSString *)dbName version:(int)version standalone:(BOOL)standalone {
    self = [super init];

    if (self) {
        if(!dbName || dbName.length <= 0) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException
                                           reason:@"dbName is empty"
                                         userInfo:nil];
        }

        if(version <= 0) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException
                                           reason:@"version is <= 0"
                                         userInfo:nil];
        }

        NSFileManager * fileManager = [NSFileManager defaultManager];

        NSString * docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];

        BOOL isDir = NO;
        BOOL isExists = NO;

        // 兼容旧数据库路径
        // 先判断/Documents/database/下面有没有
        NSString * dbDir1 = [docDir stringByAppendingPathComponent:@"database"];
        NSString * dbPath = [dbDir1 stringByAppendingPathComponent:dbName];

        isExists = [fileManager fileExistsAtPath:dbPath isDirectory:&isDir];

        // 旧数据库不存在
        if(!isExists || isDir) {
            NSString * dbDir2 = [docDir stringByAppendingPathComponent:@"databases"];

            isExists = [fileManager fileExistsAtPath:dbDir2 isDirectory:&isDir];

            if(!isExists || !isDir) {
                [fileManager createDirectoryAtPath:dbDir2
                       withIntermediateDirectories:YES
                                        attributes:nil
                                             error:nil];
            }

            dbPath = [dbDir2 stringByAppendingPathComponent:dbName];
        }

        _dbName = [dbName copy];
        _dbPath = [dbPath copy];
        _newVersion = version;

        _myThread = [[XDTAFFMDBThreadPool instance] obtain:standalone];
    }

    return self;
}

- (void)dealloc {
    [self close];
    
    [[XDTAFFMDBThreadPool instance] release:_myThread];
}

// MARK: Public

- (int)databaseOnAdjustVersion:(XDTAFFMDatabase *)db {
    // Implement in child
    return 0;
}

- (BOOL)databaseOnCreate:(XDTAFFMDatabase *)db {
    // Implement in child
    return YES;
}

- (BOOL)databaseOnUpgrade:(XDTAFFMDatabase *)db oldVersion:(int)oldVersion newVersion:(int)newVersion {
    // Implement in child
    return YES;
}

- (BOOL)databaseOnDowngrade:(XDTAFFMDatabase *)db oldVersion:(int)oldVersion newVersion:(int)newVersion {
    // Implement in child
    return YES;
}

- (void)databaseOnOpenError:(NSString *)dbPath {
    // Implement in child
}

- (void)inDatabase:(__attribute__((noescape)) void (^)(XDTAFFMDatabase *db))block {
    dispatch_block_t myBlock = ^{
        XDTAFFMDatabase * db = [self openDatabase];

        if(db) {
            block(db);

            if([db hasOpenResultSets]) {
                NSException * e = [NSException exceptionWithName:@"XDTAFFMDBHelperException"
                                                          reason:@"ResultSet not close"
                                                        userInfo:nil];

                @throw e;
            }
        }
    };

    if (NSThread.currentThread == _myThread.thread) {
        myBlock();
    } else {
        [_myThread dispatchSync:myBlock];
    }
}

- (void)inTransaction:(__attribute__((noescape)) void (^)(XDTAFFMDatabase *db, BOOL *rollback))block {
    dispatch_block_t myBlock = ^{
        XDTAFFMDatabase * db = [self openDatabase];

        if(db) {
            if([db beginTransaction]) {
                BOOL shouldRollback = NO;

                block(db, &shouldRollback);

                if([db hasOpenResultSets]) {
                    NSException * e = [NSException exceptionWithName:@"XDTAFFMDBHelperException"
                                                              reason:@"ResultSet not close"
                                                            userInfo:nil];

                    @throw e;
                }

                if(shouldRollback) {
                    [db rollback];
                } else {
                    [db commit];
                }
            }
        }
    };

    if (NSThread.currentThread == _myThread.thread) {
        myBlock();
    } else {
        [_myThread dispatchSync:myBlock];
    }
}

- (void)close {
    dispatch_block_t myBlock = ^{
        XDTAFFMDatabase * db = self.myDatabase;
        self.myDatabase = nil;

        if(db) {
            [db close];
        }
    };

    if (NSThread.currentThread == _myThread.thread) {
        myBlock();
    } else {
        [_myThread dispatchSync:myBlock];
    }
}

- (BOOL)setVersion:(int)version {
    __block BOOL result = NO;

    [self inDatabase:^(XDTAFFMDatabase *db) {
        result = [db executeUpdate:[NSString stringWithFormat:@"PRAGMA user_version = %d;", version]];
    }];

    return result;
}

// MARK: Private

- (XDTAFFMDatabase *)openDatabase {
    if(!self.myDatabase) {
        NSString * dbPath = self.dbPath;

        XDTAFFMDatabase * db = [XDTAFFMDatabase databaseWithPath:dbPath];

        // 测试数据库是否损坏
        BOOL success = [db open] && [db goodConnection];

        if(success) {
            // 检查版本
            int oldVersion = 0;
            int newVersion = self.newVersion;

            XDTAFFMResultSet * set = [db executeQuery:@"PRAGMA user_version;"];

            if(set) {
                if([set next]) {
                    oldVersion = [set intForColumnIndex:0];
                }

                [set close];
            }

            NSLog(@"[XDTAFFMDBHelper] Open database %@ with version (%d,%d)", dbPath, oldVersion, newVersion);

            // 这是一段兼容逻辑
            // 如果数据库有数据, 但是版本号为0, 给一个机会让外部重置一下版本
            if(oldVersion == 0) {
                BOOL needAdjust = NO;

                XDTAFFMResultSet * set = [db executeQuery:@"SELECT COUNT(*) FROM sqlite_master WHERE type = 'table';"];

                if(set) {
                    if([set next]) {
                        needAdjust = [set intForColumnIndex:0] > 0;
                    }

                    [set close];
                }

                if(needAdjust) {
                    int adjustVersion = [self databaseOnAdjustVersion:db];

                    if(adjustVersion > 0) {
                        if([db executeUpdate:[NSString stringWithFormat:@"PRAGMA user_version = %d;", adjustVersion]]) {
                            oldVersion = adjustVersion;
                        } else {
                            NSLog(@"[XDTAFFMDBHelper] Adjust database %@ failed", dbPath);

                            [db close];
                            
                            return nil;
                        }
                    }
                }
            }

            if(oldVersion != newVersion) {
                if([db beginTransaction]) {
                    BOOL result = YES;

                    if(oldVersion == 0) {
                        result = [self databaseOnCreate:db];
                    } else if(oldVersion < newVersion) {
                        result = [self databaseOnUpgrade:db oldVersion:oldVersion newVersion:newVersion];
                    } else {
                        result = [self databaseOnDowngrade:db oldVersion:oldVersion newVersion:newVersion];
                    }

                    if(result) {
                        result = [db executeUpdate:[NSString stringWithFormat:@"PRAGMA user_version = %d;", newVersion]];
                    }

                    if(result) {
                        [db commit];
                    } else {
                        NSLog(@"[XDTAFFMDBHelper] Open database %@ failed", dbPath);

                        // 这里失败了不删库, 因为数据库本身是好的, 只是这次请求跪了
                        [db rollback];
                        [db close];

                        return nil;
                    }
                }
            }

            self.myDatabase = db;
        } else {
            NSLog(@"[XDTAFFMDBHelper] Database %@ corrupted", dbPath);

            [db close];

            // sudo rm -rf, 跑路
            [[NSFileManager defaultManager] removeItemAtPath:dbPath error:nil];

            [self databaseOnOpenError:dbPath];

            return nil;
        }
    }

    return self.myDatabase;
}

@end
