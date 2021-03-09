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
#import "NSFileManager+DirectoryLocations.h"


@implementation DownloadHistoryController
- (instancetype)init
{
	if (!(self = [super init])) return nil;
	[self readHistory:self];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addToHistory:) name:@"AddProgToHistory" object:nil];
	return self;
}
- (void)readHistory:(id)sender
{
	NSLog(@"Read History");
	if ([historyArrayController.arrangedObjects count] > 0)
		[historyArrayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [historyArrayController.arrangedObjects count])]];
	
    NSString *historyFilePath = [[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingPathComponent:@"download_history"];
	NSFileHandle *historyFile = [NSFileHandle fileHandleForReadingAtPath:historyFilePath];
	NSData *historyFileData = [historyFile readDataToEndOfFile];
	NSString *historyFileInfo = [[NSString alloc] initWithData:historyFileData encoding:NSUTF8StringEncoding];
	
	if (historyFileInfo.length > 0)
	{
		NSString *string = [NSString stringWithString:historyFileInfo];
		NSUInteger length = string.length;
		NSUInteger paraStart = 0, paraEnd = 0, contentsEnd = 0;
		NSMutableArray *array = [NSMutableArray array];
		NSRange currentRange;
		while (paraEnd < length) {
			[string getParagraphStart:&paraStart end:&paraEnd
						  contentsEnd:&contentsEnd forRange:NSMakeRange(paraEnd, 0)];
			currentRange = NSMakeRange(paraStart, contentsEnd - paraStart);
			[array addObject:[string substringWithRange:currentRange]];
		}
		for (NSString *entry in array) {
            NSArray *components = [entry componentsSeparatedByString:@"|"];
            NSString *pid = components[0];
            NSString *showName = components[1];
            NSString *episodeName = components[2];
            NSString *type = components[3];
            NSString *someNumber = components[4];
            NSString *downloadFormat = components[5];
            NSString *downloadPath = components[6];

            DownloadHistoryEntry *historyEntry = [[DownloadHistoryEntry alloc] initWithPID:pid
                                                                                  showName:showName
                                                                               episodeName:episodeName
                                                                                      type:type
                                                                                someNumber:someNumber
                                                                            downloadFormat:downloadFormat
                                                                              downloadPath:downloadPath];
            [historyArrayController addObject:historyEntry];
        }
	}
	NSLog(@"end read history");
}

- (IBAction)writeHistory:(id)sender
{
	if (!runDownloads || [sender isEqualTo:self])
	{
		NSLog(@"Write History to File");
		NSArray *currentHistory = historyArrayController.arrangedObjects;
		NSMutableString *historyString = [[NSMutableString alloc] init];
		for (DownloadHistoryEntry *entry in currentHistory)
		{
			[historyString appendFormat:@"%@\n", [entry entryString]];
		}
        NSString *historyPath = [[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingPathComponent:@"download_history"];
		NSData *historyData = [historyString dataUsingEncoding:NSUTF8StringEncoding];
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if (![fileManager fileExistsAtPath:historyPath])
        {
			if (![fileManager createFileAtPath:historyPath contents:historyData attributes:nil])
            {
                NSAlert *alert = [[NSAlert alloc] init];
                alert.informativeText = @"Please submit a bug report saying that the history file could not be created.";
                alert.messageText = @"Could not create history file!";
                [alert addButtonWithTitle:@"OK"];
                [alert runModal];
                [self addToLog:@"Could not create history file!"];
            }
        }
		else
        {
            NSError *writeToFileError;
			if (![historyData writeToFile:historyPath options:NSDataWritingAtomic error:&writeToFileError])
            {
                NSAlert *alert = [[NSAlert alloc] init];
                alert.informativeText = @"Please submit a bug report saying that the history file could not be written to.";
                alert.messageText = @"Could not write to history file!";
                [alert addButtonWithTitle:@"OK"];
                [alert runModal];
            }
        }
	}
	else
	{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.informativeText = @"Your changes have been discarded.";
        alert.messageText = @"Download History cannot be edited while downloads are running.";
        [alert addButtonWithTitle:@"OK"];
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
		if (!historyWindow.documentEdited) [self readHistory:self];
		[historyWindow makeKeyAndOrderFront:self];
		saveButton.enabled = historyWindow.documentEdited;
	}
	else
	{
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"Download History cannot be edited while downloads are running.";
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
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"Download History cannot be edited while downloads are running.";
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
	NSDictionary *userInfo = note.userInfo;
	Programme *prog = [userInfo valueForKey:@"Programme"];
	DownloadHistoryEntry *entry = [[DownloadHistoryEntry alloc] initWithPID:prog.pid showName:prog.seriesName episodeName:prog.episodeName type:nil someNumber:@"251465" downloadFormat:@"flashhigh" downloadPath:@"/"];
	[historyArrayController addObject:entry];
	[self writeHistory:self];
}
- (void)addToLog:(NSString *)logMessage
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"AddToLog" object:self userInfo:@{@"message": logMessage}];
}
@end
