//
//  GiASearch.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/9/14.
//
//

#import <Foundation/Foundation.h>
#import "Programme.h"
#import "LogController.h"

@interface GiASearch : NSObject {
   NSTask *task;
	NSPipe *pipe;
	NSMutableString *data;
   id target;
   SEL selector;
   LogController *logger;
}

- (id)initWithSearchTerms:(NSString *)searchTerms
  allowHidingOfDownloadedItems:(BOOL)allowHidingOfDownloadedItems
            logController:(LogController *)logger
                 selector:(SEL)selector
               withTarget:(id)target;

@end
