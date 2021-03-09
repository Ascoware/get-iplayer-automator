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

@property LogController *logger;

@property Programme *show;

@property (nullable) NSTask *task;
@property (nullable) NSPipe *pipe;
@property (nullable) NSPipe *errorPipe;

//AtomicParsley Tagging
@property (nullable) NSTask *apTask;
@property (nullable) NSPipe *apPipe;

//Download Information
@property (nullable) NSString *subtitleURL;
@property (copy) NSString *downloadPath;
@property (copy) NSString *thumbnailPath;
@property (copy) NSString *subtitlePath;

//Subtitle Conversion
@property (nullable) NSTask *subsTask;
@property (nullable) NSPipe *subsErrorPipe;

@property (copy) NSString *defaultsPrefix;
@property (assign) BOOL running;

//Verbose Logging
@property (assign) BOOL verbose;

//Proxy Info
@property (nullable) HTTPProxy *proxy;

// If proxy is set, this will be a session configured with the set proxy.
// Otherwise, it uses the system (shared) session information.
@property NSURLSession *session;
@property (assign) BOOL isFilm;

@property NSURLSessionDataTask *currentRequest;

- (instancetype)initWithLogController:(LogController *)logger;
- (void)setCurrentProgress:(NSString *)string;
- (void)setPercentage:(double)d;
- (void)cancelDownload;

- (void)logDebugMessage:(NSString *)message noTag:(BOOL)b;
- (void)addToLog:(NSString *)logMessage noTag:(BOOL)b;
- (void)addToLog:(NSString *)logMessage;

- (void)processGetiPlayerOutput:(NSString *)outp;
- (void)createDownloadPath;

- (void)thumbnailRequestFinished:(nullable NSURL *)location;
- (void)atomicParsleyFinished:(nullable NSNotification *)finishedNote;

@end

NS_ASSUME_NONNULL_END

