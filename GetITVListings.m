//
//  GetITVListings.m
//  ITVLoader
//
//  Created by LFS on 6/25/16.
//

@import Kanna;
#import <Foundation/Foundation.h>
#import "GetITVListings.h"


AppController           *sharedAppController;

@implementation GetITVShows
- (instancetype)init;
{
    if (self = [super init]) {
        _forceUpdateAllProgrammes = false;
        _getITVShowRunning = false;
        sharedAppController     = [AppController sharedController];
    }
    
    return self;
}


-(void)forceITVUpdateWithLogger:(LogController *)theLogger
{
    _logger = theLogger;
    [_logger addToLog:@"GetITVShows: Force all programmes update "];
    _forceUpdateAllProgrammes = true;
    [self itvUpdateWithLogger:_logger];
}

-(void)itvUpdateWithLogger:(LogController *)theLogger
{
    /* cant run if we are already running */
    
    if (_getITVShowRunning == true )
        return;
    
    _logger = theLogger;
    
    [_logger addToLog:@"GetITVShows: ITV Cache Update Starting "];
    
    _getITVShowRunning = true;
    _myQueueSize = 0;
    _htmlData = nil;
    
    /* Create the NUSRLSession */
    
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSString *cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"/itvloader.cache"];
    NSURLCache *myCache = [[NSURLCache alloc] initWithMemoryCapacity: 16384 diskCapacity: 268435456 diskPath: cachePath];
    defaultConfigObject.URLCache = myCache;
    defaultConfigObject.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
    
    _mySession = [NSURLSession sessionWithConfiguration:defaultConfigObject delegate:self delegateQueue: [NSOperationQueue mainQueue]];
    
    /* Load in carried forward programmes & programme History*/
    
    _filesPath = @"~/Library/Application Support/Get iPlayer Automator/";
    _filesPath= _filesPath.stringByExpandingTildeInPath;

    _programmesFilePath = [_filesPath stringByAppendingString:@"/itvprogrammes.gia"];
    
    if ( !_forceUpdateAllProgrammes )
        _boughtForwardProgrammeArray = [NSKeyedUnarchiver unarchiveObjectWithFile:_programmesFilePath];

    if ( _boughtForwardProgrammeArray == nil || _forceUpdateAllProgrammes ) {
        ProgrammeData *emptyProgramme = [[ProgrammeData alloc]initWithName:@"program to be deleted" andPID:@"PID" andURL:@"URL" andNUMBEREPISODES:0 andDATELASTAIRED:0];
        _boughtForwardProgrammeArray = [[NSMutableArray alloc]init];
        [_boughtForwardProgrammeArray addObject:emptyProgramme];
    }
    
    /* Create empty carriedForwardProgrammeArray & history array */
    
    _carriedForwardProgrammeArray = [[NSMutableArray alloc]init];
    
    /* establish time added for any new programmes we find today */
    
    NSTimeInterval timeAdded = [NSDate date].timeIntervalSince1970;
    timeAdded += [[NSTimeZone systemTimeZone] secondsFromGMTForDate:[NSDate date]];
    _intTimeThisRun = timeAdded;

    /* Load in todays shows for itv.com */
    
    self.myOpQueue = [[NSOperationQueue alloc] init];
    (self.myOpQueue).maxConcurrentOperationCount = 1;
    [self.myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(requestTodayListing) object:nil]];
    
    return;
}



- (id)requestTodayListing
{
    
    [[_mySession dataTaskWithURL:[NSURL URLWithString:@"https://www.itv.com/hub/shows"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        _htmlData = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        if ( ![self createTodayProgrammeArray] )
            [self endOfRun];
        else
            [self mergeAllProgrammes];
    }
      
    ] resume];

    return self;

}


- (void)requestProgrammeEpisodes:(ProgrammeData *)myProgramme
{
    /* Get all episodes for the programme name identified in MyProgramme */
    
    usleep(1);

    [[_mySession dataTaskWithURL:[NSURL URLWithString:myProgramme.programmeURL] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
      {
          if ( error ) {
            [_logger addToLog:[NSString stringWithFormat:@"GetITVListings (Error(%@)): Unable to retreive programme episodes for %@", error, myProgramme.programmeURL]];
            [[NSAlert alertWithMessageText:@"GetITVShows: Unable to retreive programme episode data" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"If problem persists, please submit a bug report and include the log file."] runModal];
          }
          else {
              NSString *myHtmlData = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
              [self processProgrammeEpisodesData:myProgramme : myHtmlData];
          }
      }
      
      ] resume];

    return;
    
}

