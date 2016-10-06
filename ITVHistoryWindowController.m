//
//  ITVHistoryWindowController.m
//  Get_iPlayer GUI
//
//  Created by LFS on 8/6/16.
//
//

#import "GetITVListings.h"
#import "ITVHistoryWindowController.h"
#import "GetITVListings.h"

NewProgrammeHistory *sharedHistoryContoller;

@implementation ITVHistoryTableViewController

-(id)init
{
    self = [super init];
    
    if (!self)
        return self;
    
    /* Load in programme History */

    sharedHistoryContoller = [NewProgrammeHistory sharedInstance];
    programmeHistoryArray =  [sharedHistoryContoller getHistoryArray];
    
    historyDisplayArray = [[NSMutableArray alloc]init];
    
    [self loadDisplayData];
    
    NSNotificationCenter *nc;
    nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self selector:@selector(loadDisplayData) name:@"NewProgrammeDisplayFilterChanged" object:nil];
    
    return self;
}

- (IBAction)changeFilter:(id)sender {
    [self loadDisplayData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [historyDisplayArray count];
    
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    
    ProgrammeHistoryObject *np = [historyDisplayArray objectAtIndex:row];
    
    NSString *identifer = [tableColumn identifier];
    
    return [np valueForKey:identifer];
    
}

-(void)loadDisplayData
{
    NSString *displayDate = nil;
    NSString *headerDate = nil;
    NSString *theItem = nil;
    int     pageNumber = 0;
    
    /* Set up date for use in headings comparison */
    
    double secondsSince1970 = [[NSDate date] timeIntervalSince1970];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];            [dateFormatter setDateFormat:@"EEE MMM dd"];
    NSDateFormatter *dateFormatterDayOfWeek = [[NSDateFormatter alloc] init];   [dateFormatterDayOfWeek setDateFormat:@"EEEE"];
    
    NSMutableDictionary *dayNames = [[NSMutableDictionary alloc]init];

    NSString *keyValue;
    NSString *key;
    
    for (int i=0;i<7;i++, secondsSince1970-=(24*60*60)) {
        
        if (i==0)
            keyValue = @"Today";
        else if (i==1)
            keyValue = @"Yesterday";
        else
            keyValue = [dateFormatterDayOfWeek stringFromDate:[NSDate dateWithTimeIntervalSince1970:secondsSince1970]];
        
        key = [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:secondsSince1970]];
        
        [dayNames setValue:keyValue forKey:key];
    }
    
    [historyDisplayArray removeAllObjects];
    
    for (ProgrammeHistoryObject *np in programmeHistoryArray )  {
        
        if ( [self showITVProgramme:np] || [self showBBCProgramme:np] || [self showRadioProgramme:np] )  {
                                                                                                            
            if ( [np.dateFound isNotEqualTo:displayDate] ) {
                
                displayDate = np.dateFound;
                
                headerDate = [dayNames objectForKey:np.dateFound];
                
                if (!headerDate)  {
                    headerDate = @"On : ";
                    headerDate = [headerDate stringByAppendingString:displayDate];
                }
                
                [historyDisplayArray addObject:[[HistoryDisplay alloc]initWithItemString:nil andTVChannel:nil andLineNumber:2 andPageNumber:pageNumber]];
                
                [historyDisplayArray addObject:[[HistoryDisplay alloc]initWithItemString:headerDate andTVChannel:nil andLineNumber:0 andPageNumber:++pageNumber]];
            }
            
            theItem = @"     ";
            theItem = [theItem stringByAppendingString:[np programmeName]];
            
            [historyDisplayArray addObject:[[HistoryDisplay alloc]initWithItemString:theItem andTVChannel:np.tvChannel andLineNumber:1 andPageNumber:pageNumber]];
        }
    }
    
    [historyDisplayArray addObject:[[HistoryDisplay alloc]initWithItemString:nil andTVChannel:nil andLineNumber:2 andPageNumber:pageNumber]];
    
    /* Sort in to programme within reverse date order */

    NSSortDescriptor *sort4 = [NSSortDescriptor sortDescriptorWithKey:@"networkNameString" ascending:YES];
    NSSortDescriptor *sort3 = [NSSortDescriptor sortDescriptorWithKey:@"programmeNameString" ascending:YES];
    NSSortDescriptor *sort2 = [NSSortDescriptor sortDescriptorWithKey:@"lineNumber" ascending:YES];
    NSSortDescriptor *sort1 = [NSSortDescriptor sortDescriptorWithKey:@"pageNumber" ascending:NO];
    [historyDisplayArray sortUsingDescriptors:[NSArray arrayWithObjects:sort1, sort2, sort3, sort4, nil]];
    
    [historyTable reloadData];
    
    return;
}

