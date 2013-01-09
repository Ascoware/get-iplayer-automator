//
//  HTTPProxy.m
//  Get_iPlayer GUI
//

#import "HTTPProxy.h"

@implementation HTTPProxy

- (id)initWithURL:(NSURL *)aURL
{
    self = [super init];
    url = [aURL copy];
    if ([[[url scheme] lowercaseString] isEqualToString:@"https"])
        type = (NSString *)kCFProxyTypeHTTPS;
    else
        type = (NSString *)kCFProxyTypeHTTP;
    host = [[url host] copy];
    port = [[url port] integerValue];
    return self;
}

- (id)initWithString:(NSString *)aString
{
    if ([[aString lowercaseString] hasPrefix:@"http://"] || [[aString lowercaseString] hasPrefix:@"https://"])
        return [self initWithURL:[NSURL URLWithString:aString]];
    else
        return [self initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@", aString]]];
}

- (id)initWithScheme:(NSString *)aScheme host:(NSString *)aHost port:(NSInteger)aPort
{
    return [self initWithString:[NSString stringWithFormat:(aPort ? @"%@://%@:%ld" : @"%@://%@"), aScheme, aHost, aPort]];
}

@synthesize url;
@synthesize type;
@synthesize host;
@synthesize port;

@end
