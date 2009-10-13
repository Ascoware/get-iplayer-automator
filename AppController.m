//
//  AppController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "AppController.h"
#import "Programme.h"
#import "Safari.h"
#import "iTunes.h"
#import "Camino.h"
#import "Growl-WithInstaller.framework/Headers/GrowlApplicationBridge.h"
#import "Sparkle.framework/Headers/Sparkle.h"
#import "JRFeedbackController.h"
#import "LiveTVChannel.h"

@implementation AppController
#pragma mark Overriden Methods
- (id)description
{
	return @"AppController";
}
- (id)init { 
	//Initialization
	[super init];
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	
	//Initialize Arrays for Controllers
	searchResultsArray = [NSMutableArray array];
	pvrSearchResultsArray = [NSMutableArray array];
	pvrQueueArray = [NSMutableArray array];
	queueArray = [NSMutableArray array];
	
	//Initialize Log
	log_value = [[NSMutableAttributedString alloc] initWithString:@"Get iPlayer Automator Initialized."];
	[self addToLog:@"" :nil];
	[nc addObserver:self selector:@selector(addToLogNotification:) name:@"AddToLog" object:nil];
	[nc addObserver:self selector:@selector(postLog:) name:@"NeedLog" object:nil];
	
	
	//Register Default Preferences
	NSMutableDictionary *defaultValues = [[NSMutableDictionary alloc] init];
	
	[defaultValues setObject:@"/TV Shows" forKey:@"DownloadPath"];
	[defaultValues setObject:@"Provided" forKey:@"Proxy"];
	[defaultValues setObject:@"" forKey:@"CustomProxy"];
	[defaultValues setObject:[NSNumber numberWithBool:YES] forKey:@"AutoRetryFailed"];
	[defaultValues setObject:@"30" forKey:@"AutoRetryTime"];
	[defaultValues setObject:[NSNumber numberWithBool:YES] forKey:@"AddCompletedToiTunes"];
	[defaultValues setObject:@"Safari" forKey:@"DefaultBrowser"];
	[defaultValues setObject:@"iPhone" forKey:@"DefaultFormat"];
	[defaultValues setObject:@"Flash - Standard" forKey:@"AlternateFormat"];
	[defaultValues setObject:[NSNumber numberWithBool:YES] forKey:@"CacheBBC_TV"];
	[defaultValues setObject:[NSNumber numberWithBool:YES] forKey:@"CacheITV_TV"];
	[defaultValues setObject:[NSNumber numberWithBool:NO] forKey:@"CacheBBC_Radio"];
	[defaultValues setObject:[NSNumber numberWithBool:NO] forKey:@"CacheBBC_Podcasts"];
	[defaultValues setObject:@"4" forKey:@"CacheExpiryTime"];
	[defaultValues setObject:[NSNumber numberWithBool:NO] forKey:@"Verbose"];
	[defaultValues setObject:[NSNumber numberWithBool:YES] forKey:@"SeriesLinkStartup"];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
	defaultValues = nil;
	
	//Make sure Application Support folder exists
	NSString *folder = @"~/Library/Application Support/Get iPlayer Automator/";
	folder = [folder stringByExpandingTildeInPath];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if (![fileManager fileExistsAtPath:folder])
	{
		[fileManager createDirectoryAtPath:folder attributes:nil];
	}
	[fileManager changeCurrentDirectoryPath:folder];
	
	//Install Plugins If Needed
	NSString *pluginPath = [folder stringByAppendingPathComponent:@"plugins"];
	if (![fileManager fileExistsAtPath:pluginPath])
	{
		[self addToLog:@"Installing Get_iPlayer Plugins..." :self];
		NSString *providedPath = [[NSBundle mainBundle] bundlePath];
		providedPath = [providedPath stringByAppendingPathComponent:@"/Contents/Resources/plugins"];
		[fileManager copyPath:providedPath toPath:pluginPath handler:nil];
	}
	
	
	//Initialize Arguments
	noWarningArg = [[NSString alloc] initWithString:@"--nocopyright"];
	listFormat = [[NSString alloc] initWithString:@"--listformat=<index>: <type>, ~<name> - <episode>~, <channel>"];
	profileDirArg = [[NSString alloc] initWithFormat:@"--profile-dir=%@", folder];
	
	getiPlayerPath = [[NSString alloc] initWithString:[[NSBundle mainBundle] bundlePath]];
	getiPlayerPath = [getiPlayerPath stringByAppendingString:@"/Contents/Resources/get_iplayer.pl"];
	runScheduled=NO;
	return self;
}
#pragma mark Delegate Methods
- (void)awakeFromNib
{
	[self updateCache:nil];
	
	//Read Queue & Series-Link from File
	NSFileManager *fileManager = [NSFileManager defaultManager];
    
	NSString *folder = @"~/Library/Application Support/Get iPlayer Automator/";
	folder = [folder stringByExpandingTildeInPath];
	if ([fileManager fileExistsAtPath: folder] == NO)
	{
		[fileManager createDirectoryAtPath: folder attributes: nil];
	}
	NSString *filename = @"Queue.automatorqueue";
	NSString *filePath = [folder stringByAppendingPathComponent:filename];
	
	NSDictionary * rootObject;
    @try
	{
		rootObject = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
		NSArray *tempQueue = [rootObject valueForKey:@"queue"];
		NSArray *tempSeries = [rootObject valueForKey:@"serieslink"];
		[queueController addObjects:tempQueue];
		[pvrQueueController addObjects:tempSeries];
	}
	@catch (NSException *e)
	{
		[fileManager removeItemAtPath:filePath error:nil];
		NSLog(@"Unable to load saved application data. Deleted the data file.");
		rootObject=nil;
	}
	
	//Read Format Preferences
	
	filename = @"Formats.automatorqueue";
	filePath = [folder stringByAppendingPathComponent:filename];
	
    @try
	{
		rootObject = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
		[radioFormatController addObjects:[rootObject valueForKey:@"radioFormats"]];
		[tvFormatController addObjects:[rootObject valueForKey:@"tvFormats"]];
	}
	@catch (NSException *e)
	{
		[fileManager removeItemAtPath:filePath error:nil];
		NSLog(@"Unable to load saved application data. Deleted the data file.");
		rootObject=nil;
	}
	//Adds Defaults to Type Preferences
	if ([[tvFormatController arrangedObjects] count] == 0)
	{
		TVFormat *format1 = [[TVFormat alloc] init];
		[format1 setFormat:@"Flash - Standard"];
		TVFormat *format2 = [[TVFormat alloc] init];
		[format2 setFormat:@"iPhone"];
		[tvFormatController addObjects:[NSArray arrayWithObjects:format2,format1,nil]];
	}
	if ([[radioFormatController arrangedObjects] count] == 0)
	{
		RadioFormat *format1 = [[RadioFormat alloc] init];
		[format1 setFormat:@"Flash"];
		RadioFormat *format2 = [[RadioFormat alloc] init];
		[format2 setFormat:@"iPhone"];
		[radioFormatController addObjects:[NSArray arrayWithObjects:format2,format1,nil]];
	}
		
	//Growl Initialization
	[GrowlApplicationBridge setGrowlDelegate:@""];
	
	//Populate Live TV Channel List
	LiveTVChannel *bbcOne = [[LiveTVChannel alloc] initWithChannelName:@"BBC One"];
	LiveTVChannel *bbcTwo = [[LiveTVChannel alloc] initWithChannelName:@"BBC Two"];
	LiveTVChannel *bbcNews24 = [[LiveTVChannel alloc] initWithChannelName:@"BBC News 24"];
	[liveTVChannelController setContent:[NSArray arrayWithObjects:bbcOne,bbcTwo,bbcNews24,nil]];
	[liveTVTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application
{
	return YES;
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	return NSTerminateNow;
}
- (BOOL)windowShouldClose:(id)sender
{
	if ([sender isEqualTo:mainWindow])
	{
		if (runUpdate)
		{
			NSAlert *updateAlert = [NSAlert alertWithMessageText:@"Are you sure?" 
												   defaultButton:@"No" 
												 alternateButton:@"Yes" 
													 otherButton:nil 
									   informativeTextWithFormat:@"Get iPlayer Automator is currently updating the cache." 
									@"If you proceed with quiting, some series-link information will be lost." 
									@"It is not reccommended to quit during an update. Are you sure you wish to quit?"];
			NSInteger response = [updateAlert runModal];
			if (response == NSAlertDefaultReturn) return NO;
			else if (response == NSAlertAlternateReturn) return YES;
		}
		else if (runDownloads)
		{
			NSAlert *downloadAlert = [NSAlert alertWithMessageText:@"Are you sure you wish to quit?" 
													 defaultButton:@"No" 
												   alternateButton:@"Yes" 
													   otherButton:nil 
										 informativeTextWithFormat:@"You are currently downloading shows. If you quit, they will be cancelled."];
			NSInteger response = [downloadAlert runModal];
			if (response == NSAlertDefaultReturn) return NO;
			else return YES;
			
		}
		return YES;
	}
	else return YES;
}
- (void)windowWillClose:(NSNotification *)note
{
	if ([[note object] isEqualTo:mainWindow]) [application terminate:self];
}
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	//End Downloads if Running
	if (runDownloads)
		[currentDownload cancelDownload:nil];
	
	//Save Queue & Series-Link
	NSMutableArray *tempQueue = [[NSMutableArray alloc] initWithArray:[queueController arrangedObjects]];
	NSMutableArray *tempSeries = [[NSMutableArray alloc] initWithArray:[pvrQueueController arrangedObjects]];
	NSMutableArray *temptempQueue = [[NSMutableArray alloc] initWithArray:tempQueue];
	for (Programme *show in temptempQueue)
	{
		if (([[show complete] isEqualToNumber:[NSNumber numberWithBool:YES]] && [[show successful] isEqualToNumber:[NSNumber numberWithBool:YES]]) 
			|| [[show status] isEqualToString:@"Added by Series-Link"]) [tempQueue removeObject:show];
	}
	NSFileManager *fileManager = [NSFileManager defaultManager];
    
	NSString *folder = @"~/Library/Application Support/Get iPlayer Automator/";
	folder = [folder stringByExpandingTildeInPath];
	if ([fileManager fileExistsAtPath: folder] == NO)
	{
		[fileManager createDirectoryAtPath: folder attributes: nil];
	}
	NSString *filename = @"Queue.automatorqueue";
	NSString *filePath = [folder stringByAppendingPathComponent:filename];
	
	NSMutableDictionary * rootObject;
	rootObject = [NSMutableDictionary dictionary];
    
	[rootObject setValue:tempQueue forKey:@"queue"];
	[rootObject setValue:tempSeries forKey:@"serieslink"];
	[NSKeyedArchiver archiveRootObject: rootObject toFile: filePath];
	
	filename = @"Formats.automatorqueue";
	filePath = [folder stringByAppendingPathComponent:filename];
	
	rootObject = [NSMutableDictionary dictionary];
	
	[rootObject setValue:[tvFormatController arrangedObjects] forKey:@"tvFormats"];
	[rootObject setValue:[radioFormatController arrangedObjects] forKey:@"radioFormats"];
	[NSKeyedArchiver archiveRootObject:rootObject toFile:filePath];
}
- (void)updater:(SUUpdater *)updater didFindValidUpdate:(SUAppcastItem *)update
{
	[GrowlApplicationBridge notifyWithTitle:@"Update Available!" 
								description:[NSString stringWithFormat:@"Get iPlayer Automator %@ is available.",[update displayVersionString]]
						   notificationName:@"New Version Available"
								   iconData:nil
								   priority:0
								   isSticky:NO
							   clickContext:nil];
}
#pragma mark Cache Update
- (IBAction)updateCache:(id)sender
{
	runSinceChange=YES;
	runUpdate=YES;
	[mainWindow setDocumentEdited:YES];
	
	NSString *cacheExpiryArg;
	if ([[sender class] isEqualTo:[[NSString stringWithString:@""] class]])
	{
		cacheExpiryArg = @"-e1";
	}
	else
	{
		cacheExpiryArg = [[NSString alloc] initWithFormat:@"-e%d", ([[[NSUserDefaults standardUserDefaults] objectForKey:@"CacheExpiryTime"] intValue]*3600)];
	}
	NSString *typeArgument = [[NSString alloc] initWithString:[self typeArgument:nil]];
	
	[self addToLog:@"Updating Program Index Feeds...\r" :self];
	didUpdate=NO;
	
	//UI might not be loaded yet
	@try
	{
		//Update Should Be Running:
		[currentIndicator setIndeterminate:YES];
		[currentIndicator startAnimation:nil];
		[currentProgress setStringValue:@"Updating Program Indexes..."];
		//Shouldn't search until update is done.
		[searchField setEnabled:NO];
		[stopButton setEnabled:NO];
		[startButton setEnabled:NO];
	}
	@catch (NSException *e) {
		NSLog(@"NO UI");
	}
	getiPlayerUpdateArgs = [[NSArray alloc] initWithObjects:getiPlayerPath,cacheExpiryArg,typeArgument,@"--nopurge",profileDirArg,nil];
	getiPlayerUpdateTask = [[NSTask alloc] init];
	[getiPlayerUpdateTask setLaunchPath:@"/usr/bin/perl"];
	[getiPlayerUpdateTask setArguments:getiPlayerUpdateArgs];
	getiPlayerUpdatePipe = [[NSPipe alloc] init];
	[getiPlayerUpdateTask setStandardOutput:getiPlayerUpdatePipe];
	[getiPlayerUpdateTask setStandardError:getiPlayerUpdatePipe];
	
	NSFileHandle *fh = [getiPlayerUpdatePipe fileHandleForReading];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	[nc addObserver:self
		   selector:@selector(dataReady:)
			   name:NSFileHandleReadCompletionNotification
			 object:fh];
	[getiPlayerUpdateTask launch];
	
	[fh readInBackgroundAndNotify];
}
- (void)dataReady:(NSNotification *)n
{
    NSData *d;
    d = [[n userInfo] valueForKey:NSFileHandleNotificationDataItem];
	
    if ([d length] > 0) {
		NSString *s = [[NSString alloc] initWithData:d
											encoding:NSUTF8StringEncoding];
		if ([s hasPrefix:@"INFO:"])
		{
			[self addToLog:[NSString stringWithString:s] :nil];
			NSScanner *scanner = [NSScanner scannerWithString:s];
			NSString *r;
			[scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&r];
			NSString *infoMessage = [[NSString alloc] initWithFormat:@"Updating Program Indexes: %@", r];
			[currentProgress setStringValue:infoMessage];
			infoMessage = nil;
			scanner = nil;
		}
		else if ([s isEqualToString:@"."])
		{
			NSMutableString *infomessage = [[NSMutableString alloc] initWithFormat:@"%@.", [currentProgress stringValue]];
			if ([infomessage hasSuffix:@".........."]) [infomessage deleteCharactersInRange:NSMakeRange([infomessage length]-9, 9)];
			[currentProgress setStringValue:infomessage];
			infomessage = nil;
			didUpdate = YES;
		}
    }
	else
	{
		getiPlayerUpdateTask = nil;
		[self getiPlayerUpdateFinished];
	}
	
    // If the task is running, start reading again
    if (getiPlayerUpdateTask)
        [[getiPlayerUpdatePipe fileHandleForReading] readInBackgroundAndNotify];
}
- (void)getiPlayerUpdateFinished
{
	runUpdate=NO;
	[mainWindow setDocumentEdited:NO];
	
	[currentProgress setStringValue:@""];
	[currentIndicator setIndeterminate:NO];
	[currentIndicator stopAnimation:nil];
	[searchField setEnabled:YES];
	getiPlayerUpdatePipe = nil;
	getiPlayerUpdateTask = nil;
	[startButton setEnabled:YES];
	
	if (didUpdate)
	{
		[GrowlApplicationBridge notifyWithTitle:@"Index Updated" 
									description:@"The program index was updated."
							   notificationName:@"Index Updating Completed"
									   iconData:nil
									   priority:0
									   isSticky:NO
								   clickContext:nil];
		[self addToLog:@"Index Updated." :self];
	}
	else
	{
		runSinceChange=NO;
		[self addToLog:@"Index was Up-To-Date." :self];
	}
	
	
	//Long, Complicated Bit of Code that updates the index number.
	//This is neccessary because if the cache is updated, the index number will almost certainly change.
	NSArray *tempQueue = [queueController arrangedObjects];
	for (Programme *show in tempQueue)
	{
		BOOL foundMatch=NO;
		if ([[show showName] length] > 0)
			{
				NSTask *pipeTask = [[NSTask alloc] init];
				NSPipe *newPipe = [[NSPipe alloc] init];
				NSFileHandle *readHandle2 = [newPipe fileHandleForReading];
				NSData *someData;
		
				NSString *name = [[show showName] copy];
				NSScanner *scanner = [NSScanner scannerWithString:name];
				NSString *searchArgument;
				[scanner scanUpToString:@" - " intoString:&searchArgument];
				NSLog(searchArgument);
				// write handle is closed to this process
				[pipeTask setStandardOutput:newPipe];
				[pipeTask setStandardError:newPipe];
				[pipeTask setLaunchPath:@"/usr/bin/perl"];
				[pipeTask setArguments:[NSArray arrayWithObjects:getiPlayerPath,profileDirArg,@"--nopurge",noWarningArg,[self typeArgument:nil],[self cacheExpiryArgument:nil],listFormat,
										searchArgument,nil]];
				NSMutableString *taskData = [[NSMutableString alloc] initWithString:@""];
				[pipeTask launch];
				while ((someData = [readHandle2 availableData]) && [someData length]) {
						[taskData appendString:[[NSString alloc] initWithData:someData
																	 encoding:NSUTF8StringEncoding]];
				}
				NSString *string = [NSString stringWithString:taskData];
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
				for (NSString *string in array)
				{
					if (![string isEqualToString:@"Matches:"] && ![string hasPrefix:@"INFO:"] && ![string hasPrefix:@"WARNING:"] && [string length]>0)
					{
						@try 
						{
							NSScanner *myScanner = [NSScanner scannerWithString:string];
							Programme *p = [[Programme alloc] init];
							NSString *temp_pid, *temp_showName, *temp_tvNetwork, *temp_type;
							[myScanner scanUpToString:@":" intoString:&temp_pid];
							[myScanner scanUpToString:@"," intoString:&temp_type];
							[myScanner scanString:@", ~" intoString:NULL];
							[myScanner scanUpToString:@"~," intoString:&temp_showName];
							[myScanner scanString:@"~," intoString:NULL];
							[myScanner scanUpToString:@"jkhjjhkjh" intoString:&temp_tvNetwork];
							[p setValue:temp_pid forKey:@"pid"];
							[p setValue:temp_showName forKey:@"showName"];
							[p setValue:temp_tvNetwork forKey:@"tvNetwork"];
							if ([temp_type isEqualToString:@"radio"]) [p setValue:[NSNumber numberWithBool:YES] forKey:@"radio"];
							if ([[p showName] isEqualToString:[show showName]])
							{
								[show setValue:[p pid] forKey:@"pid"];
								foundMatch=YES;
								break;
							}
						}
						@catch (NSException *e) {
							NSAlert *searchException = [[NSAlert alloc] init];
							[searchException addButtonWithTitle:@"OK"];
							[searchException setMessageText:[NSString stringWithFormat:@"Invalid Output!"]];
							[searchException setInformativeText:@"Please check your query. You query must not alter the output format of Get_iPlayer."];
							[searchException setAlertStyle:NSWarningAlertStyle];
							[searchException runModal];
							searchException = nil;
						}
					}
					else
					{
						if ([string hasPrefix:@"Unknown option:"] || [string hasPrefix:@"Option"] || [string hasPrefix:@"Usage"])
						{
							NSLog(@"Unknown Option");
						}
					}
				}
				if (!foundMatch)
				{
					[show setValue:@"Not Currently Available" forKey:@"status"];
					[show setValue:[NSNumber numberWithBool:YES] forKey:@"complete"];
					[show setValue:[NSNumber numberWithBool:NO] forKey:@"successful"];
				}
		}
		
	}
	
	//Don't want to add these until the cache is up-to-date!
	if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SeriesLinkStartup"] isEqualToNumber:[NSNumber numberWithBool:YES]])
	{
		[self addSeriesLinkToQueue:self];
	}
	
	//Check for Updates - Don't want to prompt the user when updates are running.
	SUUpdater *updater = [SUUpdater sharedUpdater];
	[updater checkForUpdatesInBackground];
	
	//If this is an update initiated by the scheduler, run the downloads.
	if (runScheduled) 
	{
		[self startDownloads:self];
		runScheduled=NO;
	}
	
	if (runDownloads)
	{
		[self addToLog:@"Download(s) are still running." :self];
	}
}
- (IBAction)forceUpdate:(id)sender
{
	[self updateCache:@"force"];
}
#pragma mark Log
- (void)showLog:(id)sender
{
	[logWindow makeKeyAndOrderFront:self];
	
	//Make sure the log scrolled to the bottom. It might not have if the Log window was not open.
	NSAttributedString *temp_log = [[NSAttributedString alloc] initWithAttributedString:[self valueForKey:@"log_value"]];
	[log scrollRangeToVisible:NSMakeRange([temp_log length], [temp_log length])];
}
- (void)postLog:(NSNotification *)note
{
	NSString *tempLog = [log string];
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc postNotification:[NSNotification notificationWithName:@"Log" object:tempLog]];
}
-(void)addToLog:(NSString *)string :(id)sender {
	//Get Current Log
	NSMutableAttributedString *current_log = [[NSMutableAttributedString alloc] initWithAttributedString:log_value];
	
	//Define Return Character for Easy Use
	NSAttributedString *return_character = [[NSAttributedString alloc] initWithString:@"\r"];
	
	//Initialize Sender Prefix
	NSAttributedString *from_string;
	if (sender != nil)
	{
		from_string = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@: ", [sender description]]];
	}
	else
	{
		from_string = [[NSAttributedString alloc] initWithString:@""];
	}
	
	//Convert String to Attributed String
	NSAttributedString *converted_string = [[NSAttributedString alloc] initWithString:string];
	
	//Append the new items to the log.
	[current_log appendAttributedString:return_character];
	[current_log appendAttributedString:from_string];
	[current_log appendAttributedString:converted_string];
	
	//Make the Text White.
	[current_log addAttribute:NSForegroundColorAttributeName
						value:[NSColor whiteColor]
						range:NSMakeRange(0, [current_log length])];
	
	//Update the log.
	[self setValue:current_log forKey:@"log_value"];
	
	//Scroll log to bottom only if it is visible.
	if ([logWindow isVisible]) {
		[log scrollRangeToVisible:NSMakeRange([current_log length], [current_log length])];
	}
}
- (void)addToLogNotification:(NSNotification *)note
{
	NSString *logMessage = [[note userInfo] objectForKey:@"message"];
	[self addToLog:logMessage :[note object]];
}
- (IBAction)copyLog:(id)sender
{
	NSString *unattributedLog = [log string];
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSArray *types = [[NSArray alloc] initWithObjects:NSStringPboardType,nil];
	[pb declareTypes:types owner:self];
	[pb setString:unattributedLog forType:NSStringPboardType];
}
#pragma mark Search
- (IBAction)mainSearch:(id)sender
{
	NSString *searchTerms = [searchField stringValue];
	
	if([searchTerms length] > 0)
	{
		searchTask = [[NSTask alloc] init];
		searchPipe = [[NSPipe alloc] init];
		
		[searchTask setLaunchPath:@"/usr/bin/perl"];
		NSString *searchArgument = [[NSString alloc] initWithString:searchTerms];
		NSString *cacheExpiryArg = [self cacheExpiryArgument:nil];
		NSString *typeArgument = [self typeArgument:nil];
		NSArray *args = [[NSArray alloc] initWithObjects:getiPlayerPath,noWarningArg,cacheExpiryArg,typeArgument,listFormat,@"--long",@"--nopurge",searchArgument,profileDirArg,nil];
		[searchTask setArguments:args];
		
		[searchTask setStandardOutput:searchPipe];
		NSFileHandle *fh = [searchPipe fileHandleForReading];
		
		NSNotificationCenter *nc;
		nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self
			   selector:@selector(searchDataReady:)
				   name:NSFileHandleReadCompletionNotification
				 object:fh];
		[nc addObserver:self
			   selector:@selector(searchFinished:)
				   name:NSTaskDidTerminateNotification
				 object:searchTask];
		searchData = [[NSMutableString alloc] init];
		[searchTask launch];
		[searchIndicator startAnimation:nil];
		[fh readInBackgroundAndNotify];
	}
}

