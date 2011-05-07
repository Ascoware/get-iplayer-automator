//
//  Download.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/14/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Programme.h"
#import "TVFormat.h"
#import "RadioFormat.h"

extern bool runDownloads;

@interface Download : NSObject {
	NSNotificationCenter *nc;
	IBOutlet NSTextField *currentProgress;
	IBOutlet NSProgressIndicator *currentIndicator;
	IBOutlet NSTextField *overallProgress;
	IBOutlet NSProgressIndicator *overallIndicator;
	IBOutlet NSArrayController *queueController;
	Programme *show;
	NSString *profileDirArg;
	
	NSTask *task;
	NSPipe *pipe;
	NSPipe *errorPipe;
	NSFileHandle *fh;
	NSFileHandle *errorFh;
	
	NSMutableString *log;
	NSMutableString *errorCache;
	NSTimer *processErrorCache;
	BOOL runAgain;
	BOOL running;
	int i;
	
	BOOL foundLastLine;
	NSString *LastLine;
	NSString *reasonForFailure;
	
	double lastDownloaded;
	NSDate *lastDate;
	NSMutableArray *rateEntries;
	double oldRateAverage;
	int outOfRange;
}
- (id)initWithProgramme:(Programme *)tempShow tvFormats:(NSArray *)tvFormatList radioFormats:(NSArray *)radioFormatList;
- (void)cancelDownload:(id)sender;
- (void)addToLog:(NSString *)logMessage noTag:(BOOL)b;
- (void)addToLog:(NSString *)logMessage;
- (void)processGetiPlayerOutput:(NSString *)outp;
- (void)setCurrentProgress:(NSString *)string;
- (void)setPercentage:(double)d;
@property (readonly) Programme *show;
@end
