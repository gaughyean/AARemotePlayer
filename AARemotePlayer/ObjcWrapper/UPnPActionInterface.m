//
//  UPnPActionInterface.m
//  AARemotePlayer
//
//  Created by Gavin Tsang on 2017/5/8.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import "UPnPActionInterface.h"
#import "UPnPManager.h"
#import "UPnPService.h"
#import "UPnPDevice.h"

typedef NS_ENUM (NSInteger, AAUPnPCommonErrorType) {
    AAUPnPCommonErrorTypeInvalidDevice,
};

typedef NS_ENUM(NSInteger, AAUPnPServiceType) {
    AAUPnPServiceTypeUnknown,
    AAUPnPServiceTypeRenderingControl,
    AAUPnPServiceTypeConnectionManager,
    AAUPnPServiceTypeAVTransport,
    AAUPnPServiceTypeContentDirectory,
    AAUPnPServiceTypeCacheControl,
    AAUPnPServiceTypeBoxControl,
};

typedef id (^AAUPnPResultParseBlock)(NSDictionary *result);

static NSString *const kAAUPnPDictionaryMakerUPnPActionKey           = @"action";

static NSString *const kAAUPnPDictionaryMakerUPnPParametersKey       = @"parameters";

static NSString *const kParametersID                                 = @"id";

static NSString *const kParametersTrackID                            = @"trackID";

static NSString *const kParametersAlbumID                            = @"albumID";

static NSString *const kParametersThemeID                            = @"themeID";

static NSString *const kParametersPlaylistID                         = @"playlistID";

static NSString *const kParametersUSBResourceID                      = @"usbResourceID";

static NSString *const kParametersOffset                             = @"offset";

static NSString *const kParametersLimit                              = @"limit";

static NSString *const kParametersURL                                = @"url";

static NSString *const kParametersVolume                             = @"volume";

static NSString *const kParametersMute                               = @"mute";

static NSString *const kParametersPlayMode                           = @"playMode";

static NSString *const kParametersSeekTime                           = @"seekTime";

@class UPnPDevice;

@interface UPnPActionInterface ()

@property(weak, nonatomic) UPnPDevice * selectedDevice;

+ (NSString *)stringValueOfDictionary:(NSDictionary *)dict forKey:(NSString *)key;

@end

@implementation UPnPActionInterface

- (instancetype)initWithDevice:(UPnPDevice *)device {
    if (self = [super init]) {
        self.selectedDevice = device;
        [[UPnPManager shareManager] connectTo:device];
    }
    return self;
}

- (void)dealloc {
    [self clearServicesOperationQueues];
    [[UPnPManager shareManager] disconnectFrom:self.selectedDevice];
}

- (void)setSelectedDevice:(UPnPDevice *)selectedDevice {
    _selectedDevice = selectedDevice;
}

#pragma mark - public methods

#pragma mark ConnectionManager
- (void)fetchProtocolInfoWithCompletion:(AAUPnPActionCompletion)completion {
    [self sendAction:AAUPnPActionGetProtocolInfo withParameters:nil completion:completion];
}

#pragma mark AVTransport
- (void)fetchMediaInfoWithCompletion:(AAUPnPActionCompletion)completion {
    [self sendAction:AAUPnPActionGetMediaInfo withParameters:nil completion:completion];
}

- (void)fetchPositionInfoWithCompletion:(AAUPnPActionCompletion)completion {
    [self sendAction:AAUPnPActionGetPositionInfo withParameters:nil completion:completion];
}

- (void)fetchNowPlayingInfoWithCompletion:(AAUPnPActionCompletion)completion {
    [self sendAction:AAUPnPActionGetNowPlayingInfo withParameters:nil completion:completion];
}

- (void)fetchCurrentTransportActionsWithCompletion:(AAUPnPActionCompletion)completion {
    [self sendAction:AAUPnPActionGetCurrentTransportActions withParameters:nil completion:completion];
}

- (void)fetchTransportInfoWithCompletion:(AAUPnPActionCompletion)completion {
    [self sendAction:AAUPnPActionGetTransportInfo withParameters:nil completion:completion];
}

- (void)fetchTransportSettingsWithCompletion:(AAUPnPActionCompletion)completion {
    [self sendAction:AAUPnPActionGetTransportSettings withParameters:nil completion:completion];
}

