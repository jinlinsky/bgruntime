
// import
#import <Foundation/NSTimer.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBUIController.h>
// include
#include "Config.h"
#include "Socket.h"
#include "File.h"


@interface SBUIController (iOS40)
- (void)activateApplicationFromSwitcher:(SBApplication *)application;
@end

class FileBuffer
{
public:
	static int getAppIdleTime ( void )
	{
		int idleTime = 0;
		
		File file;
		if (file.Open("/config/buffer", File::OM_READ))
		{
			std::string value;
			file.ReadLine(value);
			
			idleTime = atoi(value.c_str());
			
			file.Close();
		}
		
		return idleTime;
	}
	
	static void setAppIdleTime ( int _idleTime )
	{
		File file;
		// set App Idel Time = _idleTime and save it to file buffer
		if (file.Open("/config/buffer", File::OM_WRITE))
		{
			char buffer[32];
			sprintf(buffer, "%d", _idleTime);
			
			file.WriteLine(buffer);
			
			file.Close();
		}
	}
};

//-----------------------------------------------------------------------------
// %hook SBApplication
//-----------------------------------------------------------------------------
%hook SBApplication
int              gTotalIdelTime    = 120;
SBApplication*   gTopApplication          = nil;
bool             gIsOpenedFile            = false;
	
- (void)activate{
	%orig;
	
	// get activate app id
	NSString* activateAppID = self.bundleIdentifier;

	//----------------------------------------------------------
	// read config file
	//----------------------------------------------------------
	static std::string ip;
	static std::string port;
	static std::string idleTime;
	
	gIsOpenedFile = false;

	Config config;
	bool loadConfig = config.LoadConfig("/config/config.txt");

	if (!loadConfig)
	{
		return;
	}else
	{
		gIsOpenedFile = true;
	}
	
	ip   = config.GetText("ip");
	port = config.GetText("port");
	idleTime = config.GetText("idletime");
	
	// init total idle time
	gTotalIdelTime = atoi(idleTime.c_str());
	
	//----------------------------------------------------------
	// initialize socket connection
	//----------------------------------------------------------
	int connectState = Socket::gSharedSocket.GetConnectState();
	if (gIsOpenedFile && connectState != Socket::CS_CONNECTED)
	{
		if (connectState == Socket::CS_CONNECTING)
		{
			Socket::gSharedSocket.Disconnect();
		}
		
		Socket::gSharedSocket.Connect(ip.c_str(), atoi(port.c_str()), true);
	}
	
	//----------------------------------------------------------
	// notice socket server the active app name
	//----------------------------------------------------------
	if (connectState == Socket::CS_CONNECTED)
	{			
		// send debug information
		NSString* sendData = [[NSString alloc] initWithFormat: @"ACTIVATE_APP=%s", [activateAppID UTF8String]];
		Socket::gSharedSocket.Send([sendData UTF8String], [sendData length]);
		
		[sendData release];
	}
	
	//----------------------------------------------------------
	// startup update timer
	//----------------------------------------------------------
	static bool isTimerStartuped = false;
	if (!isTimerStartuped)
	{
		isTimerStartuped = true;
		
		[NSTimer scheduledTimerWithTimeInterval:1 
								   target:self 
								 selector:@selector(TimerUpdate:) 
								 userInfo:nil 
								  repeats:YES];	
	}

	//----------------------------------------------------------
	// reset app idel time & setup the top app
	//----------------------------------------------------------	
	if ([self.bundleIdentifier isEqualToString: @"com.apple.mobilephone"] || [self.bundleIdentifier isEqualToString: @"com.apple.mobilemail"])
	{
		// ignore mobilephone & mobilemail app
		return ;
	}
	
	// init App Idle Time
	FileBuffer::setAppIdleTime(0);
	
	// set top application
	gTopApplication = self;
	
	/*
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"feilaifeiqu information"
	message:activateAppID
	delegate:nil
	cancelButtonTitle:@"OK"
	otherButtonTitles:nil];
	[alert show];
	[alert release];
	*/
	
}

