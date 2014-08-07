//
//  Programme.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/13/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "Programme.h"
#import "NSString+HTML.h"
#import "AppController.h"
#import "HTTPProxy.h"
#import "ASIHTTPRequest.h"
//extern bool runDownloads;


@implementation Programme
- (id)initWithLogController:(LogController *)logger
{
   if (![self init]) return nil;
   self->logger = logger;
   return self;
}
- (id)initWithInfo:(id)sender pid:(NSString *)PID programmeName:(NSString *)SHOWNAME network:(NSString *)TVNETWORK logController:(LogController *)logger
{
	if (!(self = [super init])) return nil;
   self->logger = logger;
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
   extendedMetadataRetrieved=@NO;
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
   extendedMetadataRetrieved=@NO;
	return self;
}
- (id)init
{
   if (!(self = [super init])) return nil;
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
   extendedMetadataRetrieved=@NO;
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
   extendedMetadataRetrieved=@NO;
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

-(void)retrieveExtendedMetadata
{
   [logger addToLog:@"Retrieving Extended Metadata" :self];
   [[AppController sharedController] loadProxyInBackgroundForSelector:@selector(proxyRetrievalFinished:proxyError:) withObject:nil onTarget:self];
}

-(void)proxyRetrievalFinished:(id)sender proxyError:(NSError *)proxyError
{
   taskOutput = [[NSMutableString alloc] init];
   metadataTask = [[NSTask alloc] init];
   pipe = [[NSPipe alloc] init];   
   
   [metadataTask setLaunchPath:@"/usr/bin/perl"];
   NSMutableArray *args = [NSMutableArray arrayWithArray:@[[[NSBundle mainBundle] pathForResource:@"get_iplayer" ofType:@"pl"],
                                                           @"--nopurge",
                                                           @"--nocopyright",
                                                           @"-e60480000000000000",
                                                           @"-i",
                                                           [NSString stringWithFormat:@"--profile-dir=%@",[@"~/Library/Application Support/Get iPlayer Automator/" stringByExpandingTildeInPath]],pid]];
   if ([AppController sharedController].proxy) {
      [args addObject:[NSString stringWithFormat:@"-p%@",[AppController sharedController].proxy.url]];
      
      if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue])
      {
         [args addObject:@"--partial-proxy"];
      }
      
   }
   
   [metadataTask setArguments:args];
   
   [metadataTask setStandardOutput:pipe];
   NSFileHandle *fh = [pipe fileHandleForReading];
   
   [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataRetrievalDataReady:) name:NSFileHandleReadCompletionNotification object:fh];
   [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataRetrievalFinished:) name:NSTaskDidTerminateNotification object:metadataTask];
   
   [metadataTask launch];
   [fh readInBackgroundAndNotify];
}

-(void)metadataRetrievalDataReady:(NSNotification *)n
{
   NSData *d = [[n userInfo] valueForKey:NSFileHandleNotificationDataItem];
	
   if ([d length] > 0) {
		NSString *s = [[NSString alloc] initWithData:d
                                          encoding:NSUTF8StringEncoding];
		
		[taskOutput appendString:s];
      [logger addToLog:s :self];
      [[pipe fileHandleForReading] readInBackgroundAndNotify];
	}
   else {
      [self metadataRetrievalFinished:nil];
   }
}

