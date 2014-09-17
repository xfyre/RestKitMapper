//
//  RestKitMapper.m
//  RestKitMapper
//
//  Created by Ilya Obshadko on 17.09.14.
//  Copyright (c) 2014 xfyre.com. All rights reserved.
//

#import "RKMRestKitMapper.h"

#import <objc/runtime.h>
#import <RestKit/RestKit.h>

NSString * const RKMRestKitMapperServerBaseKey = @"RestKitMapperServerBase";
NSString * const RKMRestKitMapperContextUrlKey = @"RestKitMapperContextUrl";

@interface RKMRestKitMapper()

@property (nonatomic, strong) NSString *contextUrl;
@property (nonatomic, strong) NSString *serverBase;

@end

@interface RKMRestKitMapper(Private)

- (void)initDataLayerMappings;
- (void)initRESTKit;
- (NSArray *)dataLayerPathMappings;
- (NSArray *)dataLayerRequestMappings;
- (RKObjectMapping *)objectMappingForEntityName:(NSString *)name;
- (NSString *)fetchRequestForUri:(NSString *)uri withArgs:(NSMutableDictionary *)args;
- (void)setupHttpClient;

@end

@implementation RKMRestKitMapper

+ (RKMRestKitMapper *)sharedInstance
{
    static dispatch_once_t onceToken;
    static RKMRestKitMapper *instance;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        _serverBase = [[NSUserDefaults standardUserDefaults] stringForKey:RKMRestKitMapperServerBaseKey];
        _contextUrl = [[NSUserDefaults standardUserDefaults] stringForKey:RKMRestKitMapperContextUrlKey];

        if (_serverBase.length == 0)
            [NSException raise:NSInternalInconsistencyException format:@"Server base URL must be set in user defaults"];

        if ([NSURL URLWithString:[_serverBase stringByAppendingPathComponent:_contextUrl]] == nil)
            [NSException raise:NSInternalInconsistencyException format:@"Invalid server URL"];

        [self initDataLayerMappings];
        [self initRESTKit];
    }

    return self;
}

- (void)reconfigureWithBaseUrl:(NSURL*)url
{
    RKObjectManager *manager = [RKObjectManager sharedManager];
    manager.requestSerializationMIMEType = RKMIMETypeJSON;
    [manager setHTTPClient:[AFHTTPClient clientWithBaseURL:url]];
    [self setupHttpClient];

    for (RKResponseDescriptor *responseDescriptor in [RKObjectManager sharedManager].responseDescriptors)
        [responseDescriptor setBaseURL:[RKObjectManager sharedManager].baseURL];
}

- (AFHTTPClient *)HTTPClient
{
    return [RKObjectManager sharedManager].HTTPClient;
}

- (void)get:(NSString *)uri cached:(BOOL)cached withParams:(NSDictionary *)params success:(RKMRequestSuccess)success failure:(RKMRequestFailure)failure
{
    RKObjectManager * objectManager = [RKObjectManager sharedManager];

    if (!cached) {
        NSMutableURLRequest *request = [objectManager requestWithObject:nil
                                                                 method:RKRequestMethodGET
                                                                   path:[_contextUrl stringByAppendingPathComponent:uri]
                                                             parameters:params];

        RKManagedObjectRequestOperation *requestOperation =
        [objectManager managedObjectRequestOperationWithRequest:request
                                           managedObjectContext:objectManager.managedObjectStore.persistentStoreManagedObjectContext
                                                        success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
                                                            if (success)
                                                                success(mappingResult.array);
                                                        }
                                                        failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                                            if (failure)
                                                                failure(error);
                                                        }];

        [objectManager.operationQueue addOperation: requestOperation];
    } else {
        RKManagedObjectStore *store = objectManager.managedObjectStore;
        NSManagedObjectModel *model = store.managedObjectModel;
        NSManagedObjectContext *ctx = store.mainQueueManagedObjectContext;

        NSMutableDictionary *args = [params mutableCopy];
        NSString *fetchRequestName = [self fetchRequestForUri:uri withArgs:args];
        if (fetchRequestName) {
            NSFetchRequest *fetchRequest = [model fetchRequestFromTemplateWithName:fetchRequestName
                                                             substitutionVariables:args];
            [ctx performBlock:^{
                NSError *error = nil;
                NSArray *array = [ctx executeFetchRequest:fetchRequest error:&error];
                if (error)
                    failure(error);
                else
                    success(array);
            }];
        } else {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"path %@ didn't match any fetch requests", uri]
                                         userInfo:params];
        }
    }
}

