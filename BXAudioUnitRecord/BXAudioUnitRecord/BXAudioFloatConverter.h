//
//  BXAudioFloatConverter.h
//  BXAudioUnitRecord
//
//  Created by baxiang on 2017/7/23.
//  Copyright © 2017年 baxiang. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AudioToolbox;
@interface BXAudioFloatConverter : NSObject
- (instancetype)initWithInputFormat:(AudioStreamBasicDescription)inputFormat;
- (void)convertDataFromAudioBufferList:(AudioBufferList *)audioBufferList
                    withNumberOfFrames:(UInt32)frames
                        toFloatBuffers:(float **)buffers;
@end