- (void)searchDataReady:(NSNotification *)n
{
    NSData *d;
    d = [[n userInfo] valueForKey:NSFileHandleNotificationDataItem];
	
    if ([d length] > 0) {
		NSString *s = [[NSString alloc] initWithData:d
											encoding:NSUTF8StringEncoding];
		[searchData appendString:s];
	}
	else
	{
		searchTask = nil;
	}
	
    // If the task is running, start reading again
    if (searchTask)
        [[searchPipe fileHandleForReading] readInBackgroundAndNotify];
}
- (void)searchFinished:(NSNotification *)n
{
	BOOL foundShow=NO;
	[resultsController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[resultsController arrangedObjects] count])]];
	NSString *string = [NSString stringWithString:searchData];
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
	for (NSString *string in array)
	{
		if (![string isEqualToString:@"Matches:"] && ![string hasPrefix:@"INFO:"] && ![string hasPrefix:@"WARNING:"] && [string length]>0)
		{
			@try {
				NSScanner *myScanner = [NSScanner scannerWithString:string];
				NSString *temp_pid, *temp_showName, *temp_tvNetwork, *temp_type;
				[myScanner scanUpToString:@":" intoString:&temp_pid];
				[myScanner scanUpToCharactersFromSet:[NSCharacterSet letterCharacterSet] intoString:NULL];
				[myScanner scanUpToString:@", ~" intoString:&temp_type];
				[myScanner scanString:@", ~" intoString:NULL];
				[myScanner scanUpToString:@"~," intoString:&temp_showName];
				[myScanner scanUpToCharactersFromSet:[NSCharacterSet letterCharacterSet] intoString:NULL];
				[myScanner scanUpToString:@"," intoString:&temp_tvNetwork];
				Programme *p = [[Programme alloc] initWithInfo:nil pid:temp_pid programmeName:temp_showName network:temp_tvNetwork];
				if ([temp_type isEqualToString:@"radio"])
				{
					[p setValue:[NSNumber numberWithBool:YES] forKey:@"radio"];
				}
				[resultsController addObject:p];
				foundShow=YES;
			}
			@catch (NSException *e) {
				NSAlert *searchException = [[NSAlert alloc] init];
				[searchException addButtonWithTitle:@"OK"];
				[searchException setMessageText:[NSString stringWithFormat:@"Invalid Output!"]];
				[searchException setInformativeText:@"Please check your query. You query must not alter the output format of Get_iPlayer."];
				[searchException setAlertStyle:NSWarningAlertStyle];
				[searchException runModal];
				searchException = nil;
			}
		}
		else
		{
			if ([string hasPrefix:@"Unknown option:"] || [string hasPrefix:@"Option"] || [string hasPrefix:@"Usage"])
			{
				NSLog(@"Unknown Option");
				[searchIndicator stopAnimation:nil];
				return;
			}
		}
	}
	[searchIndicator stopAnimation:nil];
	if (!foundShow)
	{
		NSAlert *noneFound = [NSAlert alertWithMessageText:@"No Shows Found" 
											 defaultButton:@"OK" 
										   alternateButton:nil 
											   otherButton:nil 
								 informativeTextWithFormat:@"0 shows were found for your search terms. Please check your spelling!"];
		[noneFound runModal];
	}
}
#pragma mark Queue
- (NSArray *)queueArray
{
	return [NSArray arrayWithArray:queueArray];
}
- (void)setQueueArray:(NSArray *)queue
{
	queueArray = [NSMutableArray arrayWithArray:queue];
}
- (IBAction)addToQueue:(id)sender
{
	//Check to make sure the programme isn't already in the queue before adding it.
	NSMutableArray *selectedObjects = [NSMutableArray arrayWithArray:[resultsController selectedObjects]];
	NSArray *queuedObjects = [queueController arrangedObjects];
	for (Programme *show in selectedObjects)
	{
		BOOL add=YES;
		for (Programme *queuedShow in queuedObjects)
		{
			if ([[show showName] isEqualToString:[queuedShow showName]]) add=NO;
		}
		if (add) 
		{
			if (runDownloads) [show setValue:@"Waiting..." forKey:@"status"];
			[queueController addObject:show];
		}
	}
}
- (IBAction)getName:(id)sender
{
	NSArray *selectedObjects = [queueController selectedObjects];
	for (Programme *pro in selectedObjects)
	{
		[self getNameForProgramme:pro];
	}
}
- (void)getNameForProgramme:(Programme *)pro
{
	NSTask *getNameTask = [[NSTask alloc] init];
	NSPipe *getNamePipe = [[NSPipe alloc] init];
	NSMutableString *getNameData = [[NSMutableString alloc] initWithString:@""];
	
	NSString *listArgument = [[NSString alloc] initWithFormat:@"--listformat=<index> <pid> <type> <name> - <episode>", [pro valueForKey:@"pid"]];
	NSString *cacheExpiryArg = [self cacheExpiryArgument:nil];
	NSArray *args = [[NSArray alloc] initWithObjects:getiPlayerPath,noWarningArg,@"--nopurge",cacheExpiryArg,[self typeArgument:nil],listArgument,profileDirArg,nil];
	[getNameTask setArguments:args];
	[getNameTask setLaunchPath:@"/usr/bin/perl"];
	
	[getNameTask setStandardOutput:getNamePipe];
	NSFileHandle *getNameFh = [getNamePipe fileHandleForReading];
	NSData *inData;
	
	[getNameTask launch];
	
	while ((inData = [getNameFh availableData]) && [inData length]) {
		NSString *tempData = [[NSString alloc] initWithData:inData encoding:NSUTF8StringEncoding];
		[getNameData appendString:tempData];
	}
	[self processGetNameData:getNameData forProgramme:pro];
}
- (void)processGetNameData:(NSString *)getNameData forProgramme:(Programme *)p
{
	NSString *string = getNameData;
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
	int i = 0;
	NSString *wantedID = [p valueForKey:@"pid"];
	BOOL found=NO;
	for (NSString *string in array)
	{
		i++;
		if (i>1 && i<[array count]-1)
		{
			NSString *pid, *showName, *index, *type;
			@try{
				NSScanner *scanner = [NSScanner scannerWithString:string];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&index];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&pid];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&type];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet]  intoString:&showName];
				scanner = nil;
			}
			@catch (NSException *e) {
				NSAlert *getNameException = [[NSAlert alloc] init];
				[getNameException addButtonWithTitle:@"OK"];
				[getNameException setMessageText:[NSString stringWithFormat:@"Unknown Error!"]];
				[getNameException setInformativeText:@"An unknown error occured whilst trying to parse Get_iPlayer output."];
				[getNameException setAlertStyle:NSWarningAlertStyle];
				[getNameException runModal];
				getNameException = nil;
			}
			if ([wantedID isEqualToString:pid])
			{
				found=YES;
				[p setValue:showName forKey:@"showName"];
				[p setValue:index forKey:@"pid"];
				if ([type isEqualToString:@"radio"]) [p setValue:[NSNumber numberWithBool:YES] forKey:@"radio"];
			}
			else if ([wantedID isEqualToString:index])
			{
				found=YES;
				[p setValue:showName forKey:@"showName"];
				if ([type isEqualToString:@"radio"]) [p setValue:[NSNumber numberWithBool:YES] forKey:@"radio"];
			}
		}
			
	}
	if (!found)
		[p setValue:@"Not Found" forKey:@"showName"];
	else
		[p setProcessedPID:[NSNumber numberWithBool:YES]];
	
}
- (IBAction)getCurrentWebpage:(id)sender
{
	//Get Default Browser
	NSString *browser = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultBrowser"];
	
	//Prepare Pointer for URL
	NSString *url;
	
	//Prepare Alert in Case the Browser isn't Open
	NSAlert *browserNotOpen = [[NSAlert alloc] init];
	[browserNotOpen addButtonWithTitle:@"OK"];
	[browserNotOpen setMessageText:[NSString stringWithFormat:@"%@ is not open.", browser]];
	[browserNotOpen setInformativeText:@"Please ensure your browser is running and has at least one window open."];
	[browserNotOpen setAlertStyle:NSWarningAlertStyle];
	
	//Get URL
	if ([browser isEqualToString:@"Safari"])
	{
		BOOL foundURL=NO;
		SafariApplication *Safari = [SBApplication applicationWithBundleIdentifier:@"com.apple.Safari"];
		if ([Safari isRunning])
		{
			@try
			{
				SBElementArray *documents = [Safari documents];
				if ([[NSNumber numberWithUnsignedInteger:[documents count]] intValue])
				{
					for (SafariDocument *document in documents)
					{
						if ([[document URL] hasPrefix:@"http://www.bbc.co.uk/iplayer/episode/"] || [[document URL] hasPrefix:@"http://www.itv.com/ITVPlayer/Video/default.html?ViewType"])
						{
							url = [NSString stringWithString:[document URL]];
							foundURL=YES;
						}
					}
					if (foundURL==NO)
					{
						url = [NSString stringWithString:[[documents objectAtIndex:0] URL]];
					}
				}
				else
				{
					[browserNotOpen runModal];
					return;
				}
			}
			@catch (NSException *e)
			{
				[browserNotOpen runModal];
				return;
			}
		}
		else
		{
			[browserNotOpen runModal];
			return;
		}
		
	}
	else if ([browser isEqualToString:@"Firefox"])
	{
		NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"GetFireFoxURL" ofType:@"applescript"];
		NSURL *scriptLocation = [[NSURL alloc] initFileURLWithPath:scriptPath];
		if (scriptLocation)
		{
			NSDictionary *errorDic;
			NSAppleScript *getFirefoxURL = [[NSAppleScript alloc] initWithContentsOfURL:scriptLocation error:&errorDic];
			if (getFirefoxURL)
			{
				NSDictionary *executionError;
				NSAppleEventDescriptor *result = [getFirefoxURL executeAndReturnError:&executionError];
				if (result)
				{
					url = [[NSString alloc] initWithString:[result stringValue]];
					if ([url isEqualToString:@"Error"]) 
					{
						[browserNotOpen runModal];
						return;
					}
				}
			}
		}
	}
	else if ([browser isEqualToString:@"Camino"])
	{
		/* AppleScript Version
		NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"GetCaminoURL" ofType:@"applescript"];
		NSURL *scriptLocation = [[NSURL alloc] initFileURLWithPath:scriptPath];
		if (scriptLocation)
		{
			NSDictionary *errorDic;
			NSAppleScript *getCaminoURL = [[NSAppleScript alloc] initWithContentsOfURL:scriptLocation error:&errorDic];
			if (getCaminoURL)
			{
				NSDictionary *executionError;
				NSAppleEventDescriptor *result = [getCaminoURL executeAndReturnError:&executionError];
				if (result)
				{
					url = [[NSString alloc] initWithString:[result stringValue]];
					if ([url isEqualToString:@"Error"]) 
					{
						[browserNotOpen runModal];
						return;
					}
				}
			}
		}
		 */
		
		//Scripting Bridge Version
		CaminoApplication *camino = [SBApplication applicationWithBundleIdentifier:@"org.mozilla.camino"];
		if ([camino isRunning])
		{
			BOOL foundURL=NO;
			NSMutableArray *tabsArray = [[NSMutableArray alloc] init];
			SBElementArray *windows = [camino browserWindows];
			if ([[NSNumber numberWithUnsignedInteger:[windows count]] intValue])
			{
				for (CaminoBrowserWindow *window in windows)
				{
					SBElementArray *tabs = [window tabs];
					if ([[NSNumber numberWithUnsignedInteger:[tabs count]] intValue]) 
					{
						[tabsArray addObjectsFromArray:tabs];
					}
				}
			}
			else [browserNotOpen runModal];
			if ([[NSNumber numberWithUnsignedInteger:[tabsArray count]] intValue])
			{
				for (CaminoTab *tab in tabsArray)
				{
					if ([[tab URL] hasPrefix:@"http://bbc.co.uk/iplayer/episode"] || [[tab URL] hasPrefix:@"http://www.itv.com/ITVPlayer/Video/default.html?ViewType"])
					{
						url = [[NSString alloc] initWithString:[tab URL]];
						foundURL=YES;
						break;
					}
				}
				if (foundURL==NO)
				{
					url = [[NSString alloc] initWithString:[[tabsArray objectAtIndex:0] URL]];
				}
			}
			else
			{
				[browserNotOpen runModal];
				return;
			}
		}
		else
		{
			[browserNotOpen runModal];
			return;
		}
	}
	else if ([browser isEqualToString:@"Opera"])
	{
		NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"GetOperaURL" ofType:@"applescript"];
		NSURL *scriptLocation = [[NSURL alloc] initFileURLWithPath:scriptPath];
		if (scriptLocation)
		{
			NSDictionary *errorDic;
			NSAppleScript *getOperaURL = [[NSAppleScript alloc] initWithContentsOfURL:scriptLocation error:&errorDic];
			if (getOperaURL)
			{
				NSDictionary *executionError;
				NSAppleEventDescriptor *result = [getOperaURL executeAndReturnError:&executionError];
				if (result)
				{
					url = [[NSString alloc] initWithString:[result stringValue]];
					if ([url isEqualToString:@"Error"]) 
					{
						[browserNotOpen runModal];
						return;
					}
				}
			}
		}
	}
	
	//Process URL
	if([url hasPrefix:@"http://www.bbc.co.uk/iplayer/episode/"])
	{
		NSString *pid;
		NSScanner *urlScanner = [[NSScanner alloc] initWithString:url];
		[urlScanner scanUpToString:@"pisode" intoString:nil];
		[urlScanner scanUpToString:@"b" intoString:nil];
		[urlScanner scanUpToString:@"/" intoString:&pid];
		Programme *newProg = [[Programme alloc] init];
		[newProg setValue:pid forKey:@"pid"];
		[queueController addObject:newProg];
		[self getNameForProgramme:newProg];
	}
	else if ([url hasPrefix:@"http://www.itv.com/ITVPlayer/Video/default.html?ViewType"])
	{
		NSString *pid;
		NSScanner *urlScanner = [NSScanner scannerWithString:url];
		[urlScanner scanUpToString:@"Filter" intoString:nil];
		[urlScanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
		[urlScanner scanUpToString:@"&" intoString:&pid];
		Programme *newProg = [[Programme alloc] init];
		[newProg setValue:pid forKey:@"pid"];
		[queueController addObject:newProg];
		[self getNameForProgramme:newProg];
	}
	else
	{
		NSAlert *invalidURL = [[NSAlert alloc] init];
		[invalidURL addButtonWithTitle:@"OK"];
		[invalidURL setMessageText:[NSString stringWithFormat:@"Invalid URL: %@",url]];
		[invalidURL setInformativeText:@"Please ensure the browser is open to an iPlayer page."];
		[invalidURL setAlertStyle:NSWarningAlertStyle];
		[invalidURL runModal];
	}

}
- (IBAction)removeFromQueue:(id)sender
{
	//Check to make sure one of the shows isn't currently downloading.
	if (runDownloads)
	{
		BOOL downloading=NO;
		NSArray *selected = [queueController selectedObjects];
		for (Programme *show in selected)
		{
			if (![[show status] isEqualToString:@"Waiting..."] && ![[show complete] isEqualToNumber:[NSNumber numberWithBool:YES]])
			{
				downloading = YES;
			}
		}
		if (downloading)
		{
			NSAlert *cantRemove = [NSAlert alertWithMessageText:@"A Selected Show is Currently Downloading." 
												  defaultButton:@"OK" 
												alternateButton:nil 
													otherButton:nil 
									  informativeTextWithFormat:@"You can not remove a show that is currently downloading." 
																@"Please stop the downloads then remove the download if you wish to cancel it."];
			[cantRemove runModal];
		}
		else
		{
			[queueController remove:self];
		}
	}
	else
	{
		[queueController remove:self];
	}
}
#pragma mark Download Controller
- (IBAction)startDownloads:(id)sender
{
	NSAlert *whatAnIdiot = [NSAlert alertWithMessageText:@"No Shows in Queue!" 
										   defaultButton:nil 
										 alternateButton:nil 
											 otherButton:nil 
							   informativeTextWithFormat:@"Try adding shows to the queue before clicking start; " 
							@"Get iPlayer Automator needs to know what to download."];
	if ([[queueController arrangedObjects] count] > 0)
	{
		BOOL foundOne=NO;
		runDownloads=YES;
		[mainWindow setDocumentEdited:YES];
		[self addToLog:@"\rAppController: Starting Downloads" :nil];
		//Clean-Up Queue
		NSArray *tempQueue = [queueController arrangedObjects];
		for (Programme *show in tempQueue)
		{
			if ([[show successful] isEqualToNumber:[NSNumber numberWithBool:NO]])
			{
				if ([[show processedPID] boolValue])
				{
					[show setComplete:[NSNumber numberWithBool:NO]];
					[show setStatus:@"Waiting..."];
					foundOne=YES;
				}
				else
				{
					[self getNameForProgramme:show];
					if ([[show showName] isEqualToString:@"Not Found"])
					{
						[show setComplete:[NSNumber numberWithBool:YES]];
						[show setSuccessful:[NSNumber numberWithBool:NO]];
						[show setStatus:@"Failed: Not in Cache"];
					}
					else
					{
						[show setComplete:[NSNumber numberWithBool:NO]];
						[show setStatus:@"Waiting..."];
						foundOne=YES;
					}
				}
			}
			else
			{
				[queueController removeObject:show];
			}
		}
		if (foundOne)
		{
			//Start First Download
			tempQueue = [queueController arrangedObjects];
			[self addToLog:[NSString stringWithFormat:@"\rDownloading Show %d/%d:\r",
							(1),
							[tempQueue count]]
						  :nil];
			for (Programme *show in tempQueue)
			{
				if ([[show complete] isEqualToNumber:[NSNumber numberWithBool:NO]])
				{
					currentDownload = [[Download alloc] initWithProgramme:show 
															 tvFormats:[tvFormatController arrangedObjects] 
														  radioFormats:[radioFormatController arrangedObjects]];
					break;
				}
			}
			[startButton setEnabled:NO];
			[stopButton setEnabled:YES];
			[currentIndicator setIndeterminate:NO];
			[currentIndicator setDoubleValue:0.0];
			
			NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
			[nc addObserver:self selector:@selector(setPercentage:) name:@"setPercentage" object:nil];
			[nc addObserver:self selector:@selector(setProgress:) name:@"setCurrentProgress" object:nil];
			[nc addObserver:self selector:@selector(nextDownload:) name:@"DownloadFinished" object:nil];
		}
		else
		{
			[whatAnIdiot runModal];
			runDownloads=NO;
			[mainWindow setDocumentEdited:NO];
		}
	}
	else
	{
		[whatAnIdiot runModal];
		runDownloads=NO;
		[mainWindow setDocumentEdited:NO];
	}
}
- (IBAction)stopDownloads:(id)sender
{
	runDownloads=NO;
	[currentDownload cancelDownload:self];
	[[currentDownload show] setStatus:@"Cancelled"];
	if (!runUpdate)
		[startButton setEnabled:YES];
	[stopButton setEnabled:NO];
	currentDownload = nil;
	[currentIndicator stopAnimation:nil];
	[currentIndicator setDoubleValue:0];
	if (!runUpdate)
	{
		[currentProgress setStringValue:@""];
		[mainWindow setDocumentEdited:NO];
	}
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver:self name:@"setPercentage" object:nil]; 
	[nc removeObserver:self name:@"setCurrentProgress" object:nil]; 
	[nc removeObserver:self name:@"DownloadFinished" object:nil]; 
	
	NSArray *tempQueue = [queueController arrangedObjects];
	for (Programme *show in tempQueue)
		if ([[show status] isEqualToString:@"Waiting..."]) [show setStatus:@""];
	}
