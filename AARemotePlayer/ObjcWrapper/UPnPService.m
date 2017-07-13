//
//  UPnPService.m
//  AARemotePlayer
//
//  Created by AAMac on 2017/4/20.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import "UPnPService.h"

@interface UPnPService ()

@property (nonatomic, strong) NSString *serviceID;
@property (nonatomic, strong) NSString *serviceType;
@property (nonatomic, strong) NSURL *eventSubURL;
@property (nonatomic, strong) NSURL *controlURL;
@property (nonatomic, strong) NSURL *descriptionURL;

@property (nonatomic, strong) NSString *subscriptionID;
@property (nonatomic, assign) NSTimeInterval subscriptionTimeout;
@property (atomic, assign) UPnPServiceSubscriptionState subscriptionState;

@end

@implementation UPnPService
@synthesize subscriptionState = _subscriptionState;

- (instancetype)initWithDevice:(UPnPDevice *)device {
    if (self = [super init]) {
        if (self) {
            _device = device;
        }
    }
    return self;
}

- (NSOperationQueue *)actionOperationQueue {
    if (!_actionOperationQueue) {
        _actionOperationQueue = [[NSOperationQueue alloc] init];
        [_actionOperationQueue setName:@"com.AA.UPnPOperationQueue"];
    }
    return _actionOperationQueue;
}

- (void)setSubscriptionState:(UPnPServiceSubscriptionState)subscriptionState {
    if (_subscriptionState == subscriptionState) {
        return;
    }
    @synchronized(self) {
        if (_subscriptionState != subscriptionState) {
            [self willChangeValueForKey:@"subscriptionState"];
            _subscriptionState = subscriptionState;
            [self didChangeValueForKey:@"subscriptionState"];
        }
    }
}

- (UPnPServiceSubscriptionState)subscriptionState {
    UPnPServiceSubscriptionState state = UPnPServiceSubscriptionStateNone;
    @synchronized(self) {
        state = _subscriptionState;
    }
    return state;
}

- (void)parseEventWithProperties:(NSDictionary *)properties {
    if (self.eventDelegate) {
        [self.eventDelegate servie:self parseEventWithProperties:properties];
    }
}

@end