-(void)processProgrammeEpisodesData:(ProgrammeData *)aProgramme :(NSString *)myHtmlData
{
    /*  Scan through episode page and create carried forward programme entries for each eipsode of aProgramme */
    NSScanner *scanner = [NSScanner scannerWithString:myHtmlData];
    NSScanner *fullProgrammeScanner;
    NSString *programmeURL = nil;
    NSString *productionId = nil;
    NSString *token        = nil;
    NSString *fullProgramme = nil;
    NSString *searchPath    = nil;
    NSString *basePath     = @"<a href=\"https://www.itv.com/hub/";
    NSUInteger scanPoint   = 0;
    int seriesNumber = 0;
    int  episodeNumber = 0;
    int numberEpisodesFound = 0;
    NSString *temp = nil;
    NSString *dateLastAired = nil;
    NSTimeInterval timeIntDateLastAired = 0;
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    dateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm'Z'";
    dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    
    /* Scan to start of episodes data  - first re-hyphonate the programe name */
    
    [scanner scanUpToString:@"data-episode-current" intoString:NULL];
    searchPath  = [basePath stringByAppendingString:[aProgramme.programmeName stringByReplacingOccurrencesOfString:@" " withString:@"-"]];
    searchPath  = [searchPath stringByAppendingString:@"/"];
    
    /* Get first episode  */
    
    [scanner scanUpToString:searchPath intoString:NULL];
    [scanner scanUpToString:@"</a>" intoString:&fullProgramme];

    while ( !scanner.atEnd ) {
        
        fullProgrammeScanner = [NSScanner scannerWithString:fullProgramme];
        
        numberEpisodesFound++;
        
        /* URL */
        
        [fullProgrammeScanner scanUpToString:@"<a href=\"" intoString:&temp];
        [fullProgrammeScanner scanString:@"<a href=\"" intoString:&temp];
        [fullProgrammeScanner scanUpToString:@"\"" intoString:&programmeURL];
        
        /* Production ID */
        
        [fullProgrammeScanner scanUpToString:@"productionId=" intoString:&temp];
        [fullProgrammeScanner scanString:@"productionId=" intoString:&temp];
        [fullProgrammeScanner scanUpToString:@"\"" intoString:&token];
        productionId=token.stringByRemovingPercentEncoding;
        
        /* Series (if available) */
        
        scanPoint = fullProgrammeScanner.scanLocation;
        seriesNumber = 0;
        [fullProgrammeScanner scanUpToString:@"Series" intoString:&temp];
        
        if ( !fullProgrammeScanner.atEnd)  {
            [fullProgrammeScanner scanString:@"Series" intoString:&temp];
            [fullProgrammeScanner scanInt:&seriesNumber];
        }
        
        episodeNumber = 0;
        fullProgrammeScanner.scanLocation = scanPoint;
        [fullProgrammeScanner scanUpToString:@"Episode" intoString:&temp];
        
        if ( !fullProgrammeScanner.atEnd)  {
            [fullProgrammeScanner scanString:@"Episode" intoString:&temp];
            [fullProgrammeScanner scanInt:&episodeNumber];
        }
        
        /* get date aired so that we can quickPurge last episode in mergeAllEpisodes */
        
        dateLastAired= @"";
        fullProgrammeScanner.scanLocation = scanPoint;
        [fullProgrammeScanner scanUpToString:@"datetime=\"" intoString:&temp];
        
        if ( !fullProgrammeScanner.atEnd)  {
            [fullProgrammeScanner scanString:@"datetime=\"" intoString:&temp];
            [fullProgrammeScanner scanUpToString:@"\"" intoString:&dateLastAired];
            timeIntDateLastAired = [dateFormatter dateFromString:dateLastAired].timeIntervalSince1970;
        }
        /* Create ProgrammeData Object and store in array */
        
        ProgrammeData *myProgramme = [[ProgrammeData alloc]initWithName:aProgramme.programmeName andPID:productionId andURL:programmeURL andNUMBEREPISODES:aProgramme.numberEpisodes andDATELASTAIRED:timeIntDateLastAired];
        
        [myProgramme addProgrammeSeriesInfo:seriesNumber :episodeNumber];
        
        if (numberEpisodesFound == 1)
            [myProgramme makeNew];
        
        [_carriedForwardProgrammeArray addObject:myProgramme];

        /* if we couldnt find dateAired then mark first programme for forced cache update - hopefully this will repair issue on next run */
        
        if ( myProgramme.timeIntDateLastAired == 0 )  {

            [_carriedForwardProgrammeArray[_carriedForwardProgrammeArray.count-numberEpisodesFound] forceCacheUpdateOn];
            
            [_logger addToLog:[NSString stringWithFormat:@"GetITVListings: WARNING: Date aired not found %@", aProgramme.programmeName]];
        }
        
        /* Scan for next programme */
        
        [scanner scanUpToString:searchPath intoString:NULL];
        [scanner scanUpToString:@"</a>" intoString:&fullProgramme];
    }
    
    /* Quick sanity check - did we find the number of episodes that we expected */
    
    if ( numberEpisodesFound != aProgramme.numberEpisodes)  {
        
        /* if not - mark first entry as requireing a full update on next run - hopefully this will repair the issue */
        
        if ( numberEpisodesFound > 0 )
            [_carriedForwardProgrammeArray[_carriedForwardProgrammeArray.count-numberEpisodesFound] forceCacheUpdateOn];
       
        [_logger addToLog:[NSString stringWithFormat:@"GetITVListings (Warning): Processing Error %@ - episodes expected/found %ld/%d", aProgramme.programmeURL, (long)aProgramme.numberEpisodes, numberEpisodesFound]];
    }
    
    /* Check if there is any outstanding work before processing the carried forward programme list */
    
    [sharedAppController.itvProgressIndicator incrementBy:_myQueueSize -1 ? 100.0f/(float)(_myQueueSize -1.0f) : 100.0f];

    if ( !--_myQueueLeft  )
        [self processCarriedForwardProgrammes];
}

