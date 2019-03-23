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
#import "LogController.h"
#import "TVFormat.h"

NS_ASSUME_NONNULL_BEGIN

@interface Download : NSObject

@property (nonatomic) LogController *logger;

@property (nonatomic) Programme *show;

@property (nonatomic) double lastDownloaded;
@property (nonatomic) NSDate *lastDate;
@property (nonatomic) NSMutableArray *rateEntries;
@property (nonatomic) double oldRateAverage;
@property (nonatomic) int outOfRange;
@property (nonatomic) NSMutableString *log;

//RTMPDump Task
@property (nonatomic, nullable) NSTask *task;
@property (nonatomic, nullable) NSPipe *pipe;
@property (nonatomic, nullable) NSPipe *errorPipe;
@property (nonatomic, nullable) NSFileHandle *fh;
@property (nonatomic, nullable) NSFileHandle *errorFh;
@property (nonatomic) NSMutableString *errorCache;
@property (nonatomic) NSTimer *processErrorCache;

//ffmpeg Conversion
@property (nullable, nonatomic) NSTask *ffTask;
@property (nullable, nonatomic) NSPipe *ffPipe;
@property (nullable, nonatomic) NSPipe *ffErrorPipe;
@property (nullable, nonatomic) NSFileHandle *ffFh;
@property (nullable, nonatomic) NSFileHandle *ffErrorFh;

//AtomicParsley Tagging
@property (nonatomic) NSTask *apTask;
@property (nonatomic) NSPipe *apPipe;
@property (nonatomic) NSFileHandle *apFh;

//Download Information
@property (nonatomic, nullable) NSString *subtitleURL;
@property (nonatomic, nullable) NSString *thumbnailURL;
@property (nonatomic) NSString *downloadPath;
@property (nonatomic) NSString *thumbnailPath;
@property (nonatomic) NSString *subtitlePath;

//Subtitle Conversion
@property (nonatomic) NSTask *subsTask;
@property (nonatomic) NSPipe *subsErrorPipe;
@property (nonatomic) NSString *defaultsPrefix;

@property (nonatomic) NSArray<TVFormat *> *formatList;
@property (nonatomic, assign) BOOL running;

@property (nonatomic, assign) NSInteger attemptNumber;

//Verbose Logging
@property (nonatomic, assign) BOOL verbose;

//Download Parameters
@property (nonatomic) NSMutableDictionary *downloadParams;

//Proxy Info
@property (nonatomic, nullable) HTTPProxy *proxy;

// If proxy is set, this will be a session configured with the set proxy.
// Otherwise, it uses the system (shared) session information.
@property (nonatomic) NSURLSession *session;
@property (nonatomic, assign) BOOL isFilm;

@property (nonatomic) NSURLSessionDataTask *currentRequest;

//Download Test
@property (nonatomic) BOOL isTest;

- (instancetype)initWithLogController:(LogController *)logger;
- (void)setCurrentProgress:(NSString *)string;
- (void)setPercentage:(double)d;
- (void)cancelDownload;

- (void)logDebugMessage:(NSString *)message noTag:(BOOL)b;
- (void)addToLog:(NSString *)logMessage noTag:(BOOL)b;
- (void)addToLog:(NSString *)logMessage;
- (void)processFLVStreamerMessage:(NSString *)message;

- (void)launchMetaRequest;
- (void)processGetiPlayerOutput:(NSString *)outp;
- (void)createDownloadPath;
- (void)processError;

- (void)thumbnailRequestFinished:(nullable NSURL *)location;
- (void)atomicParsleyFinished:(nullable NSNotification *)finishedNote;

@end

NS_ASSUME_NONNULL_END