- (void)setPercentage:(NSNotification *)note
{	
	if ([note userInfo])
	{
		NSDictionary *userInfo = [note userInfo];
		[currentIndicator setIndeterminate:NO];
		[currentIndicator startAnimation:nil];
		[currentIndicator setDoubleValue:[[userInfo valueForKey:@"nsDouble"] doubleValue]];
	}
	else
	{
		[currentIndicator setIndeterminate:YES];
		[currentIndicator startAnimation:nil];
	}
}
- (void)setProgress:(NSNotification *)note
{
	if (!runUpdate)
		[currentProgress setStringValue:[[note userInfo] valueForKey:@"string"]];
	if (runDownloads)
	{
		[startButton setEnabled:NO];
		[stopButton setEnabled:YES];
		[mainWindow setDocumentEdited:YES];
	}
}
- (void)nextDownload:(NSNotification *)note
{
	if (runDownloads)
	{
		Programme *finishedShow = [note object];
		if ([[finishedShow successful] boolValue])
		{
			[finishedShow setValue:@"Processing..." forKey:@"status"];
			[self cleanUpPath:finishedShow];
			[self seasonEpisodeInfo:finishedShow];
			if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"AddCompletedToiTunes"] isEqualTo:[NSNumber numberWithBool:YES]])
				[self addToiTunes:finishedShow];
			else
				[finishedShow setValue:@"Download Complete" forKey:@"status"];
			
			[GrowlApplicationBridge notifyWithTitle:@"Download Finished" 
										description:[NSString stringWithFormat:@"%@ Completed Successfully",[finishedShow showName]] 
								   notificationName:@"Download Finished"
										   iconData:nil
										   priority:0
										   isSticky:NO
									   clickContext:nil];
		}
		else
		{
			[GrowlApplicationBridge notifyWithTitle:@"Download Failed" 
										description:[NSString stringWithFormat:@"%@ failed. See log for details.",[finishedShow showName]] 
								   notificationName:@"Download Failed"
										   iconData:nil
										   priority:0
										   isSticky:NO
									   clickContext:nil];
		}
		NSArray *tempQueue = [queueController arrangedObjects];
		Programme *nextShow=nil;
		NSUInteger showNum=0;
		@try
		{
			for (Programme *show in tempQueue)
			{
				showNum++;
				if (![[show complete] boolValue])
				{
					nextShow = show;
					break;
				}
			}
			if (nextShow==nil)
			{
				NSException *noneLeft = [NSException exceptionWithName:@"EndOfDownloads" reason:@"Done" userInfo:nil];
				[noneLeft raise];
			}
			[self addToLog:[NSString stringWithFormat:@"\rDownloading Show %d/%d:\r",
							([tempQueue indexOfObject:nextShow]+1),
							[tempQueue count]]
						  :nil];
			currentDownload = [[Download alloc] initWithProgramme:nextShow
													 tvFormats:[tvFormatController arrangedObjects]
												  radioFormats:[radioFormatController arrangedObjects]];
		}
		@catch (NSException *e)
		{
			//Downloads must be finished.
			[stopButton setEnabled:NO];
			[startButton setEnabled:YES];
			[currentProgress setStringValue:@""];
			[currentIndicator setDoubleValue:0];
			@try {[currentIndicator stopAnimation:nil];}
			@catch (NSException *exception) {NSLog(@"Unable to stop Animation.");}
			[currentIndicator setIndeterminate:NO];
			[self addToLog:@"\rAppController: Downloads Finished" :nil];
			NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
			[nc removeObserver:self name:@"setPercentage" object:nil]; 
			[nc removeObserver:self name:@"setCurrentProgress" object:nil]; 
			[nc removeObserver:self name:@"DownloadFinished" object:nil]; 
			
			runDownloads=NO;
			[mainWindow setDocumentEdited:NO];
			
			//Growl Notification
			NSUInteger downloadsSuccessful=0, downloadsFailed=0;
			for (Programme *show in tempQueue)
			{
				if ([[show successful] boolValue])
				{
					downloadsSuccessful++;
				}
				else
				{
					downloadsFailed++;
				}
			}
			tempQueue=nil;
			[GrowlApplicationBridge notifyWithTitle:@"Downloads Finished" 
										description:[NSString stringWithFormat:@"Downloads Successful = %d\nDownload Failed = %d",downloadsSuccessful,downloadsFailed] 
								   notificationName:@"Downloads Finished"
										   iconData:nil
										   priority:0
										   isSticky:NO
									   clickContext:nil];
			[[SUUpdater sharedUpdater] checkForUpdatesInBackground];
			
			return;
		}
	}
	return;
}

