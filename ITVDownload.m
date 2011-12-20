//
//  ITVDownload.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 12/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ITVDownload.h"
#import "ASIHTTPRequest.h"

@implementation ITVDownload

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}
- (id)description
{
	return [NSString stringWithFormat:@"Download (ID=%@)", [show pid]];
}
- (id)initWithProgramme:(Programme *)tempShow itvFormats:(NSArray *)itvFormatList
{
    nc = [NSNotificationCenter defaultCenter];
    
    [self setCurrentProgress:@"Retrieving Programme Metadata..."];
    [self setPercentage:102];
    [tempShow setValue:@"Initialising..." forKey:@"status"];
    
    formatList = [itvFormatList copy];
    [self addToLog:[NSString stringWithFormat:@"Downloading %@",[show showName]] noTag:NO];
    [self addToLog:@"INFO: Preparing Request for Auth Info" noTag:YES];
    
    
    errorCache = [[NSMutableString alloc] initWithString:@""];
    errorTimer = [NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(processError) userInfo:nil repeats:YES];
    
    show = tempShow;
    NSString *body = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Body" ofType:nil]] 
                                           encoding:NSUTF8StringEncoding];
    NSString *temp_id;
    NSScanner *scanner = [NSScanner scannerWithString:[show url]];
    [scanner scanUpToString:@"Filter=" intoString:nil];
    [scanner scanString:@"Filter=" intoString:nil];
    [scanner scanUpToString:@"kljkjj" intoString:&temp_id];
    [show setRealPID:temp_id];
    body = [body stringByReplacingOccurrencesOfString:@"!!!ID!!!" withString:temp_id];
        
    
    NSURL *requestURL = [[NSURL alloc] initWithString:@"http://mercury.itv.com/PlaylistService.svc"];
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:requestURL];
    [request addRequestHeader:@"Referer" value:@"http://www.itv.com/mercury/Mercury_VideoPlayer.swf?v=1.5.309/[[DYNAMIC]]/2"];
    [request addRequestHeader:@"Content-Type" value:@"text/xml; charset=utf-8"];
    [request addRequestHeader:@"SOAPAction" value:@"\"http://tempuri.org/PlaylistService/GetPlaylist\""];
    [request setRequestMethod:@"POST"];
    [request setPostBody:[NSMutableData dataWithData:[body dataUsingEncoding:NSUTF8StringEncoding]]];
    [request setDidFinishSelector:@selector(metaRequestFinished:)];
    [request setDelegate:self];
    
    NSString *proxyOption = [[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"];
	if ([proxyOption isEqualToString:@"Custom"])
	{
        NSString *proxyHost;
        NSInteger proxyPort;
		scanner = [NSScanner scannerWithString:[[NSUserDefaults standardUserDefaults] valueForKey:@"CustomProxy"]];
        [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
        [scanner scanUpToString:@":" intoString:&proxyHost];
        [scanner scanString:@":" intoString:nil];
        if ([scanner scanInteger:&proxyPort]) [request setProxyPort:proxyPort];
        [request setProxyHost:proxyHost];
        [self addToLog:[NSString stringWithFormat:@"INFO: Using proxy %@",[[NSUserDefaults standardUserDefaults] valueForKey:@"CustomProxy"]] noTag:YES];
	}
	else if ([proxyOption isEqualToString:@"Provided"])
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
		}
		else
		{
            NSString *providedProxy = [[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding];
            scanner = [NSScanner scannerWithString:providedProxy];
            NSString *proxyHost;
            NSInteger proxyPort;
            [scanner scanUpToString:@":" intoString:&proxyHost];
            [scanner scanString:@":" intoString:nil];
            [scanner scanInteger:&proxyPort];
            [request setProxyHost:proxyHost];
            [request setProxyPort:proxyPort];
            [self addToLog:[NSString stringWithFormat:@"INFO: Using proxy %@",providedProxy] noTag:YES];
		}
	}

    [request setProxyType:@"HTTP"];
    [self addToLog:@"INFO: Requesting Auth." noTag:YES];
    [request startAsynchronous];
    return self;
}
-(void)metaRequestFinished:(ASIHTTPRequest *)request
{
    NSLog(@"Response Status Code: %ld",(long)[request responseStatusCode]);
    if ([request responseStatusCode] == 0)
    {
        [self addToLog:@"ERROR: No response received. Probably a proxy issue." noTag:YES];
        [show setSuccessful:[NSNumber numberWithBool:NO]];
        [show setComplete:[NSNumber numberWithBool:YES]];
        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"] isEqualTo:@"Provided"])
            [show setReasonForFailure:@"Provided_Proxy"];
        else if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"] isEqualTo:@"Custom"])
            [show setReasonForFailure:@"Custom_Proxy"];
        else
            [show setReasonForFailure:@"Internet_Connection"];
        [show setValue:@"Failed: Bad Proxy" forKey:@"status"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        [self addToLog:@"Download Failed" noTag:NO];
        return;
    }
    else if ([request responseStatusCode] == 500)
    {
        [self addToLog:@"ERROR: ITV thinks you are outside the UK."  noTag:YES];
        [show setSuccessful:[NSNumber numberWithBool:NO]];
        [show setComplete:[NSNumber numberWithBool:YES]];
        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"] isEqualTo:@"Provided"])
            [show setReasonForFailure:@"Provided_Proxy"];
        else if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"] isEqualTo:@"Custom"])
            [show setReasonForFailure:@"Custom_Proxy"];
        else
            [show setReasonForFailure:@"Outside_UK"];
        [show setValue:@"Failed: Outside UK" forKey:@"status"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        [self addToLog:@"Download Failed" noTag:NO];
        return;
    }
    else if ([request responseStatusCode] != 200)
    {
        [self addToLog:@"ERROR: Could not retrieve program metadata." noTag:YES];
        [show setSuccessful:[NSNumber numberWithBool:NO]];
        [show setComplete:[NSNumber numberWithBool:YES]];
        [show setValue:@"Download Failed" forKey:@"status"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        [self addToLog:@"Download Failed" noTag:NO];
        return;
    }
    NSData *urlData = [request responseData];
    
    NSString *output;
    if (urlData != nil)
    {
        output = [[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding];
        NSLog(@"Auth Request: %@",output);
        [self addToLog:@"INFO: Response recieved" noTag:YES];
    }
    else
    {
        NSLog(@"Could not retrieve program metadata");
        [show setValue:[NSNumber numberWithBool:YES] forKey:@"complete"];
        [show setValue:[NSNumber numberWithBool:NO] forKey:@"successful"];
        [show setValue:@"Download Failed" forKey:@"status"];
        [self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
        [show setReasonForFailure:@"ITVUnknown"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        return;
    }
        
    
    output = [output stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
    NSScanner *scanner = [NSScanner scannerWithString:output];
    //Retrieve Series Name
    NSString *seriesName;
    [scanner scanUpToString:@"<ProgrammeTitle>" intoString:nil];
    [scanner scanString:@"<ProgrammeTitle>" intoString:nil];
    [scanner scanUpToString:@"</ProgrammeTitle>" intoString:&seriesName];
    [show setSeriesName:seriesName];
    
    //Retrieve Transmission Date
    NSString *dateString;
    [scanner scanUpToString:@"<TransmissionDate>" intoString:nil];
    [scanner scanString:@"<TransmissionDate>" intoString:nil];
    [scanner scanUpToString:@"</TransmissionDate>" intoString:&dateString];
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] initWithDateFormat:@"dd LLLL yyyy" allowNaturalLanguage:NO];
    [show setDateAired:[dateFormat dateFromString:dateString]];
    
    //Retrieve Episode Name
    NSString *episodeName;
    [scanner scanUpToString:@"<EpisodeTitle>" intoString:nil];
    [scanner scanString:@"<EpisodeTitle>" intoString:nil];
    [scanner scanUpToString:@"</EpisodeTitle>" intoString:&episodeName];
    [show setEpisodeName:episodeName];
    
    //Fix Show Name - Episode Name
    NSScanner *scanner2 = [NSScanner scannerWithString:episodeName];
    if ([scanner2 scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil] && ![[show showName] hasSuffix:episodeName])
        [show setShowName:[[show showName] stringByAppendingFormat:@" - %@",episodeName]];
    
    //Retrieve Episode Number
    NSInteger episodeNumber;
    [scanner scanUpToString:@"<EpisodeNumber>" intoString:nil];
    [scanner scanString:@"<EpisodeNumber>" intoString:nil];
    [scanner scanInteger:&episodeNumber];
    [show setEpisode:episodeNumber];
    
    //Retrieve Thumbnail URL
    [scanner scanUpToString:@"<PosterFrame>" intoString:nil];
    [scanner scanUpToString:@"CDATA" intoString:nil];
    [scanner scanString:@"CDATA[" intoString:nil];
    [scanner scanUpToString:@"]]" intoString:&thumbnailURL];
        
    //Retrieve Subtitle URL
    [scanner scanUpToString:@"<ClosedCaptioning" intoString:nil];
    if(![scanner scanString:@"<ClosedCaptioningURIs/>" intoString:nil])
    {
        [scanner scanUpToString:@"CDATA[" intoString:nil];
        [scanner scanString:@"CDATA[" intoString:nil];
        [scanner scanUpToString:@"]]" intoString:&subtitleURL];
    }
    
    //Retrieve Auth URL
    NSString *authURL;
    [scanner scanUpToString:@"rtmpe://" intoString:nil];
    [scanner scanUpToString:@"\"" intoString:&authURL];
    
    NSLog(@"Retrieving Playpath");
    //Retrieve PlayPath
    NSString *playPath;
    NSArray *formatKeys = [NSArray arrayWithObjects:@"Flash - Very Low",@"Flash - Low",@"Flash - Standard",@"Flash - High",nil];
    NSArray *formatObjects = [NSArray arrayWithObjects:@"400000",@"600000",@"800000",@"1200000",nil];
    NSDictionary *formatDic = [NSDictionary dictionaryWithObjects:formatObjects forKeys:formatKeys];
    [scanner scanUpToString:@"MediaFile delivery" intoString:nil];
    [scanner scanString:@"MediaFile delivery" intoString:nil];
    [scanner scanUpToString:@"MediaFile delivery" intoString:nil];
    NSUInteger location = [scanner scanLocation];
    NSMutableArray *bitrates = [[NSMutableArray alloc] init];
    NSLog(@"ITVFormatList = %@",formatList);
    for (TVFormat *format in formatList)
        [bitrates addObject:[formatDic objectForKey:[format format]]];
    NSLog(@"Birates=%@",bitrates);
    for (NSString *bitrate in bitrates)
    {
        NSLog(@"Bitrate = %@",bitrate);
        [scanner scanUpToString:[NSString stringWithFormat:@"bitrate=\"%@",bitrate] intoString:nil];
        if ([scanner scanString:[NSString stringWithFormat:@"bitrate=\"%@",bitrate] intoString:nil])
        {
            NSLog(@"Found it");
            [scanner scanUpToString:@"CDATA" intoString:nil];
            [scanner scanString:@"CDATA[" intoString:nil];
            [scanner scanUpToString:@"]]" intoString:&playPath];
            break;
        }
        [scanner setScanLocation:location];
    }
    
    [self addToLog:@"INFO: Program data processed." noTag:YES];
    
    //Create Download Path
    downloadPath = [[NSUserDefaults standardUserDefaults] valueForKey:@"DownloadPath"];
    downloadPath = [downloadPath stringByAppendingPathComponent:[show seriesName]];
    [[NSFileManager defaultManager] createDirectoryAtPath:downloadPath withIntermediateDirectories:YES attributes:nil error:nil];
    downloadPath = [downloadPath stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@ - %@.partial.flv",[show seriesName],[show episodeName]] stringByReplacingOccurrencesOfString:@"/" withString:@"-"]];
    
    NSMutableArray *args = [NSMutableArray arrayWithObjects:
                            [NSString stringWithFormat:@"-r%@",authURL],
                            @"-Whttp://www.itv.com/mediaplayer/ITVMediaPlayer.swf?v=11.20.654",
                            [NSString stringWithFormat:@"-y%@",playPath],
                            [NSString stringWithFormat:@"-o%@",downloadPath],
                            nil];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[[[downloadPath stringByDeletingPathExtension] stringByDeletingPathExtension] stringByAppendingPathExtension:@"mp4"]])
    {
        [self addToLog:@"ERROR: Destination file already exists." noTag:YES];
        [show setComplete:[NSNumber numberWithBool:YES]];
        [show setSuccessful:[NSNumber numberWithBool:NO]];
        [show setValue:@"Download Failed" forKey:@"status"];
        [show setReasonForFailure:@"FileExists"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        return;
    }
    else if ([[NSFileManager defaultManager] fileExistsAtPath:downloadPath])
    {
        [self addToLog:@"WARNING: Partial file already exists...attempting to resume" noTag:YES];
        [args addObject:@"--resume"];
    }
    
    task = [[NSTask alloc] init];
    pipe = [[NSPipe alloc] init];
    errorPipe = [[NSPipe alloc] init];
    [task setLaunchPath:[[NSBundle mainBundle] pathForResource:@"rtmpdump-2.4" ofType:nil]];
    [self addToLog:[NSString stringWithFormat:@"LaunchPath: %@",[task launchPath]] noTag:YES];
    
    /* rtmpdump -r "rtmpe://cp72511.edgefcs.net/ondemand?auth=eaEc.b4aodIcdbraJczd.aKchaza9cbdTc0cyaUc2aoblaLc3dsdkd5d9cBduczdLdn-bo64cN-eS-6ys1GDrlysDp&aifp=v002&slist=production/" -W http://www.itv.com/mediaplayer/ITVMediaPlayer.swf?v=11.20.654 -y "mp4:production/priority/CATCHUP/e48ab1e2/1a73/4620/adea/dda6f21f45ee/1-6178-0002-001_THE-ROYAL-VARIETY-PERFORMANCE-2011_TX141211_ITV1200_16X9.mp4" -o test2 */
    
    [task setArguments:[NSArray arrayWithArray:args]];
    
    
    [task setStandardOutput:pipe];
    [task setStandardError:errorPipe];
    fh = [pipe fileHandleForReading];
	errorFh = [errorPipe fileHandleForReading];
    
    NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:[task environment]];
    [envVariableDictionary setObject:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources"] forKey:@"DYLD_LIBRARY_PATH"];
    [envVariableDictionary setObject:[@"~" stringByExpandingTildeInPath] forKey:@"HOME"];
    [task setEnvironment:envVariableDictionary];
    
	
	[nc addObserver:self
		   selector:@selector(DownloadDataReady:)
			   name:NSFileHandleReadCompletionNotification
			 object:fh];
	[nc addObserver:self
		   selector:@selector(ErrorDataReady:)
			   name:NSFileHandleReadCompletionNotification
			 object:errorFh];
    [nc addObserver:self 
           selector:@selector(rtmpdumpFinished:) 
               name:NSTaskDidTerminateNotification 
             object:task];
    
    [self addToLog:@"INFO: Launching RTMPDUMP..." noTag:YES];
	[task launch];
	[fh readInBackgroundAndNotify];
	[errorFh readInBackgroundAndNotify];
	[show setValue:@"Initiliasing..." forKey:@"status"];
	
	//Prepare UI
	[self setCurrentProgress:@"Initialising RTMPDump..."];
    [self setPercentage:102];
    
    return;
}
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
        [self addToLog:output noTag:YES];
    }
}
- (void)processError
{
	//Separate the output by line.
	NSString *string = [[NSString alloc] initWithString:errorCache];
    errorCache = [NSMutableString stringWithString:@""];
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
        NSScanner *scanner = [NSScanner scannerWithString:output];
        if ([scanner scanFloat:nil])
        {
            [self processFLVStreamerMessage:output];
        }
        else
            if([output length] > 1) [self addToLog:output noTag:YES];
    }
}
- (void)cancelDownload:(id)sender
{
	//Some basic cleanup.
	[task interrupt];
	[nc removeObserver:self name:NSFileHandleReadCompletionNotification object:fh];
	[nc removeObserver:self name:NSFileHandleReadCompletionNotification object:errorFh];
	[show setValue:@"Cancelled" forKey:@"status"];
    [show setComplete:[NSNumber numberWithBool:NO]];
    [show setSuccessful:[NSNumber numberWithBool:NO]];
	[self addToLog:@"Download Cancelled"];
    [errorTimer invalidate];
}
- (void)rtmpdumpFinished:(NSNotification *)finishedNote
{
    [self addToLog:@"RTMPDUMP finished"];
    [nc removeObserver:self name:NSFileHandleReadCompletionNotification object:fh];
	[nc removeObserver:self name:NSFileHandleReadCompletionNotification object:errorFh];
    [errorTimer invalidate];
    
    NSInteger exitCode=[[finishedNote object] terminationStatus];
    NSLog(@"Exit Code = %ld",(long)exitCode);
    if (exitCode==0)
    {
        [show setComplete:[NSNumber numberWithBool:YES]];
        [show setSuccessful:[NSNumber numberWithBool:YES]];
        NSDictionary *info = [NSDictionary dictionaryWithObject:show forKey:@"Programme"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AddProgToHistory" object:self userInfo:info];
    }
    else if (exitCode==1)
    {
        if ([[[task arguments] lastObject] isEqualTo:@"--resume"])
        {
            
            [self addToLog:@"WARNING: Download couldn't be resumed. Overwriting partial file." noTag:YES];
            [self addToLog:@"INFO: Preparing Request for Auth Info" noTag:YES];
            
            
            errorCache = [[NSMutableString alloc] initWithString:@""];
            errorTimer = [NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(processError) userInfo:nil repeats:YES];
            
            NSString *body = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Body" ofType:nil]] 
                                                   encoding:NSUTF8StringEncoding];
            NSString *temp_id;
            NSScanner *scanner = [NSScanner scannerWithString:[show url]];
            [scanner scanUpToString:@"Filter=" intoString:nil];
            [scanner scanString:@"Filter=" intoString:nil];
            [scanner scanUpToString:@"kljkjj" intoString:&temp_id];
            [show setRealPID:temp_id];
            body = [body stringByReplacingOccurrencesOfString:@"!!!ID!!!" withString:temp_id];
            
            
            NSURL *requestURL = [[NSURL alloc] initWithString:@"http://mercury.itv.com/PlaylistService.svc"];
            
            ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:requestURL];
            [request addRequestHeader:@"Referer" value:@"http://www.itv.com/mercury/Mercury_VideoPlayer.swf?v=1.5.309/[[DYNAMIC]]/2"];
            [request addRequestHeader:@"Content-Type" value:@"text/xml; charset=utf-8"];
            [request addRequestHeader:@"SOAPAction" value:@"\"http://tempuri.org/PlaylistService/GetPlaylist\""];
            [request setRequestMethod:@"POST"];
            [request setPostBody:[NSMutableData dataWithData:[body dataUsingEncoding:NSUTF8StringEncoding]]];
            
            NSString *proxyOption = [[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"];
            if ([proxyOption isEqualToString:@"Custom"])
            {
                NSString *proxyHost;
                NSInteger proxyPort;
                scanner = [NSScanner scannerWithString:[[NSUserDefaults standardUserDefaults] valueForKey:@"CustomProxy"]];
                [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
                [scanner scanUpToString:@":" intoString:&proxyHost];
                [scanner scanString:@":" intoString:nil];
                if ([scanner scanInteger:&proxyPort]) [request setProxyPort:proxyPort];
                [request setProxyHost:proxyHost];
                [self addToLog:[NSString stringWithFormat:@"INFO: Using proxy %@",[[NSUserDefaults standardUserDefaults] valueForKey:@"CustomProxy"]] noTag:YES];
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
                }
                else
                {
                    NSString *providedProxy = [[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding];
                    scanner = [NSScanner scannerWithString:providedProxy];
                    NSString *proxyHost;
                    NSInteger proxyPort;
                    [scanner scanUpToString:@":" intoString:&proxyHost];
                    [scanner scanString:@":" intoString:nil];
                    [scanner scanInteger:&proxyPort];
                    [request setProxyHost:proxyHost];
                    [request setProxyPort:proxyPort];
                    [self addToLog:[NSString stringWithFormat:@"INFO: Using proxy %@",providedProxy] noTag:YES];
                }
            }
            
            [request setProxyType:@"HTTP"];
            [self addToLog:@"INFO: Requesting Auth." noTag:YES];
            [request startSynchronous];
            NSData *urlData = [request responseData];
            
            NSString *output;
            if (urlData != nil)
            {
                output = [[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding];
                [self addToLog:@"INFO: Response recieved" noTag:YES];
            }
            else
            {
                NSLog(@"Could not retrieve program metadata");
                [show setValue:[NSNumber numberWithBool:YES] forKey:@"complete"];
                [show setValue:[NSNumber numberWithBool:NO] forKey:@"successful"];
                [show setValue:@"Download Failed" forKey:@"status"];
                [self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
                [show setReasonForFailure:@"ITVUnknown"];
                [nc postNotificationName:@"DownloadFinished" object:show];
                return;
            }
            
            
            output = [output stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
            scanner = [NSScanner scannerWithString:output];
            //Retrieve Series Name
            NSString *seriesName;
            [scanner scanUpToString:@"<ProgrammeTitle>" intoString:nil];
            [scanner scanString:@"<ProgrammeTitle>" intoString:nil];
            [scanner scanUpToString:@"</ProgrammeTitle>" intoString:&seriesName];
            [show setSeriesName:seriesName];
            
            //Retrieve Transmission Date
            NSString *dateString;
            [scanner scanUpToString:@"<TransmissionDate>" intoString:nil];
            [scanner scanString:@"<TransmissionDate>" intoString:nil];
            [scanner scanUpToString:@"</TransmissionDate>" intoString:&dateString];
            NSDateFormatter *dateFormat = [[NSDateFormatter alloc] initWithDateFormat:@"dd LLLL yyyy" allowNaturalLanguage:NO];
            [show setDateAired:[dateFormat dateFromString:dateString]];
            
            //Retrieve Episode Name
            NSString *episodeName;
            [scanner scanUpToString:@"<EpisodeTitle>" intoString:nil];
            [scanner scanString:@"<EpisodeTitle>" intoString:nil];
            [scanner scanUpToString:@"</EpisodeTitle>" intoString:&episodeName];
            [show setEpisodeName:episodeName];
            
            //Retrieve Episode Number
            NSInteger episodeNumber;
            [scanner scanUpToString:@"<EpisodeNumber>" intoString:nil];
            [scanner scanString:@"<EpisodeNumber>" intoString:nil];
            [scanner scanInteger:&episodeNumber];
            [show setEpisode:episodeNumber];
            
            //Retrieve Thumbnail URL
            [scanner scanUpToString:@"<PosterFrame>" intoString:nil];
            [scanner scanUpToString:@"CDATA" intoString:nil];
            [scanner scanString:@"CDATA[" intoString:nil];
            [scanner scanUpToString:@"]]" intoString:&thumbnailURL];
            
            //Retrieve Subtitle URL
            [scanner scanUpToString:@"<ClosedCaptioning" intoString:nil];
            if(![scanner scanString:@"<ClosedCaptioningURIs/>" intoString:nil])
            {
                [scanner scanUpToString:@"CDATA[" intoString:nil];
                [scanner scanString:@"CDATA[" intoString:nil];
                [scanner scanUpToString:@"]]" intoString:&subtitleURL];
            }
            
            //Retrieve Auth URL
            NSString *authURL;
            [scanner scanUpToString:@"rtmpe://" intoString:nil];
            [scanner scanUpToString:@"\"" intoString:&authURL];
            
            NSLog(@"Retrieving Playpath");
            //Retrieve PlayPath
            NSString *playPath;
            NSArray *formatKeys = [NSArray arrayWithObjects:@"Flash - Very Low",@"Flash - Low",@"Flash - Standard",@"Flash - High",nil];
            NSArray *formatObjects = [NSArray arrayWithObjects:@"400000",@"600000",@"800000",@"1200000",nil];
            NSDictionary *formatDic = [NSDictionary dictionaryWithObjects:formatObjects forKeys:formatKeys];
            [scanner scanUpToString:@"MediaFile delivery" intoString:nil];
            [scanner scanString:@"MediaFile derlivery" intoString:nil];
            [scanner scanUpToString:@"MediaFile delivery" intoString:nil];
            NSUInteger location = [scanner scanLocation];
            NSMutableArray *bitrates = [[NSMutableArray alloc] init];
            NSLog(@"ITVFormatList = %@",formatList);
            for (TVFormat *format in formatList)
                [bitrates addObject:[formatDic objectForKey:[format format]]];
            NSLog(@"Birates=%@",bitrates);
            for (NSString *bitrate in bitrates)
            {
                NSLog(@"Bitrate = %@",bitrate);
                [scanner scanUpToString:[NSString stringWithFormat:@"bitrate=\"%@",bitrate] intoString:nil];
                if ([scanner scanString:[NSString stringWithFormat:@"bitrate=\"%@",bitrate] intoString:nil])
                {
                    NSLog(@"Found it");
                    [scanner scanUpToString:@"CDATA" intoString:nil];
                    [scanner scanString:@"CDATA[" intoString:nil];
                    [scanner scanUpToString:@"]]" intoString:&playPath];
                    break;
                }
                [scanner setScanLocation:location];
            }
            
            [self addToLog:@"INFO: Program data processed." noTag:YES];
            
            //Create Download Path
            downloadPath = [[NSUserDefaults standardUserDefaults] valueForKey:@"DownloadPath"];
            downloadPath = [downloadPath stringByAppendingPathComponent:[show seriesName]];
            [[NSFileManager defaultManager] createDirectoryAtPath:downloadPath withIntermediateDirectories:YES attributes:nil error:nil];
            downloadPath = [downloadPath stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@ - %@.partial.flv",[show seriesName],[show episodeName]] stringByReplacingOccurrencesOfString:@"/" withString:@"-"]];
            
            NSMutableArray *args = [NSMutableArray arrayWithObjects:
                                    [NSString stringWithFormat:@"-r%@",authURL],
                                    @"-Whttp://www.itv.com/mediaplayer/ITVMediaPlayer.swf?v=11.20.654",
                                    [NSString stringWithFormat:@"-y%@",playPath],
                                    [NSString stringWithFormat:@"-o%@",downloadPath],
                                    nil];
            
            
            task = [[NSTask alloc] init];
            pipe = [[NSPipe alloc] init];
            errorPipe = [[NSPipe alloc] init];
            [task setLaunchPath:[[NSBundle mainBundle] pathForResource:@"rtmpdump-2.4" ofType:nil]];
            [self addToLog:[NSString stringWithFormat:@"LaunchPath: %@",[task launchPath]] noTag:YES];
            
            /* rtmpdump -r "rtmpe://cp72511.edgefcs.net/ondemand?auth=eaEc.b4aodIcdbraJczd.aKchaza9cbdTc0cyaUc2aoblaLc3dsdkd5d9cBduczdLdn-bo64cN-eS-6ys1GDrlysDp&aifp=v002&slist=production/" -W http://www.itv.com/mediaplayer/ITVMediaPlayer.swf?v=11.20.654 -y "mp4:production/priority/CATCHUP/e48ab1e2/1a73/4620/adea/dda6f21f45ee/1-6178-0002-001_THE-ROYAL-VARIETY-PERFORMANCE-2011_TX141211_ITV1200_16X9.mp4" -o test2 */
            
            [task setArguments:[NSArray arrayWithArray:args]];
            
            
            [task setStandardOutput:pipe];
            [task setStandardError:errorPipe];
            fh = [pipe fileHandleForReading];
            errorFh = [errorPipe fileHandleForReading];
            
            NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:[task environment]];
            [envVariableDictionary setObject:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources"] forKey:@"DYLD_LIBRARY_PATH"];
            [envVariableDictionary setObject:[@"~" stringByExpandingTildeInPath] forKey:@"HOME"];
            [task setEnvironment:envVariableDictionary];
            
            
            [nc addObserver:self
                   selector:@selector(DownloadDataReady:)
                       name:NSFileHandleReadCompletionNotification
                     object:fh];
            [nc addObserver:self
                   selector:@selector(ErrorDataReady:)
                       name:NSFileHandleReadCompletionNotification
                     object:errorFh];
            [nc addObserver:self 
                   selector:@selector(rtmpdumpFinished:) 
                       name:NSTaskDidTerminateNotification 
                     object:task];
            
            [self addToLog:@"INFO: Launching RTMPDUMP..." noTag:YES];
            [task launch];
            [fh readInBackgroundAndNotify];
            [errorFh readInBackgroundAndNotify];
            [show setValue:@"Initiliasing..." forKey:@"status"];
            
            //Prepare UI
            [self setCurrentProgress:@"Initialising RTMPDump..."];
            [self setPercentage:102];

            return;
        }
    }
    else
    {
        [show setSuccessful:[NSNumber numberWithBool:NO]];
        [show setComplete:[NSNumber numberWithBool:YES]];
        [show setReasonForFailure:@"Unknown"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        [show setValue:@"Download Failed" forKey:@"status"];
    }
    
    if ([[show successful] boolValue])
    {
        ffTask = [[NSTask alloc] init];
        ffPipe = [[NSPipe alloc] init];
        ffErrorPipe = [[NSPipe alloc] init];
        
        [ffTask setStandardOutput:ffPipe];
        [ffTask setStandardError:ffErrorPipe];
        
        ffFh = [ffPipe fileHandleForReading];
        ffErrorFh = [ffErrorPipe fileHandleForReading];
        
        NSString *completeDownloadPath = [[downloadPath stringByDeletingPathExtension] stringByDeletingPathExtension];
        completeDownloadPath = [completeDownloadPath stringByAppendingPathExtension:@"mp4"];
        [show setPath:completeDownloadPath];
        
        [ffTask setLaunchPath:[[NSBundle mainBundle] pathForResource:@"ffmpeg" ofType:nil]];
        
        [ffTask setArguments:[NSArray arrayWithObjects:
                              @"-i",[NSString stringWithFormat:@"%@",downloadPath],
                              @"-vcodec",@"copy",
                              @"-acodec",@"copy",
                              [NSString stringWithFormat:@"%@",completeDownloadPath],
                              nil]];

        [nc addObserver:self
               selector:@selector(DownloadDataReady:)
                   name:NSFileHandleReadCompletionNotification
                 object:ffFh];
        [nc addObserver:self 
               selector:@selector(ffmpegFinished:) 
                   name:NSTaskDidTerminateNotification 
                 object:ffTask];

        [ffTask launch];
        [ffFh readInBackgroundAndNotify];
        [ffErrorFh readInBackgroundAndNotify];
        
        [self setCurrentProgress:@"Converting..."];
        [show setStatus:@"Converting..."];
        [self setPercentage:102];
    }
}
- (void)ffmpegFinished:(NSNotification *)finishedNote
{
    NSLog(@"Conversion Finished");
    if ([[finishedNote object] terminationStatus] == 0)
    {
        [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:nil];
        [show setValue:@"Tagging..." forKey:@"status"];
        [self setPercentage:102];
        [self setCurrentProgress:@"Tagging..."];
        [self addToLog:@"INFO: Tagging the Show" noTag:YES];
        [self addToLog:@"INFO: Downloading thumbnail" noTag:YES];
        
        ASIHTTPRequest *downloadThumb = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:thumbnailURL]];
        [downloadThumb setDownloadDestinationPath:[[show path] stringByAppendingPathExtension:@".jpg"]];
        [downloadThumb setDelegate:self];
        [downloadThumb startAsynchronous];        
    }
    else
    {
       [nc postNotificationName:@"DownloadFinished" object:show]; 
    }
}
- (void)requestFinished:(ASIHTTPRequest *)request
{
    [self addToLog:@"INFO: Thumbnail Download Completed" noTag:YES];
    apTask = [[NSTask alloc] init];
    apPipe = [[NSPipe alloc] init];
    apFh = [apPipe fileHandleForReading];
    
    //[apTask setStandardOutput:apPipe];
    //[apTask setStandardError:apPipe];
    
    [apTask setLaunchPath:[[NSBundle mainBundle] pathForResource:@"AtomicParsley" ofType:nil]];
    
    [apTask setArguments:[NSArray arrayWithObjects:
                          [NSString stringWithFormat:@"%@",[show path]],
                          @"--stik",@"value=10",
                          @"--TVNetwork",[show tvNetwork],
                          @"--TVShowName",[show seriesName],
                          @"--TVSeasonNum",[NSString stringWithFormat:@"%ld",(long)[show season]],
                          @"--TVEpisodeNum",[NSString stringWithFormat:@"%ld",(long)[show episode]],
                          @"--TVEpisode",[show episodeName],
                          @"--title",[NSString stringWithFormat:@"%@ - %@",[show seriesName],[show episodeName]],
                          @"--artwork",[request downloadDestinationPath],
                          @"--overWrite",
                          nil]];
    [nc addObserver:self
           selector:@selector(DownloadDataReady:)
               name:NSFileHandleReadCompletionNotification
             object:apFh];
    [nc addObserver:self 
           selector:@selector(atomicParsleyFinished:) 
               name:NSTaskDidTerminateNotification 
             object:apTask];
    
    [self addToLog:@"INFO: Beginning AtomicParsley Tagging." noTag:YES];
    
    [apTask launch];
    [apFh readInBackgroundAndNotify];
    
}
- (void)requestFailed:(ASIHTTPRequest *)request
{
    [request startAsynchronous];
}
- (void)atomicParsleyFinished:(NSNotification *)finishedNote
{
    if ([[finishedNote object] terminationStatus] == 0)
        [self addToLog:@"INFO: AtomicParsley Tagging finished." noTag:YES];
    else
        [self addToLog:@"INFO: Tagging failed." noTag:YES];
    
    [nc postNotificationName:@"DownloadFinished" object:show];    
}
@end
