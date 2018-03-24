//
//  Download.m
//  
//
//  Created by Thomas Willson on 12/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Download.h"

@implementation Download

- (instancetype)init {
    if (self = [super init]) {
        //Prepare Time Remaining
        _rateEntries = [[NSMutableArray alloc] initWithCapacity:50];
        _running=YES;
        _lastDownloaded=0;
        _outOfRange=0;
        _verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose"];
        _downloadParams = [[NSMutableDictionary alloc] init];
        _errorCache = [[NSMutableString alloc] init];
        _processErrorCache = [NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(processError) userInfo:nil repeats:YES];
        _isTest=false;
        _defaultsPrefix = @"BBC_";
        
        _log = [[NSMutableString alloc] initWithString:@""];
//        _nc = [NSNotificationCenter defaultCenter];
        _downloadPath = [[NSString alloc] initWithString:[[NSUserDefaults standardUserDefaults] valueForKey:@"DownloadPath"]];
        _task = [[NSTask alloc] init];
        _pipe = [[NSPipe alloc] init];
        _errorPipe = [[NSPipe alloc] init];
        


    }
    return self;
}
- (instancetype)initWithLogController:(LogController *)logger {
    if (self = [self init]) {
        _logger = logger;
    }
    return self;
}

#pragma mark Notification Posters
- (void)logDebugMessage:(NSString *)message noTag:(BOOL)b {
    NSLog(@"%@", message);
    
    if (self.verbose) {
        [self addToLog:message noTag:b];
    }
}

- (void)addToLog:(NSString *)logMessage noTag:(BOOL)b
{
	if (b)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"AddToLog" object:nil userInfo:@{@"message": logMessage}];
	}
	else
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"AddToLog" object:self userInfo:@{@"message": logMessage}];
	}
    [self.log appendFormat:@"%@\n", logMessage];
}
- (void)addToLog:(NSString *)logMessage
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"AddToLog" object:self userInfo:@{@"message": logMessage}];
    [self.log appendFormat:@"%@\n", logMessage];
}
- (void)setCurrentProgress:(NSString *)string
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"setCurrentProgress" object:self userInfo:@{@"string": string}];
}
- (void)setPercentage:(double)d
{
	if (d<=100.0)
	{
		NSNumber *value = @(d);
		[[NSNotificationCenter defaultCenter] postNotificationName:@"setPercentage" object:self userInfo:@{@"nsDouble": value}];
	}
	else
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"setPercentage" object:self userInfo:nil];
	}
}

