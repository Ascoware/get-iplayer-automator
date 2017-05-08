//
//  DownloadHistoryEntry.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 10/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DownloadHistoryEntry : NSObject {
}
@property (nonatomic) NSString *pid;
@property (nonatomic) NSString *showName;
@property (nonatomic) NSString *episodeName;
@property (nonatomic) NSString *type;
@property (nonatomic) NSString *someNumber;
@property (nonatomic) NSString *downloadFormat;
@property (nonatomic) NSString *downloadPath;
@property (nonatomic, readonly, copy) NSString *entryString;

- (instancetype)initWithPID:(NSString *)temp_pid showName:(NSString *)temp_showName episodeName:(NSString *)temp_episodeName type:(NSString *)temp_type someNumber:(NSString *)temp_someNumber downloadFormat:(NSString *)temp_downloadFormat downloadPath:(NSString *)temp_downloadPath;

@end
