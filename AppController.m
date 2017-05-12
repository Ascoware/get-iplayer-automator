//
//  AppController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "AppController.h"
#import <Sparkle/Sparkle.h>
#import "HTTPProxy.h"
#import "Programme.h"
#import "Safari.h"
#import "iTunes.h"
#import "Growl.framework/Headers/GrowlApplicationBridge.h"
#import "JRFeedbackController.h"
#import "ReasonForFailure.h"
#import "Chrome.h"
#import "ASIHTTPRequest.h"
#import "GetITVListings.h"
#import "NPHistoryWindowController.h"

static AppController *sharedController;
bool runDownloads=NO;
bool runUpdate=NO;
NSDictionary *tvFormats;
NSDictionary *radioFormats;

// New ITV Cache
GetITVShows                   *newITVListing;
NPHistoryTableViewController *npHistoryTableViewController;
NewProgrammeHistory           *sharedHistoryController;

@implementation AppController
#pragma mark Overriden Methods
- (id)description
{
    return @"AppController";
}
- (instancetype)init {
    //Initialization
    if (!(self = [super init])) return nil;
    sharedController = self;
    
    sharedHistoryController = [NewProgrammeHistory sharedInstance];
    NSNotificationCenter *nc;
    nc = [NSNotificationCenter defaultCenter];
    
    //Initialize Arrays for Controllers
    _searchResultsArray = [NSMutableArray array];
    _pvrSearchResultsArray = [NSMutableArray array];
    _pvrQueueArray = [NSMutableArray array];
    _queueArray = [NSMutableArray array];
    
    //Look for Start notifications for ASS
    [nc addObserver:self selector:@selector(applescriptStartDownloads) name:@"StartDownloads" object:nil];
    
    //Register Default Preferences
    NSMutableDictionary *defaultValues = [[NSMutableDictionary alloc] init];
    
    NSString *defaultDownloadDirectory = @"~/Movies/TV Shows";
    defaultValues[@"DownloadPath"] = defaultDownloadDirectory.stringByExpandingTildeInPath;
    defaultValues[@"Proxy"] = @"None";
    defaultValues[@"CustomProxy"] = @"";
    defaultValues[@"AutoRetryFailed"] = @YES;
    defaultValues[@"AutoRetryTime"] = @"30";
    defaultValues[@"AddCompletedToiTunes"] = @YES;
    defaultValues[@"DefaultBrowser"] = @"Safari";
    defaultValues[@"CacheBBC_TV"] = @YES;
    defaultValues[@"CacheITV_TV"] = @YES;
    defaultValues[@"CacheBBC_Radio"] = @NO;
    defaultValues[@"CacheExpiryTime"] = @"4";
    defaultValues[@"Verbose"] = @NO;
    defaultValues[@"SeriesLinkStartup"] = @YES;
    defaultValues[@"DownloadSubtitles"] = @NO;
    defaultValues[@"AlwaysUseProxy"] = @NO;
    defaultValues[@"XBMC_naming"] = @NO;
    defaultValues[@"KeepSeriesFor"] = @"30";
    defaultValues[@"RemoveOldSeries"] = @NO;
    defaultValues[@"QuickCache"] = @NO;
    defaultValues[@"TagShows"] = @YES;
    defaultValues[@"BBCOne"] = @YES;
    defaultValues[@"BBCTwo"] = @YES;
    defaultValues[@"BBCThree"] = @YES;
    defaultValues[@"BBCFour"] = @YES;
    defaultValues[@"BBCAlba"] = @NO;
    defaultValues[@"S4C"] = @NO;
    defaultValues[@"CBBC"] = @NO;
    defaultValues[@"CBeebies"] = @NO;
    defaultValues[@"BBCNews"] = @NO;
    defaultValues[@"BBCParliament"] = @NO;
    defaultValues[@"Radio1"] = @YES;
    defaultValues[@"Radio2"] = @YES;
    defaultValues[@"Radio3"] = @YES;
    defaultValues[@"Radio4"] = @YES;
    defaultValues[@"Radio4Extra"] = @YES;
    defaultValues[@"Radio6Music"] = @YES;
    defaultValues[@"BBCWorldService"] = @NO;
    defaultValues[@"Radio5Live"] = @NO;
    defaultValues[@"Radio5LiveSportsExtra"] = @NO;
    defaultValues[@"Radio1Xtra"] = @NO;
    defaultValues[@"RadioAsianNetwork"] = @NO;
    defaultValues[@"ShowRegionalRadioStations"] = @NO;
    defaultValues[@"ShowLocalRadioStations"] = @NO;
    defaultValues[@"IgnoreAllTVNews"] = @YES;
    defaultValues[@"IgnoreAllRadioNews"] = @YES;
    defaultValues[@"ShowBBCTV"] = @YES;
    defaultValues[@"ShowBBCRadio"] = @YES;
    defaultValues[@"ShowITV"] = @YES;
    defaultValues[@"TestProxy"] = @YES;
    defaultValues[@"ShowDownloadedInSearch"] = @YES;
    defaultValues[@"AudioDescribedNew"] = @NO;
    defaultValues[@"SignedNew"] = @NO;
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
    defaultValues = nil;
    
    //Migrate old AudioDescribed option
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"AudioDescribed"]) {
        [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"AudioDescribedNew"];
        [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"SignedNew"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AudioDescribed"];
    }

    // remove obsolete preferences
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DefaultFormat"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AlternateFormat"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Cache4oD_TV"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CacheBBC_Podcasts"];

    //Make sure Application Support folder exists
    NSString *folder = @"~/Library/Application Support/Get iPlayer Automator/";
    folder = folder.stringByExpandingTildeInPath;
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
        [_logger addToLog:@"Installing/Updating Get_iPlayer Plugins..." :self];
        NSString *providedPath = [NSBundle mainBundle].bundlePath;
        if ([fileManager fileExistsAtPath:pluginPath]) [fileManager removeItemAtPath:pluginPath error:NULL];
        providedPath = [providedPath stringByAppendingPathComponent:@"/Contents/Resources/plugins"];
        [fileManager copyItemAtPath:providedPath toPath:pluginPath error:nil];
    }
    
    
    //Initialize Arguments
    _getiPlayerPath = [[NSString alloc] initWithString:[NSBundle mainBundle].bundlePath];
    _getiPlayerPath = [_getiPlayerPath stringByAppendingString:@"/Contents/Resources/get_iplayer.pl"];
    _runScheduled=NO;
    _quickUpdateFailed=NO;
    _nilToEmptyStringTransformer = [[NilToStringTransformer alloc] init];
    _nilToAsteriskTransformer = [[NilToStringTransformer alloc] initWithString:@"*"];
    _tvFormatTransformer = [[EmptyToStringTransformer alloc] initWithString:@"Please select..."];
    _radioFormatTransformer = [[EmptyToStringTransformer alloc] initWithString:@"Please select..."];
    _itvFormatTransformer = [[EmptyToStringTransformer alloc] initWithString:@"Please select..."];
    [NSValueTransformer setValueTransformer:_nilToEmptyStringTransformer forName:@"NilToEmptyStringTransformer"];
    [NSValueTransformer setValueTransformer:_nilToAsteriskTransformer forName:@"NilToAsteriskTransformer"];
    [NSValueTransformer setValueTransformer:_tvFormatTransformer forName:@"TVFormatTransformer"];
    [NSValueTransformer setValueTransformer:_radioFormatTransformer forName:@"RadioFormatTransformer"];
    [NSValueTransformer setValueTransformer:_itvFormatTransformer forName:@"ITVFormatTransformer"];
    _verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itvUpdateFinished) name:@"ITVUpdateFinished" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(forceITVUpdateFinished) name:@"ForceITVUpdateFinished" object:nil];
    _forceITVUpdateInProgress = NO;
    newITVListing =  [[GetITVShows alloc] init];

    
    return self;
}
#pragma mark Delegate Methods
- (void)awakeFromNib
{
    //Initialize Search Results Click Actions
    _searchResultsTable.target = self;
    _searchResultsTable.doubleAction = @selector(addToQueue:);
    
    _tvFormatList = [NSMutableArray array];
    _itvFormatList = [NSMutableArray array];
    _radioFormatList = [NSMutableArray array];
    
    //Read Queue & Series-Link from File
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *folder = @"~/Library/Application Support/Get iPlayer Automator/";
    folder = folder.stringByExpandingTildeInPath;
    if ([fileManager fileExistsAtPath: folder] == NO)
    {
        [fileManager createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:nil];
    }
    
    // remove obsolete cache files
    [fileManager removeItemAtPath:[folder stringByAppendingPathComponent:@"ch4.cache"] error:nil];
    [fileManager removeItemAtPath:[folder stringByAppendingPathComponent:@"podcast.cache"] error:nil];
    
    NSString *filename = @"Queue.automatorqueue";
    NSString *filePath = [folder stringByAppendingPathComponent:filename];
    
    NSDictionary * rootObject;
    @try
    {
        rootObject = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
        NSArray *tempQueue = [rootObject valueForKey:@"queue"];
        NSArray *tempSeries = [rootObject valueForKey:@"serieslink"];
        _lastUpdate = [rootObject valueForKey:@"lastUpdate"];
        [_queueController addObjects:tempQueue];
        [_pvrQueueController addObjects:tempSeries];
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
        [_radioFormatController addObjects:[rootObject valueForKey:@"radioFormats"]];
        [_tvFormatController addObjects:[rootObject valueForKey:@"tvFormats"]];
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
    NSMutableArray *tempTVFormats = [[NSMutableArray alloc] initWithArray:_tvFormatController.arrangedObjects];
    for (TVFormat *tvFormat in tempTVFormats) {
        if (!tvFormats[tvFormat.format]) {
            [_tvFormatController removeObject:tvFormat];
        }
    }
    NSMutableArray *tempRadioFormats = [[NSMutableArray alloc] initWithArray:_radioFormatController.arrangedObjects];
    for (RadioFormat *radioFormat in tempRadioFormats) {
        if (!radioFormats[radioFormat.format]) {
            [_radioFormatController removeObject:radioFormat];
        }
    }
    
    filename = @"ITVFormats.automator";
    filePath = [folder stringByAppendingPathComponent:filename];
    @try {
        rootObject = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
        [_itvFormatController addObjects:[rootObject valueForKey:@"itvFormats"]];
    }
    @catch (NSException *exception) {
        [fileManager removeItemAtPath:filePath error:nil];
        rootObject=nil;
    }
    
    //Adds Defaults to Type Preferences
    if ([_tvFormatController.arrangedObjects count] == 0)
    {
        TVFormat *format1 = [[TVFormat alloc] init];
        format1.format = @"Best";
        TVFormat *format2 = [[TVFormat alloc] init];
        format2.format = @"Better";
        TVFormat *format3 = [[TVFormat alloc] init];
        format3.format = @"Very Good";
        [_tvFormatController addObjects:@[format1,format2,format3]];
    }
    if ([_radioFormatController.arrangedObjects count] == 0)
    {
        RadioFormat *format1 = [[RadioFormat alloc] init];
        format1.format = @"Best";
        RadioFormat *format2 = [[RadioFormat alloc] init];
        format2.format = @"Better";
        RadioFormat *format3 = [[RadioFormat alloc] init];
        format3.format = @"Very Good";
        [_radioFormatController addObjects:@[format1,format2,format3]];
    }
    if ([_itvFormatController.arrangedObjects count] == 0)
    {
        TVFormat *format0 = [[TVFormat alloc] init];
        format0.format = @"Flash - HD";
        TVFormat *format1 = [[TVFormat alloc] init];
        format1.format = @"Flash - Very High";
        TVFormat *format2 = [[TVFormat alloc] init];
        format2.format = @"Flash - High";
        [_itvFormatController addObjects:@[format0, format1, format2]];
    }
    
    //Growl Initialization
    @try {
        [GrowlApplicationBridge setGrowlDelegate:(id<GrowlApplicationBridgeDelegate>)@""];
    }
    @catch (NSException *e) {
        NSLog(@"ERROR: Growl initialisation failed: %@: %@", e.name, e.description);
        [_logger addToLog:[NSString stringWithFormat:@"ERROR: Growl initialisation failed: %@: %@", e.name, e.description]];
    }
    
    //Remove SWFinfo
    NSString *infoPath = @"~/.swfinfo";
    infoPath = infoPath.stringByExpandingTildeInPath;
    if ([fileManager fileExistsAtPath:infoPath]) [fileManager removeItemAtPath:infoPath error:nil];
    
    [self updateCache:nil];
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
    if ([sender isEqualTo:_mainWindow])
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
    if ([note.object isEqualTo:_mainWindow]) [_application terminate:self];
}
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    //End Downloads if Running
    if (runDownloads)
        [_currentDownload cancelDownload:nil];
    
    [self saveAppData];
}

