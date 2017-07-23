//
//  BXAudioDevice.m
//  BXAudioUnitRecord
//
//  Created by baxiang on 2017/7/23.
//  Copyright © 2017年 baxiang. All rights reserved.
//

#import "BXAudioDevice.h"

@interface BXAudioDevice()
@property (nonatomic, strong, readwrite) AVAudioSessionPortDescription *port;
@property (nonatomic, strong, readwrite) AVAudioSessionDataSourceDescription *dataSource;
@end

@implementation BXAudioDevice

+ (BXAudioDevice *)currentInputDevice
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    AVAudioSessionPortDescription *port = [[[session currentRoute] inputs] firstObject];
    AVAudioSessionDataSourceDescription *dataSource = [session inputDataSource];
    BXAudioDevice *device = [[BXAudioDevice alloc] init];
    device.port = port;
    device.dataSource = dataSource;
    return device;
}
@end
