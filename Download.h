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

@property (nonatomic, nullable) NSTask *task;
@property (nonatomic, nullable) NSPipe *pipe;
@property (nonatomic, nullable) NSPipe *errorPipe;

//AtomicParsley Tagging
@property (nonatomic, nullable) NSTask *apTask;
@property (nonatomic, nullable) NSPipe *apPipe;

//Download Information
@property (nonatomic, nullable) NSString *subtitleURL;
@property (nonatomic, nullable) NSString *thumbnailURL;
@property (nonatomic) NSString *downloadPath;
@property (nonatomic) NSString *thumbnailPath;
@property (nonatomic) NSString *subtitlePath;

//Subtitle Conversion
@property (nonatomic, nullable) NSTask *subsTask;
@property (nonatomic, nullable) NSPipe *subsErrorPipe;

@property (nonatomic) NSString *defaultsPrefix;
@property (nonatomic, assign) BOOL running;

//Verbose Logging
@property (nonatomic, assign) BOOL verbose;

//Proxy Info
@property (nonatomic, nullable) HTTPProxy *proxy;

// If proxy is set, this will be a session configured with the set proxy.
// Otherwise, it uses the system (shared) session information.
@property (nonatomic) NSURLSession *session;
@property (nonatomic, assign) BOOL isFilm;

@property (nonatomic) NSURLSessionDataTask *currentRequest;

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

