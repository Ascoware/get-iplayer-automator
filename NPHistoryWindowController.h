//
//  NPHistoryWindowController.h
//  Get_iPlayer GUI
//
//  Created by LFS on 8/6/16.
//
//

#import <Cocoa/Cocoa.h>
#import "Get_iPlayer_Automator-Swift.h"

@interface NPHistoryTableViewController : NSWindowController  <NSTableViewDataSource>
{
    IBOutlet NSTableView    *historyTable;
    NSMutableArray          *historyDisplayArray;
    NSArray                 *programmeHistoryArray;
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
-(id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
-(void)loadDisplayData;
-(BOOL)showITVProgramme:(ProgrammeHistoryObject *)np;
-(BOOL)showBBCTVProgramme:(ProgrammeHistoryObject *)np;
-(BOOL)showBBCRadioProgramme:(ProgrammeHistoryObject *)np;



@end


@interface HistoryDisplay : NSObject
{
    NSString *programmeNameString;
    NSString *networkNameString;
    int lineNumber;
    int pageNumber;
}

- (instancetype)initWithItemString:(NSString *)aItemString andTVChannel:(NSString *)aTVChannel andLineNumber:(int)aLineNumber andPageNumber:(int)aPageNumber;

@end



