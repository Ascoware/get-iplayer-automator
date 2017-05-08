//
//  Series.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/19/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "Series.h"


@implementation Series
 - (instancetype)init
{
	if (!(self = [super init])) return nil;
	_showName = [[NSString alloc] init];
	_tvNetwork = [[NSString alloc] init];
	_lastFound = [[NSDate alloc] init];
    _added = @([[NSDate alloc] init].timeIntervalSince1970);
	return self;
}
- (instancetype)initWithShowname:(NSString *)SHOWNAME
{
	if (!(self = [super init])) return nil;
	_showName = [[NSString alloc] initWithString:SHOWNAME];
	_tvNetwork = [[NSString alloc] init];
	_lastFound = [NSDate date];
	return self;
}
- (void) encodeWithCoder: (NSCoder *)coder
{
	[coder encodeObject: _showName forKey:@"showName"];
	[coder encodeObject: _added forKey:@"added"];
	[coder encodeObject: _tvNetwork forKey:@"tvNetwork"];
	[coder encodeObject: _lastFound  forKey:@"lastFound"];
}
- (instancetype) initWithCoder: (NSCoder *)coder
{
	if (!(self = [super init])) return nil;
	_showName = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"showName"]];
	_added = [coder decodeObjectForKey:@"added"];
	_tvNetwork = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"tvNetwork"]];
	_lastFound = [coder decodeObjectForKey:@"lastFound"];
	return self;
}
- (id)description
{
	return [NSString stringWithFormat:@"%@ (%@)", _showName,_tvNetwork];
}

@end
