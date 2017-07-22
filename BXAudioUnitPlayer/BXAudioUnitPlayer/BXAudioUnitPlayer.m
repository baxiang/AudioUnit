//
//  BXAudioUnitPlayer.m
//  BXAudioUnitPlayer
//
//  Created by baxiang on 2017/7/22.
//  Copyright © 2017年 baxiang. All rights reserved.
//

#import "BXAudioUnitPlayer.h"
#import <AudioToolbox/AudioToolbox.h>
@interface BXAudioUnitPlayer()<NSURLSessionDelegate>
{
    AudioUnit _outAudioUinit;
    AudioBufferList *_renderBufferList;
    AudioFileStreamID _audioFileStreamID;
    AudioConverterRef _converter;
    AudioStreamBasicDescription _streamDescription;
    NSInteger _readedPacketIndex;
    UInt32 _renderBufferSize;
}
@property(nonatomic,strong) NSMutableArray<NSData*> *paketsArray;
@end
@implementation BXAudioUnitPlayer

static AudioStreamBasicDescription PCMStreamDescription()
{
    AudioStreamBasicDescription description;
    description.mSampleRate = 44100.0;
    description.mFormatID = kAudioFormatLinearPCM;
    description.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;
    description.mFramesPerPacket = 1;
    description.mBytesPerPacket = 4;
    description.mBytesPerFrame = 4;
    description.mChannelsPerFrame = 2;
    description.mBitsPerChannel = 16;
    description.mReserved = 0;
    return description;
}
 OSStatus BXAudioConverterComplexInputDataProc(AudioConverterRef inAudioConverter,UInt32 * ioNumberDataPackets,AudioBufferList *  ioData,AudioStreamPacketDescription * __nullable * __nullable outDataPacketDescription,void * __nullable inUserData)
{
     BXAudioUnitPlayer *self = (__bridge BXAudioUnitPlayer *)(inUserData);
    if (self->_readedPacketIndex >= self.paketsArray.count) {
        NSLog(@"No Data");
        return 'bxmo';
    }
    NSData *packet = self.paketsArray[self->_readedPacketIndex];
    ioData->mNumberBuffers = 1;
    ioData->mBuffers[0].mData = (void *)packet.bytes;
    ioData->mBuffers[0].mDataByteSize = (UInt32)packet.length;
    
    static AudioStreamPacketDescription aspdesc;
    aspdesc.mDataByteSize = (UInt32)packet.length;
    aspdesc.mStartOffset = 0;
    aspdesc.mVariableFramesInPacket = 1;
    *outDataPacketDescription = &aspdesc;
    self->_readedPacketIndex++;
    return 0;

}

 OSStatus  BXAURenderCallback(void *inRefCon,AudioUnitRenderActionFlags *	ioActionFlags,const AudioTimeStamp *inTimeStamp,UInt32	inBusNumber,UInt32 inNumberFrames, AudioBufferList * __nullable ioData){
     BXAudioUnitPlayer *self = (__bridge BXAudioUnitPlayer *)(inRefCon);
     @synchronized (self) {
         if (self->_readedPacketIndex < self.paketsArray.count) {
             @autoreleasepool {
                 UInt32 packetSize = inNumberFrames;
                 OSStatus status = AudioConverterFillComplexBuffer(self->_converter, BXAudioConverterComplexInputDataProc, (__bridge void *)self, &packetSize, self->_renderBufferList, NULL);
                 if (status != noErr && status != 'bxnd') {
                     [self stop];
                     return -1;
                 }
                 else if (!packetSize) {
                     ioData->mNumberBuffers = 0;
                 }
                 else {
                     ioData->mNumberBuffers = 1;
                     ioData->mBuffers[0].mNumberChannels = 2;
                     ioData->mBuffers[0].mDataByteSize = self->_renderBufferList->mBuffers[0].mDataByteSize;
                     ioData->mBuffers[0].mData =self->_renderBufferList->mBuffers[0].mData;
                     self->_renderBufferList->mBuffers[0].mDataByteSize = self->_renderBufferSize;
                 }
             }
         }
         else {
             ioData->mNumberBuffers = 0;
             return -1;
         }
     }
     return noErr;
     
 }

 void BXAudioFileStream_PropertyListenerProc(void *	inClientData,AudioFileStreamID				inAudioFileStream,AudioFileStreamPropertyID	inPropertyID,AudioFileStreamPropertyFlags *	ioFlags)
{
    if (inPropertyID == kAudioFileStreamProperty_DataFormat) {
        
        BXAudioUnitPlayer *self = (__bridge BXAudioUnitPlayer *)(inClientData);
        UInt32 dataSize = 0;
        Boolean writable = false;
        OSStatus status = AudioFileStreamGetPropertyInfo(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &dataSize, &writable);
        assert(status == noErr);
       
        status = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &dataSize, &self->_streamDescription);
        assert(status == noErr);
        AudioStreamBasicDescription destFormat = PCMStreamDescription();
        status = AudioConverterNew(&self->_streamDescription, &destFormat, &self->_converter);
        assert(status == noErr);
    }

}

 void BXAudioFileStreamPacketsProc(void *inClientData,UInt32 inNumberBytes,UInt32							inNumberPackets,const void *inInputData,AudioStreamPacketDescription *inPacketDescriptions)
{
     BXAudioUnitPlayer *self = (__bridge BXAudioUnitPlayer *)(inClientData);
    if (inPacketDescriptions) {
        for (int i = 0; i < inNumberPackets; i++) {
            SInt64 packetOffset = inPacketDescriptions[i].mStartOffset;
            UInt32 packetSize = inPacketDescriptions[i].mDataByteSize;
            assert(packetSize > 0);
            NSData *packet = [NSData dataWithBytes:inInputData + packetOffset length:packetSize];
            [self.paketsArray addObject:packet];
        }
    }
    
    if (self->_readedPacketIndex == 0 && self.paketsArray.count > [self packetsPerSecond] * 3) {
            [self play];
        
    }
}