#pragma mark PVR
- (IBAction)pvrSearch:(id)sender
{
	NSString *searchTerms = [pvrSearchField stringValue];
	
	if([searchTerms length] > 0)
	{
		pvrSearchTask = [[NSTask alloc] init];
		pvrSearchPipe = [[NSPipe alloc] init];
		
		[pvrSearchTask setLaunchPath:@"/usr/bin/perl"];
		NSString *searchArgument = [[NSString alloc] initWithString:searchTerms];
		NSString *cacheExpiryArg = [self cacheExpiryArgument:nil];
		NSString *typeArgument = [self typeArgument:nil];
		NSArray *args = [[NSArray alloc] initWithObjects:getiPlayerPath,noWarningArg,cacheExpiryArg,typeArgument,@"--nopurge",
						  @"--listformat=<index>: <type>, ~<name> - <episode>~, <channel>, <timeadded>",searchArgument,profileDirArg,nil];
		[pvrSearchTask setArguments:args];
		
		[pvrSearchTask setStandardOutput:pvrSearchPipe];
		NSFileHandle *fh = [pvrSearchPipe fileHandleForReading];
		
		NSNotificationCenter *nc;
		nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self
			   selector:@selector(pvrSearchDataReady:)
				   name:NSFileHandleReadCompletionNotification
				 object:fh];
		[nc addObserver:self
			   selector:@selector(pvrSearchFinished:)
				   name:NSTaskDidTerminateNotification
				 object:pvrSearchTask];
		pvrSearchData = [[NSMutableString alloc] init];
		[pvrSearchTask launch];
		[pvrSearchIndicator startAnimation:nil];
		[fh readInBackgroundAndNotify];
	}
}

