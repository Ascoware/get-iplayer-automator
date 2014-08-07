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

typedef NS_ENUM(NSInteger, GIA_ProgrammeType) {
   GiA_ProgrammeTypeBBC_TV,
   GiA_ProgrammeTypeBBC_Radio,
   GiA_ProgrammeTypeBBC_Podcast,
   GIA_ProgrammeTypeITV
};


@interface Programme : NSObject <NSCoding> {
   LogController *logger;
   
	NSString *tvNetwork;
	NSString *showName;
	NSString *pid;
	NSString *status;
	NSString *seriesName;
	NSString *episodeName;
	NSNumber *complete;
	NSNumber *successful;
	NSNumber *timeadded;
	NSString *path;
	NSInteger season;
	NSInteger episode;
	NSNumber *processedPID;
	NSNumber *radio;
	NSString *realPID;
	NSString *subtitlePath;
   NSString *reasonForFailure;
   NSString *availableModes;
   NSString *url;
   NSDate *__strong dateAired;
   NSString *desc;
   NSNumber *podcast;
   
   //Extended Metadata
   NSNumber *extendedMetadataRetrieved;
   NSNumber *successfulRetrieval;
   NSNumber *duration;
   NSString *categories;
   NSDate *__strong firstBroadcast;
   NSDate *__strong lastBroadcast;
   NSDictionary *modeSizes;
   NSImage *thumbnail;
   
   NSMutableString *taskOutput;
   NSPipe *pipe;
   volatile bool taskRunning;
   NSTask *metadataTask;
   GetiPlayerProxy *getiPlayerProxy;
   
}
- (id)initWithInfo:(id)sender pid:(NSString *)PID programmeName:(NSString *)SHOWNAME network:(NSString *)TVNETWORK logController:(LogController *)logger;
- (id)initWithShow:(Programme *)show;
- (id)initWithLogController:(LogController *)logger;
- (void)printLongDescription;
- (void)retrieveExtendedMetadata;
- (void)cancelMetadataRetrieval;
- (GIA_ProgrammeType)type;
- (NSString *)typeDescription;
- (void)getName;
- (void)processGetNameData:(NSString *)getNameData;

@property (readwrite) NSString *showName;
@property (readwrite) NSString *tvNetwork;
@property (readwrite) NSString *pid;
@property (readwrite) NSString *status;
@property (readwrite) NSString *seriesName;
@property (readwrite) NSString *episodeName;
@property (readwrite) NSNumber *complete;
@property (readwrite) NSNumber *successful;
@property (readwrite) NSNumber *timeadded;
@property (readwrite) NSString *path;
@property (readwrite, assign) NSInteger season;
@property (readwrite, assign) NSInteger episode;
@property (readwrite) NSNumber *processedPID;
@property (readwrite) NSNumber *radio;
@property (readwrite) NSString *realPID;
@property (readwrite) NSString *subtitlePath;
@property (readwrite) NSString *reasonForFailure;
@property (readwrite) NSString *availableModes;
@property (readwrite) NSString *url;
@property (readwrite, strong) NSDate *dateAired;
@property (readwrite) NSString *desc;
@property (readwrite) NSNumber *podcast;

@property (readwrite) NSNumber *extendedMetadataRetrieved;
@property (readwrite) NSNumber *successfulRetrieval;
@property (readwrite) NSNumber *duration;
@property (readwrite) NSString *categories;
@property (readwrite) NSDate *firstBroadcast;
@property (readwrite) NSDate *lastBroadcast;
@property (readwrite) NSDictionary *modeSizes;
@property (readwrite) NSImage *thumbnail;
@end
