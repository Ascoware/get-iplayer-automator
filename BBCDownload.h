//
//  Download.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/14/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Programme.h"
#import "TVFormat.h"
#import "RadioFormat.h"
#import "Download.h"
#import "AppController.h"

@interface BBCDownload : Download {
}

@property (copy) NSString *reasonForFailure;

+ (void)initFormats;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithProgramme:(Programme *)tempShow tvFormats:(NSArray *)tvFormatList radioFormats:(NSArray *)radioFormatList proxy:(HTTPProxy *)aProxy  NS_DESIGNATED_INITIALIZER;
- (void)processGetiPlayerOutput:(NSString *)outp;

@end
