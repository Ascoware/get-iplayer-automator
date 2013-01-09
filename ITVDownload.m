//
//  ITVDownload.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 12/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ITVDownload.h"
#import "ASIHTTPRequest.h"
#import "ITVMediaFileEntry.h"

@implementation ITVDownload

- (id)init
{
    [super init];
    
    return self;
}
- (id)description
{
	return [NSString stringWithFormat:@"ITV Download (ID=%@)", [show pid]];
}
- (id)initWithProgramme:(Programme *)tempShow itvFormats:(NSArray *)itvFormatList
{
    [super init];
    
    show = tempShow;
    attemptNumber=1;
    nc = [NSNotificationCenter defaultCenter];
    defaultsPrefix = @"ITV_";
    
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
    [self addToLog:@"INFO: Requesting Metadata." noTag:YES];
    [request startAsynchronous];
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
    
    NSString *output = nil;
    if (urlData != nil)
    {
        output = [[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding];
        NSLog(@"Metadata Response: %@",output);
        if (verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata Response: %@", output] noTag:YES];
        [self addToLog:@"INFO: Metadata Response received" noTag:YES];
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
    NSString *seriesName = nil;
    [scanner scanUpToString:@"<ProgrammeTitle>" intoString:nil];
    [scanner scanString:@"<ProgrammeTitle>" intoString:nil];
    [scanner scanUpToString:@"</ProgrammeTitle>" intoString:&seriesName];
    [show setSeriesName:seriesName];
    
    //Init date formatter
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];

    //Retrieve Transmission Date
    NSString *dateString = nil;
    [scanner scanUpToString:@"<TransmissionDate>" intoString:nil];
    [scanner scanString:@"<TransmissionDate>" intoString:nil];
    [scanner scanUpToString:@"</TransmissionDate>" intoString:&dateString];
    [dateFormat setDateFormat:@"dd LLLL yyyy"];
    [show setDateAired:[dateFormat dateFromString:dateString]];
    
    //Retrieve Episode Name
    NSString *episodeName = nil;
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
    
    //Retrieve Episode Number
    NSInteger episodeNumber = 0;
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
    NSString *authURL = nil;
    [scanner scanUpToString:@"rtmpe://" intoString:nil];
    [scanner scanUpToString:@"\"" intoString:&authURL];
    
    NSLog(@"Metadata Processed");
    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata Processed: seriesName=%@ dateString=%@ episodeName=%@ episodeNumber=%ld thumbnailURL=%@ subtitleURL=%@ authURL=%@",
                        seriesName, dateString, episodeName, episodeNumber, thumbnailURL, subtitleURL, authURL] noTag:YES];
    
    @try {
        //Fix Showname
        NSHTTPURLResponse *metaDataResponse = nil;
        NSError *metaDataError = nil;
        NSURLRequest *metaDataRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.itv.com/_app/Dynamic/CatchUpData.ashx?ViewType=5&Filter=%@",[show realPID]]]];
        NSData *metaData = [NSURLConnection sendSynchronousRequest:metaDataRequest returningResponse:&metaDataResponse error:&metaDataError];
        if (metaDataError != nil) {
            NSLog(@"Secondary Metadata Error: %ld %@", [metaDataError code], [metaDataError localizedDescription]);
        }
        NSLog(@"Secondary Metadata Result: %ld %@", [metaDataResponse statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[metaDataResponse statusCode]]);
        NSString *response = [[NSString alloc] initWithData:metaData encoding:NSUTF8StringEncoding];
        NSLog(@"Secondary Metadata Response: %@", response);
        if (verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: Secondary Metadata Response: %@", response] noTag:YES];
        NSString *description = nil, *showname = nil, *epnum = nil, *epname = nil, *temp_showname = nil;
        if (metaData != nil && [metaDataResponse statusCode] == 200) {
            [self addToLog:@"INFO: Secondary Metadata Response received" noTag:YES];
            epname = [show episodeName];
            NSScanner *metadataScanner = [NSScanner scannerWithString:response];
            [metadataScanner scanUpToString:@"<h2>" intoString:nil];
            [metadataScanner scanString:@"<h2>" intoString:nil];
            [metadataScanner scanUpToString:@"</h2>" intoString:&temp_showname];
            [metadataScanner scanUpToString:@"<p>" intoString:nil];
            [metadataScanner scanString:@"<p>" intoString:nil];
            [metadataScanner scanUpToString:@"</p>" intoString:&description];
        }
        else {
            [self addToLog:[NSString stringWithFormat:@"INFO: Secondary Metadata Request failed: %ld %@", [metaDataResponse statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[metaDataResponse statusCode]]] noTag:YES];
            if ([show episodeName] != @"(No Episode Name)")
                epname = [show episodeName];
            else {
                [dateFormat setDateFormat:@"dd/MM/yyyy"];
                epname = [dateFormat stringFromDate:[show dateAired]];
            }
            temp_showname = nil;
            description = nil;
        }
        if (!temp_showname)
            temp_showname = [show seriesName];
        showname = [NSString stringWithFormat:@"%@ - %@", temp_showname, epname];
        // add episode identifier if episode name contains only date
        [dateFormat setDateFormat:@"dd/MM/yyyy"];
        if ([dateFormat dateFromString:epname]) {
            if ([show episode] != 0)
                epnum = [NSString stringWithFormat:@"Episode %ld", [show episode]];
            else
                epnum = [NSString stringWithFormat:@"%@", [show realPID]];
            showname = [NSString stringWithFormat:@"%@ - %@", showname, epnum];
        }
        if (!description)
            description = @"(No Description)";
        [show setShowName:showname];
        [show setDesc:description];
        NSLog(@"Secondary Metadata Processed");
        if (verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: Secondary Metadata Processed: showname=%@ temp_showname=%@ epname=%@ epnum=%@ description=%@",
                            showname, temp_showname, epname, epnum, description] noTag:YES];
    }
    @catch (NSException *exception) {
        [self addToLog:@"Could not fix showName. Likely to encounter trouble with metadata."];
    }

    NSLog(@"Retrieving Playpath");
    if (verbose)
        [self addToLog:@"DEBUG: Retrieving Playpath" noTag:YES];
    
    //Retrieve PlayPath
    NSString *playPath = nil;
    NSArray *formatKeys = [NSArray arrayWithObjects:@"Flash - Very Low",@"Flash - Low",@"Flash - Standard",@"Flash - High",nil];
    NSArray *itvRateObjects = [NSArray arrayWithObjects:@"400",@"600",@"800",@"1200",nil];
    NSArray *bitrateObjects = [NSArray arrayWithObjects:@"400000",@"600000",@"800000",@"1200000",nil];
    NSDictionary *itvRateDic = [NSDictionary dictionaryWithObjects:itvRateObjects forKeys:formatKeys];
    NSDictionary *bitrateDic = [NSDictionary dictionaryWithObjects:bitrateObjects forKeys:formatKeys];
    
    NSMutableArray *itvRateArray = [[NSMutableArray alloc] init];
    NSMutableArray *bitrateArray = [[NSMutableArray alloc] init];
    
    for (TVFormat *format in formatList) [itvRateArray addObject:[itvRateDic objectForKey:[format format]]];
    for (TVFormat *format in formatList) [bitrateArray addObject:[bitrateDic objectForKey:[format format]]];
    
    if (verbose)
        [self addToLog:@"DEBUG: Parsing MediaFile entries" noTag:YES];
    NSMutableArray *mediaEntries = [[NSMutableArray alloc] init];
    while ([scanner scanUpToString:@"MediaFile delivery" intoString:nil]) {
        NSString *url = nil, *bitrate = nil, *itvRate = nil;
        ITVMediaFileEntry *entry = [[ITVMediaFileEntry alloc] init];
        [scanner scanUpToString:@"bitrate=" intoString:nil];
        [scanner scanString:@"bitrate=\"" intoString:nil];
        [scanner scanUpToString:@"\"" intoString:&bitrate];
        [scanner scanUpToString:@"CDATA" intoString:nil];
        [scanner scanString:@"CDATA[" intoString:nil];
        NSUInteger location = [scanner scanLocation];
        [scanner scanUpToString:@"]]" intoString:&url];
        [scanner setScanLocation:location];
        [scanner scanUpToString:@"_itv" intoString:nil];
        [scanner scanString:@"_itv" intoString:nil];
        [scanner scanUpToString:@"_" intoString:&itvRate];
        [entry setBitrate:bitrate];
        [entry setUrl:url];
        [entry setItvRate:itvRate];
        [mediaEntries addObject:entry];
        if (verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: ITVMediaFileEntry: bitrate=%@ itvRate=%@ url=%@", bitrate, itvRate, url] noTag:YES];
    }
    
    if (verbose)
        [self addToLog:@"DEBUG: Searching for itvRate match" noTag:YES];
    BOOL foundIt=FALSE;
    for (NSString *rate in itvRateArray) {
        for (ITVMediaFileEntry *entry in mediaEntries) {
            if ([[entry itvRate] isEqualToString:rate]) {
                foundIt=TRUE;
                playPath=[entry url];
                if (verbose)
                    [self addToLog:[NSString stringWithFormat:@"DEBUG: foundIt (itvRate): rate=%@ url=%@", rate, playPath] noTag:YES];
                break;
            }
        }
        if (foundIt) break;
    }
    if (verbose)
        [self addToLog:@"DEBUG: Searching for bitrate match" noTag:YES];
    if (!foundIt) for (NSString *rate in bitrateArray) {
        for (ITVMediaFileEntry *entry in mediaEntries) {
            if ([[entry bitrate] isEqualToString:rate]) {
                foundIt=TRUE;
                playPath=[entry url];
                if (verbose)
                    [self addToLog:[NSString stringWithFormat:@"DEBUG: foundIt (bitrate): rate=%@ url=%@", rate, playPath] noTag:YES];
                break;
            }
        }
        if (foundIt) break;
    }
    
    if (!foundIt) {
        [self addToLog:@"ERROR: Could not find suitable playpath." noTag:YES];
    }
    else {
        NSLog(@"%@",playPath);
        if (verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: playPath = %@", playPath] noTag:YES];
    }
    [self addToLog:@"INFO: Program data processed." noTag:YES];
    
    //Create Download Path
    downloadPath = [[NSUserDefaults standardUserDefaults] valueForKey:@"DownloadPath"];
    downloadPath = [downloadPath stringByAppendingPathComponent:[show seriesName]];
    [[NSFileManager defaultManager] createDirectoryAtPath:downloadPath withIntermediateDirectories:YES attributes:nil error:nil];
    downloadPath = [downloadPath stringByAppendingPathComponent:[[[NSString stringWithFormat:@"%@.partial.flv",[show showName]] stringByReplacingOccurrencesOfString:@"/" withString:@"-"] stringByReplacingOccurrencesOfString:@":" withString:@" -"]];
    NSArray *args;
    @try {
        if (foundIt) args = [NSMutableArray arrayWithObjects:
                                [NSString stringWithFormat:@"-r%@",authURL],
                                @"-Whttp://www.itv.com/mediaplayer/ITVMediaPlayer.swf?v=11.20.654",
                                [NSString stringWithFormat:@"-y%@",playPath],
                                [NSString stringWithFormat:@"-o%@",downloadPath],
                                nil];
        else [NSException raise:@"NoShow" format:@"Could not find show"];
        NSLog(@"%@",args);
        if (verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: rtmpdump args: %@", args] noTag:YES];
    }
    @catch (NSException *exception) {
        [show setComplete:[NSNumber numberWithBool:YES]];
        [show setSuccessful:[NSNumber numberWithBool:NO]];
        [show setValue:@"Download Failed" forKey:@"status"];
        [self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
        if ([[exception name] isEqualToString:@"NoShow"] && [mediaEntries count] > 0) {
            [self addToLog:@"REASON FOR FAILURE: None of the modes in your download format list are available for this show." noTag:YES];
            [self addToLog:@"Try adding more modes." noTag:YES];
            [show setReasonForFailure:@"Specified_Modes"];
        } else {
            [self addToLog:@"ERROR: Could not process ITV metadata." noTag:YES];
            [show setReasonForFailure:@"MetadataProcessing"];
        }
        [nc postNotificationName:@"DownloadFinished" object:show];
        return;
    }
    [self launchRTMPDumpWithArgs:args];
}
@end