-(void)processCarriedForwardProgrammes
{
    /* First we add or update datetimeadded for the carried forward programmes */
    
    NSSortDescriptor *sort1 = [NSSortDescriptor sortDescriptorWithKey:@"productionId" ascending:YES];
    
    [_boughtForwardProgrammeArray sortUsingDescriptors:@[sort1]];
    
    for ( int i=0; i < _carriedForwardProgrammeArray.count; i++ )  {
        ProgrammeData *cfProgramme = _carriedForwardProgrammeArray[i];
                                      
        cfProgramme.timeAddedInt = [self searchForProductionId:cfProgramme.productionId inProgrammeArray:_boughtForwardProgrammeArray];
        
        _carriedForwardProgrammeArray[i] = cfProgramme;
    }

    /* Now we sort the programmes & write CF to disk */
    
    sort1 = [NSSortDescriptor sortDescriptorWithKey:@"programmeName" ascending:YES];
    NSSortDescriptor *sort2 = [NSSortDescriptor sortDescriptorWithKey:@"isNew" ascending:NO];
    NSSortDescriptor *sort3 = [NSSortDescriptor sortDescriptorWithKey:@"timeIntDateLastAired" ascending:NO];
    
    [_carriedForwardProgrammeArray sortUsingDescriptors:@[sort1, sort2, sort3]];
    
    [NSKeyedArchiver archiveRootObject:_carriedForwardProgrammeArray toFile:_programmesFilePath];

    
    /* Now create the cache file that used to be created by get_iplayer */
    
    NSMutableString *cacheFileContentString = [[NSMutableString alloc] initWithString:@"#index|type|name|pid|available|expires|episode|seriesnum|episodenum|versions|duration|desc|channel|categories|thumbnail|timeadded|guidance|web\n"];

    int cacheIndexNumber = 100000;
    

    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"EEE MMM dd";
    NSString *episodeString = nil;
    
    NSDateFormatter* dateFormatter1 = [[NSDateFormatter alloc] init];
    dateFormatter1.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
    NSString *dateAiredString = nil;

    NSDate *dateAiredUTC;
    
    for (ProgrammeData *carriedForwardProgramme in _carriedForwardProgrammeArray)    {
        
        if ( carriedForwardProgramme.timeIntDateLastAired )  {
            dateAiredUTC = [[NSDate alloc] initWithTimeIntervalSince1970:carriedForwardProgramme.timeIntDateLastAired];
            episodeString = [dateFormatter stringFromDate:dateAiredUTC];
            dateAiredString = [dateFormatter1 stringFromDate:dateAiredUTC];
        }
        else {
            episodeString = @"";
            dateAiredUTC = [[NSDate alloc]init];
            dateAiredString = [dateFormatter1 stringFromDate:dateAiredUTC];
        }
        
        [cacheFileContentString appendFormat:@"%06d|", cacheIndexNumber++];
        [cacheFileContentString appendString:@"itv|"];
        [cacheFileContentString appendString:carriedForwardProgramme.programmeName];
        [cacheFileContentString appendString:@"|"];
        [cacheFileContentString appendString:carriedForwardProgramme.productionId];
        [cacheFileContentString appendString:@"|"];
        [cacheFileContentString appendString:dateAiredString];
        [cacheFileContentString appendString:@"||"];
        [cacheFileContentString appendString:episodeString];
        [cacheFileContentString appendString:@"|||default|||ITV Player|TV||"];
        [cacheFileContentString appendFormat:@"%ld||",(long)carriedForwardProgramme.timeAddedInt];
        [cacheFileContentString appendString:carriedForwardProgramme.programmeURL];
        [cacheFileContentString appendString:@"|\n"];
    }

    NSData *cacheData = [cacheFileContentString dataUsingEncoding:NSUTF8StringEncoding];

    NSString *cacheFilePath = [_filesPath stringByAppendingString:@"/itv.cache"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:cacheFilePath])  {
        
        if (![fileManager createFileAtPath:cacheFilePath contents:cacheData attributes:nil])    {
                [[NSAlert alertWithMessageText:@"GetITVShows: Could not create cache file!" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Please submit a bug report."] runModal];
        }
    }
    else    {
        
        NSError *writeToFileError;
        
        if (![cacheData writeToFile:cacheFilePath options:NSDataWritingAtomic error:&writeToFileError]) {
            [[NSAlert alertWithMessageText:@"GetITVShows: Could not write to history file!" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Please submit a bug report saying that the history file could not be written to."] runModal];
        }
    }
    
    [self endOfRun];
}

-(void)endOfRun
{
    /* Notify finish and invaliate the NSURLSession */

    _getITVShowRunning = false;
    [_mySession finishTasksAndInvalidate];

    if (_forceUpdateAllProgrammes) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ForceITVUpdateFinished" object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ITVUpdateFinished" object:nil];
    }
    
    _forceUpdateAllProgrammes = false;
    
    [_logger addToLog:@"GetITVShows: Update Finished"];
}

-(NSInteger)searchForProductionId:(NSString *)productionId inProgrammeArray:(NSMutableArray *)programmeArray
{
    NSInteger startPoint = 0;
    NSInteger endPoint   = programmeArray.count -1;
    NSInteger midPoint = endPoint / 2;
    ProgrammeData *midProgramme;
    
    while (startPoint <= endPoint) {
        
        midProgramme = programmeArray[midPoint];
        NSString *midProductionId = midProgramme.productionId;

        NSComparisonResult result = [midProductionId compare:productionId];
        
        switch ( result )  {
            case NSOrderedAscending:
                startPoint = midPoint +1;
                break;
            case NSOrderedSame:
                return midProgramme.timeAddedInt ? midProgramme.timeAddedInt : _intTimeThisRun;
                break;
            case NSOrderedDescending:
                endPoint = midPoint -1;
                break;
        }
        midPoint = (startPoint + endPoint)/2;
    }
    
    return _intTimeThisRun;
}


-(void)mergeAllProgrammes
{
    int bfIndex = 0;
    int todayIndex = 0;
    
    ProgrammeData *bfProgramme = _boughtForwardProgrammeArray[bfIndex];
    ProgrammeData *todayProgramme  = _todayProgrammeArray[todayIndex];
    NSString *bfProgrammeName;
    NSString *todayProgrammeName;
    
    do {

        if (bfIndex < _boughtForwardProgrammeArray.count) {
            bfProgramme = _boughtForwardProgrammeArray[bfIndex];
            bfProgrammeName = bfProgramme.programmeName;
        }
        else {
            bfProgrammeName = @"~~~~~~~~~~";
        }
        if (todayIndex < _todayProgrammeArray.count) {
            todayProgramme = _todayProgrammeArray[todayIndex];
            todayProgrammeName = todayProgramme.programmeName;
        }
        else {
            todayProgrammeName = @"~~~~~~~~~~";
        }

        NSComparisonResult result = [bfProgrammeName compare:todayProgrammeName];
        
        switch ( result )  {

            case NSOrderedDescending:
            
                /* Now get all episodes & add carriedForwardProgrammeArray - note if only 1 episode then just copy todays programme */
            
                if ( todayProgramme.numberEpisodes == 1 )  {
                    [todayProgramme makeNew];
                    [_carriedForwardProgrammeArray addObject:todayProgramme];
                }
                else {
                    _myQueueSize++;
                    [self.myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(requestProgrammeEpisodes:) object:todayProgramme]];
                }
            
                todayIndex++;
                
                break;

            case NSOrderedSame:
                
                /* for programmes that have more then one current episode and cache update is forced or current episode has changed or new episodes have been found; get full episode listing */
                
                if (  todayProgramme.numberEpisodes > 1  &&
                     ( bfProgramme.forceCacheUpdate == true || ![todayProgramme.productionId isEqualToString:bfProgramme.productionId] ||todayProgramme.numberEpisodes > bfProgramme.numberEpisodes) )  {
                    
                        if (bfProgramme.forceCacheUpdate == true)
                            [_logger addToLog:[NSString stringWithFormat:@"GetITVListings (Warning): Cache upate forced for: %@", bfProgramme.programmeName]];
                        
                        _myQueueSize++;
                        
                        [self.myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(requestProgrammeEpisodes:)object:todayProgramme]];
                    
                        /* Now skip remaining BF episodes */
                    
                        for (bfIndex++; (bfIndex < _boughtForwardProgrammeArray.count  &&
                                     [todayProgramme.programmeName isEqualToString:((ProgrammeData *)_boughtForwardProgrammeArray[bfIndex]).programmeName]); bfIndex++ );
                 
                }
                
                else if ( todayProgramme.numberEpisodes == 1 )  {
                    
                    /* For programmes with only 1 episode found just copy it from today to CF */
                    
                    [todayProgramme makeNew];
                    [_carriedForwardProgrammeArray addObject:todayProgramme];
                
                    /* Now skip remaining BF episodes (if any) */
                
                    for (bfIndex++; (bfIndex < _boughtForwardProgrammeArray.count  &&
                                     [todayProgramme.programmeName isEqualToString:((ProgrammeData *)_boughtForwardProgrammeArray[bfIndex]).programmeName]); bfIndex++ );
                }
                
                else if ( [todayProgramme.productionId isEqualToString:bfProgramme.productionId] && todayProgramme.numberEpisodes == bfProgramme.numberEpisodes  )              {
                    
                    /* For programmes where the current episode and number of episodes has not changed so just copy BF to CF  */
                    
                    do {
                        [_carriedForwardProgrammeArray addObject:_boughtForwardProgrammeArray[bfIndex]];
                        
                    } while (  ++bfIndex < _boughtForwardProgrammeArray.count  &&
                             [todayProgramme.programmeName isEqualToString:((ProgrammeData *)_boughtForwardProgrammeArray[bfIndex]).programmeName]);
                }
                
                else if ( todayProgramme.numberEpisodes < bfProgramme.numberEpisodes )  {
                    
                    /* For programmes where the current episode has changed but fewer episodes found today; copy available episodes & drop the remainder */
                    
                    for (NSInteger i = todayProgramme.numberEpisodes; i; i--, bfIndex++ ) {
                        ProgrammeData *pd = _boughtForwardProgrammeArray[bfIndex];  
                        pd.numberEpisodes = todayProgramme.numberEpisodes;
                        [_carriedForwardProgrammeArray addObject:pd];
                    }
                
                    /* and drop the rest */
                    
                    for (; (bfIndex < _boughtForwardProgrammeArray.count  &&
                            [todayProgramme.programmeName isEqualToString:((ProgrammeData *)_boughtForwardProgrammeArray[bfIndex]).programmeName]); bfIndex++ );
                }
                
                else {
                
                    /* Should never get here fo full reload & skip all episodes for this programme */
                    
                    [_logger addToLog:[NSString stringWithFormat:@"GetITVListings (Error): Failed to correctly process %@ will issue a full refresh", todayProgramme]];
                    
                    _myQueueSize++;
                    
                    [self.myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(requestProgrammeEpisodes:)object:todayProgramme]];
                    
                    for (bfIndex++; (bfIndex < _boughtForwardProgrammeArray.count  &&
                                     [todayProgramme.programmeName isEqualToString:((ProgrammeData *)_boughtForwardProgrammeArray[bfIndex]).programmeName]); bfIndex++ );
                }
        
        todayIndex++;
        
        break;
        
            case NSOrderedAscending:

                /*  BF not found; Skip all episdoes on BF as programme no longer available */
            
                for (bfIndex++; (bfIndex < _boughtForwardProgrammeArray.count  &&
                             [bfProgramme.programmeName isEqualToString:((ProgrammeData *)_boughtForwardProgrammeArray[bfIndex]).programmeName]);  bfIndex++ );
                
                break;
        }
        
    } while ( bfIndex < _boughtForwardProgrammeArray.count  || todayIndex < _todayProgrammeArray.count  );
    
    [_logger addToLog:[NSString stringWithFormat:@"GetITVShows (Info): Merge complete B/F Programmes: %ld C/F Programmes: %ld Today Programmes: %ld ", _boughtForwardProgrammeArray.count, _carriedForwardProgrammeArray.count, _todayProgrammeArray.count]];
    
    _myQueueLeft = _myQueueSize;
    
    if (_myQueueSize < 2 )
        [sharedAppController.itvProgressIndicator incrementBy:100.0f];

    if (!_myQueueSize)
        [self processCarriedForwardProgrammes];
}

