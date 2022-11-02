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
    NSArray *tvFormatKeys = @[@"Full HD (1080p)", @"HD (720p)", @"SD (540p)", @"Web (396p)", @"Mobile (288p)"];
    NSArray *tvFormatObjects = @[@"fhd",@"hd",@"sd",@"web",@"mobile"];
    NSArray *radioFormatKeys = @[@"High", @"Standard", @"Medium", @"Low"];
    NSArray *radioFormatObjects = @[@"high", @"std", @"med", @"low"];
    
    tvFormats = [[NSDictionary alloc] initWithObjects:tvFormatObjects forKeys:tvFormatKeys];
    radioFormats = [[NSDictionary alloc] initWithObjects:radioFormatObjects forKeys:radioFormatKeys];
}
#pragma mark Overridden Methods
- (instancetype)initWithProgramme:(Programme *)p tvFormats:(NSArray *)tvFormatList radioFormats:(NSArray *)radioFormatList proxy:(HTTPProxy *)aProxy logController:(LogController *)logger
{
    if (self = [super initWithLogController:logger]) {
        self.reasonForFailure = nil;
        self.proxy = aProxy;
        self.show = p;
        [self addToLog:[NSString stringWithFormat:@"Downloading %@", self.show.showName]];

        //Initialize Formats
        if (!tvFormats || !radioFormats) {
            [BBCDownload initFormats];
        }
        NSMutableString *formatArg = [[NSMutableString alloc] initWithString:@"--quality="];
        NSMutableArray *formatStrings = [NSMutableArray array];

        if (self.show.radio) {
            for (RadioFormat *format in radioFormatList) {
                [formatStrings addObject:[radioFormats valueForKey:format.format]];
            }
        } else {
            for (TVFormat *format in tvFormatList) {
                [formatStrings addObject:[tvFormats valueForKey:format.format]];
            }
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
        NSString *noWarningArg = [GetiPlayerArguments sharedController].noWarningArg;
        NSString *noPurgeArg = @"--nopurge";
        NSString *atomicParsleyArg = [[NSString alloc] initWithFormat:@"--atomicparsley=%@", [[[AppController sharedController] extraBinariesPath] stringByAppendingPathComponent:@"AtomicParsley"]];
        NSString *ffmpegArg = [[NSString alloc] initWithFormat:@"--ffmpeg=%@", [[[AppController sharedController] extraBinariesPath] stringByAppendingPathComponent:@"ffmpeg"]];
        NSString *downloadPathArg = [[NSString alloc] initWithFormat:@"--output=%@", self.downloadPath];
        NSString *subDirArg = @"--subdir";
        NSString *progressArg = @"--logprogress";
        
        NSString *getArg = @"--pid";
        NSString *searchArg = self.show.pid;
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
        NSString *cacheExpiryArg = [[GetiPlayerArguments sharedController] cacheExpiryArg];
        NSString *profileDirArg = [[GetiPlayerArguments sharedController] profileDirArg];
        
        //Add Arguments that can't be NULL
        NSMutableArray *args = [[NSMutableArray alloc] initWithObjects:
                                [[AppController sharedController] getiPlayerPath],
                                profileDirArg,
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
            [args addObject:@"--tv-lower-bitrate"];
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

        self.task = [NSTask new];
        self.pipe = [NSPipe new];
        self.errorPipe = [NSPipe new];

        self.task.arguments = args;
        self.task.launchPath = [[AppController sharedController] perlBinaryPath];
        self.task.standardOutput = self.pipe;
        self.task.standardError = self.errorPipe;
        
        NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:self.task.environment];
        envVariableDictionary[@"HOME"] = (@"~").stringByExpandingTildeInPath;
        envVariableDictionary[@"PERL_UNICODE"] = @"AS";
        envVariableDictionary[@"PATH"] = [[AppController sharedController] perlEnvironmentPath];
        self.task.environment = envVariableDictionary;
        
        NSFileHandle *fh = self.pipe.fileHandleForReading;
        NSFileHandle *errorFh = self.errorPipe.fileHandleForReading;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(downloadDataNotification:)
                                                     name:NSFileHandleReadCompletionNotification
                                                   object:fh];
        [fh readInBackgroundAndNotify];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(downloadDataNotification:)
                                                     name:NSFileHandleReadCompletionNotification
                                                   object:errorFh];
        [errorFh readInBackgroundAndNotify];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(downloadFinished:)
                                                     name:NSTaskDidTerminateNotification
                                                   object:self.task];

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
    NSData *data = [[n userInfo] valueForKey:NSFileHandleNotificationDataItem];

    if (data.length > 0) {
        NSString *s = [[NSString alloc] initWithData:data
                                            encoding:NSUTF8StringEncoding];
        [self processGetiPlayerOutput:s];
    }

    NSFileHandle *fh = (NSFileHandle *)[n object];
    [fh readInBackgroundAndNotify];
}

