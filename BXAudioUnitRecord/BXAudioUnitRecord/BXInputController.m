//
//  BXInputController.m
//  BXAudioUnitRecord
//
//  Created by baxiang on 2017/7/23.
//  Copyright © 2017年 baxiang. All rights reserved.
//

#import "BXInputController.h"
#import "BXAudioUtilities.h"
#import "BXAudioFloatConverter.h"
typedef struct BXInputInfo
{
    AudioUnit                     audioUnit;
    AudioBufferList              *audioBufferList;
    float                       **floatData;
    AudioStreamBasicDescription   inputFormat;
    AudioStreamBasicDescription   streamFormat;
} BXInputInfo;

@interface BXInputController ()
@property (nonatomic, strong) BXAudioFloatConverter *floatConverter;
@property (nonatomic, assign) BXInputInfo *info;
@end;
@implementation BXInputController


static OSStatus EZAudioMicrophoneCallback(void                       *inRefCon,
                                          AudioUnitRenderActionFlags *ioActionFlags,
                                          const AudioTimeStamp       *inTimeStamp,
                                          UInt32                      inBusNumber,
                                          UInt32                      inNumberFrames,
                                          AudioBufferList            *ioData)
{
    BXInputController *microphone = (__bridge BXInputController *)inRefCon;
    BXInputInfo *info = (BXInputInfo *)microphone.info;
    for (int i = 0; i < info->audioBufferList->mNumberBuffers; i++) {
        info->audioBufferList->mBuffers[i].mDataByteSize = inNumberFrames * info->streamFormat.mBytesPerFrame;
    }
    
    OSStatus result = AudioUnitRender(info->audioUnit,
                                      ioActionFlags,
                                      inTimeStamp,
                                      inBusNumber,
                                      inNumberFrames,
                                      info->audioBufferList);
    
    if ([microphone.delegate respondsToSelector:@selector(microphone:hasBufferList:withBufferSize:withNumberOfChannels:)])
    {
        [microphone.delegate microphone:microphone
                          hasBufferList:info->audioBufferList
                         withBufferSize:inNumberFrames
                   withNumberOfChannels:info->streamFormat.mChannelsPerFrame];
    }
    
    //
    // Notify delegate of new float data processed
    //
    if ([microphone.delegate respondsToSelector:@selector(microphone:hasAudioReceived:withBufferSize:withNumberOfChannels:)])
    {
       
        [microphone.floatConverter convertDataFromAudioBufferList:info->audioBufferList
                                               withNumberOfFrames:inNumberFrames
                                                   toFloatBuffers:info->floatData];
        [microphone.delegate microphone:microphone
                       hasAudioReceived:info->floatData
                         withBufferSize:inNumberFrames
                   withNumberOfChannels:info->streamFormat.mChannelsPerFrame];
    }
    
    return result;
}
+ (BXInputController *)controllerWithDelegate:(id<BXInputControllerDelegate>)delegate
{
    return [[BXInputController alloc] initWithController:delegate];
}

- (id)init
{
    self = [super init];
    if(self)
    {
        self.info = (BXInputInfo *)malloc(sizeof(BXInputInfo));
        memset(self.info, 0, sizeof(BXInputInfo));
        [self setup];
    }
    return self;
}
- (BXInputController *)initWithController:(id<BXInputControllerDelegate>)delegate
{
    self = [super init];
    if(self)
    {
        self.info = (BXInputInfo *)malloc(sizeof(BXInputInfo));
        memset(self.info, 0, sizeof(BXInputInfo));
        _delegate = delegate;
        [self setup];
    }
    return self;
}

