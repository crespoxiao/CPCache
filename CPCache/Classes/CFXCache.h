//
//  CFXCache.h
//  Pods
//
//  Created by xiaochengfei on 16/10/10.
//
//

#import <Foundation/Foundation.h>


@interface CFXCache : NSObject

#pragma mark - set
/**
 *   the object must implement protocol NSCoding
 */
+ (void)setObject:(nullable id <NSCoding>)object forKey:(nullable NSString *)key;

#pragma mark - get

+ (__nullable id)objectForKey:(nullable NSString *)key;

#pragma mark - remove

+ (void)removeObjectForKey:(nullable NSString *)key;

+ (void)removeAll;

@end

