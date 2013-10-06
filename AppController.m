//
//  AppController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "AppController.h"
#import "HTTPProxy.h"
#import "Programme.h"
#import "Safari.h"
#import "iTunes.h"
#import "Growl.framework/Headers/GrowlApplicationBridge.h"
#import "Sparkle.framework/Headers/Sparkle.h"
#import "JRFeedbackController.h"
#import "LiveTVChannel.h"
#import "ReasonForFailure.h"
#import "Chrome.h"
#import "ASIHTTPRequest.h"

@implementation AppController
#pragma mark Overriden Methods
- (id)description
{
	return @"AppController";
}
- (id)init { 
	//Initialization
	if (!(self = [super init])) return nil;
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	
	//Initialize Arrays for Controllers
	searchResultsArray = [NSMutableArray array];
	pvrSearchResultsArray = [NSMutableArray array];
	pvrQueueArray = [NSMutableArray array];
	queueArray = [NSMutableArray array];
	
	//Initialize Log
    NSString *version = [NSString stringWithFormat:@"%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    NSLog(@"Get iPlayer Automator %@ Initialized.", version);
	log_value = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"Get iPlayer Automator %@ Initialized.", version]];
	[self addToLog:@"" :nil];
	[nc addObserver:self selector:@selector(addToLogNotification:) name:@"AddToLog" object:nil];
	[nc addObserver:self selector:@selector(postLog:) name:@"NeedLog" object:nil];
	
	
	//Register Default Preferences
	NSMutableDictionary *defaultValues = [[NSMutableDictionary alloc] init];
	
    NSString *defaultDownloadDirectory = @"~/Movies/TV Shows";
	defaultValues[@"DownloadPath"] = [defaultDownloadDirectory stringByExpandingTildeInPath];
	defaultValues[@"Proxy"] = @"Provided";
	defaultValues[@"CustomProxy"] = @"";
	defaultValues[@"AutoRetryFailed"] = @YES;
	defaultValues[@"AutoRetryTime"] = @"30";
	defaultValues[@"AddCompletedToiTunes"] = @YES;
	defaultValues[@"DefaultBrowser"] = @"Safari";
	defaultValues[@"DefaultFormat"] = @"iPhone";
	defaultValues[@"AlternateFormat"] = @"Flash - Standard";
	defaultValues[@"CacheBBC_TV"] = @YES;
	defaultValues[@"CacheITV_TV"] = @YES;
	defaultValues[@"CacheBBC_Radio"] = @NO;
	defaultValues[@"CacheBBC_Podcasts"] = @NO;
	defaultValues[@"CacheExpiryTime"] = @"4";
	defaultValues[@"Verbose"] = @NO;
	defaultValues[@"SeriesLinkStartup"] = @YES;
	defaultValues[@"DownloadSubtitles"] = @NO;
	defaultValues[@"AlwaysUseProxy"] = @NO;
	defaultValues[@"XBMC_naming"] = @NO;
	defaultValues[@"KeepSeriesFor"] = @"30";
	defaultValues[@"RemoveOldSeries"] = @NO;
    defaultValues[@"AudioDescribed"] = @NO;
    defaultValues[@"QuickCache"] = @YES;
    defaultValues[@"TagShows"] = @YES;
    defaultValues[@"Cache4oD_TV"] = @YES;
    defaultValues[@"TestProxy"] = @YES;
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
	defaultValues = nil;
	
	//Make sure Application Support folder exists
	NSString *folder = @"~/Library/Application Support/Get iPlayer Automator/";
	folder = [folder stringByExpandingTildeInPath];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if (![fileManager fileExistsAtPath:folder])
	{
		[fileManager createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:nil];
	}
	[fileManager changeCurrentDirectoryPath:folder];
	
	//Install Plugins If Needed
	NSString *pluginPath = [folder stringByAppendingPathComponent:@"plugins"];
	if (/*![fileManager fileExistsAtPath:pluginPath]*/TRUE)
	{
		[self addToLog:@"Installing/Updating Get_iPlayer Plugins..." :self];
		NSString *providedPath = [[NSBundle mainBundle] bundlePath];
		if ([fileManager fileExistsAtPath:pluginPath]) [fileManager removeItemAtPath:pluginPath error:NULL];
		providedPath = [providedPath stringByAppendingPathComponent:@"/Contents/Resources/plugins"];
		[fileManager copyItemAtPath:providedPath toPath:pluginPath error:nil];
	}
	
	
	//Initialize Arguments
	noWarningArg = @"--nocopyright";
	listFormat = @"--listformat=<index>: <type>, ~<name> - <episode>~, <channel>, <web>";
	profileDirArg = [[NSString alloc] initWithFormat:@"--profile-dir=%@", folder];
	
	getiPlayerPath = [[NSString alloc] initWithString:[[NSBundle mainBundle] bundlePath]];
	getiPlayerPath = [getiPlayerPath stringByAppendingString:@"/Contents/Resources/get_iplayer.pl"];
	runScheduled=NO;
    quickUpdateFailed=NO;
    proxyDict = [[NSMutableDictionary alloc] init];
	return self;
}
#pragma mark Delegate Methods
- (void)awakeFromNib
{
#ifdef __x86_64__
    [itvTVCheckbox setEnabled:YES];
#else
    [itvTVCheckbox setEnabled:NO];
    [itvTVCheckbox setState:NSOffState];
    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:NO] forKey:@"CacheITV_TV"];
