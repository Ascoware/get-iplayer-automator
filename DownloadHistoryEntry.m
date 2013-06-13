//
//  DownloadHistoryEntry.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 10/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "DownloadHistoryEntry.h"


@implementation DownloadHistoryEntry
- (id)initWithPID:(NSString *)temp_pid showName:(NSString *)temp_showName episodeName:(NSString *)temp_episodeName type:(NSString *)temp_type someNumber:(NSString *)temp_someNumber downloadFormat:(NSString *)temp_downloadFormat downloadPath:(NSString *)temp_downloadPath
{
	if (!(self = [super init])) return nil;
	pid=[temp_pid copy];
	showName=[temp_showName copy];
	episodeName=[temp_episodeName copy];
	type=[temp_type copy];
	someNumber=[temp_someNumber copy];
	downloadFormat=[temp_downloadFormat copy];
	downloadPath=[temp_downloadPath copy];
	return self;
}
- (NSString *)entryString
{
	return [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%@|%@",pid,showName,episodeName,type,someNumber,downloadFormat,downloadPath];
}
	

@synthesize pid;
@synthesize showName;
@synthesize episodeName;
@synthesize type;
@synthesize someNumber;
@synthesize downloadFormat;
@synthesize downloadPath;
@end
