//
//  ITVMediaFileEntry.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 1/9/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ITVMediaFileEntry : NSObject {
    NSString *bitrate;
    NSString *itvRate;
    NSString *url;
}
@property (readwrite) NSString *bitrate;
@property (readwrite) NSString *itvRate;
@property (readwrite) NSString *url;
@end
