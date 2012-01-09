//
//  ITVMediaFileEntry.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 1/9/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "ITVMediaFileEntry.h"

@implementation ITVMediaFileEntry

- (id)init
{
    self = [super init];
    if (self) {
        url = [[NSString alloc] init];
        bitrate = [[NSString alloc] init];
        itvRate = [[NSString alloc] init];
    }
    
    return self;
}
@synthesize url;
@synthesize bitrate;
@synthesize itvRate;
@end
