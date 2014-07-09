//
//  LogController.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/9/14.
//
//

#import <Foundation/Foundation.h>

@interface LogController : NSObject {
   IBOutlet NSTextView *log;
   IBOutlet NSWindow *window;
   NSMutableAttributedString *log_value;
}

@property (readonly) NSWindow *window;
@property (readwrite) NSMutableAttributedString *log_value;

- (id)init;
- (IBAction)showLog:(id)sender;
- (IBAction)copyLog:(id)sender;
- (void)addToLog:(NSString *)string :(id)sender;
- (void)addToLog:(NSString *)string;

@end
