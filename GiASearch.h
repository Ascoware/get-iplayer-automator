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

- (id)initWithSearchTerms:(NSString *)searchTerms logController:(LogController *)logger typeArgument:(NSString *)typeArgument profileDirArg:(NSString *)profileDirArg selector:(SEL)selector withTarget:(id)target;

@property (readwrite) bool allowHide;

@end