-(void)metadataRetrievalFinished:(NSNotification *)n
{
   taskRunning=NO;
   categories = [self scanField:@"categories" fromList:taskOutput];
   
   NSString *descTemp = [self scanField:@"desc" fromList:taskOutput];
   if (descTemp) {
      desc = descTemp;
   }
   
   NSString *durationTemp = [self scanField:@"duration" fromList:taskOutput];
   if (durationTemp) {
      if ([durationTemp hasSuffix:@"min"])
         duration = [NSNumber numberWithInteger:[durationTemp integerValue]];
      else
         duration = [NSNumber numberWithInteger:[durationTemp integerValue]/60];
   }
   
   firstBroadcast = [self processDate:[self scanField:@"firstbcast" fromList:taskOutput]];
   lastBroadcast = [self processDate:[self scanField:@"lastbcast" fromList:taskOutput]];
   
   seriesName = [self scanField:@"longname" fromList:taskOutput];

   episodeName = [self scanField:@"episode" fromList:taskOutput];
   
   NSString *seasonNumber = [self scanField:@"seriesnum" fromList:taskOutput];
   if (seasonNumber) {
      season = [seasonNumber integerValue];
   }
   
   NSString *episodeNumber = [self scanField:@"episodenum" fromList:taskOutput];
   if (episodeNumber) {
      episode = [episodeNumber integerValue];
   }
   NSString *modeSizesString = [self scanField:@"modesizes" fromList:taskOutput];
   if (modeSizesString) {
      NSScanner *sizeScanner = [NSScanner scannerWithString:modeSizesString];
      [sizeScanner scanString:@"default:" intoString:nil];
      NSString *newSizesString;
      [sizeScanner scanUpToString:@":" intoString:&newSizesString];
      
      NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[a-z]*[0-2]=[0-9]*MB" options:0 error:nil];
      NSArray *matches = [regex matchesInString:newSizesString options:0 range:NSMakeRange(0, [newSizesString length])];
      if ([matches count] > 0) {
         NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
         for (NSTextCheckingResult *modesizeResult in matches) {
            NSString *modesize = [newSizesString substringWithRange:modesizeResult.range];
            if ([modesize hasPrefix:@"rtsp"] || [modesize hasPrefix:@"wma"]) {
               continue;
            }
            NSArray *comps = [modesize componentsSeparatedByString:@"="];
            if ([comps count] == 2) {
               [dictionary setObject:comps[1] forKey:comps[0]];
            }
         }
         modeSizes = dictionary;
      }
   }
   NSString *thumbURL = [self scanField:@"thumbnail4" fromList:taskOutput];
   if (!thumbURL) {
      thumbURL = [self scanField:@"thumbnail" fromList:taskOutput];
   }
   if (thumbURL) {
      NSLog(@"URL: %@", thumbURL);
      ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:thumbURL]];
      [request setDelegate:self];
      [request setDidFinishSelector:@selector(thumbnailRequestFinished:)];
      [request setDidFailSelector:@selector(thumbnailRequestFinished:)];
      [request setTimeOutSeconds:3];
      [request setNumberOfTimesToRetryOnTimeout:3];
      [request startAsynchronous];
   }
}

- (void)thumbnailRequestFinished:(ASIHTTPRequest *)request
{
   if (request.responseStatusCode == 200) {
      thumbnail = [[NSImage alloc] initWithData:request.responseData];
   }
   successfulRetrieval = @YES;
   extendedMetadataRetrieved = @YES;
   [[NSNotificationCenter defaultCenter] postNotificationName:@"ExtendedInfoRetrieved" object:self];
   
}

