//
//  Programme.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/13/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GetiPlayerArguments.h"
#import "LogController.h"
#import "GetiPlayerProxy.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GIA_ProgrammeType) {
    GiA_ProgrammeTypeBBC_TV,
    GiA_ProgrammeTypeBBC_Radio,
    GIA_ProgrammeTypeITV
};

@interface Programme : NSObject <NSSecureCoding>
@property LogController *logger;
@property (copy) NSString *tvNetwork;
@property (copy) NSString *showName;
@property (copy) NSString *pid;
@property (copy) NSString *status;
@property (copy) NSString *seriesName;
@property (copy) NSString *episodeName;
@property (assign) BOOL complete;
@property (assign) BOOL successful;
@property (copy) NSNumber *timeadded;
@property (copy) NSString *path;
@property (assign) NSInteger season;
@property (assign) NSInteger episode;
@property (assign) BOOL processedPID;
@property (assign) BOOL radio;
@property (assign) BOOL podcast;
@property (copy) NSString *realPID;
@property (copy) NSString *subtitlePath;
@property (copy) NSString *reasonForFailure;
@property (copy) NSString *availableModes;
@property (copy) NSString *url;
@property (copy) NSString *desc;
    
//Extended Metadata
@property (assign) BOOL extendedMetadataRetrieved;
@property (assign) BOOL successfulRetrieval;
@property (assign) NSNumber *duration;
@property (copy) NSString *categories;
@property (copy) NSDate *firstBroadcast;
@property (copy) NSDate *lastBroadcast;
@property (copy) NSString *lastBroadcastString;
@property NSArray *modeSizes;
@property (copy) NSString *thumbnailURLString;
@property NSImage *thumbnail;
    
@property NSMutableString *taskOutput;
@property (nullable) NSPipe *pipe;
@property (nullable) NSPipe *errorPipe;
@property (nullable) NSTask *metadataTask;
@property (nullable) GetiPlayerProxy *getiPlayerProxy;
@property (assign) BOOL addedByPVR;
@property (readonly) GIA_ProgrammeType type;
@property (readonly, copy) NSString *typeDescription;

- (void)retrieveExtendedMetadata;
- (void)cancelMetadataRetrieval;
- (void)getName;
- (void)processGetNameData:(NSString *)getNameData;
- (void)getNameSynchronous;

@end

NS_ASSUME_NONNULL_END

