//
//  LogController.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/9/14.
//
//

#import <Foundation/Foundation.h>

@interface LogController : NSObject

@property (nonatomic) IBOutlet NSTextView *log;
@property (nonatomic, weak) IBOutlet NSWindow *window;
@property (nonatomic) NSFileHandle *fh;

- (instancetype)init;
- (IBAction)showLog:(id)sender;
- (IBAction)copyLog:(id)sender;
- (void)addToLog:(NSString *)string :(id)sender;
- (void)addToLog:(NSString *)string;

@end
