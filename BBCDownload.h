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

extern bool runDownloads;

#import "Download.h"

@interface BBCDownload : Download {
	NSString *profileDirArg;
	
	BOOL runAgain;
	int i;
	
	BOOL foundLastLine;
	NSString *LastLine;
	NSString *reasonForFailure;
}
- (id)initWithProgramme:(Programme *)tempShow tvFormats:(NSArray *)tvFormatList radioFormats:(NSArray *)radioFormatList proxy:(HTTPProxy *)aProxy;
- (void)processGetiPlayerOutput:(NSString *)outp;

@end
