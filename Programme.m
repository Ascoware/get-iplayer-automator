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


@implementation Programme {
    bool getNameRunning;
}

- (instancetype)initWithLogController:(LogController *)logger
{
    if (self = [self init]) {
        _logger = logger;
    }
    return self;
}

- (instancetype)initWithInfo:(id)sender pid:(NSString *)PID programmeName:(NSString *)SHOWNAME network:(NSString *)TVNETWORK logController:(LogController *)logger
{
    if (self = [super init]) {
        _logger = logger;
        _pid = [PID stringByReplacingOccurrencesOfString:@";amp" withString:@""];
        _showName = [[[NSString alloc] initWithString:SHOWNAME] stringByDecodingHTMLEntities];
        _tvNetwork = [[NSString alloc] initWithString:TVNETWORK];
        _status = [[NSString alloc] init];
        _complete = @NO;
        _successful = @NO;
        _path = @"Unknown";
        _seriesName = [[NSString alloc] init];
        _episodeName = [[NSString alloc] init];
        _timeadded = [[NSNumber alloc] init];
        _processedPID = @YES;
        _radio = @NO;
        _subtitlePath=[[NSString alloc] init];
        _realPID=[[NSString alloc] init];
        _reasonForFailure=[[NSString alloc] init];
        _availableModes=[[NSString alloc] init];
        _desc=[[NSString alloc] init];
        _extendedMetadataRetrieved=@NO;
        getNameRunning = false;
        _addedByPVR = false;
    }
    return self;
}
- (instancetype)initWithShow:(Programme *)show
{
    if (self = [super init]) {
        _pid = [[NSString alloc] initWithString:show.pid];
        _showName = [[[NSString alloc] initWithString:show.showName] stringByDecodingHTMLEntities];
        _tvNetwork = [[NSString alloc] initWithString:show.tvNetwork];
        _status = [[NSString alloc] initWithString:show.status];
        _complete = @NO;
        _successful = @NO;
        _path = [[NSString alloc] initWithString:show.path];
        _seriesName = [[NSString alloc] init];
        _episodeName = [[NSString alloc] init];
        _timeadded = [[NSNumber alloc] init];
        _processedPID = @YES;
        _radio = show.radio;
        _realPID = show.realPID;
        _subtitlePath = show.subtitlePath;
        _reasonForFailure=show.reasonForFailure;
        _availableModes=[[NSString alloc] init];
        _desc=[[NSString alloc] init];
        _extendedMetadataRetrieved=@NO;
        getNameRunning = false;
        _addedByPVR = false;
    }
    return self;
}

