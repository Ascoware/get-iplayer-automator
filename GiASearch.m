//
//  GiASearch.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/9/14.
//
//

#import "GiASearch.h"
#import "AppController.h"

@implementation GiASearch
- (instancetype)initWithSearchTerms:(NSString *)searchTerms allowHidingOfDownloadedItems:(BOOL)allowHidingOfDownloadedItems logController:(LogController *)logger selector:(SEL)selector withTarget:(id)target
{
    if (!(self = [super init])) return nil;
    
    if (searchTerms.length > 0)
    {
        self.task = [[NSTask alloc] init];
        self.pipe = [[NSPipe alloc] init];
        self.errorPipe = [[NSPipe alloc] init];

        self.selector = selector;
        self.target = target;
        self.logger = logger;
        
        self.task.launchPath = [[AppController sharedController] perlBinaryPath];
        NSString *typeArg = [[GetiPlayerArguments sharedController] typeArgumentForCacheUpdate:NO];
        NSArray *args = @[
            [[AppController sharedController] getiPlayerPath],
            [[GetiPlayerArguments sharedController] noWarningArg],
            [[GetiPlayerArguments sharedController] cacheExpiryArg],
            typeArg,
            @"--listformat",
            @"SearchResult|<pid>|<available>|<type>|<name>|<episode>|<channel>|<seriesnum>|<episodenum>|<desc>|<thumbnail>|<web>|<available>",
            @"--long",
            @"--nopurge",
            @"--search",
            searchTerms,
            [GetiPlayerArguments sharedController].profileDirArg];
        
        if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"ShowDownloadedInSearch"] boolValue] && allowHidingOfDownloadedItems) {
            args = [args arrayByAddingObject:@"--hide"];
        }
        
        for (NSString *arg in args) {
            [_logger addToLog: arg];
        }
        
        self.task.arguments = args;
        self.task.standardOutput = self.pipe;
        self.task.standardError = self.errorPipe;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(searchDataReadyNotification:)
                                                     name:NSFileHandleReadCompletionNotification
                                                   object:self.pipe.fileHandleForReading];
        [self.pipe.fileHandleForReading readInBackgroundAndNotify];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(searchDataReadyNotification:)
                                                     name:NSFileHandleReadCompletionNotification
                                                   object:self.errorPipe.fileHandleForReading];
        [self.errorPipe.fileHandleForReading readInBackgroundAndNotify];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(searchFinished:)
                                                     name:NSTaskDidTerminateNotification
                                                   object:self.task];
        _data = [[NSMutableString alloc] init];
        NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:self.task.environment];
        envVariableDictionary[@"HOME"] = (@"~").stringByExpandingTildeInPath;
        envVariableDictionary[@"PERL_UNICODE"] = @"AS";
        envVariableDictionary[@"PATH"] = [[AppController sharedController] perlEnvironmentPath];
        self.task.environment = envVariableDictionary;
        [self.task launch];
    }
    else {
        [[NSException exceptionWithName:@"EmptySearchArguments" reason:@"The search arguments string provided was nil or empty." userInfo:nil] raise];
    }
    
    return self;
}

- (void)searchDataReadyNotification:(NSNotification *)notification
{
    NSData *d = [notification.userInfo valueForKey:NSFileHandleNotificationDataItem];

    if (d.length > 0) {
        NSString *s = [[NSString alloc] initWithData:d
                                            encoding:NSUTF8StringEncoding];
        [_data appendString:s];
    }

    NSFileHandle *fh = [notification object];
    [fh readInBackgroundAndNotify];
}

- (void)searchFinished:(NSNotification *)notification
{
    NSArray *array = [_data componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *resultsArray = [[NSMutableArray alloc] initWithCapacity:array.count];
    NSDateFormatter *rawDateParser = [[NSDateFormatter alloc]init];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];

    self.task = nil;
    self.pipe = nil;
    self.errorPipe = nil;
    
    rawDateParser.locale = enUSPOSIXLocale;
    rawDateParser.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
    rawDateParser.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];

    for (NSString *string in array)
    {
        if ([string hasPrefix:@"SearchResult|"])
        {
            @try {
                //SearchResult|<pid>|<available>|<type>|<name>|<episode>|<channel>|<seriesnum>|<episodenum>|<desc>|<thumbnail>|<web>
                NSArray<NSString *> *fields = [string componentsSeparatedByString:@"|"];
                Programme *p = [Programme new];
                p.logger = _logger;
                p.processedPID = YES;
                p.pid = fields[1];
                NSDate *broadcastDate = [rawDateParser dateFromString:fields[2]];
                p.lastBroadcast = broadcastDate;
                p.lastBroadcastString = [NSDateFormatter localizedStringFromDate:broadcastDate dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterNoStyle];
                p.radio = [fields[3] isEqualToString:@"radio"];
                p.seriesName = fields[4];
                p.episodeName = fields[5];
                p.tvNetwork = fields[6];
                p.season = fields[7].integerValue;
                p.episode = fields[8].integerValue;
                p.desc = fields[9];

                if (p.seriesName.length > 0) {
                    p.showName = p.seriesName;
                } else {
                    p.showName = p.episodeName;
                }

                p.thumbnail = [[NSImage alloc] initByReferencingURL:[NSURL URLWithString:fields[10]]];
                p.url = fields[11];

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
                searchException.alertStyle = NSAlertStyleWarning;
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
