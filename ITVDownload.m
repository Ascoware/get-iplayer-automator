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
    show = tempShow;
    attemptNumber=1;
    nc = [NSNotificationCenter defaultCenter];
    
    running=TRUE;
    
    [self setCurrentProgress:[NSString stringWithFormat:@"Retrieving Programme Metadata... -- %@",[show showName]]];
    [self setPercentage:102];
    [tempShow setValue:@"Initialising..." forKey:@"status"];
    
    formatList = [itvFormatList copy];
    [self addToLog:[NSString stringWithFormat:@"Downloading %@",[show showName]] noTag:NO];
    [self addToLog:@"INFO: Preparing Request for Auth Info" noTag:YES];
    
    [self launchMetaRequest];
    
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
        [self addToLog:@"ERROR: Show not Available."  noTag:YES];
        [show setSuccessful:[NSNumber numberWithBool:NO]];
        [show setComplete:[NSNumber numberWithBool:YES]];
        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"] isEqualTo:@"Provided"])
            [show setReasonForFailure:@"ShowNotFound"];
        else if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"] isEqualTo:@"Custom"])
            [show setReasonForFailure:@"ShowNotFound"];
        else
            [show setReasonForFailure:@"ShowNotFound"];
        [show setValue:@"Failed: Not Available" forKey:@"status"];
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
    [scanner scanUpToString:@"<EpisodeTitle" intoString:nil];
    if (![scanner scanString:@"<EpisodeTitle/>" intoString:nil])
    {
        [scanner scanString:@"<EpisodeTitle>" intoString:nil];
        [scanner scanUpToString:@"</EpisodeTitle>" intoString:&episodeName];
        if (!episodeName) episodeName=@"(No Episode Name)";
        [show setEpisodeName:episodeName];
    }
    else
        [show setEpisodeName:@"(No Episode Name)"];
    
    @try {
        //Fix Showname
        NSURLRequest *metaDataRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.itv.com/_app/Dynamic/CatchUpData.ashx?ViewType=5&Filter=%@",[show realPID]]]];
        NSString *response = [[NSString alloc] initWithData:[NSURLConnection sendSynchronousRequest:metaDataRequest returningResponse:nil error:nil] encoding:NSUTF8StringEncoding];
        NSScanner *metadataScanner = [NSScanner scannerWithString:response];
        [metadataScanner scanUpToString:@"<h2>" intoString:nil];
        [metadataScanner scanString:@"<h2>" intoString:nil];
        NSString *description, *showname;
        [metadataScanner scanUpToString:@"</h2>" intoString:&showname];
        [metadataScanner scanUpToString:@"<p>" intoString:nil];
        [metadataScanner scanString:@"<p>" intoString:nil];
        [metadataScanner scanUpToString:@"</p>" intoString:&description];
        showname = [NSString stringWithFormat:@"%@ - %@",showname,[show episodeName]];
        [show setShowName:showname];
        [show setDesc:description];
    }
    @catch (NSException *exception) {
        [self addToLog:@"Could not fix showName. Likely to encounter trouble with metadata."];
    }

    
    
    //Retrieve Episode Number
    NSInteger episodeNumber;
    [scanner scanUpToString:@"<EpisodeNumber" intoString:nil];
    if (![scanner scanString:@"<EpisodeNumber/>" intoString:nil])
    {
        [scanner scanString:@"<EpisodeNumber>" intoString:nil];
        [scanner scanInteger:&episodeNumber];
        [show setEpisode:episodeNumber];
    }
    else
        [show setEpisode:0];
    
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
    downloadPath = [downloadPath stringByAppendingPathComponent:[[[NSString stringWithFormat:@"%@.partial.flv",[show showName]] stringByReplacingOccurrencesOfString:@"/" withString:@"-"] stringByReplacingOccurrencesOfString:@":" withString:@" -"]];
    NSMutableArray *args;
    @try {
        args = [NSMutableArray arrayWithObjects:
                                [NSString stringWithFormat:@"-r%@",authURL],
                                @"-Whttp://www.itv.com/mediaplayer/ITVMediaPlayer.swf?v=11.20.654",
                                [NSString stringWithFormat:@"-y%@",playPath],
                                [NSString stringWithFormat:@"-o%@",downloadPath],
                                nil];
    }
    @catch (NSException *exception) {
        [self addToLog:@"ERROR: Could not process ITV metadata." noTag:YES];
        [show setComplete:[NSNumber numberWithBool:YES]];
        [show setSuccessful:[NSNumber numberWithBool:NO]];
        [show setValue:@"Download Failed" forKey:@"status"];
        [show setReasonForFailure:@"MetadataProcessing"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        return;
    }
    [self launchRTMPDumpWithArgs:args];
#pragma mark
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
    [processErrorCache invalidate];
    running=FALSE;
}

- (void)launchMetaRequest
{
    errorCache = [[NSMutableString alloc] initWithString:@""];
    processErrorCache = [NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(processError) userInfo:nil repeats:YES];
    
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
    [request setTimeOutSeconds:10];
    [request setNumberOfTimesToRetryOnTimeout:3];
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
}
-(void)launchRTMPDumpWithArgs:(NSMutableArray *)args
{
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
	[self setCurrentProgress:[NSString stringWithFormat:@"Initialising RTMPDump... -- %@",[show showName]]];
    [self setPercentage:102];
}
@end
