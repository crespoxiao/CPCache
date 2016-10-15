//
//  CFXCache.m
//  Pods
//
//  Created by xiaochengfei on 16/10/10.
//
//

#import "CFXCache.h"

static NSString * const CFX_CacheShared = @"CFX_CacheShared";
static dispatch_semaphore_t _globalLock;


@interface CFXCache ()

@property (nonatomic,strong)NSMutableDictionary *memoryCacheDic;
@property (nonatomic,strong)NSURL *cacheURL;

@end



@implementation CFXCache

#pragma mark - set

+ (void)setObject:(nullable id <NSCoding>)object forKey:(nullable NSString *)key {
    
    if (object && key) {
        [[CFXCache sharedInstance].memoryCacheDic setValue:object forKey:key];
        [[CFXCache sharedInstance] syncCacheWithKey:key value:object];
    }
}

#pragma mark - get

+ (__nullable id)objectForKey:(nullable NSString *)key {
    
    if (!key) {
        return nil;
    }
    if ([[CFXCache sharedInstance].memoryCacheDic objectForKey:key]) {
        return [[CFXCache sharedInstance].memoryCacheDic objectForKey:key];
    } else {
        return [[CFXCache sharedInstance] getCacheDataWithKey:key];
    }
}

#pragma mark - remove

+ (void)removeObjectForKey:(nullable NSString *)key {
    
    if (!key) {
        return;
    }
    NSString *tmpKey = [NSString stringWithFormat:@"%@",key?:@""];
    if ([[CFXCache sharedInstance].memoryCacheDic objectForKey:tmpKey]) {
        [[CFXCache sharedInstance].memoryCacheDic removeObjectForKey:tmpKey];
    }
    [[CFXCache sharedInstance] syncCacheWithKey:tmpKey value:nil];
}

+ (void)removeAll {
    
    [[CFXCache sharedInstance]lock];
    if ([[CFXCache sharedInstance] moveItemAtURLToTrash:[CFXCache sharedInstance].cacheURL]) {
        [[CFXCache sharedInstance].memoryCacheDic removeAllObjects];
        [[CFXCache sharedInstance] emptyTrash];
    }
    [[CFXCache sharedInstance]unlock];
}

#pragma mark - init

+ (nonnull CFXCache *)sharedInstance {
    static CFXCache *infoInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        infoInstance = [[CFXCache alloc] init];
    });
    return infoInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _globalLock = dispatch_semaphore_create(1);
        _memoryCacheDic = [NSMutableDictionary dictionary];
        
        [self createCacheFolder];
    }
    return self;
}

#pragma mark - private methods

- (BOOL)createCacheFolder {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"%@",CFX_CacheShared]];
    _cacheURL = [NSURL fileURLWithPathComponents:@[cachePath]];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        BOOL success = [[NSFileManager defaultManager] createDirectoryAtURL:_cacheURL
                                                withIntermediateDirectories:YES
                                                                 attributes:nil
                                                                      error:nil];
        return success;
    }
    return YES;
}

- (nullable id)getCacheDataWithKey:(NSString *)keyName {
    [self lock];
    id <NSCoding> object = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[_cacheURL path]]) {
        
        NSArray *keys = @[NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey];
        NSError *error = nil;
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:_cacheURL
                                                       includingPropertiesForKeys:keys
                                                                          options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                            error:&error];
        for (NSURL *fileURL in files) {
            NSString *key = [self keyForEncodedFileURL:fileURL];
            if ([key isEqualToString:keyName]) {
                NSURL *fileURL = [self encodedFileURL:_cacheURL forKey:key];
                if ([[NSFileManager defaultManager] fileExistsAtPath:[fileURL path]]) {
                    @try {
                        object = [NSKeyedUnarchiver unarchiveObjectWithFile:[fileURL path]];
                        if (object) {
                            [_memoryCacheDic setObject:object forKey:key];
                        }
                    } @catch (NSException *exception) {
                        NSError *error = nil;
                        [[NSFileManager defaultManager] removeItemAtPath:[fileURL path] error:&error];
                    }
                }
                break;
            }
        }
    } else {
        [self createCacheFolder];
    }
    [self unlock];
    return object;
}

