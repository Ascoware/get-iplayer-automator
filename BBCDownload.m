//
//  Download.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/14/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "BBCDownload.h"

@implementation BBCDownload
#pragma mark Overridden Methods
- (id)initWithProgramme:(Programme *)tempShow tvFormats:(NSArray *)tvFormatList radioFormats:(NSArray *)radioFormatList
{
	[super init];
	runAgain = NO;
	running=YES;
	foundLastLine=NO;
	errorCache = [[NSMutableString alloc] init];
	processErrorCache = [NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(processError) userInfo:nil repeats:YES];
    reasonForFailure = [[NSString alloc] initWithString:@"None"];
    
	log = [[NSMutableString alloc] initWithString:@""];
	nc = [NSNotificationCenter defaultCenter];
	show = tempShow;
	[self addToLog:[NSString stringWithFormat:@"Downloading %@", [show showName]]];
	i=0;
	//Prepare Arguments
		//Initialize Paths
	NSString *bundlePath = [[NSString alloc] initWithString:[[NSBundle mainBundle] bundlePath]];
    NSString *resourcesPath = [bundlePath stringByAppendingString:@"/Contents/Resources/"];
	NSString *getiPlayerPath = [bundlePath stringByAppendingString:@"/Contents/Resources/get_iplayer.pl"];
	NSString *mplayerPath = [bundlePath stringByAppendingString:@"/Contents/Resources/mplayer"];
	NSString *atomicParsleyPath = [bundlePath stringByAppendingString:@"/Contents/Resources/AtomicParsley"];
	NSString *lamePath = [bundlePath stringByAppendingString:@"/Contents/Resources/lame"];
	NSString *ffmpegPath = [bundlePath stringByAppendingString:@"/Contents/Resources/ffmpeg"];
	downloadPath = [[NSString alloc] initWithString:[[NSUserDefaults standardUserDefaults] valueForKey:@"DownloadPath"]];
		//Initialize Formats
	NSArray *tvFormatKeys = [NSArray arrayWithObjects:@"iPhone",@"Flash - High",@"Flash - Low",@"Flash - HD",@"Flash - Standard",@"Flash - Normal",@"Flash - Very High",nil];
	NSArray *tvFormatObjects = [NSArray arrayWithObjects:@"iphone",@"flashhigh2,flashhigh1",@"flashlow2,flashlow1",@"flashhd2,flashhd1",@"flashstd2,flashstd,1",@"flashstd2,flashstd1",@"flashvhigh2,flashvhigh1",nil];
	NSDictionary *tvFormats = [[NSDictionary alloc] initWithObjects:tvFormatObjects forKeys:tvFormatKeys];
	NSArray *radioFormatKeys = [NSArray arrayWithObjects:@"iPhone",@"Flash - MP3",@"Flash - AAC",@"WMA",@"Real Audio",@"Flash",@"Flash AAC - High",@"Flash AAC - Standard",@"Flash AAC - Low",nil];
	NSArray *radioFormatObjects = [NSArray arrayWithObjects:@"iphone", @"flashaudio",@"flashaac",@"wma",@"realaudio",@"flashaudio",@"flashaachigh",@"flashaacstd",@"flashaaclow",nil];
	NSDictionary *radioFormats = [[NSDictionary alloc] initWithObjects:radioFormatObjects forKeys:radioFormatKeys];
	NSString *formatArg;
    NSMutableString *temp_Format;
    temp_Format = [[NSMutableString alloc] initWithString:@"--modes="];
    for (RadioFormat *format in radioFormatList)
        [temp_Format appendFormat:@"%@,", [radioFormats valueForKey:[format format]]];
    for (TVFormat *format in tvFormatList)
        [temp_Format appendFormat:@"%@,",[tvFormats valueForKey:[format format]]];
    formatArg = [NSString stringWithString:temp_Format];

		//Set Proxy Argument
	NSString *proxyArg;
	NSString *partialProxyArg;
	NSString *proxyOption = [[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"];
	if ([proxyOption isEqualToString:@"None"])
	{
		//No Proxy
		proxyArg = NULL;
	}
	else if ([proxyOption isEqualToString:@"Custom"]/* && (![[show radio] isEqualToNumber:[NSNumber numberWithBool:YES]] || [[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue])*/)
	{
		if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CustomProxy"] hasPrefix:@"http"])
			proxyArg = [[NSString alloc] initWithFormat:@"-p%@",[[NSUserDefaults standardUserDefaults] valueForKey:@"CustomProxy"]];
		else
			proxyArg = [[NSString alloc] initWithFormat:@"-phttp://%@",[[NSUserDefaults standardUserDefaults] valueForKey:@"CustomProxy"]];
	}
	else
	{
		//Get provided proxy from my server.
		NSURL *proxyURL = [[NSURL alloc] initWithString:@"http://tom-tech.com/get_iplayer/proxy.txt"];
		NSURLRequest *proxyRequest = [NSURLRequest requestWithURL:proxyURL
													  cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
												  timeoutInterval:30];
		NSData *urlData;
		NSURLResponse *response;
		NSError *error;
		urlData = [NSURLConnection sendSynchronousRequest:proxyRequest
										returningResponse:&response
													error:&error];
		if (!urlData)
		{
			NSAlert *alert = [NSAlert alertWithMessageText:@"Provided Proxy could not be retrieved!" 
											 defaultButton:nil 
										   alternateButton:nil 
											   otherButton:nil 
								 informativeTextWithFormat:@"No proxy will be used.\r\rError: %@", [error localizedDescription]];
			[alert runModal];
			[self addToLog:@"WARNING: Proxy could not be retrieved. No proxy will be used."];
			proxyArg=NULL;
		}
		else
		{
			if (/*![[show radio] isEqualToNumber:[NSNumber numberWithBool:YES]] || [[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue]*/TRUE)
			{	
				NSString *providedProxy = [[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding];
				proxyArg = [[NSString alloc] initWithFormat:@"-phttp://%@", providedProxy];
			}
			else proxyArg=NULL;
		}
	}
		//Partial Proxy?
	if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue])
	{
		partialProxyArg = [[NSString alloc] initWithString:@"--partial-proxy"];
	}
	else
	{
		partialProxyArg = NULL;
	}
		//Initialize the rest of the arguments
	NSString *noWarningArg = [[NSString alloc] initWithString:@"--nocopyright"];
	NSString *noExpiryArg = [[NSString alloc] initWithString:@"--nopurge"];
	NSString *mplayerArg = [[NSString alloc] initWithFormat:@"--mplayer=%@", mplayerPath];
    NSString *flvstreamerArg;
   
#ifdef __x86_64__
    NSString *rtmpdumpPath = [bundlePath stringByAppendingString:@"/Contents/Resources/rtmpdump-2.4"];
    flvstreamerArg = [[NSString alloc] initWithFormat:@"--flvstreamer=%@", rtmpdumpPath];
#else
    NSString *flvstreamerPath = [bundlePath stringByAppendingString:@"/Contents/Resources/flvstreamer"];
    flvstreamerArg = [[NSString alloc] initWithFormat:@"--flvstreamer=%@", flvstreamerPath];
#endif

	NSString *lameArg = [[NSString alloc] initWithFormat:@"--lame=%@", lamePath];
	NSString *atomicParsleyArg = [[NSString alloc] initWithFormat:@"--atomicparsley=%@", atomicParsleyPath];
	NSString *ffmpegArg;
	if (ffmpegPath) ffmpegArg = [[NSString alloc] initWithFormat:@"--ffmpeg=%@", ffmpegPath];
	else ffmpegArg = nil;
	NSString *downloadPathArg = [[NSString alloc] initWithFormat:@"--output=%@", downloadPath];
	NSString *subDirArg = [[NSString alloc] initWithString:@"--subdir"];
	NSString *getArg;
	if ([[show processedPID] boolValue])
		getArg = [[NSString alloc] initWithString:@"--get"];
	else
		getArg = [[NSString alloc] initWithString:@"--pid"];		
	NSString *searchArg = [[NSString alloc] initWithFormat:@"%@", [show pid]];
	NSString *versionArg = [[NSString alloc] initWithString:@"--versions=default"];
	//We don't want this to refresh now!
	NSString *cacheExpiryArg = @"-e604800000000";
	NSString *folder = @"~/Library/Application Support/Get iPlayer Automator/";
		//Profile Override Argument
	folder = [folder stringByExpandingTildeInPath];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath: folder] == NO)
	{
		[fileManager createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:nil];
	}
	profileDirArg = [[NSString alloc] initWithFormat:@"--profile-dir=%@", folder];
	
		//Add Arguments that can't be NULL
	NSMutableArray *args = [[NSMutableArray alloc] initWithObjects:getiPlayerPath,profileDirArg,noWarningArg,noExpiryArg,mplayerArg,flvstreamerArg,lameArg,atomicParsleyArg,cacheExpiryArg,downloadPathArg,
					 subDirArg,formatArg,getArg,searchArg,@"--attempts=5",@"--nopurge",@"--fatfilename",@"-w",versionArg,proxyArg,partialProxyArg,nil];
		//Verbose?
	if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"Verbose"] isEqualTo:[NSNumber numberWithBool:YES]])
		[args addObject:[[NSString alloc] initWithString:@"--verbose"]];
	if (ffmpegArg) [args addObject:ffmpegArg];
	if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"DownloadSubtitles"] isEqualTo:[NSNumber numberWithBool:YES]])
		[args addObject:@"--subtitles"];
	
		//Naming Convention
	if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"XBMC_naming"] boolValue])
	{
		[args addObject:@"--file-prefix=<name> - <episode> ((<modeshort>))"];
	}
	else 
	{
		[args addObject:@"--file-prefix=<nameshort>.<senum>.<episode>"];
		[args addObject:@"--subdir-format=<nameshort>"];
	}
	
	//if (floor(NSAppKitVersionNumber) > 949)
		//[args addObject:@"--rtmp-tv-opts=-W http://www.bbc.co.uk/emp/10player.swf?revision=18269_21576"];

	task = [[NSTask alloc] init];
	pipe = [[NSPipe alloc] init];
	errorPipe = [[NSPipe alloc] init];
	
	[task setArguments:args];
	[task setLaunchPath:@"/usr/bin/perl"];
	[task setStandardOutput:pipe];
	[task setStandardError:errorPipe];
    NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:[task environment]];
    [envVariableDictionary setObject:resourcesPath forKey:@"DYLD_LIBRARY_PATH"];
    [envVariableDictionary setObject:[@"~" stringByExpandingTildeInPath] forKey:@"HOME"];
    NSLog(@"%@",envVariableDictionary);
    [task setEnvironment:envVariableDictionary];
	
	fh = [pipe fileHandleForReading];
	errorFh = [errorPipe fileHandleForReading];
	
	[nc addObserver:self
		   selector:@selector(DownloadDataReady:)
			   name:NSFileHandleReadCompletionNotification
			 object:fh];
	[nc addObserver:self
		   selector:@selector(ErrorDataReady:)
			   name:NSFileHandleReadCompletionNotification
			 object:errorFh];
	[task launch];
	[fh readInBackgroundAndNotify];
	[errorFh readInBackgroundAndNotify];
	[show setValue:@"Starting..." forKey:@"status"];
	
	//Prepare UI
	[self setCurrentProgress:@"Beginning..."];
	return self;
}
- (id)description
{
	return [NSString stringWithFormat:@"Download (ID=%@)", [show pid]];
}
#pragma mark Task Control
- (void)DownloadDataReady:(NSNotification *)note
{
	[[pipe fileHandleForReading] readInBackgroundAndNotify];
	NSData *d;
    d = [[note userInfo] valueForKey:NSFileHandleNotificationDataItem];
	
    if ([d length] > 0) {
		NSString *s = [[NSString alloc] initWithData:d
											encoding:NSUTF8StringEncoding];
		[self processGetiPlayerOutput:s];
	}
	else
	{
		i++;
		if (i>20 && running)
		{
			running=NO;
			//Download Finished Handler
			task = nil;
			pipe = nil;
			if (runDownloads)
			{
				NSString *lastLine;
				if (!foundLastLine)
				{
					NSUInteger length = [log length];
					NSUInteger paraStart = 0, paraEnd = 0, contentsEnd = 0;
					NSMutableArray *array = [NSMutableArray array];
					NSRange currentRange;
					while (paraEnd < length) {
						[log getParagraphStart:&paraStart end:&paraEnd
									  contentsEnd:&contentsEnd forRange:NSMakeRange(paraEnd, 0)];
						currentRange = NSMakeRange(paraStart, contentsEnd - paraStart);
						[array addObject:[log substringWithRange:currentRange]];
					}
					lastLine = [array objectAtIndex:([array count]-1)];
				}
				else 
				{
					lastLine = LastLine;
				}

				NSScanner *scn = [NSScanner scannerWithString:lastLine];
				if ([reasonForFailure isEqualToString:@"unresumable"])
				{
					[show setValue:[NSNumber numberWithBool:YES] forKey:@"complete"];
					[show setValue:[NSNumber numberWithBool:NO] forKey:@"successful"];
					[show setValue:@"Failed: Unresumable File" forKey:@"status"];
                    [show setReasonForFailure:@"Unresumable_File"];
				}
				else if ([reasonForFailure isEqualToString:@"proxy"])
				{
					[show setValue:[NSNumber numberWithBool:YES] forKey:@"complete"];
					[show setValue:[NSNumber numberWithBool:NO] forKey:@"successful"];
					NSString *proxyOption = [[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"];
					if ([proxyOption isEqualToString:@"None"])
					{
						[show setValue:@"Failed: See Log" forKey:@"status"];
						[self addToLog:@"REASON FOR FAILURE: Proxy failed. If in the UK, please submit a bug report." noTag:TRUE];
						[self addToLog:@"If outside the UK, please enable the provided proxy." noTag:TRUE];
                        [show setReasonForFailure:@"ShowNotFound"];
					}
					else if ([proxyOption isEqualToString:@"Provided"])
					{
						[show setValue:@"Failed: Bad Proxy" forKey:@"status"];
						[self addToLog:@"REASON FOR FAILURE: Proxy failed. If in the UK, please disable the proxy in the preferences." noTag:TRUE];
						[self addToLog:@"If outside the UK, please submit a bug report so that the proxy can be updated." noTag:TRUE];
                        [show setReasonForFailure:@"Provided_Proxy"];
					}
					else if ([proxyOption isEqualToString:@"Custom"])
					{
						[show setValue:@"Failed: Bad Proxy" forKey:@"status"];
						[self addToLog:@"REASON FOR FAILURE: Proxy failed. If in the UK, please disable the proxy in the preferences." noTag:TRUE];
						[self addToLog:@"If outside the UK, please use a different proxy." noTag:TRUE];
                        [show setReasonForFailure:@"Custom_Proxy"];
					}
					[self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
				}
                else if ([reasonForFailure isEqualToString:@"modes"])
                {
                    [show setValue:[NSNumber numberWithBool:YES] forKey:@"complete"];
					[show setValue:[NSNumber numberWithBool:NO] forKey:@"successful"];
                    [show setValue:@"Failed: No Specified Modes" forKey:@"status"];
                    [self addToLog:@"REASON FOR FAILURE: None of the modes in your download format list are available for this show." noTag:YES];
                    [self addToLog:@"Try adding more modes." noTag:YES];
                    [self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
                    [show setReasonForFailure:@"Specified_Modes"];
                    NSLog(@"Set Modes");
                }
                else if ([[show reasonForFailure] isEqualToString:@"InHistory"])
                {
                    NSLog(@"InHistory");
                }
				else if ([lastLine hasPrefix:@"INFO: Recorded"])
				{
					[show setValue:[NSNumber numberWithBool:YES] forKey:@"complete"];
					[show setValue:[NSNumber numberWithBool:YES] forKey:@"successful"];
					[show setValue:@"Download Complete" forKey:@"status"];
					NSScanner *scanner = [NSScanner scannerWithString:lastLine];
					NSString *path;
					[scanner scanString:@"INFO: Recorded" intoString:nil];
					if (![scanner scanFloat:nil])
					{
						[scanner scanUpToString:@"kjkjkjkjk" intoString:&path];
					}
					else
					{
						[scanner scanUpToString:@"to" intoString:nil];
						[scanner scanString:@"to " intoString:nil];
						[scanner scanUpToString:@"kjkfjkj" intoString:&path];
					}
					[show setPath:path];
					[self addToLog:[NSString stringWithFormat:@"%@ Completed Successfully",[show showName]]];
				}
				else if ([lastLine hasPrefix:@"INFO: All streaming threads completed"])
				{
					[show setValue:[NSNumber numberWithBool:YES] forKey:@"complete"];
					[show setValue:[NSNumber numberWithBool:YES] forKey:@"successful"];
					[show setValue:@"Download Complete" forKey:@"status"];
					[show setPath:@"Unknown"];
				}
				else if ([scn scanUpToString:@"Already in history" intoString:nil] && 
						 [scn scanString:@"Already in" intoString:nil])
				{
					[show setValue:[NSNumber numberWithBool:YES] forKey:@"complete"];
					[show setValue:[NSNumber numberWithBool:NO] forKey:@"successful"];
					[show setValue:@"Failed: Download in History" forKey:@"status"];
					[self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
                    [show setReasonForFailure:@"InHistory"];
				}
				else
				{
					[show setValue:[NSNumber numberWithBool:YES] forKey:@"complete"];
					[show setValue:[NSNumber numberWithBool:NO] forKey:@"successful"];
					[show setValue:@"Download Failed" forKey:@"status"];
					[self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
				}
			}
			[nc postNotificationName:@"DownloadFinished" object:show];
		}
	}
}
- (void)ErrorDataReady:(NSNotification *)note
{
	[[errorPipe fileHandleForReading] readInBackgroundAndNotify];
	NSData *d;
    d = [[note userInfo] valueForKey:NSFileHandleNotificationDataItem];
    if ([d length] > 0)
	{
		[errorCache appendString:[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]];
	}
	else
	{
		i++;
		if (i>20)
		{
			//Close the error pipe when it is empty.
			errorPipe = nil;
		}
	}
}
- (void)processError
{
	if (running)
	{
		NSString *outp = [errorCache copy];
		errorCache = [NSMutableString stringWithString:@""];
		if ([outp length] > 0) {
			BOOL status=YES;
			NSString *outpt = [[NSString alloc] initWithString:outp];
			NSString *string = [NSString stringWithString:outpt];
			NSUInteger length = [string length];
			NSUInteger paraStart = 0, paraEnd = 0, contentsEnd = 0;
			NSMutableArray *array = [NSMutableArray array];
			NSRange currentRange;
			while (paraEnd < length) {
				[string getParagraphStart:&paraStart end:&paraEnd
							  contentsEnd:&contentsEnd forRange:NSMakeRange(paraEnd, 0)];
				currentRange = NSMakeRange(paraStart, contentsEnd - paraStart);
				[array addObject:[string substringWithRange:currentRange]];
			}
			for (NSString *s in array)
			{
				NSString *s2;
				NSScanner *scanner = [NSScanner scannerWithString:s];
				//Check if BBC Flash status Message
				if (![scanner scanFloat:nil])
				{
					if ([s length] != 0)
					{
						//If not...
						if ([s hasPrefix:@"frame="]) s2= @"Converting...";
						else if ([s hasPrefix:@" Progress"]) s2= @"Processing Download...";
						else 
						{
							s2 = [NSString stringWithFormat:@"Initialising... -- %@", [show valueForKey:@"showName"]];
							[self addToLog:s noTag:YES];
						}
						status=NO;
						[scanner setScanLocation:0];
						if ([s hasPrefix:@"ERROR:"] || [s hasPrefix:@"\rERROR:"] || [s hasPrefix:@"\nERROR:"])
						{
							if ([scanner scanUpToString:@"corrupt file!" intoString:nil] && [scanner scanString:@"corrupt file!" intoString:nil])
							{
								[self addToLog:@"Unresumable file, please delete the partial file and try again." noTag:NO];
								[task interrupt];
								reasonForFailure=@"unresumable";
                                [show setReasonForFailure:@"Unresumable_File"];
							}
						}
                        [scanner setScanLocation:0];
                        [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
					}
					else
					{
						status=NO;
						s2=nil;
						[scanner setScanLocation:0];
                        [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
					}
				}
				else
                    [self processFLVStreamerMessage:[scanner string]];

				//If an MPlayer (Real Audio) status message...
				if ([s hasPrefix:@"A:"])
				{
                    double downloaded, percent, total;
					NSString *downloadedString, *totalString;
					[scanner setScanLocation:0];
					[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
					if (![scanner scanDouble:&downloaded]) downloaded=0.0;
					[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
					[scanner scanUpToString:@")" intoString:&downloadedString];
					[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
					if (![scanner scanDouble:&total]) total=0.0;
					[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
					[scanner scanUpToString:@")" intoString:&totalString];
					if (total>0) percent = (downloaded/total)*100; 
					else percent = 0.0;
					if ([downloadedString length] < 7) downloadedString = [@"00:" stringByAppendingString:downloadedString];
					[self setCurrentProgress:[NSString stringWithFormat:@"%.1f%% - (%@/%@) -- %@",percent,downloadedString,totalString,[show valueForKey:@"showName"]]];
					[self setPercentage:percent];
					[show setValue:[NSString stringWithFormat:@"Downloading: %.1f%%", percent] forKey:@"status"];
				}
				else
				{	
					//Otherwise, use the indeterminate display.
					if ([s2 isEqualToString:@"Converting..."])
					{
						[self setCurrentProgress:[NSString stringWithFormat:@"Converting... -- %@",[show valueForKey:@"showName"]]];
						[self setPercentage:102];
						[show setValue:@"Converting..." forKey:@"status"];
					}
					else if ([s2 isEqualToString:@"Processing Download..."])
					{
						[self setCurrentProgress:[NSString stringWithFormat:@"Processing Download... -- %@", [show valueForKey:@"showName"]]];
						[self setPercentage:102];
						[show setValue:@"Processing Download..." forKey:@"status"];
					}
					else if (s2 != nil) 
					{
						[self setCurrentProgress:s2];
						[self setPercentage:102];
						[show setValue:@"Downloading..." forKey:@"status"];
					}
				}
			}
			
		}
	}
}	
- (void)cancelDownload:(id)sender
{
	//Some basic cleanup.
	[task interrupt];
	[nc removeObserver:self name:NSFileHandleReadCompletionNotification object:fh];
	[nc removeObserver:self name:NSFileHandleReadCompletionNotification object:errorFh];
	[show setValue:@"Cancelled" forKey:@"status"];
	[self addToLog:@"Download Cancelled"];
    [processErrorCache invalidate];
}
- (void)processGetiPlayerOutput:(NSString *)outp
{
	//Separate the output by line.
	NSString *outpt = [[NSString alloc] initWithString:outp];
	NSString *string = [NSString stringWithString:outpt];
	NSUInteger length = [string length];
	NSUInteger paraStart = 0, paraEnd = 0, contentsEnd = 0;
	NSMutableArray *array = [NSMutableArray array];
	NSRange currentRange;
	while (paraEnd < length) {
		[string getParagraphStart:&paraStart end:&paraEnd
					  contentsEnd:&contentsEnd forRange:NSMakeRange(paraEnd, 0)];
		currentRange = NSMakeRange(paraStart, contentsEnd - paraStart);
		[array addObject:[string substringWithRange:currentRange]];
	}
	//Parse each line individually.
	for (NSString *output in array)
	{
		if ([output hasPrefix:@"INFO: Downloading Subtitles"])
		{
			NSScanner *scanner = [NSScanner scannerWithString:output];
			NSString *subtitlePath;
			[scanner scanString:@"INFO: Downloading Subtitles to \'" intoString:nil];
			[scanner scanUpToString:@".srt\'" intoString:&subtitlePath];
			subtitlePath = [subtitlePath stringByAppendingPathExtension:@"srt"];
			[show setSubtitlePath:subtitlePath];
		}
		if ([output hasPrefix:@"INFO: Recorded"])
		{
			LastLine = [NSString stringWithString:output];
			foundLastLine=YES;
		}
		if ([output hasPrefix:@"INFO: No specified modes"] && [output hasSuffix:@"--modes=)"])
		{
			reasonForFailure=@"proxy";
			[self addToLog:output noTag:YES];
		}
        else if ([output hasPrefix:@"INFO: No specified modes"])
        {
            reasonForFailure=@"modes";
            [show setReasonForFailure:@"Specified_Modes"];
            [self addToLog:output noTag:YES];
            NSScanner *modeScanner = [NSScanner scannerWithString:output];
            [modeScanner scanUpToString:@"--modes=" intoString:nil];
            [modeScanner scanString:@"--modes=" intoString:nil];
            NSString *availableModes;
            [modeScanner scanUpToString:@")" intoString:&availableModes];
            [show setAvailableModes:availableModes];
        }
        else if ([output hasSuffix:@"use --force to override"])
        {
            [show setValue:[NSNumber numberWithBool:YES] forKey:@"complete"];
            [show setValue:[NSNumber numberWithBool:NO] forKey:@"successful"];
            [show setValue:@"Failed: Download in History" forKey:@"status"];
            [self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
            [show setReasonForFailure:@"InHistory"];
            foundLastLine=YES;
        }
        else if ([output hasPrefix:@"ERROR: Failed to get version pid"])
        {
            [show setReasonForFailure:@"ShowNotFound"];
            [self addToLog:output noTag:YES];
        }
		else if ([output hasPrefix:@"INFO:"] || [output hasPrefix:@"WARNING:"] || [output hasPrefix:@"ERROR:"] || 
			[output hasSuffix:@"default"] || [output hasPrefix:[show pid]])
		{
			//Add Status Message to Log
			[self addToLog:output noTag:YES];
		}
		else if ([output hasPrefix:@" Progress"])
		{
			[self setPercentage:102];
			[self setCurrentProgress:[NSString stringWithFormat:@"Processing Download... - %@", [show valueForKey:@"showName"]]];
			[self setValue:@"Processing Download..." forKey:@"status"];
		}
		else if ([output hasPrefix:@"Threads:"])
		{
			//If it is an MPlayer (ITV) status message:
			NSScanner *scanner = [NSScanner scannerWithString:output];
			
			NSString *threadRecieved;
			[scanner scanUpToString:@"recorded" intoString:&threadRecieved];
			
			NSScanner *threadRecievedScanner = [NSScanner scannerWithString:threadRecieved];
			double downloaded=0;
			while ([threadRecievedScanner scanUpToString:@")" intoString:nil]) 
			{
				[threadRecievedScanner scanString:@") " intoString:nil];
				double thread;
				[threadRecievedScanner scanDouble:&thread];
				downloaded = downloaded + thread;
			}
			NSInteger speed;
			[scanner scanUpToString:@"(" intoString:nil];
			[scanner scanString:@"(" intoString:nil];
			[scanner scanInteger:&speed];
			
			[self setCurrentProgress:[NSString stringWithFormat:@"Unknown%% (%3.2fMB/Unknown) - %5.1fKB/s -- %@",
									  downloaded,
									  [[NSDecimalNumber numberWithInteger:speed] doubleValue]/8,
									  [show showName]]];
			[show setValue:@"Downloading..." forKey:@"status"];
			[self setPercentage:102];

		}
		else if ([output hasPrefix:@" Progress"])
		{
			[show setValue:@"Downloading Artwork..." forKey:@"status"];
			[self setPercentage:102];
			[self setCurrentProgress:[NSString stringWithFormat:@"Downloading Artwork... -- %@", [show showName]]];
		}
		else
		{
			//Process iPhone/Podcast/Radio Downloads Status Message
			NSScanner *scanner = [NSScanner scannerWithString:output];
			NSDecimal recieved, total, percentage;
			NSInteger speed=0;
			NSString *timeRemaining;
			if(![scanner scanDecimal:&recieved]) recieved = [[NSNumber numberWithInt:0]decimalValue];
			[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] 
									intoString:nil];
			if(![scanner scanDecimal:&total]) total = [[NSNumber numberWithInt:0]decimalValue];
			[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] 
									intoString:nil];
			if(![scanner scanInteger:&speed]) speed = [[NSNumber numberWithInt:0]integerValue];
			[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] 
									intoString:nil];
			if(![scanner scanDecimal:&percentage]) percentage = [[NSNumber numberWithInt:0]decimalValue];
			[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] 
									intoString:nil];
			if(![scanner scanUpToString:@"rem" intoString:&timeRemaining]) timeRemaining=@"Unknown";
			double adjustedSpeed = [[NSNumber numberWithInteger:speed] doubleValue]/8;
			[self setPercentage:[[NSDecimalNumber decimalNumberWithDecimal:percentage] doubleValue]];
			if ([[NSDecimalNumber decimalNumberWithDecimal:total] doubleValue] < 5.00 && [[NSDecimalNumber decimalNumberWithDecimal:recieved] doubleValue] > 0)
			{
				[self setCurrentProgress:[NSString stringWithFormat:@"%3.1f%% (%3.2fMB/%3.2fMB) - %5.1fKB/s -- Getting MOV atom.",
										  [[NSDecimalNumber decimalNumberWithDecimal:percentage] doubleValue],
										  [[NSDecimalNumber decimalNumberWithDecimal:recieved] doubleValue],
										  [[NSDecimalNumber decimalNumberWithDecimal:total] doubleValue],
										  adjustedSpeed,[show showName]]];
				[show setValue:[NSString stringWithFormat:@"Getting MOV atom: %3.1f%%",
								[[NSDecimalNumber decimalNumberWithDecimal:percentage] doubleValue]]
						forKey:@"status"];
			}
			else if ([[NSDecimalNumber decimalNumberWithDecimal:total] doubleValue] == 0)
			{
				[self setCurrentProgress:[NSString stringWithFormat:@"%3.1f%% (%3.2fMB/%3.2fMB) - %5.1fKB/s -- Initializing...",
										  [[NSDecimalNumber decimalNumberWithDecimal:percentage] doubleValue],
										  [[NSDecimalNumber decimalNumberWithDecimal:recieved] doubleValue],
										  [[NSDecimalNumber decimalNumberWithDecimal:total] doubleValue],
										  adjustedSpeed,timeRemaining]];
				[show setValue:[NSString stringWithFormat:@"Initializing: %3.1f%%",
								[[NSDecimalNumber decimalNumberWithDecimal:percentage] doubleValue]]
						forKey:@"status"];		
			}
			else
			{
				[self setCurrentProgress:[NSString stringWithFormat:@"%3.1f%% (%3.2fMB/%3.2fMB) - %.1fKB/s - %@ Remaining -- %@",
				 [[NSDecimalNumber decimalNumberWithDecimal:percentage] doubleValue],
				 [[NSDecimalNumber decimalNumberWithDecimal:recieved] doubleValue],
				 [[NSDecimalNumber decimalNumberWithDecimal:total] doubleValue],
										  adjustedSpeed,timeRemaining,[show showName]]];
				[show setValue:[NSString stringWithFormat:@"Downloading: %3.1f%%",
								[[NSDecimalNumber decimalNumberWithDecimal:percentage] doubleValue]]
						forKey:@"status"];
			}
		}
	}
}

@end