-(NSString *)scanField:(NSString *)field fromList:(NSString *)list
{
   NSString __autoreleasing *buffer;
   
   NSScanner *scanner = [NSScanner scannerWithString:list];
   [scanner scanUpToString:[NSString stringWithFormat:@"%@:",field] intoString:nil];
   [scanner scanString:[NSString stringWithFormat:@"%@:",field] intoString:nil];
   [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
   [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&buffer];
   
   return [buffer copy];
}

-(NSDate *)processDate:(NSString *)date
{
   NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
   if (NSAppKitVersionNumber >= NSAppKitVersionNumber10_8) //10.8, 10.9
      [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZZZ"];
   else //10.7
      [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ssZZ"];
   
   if (date) {
      date = [self scanField:@"default" fromList:date];
      if (date) {
         if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_8) { //Before 10.9 doesn't recognize the Z
            if ([date hasSuffix:@"Z"]) {
               date = [date stringByReplacingOccurrencesOfString:@"Z" withString:@"+00:00"];
            }
         }
         if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_7) {
            date = [date stringByReplacingCharactersInRange:NSMakeRange(date.length - 3, 1) withString:@""];
         }
         return [dateFormatter dateFromString:date];
      }
   }
   return nil;
}

-(void)cancelMetadataRetrieval
{
   if ([metadataTask isRunning]) {
      [metadataTask interrupt];
   }
   [logger addToLog:@"Metadata Retrieval Cancelled" :self];
}

- (GIA_ProgrammeType)type
{
   if (radio.boolValue)
      return GiA_ProgrammeTypeBBC_Radio;
   else if (podcast.boolValue)
      return GiA_ProgrammeTypeBBC_Podcast;
   else if ([tvNetwork hasPrefix:@"ITV"])
      return GIA_ProgrammeTypeITV;
   else
      return GiA_ProgrammeTypeBBC_TV;   
}

- (NSString *)typeDescription
{
   NSDictionary *dic = @{@(GiA_ProgrammeTypeBBC_TV): @"BBC TV",
                         @(GiA_ProgrammeTypeBBC_Radio): @"BBC Radio",
                         @(GiA_ProgrammeTypeBBC_Podcast): @"BBC Podcast",
                         @(GIA_ProgrammeTypeITV): @"ITV"};
   
   return [dic objectForKey:@([self type])];
}

- (BOOL)isEqual:(id)object
{
   if ([object isKindOfClass:[self class]]) {
      Programme *otherP = (Programme *)object;
      return [otherP.showName isEqual:showName] && [otherP.pid isEqual:pid];
   }
   else {
      return false;
   }
}

- (void)getName
{
	NSTask *getNameTask = [[NSTask alloc] init];
	NSPipe *getNamePipe = [[NSPipe alloc] init];
	NSMutableString *getNameData = [[NSMutableString alloc] initWithString:@""];
	NSString *listArgument = @"--listformat=<index> <pid> <type> <name> - <episode>,<channel>|<web>|";
	NSString *fieldsArgument = @"--fields=index,pid";
	NSString *wantedID = pid;
	NSString *cacheExpiryArg = [[GetiPlayerArguments sharedController] cacheExpiryArgument:nil];
	NSArray *args = @[[[NSBundle mainBundle] pathForResource:@"get_iplayer" ofType:@"pl"],@"--nowarning",@"--nopurge",cacheExpiryArg,[[GetiPlayerArguments sharedController] typeArgumentForCacheUpdate:NO],listArgument,[GetiPlayerArguments sharedController].profileDirArg,fieldsArgument,wantedID];
	[getNameTask setArguments:args];
	[getNameTask setLaunchPath:@"/usr/bin/perl"];
	
	[getNameTask setStandardOutput:getNamePipe];
	NSFileHandle *getNameFh = [getNamePipe fileHandleForReading];
	NSData *inData;
	
	[getNameTask launch];
	
	while ((inData = [getNameFh availableData]) && [inData length]) {
		NSString *tempData = [[NSString alloc] initWithData:inData encoding:NSUTF8StringEncoding];
		[getNameData appendString:tempData];
	}
	[self processGetNameData:getNameData];
}

- (void)processGetNameData:(NSString *)getNameData
{
	NSArray *array = [getNameData componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
   Programme *p = self;
	int i = 0;
	NSString *wantedID = [p valueForKey:@"pid"];
	BOOL found=NO;
	for (NSString *string in array)
	{
		i++;
		if (i>1 && i<[array count]-1)
		{
			NSString *pid, *showName, *index, *type, *tvNetwork, *url;
			@try{
				NSScanner *scanner = [NSScanner scannerWithString:string];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&index];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&pid];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&type];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL];
				[scanner scanUpToString:@","  intoString:&showName];
            [scanner scanString:@"," intoString:nil];
            [scanner scanUpToString:@"|" intoString:&tvNetwork];
            [scanner scanString:@"|" intoString:nil];
            [scanner scanUpToString:@"|" intoString:&url];
				scanner = nil;
			}
			@catch (NSException *e) {
				NSAlert *getNameException = [[NSAlert alloc] init];
				[getNameException addButtonWithTitle:@"OK"];
				[getNameException setMessageText:[NSString stringWithFormat:@"Unknown Error!"]];
				[getNameException setInformativeText:@"An unknown error occured whilst trying to parse Get_iPlayer output."];
				[getNameException setAlertStyle:NSWarningAlertStyle];
				[getNameException runModal];
				getNameException = nil;
			}
			if ([wantedID isEqualToString:pid])
			{
				found=YES;
				[p setValue:showName forKey:@"showName"];
				[p setValue:index forKey:@"pid"];
            [p setValue:tvNetwork forKey:@"tvNetwork"];
            [p setUrl:url];
				if ([type isEqualToString:@"radio"]) [p setValue:@YES forKey:@"radio"];
            else if ([type isEqualToString:@"podcast"]) [p setPodcast:@YES];
			}
			else if ([wantedID isEqualToString:index])
			{
				found=YES;
				[p setValue:showName forKey:@"showName"];
            [p setValue:tvNetwork forKey:@"tvNetwork"];
            [p setUrl:url];
				if ([type isEqualToString:@"radio"]) [p setValue:@YES forKey:@"radio"];
            else if ([type isEqualToString:@"podcast"]) [p setPodcast:@YES];
			}
		}
      
	}
	if (!found)
   {
      if ([[p showName] isEqualToString:@""] || [[p showName] isEqualToString:@"Unknown: Not in Cache"])
         [p setValue:@"Unknown: Not in Cache" forKey:@"showName"];
      [p setProcessedPID:@NO];
   }
	else
		[p setProcessedPID:@YES];
	
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

@synthesize extendedMetadataRetrieved;
@synthesize successfulRetrieval;
@synthesize duration;
@synthesize categories;
@synthesize firstBroadcast;
@synthesize lastBroadcast;
@synthesize modeSizes;
@synthesize thumbnail;
@end
