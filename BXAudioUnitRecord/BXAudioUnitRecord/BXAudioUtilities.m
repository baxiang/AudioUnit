//
//  BXAudioUtilities.m
//  BXAudioUnitRecord
//
//  Created by baxiang on 2017/7/23.
//  Copyright © 2017年 baxiang. All rights reserved.
//

#import "BXAudioUtilities.h"
//BOOL __shouldExitOnCheckResultFail = YES;
@implementation BXAudioUtilities

+ (AudioStreamBasicDescription)floatFormatWithNumberOfChannels:(UInt32)channels
                                                    sampleRate:(float)sampleRate
{
    AudioStreamBasicDescription asbd;
    UInt32 floatByteSize   = sizeof(float);
    asbd.mBitsPerChannel   = 8 * floatByteSize;
    asbd.mBytesPerFrame    = floatByteSize;
    asbd.mBytesPerPacket   = floatByteSize;
    asbd.mChannelsPerFrame = channels;
    asbd.mFormatFlags      = kAudioFormatFlagIsFloat|kAudioFormatFlagIsNonInterleaved;
    asbd.mFormatID         = kAudioFormatLinearPCM;
    asbd.mFramesPerPacket  = 1;
    asbd.mSampleRate       = sampleRate;
    return asbd;
}


+ (AudioStreamBasicDescription)AIFFFormatWithNumberOfChannels:(UInt32)channels
                                                   sampleRate:(float)sampleRate
{
    AudioStreamBasicDescription asbd;
    memset(&asbd, 0, sizeof(asbd));
    asbd.mFormatID          = kAudioFormatLinearPCM;
    asbd.mFormatFlags       = kAudioFormatFlagIsBigEndian|kAudioFormatFlagIsPacked|kAudioFormatFlagIsSignedInteger;
    asbd.mSampleRate        = sampleRate;
    asbd.mChannelsPerFrame  = channels;
    asbd.mBitsPerChannel    = 32;
    asbd.mBytesPerPacket    = (asbd.mBitsPerChannel / 8) * asbd.mChannelsPerFrame;
    asbd.mFramesPerPacket   = 1;
    asbd.mBytesPerFrame     = (asbd.mBitsPerChannel / 8) * asbd.mChannelsPerFrame;
    return asbd;
}

+ (AudioStreamBasicDescription)M4AFormatWithNumberOfChannels:(UInt32)channels
                                                  sampleRate:(float)sampleRate
{
    AudioStreamBasicDescription asbd;
    memset(&asbd, 0, sizeof(asbd));
    asbd.mFormatID          = kAudioFormatMPEG4AAC;
    asbd.mChannelsPerFrame  = channels;
    asbd.mSampleRate        = sampleRate;
    
    // Fill in the rest of the descriptions using the Audio Format API
    UInt32 propSize = sizeof(asbd);
    [BXAudioUtilities checkResult:AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                                                         0,
                                                         NULL,
                                                         &propSize,
                                                         &asbd)
                        operation:"Failed to fill out the rest of the m4a AudioStreamBasicDescription"];
    
    return asbd;
}
+ (AudioStreamBasicDescription)stereoFloatInterleavedFormatWithSampleRate:(float)sampleRate
{
    AudioStreamBasicDescription asbd;
    UInt32 floatByteSize   = sizeof(float);
    asbd.mChannelsPerFrame = 2;
    asbd.mBitsPerChannel   = 8 * floatByteSize;
    asbd.mBytesPerFrame    = asbd.mChannelsPerFrame * floatByteSize;
    asbd.mFramesPerPacket  = 1;
    asbd.mBytesPerPacket   = asbd.mFramesPerPacket * asbd.mBytesPerFrame;
    asbd.mFormatFlags      = kAudioFormatFlagIsFloat;
    asbd.mFormatID         = kAudioFormatLinearPCM;
    asbd.mSampleRate       = sampleRate;
    asbd.mReserved         = 0;
    return asbd;
}
+ (AudioStreamBasicDescription)stereoCanonicalNonInterleavedFormatWithSampleRate:(float)sampleRate
{
    AudioStreamBasicDescription asbd;
    UInt32 byteSize = sizeof(float);
    asbd.mBitsPerChannel   = 8 * byteSize;
    asbd.mBytesPerFrame    = byteSize;
    asbd.mBytesPerPacket   = byteSize;
    asbd.mChannelsPerFrame = 2;
    asbd.mFormatFlags      = kAudioFormatFlagsNativeFloatPacked|kAudioFormatFlagIsNonInterleaved;
    asbd.mFormatID         = kAudioFormatLinearPCM;
    asbd.mFramesPerPacket  = 1;
    asbd.mSampleRate       = sampleRate;
    return asbd;
}

+ (void)checkResult:(OSStatus)result operation:(const char *)operation
{
    if (result == noErr) return;
    char errorString[20];
    // see if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(result);
    if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4]))
    {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(errorString, "%d", (int)result);
    fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
//    if (__shouldExitOnCheckResultFail)
//    {
        exit(-1);
//    }
}
+ (BOOL)isInterleaved:(AudioStreamBasicDescription)asbd
{
    return !(asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved);
}
+ (float **)floatBuffersWithNumberOfFrames:(UInt32)frames
                          numberOfChannels:(UInt32)channels
{
    size_t size = sizeof(float *) * channels;
    float **buffers = (float **)malloc(size);
    for (int i = 0; i < channels; i++)
    {
        size = sizeof(float) * frames;
        buffers[i] = (float *)malloc(size);
    }
    return buffers;
}
+ (AudioBufferList *)audioBufferListWithNumberOfFrames:(UInt32)frames
                                      numberOfChannels:(UInt32)channels
                                           interleaved:(BOOL)interleaved
{
    unsigned nBuffers;
    unsigned bufferSize;
    unsigned channelsPerBuffer;
    if (interleaved)
    {
        nBuffers = 1;
        bufferSize = sizeof(float) * frames * channels;
        channelsPerBuffer = channels;
    }
    else
    {
        nBuffers = channels;
        bufferSize = sizeof(float) * frames;
        channelsPerBuffer = 1;
    }
    
    AudioBufferList *audioBufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList) + sizeof(AudioBuffer) * (channels-1));
    audioBufferList->mNumberBuffers = nBuffers;
    for(unsigned i = 0; i < nBuffers; i++)
    {
        audioBufferList->mBuffers[i].mNumberChannels = channelsPerBuffer;
        audioBufferList->mBuffers[i].mDataByteSize = bufferSize;
        audioBufferList->mBuffers[i].mData = calloc(bufferSize, 1);
    }
    return audioBufferList;
}
+ (NSString *)displayTimeStringFromSeconds:(NSTimeInterval)seconds
{
    int totalSeconds = (int)ceil(seconds);
    int secondsComponent = totalSeconds % 60;
    int minutesComponent = (totalSeconds / 60) % 60;
    return [NSString stringWithFormat:@"%02d:%02d", minutesComponent, secondsComponent];
}

+ (float)MAP:(float)value
     leftMin:(float)leftMin
     leftMax:(float)leftMax
    rightMin:(float)rightMin
    rightMax:(float)rightMax
{
    float leftSpan    = leftMax  - leftMin;
    float rightSpan   = rightMax - rightMin;
    float valueScaled = ( value  - leftMin) / leftSpan;
    return rightMin + (valueScaled * rightSpan);
}

@end
