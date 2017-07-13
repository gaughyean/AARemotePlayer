//
//  AARemotePlayer.m
//  AARemotePlayer
//
//  Created by Gavin Tsang on 2017/5/11.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import "AARemotePlayer.h"
#import "UPnPActionInterface.h"
#import "PositionInfo.h"

@interface AARemotePlayer ()
{
    PositionInfo * _positionInfo;
    float _volume;
    dispatch_queue_t _infoUpdateQueue;
    uint _tryTime;
    dispatch_semaphore_t _volumeSema;
}
@end

@implementation AARemotePlayer

+ (instancetype)sharedPlayer {
    static AARemotePlayer * player;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        player = [[AARemotePlayer alloc] init];
    });
    return player;
}

- (instancetype)init {
    if (self = [super init]) {
        _positionInfo = [[PositionInfo alloc] init];
        _volumeSema = dispatch_semaphore_create(0);
        _volume = 0;
        _tryTime = 0;
//        static void * kInfoUpdateQueue = "AA.cn.remotePlayer.infoUpdateQueue";
        _infoUpdateQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
//        dispatch_queue_set_specific(_infoUpdateQueue, kInfoUpdateQueue, &kInfoUpdateQueue, NULL);
        self.state = AARemotePlayerStateNone;
    }
    return self;
}

- (void)setState:(AARemotePlayerState)state {
    [self willChangeValueForKey:@"state"];
    _state = state;
    if (_state == AARemotePlayerStateStopped || _state == AARemotePlayerStateComplete) {
        [_positionInfo setValue:@"0:00:00" forKey:@"TrackDuration"];
        [_positionInfo setValue:@"0:00:00" forKey:@"RelTime"];
    }
    [self didChangeValueForKey:@"state"];
}

#pragma mark - public methods

- (void)releaseInterface {
    self.interface = nil;
    self.state = AARemotePlayerStateNone;
}

- (void)setInterface:(UPnPActionInterface *)interface {
    _interface = interface;
    self.state = AARemotePlayerStateNone;
}

- (void)playerSetURI:(NSString *)uri{
    self.state = AARemotePlayerStateInit;
    _tryTime = 0;
    [_interface playTrack:nil withURL:uri completion:^(id resultAsDictOrArray, NSError *error) {
        if (!error) {
            self.state = AARemotePlayerStateTransitioning;
            [self play];
        }else{
            self.state = AARemotePlayerStateError;
        }
    }];
}

- (void)play {
    [_interface playWithCompletion:^(id resultAsDictOrArray, NSError *error) {
        if (!error) {
            [self checkTransportInfo];
        }else{
            self.state = AARemotePlayerStateError;
        }
    }];
}

- (void)pause {
    [_interface pauseWithCompletion:^(id resultAsDictOrArray, NSError *error) {
        if (!error) {
            self.state = AARemotePlayerStatePaused;
        }else{
            self.state = AARemotePlayerStateError;
        }
    }];
}

- (void)resume {
    [self play];
}

- (void)stop {
    [_interface stopWithCompletion:^(id resultAsDictOrArray, NSError *error) {
        if (!error) {
            self.state = AARemotePlayerStateStopped;
        }else{
            self.state = AARemotePlayerStateError;
        }
    }];
}

- (void)seekTo:(float)time {
    [_interface seekToTime:time completion:^(id resultAsDictOrArray, NSError *error) {
        if (!error) {
            self.state = AARemotePlayerStatePlaying;
        }else{
            self.state = AARemotePlayerStateError;
        }
    }];
}

- (float)volume {
    [_interface fetchVolumeWithCompletion:^(id resultAsDictOrArray, NSError *error) {
        NSDictionary * dict = (NSDictionary *)resultAsDictOrArray;
        _volume = [dict[@"currentVolume"] floatValue];
    }];
    dispatch_semaphore_wait(_volumeSema, dispatch_time(DISPATCH_TIME_NOW, 2));
    return _volume;
}

- (void)setVolume:(float)volume withErrorBlock:(void (^)(NSError * err))block {
    [_interface setVolume:volume completion:^(id resultAsDictOrArray, NSError *error) {
        if (!error) {
#ifdef DEBUG
            NSLog(@"volume:%@",resultAsDictOrArray);
#endif
            _volume = volume;
            //set volume
        }else{
            if (block) {
                block(error);
            }
        }
    }];
}