- (void)deactivate{
	%orig;
	
	// get deactivate app id
	NSString* deactivateAppID = self.bundleIdentifier;
	
	int connectState = Socket::gSharedSocket.GetConnectState();
	if (connectState == Socket::CS_CONNECTED)
	{	
		// send debug information
		NSString* sendData = [[NSString alloc] initWithFormat: @"DEACTIVATE_APP=%s", [deactivateAppID UTF8String]];
		Socket::gSharedSocket.Send([sendData UTF8String], [sendData length]);
		
		[sendData release];
	}
	
	if (gTopApplication != nil)
	{
		gTopApplication = nil;
	}
}

%new
- (void) TimerUpdate:(NSTimer *) timer {

	bool isLaunchApp = false;
	
	int connectState = Socket::gSharedSocket.GetConnectState();
	if (connectState == Socket::CS_CONNECTED)
	{
		// receive message from socket server
		char data[512] = "";
		Socket::gSharedSocket.Recv(data, 512);

		// launch app by socket server message
		if(strcmp(data, "OPENAPP") == 0)
		{				
			isLaunchApp = true;
		}
	}
	
	if (gTopApplication != nil && ![gTopApplication.bundleIdentifier isEqualToString: @"com.jinlin.qiyeanli"])
	{	
		int idleTime = FileBuffer::getAppIdleTime();
		++idleTime;
		
		// receive message from socket server
		char data[512] = "";
		Socket::gSharedSocket.Recv(data, 512);

		// launch app if idle timer > gTotalIdelTime
		if(idleTime >= gTotalIdelTime)
		{				
			idleTime = 0;
			isLaunchApp = true;
		}
		
		FileBuffer::setAppIdleTime(idleTime);
		
		if (connectState == Socket::CS_CONNECTED)
		{
			// get top App ID
			NSString* topAppID = gTopApplication.bundleIdentifier;
			
			// send debug information
			NSString* sendData = [[NSString alloc] initWithFormat: @"BGRUNTIME_UPDATE  APP_NAME=%s  IDLE_TIME=%d/%d", [topAppID UTF8String], idleTime, gTotalIdelTime];
			Socket::gSharedSocket.Send([sendData UTF8String], [sendData length]);
			
			[sendData release];
		}
	}
		
	// open App
	if (isLaunchApp)
	{
		[NSTimer scheduledTimerWithTimeInterval:1 
			   target:self 
			 selector:@selector(AppLaunchTrigger) 
			 userInfo:nil 
			  repeats:NO];	
	}
}

%new
- (void) AppLaunchTrigger{
	SBApplication *application = [[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:@"com.jinlin.qiyeanli"];
	[[%c(SBUIController) sharedInstance] activateApplicationFromSwitcher:application];
	
	const char* sendData = "Trigger";
	int dataLength = strlen(sendData);

	Socket::gSharedSocket.Send(sendData, dataLength);
}
%end

/*
//-----------------------------------------------------------------------------
// %hook UIResponder
//-----------------------------------------------------------------------------
%hook UIResponder

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{%orig; FileBuffer::setAppIdleTime(0);}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{%orig; FileBuffer::setAppIdleTime(0);}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{%orig; FileBuffer::setAppIdleTime(0);}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event{%orig; FileBuffer::setAppIdleTime(0);}

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event{%orig; FileBuffer::setAppIdleTime(0);}
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event{%orig; FileBuffer::setAppIdleTime(0);}
- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event{%orig; FileBuffer::setAppIdleTime(0);}

%end

//-----------------------------------------------------------------------------
// %hook UIStatusBar
//-----------------------------------------------------------------------------
%hook UIStatusBar

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{%orig; FileBuffer::setAppIdleTime(0);}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{%orig; FileBuffer::setAppIdleTime(0);}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{%orig; FileBuffer::setAppIdleTime(0);}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event{%orig; FileBuffer::setAppIdleTime(0);}

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event{%orig; FileBuffer::setAppIdleTime(0);}
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event{%orig; FileBuffer::setAppIdleTime(0);}
- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event{%orig; FileBuffer::setAppIdleTime(0);}

%end
*/

//-----------------------------------------------------------------------------
// %hook UITouch
//-----------------------------------------------------------------------------
%hook UITouch
- (CGPoint)locationInView:(UIView *)view
{
	FileBuffer::setAppIdleTime(0);
	
	return %orig;
}
%end



