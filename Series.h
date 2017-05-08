//
//  Series.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/19/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Series : NSObject <NSCoding> {
}
@property (nonatomic) NSString *showName;
@property (nonatomic) NSNumber *added;
@property (nonatomic) NSString *tvNetwork;
@property (nonatomic) NSDate *lastFound;

- (instancetype)initWithShowname:(NSString *)SHOWNAME;
@end