- (void)fetch:(NSString *)requestName withParams:(NSDictionary *)parameters success:(RKMRequestSuccess)success failure:(RKMRequestFailure)failure
{
    RKObjectManager * objectManager = [RKObjectManager sharedManager];
    NSManagedObjectContext *moc = objectManager.managedObjectStore.mainQueueManagedObjectContext;
    NSManagedObjectModel *mom = objectManager.managedObjectStore.managedObjectModel;
    NSFetchRequest *fetchRequest = [mom fetchRequestFromTemplateWithName:requestName substitutionVariables:parameters];

    [moc performBlock:^{
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];

        if (error)
            failure(error);
        else
            success(results);
    }];
}

- (NSArray *)get:(NSString *)requestName withParams:(NSDictionary *)parameters error:(NSError *__autoreleasing *)error
{
    RKObjectManager * objectManager = [RKObjectManager sharedManager];
    NSManagedObjectContext *moc = objectManager.managedObjectStore.mainQueueManagedObjectContext;
    NSManagedObjectModel *mom = objectManager.managedObjectStore.managedObjectModel;
    NSFetchRequest *fetchRequest = [mom fetchRequestFromTemplateWithName:requestName substitutionVariables:parameters];

    __block NSArray *results = nil;

    [moc performBlockAndWait:^{
        results = [moc executeFetchRequest:fetchRequest error:error];
    }];

    return results;
}


- (void)post:(NSString *)uri withObject:(id)obj success:(RKMRequestSuccess)success failure:(RKMRequestFailure)failure
{
    RKObjectManager * objectManager = [RKObjectManager sharedManager];

    NSMutableURLRequest *request = [objectManager requestWithObject: obj
                                                             method: RKRequestMethodPOST
                                                               path: [_contextUrl stringByAppendingPathComponent:uri]
                                                         parameters: nil];

    RKManagedObjectRequestOperation *requestOperation =
    [objectManager managedObjectRequestOperationWithRequest:request
                                       managedObjectContext:objectManager.managedObjectStore.persistentStoreManagedObjectContext
                                                    success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
                                                        if (success)
                                                            success(mappingResult.array);
                                                    }
                                                    failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                                        if (failure)
                                                            failure(error);
                                                    }];

    [objectManager.operationQueue addOperation: requestOperation];
}

- (void)configureErrorMappingForClass:(Class)class withAttributes:(NSDictionary *)attributes
{
    // Configure error mappings
    RKObjectMapping *errorMapping = [RKObjectMapping mappingForClass:class];
    [attributes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [errorMapping addPropertyMapping: [RKAttributeMapping attributeMappingFromKeyPath:key toKeyPath:obj]];
    }];

    RKResponseDescriptor *serverErrorResponseDescriptor =
    [RKResponseDescriptor responseDescriptorWithMapping:errorMapping
                                                 method:RKRequestMethodAny
                                            pathPattern:nil
                                                keyPath:nil
                                            statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassServerError)];

    RKResponseDescriptor *clientErrorResponseDescriptor =
    [RKResponseDescriptor responseDescriptorWithMapping:errorMapping
                                                 method:RKRequestMethodAny
                                            pathPattern:nil
                                                keyPath:nil
                                            statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassClientError)];

    [[RKObjectManager sharedManager] addResponseDescriptorsFromArray:@[serverErrorResponseDescriptor, clientErrorResponseDescriptor]];
}

@end

@implementation RKMRestKitMapper(Private)

static NSDictionary *dataLayerMappings = nil;
static NSDictionary *objectMappings = nil;
static NSDictionary *fetchRequestMappings = nil;

