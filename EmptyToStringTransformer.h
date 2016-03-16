//
//  EmptyToStringTransformer.h
//  Get_iPlayer GUI
//

#import <Foundation/Foundation.h>

@interface EmptyToStringTransformer : NSValueTransformer
{
    NSString *string;
}
- (id)initWithString:(NSString *)aString;
@end