- (void)playTrack:(NSString *)trackID withURL:(NSString *)url completion:(AAUPnPActionCompletion)completion {
    NSDictionary *parameters = @{ kParametersURL:url};

    [self sendAction:AAUPnPActionPlayTrack withParameters:parameters completion:completion];
}

- (void)playWithCompletion:(AAUPnPActionCompletion)completion {
    [self sendAction:AAUPnPActionPlaybackPlay withParameters:nil completion:completion];
}

- (void)stopWithCompletion:(AAUPnPActionCompletion)completion {
    [self sendAction:AAUPnPActionPlaybackStop withParameters:nil completion:completion];
}

- (void)seekToTime:(float)time completion:(AAUPnPActionCompletion)completion {
    NSDictionary *parameters = @{ kParametersSeekTime:[NSString stringWithFormat:@"%d", (int)time] };
    [self sendAction:AAUPnPActionSeek withParameters:parameters completion:completion];
}

- (void)pauseWithCompletion:(AAUPnPActionCompletion)completion {
    [self sendAction:AAUPnPActionPlaybackPause withParameters:nil completion:completion];
}

- (void)skipToNextWithCompletion:(AAUPnPActionCompletion)completion {
    [self sendAction:AAUPnPActionPlaybackNext withParameters:nil completion:completion];
}

- (void)skipToPreviousWithCompletion:(AAUPnPActionCompletion)completion {
    [self sendAction:AAUPnPActionPlaybackPrevious withParameters:nil completion:completion];
}

- (void)setPlayMode:(AAUPnPUPnPAVTransportPlayMode)playMode completion:(AAUPnPActionCompletion)completion {
    NSDictionary *parameters = @{ kParametersPlayMode:[self stringValueOfPlayMode:playMode] };

    [self sendAction:AAUPnPActionPlaybackSetPlayMode withParameters:parameters completion:completion];
}

#pragma mark Rendering Control
- (void)fetchVolumeWithCompletion:(AAUPnPActionCompletion)completion {
    [self sendAction:AAUPnPActionPlaybackGetVolume withParameters:nil completion:completion];
}

- (void)setVolume:(NSUInteger)volume completion:(AAUPnPActionCompletion)completion {
    NSDictionary *parameters = @{ kParametersVolume:[NSString stringWithFormat:@"%lu", (unsigned long)volume] };
    
    [self sendAction:AAUPnPActionPlaybackSetVolume withParameters:parameters completion:completion];
}

#pragma mark - private methods

- (NSString *)serviceURNOfType:(AAUPnPServiceType)type {
    NSString *urn = nil;
    switch (type) {
        case AAUPnPServiceTypeUnknown:
            break;
        case AAUPnPServiceTypeRenderingControl:
            urn = @"urn:schemas-upnp-org:service:RenderingControl:1";
            break;
        case AAUPnPServiceTypeConnectionManager:
            urn = @"urn:schemas-upnp-org:service:ConnectionManager:1";
            break;
        case AAUPnPServiceTypeAVTransport:
            urn = @"urn:schemas-upnp-org:service:AVTransport:1";
            break;
        case AAUPnPServiceTypeContentDirectory:
            urn = @"urn:schemas-upnp-org:service:ContentDirectory:1";
            break;
        case AAUPnPServiceTypeCacheControl:
            urn = @"urn:schemas-upnp-org:service:CacheControl:1";
            break;
        case AAUPnPServiceTypeBoxControl:
            urn = @"urn:schemas-upnp-org:service:BoxControl:1";
            break;
            
        default:
            break;
    }
    
    return urn;
}

