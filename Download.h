//
//  Download.h
//  
//
//  Created by Thomas Willson on 12/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "HTTPProxy.h"
#import "Programme.h"
#import "ASIHTTPRequest.h"

@interface Download : NSObject {
    NSNotificationCenter *nc;
    
	Programme *show;
    
    //Estimated Time Remaining
    double lastDownloaded;
	NSDate *lastDate;
	NSMutableArray *rateEntries;
	double oldRateAverage;
	int outOfRange;
    NSMutableString *log;
    
    //RTMPDump Task
    NSTask *task;
    NSPipe *pipe;
    NSPipe *errorPipe;
    NSFileHandle *fh;
    NSFileHandle *errorFh;
    NSMutableString *errorCache;
    NSTimer *processErrorCache;
    
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
    
    //Download Information
    NSString *subtitleURL;
    NSString *thumbnailURL;
    NSString *downloadPath;
    NSString *thumbnailPath;
    NSString *subtitlePath;
    
    //Subtitle Conversion
    NSTask *subsTask;
    NSPipe *subsErrorPipe;
    NSString *defaultsPrefix;
    
    NSArray *formatList;
    BOOL running;
    
    NSInteger attemptNumber;

    //Verbose Logging
    BOOL verbose;
    
    //Download Parameters
    NSMutableDictionary *downloadParams;

    //Proxy Info
    HTTPProxy *proxy;
    
    BOOL isFilm;

    ASIHTTPRequest *currentRequest;
}
- (void)setCurrentProgress:(NSString *)string;
- (void)setPercentage:(double)d;
- (void)cancelDownload:(id)sender;
- (void)addToLog:(NSString *)logMessage noTag:(BOOL)b;
- (void)addToLog:(NSString *)logMessage;
- (void)processFLVStreamerMessage:(NSString *)message;

- (void)launchMetaRequest;
- (void)launchRTMPDumpWithArgs:(NSArray *)args;
- (void)processGetiPlayerOutput:(NSString *)outp;
- (void)createDownloadPath;

@property (readonly) Programme *show;
@end
