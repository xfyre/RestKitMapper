//
//  RestKitMapper.h
//  RestKitMapper
//
//  Created by Ilya Obshadko on 17.09.14.
//  Copyright (c) 2014 xfyre.com. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const RKMRestKitMapperModelNameKey;
extern NSString * const RKMRestKitMapperConfigFileKey;
extern NSString * const RKMRestKitMapperServerBaseKey;
extern NSString * const RKMRestKitMapperContextUrlKey;

@class AFHTTPClient;

/**
 Helper class providing declarative-style RestKit configuration using property files
 */
@interface RKMRestKitMapper : NSObject

typedef void (^RKMRequestSuccess)(id result);
typedef void (^RKMRequestFailure)(NSError *error);

/**
 Configure RestKitMapper
 */
+ (void)configureWithFileName:(NSString *)fileName serverBaseUrl:(NSString *)baseUrl contextUrl:(NSString *)contextUrl modelName:(NSString *)modelName;

/**
 Instantiate and configure RestKitMapper
 */
+ (instancetype)sharedInstance;

/**
 Reconfigure RestKitMapper with another base URL (for example when you need to switch between staging/production servers)
 */
- (void)reconfigureWithBaseUrl:(NSURL*)url;


/**
 Configure error mapping class for HTTP 40x-50x status codes.
 
 @param clazz error mapping class
 @param attributes attribute mappings
 */
- (void)configureErrorMappingForClass:(Class)clazz withAttributes:(NSDictionary *)attributes;

/**
 Retrieve relative URL. Success block receives NSArray of mapped items.
 */
- (void)get:(NSString *)uri cached:(BOOL)cached withParams:(NSDictionary *)params success:(RKMRequestSuccess)success failure:(RKMRequestFailure)failure;

/**
 Same as above, synchronously
 */
- (NSArray *)get:(NSString *)requestName withParams:(NSDictionary *)parameters error: (NSError**)error;

/**
 Post to relative URL. Object mapping must be configured.
 */
- (void)post:(NSString *)uri withObject:(id)obj success:(RKMRequestSuccess)success failure:(RKMRequestFailure)failure;

/**
 Put to relative URL. Object mapping must be configured.
 */
- (void)put:(NSString *)uri withObject:(id)obj success:(RKMRequestSuccess)success failure:(RKMRequestFailure)failure;

/**
 Perform named fetch request from underlying Core Data storage.
 */
- (void)fetch:(NSString *)requestName withParams:(NSDictionary *)params success:(RKMRequestSuccess)success failure:(RKMRequestFailure)failure;

/**
 Provide access to underlying AFNetworking AFHTTPClient object.
 
 @return shared HTTPClient instance
 */
- (AFHTTPClient*)HTTPClient;

@end