- (void)setup
{
    
    AudioComponentDescription inputComponentDescription;
    inputComponentDescription.componentType = kAudioUnitType_Output;
    inputComponentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    inputComponentDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    inputComponentDescription.componentFlags = 0;
    inputComponentDescription.componentFlagsMask = 0;
    
    // get the first matching component
    AudioComponent inputComponent = AudioComponentFindNext( NULL , &inputComponentDescription);
    NSAssert(inputComponent, @"Couldn't get input component unit!");
    
    [BXAudioUtilities checkResult:AudioComponentInstanceNew(inputComponent, &self.info->audioUnit)
                        operation:"Failed to get audio component instance"];
    
    UInt32 flag = 1;
    [BXAudioUtilities checkResult:AudioUnitSetProperty(self.info->audioUnit,
                                                       kAudioOutputUnitProperty_EnableIO,
                                                       kAudioUnitScope_Input,
                                                       1,
                                                       &flag,
                                                       sizeof(flag))
                        operation:"Couldn't enable input on remote IO unit."];

    [self setDevice:[BXAudioDevice currentInputDevice]];
    
    UInt32 propSize = sizeof(self.info->inputFormat);
    [BXAudioUtilities checkResult:AudioUnitGetProperty(self.info->audioUnit,
                                                       kAudioUnitProperty_StreamFormat,
                                                       kAudioUnitScope_Input,
                                                       1,
                                                       &self.info->inputFormat,
                                                       &propSize)
                        operation:"Failed to get stream format of microphone input scope"];

    self.info->inputFormat.mSampleRate = [[AVAudioSession sharedInstance] sampleRate];
    NSAssert(self.info->inputFormat.mSampleRate, @"Expected AVAudioSession sample rate to be greater than 0.0. Did you setup the audio session?");

    [self setAudioStreamBasicDescription:[self defaultStreamFormat]];
    
    // render callback
    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProc = EZAudioMicrophoneCallback;
    renderCallbackStruct.inputProcRefCon = (__bridge void *)(self);
    [BXAudioUtilities checkResult:AudioUnitSetProperty(self.info->audioUnit,
                                                       kAudioOutputUnitProperty_SetInputCallback,
                                                       kAudioUnitScope_Global,
                                                       1,
                                                       &renderCallbackStruct,
                                                       sizeof(renderCallbackStruct))
                        operation:"Failed to set render callback"];
    
    [BXAudioUtilities checkResult:AudioUnitInitialize(self.info->audioUnit)
                        operation:"Failed to initialize input unit"];
    
    // setup notifications
   // [self setupNotifications];
}

- (void)setAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd
{
//    if (self.floatConverter)
//    {
//        [BXAudioUtilities freeBufferList:self.info->audioBufferList];
//        [BXAudioUtilities freeFloatBuffers:self.info->floatData
//                          numberOfChannels:self.info->streamFormat.mChannelsPerFrame];
//    }
    
    //
    // Set new stream format
    //
    self.info->streamFormat = asbd;
    [BXAudioUtilities checkResult:AudioUnitSetProperty(self.info->audioUnit,
                                                       kAudioUnitProperty_StreamFormat,
                                                       kAudioUnitScope_Input,
                                                       0,
                                                       &asbd,
                                                       sizeof(asbd))
                        operation:"Failed to set stream format on input scope"];
    [BXAudioUtilities checkResult:AudioUnitSetProperty(self.info->audioUnit,
                                                       kAudioUnitProperty_StreamFormat,
                                                       kAudioUnitScope_Output,
                                                       1,
                                                       &asbd,
                                                       sizeof(asbd))
                        operation:"Failed to set stream format on output scope"];
    
    //
    // Allocate scratch buffers
    //
    UInt32 maximumBufferSize = [self maximumBufferSize];
    BOOL isInterleaved = [BXAudioUtilities isInterleaved:asbd];
    UInt32 channels = asbd.mChannelsPerFrame;
    self.floatConverter = [[BXAudioFloatConverter alloc] initWithInputFormat:asbd];
    self.info->floatData = [BXAudioUtilities floatBuffersWithNumberOfFrames:maximumBufferSize
                                                           numberOfChannels:channels];
    self.info->audioBufferList = [BXAudioUtilities audioBufferListWithNumberOfFrames:maximumBufferSize
                                                                    numberOfChannels:channels
                                                                         interleaved:isInterleaved];
    //
    // Notify delegate
    //
    if ([self.delegate respondsToSelector:@selector(microphone:hasAudioStreamBasicDescription:)])
    {
        [self.delegate microphone:self hasAudioStreamBasicDescription:asbd];
    }
}
- (UInt32)maximumBufferSize
{
    UInt32 maximumBufferSize;
    UInt32 propSize = sizeof(maximumBufferSize);
    [BXAudioUtilities checkResult:AudioUnitGetProperty(self.info->audioUnit,
                                                       kAudioUnitProperty_MaximumFramesPerSlice,
                                                       kAudioUnitScope_Global,
                                                       0,
                                                       &maximumBufferSize,
                                                       &propSize)
                        operation:"Failed to get maximum number of frames per slice"];
    return maximumBufferSize;
}

