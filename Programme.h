//
//  Programme.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/13/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Programme : NSObject <NSCoding> {
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
}
- (id)initWithInfo:(id)sender pid:(NSString *)PID programmeName:(NSString *)SHOWNAME network:(NSString *)TVNETWORK;
- (id)initWithShow:(Programme *)show;

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
@end
