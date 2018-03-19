//
//  HTTPProxy.h
//  Get_iPlayer GUI
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HTTPProxy : NSObject

- (instancetype)initWithURL:(NSURL *)aURL;
- (instancetype)initWithString:(NSString *)aString;

@property (readonly, copy) NSURL *url;
@property (readonly, copy) NSString *type;
@property (readonly, copy) NSString *host;
@property (readonly, assign) NSUInteger port;
@property (readonly, copy, nullable) NSString *user;
@property (readonly, copy, nullable) NSString *password;
@end

NS_ASSUME_NONNULL_END