- (NSUInteger)duration {
    return _positionInfo.durationInt;
}

- (NSUInteger)currentTime {
    return _positionInfo.positionInt;
}

#pragma mark - privte methods

- (void)checkTransportInfo {
    [_interface fetchTransportInfoWithCompletion:^(id resultAsDictOrArray, NSError *error) {
        NSDictionary * dict = (NSDictionary *)resultAsDictOrArray;
        NSString * state = dict[@"CurrentTransportState"];
        NSString * status = dict[@"CurrentTransportStatus"];
        if (![status isEqualToString:@"OK"]) {
            self.state = AARemotePlayerStateError;
            return ;
        }
        if ([state isEqualToString:@"NO_MEDIA_PRESENT"]) {
            self.state = AARemotePlayerStateStopped;
            return;
        }
        if (![state isEqualToString:@"PLAYING"]) {
            if (_tryTime < 10) {
                _tryTime += 1;
#ifdef DEBUG
                NSLog(@"retry %d time",_tryTime);
#endif
                [self play];
                sleep(1);
            }else{
                self.state = AARemotePlayerStateError;
            }
        }else{
            self.state = AARemotePlayerStatePlaying;
            _tryTime = 0;
            [self updatePosition];
        }
    }];
}

- (void)doubleCheckTransportInfoWithCompletion:(void (^)(BOOL error))block {
    [_interface fetchTransportInfoWithCompletion:^(id resultAsDictOrArray, NSError *error) {
        NSDictionary * dict = (NSDictionary *)resultAsDictOrArray;
        NSString * state = dict[@"CurrentTransportState"];
        NSString * status = dict[@"CurrentTransportStatus"];
        if (![status isEqualToString:@"OK"] || [state isEqualToString:@"NO_MEDIA_PRESENT"]) {
            printf("state:%s status:%s \n",[state cStringUsingEncoding:NSASCIIStringEncoding],[status cStringUsingEncoding:NSASCIIStringEncoding]);
            if (block) {
                block(YES);
            }
        }else{
            if (block) {
                block(NO);
            }
        }
    }];
}

- (void)getPositionInfoWithCompletionBlock:(void(^)(BOOL gotIt))block {
    [_interface fetchPositionInfoWithCompletion:^(id resultAsDictOrArray, NSError *error) {
        if (!error) {
            NSDictionary * dict = (NSDictionary *)resultAsDictOrArray;
            [_positionInfo setValue:dict[@"TrackDuration"] forKey:@"TrackDuration"];
            [_positionInfo setValue:dict[@"RelTime"] forKey:@"RelTime"];
            if(block) block(YES);
        }else{
            if(block) block(NO);
        }
    }];
}

- (void)updatePosition {
    dispatch_async(_infoUpdateQueue, ^{
        NSInteger lastPosition = -1;
        __block uint errorTime = 0;
        while (self.state == AARemotePlayerStatePlaying) {
            if (_positionInfo.positionInt == _positionInfo.durationInt - 1 && _positionInfo.positionInt != 0) {
                self.state = AARemotePlayerStateComplete;
                break;
            }
            if (lastPosition == _positionInfo.positionInt && lastPosition != -1) {
                if (errorTime >= 10) {
                    [self doubleCheckTransportInfoWithCompletion:^(BOOL error) {
                        if (error) {
                            self.state = AARemotePlayerStateError;
                        }
                    }];
                }else{
                    errorTime += 1;
#ifdef DEBUG
                    NSLog(@"出现异常%d次",errorTime);
#endif
                }
            }else{
                errorTime = 0;
            }
            lastPosition = _positionInfo.positionInt;
            [self getPositionInfoWithCompletionBlock:nil];
            sleep(1);
#ifdef DEBUG
            NSLog(@"%ld / %ld",(long)_positionInfo.positionInt, (long)_positionInfo.durationInt);
#endif
        }
    });
}

- (void)updateInBackground {
    if (self.state == AARemotePlayerStatePlaying) {
        if (_positionInfo.positionInt == _positionInfo.durationInt - 1 && _positionInfo.positionInt != 0) {
            self.state = AARemotePlayerStateComplete;
            return;
        }
        [self getPositionInfoWithCompletionBlock:nil];
        sleep(1);
#ifdef DEBUG
        NSLog(@"%ld / %ld",(long)_positionInfo.positionInt, (long)_positionInfo.durationInt);
#endif
    }
}

@end
