//
//  DownloadHistoryEntry.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 10/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "DownloadHistoryEntry.h"


@implementation DownloadHistoryEntry
- (instancetype)initWithPID:(NSString *)temp_pid showName:(NSString *)temp_showName episodeName:(NSString *)temp_episodeName type:(NSString *)temp_type someNumber:(NSString *)temp_someNumber downloadFormat:(NSString *)temp_downloadFormat downloadPath:(NSString *)temp_downloadPath
{
	if (!(self = [super init])) return nil;
	self.pid = temp_pid;
	self.showName = temp_showName;
	self.episodeName = temp_episodeName;
    self.type = temp_type;
	self.someNumber = temp_someNumber;
	self.downloadFormat = temp_downloadFormat;
	self.downloadPath = temp_downloadPath;
	return self;
}
- (NSString *)entryString
{
	return [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%@|%@",_pid,_showName,_episodeName,_type,_someNumber,_downloadFormat,_downloadPath];
}
	
@end
