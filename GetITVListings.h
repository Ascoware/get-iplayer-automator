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

@property (nonatomic, assign) NSInteger afield;
@property (nonatomic, assign) NSInteger seriesNumber;
@property (nonatomic, assign) NSInteger episodeNumber;
@property (nonatomic, assign) BOOL isNew;
@property (nonatomic)  NSString *programmeName;
@property (nonatomic) NSString *productionId;
@property (nonatomic) NSString *programmeURL;
@property (nonatomic, assign) NSInteger numberEpisodes;
@property (nonatomic, assign) NSInteger forceCacheUpdate;
@property (nonatomic, assign) NSTimeInterval timeIntDateLastAired;
@property (nonatomic, assign) NSInteger timeAddedInt;

- (instancetype)initWithName:(NSString *)name andPID:(NSString *)pid andURL:(NSString *)url andNUMBEREPISODES:(NSInteger)numberEpisodes andDATELASTAIRED:(NSTimeInterval)timeIntDateLastAired;
- (id)addProgrammeSeriesInfo:(int)seriesNumber :(int)episodeNumber;
@property (nonatomic, readonly, strong) id makeNew;
@property (nonatomic, readonly, strong) id forceCacheUpdateOn;
-(void)fixProgrammeName;

@end


@interface ProgrammeHistoryObject : NSObject <NSCoding>
@property (nonatomic, assign) long      sortKey;
@property (nonatomic) NSString  *programmeName;
@property (nonatomic) NSString  *dateFound;
@property (nonatomic) NSString  *tvChannel;
@property (nonatomic) NSString  *networkName;

- (instancetype)initWithName:(NSString *)name andTVChannel:(NSString *)aTVChannel andDateFound:(NSString *)dateFound andSortKey:(NSUInteger)sortKey andNetworkName:(NSString *)networkName;

@end


@interface NewProgrammeHistory : NSObject

@property (nonatomic)     NSString        *historyFilePath;
@property (nonatomic) NSMutableArray  *programmeHistoryArray;
@property (nonatomic, assign) BOOL            itemsAdded;
@property (nonatomic, assign) NSUInteger      timeIntervalSince1970UTC;
@property (nonatomic) NSString        *dateFound;
@property (nonatomic, getter=getHistoryArray, readonly, copy) NSMutableArray *historyArray;

+(NewProgrammeHistory*)sharedInstance;

-(instancetype)init;
-(void)addToNewProgrammeHistory:(NSString *)name andTVChannel:(NSString *)tvChannel andNetworkName:(NSString *)networkName;
-(void)flushHistoryToDisk;

@end

@interface GetITVShows : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (nonatomic, assign)    NSUInteger          myQueueSize;
@property (nonatomic, assign) NSUInteger          myQueueLeft;
@property (nonatomic) NSURLSession        *mySession;
@property (nonatomic) NSString            *htmlData;
@property (nonatomic) NSMutableArray      *boughtForwardProgrammeArray;
@property (nonatomic) NSMutableArray      *todayProgrammeArray;
@property (nonatomic) NSMutableArray      *carriedForwardProgrammeArray;
@property (nonatomic) NSString            *filesPath;
@property (nonatomic) NSString            *programmesFilePath;
@property (nonatomic, assign) BOOL                getITVShowRunning;
@property (nonatomic, assign) BOOL                forceUpdateAllProgrammes;
@property (nonatomic, assign) NSTimeInterval      timeIntervalSince1970UTC;
@property (nonatomic, assign) NSInteger                 intTimeThisRun;
@property (nonatomic) LogController       *logger;
@property (nonatomic) NSOperationQueue  *myOpQueue;
@property (nonatomic, readonly) id requestTodayListing;
@property (nonatomic, readonly) BOOL createTodayProgrammeArray;

-(instancetype)init;
-(void)itvUpdateWithLogger:(LogController *)theLogger;;
-(void)forceITVUpdateWithLogger:(LogController *)theLogger;
-(void)requestProgrammeEpisodes:(ProgrammeData *)myProgramme;
-(void)processProgrammeEpisodesData:(ProgrammeData *)myProgramm :(NSString *)myHtmlData;
-(void)processCarriedForwardProgrammes;
-(NSInteger)searchForProductionId:(NSString *)productionId inProgrammeArray:(NSMutableArray *)programmeArray;
-(void)endOfRun;

@end


#endif /* GetITVListings_h */