-(void)setupHttpClient
{
    RKObjectManager *manager = [RKObjectManager sharedManager];
    [manager.HTTPClient registerHTTPOperationClass:[AFJSONRequestOperation class]];
    [manager.HTTPClient setParameterEncoding:AFJSONParameterEncoding];
    [manager.HTTPClient setDefaultHeader:@"Accept" value:@"application/json"];
    [manager.HTTPClient setDefaultHeader:@"Content-Type" value:@"application/json"];
    [manager setAcceptHeaderWithMIMEType:RKMIMETypeJSON];
}

- (void)initDataLayerMappings
{
    if (dataLayerMappings == nil) {
        NSString *mappingsFilePath = [[NSBundle mainBundle] pathForResource: @"iVViDataMappings" ofType: @"plist"];
        dataLayerMappings = [NSDictionary dictionaryWithContentsOfFile: mappingsFilePath];
    }
}

- (NSString *)fetchRequestForUri:(NSString *)uri withArgs:(NSMutableDictionary *)args
{
    __block NSString *result = nil;

    [fetchRequestMappings enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        RKPathMatcher *matcher = [RKPathMatcher pathMatcherWithPath:[_contextUrl stringByAppendingPathComponent:uri]];
        NSDictionary *dict = nil;
        if ([matcher matchesPattern:key tokenizeQueryStrings:YES parsedArguments:&dict]) {
            if (dict.count) [args addEntriesFromDictionary:dict];
            result = obj;
        }
    }];

    return result;
}

