//
//  UPnPDevice.h
//  AARemotePlayer
//
//  Created by AAMac on 2017/4/20.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString * const kUPnPDevicesHasAddedNotificationName = @"kUPnPDevicesHasAddedNotificationName";

static NSString * const kUPnPDevicesHasRemovedNotificationName = @"kUPnPDevicesHasRemovedNotificationName";

typedef NS_ENUM (NSInteger, UPnPDeviceState) {
    UPnPDeviceStateFailed = -1,
    UPnPDeviceStateDisconnected,
    UPnPDeviceStateInitializing,
    UPnPDeviceStateReady,
};

@interface UPnPDevice : NSObject

@property (nonatomic, strong, readwrite) NSURL          *descriptionURL;
@property (nonatomic, strong, readwrite) NSString       *ipAddress;
@property (nonatomic, strong, readonly) NSString        *udn;
@property (nonatomic, strong, readonly) NSString        *deviceType;
@property (nonatomic, strong, readonly) NSString        *friendlyName;
@property (nonatomic, strong, readonly) NSString        *manufacturer;
@property (nonatomic, strong, readonly) NSURL           *manufacturerURL;
@property (nonatomic, strong, readonly) NSString        *modelDescription;
@property (nonatomic, strong, readonly) NSString        *modelName;
@property (nonatomic, strong, readonly) NSString        *modelNumber;
@property (nonatomic, strong, readonly) NSURL           *modelURL;
@property (nonatomic, strong, readonly) NSString        *serialNumber;
@property (nonatomic, strong, readonly) NSString        *universalProductCode;
@property (nonatomic, strong, readonly) NSURL           *presentationURL;
@property (nonatomic, strong, readonly) NSSet           *services;
@property (nonatomic, strong, readonly) NSSet           *iconURLs;
@property (atomic,   strong, readwrite) NSDate          *lastActivityDate;
@property (nonatomic, assign, readwrite) UPnPDeviceState state;
@property (nonatomic, assign, readwrite) NSTimeInterval  expiration;
@property (nonatomic, assign) NSTimeInterval            fadeExpiration;

- (instancetype)initWithUniversalDeviceNumber:(NSString *)udn;

- (void)updateDeviceFromDescriptionURL:(NSURL *)descriptionURL andDate:(NSDate *)lastActivityDate andExpiration:(NSTimeInterval)expiration;

- (void)connect;

- (void)disConnect;

@end
