//
//  LogController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/9/14.
//
//

#import "LogController.h"

@implementation LogController

- (instancetype)init
{
    //Initialize Log
    if (self = [super init]) {
        DDFileLogger *fileLogger = [DDFileLogger new];
        fileLogger.rollingFrequency = 60 * 60 * 24;
        fileLogger.logFileManager.maximumNumberOfLogFiles = 1;
        fileLogger.logFormatter = self;
        [DDLog addLogger:fileLogger];
        [DDLog addLogger:[DDOSLogger new]];
        NSString *version = [NSString stringWithFormat:@"%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
        DDLogInfo(@"Get iPlayer Automator %@ Initialized.", version);
    }
    return self;
}

-(void)awakeFromNib {
    _log.textColor = [NSColor whiteColor];
    _log.font = [NSFont userFixedPitchFontOfSize:12.0];
}

- (void)showLog:(id)sender
{
	[_window makeKeyAndOrderFront:self];
    [_log scrollToEndOfDocument:self];
}

- (IBAction)copyLog:(id)sender
{
	NSString *unattributedLog = _log.string;
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSArray *types = @[NSPasteboardTypeString];
	[pb declareTypes:types owner:self];
    [pb setString:unattributedLog forType:NSPasteboardTypeString];
}

- (IBAction)clearLog:(id)sender
{
    self.log.string = @"";
}

- (nullable NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // In normal mode don't dump debug or verbose messages to the console.
        BOOL verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose"];
        if (!verbose && ((logMessage.flag == DDLogFlagDebug) || (logMessage.flag == DDLogFlagVerbose))) {
            return;
        }

        NSString *messageWithNewline = [logMessage.message stringByAppendingString:@"\r"];
        NSMutableAttributedString *newMessage = [[NSMutableAttributedString alloc] initWithString:messageWithNewline];

        NSColor *textColor = self.log.textColor;

        switch (logMessage.flag) {
            case DDLogFlagWarning:
                textColor = [NSColor yellowColor];
                break;
            case DDLogFlagError:
                textColor = [NSColor redColor];
                break;
            case DDLogFlagDebug:
                textColor = [NSColor lightGrayColor];
                break;
            case DDLogFlagVerbose:
                textColor = [NSColor grayColor];
                break;
            default:
                // use base color.
                break;
        }

        [newMessage addAttribute:NSForegroundColorAttributeName
                           value:textColor
                           range:NSMakeRange(0, newMessage.length)];

        [newMessage addAttribute:NSFontAttributeName
                           value:self.log.font
                           range:NSMakeRange(0, newMessage.length)];

        [self.log.textStorage appendAttributedString:newMessage];

        //Scroll log to bottom only if it is visible.
        if (self.window.visible) {
            BOOL shouldAutoScroll = ((int)NSMaxY([self.log bounds]) == (int)NSMaxY([self.log visibleRect]));
            if (shouldAutoScroll) {
                [self.log scrollToEndOfDocument:nil];
            }
        }
    });

    return [logMessage message];
}

@end


