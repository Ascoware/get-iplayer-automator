//
//  AppController.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import "BBCDownload.h"
#import "Series.h"
#import "Get iPlayer Automator-Bridging-Header.h"
#import "Download.h"
#import "NilToStringTransformer.h"
#import "EmptyToStringTransformer.h"
#import "LogController.h"
#import "GiASearch.h"
#import "GetiPlayerArguments.h"
#import "GetiPlayerProxy.h"

NS_ASSUME_NONNULL_BEGIN

extern BOOL runDownloads;
extern NSDictionary *tvFormats;
extern NSDictionary *radioFormats;

@interface AppController : NSObject <SUUpdaterDelegate, NSApplicationDelegate>
//General
@property (nonatomic, readonly) NSString *getiPlayerPath;
@property (nonatomic, readonly) NSString *perlBinaryPath;
@property (nonatomic, readonly) NSString *perlEnvironmentPath;
@property (nonatomic, readonly) NSString *extraBinariesPath;
@property (nonatomic) IBOutlet NSWindow *mainWindow;
@property (nonatomic) IBOutlet NSApplication *application;
@property (nonatomic) IBOutlet NSWindow *historyWindow;
@property (nonatomic) IOPMAssertionID powerAssertionID;

//Update Components
@property (nonatomic, nullable) NSTask *getiPlayerUpdateTask;
@property (nonatomic, nullable) NSPipe *getiPlayerUpdatePipe;
@property (nonatomic) NSMutableArray *typesToCache;
@property (nonatomic) BOOL didUpdate;
@property (nonatomic) BOOL runSinceChange;
@property (nonatomic) NSUInteger nextToCache;
@property (nonatomic) NSDictionary *updateURLDic;
@property (nonatomic) NSDate *lastUpdate;

//Main Window: Search
@property (nonatomic) IBOutlet NSTextField *searchField;
@property (nonatomic) IBOutlet NSProgressIndicator *searchIndicator;
@property (nonatomic) IBOutlet NSArrayController *resultsController;
@property (nonatomic) IBOutlet NSTableView *searchResultsTable;
@property (nonatomic) NSMutableArray *searchResultsArray;
@property (nonatomic, nullable) GiASearch *currentSearch;

//PVR
@property (nonatomic) IBOutlet NSTextField *pvrSearchField;
@property (nonatomic) IBOutlet NSProgressIndicator *pvrSearchIndicator;
@property (nonatomic) IBOutlet NSArrayController *pvrResultsController;
@property (nonatomic) IBOutlet NSArrayController *pvrQueueController;
@property (nonatomic) IBOutlet NSPanel *pvrPanel;
@property (nonatomic) NSMutableArray *pvrSearchResultsArray;
@property (nonatomic) NSMutableArray *pvrQueueArray;
@property (nonatomic, nullable) GiASearch *currentPVRSearch;
//Queue
@property (nonatomic) IBOutlet NSButton *addToQueue;
@property (nonatomic) IBOutlet NSArrayController *queueController;
@property (nonatomic) NSMutableArray *queueArray;
@property (nonatomic) IBOutlet NSTableView *queueTableView;
@property (nonatomic)  IBOutlet NSToolbarItem *addSeriesLinkToQueueButton;

//Main Window: Status
@property (nonatomic) IBOutlet NSProgressIndicator *currentIndicator;
@property (nonatomic) IBOutlet NSTextField *currentProgress;

//Download Controller
@property (nonatomic, nullable) Download *currentDownload;
@property (nonatomic, nullable) IBOutlet NSToolbarItem *stopButton;
@property (nonatomic) IBOutlet NSToolbarItem *startButton;

//Preferences
@property (nonatomic) NSMutableArray *tvFormatList;
@property (nonatomic) NSMutableArray *radioFormatList;
@property (nonatomic) NSMutableArray *itvFormatList;
@property (nonatomic) IBOutlet NSArrayController *tvFormatController;
@property (nonatomic) IBOutlet NSArrayController *radioFormatController;
@property (nonatomic) IBOutlet NSArrayController *itvFormatController;
@property (nonatomic) IBOutlet NSPanel *prefsPanel;

