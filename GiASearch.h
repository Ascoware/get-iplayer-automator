//
//  GiASearch.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/9/14.
//
//

#import <Foundation/Foundation.h>
#import "Programme.h"

@interface GiASearch : NSObject

@property (nonatomic) NSTask *task;
@property (nonatomic) NSPipe *pipe;
@property (nonatomic) NSPipe *errorPipe;
@property (nonatomic) NSMutableString *data;
@property (nonatomic) id target;
@property (nonatomic) SEL selector;

- (instancetype)initWithSearchTerms:(NSString *)searchTerms
       allowHidingOfDownloadedItems:(BOOL)allowHidingOfDownloadedItems
                           selector:(SEL)selector
                         withTarget:(id)target;

@end