-(BOOL)createTodayProgrammeArray
{
    /* Scan itv.com/shows to create full listing of programmes (not episodes) that are available today */
    
    _todayProgrammeArray = [[NSMutableArray alloc]init];
    NSScanner *scanner = [NSScanner scannerWithString:_htmlData];

    NSString *programmeName = nil;
    NSString *programmeURL = nil;
    NSString *productionId = nil;
    NSString *token = nil;
    NSString *fullProgramme = nil;
    NSString *temp = nil;
    
    NSUInteger scanPoint = 0;
    int numberEpisodes = 0;
    int testingProgrammeCount = 0;
    
    /* Get first programme  */
    
    [scanner scanUpToString:@"<a href=\"https://www.itv.com/hub/" intoString:NULL];
    [scanner scanUpToString:@"</a>" intoString:&fullProgramme];
    
    while ( (!scanner.atEnd) && ++testingProgrammeCount ) {
    
        NSScanner *fullProgrammeScanner = [NSScanner scannerWithString:fullProgramme];
        scanPoint = fullProgrammeScanner.scanLocation;
        
        /* URL */
        
        [fullProgrammeScanner scanString:@"<a href=\"" intoString:NULL];
        [fullProgrammeScanner scanUpToString:@"\"" intoString:&programmeURL];
        
        /* Programme Name */
        
        fullProgrammeScanner.scanLocation = scanPoint;
        [fullProgrammeScanner scanString:@"<a href=\"https://www.itv.com/hub/" intoString:NULL];
        [fullProgrammeScanner scanUpToString:@"/" intoString:&programmeName];
        
        /* Production ID */
        
        [fullProgrammeScanner scanUpToString:@"productionId=" intoString:NULL];
        [fullProgrammeScanner scanString:@"productionId=" intoString:NULL];
        [fullProgrammeScanner scanUpToString:@"\"" intoString:&token];
        productionId=token.stringByRemovingPercentEncoding;
        
        /* Get mumber of episodes, assume 1 if you cant figure it out */
        
        numberEpisodes  = 1;
        
        [fullProgrammeScanner scanUpToString:@"<p class=\"tout__meta theme__meta\">" intoString:&temp];
        
        if ( !fullProgrammeScanner.atEnd)  {
            [fullProgrammeScanner scanString:@"<p class=\"tout__meta theme__meta\">" intoString:&temp];
            scanPoint = fullProgrammeScanner.scanLocation;
            [fullProgrammeScanner scanUpToString:@"episode" intoString:&temp];
                
            if ( !fullProgrammeScanner.atEnd)  {
                fullProgrammeScanner.scanLocation = scanPoint;
                [fullProgrammeScanner scanInt:&numberEpisodes];
            }
        }
        
        /* Create ProgrammeData Object and store in array */
        
        ProgrammeData *myProgramme = [[ProgrammeData alloc]initWithName:programmeName andPID:productionId andURL:programmeURL andNUMBEREPISODES:numberEpisodes andDATELASTAIRED:_timeIntervalSince1970UTC];
        [_todayProgrammeArray addObject:myProgramme];
        
        /* Scan for next programme */
        
        [scanner scanUpToString:@"<a href=\"https://www.itv.com/hub/" intoString:NULL];
        [scanner scanUpToString:@"</a>" intoString:&fullProgramme];
        
    }

    /* Now we sort the programmes and the drop duplicates */
    
    if ( !_todayProgrammeArray.count )  {
        [_logger addToLog:@"No programmes found on www.itv.com/hub/shows"];
        
        NSAlert *noProgs = [NSAlert alertWithMessageText:@"No programmes were found on www.itv.com/hub/shows"
                                                 defaultButton:@"OK"
                                               alternateButton:nil
                                                   otherButton:nil
                                     informativeTextWithFormat:@"Try again later, if problem persists create a support request"];
        [noProgs runModal];
        
        return NO;
    }
    
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"programmeName" ascending:YES];
    [_todayProgrammeArray sortUsingDescriptors:@[sort]];
    
    for (int i=0; i < _todayProgrammeArray.count -1; i++) {
        ProgrammeData *programme1 = _todayProgrammeArray[i];
        ProgrammeData *programme2 = _todayProgrammeArray[i+1];
        
        if ( [programme1.programmeName isEqualToString:programme2.programmeName] ) {
            [_todayProgrammeArray removeObjectAtIndex:i];
        }
    }

    return YES;
}

