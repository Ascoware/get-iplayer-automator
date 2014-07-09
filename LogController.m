//
//  LogController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/9/14.
//
//

#import "LogController.h"

@implementation LogController

- (id)init
{
   //Initialize Log
   NSString *version = [NSString stringWithFormat:@"%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
   NSLog(@"Get iPlayer Automator %@ Initialized.", version);
	log_value = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"Get iPlayer Automator %@ Initialized.", version]];
	[self addToLog:@"" :nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addToLogNotification:) name:@"AddToLog" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postLog:) name:@"NeedLog" object:nil];
   
   return self;
}
- (void)showLog:(id)sender
{
	[window makeKeyAndOrderFront:self];
	
	//Make sure the log scrolled to the bottom. It might not have if the Log window was not open.
	NSAttributedString *temp_log = [[NSAttributedString alloc] initWithAttributedString:[self valueForKey:@"log_value"]];
	[log scrollRangeToVisible:NSMakeRange([temp_log length], [temp_log length])];
}
- (void)postLog:(NSNotification *)note
{
	NSString *tempLog = [log string];
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc postNotification:[NSNotification notificationWithName:@"Log" object:tempLog]];
}
-(void)addToLog:(NSString *)string
{
   [self addToLog:string :nil];
}
-(void)addToLog:(NSString *)string :(id)sender {
	//Get Current Log
	NSMutableAttributedString *current_log = [[NSMutableAttributedString alloc] initWithAttributedString:log_value];
	
	//Define Return Character for Easy Use
	NSAttributedString *return_character = [[NSAttributedString alloc] initWithString:@"\r"];
	
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
	[current_log appendAttributedString:return_character];
	[current_log appendAttributedString:from_string];
	[current_log appendAttributedString:converted_string];
	
	//Make the Text White.
	[current_log addAttribute:NSForegroundColorAttributeName
                       value:[NSColor whiteColor]
                       range:NSMakeRange(0, [current_log length])];
	
	//Update the log.
	[self setValue:current_log forKey:@"log_value"];
	
	//Scroll log to bottom only if it is visible.
	if ([window isVisible]) {
		[log scrollRangeToVisible:NSMakeRange([current_log length], [current_log length])];
	}
}
- (void)addToLogNotification:(NSNotification *)note
{
	NSString *logMessage = [note userInfo][@"message"];
	[self addToLog:logMessage :[note object]];
}
- (IBAction)copyLog:(id)sender
{
	NSString *unattributedLog = [log string];
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSArray *types = @[NSStringPboardType];
	[pb declareTypes:types owner:self];
	[pb setString:unattributedLog forType:NSStringPboardType];
}
@synthesize window;
@synthesize log_value;
@end
