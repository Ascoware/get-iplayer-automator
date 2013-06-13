//
//  LiveTVChannel.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 10/3/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "LiveTVChannel.h"


@implementation LiveTVChannel
- (id)init
{
	if (!(self = [super init])) return nil;
	channel = [[NSString alloc] init];
	return self;
}
- (id)initWithChannelName:(NSString *)channelName
{
	if (!(self = [super init])) return nil;
	channel = [channelName copy];
	return self;
}
@synthesize channel;
@end
