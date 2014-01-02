//
//  NilToEmptyStringTransformer.h
//  Get_iPlayer GUI
//

#import <Foundation/Foundation.h>

@interface NilToStringTransformer : NSValueTransformer
{
    NSString *string;
}
- (id)initWithString:(NSString *)aString;
@end