- (AudioStreamBasicDescription)defaultStreamFormat
{
    return [BXAudioUtilities floatFormatWithNumberOfChannels:1
                                                  sampleRate:self.info->inputFormat.mSampleRate];
}

- (void)setDevice:(BXAudioDevice *)device
{
#if TARGET_OS_IPHONE
    
    // if the devices are equal then ignore
    if ([device isEqual:self.device])
    {
        return;
    }
    
    NSError *error;
    [[AVAudioSession sharedInstance] setPreferredInput:device.port error:&error];
    if (error)
    {
        NSLog(@"Error setting input device port (%@), reason: %@",
              device.port,
              error.localizedDescription);
    }
    else
    {
        if (device.dataSource)
        {
            [[AVAudioSession sharedInstance] setInputDataSource:device.dataSource error:&error];
            if (error)
            {
                NSLog(@"Error setting input data source (%@), reason: %@",
                      device.dataSource,
                      error.localizedDescription);
            }
        }
    }
    
#elif TARGET_OS_MAC
    UInt32 inputEnabled = device.inputChannelCount > 0;
    [EZAudioUtilities checkResult:AudioUnitSetProperty(self.info->audioUnit,
                                                       kAudioOutputUnitProperty_EnableIO,
                                                       kAudioUnitScope_Input,
                                                       1,
                                                       &inputEnabled,
                                                       sizeof(inputEnabled))
                        operation:"Failed to set flag on device input"];
    
    UInt32 outputEnabled = device.outputChannelCount > 0;
    [EZAudioUtilities checkResult:AudioUnitSetProperty(self.info->audioUnit,
                                                       kAudioOutputUnitProperty_EnableIO,
                                                       kAudioUnitScope_Output,
                                                       0,
                                                       &outputEnabled,
                                                       sizeof(outputEnabled))
                        operation:"Failed to set flag on device output"];
    
    AudioDeviceID deviceId = device.deviceID;
    [EZAudioUtilities checkResult:AudioUnitSetProperty(self.info->audioUnit,
                                                       kAudioOutputUnitProperty_CurrentDevice,
                                                       kAudioUnitScope_Global,
                                                       0,
                                                       &deviceId,
                                                       sizeof(AudioDeviceID))
                        operation:"Couldn't set default device on I/O unit"];
#endif
    
    //
    // Store device
    //
    _device = device;
    
    //
    // Notify delegate
    //
    if ([self.delegate respondsToSelector:@selector(microphone:changedDevice:)])
    {
        [self.delegate microphone:self changedDevice:device];
    }
}
-(AudioStreamBasicDescription)audioStreamBasicDescription
{
    return self.info->streamFormat;
}

-(void)startFetchingAudio
{
   
    [BXAudioUtilities checkResult:AudioOutputUnitStart(self.info->audioUnit)
                        operation:"Failed to start microphone audio unit"];
    
    
    if ([self.delegate respondsToSelector:@selector(microphone:changedPlayingState:)])
    {
        [self.delegate microphone:self changedPlayingState:YES];
    }
}
-(void)stopFetchingAudio
{
    //
    // Stop output unit
    //
    [BXAudioUtilities checkResult:AudioOutputUnitStop(self.info->audioUnit)
                        operation:"Failed to stop microphone audio unit"];
    
    //
    // Notify delegate
    //
    if ([self.delegate respondsToSelector:@selector(microphone:changedPlayingState:)])
    {
        [self.delegate microphone:self changedPlayingState:NO];
    }
}


@end
