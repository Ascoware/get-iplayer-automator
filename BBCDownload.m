//
//  Download.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/14/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "BBCDownload.h"
#import "AppController.h"

@implementation BBCDownload
+ (void)initFormats
{
    NSArray *tvFormatKeys = @[@"Best", @"Better", @"Good", @"Worst"];
    NSArray *tvFormatObjects = @[@"tvbest",@"tvbetter",@"tvgood", @"tvworst"];
    NSArray *radioFormatKeys = @[@"Best", @"Better", @"Good", @"Worst"];
    NSArray *radioFormatObjects = @[@"radiobest", @"radiobetter", @"radiogood", @"radioworst"];
    
    tvFormats = [[NSDictionary alloc] initWithObjects:tvFormatObjects forKeys:tvFormatKeys];
    radioFormats = [[NSDictionary alloc] initWithObjects:radioFormatObjects forKeys:radioFormatKeys];
}
#pragma mark Overridden Methods
- (instancetype)initWithProgramme:(Programme *)tempShow tvFormats:(NSArray *)tvFormatList radioFormats:(NSArray *)radioFormatList proxy:(HTTPProxy *)aProxy logController:(LogController *)logger
{
    if (self = [super initWithLogController:logger]) {
        _runAgain = NO;
        _foundLastLine=NO;
        _reasonForFailure = @"None";
        self.proxy = aProxy;
        self.show = tempShow;
        [self addToLog:[NSString stringWithFormat:@"Downloading %@", tempShow.showName]];
        _noDataCount=0;
        
        //Initialize Formats
        if (!tvFormats || !radioFormats) {
            [BBCDownload initFormats];
        }
        NSMutableString *formatArg = [[NSMutableString alloc] initWithString:@"--modes="];
        NSMutableArray *formatStrings = [NSMutableArray array];
        
        for (RadioFormat *format in radioFormatList) {
            [formatStrings addObject:[radioFormats valueForKey:format.format]];
        }
        for (TVFormat *format in tvFormatList) {
            [formatStrings addObject:[tvFormats valueForKey:format.format]];
        }
        
        NSString *commaSeparatedFormats = [formatStrings componentsJoinedByString:@","];
        
        [formatArg appendString:commaSeparatedFormats];
        
        //Set Proxy Arguments
        NSString *proxyArg = nil;
        NSString *partialProxyArg = nil;
        if (aProxy)
        {
            proxyArg = [[NSString alloc] initWithFormat:@"-p%@", aProxy.url];
            if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue])
            {
                partialProxyArg = @"--partial-proxy";
            }
        }
        //Initialize the rest of the arguments
        NSString *noWarningArg = @"--nocopyright";
        NSString *noPurgeArg = @"--nopurge";
        NSString *atomicParsleyArg = [[NSString alloc] initWithFormat:@"--atomicparsley=%@", [[[AppController sharedController] extraBinariesPath] stringByAppendingPathComponent:@"AtomicParsley"]];
        NSString *ffmpegArg = [[NSString alloc] initWithFormat:@"--ffmpeg=%@", [[[AppController sharedController] extraBinariesPath] stringByAppendingPathComponent:@"ffmpeg"]];
        NSString *downloadPathArg = [[NSString alloc] initWithFormat:@"--output=%@", self.downloadPath];
        NSString *subDirArg = @"--subdir";
        NSString *progressArg = @"--logprogress";
        
        NSString *getArg = @"--pid";
        NSString *searchArg = [[NSString alloc] initWithFormat:@"%@", self.show.pid];
        NSString *whitespaceArg = @"--whitespace";
        
        //AudioDescribed & Signed
        BOOL needVersions = NO;
        
        NSMutableArray *nonDefaultVersions = [[NSMutableArray alloc] init];
        
        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"AudioDescribedNew"] boolValue]) {
            [nonDefaultVersions addObject:@"audiodescribed"];
            needVersions = YES;
        }
        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SignedNew"] boolValue]) {
            [nonDefaultVersions addObject:@"signed"];
            needVersions = YES;
        }
        
        //We don't want this to refresh now!
        NSString *cacheExpiryArg = @"-e604800000000";
        NSString *appSupportFolder = [[NSFileManager defaultManager] applicationSupportDirectory];
        _profileDirArg = [[NSString alloc] initWithFormat:@"--profile-dir=%@", appSupportFolder];
        
        //Add Arguments that can't be NULL
        NSMutableArray *args = [[NSMutableArray alloc] initWithObjects:
                                [[AppController sharedController] getiPlayerPath],
                                _profileDirArg,
                                noWarningArg,
                                noPurgeArg,
                                atomicParsleyArg,
                                cacheExpiryArg,
                                downloadPathArg,
                                subDirArg,
                                progressArg,
                                formatArg,
                                getArg,
                                searchArg,
                                whitespaceArg,
                                @"--attempts=5",
                                @"--thumbsize=640",
                                ffmpegArg,
                                @"--log-progress",
                                nil];
        
        if (proxyArg) {
            [args addObject:proxyArg];
        }
        
        if (partialProxyArg) {
            [args addObject:partialProxyArg];
        }
        
        // Only add a --versions parameter for audio described or signed. Otherwise, let get_iplayer figure it out.
        if (needVersions) {
            [nonDefaultVersions addObject:@"default"];
            NSMutableString *versionArg = [NSMutableString stringWithString:@"--versions="];
            [versionArg appendString:[nonDefaultVersions componentsJoinedByString:@","]];
            [args addObject:versionArg];
        }
        
        //Verbose?
        if (self.verbose)
            [args addObject:@"--verbose"];
        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"DownloadSubtitles"] isEqualTo:@YES]) {
            [args addObject:@"--subtitles"];
            if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"EmbedSubtitles"] isEqualTo:@YES]) {
                [args addObject:@"--subs-embed"];
            }
        }
        
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
        
        // 50 FPS frames?
        if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"Use25FPSStreams"] boolValue]) {
            [args addObject:@"--fps25"];
        }
        
        //Tagging
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"TagShows"])
            [args addObject:@"--no-tag"];
        
        if (self.verbose) {
            for (NSString *arg in args) {
                [self logDebugMessage:arg noTag:YES];
            }
        }
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"TagRadioAsPodcast"]) {
            [args addObject:@"--tag-podcast-radio"];
            self.show.podcast = YES;
        }
        
        self.task.arguments = args;
        self.task.launchPath = [[AppController sharedController] perlBinaryPath];
        self.task.standardOutput = self.pipe;
        self.task.standardError = self.errorPipe;
        
        NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:self.task.environment];
        envVariableDictionary[@"HOME"] = (@"~").stringByExpandingTildeInPath;
        envVariableDictionary[@"PERL_UNICODE"] = @"AS";
        envVariableDictionary[@"PATH"] = [[AppController sharedController] perlEnvironmentPath];
        self.task.environment = envVariableDictionary;
        
        self.fh = self.pipe.fileHandleForReading;
        self.errorFh = self.errorPipe.fileHandleForReading;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(downloadDataNotification:)
                                                     name:NSFileHandleReadCompletionNotification
                                                   object:self.fh];
        [self.fh readInBackgroundAndNotify];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(errorDataReadyNotification:)
                                                     name:NSFileHandleReadCompletionNotification
                                                   object:self.errorFh];
        [self.errorFh readInBackgroundAndNotify];
        
        [self.task launch];
        
        //Prepare UI
        [self setCurrentProgress:@"Starting download..."];
        self.show.status = @"Starting..";
    }
    return self;
}
- (id)description
{
    return [NSString stringWithFormat:@"BBC Download (ID=%@)", self.show.pid];
}
#pragma mark Task Control
- (void)downloadDataNotification:(NSNotification *)n
{
    NSData *d = [[n userInfo] valueForKey:NSFileHandleNotificationDataItem];
    [self downloadDataReady:d];
}

