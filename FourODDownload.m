//
//  FourODDownload.m
//  Get_iPlayer GUI
//
//  Created by Thomas E. Willson on 7/29/12.
//
//

#import "FourODDownload.h"
#import "ASIHTTPRequest.h"
#import "NSHost+ThreadedAdditions.h"
#import "NSString+HTML.h"
#import <Python/Python.h>

@implementation FourODDownload
- (id)description
{
	return [NSString stringWithFormat:@"4oD Download (ID=%@)", [show pid]];
}
- (id)initWithProgramme:(Programme *)tempShow
{
    [super init];
    
    show = tempShow;
    attemptNumber=1;
    nc = [NSNotificationCenter defaultCenter];
    defaultsPrefix = @"4oD_";
    
    running=TRUE;
    
    [self setCurrentProgress:[NSString stringWithFormat:@"Retrieving Programme Metadata... -- %@",[show showName]]];
    [self setPercentage:102];
    [tempShow setValue:@"Initialising..." forKey:@"status"];
    
    [self addToLog:[NSString stringWithFormat:@"Downloading %@",[show showName]] noTag:NO];
    [self addToLog:@"INFO: Preparing Request for Auth Info" noTag:YES];
    
    [self launchMetaRequest];
    
    return self;
}

- (void)launchMetaRequest
{
    errorCache = [[NSMutableString alloc] initWithString:@""];
    processErrorCache = [NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(processError) userInfo:nil repeats:YES];

    NSScanner *scanner = [NSScanner scannerWithString:[show url]];
    [scanner scanUpToString:@"#" intoString:nil];
    [scanner scanString:@"#" intoString:nil];
    NSString *pid = nil;
    [scanner scanUpToString:@"lklk" intoString:&pid];

    if (!pid)
    {
        [self addToLog:[NSString stringWithFormat:@"ERROR: GiA cannot interpret the 4oD URL: %@", [show url]]];
        [show setReasonForFailure:@"MetadataProcessing"];
        [show setComplete:[NSNumber numberWithBool:YES]];
        [show setSuccessful:[NSNumber numberWithBool:NO]];
        [show setValue:@"Download Failed" forKey:@"status"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        return;
    }
    
    [show setRealPID:pid];
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.channel4.com/programmes/asset/%@",[show realPID]]];
    ASIHTTPRequest *dataRequest = [ASIHTTPRequest requestWithURL:requestURL];
    [dataRequest setDidFinishSelector:@selector(dataRequestFinished:)];
    [dataRequest setTimeOutSeconds:10];
    [dataRequest setNumberOfTimesToRetryOnTimeout:3];
    [dataRequest setDelegate:self];
    [dataRequest startAsynchronous];
}

-(void)dataRequestFinished:(ASIHTTPRequest *)request
{
    if (!running)
        return;
    NSLog(@"Response Status Code: %ld",(long)[request responseStatusCode]);
    if ([request responseStatusCode] == 200)
    {
        NSString *responseString = [[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding];
        BOOL verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose"];
        if (verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme Data Response: %@", responseString] noTag:YES];
        
        NSScanner *scanner = [NSScanner scannerWithString:responseString];
        
        NSString *episodeTitle = nil;
        [scanner scanUpToString:@"<episodeTitle>" intoString:nil];
        [scanner scanString:@"<episodeTitle>" intoString:nil];
        [scanner scanUpToString:@"</" intoString:&episodeTitle];
        episodeTitle = [episodeTitle stringByDecodingHTMLEntities];
        [show setEpisodeName:episodeTitle];

        NSString *seriesTitle = nil;
        [scanner scanUpToString:@"<brandTitle>" intoString:nil];
        [scanner scanString:@"<brandTitle>" intoString:nil];
        [scanner scanUpToString:@"</" intoString:&seriesTitle];
        seriesTitle = [seriesTitle stringByDecodingHTMLEntities];
        [show setSeriesName:seriesTitle];

        NSInteger episodeNumber = 0;
        [scanner scanUpToString:@"<episodeNumber>" intoString:nil];
        [scanner scanString:@"<episodeNumber>" intoString:nil];
        [scanner scanInteger:&episodeNumber];
        [show setEpisode:episodeNumber];
        
        NSInteger seriesNumber = 0;
        [scanner scanUpToString:@"<seriesNumber>" intoString:nil];
        [scanner scanString:@"<seriesNumber>" intoString:nil];
        [scanner scanInteger:&seriesNumber];
        [show setSeason:seriesNumber];

        NSString *imagePath = nil;
        [scanner scanUpToString:@"<imagePath>" intoString:nil];
        [scanner scanString:@"<imagePath>" intoString:nil];
        [scanner scanUpToString:@"</" intoString:&imagePath];
        if (imagePath)
            thumbnailURL = [NSString stringWithFormat:@"http://www.channel4.com%@",imagePath];
        
        NSString *episodeGuideUrl = nil;
        [scanner scanUpToString:@"<episodeGuideUrl>" intoString:nil];
        [scanner scanString:@"<episodeGuideUrl>" intoString:nil];
        [scanner scanUpToString:@"</" intoString:&episodeGuideUrl];

        if (!(episodeTitle && seriesTitle && episodeNumber && seriesNumber && imagePath && episodeGuideUrl))
            [self addToLog:[NSString stringWithFormat:@"INFO: Some programme data not found. Tagging will be incomplete."] noTag:YES];
        
        if (verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme Data Processed: episodeTitle=%@ seriesTitle=%@ episodeNumber=%ld seriesNumber=%ld imagePath=%@ episodeGuideUrl=%@", episodeTitle, seriesTitle, episodeNumber, seriesNumber, imagePath, episodeGuideUrl]];        
        
        if (episodeGuideUrl)
        {
            NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.channel4.com%@",episodeGuideUrl]];
            ASIHTTPRequest *descRequest = [ASIHTTPRequest requestWithURL:requestURL];
            [descRequest setDidFinishSelector:@selector(descRequestFinished:)];
            [descRequest setTimeOutSeconds:10];
            [descRequest setNumberOfTimesToRetryOnTimeout:3];
            [descRequest setDelegate:self];
            [descRequest startAsynchronous];
        }
        else
        {
            [self doHostLookup];
        }
    }
    else
    {
       [self addToLog:[NSString stringWithFormat:@"WARNING: Programme data request failed. Tagging will be incomplete."] noTag:YES];
       [self doHostLookup];
    }
}

-(void)descRequestFinished:(ASIHTTPRequest *)request
{
    if (!running)
        return;
    NSLog(@"Response Status Code: %ld",(long)[request responseStatusCode]);
    if ([request responseStatusCode] == 200)
    {
        NSString *responseString = [[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding];
        BOOL verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose"];
        if (verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: Description Data Response: %@", responseString] noTag:YES];

        NSScanner *scanner = [NSScanner scannerWithString:responseString];

        NSString *synopsis = nil;
        [scanner scanUpToString:@"<meta name=\"synopsis\" content=\"" intoString:nil];
        [scanner scanString:@"<meta name=\"synopsis\" content=\"" intoString:nil];
        [scanner scanUpToString:@"\"/>" intoString:&synopsis];
        synopsis = [synopsis stringByConvertingHTMLToPlainText];
        [show setDesc:synopsis];

        if (!synopsis)
            [self addToLog:[NSString stringWithFormat:@"INFO: Programme description not found. Tagging may be incomplete."] noTag:YES];
        
        if (verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme Data Processed: synopsis=%@", synopsis]];
    }
    else
    {
        [self addToLog:[NSString stringWithFormat:@"WARNING: Programme description request failed. Tagging will be incomplete."] noTag:YES];
    }
    [self doHostLookup];
}

-(void)doHostLookup
{
    BOOL skipLookup = [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"%@SkipDNSLookup", defaultsPrefix]];
    if (skipLookup)
        [self hostLookupFinished:nil];
    else
        [NSHost hostWithName:@"ais.channel4.com" inBackgroundForReceiver:self selector:@selector(hostLookupFinished:)];    
}

-(void)hostLookupFinished:(NSHost *)aHost
{
    if (!running)
        return;
    NSString *hostAddr = nil;
    if (aHost)
        hostAddr = [aHost address];
    if (!hostAddr)
        hostAddr = @"ais.channel4.com";
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/asset/%@",hostAddr,[show realPID]]];
    NSLog(@"Metadata URL: %@",requestURL);
    [self addToLog:[NSString stringWithFormat:@"INFO: Metadata URL: %@", requestURL] noTag:YES];

    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:requestURL];
    [request setDidFinishSelector:@selector(metaRequestFinished:)];
    [request setTimeOutSeconds:10];
    [request setNumberOfTimesToRetryOnTimeout:3];
    [request setDelegate:self];
    
    NSScanner *scanner = nil;
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
    if (!running)
        return;
    BOOL skipSearch = [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"%@SkipMP4Search", defaultsPrefix]];
    NSInteger searchRange = [[NSUserDefaults standardUserDefaults] integerForKey:[NSString stringWithFormat:@"%@MP4SearchRange", defaultsPrefix]];
    if (!searchRange)
        searchRange = 10;
    NSInteger realPID = [[show realPID] integerValue];
    NSInteger minPID = realPID - searchRange;
    NSInteger maxPID = realPID + searchRange;
    NSInteger currentPID = [request tag];
    NSString *mp4UriData = [[request userInfo] valueForKey:@"mp4UriData"];
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
    else if ([request responseStatusCode] != 200)
    {
        if (currentPID != 0)
        {
            if (currentPID < maxPID)
            {
                if (realPID - currentPID == 1)
                    ++currentPID;
                [self retryMetaRequest:request pid:++currentPID];
                return;
            }
            else
            {
                [self addToLog:@"GiA does not support downloading this show."];
                [self addToLog:@"    HTTP Dynamic Streaming Detected"];
                [show setReasonForFailure:@"4oDHTTP"];
                [show setComplete:[NSNumber numberWithBool:YES]];
                [show setSuccessful:[NSNumber numberWithBool:NO]];
                [show setValue:@"Download Failed" forKey:@"status"];
                [nc postNotificationName:@"DownloadFinished" object:show];
                return;
            }
        }
        else
        {
            [self addToLog:@"ERROR: Could not retrieve program metadata." noTag:YES];
            [show setSuccessful:[NSNumber numberWithBool:NO]];
            [show setComplete:[NSNumber numberWithBool:YES]];
            [show setValue:@"Download Failed" forKey:@"status"];
            [nc postNotificationName:@"DownloadFinished" object:show];
            [self addToLog:@"Download Failed" noTag:NO];
            return;
        }
    }
    

    NSString *responseString = [[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding];
    
    NSLog(@"%@",responseString);
    
    BOOL verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose"];
    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata Response: %@", responseString] noTag:YES];
    
    NSScanner *scanner = [NSScanner scannerWithString:responseString];
    
    NSString *programmeNumber = nil;
    [scanner scanUpToString:@"<programmeNumber>" intoString:nil];
    [scanner scanString:@"<programmeNumber>" intoString:nil];
    [scanner scanUpToString:@"</programmeNumber>" intoString:&programmeNumber];
    
    NSString *brandTitle = nil;
    [scanner scanUpToString:@"<brandTitle>" intoString:nil];
    [scanner scanString:@"<brandTitle>" intoString:nil];
    [scanner scanUpToString:@"</brandTitle>" intoString:&brandTitle];

    NSString *uriData = nil;
    [scanner scanUpToString:@"<uriData>" intoString:nil];
    [scanner scanString:@"<uriData>" intoString:nil];
    [scanner scanUpToString:@"</uriData>" intoString:&uriData];
    
    scanner = [NSScanner scannerWithString:uriData];
    [scanner scanUpToString:@"<streamUri>" intoString:nil];
    [scanner scanString:@"<streamUri>" intoString:nil];
    NSString *streamUri = nil;
    [scanner scanUpToString:@"</" intoString:&streamUri];

    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata Processed: programmeNumber=%@ brandTitle=%@ uriData=%@ streamUri=%@", programmeNumber, brandTitle, uriData, streamUri]];

    if ([streamUri hasSuffix:@".f4m"])
    {
        if (skipSearch)
        {
            [self addToLog:@"GiA does not support downloading this show."];
            [self addToLog:@"    HTTP Dynamic Streaming Detected"];
            [show setReasonForFailure:@"4oDHTTP"];
            [show setComplete:[NSNumber numberWithBool:YES]];
            [show setSuccessful:[NSNumber numberWithBool:NO]];
            [show setValue:@"Download Failed" forKey:@"status"];
            [nc postNotificationName:@"DownloadFinished" object:show];
            return;
        }
        if (currentPID == 0)
        {
            [self retryMetaRequest:request pid:minPID brandTitle:brandTitle programmeNumber:programmeNumber];
            return;
        }
        else if (currentPID < maxPID)
        {
            if (realPID - currentPID == 1)
                ++currentPID;
            [self retryMetaRequest:request pid:++currentPID];
            return;
        }
    }
    else if ([streamUri hasSuffix:@".mp4"])
    {
        if (currentPID != 0)
        {
            if ([brandTitle isEqualToString:[[request userInfo] valueForKey:@"brandTitle"]] && [programmeNumber isEqualToString:[[request userInfo] valueForKey:@"programmeNumber"]])
            {
                [self addToLog:[NSString stringWithFormat:@"INFO: MP4 Stream Found: %@", streamUri] noTag:YES];
                mp4UriData = uriData;
                if ([streamUri rangeOfString:@"PS3" options:NSCaseInsensitiveSearch].location == NSNotFound)
                {
                    if (currentPID < maxPID)
                    {
                        if (realPID - currentPID == 1)
                            ++currentPID;
                        [self retryMetaRequest:request pid:++currentPID brandTitle:brandTitle programmeNumber:programmeNumber mp4UriData:mp4UriData];
                        return;
                    }
                }
            }
            else if (currentPID < maxPID)
            {
                if (realPID - currentPID == 1)
                    ++currentPID;
                [self retryMetaRequest:request pid:++currentPID];
                return;
            }
        }
        else
        {
            mp4UriData = uriData;
        }
    }
    else if (currentPID != 0)
    {
        if (currentPID < maxPID)
        {
            if (realPID - currentPID == 1)
                currentPID++;
            [self retryMetaRequest:request pid:++currentPID];
            return;
        }
    }
    
    if (!mp4UriData)
    {
        [self addToLog:@"GiA does not support downloading this show."];
        if (currentPID != 0)
        {
            [self addToLog:@"    HTTP Dynamic Streaming Detected"];
            [show setReasonForFailure:@"4oDHTTP"];
        }
        else
        {
            [self addToLog:@"    Did not find suitable download format"];
            [show setReasonForFailure:@"4oDFormat"];
        }
        [show setComplete:[NSNumber numberWithBool:YES]];
        [show setSuccessful:[NSNumber numberWithBool:NO]];
        [show setValue:@"Download Failed" forKey:@"status"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        return;
    }
    
    uriData = mp4UriData;
    scanner = [NSScanner scannerWithString:uriData];
    [scanner scanUpToString:@"<streamUri>" intoString:nil];
    [scanner scanString:@"<streamUri>" intoString:nil];
    streamUri = nil;
    [scanner scanUpToString:@"</" intoString:&streamUri];
    [scanner scanUpToString:@"<token>" intoString:nil];
    [scanner scanString:@"<token>" intoString:nil];
    NSString *token = nil;
    [scanner scanUpToString:@"</" intoString:&token];
    [scanner scanUpToString:@"<cdn>" intoString:nil];
    [scanner scanString:@"<cdn>" intoString:nil];
    NSString *cdn = nil;
    [scanner scanUpToString:@"</" intoString:&cdn];
    
    NSString *decodedToken = [self decodeToken:token];
    NSLog(@"%@",decodedToken);
    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata Processed: uriData=%@ streamUri=%@ token=%@ cdn=%@ decodedToken=%@", uriData, streamUri, token, cdn, decodedToken]];
    
    NSString *auth = nil, *rtmpURL = nil, *app = nil, *playpath = nil;
    @try
    {
        if (!(uriData && streamUri && token && cdn && decodedToken))
            [NSException raise:@"Parsing Error." format:@"Could not process 4oD Metadata"];

        if ([cdn isEqualToString:@"ll"])
        {
            [scanner setScanLocation:0];
            if ([uriData rangeOfString:@"<e>"].location != NSNotFound)
            {
                NSString *e = nil;
                [scanner scanUpToString:@"<e>" intoString:nil];
                [scanner scanString:@"<e>" intoString:nil];
                [scanner scanUpToString:@"</e>" intoString:&e];
                if (verbose)
                    [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata Processed: e=%@", e]];
                if (e)
                    auth = [NSString stringWithFormat:@"e=%@&h=%@",e,decodedToken];
                else
                    [NSException raise:@"Parsing Error." format:@"Could not process 4oD Metadata"];
                rtmpURL = [[streamUri componentsSeparatedByString:@"mp4:"] objectAtIndex:0];
                if ([rtmpURL hasPrefix:@"http"])
                    [NSException raise:@"4oD: Unsupported HTTP Download." format:@"GiA does not support this programme."];
                rtmpURL = [rtmpURL stringByReplacingOccurrencesOfString:@".com/" withString:@".com:1935/"];
                scanner = [NSScanner scannerWithString:streamUri];
                [scanner scanUpToString:@".com/" intoString:nil];
                [scanner scanString:@".com/" intoString:nil];
                [scanner scanUpToString:@"mp4:" intoString:&app];
                playpath = [streamUri substringFromIndex:[scanner scanLocation]];
                playpath = [playpath stringByAppendingFormat:@"?%@", auth];
            }
            else if ([uriData rangeOfString:@"<et>"].location != NSNotFound)
            {
                NSString *av = nil, *te = nil, *st = nil, *et = nil, *mp = nil;
                [scanner scanUpToString:@"<av>" intoString:nil];
                [scanner scanString:@"<av>" intoString:nil];
                [scanner scanUpToString:@"</av>" intoString:&av];
                [scanner scanUpToString:@"<te>" intoString:nil];
                [scanner scanString:@"<te>" intoString:nil];
                [scanner scanUpToString:@"</te>" intoString:&te];
                [scanner scanUpToString:@"<st>" intoString:nil];
                [scanner scanString:@"<st>" intoString:nil];
                [scanner scanUpToString:@"</st>" intoString:&st];
                [scanner scanUpToString:@"<et>" intoString:nil];
                [scanner scanString:@"<et>" intoString:nil];
                [scanner scanUpToString:@"</et>" intoString:&et];
                mp = [[streamUri componentsSeparatedByString:@"mp4:"] objectAtIndex:1];
                if (verbose)
                    [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata Processed: av=%@ te=%@ st=%@ et=%@ mp=%@", av, te, st, et, mp]];
                if (av && te && st && et && mp)
                    auth = [NSString stringWithFormat:@"as=adobe-hmac-sha256&av=%@&te=%@&st=%@&et=%@&mp=%@&fmta-token=%@",av,te,st,et,mp,decodedToken];
                else
                    [NSException raise:@"Parsing Error." format:@"Could not process 4oD Metadata"];
                rtmpURL = [[streamUri componentsSeparatedByString:@"mp4:"] objectAtIndex:0];
                if ([rtmpURL hasPrefix:@"http"])
                    [NSException raise:@"4oD: Unsupported HTTP Download." format:@"GiA does not support this programme."];
                rtmpURL = [rtmpURL stringByReplacingOccurrencesOfString:@".com/" withString:@".com:1935/"];
                rtmpURL = [rtmpURL stringByAppendingFormat:@"?%@",auth];
                scanner = [NSScanner scannerWithString:streamUri];
                [scanner scanUpToString:@".com/" intoString:nil];
                [scanner scanString:@".com/" intoString:nil];
                [scanner scanUpToString:@"mp4:" intoString:&app];
                app = [app stringByAppendingFormat:@"?%@", auth];
                playpath = [streamUri substringFromIndex:[scanner scanLocation]];
            }
            else
            {
                [NSException raise:@"Parsing Error." format:@"Could not process 4oD Metadata"];
            }
        }
        else if ([cdn isEqualToString:@"ak"])
        {
            [scanner setScanLocation:0];
            NSString *fingerprint = nil, *slist = nil;
            [scanner scanUpToString:@"<fingerprint>" intoString:nil];
            [scanner scanString:@"<fingerprint>" intoString:nil];
            [scanner scanUpToString:@"</fingerprint>" intoString:&fingerprint];
            [scanner setScanLocation:0];
            [scanner scanUpToString:@"<slist>" intoString:nil];
            [scanner scanString:@"<slist>" intoString:nil];
            [scanner scanUpToString:@"</slist>" intoString:&slist];
            if (verbose)
                [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata Processed: fingerprint=%@ slist=%@", fingerprint, slist]];
            if (fingerprint && slist)
                auth = [NSString stringWithFormat:@"auth=%@&aifp=%@&slist=%@",decodedToken,fingerprint,slist];
            else
                [NSException raise:@"Parsing Error." format:@"Could not process 4oD Metadata"];
            rtmpURL = [[streamUri componentsSeparatedByString:@"mp4:"] objectAtIndex:0];
            if ([rtmpURL hasPrefix:@"http"])
                [NSException raise:@"4oD: Unsupported HTTP Download." format:@"GiA does not support this programme."];
            rtmpURL = [rtmpURL stringByReplacingOccurrencesOfString:@".com/" withString:@".com:1935/"];
            rtmpURL = [rtmpURL stringByAppendingFormat:@"?%@",auth];
            scanner = [NSScanner scannerWithString:streamUri];
            [scanner scanUpToString:@".com/" intoString:nil];
            [scanner scanString:@".com/" intoString:nil];
            [scanner scanUpToString:@"mp4:" intoString:&app];
            app = [app stringByAppendingFormat:@"?%@", auth];
            playpath = [streamUri substringFromIndex:[scanner scanLocation]];
        }
        else
        {
            [NSException raise:@"Parsing Error." format:@"Could not process 4oD Metadata"];
        }
    }
    @catch (NSException *exception)
    {
        [self addToLog:[exception name]];
        [self addToLog:[exception description]];
        [show setComplete:[NSNumber numberWithBool:YES]];
        [show setSuccessful:[NSNumber numberWithBool:NO]];
        [show setValue:@"Download Failed" forKey:@"status"];
        if ([[exception name] isEqualToString:@"4oD: Unsupported HTTP Download."])
            [show setReasonForFailure:@"4oDHTTP"];
        else
            [show setReasonForFailure:@"MetadataProcessing"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        return;
    }
    
    
    NSString *swfplayer = [[NSUserDefaults standardUserDefaults] valueForKey:[NSString stringWithFormat:@"%@SWFURL", defaultsPrefix]];
    if (!swfplayer) {
        swfplayer = @"http://www.channel4.com/static/programmes/asset/flash/swf/4odplayer-11.34.1.swf";
    }

    [self createDownloadPath];
    
    NSArray *args = [NSArray arrayWithObjects:@"--rtmp",rtmpURL,
                     @"--app",app,
                     @"--flashVer",@"\"WIN 11,5,502,110\"",
                     @"--swfVfy",swfplayer,
                     @"--pageUrl",[show url],
                     @"--playpath",playpath,
                     @"--flv",downloadPath,
                     @"--conn",@"O:1",
                     @"--conn",@"O:0",
                     nil];
    [self launchRTMPDumpWithArgs:args];
    
}

-(void)retryMetaRequest:(ASIHTTPRequest *)request pid:(NSInteger)pid pidInfo:(NSDictionary *)pidInfo
{
    NSURL *retryURL = [[[request url] URLByDeletingLastPathComponent] URLByAppendingPathComponent:[NSString stringWithFormat:@"%ld", pid]];
    [self addToLog:[NSString stringWithFormat:@"INFO: Retry Metadata URL: %@", retryURL] noTag:YES];
    ASIHTTPRequest *retryRequest = [[request copy] autorelease];
    [retryRequest setURL:retryURL];
    [retryRequest setTag:pid];
    if (pidInfo)
        [retryRequest setUserInfo:pidInfo];
    [retryRequest startAsynchronous];
}

-(void)retryMetaRequest:(ASIHTTPRequest *)request pid:(NSInteger)pid
{
    [self retryMetaRequest:request pid:pid pidInfo:nil];
}

-(void)retryMetaRequest:(ASIHTTPRequest *)request pid:(NSInteger)pid brandTitle:(NSString *)brandTitle programmeNumber:(NSString *)programmeNumber
{
    NSDictionary *pidInfo = [NSDictionary dictionaryWithObjectsAndKeys: brandTitle, @"brandTitle", programmeNumber, @"programmeNumber", nil];
    [self retryMetaRequest:request pid:pid pidInfo:pidInfo];
}

-(void)retryMetaRequest:(ASIHTTPRequest *)request pid:(NSInteger)pid brandTitle:(NSString *)brandTitle programmeNumber:(NSString *)programmeNumber mp4UriData:(NSString *)mp4UriData
{
    NSDictionary *pidInfo = [NSDictionary dictionaryWithObjectsAndKeys: brandTitle, @"brandTitle", programmeNumber, @"programmeNumber", mp4UriData, @"mp4UriData", nil];
    [self retryMetaRequest:request pid:pid pidInfo:pidInfo];
}

- (NSString *)decodeToken:(NSString *)string
{
    PyObject *pName, *pModule, *pFunc;
    PyObject *pArgs, *pValue;
    NSString *result;
    
    
    Py_Initialize();
    pName = PyString_FromString([[[[NSBundle mainBundle] pathForResource:@"fourOD_token_decoder" ofType:@"py"] stringByDeletingLastPathComponent] cStringUsingEncoding:NSUTF8StringEncoding]);
    PySys_SetPath([[[[NSBundle mainBundle] pathForResource:@"fourOD_token_decoder" ofType:@"py"] stringByDeletingLastPathComponent] cStringUsingEncoding:NSUTF8StringEncoding]);
    /* Error checking of pName left out */
    
    pModule = PyImport_Import(PyString_FromString("fourOD_token_decoder"));
    Py_DECREF(pName);
    
    if (pModule != NULL) {
        pFunc = PyObject_GetAttrString(pModule, "Decode4odToken");
        /* pFunc is a new reference */
        
        if (pFunc && PyCallable_Check(pFunc)) {
            pArgs = PyTuple_New(1);
            PyTuple_SetItem(pArgs, 0, PyString_FromString([string cStringUsingEncoding:NSUTF8StringEncoding]));
            pValue = PyObject_CallObject(pFunc, pArgs);
            Py_DECREF(pArgs);
            if (pValue != NULL) {
                result = [NSString stringWithCString:PyString_AsString(pValue) encoding:NSUTF8StringEncoding];
                Py_DECREF(pValue);
            }
            else {
                Py_DECREF(pFunc);
                Py_DECREF(pModule);
                PyErr_Print();
                NSLog(@"Call failed\n");
                return nil;
            }
        }
        else {
            if (PyErr_Occurred())
                PyErr_Print();
            NSLog(@"Cannot find function \"%@\"\n", @"Decode4odToken");
        }
        Py_XDECREF(pFunc);
        Py_DECREF(pModule);
    }
    else {
        PyErr_Print();
        NSLog(@"Failed to load \"%@\"\n", @"Token Decoder File");
        return nil;
    }
    Py_Finalize();
    return result;
    
}
@end