@end


@implementation ProgrammeData


- (instancetype)initWithName:(NSString *)name andPID:(NSString *)pid andURL:(NSString *)url andNUMBEREPISODES:(NSInteger)numberEpisodes andDATELASTAIRED:(NSTimeInterval)timeIntDateLastAired;
{
    if (self = [super init]) {
        _programmeName = name;
        [self fixProgrammeName];
        _productionId = pid != nil ? pid : @"";
        _programmeURL = url != nil ? url : @"";
        self.numberEpisodes = numberEpisodes;
        _seriesNumber = 0;
        _episodeNumber = 0;
        _isNew = false;
        self.forceCacheUpdate = false;
        self.timeIntDateLastAired = timeIntDateLastAired;
        self.timeAddedInt = 0;
    }
    return self;
    
}

- (id)addProgrammeSeriesInfo:(int)aSeriesNumber :(int)aEpisodeNumber
{
    _seriesNumber = aSeriesNumber;
    _episodeNumber = aEpisodeNumber;
    
    return self;
}

- (id)makeNew
{
    _isNew = true;
    
    return self;
}

- (id)forceCacheUpdateOn
{
    self.forceCacheUpdate = true;
    
    return self;
}
- (void) encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.programmeName forKey:@"programmeName"];
    [encoder encodeObject:self.productionId forKey:@"productionId"];
    [encoder encodeObject:self.programmeURL forKey:@"programmeURL"];
    [encoder encodeObject:@(self.numberEpisodes) forKey:@"numberEpisodes"];
    [encoder encodeObject:@(_seriesNumber) forKey:@"seriesNumber"];
    [encoder encodeObject:@(_episodeNumber) forKey:@"episodeNumber"];
    [encoder encodeObject:@(_isNew) forKey:@"isNew"];
    [encoder encodeObject:@(self.forceCacheUpdate) forKey:@"forceCacheUpdate"];
    [encoder encodeObject:[NSNumber numberWithDouble:self.timeIntDateLastAired] forKey:@"timeIntDateLastAired"];
    [encoder encodeObject:@(self.timeAddedInt) forKey:@"timeAddedInt"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (self != nil) {
        self.programmeName = [decoder decodeObjectForKey:@"programmeName"];
        self.productionId = [decoder decodeObjectForKey:@"productionId"];
        self.programmeURL = [decoder decodeObjectForKey:@"programmeURL"];
        self.numberEpisodes = [[decoder decodeObjectForKey:@"numberEpisodes"] intValue];
        _seriesNumber = [[decoder decodeObjectForKey:@"seriesNumber"] intValue];
        _episodeNumber = [[decoder decodeObjectForKey:@"episodeNumber"] intValue];
        _isNew = [[decoder decodeObjectForKey:@"isNew"] intValue];
        self.forceCacheUpdate = [[decoder decodeObjectForKey:@"forceCacheUpdate"] intValue];
        self.timeIntDateLastAired = [[decoder decodeObjectForKey:@"timeIntDateLastAired"] floatValue];
        self.timeAddedInt = [[decoder decodeObjectForKey:@"timeAddedInt"] intValue];
    }
    
    return self;
}

