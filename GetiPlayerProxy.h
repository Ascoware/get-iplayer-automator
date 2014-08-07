//
//  GetiPlayerProxy.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/7/14.
//
//

#import <Foundation/Foundation.h>
#import "HTTPProxy.h"
#import "LogController.h"
#import "ASIHTTPRequest.h"

@interface GetiPlayerProxy : NSObject {
   //Proxy
   LogController *logger;
   NSMutableDictionary *proxyDict;
   BOOL currentIsSilent;
   
   enum {
      kProxyLoadCancelled = 1,
      kProxyLoadFailed = 2,
      kProxyTestFailed = 3
   };
   
}
- (void)loadProxyInBackgroundForSelector:(SEL)selector withObject:(id)object onTarget:(id)target silently:(BOOL)silent;
- (id)initWithLogger:(LogController *)logger;

@end
