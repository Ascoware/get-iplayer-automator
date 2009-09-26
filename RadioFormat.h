//
//  RadioFormat.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 9/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface RadioFormat : NSObject <NSCoding> {
	NSString *format;
}
@property (readwrite, assign) NSString *format;
@end
