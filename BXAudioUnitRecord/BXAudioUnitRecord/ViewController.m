
#import "ViewController.h"

@implementation ViewController

//------------------------------------------------------------------------------
#pragma mark - Dealloc
//------------------------------------------------------------------------------

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

//------------------------------------------------------------------------------
#pragma mark - Status Bar Style
//------------------------------------------------------------------------------

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

//------------------------------------------------------------------------------
#pragma mark - Setup
//------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor grayColor];
   
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error)
    {
        NSLog(@"Error setting up audio session category: %@", error.localizedDescription);
    }
    [session setActive:YES error:&error];
    if (error)
    {
        NSLog(@"Error setting up audio session active: %@", error.localizedDescription);
    }

    
    self.microphone = [BXInputController controllerWithDelegate:self];
    
    //
    // Override the output to the speaker. Do this after creating the EZAudioPlayer
    // to make sure the EZAudioDevice does not reset this.
    //
    [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
    if (error)
    {
        NSLog(@"Error overriding output to the speaker: %@", error.localizedDescription);
    }
    
    //
    // Initialize UI components
    //
    self.microphoneStateLabel.text = @"Microphone On";
    self.recordingStateLabel.text = @"Not Recording";
    self.playingStateLabel.text = @"Not Playing";
    self.playButton.enabled = NO;

    //
    // Setup notifications
    //
   // [self setupNotifications];

    //
    // Log out where the file is being written to within the app's documents directory
    //
    NSLog(@"File written to application sandbox's documents directory: %@",[self testFilePathURL]);

    //
    // Start the microphone
    //
    [self.microphone startFetchingAudio];
}

//------------------------------------------------------------------------------
#pragma mark - Actions
//------------------------------------------------------------------------------

- (void)playFile:(id)sender
{
    //
    // Update microphone state
    //
    [self.microphone stopFetchingAudio];

    //
    // Update recording state
    //
    self.isRecording = NO;
    self.recordingStateLabel.text = @"Not Recording";
    self.recordSwitch.on = NO;

    //
    // Close the audio file
    //
    if (self.recorder)
    {
        [self.recorder closeAudioFile];
    }

//    EZAudioFile *audioFile = [EZAudioFile audioFileWithURL:[self testFilePathURL]];
//    [self.player playAudioFile:audioFile];
}

//------------------------------------------------------------------------------

- (void)toggleMicrophone:(id)sender
{
    //[self.player pause];

    BOOL isOn = [(UISwitch*)sender isOn];
    if (!isOn)
    {
        [self.microphone stopFetchingAudio];
    }
    else
    {
        [self.microphone startFetchingAudio];
    }
}

//------------------------------------------------------------------------------

- (void)toggleRecording:(id)sender
{
    if ([sender isOn])
    {
        [self.microphone startFetchingAudio];
        self.recorder = [BXAudioUnitRecorder recorderWithURL:[self testFilePathURL]
                                       clientFormat:[self.microphone audioStreamBasicDescription]
                                           fileType:BXRecorderFileTypeM4A
                                           delegate:self];
        self.playButton.enabled = YES;
    }else{
        [self.microphone stopFetchingAudio];
        [self.recorder closeAudioFile];
    }
    self.isRecording = (BOOL)[sender isOn];
    self.recordingStateLabel.text = self.isRecording ? @"Recording" : @"Not Recording";
}

//------------------------------------------------------------------------------
#pragma mark - EZMicrophoneDelegate
//------------------------------------------------------------------------------

- (void)microphone:(BXInputController *)microphone changedPlayingState:(BOOL)isPlaying
{
    self.microphoneStateLabel.text = isPlaying ? @"Microphone On" : @"Microphone Off";
    self.microphoneSwitch.on = isPlaying;
}

- (void)   microphone:(BXInputController *)microphone
        hasBufferList:(AudioBufferList *)bufferList
       withBufferSize:(UInt32)bufferSize
 withNumberOfChannels:(UInt32)numberOfChannels
{
    if (self.isRecording)
    {
        [self.recorder appendDataFromBufferList:bufferList
                                 withBufferSize:bufferSize];
    }
}


- (void)recorderDidClose:(BXAudioUnitRecorder *)recorder
{
    recorder.delegate = nil;
}

//------------------------------------------------------------------------------

- (void)recorderUpdatedCurrentTime:(BXAudioUnitRecorder *)recorder
{
//    __weak typeof (self) weakSelf = self;
//    NSString *formattedCurrentTime = [recorder formattedCurrentTime];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        weakSelf.currentTimeLabel.text = formattedCurrentTime;
//    });
}


//------------------------------------------------------------------------------
#pragma mark - Utility
//------------------------------------------------------------------------------

- (NSArray *)applicationDocuments
{
  return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
}

//------------------------------------------------------------------------------

- (NSString *)applicationDocumentsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

//------------------------------------------------------------------------------

- (NSURL *)testFilePathURL
{
    return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",
                                   [self applicationDocumentsDirectory],
                                   kAudioFilePath]];
}

@end