- (void)syncCacheWithKey:(NSString *)key value:(nullable id)object {
    [self lock];
    if ([self createCacheFolder]) {
        NSURL *fileURL = [self encodedFileURL:_cacheURL forKey:key];
        if (object) { //save
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object];
            NSDataWritingOptions writeOptions = NSDataWritingAtomic | NSDataWritingFileProtectionNone;
            [data writeToURL:fileURL options:writeOptions error:nil];
        } else { //delete
            [self moveItemAtURLToTrash:fileURL];
            [self emptyTrash];
        }
    }
    [self unlock];
}

- (NSURL *)encodedFileURL:(NSURL*)url forKey:(NSString *)key {
    if (!url || ![key length]) {
        return nil;
    }
    return [url URLByAppendingPathComponent:[self encodedString:key]];
}

- (NSString *)keyForEncodedFileURL:(NSURL *)url {
    NSString *fileName = [url lastPathComponent];
    if (!fileName){
        return nil;
    }
    return [self decodedString:fileName];
}

- (NSString *)encodedString:(NSString *)string {
    if (![string length]) {
        return @"";
    }
    if ([string respondsToSelector:@selector(stringByAddingPercentEncodingWithAllowedCharacters:)]) {
        return [string stringByAddingPercentEncodingWithAllowedCharacters:
                [[NSCharacterSet characterSetWithCharactersInString:@".:/%"] invertedSet]];
    } else {
        CFStringRef static const charsToEscape = CFSTR(".:/%");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CFStringRef escapedString = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                            (__bridge CFStringRef)string,
                                                                            NULL,
                                                                            charsToEscape,
                                                                            kCFStringEncodingUTF8);
#pragma clang diagnostic pop
        return (__bridge_transfer NSString *)escapedString;
    }
}

- (NSString *)decodedString:(NSString *)string {
    if (![string length]) {
        return @"";
    }
    if ([string respondsToSelector:@selector(stringByRemovingPercentEncoding)]) {
        return [string stringByRemovingPercentEncoding];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CFStringRef unescapedString = CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                                                              (__bridge CFStringRef)string,
                                                                                              CFSTR(""),
                                                                                              kCFStringEncodingUTF8);
#pragma clang diagnostic pop
        return (__bridge_transfer NSString *)unescapedString;
    }
}

#pragma mark - private trash methods

- (dispatch_queue_t)sharedTrashQueue {
    static dispatch_queue_t trashQueue;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        NSString *queueName = [[NSString alloc] initWithFormat:@"%@.trash", CFX_CacheShared];
        trashQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(trashQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
    });
    return trashQueue;
}

- (NSURL *)sharedTrashURL {
    NSURL *sharedTrashURL = [[[NSURL alloc] initFileURLWithPath:NSTemporaryDirectory()]
                             URLByAppendingPathComponent:CFX_CacheShared isDirectory:YES];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[sharedTrashURL path]]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtURL:sharedTrashURL
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:&error];
    }
    return sharedTrashURL;
}

- (BOOL)moveItemAtURLToTrash:(NSURL *)itemURL {
    if (!itemURL || ![[NSFileManager defaultManager] fileExistsAtPath:[itemURL path]]){
        return NO;
    }
    NSError *error = nil;
    NSString *uniqueString = [[NSProcessInfo processInfo] globallyUniqueString];
    NSURL *uniqueTrashURL = [[self sharedTrashURL] URLByAppendingPathComponent:uniqueString];
    BOOL moved = [[NSFileManager defaultManager] moveItemAtURL:itemURL toURL:uniqueTrashURL error:&error];
    return moved;
}

- (void)emptyTrash {
    dispatch_async([self sharedTrashQueue], ^{
        NSError *searchTrashedItemsError = nil;
        NSArray *trashedItems = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self sharedTrashURL]
                                                              includingPropertiesForKeys:nil
                                                                                 options:0
                                                                                   error:&searchTrashedItemsError];
        for (NSURL *trashedItemURL in trashedItems) {
            NSError *removeTrashedItemError = nil;
            [[NSFileManager defaultManager] removeItemAtURL:trashedItemURL error:&removeTrashedItemError];
        }
    });
}

#pragma mark - lock methods

- (void)lock {
    dispatch_semaphore_wait(_globalLock, DISPATCH_TIME_FOREVER);
}

- (void)unlock {
    dispatch_semaphore_signal(_globalLock);
}

@end
