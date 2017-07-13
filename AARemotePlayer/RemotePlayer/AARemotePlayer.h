//
//  AARemotePlayer.h
//  AARemotePlayer
//
//  Created by Gavin Tsang on 2017/5/11.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UPnPActionInterface.h"

typedef enum {
    AARemotePlayerStateNone,
    AARemotePlayerStateError,
    AARemotePlayerStateStopped,
    AARemotePlayerStateTransitioning,
    AARemotePlayerStatePlaying,
    AARemotePlayerStatePaused,
    AARemotePlayerStateComplete,
    AARemotePlayerStateInit
} AARemotePlayerState;

@interface AARemotePlayer : NSObject

@property(assign, nonatomic) AARemotePlayerState state;

@property(strong, nonatomic) UPnPActionInterface * interface;

+ (instancetype)sharedPlayer;

- (void)releaseInterface;

- (void)playerSetURI:(NSString *)uri;

- (void)play;

- (void)pause;

- (void)resume;

- (void)stop;

- (void)seekTo:(float)time;
// invoke in background thread;
- (float)volume;

- (void)setVolume:(float)volume withErrorBlock:(void (^)(NSError * err))block;

- (NSUInteger)duration;

- (NSUInteger)currentTime;

- (void)updateInBackground;

@end
