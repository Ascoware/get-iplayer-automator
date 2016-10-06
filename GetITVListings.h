//
//  GetITVListings.h
//  ITVLoader
//
//  Created by LFS on 6/25/16.
//


#ifndef GetITVListings_h
#define GetITVListings_h

#import "AppController.h"

@interface ProgrammeData : NSObject <NSCoding>
{
    int afield;
    int seriesNumber;
    int episodeNumber;
    int isNew;
}
@property NSString *programmeName;
@property NSString *productionId;
@property NSString *programmeURL;
@property int numberEpisodes;
@property int forceCacheUpdate;
@property NSTimeInterval timeIntDateLastAired;
@property int timeAddedInt;

- (id)initWithName:(NSString *)name andPID:(NSString *)pid andURL:(NSString *)url andNUMBEREPISODES:(int)numberEpisodes andDATELASTAIRED:(NSTimeInterval)timeIntDateLastAired;
- (id)addProgrammeSeriesInfo:(int)seriesNumber :(int)episodeNumber;
- (id)makeNew;
- (id)forceCacheUpdateOn;
-(void)fixProgrammeName;


@end


@interface ProgrammeHistoryObject : NSObject <NSCoding>
{
   // long      sortKey;
}
@property long      sortKey;
@property NSString  *programmeName;
@property NSString  *dateFound;
@property NSString  *tvChannel;
@property NSString  *networkName;

- (id)initWithName:(NSString *)name andTVChannel:(NSString *)aTVChannel andDateFound:(NSString *)dateFound andSortKey:(NSUInteger)sortKey andNetworkName:(NSString *)networkName;

@end


@interface NewProgrammeHistory : NSObject
{
    NSString        *historyFilePath;
    NSMutableArray  *programmeHistoryArray;
    BOOL            itemsAdded;
    NSUInteger      timeIntervalSince1970UTC;
    NSString        *dateFound;
}

+(NewProgrammeHistory*)sharedInstance;
-(id)init;
-(void)addToNewProgrammeHistory:(NSString *)name andTVChannel:(NSString *)tvChannel andNetworkName:(NSString *)netwokrName;
-(void)flushHistoryToDisk;
-(NSMutableArray *)getHistoryArray;

@end

@interface GetITVShows : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
{
    NSUInteger          myQueueSize;
    NSUInteger          myQueueLeft;
    NSURLSession        *mySession;
    NSString            *htmlData;
    NSMutableArray      *boughtForwardProgrammeArray;
    NSMutableArray      *todayProgrammeArray;
    NSMutableArray      *carriedForwardProgrammeArray;
    NSString            *filesPath;
    NSString            *programmesFilePath;
    BOOL                getITVShowRunning;
    BOOL                forceUpdateAllProgrammes;
    NSTimeInterval      timeIntervalSince1970UTC;
    int                 intTimeThisRun;
    LogController       *logger;
    NSNotificationCenter *nc;
}

@property NSOperationQueue  *myOpQueue;

-(id)init;
-(void)itvUpdateWithLogger:(LogController *)theLogger;;
-(void)forceITVUpdateWithLogger:(LogController *)theLogger;
-(id)requestTodayListing;
-(BOOL)createTodayProgrammeArray;
-(void)requestProgrammeEpisodes:(ProgrammeData *)myProgramme;
-(void)processProgrammeEpisodesData:(ProgrammeData *)myProgramm :(NSString *)myHtmlData;
-(void)processCarriedForwardProgrammes;
-(int)searchForProductionId:(NSString *)productionId inProgrammeArray:(NSMutableArray *)programmeArray;
-(void)endOfRun;

@end


#endif /* GetITVListings_h */
