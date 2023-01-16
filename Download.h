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
#import "TVFormat.h"

NS_ASSUME_NONNULL_BEGIN

@interface Download : NSObject

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
@property (copy) NSString *subtitlePath;

//Subtitle Conversion
@property (nullable) NSTask *subsTask;
@property (nullable) NSPipe *subsErrorPipe;

@property (copy) NSString *defaultsPrefix;
@property (assign) BOOL running;

//Proxy Info
@property (nullable) HTTPProxy *proxy;

// If proxy is set, this will be a session configured with the set proxy.
// Otherwise, it uses the system (shared) session information.
@property NSURLSession *session;
@property (assign) BOOL isFilm;

@property NSURLSessionDataTask *currentRequest;

- (void)setCurrentProgress:(NSString *)string;
- (void)setPercentage:(double)d;
- (void)cancelDownload;

- (void)processGetiPlayerOutput:(NSString *)outp;
- (void)createDownloadPath;

- (void)tagDownloadWithMetadata;
- (void)atomicParsleyFinished:(nullable NSNotification *)finishedNote;

@end

NS_ASSUME_NONNULL_END

