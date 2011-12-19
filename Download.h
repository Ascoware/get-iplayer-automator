//
//  Download.h
//  
//
//  Created by Thomas Willson on 12/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Programme.h"

@interface Download : NSObject {
    NSNotificationCenter *nc;
    
	Programme *show;
    
    double lastDownloaded;
	NSDate *lastDate;
	NSMutableArray *rateEntries;
	double oldRateAverage;
	int outOfRange;
    NSMutableString *log;
}
- (void)setCurrentProgress:(NSString *)string;
- (void)setPercentage:(double)d;
- (void)cancelDownload:(id)sender;
- (void)addToLog:(NSString *)logMessage noTag:(BOOL)b;
- (void)addToLog:(NSString *)logMessage;
- (void)processFLVStreamerMessage:(NSString *)message;
@property (readonly) Programme *show;
@end
