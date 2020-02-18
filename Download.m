//
//  Download.m
//
//
//  Created by Thomas Willson on 12/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Download.h"
#import "AppController.h"

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
            _show.status = [NSString stringWithFormat:@"Downloading: %.1f%%", percent];
        }
        else {
            _show.status = @"Downloading...";
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

                unsigned int unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute;
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

- (void)ffmpegFinished:(NSNotification *)finishedNote
{
    NSLog(@"Conversion Finished");
    [self addToLog:@"INFO: Finished Converting." noTag:YES];
    if ([finishedNote.object terminationStatus] == 0)
    {
        [[NSFileManager defaultManager] removeItemAtPath:_downloadPath error:nil];
        if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"TagShows"] boolValue])
        {
            _show.status = @"Tagging...";
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
        self.show.status = @"Download Complete";
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
        // youtube-dl should try to download a subtitle file, but if there isn't one log it and continue.
        if (_subtitlePath && [[NSFileManager defaultManager] fileExistsAtPath:_subtitlePath]) {
            if (![_subtitlePath.pathExtension isEqual: @"srt"])
            {
                _show.status = @"Converting Subtitles...";
                [self setPercentage:102];
                [self setCurrentProgress:[NSString stringWithFormat:@"Converting Subtitles... -- %@",_show.showName]];
                [self addToLog:@"INFO: Converting Subtitles..." noTag:YES];
                if ([_subtitlePath.pathExtension isEqualToString:@"ttml"]) {
                    [self convertTTMLToSRT];
                } else {
                    [self convertWebVTTToSRT];
                }
            } else {
                [self convertSubtitlesFinished:nil];
            }
        } else {
            // If youtube-dl embeds subtitles for us it deletes the raw subtitle file. When that happens
            // we don't know if it was subtitled or not, so don't report an error when embedding is on.
            if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"EmbedSubtitles"] boolValue]) {
                NSString *message = [NSString stringWithFormat:@"INFO: No subtitles were found for %@", _show.showName];
                [self addToLog:message noTag:YES];
            }
            [self convertSubtitlesFinished:nil];
        }
    } else {
        [self convertSubtitlesFinished:nil];
    }
}

- (void)convertWebVTTToSRT
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

            NSString *ffmpegURL = [[[AppController sharedController] extraBinariesPath] stringByAppendingPathComponent:@"ffmpeg"];
            self.subsTask.launchPath = ffmpegURL;
            self.subsTask.arguments = args;
            [self.subsTask launch];
        });
    }
}

- (void)convertTTMLToSRT
{
    if (!_subtitlePath) {
        [self convertSubtitlesFinished:nil];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self addToLog:[NSString stringWithFormat:@"INFO: Converting to SubRip: %@", self.subtitlePath] noTag:YES];
            NSString *ttml2srtPath = [[NSBundle mainBundle] pathForResource:@"ttml2srt.py" ofType:nil];
            NSMutableArray *args = [[NSMutableArray alloc] initWithObjects:ttml2srtPath, nil];

            BOOL srtIgnoreColors = [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"%@SRTIgnoreColors", self.defaultsPrefix]];
            if (srtIgnoreColors)
            {
                [args addObject:@"--srt-ignore-colors"];
            }

            [args addObject:self.subtitlePath];

            self.subsTask = [[NSTask alloc] init];
            self.subsErrorPipe = [[NSPipe alloc] init];
            self.subsTask.standardError = self.subsErrorPipe;
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(convertSubtitlesFinished:) name:NSTaskDidTerminateNotification object:self.subsTask];

            self.subsTask.launchPath = @"/usr/bin/python";
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
    self.show.status = @"Download Complete";
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

- (void)launchMetaRequest
{
    [[NSException exceptionWithName:@"InvalidDownload" reason:@"Launch Meta Request shouldn't be called on base class." userInfo:nil] raise];
}

- (void)createDownloadPath
{
    NSString *fileName = _show.showName;

    // XBMC naming is always used on ITV shows to ensure unique names.
    if ([_show.tvNetwork hasPrefix:@"ITV"] || [[[NSUserDefaults standardUserDefaults] valueForKey:@"XBMC_naming"] boolValue]) {
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
    NSString *filepart = [[[NSString stringWithFormat:@"%@.%%(ext)s",fileName] stringByReplacingOccurrencesOfString:@"/" withString:@"-"] stringByReplacingOccurrencesOfString:@":" withString:@" -"];
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
	self.show.status = @"Cancelled";
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
