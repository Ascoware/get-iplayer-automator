//
//  Programme.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/13/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "Programme.h"
#import "NSString+HTML.h"
extern BOOL runDownloads;


@implementation Programme
- (id)initWithInfo:(id)sender pid:(NSString *)PID programmeName:(NSString *)SHOWNAME network:(NSString *)TVNETWORK
{
	if (!(self = [super init])) return nil;
	pid = [PID stringByReplacingOccurrencesOfString:@";amp" withString:@""];
	showName = [[[NSString alloc] initWithString:SHOWNAME] stringByDecodingHTMLEntities];
	tvNetwork = [[NSString alloc] initWithString:TVNETWORK];
	status = [[NSString alloc] init];
	complete = @NO;
	successful = @NO;
	path = @"Unknown";
	seriesName = [[NSString alloc] init];
	episodeName = [[NSString alloc] init];
	timeadded = [[NSNumber alloc] init];
	processedPID = @YES;
	radio = @NO;
	subtitlePath=[[NSString alloc] init];
	realPID=[[NSString alloc] init];
    reasonForFailure=[[NSString alloc] init];
    availableModes=[[NSString alloc] init];
    desc=[[NSString alloc] init];
    podcast=@NO;
	return self;
}
- (id)initWithShow:(Programme *)show
{
	pid = [[NSString alloc] initWithString:[show pid]];
	showName = [[[NSString alloc] initWithString:[show showName]] stringByDecodingHTMLEntities];
	tvNetwork = [[NSString alloc] initWithString:[show tvNetwork]];
	status = [[NSString alloc] initWithString:[show status]];
	complete = @NO;
	successful = @NO;
	path = [[NSString alloc] initWithString:[show path]];
	seriesName = [[NSString alloc] init];
	episodeName = [[NSString alloc] init];
	timeadded = [[NSNumber alloc] init];
	processedPID = @YES;
	radio = [show radio];
	realPID = [show realPID];
	subtitlePath = [show subtitlePath];
    reasonForFailure=[show reasonForFailure];
    availableModes=[[NSString alloc] init];
    desc=[[NSString alloc] init];
    podcast = [show podcast];
	return self;
}
- (id)init
{
	pid = [[NSString alloc] init];
	showName = [[NSString alloc] init];
	tvNetwork = [[NSString alloc] init];
	if (runDownloads)
	{
		status = @"Waiting...";
	}
	else
	{
		status = [[NSString alloc] init];
	}
	seriesName = [[NSString alloc] init];
	episodeName = [[NSString alloc] init];
	complete = @NO;
	successful = @NO;
	timeadded = [[NSNumber alloc] init];
	path = @"Unknown";
	processedPID = @NO;
	radio = @NO;
    url = [[NSString alloc] init];
	realPID=[[NSString alloc] init];
	subtitlePath=[[NSString alloc] init];
    reasonForFailure=[[NSString alloc] init];
    availableModes=[[NSString alloc] init];
    desc=[[NSString alloc] init];
    podcast=@NO;
	return self;
}
- (id)description
{
	return [NSString stringWithFormat:@"%@: %@",pid,showName];
}
- (void) encodeWithCoder: (NSCoder *)coder
{
	[coder encodeObject: showName forKey:@"showName"];
	[coder encodeObject: pid     forKey:@"pid"];
	[coder encodeObject:tvNetwork forKey:@"tvNetwork"];
	[coder encodeObject:status forKey:@"status"];
	[coder encodeObject:path forKey:@"path"];
	[coder encodeObject:seriesName forKey:@"seriesName"];
	[coder encodeObject:episodeName forKey:@"episodeName"];
	[coder encodeObject:timeadded forKey:@"timeadded"];
	[coder encodeObject:processedPID forKey:@"processedPID"];
	[coder encodeObject:radio forKey:@"radio"];
	[coder encodeObject:realPID forKey:@"realPID"];
    [coder encodeObject:url forKey:@"url"];
    [coder encodeObject:podcast forKey:@"podcast"];
}
- (id) initWithCoder: (NSCoder *)coder
{
	if (!(self = [super init])) return nil;
	pid = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"pid"]];
	showName = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"showName"]];
	tvNetwork = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"tvNetwork"]];
	status = @"";
	complete = @NO;
	successful = @NO;
	path = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"path"]];
	seriesName = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"seriesName"]];
	episodeName = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"episodeName"]];
	timeadded = [coder decodeObjectForKey:@"timeadded"];
	processedPID = [coder decodeObjectForKey:@"processedPID"];
	radio = [coder decodeObjectForKey:@"radio"];
	realPID = [coder decodeObjectForKey:@"realPID"];
    url = [coder decodeObjectForKey:@"url"];
	subtitlePath=[[NSString alloc] init];
    reasonForFailure=[[NSString alloc] init];
    availableModes=[[NSString alloc] init];
    desc=[[NSString alloc] init];
    podcast = [coder decodeObjectForKey:@"podcast"];
	return self;
}
/*
- (id)pasteboardPropertyListForType:(NSString *)type
{
	if ([type isEqualToString:@"com.thomaswillson.programme"])
	{
		return [NSKeyedArchiver archivedDataWithRootObject:self];
	}
}
- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
	return [NSArray arrayWithObject:@"com.thomaswillson.programme"];
}
 */
-(void)setPid:(NSString *)newPID
{
    self->pid = [newPID stringByReplacingOccurrencesOfString:@"amp;" withString:@""];
}
-(NSString *)pid
{
    return pid;
}
-(void)printLongDescription
{
    NSLog(@"%@:\n   TV Network: %@\n   Processed PID: %@\n   Real PID: %@\n   Available Modes: %@\n   URL: %@\n",
          showName,tvNetwork,processedPID,realPID,availableModes,url);
}

@synthesize showName;
@synthesize tvNetwork;
@synthesize status;
@synthesize complete;
@synthesize successful;
@synthesize path;
@synthesize seriesName;
@synthesize episodeName;
@synthesize season;
@synthesize episode;
@synthesize timeadded;
@synthesize processedPID;
@synthesize radio;
@synthesize realPID;
@synthesize subtitlePath;
@synthesize reasonForFailure;
@synthesize availableModes;
@synthesize url;
@synthesize dateAired;
@synthesize desc;
@synthesize podcast;
@end