- (AAUPnPResultParseBlock)parseBlockOfAction:(AAUPnPAction)action {
    AAUPnPResultParseBlock parseBlock = nil;
    switch (action) {
        case AAUPnPActionGetBoxInfo:
            parseBlock = ^id (NSDictionary *result) {
                id cleanResult = nil;
                if (result) {
                    NSMutableDictionary *cleanDict = [NSMutableDictionary dictionary];
                    NSString *value = [UPnPActionInterface stringValueOfDictionary:result forKey:@"ApplicationVersion"];//[result stringValueForKey:@"ApplicationVersion"];//
                    if (value.length > 0) {
                        cleanDict[@"appVersion"] = value;
                    }
                    
                    value = [UPnPActionInterface stringValueOfDictionary:result forKey:@"Deviceno"];//[result stringValueForKey:@"Deviceno"];//
                    if (value.length > 0) {
                        cleanDict[@"deviceID"] = value;
                    }
                    
                    value = [UPnPActionInterface stringValueOfDictionary:result forKey:@"Model"];//[result stringValueForKey:@"Model"];//
                    if (value.length > 0) {
                        cleanDict[@"model"] = value;
                    }
                    
                    value = [UPnPActionInterface stringValueOfDictionary:result forKey:@"SystemVersion"];//[result stringValueForKey:@"SystemVersion"];//
                    if (value.length > 0) {
                        cleanDict[@"systemVersion"] = value;
                    }
                    
                    value = [UPnPActionInterface stringValueOfDictionary:result forKey:@"Username"];//[result stringValueForKey:@"Username"];//
                    if (value.length > 0) {
                        cleanDict[@"DFMID"] = value;
                    }
                    
                    cleanResult = [NSDictionary dictionaryWithDictionary:cleanDict];
                }
                
                return cleanResult;
            };
            break;
        case AAUPnPActionGetBoxVersion:
            parseBlock = ^id (NSDictionary *result) {
                id cleanResult = nil;
                if (result) {
                    NSMutableDictionary *cleanDict = [NSMutableDictionary dictionary];
                    NSString *value = [UPnPActionInterface stringValueOfDictionary:result forKey:@"versionCode"];//[result stringValueForKey:@"versionCode"];//
                    if (value.length > 0) {
                        cleanDict[@"versionCode"] = value;
                    }
                    
                    value = [UPnPActionInterface stringValueOfDictionary:result forKey:@"versionName"];//[result stringValueForKey:@"versionName"];//
                    if (value.length > 0) {
                        cleanDict[@"versionName"] = value;
                    }
                    
                    cleanResult = [NSDictionary dictionaryWithDictionary:cleanDict];
                }
                
                return cleanResult;
            };
            break;
        case AAUPnPActionGetSystemUpdateID:
            break;
        case AAUPnPActionGetUSB:
            break;
        case AAUPnPActionGetProtocolInfo:
            break;
        case AAUPnPActionGetMediaInfo:
            break;
        case AAUPnPActionGetPositionInfo:
            break;
        case AAUPnPActionGetNowPlayingInfo:
            parseBlock = ^id (NSDictionary *result) {
                id cleanResult = nil;
                if (result) {
                    NSMutableDictionary *mutableDict = [NSMutableDictionary dictionary];
                    
                    NSString *durationStr = [UPnPActionInterface stringValueOfDictionary:result forKey:@"duration"];//[result stringValueForKey:@"duration"];//
                    NSString *currentTimeStr = [UPnPActionInterface stringValueOfDictionary:result forKey:@"currentposition"];//[result stringValueForKey:@"currentposition"];//
                    NSArray *components = [durationStr componentsSeparatedByString:@":"];
                    float duration = ((NSString *)components[0]).intValue * 3600 + ((NSString *)components[1]).intValue * 60 + ((NSString *)components[2]).intValue;
                    components = [currentTimeStr componentsSeparatedByString:@":"];
                    float currentTime = ((NSString *)components[0]).intValue * 3600 + ((NSString *)components[1]).intValue * 60 + ((NSString *)components[2]).intValue;
                    
                    mutableDict[@"duration"] = [NSNumber numberWithFloat:duration];
                    mutableDict[@"currentTime"] = [NSNumber numberWithFloat:currentTime];
                    
                    NSString *currentTrackID = [UPnPActionInterface stringValueOfDictionary:result forKey:@"musicid"];//[result stringValueForKey:@"musicid"];//
                    
                    if (currentTrackID.length > 0) {
                        mutableDict[@"currentTrackID"] = currentTrackID;
                    }
                    
                    NSString *playbackStateStr = [UPnPActionInterface stringValueOfDictionary:result forKey:@"playstate"];//[result stringValueForKey:@"playstate"];//

                    if (playbackStateStr.length > 0) {

                    }
                    cleanResult = [NSDictionary dictionaryWithDictionary:mutableDict];
                }
                return cleanResult;
            };
            break;
        case AAUPnPActionGetCurrentTransportActions:
            break;
        case AAUPnPActionGetTransportInfo:
            break;
        case AAUPnPActionPlayTrack:
            break;
        case AAUPnPActionSeek:
            break;
        case AAUPnPActionGetTransportSettings:
            parseBlock = ^id (NSDictionary *result) {
                id cleanResult = nil;
                if (result) {
                    NSString *playModeStr = [UPnPActionInterface stringValueOfDictionary:result forKey:@"PlayMode"];//[result stringValueForKey:@"PlayMode"];//
                }
                
                return cleanResult;
            };
            break;
        case AAUPnPActionPlaybackPlay:
            break;
        case AAUPnPActionPlaybackStop:
            break;
        case AAUPnPActionPlaybackPause:
            break;
        case AAUPnPActionPlaybackNext:
            break;
        case AAUPnPActionPlaybackPrevious:
            break;
        case AAUPnPActionPlaybackSetPlayMode:
            break;
        case AAUPnPActionPlaybackGetVolume:
            parseBlock = ^id (NSDictionary *result) {
                id cleanResult = nil;
                if (result) {
                    NSString *currentVolumeStr = [UPnPActionInterface stringValueOfDictionary:result forKey:@"CurrentVolume"];// [result stringValueForKey:@"CurrentVolume"];//
                    
                    cleanResult = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:[currentVolumeStr integerValue]], @"currentVolume", nil];
                }
                
                return cleanResult;
            };
            break;
        case AAUPnPActionPlaybackSetVolume:
            break;
        case AAUPnPActionPlaybackGetMuteState:
            break;
        case AAUPnPActionPlaybackSetMuteState:
            break;
        default:
            break;
    }
    
    return parseBlock;
}

