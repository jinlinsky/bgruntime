#import <Foundation/NSTimer.h>
#import "Socket.h"
#import "File.h"
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBUIController.h>

SBApplication* gTopApplication = nil;

@interface SBUIController (iOS40)
- (void)activateApplicationFromSwitcher:(SBApplication *)application;
@end

%hook SBApplication

bool gIsConnected = false;
bool gIsOpenedFile = false;
int  gIdleTime = 0;

const int OPEN_YUNJIEMI_IDLE_TIME = 10;
	
- (void)activate{
	%orig;
	
	// get activate app id
	NSString* activateAppID = self.bundleIdentifier;

	static std::string ip;
	static std::string port;
	
	if (!gIsOpenedFile)
	{
		File file;
		int result = (int)file.Open("/config/yunjiemi.txt", File::OM_READ);
		if (result == 0)
		{
			return;
		}else
		{
			gIsOpenedFile = true;
		}
		
		file.ReadLine(ip);
		file.ReadLine(port);
		file.Close();
	}
	
	if (gIsOpenedFile && !gIsConnected)
	{
		int result = Socket::gSharedSocket.Connect(ip.c_str(), atoi(port.c_str()));
		
		if (result == -1)
		{
			gIsOpenedFile = false;
			return;
		}else
		{
			gIsConnected = true;
		}
		
		[NSTimer scheduledTimerWithTimeInterval:1 
									   target:self 
									 selector:@selector(TimerUpdate:) 
									 userInfo:nil 
									  repeats:YES];	
	}
	
	if (gIsConnected)
	{			
		// send debug information
		NSString* sendData = [[NSString alloc] initWithFormat: @"[activate APP] %s", [activateAppID UTF8String]];
		Socket::gSharedSocket.Send([sendData UTF8String], [sendData length]);
		
		[sendData release];
	}

	// ignore mobilephone & mobilemail app
	if ([self.bundleIdentifier isEqualToString: @"com.apple.mobilephone"] || [self.bundleIdentifier isEqualToString: @"com.apple.mobilemail"])
	{
		return ;
	}
	
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
	
	if (gIsConnected)
	{	
		// send debug information
		NSString* sendData = [[NSString alloc] initWithFormat: @"[deactivate APP] %s", [deactivateAppID UTF8String]];
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
	if (gIsConnected && gTopApplication != nil)
	{	
		// get top App ID
		NSString* topAppID = gTopApplication.bundleIdentifier;
		
		// send debug information
		NSString* sendData = [[NSString alloc] initWithFormat: @"[bgruntime update] %s", [topAppID UTF8String]];
		Socket::gSharedSocket.Send([sendData UTF8String], [sendData length]);
		
		[sendData release];
		
		// receive message from socket server
		char data[512] = "";
		Socket::gSharedSocket.Recv(data, 512);

		// launch qiyeanli app by socket server message
		if(strcmp(data, "OPENAPP") == 0 || gIdleTime >= OPEN_YUNJIEMI_IDLE_TIME)
		{				
			gIdleTime = 0;
			
			[NSTimer scheduledTimerWithTimeInterval:1 
							   target:self 
							 selector:@selector(AppLaunchTrigger) 
							 userInfo:nil 
							  repeats:NO];	
		}
		
		// update idle time
		gIdleTime += 1;
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

%hook UIResponder

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	%orig;
	
	gIdleTime = 0;

}

%end