- (void)updater:(SUUpdater *)updater didFinishLoadingAppcast:(SUAppcast *)appcast
{
    NSLog(@"didFinishLoadingAppcast");
}
- (void)updater:(SUUpdater *)updater didFindValidUpdate:(SUAppcastItem *)update
{
    @try
    {
        
        [GrowlApplicationBridge notifyWithTitle:@"Update Available!"
                                    description:[NSString stringWithFormat:@"Get iPlayer Automator %@ is available.",update.displayVersionString]
                               notificationName:@"New Version Available"
                                       iconData:nil
                                       priority:0
                                       isSticky:NO
                                   clickContext:nil];
    }
    @catch (NSException *e) {
        NSLog(@"ERROR: Growl notification failed (updater): %@: %@", e.name, e.description);
        [_logger addToLog:[NSString stringWithFormat:@"ERROR: Growl notification failed (updater): %@: %@", e.name, e.description]];
    }
}
#pragma mark Cache Update
- (IBAction)updateCache:(id)sender
{
    @try
    {
        [_searchField setEnabled:NO];
        [_stopButton setEnabled:NO];
        [_startButton setEnabled:NO];
        [_pvrSearchField setEnabled:NO];
        [_addSeriesLinkToQueueButton setEnabled:NO];
        [_refreshCacheButton setEnabled:NO];
        [_forceCacheUpdateMenuItem setEnabled:NO];
        [_checkForCacheUpdateMenuItem setEnabled:NO];
        [_showNewProgrammesMenuItem setEnabled:NO];
        if (!_forceITVUpdateMenuItem.hidden)
            [_forceITVUpdateMenuItem setEnabled:NO];
    }
    @catch (NSException *e) {
        NSLog(@"NO UI: updateCache:");
    }
    if ((![[[NSUserDefaults standardUserDefaults] objectForKey:@"QuickCache"] boolValue] || _quickUpdateFailed) && [[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue])
    {
        _getiPlayerProxy = [[GetiPlayerProxy alloc] initWithLogger:_logger];
        [_getiPlayerProxy loadProxyInBackgroundForSelector:@selector(updateCache:proxyDict:) withObject:sender onTarget:self silently:_runScheduled];
    }
    else
    {
        [self updateCache:sender proxyDict:nil];
    }
}

- (void)updateCache:(id)sender proxyDict:(NSDictionary *)proxyDict
{
    _getiPlayerProxy = nil;
    // reset after proxy load
    @try
    {
        [_searchField setEnabled:YES];
        [_stopButton setEnabled:YES];
        [_startButton setEnabled:YES];
        [_pvrSearchField setEnabled:YES];
        [_addSeriesLinkToQueueButton setEnabled:YES];
        [_refreshCacheButton setEnabled:YES];
        [_forceCacheUpdateMenuItem setEnabled:YES];
        [_checkForCacheUpdateMenuItem setEnabled:YES];
        [_showNewProgrammesMenuItem setEnabled:YES];
        if (!_forceITVUpdateMenuItem.hidden)
            [_forceITVUpdateMenuItem setEnabled:YES];
    }
    @catch (NSException *e) {
        NSLog(@"NO UI: updateCache:proxyError:");
    }
    if (proxyDict && [proxyDict[@"error"] code] == kProxyLoadCancelled) {
        [_stopButton setEnabled:NO];
        return;
    }
    _runSinceChange=YES;
    runUpdate=YES;
    _didUpdate=NO;
    [_mainWindow setDocumentEdited:YES];
    
    NSArray *tempQueue = _queueController.arrangedObjects;
    for (Programme *show in tempQueue)
    {
        if (show.successful.boolValue)
        {
            [_queueController removeObject:show];
        }
    }
    
    //UI might not be loaded yet
    @try
    {
        //Update Should Be Running:
        [_currentIndicator setIndeterminate:YES];
        [_currentIndicator startAnimation:nil];
        //Shouldn't search until update is done.
        [_searchField setEnabled:NO];
        [_stopButton setEnabled:NO];
        [_startButton setEnabled:NO];
        [_searchField setEnabled:NO];
        [_addSeriesLinkToQueueButton setEnabled:NO];
        [_refreshCacheButton setEnabled:NO];
        [_forceCacheUpdateMenuItem setEnabled:NO];
        [_checkForCacheUpdateMenuItem setEnabled:NO];
        [_showNewProgrammesMenuItem setEnabled:NO];
        if (!_forceITVUpdateMenuItem.hidden)
            [_forceITVUpdateMenuItem setEnabled:NO];
    }
    @catch (NSException *e) {
        NSLog(@"NO UI");
    }
    
    if (proxyDict) {
        _proxy = proxyDict[@"proxy"];
    }
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheITV_TV"] isEqualTo:@YES])
    {
        _updatingITVIndex = true;
        [self.itvProgressIndicator startAnimation:self];
        self.itvProgressIndicator.doubleValue = 0.0;
        [self.itvProgressIndicator setHidden:false];
        [_itvProgressText setHidden:false];

        [newITVListing itvUpdateWithLogger:_logger];
    }
    
    _updatingBBCIndex = true;

    NSString *cacheExpiryArg;
    if ([[sender class] isEqualTo:[@"" class]])
    {
        cacheExpiryArg = @"-e1";
    }
    else
    {
        cacheExpiryArg = [[NSString alloc] initWithFormat:@"-e%d", ([[[NSUserDefaults standardUserDefaults] objectForKey:@"CacheExpiryTime"] intValue]*3600)];
    }
    
    NSString *typeArgument = [[GetiPlayerArguments sharedController] typeArgumentForCacheUpdate:YES andIncludeITV:NO];
    
    if (![typeArgument isEqualToString:@"--type"]) {
        
        _getiPlayerUpdateArgs = @[_getiPlayerPath,cacheExpiryArg,typeArgument,@"--nopurge",[GetiPlayerArguments sharedController].profileDirArg];
        
        if (_proxy && [[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue])
        {
            _getiPlayerUpdateArgs = [_getiPlayerUpdateArgs arrayByAddingObject:[[NSString alloc] initWithFormat:@"-p%@", _proxy.url]];
        }
        
        [_logger addToLog:@"Updating Programme Index Feeds...\r" :self];
        _currentProgress.stringValue = @"Updating Programme Index Feeds...";
        
        _getiPlayerUpdateTask = [[NSTask alloc] init];
        _getiPlayerUpdateTask.launchPath = @"/usr/bin/perl";
        _getiPlayerUpdateTask.arguments = _getiPlayerUpdateArgs;
        _getiPlayerUpdatePipe = [[NSPipe alloc] init];
        _getiPlayerUpdateTask.standardOutput = _getiPlayerUpdatePipe;
        _getiPlayerUpdateTask.standardError =_getiPlayerUpdatePipe;
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        
        [nc addObserver:self
               selector:@selector(dataReady:)
                   name:NSFileHandleReadCompletionNotification
                 object:_getiPlayerUpdatePipe.fileHandleForReading];
        [_getiPlayerUpdatePipe.fileHandleForReading readInBackgroundAndNotify];
        
        NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:_getiPlayerUpdateTask.environment];
        envVariableDictionary[@"HOME"] = (@"~").stringByExpandingTildeInPath;
        envVariableDictionary[@"PERL_UNICODE"] = @"AS";
        _updatingBBCIndex = true;
        _getiPlayerUpdateTask.environment = envVariableDictionary;
        [_getiPlayerUpdateTask launch];
    }
    else
    {
        _updatingBBCIndex = false;
        [self getiPlayerUpdateFinished];
    }
}

- (void)dataReady:(NSNotification *)n
{
    NSData *d;
    d = [[n userInfo] valueForKey:NSFileHandleNotificationDataItem];
    BOOL matches=NO;
    if (d.length > 0) {
        NSString *s = [[NSString alloc] initWithData:d
                                            encoding:NSUTF8StringEncoding];
        NSArray *lines = [s componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        for (NSString *line in lines) {
            if ([line hasPrefix:@"INFO:"])
            {
                [_logger addToLog:line];
                NSString *actualMessage = [line substringFromIndex:5];
                NSString *infoMessage = [[NSString alloc] initWithFormat:@"Updating Programme Indexes: %@", actualMessage];
                _currentProgress.stringValue = infoMessage;
            }
            else if ([line hasPrefix:@"WARNING:"] || [line hasPrefix:@"ERROR:"])
            {
                [_logger addToLog:s :nil];
            }
            else if ([line isEqualToString:@"."])
            {
                NSMutableString *infomessage = [[NSMutableString alloc] initWithFormat:@"%@.", _currentProgress.stringValue];
                if ([infomessage hasSuffix:@".........."]) [infomessage deleteCharactersInRange:NSMakeRange(infomessage.length-9, 9)];
                _currentProgress.stringValue = infomessage;
                _didUpdate = YES;
            }
            else if ([line hasPrefix:@"Matches:"])
            {
                matches=YES;
                _getiPlayerUpdateTask=nil;
                _updatingBBCIndex = false;
                [self getiPlayerUpdateFinished];
            }
        }
    }
    else
    {
        _getiPlayerUpdateTask = nil;
        _updatingBBCIndex = false;
        [self getiPlayerUpdateFinished];
    }
    
    // If the task is running, start reading again
    if (_getiPlayerUpdateTask && !matches) {
        [_getiPlayerUpdatePipe.fileHandleForReading readInBackgroundAndNotify];
    }
}
- (void)itvUpdateFinished
{
    //  ITV Cache Update Finished - turn off progress display and process data
    
    _updatingITVIndex = false;
    _didUpdate = YES;
    [self.itvProgressIndicator stopAnimation:self];
    [self.itvProgressIndicator setHidden:true];
    [_itvProgressText setHidden:true];
    [self getiPlayerUpdateFinished];
}
- (void)getiPlayerUpdateFinished
{
    if (_updatingITVIndex || _updatingBBCIndex)
        return;

    runUpdate=NO;
    [_mainWindow setDocumentEdited:NO];
    
    _getiPlayerUpdatePipe = nil;
    _getiPlayerUpdateTask = nil;
    _currentProgress.stringValue = @"";
    [_currentIndicator setIndeterminate:NO];
    [_currentIndicator stopAnimation:nil];
    [_searchField setEnabled:YES];
    [_startButton setEnabled:YES];
    [_searchField setEnabled:YES];
    [_addSeriesLinkToQueueButton setEnabled:YES];
    [_refreshCacheButton setEnabled:YES];
    [_forceCacheUpdateMenuItem setEnabled:YES];
    [_checkForCacheUpdateMenuItem setEnabled:YES];
    [_showNewProgrammesMenuItem setEnabled:YES];
    if (!_forceITVUpdateMenuItem.hidden)
        [_forceITVUpdateMenuItem setEnabled:YES];
    
    if (_didUpdate)
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
            NSLog(@"ERROR: Growl notification failed (getiPlayerUpdateFinished): %@: %@", e.name, e.description);
            [_logger addToLog:[NSString stringWithFormat:@"ERROR: Growl notification failed (getiPlayerUpdateFinished): %@: %@", e.name, e.description]];
        }
        [_logger addToLog:@"Index Updated." :self];
        _lastUpdate=[NSDate date];
        [self updateHistory];
    }
    else
    {
        _runSinceChange=NO;
        [_logger addToLog:@"Index was Up-To-Date." :self];
    }
    
    
    //Long, Complicated Bit of Code that updates the index number.
    //This is neccessary because if the cache is updated, the index number will almost certainly change.
    NSArray *tempQueue = _queueController.arrangedObjects;
    for (Programme *show in tempQueue)
    {
        BOOL foundMatch=NO;
        if (show.showName.length > 0)
        {
            NSTask *pipeTask = [[NSTask alloc] init];
            NSPipe *newPipe = [[NSPipe alloc] init];
            NSFileHandle *readHandle2 = newPipe.fileHandleForReading;
            NSData *someData;
            
            NSString *name = [show.showName copy];
            NSScanner *scanner = [NSScanner scannerWithString:name];
            NSString *searchArgument;
            [scanner scanUpToString:@" - " intoString:&searchArgument];
            // write handle is closed to this process
            pipeTask.standardOutput = newPipe;
            pipeTask.standardError = newPipe;
            pipeTask.launchPath = @"/usr/bin/perl";
            pipeTask.arguments = @[_getiPlayerPath,[GetiPlayerArguments sharedController].profileDirArg,@"--nopurge",[GetiPlayerArguments sharedController].noWarningArg,[[GetiPlayerArguments sharedController] typeArgumentForCacheUpdate:NO andIncludeITV:YES],[[GetiPlayerArguments sharedController] cacheExpiryArgument:nil],[GetiPlayerArguments sharedController].standardListFormat,
                                     searchArgument];
            NSMutableString *taskData = [[NSMutableString alloc] initWithString:@""];
            NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:pipeTask.environment];
            envVariableDictionary[@"HOME"] = (@"~").stringByExpandingTildeInPath;
            envVariableDictionary[@"PERL_UNICODE"] = @"AS";
            pipeTask.environment = envVariableDictionary;
            [pipeTask launch];
            while ((someData = readHandle2.availableData) && someData.length) {
                [taskData appendString:[[NSString alloc] initWithData:someData
                                                             encoding:NSUTF8StringEncoding]];
            }
            NSString *string = [NSString stringWithString:taskData];
            NSArray *array = [string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            for (NSString *string in array)
            {
                if (![string isEqualToString:@"Matches:"] && ![string hasPrefix:@"INFO:"] && ![string hasPrefix:@"WARNING:"]
                    && ![string hasPrefix:@"reading"]
                    && string.length >0)
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
                        p.url = url;
                        if ([temp_type isEqualToString:@"radio"]) [p setValue:@YES forKey:@"radio"];

                        if (  [p.url isEqualToString:show.url] && show.url )
                        {
                            [show setValue:p.pid forKey:@"pid"];
                            show.status = @"Available";
                            foundMatch=YES;
                            break;
                        }
                    }
                    @catch (NSException *e) {
                        NSAlert *searchException = [[NSAlert alloc] init];
                        [searchException addButtonWithTitle:@"OK"];
                        searchException.messageText = [NSString stringWithFormat:@"Invalid Output!"];
                        searchException.informativeText = @"Please check your query. Your query must not alter the output format of Get_iPlayer. (getiPlayerUpdateFinished)";
                        searchException.alertStyle = NSWarningAlertStyle;
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
                show.status = @"Processing...";
                [show getName];
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
        if (_runScheduled)
        {
            [self performSelectorOnMainThread:@selector(startDownloads:) withObject:self waitUntilDone:NO];
        }
    }
    
    //Check for Updates - Don't want to prompt the user when updates are running.
    SUUpdater *updater = [SUUpdater sharedUpdater];
    [updater checkForUpdatesInBackground];

    if (runDownloads)
    {
        [_logger addToLog:@"Download(s) are still running." :self];
    }
}
- (IBAction)forceUpdate:(id)sender
{
    [self updateCache:@"force"];
}

#pragma mark Search
- (IBAction)goToSearch:(id)sender {
    [_mainWindow makeKeyAndOrderFront:self];
    [_mainWindow makeFirstResponder:_searchField];
}
- (IBAction)mainSearch:(id)sender
{
    if((_searchField.stringValue).length > 0)
    {
        [_searchField setEnabled:NO];
        [_searchIndicator startAnimation:nil];
        [_resultsController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_resultsController.arrangedObjects count])]];
        _currentSearch = [[GiASearch alloc] initWithSearchTerms:_searchField.stringValue
                                  allowHidingOfDownloadedItems:YES
                                                 logController:_logger
                                                      selector:@selector(searchFinished:)
                                                    withTarget:self];
    }
}
- (void)searchFinished:(NSArray *)results
{
    [_searchField setEnabled:YES];
    [_resultsController addObjects:results];
    [_resultsController setSelectionIndexes:[NSIndexSet indexSet]];
    [_searchIndicator stopAnimation:nil];
    if (!results.count)
    {
        NSAlert *noneFound = [NSAlert alertWithMessageText:@"No Shows Found"
                                             defaultButton:@"OK"
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:@"0 shows were found for your search terms. Please check your spelling!"];
        [noneFound runModal];
    }
    _currentSearch = nil;
}
#pragma mark Queue
- (IBAction)addToQueue:(id)sender
{
    for (Programme *show in _resultsController.selectedObjects)
    {
        if (![_queueController.arrangedObjects containsObject:show])
        {
            if (runDownloads) show.status = @"Waiting...";
            else show.status = @"Available";
            [_queueController addObject:show];
        }
    }
}
- (IBAction)getName:(id)sender
{
    for (Programme *p in _queueController.selectedObjects)
    {
        p.status = @"Processing...";
        [p performSelectorInBackground:@selector(getName) withObject:nil];
    }
}

