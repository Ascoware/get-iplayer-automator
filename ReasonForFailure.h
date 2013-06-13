//
//  ReasonForFailure.h
//  Get_iPlayer GUI
//
//  Created by Thomas E. Willson on 8/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ReasonForFailure : NSObject {
    NSString *showName;
    NSString *solution;
}

@property (readwrite) NSString *showName;
@property (readwrite) NSString *solution;

@end
