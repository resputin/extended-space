

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import <OpenAL/al.h>
#import <OpenAL/alc.h>

#define kDefaultDistance 25.0

@interface oalPlayback : NSObject
{
	IBOutlet	UISwitch*	musicSwitch;

    ALuint					source[8];
    ALuint                  buffer[8];
	ALCcontext*				context;
	ALCdevice*				device;

	void*					data;
	CGPoint					sourcePos1, sourcePos2, sourcePos3, sourcePos4, sourcePos5, sourcePos6, sourcePos7, sourcePos8, sourcePos9;
	CGPoint					listenerPos;
	CGFloat					listenerRotation;
	ALfloat					sourceVolume;
	BOOL					isPlaying;
	BOOL					wasInterrupted;
	
	NSURL*					bgURL;
	AVAudioPlayer*			bgPlayer;
	UInt32					iPodIsPlaying;
	
}

@property (nonatomic, assign)   ALCcontext* context;
@property (nonatomic, assign)	BOOL		isPlaying;			// Whether the sound is playing or stopped
@property (nonatomic, assign)	UInt32		iPodIsPlaying;		// Whether the iPod is playing
@property (nonatomic, assign)	BOOL		wasInterrupted;		// Whether playback was interrupted by the system
@property (nonatomic, assign)	CGPoint		sourcePos;			// The coordinates of the sound source
@property (nonatomic, assign)	CGPoint		listenerPos;		// The coordinates of the listener
@property (nonatomic, assign)	CGFloat		listenerRotation;	// The rotation angle of the listener in radians

- (IBAction)toggleMusic:(UISwitch*)sender;
- (void)checkForMusic;

- (void)initOpenAL;
- (void)teardownOpenAL;

- (void)startSound;
- (void)stopSound;

@end
