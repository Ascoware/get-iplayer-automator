//
//  GetITVListings.m
//  ITVLoader
//
//  Created by LFS on 6/25/16.
//

#import <Foundation/Foundation.h>
#import "GetITVListings.h"


AppController           *sharedAppController;

@implementation GetITVShows
- (id)init;
{
    if (!(self = [super init])) return nil;
    
    nc = [NSNotificationCenter defaultCenter];
    forceUpdateAllProgrammes = false;
    getITVShowRunning = false;
    sharedAppController     = [AppController sharedController];

    return self;
}


-(void)forceITVUpdateWithLogger:(LogController *)theLogger
{
    logger = theLogger;
    
    [logger addToLog:@"GetITVShows: Force all programmes update "];
    
    forceUpdateAllProgrammes = true;
    [self itvUpdateWithLogger:logger];

}

-(void)itvUpdateWithLogger:(LogController *)theLogger
{
    /* cant run if we are already running */
    
    if ( getITVShowRunning == true )
        return;
    
    logger = theLogger;
    
    [logger addToLog:@"GetITVShows: ITV Cache Update Starting "];
    
    getITVShowRunning = true;
    myQueueSize = 0;
    htmlData = nil;
    
    /* Create the NUSRLSession */
    
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSString *cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"/itvloader.cache"];
    NSURLCache *myCache = [[NSURLCache alloc] initWithMemoryCapacity: 16384 diskCapacity: 268435456 diskPath: cachePath];
    defaultConfigObject.URLCache = myCache;
    defaultConfigObject.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
    
    mySession = [NSURLSession sessionWithConfiguration:defaultConfigObject delegate:self delegateQueue: [NSOperationQueue mainQueue]];
    
    /* Load in carried forward programmes & programme History*/
    
    filesPath = @"~/Library/Application Support/Get iPlayer Automator/";
    filesPath= [filesPath stringByExpandingTildeInPath];

    programmesFilePath = [filesPath stringByAppendingString:@"/itvprogrammes.gia"];
    
    if ( !forceUpdateAllProgrammes )
        boughtForwardProgrammeArray = [NSKeyedUnarchiver unarchiveObjectWithFile:programmesFilePath];

    if ( boughtForwardProgrammeArray == nil || forceUpdateAllProgrammes ) {
        ProgrammeData *emptyProgramme = [[ProgrammeData alloc]initWithName:@"program to be deleted" andPID:@"PID" andURL:@"URL" andNUMBEREPISODES:0 andDATELASTAIRED:0];
        boughtForwardProgrammeArray = [[NSMutableArray alloc]init];
        [boughtForwardProgrammeArray addObject:emptyProgramme];
    }
    
    /* Create empty carriedForwardProgrammeArray & history array */
    
    carriedForwardProgrammeArray = [[NSMutableArray alloc]init];
    
    /* establish time added for any new programmes we find today */
    
    NSTimeInterval timeAdded = [[NSDate date] timeIntervalSince1970];
    timeAdded += [[NSTimeZone systemTimeZone] secondsFromGMTForDate:[NSDate date]];
    intTimeThisRun = timeAdded;

    /* Load in todays shows for itv.com */
    
    self.myOpQueue = [[NSOperationQueue alloc] init];
    [self.myOpQueue setMaxConcurrentOperationCount:1];
    [self.myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(requestTodayListing) object:nil]];
    
    return;
}



