//
//  ViewController.m
//  UPNPTest
//
//  Created by AAMac on 2017/4/19.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "UPnPManager.h"
#import "UPnPDevice.h"
#import "UPnPActionInterface.h"
#import "AARemotePlayer.h"


@interface ViewController ()<UITableViewDataSource, UITableViewDelegate>

@property(strong, nonatomic) NSTimer * timer;

@property(strong, nonatomic) NSTimer * timeTimer;

@property(strong, nonatomic) UPnPDevice * device;

@property(strong, nonatomic) NSArray * devices;

@property(strong, nonatomic) UITableView * table;

@property(strong, nonatomic) AARemotePlayer * player;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addDevice:) name:kUPnPDevicesHasAddedNotificationName object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeDevice:) name:kUPnPDevicesHasRemovedNotificationName object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeChange:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    [[UPnPManager shareManager] setupRootDir:path];
    [[UPnPManager shareManager] upnpManagerOnline:YES];
    self.player = [AARemotePlayer sharedPlayer];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(update) userInfo:nil repeats:YES];
    [self.timer fire];
    UITableView * table = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    [table registerClass:[UITableViewCell class] forCellReuseIdentifier:@"test"];
    self.table = table;
    self.table.delegate = self;
    self.table.dataSource = self;
    [self.view addSubview:table];
    NSString * encoded =[@"&" stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
    NSLog(@"%@",encoded);
    [self.player addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)dealloc {
    [self.player removeObserver:self forKeyPath:@"state"];
    [[UPnPManager shareManager] upnpManagerOffline:YES];
}

- (void)logTime {
    NSLog(@"duration:%lu -- currentTime:%lu",(unsigned long)self.player.duration,(unsigned long)self.player.currentTime);
}

- (void)update {
    self.devices = [[UPnPManager shareManager] valueForKey:@"devices"];
    [self.table reloadData];
}

- (void)volumeChange:(NSNotification *)noti {
    float volume = [noti.userInfo[@"AVSystemController_AudioVolumeNotificationParameter"] floatValue];
}

- (void)addDevice:(NSNotification *)noti {
    UPnPDevice * device = noti.object;
//    NSLog(@"add%@",device);
}

- (void)removeDevice:(NSNotification *)noti {
    UPnPDevice * device = noti.object;
//    NSLog(@"remove%@",device);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.devices) {
        return self.devices.count;
    }else{
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"test" forIndexPath:indexPath];
    UPnPDevice * device = self.devices[indexPath.row];
    NSString * deviceName = device.friendlyName;
    cell.textLabel.text = deviceName;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UPnPDevice * device = self.devices[indexPath.row];
    self.device = device;
    NSLog(@"%@",device.description);
    self.player.interface = nil;
    UPnPActionInterface * interface = [[UPnPActionInterface alloc] initWithDevice:device];
    self.player.interface = interface;
    [self.player playerSetURI:@"http://192.168.100.15/music/1394098802519.mp3"];

    UIAlertController * controller = [UIAlertController alertControllerWithTitle:device.udn message:device.descriptionURL.absoluteString preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction * action = [UIAlertAction actionWithTitle:@"test" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
    }];
    [controller addAction:action];
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"state"]) {
        AARemotePlayerState state = (AARemotePlayerState)[change[NSKeyValueChangeNewKey] integerValue];
        switch (state) {
            case AARemotePlayerStateNone:
                break;
            case AARemotePlayerStateError:
                break;
            case AARemotePlayerStateStopped:
                break;
            case AARemotePlayerStateTransitioning:
                break;
            case AARemotePlayerStatePlaying:
                break;
            case AARemotePlayerStatePaused:
                break;
            case AARemotePlayerStateComplete:
                break;
            case AARemotePlayerStateInit:
                break;
            default:
                break;
        }
        NSLog(@"state:%d",state);
    }
}

@end
