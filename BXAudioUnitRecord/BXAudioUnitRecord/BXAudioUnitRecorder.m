//
//  BXAudioUnitRecorder.m
//  BXAudioUnitRecord
//
//  Created by baxiang on 2017/7/23.
//  Copyright © 2017年 baxiang. All rights reserved.
//

#import "BXAudioUnitRecorder.h"
#import "BXAudioUtilities.h"

typedef struct
{
    AudioFileTypeID             audioFileTypeID;
    ExtAudioFileRef             extAudioFileRef;
    AudioStreamBasicDescription clientFormat;
    BOOL                        closed;
    CFURLRef                    fileURL;
    AudioStreamBasicDescription fileFormat;
} BXRecorderInfo;

@interface BXAudioUnitRecorder()
{
  AudioUnit audioUnit;
  AudioStreamBasicDescription   inputFormat;
  AudioStreamBasicDescription   streamFormat;
  AudioBufferList              *audioBufferList;
}
@property (nonatomic, assign) BXRecorderInfo *info;
@end
@implementation BXAudioUnitRecorder

- (void)dealloc
{
    if (!self.info->closed)
    {
        [self closeAudioFile];
    }
    free(self.info);
}

+ (instancetype)recorderWithURL:(NSURL *)url
                   clientFormat:(AudioStreamBasicDescription)clientFormat
                       fileType:(BXRecorderFileType)fileType
                       delegate:(id<BXAudioUnitRecorderDelegate>)delegate{

    return [[self alloc] initWithURL:url
                        clientFormat:clientFormat
                            fileType:fileType
                            delegate:delegate];

}

- (instancetype)initWithURL:(NSURL *)url
               clientFormat:(AudioStreamBasicDescription)clientFormat
                   fileType:(BXRecorderFileType)fileType
                   delegate:(id<BXAudioUnitRecorderDelegate>)delegate
{
    AudioStreamBasicDescription fileFormat = [BXAudioUnitRecorder formatForFileType:fileType
                                                          withSourceFormat:clientFormat];
    AudioFileTypeID audioFileTypeID = [BXAudioUnitRecorder fileTypeIdForFileType:fileType
                                                       withSourceFormat:clientFormat];
    return [self initWithURL:url
                clientFormat:clientFormat
                  fileFormat:fileFormat
             audioFileTypeID:audioFileTypeID
                    delegate:delegate];
}

- (instancetype)initWithURL:(NSURL *)url
               clientFormat:(AudioStreamBasicDescription)clientFormat
                 fileFormat:(AudioStreamBasicDescription)fileFormat
            audioFileTypeID:(AudioFileTypeID)audioFileTypeID
                   delegate:(id<BXAudioUnitRecorderDelegate>)delegate
{
    
    self = [super init];
    if (self)
    {
        // Set defaults
        self.info = (BXRecorderInfo *)calloc(1, sizeof(BXRecorderInfo));
        self.info->audioFileTypeID  = audioFileTypeID;
        self.info->fileURL = (__bridge CFURLRef)url;
        self.info->clientFormat = clientFormat;
        self.info->fileFormat = fileFormat;
        self.delegate = delegate;
        [self setup];
    }
    return self;
}

- (void)setup
{
    // Finish filling out the destination format description
    UInt32 propSize = sizeof(self.info->fileFormat);
    [BXAudioUtilities checkResult:AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                                                         0,
                                                         NULL,
                                                         &propSize,
                                                         &self.info->fileFormat)
                        operation:"Failed to fill out rest of destination format"];
    
    //
    // Create the audio file
    //
    [BXAudioUtilities checkResult:ExtAudioFileCreateWithURL(self.info->fileURL,
                                                            self.info->audioFileTypeID,
                                                            &self.info->fileFormat,
                                                            NULL,
                                                            kAudioFileFlags_EraseFile,
                                                            &self.info->extAudioFileRef)
                        operation:"Failed to create audio file"];
    
    [self setClientFormat:self.info->clientFormat];
}
- (void)setClientFormat:(AudioStreamBasicDescription)clientFormat
{
    [BXAudioUtilities checkResult:ExtAudioFileSetProperty(self.info->extAudioFileRef,
                                                          kExtAudioFileProperty_ClientDataFormat,
                                                          sizeof(clientFormat),
                                                          &clientFormat)
                        operation:"Failed to set client format on recorded audio file"];
    self.info->clientFormat = clientFormat;
}

