//
//  EmptyToStringTransformer.m
//  Get_iPlayer GUI
//

#import "EmptyToStringTransformer.h"

@implementation EmptyToStringTransformer

-(id)init
{
    return [self initWithString:@""];
}

- (id)initWithString:(NSString *)aString;
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
    if ([value isEqual:@""]) return string;
    return value;
}

- (id)reverseTransformedValue:(id)value
{
    if ([value isEqual:string]) return @"";
    return value;
}

@end
