//
//  GiASearch.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/9/14.
//
//

#import "GiASearch.h"

@implementation GiASearch
- (instancetype)initWithSearchTerms:(NSString *)searchTerms allowHidingOfDownloadedItems:(BOOL)allowHidingOfDownloadedItems logController:(LogController *)logger selector:(SEL)selector withTarget:(id)target
{
    if (!(self = [super init])) return nil;
    
    if(searchTerms.length > 0)
    {
        _task = [[NSTask alloc] init];
        _pipe = [[NSPipe alloc] init];
        _errorPipe = [[NSPipe alloc] init];
        _selector = selector;
        _target = target;
        _logger = logger;
        
        _task.launchPath = @"/usr/bin/perl";
        NSString *typeArg  = [[GetiPlayerArguments sharedController] typeArgumentForCacheUpdate:NO andIncludeITV:YES];
        NSString *getiPlayerPath = [[NSBundle mainBundle] pathForResource:@"get_iplayer" ofType:nil];
        NSArray *args = @[getiPlayerPath, @"--nocopyright", @"-e60480000000000000", typeArg, @"--listformat=SearchResult|<pid>|<timeadded>|<type>|<name>|<episode>|<channel>|<seriesnum>|<episodenum>|<desc>|<thumbnail>|<web>", @"--long",@"--nopurge", @"--search",searchTerms, [GetiPlayerArguments sharedController].profileDirArg];
        
        if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"ShowDownloadedInSearch"] boolValue] && allowHidingOfDownloadedItems) {
            args=[args arrayByAddingObject:@"--hide"];
        }
        
        for (NSString *arg in args) {
            [_logger addToLog: arg];
        }
        
        _task.arguments = args;
        _task.standardOutput = _pipe;
        _task.standardError = _errorPipe;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(searchDataReadyNotification:)
                                                     name:NSFileHandleReadCompletionNotification
                                                   object:_pipe.fileHandleForReading];
        [_pipe.fileHandleForReading readInBackgroundAndNotify];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(searchDataReadyNotification:)
                                                     name:NSFileHandleReadCompletionNotification
                                                   object:_errorPipe.fileHandleForReading];
        [_errorPipe.fileHandleForReading readInBackgroundAndNotify];
        
        _data = [[NSMutableString alloc] init];
        NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:_task.environment];
        envVariableDictionary[@"HOME"] = (@"~").stringByExpandingTildeInPath;
        envVariableDictionary[@"PERL_UNICODE"] = @"AS";
        
        NSString *perlPath = [[NSBundle mainBundle] resourcePath];
        perlPath = [perlPath stringByAppendingPathComponent:@"perl5"];
        envVariableDictionary[@"PERL5LIB"] = perlPath;
        _task.environment = envVariableDictionary;
        [_task launch];
    }
    else {
        [[NSException exceptionWithName:@"EmptySearchArguments" reason:@"The search arguments string provided was nil or empty." userInfo:nil] raise];
    }
    
    return self;
}

- (void)searchDataReadyNotification:(NSNotification *)n
{
    NSData *d = n.userInfo[NSFileHandleNotificationDataItem];
    [self searchDataReady:d];
}

- (void)searchDataReady:(NSData *)d
{
    if (d.length > 0) {
        NSString *s = [[NSString alloc] initWithData:d
                                            encoding:NSUTF8StringEncoding];
        [_data appendString:s];
    }
    
    if (_task.isRunning) {
        [_pipe.fileHandleForReading readInBackgroundAndNotify];
        [_errorPipe.fileHandleForReading readInBackgroundAndNotify];
    }
    else {
        [self performSelectorOnMainThread:@selector(searchFinished:) withObject:nil waitUntilDone:NO];
    }
}

