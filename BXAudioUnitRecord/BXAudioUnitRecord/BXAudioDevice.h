//
//  BXAudioDevice.h
//  BXAudioUnitRecord
//
//  Created by baxiang on 2017/7/23.
//  Copyright © 2017年 baxiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
@interface BXAudioDevice : NSObject
@property (nonatomic, strong, readonly) AVAudioSessionPortDescription *port;

@property (nonatomic, strong, readonly) AVAudioSessionDataSourceDescription *dataSource;
+ (BXAudioDevice *)currentInputDevice;
@end