-(BOOL)showITVProgramme:(ProgrammeHistoryObject *)np
{
    return [[[NSUserDefaults standardUserDefaults] valueForKey:@"showITVProgrammes"]isEqualTo:@YES] && [np.networkName isEqualToString:@"ITV"]?YES:NO;
}
-(BOOL)showBBCProgramme:(ProgrammeHistoryObject *)np
{
    
    if ( [[[NSUserDefaults standardUserDefaults] valueForKey:@"showBBCProgrammes"]isEqualTo:@NO] )
        return NO;
    
    if ( ![np.networkName isEqualToString:@"BBC TV"] )
        return NO;
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"IgnoreAllTVNews"]isEqualTo:@YES] &&
        ([np.programmeName containsString:@"News"] || [np.programmeName containsString:@"news"]))
        return NO;
    
    if (([[[NSUserDefaults standardUserDefaults] valueForKey:@"BBC1"]isEqualTo:@YES] && [np.tvChannel hasPrefix:@"BBC One"]) ||
         ([[[NSUserDefaults standardUserDefaults] valueForKey:@"BBC2"]isEqualTo:@YES] && [np.tvChannel hasPrefix:@"BBC Two"]) ||
         ([[[NSUserDefaults standardUserDefaults] valueForKey:@"BBC3"]isEqualTo:@YES] && [np.tvChannel hasPrefix:@"BBC Three"]) ||
         ([[[NSUserDefaults standardUserDefaults] valueForKey:@"BBC4"]isEqualTo:@YES] && [np.tvChannel hasPrefix:@"BBC Four"]) ||
         ([[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCNews"]isEqualTo:@YES] && [np.tvChannel isEqualToString:@"BBC News"]) ||
         ([[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCParliament"]isEqualTo:@YES] && [np.tvChannel isEqualToString:@"BBC Parliament"]) ||
         ([[[NSUserDefaults standardUserDefaults] valueForKey:@"S4C"]isEqualTo:@YES] && [np.tvChannel isEqualToString:@"S4C"]) ||
         ([[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCAlba"]isEqualTo:@YES] && [np.tvChannel isEqualToString:@"BBC Alba"]) ||
         ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CBeebies"]isEqualTo:@YES] && [np.tvChannel isEqualToString:@"CBeebies"]) ||
         ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CBBC"]isEqualTo:@YES] && [np.tvChannel isEqualToString:@"CBBC"])
        )
        return YES;
    
    return NO;
}
-(BOOL)showRadioProgramme:(ProgrammeHistoryObject *)np
{
    NSArray *regions = @[@"Radio Scotland", @"Radio Nan", @"Radio Shetland", @"Radio Orkney", @"Radio Wales", @"Radio Cymru", @"Radio Ulster", @"Radio Foyle" ];
   
    /* Filter out if not radio or news and news not wanted */
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"showBBCRadio"]isEqualTo:@NO])
        return NO;
    
    if (![np.networkName isEqualToString:@"BBC Radio"])
        return NO;
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"IgnoreAllRadioNews"]isEqualTo:@YES] &&
        ([np.programmeName containsString:@"News"] || [np.programmeName containsString:@"news"]))
        return NO;

    /* Filter each of the nationals in turn */
    
    if  ([np.tvChannel isEqualToString:@"BBC Radio 1"])
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio1"]isEqualTo:@YES] ? YES:NO;

    if ([np.tvChannel isEqualToString:@"BBC Radio 2"])
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio2"]isEqualTo:@YES] ? YES:NO;
    
    if ([np.tvChannel isEqualToString:@"BBC Radio 3"])
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio3"]isEqualTo:@YES] ? YES:NO;
    
    if ([np.tvChannel isEqualToString:@"BBC Radio 4"])
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio4"]isEqualTo:@YES] ? YES:NO;
    
    if ([np.tvChannel isEqualToString:@"BBC Radio 1Xtra"])
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio1Xtra"]isEqualTo:@YES] ? YES:NO;
    
    if ([np.tvChannel isEqualToString:@"BBC Radio 4 Extra"])
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio4extra"]isEqualTo:@YES] ? YES:NO;
    
    if ([np.tvChannel isEqualToString:@"BBC Radio 5 live"])
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio5Live"]isEqualTo:@YES] ? YES:NO;
    
    if ([np.tvChannel isEqualToString:@"BBC 5 live sports extra"])
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio5LiveSportsExtra"]isEqualTo:@YES]  ? YES:NO;
    
    if ([np.tvChannel isEqualToString:@"BBC 6 Music"])
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio6Music"]isEqualTo:@YES] ? YES:NO;

    if ([np.tvChannel isEqualToString:@"BBC Asian Network"])
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCRadioAsianNetwork"]isEqualTo:@YES] ? YES:NO;
    
    if ([np.tvChannel isEqualToString:@"BBC World Service"])
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCWorldService"]isEqualTo:@YES]  ? YES:NO;
    
    /* Filter for regionals */
    
    for (int i=0; i<regions.count;i++)
        if ([np.tvChannel containsString:regions[i]])
            return [[[NSUserDefaults standardUserDefaults] valueForKey:@"ShowRegionalRadioChannels"]isEqualTo:@YES] ? YES:NO;
    
    /* Otherwise must be local */
    
    return [[[NSUserDefaults standardUserDefaults] valueForKey:@"ShowLocalRadioChannels"]isEqualTo:@YES] ? YES:NO;

}

@end




@implementation HistoryDisplay

- (id)initWithItemString:(NSString *)aItemString andTVChannel:(NSString *)aTVChannel andLineNumber:(int)aLineNumber andPageNumber:(int)aPageNumber;
{
    programmeNameString = aItemString;
    lineNumber = aLineNumber;
    pageNumber  = aPageNumber;
    networkNameString = aTVChannel;
    
    return self;
}

@end


