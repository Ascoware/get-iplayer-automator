//
//  NPHistoryWindowController.m
//  Get_iPlayer GUI
//
//  Created by LFS on 8/6/16.
//
//

#import "NPHistoryWindowController.h"
#import <Get_iPlayer_Automator-Swift.h>

NewProgrammeHistory *sharedHistoryContoller;

@implementation NPHistoryTableViewController

-(instancetype)init
{
    self = [super init];
    
    if (!self)
        return self;
    
    /* Load in programme History */

    sharedHistoryContoller = [NewProgrammeHistory sharedInstance];
    programmeHistoryArray =  sharedHistoryContoller.programmeHistoryArray;
    
    historyDisplayArray = [[NSMutableArray alloc]init];
    
    [self loadDisplayData];
        
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadDisplayData) name:@"NewProgrammeDisplayFilterChanged" object:nil];
    
    return self;
}

- (IBAction)changeFilter:(id)sender {
    [self loadDisplayData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return historyDisplayArray.count;
    
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    
    ProgrammeHistoryObject *np = historyDisplayArray[row];
    
    NSString *identifer = tableColumn.identifier;
    
    return [np valueForKey:identifer];
    
}

-(void)loadDisplayData
{
    NSString *displayDate = nil;
    NSString *headerDate = nil;
    NSString *theItem = nil;
    int     pageNumber = 0;
    
    /* Set up date for use in headings comparison */
    
    double secondsSince1970 = [NSDate date].timeIntervalSince1970;
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];            dateFormatter.dateFormat = @"EEE MMM dd";
    NSDateFormatter *dateFormatterDayOfWeek = [[NSDateFormatter alloc] init];   dateFormatterDayOfWeek.dateFormat = @"EEEE";
    
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
        
        if ( [self showITVProgramme:np] || [self showBBCTVProgramme:np] || [self showBBCRadioProgramme:np] )  {
                                                                                                            
            if ( [np.dateFound isNotEqualTo:displayDate] ) {
                
                displayDate = np.dateFound;
                
                headerDate = dayNames[np.dateFound];
                
                if (!headerDate)  {
                    headerDate = @"On : ";
                    headerDate = [headerDate stringByAppendingString:displayDate];
                }
                
                [historyDisplayArray addObject:[[HistoryDisplay alloc]initWithItemString:nil andTVChannel:nil andLineNumber:2 andPageNumber:pageNumber]];
                
                [historyDisplayArray addObject:[[HistoryDisplay alloc]initWithItemString:headerDate andTVChannel:nil andLineNumber:0 andPageNumber:++pageNumber]];
            }
            
            theItem = @"     ";
            theItem = [theItem stringByAppendingString:np.programmeName];
            
            [historyDisplayArray addObject:[[HistoryDisplay alloc]initWithItemString:theItem andTVChannel:np.tvChannel andLineNumber:1 andPageNumber:pageNumber]];
        }
    }
    
    [historyDisplayArray addObject:[[HistoryDisplay alloc]initWithItemString:nil andTVChannel:nil andLineNumber:2 andPageNumber:pageNumber]];
    
    /* Sort in to programme within reverse date order */

    NSSortDescriptor *sort4 = [NSSortDescriptor sortDescriptorWithKey:@"networkNameString" ascending:YES];
    NSSortDescriptor *sort3 = [NSSortDescriptor sortDescriptorWithKey:@"programmeNameString" ascending:YES];
    NSSortDescriptor *sort2 = [NSSortDescriptor sortDescriptorWithKey:@"lineNumber" ascending:YES];
    NSSortDescriptor *sort1 = [NSSortDescriptor sortDescriptorWithKey:@"pageNumber" ascending:NO];
    [historyDisplayArray sortUsingDescriptors:@[sort1, sort2, sort3, sort4]];
    
    [historyTable reloadData];
    
    return;
}