-(void)fixProgrammeName
{
    self.programmeName = [self.programmeName stringByReplacingOccurrencesOfString:@"-" withString:@" "];
    self.programmeName = (self.programmeName).capitalizedString;
}

@end


@implementation NewProgrammeHistory

+ (NewProgrammeHistory *)sharedInstance
{
    static NewProgrammeHistory *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[NewProgrammeHistory alloc] init];
    });
    
    return sharedInstance;
}

-(instancetype)init
{
    if (self = [super init]) {
        
        _itemsAdded = false;
        _historyFilePath = @"~/Library/Application Support/Get iPlayer Automator/history.gia";
        _historyFilePath= _historyFilePath.stringByExpandingTildeInPath;
        _programmeHistoryArray = [NSKeyedUnarchiver unarchiveObjectWithFile:_historyFilePath];
        
        if ( _programmeHistoryArray == nil )
               _programmeHistoryArray = [[NSMutableArray alloc]init];
        
        /* Cull history if > 3,000 entries */
        
        while ( _programmeHistoryArray.count > 3000 )
            [_programmeHistoryArray removeObjectAtIndex:0];
        
        _timeIntervalSince1970UTC = [NSDate date].timeIntervalSince1970;
        _timeIntervalSince1970UTC += [[NSTimeZone systemTimeZone] secondsFromGMTForDate:[NSDate date]];
        _timeIntervalSince1970UTC /= (24*60*60);
        
        NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"EEE MMM dd";
        _dateFound = [dateFormatter stringFromDate:[NSDate date]];
    }
    return self;
}

