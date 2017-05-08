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
	_pid=[temp_pid copy];
	_showName=[temp_showName copy];
	_episodeName=[temp_episodeName copy];
	_type=[temp_type copy];
	_someNumber=[temp_someNumber copy];
	_downloadFormat=[temp_downloadFormat copy];
	_downloadPath=[temp_downloadPath copy];
	return self;
}
- (NSString *)entryString
{
	return [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%@|%@",_pid,_showName,_episodeName,_type,_someNumber,_downloadFormat,_downloadPath];
}
	
@end