- (void)appendDataFromBufferList:(AudioBufferList *)bufferList
                  withBufferSize:(UInt32)bufferSize
{
    //
    // Make sure the audio file is not closed
    //
    NSAssert(!self.info->closed, @"Cannot append data when EZRecorder has been closed. You must create a new instance.;");
    
    //
    // Perform the write
    //
    [BXAudioUtilities checkResult:ExtAudioFileWrite(self.info->extAudioFileRef,
                                                    bufferSize,
                                                    bufferList)
                        operation:"Failed to write audio data to recorded audio file"];
    
    //
    // Notify delegate
    //
    if ([self.delegate respondsToSelector:@selector(recorderUpdatedCurrentTime:)])
    {
        [self.delegate recorderUpdatedCurrentTime:self];
    }
}
- (void)closeAudioFile
{
    if (!self.info->closed)
    {
        //
        // Close, audio file can no longer be written to
        //
        [BXAudioUtilities checkResult:ExtAudioFileDispose(self.info->extAudioFileRef)
                            operation:"Failed to close audio file"];
        self.info->closed = YES;
        
        //
        // Notify delegate
        //
        if ([self.delegate respondsToSelector:@selector(recorderDidClose:)])
        {
            [self.delegate recorderDidClose:self];
        }
    }
}


+ (AudioFileTypeID)fileTypeIdForFileType:(BXRecorderFileType)fileType
                        withSourceFormat:(AudioStreamBasicDescription)sourceFormat
{
    AudioFileTypeID audioFileTypeID;
    switch (fileType)
    {
        case BXRecorderFileTypeAIFF:
            audioFileTypeID = kAudioFileAIFFType;
            break;
            
        case BXRecorderFileTypeM4A:
            audioFileTypeID = kAudioFileM4AType;
            break;
            
        case BXRecorderFileTypeWAV:
            audioFileTypeID = kAudioFileWAVEType;
            break;
            
        default:
            audioFileTypeID = kAudioFileWAVEType;
            break;
    }
    return audioFileTypeID;
}



+ (AudioStreamBasicDescription)formatForFileType:(BXRecorderFileType)fileType
                                withSourceFormat:(AudioStreamBasicDescription)sourceFormat
{
    AudioStreamBasicDescription asbd;
    switch (fileType)
    {
        case BXRecorderFileTypeAIFF:
            asbd = [BXAudioUtilities AIFFFormatWithNumberOfChannels:sourceFormat.mChannelsPerFrame
                                                         sampleRate:sourceFormat.mSampleRate];
            break;
        case BXRecorderFileTypeM4A:
            asbd = [BXAudioUtilities M4AFormatWithNumberOfChannels:sourceFormat.mChannelsPerFrame
                                                        sampleRate:sourceFormat.mSampleRate];
            break;
            
        case BXRecorderFileTypeWAV:
            asbd = [BXAudioUtilities stereoFloatInterleavedFormatWithSampleRate:sourceFormat.mSampleRate];
            break;
            
        default:
            asbd = [BXAudioUtilities stereoCanonicalNonInterleavedFormatWithSampleRate:sourceFormat.mSampleRate];
            break;
    }
    return asbd;
}
- (NSString *)formattedCurrentTime
{
    return [BXAudioUtilities displayTimeStringFromSeconds:[self currentTime]];
}
- (NSTimeInterval)currentTime
{
    NSTimeInterval currentTime = 0.0;
    NSTimeInterval duration = [self duration];
    if (duration != 0.0)
    {
        currentTime = (NSTimeInterval)[BXAudioUtilities MAP:(float)[self frameIndex]
                                                    leftMin:0.0f
                                                    leftMax:(float)[self totalFrames]
                                                   rightMin:0.0f
                                                   rightMax:duration];
    }
    return currentTime;
}
- (NSTimeInterval)duration
{
    NSTimeInterval frames = (NSTimeInterval)[self totalFrames];
    return (NSTimeInterval) frames / self.info->fileFormat.mSampleRate;
}
- (SInt64)totalFrames
{
    SInt64 totalFrames;
    UInt32 propSize = sizeof(SInt64);
    [BXAudioUtilities checkResult:ExtAudioFileGetProperty(self.info->extAudioFileRef,
                                                          kExtAudioFileProperty_FileLengthFrames,
                                                          &propSize,
                                                          &totalFrames)
                        operation:"Recorder failed to get total frames."];
    return totalFrames;
}
- (SInt64)frameIndex
{
    SInt64 frameIndex;
    [BXAudioUtilities checkResult:ExtAudioFileTell(self.info->extAudioFileRef,
                                                   &frameIndex)
                        operation:"Failed to get frame index"];
    return frameIndex;
}

@end
