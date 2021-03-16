//
//  Programme.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/13/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "Programme.h"
#import "AppController.h"
#import "HTTPProxy.h"
//extern bool runDownloads;


@implementation Programme {
    bool getNameRunning;
}

- (instancetype)init
{
    if (self = [super init]) {
        _status = runDownloads ? @"Waiting..." : @"";
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
    [coder encodeObject: _tvNetwork forKey:@"tvNetwork"];
    [coder encodeObject: _status forKey:@"status"];
    [coder encodeObject: _path forKey:@"path"];
    [coder encodeObject: _seriesName forKey:@"seriesName"];
    [coder encodeObject: _episodeName forKey:@"episodeName"];
    [coder encodeObject: _timeadded forKey:@"timeadded"];
    [coder encodeBool: _processedPID forKey:@"processedPID"];
    [coder encodeBool: _radio forKey:@"radio"];
    [coder encodeObject: _realPID forKey:@"realPID"];
    [coder encodeObject: _url forKey:@"url"];
    [coder encodeInteger: _season forKey:@"season"];
    [coder encodeInteger: _episode forKey:@"episode"];
    [coder encodeObject: _lastBroadcast forKey:@"lastBroadcast"];
    [coder encodeObject: _lastBroadcastString forKey:@"lastBroadcastString"];
}

- (instancetype) initWithCoder: (NSCoder *)coder {
    if (self = [super init]) {
        _pid = [coder decodeObjectForKey:@"pid"];
        _showName = [coder decodeObjectForKey:@"showName"];
        _tvNetwork = [coder decodeObjectForKey:@"tvNetwork"];
        _status = [coder decodeObjectForKey:@"status"];
        _complete = NO;
        _successful = NO;
        _path = [coder decodeObjectForKey:@"path"];
        _seriesName = [coder decodeObjectForKey:@"seriesName"];
        _episodeName = [coder decodeObjectForKey:@"episodeName"];
        _timeadded = [coder decodeObjectForKey:@"timeadded"];
        _processedPID = [coder decodeBoolForKey:@"processedPID"];
        _radio = [coder decodeBoolForKey:@"radio"];
        _realPID = [coder decodeObjectForKey:@"realPID"];
        _url = [coder decodeObjectForKey:@"url"];
        _subtitlePath = @"";
        _reasonForFailure = @"";
        _availableModes = @"";
        _desc = @"";
        getNameRunning = false;
        _addedByPVR = false;
        _season = [coder decodeIntegerForKey:@"season"];
        _episode = [coder decodeIntegerForKey:@"episode"];
        _lastBroadcast = [coder decodeObjectForKey:@"lastBroadcast"];
        _lastBroadcastString = [coder decodeObjectForKey:@"lastBroadcastString"];
    }
    return self;
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

    // Cancel any pending request.
    [self cancelMetadataRetrieval];
    self.taskOutput = [NSMutableString new];
    self.metadataTask = [NSTask new];
    self.pipe = [NSPipe new];
    self.errorPipe = [NSPipe new];
    
    self.metadataTask.launchPath = [[AppController sharedController] perlBinaryPath];
    NSString *profileDirPath = [[NSFileManager defaultManager] applicationSupportDirectory];
    NSString *profileArg = [NSString stringWithFormat:@"--profile-dir=%@", profileDirPath];
    
    NSMutableArray *args = [NSMutableArray arrayWithArray:@[[[AppController sharedController] getiPlayerPath],
                                                            @"--nopurge",
                                                            @"--nocopyright",
                                                            @"-e60480000000000000",
                                                            @"--info",
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
    
    self.metadataTask.arguments = args;

    BOOL verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose"];

    if (verbose) {
        NSLog(@"get metadata args: %@", args);
    }

    self.metadataTask.standardOutput = self.pipe;
    self.metadataTask.standardError = self.errorPipe;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataRetrievalDataReady:) name:NSFileHandleReadCompletionNotification object:self.pipe.fileHandleForReading];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataRetrievalDataReady:) name:NSFileHandleReadCompletionNotification object:self.errorPipe.fileHandleForReading];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataRetrievalFinished:) name:NSTaskDidTerminateNotification object:self.metadataTask];
    
    NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:self.metadataTask.environment];
    envVariableDictionary[@"HOME"] = (@"~").stringByExpandingTildeInPath;
    envVariableDictionary[@"PERL_UNICODE"] = @"AS";
    envVariableDictionary[@"PATH"] = [[AppController sharedController] perlEnvironmentPath];
    self.metadataTask.environment = envVariableDictionary;
    [self.metadataTask launch];

    [self.pipe.fileHandleForReading readInBackgroundAndNotify];
    [self.errorPipe.fileHandleForReading readInBackgroundAndNotify];
}

