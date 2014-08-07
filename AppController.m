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

static AppController *sharedController;
bool runDownloads=NO;
bool runUpdate=NO;
NSDictionary *tvFormats;
NSDictionary *radioFormats;

@implementation AppController
#pragma mark Overriden Methods
- (id)description
{
	return @"AppController";
}
- (id)init {
	//Initialization
	if (!(self = [super init])) return nil;
   sharedController = self;
   
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	
	//Initialize Arrays for Controllers
	searchResultsArray = [NSMutableArray array];
	pvrSearchResultsArray = [NSMutableArray array];
	pvrQueueArray = [NSMutableArray array];
	queueArray = [NSMutableArray array];
   
   //Look for Start notifications for ASS
   [nc addObserver:self selector:@selector(applescriptStartDownloads) name:@"StartDownloads" object:nil];
	
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
   // TODO: remove 4oD
   // set 4oD off by default
   defaultValues[@"Cache4oD_TV"] = @NO;
   defaultValues[@"TestProxy"] = @YES;
   defaultValues[@"ShowDownloadedInSearch"] = @YES;
	
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
		[logger addToLog:@"Installing/Updating Get_iPlayer Plugins..." :self];
		NSString *providedPath = [[NSBundle mainBundle] bundlePath];
		if ([fileManager fileExistsAtPath:pluginPath]) [fileManager removeItemAtPath:pluginPath error:NULL];
		providedPath = [providedPath stringByAppendingPathComponent:@"/Contents/Resources/plugins"];
		[fileManager copyItemAtPath:providedPath toPath:pluginPath error:nil];
	}
	
	
	//Initialize Arguments
	getiPlayerPath = [[NSString alloc] initWithString:[[NSBundle mainBundle] bundlePath]];
	getiPlayerPath = [getiPlayerPath stringByAppendingString:@"/Contents/Resources/get_iplayer.pl"];
	runScheduled=NO;
   quickUpdateFailed=NO;
   proxyDict = [[NSMutableDictionary alloc] init];
   nilToEmptyStringTransformer = [[NilToStringTransformer alloc] init];
   nilToAsteriskTransformer = [[NilToStringTransformer alloc] initWithString:@"*"];
   [NSValueTransformer setValueTransformer:nilToEmptyStringTransformer forName:@"NilToEmptyStringTransformer"];
   [NSValueTransformer setValueTransformer:nilToAsteriskTransformer forName:@"NilToAsteriskTransformer"];
   verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose"];
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
   
   //Initialize Search Results Click Actions
   [searchResultsTable setTarget:self];
   [searchResultsTable setDoubleAction:@selector(addToQueue:)];
   
   
	//Read Queue & Series-Link from File
	NSFileManager *fileManager = [NSFileManager defaultManager];
   
	NSString *folder = @"~/Library/Application Support/Get iPlayer Automator/";
	folder = [folder stringByExpandingTildeInPath];
	if ([fileManager fileExistsAtPath: folder] == NO)
	{
		[fileManager createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:nil];
	}
   
   // TODO: remove 4oD
   // disable 4oD and delete CH4 cache
   [[NSUserDefaults standardUserDefaults] setValue:@NO forKey:@"Cache4oD_TV"];
   [ch4TVCheckbox setState:NSOffState];
   [ch4TVCheckbox setEnabled:NO];
   [fileManager removeItemAtPath:[folder stringByAppendingPathComponent:@"ch4.cache"] error:nil];
   
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
   if (!tvFormats || !radioFormats) {
      [BBCDownload initFormats];
   }
   // clear obsolete formats
   NSMutableArray *tempTVFormats = [[NSMutableArray alloc] initWithArray:[tvFormatController arrangedObjects]];
   for (TVFormat *tvFormat in tempTVFormats) {
      if (!tvFormats[[tvFormat format]]) {
         [tvFormatController removeObject:tvFormat];
      }
   }
   NSMutableArray *tempRadioFormats = [[NSMutableArray alloc] initWithArray:[radioFormatController arrangedObjects]];
   for (RadioFormat *radioFormat in tempRadioFormats) {
      if (!radioFormats[[radioFormat format]]) {
         [radioFormatController removeObject:radioFormat];
      }
   }
   
   // TODO: Remove 4oD
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
		[format1 setFormat:@"Flash - HD"];
		TVFormat *format2 = [[TVFormat alloc] init];
		[format2 setFormat:@"Flash - Very High"];
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
   @try {
      [GrowlApplicationBridge setGrowlDelegate:(id<GrowlApplicationBridgeDelegate>)@""];
   }
   @catch (NSException *e) {
      NSLog(@"ERROR: Growl initialisation failed: %@: %@", [e name], [e description]);
      [logger addToLog:[NSString stringWithFormat:@"ERROR: Growl initialisation failed: %@: %@", [e name], [e description]]];
   }
   
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
   // ensure get_iplayer encodes output as UTF-8
   setenv("PERL_UNICODE", "S", 1);
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
   else if (runUpdate && ![[[NSUserDefaults standardUserDefaults] objectForKey:@"QuickCache"] boolValue])
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
		if (runUpdate && ![[[NSUserDefaults standardUserDefaults] objectForKey:@"QuickCache"] boolValue])
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
   
   [self saveAppData];
}
- (void)updater:(SUUpdater *)updater didFindValidUpdate:(SUAppcastItem *)update
{
   @try
   {
      
      [GrowlApplicationBridge notifyWithTitle:@"Update Available!"
                                  description:[NSString stringWithFormat:@"Get iPlayer Automator %@ is available.",[update displayVersionString]]
                             notificationName:@"New Version Available"
                                     iconData:nil
                                     priority:0
                                     isSticky:NO
                                 clickContext:nil];
   }
   @catch (NSException *e) {
      NSLog(@"ERROR: Growl notification failed (updater): %@: %@", [e name], [e description]);
      [logger addToLog:[NSString stringWithFormat:@"ERROR: Growl notification failed (updater): %@: %@", [e name], [e description]]];
   }
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
		if (show.successful.boolValue)
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
      
      NSString *typeArgument = [[GetiPlayerArguments sharedController] typeArgumentForCacheUpdate:YES];
      
      getiPlayerUpdateArgs = @[getiPlayerPath,cacheExpiryArg,typeArgument,@"--nopurge",[GetiPlayerArguments sharedController].profileDirArg];
      
      if (proxy && [[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue])
      {
         getiPlayerUpdateArgs = [getiPlayerUpdateArgs arrayByAddingObject:[[NSString alloc] initWithFormat:@"-p%@", [proxy url]]];
      }
      
      [logger addToLog:@"Updating Program Index Feeds...\r" :self];
      
      
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
      [logger addToLog:@"Updating Program Index Feeds from Server..." :nil];
      
      NSLog(@"DEBUG: Last cache update: %@",lastUpdate);
      
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      if (!lastUpdate || ([[NSDate date] timeIntervalSinceDate:lastUpdate] > ([[defaults objectForKey:@"CacheExpiryTime"] intValue]*3600)) || [[sender class] isEqualTo:[@"" class]])
      {
         typesToCache = [[NSMutableArray alloc] initWithCapacity:5];
         if ([[defaults objectForKey:@"CacheBBC_TV"] boolValue]) [typesToCache addObject:@"tv"];
         if ([[defaults objectForKey:@"CacheITV_TV"] boolValue]) [typesToCache addObject:@"itv"];
         if ([[defaults objectForKey:@"CacheBBC_Radio"] boolValue]) [typesToCache addObject:@"radio"];
         if ([[defaults objectForKey:@"CacheBBC_Podcasts"] boolValue]) [typesToCache addObject:@"podcast"];
         // TODO: Remove 4oD
         if ([[defaults objectForKey:@"Cache4oD_TV"] boolValue]) [typesToCache addObject:@"ch4"];
         
         NSArray *urlKeys = @[@"tv",@"itv",@"radio",@"podcast",@"ch4"];
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
   [logger addToLog:[NSString stringWithFormat:@"    Retrieving %@ index feeds.",type] :nil];
   [currentProgress setStringValue:[NSString stringWithFormat:@"Updating Program Indexes: Getting %@ index feeds from server...",type]];
   
   ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:updateURLDic[type]]];
   [request setDelegate:self];
   [request setDidFinishSelector:@selector(indexRequestFinished:)];
   [request setDidFailSelector:@selector(indexRequestFinished:)];
   [request setTimeOutSeconds:10];
   [request setNumberOfTimesToRetryOnTimeout:2];
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
			[logger addToLog:[NSString stringWithString:s] :nil];
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
         [logger addToLog:s :nil];
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
      @try
      {
         [GrowlApplicationBridge notifyWithTitle:@"Index Updated"
                                     description:@"The program index was updated."
                                notificationName:@"Index Updating Completed"
                                        iconData:nil
                                        priority:0
                                        isSticky:NO
                                    clickContext:nil];
      }
      @catch (NSException *e) {
         NSLog(@"ERROR: Growl notification failed (getiPlayerUpdateFinished): %@: %@", [e name], [e description]);
         [logger addToLog:[NSString stringWithFormat:@"ERROR: Growl notification failed (getiPlayerUpdateFinished): %@: %@", [e name], [e description]]];
      }
		[logger addToLog:@"Index Updated." :self];
      lastUpdate=[NSDate date];
	}
	else
	{
		runSinceChange=NO;
		[logger addToLog:@"Index was Up-To-Date." :self];
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
         [pipeTask setArguments:@[getiPlayerPath,[GetiPlayerArguments sharedController].profileDirArg,@"--nopurge",[GetiPlayerArguments sharedController].noWarningArg,[[GetiPlayerArguments sharedController] typeArgumentForCacheUpdate:NO],[[GetiPlayerArguments sharedController] cacheExpiryArgument:nil],[GetiPlayerArguments sharedController].standardListFormat,
                                  searchArgument]];
         NSMutableString *taskData = [[NSMutableString alloc] initWithString:@""];
         [pipeTask launch];
         while ((someData = [readHandle2 availableData]) && [someData length]) {
            [taskData appendString:[[NSString alloc] initWithData:someData
                                                         encoding:NSUTF8StringEncoding]];
         }
         NSString *string = [NSString stringWithString:taskData];
         NSArray *array = [string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
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
		[logger addToLog:@"Download(s) are still running." :self];
	}
}
- (IBAction)forceUpdate:(id)sender
{
	[self updateCache:@"force"];
}

