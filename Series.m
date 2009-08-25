//
//  Series.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/19/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "Series.h"


@implementation Series
 - (id)init
{
	[super init];
	showName = [[NSString alloc] init];
	tvNetwork = [[NSString alloc] init];
	return self;
}
- (id)initWithShowname:(NSString *)SHOWNAME
{
	[super init];
	showName = [[NSString alloc] initWithString:SHOWNAME];
	tvNetwork = [[NSString alloc] init];
	return self;
}
- (void) encodeWithCoder: (NSCoder *)coder
{
	[coder encodeObject: showName forKey:@"showName"];
	[coder encodeObject: added forKey:@"added"];
	[coder encodeObject: tvNetwork forKey:@"tvNetwork"];
}
- (id) initWithCoder: (NSCoder *)coder
{
	[super init];
	showName = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"showName"]];
	added = [coder decodeObjectForKey:@"added"];
	tvNetwork = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"tvNetwork"]];
	return self;
}
@synthesize showName;
@synthesize added;
@synthesize tvNetwork;
@end
