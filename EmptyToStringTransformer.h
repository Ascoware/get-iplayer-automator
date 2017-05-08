//
//  EmptyToStringTransformer.h
//  Get_iPlayer GUI
//

#import <Foundation/Foundation.h>

@interface EmptyToStringTransformer : NSValueTransformer
{
    NSString *string;
}
- (instancetype)initWithString:(NSString *)aString NS_DESIGNATED_INITIALIZER;
@end
