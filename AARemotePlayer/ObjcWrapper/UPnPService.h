//
//  UPnPService.h
//  AARemotePlayer
//
//  Created by AAMac on 2017/4/20.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString *const kServiceType = @"serviceType";
static NSString *const kServiceID = @"serviceId";
static NSString *const kServiceDescriptionURL = @"SCPDURL";
static NSString *const kServiceControlURL = @"controlURL";
static NSString *const kServiceEventSubscriptionURL = @"eventSubURL";

typedef NS_ENUM (NSInteger, UPnPServiceSubscriptionState) {
    UPnPServiceSubscriptionStateNone,
    UPnPServiceSubscriptionStatePending,
    UPnPServiceSubscriptionStateSubscribed,
};

@class UPnPService;
@protocol UPnPServiceEventDelegate <NSObject>

- (void)servie:(UPnPService *)service parseEventWithProperties:(NSDictionary *)properties;

@end

@class UPnPDevice;

@interface UPnPService : NSObject

@property (nonatomic, weak, readonly) UPnPDevice *device;

@property (nonatomic, strong) NSOperationQueue *actionOperationQueue;

@property (nonatomic, weak) id <UPnPServiceEventDelegate> eventDelegate;

@property (nonatomic, strong, readonly) NSString *serviceID;
@property (nonatomic, strong, readonly) NSString *serviceType;
@property (nonatomic, strong, readonly) NSURL *eventSubURL;
@property (nonatomic, strong, readonly) NSURL *controlURL;
@property (nonatomic, strong, readonly) NSURL *descriptionURL;

@property (nonatomic, strong, readonly) NSString *subscriptionID;
@property (nonatomic, assign, readonly) NSTimeInterval subscriptionTimeout;
@property (atomic, assign, readonly) UPnPServiceSubscriptionState subscriptionState;

- (instancetype)initWithDevice:(UPnPDevice *)device;

- (void)parseEventWithProperties:(NSDictionary *)properties;

@end
