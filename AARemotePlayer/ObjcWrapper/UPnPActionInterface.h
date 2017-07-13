//
//  UPnPActionInterface.h
//  AARemotePlayer
//
//  Created by Gavin Tsang on 2017/5/8.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM (NSInteger, AAUPnPAction) {
    // Box Control
    AAUPnPActionGetBoxInfo,
    AAUPnPActionGetBoxVersion,
 
    // Content Directory
    AAUPnPActionGetSystemUpdateID,
    AAUPnPActionGetUSB,
    
    // Connection Manager
    AAUPnPActionGetProtocolInfo,
    
    // AVTransport
    AAUPnPActionGetMediaInfo,
    AAUPnPActionGetPositionInfo,
    AAUPnPActionGetNowPlayingInfo,
    AAUPnPActionGetCurrentTransportActions,
    AAUPnPActionGetTransportInfo,
    AAUPnPActionPlayTrack,
    AAUPnPActionSeek,
    AAUPnPActionGetTransportSettings,
  
    // Playback control
    AAUPnPActionPlaybackPlay,
    AAUPnPActionPlaybackStop,
    AAUPnPActionPlaybackPause,
    AAUPnPActionPlaybackNext,
    AAUPnPActionPlaybackPrevious,
    AAUPnPActionPlaybackSetPlayMode,
    
    // Rendering Control
    AAUPnPActionPlaybackGetVolume,
    AAUPnPActionPlaybackSetVolume,
    AAUPnPActionPlaybackGetMuteState,
    AAUPnPActionPlaybackSetMuteState,
};

typedef NS_ENUM (NSInteger, AAUPnPUPnPAVTransportPlayMode) {
    AAUPnPUPnPAVTransportPlayModeNormal,
    AAUPnPUPnPAVTransportPlayModeShuffle,
    AAUPnPUPnPAVTransportPlayModeRepeatOne,
    AAUPnPUPnPAVTransportPlayModeRepeatAll,
    AAUPnPUPnPAVTransportPlayModeRandom,
};

typedef void (^AAUPnPActionCompletion)(id resultAsDictOrArray, NSError *error);

@class UPnPDevice;

@interface UPnPActionInterface : NSObject

- (instancetype)initWithDevice:(UPnPDevice *)device;

- (void)fetchMediaInfoWithCompletion:(AAUPnPActionCompletion)completion;

- (void)fetchPositionInfoWithCompletion:(AAUPnPActionCompletion)completion;

- (void)fetchNowPlayingInfoWithCompletion:(AAUPnPActionCompletion)completion;

- (void)fetchCurrentTransportActionsWithCompletion:(AAUPnPActionCompletion)completion;

- (void)fetchTransportInfoWithCompletion:(AAUPnPActionCompletion)completion;

- (void)fetchTransportSettingsWithCompletion:(AAUPnPActionCompletion)completion;

- (void)playTrack:(NSString *)trackID withURL:(NSString *)url completion:(AAUPnPActionCompletion)completion;

- (void)playWithCompletion:(AAUPnPActionCompletion)completion;

- (void)stopWithCompletion:(AAUPnPActionCompletion)completion;

- (void)pauseWithCompletion:(AAUPnPActionCompletion)completion;

- (void)seekToTime:(float)time completion:(AAUPnPActionCompletion)completion;

- (void)skipToNextWithCompletion:(AAUPnPActionCompletion)completion;

- (void)skipToPreviousWithCompletion:(AAUPnPActionCompletion)completion;

- (void)setPlayMode:(AAUPnPUPnPAVTransportPlayMode)playMode completion:(AAUPnPActionCompletion)completion;

- (void)fetchVolumeWithCompletion:(AAUPnPActionCompletion)completion;

- (void)setVolume:(NSUInteger)volume completion:(AAUPnPActionCompletion)completion;

@end