- (instancetype)init
{
    if (self = [super init]) {
        _pid = [[NSString alloc] init];
        _showName = [[NSString alloc] init];
        _tvNetwork = [[NSString alloc] init];
        if (runDownloads)
        {
            _status = @"Waiting...";
        }
        else
        {
            _status = [[NSString alloc] init];
        }
        _seriesName = [[NSString alloc] init];
        _episodeName = [[NSString alloc] init];
        _complete = @NO;
        _successful = @NO;
        _timeadded = [[NSNumber alloc] init];
        _path = @"Unknown";
        _processedPID = @NO;
        _radio = @NO;
        _url = [[NSString alloc] init];
        _realPID=[[NSString alloc] init];
        _subtitlePath=[[NSString alloc] init];
        _reasonForFailure=[[NSString alloc] init];
        _availableModes=[[NSString alloc] init];
        _desc=[[NSString alloc] init];
        _extendedMetadataRetrieved=@NO;
        getNameRunning = false;
        _addedByPVR = false;
    }
    return self;
}
- (id)description
{
    return [NSString stringWithFormat:@"%@: %@",_pid, _showName];
}
- (void) encodeWithCoder: (NSCoder *)coder
{
    [coder encodeObject: _showName forKey:@"showName"];
    [coder encodeObject: _pid     forKey:@"pid"];
    [coder encodeObject:_tvNetwork forKey:@"tvNetwork"];
    [coder encodeObject:_status forKey:@"status"];
    [coder encodeObject:_path forKey:@"path"];
    [coder encodeObject:_seriesName forKey:@"seriesName"];
    [coder encodeObject:_episodeName forKey:@"episodeName"];
    [coder encodeObject:_timeadded forKey:@"timeadded"];
    [coder encodeObject:_processedPID forKey:@"processedPID"];
    [coder encodeObject:_radio forKey:@"radio"];
    [coder encodeObject:_realPID forKey:@"realPID"];
    [coder encodeObject:_url forKey:@"url"];
    [coder encodeInteger:_season forKey:@"season"];
    [coder encodeInteger:_episode forKey:@"episode"];
}
- (instancetype) initWithCoder: (NSCoder *)coder {
    if (self = [super init]) {
        _pid = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"pid"]];
        _showName = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"showName"]];
        _tvNetwork = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"tvNetwork"]];
        _status = @"";
        _complete = @NO;
        _successful = @NO;
        _path = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"path"]];
        _seriesName = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"seriesName"]];
        _episodeName = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"episodeName"]];
        _timeadded = [coder decodeObjectForKey:@"timeadded"];
        _processedPID = [coder decodeObjectForKey:@"processedPID"];
        _radio = [coder decodeObjectForKey:@"radio"];
        _realPID = [coder decodeObjectForKey:@"realPID"];
        _url = [coder decodeObjectForKey:@"url"];
        _subtitlePath=[[NSString alloc] init];
        _reasonForFailure=[[NSString alloc] init];
        _availableModes=[[NSString alloc] init];
        _desc=[[NSString alloc] init];
        _extendedMetadataRetrieved=@NO;
        getNameRunning = false;
        _addedByPVR = false;
        _season = [coder decodeIntegerForKey:@"season"];
        _episode = [coder decodeIntegerForKey:@"episode"];
    }
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
    _pid = [newPID stringByReplacingOccurrencesOfString:@"amp;" withString:@""];
}

-(void)printLongDescription
{
    NSLog(@"%@:\n   TV Network: %@\n   Processed PID: %@\n   Real PID: %@\n   Available Modes: %@\n   URL: %@\n",
          _showName,_tvNetwork,_processedPID,_realPID,_availableModes,_url);
}

-(void)retrieveExtendedMetadata
{
    [_logger addToLog:@"Retrieving Extended Metadata" :self];
    _getiPlayerProxy = [[GetiPlayerProxy alloc] initWithLogger:_logger];
    [_getiPlayerProxy loadProxyInBackgroundForSelector:@selector(proxyRetrievalFinished:proxyDict:) withObject:nil onTarget:self silently:NO];
}

-(void)proxyRetrievalFinished:(id)sender proxyDict:(NSDictionary *)proxyDict
{
    _getiPlayerProxy = nil;
    if (proxyDict && [proxyDict[@"error"] code] == kProxyLoadCancelled)
        return;
    
    _taskOutput = [[NSMutableString alloc] init];
    _metadataTask = [[NSTask alloc] init];
    _pipe = [[NSPipe alloc] init];
    
    _metadataTask.launchPath = @"/usr/bin/perl";
    NSString *profileDirPath = [@"~/Library/Application Support/Get iPlayer Automator/" stringByExpandingTildeInPath];
    NSString *profileArg = [NSString stringWithFormat:@"--profile-dir=%@", profileDirPath];
    
    NSMutableArray *args = [NSMutableArray arrayWithArray:@[[[NSBundle mainBundle] pathForResource:@"get_iplayer" ofType:@"pl"],
                                                            @"--nopurge",
                                                            @"--nocopyright",
                                                            @"-e60480000000000000",
                                                            @"-i",
                                                            profileArg,
                                                            @"--pid",
                                                            _pid]];
    if (proxyDict[@"proxy"]) {
        [args addObject:[NSString stringWithFormat:@"-p%@",[proxyDict[@"proxy"] url]]];
        
        if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue])
        {
            [args addObject:@"--partial-proxy"];
        }
        
    }
    
    _metadataTask.arguments = args;
    
    _metadataTask.standardOutput = _pipe;
    NSFileHandle *fh = _pipe.fileHandleForReading;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataRetrievalDataReady:) name:NSFileHandleReadCompletionNotification object:fh];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataRetrievalFinished:) name:NSTaskDidTerminateNotification object:_metadataTask];
    
    NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:_metadataTask.environment];
    envVariableDictionary[@"HOME"] = (@"~").stringByExpandingTildeInPath;
    envVariableDictionary[@"PERL_UNICODE"] = @"AS";
    _metadataTask.environment = envVariableDictionary;
    [_metadataTask launch];
    [fh readInBackgroundAndNotify];
}

