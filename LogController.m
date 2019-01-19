//
//  LogController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/9/14.
//
//

#import "LogController.h"
#import "NSFileManager+DirectoryLocations.h"

@implementation LogController

- (instancetype)init
{
    //Initialize Log
    if (self = [super init]) {
        NSString *version = [NSString stringWithFormat:@"%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
        NSLog(@"Get iPlayer Automator %@ Initialized.", version);
        NSString *initialLog = [NSString stringWithFormat:@"Get iPlayer Automator %@ Initialized.", version];
        [self addToLog:initialLog :nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addToLogNotification:) name:@"AddToLog" object:nil];
        NSString *filePath = [[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingPathComponent:@"log.txt"];

        [[NSFileManager defaultManager] createFileAtPath:filePath
                                                contents:nil
                                              attributes:nil];
        _fh = [NSFileHandle fileHandleForWritingAtPath:filePath];
        [_fh seekToEndOfFile];
    }
    return self;
}

-(void)awakeFromNib {
    _log.textColor = [NSColor whiteColor];
    _log.font = [NSFont fontWithName:@"Monaco" size:12];
}

- (void)showLog:(id)sender
{
	[_window makeKeyAndOrderFront:self];
    [_log scrollToEndOfDocument:self];
}

-(void)addToLog:(NSString *)string
{
   [self addToLog:string :nil];
}

-(void)addToLog:(NSString *)string :(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableAttributedString *current_log = [[NSMutableAttributedString alloc] init];

        //Define Return Character for Easy Use
        NSAttributedString *return_character = [[NSAttributedString alloc] initWithString:@"\n"];
        
        //Initialize Sender Prefix
        NSAttributedString *from_string;
        if (sender != nil)
        {
            from_string = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@: ", [sender description]]];
        }
        else
        {
            from_string = [[NSAttributedString alloc] initWithString:@""];
        }
        
        //Convert String to Attributed String
        NSAttributedString *converted_string = [[NSAttributedString alloc] initWithString:string];
        
        //Append the new items to the log.
        [current_log appendAttributedString:from_string];
        [current_log appendAttributedString:converted_string];
        [current_log appendAttributedString:return_character];

        //Make the Text White.
        [current_log addAttribute:NSForegroundColorAttributeName
                            value:[NSColor whiteColor]
                            range:NSMakeRange(0, current_log.length)];
        
        NSFont *logFont =  [NSFont fontWithName:@"Monaco" size:12.0];
        [current_log addAttribute:NSFontAttributeName
                            value:logFont
                            range:NSMakeRange(0, current_log.length)];
        
        [self.log.textStorage appendAttributedString:current_log];

        //Scroll log to bottom only if it is visible.
        if (self.window.visible) {
            BOOL shouldAutoScroll = ((int)NSMaxY([self.log bounds]) == (int)NSMaxY([self.log visibleRect]));
            if (shouldAutoScroll) {
                [self.log scrollToEndOfDocument:nil];
            }
        }
        
        //Write log out to file.
        [self.fh writeData:[return_character.string dataUsingEncoding:NSUTF8StringEncoding]];
        [self.fh writeData:[from_string.string dataUsingEncoding:NSUTF8StringEncoding]];
        [self.fh writeData:[string dataUsingEncoding:NSUTF8StringEncoding]];
    });
}
- (void)addToLogNotification:(NSNotification *)note
{
	NSString *logMessage = note.userInfo[@"message"];
	[self addToLog:logMessage :note.object];
}
- (IBAction)copyLog:(id)sender
{
	NSString *unattributedLog = _log.string;
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSArray *types = @[NSStringPboardType];
	[pb declareTypes:types owner:self];
	[pb setString:unattributedLog forType:NSStringPboardType];
}

- (void)dealloc
{
   [_fh closeFile];
}

@end