- (void)initRESTKit
{
    RKLogConfigureByName("RestKit", RKLogLevelOff);
    RKLogConfigureByName("RestKit/Network", RKLogLevelInfo);
    RKLogConfigureByName("RestKit/ObjectMapping", RKLogLevelInfo);

    NSURL *baseURL = [NSURL URLWithString:_serverBase];
    RKObjectManager *objectManager = [RKObjectManager managerWithBaseURL:baseURL];
    objectManager.requestSerializationMIMEType = RKMIMETypeJSON;
    [self setupHttpClient];

    NSURL *modelURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"iVVi" ofType:@"momd"]];
    NSString *storePath = [RKApplicationDataDirectory() stringByAppendingPathComponent:@"iVVi.sqlite"];
    NSError * error;

    // NOTE: Due to an iOS 5 bug, the managed object model returned is immutable.
    NSManagedObjectModel *managedObjectModel = [[[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL] mutableCopy];
    RKManagedObjectStore *managedObjectStore = [[RKManagedObjectStore alloc] initWithManagedObjectModel:managedObjectModel];

    // Initialize the Core Data stack
    [managedObjectStore createPersistentStoreCoordinator];
    NSPersistentStore __unused *persistentStore = [managedObjectStore addSQLitePersistentStoreAtPath:storePath
                                                                              fromSeedDatabaseAtPath:nil
                                                                                   withConfiguration:nil
                                                                                             options:nil
                                                                                               error:&error];
    NSAssert(persistentStore, @"Failed to add persistent store: %@", error);
    [managedObjectStore createManagedObjectContexts];

    // Set the default store shared instance
    [RKManagedObjectStore setDefaultStore:managedObjectStore];
    objectManager.managedObjectStore = managedObjectStore;

    [RKObjectManager setSharedManager:objectManager];

    // Enable Activity Indicator Spinner
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;

    NSMutableDictionary *fetchRequestsDict = [NSMutableDictionary dictionary];

    // Configure path mappings
    for ( NSDictionary *pathMappingInfo in self.dataLayerPathMappings ) {
        RKDynamicMapping *dynamicMapping = [RKDynamicMapping new];
        NSString *pathMappingUri = [_contextUrl stringByAppendingPathComponent: [pathMappingInfo objectForKey: @"uri"]];

        // configure attribute matchers
        NSArray *pathMappingMatchers = [pathMappingInfo objectForKey: @"matchers"];
        for ( NSDictionary *pathMappingMatcherInfo in pathMappingMatchers ) {
            NSString *keyPath = [pathMappingMatcherInfo objectForKey: @"key_path"];
            NSString *expectedValue = [pathMappingMatcherInfo objectForKey: @"expected_value"];
            NSString *entityName = [pathMappingMatcherInfo objectForKey: @"entity_name"];

            if (entityName) {
                RKObjectMapping *objectMapping = [self objectMappingForEntityName: entityName];

                if (keyPath && expectedValue) {
                    RKObjectMappingMatcher *matcher = [RKObjectMappingMatcher matcherWithKeyPath:keyPath
                                                                                   expectedValue:expectedValue
                                                                                   objectMapping:objectMapping];
                    [dynamicMapping addMatcher:matcher];
                } else {
                    [dynamicMapping setObjectMappingForRepresentationBlock:^RKObjectMapping *(id representation) {
                        return objectMapping;
                    }];
                }
            } else {
                NSString *className = [pathMappingMatcherInfo objectForKey:@"class_name"];
                Class mappingClass = className ? objc_getClass([className UTF8String]) : [NSDictionary class];
                RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:mappingClass];

                NSDictionary *attributeMappings = [pathMappingMatcherInfo objectForKey:@"attribute_mappings"];
                if ( attributeMappings != nil )
                    [objectMapping addAttributeMappingsFromDictionary: attributeMappings];

                [dynamicMapping setObjectMappingForRepresentationBlock:^RKObjectMapping *(id representation) {
                    return objectMapping;
                }];
            }
        }

        // add related database fetch request
        NSString *relatedFetchRequest = [pathMappingInfo objectForKey:@"fetch_request"];
        if (relatedFetchRequest) [fetchRequestsDict setObject:relatedFetchRequest forKey:pathMappingUri];

        // fetch request blocks for orphaned objects
        /*
         __block RKObjectManager *objectManagerRef = objectManager;
         [objectManager addFetchRequestBlock:^NSFetchRequest * (NSURL *URL) {
         RKPathMatcher *matcher = [RKPathMatcher pathMatcherWithPath:URL.relativePath];
         NSDictionary *argsDict = nil;
         if ([matcher matchesPattern:pathMappingUri tokenizeQueryStrings:YES parsedArguments:&argsDict]) {
         NSManagedObjectModel *model = objectManagerRef.managedObjectStore.managedObjectModel;
         // !!NB!!: substitution variables in path patterns must EXACTLY MATCH core data attribute names
         return [model fetchRequestFromTemplateWithName:relatedFetchRequest substitutionVariables:argsDict];
         }

         return nil;
         }];
         */

        // create response descriptor
        NSString *responseKeyPath = [pathMappingInfo objectForKey:@"key_path"];

        RKResponseDescriptor *responseDescriptor =
        [RKResponseDescriptor responseDescriptorWithMapping:dynamicMapping
                                                     method:RKRequestMethodAny
                                                pathPattern:pathMappingUri
                                                    keyPath:responseKeyPath
                                                statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];

        [objectManager addResponseDescriptor:responseDescriptor];
    }

    // Configure request mappings
    for (NSDictionary *requestMappingInfo in self.dataLayerRequestMappings) {
        NSString *className = [requestMappingInfo objectForKey:@"class_name"];
        NSString *rootKeypath = [requestMappingInfo objectForKey:@"root_keypath"];
        NSDictionary *attributeMappings = [requestMappingInfo objectForKey:@"attribute_mappings"];

        NSAssert(className, @"class_name is not defined in request mapping");
        NSAssert([attributeMappings isKindOfClass:[NSDictionary class]], @"attribute_mappings is not defined in request mapping");

        RKObjectMapping *requestMapping = [RKObjectMapping requestMapping];
        [requestMapping addAttributeMappingsFromDictionary:attributeMappings];

        RKRequestDescriptor *requestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:requestMapping
                                                                                       objectClass:objc_getClass([className UTF8String])
                                                                                       rootKeyPath:rootKeypath
                                                                                            method:RKRequestMethodAny];
        [[RKObjectManager sharedManager] addRequestDescriptor:requestDescriptor];
    }


    fetchRequestMappings = [NSDictionary dictionaryWithDictionary:fetchRequestsDict];
}

- (NSArray *)dataLayerPathMappings
{
    NSArray *mappings = [dataLayerMappings objectForKey:@"path_mappings"];
    NSAssert(mappings, @"unable to retrieve path mappings");
    return mappings;
}

- (NSArray *)dataLayerRequestMappings
{
    NSArray *mappings = [dataLayerMappings objectForKey:@"request_mappings"];
    NSAssert(mappings, @"unable to retrieve request mappings");
    return mappings;
}

