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
        _defaultsPrefix = @"BBC_";
        _downloadPath = [[NSString alloc] initWithString:[[NSUserDefaults standardUserDefaults] valueForKey:@"DownloadPath"]];
    }
    return self;
}

#pragma mark Notification Posters
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
        DDLogWarn(@"WARNING: AtomicParsley key: %@, value: %@", (key ?: @"nil"), (value ?: @"nil"));
    }
}

- (void)tagDownloadWithMetadata
{
    if (self.show.path.length == 0) {
        DDLogWarn(@"WARNING: Can't tag, no path");
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
        [self safeAppend:arguments key:@"--title" value:self.show.episodeName];
        [self safeAppend:arguments key:@"--description" value:self.show.desc];
        [self safeAppend:arguments key:@"--artist" value:self.show.tvNetwork];
        [self safeAppend:arguments key:@"--year" value: self.show.lastBroadcastString];
        [arguments addObject:@"--overWrite"];

        self.apTask.arguments = arguments;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(atomicParsleyFinished:)
                                                     name:NSTaskDidTerminateNotification
                                                   object:self.apTask];

        DDLogInfo(@"INFO: Beginning AtomicParsley Tagging.");

        [self.apTask launch];
        [self setCurrentProgress:[NSString stringWithFormat:@"Tagging the Programme... -- %@",self.show.showName]];
    });
}

- (void)atomicParsleyFinished:(NSNotification *)finishedNote
{
    if (finishedNote) {
        if ([finishedNote.object terminationStatus] == 0) {
            DDLogInfo(@"INFO: AtomicParsley Tagging finished.");
            self.show.successful = YES;
        } else {
            DDLogInfo(@"INFO: Tagging failed.");
            self.show.successful = NO;
        }
    }

    self.apTask = nil;
    self.apPipe = nil;

    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"DownloadSubtitles"] boolValue]) {
        // youtube-dl should try to download a subtitle file, but if there isn't one log it and continue.
        if (_subtitlePath && [[NSFileManager defaultManager] fileExistsAtPath:_subtitlePath]) {
            if (![_subtitlePath.pathExtension isEqual: @"srt"]) {
                _show.status = @"Converting Subtitles...";
                [self setPercentage:102];
                [self setCurrentProgress:[NSString stringWithFormat:@"Converting Subtitles... -- %@",_show.showName]];
                DDLogInfo(@"INFO: Converting Subtitles...");
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
                DDLogInfo(@"INFO: No subtitles were found for %@", _show.showName);
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
            DDLogInfo(@"INFO: Converting to SubRip: %@", self.subtitlePath);

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
            DDLogInfo(@"INFO: Converting to SubRip: %@", self.subtitlePath);
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

            NSURL *pythonInstall = [[NSBundle mainBundle] URLForResource: @"python" withExtension: nil];
            NSURL *pythonPath = [pythonInstall URLByAppendingPathComponent:@"bin/python3.11" isDirectory:false];

            self.subsTask.launchPath = pythonPath.path;
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
            [[NSFileManager defaultManager] removeItemAtPath:_subtitlePath error:nil];
            DDLogInfo(@"INFO: Conversion to SubRip complete: %@", [_show.path.stringByDeletingPathExtension stringByAppendingPathExtension:@"srt"]);
        }
        else
        {
            DDLogError(@"ERROR: Conversion to SubRip failed: %@", _subtitlePath);
            NSData *errData = [_subsErrorPipe.fileHandleForReading readDataToEndOfFile];
            if (errData.length > 0)
            {
                DDLogError(@"%@", [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding]);
            }
        }
    }
    self.show.status = @"Download Complete";
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:_show];
    self.subsTask = nil;
    self.subsErrorPipe = nil;
}

- (void)processGetiPlayerOutput:(NSString *)output
{
	NSArray *array = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	for (NSString *outputLine in array)
	{
        if (![outputLine hasPrefix:@"frame="])
            DDLogInfo(@"%@", outputLine);
    }
}

- (void)createDownloadPath
{
    NSString *fileName = _show.showName;

    // XBMC naming is always used on ITV shows to ensure unique names.
    if ([_show.tvNetwork hasPrefix:@"ITV"] || [[[NSUserDefaults standardUserDefaults] valueForKey:@"XBMC_naming"] boolValue]) {
        if (_show.seriesName) {
            fileName = _show.seriesName;
        }
        if (!_isFilm) {
            if (_show.season == 0) {
                _show.season = 1;
                if (_show.episode == 0) {
                    _show.episode = 1;
                }
            }
            NSString *format = _show.episodeName.length > 0 ? @"%@.s%02lde%02ld.%@" : @"%@.s%02lde%02ld";
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
    _show.complete = NO;
    _show.successful = NO;
	DDLogInfo(@"%@: Download Cancelled", self.description);
    _running=FALSE;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