-(void)metadataRetrievalDataReady:(NSNotification *)n
{
    NSData *d = [n.userInfo valueForKey:NSFileHandleNotificationDataItem];
    
    if (d.length > 0) {
        NSString *s = [[NSString alloc] initWithData:d
                                            encoding:NSUTF8StringEncoding];
        
        [_taskOutput appendString:s];
        [_logger addToLog:s :self];
        [_pipe.fileHandleForReading readInBackgroundAndNotify];
    }
    else {
        [self metadataRetrievalFinished:nil];
    }
}

-(void)metadataRetrievalFinished:(NSNotification *)n
{
    _taskRunning=NO;
    _categories = [self scanField:@"categories" fromList:_taskOutput];
    
    NSString *descTemp = [self scanField:@"desc" fromList:_taskOutput];
    if (descTemp) {
        _desc = descTemp;
    }
    
    NSString *durationTemp = [self scanField:@"duration" fromList:_taskOutput];
    if (durationTemp) {
        if ([durationTemp hasSuffix:@"min"])
            _duration = @(durationTemp.integerValue);
        else
            _duration = @(durationTemp.integerValue/60);
    }
    
    _firstBroadcast = [self processDate:[self scanField:@"firstbcast" fromList:_taskOutput]];
    _lastBroadcast = [self processDate:[self scanField:@"lastbcast" fromList:_taskOutput]];
    
    _seriesName = [self scanField:@"longname" fromList:_taskOutput];
    
    _episodeName = [self scanField:@"episode" fromList:_taskOutput];
    
    NSString *seasonNumber = [self scanField:@"seriesnum" fromList:_taskOutput];
    if (seasonNumber) {
        _season = seasonNumber.integerValue;
    }
    
    NSString *episodeNumber = [self scanField:@"episodenum" fromList:_taskOutput];
    if (episodeNumber) {
        _episode = episodeNumber.integerValue;
    }
    // determine default version
    NSString *default_version = nil;
    NSString *info_versions = [self scanField:@"versions" fromList:_taskOutput];
    NSArray *versions = [info_versions componentsSeparatedByString:@","];
    for (NSString *version in versions) {
        if (([version isEqualToString:@"default"]) ||
            ([version isEqualToString:@"original"] && ![default_version isEqualToString:@"default"]) ||
            (!default_version && ![version isEqualToString:@"signed"] && ![version isEqualToString:@"audiodescribed"])) {
            default_version = version;
        }
    }
    // parse mode sizes
    NSMutableArray *array = [NSMutableArray array];
    NSScanner *sizeScanner = [NSScanner scannerWithString:_taskOutput];
    [sizeScanner scanUpToString:@"modesizes:" intoString:nil];
    while ([sizeScanner scanString:@"modesizes:" intoString:nil]) {
        NSString *version = nil;
        [sizeScanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
        [sizeScanner scanUpToString:@":" intoString:&version];
        if (![version isEqualToString:default_version] && ![version isEqualToString:@"signed"] && ![version isEqualToString:@"audiodescribed"]) {
            [sizeScanner scanUpToString:@"modesizes:" intoString:nil];
            continue;
        }
        NSString *group = nil;
        if ([version isEqualToString:default_version]) {
            group = @"A";
        }
        else if ([version isEqualToString:@"signed"]) {
            group = @"C";
        }
        else if ([version isEqualToString:@"audiodescribed"]) {
            group = @"D";
        }
        else {
            group = @"B";
        }
        NSString *newSizesString;
        [sizeScanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
        [sizeScanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&newSizesString];
        // TODO: adjust with switch to HLS
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"flash[a-z]+[1-9]=[0-9]+MB" options:0 error:nil];
        NSArray *matches = [regex matchesInString:newSizesString options:0 range:NSMakeRange(0, newSizesString.length)];
        if (matches.count > 0) {
            for (NSTextCheckingResult *modesizeResult in matches) {
                NSString *modesize = [newSizesString substringWithRange:modesizeResult.range];
                NSArray *comps = [modesize componentsSeparatedByString:@"="];
                if (comps.count == 2) {
                    NSMutableDictionary *item = [NSMutableDictionary dictionary];
                    if ([version isEqualToString:default_version]) {
                        item[@"version"] = @"default";
                    }
                    else {
                        item[@"version"] = version;
                    }
                    item[@"mode"] = comps[0];
                    item[@"size"] = comps[1];
                    item[@"group"] = group;
                    [array addObject:item];
                }
            }
        }
        [sizeScanner scanUpToString:@"modesizes:" intoString:nil];
    }
    _modeSizes = array;
    NSString *thumbURL = [self scanField:@"thumbnail4" fromList:_taskOutput];
    if (!thumbURL) {
        thumbURL = [self scanField:@"thumbnail" fromList:_taskOutput];
    }
    if (thumbURL) {
        NSLog(@"URL: %@", thumbURL);
        ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:thumbURL]];
        request.delegate = self;
        request.didFinishSelector = @selector(thumbnailRequestFinished:);
        request.didFailSelector = @selector(thumbnailRequestFinished:);
        request.timeOutSeconds = 3;
        request.numberOfTimesToRetryOnTimeout = 3;
        [request startAsynchronous];
    }
}

