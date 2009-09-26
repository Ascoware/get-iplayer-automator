//
//  TVFormat.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 9/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TVFormat.h"


@implementation TVFormat
- (id)init
{
	[super init];
	format = [[NSString alloc] init];
	return self;
}
- (void) encodeWithCoder: (NSCoder *)coder
{
	[coder encodeObject: format forKey:@"format"];
}
- (id) initWithCoder: (NSCoder *)coder
{
	[super init];
	format = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"format"]];
	return self;
}

@synthesize format;
@end
