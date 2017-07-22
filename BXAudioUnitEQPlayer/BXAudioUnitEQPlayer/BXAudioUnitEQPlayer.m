//
//  BXAudioUnitEQPlayer.m
//  BXAudioUnitEQPlayer
//
//  Created by baxiang on 2017/7/22.
//  Copyright © 2017年 baxiang. All rights reserved.
//

#import "BXAudioUnitEQPlayer.h"

@interface BXAudioUnitEQPlayer ()<NSURLSessionDelegate>
{
    AUGraph _audioGraph;
    AudioUnit _EQUnit;
    AudioUnit _outUnit;
    AudioBufferList *_renderBufferList;
    UInt32 _renderBufferSize;
    AudioStreamBasicDescription streamDescription;
    AudioFileStreamID  _outAudioFileStream;
    AudioConverterRef _converter;
    NSInteger _readPacketIndex;
}
@property(nonatomic,strong) NSMutableArray *packetArray;
@end
@implementation BXAudioUnitEQPlayer
static AudioStreamBasicDescription PCMStreamDescription()
{
    AudioStreamBasicDescription description;
    bzero(&description, sizeof(AudioStreamBasicDescription));
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
static OSStatus BXPlayerConverterFiller(AudioConverterRef inAudioConverter, UInt32 * ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription** outDataPacketDescription, void * inUserData)
{
   
    BXAudioUnitEQPlayer *self = (__bridge BXAudioUnitEQPlayer *)(inUserData);
    
    if (self->_readPacketIndex >= self->_packetArray.count) {
        *ioNumberDataPackets = 0;
        return 'bxnd';
    }
    NSData *packet = self->_packetArray[self->_readPacketIndex];
    ioData->mNumberBuffers = 1;
    ioData->mBuffers[0].mData = (void *)packet.bytes;
    ioData->mBuffers[0].mDataByteSize = (UInt32)packet.length;
    
    static AudioStreamPacketDescription aspdesc;
    aspdesc.mDataByteSize = (UInt32)packet.length;
    aspdesc.mStartOffset = 0;
    aspdesc.mVariableFramesInPacket = 1;
    *outDataPacketDescription = &aspdesc;
    self->_readPacketIndex++;
     *ioNumberDataPackets = 1;
    return noErr;
}
static OSStatus BXPlayerAURenderCallback(void * userData, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    
    BXAudioUnitEQPlayer *self = (__bridge BXAudioUnitEQPlayer *)(userData);
    @synchronized (self) {
        if (self->_readPacketIndex < self.packetArray.count) {
            @autoreleasepool {
                
                UInt32 packetSize = inNumberFrames;
                OSStatus status = AudioConverterFillComplexBuffer(self->_converter, BXPlayerConverterFiller, (__bridge void *)self, &packetSize, self->_renderBufferList, NULL);
                
                if (status != noErr && status != 'bxna') {
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
                    ioData->mBuffers[0].mData = self->_renderBufferList->mBuffers[0].mData;
                    // Reset renderBufferList size
                    self->_renderBufferList->mBuffers[0].mDataByteSize =self->_renderBufferSize;
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
static void BXAudioFileStreamPropertyListener(void * inClientData, AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID, UInt32 * ioFlags)
{
    if (inPropertyID == kAudioFileStreamProperty_DataFormat) {
        BXAudioUnitEQPlayer *self = (__bridge BXAudioUnitEQPlayer *)(inClientData);
        UInt32 dataSize = 0;
        Boolean writable = false;
        OSStatus status = AudioFileStreamGetPropertyInfo(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &dataSize, &writable);
        assert(status == noErr);
        status = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &dataSize, &self->streamDescription);
        assert(status == noErr);
        AudioStreamBasicDescription destFormat = PCMStreamDescription();
       AudioConverterNew(&self->streamDescription, &destFormat, &self->_converter);
       
    }
}
static void BXAudioFileStreamPacketsCallback(void * inClientData, UInt32 inNumberBytes, UInt32 inNumberPackets, const void * inInputData, AudioStreamPacketDescription *inPacketDescriptions)
{
    
    BXAudioUnitEQPlayer *self = (__bridge BXAudioUnitEQPlayer *)(inClientData);
    for (int i = 0; i < inNumberPackets; i++) {
        SInt64 packetOffset = inPacketDescriptions[i].mStartOffset;
        UInt32 packetSize = inPacketDescriptions[i].mDataByteSize;
        assert(packetSize > 0);
        NSData *packet = [NSData dataWithBytes:inInputData + packetOffset length:packetSize];
        [self.packetArray addObject:packet];
    }
    
    if (self->_readPacketIndex == 0 && self.packetArray.count > [self packetsPerSecond] * 3) {
            [self play];
        
    }
}
- (double)packetsPerSecond
{
    if (streamDescription.mFramesPerPacket) {
        return streamDescription.mSampleRate / streamDescription.mFramesPerPacket;
    }
    return 44100.0 / 1152.0;
}
- (NSArray*)iPodEQPresetsArray
{
    CFArrayRef presets;
    UInt32 size = sizeof(presets);
    OSStatus status = AudioUnitGetProperty(_EQUnit, kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &presets, &size);
    assert(status == noErr);
    return (__bridge NSArray *)(presets);
}

-(instancetype)initWithURL:(NSURL*)url
{
    if (self = [super init]) {
        _packetArray = [NSMutableArray new];
        [self setupAudioUnit];
        AudioFileStreamOpen((__bridge void *)self, BXAudioFileStreamPropertyListener, BXAudioFileStreamPacketsCallback, 0, &_outAudioFileStream);
       NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
        NSURLSessionDataTask *task = [urlSession dataTaskWithURL:url];
        [task resume];
        
    }
    return self;
}

-(void)setupAudioUnit
{
    NewAUGraph(&_audioGraph);
    AUGraphOpen(_audioGraph);
    
    // EQ
    AudioComponentDescription EQUnitDesc;
    EQUnitDesc.componentType = kAudioUnitType_Effect;
    EQUnitDesc.componentSubType = kAudioUnitSubType_AUiPodEQ;
    EQUnitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    EQUnitDesc.componentFlags = 0;
    EQUnitDesc.componentFlagsMask = 0;
    AUNode EQNode;
    AUGraphAddNode(_audioGraph, &EQUnitDesc, &EQNode);
    
    // out
    AudioComponentDescription outUnitDesc;
    outUnitDesc.componentType = kAudioUnitType_Output;
    outUnitDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    outUnitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    outUnitDesc.componentFlags = 0;
    outUnitDesc.componentFlagsMask = 0;
    AUNode outNode;
    AUGraphAddNode(_audioGraph, &outUnitDesc, &outNode);
    
    AUGraphConnectNodeInput(_audioGraph, EQNode, 0, outNode, 0);
    
   
    AUGraphNodeInfo(_audioGraph, EQNode, &EQUnitDesc, &_EQUnit);
    
    AUGraphNodeInfo(_audioGraph, outNode, &outUnitDesc, &_outUnit);
    
    AudioStreamBasicDescription audioFormat = PCMStreamDescription();
   
    AudioUnitSetProperty(_EQUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &audioFormat, sizeof(audioFormat));
    
    AudioUnitSetProperty(_EQUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &audioFormat, sizeof(audioFormat));
    
    AudioUnitSetProperty(_outUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &audioFormat, sizeof(audioFormat));
    
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    callbackStruct.inputProc = BXPlayerAURenderCallback;
    
    AUGraphSetNodeInputCallback(_audioGraph, EQNode, 0, &callbackStruct);
    AUGraphInitialize(_audioGraph);
    
    UInt32 bufferSize = 4096 * 4;
    _renderBufferSize = bufferSize;
    _renderBufferList = (AudioBufferList *)calloc(1, sizeof(UInt32) + sizeof(AudioBuffer));
    _renderBufferList->mNumberBuffers = 1;
    _renderBufferList->mBuffers[0].mNumberChannels = 2;
    _renderBufferList->mBuffers[0].mDataByteSize = bufferSize;
    _renderBufferList->mBuffers[0].mData = calloc(1, bufferSize);
    
     CAShow(_audioGraph);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    AudioFileStreamParseBytes(_outAudioFileStream, (UInt32)data.length, data.bytes, 0);
}

- (void)play
{
    AUGraphStart(_audioGraph);
}

-(void)stop
{
    AUGraphStop(_audioGraph);
}
- (void)selectEQPreset:(NSInteger)value
{
    AUPreset *preset = (AUPreset *)CFArrayGetValueAtIndex((CFArrayRef)self.iPodEQPresetsArray, value);
    OSStatus status = AudioUnitSetProperty(_EQUnit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, preset, sizeof(AUPreset));
    assert(status == noErr);
}
@end