#pragma mark Message Processers
- (void)processFLVStreamerMessage:(NSString *)message
{
    NSScanner *scanner = [NSScanner scannerWithString:message];
    scanner.scanLocation = 0;
    [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
    double downloaded, elapsed, percent, total;
    if ([scanner scanDouble:&downloaded])
    {
        [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
        if (![scanner scanDouble:&elapsed]) elapsed=0.0;
        [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
        if (![scanner scanDouble:&percent]) percent=102.0;
        if (downloaded>0 && percent>0 && percent!=102) total = ((downloaded/1024)/(percent/100));
        else total=0;
        if (percent != 102) {
            [_show setValue:[NSString stringWithFormat:@"Downloading: %.1f%%", percent] forKey:@"status"];
        }
        else {
            [_show setValue:@"Downloading..." forKey:@"status"];
        }
        [self setPercentage:percent];
        
        //Calculate Time Remaining
        downloaded/=1024;
        if (total>0 && downloaded>0 && percent>0)
        {
            if (_rateEntries.count >= 50)
            {
                double rateSum, rateAverage;
                double rate = ((downloaded-_lastDownloaded)/(-_lastDate.timeIntervalSinceNow));
                double oldestRate = [_rateEntries[0] doubleValue];
                if (rate < (_oldRateAverage*5) && rate > (_oldRateAverage/5) && rate < 50)
                {
                    [_rateEntries removeObjectAtIndex:0];
                    [_rateEntries addObject:@(rate)];
                    _outOfRange=0;
                    rateSum= (_oldRateAverage*50)-oldestRate+rate;
                    rateAverage = _oldRateAverage = rateSum/50;
                }
                else 
                {
                    _outOfRange++;
                    rateAverage = _oldRateAverage;
                    if (_outOfRange>10)
                    {
                        _rateEntries = [[NSMutableArray alloc] initWithCapacity:50];
                        _outOfRange=0;
                    }
                }
                
                _lastDownloaded=downloaded;
                _lastDate = [NSDate date];
                NSDate *predictedFinished = [NSDate dateWithTimeIntervalSinceNow:(total-downloaded)/rateAverage];
                
                unsigned int unitFlags = NSHourCalendarUnit | NSMinuteCalendarUnit;
                NSDateComponents *conversionInfo = [[NSCalendar currentCalendar] components:unitFlags fromDate:_lastDate toDate:predictedFinished options:0];
                
                [self setCurrentProgress:[NSString stringWithFormat:@"%.1f%% - (%.2f MB/~%.0f MB) - %02ld:%02ld Remaining -- %@",percent,downloaded,total,(long)conversionInfo.hour,(long)conversionInfo.minute,[_show valueForKey:@"showName"]]];
            }
            else 
            {
                if (_lastDownloaded>0 && _lastDate)
                {
                    double rate = ((downloaded-_lastDownloaded)/(-_lastDate.timeIntervalSinceNow));
                    if (rate<50)
                    {
                        [_rateEntries addObject:@(rate)];
                    }
                    _lastDownloaded=downloaded;
                    _lastDate = [NSDate date];
                    if (_rateEntries.count>48)
                    {
                        double rateSum=0;
                        for (NSNumber *entry in _rateEntries)
                        {
                            rateSum+=entry.doubleValue;
                        }
                        _oldRateAverage = rateSum/_rateEntries.count;
                    }
                }
                else 
                {
                    _lastDownloaded=downloaded;
                    _lastDate = [NSDate date];
                }
                if (percent != 102)
                    [self setCurrentProgress:[NSString stringWithFormat:@"%.1f%% - (%.2f MB/~%.0f MB) -- %@",percent,downloaded,total,[_show valueForKey:@"showName"]]];
                else
                    [self setCurrentProgress:[NSString stringWithFormat:@"%.2f MB Downloaded -- %@",downloaded/1024,_show.showName]];
            }
        }
        else
        {
            [self setCurrentProgress:[NSString stringWithFormat:@"%.2f MB Downloaded -- %@",downloaded,_show.showName]];
        }
    }
}
- (void)rtmpdumpFinished:(NSNotification *)finishedNote
{
    [self addToLog:@"RTMPDUMP finished"];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:self.fh];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:self.errorFh];
    [self.processErrorCache invalidate];
    
    NSInteger exitCode=[finishedNote.object terminationStatus];
    NSLog(@"Exit Code = %ld",(long)exitCode);
    if (exitCode==0) //RTMPDump is successful
    {
        _show.complete = @YES;
        _show.successful = @YES;
        NSDictionary *info = @{@"Programme": _show};
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AddProgToHistory" object:self userInfo:info];
        
        _ffTask = [[NSTask alloc] init];
        _ffPipe = [[NSPipe alloc] init];
        _ffErrorPipe = [[NSPipe alloc] init];
        
        _ffTask.standardOutput = _ffPipe;
        _ffTask.standardError = _ffErrorPipe;
        
        _ffFh = _ffPipe.fileHandleForReading;
        _ffErrorFh = _ffErrorPipe.fileHandleForReading;
        
        NSString *completeDownloadPath = _downloadPath.stringByDeletingPathExtension.stringByDeletingPathExtension;
        completeDownloadPath = [completeDownloadPath stringByAppendingPathExtension:@"mp4"];
        _show.path = completeDownloadPath;
        
        _ffTask.launchPath = [([NSBundle mainBundle].executablePath).stringByDeletingLastPathComponent stringByAppendingPathComponent:@"ffmpeg"];
        
        _ffTask.arguments = @[@"-i",[NSString stringWithFormat:@"%@", _downloadPath],
                              @"-vcodec",@"copy",
                              @"-acodec",@"copy",
                              [NSString stringWithFormat:@"%@",completeDownloadPath]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
               selector:@selector(DownloadDataReady:)
                   name:NSFileHandleReadCompletionNotification
                 object:_ffFh];
        [[NSNotificationCenter defaultCenter] addObserver:self 
               selector:@selector(DownloadDataReady:) 
                   name:NSFileHandleReadCompletionNotification 
                 object:_ffErrorFh];
        [[NSNotificationCenter defaultCenter] addObserver:self 
               selector:@selector(ffmpegFinished:) 
                   name:NSTaskDidTerminateNotification 
                 object:_ffTask];
        
        [_ffTask launch];
        [_ffFh readInBackgroundAndNotify];
        [_ffErrorFh readInBackgroundAndNotify];
        
        [self setCurrentProgress:[NSString stringWithFormat:@"Converting... -- %@",_show.showName]];
        _show.status = @"Converting...";
        [self addToLog:@"INFO: Converting FLV File to MP4" noTag:YES];
        [self setPercentage:102];
    }
    else if (exitCode==1 && _running) //RTMPDump could not resume
    {
        if ([_task.arguments.lastObject isEqualTo:@"--resume"])
        {
            [[NSFileManager defaultManager] removeItemAtPath:_downloadPath error:nil];
            [self addToLog:@"WARNING: Download couldn't be resumed. Overwriting partial file." noTag:YES];
            [self addToLog:@"INFO: Preparing Request for Auth Info" noTag:YES];
            [self launchMetaRequest];
            return;
        }
        else if (_attemptNumber < 4) //some other reason, so retry
        {
            _attemptNumber++;
            [self addToLog:[NSString stringWithFormat:@"WARNING: Trying download again. Attempt %ld/4",(long)_attemptNumber] noTag:YES];
            [self launchMetaRequest];
        }
        else // give up
        {
            _show.successful = @NO;
            _show.complete = @YES;
            _show.reasonForFailure = @"Unknown";
            [[NSNotificationCenter defaultCenter] removeObserver:self];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:_show];
            [_show setValue:@"Download Failed" forKey:@"status"];
        }
    }
    else if (exitCode==2 && _attemptNumber<4 && _running) //RTMPDump lost connection but should be able to resume.
    {
        _attemptNumber++;
        [self addToLog:[NSString stringWithFormat:@"WARNING: Trying download again. Attempt %ld/4",(long)_attemptNumber] noTag:YES];
        [self launchMetaRequest];
    }
    else //Some undocumented exit code or too many attempts
    {
        _show.successful = @NO;
        _show.complete = @YES;
        _show.reasonForFailure = @"Unknown";
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:_show];
        [_show setValue:@"Download Failed" forKey:@"status"];
    }
    [_processErrorCache invalidate];
}
- (void)ffmpegFinished:(NSNotification *)finishedNote
{
    NSLog(@"Conversion Finished");
    [self addToLog:@"INFO: Finished Converting." noTag:YES];
    if ([finishedNote.object terminationStatus] == 0)
    {
        [[NSFileManager defaultManager] removeItemAtPath:_downloadPath error:nil];
        if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"TagShows"] boolValue])
        {
            [_show setValue:@"Tagging..." forKey:@"status"];
            [self setPercentage:102];
            [self setCurrentProgress:[NSString stringWithFormat:@"Downloading Thumbnail... -- %@",_show.showName]];
            [self addToLog:@"INFO: Tagging the Show" noTag:YES];
            if (_thumbnailURL)
            {
                [self addToLog:@"INFO: Downloading thumbnail" noTag:YES];
                NSURL *filePath = [NSURL fileURLWithPath:_show.path];
                filePath = [filePath URLByAppendingPathExtension:@"jpg"];
                _thumbnailPath = [filePath path];
                NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithURL: [NSURL URLWithString:_thumbnailURL] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                    [self thumbnailRequestFinished:location];
                }];
                
                [downloadTask resume];
            }
            else
            {
                [self thumbnailRequestFinished:nil];
            }
        }
        else
        {
            [self atomicParsleyFinished:nil];
        }
    }
    else
    {
        [self addToLog:[NSString stringWithFormat:@"INFO: Exit Code = %ld",(long)[finishedNote.object terminationStatus]] noTag:YES];
        [_show setValue:@"Download Complete" forKey:@"status"];
        _show.path = _downloadPath;
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:_show];
    }
}

