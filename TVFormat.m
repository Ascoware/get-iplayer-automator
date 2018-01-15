//
//  TVFormat.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 9/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TVFormat.h"

@implementation TVFormat

- (instancetype)init
{
	if (!(self = [super init])) return nil;
    _format = @"";
	return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
	[coder encodeObject: _format forKey:@"format"];
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
	if (!(self = [super init])) return nil;
	_format = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"format"]];
	return self;
}

@end
