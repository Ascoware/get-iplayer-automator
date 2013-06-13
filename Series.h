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
	NSNumber *__strong added;
	NSDate *lastFound;
}
- (id)initWithShowname:(NSString *)SHOWNAME;
@property (readwrite) NSString *showName;
@property (readwrite, strong) NSNumber *added;
@property (readwrite) NSString *tvNetwork;
@property (readwrite) NSDate *lastFound;
@end
