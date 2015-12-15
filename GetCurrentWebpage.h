//
//  GetCurrentWebpageController.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/3/14.
//
//

#import <Foundation/Foundation.h>
#import "Chrome.h"
#import "Safari.h"
#import "Programme.h"
#import "LogController.h"
#import "NSString+HTML.h"

@interface GetCurrentWebpage : NSObject
+ (Programme *)getCurrentWebpage:(LogController *)logger;
@end
