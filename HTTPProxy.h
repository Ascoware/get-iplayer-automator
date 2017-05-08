//
//  HTTPProxy.h
//  Get_iPlayer GUI
//

#import <Foundation/Foundation.h>

@interface HTTPProxy : NSObject

- (instancetype)initWithURL:(NSURL *)aURL;
- (instancetype)initWithString:(NSString *)aString;

@property (readonly, copy) NSURL *url;
@property (readonly, copy) NSString *type;
@property (readonly, copy) NSString *host;
@property (readonly, assign) NSUInteger port;
@property (readonly, copy) NSString *user;
@property (readonly, copy) NSString *password;
@end