- (IBAction)getCurrentWebpage:(id)sender
{
    Programme *p = [GetCurrentWebpage getCurrentWebpage:_logger];
    
    if (p)  {
    
        /* don't allow duplicates */
    
        NSArray *tempQueue = _queueController.arrangedObjects;
        BOOL foundIt = false;
    
        for (Programme *show in tempQueue)
            if ( [show.pid isEqualToString:p.pid] )
                foundIt = true;
        
        if ( !foundIt )
            [_queueController addObject:p];
    }
}
- (IBAction)removeFromQueue:(id)sender
{
    //Check to make sure one of the shows isn't currently downloading.
    if (runDownloads)
    {
        BOOL downloading=NO;
        NSArray *selected = _queueController.selectedObjects;
        for (Programme *show in selected)
        {
            if (![show.status isEqualToString:@"Waiting..."] && ![show.complete isEqualToNumber:@YES])
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
            [_queueController remove:self];
        }
    }
    else
    {
        [_queueController remove:self];
    }
}
- (IBAction)hidePvrShow:(id)sender
{
    NSArray *temp_queue = _queueController.selectedObjects;
    for (Programme *show in temp_queue)
    {
        if (show.realPID && show.addedByPVR)
        {
            NSDictionary *info = @{@"Programme": show};
            [[NSNotificationCenter defaultCenter] postNotificationName:@"AddProgToHistory" object:self userInfo:info];
            [_queueController removeObject:show];
        }
    }
}
#pragma mark Download Controller
- (IBAction)startDownloads:(id)sender
{
    @try
    {
        [_stopButton setEnabled:NO];
        [_startButton setEnabled:NO];
    }
    @catch (NSException *e) {
        NSLog(@"NO UI: startDownloads:");
    }
    [self saveAppData]; //Save data in case of crash.
    _getiPlayerProxy = [[GetiPlayerProxy alloc] initWithLogger:_logger];
    [_getiPlayerProxy loadProxyInBackgroundForSelector:@selector(startDownloads:proxyDict:) withObject:sender onTarget:self silently:_runScheduled];
}

