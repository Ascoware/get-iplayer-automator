//
//  FourODDownload.m
//  Get_iPlayer GUI
//
//  Created by Thomas E. Willson on 7/29/12.
//
//

#import "FourODDownload.h"
#import "ASIHTTPRequest.h"
#import "FourODTokenDecoder.h"

@implementation FourODDownload
- (id)initWithProgramme:(Programme *)tempShow
{
    show = tempShow;
    attemptNumber=1;
    nc = [NSNotificationCenter defaultCenter];
    
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
    NSURL *requestURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"http://ais.channel4.com/asset/%@",[show realPID]]];
    NSLog(@"Request URL: %@",requestURL);
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:requestURL];
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
    
    NSString *uriData;
    [scanner scanUpToString:@"<uriData>" intoString:nil];
    [scanner scanString:@"<uriData>" intoString:nil];
    [scanner scanUpToString:@"</uriData>" intoString:&uriData];
    
    scanner = [NSScanner scannerWithString:uriData];
    [scanner scanUpToString:@"<streamUri>" intoString:nil];
    [scanner scanString:@"<streamUri>" intoString:nil];
    NSString *streamUri;
    [scanner scanUpToString:@"</" intoString:&streamUri];
    [scanner scanUpToString:@"<token>" intoString:nil];
    [scanner scanString:@"<token>" intoString:nil];
    NSString *token;
    [scanner scanUpToString:@"</" intoString:&token];
    [scanner scanUpToString:@"<cdn>" intoString:nil];
    [scanner scanString:@"<cdn>" intoString:nil];
    NSString *cdn;
    [scanner scanUpToString:@"</" intoString:&cdn];
    
    NSString *decodedToken = [FourODTokenDecoder decodeToken:token];
    NSLog(@"%@",decodedToken);
    
    NSString *auth;
    if ([cdn isEqualToString:@"ll"])
    {
        [scanner setScanLocation:0];
        NSString *e;
        [scanner scanUpToString:@"<e>" intoString:nil];
        [scanner scanString:@"<e>" intoString:nil];
        [scanner scanUpToString:@"</e>" intoString:&e];
        auth = [NSString stringWithFormat:@"e=%@&h=%@",e,decodedToken];
    }
    else
    {
        [scanner setScanLocation:0];
        NSString *fingerprint, *slist;
        [scanner scanUpToString:@"<fingerprint>" intoString:nil];
        [scanner scanString:@"<fingerprint>" intoString:nil];
        [scanner scanUpToString:@"</fingerprint>" intoString:&fingerprint];
        [scanner setScanLocation:0];
        [scanner scanUpToString:@"<slist>" intoString:nil];
        [scanner scanString:@"<slist>" intoString:nil];
        [scanner scanUpToString:@"</slist>" intoString:&slist];
        auth = [NSString stringWithFormat:@"auth=%@&aifp=%@&slist=%@",decodedToken,fingerprint,slist];
    }
    
    NSString *rtmpURL = [[streamUri componentsSeparatedByString:@"mp4:"] objectAtIndex:0];
    rtmpURL = [rtmpURL stringByReplacingOccurrencesOfString:@".com/" withString:@".com:1935/"];
    rtmpURL = [rtmpURL stringByAppendingFormat:@"?ovpfv=1.1&%@",auth];
    
    NSString *app;
    scanner = [NSScanner scannerWithString:streamUri];
    [scanner scanUpToString:@".com/" intoString:nil];
    [scanner scanString:@".com/" intoString:nil];
    [scanner scanUpToString:@"mp4:" intoString:&app];
    
    app = [app stringByAppendingFormat:@"?ovpfv=1.1&%@", auth];
    
    NSString *swfplayer = @"http://www.channel4.com/static/programmes/asset/flash/swf/4odplayer-11.27.4.swf";
    NSString *playpath = [streamUri substringFromIndex:[scanner scanLocation]];
    playpath = [playpath stringByAppendingFormat:@"?%@",auth];
    [self createDownloadPath];
    
    NSArray *args = [NSArray arrayWithObjects:@"--rtmp",rtmpURL,
                     @"--app",app,
                     @"--flashVer",@"\"WIN 11,2,202,235\"",
                     @"--swfVfy",swfplayer,
                     @"--pageUrl",[show url],
                     @"--conn",@"Z:",
                     @"--playpath",playpath,
                     @"-o",downloadPath,
                     nil];
    [self launchRTMPDumpWithArgs:args];
    
}
@end