- (void)thumbnailRequestFinished:(ASIHTTPRequest *)request
{
    if (request.responseStatusCode == 200) {
        _thumbnail = [[NSImage alloc] initWithData:request.responseData];
    }
    _successfulRetrieval = @YES;
    _extendedMetadataRetrieved = @YES;
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
        dateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZZZ";
    else //10.7
        dateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ssZZ";
    
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
    if (_metadataTask.running) {
        [_metadataTask interrupt];
    }
    [_logger addToLog:@"Metadata Retrieval Cancelled" :self];
}

- (GIA_ProgrammeType)type
{
    if (_radio.boolValue)
        return GiA_ProgrammeTypeBBC_Radio;
    else if ([_tvNetwork hasPrefix:@"ITV"])
        return GIA_ProgrammeTypeITV;
    else
        return GiA_ProgrammeTypeBBC_TV;
}

- (NSString *)typeDescription
{
    NSDictionary *dic = @{@(GiA_ProgrammeTypeBBC_TV): @"BBC TV",
                          @(GiA_ProgrammeTypeBBC_Radio): @"BBC Radio",
                          @(GIA_ProgrammeTypeITV): @"ITV"};
    
    return dic[@([self type])];
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[self class]]) {
        Programme *otherP = (Programme *)object;
        return [otherP.showName isEqual:_showName] && [otherP.pid isEqual:_pid];
    }
    else {
        return false;
    }
}

- (void)getNameSynchronous
{
    [self getName];
    while (getNameRunning) {
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow: 0.1]];
    }
}

