//
//  PositionInfo.m
//  AARemotePlayer
//
//  Created by Gavin Tsang on 2017/5/9.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import "PositionInfo.h"

@implementation PositionInfo {
    NSInteger oldRel;
    NSInteger oldDur;
}

- (NSInteger)durationInt {
    NSInteger  durPosition = [PositionInfo dateStringToInt:self.TrackDuration];
    if(durPosition >36000|| durPosition <= 0){
        oldDur = 0;
        return oldDur;
    }
    oldDur = durPosition;
    return durPosition;
}

- (NSInteger)positionInt {
    NSInteger relPosition = [PositionInfo dateStringToInt:self.RelTime];
    if(relPosition >36000|| relPosition < 0){
        oldRel = 0;
        return oldRel;
    }
    oldRel = relPosition;
    return relPosition;
}

+ (NSInteger)dateStringToInt:(NSString *)datastr {
    NSInteger hours;
    NSInteger minis;
    NSInteger secs;
    NSInteger secondes;
    if (![datastr isKindOfClass:[NSString class]] || datastr == nil || datastr.length < 7) {
        return 0;
    }
    NSArray *array = [datastr componentsSeparatedByString:@":"];
    if ([array count] >= 3) {
        hours = [array[0] integerValue];
        minis = [array[1] integerValue];
        NSString *secstr = ((NSString *) array[2]);
        if (secstr.length > 2) {
            secstr = [secstr substringFromIndex:2];
        }
        secs = [secstr integerValue];
        return secondes = hours * 3600 + minis * 60 + secs;
    }
    return 0;
}

@end