- (void)pvrSearchDataReady:(NSNotification *)n
{
    NSData *d;
    d = [[n userInfo] valueForKey:NSFileHandleNotificationDataItem];
	
    if ([d length] > 0) {
		NSString *s = [[NSString alloc] initWithData:d
											encoding:NSUTF8StringEncoding];
		
		[pvrSearchData appendString:s];
		
	}
	else
	{
		pvrSearchTask = nil;
	}
	
    // If the task is running, start reading again
    if (pvrSearchTask)
        [[pvrSearchPipe fileHandleForReading] readInBackgroundAndNotify];
}
- (void)pvrSearchFinished:(NSNotification *)n
{
	[pvrSearchTask dealloc];
	[pvrSearchPipe dealloc];
	[pvrResultsController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[pvrResultsController arrangedObjects] count])]];
	NSString *string = [NSString stringWithString:pvrSearchData];
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
	for (NSString *string in array)
	{
		if (![string isEqualToString:@"Matches:"] && ![string hasPrefix:@"INFO:"] && ![string hasPrefix:@"WARNING:"] && [string length]>0)
		{
			@try {
				NSScanner *myScanner = [NSScanner scannerWithString:string];
				Programme *p = [pvrResultsController newObject];
				NSString *temp_pid, *temp_showName, *temp_tvNetwork;
				NSInteger timeadded;
				[myScanner scanUpToString:@":" intoString:&temp_pid];
				[myScanner scanUpToCharactersFromSet:[NSCharacterSet letterCharacterSet] intoString:NULL];
				[myScanner scanUpToString:@", ~" intoString:NULL];
				[myScanner scanString:@", ~" intoString:nil];
				[myScanner scanUpToString:@"~," intoString:&temp_showName];
				[myScanner scanUpToCharactersFromSet:[NSCharacterSet letterCharacterSet] intoString:NULL];
				[myScanner scanUpToString:@"," intoString:&temp_tvNetwork];
				[myScanner scanString:@", " intoString:nil];
				[myScanner scanInteger:&timeadded];
				
				[p setValue:temp_pid forKey:@"pid"];
				[p setValue:temp_showName forKey:@"showName"];
				[p setValue:temp_tvNetwork forKey:@"tvNetwork"];
				NSNumber *added = [NSNumber numberWithInteger:timeadded];
				[p setValue:added forKey:@"timeadded"];
				[pvrResultsController addObject:p];
			}
			@catch (NSException *e) {
				NSAlert *searchException = [[NSAlert alloc] init];
				[searchException addButtonWithTitle:@"OK"];
				[searchException setMessageText:[NSString stringWithFormat:@"Invalid Output!"]];
				[searchException setInformativeText:@"Please check your query. You query must not alter the output format of Get_iPlayer."];
				[searchException setAlertStyle:NSWarningAlertStyle];
				[searchException runModal];
				searchException = nil;
			}
		}
		else
		{
			if ([string hasPrefix:@"Unknown option:"] || [string hasPrefix:@"Option"] || [string hasPrefix:@"Usage"])
			{
				NSLog(@"Unknown Option");
				[pvrSearchIndicator stopAnimation:nil];
				return;
			}
		}
	}
	[pvrSearchIndicator stopAnimation:nil];
}
- (IBAction)addToAutoRecord:(id)sender
{
	NSArray *selected = [[NSArray alloc] initWithArray:[pvrResultsController selectedObjects]];
	for (Programme *programme in selected)
	{
		NSString *episodeName = [[NSString alloc] initWithString:[programme showName]];
		NSScanner *scanner = [NSScanner scannerWithString:episodeName];
		NSString *tempName;
		[scanner scanUpToString:@" - " intoString:&tempName];
		Series *show = [Series alloc];
		[show initWithShowname:tempName];
		[show setValue:[programme timeadded] forKey:@"added"];
		[show setValue:[programme tvNetwork] forKey:@"tvNetwork"];
		[pvrQueueController addObject:show];
	}
}
- (IBAction)addSeriesLinkToQueue:(id)sender
{
	NSArray *seriesLink = [pvrQueueController arrangedObjects];
	for (Series *series in seriesLink)
	{
		NSString *cacheExpiryArgument = [self cacheExpiryArgument:nil];
		NSString *typeArgument = [self typeArgument:nil];
		
		NSMutableArray *autoRecordArgs = [[NSMutableArray alloc] initWithObjects:getiPlayerPath, noWarningArg,@"--nopurge",
										 @"--listformat=<index>: <type>, ~<name> - <episode>~, <channel>, <timeadded>", cacheExpiryArgument, 
										  typeArgument, profileDirArg,@"--hide",[series showName],nil];
		
		NSTask *autoRecordTask = [[NSTask alloc] init];
		NSPipe *autoRecordPipe = [[NSPipe alloc] init];
		NSMutableString *autoRecordData = [[NSMutableString alloc] initWithString:@""];
		NSFileHandle *readHandle = [autoRecordPipe fileHandleForReading];
		NSData *inData = nil;
		
		[autoRecordTask setLaunchPath:@"/usr/bin/perl"];
		[autoRecordTask setArguments:autoRecordArgs];
		[autoRecordTask setStandardOutput:autoRecordPipe];
		[autoRecordTask launch];
		
		while ((inData = [readHandle availableData]) && [inData length]) {
			NSString *tempData = [[NSString alloc] initWithData:inData encoding:NSUTF8StringEncoding];
			[autoRecordData appendString:tempData];
		}
		[self processAutoRecordData:[autoRecordData copy] forSeries:series];
	}
}

