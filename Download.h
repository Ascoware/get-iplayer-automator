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
#import "LogController.h"

@interface Download : NSObject

@property (nonatomic) NSNotificationCenter *nc;
@property (nonatomic) LogController *logger;

@property (nonatomic) Programme *show;

@property (nonatomic) double lastDownloaded;
@property (nonatomic) NSDate *lastDate;
@property (nonatomic) NSMutableArray *rateEntries;
@property (nonatomic) double oldRateAverage;
@property (nonatomic) int outOfRange;
@property (nonatomic) NSMutableString *log;

//RTMPDump Task
@property (nonatomic) NSTask *task;
@property (nonatomic) NSPipe *pipe;
@property (nonatomic) NSPipe *errorPipe;
@property (nonatomic) NSFileHandle *fh;
@property (nonatomic) NSFileHandle *errorFh;
@property (nonatomic) NSMutableString *errorCache;
@property (nonatomic) NSTimer *processErrorCache;

//ffmpeg Conversion
@property (nonatomic) NSTask *ffTask;
@property (nonatomic) NSPipe *ffPipe;
@property (nonatomic) NSPipe *ffErrorPipe;
@property (nonatomic) NSFileHandle *ffFh;
@property (nonatomic) NSFileHandle *ffErrorFh;

//AtomicParsley Tagging
@property (nonatomic) NSTask *apTask;
@property (nonatomic) NSPipe *apPipe;
@property (nonatomic) NSFileHandle *apFh;

//Download Information
@property (nonatomic) NSString *subtitleURL;
@property (nonatomic) NSString *thumbnailURL;
@property (nonatomic) NSString *downloadPath;
@property (nonatomic) NSString *thumbnailPath;
@property (nonatomic) NSString *subtitlePath;

//Subtitle Conversion
@property (nonatomic) NSTask *subsTask;
@property (nonatomic) NSPipe *subsErrorPipe;
@property (nonatomic) NSString *defaultsPrefix;

@property (nonatomic) NSArray *formatList;
@property (nonatomic) BOOL running;

@property (nonatomic)NSInteger attemptNumber;

//Verbose Logging
@property (nonatomic) BOOL verbose;

//Download Parameters
@property (nonatomic) NSMutableDictionary *downloadParams;

//Proxy Info
@property (nonatomic) HTTPProxy *proxy;

@property (nonatomic) BOOL isFilm;

@property (nonatomic) ASIHTTPRequest *currentRequest;

//Download Test
@property (nonatomic) BOOL isTest;

- (instancetype)initWithLogController:(LogController *)logger;
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
- (void)processError;

@end
