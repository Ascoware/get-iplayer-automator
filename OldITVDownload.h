//
//  ITVDownload.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 12/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Download.h"
#import "TVFormat.h"
#import "LogController.h"

@interface OldITVDownload : Download
- (instancetype)initTest:(Programme *)tempShow proxy:(HTTPProxy *)aProxy;
-(void)dataRequestFinished:(NSHTTPURLResponse *)request data:(NSData *)data error:(NSError *)error;

@end
