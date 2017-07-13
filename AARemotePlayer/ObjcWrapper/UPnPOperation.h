//
//  UPnPOperation.h
//  AARemotePlayer
//
//  Created by AAMac on 2017/4/20.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libupnp/upnp.h>

@class UPnPService;

typedef void (^UPnPOperationCompletion)(NSDictionary *result, NSError *error);

@interface UPnPOperation : NSOperation

@property (atomic, assign) UpnpClient_Handle clientHandle;

@property (nonatomic, strong) NSSet *runLoopModes;

@property (nonatomic, strong) NSString *actionName;
@property (nonatomic, strong) NSDictionary *parameters;
@property (nonatomic, strong) UPnPService *service;

@property (nonatomic, strong) dispatch_queue_t completionQueue;
@property (nonatomic, strong) dispatch_group_t completionGroup;

@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSDictionary *actionResponse;

- (instancetype)initWithCompletion:(UPnPOperationCompletion)completionBlock;
- (void)setCompletionBlockWithUPnPOperationCompletion:(UPnPOperationCompletion)upnpCompletion;

@end
