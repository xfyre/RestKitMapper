//
//  RestKitMapper.h
//  RestKitMapper
//
//  Created by Ilya Obshadko on 17.09.14.
//  Copyright (c) 2014 xfyre.com. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const RKMRestKitMapperServerBaseKey;
extern NSString * const RKMRestKitMapperContextUrlKey;

@class AFHTTPClient;

@interface RKMRestKitMapper : NSObject

typedef void (^RKMRequestSuccess)(id result);
typedef void (^RKMRequestFailure)(NSError *error);

+ (instancetype)sharedInstance;
- (void)reconfigureWithBaseUrl: (NSURL*)url;
- (void)configureErrorMappingForClass:(Class)class withAttributes:(NSDictionary *)attributes;
- (void)get:(NSString *)uri cached:(BOOL)cached withParams:(NSDictionary *)params success:(RKMRequestSuccess)success failure:(RKMRequestFailure)failure;
- (NSArray *)get:(NSString *)requestName withParams:(NSDictionary *)parameters error: (NSError**)error;
- (void)post:(NSString *)uri withObject:(id)obj success:(RKMRequestSuccess)success failure:(RKMRequestFailure)failure;
- (void)fetch:(NSString *)requestName withParams:(NSDictionary *)params success:(RKMRequestSuccess)success failure:(RKMRequestFailure)failure;

- (AFHTTPClient*)HTTPClient;

@end
