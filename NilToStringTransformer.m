//
//  NilToStringTransformer.m
//  Get_iPlayer GUI
//

#import "NilToStringTransformer.h"

@implementation NilToStringTransformer

-(instancetype)init
{
    return [self initWithString:@""];
}

- (instancetype)initWithString:(NSString *)aString;
{
    if (self = [super init])
    {
        string = aString;
    }
    return self;
}

+ (Class)transformedValueClass
{
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (id)transformedValue:(id)value
{
    if (value == nil) return string;
    return value;
}

- (id)reverseTransformedValue:(id)value
{
    if (value == nil) return string;
    return value;
}

@end