- (NSDictionary *)dictionaryOfAction:(AAUPnPAction)action withParameters:(NSDictionary *)parameters {
    NSDictionary *actionDict = nil;
    
    switch (action) {
            // Box Control
        case AAUPnPActionGetBoxInfo:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"GetBoxInfo", kAAUPnPDictionaryMakerUPnPParametersKey:@{} };
            break;
            
        case AAUPnPActionGetBoxVersion:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"GetVersion", kAAUPnPDictionaryMakerUPnPParametersKey:@{} };
            break;
            
        // Content Directory
        case AAUPnPActionGetSystemUpdateID:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"GetSystemUpdateID", kAAUPnPDictionaryMakerUPnPParametersKey:@{} };
            break;
            
        case AAUPnPActionGetUSB:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"Browse", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"ObjectID":@"0", @"BrowseFlag":@"BrowseMetadata", @"filter":@"childCount,res,res", @"StartingIndex":@"0", @"RequestedCount":@"0", @"SortCriteria":@"-dc:date" } };
            
            break;
            
            // Connection Manager
        case AAUPnPActionGetProtocolInfo:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"GetProtocolInfo", kAAUPnPDictionaryMakerUPnPParametersKey:@{} };
            break;
            
            // AVTransport
        case AAUPnPActionGetMediaInfo:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"GetMediaInfo", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0" } };
            break;
            
        case AAUPnPActionGetPositionInfo:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"GetPositionInfo", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0" } };
            break;
            
        case AAUPnPActionGetNowPlayingInfo:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"GetNowPlayInfo", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0" } };
            break;
            
        case AAUPnPActionGetCurrentTransportActions:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"GetCurrentTransportActions", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0" } };
            break;
            
        case AAUPnPActionGetTransportInfo:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"GetTransportInfo", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0" } };
            break;
            
        case AAUPnPActionPlayTrack:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"SetAVTransportURI", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0",@"CurrentURI":parameters[kParametersURL], @"CurrentURIMetaData":@"" } };
            break;
            
        case AAUPnPActionSeek:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"Seek", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0",@"TRACK_NR":@"0",@"Unit":@"REL_TIME", @"Target":parameters[kParametersSeekTime] } };
            break;
            
        case AAUPnPActionGetTransportSettings:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"GetTransportSettings", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0" } };
            break;
            
        case AAUPnPActionPlaybackPlay:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"Play", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0", @"Speed":@"1" } };
            break;
            
        case AAUPnPActionPlaybackStop:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"Stop", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0" } };
            break;
            
        case AAUPnPActionPlaybackPause:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"Pause", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0" } };
            break;
            
        case AAUPnPActionPlaybackNext:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"Next", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0" } };
            break;
            
        case AAUPnPActionPlaybackPrevious:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"Previous", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0" } };
            break;
            
        case AAUPnPActionPlaybackGetVolume:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"GetVolume", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0", @"Channel":@"Master" } };
            break;
            
        case AAUPnPActionPlaybackSetVolume:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"SetVolume", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0", @"Channel":@"Master", @"DesiredVolume":parameters[kParametersVolume] } };
            break;
            
        case AAUPnPActionPlaybackGetMuteState:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"GetMute", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0", @"Channel":@"Master" } };
            break;
            
        case AAUPnPActionPlaybackSetMuteState:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"SetMute", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0", @"Channel":@"Master", @"DesiredMute":parameters[kParametersMute] } };
            break;
            
        case AAUPnPActionPlaybackSetPlayMode:
            actionDict = @{ kAAUPnPDictionaryMakerUPnPActionKey:@"SetPlayMode", kAAUPnPDictionaryMakerUPnPParametersKey:@{ @"InstanceID":@"0", @"NewPlayMode":parameters[kParametersPlayMode] } };
            break;
            
        default:
            break;
    }
    
    return actionDict;
}

