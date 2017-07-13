//
//  PositionInfo.h
//  AARemotePlayer
//
//  Created by Gavin Tsang on 2017/5/9.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PositionInfo : NSObject

@property(strong, nonatomic) NSString * RelTime;

@property(strong, nonatomic) NSString * TrackDuration;

@property(assign, nonatomic, readonly) NSInteger durationInt;

@property(assign, nonatomic, readonly) NSInteger positionInt;

@end
