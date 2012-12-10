//
//  FourODDownload.m
//  Get_iPlayer GUI
//
//  Created by Thomas E. Willson on 7/29/12.
//
//

#import "FourODDownload.h"
#import "ASIHTTPRequest.h"
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
    NSString *pid;
    [scanner scanUpToString:@"lklk" intoString:&pid];
    [show setRealPID:pid];
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://ais.channel4.com/asset/%@",[show realPID]]];
    NSLog(@"Request URL: %@",requestURL);
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:requestURL];
    [request setDidFinishSelector:@selector(metaRequestFinished:)];
    [request setTimeOutSeconds:10];
    [request setNumberOfTimesToRetryOnTimeout:3];
    [request setDelegate:self];
    
    ASIHTTPRequest *dataRequest = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[show url]]];
    [dataRequest setDidFinishSelector:@selector(dataRequestFinished:)];
    [dataRequest setTimeOutSeconds:10];
    [dataRequest setNumberOfTimesToRetryOnTimeout:3];
    [dataRequest setDelegate:self];
    [dataRequest startAsynchronous];
    
    
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
    

    NSString *responseString = [[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding];
    
    NSLog(@"%@",responseString);
    
    NSScanner *scanner = [NSScanner scannerWithString:responseString];
    
    if ([responseString rangeOfString:@"f4m"].location != NSNotFound)
    {
        [self addToLog:@"GiA does not support downloading this show."];
        [self addToLog:@"    HTTP Dynamic Streaming Detected"];
        [show setComplete:[NSNumber numberWithBool:YES]];
        [show setSuccessful:[NSNumber numberWithBool:NO]];
        [show setValue:@"Download Failed" forKey:@"status"];
        [show setReasonForFailure:@"4oDHTTP"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        return;
    }
    
    NSString *uriData = nil;
    [scanner scanUpToString:@"<uriData>" intoString:nil];
    [scanner scanString:@"<uriData>" intoString:nil];
    [scanner scanUpToString:@"</uriData>" intoString:&uriData];
    
    scanner = [NSScanner scannerWithString:uriData];
    [scanner scanUpToString:@"<streamUri>" intoString:nil];
    [scanner scanString:@"<streamUri>" intoString:nil];
    NSString *streamUri = nil;
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
    
    if (!(uriData && streamUri && token && cdn && decodedToken))
        [NSException raise:@"Parsing Error." format:@"Could not process 4oD Metadata"];

    NSString *auth = nil, *rtmpURL = nil;
    if ([cdn isEqualToString:@"ll"])
    {
        [scanner setScanLocation:0];
        NSString *av = nil, *te = nil, *st = nil, *et = nil;
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
        NSString *mp = [[streamUri componentsSeparatedByString:@"mp4:"] objectAtIndex:1];
        if (av && te && st && et && mp)
            auth = [NSString stringWithFormat:@"as=adobe-hmac-sha256&av=%@&te=%@&st=%@&et=%@&mp=%@&fmta-token=%@",av,te,st,et,mp,decodedToken];
        else
            [NSException raise:@"Parsing Error." format:@"Could not process 4oD Metadata"];
        rtmpURL = [[streamUri componentsSeparatedByString:@"mp4:"] objectAtIndex:0];
        rtmpURL = [rtmpURL stringByReplacingOccurrencesOfString:@".com/" withString:@".com:1935/"];
        rtmpURL = [rtmpURL stringByAppendingFormat:@"?%@",auth];
    }
    else
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
        @try {
            if (fingerprint && slist)
                auth = [NSString stringWithFormat:@"auth=%@&aifp=%@&slist=%@",decodedToken,fingerprint,slist];
            else
                [NSException raise:@"Parsing Error." format:@"Could not process 4oD Metadata"];
            
            rtmpURL = [[streamUri componentsSeparatedByString:@"mp4:"] objectAtIndex:0];
            rtmpURL = [rtmpURL stringByReplacingOccurrencesOfString:@".com/" withString:@".com:1935/"];
            rtmpURL = [rtmpURL stringByAppendingFormat:@"?%@",auth];
            
            if ([rtmpURL hasPrefix:@"http"])
                [NSException raise:@"4oD: Unsupported HTTP Download." format:@"GiA does not support this programme."];
        }
        @catch (NSException *exception) {
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
    }
    
    NSString *app;
    scanner = [NSScanner scannerWithString:streamUri];
    [scanner scanUpToString:@".com/" intoString:nil];
    [scanner scanString:@".com/" intoString:nil];
    [scanner scanUpToString:@"mp4:" intoString:&app];
    
    app = [app stringByAppendingFormat:@"?%@", auth];
    
    NSString *swfplayer = [[NSUserDefaults standardUserDefaults] valueForKey:[NSString stringWithFormat:@"%@SWFURL", defaultsPrefix]];
    if (!swfplayer) {
        swfplayer = @"http://www.channel4.com/static/programmes/asset/flash/swf/4odplayer-11.32.2.swf";
    }
    NSString *playpath = [streamUri substringFromIndex:[scanner scanLocation]];
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
-(void)dataRequestFinished:(ASIHTTPRequest *)request
{
    NSString *responseString = [[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding];
    
    NSScanner *scanner = [NSScanner scannerWithString:responseString];
    
    [scanner scanUpToString:@"og:image" intoString:nil];
    [scanner scanString:@"og:image\" content=\"" intoString:nil];
    [scanner scanUpToString:@"\"" intoString:&thumbnailURL];
    
    NSString *description, *seriesTitle;
    [scanner scanUpToString:@"<meta name=\"description\"" intoString:nil];
    [scanner scanUpToString:@"4oD" intoString:nil];
    [scanner scanString:@"4oD. " intoString:nil];
    [scanner scanUpToString:@"\"/>" intoString:&description];
    [show setDesc:description];
    
    [scanner scanUpToString:@"<h1 class=\"brandTitle\" data-wsbrandtitle=" intoString:nil];
    [scanner scanString:@"<h1 class=\"brandTitle\" data-wsbrandtitle=" intoString:nil];
    [scanner scanUpToString:@"title=\"" intoString:nil];
    [scanner scanString:@"title=\"" intoString:nil];
    [scanner scanUpToString:@"\">" intoString:&seriesTitle];
    [show setSeriesName:seriesTitle];
    
    [show setEpisodeName:[[[show showName] componentsSeparatedByString:@" - "] objectAtIndex:1]];
    
    NSInteger series, episode;
    [scanner scanUpToString:@"seriesNo" intoString:nil];
    [scanner scanString:@"seriesNo\">Series " intoString:nil];
    [scanner scanInteger:&series];
    [show setSeason:series];
    [scanner scanUpToString:@"episodeNo" intoString:nil];
    [scanner scanString:@"episodeNo\">Episode " intoString:nil];
    [scanner scanInteger:&episode];
    [show setEpisode:episode];
    
    
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