//Scheduling a Start
@property (nonatomic) IBOutlet NSPanel *scheduleWindow;
@property (nonatomic) IBOutlet NSDatePicker *datePicker;
@property (nonatomic) NSTimer *interfaceTimer;
@property (nonatomic, nullable) NSTimer *scheduleTimer;
@property (nonatomic) BOOL runScheduled;

//Download Solutions
@property (nonatomic) IBOutlet NSWindow *solutionsWindow;
@property (nonatomic) IBOutlet NSArrayController *solutionsArrayController;
@property (nonatomic) IBOutlet NSTableView *solutionsTableView;
@property (nonatomic) NSDictionary *solutionsDictionary;

//PVR list editing
@property (nonatomic) NilToStringTransformer *nilToEmptyStringTransformer;
@property (nonatomic) NilToStringTransformer *nilToAsteriskTransformer;

// Format preferences
@property (nonatomic) EmptyToStringTransformer *tvFormatTransformer;
@property (nonatomic) EmptyToStringTransformer *radioFormatTransformer;
@property (nonatomic) EmptyToStringTransformer *itvFormatTransformer;

//Verbose Logging
@property (nonatomic) BOOL verbose;
@property (nonatomic) IBOutlet LogController *logger;

//Proxy
@property (nonatomic) GetiPlayerProxy *getiPlayerProxy;
@property (nonatomic) HTTPProxy *proxy;

// Misc Menu Items / Buttons
@property (nonatomic) IBOutlet NSToolbarItem *refreshCacheButton;
@property (nonatomic) IBOutlet NSMenuItem *forceCacheUpdateMenuItem;
@property (nonatomic) IBOutlet NSMenuItem *checkForCacheUpdateMenuItem;

//ITV Cache
@property (nonatomic) BOOL updatingITVIndex;
@property (nonatomic) BOOL updatingBBCIndex;
@property (nonatomic) BOOL forceITVUpdateInProgress;
@property (nonatomic) IBOutlet NSMenuItem          *showNewProgrammesMenuItem;
@property (nonatomic) IBOutlet NSTextField         *itvProgressText;
@property (nonatomic) IBOutlet NSMenuItem          *forceITVUpdateMenuItem;

//New Programmes History
@property (nonatomic) NSWindow *newestProgrammesWindow;
@property IBOutlet NSProgressIndicator *itvProgressIndicator;

//Update
- (void)getiPlayerUpdateFinished;
- (IBAction)updateCache:(nullable id)sender;
- (IBAction)forceUpdate:(id)sender;

//Search
- (IBAction)pvrSearch:(id)sender;
- (IBAction)mainSearch:(id)sender;

//PVR
- (IBAction)addToAutoRecord:(id)sender;

//Misc.
- (void)addToiTunesThread:(Programme *)show;
- (IBAction)chooseDownloadPath:(id)sender;
- (IBAction)restoreDefaults:(id)sender;
- (IBAction)closeWindow:(id)sender;
+ (nonnull AppController*)sharedController;

//Queue
- (IBAction)addToQueue:(id)sender;
- (IBAction)getCurrentWebpage:(id)sender;
- (IBAction)removeFromQueue:(id)sender;

//Download Controller
- (IBAction)startDownloads:(id)sender;
- (IBAction)stopDownloads:(id)sender;

//PVR
- (IBAction)addSeriesLinkToQueue:(id)sender;
- (BOOL)processAutoRecordData:(NSString *)autoRecordData2 forSeries:(Series *)series2;
- (IBAction)hidePvrShow:(id)sender;

//Scheduling a Start
- (IBAction)showScheduleWindow:(id)sender;
- (IBAction)scheduleStart:(id)sender;
- (IBAction)cancelSchedule:(id)sender;


//Download Solutions
//- (IBAction)saveSolutionsAsText:(id)sender;

-(void)updateHistory;
-(void)updateHistoryForType:(NSString *)chanelType andProgFile:(NSString *)oldProgrammesFile andCacheFile:(NSString *)newCacheFile;
-(NSScanner *)skip:(NSScanner *)s andDelimiter:(NSString *)d andTimes:(int)times;
-(void)itvUpdateFinished;
-(int)findItemNumberFor:(NSString *)key inString:(NSString *)string;
-(NSString *)getItemNumber:(int)itemLocation fromString:(NSString *)string;

@end

NS_ASSUME_NONNULL_END
