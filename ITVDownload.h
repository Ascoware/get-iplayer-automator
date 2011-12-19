//
//  ITVDownload.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 12/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Download.h"
#import "TVFormat.h"

@interface ITVDownload : Download {
    NSTask *task;
    
    NSPipe *pipe;
    NSPipe *errorPipe;
    
    NSFileHandle *fh;
    NSFileHandle *errorFh;
    
    NSMutableString *errorCache;
    NSTimer *errorTimer;
    
    NSString *subtitleURL;
    NSString *thumbnailURL;
    NSString *downloadPath;
    
    //ffmpeg Conversion
    NSTask *ffTask;
    NSPipe *ffPipe;
    NSPipe *ffErrorPipe;
    NSFileHandle *ffFh;
    NSFileHandle *ffErrorFh;
    
    //AtomicParsley Tagging
    NSTask *apTask;
    NSPipe *apPipe;
    NSFileHandle *apFh;
    
    NSArray *formatList;
}
- (id)initWithProgramme:(Programme *)tempShow itvFormats:(NSArray *)itvFormatList;
- (void)processGetiPlayerOutput:(NSString *)outp;
@end
