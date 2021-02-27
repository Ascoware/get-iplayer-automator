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
        _running=YES;
        _verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose"];
        _defaultsPrefix = @"BBC_";
        _downloadPath = [[NSString alloc] initWithString:[[NSUserDefaults standardUserDefaults] valueForKey:@"DownloadPath"]];
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

- (void)addToLog:(NSString *)logMessage noTag:(BOOL)noTag
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AddToLog" object:(noTag ? nil : self) userInfo:@{@"message": logMessage}];
}

- (void)addToLog:(NSString *)logMessage
{
    [self addToLog: logMessage noTag:YES];
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
- (void)safeAppend: (NSMutableArray *)array key:(NSString *)key value:(NSObject *)value
{
    if (key && value) {
        [array addObject:key];
        // Converts any object into a string representation
        [array addObject:[NSString stringWithFormat:@"%@", value]];
    } else {
        NSString *msg = [NSString stringWithFormat:@"WARN: AtomicParsley key: %@, value: %@", (key ?: @"nil"), (value ?: @"nil")];
        [self addToLog:msg noTag:YES];
    }
}
- (void)thumbnailRequestFinished:(NSURL *)location
{

    if (location) {
        NSString *msg = [NSString stringWithFormat:@"INFO: Thumbnail download completed to %@", location];
        [self addToLog:msg noTag:YES];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *destinationURL = [NSURL fileURLWithPath:_thumbnailPath];
        NSError *error = nil;
        [fm removeItemAtPath:_thumbnailPath error:&error];
        if (![fm copyItemAtURL:location toURL:destinationURL error:&error]) {
            NSLog(@"Unable to save downloaded thumbnail: %@", error.description);
            [self addToLog:@"INFO: Thumbnail Download Failed" noTag:YES];
        }
    } else {
        [self addToLog:@"INFO: No thumbnail downloaded" noTag:YES];
    }

    if (self.show.path.length == 0) {
        [self addToLog:@"WARN: Can't tag, no path" noTag:YES];
        [self atomicParsleyFinished:nil];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        self.apTask = [[NSTask alloc] init];
        self.apPipe = [[NSPipe alloc] init];

        self.apTask.launchPath = [[[AppController sharedController] extraBinariesPath] stringByAppendingPathComponent:@"AtomicParsley"];

        NSMutableArray *arguments = [NSMutableArray array];
        [arguments addObject:self.show.path];
        [self safeAppend:arguments key:@"--stik" value:@"value=10"];
        [self safeAppend:arguments key:@"--TVNetwork" value:self.show.tvNetwork];
        [self safeAppend:arguments key:@"--TVShowName" value:self.show.seriesName];
        [self safeAppend:arguments key:@"--TVSeasonNum" value: @(self.show.season)];
        [self safeAppend:arguments key:@"--TVEpisodeNum" value: @(self.show.episode)];
        [self safeAppend:arguments key:@"--TVEpisode" value:self.show.episodeName];
        [self safeAppend:arguments key:@"--title" value:self.show.showName];
        [self safeAppend:arguments key:@"--comment" value:self.show.desc];
        [self safeAppend:arguments key:@"--description" value:self.show.desc];
        [self safeAppend:arguments key:@"--longdesc" value:self.show.desc];
        [self safeAppend:arguments key:@"--lyrics" value:self.show.desc];
        [self safeAppend:arguments key:@"--artist" value:self.show.tvNetwork];
        [self safeAppend:arguments key:@"--artwork" value: self.thumbnailPath];
        [self safeAppend:arguments key:@"--year" value: self.show.standardizedAirDate];
        [arguments addObject:@"--overWrite"];

        self.apTask.arguments = arguments;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(atomicParsleyFinished:)
                                                     name:NSTaskDidTerminateNotification
                                                   object:self.apTask];

        [self addToLog:@"INFO: Beginning AtomicParsley Tagging." noTag:YES];

        [self.apTask launch];
        [self setCurrentProgress:[NSString stringWithFormat:@"Tagging the Programme... -- %@",self.show.showName]];
    });
}
- (void)atomicParsleyFinished:(NSNotification *)finishedNote
{
    if (finishedNote) {
        if ([finishedNote.object terminationStatus] == 0) {
            [[NSFileManager defaultManager] removeItemAtPath:_thumbnailPath error:nil];
            [self addToLog:@"INFO: AtomicParsley Tagging finished." noTag:YES];
        } else {
            [self addToLog:@"INFO: Tagging failed." noTag:YES];
        }
    }

    self.apTask = nil;
    self.apPipe = nil;

    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"DownloadSubtitles"] boolValue]) {
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
            if (![[[NSUserDefaults standardUserDefaults] objectForKey:@"EmbedSubtitles"] boolValue]) {
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
    self.subsTask = nil;
    self.subsErrorPipe = nil;
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
- (void)processGetiPlayerOutput:(NSString *)output
{
	NSArray *array = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	for (NSString *outputLine in array)
	{
        if (![outputLine hasPrefix:@"frame="])
            [self addToLog:outputLine noTag:YES];
    }
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
    if ([self.task isRunning]) {
        [self.task terminate];
    }

    self.task = nil;
    self.pipe = nil;
    self.errorPipe = nil;
    
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:nil];
	self.show.status = @"Cancelled";
    _show.complete = @NO;
    _show.successful = @NO;
	[self addToLog:@"Download Cancelled"];
    _running=FALSE;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
