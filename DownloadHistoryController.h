//
//  DownloadHistoryController.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 10/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern bool runDownloads;

@interface DownloadHistoryController : NSObject {
	NSMutableArray *history;
	IBOutlet NSArrayController *historyArrayController;
	IBOutlet NSWindow *historyWindow;
	IBOutlet NSButton *cancelButton;
	IBOutlet NSButton *saveButton;
}
- (IBAction)showHistoryWindow:(id)sender;
- (IBAction)removeSelectedFromHistory:(id)sender;
- (void)readHistory:(id)sender;
- (IBAction)writeHistory:(id)sender;
- (IBAction)cancelChanges:(id)sender;
- (void)addToLog:(NSString *)logMessage;
@end
