//
//  LogController.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/9/14.
//
//

#import <Cocoa/Cocoa.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface LogController : NSObject<DDLogFormatter>

@property IBOutlet NSTextView *log;
@property (weak) IBOutlet NSWindow *window;

- (instancetype)init;
- (IBAction)showLog:(id)sender;
- (IBAction)copyLog:(id)sender;
- (IBAction)clearLog:(id)sender;

@end
