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
#import "NilToStringTransformer.h"
#import "EmptyToStringTransformer.h"
#import "GiASearch.h"
#import "GetiPlayerArguments.h"
#import "GetiPlayerProxy.h"

NS_ASSUME_NONNULL_BEGIN

@class Download;
@class Programme;
@class Series;
@class LogController;

extern BOOL runDownloads;
extern NSDictionary<NSString *, NSString *> *tvFormats;
extern NSDictionary<NSString *, NSString *> *stvFormats;
extern NSDictionary<NSString *, NSString *> *radioFormats;

@interface AppController : NSObject <SPUUpdaterDelegate, NSApplicationDelegate>
//General
@property (readonly, nonnull) NSString *getiPlayerPath;
@property (readonly, nonnull) NSString *perlBinaryPath;
@property (readonly, nonnull) NSString *perlEnvironmentPath;
@property (readonly, nonnull) NSString *extraBinariesPath;
@property IBOutlet NSWindow *mainWindow;
@property IBOutlet NSApplication *application;
@property IBOutlet NSWindow *historyWindow;
@property (assign) IOPMAssertionID powerAssertionID;
@property BOOL confirmedQuit;

//Update Components
@property (nullable) NSTask *getiPlayerUpdateTask;
@property (nullable) NSPipe *getiPlayerUpdatePipe;
@property NSMutableArray *typesToCache;
@property (assign) BOOL didUpdate;
@property (assign) BOOL runSinceChange;
@property (assign) NSUInteger nextToCache;
@property NSDate *lastUpdate;

//Main Window: Search
@property IBOutlet NSTextField *searchField;
@property IBOutlet NSProgressIndicator *searchIndicator;
@property IBOutlet NSArrayController *resultsController;
@property IBOutlet NSTableView *searchResultsTable;
@property NSMutableArray *searchResultsArray;
@property (nullable) GiASearch *currentSearch;

//PVR
@property IBOutlet NSTextField *pvrSearchField;
@property IBOutlet NSProgressIndicator *pvrSearchIndicator;
@property IBOutlet NSArrayController *pvrResultsController;
@property IBOutlet NSArrayController *pvrQueueController;
@property IBOutlet NSPanel *pvrPanel;
@property NSMutableArray *pvrSearchResultsArray;
@property NSMutableArray *pvrQueueArray;
@property (nullable) GiASearch *currentPVRSearch;
//Queue
@property IBOutlet NSButton *addToQueue;
@property IBOutlet NSArrayController *queueController;
@property IBOutlet NSMutableArray *queueArray;
@property IBOutlet NSTableView *queueTableView;
@property  IBOutlet NSToolbarItem *addSeriesLinkToQueueButton;

//Main Window: Status
@property IBOutlet NSProgressIndicator *currentIndicator;
@property IBOutlet NSTextField *currentProgress;

//Download Controller
@property (nullable) Download *currentDownload;
@property (nullable) IBOutlet NSToolbarItem *stopButton;
@property IBOutlet NSToolbarItem *startButton;

//Preferences
@property NSMutableArray *tvFormatList;
@property NSMutableArray *radioFormatList;
@property NSMutableArray *itvFormatList;
@property IBOutlet NSArrayController *tvFormatController;
@property IBOutlet NSArrayController *radioFormatController;

@property IBOutlet NSPanel *prefsPanel;
@property IBOutlet NSUserDefaultsController *preferences;
//Scheduling a Start
@property IBOutlet NSPanel *scheduleWindow;
@property IBOutlet NSDatePicker *datePicker;
@property (nullable) NSTimer *interfaceTimer;
@property (nullable) NSTimer *scheduleTimer;
@property BOOL runScheduled;

//Download Solutions
@property IBOutlet NSWindow *solutionsWindow;
@property IBOutlet NSArrayController *solutionsArrayController;
@property IBOutlet NSTableView *solutionsTableView;
@property NSDictionary *solutionsDictionary;

//PVR list editing
@property NilToStringTransformer *nilToEmptyStringTransformer;
@property NilToStringTransformer *nilToAsteriskTransformer;

// Format preferences
@property EmptyToStringTransformer *tvFormatTransformer;
@property EmptyToStringTransformer *radioFormatTransformer;
@property EmptyToStringTransformer *itvFormatTransformer;

//Verbose Logging
@property (assign) BOOL verbose;
@property IBOutlet LogController *logger;

//Proxy
@property GetiPlayerProxy *getiPlayerProxy;
@property HTTPProxy *proxy;

// Misc Menu Items / Buttons
@property IBOutlet NSToolbarItem *refreshCacheButton;
@property IBOutlet NSMenuItem *forceCacheUpdateMenuItem;
@property IBOutlet NSMenuItem *checkForCacheUpdateMenuItem;

//ITV Cache
@property (assign) BOOL updatingITVIndex;
@property (assign) BOOL updatingBBCIndex;
@property IBOutlet NSMenuItem *showNewProgrammesMenuItem;

//New Programmes History
@property NSWindow *newestProgrammesWindow;
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
-(void)itvUpdateFinished;

@end

NS_ASSUME_NONNULL_END