#pragma mark Search
- (IBAction)goToSearch:(id)sender {
   [mainWindow makeKeyAndOrderFront:self];
   [mainWindow makeFirstResponder:searchField];
}
- (IBAction)mainSearch:(id)sender
{
	if([searchField.stringValue length] > 0)
	{
      [searchField setEnabled:NO];
		[searchIndicator startAnimation:nil];
      [resultsController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [resultsController.arrangedObjects count])]];
		currentSearch = [[GiASearch alloc] initWithSearchTerms:searchField.stringValue logController:logger selector:@selector(searchFinished:) withTarget:self];
	}
}
- (void)searchFinished:(NSArray *)results
{
   [searchField setEnabled:YES];
   [resultsController addObjects:results];
   [resultsController setSelectionIndexes:[NSIndexSet indexSet]];
	[searchIndicator stopAnimation:nil];
	if (![results count])
	{
		NSAlert *noneFound = [NSAlert alertWithMessageText:@"No Shows Found"
                                           defaultButton:@"OK"
                                         alternateButton:nil
                                             otherButton:nil
                               informativeTextWithFormat:@"0 shows were found for your search terms. Please check your spelling!"];
		[noneFound runModal];
	}
   currentSearch = nil;
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
	for (Programme *show in resultsController.selectedObjects)
	{
		if (![queueController.arrangedObjects containsObject:show])
		{
			if (runDownloads) show.status = @"Waiting...";
			[queueController addObject:show];
		}
	}
}
- (IBAction)getName:(id)sender
{
	for (Programme *p in queueController.selectedObjects)
	{
		[p getName];
	}
}

