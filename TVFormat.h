//
//  TVFormat.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 9/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface TVFormat : NSObject <NSCoding> {
	NSString *format;
}
@property (readwrite) NSString *format;
@end
