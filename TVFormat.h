//
//  TVFormat.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 9/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TVFormat : NSObject <NSSecureCoding>
@property (nonnull, copy) NSString *format;

-(id)initWithFormat:(NSString *)format;

@end

NS_ASSUME_NONNULL_END
