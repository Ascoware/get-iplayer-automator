//
//  ITVMediaFileEntry.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 1/9/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "ITVMediaFileEntry.h"

@implementation ITVMediaFileEntry

-(NSString *)description {
    return [NSString stringWithFormat:@"uri = %@, itvRate = %@, bitrate = %@", self.url, self.itvRate, self.bitrate];
}
@end
