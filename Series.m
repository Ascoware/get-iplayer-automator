//
//  Series.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/19/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "Series.h"


@implementation Series

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
	_showName = [coder decodeObjectForKey:@"showName"];
	_added = [coder decodeObjectForKey:@"added"];
    _tvNetwork = [coder decodeObjectForKey:@"tvNetwork"];
	_lastFound = [coder decodeObjectForKey:@"lastFound"];
	return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)description
{
	return [NSString stringWithFormat:@"%@ (%@)", _showName,_tvNetwork];
}

@end