- (void)startDownloads:(id)sender proxyDict:(NSDictionary *)proxyDict
{
    _getiPlayerProxy = nil;
    // reset after proxy load
    @try
    {
        [_stopButton setEnabled:YES];
    }
    @catch (NSException *e) {
        NSLog(@"NO UI: startDownloads:proxyError:");
    }
    if (proxyDict && [proxyDict[@"error"] code] == kProxyLoadCancelled) {
        [_startButton setEnabled:YES];
        [_stopButton setEnabled:NO];
        return;
    }
    
    if (proxyDict) {
        _proxy = proxyDict[@"proxy"];
    }
    
    NSAlert *whatAnIdiot = [NSAlert alertWithMessageText:@"No Shows in Queue!"
                                           defaultButton:nil
                                         alternateButton:nil
                                             otherButton:nil
                               informativeTextWithFormat:@"Try adding shows to the queue before clicking start; "
                            @"Get iPlayer Automator needs to know what to download."];
    if ([_queueController.arrangedObjects count] > 0)
    {
        NSLog(@"Initialising Failure Dictionary");
        if (!_solutionsDictionary)
            _solutionsDictionary = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ReasonsForFailure" ofType:@"plist"]];
        NSLog(@"Failure Dictionary Ready");
        
        BOOL foundOne=NO;
        runDownloads=YES;
        _runScheduled=NO;
        [_mainWindow setDocumentEdited:YES];
        [_logger addToLog:@"\rAppController: Starting Downloads" :nil];
        
        //Clean-Up Queue
        NSArray *tempQueue = _queueController.arrangedObjects;
        for (Programme *show in tempQueue)
        {
            if ([show.successful isEqualToNumber:@NO])
            {
                if (show.processedPID.boolValue)
                {
                    show.complete = @NO;
                    show.status = @"Waiting...";
                    foundOne=YES;
                }
                else
                {
                    [show getNameSynchronous];
                    if ([show.showName isEqualToString:@"Unknown - Not in Cache"])
                    {
                        show.complete = @YES;
                        show.successful = @NO;
                        show.status = @"Failed: Please set the show name";
                        [_logger addToLog:@"Could not download. Please set a show name first." :self];
                    }
                    else
                    {
                        show.complete = @NO;
                        show.status = @"Waiting...";
                        foundOne=YES;
                    }
                }
            }
            else
            {
                [_queueController removeObject:show];
            }
        }
        if (foundOne)
        {
            //Start First Download
            IOPMAssertionCreateWithDescription(kIOPMAssertionTypePreventUserIdleSystemSleep, (CFStringRef)@"Downloading Show", (CFStringRef)@"GiA is downloading shows.", NULL, NULL, (double)0, NULL, &_powerAssertionID);
            
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            [nc addObserver:self selector:@selector(setPercentage:) name:@"setPercentage" object:nil];
            [nc addObserver:self selector:@selector(setProgress:) name:@"setCurrentProgress" object:nil];
            [nc addObserver:self selector:@selector(nextDownload:) name:@"DownloadFinished" object:nil];
            
            tempQueue = _queueController.arrangedObjects;
            [_logger addToLog:[NSString stringWithFormat:@"\rDownloading Show %lu/%lu:\r",
                              (unsigned long)1,
                              (unsigned long)tempQueue.count]
                            :nil];
            for (Programme *show in tempQueue)
            {
                if ([show.complete isEqualToNumber:@NO])
                {
                    if ([show.tvNetwork hasPrefix:@"ITV"])
                        _currentDownload = [[ITVDownload alloc] initWithProgramme:show itvFormats:_itvFormatController.arrangedObjects proxy:_proxy logController:_logger];
                    else
                        _currentDownload = [[BBCDownload alloc] initWithProgramme:show
                                                                       tvFormats:_tvFormatController.arrangedObjects
                                                                    radioFormats:_radioFormatController.arrangedObjects
                                                                           proxy:_proxy
                                                                   logController:_logger];
                    break;
                }
            }
            [_startButton setEnabled:NO];
            [_stopButton setEnabled:YES];
            
        }
        else
        {
            [whatAnIdiot runModal];
            runDownloads=NO;
            [_mainWindow setDocumentEdited:NO];
        }
    }
    else
    {
        runDownloads=NO;
        [_mainWindow setDocumentEdited:NO];
        if (!_runScheduled)
            [whatAnIdiot runModal];
        else if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"AutoRetryFailed"] boolValue])
        {
            NSDate *scheduledDate = [NSDate dateWithTimeIntervalSinceNow:60*[[[NSUserDefaults standardUserDefaults] valueForKey:@"AutoRetryTime"] doubleValue]];
            _datePicker.dateValue = scheduledDate;
            [self scheduleStart:self];
        }
        else if (_runScheduled)
            _runScheduled=NO;
    }
}
- (IBAction)stopDownloads:(id)sender
{
    IOPMAssertionRelease(_powerAssertionID);
    
    runDownloads=NO;
    _runScheduled=NO;
    [_currentDownload cancelDownload:self];
    _currentDownload.show.status = @"Cancelled";
    if (!runUpdate)
        [_startButton setEnabled:YES];
    [_stopButton setEnabled:NO];
    [_currentIndicator stopAnimation:nil];
    _currentIndicator.doubleValue = 0;
    if (!runUpdate)
    {
        _currentProgress.stringValue = @"";
        [_mainWindow setDocumentEdited:NO];
    }
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:@"setPercentage" object:nil];
    [nc removeObserver:self name:@"setCurrentProgress" object:nil];
    [nc removeObserver:self name:@"DownloadFinished" object:nil];
    
    NSArray *tempQueue = _queueController.arrangedObjects;
    for (Programme *show in tempQueue)
        if ([show.status isEqualToString:@"Waiting..."]) show.status = @"";
    
    [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(fixDownloadStatus:) userInfo:_currentDownload repeats:NO];
}
- (void)fixDownloadStatus:(NSNotification *)note
{
    if (!runDownloads)
    {
        [((Download*)note.userInfo).show setValue:@"Cancelled" forKey:@"status"];
        _currentDownload=nil;
        NSLog(@"Download should read cancelled");
    }
    else
        NSLog(@"fixDownloadStatus handler did not run because downloads appear to be running again");
}
- (void)setPercentage:(NSNotification *)note
{
    if (note.userInfo)
    {
        if (note.userInfo[@"indeterminate"]) {
            _currentIndicator.indeterminate = [note.userInfo[@"indeterminate"] boolValue];
        }
        if (note.userInfo[@"animated"]) {
            if ([note.userInfo[@"animated"] boolValue]) {
                [_currentIndicator startAnimation:nil];
            }
            else {
                [_currentIndicator stopAnimation:nil];
            }
        }
        if (note.userInfo[@"nsDouble"]) {
            NSDictionary *userInfo = note.userInfo;
            [_currentIndicator setIndeterminate:NO];
            [_currentIndicator startAnimation:nil];
            _currentIndicator.minValue = 0;
            _currentIndicator.maxValue = 100;
            _currentIndicator.doubleValue = [[userInfo valueForKey:@"nsDouble"] doubleValue];
        }
    }
    else
    {
        [_currentIndicator setIndeterminate:YES];
        [_currentIndicator startAnimation:nil];
    }
}
- (void)setProgress:(NSNotification *)note
{
    if (!runUpdate)
        _currentProgress.stringValue = [note.userInfo valueForKey:@"string"];
    if (runDownloads)
    {
        [_startButton setEnabled:NO];
        [_stopButton setEnabled:YES];
        [_mainWindow setDocumentEdited:YES];
    }
}
- (void)nextDownload:(NSNotification *)note
{
    if (runDownloads)
    {
        Programme *finishedShow = note.object;
        if (finishedShow.successful.boolValue)
        {
            [finishedShow setValue:@"Processing..." forKey:@"status"];
            if ([finishedShow.path.pathExtension isEqualToString:@"mov"])
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
                                            description:[NSString stringWithFormat:@"%@ Completed Successfully",finishedShow.showName]
                                       notificationName:@"Download Finished"
                                               iconData:nil
                                               priority:0
                                               isSticky:NO
                                           clickContext:nil];
            }
            @catch (NSException *e) {
                NSLog(@"ERROR: Growl notification failed (nextDownload - finished): %@: %@", e.name, e.description);
                [_logger addToLog:[NSString stringWithFormat:@"ERROR: Growl notification failed (nextDownload - finished): %@: %@", e.name, e.description]];
            }
        }
        else
        {
            @try
            {
                [GrowlApplicationBridge notifyWithTitle:@"Download Failed"
                                            description:[NSString stringWithFormat:@"%@ failed. See log for details.",finishedShow.showName]
                                       notificationName:@"Download Failed"
                                               iconData:nil
                                               priority:0
                                               isSticky:NO
                                           clickContext:nil];
            }
            @catch (NSException *e) {
                NSLog(@"ERROR: Growl notification failed (nextDownload - failed): %@: %@", e.name, e.description);
                [_logger addToLog:[NSString stringWithFormat:@"ERROR: Growl notification failed (nextDownload - failed): %@: %@", e.name, e.description]];
            }
            
            ReasonForFailure *showSolution = [[ReasonForFailure alloc] init];
            showSolution.showName = finishedShow.showName;
            showSolution.solution = _solutionsDictionary[finishedShow.reasonForFailure];
            if (!showSolution.solution)
                showSolution.solution = @"Problem Unknown.\nPlease submit a bug report from the application menu.";
            NSLog(@"Reason for Failure: %@", finishedShow.reasonForFailure);
            NSLog(@"Dictionary Lookup: %@", [_solutionsDictionary valueForKey:finishedShow.reasonForFailure]);
            NSLog(@"Solution: %@", showSolution.solution);
            [_solutionsArrayController addObject:showSolution];
            NSLog(@"Added Solution");
            _solutionsTableView.rowHeight = 68;
        }
        
        [self saveAppData]; //Save app data in case of crash.
        
        NSArray *tempQueue = _queueController.arrangedObjects;
        Programme *nextShow=nil;
        NSUInteger showNum=0;
        @try
        {
            for (Programme *show in tempQueue)
            {
                showNum++;
                if (!show.complete.boolValue)
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
            [_logger addToLog:[NSString stringWithFormat:@"\rDownloading Show %lu/%lu:\r",
                              (unsigned long)([tempQueue indexOfObject:nextShow]+1),
                              (unsigned long)tempQueue.count]
                            :nil];
            if ([nextShow.complete isEqualToNumber:@NO])
            {
                if ([nextShow.tvNetwork hasPrefix:@"ITV"])
                    _currentDownload = [[ITVDownload alloc] initWithProgramme:nextShow itvFormats:_itvFormatController.arrangedObjects proxy:_proxy logController:_logger];
                else
                    _currentDownload = [[BBCDownload alloc] initWithProgramme:nextShow
                                                                   tvFormats:_tvFormatController.arrangedObjects
                                                                radioFormats:_radioFormatController.arrangedObjects
                                                                       proxy:_proxy
                                                               logController:_logger];
            }
        }
        @catch (NSException *e)
        {
            //Downloads must be finished.
            IOPMAssertionRelease(_powerAssertionID);
            
            [_stopButton setEnabled:NO];
            [_startButton setEnabled:YES];
            _currentProgress.stringValue = @"";
            _currentIndicator.doubleValue = 0;
            @try {[_currentIndicator stopAnimation:nil];}
            @catch (NSException *exception) {NSLog(@"Unable to stop Animation.");}
            [_currentIndicator setIndeterminate:NO];
            [_logger addToLog:@"\rAppController: Downloads Finished" :nil];
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            [nc removeObserver:self name:@"setPercentage" object:nil];
            [nc removeObserver:self name:@"setCurrentProgress" object:nil];
            [nc removeObserver:self name:@"DownloadFinished" object:nil];
            
            runDownloads=NO;
            [_mainWindow setDocumentEdited:NO];
            
            //Growl Notification
            NSUInteger downloadsSuccessful=0, downloadsFailed=0;
            for (Programme *show in tempQueue)
            {
                if (show.successful.boolValue)
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
                NSLog(@"ERROR: Growl notification failed (nextDownload - complete): %@: %@", e.name, e.description);
                [_logger addToLog:[NSString stringWithFormat:@"ERROR: Growl notification failed (nextDownload - complete): %@: %@", e.name, e.description]];
            }
            
            [[SUUpdater sharedUpdater] checkForUpdatesInBackground];
            
            if (downloadsFailed>0)
                [_solutionsWindow makeKeyAndOrderFront:self];
            if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"AutoRetryFailed"] boolValue] && downloadsFailed>0)
            {
                NSDate *scheduledDate = [NSDate dateWithTimeIntervalSinceNow:60*[[[NSUserDefaults standardUserDefaults] valueForKey:@"AutoRetryTime"] doubleValue]];
                _datePicker.dateValue = scheduledDate;
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
    if((_pvrSearchField.stringValue).length)
    {
        [_pvrSearchField setEnabled:NO];
        [_pvrResultsController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_pvrResultsController.arrangedObjects count])]];
        _currentPVRSearch = [[GiASearch alloc] initWithSearchTerms:_pvrSearchField.stringValue
                                     allowHidingOfDownloadedItems:NO logController:_logger
                                                         selector:@selector(pvrSearchFinished:)
                                                       withTarget:self];
        [_pvrSearchIndicator startAnimation:nil];
    }
}

