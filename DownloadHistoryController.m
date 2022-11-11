//
//  DownloadHistoryController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 10/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "DownloadHistoryController.h"
#import "DownloadHistoryEntry.h"
#import "NSFileManager+DirectoryLocations.h"
#import "Get_iPlayer_Automator-Swift.h"

@implementation DownloadHistoryController

- (void)awakeFromNib
{
    [self readHistory];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addToHistory:) name:@"AddProgToHistory" object:nil];
}

- (void)readHistory
{
	DDLogVerbose(@"Read History");
    if ([historyArrayController.arrangedObjects count] > 0) {
		[historyArrayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [historyArrayController.arrangedObjects count])]];
    }
	
    NSString *historyFilePath = [[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingPathComponent:@"download_history"];
	NSFileHandle *historyFile = [NSFileHandle fileHandleForReadingAtPath:historyFilePath];
	NSData *historyFileData = [historyFile readDataToEndOfFile];
	NSString *historyFileInfo = [[NSString alloc] initWithData:historyFileData encoding:NSUTF8StringEncoding];
	
	if (historyFileInfo.length > 0)
	{
        NSArray *historyEntries = [historyFileInfo componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

        for (NSString *entry in historyEntries) {
            if (entry.length == 0) {
                continue;
            }
            
            DownloadHistoryEntry *historyEntry = [DownloadHistoryEntry new];
            NSArray *components = [entry componentsSeparatedByString:@"|"];
            historyEntry.pid = components[0];
            historyEntry.showName = components[1];
            historyEntry.episodeName = components[2];
            historyEntry.type = components[3];
            historyEntry.someNumber = components[4];
            historyEntry.downloadFormat = components[5];
            historyEntry.downloadPath = components[6];
            [historyArrayController addObject:historyEntry];
        }
	}
    DDLogVerbose(@"End read history");
}

- (IBAction)writeHistory:(id)sender
{
	if (!runDownloads || [sender isEqualTo:self])
	{
        DDLogVerbose(@"Write History to File");
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
                DDLogWarn(@"%@: Could not create history file!", self.description);
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
        if (!historyWindow.documentEdited) {
            [self readHistory];
        }
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
	[self readHistory];
	NSDictionary *userInfo = note.userInfo;
	Programme *prog = [userInfo valueForKey:@"Programme"];
    NSInteger now = [[NSDate new] timeIntervalSince1970];
    DownloadHistoryEntry *entry = [DownloadHistoryEntry new];
    entry.pid = prog.pid;
    entry.showName = prog.seriesName;
    entry.episodeName = prog.episodeName;
    entry.someNumber = [NSString stringWithFormat:@"%ld", now];
    entry.type = @"itv";
    entry.downloadFormat = @"flashhigh";
    entry.downloadPath = prog.path;
	[historyArrayController addObject:entry];
	[self writeHistory:self];
}

@end