- (IBAction)getCurrentWebpage:(id)sender
{
   Programme *p = [GetCurrentWebpage getCurrentWebpage:logger];
   if (p) [queueController addObject:p];
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
   [self saveAppData]; //Save data in case of crash.
   [self loadProxyInBackgroundForSelector:@selector(startDownloads:proxyError:) withObject:sender];
}

- (void)startDownloads:(id)sender proxyError:(NSError *)proxyError
{
   // reset after proxy load
   @try
   {
      [stopButton setEnabled:YES];
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
		[logger addToLog:@"\rAppController: Starting Downloads" :nil];
		
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
					[show getName];
					if ([[show showName] isEqualToString:@"Unknown - Not in Cache"])
					{
						[show setComplete:@YES];
						[show setSuccessful:@NO];
						[show setStatus:@"Failed: Please set the show name"];
						[logger addToLog:@"Could not download. Please set a show name first." :self];
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
			[logger addToLog:[NSString stringWithFormat:@"\rDownloading Show %lu/%lu:\r",
                         (unsigned long)1,
                         (unsigned long)[tempQueue count]]
                       :nil];
			for (Programme *show in tempQueue)
			{
				if ([[show complete] isEqualToNumber:@NO])
				{
               if ([[show tvNetwork] hasPrefix:@"ITV"])
                  currentDownload = [[ITVDownload alloc] initWithProgramme:show itvFormats:[itvFormatController arrangedObjects] proxy:proxy logController:logger];
               /*else if ([[show tvNetwork] hasPrefix:@"4oD"])
                currentDownload = [[FourODDownload alloc] initWithProgramme:show proxy:proxy];*/
               else
                  currentDownload = [[BBCDownload alloc] initWithProgramme:show
                                                                 tvFormats:[tvFormatController arrangedObjects]
                                                              radioFormats:[radioFormatController arrangedObjects]
                                                                     proxy:proxy
                                                             logController:logger];
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
				[NSThread detachNewThreadSelector:@selector(addToiTunesThread:) toTarget:self withObject:finishedShow];
			else
				[finishedShow setValue:@"Download Complete" forKey:@"status"];
			
         @try
         {
            [GrowlApplicationBridge notifyWithTitle:@"Download Finished"
                                        description:[NSString stringWithFormat:@"%@ Completed Successfully",[finishedShow showName]]
                                   notificationName:@"Download Finished"
                                           iconData:nil
                                           priority:0
                                           isSticky:NO
                                       clickContext:nil];
         }
         @catch (NSException *e) {
            NSLog(@"ERROR: Growl notification failed (nextDownload - finished): %@: %@", [e name], [e description]);
            [logger addToLog:[NSString stringWithFormat:@"ERROR: Growl notification failed (nextDownload - finished): %@: %@", [e name], [e description]]];
         }
      }
		else
		{
         @try
         {
            [GrowlApplicationBridge notifyWithTitle:@"Download Failed"
                                        description:[NSString stringWithFormat:@"%@ failed. See log for details.",[finishedShow showName]]
                                   notificationName:@"Download Failed"
                                           iconData:nil
                                           priority:0
                                           isSticky:NO
                                       clickContext:nil];
         }
         @catch (NSException *e) {
            NSLog(@"ERROR: Growl notification failed (nextDownload - failed): %@: %@", [e name], [e description]);
            [logger addToLog:[NSString stringWithFormat:@"ERROR: Growl notification failed (nextDownload - failed): %@: %@", [e name], [e description]]];
         }
         
         ReasonForFailure *showSolution = [[ReasonForFailure alloc] init];
         [showSolution setShowName:[finishedShow showName]];
         [showSolution setSolution:solutionsDictionary[finishedShow.reasonForFailure]];
         if (![showSolution solution])
            [showSolution setSolution:@"Problem Unknown.\nPlease submit a bug report from the application menu."];
         NSLog(@"Reason for Failure: %@", [finishedShow reasonForFailure]);
         NSLog(@"Dictionary Lookup: %@", [solutionsDictionary valueForKey:[finishedShow reasonForFailure]]);
         NSLog(@"Solution: %@", [showSolution solution]);
         [solutionsArrayController addObject:showSolution];
         NSLog(@"Added Solution");
         [solutionsTableView setRowHeight:68];
		}
      
      [self saveAppData]; //Save app data in case of crash.
      
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
			[logger addToLog:[NSString stringWithFormat:@"\rDownloading Show %lu/%lu:\r",
                         (unsigned long)([tempQueue indexOfObject:nextShow]+1),
                         (unsigned long)[tempQueue count]]
                       :nil];
			if ([[nextShow complete] isEqualToNumber:@NO])
         {
            if ([[nextShow tvNetwork] hasPrefix:@"ITV"])
               currentDownload = [[ITVDownload alloc] initWithProgramme:nextShow itvFormats:[itvFormatController arrangedObjects] proxy:proxy logController:logger];
            /*else if ([[nextShow tvNetwork] hasPrefix:@"4oD"])
             currentDownload = [[FourODDownload alloc] initWithProgramme:nextShow proxy:proxy];*/
            else
               currentDownload = [[BBCDownload alloc] initWithProgramme:nextShow
                                                              tvFormats:[tvFormatController arrangedObjects]
                                                           radioFormats:[radioFormatController arrangedObjects]
                                                                  proxy:proxy
                                                          logController:logger];
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
			[logger addToLog:@"\rAppController: Downloads Finished" :nil];
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
         @try
         {
            [GrowlApplicationBridge notifyWithTitle:@"Downloads Finished"
                                        description:[NSString stringWithFormat:@"Downloads Successful = %lu\nDownload Failed = %lu",
                                                     (unsigned long)downloadsSuccessful,(unsigned long)downloadsFailed]
                                   notificationName:@"Downloads Finished"
                                           iconData:nil
                                           priority:0
                                           isSticky:NO
                                       clickContext:nil];
         }
         @catch (NSException *e) {
            NSLog(@"ERROR: Growl notification failed (nextDownload - complete): %@: %@", [e name], [e description]);
            [logger addToLog:[NSString stringWithFormat:@"ERROR: Growl notification failed (nextDownload - complete): %@: %@", [e name], [e description]]];
         }
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
	if([pvrSearchField.stringValue length])
	{
      [pvrSearchField setEnabled:NO];
      [pvrResultsController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [pvrResultsController.arrangedObjects count])]];
		currentPVRSearch = [[GiASearch alloc] initWithSearchTerms:pvrSearchField.stringValue logController:logger selector:@selector(pvrSearchFinished:) withTarget:self];
		[pvrSearchIndicator startAnimation:nil];
	}
}

- (void)pvrSearchFinished:(NSArray *)results
{
	[pvrResultsController addObjects:results];
   [pvrResultsController setSelectionIndexes:[NSIndexSet indexSet]];
	[pvrSearchIndicator stopAnimation:nil];
   [pvrSearchField setEnabled:YES];
   if (![results count])
	{
		NSAlert *noneFound = [NSAlert alertWithMessageText:@"No Shows Found"
                                           defaultButton:@"OK"
                                         alternateButton:nil
                                             otherButton:nil
                               informativeTextWithFormat:@"0 shows were found for your search terms. Please check your spelling!"];
		[noneFound runModal];
	}
   currentPVRSearch = nil;
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
		show.added = programme.timeadded;
		show.tvNetwork = programme.tvNetwork;
		show.lastFound = [NSDate date];
      
      //Check to make sure the programme isn't already in the queue before adding it.
      NSArray *queuedObjects = [pvrQueueController arrangedObjects];
      BOOL add=YES;
      for (Programme *queuedShow in queuedObjects)
      {
         if ([[show showName] isEqualToString:[queuedShow showName]] && [show tvNetwork] == [queuedShow tvNetwork])
            add=NO;
      }
      if (add)
      {
         [pvrQueueController addObject:show];
      }
	}
}
- (IBAction)addSeriesLinkToQueue:(id)sender
{
	if ([[pvrQueueController arrangedObjects] count] > 0 && !runUpdate)
	{
		if (!runDownloads)
		{
			[currentIndicator setIndeterminate:YES];
			[currentIndicator startAnimation:self];
			[startButton setEnabled:NO];
		}
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(seriesLinkFinished:) name:@"NSThreadWillExitNotification" object:nil];
		NSLog(@"About to launch Series-Link Thread");
		[NSThread detachNewThreadSelector:@selector(seriesLinkToQueueThread) toTarget:self withObject:nil];
		NSLog(@"Series-Link Thread Launched");
	}
	else if (runScheduled && !scheduleTimer)
	{
		[self performSelectorOnMainThread:@selector(startDownloads:) withObject:self waitUntilDone:NO];
	}
}
- (void)seriesLinkToQueueThread
{
   @autoreleasepool {
      NSArray *seriesLink = [pvrQueueController arrangedObjects];
      if (!runDownloads)
         [currentProgress performSelectorOnMainThread:@selector(setStringValue:) withObject:@"Updating Series Link..." waitUntilDone:YES];
      NSMutableArray *seriesToBeRemoved = [[NSMutableArray alloc] init];
      for (Series *series in seriesLink)
      {
         if (!runDownloads)
            [currentProgress performSelectorOnMainThread:@selector(setStringValue:) withObject:[NSString stringWithFormat:@"Updating Series Link - %lu/%lu - %@",(unsigned long)[seriesLink indexOfObject:series]+1,(unsigned long)[seriesLink count],[series showName]] waitUntilDone:YES];
         if ([[series showName] length] == 0) {
            [seriesToBeRemoved addObject:series];
            continue;
         } else if ([[series tvNetwork] length] == 0) {
            [series setTvNetwork:@"*"];
         }
         NSString *cacheExpiryArgument = [[GetiPlayerArguments sharedController] cacheExpiryArgument:nil];
         NSString *typeArgument = [[GetiPlayerArguments sharedController] typeArgumentForCacheUpdate:NO];
         
         NSMutableArray *autoRecordArgs = [[NSMutableArray alloc] initWithObjects:getiPlayerPath,
                                           [GetiPlayerArguments sharedController].noWarningArg,@"--nopurge",
                                           @"--listformat=<index>: <type>, ~<name> - <episode>~, <channel>, <timeadded>, <pid>,<web>",
                                           cacheExpiryArgument,
                                           typeArgument,
                                           [GetiPlayerArguments sharedController].profileDirArg,
                                           @"--hide",
                                           [self escapeSpecialCharactersInString:[series showName]],
                                           nil];
         
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
	NSArray *array = [autoRecordData2 componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	for (NSString *string in array)
	{
		if (![string isEqualToString:@"Matches:"] && ![string hasPrefix:@"INFO:"] && ![string hasPrefix:@"WARNING:"] && [string length]>0 && ![string hasPrefix:@"."] && ![string hasPrefix:@"Added:"])
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
				if (([[series2 added] integerValue] > timeadded) &&
                ([temp_tvNetwork isEqualToString:[series2 tvNetwork]] || [[[series2 tvNetwork] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@"*"] || [[series2 tvNetwork] length] == 0))
            {
               [series2 setAdded:@(timeadded)];
            }
				if (([[series2 added] integerValue] <= timeadded) &&
                ([temp_tvNetwork isEqualToString:[series2 tvNetwork]] || [[[series2 tvNetwork] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@"*"] || [[series2 tvNetwork] length] == 0))
				{
               @try {
                  oneFound=YES;
                  Programme *p = [[Programme alloc] initWithInfo:nil pid:temp_pid programmeName:temp_showName network:temp_tvNetwork logController:logger];
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


- (void)saveAppData
{
   //Save Queue & Series-Link
	NSMutableArray *tempQueue = [[NSMutableArray alloc] initWithArray:[queueController arrangedObjects]];
	NSMutableArray *tempSeries = [[NSMutableArray alloc] initWithArray:[pvrQueueController arrangedObjects]];
	NSMutableArray *temptempQueue = [[NSMutableArray alloc] initWithArray:tempQueue];
	for (Programme *show in temptempQueue)
	{
		if (([[show complete] isEqualToNumber:@YES] && [[show successful] isEqualToNumber:@YES])
          || [[show status] isEqualToString:@"Added by Series-Link"]) [tempQueue removeObject:show];
	}
	NSMutableArray *temptempSeries = [[NSMutableArray alloc] initWithArray:tempSeries];
	for (Series *series in temptempSeries)
	{
      if ([[series showName] length] == 0) {
         [tempSeries removeObject:series];
      } else if ([[series tvNetwork] length] == 0) {
         [series setTvNetwork:@"*"];
      }
      
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
   
   //Store Preferences in case of crash
   [[NSUserDefaults standardUserDefaults] synchronize];
}
- (IBAction)closeWindow:(id)sender
{
   if ([logger.window isKeyWindow]) [logger.window performClose:self];
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
   NSArray *characters = @[@"+", @"-", @"&", @"!", @"(", @")", @"{" ,@"}",
                           @"[", @"]", @"^", @"~", @"*", @"?", @":", @"\""];
   for (NSString *character in characters)
      string = [string stringByReplacingOccurrencesOfString:character withString:[NSString stringWithFormat:@"\\%@",character]];
   
   return string;
}
- (void)thirtyTwoBitModeAlert
{
   if ([[NSAlert alertWithMessageText:@"File could not be added to iTunes," defaultButton:@"Help Me!" alternateButton:@"Do nothing" otherButton:nil informativeTextWithFormat:@"This is usually fixed by running iTunes in 32-bit mode. Would you like instructions to do this?"] runModal] == NSAlertDefaultReturn)
      [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://support.apple.com/kb/TS3771"]];
}
- (void)addToiTunesThread:(Programme *)show
{
   @autoreleasepool {
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
               [track setBookmarkable:YES];
               [track setUnplayed:YES];
               [show setValue:@"Complete & in iTunes" forKey:@"status"];
            }
            else
            {
               [self performSelectorOnMainThread:@selector(addToLog:) withObject:@"iTunes did not accept file." waitUntilDone:YES];
               if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_8) { //10.8 or older
                  [self performSelectorOnMainThread:@selector(addToLog:) withObject:@"Try setting iTunes to open in 32-bit mode." waitUntilDone:YES];
                  [self performSelectorOnMainThread:@selector(thirtyTwoBitModeAlert) withObject:nil waitUntilDone:NO];
               }
               else { //Newer than 10.8. iTunes can no longer be run in 32-bit mode.
                  [self performSelectorOnMainThread:@selector(addToLog:) withObject:@"Unfortunately new versions of iTunes cannot accept this file." waitUntilDone:YES];
               }
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
- (void)applescriptStartDownloads
{
   runScheduled=YES;
   [self forceUpdate:self];
}

+ (AppController *)sharedController
{
   return sharedController;
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
                     [GetiPlayerArguments sharedController].profileDirArg,
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
   [self loadProxyInBackgroundForSelector:selector withObject:object onTarget:self];
}

- (void)loadProxyInBackgroundForSelector:(SEL)selector withObject:(id)object onTarget:(id)target
{
   [self updateProxyLoadStatus:YES message:@"Loading proxy settings..."];
   NSLog(@"INFO: Loading proxy settings...");
   [logger addToLog:@"\n\nINFO: Loading proxy settings..."];
   [proxyDict removeAllObjects];
   proxyDict[@"selector"] = [NSValue valueWithPointer:selector];
   proxyDict[@"target"] = target;
   if (object)
      proxyDict[@"object"] = object;
   proxy = nil;
   NSString *proxyOption = [[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"];
	if ([proxyOption isEqualToString:@"Custom"])
	{
      NSString *customProxy = [[NSUserDefaults standardUserDefaults] valueForKey:@"CustomProxy"];
      NSLog(@"INFO: Custom Proxy: address=[%@] length=%ld", customProxy, [customProxy length]);
      [logger addToLog:[NSString stringWithFormat:@"INFO: Custom Proxy: address=[%@] length=%ld", customProxy, [customProxy length]]];
      NSString *proxyValue = [[customProxy lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if ([proxyValue length] == 0)
      {
         NSLog(@"WARNING: Custom proxy setting was blank. No proxy will be used.");
         [logger addToLog:@"WARNING: Custom proxy setting was blank. No proxy will be used."];
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
      NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithPointer:selector],@"selector",target,@"target", nil];
      if (object){
         [userInfo addEntriesFromDictionary:@{@"object": object}];
      }
      
      ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:@"http://tom-tech.com/get_iplayer/proxy.txt"]];
      [request setUserInfo:userInfo];
      [request setDelegate:self];
      [request setDidFailSelector:@selector(providedProxyDidFinish:)];
      [request setDidFinishSelector:@selector(providedProxyDidFinish:)];
      [request setTimeOutSeconds:10];
      [request setNumberOfTimesToRetryOnTimeout:2];
      [self updateProxyLoadStatus:YES message:[NSString stringWithFormat:@"Loading provided proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]]];
      NSLog(@"INFO: Loading provided proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]);
      [logger addToLog:[NSString stringWithFormat:@"INFO: Loading provided proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]*2]];
      [request startAsynchronous];
	}
   else
   {
      NSLog(@"INFO: No proxy to load");
      [logger addToLog:@"INFO: No proxy to load"];
      [self finishProxyLoad];
   }
}

- (void)providedProxyDidFinish:(ASIHTTPRequest *)request
{
   NSData *urlData = [request responseData];
   if ([request responseStatusCode] != 200 || !urlData)
   {
      NSLog(@"WARNING: Provided proxy could not be retrieved. No proxy will be used.");
      [logger addToLog:@"WARNING: Provided proxy could not be retrieved. No proxy will be used."];
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
         [logger addToLog:@"WARNING: Provided proxy value was blank. No proxy will be used."];
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
   [logger addToLog:@"INFO: Proxy load complete."];
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
      if (!proxy.host || [proxy.host length] == 0 || [proxy.host rangeOfString:@"(null)"].location != NSNotFound)
      {
         NSLog(@"WARNING: Invalid proxy host: address=%@ length=%ld", proxy.host, [proxy.host length]);
         [logger addToLog:[NSString stringWithFormat:@"WARNING: Invalid proxy host: address=%@ length=%ld", proxy.host, [proxy.host length]]];
         if (!runScheduled)
         {
            NSAlert *alert = [NSAlert alertWithMessageText:@"Invalid proxy host.\nDownloads may fail.\nDo you wish to continue?"
                                             defaultButton:@"No"
                                           alternateButton:@"Yes"
                                               otherButton:nil
                                 informativeTextWithFormat:@"Invalid proxy host: address=[%@] length=%ld", proxy.host, [proxy.host length]];
            [alert setAlertStyle:NSCriticalAlertStyle];
            if ([alert runModal] == NSAlertDefaultReturn)
               [self cancelProxyLoad];
            else
               [self failProxyTest];
         }
         return;
      }
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
      if (proxy.port) {
         [request setProxyPort:proxy.port];
      } else {
         if ([proxy.type isEqualToString:(NSString *)kCFProxyTypeHTTPS]) {
            [request setProxyPort:443];
         } else  {
            [request setProxyPort:80];
         }
      }
      if (proxy.user) {
         [request setProxyUsername:proxy.user];
         [request setProxyPassword:proxy.password];
      }
      [self updateProxyLoadStatus:YES message:[NSString stringWithFormat:@"Testing proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]]];
      NSLog(@"INFO: Testing proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]);
      [logger addToLog:[NSString stringWithFormat:@"INFO: Testing proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]]];
      [request startAsynchronous];
   }
   else
   {
      NSLog(@"INFO: No proxy to test");
      [logger addToLog:@"INFO: No proxy to test"];
      [self finishProxyTest];
   }
}

- (void)proxyTestDidFinish:(ASIHTTPRequest *)request
{
   if ([request responseStatusCode] != 200)
   {
      NSLog(@"WARNING: Proxy failed to load test page: %@", [request url]);
      [logger addToLog:[NSString stringWithFormat:@"WARNING: Proxy failed to load test page: %@", [request url]]];
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
   [self returnFromProxyLoadWithError:[NSError errorWithDomain:@"Proxy" code:kProxyLoadFailed userInfo:@{NSLocalizedDescriptionKey: @"Proxy Test Failed"}]];
}

- (void)finishProxyTest
{
   NSLog(@"INFO: Proxy test complete.");
   [logger addToLog:@"INFO: Proxy test complete."];
   [self returnFromProxyLoadWithError:nil];
}

- (void)returnFromProxyLoadWithError:(NSError *)error
{
   if (proxy)
   {
      NSLog(@"INFO: Using proxy: %@", proxy.url);
      [logger addToLog:[NSString stringWithFormat:@"INFO: Using proxy: %@", proxy.url]];
   }
   else
   {
      NSLog(@"INFO: No proxy will be used");
      [logger addToLog:@"INFO: No proxy will be used"];
   }
   [self updateProxyLoadStatus:NO message:nil];
   [proxyDict[@"target"] performSelector:[proxyDict[@"selector"] pointerValue] withObject:proxyDict[@"object"] withObject:error];
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

#pragma mark Extended Show Information
- (IBAction)showExtendedInformationForSelectedProgramme:(id)sender {
   popover.behavior = NSPopoverBehaviorTransient;
   [logger addToLog:@"Retrieving Information." :self];
   Programme *programme = searchResultsArray[[searchResultsTable selectedRow]];
   if (programme) {
      infoView.alphaValue = 0.1;
      loadingView.alphaValue = 1.0;
      [retrievingInfoIndicator startAnimation:self];
      
      @try {
         [popover showRelativeToRect:[searchResultsTable frameOfCellAtColumn:1 row:[searchResultsTable selectedRow]] ofView:(NSView *)searchResultsTable preferredEdge:NSMaxYEdge];
      }
      @catch (NSException *exception) {
         NSLog(@"%@",[exception description]);
         NSLog(@"%@",searchResultsTable);
         return;
      }
      if (!programme.extendedMetadataRetrieved.boolValue) {
         [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(informationRetrieved:) name:@"ExtendedInfoRetrieved" object:programme];
         [programme retrieveExtendedMetadata];
         [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(timeoutTimer:) userInfo:nil repeats:NO];
      }
      else {
         [self informationRetrieved:[NSNotification notificationWithName:@"" object:programme]];
      }
   }
}
- (void)timeoutTimer:(NSTimer *)timer
{
   Programme *programme = searchResultsArray[[searchResultsTable selectedRow]];
   if (!programme.extendedMetadataRetrieved.boolValue) {
      [logger addToLog:@"Metadata Retrieval timed out" :self];
      [programme cancelMetadataRetrieval];
      loadingLabel.stringValue = @"Programme Information Retrieval Timed Out";
   }
}
- (void)informationRetrieved:(NSNotification *)note {
   Programme *programme = note.object;
   
   if (programme.successfulRetrieval.boolValue) {
      if (programme.thumbnail)
         imageView.image = programme.thumbnail;
      else
         imageView.image = nil;
      
      if (programme.seriesName)
         seriesNameField.stringValue = programme.seriesName;
      else
         seriesNameField.stringValue = @"Unable to Retrieve";
      
      if (programme.episodeName)
         episodeNameField.stringValue = programme.episodeName;
      else
         seriesNameField.stringValue = @"";
      
      if (programme.season && programme.episode)
         numbersField.stringValue = [NSString stringWithFormat:@"Series: %ld Episode: %ld",(long)programme.season,(long)programme.episode];
      else
         numbersField.stringValue = @"";
      
      if (programme.duration)
         durationField.stringValue = [NSString stringWithFormat:@"Duration: %d minutes",programme.duration.intValue];
      else
         durationField.stringValue = @"";
      
      if (programme.categories)
         categoriesField.stringValue = [NSString stringWithFormat:@"Categories: %@",programme.categories];
      else
         categoriesField.stringValue = @"";
      
      if (programme.firstBroadcast)
         firstBroadcastField.stringValue = [NSString stringWithFormat:@"First Broadcast: %@",[programme.firstBroadcast description]];
      else
         firstBroadcastField.stringValue = @"";
      
      if (programme.lastBroadcast)
         lastBroadcastField.stringValue = [NSString stringWithFormat:@"Last Broadcast: %@", [programme.lastBroadcast description]];
      else
         lastBroadcastField.stringValue = @"";
      
      if (programme.desc)
         descriptionView.string = programme.desc;
      else
         descriptionView.string = @"";
      
      if (programme.modeSizes)
         modeSizeController.content = programme.modeSizes;
      else
         modeSizeController.content = [NSDictionary dictionary];
      
      if ([programme typeDescription])
         typeField.stringValue = [NSString stringWithFormat:@"Type: %@",[programme typeDescription]];
      else
         typeField.stringValue = @"";
      
      [retrievingInfoIndicator stopAnimation:self];
      infoView.alphaValue = 1.0;
      loadingView.alphaValue = 0.0;
      [logger addToLog:@"Info Retrieved" :self];
   }
   else {
      [retrievingInfoIndicator stopAnimation:self];
      loadingLabel.stringValue = @"Info could not be retrieved.";
      [logger addToLog:@"Info could not be retrieved" :self];
   }
}

@synthesize getiPlayerPath;
@synthesize proxy;
@end
