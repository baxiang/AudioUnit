//
//  BXAudioFloatConverter.m
//  BXAudioUnitRecord
//
//  Created by baxiang on 2017/7/23.
//  Copyright © 2017年 baxiang. All rights reserved.
//

#import "BXAudioFloatConverter.h"
#import "BXAudioUtilities.h"
typedef struct
{
    AudioConverterRef             converterRef;
    AudioBufferList              *floatAudioBufferList;
    AudioStreamBasicDescription   inputFormat;
    AudioStreamBasicDescription   outputFormat;
    AudioStreamPacketDescription *packetDescriptions;
    UInt32 packetsPerBuffer;
} BXAudioFloatConverterInfo;

UInt32 const BXAudioFloatConverterDefaultPacketSize = 2048;

@interface BXAudioFloatConverter ()
@property (nonatomic, assign) BXAudioFloatConverterInfo *info;
@end
@implementation BXAudioFloatConverter

OSStatus BXAudioFloatConverterCallback(AudioConverterRef             inAudioConverter,
                                       UInt32                       *ioNumberDataPackets,
                                       AudioBufferList              *ioData,
                                       AudioStreamPacketDescription **outDataPacketDescription,
                                       void                         *inUserData)
{
    AudioBufferList *sourceBuffer = (AudioBufferList *)inUserData;
    
    memcpy(ioData,
           sourceBuffer,
           sizeof(AudioBufferList) + (sourceBuffer->mNumberBuffers - 1) * sizeof(AudioBuffer));
    sourceBuffer = NULL;
    
    return noErr;
}


- (instancetype)initWithInputFormat:(AudioStreamBasicDescription)inputFormat
{
    self = [super init];
    if (self)
    {
        self.info = (BXAudioFloatConverterInfo *)malloc(sizeof(BXAudioFloatConverterInfo));
        memset(self.info, 0, sizeof(BXAudioFloatConverterInfo));
        self.info->inputFormat = inputFormat;
        [self setup];
    }
    return self;
}

- (void)setup
{
    // create output format
    self.info->outputFormat = [BXAudioUtilities floatFormatWithNumberOfChannels:self.info->inputFormat.mChannelsPerFrame
                                                                     sampleRate:self.info->inputFormat.mSampleRate];
    
    // create a new instance of the audio converter
    [BXAudioUtilities checkResult:AudioConverterNew(&self.info->inputFormat,
                                                    &self.info->outputFormat,
                                                    &self.info->converterRef)
                        operation:"Failed to create new audio converter"];
    
    // get max packets per buffer so you can allocate a proper AudioBufferList
    UInt32 packetsPerBuffer = 0;
    UInt32 outputBufferSize = BXAudioFloatConverterDefaultPacketSize;
    UInt32 sizePerPacket = self.info->inputFormat.mBytesPerPacket;
    BOOL isVBR = sizePerPacket == 0;
    
    // VBR
    if (isVBR)
    {
        // determine the max output buffer size
        UInt32 maxOutputPacketSize;
        UInt32 propSize = sizeof(maxOutputPacketSize);
        OSStatus result = AudioConverterGetProperty(self.info->converterRef,
                                                    kAudioConverterPropertyMaximumOutputPacketSize,
                                                    &propSize,
                                                    &maxOutputPacketSize);
        if (result != noErr)
        {
            maxOutputPacketSize = BXAudioFloatConverterDefaultPacketSize;
        }
        
        // set the output buffer size to at least the max output size
        if (maxOutputPacketSize > outputBufferSize)
        {
            outputBufferSize = maxOutputPacketSize;
        }
        packetsPerBuffer = outputBufferSize / maxOutputPacketSize;
        
        // allocate memory for the packet descriptions
        self.info->packetDescriptions = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * packetsPerBuffer);
    }
    else
    {
        packetsPerBuffer = outputBufferSize / sizePerPacket;
    }
    self.info->packetsPerBuffer = packetsPerBuffer;
    
    // allocate the AudioBufferList to hold the float values
    BOOL isInterleaved = [BXAudioUtilities isInterleaved:self.info->outputFormat];
    self.info->floatAudioBufferList = [BXAudioUtilities audioBufferListWithNumberOfFrames:packetsPerBuffer
                                                                         numberOfChannels:self.info->outputFormat.mChannelsPerFrame
                                                                              interleaved:isInterleaved];
}

//------------

- (void)convertDataFromAudioBufferList:(AudioBufferList *)audioBufferList
                    withNumberOfFrames:(UInt32)frames
                        toFloatBuffers:(float **)buffers
{
    [self convertDataFromAudioBufferList:audioBufferList
                      withNumberOfFrames:frames
                          toFloatBuffers:buffers
                      packetDescriptions:self.info->packetDescriptions];
}

- (void)convertDataFromAudioBufferList:(AudioBufferList *)audioBufferList
                    withNumberOfFrames:(UInt32)frames
                        toFloatBuffers:(float **)buffers
                    packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions
{
    if (frames != 0)
    {
        //
        // Make sure the data size coming in is consistent with the number
        // of frames we're actually getting
        //
        for (int i = 0; i < audioBufferList->mNumberBuffers; i++) {
            audioBufferList->mBuffers[i].mDataByteSize = frames * self.info->inputFormat.mBytesPerFrame;
        }
        
        //
        // Fill out the audio converter with the source buffer
        //
        [BXAudioUtilities checkResult:AudioConverterFillComplexBuffer(self.info->converterRef,
                                                                      BXAudioFloatConverterCallback,
                                                                      audioBufferList,
                                                                      &frames,
                                                                      self.info->floatAudioBufferList,
                                                                      packetDescriptions ? packetDescriptions : self.info->packetDescriptions)
                            operation:"Failed to fill complex buffer in float converter"];
        
        //
        // Copy the converted buffers into the float buffer array stored
        // in memory
        //
        for (int i = 0; i < self.info->floatAudioBufferList->mNumberBuffers; i++)
        {
            memcpy(buffers[i],
                   self.info->floatAudioBufferList->mBuffers[i].mData,
                   self.info->floatAudioBufferList->mBuffers[i].mDataByteSize);
        }
    }
}
@end
