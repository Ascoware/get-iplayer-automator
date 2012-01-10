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
    NSDate *dateAired;
    NSString *desc;
    NSNumber *podcast;
}
- (id)initWithInfo:(id)sender pid:(NSString *)PID programmeName:(NSString *)SHOWNAME network:(NSString *)TVNETWORK;
- (id)initWithShow:(Programme *)show;

@property (readwrite, assign) NSString *showName;
@property (readwrite, assign) NSString *tvNetwork;
@property (readwrite, assign) NSString *pid;
@property (readwrite, assign) NSString *status;
@property (readwrite, assign) NSString *seriesName;
@property (readwrite, assign) NSString *episodeName;
@property (readwrite, assign) NSNumber *complete;
@property (readwrite, assign) NSNumber *successful;
@property (readwrite, assign) NSNumber *timeadded;
@property (readwrite, assign) NSString *path;
@property (readwrite, assign) NSInteger season;
@property (readwrite, assign) NSInteger episode;
@property (readwrite, assign) NSNumber *processedPID;
@property (readwrite, assign) NSNumber *radio;
@property (readwrite, assign) NSString *realPID;
@property (readwrite, assign) NSString *subtitlePath;
@property (readwrite, assign) NSString *reasonForFailure;
@property (readwrite, assign) NSString *availableModes;
@property (readwrite, assign) NSString *url;
@property (readwrite, assign) NSDate *dateAired;
@property (readwrite, assign) NSString *desc;
@property (readwrite, assign) NSNumber *podcast;
@end