- (RKObjectMapping *)objectMappingForEntityName:(NSString *)name
{
    if (objectMappings == nil) {
        RKManagedObjectStore *managedObjectStore = [RKObjectManager sharedManager].managedObjectStore;
        NSAssert(managedObjectStore, @"managed object store is not configured!");
        NSMutableDictionary *attributeMappingsDictionary = [NSMutableDictionary dictionary];

        // 1st pass: create entity attribute mappings
        NSDictionary *configuredEntityAttributeMappings = [dataLayerMappings objectForKey: @"entity_attribute_mappings"];
        NSAssert(configuredEntityAttributeMappings, @"unable to retrieve entity attribute mappings");

        for (NSString *entityName in configuredEntityAttributeMappings.allKeys) {
            NSDictionary *entityAttributeMappings = [configuredEntityAttributeMappings objectForKey: entityName];
            RKEntityMapping *objectMapping = [RKEntityMapping mappingForEntityForName: entityName
                                                                 inManagedObjectStore: managedObjectStore];
            [objectMapping addAttributeMappingsFromDictionary: entityAttributeMappings];
            [attributeMappingsDictionary setObject: objectMapping forKey: entityName];
        }

        // 2nd pass: provide primary key mappings
        NSDictionary *configuredPrimaryKeyMappings = [dataLayerMappings objectForKey: @"primary_key_mappings"];
        NSAssert(configuredPrimaryKeyMappings, @"unable to retrieve primary key mappings");
        for (NSString *entityName in configuredPrimaryKeyMappings.allKeys) {
            RKEntityMapping *sourceEntityMapping = [attributeMappingsDictionary objectForKey: entityName];
            NSAssert(sourceEntityMapping, @"primary key source entity mapping for %@ not found", entityName);
            NSArray *primaryKeyAttributes = [configuredPrimaryKeyMappings objectForKey: entityName];
            NSAssert(primaryKeyAttributes.count>0, @"no primary key attributes specified for %@", entityName);
            sourceEntityMapping.identificationAttributes = primaryKeyAttributes;
        }

        // 3rd pass: create relationship mappings
        NSDictionary *configuredRelationshipMappings = [dataLayerMappings objectForKey: @"relationship_mappings"];
        NSAssert(configuredRelationshipMappings, @"unable to retrieve relationship mappings");
        for (NSString *entityName in configuredRelationshipMappings.allKeys) {
            NSDictionary *relationshipMappingDict = [configuredRelationshipMappings objectForKey: entityName];
            RKEntityMapping *sourceEntityMapping = [attributeMappingsDictionary objectForKey: entityName];
            NSAssert(sourceEntityMapping, @"relationship source entity mapping for %@ not found", entityName);
            [relationshipMappingDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                NSString *sourceKeypath = key;
                NSDictionary *relationshipInfoDict = obj;

                NSDictionary *foreignKeyMapping = [relationshipInfoDict objectForKey:@"fk_mapping"];
                NSString *targetKeypath = [relationshipInfoDict objectForKey:@"key_path"];
                NSString *targetEntityName = [relationshipInfoDict objectForKey:@"target"];
                RKEntityMapping *targetEntityMapping = [attributeMappingsDictionary objectForKey: targetEntityName];
                NSAssert(targetEntityMapping, @"relationship entity mapping for %@ not found", obj);

                if (foreignKeyMapping) {
                    [sourceEntityMapping addConnectionForRelationship: targetKeypath connectedBy: foreignKeyMapping];
                } else {
                    RKRelationshipMapping *relationshipMapping = [RKRelationshipMapping relationshipMappingFromKeyPath: sourceKeypath
                                                                                                             toKeyPath: targetKeypath
                                                                                                           withMapping: targetEntityMapping];
                    [sourceEntityMapping addPropertyMapping: relationshipMapping];
                }
            }];
        }
        
        
        objectMappings = [NSDictionary dictionaryWithDictionary: attributeMappingsDictionary];
    }
    
    RKObjectMapping *mapping = [objectMappings objectForKey: name];
    NSAssert(mapping, @"object mapping for name=%@ is not defined", name);
    return mapping;
}

@end
