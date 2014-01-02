//
//  StringTrimFormatter.m
//  Get_iPlayer GUI
//

#import "StringTrimFormatter.h"

@implementation StringTrimFormatter

- (NSString *)stringForObjectValue:(id)anObject {
    if ([anObject isKindOfClass:[NSString class]]) {
        return [anObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    return @"";
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString  **)error {
    *obj = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
   return YES;
}

@end
