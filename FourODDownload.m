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
- (id)initWithProgramme:(Programme *)tempShow proxy:(HTTPProxy *)aProxy
{
    if (!(self = [super init])) return nil;
    
    proxy = aProxy;
    show = tempShow;
    attemptNumber=1;
    nc = [NSNotificationCenter defaultCenter];
    defaultsPrefix = @"4oD_";
    
    running=TRUE;
    
    [self setCurrentProgress:[NSString stringWithFormat:@"Retrieving Programme Metadata... -- %@",[show showName]]];
    [self setPercentage:102];
    [tempShow setValue:@"Initialising..." forKey:@"status"];
    
    [self addToLog:[NSString stringWithFormat:@"Downloading %@",[show showName]]];
    [self addToLog:@"INFO: Preparing Request for Auth Info" noTag:YES];

    resolveHostNamesForProxy = [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"%@ResolveHostNamesForProxy", defaultsPrefix]];
    
    skipMP4Search = [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"%@SkipMP4Search", defaultsPrefix]];
    mp4SearchRange = [[NSUserDefaults standardUserDefaults] integerForKey:[NSString stringWithFormat:@"%@MP4SearchRange", defaultsPrefix]];
    if (!mp4SearchRange)
        mp4SearchRange = 10;
    
    [self launchMetaRequest];
    return self;
}

- (void)launchMetaRequest
{
    errorCache = [[NSMutableString alloc] initWithString:@""];
    processErrorCache = [NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(processError) userInfo:nil repeats:YES];

    if ([[show url] hasPrefix:@"http://ps3.channel4.com"]) {
        [show setRealPID:[show pid]];
    }
    else {
        NSScanner *scanner = [NSScanner scannerWithString:[show url]];
        [scanner scanUpToString:@"#" intoString:nil];
        [scanner scanString:@"#" intoString:nil];
        NSString *pid = nil;
        [scanner scanUpToString:@"lklk" intoString:&pid];
        if (!pid)
        {
            NSLog(@"ERROR: GiA cannot interpret the 4oD URL: %@", [show url]);
            [self addToLog:[NSString stringWithFormat:@"ERROR: GiA cannot interpret the 4oD URL: %@", [show url]] noTag:YES];
            [show setReasonForFailure:@"MetadataProcessing"];
            [show setComplete:@YES];
            [show setSuccessful:@NO];
            [show setValue:@"Download Failed" forKey:@"status"];
            [nc postNotificationName:@"DownloadFinished" object:show];
            return;
        }
        [show setRealPID:pid];
    }
    [self doMetaHostLookup];
}

-(void)doMetaHostLookup
{
    if (resolveHostNamesForProxy)
        [NSHost hostWithName:@"ais.channel4.com" inBackgroundForReceiver:self selector:@selector(metaHostLookupFinished:)];
    else
        [self metaHostLookupFinished:nil];
}

-(void)metaHostLookupFinished:(NSHost *)aHost
{
    if (!running)
        return;
    NSString *hostAddr = nil;
    if (aHost)
        hostAddr = [aHost address];
    if (!hostAddr)
        hostAddr = @"ais.channel4.com";
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/asset/%@",hostAddr,[show realPID]]];
    NSLog(@"DEBUG: Metadata URL: %@",requestURL);
    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata URL: %@", requestURL] noTag:YES];

    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:requestURL];
    [request setDelegate:self];
    [request setDidFailSelector:@selector(metaRequestFinished:)];
    [request setDidFinishSelector:@selector(metaRequestFinished:)];
    [request setTimeOutSeconds:10];
    [request setNumberOfTimesToRetryOnTimeout:3];
    [request addRequestHeader:@"Accept" value:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"];
    if (proxy)
    {
        [request setProxyType:proxy.type];
        [request setProxyHost:proxy.host];
        if (proxy.port)
            [request setProxyPort:proxy.port];
    }
    NSLog(@"INFO: Requesting Metadata.");
    [self addToLog:@"INFO: Requesting Metadata." noTag:YES];
    [request startAsynchronous];
}

