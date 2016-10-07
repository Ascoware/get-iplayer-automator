//
//  DownloadHistoryController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 10/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "DownloadHistoryController.h"
#import "DownloadHistoryEntry.h"
#import "Programme.h"


@implementation DownloadHistoryController
- (id)init
{
	if (!(self = [super init])) return nil;
	[self readHistory:self];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addToHistory:) name:@"AddProgToHistory" object:nil];
	return self;
}
- (void)readHistory:(id)sender
{
	NSLog(@"Read History");
	if ([[historyArrayController arrangedObjects] count] > 0)
		[historyArrayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[historyArrayController arrangedObjects] count])]];
	
	NSString *historyFilePath = @"~/Library/Application Support/Get iPlayer Automator/download_history";
	NSFileHandle *historyFile = [NSFileHandle fileHandleForReadingAtPath:[historyFilePath stringByExpandingTildeInPath]];
	NSData *historyFileData = [historyFile readDataToEndOfFile];
	NSString *historyFileInfo = [[NSString alloc] initWithData:historyFileData encoding:NSUTF8StringEncoding];
	
	if ([historyFileInfo length] > 0)
	{
		NSString *string = [NSString stringWithString:historyFileInfo];
		NSUInteger length = [string length];
		NSUInteger paraStart = 0, paraEnd = 0, contentsEnd = 0;
		NSMutableArray *array = [NSMutableArray array];
		NSRange currentRange;
		while (paraEnd < length) {
			[string getParagraphStart:&paraStart end:&paraEnd
						  contentsEnd:&contentsEnd forRange:NSMakeRange(paraEnd, 0)];
			currentRange = NSMakeRange(paraStart, contentsEnd - paraStart);
			[array addObject:[string substringWithRange:currentRange]];
		}
		for (NSString *entry in array)
		{
			if ([entry length] >0)
			{
				NSScanner *scanner = [NSScanner scannerWithString:entry];
				NSString *pidtwo, *showNametwo, *episodeNametwo, *typetwo, *someNumbertwo, *downloadFormattwo, *downloadPathtwo;
				[scanner scanUpToString:@"|" intoString:&pidtwo];
				[scanner scanString:@"|" intoString:nil];
				[scanner scanUpToString:@"|" intoString:&showNametwo];
				[scanner scanString:@"|" intoString:nil];
				[scanner scanUpToString:@"|" intoString:&episodeNametwo];
				[scanner scanString:@"|" intoString:nil];
				[scanner scanUpToString:@"|" intoString:&typetwo];
				[scanner scanString:@"|" intoString:nil];
				[scanner scanUpToString:@"|" intoString:&someNumbertwo];
				[scanner scanString:@"|" intoString:nil];
				[scanner scanUpToString:@"|" intoString:&downloadFormattwo];
				[scanner scanString:@"|" intoString:nil];
				[scanner scanUpToString:@"|" intoString:&downloadPathtwo];
				DownloadHistoryEntry *historyEntry = [[DownloadHistoryEntry alloc] initWithPID:pidtwo 
																					  showName:showNametwo 
																				   episodeName:episodeNametwo 
																						  type:typetwo 
																					someNumber:someNumbertwo 
																				downloadFormat:downloadFormattwo 
																				  downloadPath:downloadPathtwo];
				[historyArrayController addObject:historyEntry];
			}
		}
	}
	NSLog(@"end read history");
}

- (IBAction)writeHistory:(id)sender
{
	if (!runDownloads || [sender isEqualTo:self])
	{
		NSLog(@"Write History to File");
		NSArray *currentHistory = [historyArrayController arrangedObjects];
		NSMutableString *historyString = [[NSMutableString alloc] init];
		for (DownloadHistoryEntry *entry in currentHistory)
		{
			[historyString appendFormat:@"%@\n", [entry entryString]];
		}
		NSString *historyPath = @"~/Library/Application Support/Get iPlayer Automator/download_history";
		historyPath = [historyPath stringByExpandingTildeInPath];
		NSData *historyData = [historyString dataUsingEncoding:NSUTF8StringEncoding];
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if (![fileManager fileExistsAtPath:historyPath])
        {
			if (![fileManager createFileAtPath:historyPath contents:historyData attributes:nil])
            {
                [[NSAlert alertWithMessageText:@"Could not create history file!" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Please submit a bug report saying that the history file could not be created."] runModal];
                [self addToLog:@"Could not create history file!"];
            }
        }
		else
        {
            NSError *writeToFileError;
			if (![historyData writeToFile:historyPath options:NSDataWritingAtomic error:&writeToFileError])
            {
                [[NSAlert alertWithMessageText:@"Could not write to history file!" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Please submit a bug report saying that the history file could not be written to."] runModal];                [self addToLog:@"Could not write to history file!"];
            }
        }
	}
	else
	{
		NSAlert *alert = [NSAlert alertWithMessageText:@"Download History cannot be edited while downloads are running." 
										 defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Your changes have been discarded."];
		[alert runModal];
		[historyWindow close];
	}
	[saveButton setEnabled:NO];
	[historyWindow setDocumentEdited:NO];
}

-(IBAction)showHistoryWindow:(id)sender
{
	if (!runDownloads)
	{
		if (![historyWindow isDocumentEdited]) [self readHistory:self];
		[historyWindow makeKeyAndOrderFront:self];
		[saveButton setEnabled:[historyWindow isDocumentEdited]];
	}
	else
	{
		NSAlert *alert = [NSAlert alertWithMessageText:@"Download History cannot be edited while downloads are running." 
										 defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
		[alert runModal];
	}
}
-(IBAction)removeSelectedFromHistory:(id)sender;
{
	if (!runDownloads)
	{
		[saveButton setEnabled:YES];
		[historyWindow setDocumentEdited:YES];
		[historyArrayController remove:self];
	}
	else
	{
		NSAlert *alert = [NSAlert alertWithMessageText:@"Download History cannot be edited while downloads are running." 
										 defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"This window will now close."];
		[alert runModal];
		[historyWindow close];
	}
}
- (IBAction)cancelChanges:(id)sender
{
	[historyWindow setDocumentEdited:NO];
	[saveButton setEnabled:NO];
	[historyWindow close];
}
- (void)addToHistory:(NSNotification *)note
{
	[self readHistory:self];
	NSDictionary *userInfo = [note userInfo];
	Programme *prog = [userInfo valueForKey:@"Programme"];
	DownloadHistoryEntry *entry = [[DownloadHistoryEntry alloc] initWithPID:[prog pid] showName:[prog seriesName] episodeName:[prog episodeName] type:nil someNumber:@"251465" downloadFormat:@"flashhigh" downloadPath:@"/"];
	[historyArrayController addObject:entry];
	[self writeHistory:self];
}
- (void)addToLog:(NSString *)logMessage
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"AddToLog" object:self userInfo:@{@"message": logMessage}];
}
@end