-(void)downloadFinished:(NSNotification *)notification {
    if (runDownloads) {
        [self completeDownload];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:self.show];

    self.task = nil;
    self.pipe = nil;
    self.errorPipe = nil;
}

- (void)completeDownload {

    // If we have a path it was successful. Note that and return.
    if (self.show.path.length > 0) {
        self.show.complete = YES;
        self.show.successful = YES;
        self.show.status = @"Download Complete";
        return;
    }

    // Handle all other error cases.
    self.show.complete = YES;
    self.show.successful = NO;

    if (self.reasonForFailure) {
        self.show.reasonForFailure = self.reasonForFailure;
    }

    if ([self.reasonForFailure isEqualToString:@"FileExists"]) {
        self.show.status = @"Failed: File already exists";
        [self addToLog:[NSString stringWithFormat:@"%@ Failed",self.show.showName]];
    } else if ([self.reasonForFailure isEqualToString:@"ShowNotFound"]) {
        self.show.status = @"Failed: PID not found";
    } else if ([self.reasonForFailure isEqualToString:@"proxy"]) {
        NSString *proxyOption = [[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"];
        if ([proxyOption isEqualToString:@"None"]) {
            self.show.status = @"Failed: See Log";
            [self addToLog:@"REASON FOR FAILURE: VPN or System Proxy failed. If you are using a VPN or a proxy configured in System Preferences, contact the VPN or proxy provider for assistance." noTag:TRUE];
            self.show.reasonForFailure = @"ShowNotFound";
        } else if ([proxyOption isEqualToString:@"Provided"]) {
            self.show.status = @"Failed: Bad Proxy";
            [self addToLog:@"REASON FOR FAILURE: Proxy failed. If in the UK, please disable the proxy in the preferences." noTag:TRUE];
            self.show.reasonForFailure = @"Provided_Proxy";
        } else if ([proxyOption isEqualToString:@"Custom"]) {
            self.show.status = @"Failed: Bad Proxy";
            [self addToLog:@"REASON FOR FAILURE: Proxy failed. If in the UK, please disable the proxy in the preferences." noTag:TRUE];
            [self addToLog:@"If outside the UK, please use a different proxy." noTag:TRUE];
            self.show.reasonForFailure = @"Custom_Proxy";
        }
        
        [self addToLog:[NSString stringWithFormat:@"%@ Failed",self.show.showName]];
    } else if ([self.reasonForFailure isEqualToString:@"Specified_Modes"]) {
        self.show.status = @"Failed: No Specified Modes";
        [self addToLog:@"REASON FOR FAILURE: None of the modes in your download format list are available for this show." noTag:YES];
        [self addToLog:@"Try adding more modes." noTag:YES];
        [self addToLog:[NSString stringWithFormat:@"%@ Failed",self.show.showName]];
        NSLog(@"Set Modes");
    } else if ([self.reasonForFailure isEqualToString:@"InHistory"]) {
        self.show.status = @"Failed: In download history";
        NSLog(@"InHistory");
    } else if ([self.reasonForFailure isEqualToString:@"AudioDescribedOnly"]) {
        self.show.reasonForFailure = @"AudioDescribedOnly";
    } else if ([self.reasonForFailure isEqualToString:@"External_Disconnected"]) {
        self.show.status = @"Failed: HDD not Accessible";
        [self addToLog:@"REASON FOR FAILURE: The specified download directory could not be written to." noTag:YES];
        [self addToLog:@"Most likely this is because your external hard drive is disconnected but it could also be a permission issue"
                 noTag:YES];
        [self addToLog:[NSString stringWithFormat:@"%@ Failed",self.show.showName]];
    } else if ([self.reasonForFailure isEqualToString:@"Download_Directory_Permissions"]) {
        self.show.status = @"Failed: Download Directory Unwriteable";
        [self addToLog:@"REASON FOR FAILURE: The specified download directory could not be written to." noTag:YES];
        [self addToLog:@"Please check the permissions on your download directory."
                 noTag:YES];
        [self addToLog:[NSString stringWithFormat:@"%@ Failed",self.show.showName]];
    } else {
        // Failed for an unknown reason.
        self.show.status = @"Download Failed";
        [self addToLog:[NSString stringWithFormat:@"%@ Failed",self.show.showName]];
    }
}

- (void)processGetiPlayerOutput:(NSString *)outp
{
    NSArray *array = [outp componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    //Parse each line individually.
    for (NSString *output in array)
    {
        if ([output hasPrefix:@"DEBUG:"]) {
            continue;
        }

        if (self.verbose) {
            if (output.length > 0) {
                [self addToLog:output noTag:YES];
            }
        }
        
        if ([output hasPrefix:@"INFO: Downloading subtitles"])
        {
            NSScanner *scanner = [NSScanner scannerWithString:output];
            NSString *srtPath;
            [scanner scanString:@"INFO: Downloading Subtitles to \'" intoString:nil];
            [scanner scanUpToString:@".srt\'" intoString:&srtPath];
            srtPath = [srtPath stringByAppendingPathExtension:@"srt"];
            self.show.subtitlePath = srtPath;
        }
        else if ([output hasPrefix:@"INFO: Wrote file "])
        {
            NSScanner *scanner = [NSScanner scannerWithString:output];
            NSString *path;
            [scanner scanString:@"INFO: Wrote file " intoString:nil];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&path];
            self.show.path = path;
        }
        else if ([output hasPrefix:@"INFO: No specified modes"] && [output hasSuffix:@"--quality=)"])
        {
            self.reasonForFailure = @"Specified_Modes";
            NSScanner *modeScanner = [NSScanner scannerWithString:output];
            [modeScanner scanUpToString:@"--quality=" intoString:nil];
            [modeScanner scanString:@"--quality=" intoString:nil];
            NSString *availableModes;
            [modeScanner scanUpToString:@")" intoString:&availableModes];
            self.show.availableModes = availableModes;
        } else if ([output hasSuffix:@"use --force to override"]) {
            self.reasonForFailure = @"InHistory";
        } else if ([output containsString:@"Permission denied"]) {
            if ([output containsString:@"/Volumes"]) { //Most likely disconnected external HDD {
                self.reasonForFailure = @"External_Disconnected";
            } else {
                self.reasonForFailure = @"Download_Directory_Permissions";
            }
        } else if ([output hasPrefix:@"WARNING: Use --overwrite"]) {
            self.reasonForFailure = @"FileExists";
        } else if ([output hasPrefix:@"ERROR: Failed to get version pid"]) {
            self.reasonForFailure = @"ShowNotFound";
        } else if ([output hasPrefix:@"WARNING: If you use a VPN"] || [output hasSuffix:@"blocked by the BBC"]) {
            self.reasonForFailure = @"proxy";
        } else if ([output hasPrefix:@"WARNING: No programmes are available for this pid with version(s):"] ||
                 [output hasPrefix:@"INFO: No versions of this programme were selected"]) {
            NSScanner *versionScanner = [NSScanner scannerWithString:output];
            [versionScanner scanUpToString:@"available versions:" intoString:nil];
            [versionScanner scanString:@"available versions:" intoString:nil];
            [versionScanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
            NSString *availableVersions;
            [versionScanner scanUpToString:@")" intoString:&availableVersions];
            if ([availableVersions rangeOfString:@"audiodescribed"].location != NSNotFound ||
                [availableVersions rangeOfString:@"signed"].location != NSNotFound)
            {
                self.reasonForFailure = @"AudioDescribedOnly";
            }
        } else if ([output hasPrefix:@"INFO: Downloading thumbnail"]) {
            self.show.status = @"Downloading Artwork..";
            [self setPercentage:102];
            [self setCurrentProgress:[NSString stringWithFormat:@"Downloading Artwork.. -- %@", self.show.showName]];
        } else if ([output hasPrefix:@"INFO:"] || [output hasPrefix:@"WARNING:"] || [output hasPrefix:@"ERROR:"] ||
                   [output hasSuffix:@"default"] || [output hasPrefix:self.show.pid]) {
            // Do nothing! This ensures we don't process any other info messages
        } else if ([output hasSuffix:@"[audio+video]"] || [output hasSuffix:@"[audio]"] || [output hasSuffix:@"[video]"]) {
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
    }
}

@end
