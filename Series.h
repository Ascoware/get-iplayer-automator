//
//  Series.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/19/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Series : NSObject <NSCoding> {
	NSString *showName;
	NSString *tvNetwork;
	NSNumber *added;
	NSDate *lastFound;
}
- (id)initWithShowname:(NSString *)SHOWNAME;
@property (readwrite, assign) NSString *showName;
@property (readwrite, assign) NSNumber *added;
@property (readwrite, assign) NSString *tvNetwork;
@property (readwrite, assign) NSDate *lastFound;
@end
