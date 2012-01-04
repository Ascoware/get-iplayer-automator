//
//  Download.m
//  
//
//  Created by Thomas Willson on 12/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Download.h"
#import "ASIHTTPRequest.h"

@implementation Download
- (void)cancelDownload:(id)sender
{
    NSLog(@"Cancel Download");
}
- (id)init
{
    [super init];
    
    //Prepare Time Remaining
	rateEntries = [[NSMutableArray alloc] init];
	lastDownloaded=0;
	outOfRange=0;
    
    return self;
}
@synthesize show;
#pragma mark Notification Posters
- (void)addToLog:(NSString *)logMessage noTag:(BOOL)b
{
	if (b)
	{
		[nc postNotificationName:@"AddToLog" object:nil userInfo:[NSDictionary dictionaryWithObject:logMessage forKey:@"message"]];
	}
	else
	{
		[nc postNotificationName:@"AddToLog" object:self userInfo:[NSDictionary dictionaryWithObject:logMessage forKey:@"message"]];
	}
    [log appendFormat:@"%@\n", logMessage];
}
- (void)addToLog:(NSString *)logMessage
{
	[nc postNotificationName:@"AddToLog" object:self userInfo:[NSDictionary dictionaryWithObject:logMessage forKey:@"message"]];
    [log appendFormat:@"%@\n", logMessage];
}
- (void)setCurrentProgress:(NSString *)string
{
	[nc postNotificationName:@"setCurrentProgress" object:self userInfo:[NSDictionary dictionaryWithObject:string forKey:@"string"]];
}
- (void)setPercentage:(double)d
{
	if (d<=100.0)
	{
		NSNumber *value = [[NSNumber alloc] initWithDouble:d];
		[nc postNotificationName:@"setPercentage" object:self userInfo:[NSDictionary dictionaryWithObject:value forKey:@"nsDouble"]];
	}
	else
	{
		[nc postNotificationName:@"setPercentage" object:self userInfo:nil];
	}
}
- (void)requestFailed:(ASIHTTPRequest *)request
{
    [request startAsynchronous];
}
#pragma mark Message Processers
- (void)processFLVStreamerMessage:(NSString *)message
{
    NSScanner *scanner = [NSScanner scannerWithString:message];
    [scanner setScanLocation:0];
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
        if (percent != 102)
            [self setCurrentProgress:[NSString stringWithFormat:@"%.1f%% - (%.2f MB/~%.0f MB) -- %@",percent,downloaded/1024,total,[show valueForKey:@"showName"]]];
        else
            [self setCurrentProgress:[NSString stringWithFormat:@"%.2f MB Downloaded -- %@",downloaded/1024,[show showName]]];
        [self setPercentage:percent];
        if (percent != 102)
            [show setValue:[NSString stringWithFormat:@"Downloading: %.1f%%", percent] forKey:@"status"];
        else 
            [show setValue:@"Downloading..." forKey:@"status"];
        
        //Calculate Time Remaining
        downloaded=downloaded/1024;
        if (total>0 && downloaded>0 && percent>0)
        {
            if ([rateEntries count] == 100)
            {
                
                double rate = ((downloaded-lastDownloaded)/(-[lastDate timeIntervalSinceNow]));
                if (rate < (oldRateAverage*5) && rate > (oldRateAverage/5) && rate < 50)
                {
                    [rateEntries removeObjectAtIndex:0];
                    [rateEntries addObject:[NSNumber numberWithDouble:rate]];
                    outOfRange=0;
                }
                else 
                {
                    outOfRange++;
                    if (outOfRange>10)
                    {
                        rateEntries = [[NSMutableArray alloc] init];
                        outOfRange=0;
                    }
                }
                
                
                double rateSum=0;
                for (NSNumber *tempRate in rateEntries)
                {
                    rateSum=rateSum+[tempRate doubleValue];
                }
                double rateAverage = oldRateAverage = rateSum/100;
                lastDownloaded=downloaded;
                lastDate = [NSDate date];
                NSDate *predictedFinished = [NSDate dateWithTimeIntervalSinceNow:(total-downloaded)/rateAverage];
                
                unsigned int unitFlags = NSHourCalendarUnit | NSMinuteCalendarUnit;
                NSDateComponents *conversionInfo = [[NSCalendar currentCalendar] components:unitFlags fromDate:lastDate toDate:predictedFinished options:0];
                
                [self setCurrentProgress:[NSString stringWithFormat:@"%.1f%% - (%.2f MB/~%.0f MB) - %2d:%2d Remaining -- %@",percent,downloaded,total,[conversionInfo hour],[conversionInfo minute],[show valueForKey:@"showName"]]];
            }
            else 
            {
                if (lastDownloaded>0 && lastDate)
                {
                    double rate = ((downloaded-lastDownloaded)/(-[lastDate timeIntervalSinceNow]));
                    if (rate<50)
                        [rateEntries addObject:[NSNumber numberWithDouble:rate]];
                    lastDownloaded=downloaded;
                    lastDate = [NSDate date];
                    if ([rateEntries count]>98)
                    {
                        double rateSum=0;
                        for (NSNumber *entry in rateEntries)
                        {
                            rateSum = rateSum+[entry doubleValue];
                        }
                        oldRateAverage = rateSum/[rateEntries count];
                    }
                }
                else 
                {
                    lastDownloaded=downloaded;
                    lastDate = [NSDate date];
                }
                if (percent != 102)
                    [self setCurrentProgress:[NSString stringWithFormat:@"%.1f%% - (%.2f MB/~%.0f MB) -- %@",percent,downloaded,total,[show valueForKey:@"showName"]]];
                else
                    [self setCurrentProgress:[NSString stringWithFormat:@"%.2f MB Downloaded -- %@",downloaded/1024,[show showName]]];
            }
        }
        
        
    }
}
- (void)rtmpdumpFinished:(NSNotification *)finishedNote
{
    [self addToLog:@"RTMPDUMP finished"];
    [nc removeObserver:self name:NSFileHandleReadCompletionNotification object:fh];
	[nc removeObserver:self name:NSFileHandleReadCompletionNotification object:errorFh];
    [processErrorCache invalidate];
    
    NSInteger exitCode=[[finishedNote object] terminationStatus];
    NSLog(@"Exit Code = %ld",(long)exitCode);
    if (exitCode==0) //RTMPDump is successful
    {
        [show setComplete:[NSNumber numberWithBool:YES]];
        [show setSuccessful:[NSNumber numberWithBool:YES]];
        NSDictionary *info = [NSDictionary dictionaryWithObject:show forKey:@"Programme"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AddProgToHistory" object:self userInfo:info];
        
        ffTask = [[NSTask alloc] init];
        ffPipe = [[NSPipe alloc] init];
        ffErrorPipe = [[NSPipe alloc] init];
        
        [ffTask setStandardOutput:ffPipe];
        [ffTask setStandardError:ffErrorPipe];
        
        ffFh = [ffPipe fileHandleForReading];
        ffErrorFh = [ffErrorPipe fileHandleForReading];
        
        NSString *completeDownloadPath = [[downloadPath stringByDeletingPathExtension] stringByDeletingPathExtension];
        completeDownloadPath = [completeDownloadPath stringByAppendingPathExtension:@"mp4"];
        [show setPath:completeDownloadPath];
        
        [ffTask setLaunchPath:[[NSBundle mainBundle] pathForResource:@"ffmpeg" ofType:nil]];
        
        [ffTask setArguments:[NSArray arrayWithObjects:
                              @"-i",[NSString stringWithFormat:@"%@",downloadPath],
                              @"-vcodec",@"copy",
                              @"-acodec",@"copy",
                              [NSString stringWithFormat:@"%@",completeDownloadPath],
                              nil]];
        
        [nc addObserver:self
               selector:@selector(DownloadDataReady:)
                   name:NSFileHandleReadCompletionNotification
                 object:ffFh];
        [nc addObserver:self 
               selector:@selector(DownloadDataReady:) 
                   name:NSFileHandleReadCompletionNotification 
                 object:ffErrorFh];
        [nc addObserver:self 
               selector:@selector(ffmpegFinished:) 
                   name:NSTaskDidTerminateNotification 
                 object:ffTask];
        
        [ffTask launch];
        [ffFh readInBackgroundAndNotify];
        [ffErrorFh readInBackgroundAndNotify];
        
        [self setCurrentProgress:[NSString stringWithFormat:@"Converting... -- %@",[show showName]]];
        [show setStatus:@"Converting..."];
        [self addToLog:@"INFO: Converting FLV File to MP4" noTag:YES];
        [self setPercentage:102];
    }
    else if (exitCode==1 && running) //RTMPDump could not resume
    {
        if ([[[task arguments] lastObject] isEqualTo:@"--resume"])
        {
            [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:nil];
            [self addToLog:@"WARNING: Download couldn't be resumed. Overwriting partial file." noTag:YES];
            [self addToLog:@"INFO: Preparing Request for Auth Info" noTag:YES];
            [self launchMetaRequest];
            return;
        }
    }
    else if (exitCode==2 && attemptNumber<4 && running) //RTMPDump lost connection but should be able to resume.
    {
        attemptNumber++;
        [self addToLog:[NSString stringWithFormat:@"WARNING: Trying download again. Attempt %ld/4",(long)attemptNumber] noTag:YES];
        [self launchMetaRequest];
    }
    else //Some undocumented exit code or too many attempts
    {
        [show setSuccessful:[NSNumber numberWithBool:NO]];
        [show setComplete:[NSNumber numberWithBool:YES]];
        [show setReasonForFailure:@"Unknown"];
        [nc postNotificationName:@"DownloadFinished" object:show];
        [show setValue:@"Download Failed" forKey:@"status"];
    }
    [processErrorCache invalidate];
}
- (void)ffmpegFinished:(NSNotification *)finishedNote
{
    NSLog(@"Conversion Finished");
    [self addToLog:@"INFO: Finished Converting." noTag:YES];
    if ([[finishedNote object] terminationStatus] == 0)
    {
        [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:nil];
        [show setValue:@"Tagging..." forKey:@"status"];
        [self setPercentage:102];
        [self setCurrentProgress:[NSString stringWithFormat:@"Downloading Thumbnail... -- %@",[show showName]]];
        [self addToLog:@"INFO: Tagging the Show" noTag:YES];
        [self addToLog:@"INFO: Downloading thumbnail" noTag:YES];
        
        ASIHTTPRequest *downloadThumb = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:thumbnailURL]];
        [downloadThumb setDownloadDestinationPath:[[show path] stringByAppendingPathExtension:@"jpg"]];
        [downloadThumb setDelegate:self];
        [downloadThumb startAsynchronous];
        [downloadThumb setDidFinishSelector:@selector(thumbnailRequestFinished:)];
    }
    else
    {
        [self addToLog:[NSString stringWithFormat:@"INFO: Exit Code = %ld",(long)[[finishedNote object]terminationStatus]] noTag:YES];
        [show setValue:@"Download Complete" forKey:@"status"];
        [nc postNotificationName:@"DownloadFinished" object:show]; 
    }
}
- (void)thumbnailRequestFinished:(ASIHTTPRequest *)request
{
    [self addToLog:@"INFO: Thumbnail Download Completed" noTag:YES];
    apTask = [[NSTask alloc] init];
    apPipe = [[NSPipe alloc] init];
    apFh = [apPipe fileHandleForReading];
    
    //[apTask setStandardOutput:apPipe];
    //[apTask setStandardError:apPipe];
    
    [apTask setLaunchPath:[[NSBundle mainBundle] pathForResource:@"AtomicParsley" ofType:nil]];
    
    [apTask setArguments:[NSArray arrayWithObjects:
                          [NSString stringWithFormat:@"%@",[show path]],
                          @"--stik",@"value=10",
                          @"--TVNetwork",[show tvNetwork],
                          @"--TVShowName",[show seriesName],
                          @"--TVSeasonNum",[NSString stringWithFormat:@"%ld",(long)[show season]],
                          @"--TVEpisodeNum",[NSString stringWithFormat:@"%ld",(long)[show episode]],
                          @"--TVEpisode",[show episodeName],
                          @"--title",[show showName],
                          @"--artwork",[request downloadDestinationPath],
                          @"--comment",[show desc],
                          @"--description",[show desc],
                          @"--artist",[show tvNetwork],
                          @"--overWrite",
                          nil]];
    [nc addObserver:self
           selector:@selector(DownloadDataReady:)
               name:NSFileHandleReadCompletionNotification
             object:apFh];
    [nc addObserver:self 
           selector:@selector(atomicParsleyFinished:) 
               name:NSTaskDidTerminateNotification 
             object:apTask];
    
    [self addToLog:@"INFO: Beginning AtomicParsley Tagging." noTag:YES];
    
    [apTask launch];
    [apFh readInBackgroundAndNotify];
    
    [self setCurrentProgress:[NSString stringWithFormat:@"Tagging the Programme... -- %@",[show showName]]];
    
}
- (void)atomicParsleyFinished:(NSNotification *)finishedNote
{
    if ([[finishedNote object] terminationStatus] == 0)
    {
        [[NSFileManager defaultManager] removeItemAtPath:[[show path] stringByAppendingPathExtension:@"jpg"] error:nil];
        [self addToLog:@"INFO: AtomicParsley Tagging finished." noTag:YES];
    }
    else
        [self addToLog:@"INFO: Tagging failed." noTag:YES];
    
    [show setValue:@"Download Complete" forKey:@"status"];
    
    [nc postNotificationName:@"DownloadFinished" object:show];
}
- (void)DownloadDataReady:(NSNotification *)note
{
	[[pipe fileHandleForReading] readInBackgroundAndNotify];
	NSData *d;
    d = [[note userInfo] valueForKey:NSFileHandleNotificationDataItem];
	
    if ([d length] > 0) {
		NSString *s = [[NSString alloc] initWithData:d
											encoding:NSUTF8StringEncoding];
		[self processGetiPlayerOutput:s];
	}
}
- (void)ErrorDataReady:(NSNotification *)note
{
	[[errorPipe fileHandleForReading] readInBackgroundAndNotify];
	NSData *d;
    d = [[note userInfo] valueForKey:NSFileHandleNotificationDataItem];
    if ([d length] > 0)
	{
		[errorCache appendString:[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]];
	}
}
- (void)processGetiPlayerOutput:(NSString *)outp
{
	//Separate the output by line.
	NSString *outpt = [[NSString alloc] initWithString:outp];
	NSString *string = [NSString stringWithString:outpt];
	NSUInteger length = [string length];
	NSUInteger paraStart = 0, paraEnd = 0, contentsEnd = 0;
	NSMutableArray *array = [NSMutableArray array];
	NSRange currentRange;
	while (paraEnd < length) {
		[string getParagraphStart:&paraStart end:&paraEnd
					  contentsEnd:&contentsEnd forRange:NSMakeRange(paraEnd, 0)];
		currentRange = NSMakeRange(paraStart, contentsEnd - paraStart);
		[array addObject:[string substringWithRange:currentRange]];
	}
	//Parse each line individually.
	for (NSString *output in array)
	{
        if (![output hasPrefix:@"frame="])
            [self addToLog:output noTag:YES];
    }
}
- (void)processError
{
	//Separate the output by line.
	NSString *string = [[NSString alloc] initWithString:errorCache];
    errorCache = [NSMutableString stringWithString:@""];
	NSUInteger length = [string length];
	NSUInteger paraStart = 0, paraEnd = 0, contentsEnd = 0;
	NSMutableArray *array = [NSMutableArray array];
	NSRange currentRange;
	while (paraEnd < length) {
		[string getParagraphStart:&paraStart end:&paraEnd
					  contentsEnd:&contentsEnd forRange:NSMakeRange(paraEnd, 0)];
		currentRange = NSMakeRange(paraStart, contentsEnd - paraStart);
		[array addObject:[string substringWithRange:currentRange]];
	}
	//Parse each line individually.
	for (NSString *output in array)
	{
        NSScanner *scanner = [NSScanner scannerWithString:output];
        if ([scanner scanFloat:nil])
        {
            [self processFLVStreamerMessage:output];
        }
        else
            if([output length] > 1) [self addToLog:output noTag:YES];
    }
}
@end