-(void)metadataRetrievalDataReady:(NSNotification *)n
{
    NSData *d = [n.userInfo valueForKey:NSFileHandleNotificationDataItem];

    if (d.length > 0) {
        NSString *s = [[NSString alloc] initWithData:d
                                            encoding:NSUTF8StringEncoding];

        // Log, but don't parse error output.
        if (![s hasPrefix:@"INFO:"] && ![s hasPrefix:@"ERROR:"]) {
            [self.taskOutput appendString:s];
        }

        [_logger addToLog:s :self];
    }
    NSFileHandle *fh = [n.userInfo valueForKey:NSFileHandleNotificationFileHandleItem];
    [fh readInBackgroundAndNotify];
}

-(void)metadataRetrievalFinished:(NSNotification *)n
{
    self.metadataTask = nil;
    self.pipe = nil;
    self.errorPipe = nil;

    _categories = [self scanField:@"categories" fromList:_taskOutput];
    
    self.desc = [self scanField:@"desc" fromList:_taskOutput];

    NSString *durationTemp = [self scanField:@"duration" fromList:_taskOutput];
    if (durationTemp) {
        if ([durationTemp hasSuffix:@"min"])
            self.duration = @(durationTemp.integerValue);
        else
            self.duration = @(durationTemp.integerValue/60);
    }
    
    self.firstBroadcast = [self processDate:[self scanField:@"firstbcast" fromList:_taskOutput]];
    self.lastBroadcast = [self processDate:[self scanField:@"lastbcast" fromList:_taskOutput]];
    
    self.seriesName = [self scanField:@"longname" fromList:_taskOutput];
    self.episodeName = [self scanField:@"episode" fromList:_taskOutput];
    
    NSString *seasonNumber = [self scanField:@"seriesnum" fromList:_taskOutput];
    if (seasonNumber) {
        self.season = seasonNumber.integerValue;
    }
    
    NSString *episodeNumber = [self scanField:@"episodenum" fromList:_taskOutput];
    if (episodeNumber) {
        self.episode = episodeNumber.integerValue;
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
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"hvf[a-z]+[1-9]=[0-9]+MB" options:0 error:nil];
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

    self.modeSizes = array;
    NSString *thumbURL = [self scanField:@"thumbnail" fromList:_taskOutput];
    
    if (thumbURL) {
        NSLog(@"URL: %@", thumbURL);
        NSURLSessionDownloadTask *downloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:[NSURL URLWithString:thumbURL]
                                                                                 completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                                                     NSData *thumbnailData = nil;
                                                                                     if (location) {
                                                                                         thumbnailData = [NSData dataWithContentsOfURL:location];
                                                                                     }
                                                                                     [self thumbnailRequestFinished:thumbnailData];
                                                                                 }];

        [downloadTask resume];
    }
}

- (void)thumbnailRequestFinished:(nullable NSData *)thumbnailData
{
    if (thumbnailData) {
        self.thumbnail = [[NSImage alloc] initWithData:thumbnailData];
    }
    self.successfulRetrieval = YES;
    self.extendedMetadataRetrieved = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ExtendedInfoRetrieved" object:self];
    
}

-(NSString *)scanField:(NSString *)field fromList:(NSString *)list
{
    NSString *buffer;
    NSScanner *scanner = [NSScanner scannerWithString:list];
    [scanner scanUpToString:[NSString stringWithFormat:@"%@:",field] intoString:nil];
    [scanner scanString:[NSString stringWithFormat:@"%@:",field] intoString:nil];
    [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
    [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&buffer];
    return buffer;
}

-(NSDate *)processDate:(NSString *)date
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZZZ";
    
    if (date) {
        date = [self scanField:@"default" fromList:date];
        if (date) {
            return [dateFormatter dateFromString:date];
        }
    }
    return nil;
}

-(void)cancelMetadataRetrieval
{
    if (self.metadataTask.running) {
        [self.metadataTask interrupt];
        [self.logger addToLog:@"Metadata Retrieval Cancelled" :self];
    }

    self.metadataTask = nil;
    self.pipe = nil;
    self.errorPipe = nil;
}

