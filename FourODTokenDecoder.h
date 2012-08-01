//
//  FourODTokenDecoder.h
//  Get_iPlayer GUI
//
//  Created by Thomas E. Willson on 8/1/12.
//
//

#import <Foundation/Foundation.h>
#include <Python/Python.h>

@interface FourODTokenDecoder : NSObject
+ (NSString *)decodeToken:(NSString *)string;
@end
