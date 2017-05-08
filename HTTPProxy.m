//
//  HTTPProxy.m
//  Get_iPlayer GUI
//

#import "HTTPProxy.h"

@implementation HTTPProxy

- (instancetype)initWithURL:(NSURL *)aURL
{
    if (self = [super init]) {
        _url = [aURL copy];
        if ([_url.scheme.lowercaseString isEqualToString:@"https"])
            _type = (NSString *)kCFProxyTypeHTTPS;
        else
            _type = (NSString *)kCFProxyTypeHTTP;
        _host = [_url.host copy];
        _port = _url.port.integerValue;
        _user = [_url.user copy];
        _password = [_url.password copy];
    }
    return self;
}

- (instancetype)initWithString:(NSString *)aString
{
    if ([aString.lowercaseString hasPrefix:@"http://"] || [aString.lowercaseString hasPrefix:@"https://"])
        return [self initWithURL:[NSURL URLWithString:aString]];
    else
        return [self initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@", aString]]];
}

@end