- (GIA_ProgrammeType)type
{
    if (_radio)
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
    @autoreleasepool {
        getNameRunning = true;
        
        NSTask *getNameTask = [[NSTask alloc] init];
        NSPipe *getNamePipe = [[NSPipe alloc] init];
        NSMutableString *getNameData = [NSMutableString new];
        NSString *listArgument = @"--listformat=<index>|<pid>|<type>|<name>|<episode>|<channel>|<available>|<web>";
        NSString *fieldsArgument = @"--fields=index,pid";
        NSString *wantedID = _pid;
        NSString *cacheExpiryArg = [[GetiPlayerArguments sharedController] cacheExpiryArgument:nil];
        NSArray *args = @[[[AppController sharedController] getiPlayerPath],
                          @"--nocopyright",
                          @"--nopurge",
                          cacheExpiryArg,
                          [[GetiPlayerArguments sharedController] typeArgumentForCacheUpdate:NO andIncludeITV:YES],
                          listArgument,
                          [GetiPlayerArguments sharedController].profileDirArg,
                          fieldsArgument,
                          wantedID];
        getNameTask.arguments = args;
        getNameTask.launchPath = [[AppController sharedController] perlBinaryPath];
        
        getNameTask.standardOutput = getNamePipe;
        NSFileHandle *getNameFh = getNamePipe.fileHandleForReading;
        NSData *inData;
        
        NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:getNameTask.environment];
        envVariableDictionary[@"HOME"] = (@"~").stringByExpandingTildeInPath;
        envVariableDictionary[@"PERL_UNICODE"] = @"AS";
        envVariableDictionary[@"PATH"] = [[AppController sharedController] perlEnvironmentPath];
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
    NSString *wantedID = self.pid;
    BOOL found = NO;

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZZZ";

    for (NSString *string in array)
    {
        // TODO: remove use of index in future version
        NSArray *elements = [string componentsSeparatedByString:@"|"];
        if (elements.count < 8) {
            continue;
        }

        NSString *pid, *showName, *episode, *index, *type, *tvNetwork, *url, *dateAired;
        @try{
            index = elements[0];
            pid = elements[1];
            type = elements[2];
            showName = elements[3];
            episode = elements[4];
            tvNetwork = elements[5];
            dateAired = elements[6];
            url = elements[7];
        }
        @catch (NSException *e) {
            NSAlert *getNameException = [[NSAlert alloc] init];
            [getNameException addButtonWithTitle:@"OK"];
            getNameException.messageText = [NSString stringWithFormat:@"Unknown Error!"];
            getNameException.informativeText = @"An unknown error occured whilst trying to parse Get_iPlayer output (processGetNameData).";
            getNameException.alertStyle = NSAlertStyleWarning;
            [getNameException runModal];
            getNameException = nil;
        }

        if ([wantedID isEqualToString:pid] || [wantedID isEqualToString:index]) {
            found=YES;
            self.showName = showName;
            self.episodeName = episode;
            self.lastBroadcast = [dateFormatter dateFromString:dateAired];
            self.lastBroadcastString = [NSDateFormatter localizedStringFromDate:self.lastBroadcast dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterNoStyle];

            if (pid.length > 0) {
                self.pid = pid;
            }
            
            if (tvNetwork.length > 0) {
                self.tvNetwork = tvNetwork;
            }
            
            if (url) {
                self.url = url;
            }
            
            self.status = runDownloads ? @"Waiting..." : @"Available";
            
            if ([type isEqualToString:@"radio"]) {
                self.radio = YES;
            }
        }

        break;
    }

    self.processedPID = found;

    if (!found) {
        if ([self.showName isEqualToString:@""]) {
            self.showName = @"Retrieving Metadata...";
            self.status = @"Unknown: Not in cache";
        }
        
        self.processedPID = NO;
        [self getNameFromPID];
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
        NSString *pidArgument = @"--pid";
        NSString *cacheExpiryArg = [[GetiPlayerArguments sharedController] cacheExpiryArgument:nil];
        NSMutableArray *args = [[NSMutableArray alloc] initWithObjects:
                                [[AppController sharedController] getiPlayerPath],
                                @"--nocopyright",
                                @"--nopurge",
                                versionArg,
                                cacheExpiryArg,
                                [GetiPlayerArguments sharedController].profileDirArg,
                                infoArgument,
                                pidArgument,
                                self.pid,
                                nil];
        
        if (proxyDict[@"proxy"]) {
            if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue]) //Don't need proxy
            {
                [args addObject:[NSString stringWithFormat:@"-p%@",[proxyDict[@"proxy"] url]]];
            }
            
        }

        // Leave this commented out for now in case I need to debug it later.
        //        BOOL verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose"];
        //
        //        if (verbose) {
        //            [args addObject:@"--verbose"];
        //            for (NSString *arg in args) {
        //                [[NSNotificationCenter defaultCenter] postNotificationName:@"AddToLog" object:nil userInfo:@{@"message": arg}];
        //            }
        //        }
        
        getNameTask.arguments = args;
        getNameTask.launchPath = [[AppController sharedController] perlBinaryPath];
        
        getNameTask.standardOutput = getNamePipe;
        NSFileHandle *getNameFh = getNamePipe.fileHandleForReading;
        NSData *inData;
        
        NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:getNameTask.environment];
        envVariableDictionary[@"HOME"] = (@"~").stringByExpandingTildeInPath;
        envVariableDictionary[@"PERL_UNICODE"] = @"AS";
        envVariableDictionary[@"PATH"] = [[AppController sharedController] perlEnvironmentPath];
        getNameTask.environment = envVariableDictionary;
        [getNameTask launch];
        
        while ((inData = getNameFh.availableData) && inData.length) {
            NSString *tempData = [[NSString alloc] initWithData:inData encoding:NSUTF8StringEncoding];
            [getNameData appendString:tempData];
        }
        [self performSelectorOnMainThread:@selector(processGetNameDataFromPID:) withObject:getNameData waitUntilDone:YES];
        getNameRunning = false;
        getNameTask = nil;
        getNamePipe = nil;
    }
}