-(void)metaRequestFinished:(ASIHTTPRequest *)request
{
    if (!running)
        return;
    NSInteger realPID = [[show realPID] integerValue];
    NSInteger minPID = realPID - mp4SearchRange;
    NSInteger maxPID = realPID + mp4SearchRange;
    NSInteger currentPID = [request tag];
    NSLog(@"DEBUG: Metadata response status code: %d", [request responseStatusCode]);
    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata response status code: %d", [request responseStatusCode]] noTag:YES];
    NSString *responseString = [[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding];
    NSLog(@"DEBUG: Metadata response: %@",responseString);
    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata response: %@", responseString] noTag:YES];
    NSError *error = [request error];
    if ([request responseStatusCode] == 0)
    {
        NSLog(@"ERROR: No response received (probably a proxy issue): %@", (error ? [error localizedDescription] : @"Unknown error"));
        [self addToLog:[NSString stringWithFormat:@"ERROR: No response received (probably a proxy issue): %@", (error ? [error localizedDescription] : @"Unknown error")]];
        [show setSuccessful:@NO];
        [show setComplete:@YES];
        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"] isEqualTo:@"Provided"])
            [show setReasonForFailure:@"Provided_Proxy"];
        else if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"] isEqualTo:@"Custom"])
            [show setReasonForFailure:@"Custom_Proxy"];
        else
            [show setReasonForFailure:@"Internet_Connection"];
        [show setValue:@"Failed: Bad Proxy" forKey:@"status"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        [self addToLog:@"Download Failed"];
        return;
    }
    else if ([responseString length] > 0 && [responseString rangeOfString:@"territoriesExcluded" options:NSCaseInsensitiveSearch].location != NSNotFound)
    {
        NSLog(@"ERROR: Access denied to users outside UK.");
        [self addToLog:@"ERROR: Access denied to users outside UK."];
        [show setSuccessful:@NO];
        [show setComplete:@YES];
        [show setReasonForFailure:@"Outside_UK"];
        [show setValue:@"Failed: Outside UK" forKey:@"status"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        [self addToLog:@"Download Failed" noTag:NO];
        return;
    }
    else if ([request responseStatusCode] != 200 || [responseString length] == 0)
    {
        if (skipMP4Search)
        {
            NSLog(@"ERROR: Could not retrieve programme metadata: %@", (error ? [error localizedDescription] : @"Unknown error"));
            [self addToLog:[NSString stringWithFormat:@"ERROR: Could not retrieve programme metadata: %@", (error ? [error localizedDescription] : @"Unknown error")]];
            [show setSuccessful:@NO];
            [show setComplete:@YES];
            [show setValue:@"Download Failed" forKey:@"status"];
            [nc postNotificationName:@"DownloadFinished" object:show];
            [self addToLog:@"Download Failed" noTag:NO];
            return;
            
        }
        else if (currentPID != 0)
        {
            if (currentPID < maxPID)
            {
                if (realPID - currentPID == 1)
                    ++currentPID;
                [self retryMetaRequest:request pid:++currentPID];
                return;
            }
        }
    }
    
    NSScanner *scanner = [NSScanner scannerWithString:[responseString stringByDecodingHTMLEntities]];
    
    NSUInteger scanloc = [scanner scanLocation];
    NSString *programmeNumber = nil;
    [scanner scanUpToString:@"<programmeNumber>" intoString:nil];
    [scanner scanString:@"<programmeNumber>" intoString:nil];
    [scanner scanUpToString:@"</programmeNumber>" intoString:&programmeNumber];
    if (programmeNumber)
        [show setEpisode:[programmeNumber integerValue]];
    else
        [scanner setScanLocation:scanloc];
    
    scanloc = [scanner scanLocation];
    NSString *brandTitle = nil;
    [scanner scanUpToString:@"<brandTitle>" intoString:nil];
    [scanner scanString:@"<brandTitle>" intoString:nil];
    [scanner scanUpToString:@"</brandTitle>" intoString:&brandTitle];
    if (brandTitle)
        [show setSeriesName:brandTitle];
    else
        [scanner setScanLocation:scanloc];

    scanloc = [scanner scanLocation];
    NSString *episodeTitle = nil;
    [scanner scanUpToString:@"<brandTitle>" intoString:nil];
    [scanner scanString:@"<brandTitle>" intoString:nil];
    [scanner scanUpToString:@"</brandTitle>" intoString:&episodeTitle];
    if (episodeTitle)
        [show setEpisodeName:episodeTitle];
    else
        [scanner setScanLocation:scanloc];

    NSString *uriData = nil;
    [scanner scanUpToString:@"<uriData>" intoString:nil];
    [scanner scanString:@"<uriData>" intoString:nil];
    [scanner scanUpToString:@"</uriData>" intoString:&uriData];
    
    scanner = [NSScanner scannerWithString:uriData];
    [scanner scanUpToString:@"<streamUri>" intoString:nil];
    [scanner scanString:@"<streamUri>" intoString:nil];
    NSString *streamUri = nil;
    [scanner scanUpToString:@"</" intoString:&streamUri];

    NSLog(@"DEBUG: Metadata processed: programmeNumber=%@ brandTitle=%@ episodeTitle=%@ uriData=%@ streamUri=%@", programmeNumber, brandTitle, episodeTitle, uriData, streamUri);
    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata processed: programmeNumber=%@ brandTitle=%@ episodeTitle=%@ uriData=%@ streamUri=%@", programmeNumber, brandTitle, episodeTitle, uriData, streamUri] noTag:YES];

    if ([streamUri hasSuffix:@".f4m"])
    {
        if (skipMP4Search)
        {
            NSLog(@"GiA does not support downloading this show. HTTP Dynamic Streaming Detected.");
            [self addToLog:@"GiA does not support downloading this show. HTTP Dynamic Streaming Detected."];
            [show setReasonForFailure:@"4oDHTTP"];
            [show setComplete:@YES];
            [show setSuccessful:@NO];
            [show setValue:@"Download Failed" forKey:@"status"];
            [nc postNotificationName:@"DownloadFinished" object:show];
            return;
        }
        if (currentPID == 0)
        {
            downloadParams[@"brandTitle"] = brandTitle;
            downloadParams[@"programmeNumber"] = programmeNumber;
            [self retryMetaRequest:request pid:minPID];
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
            if ([brandTitle isEqualToString:downloadParams[@"brandTitle"]] && [programmeNumber isEqualToString:downloadParams[@"programmeNumber"]])
            {
                NSLog(@"DEBUG: MP4 Stream Found: %@", streamUri);
                if (verbose)
                    [self addToLog:[NSString stringWithFormat:@"DEBUG: MP4 Stream Found: %@", streamUri] noTag:YES];
                downloadParams[@"mp4UriData"] = uriData;
                if ([streamUri rangeOfString:@"PS3" options:NSCaseInsensitiveSearch].location == NSNotFound)
                {
                    if (currentPID < maxPID)
                    {
                        if (realPID - currentPID == 1)
                            ++currentPID;
                        [self retryMetaRequest:request pid:++currentPID];
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
            downloadParams[@"mp4UriData"] = uriData;
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
    
    if (!downloadParams[@"mp4UriData"])
    {
        if (currentPID != 0)
        {
            NSLog(@"ERROR: GiA does not support downloading this show. HTTP Dynamic Streaming Detected.");
            [self addToLog:@"ERROR: GiA does not support downloading this show. HTTP Dynamic Streaming Detected."];
            [show setReasonForFailure:@"4oDHTTP"];
        }
        else
        {
            NSLog(@"ERROR: GiA does not support downloading this show. Did not find suitable download format.");
            [self addToLog:@"ERROR: GiA does not support downloading this show. Did not find suitable download format."];
            [show setReasonForFailure:@"4oDFormat"];
        }
        [show setComplete:@YES];
        [show setSuccessful:@NO];
        [show setValue:@"Download Failed" forKey:@"status"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        return;
    }
    
    uriData = downloadParams[@"mp4UriData"];
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
    NSLog(@"DEBUG: Metadata processed: uriData=%@ streamUri=%@ token=%@ cdn=%@ decodedToken=%@", uriData, streamUri, token, cdn, decodedToken);
    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata processed: uriData=%@ streamUri=%@ token=%@ cdn=%@ decodedToken=%@", uriData, streamUri, token, cdn, decodedToken] noTag:YES];
    
    NSString *auth = nil, *rtmpURL = nil, *app = nil, *playpath = nil;
    @try
    {
        if (!(uriData && streamUri && token && cdn))
            [NSException raise:@"Parsing Error" format:@"Could not process 4oD Metadata"];
        if (!decodedToken)
            [NSException raise:@"Decoding Error" format:@"Could not decode 4oD token"];

        if ([cdn isEqualToString:@"ll"])
        {
            [scanner setScanLocation:0];
            if ([uriData rangeOfString:@"<e>"].location != NSNotFound)
            {
                NSString *e = nil;
                [scanner scanUpToString:@"<e>" intoString:nil];
                [scanner scanString:@"<e>" intoString:nil];
                [scanner scanUpToString:@"</e>" intoString:&e];
                NSLog(@"DEBUG: Metadata Processed: e=%@", e);
                if (verbose)
                    [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata Processed: e=%@", e] noTag:YES];
                if (e)
                    auth = [NSString stringWithFormat:@"e=%@&h=%@",e,decodedToken];
                else
                    [NSException raise:@"Parsing Error" format:@"Could not process 4oD Metadata"];
                rtmpURL = [streamUri componentsSeparatedByString:@"mp4:"][0];
                if ([rtmpURL hasPrefix:@"http"])
                    [NSException raise:@"4oD: Unsupported HTTP Download" format:@"GiA does not support this programme."];
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
                mp = [streamUri componentsSeparatedByString:@"mp4:"][1];
                NSLog(@"DEBUG: Metadata Processed: av=%@ te=%@ st=%@ et=%@ mp=%@", av, te, st, et, mp);
                if (verbose)
                    [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata Processed: av=%@ te=%@ st=%@ et=%@ mp=%@", av, te, st, et, mp] noTag:YES];
                if (av && te && st && et && mp)
                    auth = [NSString stringWithFormat:@"as=adobe-hmac-sha256&av=%@&te=%@&st=%@&et=%@&mp=%@&fmta-token=%@", av, te, st, et, mp, decodedToken];
                else
                    [NSException raise:@"Parsing Error" format:@"Could not process 4oD Metadata"];
                rtmpURL = [streamUri componentsSeparatedByString:@"mp4:"][0];
                if ([rtmpURL hasPrefix:@"http"])
                    [NSException raise:@"4oD: Unsupported HTTP Download" format:@"GiA does not support this programme."];
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
                [NSException raise:@"Parsing Error" format:@"Could not process 4oD Metadata"];
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
            NSLog(@"DEBUG: Metadata Processed: fingerprint=%@ slist=%@", fingerprint, slist);
            if (verbose)
                [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata Processed: fingerprint=%@ slist=%@", fingerprint, slist] noTag:YES];
            if (fingerprint && slist)
                auth = [NSString stringWithFormat:@"auth=%@&aifp=%@&slist=%@",decodedToken,fingerprint,slist];
            else
                [NSException raise:@"Parsing Error" format:@"Could not process 4oD Metadata"];
            rtmpURL = [streamUri componentsSeparatedByString:@"mp4:"][0];
            if ([rtmpURL hasPrefix:@"http"])
                [NSException raise:@"4oD: Unsupported HTTP Download" format:@"GiA does not support this programme."];
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
            [NSException raise:@"Parsing Error" format:@"Could not process 4oD Metadata"];
        }
    }
    @catch (NSException *exception)
    {
        NSLog(@"ERROR: %@: %@", [exception name], [exception description]);
        [self addToLog:[NSString stringWithFormat:@"ERROR: %@: %@", [exception name], [exception description]]];
        [show setComplete:@YES];
        [show setSuccessful:@NO];
        [show setValue:@"Download Failed" forKey:@"status"];
        if ([[exception name] isEqualToString:@"4oD: Unsupported HTTP Download"])
            [show setReasonForFailure:@"4oDHTTP"];
        else if ([[exception name] isEqualToString:@"Decoding Error"])
            [show setReasonForFailure:@"4oDUnavailable"];
        else
            [show setReasonForFailure:@"MetadataProcessing"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        return;
    }
    
    downloadParams[@"rtmpURL"] = rtmpURL;
    downloadParams[@"app"] = app;
    downloadParams[@"playpath"] = playpath;
    
    NSLog(@"INFO: Metadata processed.");
    [self addToLog:@"INFO: Metadata processed." noTag:YES];
    
    NSURL *dataURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.channel4.com/programmes/asset/%@",[show realPID]]];
    NSLog(@"DEBUG: Programme data URL: %@",dataURL);
    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme data URL: %@", dataURL] noTag:YES];
    ASIHTTPRequest *dataRequest = [ASIHTTPRequest requestWithURL:dataURL];
    [dataRequest setDidFailSelector:@selector(dataRequestFinished:)];
    [dataRequest setDidFinishSelector:@selector(dataRequestFinished:)];
    [dataRequest setTimeOutSeconds:10];
    [dataRequest setNumberOfTimesToRetryOnTimeout:3];
    [dataRequest setDelegate:self];
    [dataRequest addRequestHeader:@"Accept" value:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"];
    NSLog(@"INFO: Requesting programme data.");
    [self addToLog:@"INFO: Requesting programme data." noTag:YES];
    [dataRequest startAsynchronous];
  
}

-(void)retryMetaRequest:(ASIHTTPRequest *)request pid:(NSInteger)pid
{
    NSURL *retryURL = [[[request url] URLByDeletingLastPathComponent] URLByAppendingPathComponent:[NSString stringWithFormat:@"%ld", pid]];
    NSLog(@"DEBUG: Retry metadata URL: %@", retryURL);
    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Retry metadata URL: %@", retryURL] noTag:YES];
    ASIHTTPRequest *retryRequest = [ASIHTTPRequest requestWithURL:retryURL];
    [retryRequest setTag:pid];
    [retryRequest setDelegate:self];
    [retryRequest setDidFailSelector:@selector(metaRequestFinished:)];
    [retryRequest setDidFinishSelector:@selector(metaRequestFinished:)];
    [retryRequest setTimeOutSeconds:10];
    [retryRequest setNumberOfTimesToRetryOnTimeout:3];
    [retryRequest addRequestHeader:@"Accept" value:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"];
    if (proxy)
    {
        [retryRequest setProxyType:proxy.type];
        [retryRequest setProxyHost:proxy.host];
        if (proxy.port)
            [retryRequest setProxyPort:proxy.port];
    }
    NSLog(@"INFO: Retry metadata: %ld", pid);
    [self addToLog:[NSString stringWithFormat:@"INFO: Retry metadata: %ld", pid] noTag:YES];
    [retryRequest startAsynchronous];
}

-(void)dataRequestFinished:(ASIHTTPRequest *)request
{
    if (!running)
        return;
    NSLog(@"DEBUG: Programme data response status code: %d", [request responseStatusCode]);
    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme data response code: %d", [request responseStatusCode]] noTag:YES];
    NSString *responseString = [[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding];
    NSLog(@"DEBUG: Programme data response: %@", responseString);
    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme data response: %@", responseString] noTag:YES];
    NSError *error = [request error];
    if ([request responseStatusCode] == 200 && [responseString length] > 0)
    {
        NSScanner *scanner = [NSScanner scannerWithString:[responseString stringByDecodingHTMLEntities]];
        
        NSUInteger scanloc = [scanner scanLocation];
        NSString *episodeTitle = nil;
        [scanner scanUpToString:@"<episodeTitle>" intoString:nil];
        [scanner scanString:@"<episodeTitle>" intoString:nil];
        [scanner scanUpToString:@"</" intoString:&episodeTitle];
        if (episodeTitle)
            [show setEpisodeName:episodeTitle];
        else
            [scanner setScanLocation:scanloc];
        
        scanloc = [scanner scanLocation];
        NSString *seriesTitle = nil;
        [scanner scanUpToString:@"<brandTitle>" intoString:nil];
        [scanner scanString:@"<brandTitle>" intoString:nil];
        [scanner scanUpToString:@"</" intoString:&seriesTitle];
        if (seriesTitle)
            [show setSeriesName:seriesTitle];
        else
            [scanner setScanLocation:scanloc];

        scanloc = [scanner scanLocation];
        NSString *primaryCategoryTitle = nil;
        [scanner scanUpToString:@"<primaryCategoryTitle>" intoString:nil];
        [scanner scanString:@"<primaryCategoryTitle>" intoString:nil];
        [scanner scanUpToString:@"</" intoString:&primaryCategoryTitle];
        if (primaryCategoryTitle) {
            if ([primaryCategoryTitle isEqual:@"Film"]) {
                isFilm = YES;
            }
        } else {
            [scanner setScanLocation:scanloc];
        }
        
        scanloc = [scanner scanLocation];
        NSInteger episodeNumber = 0;
        [scanner scanUpToString:@"<episodeNumber>" intoString:nil];
        [scanner scanString:@"<episodeNumber>" intoString:nil];
        [scanner scanInteger:&episodeNumber];
        if (episodeNumber)
            [show setEpisode:episodeNumber];
        else
            [scanner setScanLocation:scanloc];
        
        scanloc = [scanner scanLocation];
        NSInteger seriesNumber = 0;
        [scanner scanUpToString:@"<seriesNumber>" intoString:nil];
        [scanner scanString:@"<seriesNumber>" intoString:nil];
        [scanner scanInteger:&seriesNumber];
        if (seriesNumber)
            [show setSeason:seriesNumber];
        else
            [scanner setScanLocation:scanloc];
        
        scanloc = [scanner scanLocation];
        NSString *imagePath = nil;
        [scanner scanUpToString:@"<imagePath>" intoString:nil];
        [scanner scanString:@"<imagePath>" intoString:nil];
        [scanner scanUpToString:@"</" intoString:&imagePath];
        if (imagePath)
            thumbnailURL = [NSString stringWithFormat:@"http://www.channel4.com%@",imagePath];
        else
            [scanner setScanLocation:scanloc];
        
        scanloc = [scanner scanLocation];
        NSString *episodeGuideUrl = nil;
        [scanner scanUpToString:@"<episodeGuideUrl>" intoString:nil];
        [scanner scanString:@"<episodeGuideUrl>" intoString:nil];
        [scanner scanUpToString:@"</" intoString:&episodeGuideUrl];
        
        NSString *showname = nil, *senum = nil, *epnum = nil, *epname = nil;
        showname = [show seriesName];
        if ([show season])
            senum = [NSString stringWithFormat:@"Series %ld", [show season]];
        if ([show episode])
            epnum = [NSString stringWithFormat:@"Episode %ld", [show episode]];
        epname = [show episodeName];
        if (senum) {
            if (epnum) {
                showname = [NSString stringWithFormat:@"%@ - %@ %@", showname, senum, epnum];
            }
            else {
                showname = [NSString stringWithFormat:@"%@ - %@", showname, senum];
            }
        }
        else if (epnum) {
            showname = [NSString stringWithFormat:@"%@ - %@", showname, epnum];
        }
        if (epname && ![epname isEqualToString:[show seriesName]] && ![epname isEqualToString:epnum]) {
            showname = [NSString stringWithFormat:@"%@ - %@", showname, epname];
        }
        [show setShowName:showname];
        
        if (!(episodeTitle && seriesTitle && primaryCategoryTitle && episodeNumber && seriesNumber && imagePath && episodeGuideUrl))
        {
            NSLog(@"WARNING: Some programme data not found. Tagging will be incomplete.");
            [self addToLog:[NSString stringWithFormat:@"WARNING: Some programme data not found. Tagging will be incomplete."] noTag:YES];
        }
        NSLog(@"DEBUG: Programme data processed: episodeTitle=%@ seriesTitle=%@ primaryCategoryTitle=%@ episodeNumber=%ld seriesNumber=%ld imagePath=%@ episodeGuideUrl=%@", episodeTitle, seriesTitle, primaryCategoryTitle, episodeNumber, seriesNumber, imagePath, episodeGuideUrl);
        if (verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme data processed: episodeTitle=%@ seriesTitle=%@ primaryCategoryTitle=%@ episodeNumber=%ld seriesNumber=%ld imagePath=%@ episodeGuideUrl=%@", episodeTitle, seriesTitle, primaryCategoryTitle, episodeNumber, seriesNumber, imagePath, episodeGuideUrl] noTag:YES];

        NSLog(@"INFO: Programme data processed.");
        [self addToLog:@"INFO: Programme data processed." noTag:YES];

        if (episodeGuideUrl)
        {
            NSURL *descURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@%@", [[request url] host], episodeGuideUrl]];
            NSLog(@"DEBUG: Programme description URL: %@",descURL);
            if (verbose)
                [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme description URL: %@", descURL] noTag:YES];
            ASIHTTPRequest *descRequest = [ASIHTTPRequest requestWithURL:descURL];
            [descRequest setDidFailSelector:@selector(descRequestFinished:)];
            [descRequest setDidFinishSelector:@selector(descRequestFinished:)];
            [descRequest setTimeOutSeconds:10];
            [descRequest setNumberOfTimesToRetryOnTimeout:3];
            [descRequest setDelegate:self];
            [descRequest addRequestHeader:@"Accept" value:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"];
            NSLog(@"INFO: Requesting programme description.");
            [self addToLog:@"INFO: Requesting programme description." noTag:YES];
            [descRequest startAsynchronous];
            return;
        }
    }
    else
    {
        NSLog(@"WARNING: Programme data request failed. Tagging will be incomplete.");
        [self addToLog:[NSString stringWithFormat:@"WARNING: Programme data request failed. Tagging will be incomplete."] noTag:YES];
        NSLog(@"DEBUG: Programme data response error: %@", (error ? [error localizedDescription] : @"Unknown error"));
        if (verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme data response error: %@", (error ? [error localizedDescription] : @"Unknown error")] noTag:YES];
    }
    [self descRequestFinished:nil];
}

-(void)descRequestFinished:(ASIHTTPRequest *)request
{
    if (!running)
        return;
    NSLog(@"DEBUG: Programme description response status code: %d", [request responseStatusCode]);
    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme description response status code: %d", [request responseStatusCode]] noTag:YES];
    NSString *responseString = [[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding];
//    NSLog(@"DEBUG: Programme Description Response: %@", responseString);
//    if (verbose)
//        [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme Description Response: %@", responseString] noTag:YES];
    NSError *error = [request error];
    if ([request responseStatusCode] == 200 && [responseString length] > 0)
    {
        
        NSScanner *scanner = [NSScanner scannerWithString:responseString];
        
        NSString *desc = nil;
        [scanner scanUpToString:@"<div id=\"EpisodeSummary\"" intoString:nil];
        [scanner scanUpToString:@"<p>" intoString:nil];
        [scanner scanUpToString:@"<a" intoString:&desc];
        [show setDesc:[desc stringByConvertingHTMLToPlainText]];
        
        if (!desc)
        {
            NSLog(@"WARNING: Programme description not found. Tagging may be incomplete.");
            [self addToLog:[NSString stringWithFormat:@"WARNING: Programme description not found. Tagging may be incomplete."] noTag:YES];
        }
        
        NSLog(@"DEBUG: Programme description processed: desc=%@", desc);
        if (verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme description processed: synopsis=%@", desc] noTag:YES];

        NSLog(@"INFO: Programme description processed.");
        [self addToLog:@"INFO: Programme description processed." noTag:YES];
    }
    else
    {
        NSLog(@"WARNING: Programme description request failed. Tagging will be incomplete.");
        [self addToLog:[NSString stringWithFormat:@"WARNING: Programme description request failed. Tagging will be incomplete."] noTag:YES];
        NSLog(@"DEBUG: Programme description response error: %@", (error ? [error localizedDescription] : @"Unknown error"));
        if (verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme description response error: %@", (error ? [error localizedDescription] : @"Unknown error")] noTag:YES];
    }

    [self createDownloadPath];

    NSString *swfplayer = [[NSUserDefaults standardUserDefaults] valueForKey:[NSString stringWithFormat:@"%@SWFURL", defaultsPrefix]];
    if (!swfplayer) {
        swfplayer = @"http://www.channel4.com/static/programmes/asset/flash/swf/4odplayer-11.37.swf";
    }
    
    NSArray *args = @[@"--rtmp",downloadParams[@"rtmpURL"],
                     @"--app",downloadParams[@"app"],
                     @"--flashVer",@"\"WIN 11,5,502,110\"",
                     @"--swfVfy",swfplayer,
                     @"--pageUrl",[show url],
                     @"--playpath",downloadParams[@"playpath"],
                     @"--flv",downloadPath,
                     @"--conn",@"O:1",
                     @"--conn",@"O:0"];
    NSLog(@"DEBUG: RTMPDump args: %@",args);
    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: RTMPDump args: %@", args] noTag:YES];
    [self launchRTMPDumpWithArgs:args];
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
                result = @(PyString_AsString(pValue));
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
            return nil;
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
