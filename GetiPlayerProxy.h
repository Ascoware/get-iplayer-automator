//
//  GetiPlayerProxy.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/7/14.
//
//

#import <Foundation/Foundation.h>
#import "HTTPProxy.h"

@protocol GetiPlayerProxyDelegate <NSObject>

- (void)proxyLoaded:(HTTPProxy *)proxy;

@end

@interface GetiPlayerProxy : NSObject {
}

@property (nonatomic, weak) NSObject<GetiPlayerProxyDelegate> *delegate;
@property (nonatomic) NSMutableDictionary *proxyDict;
@property (nonatomic) BOOL currentIsSilent;

enum {
    kProxyLoadCancelled = 1,
    kProxyLoadFailed = 2,
    kProxyTestFailed = 3
};

- (void)loadProxyInBackgroundForSelector:(SEL)selector withObject:(id)object onTarget:(id)target silently:(BOOL)silent;

@end

