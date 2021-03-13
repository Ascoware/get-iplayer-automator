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
@property (copy) NSString *pid;
@property (copy) NSString *showName;
@property (copy) NSString *episodeName;
@property (copy) NSString *type;
@property (copy) NSString *someNumber;
@property (copy) NSString *downloadFormat;
@property (copy) NSString *downloadPath;
@property (readonly, copy) NSString *entryString;

@end