- (NSDictionary *)dictionaryOfActionResult:(NSDictionary *)result error:(NSError *__autoreleasing *)error {
    NSDictionary *retDict = nil;
    
    NSDictionary *parameters = result[kAAUPnPDictionaryMakerUPnPParametersKey];
    
    if ([parameters.allKeys containsObject:@"Json"]) {
        NSString *jsonStr = parameters[@"Json"];
        
        retDict = [NSJSONSerialization JSONObjectWithData:[jsonStr dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:error];
    } else {
        retDict = parameters;
    }
    
    return retDict;
}

- (NSString *)stringValueOfPlayMode:(AAUPnPUPnPAVTransportPlayMode)playMode {
    NSString *value = @"Unknown";
    
    switch (playMode) {
        case AAUPnPUPnPAVTransportPlayModeNormal:
            value = @"NORMAL";
            break;
        case AAUPnPUPnPAVTransportPlayModeShuffle:
            value = @"SHUFFLE";
            break;
        case AAUPnPUPnPAVTransportPlayModeRepeatOne:
            value = @"REPEAT_ONE";
            break;
        case AAUPnPUPnPAVTransportPlayModeRepeatAll:
            value = @"REPEAT_ALL";
            break;
        case AAUPnPUPnPAVTransportPlayModeRandom:
            value = @"RANDOM";
            break;
            
        default:
            break;
    }
    
    return value;
}

- (void)sendAction:(AAUPnPAction)action withParameters:(NSDictionary *)parameters completion:(AAUPnPActionCompletion)completion {
    [self sendAction:action withParameters:parameters parseBlock:[self parseBlockOfAction:action] completion:completion];
}

- (void)sendAction:(AAUPnPAction)action withParameters:(NSDictionary *)parameters parseBlock:(AAUPnPResultParseBlock)parseBlock completion:(AAUPnPActionCompletion)completion {
    UPnPService *service = nil;
    
    switch (action) {
            // Box Control
        case AAUPnPActionGetBoxInfo:
        case AAUPnPActionGetBoxVersion:
            service = [self serviceOfType:AAUPnPServiceTypeBoxControl];
            break;
            
            // Content Directory
        case AAUPnPActionGetSystemUpdateID:
        case AAUPnPActionGetUSB:
            service = [self serviceOfType:AAUPnPServiceTypeContentDirectory];
            break;
            
            // Connection Manager
        case AAUPnPActionGetProtocolInfo:
            service = [self serviceOfType:AAUPnPServiceTypeConnectionManager];
            break;
            
            // AVTransport
        case AAUPnPActionGetMediaInfo:
        case AAUPnPActionGetPositionInfo:
        case AAUPnPActionGetNowPlayingInfo:
        case AAUPnPActionGetCurrentTransportActions:
        case AAUPnPActionGetTransportInfo:
        case AAUPnPActionPlayTrack:
        case AAUPnPActionPlaybackPlay:
        case AAUPnPActionPlaybackPause:
        case AAUPnPActionPlaybackNext:
        case AAUPnPActionPlaybackPrevious:
        case AAUPnPActionPlaybackSetPlayMode:
        case AAUPnPActionSeek:
        case AAUPnPActionGetTransportSettings:
        case AAUPnPActionPlaybackStop:
            service = [self serviceOfType:AAUPnPServiceTypeAVTransport];
            break;
            
        case AAUPnPActionPlaybackGetVolume:
        case AAUPnPActionPlaybackSetVolume:
        case AAUPnPActionPlaybackGetMuteState:
        case AAUPnPActionPlaybackSetMuteState:
            service = [self serviceOfType:AAUPnPServiceTypeRenderingControl];
            break;
          
        default:
            break;
    }
    
    if (service) {
        NSDictionary *actionDict = [self dictionaryOfAction:action withParameters:parameters];
        
        [[UPnPManager shareManager] sendAction:actionDict[kAAUPnPDictionaryMakerUPnPActionKey] withParameters:actionDict[kAAUPnPDictionaryMakerUPnPParametersKey] toService:service completion:^(NSDictionary *result, NSError *error) {
            if (!error) {
                NSError *resultError = nil;
                
                NSDictionary *resultDict = [self dictionaryOfActionResult:result error:&resultError];
                
                if (!resultError) {
                    if (parseBlock) resultDict = parseBlock(resultDict);
                }
                if (completion) completion(resultDict, resultError);
                
            } else {
                if (completion) completion(nil, error);
            }
        }];
    } else {
        if (completion) completion(nil, [self errorOfType:AAUPnPCommonErrorTypeInvalidDevice]);
    }
}

- (UPnPService *)serviceOfType:(AAUPnPServiceType)type {
    UPnPService *candidateService = nil;
    
    NSString *urn = [self serviceURNOfType:type];
    
    if (urn) {
        for (UPnPService *service in self.selectedDevice.services) {
            if ([service.serviceType isEqualToString:urn]) {
                candidateService = service;
                break;
            }
        }
    }
    
    if (!candidateService) {
#ifdef DEBUG
        NSLog(@"Error: Can not found [%@] in [%@]", urn, self.selectedDevice.friendlyName);
#endif
    }
    
    return candidateService;
}

- (NSError *)errorOfType:(AAUPnPCommonErrorType)type {
    NSString *localizedDescription = nil;
    NSString *localizedFailureReason = nil;
    
    switch (type) {
        case AAUPnPCommonErrorTypeInvalidDevice: {
            localizedDescription = NSLocalizedString(@"Invalid Device", @"Invalid Device.");
            localizedFailureReason = NSLocalizedString(@"A device without box control service or no device.", @"A device without box control service or no device reason.");
        }
            break;
            
        default: {
            localizedDescription = NSLocalizedString(@"Unknown error.", @"Unknown error.");
            localizedFailureReason = NSLocalizedString(@"Unknown error.", @"Unknown error.");
        }
            
            break;
    }
    
    NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
                               localizedDescription, NSLocalizedDescriptionKey,
                               localizedFailureReason, NSLocalizedFailureReasonErrorKey,
                               nil];
    
    return [NSError errorWithDomain:@"AAUPnP" code:-88 userInfo:errorDict];
}

- (void)clearServicesOperationQueues {
    for (UPnPService *service in self.selectedDevice.services) {
        [service.actionOperationQueue cancelAllOperations];
    }
}

#pragma mark - helper methods

+ (NSString *)stringValueOfDictionary:(NSDictionary *)dict forKey:(NSString *)key {
    id candidate = [dict valueForKey:key];
    
    if ([candidate isKindOfClass:[NSNull class]]) {
        return nil;
    }
    if (candidate) {
        if ([candidate isKindOfClass:[NSString class]]) {
            return candidate;
        } else {
            return [NSString stringWithFormat:@"%@", candidate];
        }
    } else {
        return nil;
    }
}

@end


