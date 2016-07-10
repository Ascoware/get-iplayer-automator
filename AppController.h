//
//  AppController.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BBCDownload.h"
#import "Series.h"
#import "ITVDownload.h"
#import "Download.h"
#import <IOKit/pwr_mgt/IOPMLib.h>
#import "NilToStringTransformer.h"
#import "EmptyToStringTransformer.h"
#import "LogController.h"
#import "GiASearch.h"
#import "GetCurrentWebpage.h"
#import "GetiPlayerArguments.h"
#import "GetiPlayerProxy.h"

@interface AppController : NSObject {
	//General
	NSString *getiPlayerPath;
	IBOutlet NSWindow *mainWindow;
	IBOutlet NSApplication *application;
   IBOutlet NSWindow *historyWindow;
   IOPMAssertionID powerAssertionID;
	
	//Update Components
	NSTask *getiPlayerUpdateTask;
	NSPipe *getiPlayerUpdatePipe;
	NSArray *getiPlayerUpdateArgs;
   NSMutableArray *typesToCache;
	BOOL didUpdate;
	BOOL runSinceChange;
   BOOL quickUpdateFailed;
   NSUInteger nextToCache;
   NSDictionary *updateURLDic;
   NSDate *lastUpdate;
	
	//Main Window: Search
	IBOutlet NSTextField *searchField;
	IBOutlet NSProgressIndicator *searchIndicator;
	IBOutlet NSArrayController *resultsController;
   IBOutlet NSTableView *searchResultsTable;
	NSMutableArray *searchResultsArray;
   GiASearch *currentSearch;
	
	//PVR
	IBOutlet NSTextField *pvrSearchField;
	IBOutlet NSProgressIndicator *pvrSearchIndicator;
	IBOutlet NSArrayController *pvrResultsController;
	IBOutlet NSArrayController *pvrQueueController;
   IBOutlet NSPanel *pvrPanel;
	NSMutableArray *pvrSearchResultsArray;
	NSMutableArray *pvrQueueArray;
   GiASearch *currentPVRSearch;
	
	//Queue
	IBOutlet NSButton *addToQueue;
	IBOutlet NSArrayController *queueController;
	IBOutlet NSButton *getNamesButton;
	NSMutableArray *queueArray;
	IBOutlet NSTableView *queueTableView;
	
	//Main Window: Status
	IBOutlet NSProgressIndicator *overallIndicator;
	IBOutlet NSProgressIndicator *currentIndicator;
	IBOutlet NSTextField *overallProgress;
	IBOutlet NSTextField *currentProgress;
	
	//Download Controller
	Download *currentDownload;
	IBOutlet NSToolbarItem *stopButton;
	IBOutlet NSToolbarItem *startButton;
	
	//Preferences
	NSMutableArray *tvFormatList;
	NSMutableArray *radioFormatList;
   NSMutableArray *itvFormatList;
	IBOutlet NSArrayController *tvFormatController;
	IBOutlet NSArrayController *radioFormatController;
   IBOutlet NSArrayController *itvFormatController;
   IBOutlet NSButton *itvTVCheckbox;
   IBOutlet NSPanel *prefsPanel;
   IBOutlet NSButton *ch4TVCheckbox;
   
	//Scheduling a Start
	IBOutlet NSPanel *scheduleWindow;
	IBOutlet NSDatePicker *datePicker;
	NSTimer *interfaceTimer;
	NSTimer *scheduleTimer;
	BOOL runScheduled;
	
   //Download Solutions
   IBOutlet NSWindow *solutionsWindow;
   IBOutlet NSArrayController *solutionsArrayController;
   IBOutlet NSTableView *solutionsTableView;
   NSDictionary *solutionsDictionary;
   
   
   //PVR list editing
   NilToStringTransformer *nilToEmptyStringTransformer;
   NilToStringTransformer *nilToAsteriskTransformer;
    
   // Format preferences
   EmptyToStringTransformer *tvFormatTransformer;
   EmptyToStringTransformer *radioFormatTransformer;
   EmptyToStringTransformer *itvFormatTransformer;
   
   //Verbose Logging
   BOOL verbose;
   IBOutlet LogController *logger;
   
   //Proxy
   GetiPlayerProxy *getiPlayerProxy;
   HTTPProxy *proxy;
}


//Update
- (void)getiPlayerUpdateFinished;
- (IBAction)updateCache:(id)sender;
- (IBAction)forceUpdate:(id)sender;
- (void)updateCacheForType:(NSString *)type;

//Search
- (IBAction)pvrSearch:(id)sender;
- (IBAction)mainSearch:(id)sender;

//PVR
- (IBAction)addToAutoRecord:(id)sender;

//Misc.
- (void)addToiTunesThread:(Programme *)show;
- (void)cleanUpPath:(Programme *)show;
- (void)seasonEpisodeInfo:(Programme *)show;
- (IBAction)chooseDownloadPath:(id)sender;
- (IBAction)restoreDefaults:(id)sender;
- (IBAction)showFeedback:(id)sender;
- (IBAction)closeWindow:(id)sender;
+ (AppController*)sharedController;

//Queue
- (IBAction)addToQueue:(id)sender;
- (IBAction)getCurrentWebpage:(id)sender;
- (void)setQueueArray:(NSArray *)queue;
- (NSArray *)queueArray;
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

//Key-Value Coding
@property (readonly) NSString *getiPlayerPath;

@end
