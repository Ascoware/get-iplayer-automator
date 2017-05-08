//
//  NilToEmptyStringTransformer.h
//  Get_iPlayer GUI
//

#import <Foundation/Foundation.h>

@interface NilToStringTransformer : NSValueTransformer
{
    NSString *string;
}
- (instancetype)initWithString:(NSString *)aString NS_DESIGNATED_INITIALIZER;
@end
