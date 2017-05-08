//
//  ITVDownload.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 12/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ITVDownload.h"
#import "ASIHTTPRequest.h"
#import "NSString+HTML.h"
#import "ITVMediaFileEntry.h"

@implementation ITVDownload

- (id)description
{
    return [NSString stringWithFormat:@"ITV Download (ID=%@)", self.show.pid];
}

- (instancetype)initTest:(Programme *)tempShow proxy:(HTTPProxy *)aProxy
{
    if (self = [super init]) {
        self.proxy=aProxy;
        self.show=tempShow;
        self.attemptNumber=1;
        self.defaultsPrefix = @"ITV_";
        self.running = YES;
        
        self.formatList = @[[[TVFormat alloc] init],[[TVFormat alloc] init]];
        [self.formatList[0] setFormat:@"Flash - Standard"];
        [self.formatList[1] setFormat:@"Flash - High"];
        
        self.isTest=true;
        
        [tempShow printLongDescription];
        
        [self launchMetaRequest];
    }
    return self;
}
- (instancetype)initWithProgramme:(Programme *)tempShow itvFormats:(NSArray *)itvFormatList proxy:(HTTPProxy *)aProxy logController:(LogController *)logger
{
    if (self = [super initWithLogController:logger]) {
        
        self.proxy = aProxy;
        self.show = tempShow;
        self.attemptNumber=1;
        self.defaultsPrefix = @"ITV_";
        
        self.running = YES;
        
        if (!itvFormatList.count) {
            NSLog(@"ERROR: ITV Format List is empty");
            [self addToLog:@"ERROR: ITV Format List is empty"];
            self.show.reasonForFailure = @"ITVFormatListEmpty";
            self.show.complete = @YES;
            self.show.successful = @NO;
            [self.show setValue:@"Download Failed" forKey:@"status"];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:self.show];
            return self;
        }
        
        [self setCurrentProgress:[NSString stringWithFormat:@"Retrieving Programme Metadata... -- %@", self.show.showName]];
        [self setPercentage:102];
        [tempShow setValue:@"Initialising..." forKey:@"status"];
        
        self.formatList = [itvFormatList copy];
        [self addToLog:[NSString stringWithFormat:@"Downloading %@", self.show.showName]];
        [self addToLog:@"INFO: Preparing Request for Auth Info" noTag:YES];
        
        [tempShow printLongDescription];
        
        [self launchMetaRequest];
    }
    return self;
}

