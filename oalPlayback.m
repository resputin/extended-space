

#import "oalPlayback.h"
#import "MyOpenALSupport.h"


@implementation oalPlayback

@synthesize context;
@synthesize isPlaying;
@synthesize wasInterrupted;
@synthesize listenerRotation;
@synthesize iPodIsPlaying;

#pragma mark AVAudioSession
- (void)handleInterruption:(NSNotification *)notification
{
    UInt8 theInterruptionType = [[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
    
    NSLog(@"Session interrupted > --- %s ---\n", theInterruptionType == AVAudioSessionInterruptionTypeBegan ? "Begin Interruption" : "End Interruption");
    
    if (theInterruptionType == AVAudioSessionInterruptionTypeBegan) {
        alcMakeContextCurrent(NULL);
        if (self.isPlaying) {
            self.wasInterrupted = YES;
        }
    } else if (theInterruptionType == AVAudioSessionInterruptionTypeEnded) {
        // make sure to activate the session
        NSError *error;
        bool success = [[AVAudioSession sharedInstance] setActive:YES error:&error];
        if (!success) NSLog(@"Error setting session active! %@\n", [error localizedDescription]);
        
        alcMakeContextCurrent(self.context);
        
        if (self.wasInterrupted)
        {
            [self startSound];
            self.wasInterrupted = NO;
        }
    }
}

#pragma mark -Audio Session Route Change Notification

- (void)handleRouteChange:(NSNotification *)notification
{
    UInt8 reasonValue = [[notification.userInfo valueForKey:AVAudioSessionRouteChangeReasonKey] intValue];
    AVAudioSessionRouteDescription *routeDescription = [notification.userInfo valueForKey:AVAudioSessionRouteChangePreviousRouteKey];
    
    NSLog(@"Route change:");
    switch (reasonValue) {
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            NSLog(@"     NewDeviceAvailable");
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            NSLog(@"     OldDeviceUnavailable");
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:
            NSLog(@"     CategoryChange");
            NSLog(@" New Category: %@", [[AVAudioSession sharedInstance] category]);
            break;
        case AVAudioSessionRouteChangeReasonOverride:
            NSLog(@"     Override");
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
            NSLog(@"     WakeFromSleep");
            break;
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
            NSLog(@"     NoSuitableRouteForCategory");
            break;
        default:
            NSLog(@"     ReasonUnknown");
    }
    
    NSLog(@"Previous route:\n");
    NSLog(@"%@", routeDescription);
}

- (void)initAVAudioSession
{
    // Configure the audio session
    AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
    NSError *error;
    
    // set the session category
    iPodIsPlaying = [sessionInstance isOtherAudioPlaying];
    NSString *category = iPodIsPlaying ? AVAudioSessionCategoryAmbient : AVAudioSessionCategorySoloAmbient;
    bool success = [sessionInstance setCategory:category error:&error];
    if (!success) NSLog(@"Error setting AVAudioSession category! %@\n", [error localizedDescription]);
    
    double hwSampleRate = 44100.0;
    success = [sessionInstance setPreferredSampleRate:hwSampleRate error:&error];
    if (!success) NSLog(@"Error setting preferred sample rate! %@\n", [error localizedDescription]);
    
    // add interruption handler
    [[NSNotificationCenter defaultCenter]   addObserver:self
                                            selector:@selector(handleInterruption:)
                                            name:AVAudioSessionInterruptionNotification
                                            object:sessionInstance];
    
    // we don't do anything special in the route change notification
    [[NSNotificationCenter defaultCenter]   addObserver:self
                                            selector:@selector(handleRouteChange:)
                                            name:AVAudioSessionRouteChangeNotification
                                            object:sessionInstance];
    
    // activate the audio session
    success = [sessionInstance setActive:YES error:&error];
    if (!success) NSLog(@"Error setting session active! %@\n", [error localizedDescription]);
}

#pragma mark Object Init / Maintenance
- (id)init
{	
	if (self = [super init]) {
		// Start with our sound source slightly in front of the listener
        sourcePos1 = CGPointMake(0., -42.5);
        sourcePos2 = CGPointMake(0., -135.);
        sourcePos3 = CGPointMake(95., -135.);
        sourcePos4 = CGPointMake(95., -45.);
        sourcePos5 = CGPointMake(95., 80.);
        sourcePos6 = CGPointMake(0., 80.);
        sourcePos7 = CGPointMake(-95., 80.);
        sourcePos8 = CGPointMake(-95., -45.);
        sourcePos9 = CGPointMake(-95., -135.);

        
		
		// Put the listener in the center of the stage
		listenerPos = CGPointMake(0., 0.);
		
		// Listener looking straight ahead
		listenerRotation = 0.;
		
		// Setup AVAudioSession
        [self initAVAudioSession];

		bgURL = [[NSURL alloc] initFileURLWithPath: [[NSBundle mainBundle] pathForResource:@"background" ofType:@"m4a"]];
		bgPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:bgURL error:nil];	
				
		wasInterrupted = NO;
		
		// Initialize our OpenAL environment
		[self initOpenAL];
	}
	
	return self;
}

- (void)checkForMusic
{
	if (iPodIsPlaying) {
		//the iPod is playing, so we should disable the background music switch
		NSLog(@"Disabling background music, iPod is active");
		musicSwitch.enabled = NO;
	}
	else {
		musicSwitch.enabled = NO;
	}
}

- (void)dealloc
{
	[super dealloc];

	[self teardownOpenAL];
	[bgURL release];
	[bgPlayer release];
}

#pragma mark AVAudioPlayer

- (IBAction)toggleMusic:(UISwitch*)sender {
	NSLog(@"togging music %s", sender.on ? "on" : "off");
	
	if (bgPlayer) {
	
		if (sender.on) {
			[bgPlayer play];
		}
		else {
			[bgPlayer stop];
		}
	}	
}

#pragma mark OpenAL

- (void) initBuffer
{
	ALenum  error = AL_NO_ERROR;
	ALenum  format;
	ALsizei size;
	ALsizei freq;
	
	NSBundle*				bundle = [NSBundle mainBundle];
        
    
	// get some audio data from a wave file
	CFURLRef fileURL1 = (CFURLRef)[[NSURL fileURLWithPath:[bundle pathForResource:@"comp1quiet" ofType:@"aif"]] retain];
	
	if (fileURL1)
	{	
		data = MyGetOpenALAudioData(fileURL1, &size, &format, &freq);
		CFRelease(fileURL1);
		
		if((error = alGetError()) != AL_NO_ERROR) {
			NSLog(@"error loading sound: %x\n", error);
			exit(1);
		}
		
		// use the static buffer data API
		alBufferDataStaticProc(buffer[0], format, data, size, freq);
		
		if((error = alGetError()) != AL_NO_ERROR) {
			NSLog(@"error attaching audio to buffer: %x\n", error);
		}		
	}
	else
		NSLog(@"Could not find file!\n");
    
    CFURLRef fileURL2 = (CFURLRef)[[NSURL fileURLWithPath:[bundle pathForResource:@"comp2quiet" ofType:@"aif"]] retain];
    
    if (fileURL2)
    {
        data = MyGetOpenALAudioData(fileURL2, &size, &format, &freq);
        CFRelease(fileURL2);
        
        if((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"error loading sound: %x\n", error);
            exit(1);
        }
        
        // use the static buffer data API
        alBufferDataStaticProc(buffer[1], format, data, size, freq);
        
        if((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"error attaching audio to buffer: %x\n", error);
        }		
    }
    else
        NSLog(@"Could not find file!\n");
    
    CFURLRef fileURL3 = (CFURLRef)[[NSURL fileURLWithPath:[bundle pathForResource:@"comp3quiet" ofType:@"aif"]] retain];
    
    if (fileURL3)
    {
        data = MyGetOpenALAudioData(fileURL3, &size, &format, &freq);
        CFRelease(fileURL3);
        
        if((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"error loading sound: %x\n", error);
            exit(1);
        }
        
        // use the static buffer data API
        alBufferDataStaticProc(buffer[2], format, data, size, freq);
        
        if((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"error attaching audio to buffer: %x\n", error);
        }		
    }
    else
        NSLog(@"Could not find file!\n");
    
    CFURLRef fileURL4 = (CFURLRef)[[NSURL fileURLWithPath:[bundle pathForResource:@"comp4quiet" ofType:@"aif"]] retain];
    
    if (fileURL4)
    {
        data = MyGetOpenALAudioData(fileURL4, &size, &format, &freq);
        CFRelease(fileURL4);
        
        if((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"error loading sound: %x\n", error);
            exit(1);
        }
        
        // use the static buffer data API
        alBufferDataStaticProc(buffer[3], format, data, size, freq);
        
        if((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"error attaching audio to buffer: %x\n", error);
        }		
    }
    else
        NSLog(@"Could not find file!\n");
    
    CFURLRef fileURL5 = (CFURLRef)[[NSURL fileURLWithPath:[bundle pathForResource:@"comp5quiet" ofType:@"aif"]] retain];
    
    if (fileURL5)
    {
        data = MyGetOpenALAudioData(fileURL5, &size, &format, &freq);
        CFRelease(fileURL5);
        
        if((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"error loading sound: %x\n", error);
            exit(1);
        }
        
        // use the static buffer data API
        alBufferDataStaticProc(buffer[4], format, data, size, freq);
        
        if((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"error attaching audio to buffer: %x\n", error);
        }		
    }
    else
        NSLog(@"Could not find file!\n");
    
    CFURLRef fileURL6 = (CFURLRef)[[NSURL fileURLWithPath:[bundle pathForResource:@"comp6quiet" ofType:@"aif"]] retain];
    
    if (fileURL6)
    {
        data = MyGetOpenALAudioData(fileURL6, &size, &format, &freq);
        CFRelease(fileURL6);
        
        if((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"error loading sound: %x\n", error);
            exit(1);
        }
        
        // use the static buffer data API
        alBufferDataStaticProc(buffer[5], format, data, size, freq);
        
        if((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"error attaching audio to buffer: %x\n", error);
        }		
    }
    else
        NSLog(@"Could not find file!\n");
    
    CFURLRef fileURL7 = (CFURLRef)[[NSURL fileURLWithPath:[bundle pathForResource:@"comp7quiet" ofType:@"aif"]] retain];
    
    if (fileURL7)
    {
        data = MyGetOpenALAudioData(fileURL7, &size, &format, &freq);
        CFRelease(fileURL7);
        
        if((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"error loading sound: %x\n", error);
            exit(1);
        }
        
        // use the static buffer data API
        alBufferDataStaticProc(buffer[6], format, data, size, freq);
        
        if((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"error attaching audio to buffer: %x\n", error);
        }		
    }
    else
        NSLog(@"Could not find file!\n");
    
    CFURLRef fileURL8 = (CFURLRef)[[NSURL fileURLWithPath:[bundle pathForResource:@"comp8quiet" ofType:@"aif"]] retain];
    
    if (fileURL8)
    {
        data = MyGetOpenALAudioData(fileURL8, &size, &format, &freq);
        CFRelease(fileURL8);
        
        if((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"error loading sound: %x\n", error);
            exit(1);
        }
        
        // use the static buffer data API
        alBufferDataStaticProc(buffer[7], format, data, size, freq);
        
        if((error = alGetError()) != AL_NO_ERROR) {
            NSLog(@"error attaching audio to buffer: %x\n", error);
        }		
    }
    else
        NSLog(@"Could not find file!\n");
     
}

- (void) initSource
{
	ALenum error = AL_NO_ERROR;
	alGetError(); // Clear the error
    
	// Turn Looping ON
	alSourcei(source[0], AL_LOOPING, AL_TRUE);
    alSourcei(source[1], AL_LOOPING, AL_TRUE);
    alSourcei(source[2], AL_LOOPING, AL_TRUE);
    alSourcei(source[3], AL_LOOPING, AL_TRUE);
    alSourcei(source[4], AL_LOOPING, AL_TRUE);
    alSourcei(source[5], AL_LOOPING, AL_TRUE);
    alSourcei(source[6], AL_LOOPING, AL_TRUE);
    alSourcei(source[7], AL_LOOPING, AL_TRUE);
	
	// Set Source Position
	float sourcePosAL1[] = {sourcePos8.x, kDefaultDistance, sourcePos8.y};
	alSourcefv(source[0], AL_POSITION, sourcePosAL1);
    float sourcePosAL2[] = {sourcePos2.x, kDefaultDistance, sourcePos2.y};
    alSourcefv(source[1], AL_POSITION, sourcePosAL2);
    float sourcePosAL3[] = {sourcePos3.x, kDefaultDistance, sourcePos3.y};
    alSourcefv(source[2], AL_POSITION, sourcePosAL3);
    float sourcePosAL4[] = {sourcePos4.x, kDefaultDistance, sourcePos4.y};
    alSourcefv(source[3], AL_POSITION, sourcePosAL4);
    float sourcePosAL5[] = {sourcePos5.x, kDefaultDistance, sourcePos5.y};
    alSourcefv(source[4], AL_POSITION, sourcePosAL5);
    float sourcePosAL6[] = {sourcePos6.x, kDefaultDistance, sourcePos6.y};
    alSourcefv(source[5], AL_POSITION, sourcePosAL6);
    float sourcePosAL7[] = {sourcePos7.x, kDefaultDistance, sourcePos7.y};
    alSourcefv(source[6], AL_POSITION, sourcePosAL7);
    float sourcePosAL8[] = {sourcePos9.x, kDefaultDistance, sourcePos9.y};
    alSourcefv(source[7], AL_POSITION, sourcePosAL8);
	
	// Set Source Reference Distance
	alSourcef(source[0], AL_REFERENCE_DISTANCE, 5.0f);
    alSourcef(source[1], AL_REFERENCE_DISTANCE, 5.0f);
    alSourcef(source[2], AL_REFERENCE_DISTANCE, 5.0f);
    alSourcef(source[3], AL_REFERENCE_DISTANCE, 5.0f);
    alSourcef(source[4], AL_REFERENCE_DISTANCE, 5.0f);
    alSourcef(source[5], AL_REFERENCE_DISTANCE, 5.0f);
    alSourcef(source[6], AL_REFERENCE_DISTANCE, 5.0f);
    alSourcef(source[7], AL_REFERENCE_DISTANCE, 5.0f);
    

	
	// attach OpenAL Buffer to OpenAL Source
	alSourcei(source[0], AL_BUFFER, buffer[0]);
    alSourcei(source[1], AL_BUFFER, buffer[1]);
    alSourcei(source[2], AL_BUFFER, buffer[2]);
    alSourcei(source[3], AL_BUFFER, buffer[3]);
    alSourcei(source[4], AL_BUFFER, buffer[4]);
    alSourcei(source[5], AL_BUFFER, buffer[5]);
    alSourcei(source[6], AL_BUFFER, buffer[6]);
    alSourcei(source[7], AL_BUFFER, buffer[7]);
	
	if((error = alGetError()) != AL_NO_ERROR) {
		NSLog(@"Error attaching buffer to source: %x\n", error);
		//exit(1);
	}	
}


- (void)initOpenAL
{
	ALenum			error;
	
	// Create a new OpenAL Device
	// Pass NULL to specify the system’s default output device
	device = alcOpenDevice(NULL);
	if (device != NULL)
	{
		// Create a new OpenAL Context
		// The new context will render to the OpenAL Device just created 
		context = alcCreateContext(device, 0);
		if (context != NULL)
		{
			// Make the new context the Current OpenAL Context
			alcMakeContextCurrent(context);
			
			// Create some OpenAL Buffer Objects
			alGenBuffers(8, &buffer);
			if((error = alGetError()) != AL_NO_ERROR) {
				NSLog(@"Error Generating Buffers: %x", error);
				exit(1);
			}
			
			// Create some OpenAL Source Objects
			alGenSources(8, &source);
			if(alGetError() != AL_NO_ERROR) 
			{
				NSLog(@"Error generating sources! %x\n", error);
				exit(1);
			}
			
		}
	}
	// clear any errors
	alGetError();
	
	[self initBuffer];	
	[self initSource];
}

- (void)teardownOpenAL
{	
	// Delete the Sources
    alDeleteSources(8, &source);
	// Delete the Buffers
    alDeleteBuffers(8, &buffer);
	
    //Release context
    alcDestroyContext(context);
    //Close device
    alcCloseDevice(device);
}

#pragma mark Play / Pause

- (void)startSound
{
	ALenum error;
	
	NSLog(@"Start!\n");
	// Begin playing our source file
	alSourcePlay(source[0]);
    alSourcePlay(source[1]);
    alSourcePlay(source[2]);
    alSourcePlay(source[3]);
    alSourcePlay(source[4]);
    alSourcePlay(source[5]);
    alSourcePlay(source[6]);
    alSourcePlay(source[7]);
	if((error = alGetError()) != AL_NO_ERROR) {
		NSLog(@"error starting source: %x\n", error);
	} else {
		// Mark our state as playing (the view looks at this)
		self.isPlaying = YES;
	}
}

- (void)stopSound
{
	ALenum error;
	
	NSLog(@"Stop!!\n");
	// Stop playing our source file
	alSourceStop(source[0]);
    alSourceStop(source[1]);
    alSourceStop(source[2]);
    alSourceStop(source[3]);
    alSourceStop(source[4]);
    alSourceStop(source[5]);
    alSourceStop(source[6]);
    alSourceStop(source[7]);

	if((error = alGetError()) != AL_NO_ERROR) {
		NSLog(@"error stopping source: %x\n", error);
	} else {
		// Mark our state as not playing (the view looks at this)
		self.isPlaying = NO;
	}
}

#pragma mark Setters / Getters

- (ALCcontext *)context
{
    return context;
}

- (CGPoint)sourcePos
{
	return sourcePos1;
}

- (CGPoint)sourcePos2
{
    return sourcePos2;
}

- (CGPoint)sourcePos3
{
    return sourcePos3;
}

- (CGPoint)sourcePos4
{
    return sourcePos4;
}

- (CGPoint)sourcePos5
{
    return sourcePos5;
}

- (CGPoint)sourcePos6
{
    return sourcePos6;
}

- (CGPoint)sourcePos7
{
    return sourcePos7;
}

- (CGPoint)sourcePos8
{
    return sourcePos8;
}

/*- (void)setSourcePos:(CGPoint)SOURCEPOS
{
	float sourcePosAL1[] = {sourcePos1.x, kDefaultDistance, sourcePos1.y};
    float sourcePosAL2[] = {sourcePos2.x, kDefaultDistance, sourcePos2.y};
	// Move our audio source coordinates
	alSourcefv(source[0], AL_POSITION, sourcePosAL1);
    alSourcefv(source[1], AL_POSITION, sourcePosAL2);
}*/



- (CGPoint)listenerPos
{
	return listenerPos;
}

- (void)setListenerPos:(CGPoint)LISTENERPOS
{
	listenerPos = LISTENERPOS;
	float listenerPosAL[] = {listenerPos.x, 0., listenerPos.y};
	// Move our listener coordinates
	alListenerfv(AL_POSITION, listenerPosAL);
}



- (CGFloat)listenerRotation
{
	return listenerRotation;
}

- (void)setListenerRotation:(CGFloat)radians
{
	listenerRotation = radians;
	float ori[] = {cos(radians + M_PI_2), sin(radians + M_PI_2), 0., 0., 0., 1.};
	// Set our listener orientation (rotation)
	alListenerfv(AL_ORIENTATION, ori);
}

@end
