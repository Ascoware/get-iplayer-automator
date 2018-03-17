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

@interface Programme : NSObject <NSCoding>
@property (nonatomic) LogController *logger;
@property (nonatomic) NSString *tvNetwork;
@property (nonatomic) NSString *showName;
@property (nonatomic) NSString *pid;
@property (nonatomic) NSString *status;
@property (nonatomic) NSString *seriesName;
@property (nonatomic) NSString *episodeName;
@property (nonatomic) NSNumber *complete;
@property (nonatomic) NSNumber *successful;
@property (nonatomic) NSNumber *timeadded;
@property (nonatomic) NSString *path;
@property (nonatomic) NSInteger season;
@property (nonatomic) NSInteger episode;
@property (nonatomic) NSNumber *processedPID;
@property (nonatomic) NSNumber *radio;
@property (nonatomic) NSString *realPID;
@property (nonatomic) NSString *subtitlePath;
@property (nonatomic) NSString *reasonForFailure;
@property (nonatomic) NSString *availableModes;
@property (nonatomic) NSString *url;
@property (nonatomic) NSDate *dateAired;
@property (nonatomic) NSString *standardizedAirDate;
@property (nonatomic) NSString *desc;
    
    //Extended Metadata
@property (nonatomic) NSNumber *extendedMetadataRetrieved;
@property (nonatomic) NSNumber *successfulRetrieval;
@property (nonatomic) NSNumber *duration;
@property (nonatomic) NSString *categories;
@property (nonatomic) NSDate *firstBroadcast;
@property (nonatomic) NSDate *lastBroadcast;
@property (nonatomic) NSString *lastBroadcastString;
@property (nonatomic) NSArray *modeSizes;
@property (nonatomic, copy) NSImage *thumbnail;
    
@property (nonatomic) NSMutableString *taskOutput;
@property (nonatomic) NSPipe *pipe;
@property (nonatomic, assign) BOOL taskRunning;
@property (nonatomic) NSTask *metadataTask;
@property (nonatomic) GetiPlayerProxy *getiPlayerProxy;
@property (nonatomic, assign) BOOL addedByPVR;

- (instancetype)initWithPid:(NSString *)PID programmeName:(NSString *)SHOWNAME network:(NSString *)TVNETWORK logController:(LogController *)logger;
- (instancetype)initWithShow:(Programme *)show;
- (instancetype)initWithLogController:(LogController *)logger;
- (void)printLongDescription;
- (void)retrieveExtendedMetadata;
- (void)cancelMetadataRetrieval;
@property (nonatomic, readonly) GIA_ProgrammeType type;
@property (nonatomic, readonly, copy) NSString *typeDescription;
- (void)getName;
- (void)processGetNameData:(NSString *)getNameData;
- (void)getNameSynchronous;

@end

NS_ASSUME_NONNULL_END

