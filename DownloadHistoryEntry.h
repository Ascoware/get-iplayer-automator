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

@property(readwrite,assign) NSString *pid;
@property(readwrite,assign) NSString *showName;
@property(readwrite,assign) NSString *episodeName;
@property(readwrite,assign) NSString *type;
@property(readwrite,assign) NSString *someNumber;
@property(readwrite,assign) NSString *downloadFormat;
@property(readwrite,assign) NSString *downloadPath;

@end