- (void)launchMetaRequest
{
    self.errorCache = [[NSMutableString alloc] initWithString:@""];
    self.processErrorCache = [NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(processError) userInfo:nil repeats:YES];
    
    NSString *soapBody = nil;
    if (self.show.url && [self.show.url rangeOfString:@"Filter=" options:NSCaseInsensitiveSearch].location == NSNotFound) {
        self.show.realPID = self.show.pid;
        soapBody = @"Body2";
        self.downloadParams[@"UseCurrentWebPage"] = @YES;
    }
    else
    {
        NSString *pid = nil;
        NSScanner *scanner = [NSScanner scannerWithString:self.show.url];
        [scanner scanUpToString:@"Filter=" intoString:nil];
        [scanner scanString:@"Filter=" intoString:nil];
        [scanner scanUpToString:@"kljkjj" intoString:&pid];
        if (!pid)
        {
            NSLog(@"ERROR: GiA cannot interpret the ITV URL: %@", self.show.url);
            [self addToLog:[NSString stringWithFormat:@"ERROR: GiA cannot interpret the ITV URL: %@", self.show.url]];
            self.show.reasonForFailure = @"MetadataProcessing";
            self.show.complete = @YES;
            self.show.successful = @NO;
            [self.show setValue:@"Download Failed" forKey:@"status"];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:self.show];
            return;
        }
        self.show.realPID = pid;
        soapBody = @"Body";
    }
    NSString *body;
    if (!self.isTest)
        body = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:soapBody ofType:nil]]
                                     encoding:NSUTF8StringEncoding];
    else
        //body = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:[[[NSProcessInfo processInfo] environment] objectForKey:@"REQUEST_LOC"]] encoding:NSUTF8StringEncoding];
        body = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:@"/Applications/Get iPlayer Automator.app/Contents/Resources/Body"] encoding:NSUTF8StringEncoding];
    
    body = [body stringByReplacingOccurrencesOfString:@"!!!ID!!!" withString:self.show.realPID];
    
    NSURL *requestURL = [NSURL URLWithString:@"http://mercury.itv.com/PlaylistService.svc"];
    NSLog(@"DEBUG: Metadata URL: %@",requestURL);
    if (self.verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata URL: %@", requestURL] noTag:YES];
    [self.currentRequest clearDelegatesAndCancel];
    self.currentRequest = [ASIHTTPRequest requestWithURL:requestURL];
    [self.currentRequest addRequestHeader:@"Referer" value:@"http://www.itv.com/mercury/Mercury_VideoPlayer.swf?v=1.5.309/[[DYNAMIC]]/2"];
    [self.currentRequest addRequestHeader:@"Content-Type" value:@"text/xml; charset=utf-8"];
    [self.currentRequest addRequestHeader:@"SOAPAction" value:@"\"http://tempuri.org/PlaylistService/GetPlaylist\""];
    self.currentRequest.requestMethod = @"POST";
    self.currentRequest.postBody = [NSMutableData dataWithData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    self.currentRequest.delegate = self;
    self.currentRequest.didFailSelector = @selector(metaRequestFinished:);
    self.currentRequest.didFinishSelector = @selector(metaRequestFinished:);
    self.currentRequest.timeOutSeconds = 10;
    self.currentRequest.numberOfTimesToRetryOnTimeout = 3;
    [self.currentRequest addRequestHeader:@"Accept" value:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"];
    if (self.proxy)
    {
        self.currentRequest.proxyType = self.proxy.type;
        self.currentRequest.proxyHost = self.proxy.host;
        if (self.proxy.port)
            self.currentRequest.proxyPort = self.proxy.port;
        if (self.proxy.user) {
            self.currentRequest.proxyUsername = self.proxy.user;
            self.currentRequest.proxyPassword = self.proxy.password;
        }
    }
    NSLog(@"INFO: Requesting Metadata.");
    [self addToLog:@"INFO: Requesting Metadata." noTag:YES];
    [self.currentRequest startAsynchronous];
}

-(void)metaRequestFinished:(ASIHTTPRequest *)request
{
    if (!self.running)
        return;
    NSLog(@"DEBUG: Metadata response status code: %d", request.responseStatusCode);
    if (self.verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata response status code: %d", request.responseStatusCode] noTag:YES];
    NSString *responseString = [[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding];
    NSLog(@"DEBUG: Metadata response: %@",responseString);
    if (self.verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata response: %@", responseString] noTag:YES];
    NSError *error = request.error;
    if (request.responseStatusCode == 0)
    {
        NSLog(@"ERROR: No response received (probably a proxy issue): %@", (error ? error.localizedDescription : @"Unknown error"));
        [self addToLog:[NSString stringWithFormat:@"ERROR: No response received (probably a proxy issue): %@", (error ? error.localizedDescription : @"Unknown error")]];
        self.show.successful = @NO;
        self.show.complete = @YES;
        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"] isEqualTo:@"Provided"])
            self.show.reasonForFailure = @"Provided_Proxy";
        else if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"] isEqualTo:@"Custom"])
            self.show.reasonForFailure = @"Custom_Proxy";
        else
            self.show.reasonForFailure = @"Internet_Connection";
        [self.show setValue:@"Failed: Bad Proxy" forKey:@"status"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:self.show];
        [self addToLog:@"Download Failed" noTag:NO];
        return;
    }
    else if (responseString.length > 0 && [responseString rangeOfString:@"InvalidGeoRegion" options:NSCaseInsensitiveSearch].location != NSNotFound)
    {
        NSLog(@"ERROR: Access denied to users outside UK.");
        [self addToLog:@"ERROR: Access denied to users outside UK."];
        self.show.successful = @NO;
        self.show.complete = @YES;
        self.show.reasonForFailure = @"Outside_UK";
        [self.show setValue:@"Failed: Outside UK" forKey:@"status"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:self.show];
        [self addToLog:@"Download Failed" noTag:NO];
        return;
    }
    else if (request.responseStatusCode != 200 || responseString.length == 0)
    {
        NSLog(@"ERROR: Could not retrieve programme metadata: %@", (error ? error.localizedDescription : @"Unknown error"));
        [self addToLog:[NSString stringWithFormat:@"ERROR: Could not retrieve programme metadata: %@", (error ? error.localizedDescription : @"Unknown error")]];
        self.show.successful = @NO;
        self.show.complete = @YES;
        [self.show setValue:@"Download Failed" forKey:@"status"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:self.show];
        [self addToLog:@"Download Failed" noTag:NO];
        return;
    }
    
    responseString = [responseString stringByDecodingHTMLEntities];
    NSScanner *scanner = [NSScanner scannerWithString:responseString];
    
    if (self.downloadParams[@"UseCurrentWebPage"])
    {
        //Reset to numeric PID if originated from current web page
        NSString *pid = nil;
        [scanner scanUpToString:@"<Vodcrid>crid://itv.com/" intoString:nil];
        [scanner scanString:@"<Vodcrid>crid://itv.com/" intoString:nil];
        [scanner scanUpToString:@"</Vodcrid>" intoString:&pid];
        self.show.realPID = pid;
    }
    
    //Retrieve Series Name
    NSString *seriesName = nil;
    [scanner scanUpToString:@"<ProgrammeTitle>" intoString:nil];
    [scanner scanString:@"<ProgrammeTitle>" intoString:nil];
    [scanner scanUpToString:@"</ProgrammeTitle>" intoString:&seriesName];
    self.show.seriesName = seriesName;
    
    //Init date formatter
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    dateFormat.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    
    //Retrieve Transmission Date
    NSString *dateString = nil;
    [scanner scanUpToString:@"<TransmissionDate>" intoString:nil];
    [scanner scanString:@"<TransmissionDate>" intoString:nil];
    [scanner scanUpToString:@"</TransmissionDate>" intoString:&dateString];
    dateFormat.dateFormat = @"dd LLLL yyyy";
    self.show.dateAired = [dateFormat dateFromString:dateString];
    
    //Retrieve Episode Name
    NSString *episodeName = nil;
    [scanner scanUpToString:@"<EpisodeTitle" intoString:nil];
    if (![scanner scanString:@"<EpisodeTitle/>" intoString:nil])
    {
        [scanner scanString:@"<EpisodeTitle>" intoString:nil];
        [scanner scanUpToString:@"</EpisodeTitle>" intoString:&episodeName];
        if (!episodeName) episodeName=@"(No Episode Name)";
        self.show.episodeName = episodeName;
    }
    else
        self.show.episodeName = @"(No Episode Name)";
    
    //Retrieve Episode Number
    NSInteger episodeNumber = self.show.episode;
    [scanner scanUpToString:@"<EpisodeNumber" intoString:nil];
    if (![scanner scanString:@"<EpisodeNumber/>" intoString:nil])
    {
        [scanner scanString:@"<EpisodeNumber>" intoString:nil];
        [scanner scanInteger:&episodeNumber];
    }
    self.show.episode = episodeNumber;
    
    //Retrieve Thumbnail URL
    [scanner scanUpToString:@"<PosterFrame>" intoString:nil];
    [scanner scanUpToString:@"CDATA" intoString:nil];
    [scanner scanString:@"CDATA[" intoString:nil];
    NSString *url;
    [scanner scanUpToString:@"]]" intoString:&url];
    self.thumbnailURL=url;
    url=nil;
    
    //Increase thumbnail size to 640x360
    NSInteger thumbWidth = 0;
    NSScanner *thumbScanner = [NSScanner scannerWithString:self.thumbnailURL];
    [thumbScanner scanUpToString:@"?w=" intoString:nil];
    [thumbScanner scanString:@"?w=" intoString:nil];
    [thumbScanner scanInteger:&thumbWidth];
    if (thumbWidth != 0 && thumbWidth < 640)
    {
        NSRange thumbSizeRange = [self.thumbnailURL rangeOfString:@"?w=" options:NSCaseInsensitiveSearch];
        if (thumbSizeRange.location != NSNotFound)
        {
            thumbSizeRange.length = self.thumbnailURL.length - thumbSizeRange.location;
            self.thumbnailURL = [self.thumbnailURL stringByReplacingCharactersInRange:thumbSizeRange withString:@"?w=640&h=360"];
            NSLog(@"DEBUG: Thumbnail URL changed: %@", self.thumbnailURL);
            if (self.verbose)
                [self addToLog:[NSString stringWithFormat:@"DEBUG: Thumbnail URL changed: %@", self.thumbnailURL] noTag:YES];
        }
    }
    
    //Retrieve Subtitle URL
    [scanner scanUpToString:@"<ClosedCaptioning" intoString:nil];
    if(![scanner scanString:@"<ClosedCaptioningURIs/>" intoString:nil])
    {
        [scanner scanUpToString:@"CDATA[" intoString:nil];
        [scanner scanString:@"CDATA[" intoString:nil];
        NSString *url;
        [scanner scanUpToString:@"]]" intoString:&url];
        self.subtitleURL=url;
        url=nil;
    }
    //Retrieve Auth URL
    NSString *authURL = nil;
    [scanner scanUpToString:@"rtmpe://" intoString:nil];
    [scanner scanUpToString:@"\"" intoString:&authURL];
    
    NSLog(@"DEBUG: Metadata processed: seriesName=%@ dateString=%@ episodeName=%@ episodeNumber=%ld self.thumbnailURL=%@ subtitleURL=%@ authURL=%@",
          seriesName, dateString, episodeName, episodeNumber, self.thumbnailURL, self.subtitleURL, authURL);
    if (self.verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata processed: seriesName=%@ dateString=%@ episodeName=%@ episodeNumber=%ld self.thumbnailURL=%@ subtitleURL=%@ authURL=%@",
                        seriesName, dateString, episodeName, episodeNumber, self.thumbnailURL, self.subtitleURL, authURL] noTag:YES];
    
    NSLog(@"DEBUG: Retrieving Playpath");
    if (self.verbose)
        [self addToLog:@"DEBUG: Retrieving Playpath" noTag:YES];
    
    //Retrieve PlayPath
    NSString *playPath = nil;
    NSMutableArray *itvRateArray = nil;
    NSMutableArray *bitrateArray = nil;
    @try {
        NSArray *formatKeys = @[@"Flash - Very Low",@"Flash - Low",@"Flash - Standard",@"Flash - High",  @"Flash - Very High", @"Flash - HD"];
        NSArray *itvRateObjects = @[@"400",@"600",@"800",@"1200", @"1500", @"1800"];
        NSArray *bitrateObjects = @[@"400000",@"600000",@"800000",@"1200000",@"1500000",@"1800000"];
        NSDictionary *itvRateDic = [NSDictionary dictionaryWithObjects:itvRateObjects forKeys:formatKeys];
        NSDictionary *bitrateDic = [NSDictionary dictionaryWithObjects:bitrateObjects forKeys:formatKeys];
        
        itvRateArray = [[NSMutableArray alloc] init];
        bitrateArray = [[NSMutableArray alloc] init];
        
        for (TVFormat *format in self.formatList)  {
            NSString *mode;
            if ((mode = itvRateDic[format.format]))
                [itvRateArray addObject:mode];
        }
        for (TVFormat *format in self.formatList) {
            NSString *mode;
            if ((mode = bitrateDic[format.format]))
                [bitrateArray addObject:mode];
        }
    }
    @catch (NSException *exception)
    {
        NSLog(@"ERROR: %@: %@", exception.name, exception.description);
        [self addToLog:[NSString stringWithFormat:@"ERROR: %@: %@", exception.name, exception.description]];
        self.show.complete = @YES;
        self.show.successful = @NO;
        [self.show setValue:@"Download Failed" forKey:@"status"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:self.show];
        return;
    }
    NSLog(@"DEBUG: Parsing MediaFile entries");
    if (verKorea)
        [self addToLog:@"DEBUG: Parsing MediaFile entries" noTag:YES];
    NSMutableArray *mediaEntries = [[NSMutableArray alloc] init];
    NSUInteger beforeMediaFiles = scanner.scanLocation;
    while ([scanner scanUpToString:@"MediaFile delivery" intoString:nil]) {
        NSString *url = nil, *bitrate = nil, *itvRate = nil;
        ITVMediaFileEntry *entry = [[ITVMediaFileEntry alloc] init];
        [scanner scanUpToString:@"bitrate=" intoString:nil];
        [scanner scanString:@"bitrate=\"" intoString:nil];
        [scanner scanUpToString:@"\"" intoString:&bitrate];
        [scanner scanUpToString:@"CDATA" intoString:nil];
        [scanner scanString:@"CDATA[" intoString:nil];
        NSUInteger location = scanner.scanLocation;
        [scanner scanUpToString:@"]]" intoString:&url];
        scanner.scanLocation = location;
        [scanner scanUpToString:@"_PC01" intoString:nil];
        [scanner scanString:@"_PC01" intoString:nil];
        [scanner scanUpToString:@"_" intoString:&itvRate];
        if (scanner.atEnd) {
            scanner.scanLocation = location;
            [scanner scanUpToString:@"_itv" intoString:nil];
            [scanner scanString:@"_itv" intoString:nil];
            [scanner scanUpToString:@"_" intoString:&itvRate];
        }
        
        entry.bitrate = bitrate;
        entry.url = url;
        entry.itvRate = itvRate;
        [mediaEntries addObject:entry];
        NSLog(@"DEBUG: ITVMediaFileEntry: bitrate=%@ itvRate=%@ url=%@", bitrate, itvRate, url);
        if (verKorea)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: ITVMediaFileEntry: bitrate=%@ itvRate=%@ url=%@", bitrate, itvRate, url] noTag:YES];
    }
    
    NSLog(@"DEBUG: Searching for itvRate match");
    if (verKorea)
        [self addToLog:@"DEBUG: Searching for itvRate match" noTag:YES];
    BOOL foundIt=FALSE;
    for (NSString *rate in itvRateArray) {
        for (ITVMediaFileEntry *entry in mediaEntries) {
            if ([entry.itvRate isEqualToString:rate]) {
                foundIt=TRUE;
                playPath=entry.url;
                NSLog(@"DEBUG: foundIt (itvRate): rate=%@ url=%@", rate, playPath);
                if (verKorea)
                    [self addToLog:[NSString stringWithFormat:@"DEBUG: foundIt (itvRate): rate=%@ url=%@", rate, playPath] noTag:YES];
                break;
            }
        }
        if (foundIt) break;
    }
    if (!foundIt)
    {
        NSLog(@"DEBUG: Searching for bitrate match");
        if (self.verbose)
            [self addToLog:@"DEBUG: Searching for bitrate match" noTag:YES];
        for (NSString *rate in bitrateArray) {
            for (ITVMediaFileEntry *entry in mediaEntries) {
                if ([entry.bitrate isEqualToString:rate]) {
                    foundIt=TRUE;
                    playPath=entry.url;
                    NSLog(@"DEBUG: foundIt (bitrate): rate=%@ url=%@", rate, playPath);
                    if (self.verbose)
                        [self addToLog:[NSString stringWithFormat:@"DEBUG: foundIt (bitrate): rate=%@ url=%@", rate, playPath] noTag:YES];
                    break;
                }
            }
            if (foundIt) break;
        }
    }
    
    if (!foundIt) {
        NSLog(@"ERROR: None of the modes in your download format list are available for this self.show. Try adding more modes if possible.");
        [self addToLog:@"ERROR: None of the modes in your download format list are available for this self.show. Try adding more modes if possible."];
        self.show.reasonForFailure = @"NoSpecifiedFormatAvailableITV";
        self.show.complete = @YES;
        self.show.successful = @NO;
        [self.show setValue:@"Download Failed" forKey:@"status"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:self.show];
        return;
    }
    else {
        NSLog(@"DEBUG: playPath = %@",playPath);
        if (self.verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: playPath = %@", playPath] noTag:YES];
    }
    
    NSInteger seriesNumber = self.show.season;
    for (ITVMediaFileEntry *entry in mediaEntries) {
        NSScanner *mescanner = [NSScanner scannerWithString:entry.url];
        [mescanner scanUpToString:@"(series-" intoString:nil];
        [mescanner scanString:@"(series-" intoString:nil];
        if ([mescanner scanInteger:&seriesNumber])
            break;
    }
    self.show.season = seriesNumber;
    NSLog(@"DEBUG: seriesNumber=%ld", seriesNumber);
    if (self.verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: seriesNumber=%ld", seriesNumber] noTag:YES];
    
    scanner.scanLocation = beforeMediaFiles;
    [scanner scanUpToString:@"proggenre=films" intoString:nil];
    if ([scanner scanString:@"proggenre=films" intoString:nil]) {
        self.isFilm = YES;
    }
    NSLog(@"DEBUG: isFilm = %d",self.isFilm);
    if (self.verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: isFilm = %d", self.isFilm] noTag:YES];
    
    self.downloadParams[@"authURL"] = authURL;
    self.downloadParams[@"playPath"] = playPath;
    
    //Proxy Test Stuff
    if (self.isTest)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MetadataSuccessful" object:nil];
        return;
    }
    
    NSLog(@"INFO: Metadata processed.");
    [self addToLog:@"INFO: Metadata processed." noTag:YES];
    NSURL *dataURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.itv.com/_app/Dynamic/CatchUpData.ashx?ViewType=5&Filter=%@",self.show.realPID]];
    NSLog(@"DEBUG: Programme data URL: %@",dataURL);
    if (self.verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme data URL: %@", dataURL] noTag:YES];
    [self.currentRequest clearDelegatesAndCancel];
    self.currentRequest = [ASIHTTPRequest requestWithURL:dataURL];
    self.currentRequest.didFailSelector = @selector(dataRequestFinished:);
    self.currentRequest.didFinishSelector = @selector(dataRequestFinished:);
    self.currentRequest.timeOutSeconds = 10;
    self.currentRequest.numberOfTimesToRetryOnTimeout = 3;
    self.currentRequest.delegate = self;
    [self.currentRequest addRequestHeader:@"Accept" value:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"];
    NSLog(@"INFO: Requesting programme data.");
    [self addToLog:@"INFO: Requesting programme data." noTag:YES];
    [self.currentRequest startAsynchronous];
}

-(void)dataRequestFinished:(ASIHTTPRequest *)request
{
    if (!self.running)
        return;
    NSScanner *scanner = nil;
    NSLog(@"DEBUG: Programme data response status code: %d", request.responseStatusCode);
    if (self.verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme data response status code: %d", request.responseStatusCode] noTag:YES];
    NSString *responseString = [[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding];
    NSLog(@"DEBUG: Programme data response: %@", responseString);
    if (self.verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme data response: %@", responseString] noTag:YES];
    NSError *error = request.error;
    NSString *description = nil, *showname = nil, *senum = nil, *epnum = nil, *epname = nil, *temp_showname = nil;
    if (request.responseStatusCode == 200 && responseString.length > 0)
    {
        scanner = [NSScanner scannerWithString:responseString];
        [scanner scanUpToString:@"<h2>" intoString:nil];
        [scanner scanString:@"<h2>" intoString:nil];
        [scanner scanUpToString:@"</h2>" intoString:&temp_showname];
        [scanner scanUpToString:@"<p>" intoString:nil];
        [scanner scanString:@"<p>" intoString:nil];
        [scanner scanUpToString:@"</p>" intoString:&description];
        temp_showname = [temp_showname stringByConvertingHTMLToPlainText];
        description = [description stringByConvertingHTMLToPlainText];
    }
    else
    {
        NSLog(@"WARNING: Programme data request failed. Tagging will be incomplete.");
        [self addToLog:[NSString stringWithFormat:@"WARNING: Programme data request failed. Tagging will be incomplete."] noTag:YES];
        NSLog(@"DEBUG: Programme data response error: %@", (error ? error.localizedDescription : @"Unknown error"));
        if (self.verbose)
            [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme data response error: %@", (error ? error.localizedDescription : @"Unknown error")] noTag:YES];
        
    }
    //Fix Showname
    if (!temp_showname)
        temp_showname = self.show.seriesName;
    showname = temp_showname;
    if (self.show.season)
        senum = [NSString stringWithFormat:@"Series %ld", self.show.season];
    if (self.show.episode)
        epnum = [NSString stringWithFormat:@"Episode %ld", self.show.episode];
    epname = self.show.episodeName;
    if (!epname || [epname isEqualToString:@"(No Episode Name)"])
    {
        //Air date as backup
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        dateFormat.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormat.dateFormat = @"dd/MM/yyyy";
        epname = [dateFormat stringFromDate:self.show.dateAired];
    }
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
    if (epname && ![epname isEqualToString:temp_showname] && ![epname isEqualToString:epnum]) {
        showname = [NSString stringWithFormat:@"%@ - %@", showname, epname];
    }
    self.show.showName = showname;
    if (!description)
        description = @"(No Description)";
    self.show.desc = description;
    NSLog(@"DEBUG: Programme data processed: showname=%@ temp_showname=%@ senum=%@ epnum=%@ epname=%@ description=%@", showname, temp_showname, senum, epnum, epname, description);
    if (self.verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme data processed: showname=%@ temp_showname=%@ senum=%@ epnum=%@ epname=%@ description=%@",
                        showname, temp_showname, senum, epnum, epname, description] noTag:YES];
    
    NSLog(@"INFO: Program data processed.");
    [self addToLog:@"INFO: Program data processed." noTag:YES];
    
    //Create Download Path
    [self createDownloadPath];
    
    NSString *swfplayer = [[NSUserDefaults standardUserDefaults] valueForKey:[NSString stringWithFormat:@"%@SWFURL", self.defaultsPrefix]];
    if (!swfplayer) {
        swfplayer = @"http://www.itv.com/mediaplayer/ITVMediaPlayer.swf?v=11.20.654";
    }
    
    NSMutableArray *args = [NSMutableArray arrayWithObjects:
                            @"-r",self.downloadParams[@"authURL"],
                            @"-W",swfplayer,
                            @"-y",self.downloadParams[@"playPath"],
                            @"-o",self.downloadPath,
                            nil];
    if (self.verbose)
        [args addObject:@"--verbose"];
    NSLog(@"DEBUG: RTMPDump args: %@",args);
    if (self.verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: RTMPDump args: %@", args] noTag:YES];
    [self launchRTMPDumpWithArgs:args];
}
@end
