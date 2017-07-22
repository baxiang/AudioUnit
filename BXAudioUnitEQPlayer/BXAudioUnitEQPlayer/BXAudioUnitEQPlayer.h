//
//  BXAudioUnitEQPlayer.h
//  BXAudioUnitEQPlayer
//
//  Created by baxiang on 2017/7/22.
//  Copyright © 2017年 baxiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
@interface BXAudioUnitEQPlayer : NSObject

- (instancetype)initWithURL:(NSURL*)url;
- (void)selectEQPreset:(NSInteger)value;
- (NSArray*)iPodEQPresetsArray;
@end