-(void)addToNewProgrammeHistory:(NSString *)name andTVChannel:(NSString *)tvChannel andNetworkName:(NSString *)networkName
{
    _itemsAdded = true;
    ProgrammeHistoryObject *newEntry = [[ProgrammeHistoryObject alloc]initWithName:name andTVChannel:tvChannel andDateFound:_dateFound andSortKey:_timeIntervalSince1970UTC andNetworkName:networkName];
    [_programmeHistoryArray addObject:newEntry];
}

-(NSMutableArray *)getHistoryArray
{
    if (_itemsAdded)
        [self flushHistoryToDisk];
    
    return _programmeHistoryArray;
}

-(void)flushHistoryToDisk;
{
    _itemsAdded = false;
    
    /* Sort history array and flush to disk */
    
    NSSortDescriptor *sort1 = [NSSortDescriptor sortDescriptorWithKey:@"sortKey" ascending:YES];
    NSSortDescriptor *sort2 = [NSSortDescriptor sortDescriptorWithKey:@"programmeName" ascending:YES];
    NSSortDescriptor *sort3 = [NSSortDescriptor sortDescriptorWithKey:@"tvChannel" ascending:YES];
    
    [_programmeHistoryArray sortUsingDescriptors:@[sort1, sort2, sort3]];
    
    [NSKeyedArchiver archiveRootObject:_programmeHistoryArray toFile:_historyFilePath];
}