- (void)downloadDataReady:(NSData *)data
{
    if (data.length > 0) {
        NSString *s = [[NSString alloc] initWithData:data
                                            encoding:NSUTF8StringEncoding];
        [self processGetiPlayerOutput:s];
    } else {
        _noDataCount++;
    }
    
    [self.pipe.fileHandleForReading readInBackgroundAndNotify];
    [self.errorPipe.fileHandleForReading readInBackgroundAndNotify];
    
    if (_noDataCount > 20 || self.show.complete.boolValue) {
        [self performSelectorOnMainThread:@selector(downloadFinished) withObject:nil waitUntilDone:NO];
    }
}

-(void)downloadFinished {
    self.task = nil;
    self.pipe = nil;
    self.errorPipe = nil;
    
    if (runDownloads) {
        [self completeDownload];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:self.show];
}

- (void)completeDownload {
    if (!_foundLastLine) {
        NSLog(@"Setting Last Line Here..");
        NSArray *logComponents = [self.log componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        _LastLine = logComponents.lastObject;
        unsigned int offsetFromEnd=1;
        while (!_LastLine.length) {
            _LastLine = logComponents[(logComponents.count - offsetFromEnd)];
            ++offsetFromEnd;
        }
    }
    
    NSLog(@"Last Line: %@", _LastLine);
    NSLog(@"Length of Last Line: %lu", (unsigned long)_LastLine.length);
    
    NSScanner *scn = [NSScanner scannerWithString:_LastLine];
    if ([_reasonForFailure isEqualToString:@"unresumable"])
    {
        self.show.complete = @YES;
        self.show.successful = @NO;
        self.show.status = @"Failed: Unresumable File";
        self.show.reasonForFailure = @"Unresumable_File";
    }
    else if ([_reasonForFailure isEqualToString:@"FileExists"])
    {
        self.show.complete = @YES;
        self.show.successful = @NO;
        self.show.status = @"Failed: File Exists";
        self.show.reasonForFailure = _reasonForFailure;
    }
    else if ([_reasonForFailure isEqualToString:@"proxy"])
    {
        self.show.complete = @YES;
        self.show.successful = @NO;
        NSString *proxyOption = [[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"];
        if ([proxyOption isEqualToString:@"None"])
        {
            self.show.status = @"Failed: See Log";
            [self addToLog:@"REASON FOR FAILURE: VPN or System Proxy failed. If you are using a VPN or a proxy configured in System Preferences, contact the VPN or proxy provider for assistance." noTag:TRUE];
            [self addToLog:@"If outside the UK, you may also disconnect your VPN and enable the provided proxy in Preferences." noTag:TRUE];
            self.show.reasonForFailure = @"ShowNotFound";
        }
        else if ([proxyOption isEqualToString:@"Provided"])
        {
            self.show.status = @"Failed: Bad Proxy";
            [self addToLog:@"REASON FOR FAILURE: Proxy failed. If in the UK, please disable the proxy in the preferences." noTag:TRUE];
            [self addToLog:@"If outside the UK, please submit a bug report so that the proxy can be updated." noTag:TRUE];
            self.show.reasonForFailure = @"Provided_Proxy";
        }
        else if ([proxyOption isEqualToString:@"Custom"])
        {
            self.show.status = @"Failed: Bad Proxy";
            [self addToLog:@"REASON FOR FAILURE: Proxy failed. If in the UK, please disable the proxy in the preferences." noTag:TRUE];
            [self addToLog:@"If outside the UK, please use a different proxy." noTag:TRUE];
            self.show.reasonForFailure = @"Custom_Proxy";
        }
        [self addToLog:[NSString stringWithFormat:@"%@ Failed",self.show.showName]];
    }
    else if ([_reasonForFailure isEqualToString:@"modes"])
    {
        self.show.complete = @YES;
        self.show.successful = @NO;
        self.show.status = @"Failed: No Specified Modes";
        [self addToLog:@"REASON FOR FAILURE: None of the modes in your download format list are available for this show." noTag:YES];
        [self addToLog:@"Try adding more modes." noTag:YES];
        [self addToLog:[NSString stringWithFormat:@"%@ Failed",self.show.showName]];
        self.show.reasonForFailure = @"Specified_Modes";
        NSLog(@"Set Modes");
    }
    else if ([self.show.reasonForFailure isEqualToString:@"InHistory"])
    {
        NSLog(@"InHistory");
    }
    else if ([_LastLine containsString:@"Permission denied"])
    {
        if ([_LastLine containsString:@"/Volumes"]) //Most likely disconnected external HDD
        {
            self.show.complete = @YES;
            self.show.successful = @NO;
            self.show.status = @"Failed: HDD not Accessible";
            [self addToLog:@"REASON FOR FAILURE: The specified download directory could not be written to." noTag:YES];
            [self addToLog:@"Most likely this is because your external hard drive is disconnected but it could also be a permission issue"
                     noTag:YES];
            [self addToLog:[NSString stringWithFormat:@"%@ Failed",self.show.showName]];
            self.show.reasonForFailure = @"External_Disconnected";
            
        }
        else
        {
            self.show.complete = @YES;
            self.show.successful = @NO;
            self.show.status = @"Failed: Download Directory Unwriteable";
            [self addToLog:@"REASON FOR FAILURE: The specified download directory could not be written to." noTag:YES];
            [self addToLog:@"Please check the permissions on your download directory."
                     noTag:YES];
            [self addToLog:[NSString stringWithFormat:@"%@ Failed",self.show.showName]];
            self.show.reasonForFailure = @"Download_Directory_Permissions";
        }
    }
    else if ([_LastLine hasPrefix:@"WARNING: The BBC has blocked"])
    {
        self.show.complete = @YES;
        self.show.successful = @NO;
        self.show.status = @"Failed: Blocked Access";
        [self addToLog:[NSString stringWithFormat:@"%@ Failed",self.show.showName]];
        self.show.reasonForFailure = @"proxy";
    }
    else if ([_LastLine hasPrefix:@"INFO: Finished recording"])
    {
        self.show.complete = @YES;
        self.show.successful = @YES;
        self.show.status = @"Download Complete";
        NSScanner *scanner = [NSScanner scannerWithString:_LastLine];
        NSString *path;
        
        [scanner scanString:@"INFO: Finished recording " intoString:nil];
        
        [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&path];
        self.show.path = path;
        [self addToLog:[NSString stringWithFormat:@"%@ Completed Successfully",self.show.showName]];
    }
    else if ([scn scanUpToString:@"Already in history" intoString:nil] &&
             [scn scanString:@"Already in" intoString:nil])
    {
        self.show.complete = @YES;
        self.show.successful = @NO;
        self.show.status = @"Failed: Download in History";
        [self addToLog:[NSString stringWithFormat:@"%@ Failed",self.show.showName]];
        self.show.reasonForFailure = @"InHistory";
    }
    else
    {
        self.show.complete = @YES;
        self.show.successful = @NO;
        self.show.status = @"Download Failed";
        [self addToLog:[NSString stringWithFormat:@"%@ Failed",self.show.showName]];
    }
}
- (void)errorDataReadyNotification:(NSNotification *)n
{
    NSData *d = [[n userInfo] valueForKey:NSFileHandleNotificationDataItem];
    [self errorDataReady:d];
}

- (void)errorDataReady:(NSData *)data
{
    if (data.length > 0) {
        NSString *s = [[NSString alloc] initWithData:data
                                            encoding:NSUTF8StringEncoding];
        [self.errorCache appendString:s];
    } else {
        _noDataCount++;
    }
    
    [self.errorPipe.fileHandleForReading readInBackgroundAndNotify];
    
    if (self.noDataCount > 20) {
        [self.processErrorCache invalidate];
    }
}

- (void)processError
{
    if (self.task.isRunning)
    {
        NSString *outp = [self.errorCache copy];
        self.errorCache = [NSMutableString stringWithString:@""];
        if (outp.length > 0) {
            NSArray *array = [outp componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            
            for (NSString *message in array)
            {
                NSString *shortStatus=nil;
                NSScanner *scanner = [NSScanner scannerWithString:message];
                if (message.length == 0){
                    continue;
                }
                else if ([message hasPrefix:@" Progress"]) shortStatus= @"Processing Download.."; //Download Artwork
                else if ([message hasPrefix:@"ERROR:"] || [message hasPrefix:@"\rERROR:"] || [message hasPrefix:@"\nERROR:"]) //Could be unresumable.
                {
                    BOOL isUnresumable = NO;
                    if ([scanner scanUpToString:@"corrupt file!" intoString:nil] && [scanner scanString:@"corrupt file!" intoString:nil])
                    {
                        isUnresumable = YES;
                    }
                    if (!isUnresumable) {
                        scanner.scanLocation = 0;
                        if ([scanner scanUpToString:@"Couldn't find the seeked keyframe in this chunk!" intoString:nil] && [scanner scanString:@"Couldn't find the seeked keyframe in this chunk!" intoString:nil])
                        {
                            isUnresumable = YES;
                        }
                    }
                    if (isUnresumable)
                    {
                        [self addToLog:@"Unresumable file, please delete the partial file and try again." noTag:NO];
                        [self.task interrupt];
                        _reasonForFailure=@"unresumable";
                        self.show.reasonForFailure = @"Unresumable_File";
                    }
                }
                else //Other
                {
                    shortStatus = [NSString stringWithFormat:@"Initialising.. -- %@", [self.show valueForKey:@"showName"]];
                    [self addToLog:message noTag:YES];
                }
                if (shortStatus != nil)
                {
                    [self setCurrentProgress:[NSString stringWithFormat:@"%@ -- %@",shortStatus,[self.show valueForKey:@"showName"]]];
                    [self setPercentage:102];
                    self.show.status = shortStatus;
                }
            }
            
        }
    }
}
- (void)cancelDownload
{
    //Some basic cleanup.
    [self.task interrupt];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:self.fh];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:self.errorFh];
    self.show.status = @"Cancelled";
    [self addToLog:@"Download Cancelled"];
    [self.processErrorCache invalidate];
}
- (void)processGetiPlayerOutput:(NSString *)outp
{
    NSArray *array = [outp componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    //Parse each line individually.
    for (NSString *output in array)
    {
        if ([output hasPrefix:@"INFO: Downloading subtitles"])
        {
            NSScanner *scanner = [NSScanner scannerWithString:output];
            NSString *srtPath;
            [scanner scanString:@"INFO: Downloading Subtitles to \'" intoString:nil];
            [scanner scanUpToString:@".srt\'" intoString:&srtPath];
            srtPath = [srtPath stringByAppendingPathExtension:@"srt"];
            self.show.subtitlePath = srtPath;
        }
        else if ([output hasPrefix:@"INFO: Finished recording"])
        {
            _LastLine = [NSString stringWithString:output];
            _foundLastLine=YES;
        }
        else if ([output hasPrefix:@"INFO: No specified modes"] && [output hasSuffix:@"--modes=)"])
        {
            _reasonForFailure=@"proxy";
            [self addToLog:output noTag:YES];
        }
        else if ([output hasPrefix:@"INFO: No specified modes"])
        {
            _reasonForFailure=@"modes";
            self.show.reasonForFailure = @"Specified_Modes";
            [self addToLog:output noTag:YES];
            NSScanner *modeScanner = [NSScanner scannerWithString:output];
            [modeScanner scanUpToString:@"--modes=" intoString:nil];
            [modeScanner scanString:@"--modes=" intoString:nil];
            NSString *availableModes;
            [modeScanner scanUpToString:@")" intoString:&availableModes];
            self.show.availableModes = availableModes;
        }
        else if ([output hasSuffix:@"use --force to override"])
        {
            self.show.complete = @YES;
            self.show.successful = @NO;
            self.show.status = @"Failed: Download in History";
            [self addToLog:[NSString stringWithFormat:@"%@ Failed",self.show.showName]];
            self.show.reasonForFailure = @"InHistory";
            _foundLastLine=YES;
        }
        else if ([output hasPrefix:@"WARNING: Use --overwrite"])
        {
            self.show.complete = @YES;
            self.show.successful = @NO;
            self.show.status = @"Failed: File already exists";
            [self addToLog:[NSString stringWithFormat:@"%@ Failed",self.show.showName]];
            self.show.reasonForFailure = @"FileExists";
            _foundLastLine=YES;
        }
        else if ([output hasPrefix:@"ERROR: Failed to get version pid"])
        {
            self.show.reasonForFailure = @"ShowNotFound";
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
                self.show.reasonForFailure = @"AudioDescribedOnly";
            }
            [self addToLog:output noTag:YES];
        }
        else if ([output hasPrefix:@"INFO:"] || [output hasPrefix:@"WARNING:"] || [output hasPrefix:@"ERROR:"] ||
                 [output hasSuffix:@"default"] || [output hasPrefix:self.show.pid])
        {
            //Add Status Message to Log
            [self addToLog:output noTag:YES];
        }
        // Thumbnail notification
        else if ([output hasPrefix:@"INFO: Downloading thumbnail"]) {
            self.show.status = @"Downloading Artwork..";
            [self setPercentage:102];
            [self setCurrentProgress:[NSString stringWithFormat:@"Downloading Artwork.. -- %@", self.show.showName]];
        }
        else if ([output hasSuffix:@"[audio+video]"] || [output hasSuffix:@"[audio]"] || [output hasSuffix:@"[video]"]) {
            if (self.verbose) {
                [self addToLog:output noTag:YES];
            }
            //Process iPhone/Radio Downloads Status Message
            NSScanner *scanner = [NSScanner scannerWithString:output];
            NSDecimal percentage, h, m, s;
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]
                                    intoString:nil];
            if(![scanner scanDecimal:&percentage]) percentage = (@0).decimalValue;
            [self setPercentage:[NSDecimalNumber decimalNumberWithDecimal:percentage].doubleValue];
            
            // Jump ahead to the ETA field.
            [scanner scanUpToString:@"ETA: " intoString:nil];
            [scanner scanString:@"ETA: " intoString:nil];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]
                                    intoString:nil];
            if(![scanner scanDecimal:&h]) h = (@0).decimalValue;
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]
                                    intoString:nil];
            if(![scanner scanDecimal:&m]) m = (@0).decimalValue;
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]
                                    intoString:nil];
            if(![scanner scanDecimal:&s]) s = (@0).decimalValue;
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]
                                    intoString:nil];
            
            NSString *eta = [NSString stringWithFormat:@"%.2ld:%.2ld:%.2ld remaining",
                             [NSDecimalNumber decimalNumberWithDecimal:h].integerValue,
                             [NSDecimalNumber decimalNumberWithDecimal:m].integerValue,
                             [NSDecimalNumber decimalNumberWithDecimal:s].integerValue];
            [self setCurrentProgress:eta];
            
            NSString *format = @"Video downloaded: %ld%%";
            
            if ([output hasSuffix:@"[audio+video]"]) {
                format = @"Downloaded %ld%%";
            } else if ([output hasSuffix:@"[audio]"]) {
                format = @"Audio download: %ld%%";
            } else if ([output hasSuffix:@"[video]"]) {
                format = @"Video download: %ld%%";
            }
            
            self.show.status = [NSString stringWithFormat:format,
                                [NSDecimalNumber decimalNumberWithDecimal:percentage].integerValue];
        }
        else if ([output hasPrefix:@"Downloading: "])
        {
            if (self.verbose) {
                [self addToLog:output noTag:YES];
            }
            //Process iPhone/Radio Downloads Status Message
            NSScanner *scanner = [NSScanner scannerWithString:output];
            NSDecimal recieved, total, percentage, speed, ignored;
            NSString *timeRemaining;
            NSString *units;
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]
                                    intoString:nil];
            if(![scanner scanDecimal:&recieved]) recieved = (@0).decimalValue;
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]
                                    intoString:nil];
            if(![scanner scanDecimal:&total]) total = (@0).decimalValue;
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]
                                    intoString:nil];
            
            if (self.verbose) {
                // skip next 8 fields -- elapsed time (H:M:S), expected time (H:M:S), blocks finished/remaining
                for (NSInteger i = 0; i < 8; i++) {
                    [scanner scanDecimal:&ignored];
                    [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]
                                            intoString:nil];
                }
            }
            
            if(![scanner scanDecimal:&percentage]) percentage = (@0).decimalValue;
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]
                                    intoString:nil];
            if(![scanner scanDecimal:&speed]) speed = (@0).decimalValue;
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]
                                    intoString:&units];
            if(![scanner scanUpToString:@"rem" intoString:&timeRemaining]) timeRemaining=@"Unknown";
            
            [self setPercentage:[NSDecimalNumber decimalNumberWithDecimal:percentage].doubleValue];
            if ([NSDecimalNumber decimalNumberWithDecimal:total].doubleValue < 5.00 && [NSDecimalNumber decimalNumberWithDecimal:recieved].doubleValue > 0)
            {
                [self setCurrentProgress:[NSString stringWithFormat:@"%3.1f%% (%3.2fMB/%3.2fMB) - %5.1f %@ -- Getting MOV atom.",
                                          [NSDecimalNumber decimalNumberWithDecimal:percentage].doubleValue,
                                          [NSDecimalNumber decimalNumberWithDecimal:recieved].doubleValue,
                                          [NSDecimalNumber decimalNumberWithDecimal:total].doubleValue,
                                          [NSDecimalNumber decimalNumberWithDecimal:speed].doubleValue,
                                          units]];
                self.show.status = [NSString stringWithFormat:@"Getting MOV atom: %3.1f%%",
                                    [NSDecimalNumber decimalNumberWithDecimal:percentage].doubleValue];
            }
            else if ([NSDecimalNumber decimalNumberWithDecimal:total].doubleValue == 0)
            {
                [self setCurrentProgress:[NSString stringWithFormat:@"%3.1f%% (%3.2fMB/%3.2fMB) - %5.1f %@ -- Initializing..",
                                          [NSDecimalNumber decimalNumberWithDecimal:percentage].doubleValue,
                                          [NSDecimalNumber decimalNumberWithDecimal:recieved].doubleValue,
                                          [NSDecimalNumber decimalNumberWithDecimal:total].doubleValue,
                                          [NSDecimalNumber decimalNumberWithDecimal:speed].doubleValue,
                                          units]];
                self.show.status = [NSString stringWithFormat:@"Initializing: %3.1f%%",
                                    [NSDecimalNumber decimalNumberWithDecimal:percentage].doubleValue];
            }
            else
            {
                [self setCurrentProgress:[NSString stringWithFormat:@"%3.1f%% (%3.2fMB/%3.2fMB) - %.1f %@- %@Remaining -- %@",
                                          [NSDecimalNumber decimalNumberWithDecimal:percentage].doubleValue,
                                          [NSDecimalNumber decimalNumberWithDecimal:recieved].doubleValue,
                                          [NSDecimalNumber decimalNumberWithDecimal:total].doubleValue,
                                          [NSDecimalNumber decimalNumberWithDecimal:speed].doubleValue,
                                          units,
                                          timeRemaining,
                                          self.show.showName]];
                
                self.show.status = [NSString stringWithFormat:@"Downloading: %3.1f%%",
                                    [NSDecimalNumber decimalNumberWithDecimal:percentage].doubleValue];
            }
        }
    }
}

@end