- (void)processAutoRecordData:(NSString *)autoRecordData2 forSeries:(Series *)series2
{
	NSString *string = [NSString stringWithString:autoRecordData2];
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
	for (NSString *string in array)
	{
		if (![string isEqualToString:@"Matches:"] && ![string hasPrefix:@"INFO:"] && ![string hasPrefix:@"WARNING:"] && [string length]>0)
		{
			@try {
				NSScanner *myScanner = [NSScanner scannerWithString:string];
				NSArray *currentQueue = [queueController arrangedObjects];
				NSString *temp_pid, *temp_showName, *temp_tvNetwork, *temp_type;
				NSInteger timeadded;
				[myScanner scanUpToString:@":" intoString:&temp_pid];
				[myScanner scanUpToCharactersFromSet:[NSCharacterSet letterCharacterSet] intoString:NULL];
				[myScanner scanUpToString:@", ~" intoString:&temp_type];
				[myScanner scanString:@", ~" intoString:nil];
				[myScanner scanUpToString:@"~," intoString:&temp_showName];
				[myScanner scanUpToCharactersFromSet:[NSCharacterSet letterCharacterSet] intoString:NULL];
				[myScanner scanUpToString:@"," intoString:&temp_tvNetwork];
				[myScanner scanString:@"," intoString:nil];
				[myScanner scanInteger:&timeadded];
				if (([[series2 added] integerValue] < timeadded) /*&& ([temp_tvNetwork isEqualToString:[series2 tvNetwork]])*/)
				{
					Programme *p = [[Programme alloc] initWithInfo:nil pid:temp_pid programmeName:temp_showName network:temp_tvNetwork];
					if ([temp_type isEqualToString:@"radio"]) [p setValue:[NSNumber numberWithBool:YES] forKey:@"radio"];
					[p setValue:@"Added by Series-Link" forKey:@"status"];
					BOOL inQueue=NO;
					for (Programme *show in currentQueue)
						if ([[show showName] isEqualToString:[p showName]]) inQueue=YES;
					if (!inQueue) 
					{
						if (runDownloads) [p setValue:@"Waiting..." forKey:@"status"];
						[queueController addObject:p];
					}
				}
			}
			@catch (NSException *e) {
				NSAlert *searchException = [[NSAlert alloc] init];
				[searchException addButtonWithTitle:@"OK"];
				[searchException setMessageText:[NSString stringWithFormat:@"Invalid Output!"]];
				[searchException setInformativeText:@"Please check your query. You query must not alter the output format of Get_iPlayer."];
				[searchException setAlertStyle:NSWarningAlertStyle];
				[searchException runModal];
				searchException = nil;
			}
		}
		else
		{
			if ([string hasPrefix:@"Unknown option:"] || [string hasPrefix:@"Option"] || [string hasPrefix:@"Usage"])
			{
				NSLog(@"Unknown Option");
				return;
			}
		}
	}
}