@end

@implementation ProgrammeHistoryObject

- (instancetype)initWithName:(NSString *)name andTVChannel:(NSString *)aTVChannel andDateFound:(NSString *)dateFound andSortKey:(NSUInteger)aSortKey andNetworkName:(NSString *)networkName
{
    
    self.sortKey             = aSortKey;
    self.programmeName  = name;
    self.dateFound      = dateFound;
    self.tvChannel      = aTVChannel;
    self.networkName    = networkName;
    
    return self;
}


- (void) encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:@(self.sortKey) forKey:@"sortKey"];
    [encoder encodeObject:self.programmeName forKey:@"programmeName"];
    [encoder encodeObject:self.dateFound forKey:@"dateFound"];
    [encoder encodeObject:self.tvChannel forKey:@"tvChannel"];
    [encoder encodeObject:self.networkName forKey:@"networkName"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (self != nil) {
        self.sortKey = [[decoder decodeObjectForKey:@"sortKey"] intValue];
        self.programmeName = [decoder decodeObjectForKey:@"programmeName"];
        self.dateFound = [decoder decodeObjectForKey:@"dateFound"];
        self.tvChannel = [decoder decodeObjectForKey:@"tvChannel"];
        self.networkName = [decoder decodeObjectForKey:@"networkName"];
    }
    
    return self;
}

- (BOOL)isEqual:(ProgrammeHistoryObject *)anObject
{
    return [self.programmeName isEqual:anObject.programmeName];
}

- (NSUInteger)hash
{
    return (self.programmeName).hash;
}
@end