- (void)pvrSearchFinished:(NSArray *)results
{
    [_pvrResultsController addObjects:results];
    [_pvrResultsController setSelectionIndexes:[NSIndexSet indexSet]];
    [_pvrSearchIndicator stopAnimation:nil];
    [_pvrSearchField setEnabled:YES];
    if (!results.count)
    {
        NSAlert *noneFound = [NSAlert alertWithMessageText:@"No Shows Found"
                                             defaultButton:@"OK"
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:@"0 shows were found for your search terms. Please check your spelling!"];
        [noneFound runModal];
    }
    _currentPVRSearch = nil;
}
- (IBAction)addToAutoRecord:(id)sender
{
    NSArray *selected = [[NSArray alloc] initWithArray:_pvrResultsController.selectedObjects];
    for (Programme *programme in selected)
    {
        NSString *episodeName = [[NSString alloc] initWithString:programme.showName];
        NSScanner *scanner = [NSScanner scannerWithString:episodeName];
        NSString *tempName;
        [scanner scanUpToString:@" - " intoString:&tempName];
        Series *show = [[Series alloc] initWithShowname:tempName];
        show.added = programme.timeadded;
        show.tvNetwork = programme.tvNetwork;
        show.lastFound = [NSDate date];
        
        //Check to make sure the programme isn't already in the queue before adding it.
        NSArray *queuedObjects = _pvrQueueController.arrangedObjects;
        BOOL add=YES;
        for (Programme *queuedShow in queuedObjects)
        {
            if ([show.showName isEqualToString:queuedShow.showName] && show.tvNetwork == queuedShow.tvNetwork)
                add=NO;
        }
        if (add)
        {
            [_pvrQueueController addObject:show];
        }
    }
}
- (IBAction)addSeriesLinkToQueue:(id)sender
{
    if ([_pvrQueueController.arrangedObjects count] > 0 && !runUpdate)
    {
        if (!runDownloads)
        {
            [_currentIndicator setIndeterminate:YES];
            [_currentIndicator startAnimation:self];
            [_startButton setEnabled:NO];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(seriesLinkFinished:) name:@"NSThreadWillExitNotification" object:nil];
        NSLog(@"About to launch Series-Link Thread");
        [NSThread detachNewThreadSelector:@selector(seriesLinkToQueueThread) toTarget:self withObject:nil];
        NSLog(@"Series-Link Thread Launched");
    }
    else if (_runScheduled && !_scheduleTimer)
    {
        [self performSelectorOnMainThread:@selector(startDownloads:) withObject:self waitUntilDone:NO];
    }
}
- (void)seriesLinkToQueueThread
{
    @autoreleasepool {
        NSArray *seriesLink = _pvrQueueController.arrangedObjects;
        if (!runDownloads)
            [_currentProgress performSelectorOnMainThread:@selector(setStringValue:) withObject:@"Updating Series Link..." waitUntilDone:YES];
        NSMutableArray *seriesToBeRemoved = [[NSMutableArray alloc] init];
        for (Series *series in seriesLink)
        {
            if (!runDownloads)
                [_currentProgress performSelectorOnMainThread:@selector(setStringValue:) withObject:[NSString stringWithFormat:@"Updating Series Link - %lu/%lu - %@",(unsigned long)[seriesLink indexOfObject:series]+1,(unsigned long)seriesLink.count,series.showName] waitUntilDone:YES];
            if (series.showName.length == 0) {
                [seriesToBeRemoved addObject:series];
                continue;
            } else if (series.tvNetwork.length == 0) {
                series.tvNetwork = @"*";
            }
            NSString *cacheExpiryArgument = [[GetiPlayerArguments sharedController] cacheExpiryArgument:nil];
            NSString *typeArgument = [[GetiPlayerArguments sharedController] typeArgumentForCacheUpdate:NO andIncludeITV:YES];
            
            NSMutableArray *autoRecordArgs = [[NSMutableArray alloc] initWithObjects:_getiPlayerPath,
                                              [GetiPlayerArguments sharedController].noWarningArg,@"--nopurge",
                                              @"--listformat=<pid>: <type>, ~<name> - <episode>~, <channel>, <timeadded>, <pid>,<web>",
                                              cacheExpiryArgument,
                                              typeArgument,
                                              [GetiPlayerArguments sharedController].profileDirArg,
                                              @"--hide",
                                              [self escapeSpecialCharactersInString:series.showName],
                                              nil];
            
            NSTask *autoRecordTask = [[NSTask alloc] init];
            NSPipe *autoRecordPipe = [[NSPipe alloc] init];
            NSMutableString *autoRecordData = [[NSMutableString alloc] initWithString:@""];
            NSFileHandle *readHandle = autoRecordPipe.fileHandleForReading;
            NSData *inData = nil;
            
            autoRecordTask.launchPath = @"/usr/bin/perl";
            autoRecordTask.arguments = autoRecordArgs;
            autoRecordTask.standardOutput = autoRecordPipe;
            NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:autoRecordTask.environment];
            envVariableDictionary[@"HOME"] = (@"~").stringByExpandingTildeInPath;
            envVariableDictionary[@"PERL_UNICODE"] = @"AS";
            autoRecordTask.environment = envVariableDictionary;
            [autoRecordTask launch];
            
            while ((inData = readHandle.availableData) && inData.length) {
                NSString *tempData = [[NSString alloc] initWithData:inData encoding:NSUTF8StringEncoding];
                [autoRecordData appendString:tempData];
            }
            if (![self processAutoRecordData:[autoRecordData copy] forSeries:series])
                [seriesToBeRemoved addObject:series];
        }
        [_pvrQueueController performSelectorOnMainThread:@selector(removeObjects:) withObject:seriesToBeRemoved waitUntilDone:NO];
    }
}
- (void)seriesLinkFinished:(NSNotification *)note
{
    NSLog(@"Thread Finished Notification Received");
    if (!runDownloads)
    {
        _currentProgress.stringValue = @"";
        [_currentIndicator setIndeterminate:NO];
        [_currentIndicator stopAnimation:self];
        [_startButton setEnabled:YES];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"NSThreadWillExitNotification" object:nil];
    
    //If this is an update initiated by the scheduler, run the downloads.
    if (_runScheduled && !_scheduleTimer)
    {
        [self performSelectorOnMainThread:@selector(startDownloads:) withObject:self waitUntilDone:NO];
    }
    [self performSelectorOnMainThread:@selector(scheduleTimerForFinished:) withObject:nil waitUntilDone:NO];
    NSLog(@"Series-Link Thread Finished");
}

