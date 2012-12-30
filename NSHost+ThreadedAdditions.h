//
//  NSHost+ThreadedAdditions.h
//
//  Created by Matt Gallagher on 2009/11/14.
//  Copyright 2009 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import <Foundation/Foundation.h>

@interface NSHost (ThreadedAdditions)

+ (void)currentHostInBackgroundForReceiver:(id)receiver selector:(SEL)receiverSelector;
+ (void)hostWithName:(NSString *)name inBackgroundForReceiver:(id)receiver selector:(SEL)receiverSelector;
+ (void)hostWithAddress:(NSString *)address inBackgroundForReceiver:(id)receiver selector:(SEL)receiverSelector;

@end
