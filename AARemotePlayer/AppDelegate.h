//
//  AppDelegate.h
//  AARemotePlayer
//
//  Created by Gavin Tsang on 2017/5/11.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

