//
//  GetExtendedBBCMetadata.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/10/20.
//  Copyright © 2020 Ascoware LLC. All rights reserved.
//

import Foundation

//
//  Programme.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/13/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

//extern bool runDownloads;

public class GetExtendedMetadata {

    let logger: Logging
    let pipe = Pipe()
    let task = Process()

    var taskOutput = ""

    init(log: Logging) {
        logger = log
    }

    func retrieveExtendedMetadata(program: Program) {
        logger.addToLog("Retrieving extended metadata")

        task.launchPath = perlBinaryPath.path

        let args = [
            getIPlayerPath.path,
            "--nopurge",
            "--nocopyright",
            cacheExpiryArgument,
            "-i",
            profileDirArgument,
            "--pid",
            program.pid
        ]

//        if (proxyDict[@"proxy"]) {
//        [args addObject:[NSString stringWithFormat:@"-p%@",[proxyDict[@"proxy"] url]]];
//
//        if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"AlwaysUseProxy"] boolValue])
//        {
//            [args addObject:@"--partial-proxy"];
//        }


        task.arguments = args
        task.standardOutput = pipe
        let fh = pipe.fileHandleForReading

        NotificationCenter.default.addObserver(self, selector: #selector(metadataRetrievalDataReady), name: .NSFileHandleDataAvailable, object: fh)
        NotificationCenter.default.addObserver(self, selector: #selector(metadataRetrievalFinished), name: Process.didTerminateNotification, object: task)

        let envVariables: [String: String] = [
            "HOME" : NSHomeDirectory(),
            "PERL_UNICODE" : "AS",
            "PATH": perlEnvironmentPath.path
        ]
        task.environment = envVariables
        task.launch()
        fh.readInBackgroundAndNotify()
    }

    @objc func metadataRetrievalDataReady(n: Notification) {
        guard let d = n.userInfo?[NSFileHandleNotificationDataItem] as? Data, d.count > 0, let s = String(data: d, encoding: .utf8) else {
            return
        }

        if 
        taskOutput.append(s)
        logger.addToLog(s, sender: self)
        pipe.fileHandleForReading.readInBackgroundAndNotify()
    }

    @objc func metadataRetrievalFinished(n: Notification) {
        let categories = [self scanField:@"categories" fromList:_taskOutput];

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
    _modeSizes = array;
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

    func thumbnailRequestFinished(thumbnailData: Data?) {
    if (thumbnailData) {
        _thumbnail = [[NSImage alloc] initWithData:thumbnailData];
    }
    _successfulRetrieval = @YES;
    _extendedMetadataRetrieved = @YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ExtendedInfoRetrieved" object:self];

}

    func scanField(field: String, list: String) {
        var buffer = ""
        let scanner = Scanner(string: list)
        let _ = scanner.scanUpToString("\(field):")
        let _ = scanner.scanString("\(field):")
    [scanner scanUpToString:[NSString stringWithFormat:@"%@:",field] intoString:nil];
    [scanner scanString:[NSString stringWithFormat:@"%@:",field] intoString:nil];
    [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
    [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&buffer];

    return [buffer copy];
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
        if (_task.running) {
            [_task interrupt];
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
                //    if ([_pid rangeOfString:@"/"].location != NSNotFound ||
                //        [_pid rangeOfString:@"#"].location != NSNotFound) {
                //
                //        if ( [[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheITV_TV"] isEqualTo:@YES] )
                //            self.status = @"New ITV Cache";
                //        else
                //            self.status = @"Undetermined-ITV";
                //        return;
                //    }
                @autoreleasepool {
                    getNameRunning = true;

                    NSTask *getNameTask = [[NSTask alloc] init];
                    NSPipe *getNamePipe = [[NSPipe alloc] init];
                    NSMutableString *getNameData = [[NSMutableString alloc] initWithString:@""];
                    NSString *listArgument = @"--listformat=<index>|<pid>|<type>|<name> - <episode>|<channel>|<web>";
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
    Programme *p = self;
    NSString *wantedID = p.pid;
    BOOL found = NO;
    for (NSString *string in array)
    {
        // TODO: remove use of index in future version
        NSArray *elements = [string componentsSeparatedByString:@"|"];
        if (elements.count < 6) {
            continue;
        }

        NSString *pid, *showName, *index, *type, *tvNetwork, *url;
        @try{
            index = elements[0];
            pid = elements[1];
            type = elements[2];
            showName = elements[3];
            tvNetwork = elements[4];
            url = elements[5];
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
        if ([wantedID isEqualToString:pid] || [wantedID isEqualToString:index])
        {
            found=YES;
            if (showName.length > 0) {
                p.showName = showName;
            }

            if (pid.length > 0) {
                p.pid = pid;
            }

            if (tvNetwork.length > 0) {
                p.tvNetwork = tvNetwork;
            }

            if (url) {
                p.url = url;
            }

            p.status = runDownloads ? @"Waiting..." : @"Available";

            if ([type isEqualToString:@"radio"]) {
                p.radio = @YES;
            }
        }
    }
    if (!found)
    {
        if ([p.showName isEqualToString:@""] || [p.showName isEqualToString:@"Unknown: Not in Cache"]) {
            p.showName = @"Retrieving Metadata...";
            p.status = @"Unknown";
        }

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
        NSMutableArray *args = [[NSMutableArray alloc] initWithObjects:
        [[AppController sharedController] getiPlayerPath],
        @"--nocopyright",
        @"--nopurge",versionArg,
        cacheExpiryArg,
        [GetiPlayerArguments sharedController].profileDirArg,
        infoArgument,
        pidArgument,
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
    }
    }

    - (void)processGetNameDataFromPID:(NSString *)getNameData
{
    NSArray *array = [getNameData componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    Programme *p = self;
    NSString *available = nil, *versions = nil, *title = nil, *type = nil;
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

        if ([string hasPrefix:@"title:"]) {
            NSScanner *scanner = [NSScanner scannerWithString:string];
            [scanner scanString:@"title:" intoString:nil];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&title];
            title = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }

        if ([string hasPrefix:@"versions:"]) {
            NSScanner *scanner = [NSScanner scannerWithString:string];
            [scanner scanString:@"versions:" intoString:nil];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&versions];
            versions = [versions stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }

        if ([string hasPrefix:@"type:"]) {
            NSScanner *scanner = [NSScanner scannerWithString:string];
            [scanner scanString:@"radio:" intoString:nil];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&type];
            type = [versions stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
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
        p.status = @"Not Available";
    } else {
        p.status = @"Available";
    }

    if (broadcastDate) {
        p.lastBroadcast = broadcastDate;
        p.lastBroadcastString = [NSDateFormatter localizedStringFromDate:broadcastDate
            dateStyle:NSDateFormatterMediumStyle
            timeStyle:NSDateFormatterNoStyle];
    }

    if ([type isEqualToString:@"radio"]) {
        p.radio = @YES;
    }

    if (title) {
        p.showName = title;
    } else {
        p.showName = @"Unknown: PID Not Found";
    }

    p.processedPID = @NO;
}

@end
