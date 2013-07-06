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
- (id)initWithProgramme:(Programme *)tempShow tvFormats:(NSArray *)tvFormatList radioFormats:(NSArray *)radioFormatList proxy:(HTTPProxy *)aProxy
{
	if (!(self = [super init])) return nil;
	runAgain = NO;
	running=YES;
	foundLastLine=NO;
	errorCache = [[NSMutableString alloc] init];
	processErrorCache = [NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(processError) userInfo:nil repeats:YES];
    reasonForFailure = [[NSString alloc] initWithString:@"None"];
    defaultsPrefix = @"BBC_";
    proxy = aProxy;
    
	log = [[NSMutableString alloc] initWithString:@""];
	nc = [NSNotificationCenter defaultCenter];
	show = tempShow;
	[self addToLog:[NSString stringWithFormat:@"Downloading %@", [show showName]]];
	noDataCount=0;
		
    //Initialize Paths
    NSBundle *bundle = [NSBundle mainBundle];
	NSString *getiPlayerPath = [bundle pathForResource:@"get_iplayer" ofType:@"pl"];
	downloadPath = [[NSString alloc] initWithString:[[NSUserDefaults standardUserDefaults] valueForKey:@"DownloadPath"]];
		
    //Initialize Formats
	NSArray *tvFormatKeys = @[@"iPhone",@"Flash - High",@"Flash - Low",@"Flash - HD",@"Flash - Standard",@"Flash - Normal",@"Flash - Very High"];
	NSArray *tvFormatObjects = @[@"iphone",@"flashhigh2,flashhigh1",@"flashlow2,flashlow1",@"flashhd2,flashhd1",@"flashstd2,flashstd1",@"flashstd2,flashstd1",@"flashvhigh2,flashvhigh1"];
	NSDictionary *tvFormats = [[NSDictionary alloc] initWithObjects:tvFormatObjects forKeys:tvFormatKeys];
	NSArray *radioFormatKeys = @[@"iPhone",@"Flash - MP3",@"Flash - AAC",@"WMA",@"Real Audio",@"Flash",@"Flash AAC - High",@"Flash AAC - Standard",@"Flash AAC - Low"];
	NSArray *radioFormatObjects = @[@"iphone", @"flashaudio",@"flashaac",@"wma",@"realaudio",@"flashaudio",@"flashaachigh",@"flashaacstd",@"flashaaclow"];
	NSDictionary *radioFormats = [[NSDictionary alloc] initWithObjects:radioFormatObjects forKeys:radioFormatKeys];
    NSMutableString *temp_Format;
    temp_Format = [[NSMutableString alloc] initWithString:@"--modes="];
    for (RadioFormat *format in radioFormatList)
        [temp_Format appendFormat:@"%@,", [radioFormats valueForKey:[format format]]];
    for (TVFormat *format in tvFormatList)
        [temp_Format appendFormat:@"%@,",[tvFormats valueForKey:[format format]]];
    NSString *formatArg = [NSString stringWithString:temp_Format];

    //Set Proxy Arguments
    NSString *proxyArg = nil;
	NSString *partialProxyArg = nil;
    if (proxy)
    {
        proxyArg = [[NSString alloc] initWithFormat:@"-p%@", [proxy url]];
        if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue])
        {
            partialProxyArg = [[NSString alloc] initWithString:@"--partial-proxy"];
        }
    }
    //Initialize the rest of the arguments
	NSString *noWarningArg = [[NSString alloc] initWithString:@"--nocopyright"];
	NSString *noPurgeArg = [[NSString alloc] initWithString:@"--nopurge"];
	NSString *mplayerArg = [[NSString alloc] initWithFormat:@"--mplayer=%@", [bundle pathForResource:@"mplayer" ofType:nil]];
    NSString *flvstreamerArg = [[NSString alloc] initWithFormat:@"--flvstreamer=%@", [bundle pathForResource:@"rtmpdump-2.4" ofType:nil]];
	NSString *lameArg = [[NSString alloc] initWithFormat:@"--lame=%@", [bundle pathForResource:@"lame" ofType:nil]];
	NSString *atomicParsleyArg = [[NSString alloc] initWithFormat:@"--atomicparsley=%@", [bundle pathForResource:@"AtomicParsley" ofType:nil]];
	NSString *ffmpegArg = [[NSString alloc] initWithFormat:@"--ffmpeg=%@", [bundle pathForResource:@"ffmpeg" ofType:nil]];
	NSString *downloadPathArg = [[NSString alloc] initWithFormat:@"--output=%@", downloadPath];
	NSString *subDirArg = @"--subdir";
	NSString *getArg;
	if ([[show processedPID] boolValue])
		getArg = [[NSString alloc] initWithString:@"--get"];
	else
		getArg = [[NSString alloc] initWithString:@"--pid"];		
	NSString *searchArg = [[NSString alloc] initWithFormat:@"%@", [show pid]];
    
    //AudioDescribed
    NSString *versionArg;
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"AudioDescribed"] boolValue])
        versionArg = [[NSString alloc] initWithString:@"--versions=audiodescribed,signed,default"];
    else
        versionArg = [[NSString alloc] initWithString:@"--versions=default"];
    
	//We don't want this to refresh now!
	NSString *cacheExpiryArg = @"-e604800000000";
	NSString *appSupportFolder = [@"~/Library/Application Support/Get iPlayer Automator/" stringByExpandingTildeInPath];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if (![fileManager fileExistsAtPath: appSupportFolder])
	{
		[fileManager createDirectoryAtPath:appSupportFolder withIntermediateDirectories:NO attributes:nil error:nil];
	}
	profileDirArg = [[NSString alloc] initWithFormat:@"--profile-dir=%@", appSupportFolder];
	
    //Add Arguments that can't be NULL
	NSMutableArray *args = [[NSMutableArray alloc] initWithObjects:getiPlayerPath,profileDirArg,noWarningArg,noPurgeArg,mplayerArg,flvstreamerArg,lameArg,atomicParsleyArg,cacheExpiryArg,downloadPathArg,subDirArg,formatArg,getArg,searchArg,@"--attempts=5",@"--fatfilename",@"-w",@"--thumbsize=6",@"--tag-hdvideo",@"--tag-longdesc",versionArg,ffmpegArg,proxyArg,partialProxyArg,nil];
    //Verbose?
    if (verbose)
		[args addObject:[[NSString alloc] initWithString:@"--verbose"]];
	if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"DownloadSubtitles"] isEqualTo:@YES])
		[args addObject:@"--subtitles"];
	
    //Naming Convention
	if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"XBMC_naming"] boolValue])
	{
		[args addObject:@"--file-prefix=<name> - <episode> ((<modeshort>))"];
	}
	else 
	{
		[args addObject:@"--file-prefix=<nameshort><.senum><.episodeshort>"];
		[args addObject:@"--subdir-format=<nameshort>"];
	}
    //Tagging
    if (![[[NSUserDefaults standardUserDefaults] objectForKey:@"TagShows"] boolValue])
        [args addObject:@"--no-tag"];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"%@TagCNID", defaultsPrefix]]) {
		[args addObject:[[NSString alloc] initWithString:@"--tag-cnid"]];
    }

	task = [[NSTask alloc] init];
	pipe = [[NSPipe alloc] init];
	errorPipe = [[NSPipe alloc] init];
	
	[task setArguments:args];
	[task setLaunchPath:@"/usr/bin/perl"];
	[task setStandardOutput:pipe];
	[task setStandardError:errorPipe];
    
    NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:[task environment]];
    envVariableDictionary[@"DYLD_LIBRARY_PATH"] = [bundle resourcePath];
    envVariableDictionary[@"HOME"] = [@"~" stringByExpandingTildeInPath];
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
	
	//Prepare UI
	[self setCurrentProgress:@"Beginning..."];
    [show setValue:@"Starting..." forKey:@"status"];
    
	return self;
}
- (id)description
{
	return [NSString stringWithFormat:@"BBC Download (ID=%@)", [show pid]];
}
#pragma mark Task Control
- (void)DownloadDataReady:(NSNotification *)note
{
	[[pipe fileHandleForReading] readInBackgroundAndNotify];
    NSData *d = [[note userInfo] valueForKey:NSFileHandleNotificationDataItem];
	
    if ([d length] > 0) {
		NSString *s = [[NSString alloc] initWithData:d
											encoding:NSUTF8StringEncoding];
		[self processGetiPlayerOutput:s];
	}
	else
	{
		noDataCount++;
		if (noDataCount>20 && running)
		{
			running=NO;
			//Download Finished Handler
			task = nil;
			pipe = nil;
			if (runDownloads)
			{
				if (!foundLastLine)
					LastLine = [[log componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] lastObject];

				NSScanner *scn = [NSScanner scannerWithString:LastLine];
				if ([reasonForFailure isEqualToString:@"unresumable"])
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@NO forKey:@"successful"];
					[show setValue:@"Failed: Unresumable File" forKey:@"status"];
                    [show setReasonForFailure:@"Unresumable_File"];
				}
				else if ([reasonForFailure isEqualToString:@"proxy"])
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@NO forKey:@"successful"];
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
                    [show setValue:@YES forKey:@"complete"];
					[show setValue:@NO forKey:@"successful"];
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
				else if ([LastLine hasPrefix:@"INFO: Recorded"])
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@YES forKey:@"successful"];
					[show setValue:@"Download Complete" forKey:@"status"];
					NSScanner *scanner = [NSScanner scannerWithString:LastLine];
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
				else if ([LastLine hasPrefix:@"INFO: All streaming threads completed"])
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@YES forKey:@"successful"];
					[show setValue:@"Download Complete" forKey:@"status"];
					[show setPath:@"Unknown"];
				}
				else if ([scn scanUpToString:@"Already in history" intoString:nil] && 
						 [scn scanString:@"Already in" intoString:nil])
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@NO forKey:@"successful"];
					[show setValue:@"Failed: Download in History" forKey:@"status"];
					[self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
                    [show setReasonForFailure:@"InHistory"];
				}
				else
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@NO forKey:@"successful"];
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
    NSData *d = [[note userInfo] valueForKey:NSFileHandleNotificationDataItem];
    if ([d length] > 0)
	{
		[errorCache appendString:[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]];
	}
	else
	{
		noDataCount++;
		if (noDataCount>20)
		{
			//Close the error pipe when it is empty.
			errorPipe = nil;
            [processErrorCache invalidate];
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
            NSArray *array = [outp componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            
			for (NSString *message in array)
			{
                NSString *shortStatus=nil;
                NSScanner *scanner = [NSScanner scannerWithString:message];
                if ([message length] == 0){
                    continue;
                }
                else if ([scanner scanFloat:nil]) //RTMPDump
                {
                    [self processFLVStreamerMessage:message];
                    continue;
                }
				else if ([message hasPrefix:@"frame="]) shortStatus= @"Converting..."; //FFMpeg
                else if ([message hasPrefix:@" Progress"]) shortStatus= @"Processing Download..."; //Download Artwork
                else if ([message hasPrefix:@"ERROR:"] || [message hasPrefix:@"\rERROR:"] || [message hasPrefix:@"\nERROR:"]) //Could be unresumable.
                {
                    if ([scanner scanUpToString:@"corrupt file!" intoString:nil] && [scanner scanString:@"corrupt file!" intoString:nil])
                    {
                        [self addToLog:@"Unresumable file, please delete the partial file and try again." noTag:NO];
                        [task interrupt];
                        reasonForFailure=@"unresumable";
                        [show setReasonForFailure:@"Unresumable_File"];
                    }
                }
				else if ([message hasPrefix:@"A:"]) //MPlayer
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
                    continue;
				}
                else //Other
                {
                    shortStatus = [NSString stringWithFormat:@"Initialising... -- %@", [show valueForKey:@"showName"]];
                    [self addToLog:message noTag:YES];
                } 
                if (shortStatus != nil)
                {
                    [self setCurrentProgress:[NSString stringWithFormat:@"%@ -- %@",shortStatus,[show valueForKey:@"showName"]]];
                    [self setPercentage:102];
                    [show setValue:shortStatus forKey:@"status"];
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
	NSArray *array = [outp componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	//Parse each line individually.
	for (NSString *output in array)
	{
		if ([output hasPrefix:@"INFO: Downloading Subtitles"])
		{
			NSScanner *scanner = [NSScanner scannerWithString:output];
			NSString *srtPath;
			[scanner scanString:@"INFO: Downloading Subtitles to \'" intoString:nil];
			[scanner scanUpToString:@".srt\'" intoString:&srtPath];
			srtPath = [srtPath stringByAppendingPathExtension:@"srt"];
			[show setSubtitlePath:srtPath];
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
            [show setValue:@YES forKey:@"complete"];
            [show setValue:@NO forKey:@"successful"];
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
			if(![scanner scanDecimal:&recieved]) recieved = [@0 decimalValue];
			[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] 
									intoString:nil];
			if(![scanner scanDecimal:&total]) total = [@0 decimalValue];
			[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] 
									intoString:nil];
			if(![scanner scanInteger:&speed]) speed = [@0 integerValue];
			[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] 
									intoString:nil];
			if(![scanner scanDecimal:&percentage]) percentage = [@0 decimalValue];
			[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] 
									intoString:nil];
			if(![scanner scanUpToString:@"rem" intoString:&timeRemaining]) timeRemaining=@"Unknown";
			double adjustedSpeed = [@(speed) doubleValue]/8;
			[self setPercentage:[[NSDecimalNumber decimalNumberWithDecimal:percentage] doubleValue]];
			if ([[NSDecimalNumber decimalNumberWithDecimal:total] doubleValue] < 5.00 && [[NSDecimalNumber decimalNumberWithDecimal:recieved] doubleValue] > 0)
			{
				[self setCurrentProgress:[NSString stringWithFormat:@"%3.1f%% (%3.2fMB/%3.2fMB) - %5.1fKB/s -- Getting MOV atom.",
										  [[NSDecimalNumber decimalNumberWithDecimal:percentage] doubleValue],
										  [[NSDecimalNumber decimalNumberWithDecimal:recieved] doubleValue],
										  [[NSDecimalNumber decimalNumberWithDecimal:total] doubleValue],
										  adjustedSpeed]];
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
										  adjustedSpeed]];
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