#pragma mark Misc.
- (void)addToiTunes:(Programme *)show
{
	NSString *path = [[NSString alloc] initWithString:[show path]];
	NSString *ext = [path pathExtension];
	
	[self addToLog:[NSString stringWithFormat:@"Adding %@ to iTunes",[show showName]] :self];
	
	iTunesApplication *iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
	
	NSArray *fileToAdd = [NSArray arrayWithObject:[NSURL fileURLWithPath:path]];
	if (![iTunes isRunning]) [iTunes activate];
	@try
	{
		if ([ext isEqualToString:@"mov"] || [ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mp3"])
		{
			iTunesTrack *track = [iTunes add:fileToAdd to:nil];
			if (track && ([ext isEqualToString:@"mov"] || [ext isEqualToString:@"mp4"]))
			{
				[track setVideoKind:iTunesEVdKTVShow];
				[track setName:[show showName]];
				[track setUnplayed:YES];
				[track setEpisodeID:[show episodeName]];
				[track setShow:[show seriesName]];
				if ([show season]>0) [track setSeasonNumber:[show season]];
				if ([show episode]>0) [track setEpisodeNumber:[show episode]];
			}
			else if (track && [ext isEqualToString:@"mp3"])
			{
				[track setBookmarkable:YES];
				[self addToLog:@"Bookmarkable set" :self];
				[track setName:[show showName]];
				[self addToLog:@"Name set" :self];
				[track setAlbum:[show seriesName]];
				[self addToLog:@"Album set" :self];
				[track setUnplayed:YES];
				[self addToLog:@"Everything set" :self];
			}
			[show setValue:@"Complete & in iTunes" forKey:@"status"];
		}
		else
		{
			[self addToLog:@"Can't add to iTunes; incompatible format." :self];
			[self addToLog:@"			iTunes Compatible Modes: Flash - High, Flash - Standard, Flash - HD, iPhone, Radio - MP3, Podcast" :nil];
			[show setValue:@"Download Complete" forKey:@"status"];
		}
	}
	@catch (NSException *e)
	{
		[self addToLog:@"Unable to Add to iTunes" :self];
		NSLog(@"Unable %@ to iTunes",show);
		[show setValue:@"Complete, Could not add to iTunes." forKey:@"status"];
	}
}
- (void)cleanUpPath:(Programme *)show
{
	//Process Show Name into Parts
	NSString *originalShowName, *originalEpisodeName;
	NSScanner *nameScanner = [NSScanner scannerWithString:[show showName]];
	[nameScanner scanUpToString:@" - " intoString:&originalShowName];
	[nameScanner scanString:@"-" intoString:nil];
	[nameScanner scanUpToString:@"Scan to End" intoString:&originalEpisodeName];
	
	//Replace :'s with -'s
	NSString *showName = [originalShowName stringByReplacingOccurrencesOfString:@":" withString:@" -"];
	NSString *episodeName = [originalEpisodeName stringByReplacingOccurrencesOfString:@":" withString:@" -"];
	
	//Replace /'s with _'s
	showName = [showName stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
	episodeName = [episodeName stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
	
	if (![[show path] isEqualToString:@"Unknown"])
	{
		//Process Original Path into Parts
		NSString *originalPath = [NSString stringWithString:[show path]];
		NSString *originalFolder = [originalPath stringByDeletingLastPathComponent];
		NSString *extension = [originalPath pathExtension];
		
		//Rename File and Directory if Neccessary
		NSString *newFile;
		if (![showName isEqualToString:originalShowName] || ![episodeName isEqualToString:originalEpisodeName])
		{
			//Generate New Paths
			NSString *downloadDirectory = [[NSUserDefaults standardUserDefaults] objectForKey:@"DownloadPath"];
			NSString *newFolder = [downloadDirectory stringByAppendingPathComponent:showName];
			NSString *newFilename = [NSString stringWithFormat:@"%@ - %@", showName, episodeName];
			newFile = [newFolder stringByAppendingPathComponent:newFilename];
			newFile = [newFile stringByAppendingPathExtension:extension];
			
			//Perform File Operations
			NSFileManager *fileManager = [NSFileManager defaultManager];
			[fileManager createDirectoryAtPath:newFolder attributes:nil];
			NSError *copyError;
			if ([fileManager moveItemAtPath:[show path] toPath:newFile error:&copyError]) 
			{
				if (![newFolder isEqualToString:originalFolder])
				{
					[fileManager removeItemAtPath:originalFolder error:NULL];
				}
				[show setValue:newFile forKey:@"path"];
			}
			else NSLog(@"Clean Up Path Error: %@", copyError);
		}
		else 
			newFile = originalPath;
	}
	
	//Save Data to Programme for Later Use
	[show setValue:showName forKey:@"seriesName"];
	[show setValue:episodeName forKey:@"episodeName"];
}

- (void)seasonEpisodeInfo:(Programme *)show
{
	NSInteger episode=0, season=0;
	@try
	{
		NSString *episodeName = [show episodeName];
		NSString *seriesName = [show seriesName];
		
		NSScanner *episodeScanner = [NSScanner scannerWithString:episodeName];
		NSScanner *seasonScanner = [NSScanner scannerWithString:seriesName];
		
		[episodeScanner scanUpToString:@"Episode" intoString:nil];
		if ([episodeScanner scanString:@"Episode" intoString:nil])
		{
			[episodeScanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
			[episodeScanner scanInteger:&episode];
		}
		
		[seasonScanner scanUpToString:@"Series" intoString:nil];
		if ([seasonScanner scanString:@"Series" intoString:nil])
		{
			[seasonScanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
			[seasonScanner scanInteger:&season];
		}
		
		//Remove Series Number from Series Name
		//Showname is now Top Gear instead of Top Gear - Series 12
		NSString *show2;
		[seasonScanner setScanLocation:0];
		[seasonScanner scanUpToString:@" - " intoString:&show2];
		[show setSeriesName:show2];
	}
	@catch (NSException *e) {
		NSLog(@"Error occured while retrieving Season/Episode info");
	}
	@finally
	{
		[show setEpisode:episode];
		[show setSeason:season];
	}
}
- (IBAction)chooseDownloadPath:(id)sender
{
	NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
	[openPanel setCanChooseFiles:NO];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel runModalForTypes:nil];
	NSArray *urls = [openPanel URLs];
	[[NSUserDefaults standardUserDefaults] setValue:[[urls objectAtIndex:0] path] forKey:@"DownloadPath"];
}
- (IBAction)showFeedback:(id)sender
{
	[JRFeedbackController showFeedback];
}
#pragma mark Argument Retrieval
- (NSString *)typeArgument:(id)sender
{
	if (runSinceChange || !currentTypeArgument)
	{
		NSMutableString *typeArgument = [[NSMutableString alloc] initWithString:@"--type="];
		if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_TV"] isEqualTo:[NSNumber numberWithBool:YES]]) [typeArgument appendString:@"tv,"];
		if (/*[[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheITV_TV"] isEqualTo:[NSNumber numberWithBool:YES]]*/NO) [typeArgument appendString:@"itv,"];
		if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_Radio"] isEqualTo:[NSNumber numberWithBool:YES]]) [typeArgument appendString:@"radio,"];
		if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_Podcasts"] isEqualTo:[NSNumber numberWithBool:YES]]) [typeArgument appendString:@"podcast,"];
		[typeArgument deleteCharactersInRange:NSMakeRange([typeArgument length]-1,1)];
		currentTypeArgument = [typeArgument copy];
		return [NSString stringWithString:typeArgument];
	}
	else
		return currentTypeArgument;
}
- (IBAction)typeChanged:(id)sender
{
	if ([sender state] == NSOffState)
		runSinceChange=NO;
}
- (NSString *)cacheExpiryArgument:(id)sender
{
	//NSString *cacheExpiryArg = [[NSString alloc] initWithFormat:@"-e%d", ([[[NSUserDefaults standardUserDefaults] objectForKey:@"CacheExpiryTime"] intValue]*3600)];
	//return cacheExpiryArg;
	return @"-e60480000000000000";
}

#pragma mark Scheduler
- (IBAction)showScheduleWindow:(id)sender
{
	if (!runDownloads)
	{
		[scheduleWindow makeKeyAndOrderFront:self];
		[datePicker setDateValue:[NSDate date]];
	}
	else
	{
		NSAlert *alert = [NSAlert alertWithMessageText:@"Downloads are already running." 
										 defaultButton:@"OK"
									   alternateButton:nil 
										   otherButton:nil 
							 informativeTextWithFormat:@"You cannot schedule downloads to start if they are already running."];
		[alert runModal];
	}
}
- (IBAction)cancelSchedule:(id)sender
{
	[scheduleWindow close];
}
- (IBAction)scheduleStart:(id)sender
{
	NSDate *startTime = [datePicker dateValue];
	scheduleTimer = [[NSTimer alloc] initWithFireDate:startTime 
													  interval:1
														target:self 
													  selector:@selector(runScheduledDownloads:) 
													  userInfo:nil 
													   repeats:NO];
	interfaceTimer = [NSTimer scheduledTimerWithTimeInterval:1 
															   target:self 
															 selector:@selector(updateScheduleStatus:) 
															 userInfo:nil 
															  repeats:YES];
	[scheduleWindow close];
	[startButton setEnabled:NO];
	[stopButton setLabel:@"Cancel Timer"];
	[stopButton setAction:@selector(stopTimer:)];
	[stopButton setEnabled:YES];
	NSRunLoop *runLoop = [NSRunLoop mainRunLoop];
	[runLoop addTimer:scheduleTimer forMode:NSDefaultRunLoopMode];
	runScheduled=YES;
	[mainWindow setDocumentEdited:YES];
}
- (void)runScheduledDownloads:(NSTimer *)theTimer
{
	[interfaceTimer invalidate];
	[mainWindow setDocumentEdited:NO];
	[startButton setEnabled:YES];
	[stopButton setEnabled:NO];
	[stopButton setLabel:@"Stop"];
	[stopButton setAction:@selector(stopDownloads:)];
	[self forceUpdate:self];
}
- (void)updateScheduleStatus:(NSTimer *)theTimer
{
	NSDate *startTime = [scheduleTimer fireDate];
	NSDate *currentTime = [NSDate date];
	
	unsigned int unitFlags = NSHourCalendarUnit | NSMinuteCalendarUnit | NSDayCalendarUnit | NSSecondCalendarUnit;
	NSDateComponents *conversionInfo = [[NSCalendar currentCalendar] components:unitFlags fromDate:currentTime toDate:startTime options:0];
	
	NSString *status = [NSString stringWithFormat:@"Time until Start (DD:HH:MM:SS): %2d:%2d:%2d:%2d", 
						[conversionInfo day], [conversionInfo hour], 
						[conversionInfo minute], [conversionInfo second]];
	[currentProgress setStringValue:status];
	[currentIndicator setIndeterminate:YES];
	[currentIndicator startAnimation:self];
}
- (void)stopTimer:(id)sender
{
	[interfaceTimer invalidate];
	[scheduleTimer invalidate];
	[startButton setEnabled:YES];
	[stopButton setEnabled:NO];
	[stopButton setLabel:@"Stop"];
	[stopButton setAction:@selector(stopDownloads:)];
	[currentProgress setStringValue:@""];
	[currentIndicator setIndeterminate:NO];
	[currentIndicator stopAnimation:self];
	[mainWindow setDocumentEdited:NO];
	runScheduled=NO;
}

#pragma mark Live TV
- (IBAction)showLiveTVWindow:(id)sender
{
	if (!runDownloads)
	{
		[liveTVWindow makeKeyAndOrderFront:self];
	}
	else
	{
		NSAlert *downloadRunning = [NSAlert alertWithMessageText:@"Downloads are Running!" 
												   defaultButton:@"Continue" 
												 alternateButton:@"Cancel" 
													 otherButton:nil 
									   informativeTextWithFormat:@"You may experience choppy playback while downloads are running."];
		NSInteger response = [downloadRunning runModal];
		if (response == NSAlertDefaultReturn)
		{
			[liveTVWindow makeKeyAndOrderFront:self];
		}
	}
}
- (IBAction)startLiveTV:(id)sender
{
	getiPlayerStreamer = [[NSTask alloc] init];
	mplayerStreamer = [[NSTask alloc] init];
	liveTVPipe = [[NSPipe alloc] init];
	liveTVError = [[NSPipe alloc] init];
	
	[getiPlayerStreamer setLaunchPath:@"/usr/bin/perl"];
	[getiPlayerStreamer setStandardOutput:liveTVPipe];
	[getiPlayerStreamer setStandardError:liveTVPipe];
	[mplayerStreamer setStandardInput:liveTVPipe];
	[mplayerStreamer setLaunchPath:[[NSBundle mainBundle] pathForResource:@"mplayer" ofType:nil]];
	[mplayerStreamer setStandardError:liveTVError];
	[mplayerStreamer setStandardOutput:liveTVError];
	NSLog(@"get iplayer launch path set");
	
	//Get selected channel
	LiveTVChannel *selectedChannel = [[liveTVChannelController arrangedObjects] objectAtIndex:[liveTVChannelController selectionIndex]];
	
	//Set Proxy Argument
	NSString *proxyArg;
	NSString *partialProxyArg = [NSString stringWithString:@"--partial-proxy"];
	NSString *proxyOption = [[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"];
	if ([proxyOption isEqualToString:@"None"])
	{
		//No Proxy
		proxyArg = NULL;
	}
	else if ([proxyOption isEqualToString:@"Custom"])
	{
		//Get the Custom Proxy.
		proxyArg = [[NSString alloc] initWithFormat:@"-p%@",[[NSUserDefaults standardUserDefaults] valueForKey:@"CustomProxy"]];
	}
	else
	{
		//Get provided proxy from my server.
		NSURL *proxyURL = [[NSURL alloc] initWithString:@"http://tom-tech.com/get_iplayer/proxy.txt"];
		NSURLRequest *proxyRequest = [NSURLRequest requestWithURL:proxyURL
													  cachePolicy:NSURLRequestReturnCacheDataElseLoad
												  timeoutInterval:30];
		NSData *urlData;
		NSURLResponse *response;
		NSError *error;
		urlData = [NSURLConnection sendSynchronousRequest:proxyRequest
										returningResponse:&response
													error:&error];
		if (!urlData)
		{
			NSAlert *alert = [NSAlert alertWithMessageText:@"Provided Proxy could not be retrieved!" 
											 defaultButton:nil 
										   alternateButton:nil 
											   otherButton:nil 
								 informativeTextWithFormat:@"No proxy will be used.\r\rError: %@", [error localizedDescription]];
			[alert runModal];
			[self addToLog:@"Proxy could not be retrieved. No proxy will be used." :nil];
			proxyArg=NULL;
		}
		else
		{
			NSString *providedProxy = [[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding];
			proxyArg = [[NSString alloc] initWithFormat:@"-phttp://%@", providedProxy];
		}
	}
	
	//Prepare Arguments	
	NSArray *args = [NSArray arrayWithObjects:[[NSBundle mainBundle] pathForResource:@"get_iplayer" ofType:@"pl"],
					 profileDirArg,
					 @"--stream",
					 @"--modes=flashnormal",
					 @"--type=livetv",
					 [selectedChannel channel],
					 //@"--player=mplayer -cache 3072 -",
					// [NSString stringWithFormat:@"--player=\"%@\" -cache 3072 -", [[NSBundle mainBundle] pathForResource:@"mplayer" ofType:nil]],
					 proxyArg,
					 partialProxyArg,
					 nil];
	[getiPlayerStreamer setArguments:args];
	NSLog(@"Arguments set: %@",args);
	
	[mplayerStreamer setArguments:[NSArray arrayWithObjects:@"-cache",@"3072",@"-",nil]];
	
	
	[getiPlayerStreamer launch];
	[mplayerStreamer launch];
	NSLog(@"get iplayer launched");
	[liveStart setEnabled:NO];
	[liveStop setEnabled:YES];
}
- (IBAction)stopLiveTV:(id)sender
{
	[getiPlayerStreamer interrupt];
	[mplayerStreamer interrupt];
	[liveStart setEnabled:YES];
	[liveStop setEnabled:NO];
}
	
@synthesize log_value;
@synthesize getiPlayerPath;
@end
