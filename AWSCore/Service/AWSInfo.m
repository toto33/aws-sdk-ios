//
// Copyright 2010-2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
// http://aws.amazon.com/apache2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//

#import "AWSInfo.h"
#import "AWSCategory.h"
#import "AWSCredentialsProvider.h"
#import "AWSLogging.h"
#import "AWSService.h"

NSString *const AWSInfoDefault = @"Default";

static NSString *const AWSInfoRoot = @"AWS";
static NSString *const AWSInfoCredentialsProvider = @"CredentialsProvider";
static NSString *const AWSInfoRegion = @"Region";
static NSString *const AWSInfoCognitoIdentity = @"CognitoIdentity";
static NSString *const AWSInfoCognitoIdentityPoolId = @"PoolId";

static NSString *const AWSInfoIdentityManager = @"IdentityManager";

@interface AWSInfo()

@property (nonatomic, strong) AWSCognitoCredentialsProvider *defaultCognitoCredentialsProvider;
@property (nonatomic, assign) AWSRegionType defaultRegion;
@property (nonatomic, strong) NSDictionary <NSString *, id> *rootInfoDictionary;

@end

@interface AWSServiceInfo()

@property (nonatomic, strong) NSDictionary <NSString *, id> *infoDictionary;

- (instancetype)initWithInfoDictionary:(NSDictionary <NSString *, id> *)infoDictionary
                           checkRegion:(BOOL)checkRegion;

@end

@implementation AWSInfo

- (instancetype)init {
    if (self = [super init]) {
        _rootInfoDictionary = [[[NSBundle mainBundle] infoDictionary] objectForKey:AWSInfoRoot];

        NSDictionary <NSString *, id> *defaultInfoDictionary = [_rootInfoDictionary objectForKey:AWSInfoDefault];

        NSDictionary <NSString *, id> *defaultCredentialsProviderDictionary = [[[_rootInfoDictionary objectForKey:AWSInfoCredentialsProvider] objectForKey:AWSInfoCognitoIdentity] objectForKey:AWSInfoDefault];
        NSString *cognitoIdentityPoolID = [defaultCredentialsProviderDictionary objectForKey:AWSInfoCognitoIdentityPoolId];
        AWSRegionType cognitoIdentityRegion =  [[defaultCredentialsProviderDictionary objectForKey:AWSInfoRegion] aws_regionTypeValue];
        if (cognitoIdentityPoolID && cognitoIdentityRegion != AWSRegionUnknown) {
            _defaultCognitoCredentialsProvider = [[AWSCognitoCredentialsProvider alloc] initWithRegionType:cognitoIdentityRegion
                                                                                            identityPoolId:cognitoIdentityPoolID];
        }

        _defaultRegion = [[defaultInfoDictionary objectForKey:AWSInfoRegion] aws_regionTypeValue];
    }
    
    return self;
}

+ (instancetype)defaultAWSInfo {
    static AWSInfo *_defaultAWSInfo = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _defaultAWSInfo = [AWSInfo new];
    });

    return _defaultAWSInfo;
}

- (AWSServiceInfo *)serviceInfo:(NSString *)serviceName
                         forKey:(NSString *)key {
    NSDictionary <NSString *, id> *infoDictionary = [[self.rootInfoDictionary objectForKey:serviceName] objectForKey:key];
    return [[AWSServiceInfo alloc] initWithInfoDictionary:infoDictionary
                                              checkRegion:![serviceName isEqualToString:AWSInfoIdentityManager]];
}

- (AWSServiceInfo *)defaultServiceInfo:(NSString *)serviceName {
    return [self serviceInfo:serviceName
                      forKey:AWSInfoDefault];
}

@end

@implementation AWSServiceInfo

- (instancetype)initWithInfoDictionary:(NSDictionary <NSString *, id> *)infoDictionary
                           checkRegion:(BOOL)checkRegion {
    if (self = [super init]) {
        _infoDictionary = infoDictionary;
        if (!_infoDictionary) {
            _infoDictionary = @{};
        }

        _cognitoCredentialsProvider = [AWSInfo defaultAWSInfo].defaultCognitoCredentialsProvider;

        _region = [[_infoDictionary objectForKey:AWSInfoRegion] aws_regionTypeValue];
        if (_region == AWSRegionUnknown) {
            _region = [AWSInfo defaultAWSInfo].defaultRegion;
        }

        if (!_cognitoCredentialsProvider) {
            if (![AWSServiceManager defaultServiceManager].defaultServiceConfiguration) {
                AWSLogDebug(@"Couldn't read credentials provider configurations from `Info.plist`. Please check your `Info.plist` if you are providing the SDK configuration values through `Info.plist`.");
            }
            return nil;
        }

        if (checkRegion
            && _region == AWSRegionUnknown) {
            if (![AWSServiceManager defaultServiceManager].defaultServiceConfiguration) {
                AWSLogDebug(@"Couldn't read the region configuration from Info.plist for the client. Please check your `Info.plist` if you are providing the SDK configuration values through `Info.plist`.");
            }
            return nil;
        }
    }

    return self;
}

@end
