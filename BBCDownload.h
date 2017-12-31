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
@property (nonatomic) NSString *profileDirArg;
	
@property (nonatomic, assign) BOOL runAgain;
@property (nonatomic, assign) NSInteger noDataCount;
	
@property (nonatomic, assign) BOOL foundLastLine;
@property (nonatomic) NSString *LastLine;
@property (nonatomic) NSString *reasonForFailure;

+ (void)initFormats;
- (instancetype)initWithProgramme:(Programme *)tempShow tvFormats:(NSArray *)tvFormatList radioFormats:(NSArray *)radioFormatList proxy:(HTTPProxy *)aProxy logController:(LogController *)logger NS_DESIGNATED_INITIALIZER;
- (void)processGetiPlayerOutput:(NSString *)outp;

@end