- (void)thumbnailRequestFinished:(NSURL *)location
{
    [self addToLog:@"INFO: Thumbnail Download Completed" noTag:YES];
   
    if (location) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *destinationURL = [NSURL fileURLWithPath:_thumbnailPath];
        NSError *error = nil;
        [fm removeItemAtPath:_thumbnailPath error:&error];
        if (![fm copyItemAtURL:location toURL:destinationURL error:&error]) {
            NSLog(@"Unable to save downloaded thumbnail: %@", error.description);
            [self addToLog:@"INFO: Thumbnail Download Failed" noTag:YES];
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        self.apTask = [[NSTask alloc] init];
        self.apPipe = [[NSPipe alloc] init];
        self.apFh = self.apPipe.fileHandleForReading;

        self.apTask.launchPath = [([NSBundle mainBundle].executablePath).stringByDeletingLastPathComponent stringByAppendingPathComponent:@"AtomicParsley"];
        
        NSMutableArray *arguments = [NSMutableArray arrayWithObjects:
                                     [NSString stringWithFormat:@"%@",self.show.path],
                                     @"--stik",@"value=10",
                                     @"--TVNetwork",self.show.tvNetwork,
                                     @"--TVShowName",self.show.seriesName,
                                     @"--TVSeasonNum",[NSString stringWithFormat:@"%ld",(long)self.show.season],
                                     @"--TVEpisodeNum",[NSString stringWithFormat:@"%ld",(long)self.show.episode],
                                     @"--TVEpisode",self.show.episodeName,
                                     @"--title",self.show.showName,
                                     @"--artwork", self.thumbnailPath,
                                     @"--comment",self.show.desc,
                                     @"--description",self.show.desc,
                                     @"--longdesc",self.show.desc,
                                     @"--lyrics",self.show.desc,
                                     @"--artist",self.show.tvNetwork,
                                     @"--overWrite",
                                     nil];
       
        if (self.show.standardizedAirDate) {
            [arguments addObject: @"--year"];
            [arguments addObject:self.show.standardizedAirDate];
        }
            
        self.apTask.arguments = arguments;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(DownloadDataReady:)
                                                     name:NSFileHandleReadCompletionNotification
                                                   object:self.apFh];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(atomicParsleyFinished:)
                                                     name:NSTaskDidTerminateNotification
                                                   object:self.apTask];
        
        [self addToLog:@"INFO: Beginning AtomicParsley Tagging." noTag:YES];
        
        [self.apTask launch];
        [self.apFh readInBackgroundAndNotify];
        [self setCurrentProgress:[NSString stringWithFormat:@"Tagging the Programme... -- %@",self.show.showName]];
    });
}
- (void)atomicParsleyFinished:(NSNotification *)finishedNote
{
    if (finishedNote)
    {
        if ([finishedNote.object terminationStatus] == 0)
        {
            [[NSFileManager defaultManager] removeItemAtPath:_thumbnailPath error:nil];
            [self addToLog:@"INFO: AtomicParsley Tagging finished." noTag:YES];
        }
        else
            [self addToLog:@"INFO: Tagging failed." noTag:YES];
    }
    
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"DownloadSubtitles"] boolValue])
    {
        if (_subtitlePath && [[NSFileManager defaultManager] fileExistsAtPath:_subtitlePath]) {
            if (![_subtitlePath.pathExtension isEqual: @"srt"])
            {
                [_show setValue:@"Converting Subtitles..." forKey:@"status"];
                [self setPercentage:102];
                [self setCurrentProgress:[NSString stringWithFormat:@"Converting Subtitles... -- %@",_show.showName]];
                [self addToLog:@"INFO: Converting Subtitles..." noTag:YES];
                [self convertSubtitles];
            } else {
                [self convertSubtitlesFinished:nil];
            }
        }
    } else {
        [self convertSubtitlesFinished:nil];
    }
}

