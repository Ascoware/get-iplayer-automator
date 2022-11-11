//
//  Series.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/19/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Series : NSObject <NSSecureCoding> {
}

@property (copy) NSString *showName;
@property NSNumber *added;
@property (copy) NSString *tvNetwork;
@property NSDate *lastFound;

@end
