//
//  BXAudioUnitRecorder.h
//  BXAudioUnitRecord
//
//  Created by baxiang on 2017/7/23.
//  Copyright © 2017年 baxiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSInteger, BXRecorderFileType)
{
    
    BXRecorderFileTypeAIFF,
    BXRecorderFileTypeM4A,
    BXRecorderFileTypeWAV
};
@class BXAudioUnitRecorder;
@protocol BXAudioUnitRecorderDelegate <NSObject>

@optional

/**
 Triggers when the EZRecorder is explicitly closed with the `closeAudioFile` method.
 @param recorder The EZRecorder instance that triggered the action
 */
- (void)recorderDidClose:(BXAudioUnitRecorder *)recorder;

/**
 Triggers after the EZRecorder has successfully written audio data from the `appendDataFromBufferList:withBufferSize:` method.
 @param recorder The EZRecorder instance that triggered the action
 */
- (void)recorderUpdatedCurrentTime:(BXAudioUnitRecorder *)recorder;
@end
@interface BXAudioUnitRecorder : NSObject
@property (nonatomic, weak) id<BXAudioUnitRecorderDelegate> delegate;
@property (readonly) NSString *formattedCurrentTime;
+ (instancetype)recorderWithURL:(NSURL *)url
                   clientFormat:(AudioStreamBasicDescription)clientFormat
                       fileType:(BXRecorderFileType)fileType
                       delegate:(id<BXAudioUnitRecorderDelegate>)delegate;


- (void)appendDataFromBufferList:(AudioBufferList *)bufferList
                  withBufferSize:(UInt32)bufferSize;

- (void)closeAudioFile;
@end
