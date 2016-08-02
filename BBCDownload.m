//
//  Download.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/14/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "BBCDownload.h"

@implementation BBCDownload
+ (void)initFormats
{
   NSArray *tvFormatKeys = @[@"Flash - HD",@"Flash - Very High",@"Flash - High",@"Flash - Standard",@"Flash - Low"];
   NSArray *tvFormatObjects = @[@"flashhd",@"flashvhigh",@"flashhigh",@"flashstd",@"flashlow"];
   NSArray *radioFormatKeys = @[@"Flash AAC - High",@"Flash AAC - Standard",@"Flash AAC - Low"];
   NSArray *radioFormatObjects = @[@"flashaachigh",@"flashaacstd",@"flashaaclow"];
	tvFormats = [[NSDictionary alloc] initWithObjects:tvFormatObjects forKeys:tvFormatKeys];
	radioFormats = [[NSDictionary alloc] initWithObjects:radioFormatObjects forKeys:radioFormatKeys];
}
#pragma mark Overridden Methods
- (id)initWithProgramme:(Programme *)tempShow tvFormats:(NSArray *)tvFormatList radioFormats:(NSArray *)radioFormatList proxy:(HTTPProxy *)aProxy logController:(LogController *)logger
{
	if (!(self = [super initWithLogController:logger])) return nil;
	runAgain = NO;
	running=YES;
	foundLastLine=NO;
	errorCache = [[NSMutableString alloc] init];
	processErrorCache = [NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(processError) userInfo:nil repeats:YES];
   reasonForFailure = @"None";
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
   if (!tvFormats || !radioFormats) {
      [BBCDownload initFormats];
   }
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
         partialProxyArg = @"--partial-proxy";
      }
   }
   //Initialize the rest of the arguments
   NSString *executablesPath = [bundle.executablePath stringByDeletingLastPathComponent];

	NSString *noWarningArg = @"--nocopyright";
	NSString *noPurgeArg = @"--nopurge";
	NSString *id3v2Arg = [[NSString alloc] initWithFormat:@"--id3v2=%@", [executablesPath stringByAppendingPathComponent:@"id3v2"]];
    NSString *rtmpdumpArg = [[NSString alloc] initWithFormat:@"--rtmpdump=%@", [executablesPath stringByAppendingPathComponent:@"rtmpdump"]];
	NSString *atomicParsleyArg = [[NSString alloc] initWithFormat:@"--atomicparsley=%@", [executablesPath stringByAppendingPathComponent:@"AtomicParsley"]];
	NSString *ffmpegArg = [[NSString alloc] initWithFormat:@"--ffmpeg=%@", [executablesPath stringByAppendingPathComponent:@"ffmpeg"]];
	NSString *downloadPathArg = [[NSString alloc] initWithFormat:@"--output=%@", downloadPath];
	NSString *subDirArg = @"--subdir";
   
   NSLog(@"ID3V2: %@", id3v2Arg);
   
	NSString *getArg = @"--pid";
	NSString *searchArg = [[NSString alloc] initWithFormat:@"%@", [show pid]];
   
   //AudioDescribed & Signed
   NSMutableString *versionArg = [NSMutableString stringWithString:@"--versions="];
   if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"AudioDescribedNew"] boolValue])
      [versionArg appendString:@"audiodescribed,"];
   if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SignedNew"] boolValue])
      [versionArg appendString:@"signed,"];
   [versionArg  appendString:@"default"];
   
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
	NSMutableArray *args = [[NSMutableArray alloc] initWithObjects:getiPlayerPath,profileDirArg,noWarningArg,noPurgeArg,id3v2Arg,rtmpdumpArg,atomicParsleyArg,cacheExpiryArg,downloadPathArg,subDirArg,formatArg,getArg,searchArg,@"--attempts=5",@"--keep-all",@"--fatfilename",@"--thumbsize=6",@"--tag-hdvideo",@"--tag-longdesc",@"--isodate",versionArg,ffmpegArg,proxyArg,partialProxyArg,nil];
   //Verbose?
   if (verbose)
		[args addObject:@"--verbose"];
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
		[args addObject:@"--tag-cnid"];
   }
   
	task = [[NSTask alloc] init];
	pipe = [[NSPipe alloc] init];
	errorPipe = [[NSPipe alloc] init];
	
	[task setArguments:args];
	[task setLaunchPath:@"/usr/bin/perl"];
	[task setStandardOutput:pipe];
	[task setStandardError:errorPipe];
   
   NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:[task environment]];
   envVariableDictionary[@"HOME"] = [@"~" stringByExpandingTildeInPath];
   envVariableDictionary[@"PERL_UNICODE"] = @"AS";
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
            if (!foundLastLine) {
               NSLog(@"Setting Last Line Here...");
               NSArray *logComponents =[ log componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
               LastLine = [logComponents lastObject];
               unsigned int offsetFromEnd=1;
               while (!LastLine.length) {
                  LastLine = [logComponents objectAtIndex:(logComponents.count - offsetFromEnd)];
                  ++offsetFromEnd;
               }
            }
					
            
            NSLog(@"Last Line: %@", LastLine);
            NSLog(@"Length of Last Line: %lu", (unsigned long)[LastLine length]);
            
				NSScanner *scn = [NSScanner scannerWithString:LastLine];
				if ([reasonForFailure isEqualToString:@"unresumable"])
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@NO forKey:@"successful"];
					[show setValue:@"Failed: Unresumable File" forKey:@"status"];
               [show setReasonForFailure:@"Unresumable_File"];
				}
            else if ([reasonForFailure isEqualToString:@"FileExists"])
            {
               show.complete = @YES;
               show.successful = @NO;
               show.status = @"Failed: File Exists";
               show.reasonForFailure = reasonForFailure;
            }
				else if ([reasonForFailure isEqualToString:@"proxy"])
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@NO forKey:@"successful"];
					NSString *proxyOption = [[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"];
					if ([proxyOption isEqualToString:@"None"])
					{
						[show setValue:@"Failed: See Log" forKey:@"status"];
						[self addToLog:@"REASON FOR FAILURE: VPN or System Proxy failed. If you are using a VPN or a proxy configured in System Preferences, contact the VPN or proxy provider for assistance." noTag:TRUE];
						[self addToLog:@"If outside the UK, you may also disconnect your VPN and enable the provided proxy in Preferences." noTag:TRUE];
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
            else if ([LastLine containsString:@"Permission denied"])
            {
               if ([LastLine containsString:@"/Volumes"]) //Most likely disconnected external HDD
               {
                  show.complete = @YES;
                  show.successful = @NO;
                  show.status = @"Failed: HDD not Accessible";
                  [self addToLog:@"REASON FOR FAILURE: The specified download directory could not be written to." noTag:YES];
                  [self addToLog:@"Most likely this is because your external hard drive is disconnected but it could also be a permission issue"
                           noTag:YES];
                  [self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
                  [show setReasonForFailure:@"External_Disconnected"];
               
               }
               else
               {
                  show.complete = @YES;
                  show.successful = @NO;
                  show.status = @"Failed: Download Directory Unwriteable";
                  [self addToLog:@"REASON FOR FAILURE: The specified download directory could not be written to." noTag:YES];
                  [self addToLog:@"Please check the permissions on your download directory."
                           noTag:YES];
                  [self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
                  [show setReasonForFailure:@"Download_Directory_Permissions"];
               }
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
         [nc removeObserver:self];
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
               BOOL isUnresumable = NO;
               if ([scanner scanUpToString:@"corrupt file!" intoString:nil] && [scanner scanString:@"corrupt file!" intoString:nil])
               {
                  isUnresumable = YES;
               }
               if (!isUnresumable) {
                  [scanner setScanLocation:0];
                  if ([scanner scanUpToString:@"Couldn't find the seeked keyframe in this chunk!" intoString:nil] && [scanner scanString:@"Couldn't find the seeked keyframe in this chunk!" intoString:nil])
                  {
                     isUnresumable = YES;
                  }
               }
               if (isUnresumable)
               {
                  [self addToLog:@"Unresumable file, please delete the partial file and try again." noTag:NO];
                  [task interrupt];
                  reasonForFailure=@"unresumable";
                  [show setReasonForFailure:@"Unresumable_File"];
               }
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
      else if ([output hasSuffix:@"already exists"])
      {
         reasonForFailure=@"FileExists";
         [self addToLog:output noTag:YES];
      }
		else if ([output hasPrefix:@"INFO: Recorded"])
		{
			LastLine = [NSString stringWithString:output];
			foundLastLine=YES;
		}
		else if ([output hasPrefix:@"INFO: No specified modes"] && [output hasSuffix:@"--modes=)"])
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
      else if ([output hasPrefix:@"WARNING: No programmes are available for this pid with version(s):"] ||
               [output hasPrefix:@"INFO: No versions of this programme were selected"])
      {
          NSScanner *versionScanner = [NSScanner scannerWithString:output];
          [versionScanner scanUpToString:@"available versions:" intoString:nil];
          [versionScanner scanString:@"available versions:" intoString:nil];
          [versionScanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
          NSString *availableVersions;
          [versionScanner scanUpToString:@")" intoString:&availableVersions];
          if ([availableVersions rangeOfString:@"audiodescribed"].location != NSNotFound ||
              [availableVersions rangeOfString:@"signed"].location != NSNotFound)
          {
              [show setReasonForFailure:@"AudioDescribedOnly"];
          }
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
