//
//  UPnPManager.h
//  AARemotePlayer
//
//  Created by AAMac on 2017/4/19.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^UPnPManagerActionCompletionBlock)(NSDictionary *result, NSError *error);

@class UPnPService;
@class UPnPDevice;

@interface UPnPManager : NSObject

@property (nonatomic, assign) BOOL onService;

@property (nonatomic, assign) BOOL localServiceEnable;

@property (nonatomic, strong, readonly) NSString * address;

@property (nonatomic, strong) dispatch_queue_t opreationCompletionQueue;

@property (nonatomic, strong) dispatch_group_t opreationCompletionGroup;

+ (instancetype)shareManager;

- (void)setupRootDir:(NSString *)dir;

- (void)upnpManagerOnline:(BOOL)async;

- (void)upnpManagerOffline:(BOOL)async;

- (void)sendAction:(NSString *)actionName withParameters:(NSDictionary *)parameters toService:(UPnPService *)service completion:(UPnPManagerActionCompletionBlock)completion;

- (void)connectTo:(UPnPDevice *)device;

- (void)disconnectFrom:(UPnPDevice *)device;

@end
