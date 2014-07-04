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
	if (!(self = [super init])) return nil;
	showName = [[NSString alloc] init];
	tvNetwork = [[NSString alloc] init];
	lastFound = [[NSDate alloc] init];
    added = @([[[NSDate alloc] init] timeIntervalSince1970]);
	return self;
}
- (id)initWithShowname:(NSString *)SHOWNAME
{
	if (!(self = [super init])) return nil;
	showName = [[NSString alloc] initWithString:SHOWNAME];
	tvNetwork = [[NSString alloc] init];
	lastFound = [NSDate date];
	return self;
}
- (void) encodeWithCoder: (NSCoder *)coder
{
	[coder encodeObject: showName forKey:@"showName"];
	[coder encodeObject: added forKey:@"added"];
	[coder encodeObject: tvNetwork forKey:@"tvNetwork"];
	[coder encodeObject: lastFound  forKey:@"lastFound"];
}
- (id) initWithCoder: (NSCoder *)coder
{
	if (!(self = [super init])) return nil;
	showName = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"showName"]];
	added = [coder decodeObjectForKey:@"added"];
	tvNetwork = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"tvNetwork"]];
	lastFound = [coder decodeObjectForKey:@"lastFound"];
	return self;
}
- (id)description
{
	return [NSString stringWithFormat:@"%@ (%@)", showName,tvNetwork];
}
@synthesize showName;
@synthesize added;
@synthesize tvNetwork;
@synthesize lastFound;
@end