- (void)convertSubtitles
{
    if (!_subtitlePath) {
        [self convertSubtitlesFinished:nil];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self addToLog:[NSString stringWithFormat:@"INFO: Converting to SubRip: %@", self.subtitlePath] noTag:YES];
            
            NSURL *outputURL = [NSURL fileURLWithPath:self.subtitlePath];
            outputURL = [[outputURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"srt"];
            NSMutableArray *args = [[NSMutableArray alloc] init];

            // TODO: Figure out if I can bring this back. ffmpeg doesn't support it.
//            BOOL srtIgnoreColors = [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"%@SRTIgnoreColors", self.defaultsPrefix]];
//            if (srtIgnoreColors)
//            {
//                [args addObject:@"--srt-ignore-colors"];
//            }
            
            [args addObject:@"-i"];
            [args addObject:self.subtitlePath];
            [args addObject:[outputURL path]];

            self.subsTask = [[NSTask alloc] init];
            self.subsErrorPipe = [[NSPipe alloc] init];
            self.subsTask.standardError = self.subsErrorPipe;
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(convertSubtitlesFinished:) name:NSTaskDidTerminateNotification object:self.subsTask];
            
            NSURL *ffmpegURL = [[[[NSBundle mainBundle] executableURL] URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"ffmpeg"];
            self.subsTask.launchPath = [ffmpegURL path];
            self.subsTask.arguments = args;
            [self.subsTask launch];
        });
    }
}
- (void)convertSubtitlesFinished:(NSNotification *)aNotification
{
    if (aNotification)
    {
        // Should not get inside this code for ITV (webvtt) subtitles.
        if ([aNotification.object terminationStatus] == 0)
        {
            BOOL keepRawSubtitles = [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"%@KeepRawSubtitles", _defaultsPrefix]];
            if (!keepRawSubtitles)
            {
                [[NSFileManager defaultManager] removeItemAtPath:_subtitlePath error:nil];
            }
            [self addToLog:[NSString stringWithFormat:@"INFO: Conversion to SubRip complete: %@", [_show.path.stringByDeletingPathExtension stringByAppendingPathExtension:@"srt"]] noTag:YES];
        }
        else
        {
            [self addToLog:[NSString stringWithFormat:@"ERROR: Conversion to SubRip failed: %@", _subtitlePath] noTag:YES];
            NSData *errData = [_subsErrorPipe.fileHandleForReading readDataToEndOfFile];
            if (errData.length > 0)
            {
                NSString *errOutput = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
                [self addToLog:errOutput noTag:YES];
            }
        }
    }
    [_show setValue:@"Download Complete" forKey:@"status"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:_show];
}
- (void)DownloadDataReady:(NSNotification *)note
{
    NSData *data = [note.userInfo valueForKey:NSFileHandleNotificationDataItem];
    if (data.length > 0) {
		NSString *s = [[NSString alloc] initWithData:data
											encoding:NSUTF8StringEncoding];
		[self processGetiPlayerOutput:s];
	}
}
- (void)ErrorDataReady:(NSNotification *)note
{
	[_errorPipe.fileHandleForReading readInBackgroundAndNotify];
	NSData *d;
    d = [note.userInfo valueForKey:NSFileHandleNotificationDataItem];
    if (d.length > 0)
	{
		[_errorCache appendString:[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]];
	}
}
- (void)processGetiPlayerOutput:(NSString *)output
{
	NSArray *array = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	for (NSString *outputLine in array)
	{
        if (![outputLine hasPrefix:@"frame="])
            [self addToLog:outputLine noTag:YES];
    }
}
- (void)processError
{
	//Separate the output by line.
	NSString *string = [[NSString alloc] initWithString:_errorCache];
    _errorCache = [NSMutableString stringWithString:@""];
	NSArray *array = [string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	//Parse each line individually.
	for (NSString *output in array)
	{
        NSScanner *scanner = [NSScanner scannerWithString:output];
        if ([scanner scanFloat:nil])
        {
            [self processFLVStreamerMessage:output];
        }
        else
            if(output.length > 1) [self addToLog:output noTag:YES];
    }
}
-(void)launchRTMPDumpWithArgs:(NSArray *)args
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:[_downloadPath.stringByDeletingPathExtension.stringByDeletingPathExtension stringByAppendingPathExtension:@"mp4"]])
    {
        [self addToLog:@"ERROR: Destination file already exists." noTag:YES];
        _show.complete = @YES;
        _show.successful = @NO;
        [_show setValue:@"Download Failed" forKey:@"status"];
        _show.reasonForFailure = @"FileExists";
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:_show];
        return;
    }
    else if ([[NSFileManager defaultManager] fileExistsAtPath:_downloadPath])
    {
        [self addToLog:@"WARNING: Partial file already exists...attempting to resume" noTag:YES];
        args = [args arrayByAddingObject:@"--resume"];
    }

    NSMutableString *cmd = [NSMutableString stringWithCapacity:0];
    [cmd appendString:[NSString stringWithFormat:@"\"%@\"", [([NSBundle mainBundle].executablePath).stringByDeletingLastPathComponent stringByAppendingPathComponent:@"rtmpdump"]]];
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"-"] || [arg hasPrefix:@"\""])
            [cmd appendString:[NSString stringWithFormat:@" %@", arg]];
        else
            [cmd appendString:[NSString stringWithFormat:@" \"%@\"", arg]];
    }
    NSLog(@"DEBUG: RTMPDump command: %@", cmd);
    if (_verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: RTMPDump command: %@", cmd] noTag:YES];
    
    _task = [[NSTask alloc] init];
    _pipe = [[NSPipe alloc] init];
    _errorPipe = [[NSPipe alloc] init];
    _task.launchPath = [([NSBundle mainBundle].executablePath).stringByDeletingLastPathComponent stringByAppendingPathComponent:@"rtmpdump"];
    
    /* rtmpdump -r "rtmpe://cp72511.edgefcs.net/ondemand?auth=eaEc.b4aodIcdbraJczd.aKchaza9cbdTc0cyaUc2aoblaLc3dsdkd5d9cBduczdLdn-bo64cN-eS-6ys1GDrlysDp&aifp=v002&slist=production/" -W http://www.itv.com/mediaplayer/ITVMediaPlayer.swf?v=11.20.654 -y "mp4:production/priority/CATCHUP/e48ab1e2/1a73/4620/adea/dda6f21f45ee/1-6178-0002-001_THE-ROYAL-VARIETY-PERFORMANCE-2011_TX141211_ITV1200_16X9.mp4" -o test2 */
    
    _task.arguments = [NSArray arrayWithArray:args];
    
    
    _task.standardOutput = _pipe;
    _task.standardError = _errorPipe;
    _fh = _pipe.fileHandleForReading;
	_errorFh = _errorPipe.fileHandleForReading;
    
    NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:_task.environment];
    envVariableDictionary[@"PERL_UNICODE"] = @"AS";
    envVariableDictionary[@"HOME"] = (@"~").stringByExpandingTildeInPath;
    NSString *perlPath = [[NSBundle mainBundle] resourcePath];
    perlPath = [perlPath stringByAppendingPathComponent:@"perl5"];
    envVariableDictionary[@"PERL5LIB"] = perlPath;
    _task.environment = envVariableDictionary;
    
	
	[[NSNotificationCenter defaultCenter] addObserver:self
		   selector:@selector(DownloadDataReady:)
			   name:NSFileHandleReadCompletionNotification
			 object:_fh];
	[[NSNotificationCenter defaultCenter] addObserver:self
		   selector:@selector(ErrorDataReady:)
			   name:NSFileHandleReadCompletionNotification
			 object:_errorFh];
    [[NSNotificationCenter defaultCenter] addObserver:self
           selector:@selector(rtmpdumpFinished:)
               name:NSTaskDidTerminateNotification
             object:_task];
    
    [self addToLog:@"INFO: Launching RTMPDUMP..." noTag:YES];
	[_task launch];
	[_fh readInBackgroundAndNotify];
	[_errorFh readInBackgroundAndNotify];
	[_show setValue:@"Initialising..." forKey:@"status"];
	
	//Prepare UI
	[self setCurrentProgress:[NSString stringWithFormat:@"Initialising RTMPDump... -- %@",_show.showName]];
    [self setPercentage:102];
}
- (void)launchMetaRequest
{
    [[NSException exceptionWithName:@"InvalidDownload" reason:@"Launch Meta Request shouldn't be called on base class." userInfo:nil] raise];
}
- (void)createDownloadPath
{
    NSString *fileName = _show.showName;
    // XBMC naming
	if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"XBMC_naming"] boolValue]) {
        if (_show.seriesName)
            fileName = _show.seriesName;
        if (!_isFilm) {
            if (!_show.season) {
                _show.season = 1;
                if (!_show.episode) {
                    _show.episode = 1;
                }
            }
            NSString *format = _show.episodeName ? @"%@.s%02lde%02ld.%@" : @"%@.s%02lde%02ld";
            fileName = [NSString stringWithFormat:format, fileName, (long)_show.season, (long)_show.episode, _show.episodeName];
        }
	}
    //Create Download Path
    NSString *dirName = _show.seriesName;
    if (!dirName)
        dirName = _show.showName;
    _downloadPath = [[NSUserDefaults standardUserDefaults] valueForKey:@"DownloadPath"];
    _downloadPath = [_downloadPath stringByAppendingPathComponent:[[dirName stringByReplacingOccurrencesOfString:@"/" withString:@"-"] stringByReplacingOccurrencesOfString:@":" withString:@" -"]];
    [[NSFileManager defaultManager] createDirectoryAtPath:_downloadPath withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *filepart = [[[NSString stringWithFormat:@"%@.mp4",fileName] stringByReplacingOccurrencesOfString:@"/" withString:@"-"] stringByReplacingOccurrencesOfString:@":" withString:@" -"];
    NSRegularExpression *dateRegex = [NSRegularExpression regularExpressionWithPattern:@"(\\d{2})[-_](\\d{2})[-_](\\d{4})" options:0 error:nil];
    filepart = [dateRegex stringByReplacingMatchesInString:filepart options:0 range:NSMakeRange(0, filepart.length) withTemplate:@"$3-$2-$1"];
    _downloadPath = [_downloadPath stringByAppendingPathComponent:filepart];
}
- (void)cancelDownload
{
    [_currentRequest cancel];
	//Some basic cleanup.
    if ([_task isRunning]) {
        [_task terminate];
    }
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:_fh];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:_errorFh];
	[_show setValue:@"Cancelled" forKey:@"status"];
    _show.complete = @NO;
    _show.successful = @NO;
	[self addToLog:@"Download Cancelled"];
    [_processErrorCache invalidate];
    _running=FALSE;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