- (void)scheduleTimerForFinished:(id)sender
{
    [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(seriesLinkFinished2:) userInfo:_currentProgress repeats:NO];
}
- (void)seriesLinkFinished2:(NSNotification *)note
{
    NSLog(@"Second Check");
    if (!runDownloads)
    {
        _currentProgress.stringValue = @"";
        [_currentIndicator setIndeterminate:NO];
        [_currentIndicator stopAnimation:self];
        if ( !_forceITVUpdateInProgress )
            [_startButton setEnabled:YES];
    }
    NSLog(@"Definitely shouldn't show an updating series-link thing!");
}
- (BOOL)processAutoRecordData:(NSString *)autoRecordData2 forSeries:(Series *)series2
{
    BOOL oneFound=NO;
    NSArray *array = [autoRecordData2 componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *string in array)
    {
        if (![string isEqualToString:@"Matches:"] && ![string hasPrefix:@"INFO:"] && ![string hasPrefix:@"WARNING:"] && string.length>0 && ![string hasPrefix:@"."] && ![string hasPrefix:@"Added:"]
            && ![string hasPrefix:@"reading"] )
        {
            @try {
                NSScanner *myScanner = [NSScanner scannerWithString:string];
                NSArray *currentQueue = _queueController.arrangedObjects;
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
                if ((series2.added.integerValue > timeadded) &&
                    ([temp_tvNetwork isEqualToString:series2.tvNetwork] || [[series2.tvNetwork stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@"*"] || series2.tvNetwork.length == 0))
                {
                    series2.added = @(timeadded);
                }
                if ((series2.added.integerValue <= timeadded) &&
                    ([temp_tvNetwork isEqualToString:series2.tvNetwork] || [[series2.tvNetwork stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@"*"] || series2.tvNetwork.length == 0))
                {
                    @try {
                        oneFound=YES;
                        Programme *p = [[Programme alloc] initWithInfo:nil pid:temp_pid programmeName:temp_showName network:temp_tvNetwork logController:_logger];
                        p.realPID = temp_realPID;
                        p.seriesName = series_Name;
                        p.episodeName = episode_Name;
                        p.url = url;
                        if ([temp_type isEqualToString:@"radio"]) [p setValue:@YES forKey:@"radio"];
                        [p setValue:@"Added by Series-Link" forKey:@"status"];
                        p.addedByPVR = true;
                        BOOL inQueue=NO;
                        for (Programme *show in currentQueue)  {
                            if ( [show.pid isEqualToString:p.pid])
                                inQueue=YES;
                        }
                        if (!inQueue)
                        {
                            if (runDownloads) [p setValue:@"Waiting..." forKey:@"status"];
                            [_queueController performSelectorOnMainThread:@selector(addObject:) withObject:p waitUntilDone:NO];
                        }
                    }
                    @catch (NSException *e) {
                        NSAlert *queueException = [[NSAlert alloc] init];
                        [queueException addButtonWithTitle:@"OK"];
                        queueException.messageText = [NSString stringWithFormat:@"Series-Link to Queue Transfer Failed"];
                        queueException.informativeText = @"The recording queue is in an unknown state.  Please restart GiA and clear the recording queue.";
                        queueException.alertStyle = NSWarningAlertStyle;
                        [queueException runModal];
                        queueException = nil;
                    }
                }
            }
            @catch (NSException *e) {
                NSAlert *searchException = [[NSAlert alloc] init];
                [searchException addButtonWithTitle:@"OK"];
                searchException.messageText = [NSString stringWithFormat:@"Invalid Output!"];
                searchException.informativeText = @"Please check your query. Your query must not alter the output format of Get_iPlayer. (processAutoRecordData)";
                searchException.alertStyle = NSWarningAlertStyle;
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
        series2.lastFound = [NSDate date];
        return YES;
    }
    else
    {
        if (!([[NSDate date] timeIntervalSinceDate:series2.lastFound] < ([[[NSUserDefaults standardUserDefaults] valueForKey:@"KeepSeriesFor"] intValue]*86400)) && [[[NSUserDefaults standardUserDefaults] valueForKey:@"RemoveOldSeries"] boolValue])
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
    NSMutableArray *tempQueue = [[NSMutableArray alloc] initWithArray:_queueController.arrangedObjects];
    NSMutableArray *tempSeries = [[NSMutableArray alloc] initWithArray:_pvrQueueController.arrangedObjects];
    NSMutableArray *temptempQueue = [[NSMutableArray alloc] initWithArray:tempQueue];
    for (Programme *show in temptempQueue)
    {
        if (([show.complete isEqualToNumber:@YES] && [show.successful isEqualToNumber:@YES])
            || [show.status isEqualToString:@"Added by Series-Link"]
            || show.addedByPVR ) [tempQueue removeObject:show];
    }
    NSMutableArray *temptempSeries = [[NSMutableArray alloc] initWithArray:tempSeries];
    for (Series *series in temptempSeries)
    {
        if (series.showName.length == 0) {
            [tempSeries removeObject:series];
        } else if (series.tvNetwork.length == 0) {
            series.tvNetwork = @"*";
        }
        
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *folder = @"~/Library/Application Support/Get iPlayer Automator/";
    folder = folder.stringByExpandingTildeInPath;
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
    [rootObject setValue:_lastUpdate forKey:@"lastUpdate"];
    [NSKeyedArchiver archiveRootObject: rootObject toFile: filePath];
    
    filename = @"Formats.automatorqueue";
    filePath = [folder stringByAppendingPathComponent:filename];
    
    rootObject = [NSMutableDictionary dictionary];
    
    [rootObject setValue:_tvFormatController.arrangedObjects forKey:@"tvFormats"];
    [rootObject setValue:_radioFormatController.arrangedObjects forKey:@"radioFormats"];
    [NSKeyedArchiver archiveRootObject:rootObject toFile:filePath];
    
    filename = @"ITVFormats.automator";
    filePath = [folder stringByAppendingPathComponent:filename];
    rootObject = [NSMutableDictionary dictionary];
    [rootObject setValue:_itvFormatController.arrangedObjects forKey:@"itvFormats"];
    [NSKeyedArchiver archiveRootObject:rootObject toFile:filePath];
    
    //Store Preferences in case of crash
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (IBAction)closeWindow:(id)sender
{
    if ((_logger.window).keyWindow) [_logger.window performClose:self];
    else if (_historyWindow.keyWindow) [_historyWindow performClose:self];
    else if (_pvrPanel.keyWindow) [_pvrPanel performClose:self];
    else if (_prefsPanel.keyWindow) [_prefsPanel performClose:self];
    else if (_newestProgrammesWindow.keyWindow) [_newestProgrammesWindow performClose:self];
    else if (_mainWindow.keyWindow)
    {
        NSAlert *downloadAlert = [NSAlert alertWithMessageText:@"Are you sure you wish to quit?"
                                                 defaultButton:@"Yes"
                                               alternateButton:@"No"
                                                   otherButton:nil
                                     informativeTextWithFormat:@""];
        NSInteger response = [downloadAlert runModal];
        if (response == NSAlertDefaultReturn) [_mainWindow performClose:self];
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
        NSString *path = [[NSString alloc] initWithString:show.path];
        NSString *ext = path.pathExtension;
        
        [_logger performSelectorOnMainThread:@selector(addToLog:) withObject:[NSString stringWithFormat:@"Adding %@ to iTunes",show.showName] waitUntilDone:NO];
        
        iTunesApplication *iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
        
        NSArray *fileToAdd = @[[NSURL fileURLWithPath:path]];
        if (!iTunes.running) [iTunes activate];
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
                        track.name = show.episodeName;
                        track.episodeID = show.episodeName;
                        track.show = show.seriesName;
                        track.artist = show.tvNetwork;
                        if (show.season>0) track.seasonNumber = show.season;
                        if (show.episode>0) track.episodeNumber = show.episode;
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
                    [_logger performSelectorOnMainThread:@selector(addToLog:) withObject:@"iTunes did not accept file." waitUntilDone:YES];
                    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_8) { //10.8 or older
                        [_logger performSelectorOnMainThread:@selector(addToLog:) withObject:@"Try setting iTunes to open in 32-bit mode." waitUntilDone:YES];
                        [self performSelectorOnMainThread:@selector(thirtyTwoBitModeAlert) withObject:nil waitUntilDone:NO];
                    }
                    else { //Newer than 10.8. iTunes can no longer be run in 32-bit mode.
                        [_logger performSelectorOnMainThread:@selector(addToLog:) withObject:@"Unfortunately new versions of iTunes cannot accept this file." waitUntilDone:YES];
                    }
                    [show setValue:@"Complete: Not in iTunes" forKey:@"status"];
                }
            }
            else
            {
                [_logger performSelectorOnMainThread:@selector(addToLog:) withObject:@"Can't add to iTunes; incompatible format." waitUntilDone:YES];
                [_logger performSelectorOnMainThread:@selector(addToLog:) withObject:@"			iTunes Compatible Modes: Flash - High, Flash - Standard, Flash - HD, iPhone, Radio - MP3" waitUntilDone:YES];
                [show setValue:@"Download Complete" forKey:@"status"];
            }
        }
        @catch (NSException *e)
        {
            [_logger performSelectorOnMainThread:@selector(addToLog:) withObject:@"Unable to Add to iTunes" waitUntilDone:YES];
            NSLog(@"Unable %@ to iTunes",show);
            [show setValue:@"Complete, Could not add to iTunes." forKey:@"status"];
        }
    }
}
- (void)cleanUpPath:(Programme *)show
{
    
    //Process Show Name into Parts
    NSString *originalShowName, *originalEpisodeName;
    NSScanner *nameScanner = [NSScanner scannerWithString:show.showName];
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
        NSString *episodeName = show.episodeName;
        NSString *seriesName = show.seriesName;
        
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
        seasonScanner.scanLocation = 0;
        [seasonScanner scanUpToString:@" - " intoString:&show2];
        show.seriesName = show2;
    }
    @catch (NSException *e) {
        NSLog(@"Error occured while retrieving Season/Episode info");
    }
    @finally
    {
        show.episode = episode;
        show.season = season;
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
    NSArray *urls = openPanel.URLs;
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
    [sharedDefaults removeObjectForKey:@"CacheBBC_TV"];
    [sharedDefaults removeObjectForKey:@"CacheITV_TV"];
    [sharedDefaults removeObjectForKey:@"CacheBBC_Radio"];
    [sharedDefaults removeObjectForKey:@"CacheExpiryTime"];
    [sharedDefaults removeObjectForKey:@"Verbose"];
    [sharedDefaults removeObjectForKey:@"SeriesLinkStartup"];
    [sharedDefaults removeObjectForKey:@"DownloadSubtitles"];
    [sharedDefaults removeObjectForKey:@"AlwaysUseProxy"];
    [sharedDefaults removeObjectForKey:@"XBMC_naming"];
    [sharedDefaults removeObjectForKey:@"KeepSeriesFor"];
    [sharedDefaults removeObjectForKey:@"RemoveOldSeries"];
    [sharedDefaults removeObjectForKey:@"QuickCache"];
    [sharedDefaults removeObjectForKey:@"TagShows"];
    [sharedDefaults removeObjectForKey:@"BBCOne"];
    [sharedDefaults removeObjectForKey:@"BBCTwo"];
    [sharedDefaults removeObjectForKey:@"BBCThree"];
    [sharedDefaults removeObjectForKey:@"BBCFour"];
    [sharedDefaults removeObjectForKey:@"BBCAlba"];
    [sharedDefaults removeObjectForKey:@"S4C"];
    [sharedDefaults removeObjectForKey:@"CBBC"];
    [sharedDefaults removeObjectForKey:@"CBeebies"];
    [sharedDefaults removeObjectForKey:@"BBCNews"];
    [sharedDefaults removeObjectForKey:@"BBCParliament"];
    [sharedDefaults removeObjectForKey:@"Radio1"];
    [sharedDefaults removeObjectForKey:@"Radio2"];
    [sharedDefaults removeObjectForKey:@"Radio3"];
    [sharedDefaults removeObjectForKey:@"Radio4"];
    [sharedDefaults removeObjectForKey:@"Radio4Extra"];
    [sharedDefaults removeObjectForKey:@"Radio6Music"];
    [sharedDefaults removeObjectForKey:@"BBCWorldService"];
    [sharedDefaults removeObjectForKey:@"Radio5Live"];
    [sharedDefaults removeObjectForKey:@"Radio5LiveSportsExtra"];
    [sharedDefaults removeObjectForKey:@"Radio1Xtra"];
    [sharedDefaults removeObjectForKey:@"RadioAsianNetwork"];
    [sharedDefaults removeObjectForKey:@"ShowRegionalRadioStations"];
    [sharedDefaults removeObjectForKey:@"ShowLocalRadioStations"];
    [sharedDefaults removeObjectForKey:@"IgnoreAllTVNews"];
    [sharedDefaults removeObjectForKey:@"IgnoreAllRadioNews"];
    [sharedDefaults removeObjectForKey:@"ShowBBCTV"];
    [sharedDefaults removeObjectForKey:@"ShowBBCRadio"];
    [sharedDefaults removeObjectForKey:@"ShowITV"];
    [sharedDefaults removeObjectForKey:@"TestProxy"];
    [sharedDefaults removeObjectForKey:@"ShowDownloadedInSearch"];
    [sharedDefaults removeObjectForKey:@"AltCacheITV_TV"];
    [sharedDefaults removeObjectForKey:@"AudiodescribedNew"];
    [sharedDefaults removeObjectForKey:@"SignedNew"];
    [sharedDefaults removeObjectForKey:@"TomTech"];
}
- (void)applescriptStartDownloads
{
    _runScheduled=YES;
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
        [_scheduleWindow makeKeyAndOrderFront:self];
        _datePicker.dateValue = [NSDate date];
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
    [_scheduleWindow close];
}
- (IBAction)scheduleStart:(id)sender
{
    NSDate *startTime = _datePicker.dateValue;
    _scheduleTimer = [[NSTimer alloc] initWithFireDate:startTime
                                             interval:1
                                               target:self
                                             selector:@selector(runScheduledDownloads:)
                                             userInfo:nil
                                              repeats:NO];
    _interfaceTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                      target:self
                                                    selector:@selector(updateScheduleStatus:)
                                                    userInfo:nil
                                                     repeats:YES];
    if (_scheduleWindow.visible)
        [_scheduleWindow close];
    [_startButton setEnabled:NO];
    _stopButton.label = @"Cancel Timer";
    _stopButton.action = @selector(stopTimer:);
    [_stopButton setEnabled:YES];
    NSRunLoop *runLoop = [NSRunLoop mainRunLoop];
    [runLoop addTimer:_scheduleTimer forMode:NSDefaultRunLoopMode];
    _runScheduled=YES;
    [_mainWindow setDocumentEdited:YES];
}
- (void)runScheduledDownloads:(NSTimer *)theTimer
{
    [_interfaceTimer invalidate];
    [_mainWindow setDocumentEdited:NO];
    [_startButton setEnabled:YES];
    [_stopButton setEnabled:NO];
    _stopButton.label = @"Stop";
    _stopButton.action = @selector(stopDownloads:);
    _scheduleTimer=nil;
    [self forceUpdate:self];
}
- (void)updateScheduleStatus:(NSTimer *)theTimer
{
    NSDate *startTime = _scheduleTimer.fireDate;
    NSDate *currentTime = [NSDate date];
    
    unsigned int unitFlags = NSHourCalendarUnit | NSMinuteCalendarUnit | NSDayCalendarUnit | NSSecondCalendarUnit;
    NSDateComponents *conversionInfo = [[NSCalendar currentCalendar] components:unitFlags fromDate:currentTime toDate:startTime options:0];
    
    NSString *status = [NSString stringWithFormat:@"Time until Start (DD:HH:MM:SS): %02ld:%02ld:%02ld:%02ld",
                        (long)conversionInfo.day, (long)conversionInfo.hour,
                        (long)conversionInfo.minute,(long)conversionInfo.second];
    if (!runUpdate)
        _currentProgress.stringValue = status;
    [_currentIndicator setIndeterminate:YES];
    [_currentIndicator startAnimation:self];
}
- (void)stopTimer:(id)sender
{
    [_interfaceTimer invalidate];
    [_scheduleTimer invalidate];
    [_startButton setEnabled:YES];
    [_stopButton setEnabled:NO];
    _stopButton.label = @"Stop";
    _stopButton.action = @selector(stopDownloads:);
    _currentProgress.stringValue = @"";
    [_currentIndicator setIndeterminate:NO];
    [_currentIndicator stopAnimation:self];
    [_mainWindow setDocumentEdited:NO];
    _runScheduled=NO;
}

#pragma mark ITV Cache Reset
- (IBAction)forceITVUpdate:(id)sender
{
    NSAlert *downloadAlert = [NSAlert alertWithMessageText:@"Are you sure you want to reset the ITV cache?"
                                             defaultButton:@"No"
                                           alternateButton:@"Yes"
                                               otherButton:nil
                                 informativeTextWithFormat:@"This will take a few minutes to complete - do NOT abandon"];
    NSInteger response = [downloadAlert runModal];
    
    if (response == NSAlertAlternateReturn)
        [self forceITVUpdate1];
    
}

- (void)forceITVUpdate1
{    
    _forceITVUpdateInProgress = YES;
    _forceITVUpdateMenuItem.enabled = NO;
    
    [_pvrSearchField setEnabled:NO];
    [_stopButton setEnabled:NO];
    [_startButton setEnabled:NO];
    [_searchField setEnabled:NO];
    [_addSeriesLinkToQueueButton setEnabled:NO];
    [_refreshCacheButton setEnabled:NO];
    [_forceCacheUpdateMenuItem setEnabled:NO];
    [_checkForCacheUpdateMenuItem setEnabled:NO];
        
    [self.itvProgressIndicator startAnimation:self];
    self.itvProgressIndicator.doubleValue = 0.0;
    [self.itvProgressIndicator setHidden:false];
    [_itvProgressText setHidden:false];
    _updatingITVIndex=true;
    
    [newITVListing forceITVUpdateWithLogger:_logger];

}

-(void)forceITVUpdateFinished
{
    _forceITVUpdateInProgress = NO;
    _forceITVUpdateMenuItem.enabled = YES;
    
    [self itvUpdateFinished];
}

#pragma mark New Programmes History
- (IBAction)showNewProgrammesAction:(id)sender
{
    npHistoryTableViewController = [[NPHistoryTableViewController alloc]initWithWindowNibName:@"NPHistoryWindow"];
    [npHistoryTableViewController showWindow:self];
    _newestProgrammesWindow = npHistoryTableViewController.window;
}

-(void)updateHistory
{

    NSArray *files = @[@"tv", @"radio", @"itv"];
    NSArray *types = @[@"BBC TV", @"BBC Radio", @"ITV"];
    BOOL active[] = {false, false, false};
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_TV"] boolValue])
        active[0]=true;

    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_Radio"] boolValue])
        active[1]=true;
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheITV_TV"] boolValue])
        active[2]=true;
             
    NSString *filePath = @"~/Library/Application Support/Get iPlayer Automator";
    filePath= filePath.stringByExpandingTildeInPath;
    
    for (int i = 0; i < types.count; i++ )
    {
        NSString *oldProgrammesFile = [filePath stringByAppendingFormat:@"/%@.gia", files[i]];
        NSString *newCacheFile = [filePath stringByAppendingFormat:@"/%@.cache", files[i]];
        
        if (active[i])
            [self updateHistoryForType:types[i] andProgFile:oldProgrammesFile andCacheFile:newCacheFile];
    }
    
    [sharedHistoryController flushHistoryToDisk];
}

-(void)updateHistoryForType:(NSString *)networkName andProgFile:(NSString *)oldProgrammesFile andCacheFile:(NSString *)newCacheFile
{
    /* Load old Programmes file */

    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL firstTimeBuild;
    
    if ( [fileManager fileExistsAtPath:newCacheFile] && ![fileManager fileExistsAtPath:oldProgrammesFile] )
        firstTimeBuild = true;
    else
        firstTimeBuild = false;
    
    NSMutableArray *oldProgrammesArray = [NSKeyedUnarchiver unarchiveObjectWithFile:oldProgrammesFile];
   
    if ( oldProgrammesArray == nil )
        oldProgrammesArray = [[NSMutableArray alloc]init];

    /* Load in todays shows cached by get_iplayer or getITVListings and create a dictionary of show names */
    
    NSError *error;
    NSString *newCacheString = [NSString stringWithContentsOfFile:newCacheFile encoding:NSUTF8StringEncoding error:&error];
    NSArray  *newCacheArray  = [newCacheString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    NSMutableSet *todayProgrammes = [[NSMutableSet alloc]init];
    NSString *entry;
    NSString *programmeName;
    NSString  *channel;
    
    BOOL firstEntry = true;
    
    int programmeNameLocation = 0;
    int channelLocation = 0;
    
    for (entry in newCacheArray)
    {
        if (firstEntry )  {
            firstEntry = false;
            programmeNameLocation = [self findItemNumberFor:@"name" inString:entry];
            channelLocation = [self findItemNumberFor:@"channel" inString:entry];
            
            if (programmeNameLocation == 0 || channelLocation == 0)
            {
                NSLog(@"ERROR: Cannot update new programmes history from cache file: %@", newCacheFile);
                [_logger addToLog:[NSString stringWithFormat:@"ERROR: Cannot update new programmes history from cache file: %@", newCacheFile]];
                return;
            }
            continue;
        }
        
        programmeName = [self getItemNumber:programmeNameLocation fromString:entry];
        channel = [self getItemNumber:channelLocation fromString:entry];
        
        if ( programmeName.length == 0 || channel.length == 0)
            continue;
        
        ProgrammeHistoryObject *p = [[ProgrammeHistoryObject alloc]initWithName:programmeName andTVChannel:channel andDateFound:@"" andSortKey:0 andNetworkName:networkName];
        [todayProgrammes addObject:p];
    }
    
    /* Put back today's programmes for comparison on the next run */
    
    NSArray *cfProgrammes = todayProgrammes.allObjects;
    [NSKeyedArchiver archiveRootObject:cfProgrammes toFile:oldProgrammesFile];
    
    /* subtract bought forward from today to create new programmes list */
    
    NSSet *oldProgrammeSet  = [NSSet setWithArray:oldProgrammesArray];
    [todayProgrammes minusSet:oldProgrammeSet];
    NSArray *newProgrammesArray = todayProgrammes.allObjects;

    /* and update history file with new programmes */
    
    if ( !firstTimeBuild )
        for ( ProgrammeHistoryObject *p in newProgrammesArray )
            [sharedHistoryController addToNewProgrammeHistory:p.programmeName andTVChannel:p.tvChannel andNetworkName:networkName];


}
-(NSString *)getItemNumber:(int)itemLocation fromString:(NSString *)string
{
    NSString *theItem;
    NSScanner *scanner = [NSScanner scannerWithString:string];
    
    scanner = [self skip:scanner andDelimiter:@"|" andTimes:itemLocation];
    [scanner scanUpToString:@"|" intoString:&theItem];
    
    return theItem;
}

-(int)findItemNumberFor:(NSString *)key inString:(NSString *)string
{
    NSString *theItem;
    NSScanner *scanner = [NSScanner scannerWithString:string];
    
    for (int itemNumber = 1; [scanner scanUpToString:@"|" intoString:&theItem]; itemNumber++ )
    {
        if ( [theItem isEqualToString:key] )
            return itemNumber;
        
        [scanner scanString:@"|"  intoString:nil];
    }
    return false;
}

-(NSScanner *) skip:(NSScanner *)s andDelimiter:(NSString *)d andTimes:(int)times
{
    if (--times < 0)
        return s;
    
    do
    {
        [s scanUpToString:d intoString:nil];
        [s scanString:d intoString:nil];
        
    } while (--times > 0);
    
    return s;
}

-(IBAction)changeNewProgrmmeDisplayFilter:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NewProgrammeDisplayFilterChanged" object:nil];
}

#pragma mark Properties

@end