- (void)searchFinished:(NSNotification *)N
{
    NSArray *array = [_data componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *resultsArray = [[NSMutableArray alloc] initWithCapacity:array.count];
    for (NSString *string in array)
    {
        if ([string hasPrefix:@"SearchResult|"])
        {
            @try {
                //SearchResult|<pid>|<timeadded>|<type>|<name>|<episode>|<channel>|<seriesnum>|<episodenum>|<desc>|<thumbnail>|<web>
                NSScanner *myScanner = [NSScanner scannerWithString:string];
                NSString *buffer;
                Programme *p = [[Programme alloc] initWithLogController:_logger];
                p.processedPID = @YES;
                
                [myScanner scanString:@"SearchResult|" intoString:nil];
                [myScanner scanUpToString:@"|" intoString:&buffer];
                [myScanner scanString:@"|" intoString:nil];
                p.pid = buffer;
                
                [myScanner scanUpToString:@"|" intoString:&buffer];
                [myScanner scanString:@"|" intoString:nil];
                p.timeadded = @(buffer.integerValue);
                
                [myScanner scanUpToString:@"|" intoString:&buffer];
                [myScanner scanString:@"|" intoString:nil];
                if ([buffer isEqualToString:@"radio"])
                    p.radio = @YES;
                
                [myScanner scanUpToString:@"|" intoString:&buffer];
                [myScanner scanString:@"|" intoString:nil];
                p.seriesName = buffer;
                
                [myScanner scanUpToString:@"|" intoString:&buffer];
                [myScanner scanString:@"|" intoString:nil];
                p.episodeName = buffer;
                
                if (p.episodeName) {
                    p.showName = [NSString stringWithFormat:@"%@ - %@", p.seriesName, p.episodeName];
                }
                else {
                    p.showName = p.episodeName;
                }
                
                [myScanner scanUpToString:@"|" intoString:&buffer];
                [myScanner scanString:@"|" intoString:nil];
                p.tvNetwork = buffer;
                
                [myScanner scanUpToString:@"|" intoString:&buffer];
                [myScanner scanString:@"|" intoString:nil];
                if (buffer) {
                    p.season = buffer.integerValue;
                }
                else {
                    p.season = 0;
                }
                
                [myScanner scanUpToString:@"|" intoString:&buffer];
                [myScanner scanString:@"|" intoString:nil];
                if (buffer) {
                    p.episode = buffer.integerValue;
                }
                else {
                    p.season = 0;
                }
                
                [myScanner scanUpToString:@"|" intoString:&buffer];
                [myScanner scanString:@"|" intoString:nil];
                p.desc = buffer;
                
                [myScanner scanUpToString:@"|" intoString:&buffer];
                [myScanner scanString:@"|" intoString:nil];
                p.thumbnail = [[NSImage alloc] initByReferencingURL:[NSURL URLWithString:buffer]];
                
                [myScanner scanUpToString:@"|" intoString:&buffer];
                [myScanner scanString:@"|" intoString:nil];
                p.url = buffer;
                
                
                if (p.pid == nil || p.showName == nil || p.tvNetwork == nil || p.url == nil) {
                    [_logger addToLog: [NSString stringWithFormat:@"WARNING: Skipped invalid search result: %@", string]];
                    continue;
                }
                
                [resultsArray addObject:p];
            }
            @catch (NSException *e) {
                NSAlert *searchException = [[NSAlert alloc] init];
                [searchException addButtonWithTitle:@"OK"];
                searchException.messageText = [NSString stringWithFormat:@"Invalid Output!"];
                searchException.informativeText = @"Please check your query. Your query must not alter the output format of Get_iPlayer. (searchFinished)";
                searchException.alertStyle = NSWarningAlertStyle;
                [searchException runModal];
                searchException = nil;
            }
        }
        else
        {
            if ([string hasPrefix:@"Unknown option:"] || [string hasPrefix:@"Option"] || [string hasPrefix:@"Usage"])
            {
                [_logger addToLog:@"Unknown option" :self];
            }
        }
    }
    [_target performSelectorOnMainThread:_selector withObject:resultsArray waitUntilDone:NO];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
