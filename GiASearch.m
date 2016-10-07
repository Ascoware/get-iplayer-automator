//
//  GiASearch.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/9/14.
//
//

#import "GiASearch.h"

@implementation GiASearch
- (id)initWithSearchTerms:(NSString *)searchTerms allowHidingOfDownloadedItems:(BOOL)allowHidingOfDownloadedItems logController:(LogController *)logger selector:(SEL)selector withTarget:(id)target
{
   if (!(self = [super init])) return nil;
   
   if([searchTerms length] > 0)
	{
		task = [[NSTask alloc] init];
		pipe = [[NSPipe alloc] init];
      self->selector = selector;
      self->target = target;
      self->logger = logger;
		
		[task setLaunchPath:@"/usr/bin/perl"];
		NSString *searchArgument = [[NSString alloc] initWithString:searchTerms];
        NSString *typeArg  = [[GetiPlayerArguments sharedController] typeArgumentForCacheUpdate:NO andIncludeITV:YES];
        NSString *getiPlayerPath = [[NSBundle mainBundle] pathForResource:@"get_iplayer" ofType:@"pl"];
        NSArray *args = @[getiPlayerPath,@"--nocopyright",@"-e60480000000000000",typeArg ,@"--listformat=SearchResult|<pid>|<timeadded>|<type>|<name>|<episode>|<channel>|<seriesnum>|<episodenum>|<desc>|<thumbnail>|<web>",@"--long",@"--nopurge",searchArgument,[GetiPlayerArguments sharedController].profileDirArg];

        if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"ShowDownloadedInSearch"] boolValue] && allowHidingOfDownloadedItems)
            args=[args arrayByAddingObject:@"--hide"];
      
		[task setArguments:args];
		
		[task setStandardOutput:pipe];
		NSFileHandle *fh = [pipe fileHandleForReading];
		
		NSNotificationCenter *nc;
		nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self
             selector:@selector(searchDataReady:)
                 name:NSFileHandleReadCompletionNotification
               object:fh];
		[nc addObserver:self
             selector:@selector(searchFinished:)
                 name:NSTaskDidTerminateNotification
               object:task];
		data = [[NSMutableString alloc] init];
        NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:[task environment]];
        envVariableDictionary[@"HOME"] = [@"~" stringByExpandingTildeInPath];
        envVariableDictionary[@"PERL_UNICODE"] = @"AS";
        [task setEnvironment:envVariableDictionary];
		[task launch];
		[fh readInBackgroundAndNotify];
	}
   else {
      [[NSException exceptionWithName:@"EmptySearchArguments" reason:@"The search arguments string provided was nil or empty." userInfo:nil] raise];
   }
   
   return self;
}

- (void)searchDataReady:(NSNotification *)n
{
   NSData *d;
   d = [n userInfo][NSFileHandleNotificationDataItem];
	
   if ([d length] > 0) {
		NSString *s = [[NSString alloc] initWithData:d
                                          encoding:NSUTF8StringEncoding];
		[data appendString:s];
	}
	else
	{
		task = nil;
	}
	
   // If the task is running, start reading again
   if (task)
      [[pipe fileHandleForReading] readInBackgroundAndNotify];
}

- (void)searchFinished:(NSNotification *)N
{
   NSArray *array = [data componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
   NSMutableArray *resultsArray = [[NSMutableArray alloc] initWithCapacity:[array count]];
	for (NSString *string in array)
	{
		if ([string hasPrefix:@"SearchResult|"])
		{
			@try {
            //SearchResult|<pid>|<timeadded>|<type>|<name>|<episode>|<channel>|<seriesnum>|<episodenum>|<desc>|<thumbnail>|<web>
				NSScanner *myScanner = [NSScanner scannerWithString:string];
				NSString *buffer;
            Programme *p = [[Programme alloc] initWithLogController:logger];
            p.processedPID = @YES;
            
            [myScanner scanString:@"SearchResult|" intoString:nil];
				[myScanner scanUpToString:@"|" intoString:&buffer];
            [myScanner scanString:@"|" intoString:nil];
            p.pid = buffer;
            
            [myScanner scanUpToString:@"|" intoString:&buffer];
            [myScanner scanString:@"|" intoString:nil];
            p.timeadded = @([buffer integerValue]);
            
            [myScanner scanUpToString:@"|" intoString:&buffer];
            [myScanner scanString:@"|" intoString:nil];
            if ([buffer isEqualToString:@"radio"])
               p.radio = @YES;
            else if ([buffer isEqualToString:@"podcast"])
               p.podcast = @YES;
            
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
               p.season = [buffer integerValue];
            }
            else {
               p.season = 0;
            }
            
            [myScanner scanUpToString:@"|" intoString:&buffer];
            [myScanner scanString:@"|" intoString:nil];
            if (buffer) {
               p.episode = [buffer integerValue];
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
               [logger addToLog: [NSString stringWithFormat:@"WARNING: Skipped invalid search result: %@", string]];
               continue;
            }
            
				[resultsArray addObject:p];
			}
			@catch (NSException *e) {
				NSAlert *searchException = [[NSAlert alloc] init];
				[searchException addButtonWithTitle:@"OK"];
				[searchException setMessageText:[NSString stringWithFormat:@"Invalid Output!"]];
				[searchException setInformativeText:@"Please check your query. Your query must not alter the output format of Get_iPlayer. (searchFinished)"];
				[searchException setAlertStyle:NSWarningAlertStyle];
				[searchException runModal];
				searchException = nil;
			}
		}
		else
		{
			if ([string hasPrefix:@"Unknown option:"] || [string hasPrefix:@"Option"] || [string hasPrefix:@"Usage"])
			{
				[logger addToLog:@"Unknown option" :self];
			}
		}
   }
   [target performSelectorOnMainThread:selector withObject:resultsArray waitUntilDone:NO];
}

- (void)dealloc
{
   [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