- (double)packetsPerSecond
{
    if (_streamDescription.mFramesPerPacket) {
        return _streamDescription.mSampleRate / _streamDescription.mFramesPerPacket;
    }
    return 44100.0 / 1152.0;
}
-(instancetype)initWithURL:(NSURL*)url
{
    if (self = [super init]) {
        _paketsArray = [NSMutableArray arrayWithCapacity:0];
        [self setupOutAudioUnit];
        AudioFileStreamOpen((__bridge void * _Nullable)(self), BXAudioFileStream_PropertyListenerProc, BXAudioFileStreamPacketsProc, 0, &_audioFileStreamID);
      NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
        NSURLSessionDataTask *task = [urlSession dataTaskWithURL:url];
        [task resume];
    }
    return self;
}
-(void)setupOutAudioUnit
{
    AudioComponentDescription outputUinitDesc;
    memset(&outputUinitDesc, 0, sizeof(AudioComponentDescription));
    outputUinitDesc.componentType = kAudioUnitType_Output;
    outputUinitDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    outputUinitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputUinitDesc.componentFlags = 0;
    outputUinitDesc.componentFlagsMask = 0;
    AudioComponent outComponent = AudioComponentFindNext(NULL, &outputUinitDesc);
    OSStatus status = AudioComponentInstanceNew(outComponent, &_outAudioUinit);
    assert(status == noErr);
    
    AudioStreamBasicDescription pcmStreamDesc = PCMStreamDescription();
    AudioUnitSetProperty(_outAudioUinit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &pcmStreamDesc, sizeof(pcmStreamDesc));
    
    AURenderCallbackStruct callBackStruct;
    callBackStruct.inputProc = BXAURenderCallback;
    callBackStruct.inputProcRefCon = (__bridge void * _Nullable)(self);
    AudioUnitSetProperty(_outAudioUinit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0, &callBackStruct, sizeof(AURenderCallbackStruct));
    UInt32 bufferSize = 4096 * 4;
    _renderBufferSize = bufferSize;
    _renderBufferList = calloc(4, sizeof(UInt32)+sizeof(bufferSize));
    _renderBufferList->mNumberBuffers = 1;
    _renderBufferList->mBuffers[0].mData = calloc(1, bufferSize);
    _renderBufferList->mBuffers[0].mDataByteSize = bufferSize;
    _renderBufferList->mBuffers[0].mNumberChannels = 2;
    
}

#pragma mark -NSURLSessionDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    OSStatus status = AudioFileStreamParseBytes(_audioFileStreamID, (UInt32)data.length, data.bytes, 0);
    assert(status == noErr);
}

- (void)play
{
    OSStatus status = AudioOutputUnitStart(_outAudioUinit);
    assert(status == noErr);
}
- (void)stop
{
    OSStatus status = AudioOutputUnitStop(_outAudioUinit);
    assert(status == noErr);
}
@end