- (id)requestTodayListing
{
    
    [[mySession dataTaskWithURL:[NSURL URLWithString:@"http://www.itv.com/hub/shows"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        htmlData = [[NSString alloc]initWithData:data encoding:NSASCIIStringEncoding];
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

    [[mySession dataTaskWithURL:[NSURL URLWithString:myProgramme.programmeURL] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
      {
          if ( error ) {
            [logger addToLog:[NSString stringWithFormat:@"GetITVListings (Error(%@)): Unable to retreive programme episodes for %@", error, myProgramme.programmeURL]];
            [[NSAlert alertWithMessageText:@"GetITVShows: Unable to retreive programme episode data" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"If problem persists, please submit a bug report and include the log file."] runModal];
          }
          else {
              NSString *myHtmlData = [[NSString alloc]initWithData:data encoding:NSASCIIStringEncoding];
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
    NSString *basePath     = @"<a href=\"http://www.itv.com/hub/";
    NSUInteger scanPoint   = 0;
    int seriesNumber = 0;
    int  episodeNumber = 0;
    int numberEpisodesFound = 0;
    NSString *temp = nil;
    NSString *dateLastAired = nil;
    NSTimeInterval timeIntDateLastAired = 0;
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm'Z'"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    /* Scan to start of episodes data  - first re-hyphonate the programe name */
    
    [scanner scanUpToString:@"data-episode-current" intoString:NULL];
    searchPath  = [basePath stringByAppendingString:[aProgramme.programmeName stringByReplacingOccurrencesOfString:@" " withString:@"-"]];
    searchPath  = [searchPath stringByAppendingString:@"/"];
    
    /* Get first episode  */
    
    [scanner scanUpToString:searchPath intoString:NULL];
    [scanner scanUpToString:@"</a>" intoString:&fullProgramme];

    while ( ![scanner isAtEnd] ) {
        
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
        productionId=[token stringByRemovingPercentEncoding];
        
        /* Series (if available) */
        
        scanPoint = fullProgrammeScanner.scanLocation;
        seriesNumber = 0;
        [fullProgrammeScanner scanUpToString:@"Series" intoString:&temp];
        
        if ( ![fullProgrammeScanner isAtEnd])  {
            [fullProgrammeScanner scanString:@"Series" intoString:&temp];
            [fullProgrammeScanner scanInt:&seriesNumber];
        }
        
        episodeNumber = 0;
        fullProgrammeScanner.scanLocation = scanPoint;
        [fullProgrammeScanner scanUpToString:@"Episode" intoString:&temp];
        
        if ( ![fullProgrammeScanner isAtEnd])  {
            [fullProgrammeScanner scanString:@"Episode" intoString:&temp];
            [fullProgrammeScanner scanInt:&episodeNumber];
        }
        
        /* get date aired so that we can quickPurge last episode in mergeAllEpisodes */
        
        dateLastAired= @"";
        fullProgrammeScanner.scanLocation = scanPoint;
        [fullProgrammeScanner scanUpToString:@"datetime=\"" intoString:&temp];
        
        if ( ![fullProgrammeScanner isAtEnd])  {
            [fullProgrammeScanner scanString:@"datetime=\"" intoString:&temp];
            [fullProgrammeScanner scanUpToString:@"\"" intoString:&dateLastAired];
            timeIntDateLastAired = [[dateFormatter dateFromString:dateLastAired] timeIntervalSince1970];
        }
        /* Create ProgrammeData Object and store in array */
        
        ProgrammeData *myProgramme = [[ProgrammeData alloc]initWithName:aProgramme.programmeName andPID:productionId andURL:programmeURL andNUMBEREPISODES:aProgramme.numberEpisodes andDATELASTAIRED:timeIntDateLastAired];
        
        [myProgramme addProgrammeSeriesInfo:seriesNumber :episodeNumber];
        
        if (numberEpisodesFound == 1)
            [myProgramme makeNew];
        
        [carriedForwardProgrammeArray addObject:myProgramme];

        /* if we couldnt find dateAired then mark first programme for forced cache update - hopefully this will repair issue on next run */
        
        if ( myProgramme.timeIntDateLastAired == 0 )  {

            [[carriedForwardProgrammeArray objectAtIndex:[carriedForwardProgrammeArray count]-numberEpisodesFound] forceCacheUpdateOn];
            
            [logger addToLog:[NSString stringWithFormat:@"GetITVListings: WARNING: Date aired not found %@", aProgramme.programmeName]];
        }
        
        /* Scan for next programme */
        
        [scanner scanUpToString:searchPath intoString:NULL];
        [scanner scanUpToString:@"</a>" intoString:&fullProgramme];
    }
    
    /* Quick sanity check - did we find the number of episodes that we expected */
    
    if ( numberEpisodesFound != aProgramme.numberEpisodes)  {
        
        /* if not - mark first entry as requireing a full update on next run - hopefully this will repair the issue */
        
        if ( numberEpisodesFound > 0 )
            [[carriedForwardProgrammeArray objectAtIndex:[carriedForwardProgrammeArray count]-numberEpisodesFound] forceCacheUpdateOn];
       
        [logger addToLog:[NSString stringWithFormat:@"GetITVListings (Warning): Processing Error %@ - episodes expected/found %d/%d", aProgramme.programmeURL, aProgramme.numberEpisodes, numberEpisodesFound]];
    }
    
    /* Check if there is any outstanding work before processing the carried forward programme list */
    
    [[sharedAppController itvProgressIndicator]incrementBy:myQueueSize -1 ? 100.0f/(float)(myQueueSize -1.0f) : 100.0f];

    if ( !--myQueueLeft  )
        [self processCarriedForwardProgrammes];
}

-(void)processCarriedForwardProgrammes
{
    /* First we add or update datetimeadded for the carried forward programmes */
    
    NSSortDescriptor *sort1 = [NSSortDescriptor sortDescriptorWithKey:@"productionId" ascending:YES];
    
    [boughtForwardProgrammeArray sortUsingDescriptors:[NSArray arrayWithObjects:sort1, nil]];
    
    for ( int i=0; i < [carriedForwardProgrammeArray count]; i++ )  {
        ProgrammeData *cfProgramme = [carriedForwardProgrammeArray objectAtIndex:i];
                                      
        cfProgramme.timeAddedInt = [self searchForProductionId:cfProgramme.productionId inProgrammeArray:boughtForwardProgrammeArray];
        
        [carriedForwardProgrammeArray replaceObjectAtIndex:i withObject:cfProgramme];
    }

    /* Now we sort the programmes & write CF to disk */
    
    sort1 = [NSSortDescriptor sortDescriptorWithKey:@"programmeName" ascending:YES];
    NSSortDescriptor *sort2 = [NSSortDescriptor sortDescriptorWithKey:@"isNew" ascending:NO];
    NSSortDescriptor *sort3 = [NSSortDescriptor sortDescriptorWithKey:@"timeIntDateLastAired" ascending:NO];
    
    [carriedForwardProgrammeArray sortUsingDescriptors:[NSArray arrayWithObjects:sort1, sort2, sort3, nil]];
    
    [NSKeyedArchiver archiveRootObject:carriedForwardProgrammeArray toFile:programmesFilePath];

    
    /* Now create the cache file that used to be created by get_iplayer */
    
    NSMutableString *cacheFileContentString = [[NSMutableString alloc] initWithString:@"#index|type|name|pid|available|episode|seriesnum|episodenum|versions|duration|desc|channel|categories|thumbnail|timeadded|guidance|web\n"];

    int cacheIndexNumber = 100000;
    

    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"EEE MMM dd"];
    NSString *episodeString = nil;
    
    NSDateFormatter* dateFormatter1 = [[NSDateFormatter alloc] init];
    dateFormatter1.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    NSString *dateAiredString = nil;

    NSDate *dateAiredUTC;
    
    for (ProgrammeData *carriedForwardProgramme in carriedForwardProgrammeArray)    {
        
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
        [cacheFileContentString appendString:@"|"];
        [cacheFileContentString appendString:episodeString];
        [cacheFileContentString appendString:@"|||default|||ITV Player|TV||"];
        [cacheFileContentString appendFormat:@"%d||",carriedForwardProgramme.timeAddedInt];
        [cacheFileContentString appendString:carriedForwardProgramme.programmeURL];
        [cacheFileContentString appendString:@"|\n"];
    }

    NSData *cacheData = [cacheFileContentString dataUsingEncoding:NSUTF8StringEncoding];

    NSString *cacheFilePath = [filesPath stringByAppendingString:@"/itv.cache"];
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

    getITVShowRunning = false;
    [mySession finishTasksAndInvalidate];

    if (forceUpdateAllProgrammes)
        [nc postNotificationName:@"ForceITVUpdateFinished" object:nil];
    else
        [nc postNotificationName:@"ITVUpdateFinished" object:NULL];
    
    forceUpdateAllProgrammes = false;
    
    [logger addToLog:@"GetITVShows: Update Finished"];
}

-(int)searchForProductionId:(NSString *)productionId inProgrammeArray:(NSMutableArray *)programmeArray
{
    NSInteger startPoint = 0;
    NSInteger endPoint   = programmeArray.count -1;
    NSInteger midPoint = endPoint / 2;
    ProgrammeData *midProgramme;
    
    while (startPoint <= endPoint) {
        
        midProgramme = [programmeArray objectAtIndex:midPoint];
        NSString *midProductionId = midProgramme.productionId;

        NSComparisonResult result = [midProductionId compare:productionId];
        
        switch ( result )  {
            case NSOrderedAscending:
                startPoint = midPoint +1;
                break;
            case NSOrderedSame:
                return midProgramme.timeAddedInt ? midProgramme.timeAddedInt : intTimeThisRun;
                break;
            case NSOrderedDescending:
                endPoint = midPoint -1;
                break;
        }
        midPoint = (startPoint + endPoint)/2;
    }
    
    return intTimeThisRun;
}


-(void)mergeAllProgrammes
{
    int bfIndex = 0;
    int todayIndex = 0;
    
    ProgrammeData *bfProgramme = [boughtForwardProgrammeArray objectAtIndex:bfIndex];
    ProgrammeData *todayProgramme  = [todayProgrammeArray objectAtIndex:todayIndex];
    NSString *bfProgrammeName;
    NSString *todayProgrammeName;
    
    do {

        if (bfIndex < boughtForwardProgrammeArray.count) {
            bfProgramme = [boughtForwardProgrammeArray objectAtIndex:bfIndex];
            bfProgrammeName = bfProgramme.programmeName;
        }
        else {
            bfProgrammeName = @"~~~~~~~~~~";
        }
        if (todayIndex < todayProgrammeArray.count) {
            todayProgramme = [todayProgrammeArray objectAtIndex:todayIndex];
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
                    [carriedForwardProgrammeArray addObject:todayProgramme];
                }
                else {
                    myQueueSize++;
                    [self.myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(requestProgrammeEpisodes:) object:todayProgramme]];
                }
            
                todayIndex++;
                
                break;

            case NSOrderedSame:
                
                /* for programmes that have more then one current episode and cache update is forced or current episode has changed or new episodes have been found; get full episode listing */
                
                if (  todayProgramme.numberEpisodes > 1  &&
                     ( bfProgramme.forceCacheUpdate == true || ![todayProgramme.productionId isEqualToString:bfProgramme.productionId] ||todayProgramme.numberEpisodes > bfProgramme.numberEpisodes) )  {
                    
                        if (bfProgramme.forceCacheUpdate == true)
                            [logger addToLog:[NSString stringWithFormat:@"GetITVListings (Warning): Cache upate forced for: %@", bfProgramme.programmeName]];
                        
                        myQueueSize++;
                        
                        [self.myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(requestProgrammeEpisodes:)object:todayProgramme]];
                    
                        /* Now skip remaining BF episodes */
                    
                        for (bfIndex++; (bfIndex < boughtForwardProgrammeArray.count  &&
                                     [todayProgramme.programmeName isEqualToString:((ProgrammeData *)[boughtForwardProgrammeArray objectAtIndex:bfIndex]).programmeName]); bfIndex++ );
                 
                }
                
                else if ( todayProgramme.numberEpisodes == 1 )  {
                    
                    /* For programmes with only 1 episode found just copy it from today to CF */
                    
                    [todayProgramme makeNew];
                    [carriedForwardProgrammeArray addObject:todayProgramme];
                
                    /* Now skip remaining BF episodes (if any) */
                
                    for (bfIndex++; (bfIndex < boughtForwardProgrammeArray.count  &&
                                     [todayProgramme.programmeName isEqualToString:((ProgrammeData *)[boughtForwardProgrammeArray objectAtIndex:bfIndex]).programmeName]); bfIndex++ );
                }
                
                else if ( [todayProgramme.productionId isEqualToString:bfProgramme.productionId] && todayProgramme.numberEpisodes == bfProgramme.numberEpisodes  )              {
                    
                    /* For programmes where the current episode and number of episodes has not changed so just copy BF to CF  */
                    
                    do {
                        [carriedForwardProgrammeArray addObject:[boughtForwardProgrammeArray objectAtIndex:bfIndex]];
                        
                    } while (  ++bfIndex < boughtForwardProgrammeArray.count  &&
                             [todayProgramme.programmeName isEqualToString:((ProgrammeData *)[boughtForwardProgrammeArray objectAtIndex:bfIndex]).programmeName]);
                }
                
                else if ( todayProgramme.numberEpisodes < bfProgramme.numberEpisodes )  {
                    
                    /* For programmes where the current episode has changed but fewer episodes found today; copy available episodes & drop the remainder */
                    
                    for (int i = todayProgramme.numberEpisodes; i; i--, bfIndex++ ) {
                        ProgrammeData *pd = [boughtForwardProgrammeArray objectAtIndex:bfIndex];  
                        pd.numberEpisodes = todayProgramme.numberEpisodes;
                        [carriedForwardProgrammeArray addObject:pd];
                    }
                
                    /* and drop the rest */
                    
                    for (; (bfIndex < boughtForwardProgrammeArray.count  &&
                            [todayProgramme.programmeName isEqualToString:((ProgrammeData *)[boughtForwardProgrammeArray objectAtIndex:bfIndex]).programmeName]); bfIndex++ );
                }
                
                else {
                
                    /* Should never get here fo full reload & skip all episodes for this programme */
                    
                    [logger addToLog:[NSString stringWithFormat:@"GetITVListings (Error): Failed to correctly process %@ will issue a full refresh", todayProgramme]];
                    
                    myQueueSize++;
                    
                    [self.myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(requestProgrammeEpisodes:)object:todayProgramme]];
                    
                    for (bfIndex++; (bfIndex < boughtForwardProgrammeArray.count  &&
                                     [todayProgramme.programmeName isEqualToString:((ProgrammeData *)[boughtForwardProgrammeArray objectAtIndex:bfIndex]).programmeName]); bfIndex++ );
                }
        
        todayIndex++;
        
        break;
        
            case NSOrderedAscending:

                /*  BF not found; Skip all episdoes on BF as programme no longer available */
            
                for (bfIndex++; (bfIndex < boughtForwardProgrammeArray.count  &&
                             [bfProgramme.programmeName isEqualToString:((ProgrammeData *)[boughtForwardProgrammeArray objectAtIndex:bfIndex]).programmeName]);  bfIndex++ );
                
                break;
        }
        
    } while ( bfIndex < boughtForwardProgrammeArray.count  || todayIndex < todayProgrammeArray.count  );
    
    [logger addToLog:[NSString stringWithFormat:@"GetITVShows (Info): Merge complete B/F Programmes: %ld C/F Programmes: %ld Today Programmes: %ld ", boughtForwardProgrammeArray.count, carriedForwardProgrammeArray.count, todayProgrammeArray.count]];
    
    myQueueLeft = myQueueSize;
    
    if (myQueueSize < 2 )
        [[sharedAppController itvProgressIndicator]incrementBy:100.0f];

    if (!myQueueSize)
        [self processCarriedForwardProgrammes];
}

-(BOOL)createTodayProgrammeArray
{
    /* Scan itv.com/shows to create full listing of programmes (not episodes) that are available today */
    
    todayProgrammeArray = [[NSMutableArray alloc]init];
    NSScanner *scanner = [NSScanner scannerWithString:htmlData];

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
    
    [scanner scanUpToString:@"<a href=\"http://www.itv.com/hub/" intoString:NULL];
    [scanner scanUpToString:@"</a>" intoString:&fullProgramme];
    
    while ( (![scanner isAtEnd]) && ++testingProgrammeCount ) {
    
        NSScanner *fullProgrammeScanner = [NSScanner scannerWithString:fullProgramme];
        scanPoint = fullProgrammeScanner.scanLocation;
        
        /* URL */
        
        [fullProgrammeScanner scanString:@"<a href=\"" intoString:NULL];
        [fullProgrammeScanner scanUpToString:@"\"" intoString:&programmeURL];
        
        /* Programme Name */
        
        fullProgrammeScanner.scanLocation = scanPoint;
        [fullProgrammeScanner scanString:@"<a href=\"http://www.itv.com/hub/" intoString:NULL];
        [fullProgrammeScanner scanUpToString:@"/" intoString:&programmeName];
        
        /* Production ID */
        
        [fullProgrammeScanner scanUpToString:@"productionId=" intoString:NULL];
        [fullProgrammeScanner scanString:@"productionId=" intoString:NULL];
        [fullProgrammeScanner scanUpToString:@"\"" intoString:&token];
        productionId=[token stringByRemovingPercentEncoding];
        
        /* Get mumber of episodes, assume 1 if you cant figure it out */
        
        numberEpisodes  = 1;
        
        [fullProgrammeScanner scanUpToString:@"<p class=\"tout__meta theme__meta\">" intoString:&temp];
        
        if ( ![fullProgrammeScanner isAtEnd])  {
            [fullProgrammeScanner scanString:@"<p class=\"tout__meta theme__meta\">" intoString:&temp];
            scanPoint = fullProgrammeScanner.scanLocation;
            [fullProgrammeScanner scanUpToString:@"episode" intoString:&temp];
                
            if ( ![fullProgrammeScanner isAtEnd])  {
                fullProgrammeScanner.scanLocation = scanPoint;
                [fullProgrammeScanner scanInt:&numberEpisodes];
            }
        }
        
        /* Create ProgrammeData Object and store in array */
        
        ProgrammeData *myProgramme = [[ProgrammeData alloc]initWithName:programmeName andPID:productionId andURL:programmeURL andNUMBEREPISODES:numberEpisodes andDATELASTAIRED:timeIntervalSince1970UTC];
        [todayProgrammeArray addObject:myProgramme];
        
        /* Scan for next programme */
        
        [scanner scanUpToString:@"<a href=\"http://www.itv.com/hub/" intoString:NULL];
        [scanner scanUpToString:@"</a>" intoString:&fullProgramme];
        
    }

    /* Now we sort the programmes and the drop duplicates */
    
    if ( !todayProgrammeArray.count )  {
        [logger addToLog:@"No programmes found on www.itv.com/hub/shows"];
        
        NSAlert *noProgs = [NSAlert alertWithMessageText:@"No prgogrammes were found on www.itv.com/hub/shows"
                                                 defaultButton:@"OK"
                                               alternateButton:nil
                                                   otherButton:nil
                                     informativeTextWithFormat:@"Try again later, if problem persists create a support request"];
        [noProgs runModal];
        
        return NO;
    }
    
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"programmeName" ascending:YES];
    [todayProgrammeArray sortUsingDescriptors:[NSArray arrayWithObject:sort]];
    
    for (int i=0; i < todayProgrammeArray.count -1; i++) {
        ProgrammeData *programme1 = [todayProgrammeArray objectAtIndex:i];
        ProgrammeData *programme2 = [todayProgrammeArray objectAtIndex:i+1];
        
        if ( [programme1.programmeName isEqualToString:programme2.programmeName] ) {
            [todayProgrammeArray removeObjectAtIndex:i];
        }
    }

    return YES;
}

@end


@implementation ProgrammeData


- (id)initWithName:(NSString *)name andPID:(NSString *)pid andURL:(NSString *)url andNUMBEREPISODES:(int)numberEpisodes andDATELASTAIRED:(NSTimeInterval)timeIntDateLastAired;
{
    self.programmeName = name;
    [self fixProgrammeName];
    self.productionId = pid;
    self.programmeURL = url;
    self.numberEpisodes = numberEpisodes;
    seriesNumber = 0;
    episodeNumber = 0;
    isNew = false;
    self.forceCacheUpdate = false;
    self.timeIntDateLastAired = timeIntDateLastAired;
    self.timeAddedInt = 0;
    
    return self;
    
}

- (id)addProgrammeSeriesInfo:(int)aSeriesNumber :(int)aEpisodeNumber
{
    seriesNumber = aSeriesNumber;
    episodeNumber = aEpisodeNumber;
    
    return self;
}

- (id)makeNew
{
    isNew = true;
    
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
    [encoder encodeObject:[NSNumber numberWithInt:self.numberEpisodes] forKey:@"numberEpisodes"];
    [encoder encodeObject:[NSNumber numberWithInt:seriesNumber] forKey:@"seriesNumber"];
    [encoder encodeObject:[NSNumber numberWithInt:episodeNumber] forKey:@"episodeNumber"];
    [encoder encodeObject:[NSNumber numberWithInt:isNew] forKey:@"isNew"];
    [encoder encodeObject:[NSNumber numberWithInt:self.forceCacheUpdate] forKey:@"forceCacheUpdate"];
    [encoder encodeObject:[NSNumber numberWithFloat:self.timeIntDateLastAired] forKey:@"timeIntDateLastAired"];
    [encoder encodeObject:[NSNumber numberWithInt:self.timeAddedInt] forKey:@"timeAddedInt"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (self != nil) {
        self.programmeName = [decoder decodeObjectForKey:@"programmeName"];
        self.productionId = [decoder decodeObjectForKey:@"productionId"];
        self.programmeURL = [decoder decodeObjectForKey:@"programmeURL"];
        self.numberEpisodes = [[decoder decodeObjectForKey:@"numberEpisodes"] intValue];
        seriesNumber = [[decoder decodeObjectForKey:@"seriesNumber"] intValue];
        episodeNumber = [[decoder decodeObjectForKey:@"episodeNumber"] intValue];
        isNew = [[decoder decodeObjectForKey:@"isNew"] intValue];
        self.forceCacheUpdate = [[decoder decodeObjectForKey:@"forceCacheUpdate"] intValue];
        self.timeIntDateLastAired = [[decoder decodeObjectForKey:@"timeIntDateLastAired"] floatValue];
        self.timeAddedInt = [[decoder decodeObjectForKey:@"timeAddedInt"] intValue];
    }
    
    return self;
}

-(void)fixProgrammeName
{
    self.programmeName = [self.programmeName stringByReplacingOccurrencesOfString:@"-" withString:@" "];
    self.programmeName = [self.programmeName capitalizedString];
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

-(id)init
{
    if (self = [super init]) {
        
        itemsAdded = false;
        historyFilePath = @"~/Library/Application Support/Get iPlayer Automator/history.gia";
        historyFilePath= [historyFilePath stringByExpandingTildeInPath];
        programmeHistoryArray = [NSKeyedUnarchiver unarchiveObjectWithFile:historyFilePath];
        
        if ( programmeHistoryArray == nil )
               programmeHistoryArray = [[NSMutableArray alloc]init];
        
        /* Cull history if > 3,000 entries */
        
        while ( [programmeHistoryArray count] > 3000 )
            [programmeHistoryArray removeObjectAtIndex:0];
        
        timeIntervalSince1970UTC = [[NSDate date] timeIntervalSince1970];
        timeIntervalSince1970UTC += [[NSTimeZone systemTimeZone] secondsFromGMTForDate:[NSDate date]];
        timeIntervalSince1970UTC /= (24*60*60);
        
        NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"EEE MMM dd"];
        dateFound = [dateFormatter stringFromDate:[NSDate date]];
    }
    return self;
}

-(void)addToNewProgrammeHistory:(NSString *)name andTVChannel:(NSString *)tvChannel andNetworkName:(NSString *)netwokrName
{
    itemsAdded = true;
    ProgrammeHistoryObject *newEntry = [[ProgrammeHistoryObject alloc]initWithName:name andTVChannel:tvChannel andDateFound:dateFound andSortKey:timeIntervalSince1970UTC andNetworkName:netwokrName];
    [programmeHistoryArray addObject:newEntry];
}

-(NSMutableArray *)getHistoryArray
{
    if (itemsAdded)
        [self flushHistoryToDisk];
    
    return programmeHistoryArray;
}

-(void)flushHistoryToDisk;
{
    itemsAdded = false;
    
    /* Sort history array and flush to disk */
    
    NSSortDescriptor *sort1 = [NSSortDescriptor sortDescriptorWithKey:@"sortKey" ascending:YES];
    NSSortDescriptor *sort2 = [NSSortDescriptor sortDescriptorWithKey:@"programmeName" ascending:YES];
    NSSortDescriptor *sort3 = [NSSortDescriptor sortDescriptorWithKey:@"tvChannel" ascending:YES];
    
    [programmeHistoryArray sortUsingDescriptors:[NSArray arrayWithObjects:sort1, sort2, sort3, nil]];
    
    [NSKeyedArchiver archiveRootObject:programmeHistoryArray toFile:historyFilePath];
}

@end

@implementation ProgrammeHistoryObject

- (id)initWithName:(NSString *)name andTVChannel:(NSString *)aTVChannel andDateFound:(NSString *)dateFound andSortKey:(NSUInteger)aSortKey andNetworkName:(NSString *)networkName
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
    [encoder encodeObject:[NSNumber numberWithLong:self.sortKey] forKey:@"sortKey"];
    [encoder encodeObject:self.programmeName forKey:@"programmeName"];
    [encoder encodeObject:self.dateFound forKey:@"dateFound"];
    [encoder encodeObject:self.tvChannel forKey:@"tvChannel"];
    [encoder encodeObject:self.networkName forKey:@"networkName"];
}

- (id)initWithCoder:(NSCoder *)decoder
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
    return [self.programmeName hash];
}
@end