- (void)getName
{
    // skip if pid looks like ITV productionId
    if ([_pid rangeOfString:@"/"].location != NSNotFound ||
        [_pid rangeOfString:@"#"].location != NSNotFound) {
        
        if ( [[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheITV_TV"] isEqualTo:@YES] )
            self.status = @"New ITV Cache";
        else
            self.status = @"Undetermined-ITV";
        return;
    }
    @autoreleasepool {
        getNameRunning = true;
        
        NSTask *getNameTask = [[NSTask alloc] init];
        NSPipe *getNamePipe = [[NSPipe alloc] init];
        NSMutableString *getNameData = [[NSMutableString alloc] initWithString:@""];
        NSString *listArgument = @"--listformat=<index> <pid> <type> <name> - <episode>,<channel>|<web>|";
        NSString *fieldsArgument = @"--fields=index,pid";
        NSString *wantedID = _pid;
        NSString *cacheExpiryArg = [[GetiPlayerArguments sharedController] cacheExpiryArgument:nil];
        NSArray *args = @[[[NSBundle mainBundle] pathForResource:@"get_iplayer" ofType:@"pl"],@"--nocopyright",@"--nopurge",cacheExpiryArg,[[GetiPlayerArguments sharedController] typeArgumentForCacheUpdate:NO andIncludeITV:YES],listArgument,[GetiPlayerArguments sharedController].profileDirArg,fieldsArgument,wantedID];
        getNameTask.arguments = args;
        getNameTask.launchPath = @"/usr/bin/perl";
        
        getNameTask.standardOutput = getNamePipe;
        NSFileHandle *getNameFh = getNamePipe.fileHandleForReading;
        NSData *inData;
        
        NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:getNameTask.environment];
        envVariableDictionary[@"HOME"] = (@"~").stringByExpandingTildeInPath;
        envVariableDictionary[@"PERL_UNICODE"] = @"AS";
        getNameTask.environment = envVariableDictionary;
        [getNameTask launch];
        
        while ((inData = getNameFh.availableData) && inData.length) {
            NSString *tempData = [[NSString alloc] initWithData:inData encoding:NSUTF8StringEncoding];
            [getNameData appendString:tempData];
        }
        [self performSelectorOnMainThread:@selector(processGetNameData:) withObject:getNameData waitUntilDone:YES];
        getNameRunning = false;
    }
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
        if (i>1 && i<array.count-1)
        {
            // TODO: remove use of index in future version
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
                getNameException.messageText = [NSString stringWithFormat:@"Unknown Error!"];
                getNameException.informativeText = @"An unknown error occured whilst trying to parse Get_iPlayer output (processGetNameData).";
                getNameException.alertStyle = NSWarningAlertStyle;
                [getNameException runModal];
                getNameException = nil;
            }
            if ([wantedID isEqualToString:pid] || [wantedID isEqualToString:index])
            {
                found=YES;
                [p setValue:showName forKey:@"showName"];
                [p setValue:pid forKey:@"pid"];
                [p setValue:tvNetwork forKey:@"tvNetwork"];
                p.url = url;
                p.status = @"Available";
                if ([type isEqualToString:@"radio"]) [p setValue:@YES forKey:@"radio"];
            }
        }
        
    }
    if (!found)
    {
        if ([p.showName isEqualToString:@""] || [p.showName isEqualToString:@"Unknown: Not in Cache"])
            [p setValue:@"Unknown: Not in Cache" forKey:@"showName"];
        p.processedPID = @NO;
        [p getNameFromPID];
    }
    else
    {
        p.processedPID = @YES;
    }
    
}

- (void)getNameFromPID
{
    [_logger addToLog:@"Retrieving Metadata For PID" :self];
    _getiPlayerProxy = [[GetiPlayerProxy alloc] initWithLogger:_logger];
    [_getiPlayerProxy loadProxyInBackgroundForSelector:@selector(getNameFromPIDProxyLoadFinished:proxyDict:) withObject:nil onTarget:self silently:NO];
}

-(void)getNameFromPIDProxyLoadFinished:(id)sender proxyDict:(NSDictionary *)proxyDict
{
    [self performSelectorInBackground:@selector(spawnGetNameFromPIDThreadWitProxyDict:) withObject:proxyDict];
}