- (void)processGetNameDataFromPID:(NSString *)getNameData
{
    NSArray *array = [getNameData componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *available = nil, *name = @"", *series = @"", *episode = @"", *type = @"";
    NSDate *broadcastDate = nil;
    
    for (NSString *string in array)
    {
        // get_iplayer reports back "(available versions: none)" if a PID is invalid or unavailable for any reason.
        // If we don't find that string we can assume it's available in some format.
        if ([string containsString:@"(available versions: "]) {
            NSScanner *scanner = [NSScanner scannerWithString:string];
            [scanner scanString:@"(available versions: " intoString:nil];
            [scanner scanUpToString:@")" intoString:&available];
            available = [available stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
        
        if ([string hasPrefix:@"name:"]) {
            NSScanner *scanner = [NSScanner scannerWithString:string];
            [scanner scanString:@"name:" intoString:nil];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&name];
            name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
        if ([string hasPrefix:@"nameshort:"]) {
            NSScanner *scanner = [NSScanner scannerWithString:string];
            [scanner scanString:@"nameshort:" intoString:nil];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&series];
            series = [series stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }

        if ([string hasPrefix:@"episodeshort:"]) {
            NSScanner *scanner = [NSScanner scannerWithString:string];
            [scanner scanString:@"episodeshort:" intoString:nil];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&episode];
            episode = [episode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
        if ([string hasPrefix:@"type:"]) {
            NSScanner *scanner = [NSScanner scannerWithString:string];
            [scanner scanString:@"type:" intoString:nil];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&type];
            type = [type stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
        // firstbcastdate: 2005-04-09
        
        if ([string hasPrefix:@"firstbcastdate:"]) {
            NSString *dateString = nil;
            NSScanner *scanner = [NSScanner scannerWithString:string];
            [scanner scanString:@"firstbcastdate:" intoString:nil];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&dateString];
            dateString = [dateString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSDateFormatter *shortDateFormatter = [[NSDateFormatter alloc] init];
            shortDateFormatter.dateFormat = @"yyyy-MM-dd";
            broadcastDate = [shortDateFormatter dateFromString:dateString];
            
        }
    }
    
    if ([available isEqualToString:@"none"]) {
        self.status = @"Not Available";
    } else {
        self.status = @"Available";
    }
    
    if (broadcastDate) {
        self.lastBroadcast = broadcastDate;
        self.lastBroadcastString = [NSDateFormatter localizedStringFromDate:broadcastDate
                                                               dateStyle:NSDateFormatterMediumStyle
                                                               timeStyle:NSDateFormatterNoStyle];
    }
    
    if ([type isEqualToString:@"radio"]) {
        self.radio = YES;
    }
    
    if (name) {
        self.showName = name;
    } else {
        self.showName = @"Unknown: PID Not Found";
    }
    self.seriesName = series;
    self.episodeName = episode;
    self.processedPID = NO;
}

@end
