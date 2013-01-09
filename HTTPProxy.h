//
//  HTTPProxy.h
//  Get_iPlayer GUI
//

#import <Foundation/Foundation.h>

@interface HTTPProxy : NSObject
{
    NSURL *url;
    NSString *type;
    NSString *host;
    NSInteger port;
}

- (id)initWithURL:(NSURL *)aURL;
- (id)initWithString:(NSString *)aString;
- (id)initWithScheme:(NSString *)aScheme host:(NSString *)aHost port:(NSInteger)aPort;

@property (readonly, copy) NSURL *url;
@property (readonly, copy) NSString *type;
@property (readonly, copy) NSString *host;
@property (readonly, assign) NSInteger port;
@end
