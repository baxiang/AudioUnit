//
//  BXInputController.h
//  BXAudioUnitRecord
//
//  Created by baxiang on 2017/7/23.
//  Copyright © 2017年 baxiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BXAudioDevice.h"
@import AudioToolbox;
@class BXInputController;
@protocol BXInputControllerDelegate <NSObject>

@optional
- (void) microphone:(BXInputController *)microphone
  hasAudioStreamBasicDescription:(AudioStreamBasicDescription)audioStreamBasicDescription;
- (void)microphone:(BXInputController *)microphone changedDevice:(BXAudioDevice *)device;
- (void)microphone:(BXInputController *)microphone changedPlayingState:(BOOL)isPlaying;
- (void)microphone:(BXInputController *)microphone
hasAudioReceived:(float **)buffer
withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels;

- (void)microphone:(BXInputController *)microphone
hasBufferList:(AudioBufferList *)bufferList
withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels;
@end
@interface BXInputController : NSObject
@property (nonatomic, weak) id<BXInputControllerDelegate> delegate;
@property (nonatomic, strong) BXAudioDevice *device;

+ (BXInputController *)controllerWithDelegate:(id<BXInputControllerDelegate>)delegate;
- (BXInputController *)initWithController:(id<BXInputControllerDelegate>)delegate;
-(void)startFetchingAudio;
-(void)stopFetchingAudio;
-(AudioStreamBasicDescription)audioStreamBasicDescription;
@end
