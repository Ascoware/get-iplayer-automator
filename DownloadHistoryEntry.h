//
//  DownloadHistoryEntry.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 10/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DownloadHistoryEntry : NSObject {
	NSString *pid;
	NSString *showName;
	NSString *episodeName;
	NSString *type;
	NSString *someNumber;
	NSString *downloadFormat;
	NSString *downloadPath;
}
- (id)initWithPID:(NSString *)temp_pid showName:(NSString *)temp_showName episodeName:(NSString *)temp_episodeName type:(NSString *)temp_type someNumber:(NSString *)temp_someNumber downloadFormat:(NSString *)temp_downloadFormat downloadPath:(NSString *)temp_downloadPath;
- (NSString *)entryString;

@property(readwrite) NSString *pid;
@property(readwrite) NSString *showName;
@property(readwrite) NSString *episodeName;
@property(readwrite) NSString *type;
@property(readwrite) NSString *someNumber;
@property(readwrite) NSString *downloadFormat;
@property(readwrite) NSString *downloadPath;

@end