-(BOOL)showITVProgramme:(ProgrammeHistoryObject *)np
{
    if ( [[[NSUserDefaults standardUserDefaults] valueForKey:@"ShowITV"]isEqualTo:@NO] )
        return NO;
    
    if ( ![np.networkName isEqualToString:@"ITV"] )
        return NO;

    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"IgnoreAllTVNews"]isEqualTo:@YES]) {
        if ([np.programmeName rangeOfString:@"news" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return NO;
        }
    }
    
    return YES;
}
-(BOOL)showBBCTVProgramme:(ProgrammeHistoryObject *)np
{
/*
    'p00fzl6b' => 'BBC Four', # bbcfour/programmes/schedules
    'p00fzl6g' => 'BBC News', # bbcnews/programmes/schedules
    'p00fzl6n' => 'BBC One', # bbcone/programmes/schedules/hd
    'p00fzl73' => 'BBC Parliament', # bbcparliament/programmes/schedules
    'p015pksy' => 'BBC Two', # bbctwo/programmes/schedules/hd
    'p00fzl9r' => 'CBBC', # cbbc/programmes/schedules
    'p00fzl9s' => 'CBeebies', # cbeebies/programmes/schedules
*/
/*
 'p00fzl67' => 'BBC Alba', # bbcalba/programmes/schedules
 'p00fzl6q' => 'BBC One Northern Ireland', # bbcone/programmes/schedules/ni
 'p00zskxc' => 'BBC One Northern Ireland', # bbcone/programmes/schedules/ni_hd
 'p00fzl6v' => 'BBC One Scotland', # bbcone/programmes/schedules/scotland
 'p013blmc' => 'BBC One Scotland', # bbcone/programmes/schedules/scotland_hd
 'p00fzl6z' => 'BBC One Wales', # bbcone/programmes/schedules/wales
 'p013bkc7' => 'BBC One Wales', # bbcone/programmes/schedules/wales_hd
 'p06kvypx' => 'BBC Scotland', # bbcscotland/programmes/schedules
 'p06p396y' => 'BBC Scotland', # bbcscotland/programmes/schedules/hd
 'p00fzl97' => 'BBC Two England', # bbctwo/programmes/schedules/england
 'p00fzl99' => 'BBC Two Northern Ireland', # bbctwo/programmes/schedules/ni
 'p06ngcbm' => 'BBC Two Northern Ireland', # bbctwo/programmes/schedules/ni_hd
 'p00fzl9d' => 'BBC Two Wales', # bbctwo/programmes/schedules/wales
 'p06ngc52' => 'BBC Two Wales', # bbctwo/programmes/schedules/wales_hd
 'p020dmkf' => 'S4C', # s4c/programmes/schedules
*/
    NSArray *regionalChannels = @[
                                 @"BBC Alba",
                                 @"BBC One Northern Ireland",
                                 @"BBC One Scotland",
                                 @"BBC One Wales",
                                 @"BBC Scotland",
                                 @"BBC Two England",
                                 @"BBC Two Northern Ireland",
                                 @"BBC Two Wales",
                                 @"S4C"];
    
    if ( [[[NSUserDefaults standardUserDefaults] valueForKey:@"ShowBBCTV"]isEqualTo:@NO] )
        return NO;
    
    if ( ![np.networkName isEqualToString:@"BBC TV"] )
        return NO;
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"IgnoreAllTVNews"]isEqualTo:@YES]) {
        if ([np.programmeName rangeOfString:@"news" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return NO;
        }
    }

    if ([np.tvChannel isEqualToString:@"BBC Four"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCFour"]isEqualTo:@YES];
    }
    
    if ([np.tvChannel isEqualToString:@"BBC News"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCNews"]isEqualTo:@YES];
    }
    
    if ([np.tvChannel isEqualToString:@"BBC One"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCOne"]isEqualTo:@YES];
    }
    
    if ([np.tvChannel isEqualToString:@"BBC Parliament"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCParliament"]isEqualTo:@YES];
    }
    
    if ([np.tvChannel isEqualToString:@"BBC Two"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCTwo"]isEqualTo:@YES];
    }
    
    if ([np.tvChannel isEqualToString:@"CBBC"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"CBBC"]isEqualTo:@YES];
    }
    
    if ([np.tvChannel isEqualToString:@"CBeebies"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"CBeebies"]isEqualTo:@YES];
    }
    
    // Next, filter out regional channels
    BOOL showRegionalTV = [[[NSUserDefaults standardUserDefaults] valueForKey:@"ShowRegionalTVStations"]isEqualTo:@YES];
    for (NSString *region in regionalChannels) {
        if ([np.tvChannel containsString:region]) {
            return showRegionalTV;
        }
    }
    
    /* Otherwise must be local */
    return [[[NSUserDefaults standardUserDefaults] valueForKey:@"ShowLocalTVStations"]isEqualTo:@YES];
}

-(BOOL)showBBCRadioProgramme:(ProgrammeHistoryObject *)np
{
/*
 'p00fzl7b' => 'BBC Radio Cymru', # radiocymru/programmes/schedules
 'p00fzl7m' => 'BBC Radio Foyle', # radiofoyle/programmes/schedules
 'p00fzl81' => 'BBC Radio Nan Gaidheal', # radionangaidheal/programmes/schedules
 'p00fzl8d' => 'BBC Radio Scotland', # radioscotland/programmes/schedules/fm
 'p00fzl8g' => 'BBC Radio Scotland', # radioscotland/programmes/schedules/mw
 'p00fzl8b' => 'BBC Radio Scotland', # radioscotland/programmes/schedules/orkney
 'p00fzl8j' => 'BBC Radio Scotland', # radioscotland/programmes/schedules/shetland
 'p00fzl8w' => 'BBC Radio Ulster', # radioulster/programmes/schedules
 'p00fzl8y' => 'BBC Radio Wales', # radiowales/programmes/schedules/fm
 'p00fzl8x' => 'BBC Radio Wales', # radiowales/programmes/schedules/mw
*/
    
/*
 'national' => {
 'p00fzl64' => 'BBC Radio 1Xtra', # 1xtra/programmes/schedules
 'p00fzl7g' => 'BBC Radio 5 live', # 5live/programmes/schedules
 'p00fzl7h' => 'BBC Radio 5 live sports extra', # 5livesportsextra/programmes/schedules
 'p00fzl65' => 'BBC Radio 6 Music', # 6music/programmes/schedules
 'p00fzl68' => 'BBC Asian Network', # asiannetwork/programmes/schedules
 'p00fzl86' => 'BBC Radio 1', # radio1/programmes/schedules
 'p00fzl8v' => 'BBC Radio 2', # radio2/programmes/schedules
 'p00fzl8t' => 'BBC Radio 3', # radio3/programmes/schedules
 'p00fzl7j' => 'BBC Radio 4', # radio4/programmes/schedules/fm
 'p00fzl7k' => 'BBC Radio 4', # radio4/programmes/schedules/lw
 'p00fzl7l' => 'BBC Radio 4 Extra', # radio4extra/programmes/schedules
 'p02zbmb3' => 'BBC World Service', # worldserviceradio/programmes/schedules/uk
 },
 */

    NSArray *regions = @[@"BBC Radio Cymru", @"BBC Radio Foyle", @"BBC Radio Nan Gaidheal", @"BBC Radio Scotland", @"BBC Radio Ulster", @"BBC Radio Wales"];
   
    /* Filter out if not radio or news and news not wanted */
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"ShowBBCRadio"]isEqualTo:@NO])
        return NO;
    
    if (![np.networkName isEqualToString:@"BBC Radio"])
        return NO;
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"IgnoreAllRadioNews"]isEqualTo:@YES]) {
        if ([np.programmeName rangeOfString:@"news" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return NO;
        }
    }

    /* Filter each of the nationals in turn */
    
    if ([np.tvChannel isEqualToString:@"BBC Radio 1Xtra"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio1Xtra"]isEqualTo:@YES];
    }
    
    if ([np.tvChannel isEqualToString:@"BBC Radio 1"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio1"]isEqualTo:@YES];
    }

    if ([np.tvChannel isEqualToString:@"BBC Radio 2"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio2"]isEqualTo:@YES];
    }
    
    if ([np.tvChannel isEqualToString:@"BBC Radio 3"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio3"]isEqualTo:@YES];
    }
    
    if ([np.tvChannel isEqualToString:@"BBC Radio 4"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio4"]isEqualTo:@YES];
    }
    
    if ([np.tvChannel isEqualToString:@"BBC Radio 4 Extra"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio4Extra"]isEqualTo:@YES];
    }
    
    if ([np.tvChannel isEqualToString:@"BBC Radio 5 live"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio5Live"]isEqualTo:@YES];
    }
    
    if ([np.tvChannel isEqualToString:@"BBC 5 live sports extra"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio5LiveSportsExtra"]isEqualTo:@YES];
    }
    
    if ([np.tvChannel isEqualToString:@"BBC Radio 6 Music"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"Radio6Music"]isEqualTo:@YES];
    }

    if ([np.tvChannel isEqualToString:@"BBC Asian Network"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"RadioAsianNetwork"]isEqualTo:@YES];
    }
    
    if ([np.tvChannel isEqualToString:@"BBC World Service"]) {
        return [[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCWorldService"]isEqualTo:@YES];
    }
    
    /* Filter for regionals */
    
    for (int i=0; i<regions.count;i++) {
        if ([np.tvChannel containsString:regions[i]]) {
            return [[[NSUserDefaults standardUserDefaults] valueForKey:@"ShowRegionalRadioStations"]isEqualTo:@YES];
        }
    }
    
    /* Otherwise must be local */
    return [[[NSUserDefaults standardUserDefaults] valueForKey:@"ShowLocalRadioStations"]isEqualTo:@YES];

}

@end




@implementation HistoryDisplay

- (instancetype)initWithItemString:(NSString *)aItemString andTVChannel:(NSString *)aTVChannel andLineNumber:(int)aLineNumber andPageNumber:(int)aPageNumber;
{
    programmeNameString = aItemString;
    lineNumber = aLineNumber;
    pageNumber  = aPageNumber;
    networkNameString = aTVChannel;
    
    return self;
}

@end