#endif
    
    [[mainWindow windowController] setShouldCascadeWindows:NO];      // Tell the controller to not cascade its windows.
    [mainWindow setFrameAutosaveName:@"mainWindow"];  // Specify the autosave name for the window.
	
	[queueTableView registerForDraggedTypes:@[@"com.thomaswillson.programme"]];
	
	//Read Queue & Series-Link from File
	NSFileManager *fileManager = [NSFileManager defaultManager];
    
	NSString *folder = @"~/Library/Application Support/Get iPlayer Automator/";
	folder = [folder stringByExpandingTildeInPath];
	if ([fileManager fileExistsAtPath: folder] == NO)
	{
		[fileManager createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:nil];
	}
	NSString *filename = @"Queue.automatorqueue";
	NSString *filePath = [folder stringByAppendingPathComponent:filename];
	
	NSDictionary * rootObject;
    @try
	{
		rootObject = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
		NSArray *tempQueue = [rootObject valueForKey:@"queue"];
		NSArray *tempSeries = [rootObject valueForKey:@"serieslink"];
        lastUpdate = [rootObject valueForKey:@"lastUpdate"];
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
    BOOL hasCached4oD = [[rootObject valueForKey:@"hasUpdatedCacheFor4oD"] boolValue];
    
    filename = @"ITVFormats.automator";
    filePath = [folder stringByAppendingPathComponent:filename];
    @try {
        rootObject = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
        [itvFormatController addObjects:[rootObject valueForKey:@"itvFormats"]];
    }
    @catch (NSException *exception) {
        [fileManager removeItemAtPath:filePath error:nil];
        rootObject=nil;
    }
    
	//Adds Defaults to Type Preferences
	if ([[tvFormatController arrangedObjects] count] == 0)
	{
		TVFormat *format1 = [[TVFormat alloc] init];
		[format1 setFormat:@"Flash - High"];
		TVFormat *format2 = [[TVFormat alloc] init];
		[format2 setFormat:@"Flash - Standard"];
		[tvFormatController addObjects:@[format2,format1]];
	}
	if ([[radioFormatController arrangedObjects] count] == 0)
	{
		RadioFormat *format1 = [[RadioFormat alloc] init];
		[format1 setFormat:@"Flash AAC - High"];
		RadioFormat *format2 = [[RadioFormat alloc] init];
		[format2 setFormat:@"Flash AAC - Standard"];
		RadioFormat *format3 = [[RadioFormat alloc] init];
		[format3 setFormat:@"Flash - MP3"];
		[radioFormatController addObjects:@[format1,format2,format3]];
	}
    if ([[itvFormatController arrangedObjects] count] == 0)
    {
        TVFormat *format1 = [[TVFormat alloc] init];
        [format1 setFormat:@"Flash - High"];
        TVFormat *format2 = [[TVFormat alloc] init];
        [format2 setFormat:@"Flash - Standard"];
        TVFormat *format3 = [[TVFormat alloc] init];
        [format3 setFormat:@"Flash - Low"];
        TVFormat *format4 = [[TVFormat alloc] init];
        [format4 setFormat:@"Flash - Very Low"];
        [itvFormatController addObjects:@[format1,format2,format3,format4]];
    }
		
	//Growl Initialization
	[GrowlApplicationBridge setGrowlDelegate:@""];
	
	//Populate Live TV Channel List
	LiveTVChannel *bbcOne = [[LiveTVChannel alloc] initWithChannelName:@"BBC One"];
	LiveTVChannel *bbcTwo = [[LiveTVChannel alloc] initWithChannelName:@"BBC Two"];
	LiveTVChannel *bbcNews24 = [[LiveTVChannel alloc] initWithChannelName:@"BBC News 24"];
	[liveTVChannelController setContent:@[bbcOne,bbcTwo,bbcNews24]];
	[liveTVTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	
	//Remove SWFinfo
	NSString *infoPath = @"~/.swfinfo";
	infoPath = [infoPath stringByExpandingTildeInPath];
	if ([fileManager fileExistsAtPath:infoPath]) [fileManager removeItemAtPath:infoPath error:nil];
    
    if (hasCached4oD)
        [self updateCache:nil];
    else
        [self updateCache:@""];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application
{
	return YES;
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    if (runDownloads)
    {
        NSAlert *downloadAlert = [NSAlert alertWithMessageText:@"Are you sure you wish to quit?" 
                                                 defaultButton:@"No" 
                                               alternateButton:@"Yes" 
                                                   otherButton:nil 
                                     informativeTextWithFormat:@"You are currently downloading shows. If you quit, they will be cancelled."];
        NSInteger response = [downloadAlert runModal];
        if (response == NSAlertDefaultReturn) return NSTerminateCancel;
    }
    else if (runUpdate)
    {
        NSAlert *updateAlert = [NSAlert alertWithMessageText:@"Are you sure?" 
                                               defaultButton:@"No" 
                                             alternateButton:@"Yes" 
                                                 otherButton:nil 
                                   informativeTextWithFormat:@"Get iPlayer Automator is currently updating the cache." 
                                @"If you proceed with quiting, some series-link information will be lost." 
                                @"It is not reccommended to quit during an update. Are you sure you wish to quit?"];
        NSInteger response = [updateAlert runModal];
        if (response == NSAlertDefaultReturn) return NSTerminateCancel;
    }
    
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
		if (([[show complete] isEqualToNumber:@YES] && [[show successful] isEqualToNumber:@YES]) 
			|| [[show status] isEqualToString:@"Added by Series-Link"]) [tempQueue removeObject:show];
	}
	NSFileManager *fileManager = [NSFileManager defaultManager];
    
	NSString *folder = @"~/Library/Application Support/Get iPlayer Automator/";
	folder = [folder stringByExpandingTildeInPath];
	if ([fileManager fileExistsAtPath: folder] == NO)
	{
		[fileManager createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:nil];
	}
	NSString *filename = @"Queue.automatorqueue";
	NSString *filePath = [folder stringByAppendingPathComponent:filename];
	
	NSMutableDictionary * rootObject;
	rootObject = [NSMutableDictionary dictionary];
    
	[rootObject setValue:tempQueue forKey:@"queue"];
	[rootObject setValue:tempSeries forKey:@"serieslink"];
    [rootObject setValue:lastUpdate forKey:@"lastUpdate"];
	[NSKeyedArchiver archiveRootObject: rootObject toFile: filePath];
	
	filename = @"Formats.automatorqueue";
	filePath = [folder stringByAppendingPathComponent:filename];
	
	rootObject = [NSMutableDictionary dictionary];
	
	[rootObject setValue:[tvFormatController arrangedObjects] forKey:@"tvFormats"];
	[rootObject setValue:[radioFormatController arrangedObjects] forKey:@"radioFormats"];
    [rootObject setValue:@YES forKey:@"hasUpdatedCacheFor4oD"];
	[NSKeyedArchiver archiveRootObject:rootObject toFile:filePath];
    
    filename = @"ITVFormats.automator";
    filePath = [folder stringByAppendingPathComponent:filename];
    rootObject = [NSMutableDictionary dictionary];
    [rootObject setValue:[itvFormatController arrangedObjects] forKey:@"itvFormats"];
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
    @try
    {
        [searchField setEnabled:NO];
        [stopButton setEnabled:NO];
        [startButton setEnabled:NO];
        [pvrSearchField setEnabled:NO];
    }
    @catch (NSException *e) {
        NSLog(@"NO UI: updateCache:");
    }
    if ((![[[NSUserDefaults standardUserDefaults] objectForKey:@"QuickCache"] boolValue] || quickUpdateFailed) && [[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue])
    {
        [self loadProxyInBackgroundForSelector:@selector(updateCache:proxyError:) withObject:sender];
    }
    else
    {
        [self updateCache:sender proxyError:nil];
    }
}

- (void)updateCache:(id)sender proxyError:(NSError *)proxyError
{
    // reset after proxy load
    @try
    {
        [searchField setEnabled:YES];
        [stopButton setEnabled:YES];
        [startButton setEnabled:YES];
        [pvrSearchField setEnabled:YES];
    }
    @catch (NSException *e) {
        NSLog(@"NO UI: updateCache:proxyError:");
    }
    if ([proxyError code] == kProxyLoadCancelled)
        return;
	runSinceChange=YES;
	runUpdate=YES;
    didUpdate=NO;
	[mainWindow setDocumentEdited:YES];
	
	NSArray *tempQueue = [queueController arrangedObjects];
	for (Programme *show in tempQueue)
	{
		if (![[show successful] isEqualToNumber:@NO])
		{
			[queueController removeObject:show];
		}
	}
    
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
        [pvrSearchField setEnabled:NO];
    }
    @catch (NSException *e) {
        NSLog(@"NO UI");
    }
    
    if (![[[NSUserDefaults standardUserDefaults] objectForKey:@"QuickCache"] boolValue] || quickUpdateFailed)
    {
        quickUpdateFailed=NO;
        
        NSString *cacheExpiryArg;
        if ([[sender class] isEqualTo:[@"" class]])
        {
            cacheExpiryArg = @"-e1";
        }
        else
        {
            cacheExpiryArg = [[NSString alloc] initWithFormat:@"-e%d", ([[[NSUserDefaults standardUserDefaults] objectForKey:@"CacheExpiryTime"] intValue]*3600)];
        }

        NSString *typeArgument = [self typeArgument:nil];
        
        NSString *proxyArg = NULL;
        if (proxy && [[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue])
        {
            proxyArg = [[NSString alloc] initWithFormat:@"-p%@", [proxy url]];
        }
        
        [self addToLog:@"Updating Program Index Feeds...\r" :self];
        
        getiPlayerUpdateArgs = [[NSArray alloc] initWithObjects:getiPlayerPath,cacheExpiryArg,typeArgument,@"--nopurge",profileDirArg,proxyArg,nil];
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
    else
    {
        [self addToLog:@"Updating Program Index Feeds from Server..." :nil];
        
        NSLog(@"DEBUG: Last cache update: %@",lastUpdate);
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (!lastUpdate || ([[NSDate date] timeIntervalSinceDate:lastUpdate] > ([[defaults objectForKey:@"CacheExpiryTime"] intValue]*3600)) || [[sender class] isEqualTo:[@"" class]])
        {
            typesToCache = [[NSMutableArray alloc] initWithCapacity:5];
            if ([[defaults objectForKey:@"CacheBBC_TV"] boolValue]) [typesToCache addObject:@"TV"];
            if ([[defaults objectForKey:@"CacheITV_TV"] boolValue]) [typesToCache addObject:@"ITV"];
            if ([[defaults objectForKey:@"CacheBBC_Radio"] boolValue]) [typesToCache addObject:@"Radio"];
            if ([[defaults objectForKey:@"CacheBBC_Podcasts"] boolValue]) [typesToCache addObject:@"Podcast"];
            if ([[defaults objectForKey:@"Cache4oD_TV"] boolValue]) [typesToCache addObject:@"CH4"];
            
            NSArray *urlKeys = @[@"TV",@"ITV",@"Radio",@"Podcast",@"CH4"];
            NSArray *urlObjects = @[@"http://tom-tech.com/get_iplayer/cache/tv.cache",
                                   @"http://tom-tech.com/get_iplayer/cache/itv.cache",
                                   @"http://tom-tech.com/get_iplayer/cache/radio.cache",
                                   @"http://tom-tech.com/get_iplayer/cache/podcast.cache",
                                   @"http://tom-tech.com/get_iplayer/cache/ch4.cache"];
            updateURLDic = [[NSDictionary alloc] initWithObjects:urlObjects forKeys:urlKeys];
            
            nextToCache=0;
            if ([typesToCache count] > 0)
                [self updateCacheForType:typesToCache[0]];
        }
        else [self getiPlayerUpdateFinished];
        
    }
}
- (void)updateCacheForType:(NSString *)type
{
    [self addToLog:[NSString stringWithFormat:@"    Retrieving %@ index feeds.",type] :nil];
    [currentProgress setStringValue:[NSString stringWithFormat:@"Updating Program Indexes: Getting %@ index feeds from server...",type]];
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:updateURLDic[type]]];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(indexRequestFinished:)];
    [request setDownloadDestinationPath:[[@"~/Library/Application Support/Get iPlayer Automator" stringByExpandingTildeInPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.cache",type]]];
    [request startAsynchronous];
}
- (void)indexRequestFinished:(ASIHTTPRequest *)request
{
    if ([request responseStatusCode] != 200)
    {
        quickUpdateFailed=YES;
        [self updateCache:@""];
    }
    else
    {
        didUpdate=YES;
        nextToCache++;
        if (nextToCache < [typesToCache count])
            [self updateCacheForType:typesToCache[nextToCache]];
        else
        {
            [self getiPlayerUpdateFinished];
        }
    }
}
- (void)dataReady:(NSNotification *)n
{
    NSData *d;
    d = [[n userInfo] valueForKey:NSFileHandleNotificationDataItem];
	BOOL matches=NO;
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
        else if ([s hasPrefix:@"WARNING:"] || [s hasPrefix:@"ERROR:"])
        {
            [self addToLog:s :nil];
        }
		else if ([s isEqualToString:@"."])
		{
			NSMutableString *infomessage = [[NSMutableString alloc] initWithFormat:@"%@.", [currentProgress stringValue]];
			if ([infomessage hasSuffix:@".........."]) [infomessage deleteCharactersInRange:NSMakeRange([infomessage length]-9, 9)];
			[currentProgress setStringValue:infomessage];
			infomessage = nil;
			didUpdate = YES;
		}
		else if ([s hasPrefix:@"Matches:"])
		{
			matches=YES;
			getiPlayerUpdateTask=nil;
			[self getiPlayerUpdateFinished];
		}
    }
	else
	{
		getiPlayerUpdateTask = nil;
		[self getiPlayerUpdateFinished];
	}
	
    // If the task is running, start reading again
    if (getiPlayerUpdateTask && !matches)
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
	[pvrSearchField setEnabled:YES];
    
	
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
        lastUpdate=[NSDate date];
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
				// write handle is closed to this process
				[pipeTask setStandardOutput:newPipe];
				[pipeTask setStandardError:newPipe];
				[pipeTask setLaunchPath:@"/usr/bin/perl"];
				[pipeTask setArguments:@[getiPlayerPath,profileDirArg,@"--nopurge",noWarningArg,[self typeArgument:nil],[self cacheExpiryArgument:nil],listFormat,
										searchArgument]];
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
							NSString *temp_pid, *temp_showName, *temp_tvNetwork, *temp_type, *url;
							[myScanner scanUpToString:@":" intoString:&temp_pid];
							[myScanner scanUpToString:@"," intoString:&temp_type];
							[myScanner scanString:@", ~" intoString:NULL];
							[myScanner scanUpToString:@"~," intoString:&temp_showName];
							[myScanner scanString:@"~," intoString:NULL];
							[myScanner scanUpToString:@"," intoString:&temp_tvNetwork];
                            [myScanner scanString:@"," intoString:nil];
                            [myScanner scanUpToString:@"kljkjkj" intoString:&url];
                            
							if ([temp_showName hasSuffix:@" - -"])
							{
								NSString *temp_showName2;
								NSScanner *dashScanner = [NSScanner scannerWithString:temp_showName];
								[dashScanner scanUpToString:@" - -" intoString:&temp_showName2];
								temp_showName = temp_showName2;
								temp_showName = [temp_showName stringByAppendingFormat:@" - %@", temp_showName2];
							}
							[p setValue:temp_pid forKey:@"pid"];
							[p setValue:temp_showName forKey:@"showName"];
							[p setValue:temp_tvNetwork forKey:@"tvNetwork"];
                            [p setUrl:url];
							if ([temp_type isEqualToString:@"radio"]) [p setValue:@YES forKey:@"radio"];
							if ([[p showName] isEqualToString:[show showName]] || ([[p url] isEqualToString:[show url]] && [show url]))
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
							[searchException setInformativeText:@"Please check your query. Your query must not alter the output format of Get_iPlayer. (getiPlayerUpdateFinished)"];
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
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@NO forKey:@"successful"];
				}
		}
		
	}
	
	//Don't want to add these until the cache is up-to-date!
	if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SeriesLinkStartup"] boolValue])
	{
		NSLog(@"Checking series link");
		[self addSeriesLinkToQueue:self];
	}
	else
	{
		if (runScheduled) 
		{
			[self performSelectorOnMainThread:@selector(startDownloads:) withObject:self waitUntilDone:NO];
		}
	}
	
	//Check for Updates - Don't want to prompt the user when updates are running.
	SUUpdater *updater = [SUUpdater sharedUpdater];
	[updater checkForUpdatesInBackground];
	
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
-(void)addToLog:(NSString *)string
{
    [self addToLog:string :nil];
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
	NSString *logMessage = [note userInfo][@"message"];
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
    [searchField setEnabled:NO];
    
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
    [searchField setEnabled:YES];
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
		if (![string isEqualToString:@"Matches:"] && ![string hasPrefix:@"INFO:"] && ![string hasPrefix:@"WARNING:"]  && ![string hasPrefix:@"ERROR:"] && [string length]>0 && ![string hasPrefix:@"."])
		{
			@try {
				NSScanner *myScanner = [NSScanner scannerWithString:string];
				NSString *temp_pid = nil, *temp_showName = nil, *temp_tvNetwork = nil, *temp_type = nil, *url = nil;
				[myScanner scanUpToString:@":" intoString:&temp_pid];
				[myScanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
				[myScanner scanUpToString:@", ~" intoString:&temp_type];
				[myScanner scanString:@", ~" intoString:NULL];
				[myScanner scanUpToString:@"~," intoString:&temp_showName];
				[myScanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
				[myScanner scanUpToString:@"," intoString:&temp_tvNetwork];
                [myScanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
                [myScanner scanUpToString:@"kjkjkj" intoString:&url];
                if (temp_pid == nil || temp_showName == nil || temp_tvNetwork == nil || temp_type == nil || url == nil) {
                    [self addToLog: [NSString stringWithFormat:@"WARNING: Skipped invalid search result: %@", string]];
                    continue;
                }
				if ([temp_showName hasSuffix:@" - -"])
				{
					NSString *temp_showName2;
					NSScanner *dashScanner = [NSScanner scannerWithString:temp_showName];
					[dashScanner scanUpToString:@" - -" intoString:&temp_showName2];
					temp_showName = temp_showName2;
					temp_showName = [temp_showName stringByAppendingFormat:@" - %@", temp_showName2];
				}
				Programme *p = [[Programme alloc] initWithInfo:nil pid:temp_pid programmeName:temp_showName network:temp_tvNetwork];
                [p setUrl:url];
				if ([temp_type isEqualToString:@"radio"])
				{
					[p setValue:@YES forKey:@"radio"];
				}
                else if ([temp_type isEqualToString:@"podcast"])
                    [p setPodcast:@YES];
                
				[resultsController addObject:p];
				foundShow=YES;
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
			if ([[show showName] isEqualToString:[queuedShow showName]] && [show pid] == [queuedShow pid]) add=NO;
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
	NSString *listArgument = @"--listformat=<index> <pid> <type> <name> - <episode>,<channel>|<web>|";
	NSString *fieldsArgument = @"--fields=index,pid";
	NSString *wantedID = [pro valueForKey:@"pid"];
	NSString *cacheExpiryArg = [self cacheExpiryArgument:nil];
	NSArray *args = [[NSArray alloc] initWithObjects:getiPlayerPath,noWarningArg,@"--nopurge",cacheExpiryArg,[self typeArgument:nil],listArgument,profileDirArg,fieldsArgument,wantedID,nil];
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
			NSString *pid, *showName, *index, *type, *tvNetwork, *url;
			@try{
				NSScanner *scanner = [NSScanner scannerWithString:string];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&index];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&pid];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&type];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
				[scanner scanUpToString:@","  intoString:&showName];
                [scanner scanString:@"," intoString:nil];
                [scanner scanUpToString:@"|" intoString:&tvNetwork];
                [scanner scanString:@"|" intoString:nil];
                [scanner scanUpToString:@"|" intoString:&url];
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
                [p setValue:tvNetwork forKey:@"tvNetwork"];
                [p setUrl:url];
				if ([type isEqualToString:@"radio"]) [p setValue:@YES forKey:@"radio"];
                else if ([type isEqualToString:@"podcast"]) [p setPodcast:@YES];
			}
			else if ([wantedID isEqualToString:index])
			{
				found=YES;
				[p setValue:showName forKey:@"showName"];
                [p setValue:tvNetwork forKey:@"tvNetwork"];
                [p setUrl:url];
				if ([type isEqualToString:@"radio"]) [p setValue:@YES forKey:@"radio"];
                else if ([type isEqualToString:@"podcast"]) [p setPodcast:@YES];
			}
		}
			
	}
	if (!found)
    {
        if ([[p showName] isEqualToString:@""] || [[p showName] isEqualToString:@"Unknown: Not in Cache"])
            [p setValue:@"Unknown: Not in Cache" forKey:@"showName"];
        [p setProcessedPID:[[NSNumber alloc] initWithBool:NO]];
    }
	else
		[p setProcessedPID:@YES];
	
}
- (IBAction)getCurrentWebpage:(id)sender
{
    NSString *newShowName=nil;
	//Get Default Browser
	NSString *browser = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultBrowser"];
	
	//Prepare Pointer for URL
	NSString *url = nil;
    NSString *source = nil;
	
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
				SBElementArray *windows = [Safari windows];
				if ([@([windows count]) intValue])
				{
					for (SafariWindow *window in windows)
 					{
                        SafariTab *tab = [window currentTab];
                        if ([[tab URL] hasPrefix:@"http://www.bbc.co.uk/iplayer/episode/"] ||
                            [[tab URL] hasPrefix:@"http://bbc.co.uk/iplayer/episode/"] ||
                            [[tab URL] hasPrefix:@"http://bbc.co.uk/iplayer/console/"] ||
                            [[tab URL] hasPrefix:@"http://www.bbc.co.uk/iplayer/console/"] ||
                            [[tab URL] hasPrefix:@"http://bbc.co.uk/sport"])
                        {
                            url = [NSString stringWithString:[tab URL]];
                            NSScanner *nameScanner = [NSScanner scannerWithString:[tab name]];
                            [nameScanner scanString:@"BBC iPlayer - " intoString:nil];
                            [nameScanner scanString:@"BBC Sport - " intoString:nil];
                            [nameScanner scanUpToString:@"kjklgfdjfgkdlj" intoString:&newShowName];
                            foundURL=YES;
                        }
                        else if ([[tab URL] hasPrefix:@"https://www.itv.com/itvplayer/"] ||
                                 [[tab URL] hasPrefix:@"http://www.channel4.com/programmes/"] ||
                                 [[tab URL] hasPrefix:@"http://ps3.channel4.com"])
                        {
                            url = [NSString stringWithString:[tab URL]];
                            source = [Safari doJavaScript:@"document.documentElement.outerHTML" in:tab];
                            newShowName = [[[tab name] stringByReplacingOccurrencesOfString:@" | itvplayer" withString:@""] stringByReplacingOccurrencesOfString:@" - 4oD - Channel 4" withString:@""];
                            foundURL=YES;
                        }
					}
					if (foundURL==NO)
					{
						url = [NSString stringWithString:[[windows[0] currentTab] URL]];
                        //Might be incorrect
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
    else if ([browser isEqualToString:@"Chrome"])
	{
		BOOL foundURL=NO;
		ChromeApplication *Chrome = [SBApplication applicationWithBundleIdentifier:@"com.google.Chrome"];
		if ([Chrome isRunning])
		{
			@try
			{
				SBElementArray *windows = [Chrome windows];
				if ([@([windows count]) intValue])
				{
					for (ChromeWindow *window in windows)
 					{
                        ChromeTab *tab = [window activeTab];
                        if ([[tab URL] hasPrefix:@"http://www.bbc.co.uk/iplayer/episode/"] ||
                            [[tab URL] hasPrefix:@"http://bbc.co.uk/iplayer/episode/"] ||
                            [[tab URL] hasPrefix:@"http://bbc.co.uk/iplayer/console/"] ||
                            [[tab URL] hasPrefix:@"http://www.bbc.co.uk/iplayer/console/"] ||
                            [[tab URL] hasPrefix:@"http://bbc.co.uk/sport"])
                        {
                            url = [NSString stringWithString:[tab URL]];
                            NSScanner *nameScanner = [NSScanner scannerWithString:[tab title]];
                            [nameScanner scanString:@"BBC iPlayer - " intoString:nil];
                            [nameScanner scanString:@"BBC Sport - " intoString:nil];
                            [nameScanner scanUpToString:@"kjklgfdjfgkdlj" intoString:&newShowName];
                            foundURL=YES;
                        }
                        else if ([[tab URL] hasPrefix:@"https://www.itv.com/itvplayer/"] ||
                                 [[tab URL] hasPrefix:@"http://www.channel4.com/programmes/"] ||
                                 [[tab URL] hasPrefix:@"http://ps3.channel4.com"])
                        {
                            url = [NSString stringWithString:[tab URL]];
                            source = [tab executeJavascript:@"document.documentElement.outerHTML"];
                            newShowName = [[[tab title] stringByReplacingOccurrencesOfString:@" | itvplayer" withString:@""] stringByReplacingOccurrencesOfString:@" - 4oD - Channel 4" withString:@""];
                            foundURL=YES;
                        }
					}
					if (foundURL==NO)
					{
						url = [NSString stringWithString:[[windows[0] activeTab] URL]];
                        //Might be incorrect
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
    else
    {
        [[NSAlert alertWithMessageText:@"Get iPlayer Automator currently only supports Safari and Chrome." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Please change your preferred browser in the preferences and try again."] runModal];
        return;
    }
	/*else if ([browser isEqualToString:@"Firefox"])
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
					if ([[tab URL] hasPrefix:@"http://bbc.co.uk/iplayer/episode/"] || [[tab URL] hasPrefix:@"http://bbc.co.uk/iplayer/console/"] || [[tab URL] hasPrefix:@"http://www.itv.com/ITVPlayer/Video/default.html?ViewType"])
					{
						url = [[NSString alloc] initWithString:[tab URL]];
						foundURL=YES;
						break;
					}
				}
				if (foundURL==NO)
				{
					url = [[NSString alloc] initWithString:[[[tabsArray objectAtIndex:0] URL] path]];
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
    else if ([browser isEqualToString:@"Chrome"])
    {
        NSLog(@"Beginning Chrome");
        BOOL foundURL=NO;
        ChromeApplication *Chrome = [SBApplication applicationWithBundleIdentifier:@"com.google.Chrome"];
        if ([Chrome isRunning])
        {
            NSLog(@"Chrome is running.");
            @try
            {
                SBElementArray *windows = [Chrome windows];
                SBElementArray *tabs;
                for (ChromeWindow *chromeWindow1 in windows)
                {
                    [tabs addObject:[chromeWindow1 activeTab]];
                    NSLog(@"Adding tab.");
                }
                if ([tabs count]>0)
                {
                    NSLog(@"Have tabs");
                    for (ChromeTab *document in tabs)
                    {
                        NSLog(@"Looking at tab");
                        if ([[document URL] hasPrefix:@"http://www.bbc.co.uk/iplayer/episode/"] || [[document URL] hasPrefix:@"http://bbc.co.uk/iplayer/console/"] || [[document URL] hasPrefix:@"http://www.itv.com/ITVPlayer/Video/default.html?ViewType"])
                        {
                            url = [NSString stringWithString:[document URL]];
                            NSScanner *nameScanner = [NSScanner scannerWithString:[document title]];
                            [nameScanner scanString:@"BBC iPlayer - " intoString:nil];
                            [nameScanner scanUpToString:@"kjklgfdjfgkdlj" intoString:&newShowName];
                            foundURL=YES;
                        }
                    }
                    if (foundURL==NO)
                    {
                        NSLog(@"Didn't Find URL");
                        url = [NSString stringWithString:[[tabs objectAtIndex:0] URL]];
                        //Might be incorrect
                        NSLog(@"%@", url);
                    }
                    else
                    {
                        NSLog(@"%@", url);
                    }
                }
                else
                {
                    NSLog(@"Tab count is 0");
                    for (ChromeWindow *chromeWindow in windows)
                    {
                        url=[[chromeWindow activeTab] URL];
                    }
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
        NSLog(@"%d", foundURL);
    }*/
	//Process URL
	if([url hasPrefix:@"http://www.bbc.co.uk/iplayer/episode/"] || [url hasPrefix:@"http://beta.bbc.co.uk/iplayer/episode"])
	{
		NSString *pid = nil;
		NSScanner *urlScanner = [[NSScanner alloc] initWithString:url];
		[urlScanner scanUpToString:@"/episode/" intoString:nil];
		if ([urlScanner isAtEnd]) {
			[urlScanner setScanLocation:0];
			[urlScanner scanUpToString:@"/console/" intoString:nil];
		}
		[urlScanner scanString:@"/" intoString:nil];
		[urlScanner scanUpToString:@"/" intoString:nil];
		[urlScanner scanString:@"/" intoString:nil];
		[urlScanner scanUpToString:@"/" intoString:&pid];
		Programme *newProg = [[Programme alloc] init];
		[newProg setValue:pid forKey:@"pid"];
        if (newShowName) [newProg setShowName:newShowName];
		[queueController addObject:newProg];
		[self getNameForProgramme:newProg];
	}
    else if ([url hasPrefix:@"http://www.bbc.co.uk/sport/olympics/2012/live-video/"])
    {
        NSString *pid = nil;
        NSScanner *urlScanner = [NSScanner scannerWithString:url];
        [urlScanner scanString:@"http://www.bbc.co.uk/sport/olympics/2012/live-video/" intoString:nil];
        [urlScanner scanUpToString:@"kfejklfjklj" intoString:&pid];
        [queueController addObject:[[Programme alloc] initWithInfo:nil pid:pid programmeName:newShowName network:@"BBC Sport"]];
    }
	else if ([url hasPrefix:@"https://www.itv.com/itvplayer/"])
	{
        NSString *progname = nil, *productionId = nil, *pay_rights = nil, *title = nil;
        progname = newShowName;
		NSScanner *scanner = [NSScanner scannerWithString:source];
        [scanner scanUpToString:@"\"productionId\":" intoString:nil];
        [scanner scanString:@"\"productionId\":\"" intoString:nil];
        [scanner scanUpToString:@"\"" intoString:&productionId];
        [scanner scanUpToString:@"\"pay_rights\":" intoString:nil];
        [scanner scanString:@"\"pay_rights\":\"" intoString:nil];
        [scanner scanUpToString:@"\"" intoString:&pay_rights];
        [scanner scanUpToString:@"<h1 class=\"title episode-title\"" intoString:nil];
        [scanner scanUpToString:@">" intoString:nil];
        [scanner scanString:@">" intoString:nil];
        [scanner scanUpToString:@"<" intoString:&title];
        if (title) progname = title;        
        if (!progname || !productionId || ![pay_rights isEqualToString:@"free"]) {
            NSAlert *invalidPage = [[NSAlert alloc] init];
            [invalidPage addButtonWithTitle:@"OK"];
            [invalidPage setMessageText:[NSString stringWithFormat:@"Invalid Page: %@",url]];
            [invalidPage setInformativeText:@"Please ensure the frontmost browser tab is open to an ITV Player free catch-up episode page."];
            [invalidPage setAlertStyle:NSWarningAlertStyle];
            [invalidPage runModal];
            return;
        }
        NSString *pid = [productionId stringByReplacingOccurrencesOfString:@"\\" withString:@""];
        NSString *showName = [NSString stringWithFormat:@"%@ - %@", progname, pid];
		Programme *newProg = [[Programme alloc] init];
        [newProg setPid:pid];
        [newProg setShowName:showName];
        [newProg setTvNetwork:@"ITV"];
        [newProg setProcessedPID:@YES];
        [newProg setUrl:url];
		[queueController addObject:newProg];
	}
	else if ([url hasPrefix:@"http://www.channel4.com/programmes/"])
	{
		NSString *pid = nil;
		NSScanner *urlScanner = [NSScanner scannerWithString:url];
		[urlScanner scanUpToString:@"#" intoString:nil];
		[urlScanner scanString:@"#" intoString:nil];
		[urlScanner scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:&pid];
        if (!pid) {
            NSScanner *scanner = [NSScanner scannerWithString:source];
            [scanner scanUpToString:@"data-assetid=\"" intoString:nil];
            [scanner scanString:@"data-assetid=\"" intoString:nil];
            [scanner scanUpToString:@"\"" intoString:&pid];
        }
        if (!pid)
        {
            NSAlert *invalidPage = [[NSAlert alloc] init];
            [invalidPage addButtonWithTitle:@"OK"];
            [invalidPage setMessageText:[NSString stringWithFormat:@"Invalid Page: %@",url]];
            [invalidPage setInformativeText:@"Please ensure the frontmost browser tab is open to a 4oD episode page."];
            [invalidPage setAlertStyle:NSWarningAlertStyle];
            [invalidPage runModal];
            return;
        }
 		Programme *newProg = [[Programme alloc] init];
        [newProg setPid:pid];
 		[queueController addObject:newProg];
        [self getNameForProgramme:newProg];
    }
    else if ([url hasPrefix:@"http://ps3.channel4.com"])
    {
        NSString *pid = nil, *seriesName = nil;
    	NSScanner *ps3Scanner = [NSScanner scannerWithString:source];
        [ps3Scanner scanUpToString:@"brandTitle=" intoString:nil];
        [ps3Scanner scanString:@"brandTitle=" intoString:nil];
        [ps3Scanner scanUpToString:@"&" intoString:&seriesName];
        [ps3Scanner scanUpToString:@"preSelectAsset=" intoString:nil];
        [ps3Scanner scanString:@"preSelectAsset=" intoString:nil];
        [ps3Scanner scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:&pid];
        if (!seriesName) seriesName = newShowName;
        if (!pid || !seriesName)
        {
            NSAlert *invalidPage = [[NSAlert alloc] init];
            [invalidPage addButtonWithTitle:@"OK"];
            [invalidPage setMessageText:[NSString stringWithFormat:@"Invalid Page: %@",url]];
            [invalidPage setInformativeText:@"Please ensure the frontmost browser tab is open to a 4oD PS3 episode page."];
            [invalidPage setAlertStyle:NSWarningAlertStyle];
            [invalidPage runModal];
            return;
        }
        NSString *showName = [NSString stringWithFormat:@"%@ - %@", seriesName, pid];
        Programme *newProg = [[Programme alloc] init];
        [newProg setPid:pid];
        [newProg setShowName:showName];
        [newProg setTvNetwork:@"4oD C4"];
        [newProg setUrl:url];
        [newProg setProcessedPID:@YES];
        [queueController addObject:newProg];
    }
	else
	{
		NSAlert *invalidPage = [[NSAlert alloc] init];
		[invalidPage addButtonWithTitle:@"OK"];
		[invalidPage setMessageText:[NSString stringWithFormat:@"Invalid Page: %@",url]];
		[invalidPage setInformativeText:@"Please ensure the frontmost browser tab is open to an iPlayer episode page, ITV Player free catch-up episode page, 4oD episode page or 4oD PS3 episode page."];
		[invalidPage setAlertStyle:NSWarningAlertStyle];
		[invalidPage runModal];
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
			if (![[show status] isEqualToString:@"Waiting..."] && ![[show complete] isEqualToNumber:@YES])
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
									  informativeTextWithFormat:@"You can not remove a show that is currently downloading. " 
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
- (IBAction)hidePvrShow:(id)sender
{
	NSArray *temp_queue = [queueController selectedObjects];
	for (Programme *show in temp_queue)
	{
		if ([show realPID] && [[show status] isEqualToString:@"Added by Series-Link"])
		{
			NSDictionary *info = @{@"Programme": show};
			[[NSNotificationCenter defaultCenter] postNotificationName:@"AddProgToHistory" object:self userInfo:info];
			[queueController removeObject:show];
		}
	}
}
/*
- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
	[pboard declareTypes:[NSArray arrayWithObject:@"com.thomaswillson.programme.dragdrop"] owner:self];
	[pboard setData:data forType:@"com.thomaswillson.programme.dragdrop"];
	return YES;
}
- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDragOperation:(NSTableViewDropOperation)op
{
	return NSDragOperationEvery;
}
- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
			  row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard* pboard = [info draggingPasteboard];
    NSData* rowData = [pboard dataForType:MyPrivateTableViewDataType];
    NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
    int dragRow = [rowIndexes firstIndex];
	
    // Move the specified row to its new location...
}
 */
#pragma mark Download Controller
- (IBAction)startDownloads:(id)sender
{
    @try
    {
        [stopButton setEnabled:NO];
        [startButton setEnabled:NO];
    }
    @catch (NSException *e) {
        NSLog(@"NO UI: startDownloads:");
    }
    [self loadProxyInBackgroundForSelector:@selector(startDownloads:proxyError:) withObject:sender];
}

- (void)startDownloads:(id)sender proxyError:(NSError *)proxyError
{
    // reset after proxy load
    @try
    {
        [stopButton setEnabled:YES];
        [startButton setEnabled:YES];
    }
    @catch (NSException *e) {
        NSLog(@"NO UI: startDownloads:proxyError:");
    }
    if ([proxyError code] == kProxyLoadCancelled)
        return;
	NSAlert *whatAnIdiot = [NSAlert alertWithMessageText:@"No Shows in Queue!"
										   defaultButton:nil 
										 alternateButton:nil 
											 otherButton:nil 
							   informativeTextWithFormat:@"Try adding shows to the queue before clicking start; " 
							@"Get iPlayer Automator needs to know what to download."];
	if ([[queueController arrangedObjects] count] > 0)
	{
        NSLog(@"Initialising Failure Dictionary");
        if (!solutionsDictionary)
            solutionsDictionary = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ReasonsForFailure" ofType:@"plist"]];
        NSLog(@"Failure Dictionary Ready");
        
		BOOL foundOne=NO;
		runDownloads=YES;
        runScheduled=NO;
		[mainWindow setDocumentEdited:YES];
		[self addToLog:@"\rAppController: Starting Downloads" :nil];
		//Clean-Up Queue
		NSArray *tempQueue = [queueController arrangedObjects];
		for (Programme *show in tempQueue)
		{
			if ([[show successful] isEqualToNumber:@NO])
			{
				if ([[show processedPID] boolValue])
				{
					[show setComplete:@NO];
					[show setStatus:@"Waiting..."];
					foundOne=YES;
				}
				else
				{
					[self getNameForProgramme:show];
					if ([[show showName] isEqualToString:@"Unknown - Not in Cache"])
					{
						[show setComplete:@YES];
						[show setSuccessful:@NO];
						[show setStatus:@"Failed: Please set the show name"];
						[self addToLog:@"Could not download. Please set a show name first." :self];
					}
					else
					{
						[show setComplete:@NO];
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
            IOPMAssertionCreateWithDescription(kIOPMAssertionTypePreventUserIdleSystemSleep, (CFStringRef)@"Downloading Show", (CFStringRef)@"GiA is downloading shows.", NULL, NULL, (double)0, NULL, &powerAssertionID);
            
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
			[nc addObserver:self selector:@selector(setPercentage:) name:@"setPercentage" object:nil];
			[nc addObserver:self selector:@selector(setProgress:) name:@"setCurrentProgress" object:nil];
			[nc addObserver:self selector:@selector(nextDownload:) name:@"DownloadFinished" object:nil];
            
			tempQueue = [queueController arrangedObjects];
			[self addToLog:[NSString stringWithFormat:@"\rDownloading Show %lu/%lu:\r",
							(unsigned long)1,
							(unsigned long)[tempQueue count]]
						  :nil];
			for (Programme *show in tempQueue)
			{
				if ([[show complete] isEqualToNumber:@NO])
				{
                    if ([[show tvNetwork] hasPrefix:@"ITV"])
                        currentDownload = [[ITVDownload alloc] initWithProgramme:show itvFormats:[itvFormatController arrangedObjects] proxy:proxy];
                    else if ([[show tvNetwork] hasPrefix:@"4oD"])
                        currentDownload = [[FourODDownload alloc] initWithProgramme:show proxy:proxy];
                    else
                        currentDownload = [[BBCDownload alloc] initWithProgramme:show 
                                                                       tvFormats:[tvFormatController arrangedObjects] 
                                                                    radioFormats:[radioFormatController arrangedObjects]
                                                                           proxy:proxy];
					break;
				}
			}
			[startButton setEnabled:NO];
			[stopButton setEnabled:YES];
			
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
        runDownloads=NO;
        [mainWindow setDocumentEdited:NO];
		if (!runScheduled)
            [whatAnIdiot runModal];
        else if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"AutoRetryFailed"] boolValue])
        {
				NSDate *scheduledDate = [NSDate dateWithTimeIntervalSinceNow:60*[[[NSUserDefaults standardUserDefaults] valueForKey:@"AutoRetryTime"] doubleValue]];
				[datePicker setDateValue:scheduledDate];
				[self scheduleStart:self];
        }
        else if (runScheduled)
            runScheduled=NO;
	}
}
- (IBAction)stopDownloads:(id)sender
{
    IOPMAssertionRelease(powerAssertionID);
    
	runDownloads=NO;
    runScheduled=NO;
	[currentDownload cancelDownload:self];
	[[currentDownload show] setStatus:@"Cancelled"];
	if (!runUpdate)
		[startButton setEnabled:YES];
	[stopButton setEnabled:NO];
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
	
	[NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(fixDownloadStatus:) userInfo:currentDownload repeats:NO];	
}
- (void)fixDownloadStatus:(NSNotification *)note
{
	if (!runDownloads)
	{
		[[(Download*)[note userInfo] show] setValue:@"Cancelled" forKey:@"status"];
		currentDownload=nil;
		NSLog(@"Download should read cancelled");
	}
	else
		NSLog(@"fixDownloadStatus handler did not run because downloads appear to be running again");
}
- (void)setPercentage:(NSNotification *)note
{	
	if ([note userInfo])
	{
		NSDictionary *userInfo = [note userInfo];
		[currentIndicator setIndeterminate:NO];
		[currentIndicator startAnimation:nil];
        [currentIndicator setMinValue:0];
        [currentIndicator setMaxValue:100];
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
        previousDownload = currentDownload;
		Programme *finishedShow = [note object];
		if ([[finishedShow successful] boolValue])
		{
			[finishedShow setValue:@"Processing..." forKey:@"status"];
			if ([[[finishedShow path] pathExtension] isEqualToString:@"mov"])
			{
				[self cleanUpPath:finishedShow];
				[self seasonEpisodeInfo:finishedShow];
			}
			if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"AddCompletedToiTunes"] isEqualTo:@YES])
				[NSThread detachNewThreadSelector:@selector(addToiTunes:) toTarget:self withObject:finishedShow];
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
            
            ReasonForFailure *showSolution = [[ReasonForFailure alloc] init];
            [showSolution setShowName:[finishedShow showName]];
            [showSolution setSolution:[solutionsDictionary valueForKey:[finishedShow reasonForFailure]]];
            if (![showSolution solution])
                [showSolution setSolution:@"Problem Unknown.\nPlease submit a bug report from the application menu."];
            NSLog(@"Reason for Failure: %@", [finishedShow reasonForFailure]);
            NSLog(@"Dictionary Lookup: %@", [solutionsDictionary valueForKey:[finishedShow reasonForFailure]]);
            NSLog(@"Solution: %@", [showSolution solution]);
            [solutionsArrayController addObject:showSolution];
            NSLog(@"Added Solution");
            [solutionsTableView setRowHeight:68];
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
			[self addToLog:[NSString stringWithFormat:@"\rDownloading Show %lu/%lu:\r",
							(unsigned long)([tempQueue indexOfObject:nextShow]+1),
							(unsigned long)[tempQueue count]]
						  :nil];
			if ([[nextShow complete] isEqualToNumber:@NO])
            {
                if ([[nextShow tvNetwork] hasPrefix:@"ITV"])
                    currentDownload = [[ITVDownload alloc] initWithProgramme:nextShow itvFormats:[itvFormatController arrangedObjects] proxy:proxy];
                else if ([[nextShow tvNetwork] hasPrefix:@"4oD"])
                    currentDownload = [[FourODDownload alloc] initWithProgramme:nextShow proxy:proxy];
                else
                    currentDownload = [[BBCDownload alloc] initWithProgramme:nextShow 
                                                                   tvFormats:[tvFormatController arrangedObjects] 
                                                                radioFormats:[radioFormatController arrangedObjects]
                                                                       proxy:proxy];
            }
		}
		@catch (NSException *e)
		{
			//Downloads must be finished.
            IOPMAssertionRelease(powerAssertionID);
            
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
										description:[NSString stringWithFormat:@"Downloads Successful = %lu\nDownload Failed = %lu",
                                                     (unsigned long)downloadsSuccessful,(unsigned long)downloadsFailed]
								   notificationName:@"Downloads Finished"
										   iconData:nil
										   priority:0
										   isSticky:NO
									   clickContext:nil];
			[[SUUpdater sharedUpdater] checkForUpdatesInBackground];
			
			if (downloadsFailed>0)
                [solutionsWindow makeKeyAndOrderFront:self];
			if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"AutoRetryFailed"] boolValue] && downloadsFailed>0)
			{
				NSDate *scheduledDate = [NSDate dateWithTimeIntervalSinceNow:60*[[[NSUserDefaults standardUserDefaults] valueForKey:@"AutoRetryTime"] doubleValue]];
				[datePicker setDateValue:scheduledDate];
				[self scheduleStart:self];
			}
			
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
				[myScanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
				[myScanner scanUpToString:@", ~" intoString:NULL];
				[myScanner scanString:@", ~" intoString:nil];
				[myScanner scanUpToString:@"~," intoString:&temp_showName];
				[myScanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
				[myScanner scanUpToString:@"," intoString:&temp_tvNetwork];
				[myScanner scanString:@", " intoString:nil];
				[myScanner scanInteger:&timeadded];
				
				[p setValue:temp_pid forKey:@"pid"];
				[p setValue:temp_showName forKey:@"showName"];
				[p setValue:temp_tvNetwork forKey:@"tvNetwork"];
				NSNumber *added = @(timeadded);
				[p setValue:added forKey:@"timeadded"];
				[pvrResultsController addObject:p];
			}
			@catch (NSException *e) {
				NSAlert *searchException = [[NSAlert alloc] init];
				[searchException addButtonWithTitle:@"OK"];
				[searchException setMessageText:[NSString stringWithFormat:@"Invalid Output!"]];
				[searchException setInformativeText:@"Please check your query. You query must not alter the output format of Get_iPlayer. (pvrSearchFinished)"];
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
		Series *show = [[Series alloc] initWithShowname:tempName];
		[show setValue:[programme timeadded] forKey:@"added"];
		[show setValue:[programme tvNetwork] forKey:@"tvNetwork"];
		[show setValue:[NSDate date] forKey:@"lastFound"];
        //Check to make sure the programme isn't already in the queue before adding it.
        NSArray *queuedObjects = [pvrQueueController arrangedObjects];
        BOOL add=YES;
        for (Programme *queuedShow in queuedObjects)
        {
            if ([[show showName] isEqualToString:[queuedShow showName]] && [show tvNetwork] == [queuedShow tvNetwork]) add=NO;
        }
        if (add)
        {
            [pvrQueueController addObject:show];
        }
	}
}
- (IBAction)addSeriesLinkToQueue:(id)sender
{
	//[NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(seriesLinkToQueueTimerSelector:) userInfo:nil repeats:NO];
	//NSThreadWillExitNotification
	if ([[pvrQueueController arrangedObjects] count] > 0 && !runUpdate)
	{
		if (!runDownloads)
		{
			[currentIndicator setIndeterminate:YES];
			[currentIndicator startAnimation:self];
			[startButton setEnabled:NO];
		}
		NSLog(@"About to launch Series-Link Thread");
		[NSThread detachNewThreadSelector:@selector(seriesLinkToQueueTimerSelector) toTarget:self withObject:nil];
		NSLog(@"Series-Link Thread Launched");
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(seriesLinkFinished:) name:@"NSThreadWillExitNotification" object:nil];
	}	
}
- (void)seriesLinkToQueueTimerSelector
{
	NSArray *seriesLink = [pvrQueueController arrangedObjects];
	if (!runDownloads)
		[currentProgress performSelectorOnMainThread:@selector(setStringValue:) withObject:@"Updating Series Link..." waitUntilDone:YES];
	NSMutableArray *seriesToBeRemoved = [[NSMutableArray alloc] init];
	for (Series *series in seriesLink)
	{
		if (!runDownloads)
			[currentProgress performSelectorOnMainThread:@selector(setStringValue:) withObject:[NSString stringWithFormat:@"Updating Series Link - %lu/%lu - %@",(unsigned long)[seriesLink indexOfObject:series],(unsigned long)[seriesLink count],[series showName]] waitUntilDone:YES];
		NSString *cacheExpiryArgument = [self cacheExpiryArgument:nil];
		NSString *typeArgument = [self typeArgument:nil];
		
		NSMutableArray *autoRecordArgs = [[NSMutableArray alloc] initWithObjects:getiPlayerPath, noWarningArg,@"--nopurge",
										  @"--listformat=<index>: <type>, ~<name> - <episode>~, <channel>, <timeadded>, <pid>,<web>", cacheExpiryArgument, 
										  typeArgument, profileDirArg,@"--hide",[self escapeSpecialCharactersInString:[series showName]],nil];
		
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
		if (![self processAutoRecordData:[autoRecordData copy] forSeries:series])
			[seriesToBeRemoved addObject:series];
	}
	[pvrQueueController performSelectorOnMainThread:@selector(removeObjects:) withObject:seriesToBeRemoved waitUntilDone:NO];
}
- (void)seriesLinkFinished:(NSNotification *)note
{
	NSLog(@"Thread Finished Notification Received");
	if (!runDownloads)
	{
		[currentProgress setStringValue:@""];
		[currentIndicator setIndeterminate:NO];
		[currentIndicator stopAnimation:self];
		[startButton setEnabled:YES];
	}
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"NSThreadWillExitNotification" object:nil];
	
	//If this is an update initiated by the scheduler, run the downloads.
	if (runScheduled && !scheduleTimer) 
	{
		[self performSelectorOnMainThread:@selector(startDownloads:) withObject:self waitUntilDone:NO];
	}
	[self performSelectorOnMainThread:@selector(scheduleTimerForFinished:) withObject:nil waitUntilDone:NO];
	NSLog(@"Series-Link Thread Finished");
}
	 
- (void)scheduleTimerForFinished:(id)sender
{
	[NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(seriesLinkFinished2:) userInfo:currentProgress repeats:NO];
}
- (void)seriesLinkFinished2:(NSNotification *)note
{
	NSLog(@"Second Check");
	if (!runDownloads)
	{
		[currentProgress setStringValue:@""];
		[currentIndicator setIndeterminate:NO];
		[currentIndicator stopAnimation:self];
		[startButton setEnabled:YES];
	}
	NSLog(@"Definitely shouldn't show an updating series-link thing!");
}
- (BOOL)processAutoRecordData:(NSString *)autoRecordData2 forSeries:(Series *)series2
{
	BOOL oneFound=NO;
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
				NSString *temp_pid, *temp_showName, *temp_tvNetwork, *temp_type, *temp_realPID, *url;
				NSInteger timeadded;
				[myScanner scanUpToString:@":" intoString:&temp_pid];
				[myScanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
				[myScanner scanUpToString:@", ~" intoString:&temp_type];
				[myScanner scanString:@", ~" intoString:nil];
				[myScanner scanUpToString:@"~," intoString:&temp_showName];
				[myScanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
				[myScanner scanUpToString:@"," intoString:&temp_tvNetwork];
				[myScanner scanString:@"," intoString:nil];
				[myScanner scanInteger:&timeadded];
				[myScanner scanUpToString:@", " intoString:nil];
				[myScanner scanString:@", " intoString:nil];
				[myScanner scanUpToString:@"," intoString:&temp_realPID];
                [myScanner scanString:@"," intoString:nil];
                [myScanner scanUpToString:@"kjkjkj" intoString:&url];
				
				NSScanner *seriesEpisodeScanner = [NSScanner scannerWithString:temp_showName];
				NSString *series_Name, *episode_Name;
				[seriesEpisodeScanner scanUpToString:@" - " intoString:&series_Name];
				[seriesEpisodeScanner scanString:@"-" intoString:nil];
				[seriesEpisodeScanner scanUpToString:@"kjkljfdg" intoString:&episode_Name];
				if ([temp_showName hasSuffix:@" - -"])
				{
					NSString *temp_showName2;
					NSScanner *dashScanner = [NSScanner scannerWithString:temp_showName];
					[dashScanner scanUpToString:@" - -" intoString:&temp_showName2];
					temp_showName = temp_showName2;
					temp_showName = [temp_showName stringByAppendingFormat:@" - %@", temp_showName2];
				}
				if (([[series2 added] integerValue] > timeadded) && ([temp_tvNetwork isEqualToString:[series2 tvNetwork]]))
                {
                    [series2 setAdded:@(timeadded)];
                }
				if (([[series2 added] integerValue] <= timeadded) && ([temp_tvNetwork isEqualToString:[series2 tvNetwork]]))
				{
                    @try {
                        oneFound=YES;
                        Programme *p = [[Programme alloc] initWithInfo:nil pid:temp_pid programmeName:temp_showName network:temp_tvNetwork];
                        [p setRealPID:temp_realPID];
                        [p setSeriesName:series_Name];
                        [p setEpisodeName:episode_Name];
                        [p setUrl:url];
                        if ([temp_type isEqualToString:@"radio"]) [p setValue:@YES forKey:@"radio"];
                        else if ([temp_type isEqualToString:@"podcast"]) [p setPodcast:@YES];
                        [p setValue:@"Added by Series-Link" forKey:@"status"];
                        BOOL inQueue=NO;
                        for (Programme *show in currentQueue)
                            if ([[show showName] isEqualToString:[p showName]] && [[show pid] isEqualToString:[p pid]]) inQueue=YES;
                        if (!inQueue) 
                        {
                            if (runDownloads) [p setValue:@"Waiting..." forKey:@"status"];
                            [queueController performSelectorOnMainThread:@selector(addObject:) withObject:p waitUntilDone:NO];
                        }
                    }
                    @catch (NSException *e) {
                        NSAlert *queueException = [[NSAlert alloc] init];
                        [queueException addButtonWithTitle:@"OK"];
                        [queueException setMessageText:[NSString stringWithFormat:@"Series-Link to Queue Transfer Failed"]];
                        [queueException setInformativeText:@"The recording queue is in an unknown state.  Please restart GiA and clear the recording queue."];
                        [queueException setAlertStyle:NSWarningAlertStyle];
                        [queueException runModal];
                        queueException = nil;
                    }
				}
			}
			@catch (NSException *e) {
				NSAlert *searchException = [[NSAlert alloc] init];
				[searchException addButtonWithTitle:@"OK"];
				[searchException setMessageText:[NSString stringWithFormat:@"Invalid Output!"]];
				[searchException setInformativeText:@"Please check your query. Your query must not alter the output format of Get_iPlayer. (processAutoRecordData)"];
				[searchException setAlertStyle:NSWarningAlertStyle];
				[searchException runModal];
				searchException = nil;
			}
		}
		else
		{
			if ([string hasPrefix:@"Unknown option:"] || [string hasPrefix:@"Option"] || [string hasPrefix:@"Usage"])
			{
				return NO;
			}
		}
	}
	if (oneFound)
	{
		[series2 setLastFound:[NSDate date]];
		return YES;
	}
	else
	{
		if (!([[NSDate date] timeIntervalSinceDate:[series2 lastFound]] < ([[[NSUserDefaults standardUserDefaults] valueForKey:@"KeepSeriesFor"] intValue]*86400)) && [[[NSUserDefaults standardUserDefaults] valueForKey:@"RemoveOldSeries"] boolValue])
		{
			return NO;
		}
		return YES;
	}
}

#pragma mark Misc.
- (IBAction)closeWindow:(id)sender
{
    if ([logWindow isKeyWindow]) [logWindow performClose:self];
    else if ([historyWindow isKeyWindow]) [historyWindow performClose:self];
    else if ([pvrPanel isKeyWindow]) [pvrPanel performClose:self];
    else if ([prefsPanel isKeyWindow]) [prefsPanel performClose:self];
    else if ([mainWindow isKeyWindow])
    {
        NSAlert *downloadAlert = [NSAlert alertWithMessageText:@"Are you sure you wish to quit?" 
                                                 defaultButton:@"Yes" 
                                               alternateButton:@"No" 
                                                   otherButton:nil 
                                     informativeTextWithFormat:nil];
        NSInteger response = [downloadAlert runModal];
        if (response == NSAlertDefaultReturn) [mainWindow performClose:self];
    }
}
- (NSString *)escapeSpecialCharactersInString:(NSString *)string
{
    NSArray *characters = @[@"+",@"-",@"&",@"!",@"(",@")",@"{",@"}",
                           @"[",@"]"@"^",@"~",@"*",@"?",@":",@"\""];
    for (NSString *character in characters)
        string = [string stringByReplacingOccurrencesOfString:character withString:[NSString stringWithFormat:@"\\%@",character]];
    
    return string;
}
- (void)thirtyTwoBitModeAlert
{
    if ([[NSAlert alertWithMessageText:@"File could not be added to iTunes," defaultButton:@"Help Me!" alternateButton:@"Do nothing" otherButton:nil informativeTextWithFormat:@"This is usually fixed by running iTunes in 32-bit mode. Would you like instructions to do this?"] runModal] == NSAlertDefaultReturn)
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://support.apple.com/kb/TS3771"]];
}
- (void)addToiTunes:(Programme *)show
{
	NSString *path = [[NSString alloc] initWithString:[show path]];
	NSString *ext = [path pathExtension];
	
	[self performSelectorOnMainThread:@selector(addToLog:) withObject:[NSString stringWithFormat:@"Adding %@ to iTunes",[show showName]] waitUntilDone:NO];
	
	iTunesApplication *iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
	
	NSArray *fileToAdd = @[[NSURL fileURLWithPath:path]];
	if (![iTunes isRunning]) [iTunes activate];
	@try
	{
		if ([ext isEqualToString:@"mov"] || [ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mp3"] || [ext isEqualToString:@"m4a"])
		{
			iTunesTrack *track = [iTunes add:fileToAdd to:nil];
            NSLog(@"Track exists = %@", ([track exists] ? @"YES" : @"NO"));
			if ([track exists] && ([ext isEqualToString:@"mov"] || [ext isEqualToString:@"mp4"]))
			{
				if ([ext isEqualToString:@"mov"])
				{
					//[track setVideoKind:iTunesEVdKTVShow];
					[track setName:[show episodeName]];
					[track setEpisodeID:[show episodeName]];
					[track setShow:[show seriesName]];
					[track setArtist:[show tvNetwork]];
					if ([show season]>0) [track setSeasonNumber:[show season]];
					if ([show episode]>0) [track setEpisodeNumber:[show episode]];
				}
				[track setUnplayed:YES];
                [show setValue:@"Complete & in iTunes" forKey:@"status"];
			}
			else if ([track exists] && ([ext isEqualToString:@"mp3"] || [ext isEqualToString:@"m4a"]))
			{
				//[self addToLog:@"Setting Podcast Metadata:" :self];
				[track setBookmarkable:YES];
				//[self addToLog:@"	Bookmarkable set" :self];
				//[track setName:[show showName]];
				//[self addToLog:@"	Name set" :self];
				//[track setAlbum:[show seriesName]];
				//[self addToLog:@"	Album set" :self];
				[track setUnplayed:YES];
				//[self addToLog:@"	Unplayed set" :self];
				//[track setArtist:[show tvNetwork]];
				//[self addToLog:@"	Artist set" :self];
				//[self addToLog:@"All Metadata set." :self];
                [show setValue:@"Complete & in iTunes" forKey:@"status"];
			}
			else
            {
                [self performSelectorOnMainThread:@selector(addToLog:) withObject:@"iTunes did not accept file." waitUntilDone:YES];
                [self performSelectorOnMainThread:@selector(addToLog:) withObject:@"Try setting iTunes to open in 32-bit mode." waitUntilDone:YES];
                [self performSelectorOnMainThread:@selector(thirtyTwoBitModeAlert) withObject:nil waitUntilDone:NO];
                [show setValue:@"Complete: Not in iTunes" forKey:@"status"];
            }
		}
		else
		{
			[self performSelectorOnMainThread:@selector(addToLog:) withObject:@"Can't add to iTunes; incompatible format." waitUntilDone:YES];
			[self performSelectorOnMainThread:@selector(addToLog:) withObject:@"			iTunes Compatible Modes: Flash - High, Flash - Standard, Flash - HD, iPhone, Radio - MP3, Podcast" waitUntilDone:YES];
			[show setValue:@"Download Complete" forKey:@"status"];
		}
	}
	@catch (NSException *e)
	{
		[self performSelectorOnMainThread:@selector(addToLog:) withObject:@"Unable to Add to iTunes" waitUntilDone:YES];
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
	
	/*if (![[show path] isEqualToString:@"Unknown"])
	{
		//Process Original Path into Parts
		NSString *originalPath = [NSString stringWithString:[show path]];
		NSString *originalFolder = [originalPath stringByDeletingLastPathComponent];
		NSString *extension = [originalPath pathExtension];
		
		NSString *originalSubtitlePath = [show subtitlePath];
		
		//Retrieve Mode Used
		NSString *originalFilename = [originalPath lastPathComponent];
		NSScanner *originalFilenameScanner = [NSScanner scannerWithString:originalFilename];
		[originalFilenameScanner scanUpToString:@"((" intoString:nil];
		[originalFilenameScanner scanString:@"((" intoString:nil];
		NSString *modeKey;
		[originalFilenameScanner scanUpToString:@"))" intoString:&modeKey];
		NSDictionary *modeLookup = [NSDictionary dictionaryWithObjectsAndKeys:@"Very High",@"flashvhigh1",@"Very High",@"flashvhigh2",@"HD",@"flashhd1",@"HD",@"flashhd2",@"High",@"flashhigh1",@"High",@"flashhigh2",@"Standard",@"flashstd1",@"Standard",@"flashstd2",nil];
		NSString *modeUsed = [modeLookup objectForKey:modeKey];
		
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
			NSString *newSubtitlePath;
			if (originalSubtitlePath)
			{
				NSString *newSubtitleFilename = [NSString stringWithFormat:@"%@ (Subtitles).srt", newFilename];
				newSubtitlePath = [newFolder stringByAppendingPathComponent:newSubtitleFilename];
			}
			
			//Perform File Operations
			NSFileManager *fileManager = [NSFileManager defaultManager];
			[fileManager createDirectoryAtPath:newFolder attributes:nil];
			if ([fileManager fileExistsAtPath:newFile])
			{
				newFilename = [newFilename stringByAppendingFormat:@" (%@)", modeUsed];
				newFile = [newFolder stringByAppendingPathComponent:newFilename];
				newFile = [newFile stringByAppendingPathExtension:extension];
				[show setValue:[[show showName] stringByAppendingFormat:@" (%@)", modeUsed] forKey:@"showName"];
				
			}
			NSError *copyError;
			if ([fileManager moveItemAtPath:[show path] toPath:newFile error:&copyError]) 
			{
				NSLog(@"Original: %@ \rNew: %@", originalSubtitlePath, newSubtitlePath);
				if (originalSubtitlePath && newSubtitlePath)
					[fileManager moveItemAtPath:originalSubtitlePath toPath:newSubtitlePath error:nil];
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
	*/
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
    [openPanel setCanCreateDirectories:YES];
	[openPanel runModal];
	NSArray *urls = [openPanel URLs];
	[[NSUserDefaults standardUserDefaults] setValue:[urls[0] path] forKey:@"DownloadPath"];
}
- (IBAction)showFeedback:(id)sender
{
	[JRFeedbackController showFeedback];
}
- (IBAction)restoreDefaults:(id)sender
{	
	NSUserDefaults *sharedDefaults = [NSUserDefaults standardUserDefaults];
	[sharedDefaults removeObjectForKey:@"DownloadPath"];
	[sharedDefaults removeObjectForKey:@"Proxy"];
	[sharedDefaults removeObjectForKey:@"CustomProxy"];
	[sharedDefaults removeObjectForKey:@"AutoRetryFailed"];
	[sharedDefaults removeObjectForKey:@"AutoRetryTime"];
	[sharedDefaults removeObjectForKey:@"AddCompletedToiTunes"];
	[sharedDefaults removeObjectForKey:@"DefaultBrowser"];
	[sharedDefaults removeObjectForKey:@"DefaultFormat"];
	[sharedDefaults removeObjectForKey:@"AlternateFormat"];
	[sharedDefaults removeObjectForKey:@"CacheBBC_TV"];
	[sharedDefaults removeObjectForKey:@"CacheITV_TV"];
	[sharedDefaults removeObjectForKey:@"CacheBBC_Radio"];
	[sharedDefaults removeObjectForKey:@"CacheBBC_Podcasts"];
    [sharedDefaults removeObjectForKey:@"Cache4oD_TV"];
	[sharedDefaults removeObjectForKey:@"CacheExpiryTime"];
	[sharedDefaults removeObjectForKey:@"Verbose"];
	[sharedDefaults removeObjectForKey:@"SeriesLinkStartup"];
	[sharedDefaults removeObjectForKey:@"DownloadSubtitles"];
	[sharedDefaults removeObjectForKey:@"AlwaysUseProxy"];
	[sharedDefaults removeObjectForKey:@"XBMC_naming"];
}
	
#pragma mark Argument Retrieval
- (NSString *)typeArgument:(id)sender
{
	if (runSinceChange || !currentTypeArgument)
	{
		NSMutableString *typeArgument = [[NSMutableString alloc] initWithString:@"--type="];
		if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_TV"] isEqualTo:@YES])
            [typeArgument appendString:@"tv,"];
		if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheITV_TV"] isEqualTo:@YES])
            [typeArgument appendString:@"itv,"];
		if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_Radio"] isEqualTo:@YES])
            [typeArgument appendString:@"radio,"];
		if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_Podcasts"] isEqualTo:@YES])
            [typeArgument appendString:@"podcast,"];
        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"Cache4oD_TV"] isEqualTo:@YES])
            [typeArgument appendString:@"ch4,"];
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
	if ([scheduleWindow isVisible])
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
	scheduleTimer=nil;
	[self forceUpdate:self];
}
- (void)updateScheduleStatus:(NSTimer *)theTimer
{
	NSDate *startTime = [scheduleTimer fireDate];
	NSDate *currentTime = [NSDate date];
	
	unsigned int unitFlags = NSHourCalendarUnit | NSMinuteCalendarUnit | NSDayCalendarUnit | NSSecondCalendarUnit;
	NSDateComponents *conversionInfo = [[NSCalendar currentCalendar] components:unitFlags fromDate:currentTime toDate:startTime options:0];
	
	NSString *status = [NSString stringWithFormat:@"Time until Start (DD:HH:MM:SS): %02ld:%02ld:%02ld:%02ld",
						(long)[conversionInfo day], (long)[conversionInfo hour],
						(long)[conversionInfo minute],(long)[conversionInfo second]];
	if (!runUpdate)
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
    [self loadProxyInBackgroundForSelector:@selector(startLiveTV:proxyError:) withObject:sender];
}

- (IBAction)startLiveTV:(id)sender proxyError:(NSError *)proxyError
{
    if ([proxyError code] == kProxyLoadCancelled)
        return;
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
	
	//Get selected channel
	LiveTVChannel *selectedChannel = [liveTVChannelController arrangedObjects][[liveTVChannelController selectionIndex]];
	
	//Set Proxy Arguments
	NSString *proxyArg = NULL;
	NSString *partialProxyArg = NULL;
    if (proxy)
    {
        proxyArg = [[NSString alloc] initWithFormat:@"-p%@", [proxy url]];
        if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue])
        {
            partialProxyArg = @"--partial-proxy";
        }
    }
	
	//Prepare Arguments	
	NSArray *args = @[[[NSBundle mainBundle] pathForResource:@"get_iplayer" ofType:@"pl"],
					 profileDirArg,
					 @"--stream",
					 @"--modes=flashnormal",
					 @"--type=livetv",
					 [selectedChannel channel],
					 //@"--player=mplayer -cache 3072 -",
					// [NSString stringWithFormat:@"--player=\"%@\" -cache 3072 -", [[NSBundle mainBundle] pathForResource:@"mplayer" ofType:nil]],
					 proxyArg,
					 partialProxyArg];
	[getiPlayerStreamer setArguments:args];
	
	[mplayerStreamer setArguments:@[@"-cache",@"3072",@"-"]];
	
	
	[getiPlayerStreamer launch];
	[mplayerStreamer launch];
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

#pragma mark Proxy
- (void)loadProxyInBackgroundForSelector:(SEL)selector withObject:(id)object
{
    [self updateProxyLoadStatus:YES message:@"Loading proxy settings..."];
    NSLog(@"INFO: Loading proxy settings...");
    [self addToLog:@"\n\nINFO: Loading proxy settings..."];
    [proxyDict removeAllObjects];
    proxyDict[@"selector"] = [NSValue valueWithPointer:selector];
    if (object)
        proxyDict[@"object"] = object;
    proxy = nil;
    NSString *proxyOption = [[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"];
	if ([proxyOption isEqualToString:@"Custom"])
	{
        NSString *proxyValue = [[[[NSUserDefaults standardUserDefaults] valueForKey:@"CustomProxy"] lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([proxyValue length] == 0)
        {
            NSLog(@"WARNING: Custom proxy setting was blank. No proxy will be used.");
            [self addToLog:@"WARNING: Custom proxy setting was blank. No proxy will be used."];
            if (!runScheduled)
            {
                NSAlert *alert = [NSAlert alertWithMessageText:@"Custom proxy setting was blank.\nDownloads may fail.\nDo you wish to continue?"
                                                 defaultButton:@"No"
                                               alternateButton:@"Yes"
                                                   otherButton:nil
                                     informativeTextWithFormat:@""];
                [alert setAlertStyle:NSCriticalAlertStyle];
                if ([alert runModal] == NSAlertDefaultReturn)
                {
                    [self cancelProxyLoad];
                }
                else
                {
                    [self failProxyLoad];
                }
            }
        }
        else
        {
            proxy = [[HTTPProxy alloc] initWithString:proxyValue];
            [self finishProxyLoad];
        }
	}
	else if ([proxyOption isEqualToString:@"Provided"])
	{
        ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:@"http://tom-tech.com/get_iplayer/proxy.txt"]];
        [request setUserInfo:@{@"selector": [NSValue valueWithPointer:selector], @"object": object}];
        [request setDelegate:self];
        [request setDidFailSelector:@selector(providedProxyDidFinish:)];
        [request setDidFinishSelector:@selector(providedProxyDidFinish:)];
        [request setTimeOutSeconds:30];
        [self updateProxyLoadStatus:YES message:[NSString stringWithFormat:@"Loading provided proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]]];
        NSLog(@"INFO: Loading provided proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]);
        [self addToLog:[NSString stringWithFormat:@"INFO: Loading provided proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]]];
        [request startAsynchronous];
	}
    else
    {
        NSLog(@"INFO: No proxy to load");
        [self addToLog:@"INFO: No proxy to load"];
        [self finishProxyLoad];
    }
}

- (void)providedProxyDidFinish:(ASIHTTPRequest *)request
{
    NSData *urlData = [request responseData];
    if ([request responseStatusCode] != 200 || !urlData)
    {
        NSLog(@"WARNING: Provided proxy could not be retrieved. No proxy will be used.");
        [self addToLog:@"WARNING: Provided proxy could not be retrieved. No proxy will be used."];
        if (!runScheduled)
        {
            NSError *error = [request error];
            NSAlert *alert = [NSAlert alertWithMessageText:@"Provided proxy could not be retrieved.\nDownloads may fail.\nDo you wish to continue?"
                                             defaultButton:@"No"
                                           alternateButton:@"Yes"
                                               otherButton:nil
                                 informativeTextWithFormat:@"Error: %@", (error ? [error localizedDescription] : @"Unknown error")];
            [alert setAlertStyle:NSCriticalAlertStyle];
            if ([alert runModal] == NSAlertDefaultReturn)
                [self cancelProxyLoad];
            else
                [self failProxyLoad];
        }
    }
    else
    {
        NSString *proxyValue = [[[[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding] lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([proxyValue length] == 0)
        {
            NSLog(@"WARNING: Provided proxy value was blank. No proxy will be used.");
            [self addToLog:@"WARNING: Provided proxy value was blank. No proxy will be used."];
            if (!runScheduled)
            {
                NSAlert *alert = [NSAlert alertWithMessageText:@"Provided proxy value was blank.\nDownloads may fail.\nDo you wish to continue?"
                                                 defaultButton:@"No"
                                               alternateButton:@"Yes"
                                                   otherButton:nil
                                     informativeTextWithFormat:@""];
                [alert setAlertStyle:NSCriticalAlertStyle];
                if ([alert runModal] == NSAlertDefaultReturn)
                    [self cancelProxyLoad];
                else
                    [self failProxyLoad];
            }
        }
        else
        {
            proxy = [[HTTPProxy alloc] initWithString:proxyValue];
            [self finishProxyLoad];
        }
    }
}

- (void)cancelProxyLoad
{
    [self returnFromProxyLoadWithError:[NSError errorWithDomain:@"Proxy" code:kProxyLoadCancelled userInfo:@{NSLocalizedDescriptionKey: @"Proxy Load Cancelled"}]];
}

- (void)failProxyLoad
{
    [self returnFromProxyLoadWithError:[NSError errorWithDomain:@"Proxy" code:kProxyLoadFailed userInfo:@{NSLocalizedDescriptionKey: @"Proxy Load Failed"}]];
}

- (void)finishProxyLoad
{
    NSLog(@"INFO: Proxy load complete.");
    [self addToLog:@"INFO: Proxy load complete."];
    if (proxy && [[NSUserDefaults standardUserDefaults] boolForKey:@"TestProxy"])
    {
        [self testProxyOnLoad];
        return;
    }
    [self returnFromProxyLoadWithError:nil];
}

- (void)testProxyOnLoad
{
    if (proxy)
    {
        NSString *testURL = [[NSUserDefaults standardUserDefaults] stringForKey:@"ProxyTestURL"];
        if (!testURL)
            testURL = @"http://www.google.com";
        ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:testURL]];
        [request setDelegate:self];
        [request setDidFailSelector:@selector(proxyTestDidFinish:)];
        [request setDidFinishSelector:@selector(proxyTestDidFinish:)];
        [request setTimeOutSeconds:30];
        [request setProxyType:proxy.type];
        [request setProxyHost:proxy.host];
        if (proxy.port)
            [request setProxyPort:proxy.port];
        if (proxy.user) {
            [request setProxyUsername:proxy.user];
            [request setProxyPassword:proxy.password];
        }
        [self updateProxyLoadStatus:YES message:[NSString stringWithFormat:@"Testing proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]]];
        NSLog(@"INFO: Testing proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]);
        [self addToLog:[NSString stringWithFormat:@"INFO: Testing proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]]];
        [request startAsynchronous];
    }
    else
    {
        NSLog(@"INFO: No proxy to test");
        [self addToLog:@"INFO: No proxy to test"];
        [self finishProxyTest];
    }
}

- (void)proxyTestDidFinish:(ASIHTTPRequest *)request
{
    if ([request responseStatusCode] != 200)
    {
        NSLog(@"WARNING: Proxy failed to load test page: %@", [request url]);
        [self addToLog:[NSString stringWithFormat:@"WARNING: Proxy failed to load test page: %@", [request url]]];
        if (!runScheduled)
        {
            NSError *error = [request error];
            NSAlert *alert = [NSAlert alertWithMessageText:@"Proxy failed to load test page.\nDownloads may fail.\nDo you wish to continue?"
                                             defaultButton:@"No"
                                           alternateButton:@"Yes"
                                               otherButton:nil
                                 informativeTextWithFormat:@"Failed to load %@ within %ld seconds\nUsing proxy: %@\nError: %@", [request url], (NSInteger)[request timeOutSeconds], [proxy url], (error ? [error localizedDescription] : @"Unknown error")];
            [alert setAlertStyle:NSCriticalAlertStyle];
            if ([alert runModal] == NSAlertDefaultReturn)
                [self cancelProxyLoad];
            else
                [self failProxyTest];
        }
    }
    else
    {
        [self finishProxyTest];
    }
}

- (void)failProxyTest
{
    [self returnFromProxyLoadWithError:[NSError errorWithDomain:@"Proxy" code:kProxyLoadFailed userInfo:@{NSLocalizedDescriptionKey: @"Proxy Text Failed"}]];
}

- (void)finishProxyTest
{
    NSLog(@"INFO: Proxy test complete.");
    [self addToLog:@"INFO: Proxy test complete."];
    [self returnFromProxyLoadWithError:nil];
}

- (void)returnFromProxyLoadWithError:(NSError *)error
{
    if (proxy)
    {
        NSLog(@"INFO: Using proxy: %@", proxy.url);
        [self addToLog:[NSString stringWithFormat:@"INFO: Using proxy: %@", proxy.url]];
    }
    else
    {
        NSLog(@"INFO: No proxy will be used");
        [self addToLog:@"INFO: No proxy will be used"];
    }
    [self updateProxyLoadStatus:NO message:nil];
    [self performSelector:[proxyDict[@"selector"] pointerValue] withObject:proxyDict[@"object"] withObject:error];
}

- (void)updateProxyLoadStatus:(BOOL)working message:(NSString *)message
{
    @try
    {
        if (working)
        {
            [currentIndicator setIndeterminate:YES];
            [currentIndicator startAnimation:nil];
            [currentProgress setStringValue:message];
        }
        else
        {
            [currentIndicator setIndeterminate:NO];
            [currentIndicator stopAnimation:nil];
            [currentProgress setStringValue:@""];
        }
    }
    @catch (NSException *e) {
        NSLog(@"NO UI: updateProxyLoadStatus:message:");
    }
}

@synthesize log_value;
@synthesize getiPlayerPath;
@end