-(void)spawnGetNameFromPIDThreadWitProxyDict:(NSDictionary *)proxyDict
{
    @autoreleasepool {
        _getiPlayerProxy = nil;
        if (proxyDict && [proxyDict[@"error"] code] == kProxyLoadCancelled)
            return;
        NSTask *getNameTask = [[NSTask alloc] init];
        NSPipe *getNamePipe = [[NSPipe alloc] init];
        NSMutableString *getNameData = [[NSMutableString alloc] initWithString:@""];
        NSMutableString *versionArg = [NSMutableString stringWithString:@"--versions="];
        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"AudioDescribedNew"] boolValue])
            [versionArg appendString:@"audiodescribed,"];
        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SignedNew"] boolValue])
            [versionArg appendString:@"signed,"];
        [versionArg  appendString:@"default"];
        NSString *infoArgument = @"--info";
        NSString *pidArgument = [NSString stringWithFormat:@"--pid=%@", _pid];
        NSString *cacheExpiryArg = [[GetiPlayerArguments sharedController] cacheExpiryArgument:nil];
        NSMutableArray *args = [[NSMutableArray alloc] initWithObjects:[[NSBundle mainBundle] pathForResource:@"get_iplayer" ofType:@"pl"],@"--nocopyright",@"--nopurge",versionArg,cacheExpiryArg,[GetiPlayerArguments sharedController].profileDirArg,infoArgument,pidArgument,nil];
        if (proxyDict[@"proxy"]) {
            if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue]) //Don't need proxy
            {
                [args addObject:[NSString stringWithFormat:@"-p%@",[proxyDict[@"proxy"] url]]];
            }
            
        }
        getNameTask.arguments = args;
        getNameTask.launchPath = @"/usr/bin/perl";
        
        getNameTask.standardOutput = getNamePipe;
        NSFileHandle *getNameFh = getNamePipe.fileHandleForReading;
        NSData *inData;
        
        NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:getNameTask.environment];
        envVariableDictionary[@"HOME"] = (@"~").stringByExpandingTildeInPath;
        envVariableDictionary[@"PERL_UNICODE"] = @"AS";
        getNameTask.environment = envVariableDictionary;
        [getNameTask launch];
        
        while ((inData = getNameFh.availableData) && inData.length) {
            NSString *tempData = [[NSString alloc] initWithData:inData encoding:NSUTF8StringEncoding];
            [getNameData appendString:tempData];
        }
        [self performSelectorOnMainThread:@selector(processGetNameDataFromPID:) withObject:getNameData waitUntilDone:YES];
        getNameRunning = false;
    }
}

- (void)processGetNameDataFromPID:(NSString *)getNameData
{
    NSArray *array = [getNameData componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    Programme *p = self;
    int i = 0;
    NSString *available = nil, *versions = nil, *title = nil;
    for (NSString *string in array)
    {
        i++;
        if (i>1 && i<array.count-1)
        {
            NSString *tmp_info = nil, *tmp_title = nil;
            @try{
                NSScanner *scanner = [NSScanner scannerWithString:string];
                [scanner scanString:@"INFO:" intoString:&tmp_info];
                if (tmp_info) {
                    if (!available) {
                        [scanner scanUpToString:@"(available versions:" intoString:nil];
                        [scanner scanString:@"(available versions:" intoString:&available];
                        if (available) {
                            [scanner scanUpToString:@")" intoString:&versions];
                        }
                    }
                } else {
                    scanner.scanLocation = 0;
                    if (!title) {
                        [scanner scanString:@"title:" intoString:&tmp_title];
                        if (tmp_title) {
                            [scanner scanUpToString:@"asdfasdf" intoString:&title];
                        }
                    }
                    scanner = nil;
                    if (title) {
                        break;
                    }
                }
            }
            @catch (NSException *e) {
                NSAlert *getNameException = [[NSAlert alloc] init];
                [getNameException addButtonWithTitle:@"OK"];
                getNameException.messageText = [NSString stringWithFormat:@"Unknown Error!"];
                getNameException.informativeText = @"An unknown error occured whilst trying to parse Get_iPlayer output (processGetNameDataFromPID).";
                getNameException.alertStyle = NSWarningAlertStyle;
                [getNameException runModal];
                getNameException = nil;
            }
        }
        
    }
    if (available) {
        if (versions) {
            [p setValue:[NSString stringWithFormat:@"Available: %@", versions] forKey:@"status"];
        } else {
            [p setValue:@"Not Available" forKey:@"status"];
        }
    } else {
        [p setValue:@"Available" forKey:@"status"];
    }
    if (title) {
        [p setValue:title forKey:@"showName"];
    } else {
        [p setValue:@"Unknown: PID Not Found" forKey:@"showName"];
    }
    p.processedPID = @NO;
}

@end
