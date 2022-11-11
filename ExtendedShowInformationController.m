//
//  ExtendedShowInformationController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/7/14.
//
//

#import "ExtendedShowInformationController.h"
#import <Get_iPlayer_Automator-Swift.h>

@implementation ExtendedShowInformationController
- (instancetype)init
{
    if (!(self = [super init])) return nil;
    modeSizeSorters = @[[NSSortDescriptor sortDescriptorWithKey:@"group" ascending:YES],
                        [NSSortDescriptor sortDescriptorWithKey:@"version" ascending:YES],
                        [NSSortDescriptor sortDescriptorWithKey:@"size" ascending:NO comparator:^(id obj1, id obj2) {
                            return [(NSString *)obj1 compare:(NSString *)obj2 options:NSNumericSearch];
                        }],
                        [NSSortDescriptor sortDescriptorWithKey:@"mode" ascending:YES]];
    return self;
}
#pragma mark Extended Show Information
- (IBAction)showExtendedInformationForSelectedProgramme:(id)sender {
    popover.behavior = NSPopoverBehaviorTransient;
    loadingLabel.stringValue = @"Loading Episode Info";
    DDLogDebug(@"%@: Retrieving information", self.description);
    Programme *programme = searchResultsArrayController.arrangedObjects[searchResultsTable.selectedRow];
    if (programme) {
        
        if ( [programme.tvNetwork hasPrefix:@"ITV"] )
        {
            NSAlert *notNewITV = [[NSAlert alloc] init];
            [notNewITV addButtonWithTitle:@"OK"];
            notNewITV.messageText = [NSString stringWithFormat:@"This feature is not available for ITV programmes"];
            notNewITV.alertStyle = NSAlertStyleWarning;
            [notNewITV runModal];
            notNewITV = nil;
            return;
        }
        
        infoView.alphaValue = 0.1;
        loadingView.alphaValue = 1.0;
        [retrievingInfoIndicator startAnimation:self];
        
        @try {
            [popover showRelativeToRect:[searchResultsTable frameOfCellAtColumn:1 row:searchResultsTable.selectedRow] ofView:(NSView *)searchResultsTable preferredEdge:NSMaxYEdge];
        }
        @catch (NSException *exception) {
            DDLogError(@"%@",exception.description);
            DDLogError(@"%@",searchResultsTable);
            return;
        }
        if (!programme.extendedMetadataRetrieved) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(informationRetrieved:) name:@"ExtendedInfoRetrieved" object:programme];
            [programme retrieveExtendedMetadata];
            [NSTimer scheduledTimerWithTimeInterval:120 target:self selector:@selector(timeoutTimer:) userInfo:nil repeats:NO];
        }
        else {
            [self informationRetrieved:[NSNotification notificationWithName:@"" object:programme]];
        }
    }
}
- (void)timeoutTimer:(NSTimer *)timer
{
    Programme *programme = searchResultsArrayController.arrangedObjects[searchResultsTable.selectedRow];
    if (!programme.extendedMetadataRetrieved) {
        DDLogInfo(@"%@: Metadata retrieval timed out", self.description);
        [programme cancelMetadataRetrieval];
        loadingLabel.stringValue = @"Programme Information Retrieval Timed Out";
    }
}
- (void)informationRetrieved:(NSNotification *)note {
    Programme *programme = note.object;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (programme.successfulRetrieval) {
            self->imageView.image = programme.thumbnail;
            
            if (programme.seriesName)
                self->seriesNameField.stringValue = programme.seriesName;
            else
                self->seriesNameField.stringValue = @"Unable to Retrieve";
            
            self->episodeNameField.stringValue = programme.episodeName;
            
            if (programme.season && programme.episode)
                self->numbersField.stringValue = [NSString stringWithFormat:@"Series: %ld Episode: %ld",(long)programme.season,(long)programme.episode];
            else
                self->numbersField.stringValue = @"";
            
            if (programme.duration > 0)
                self->durationField.stringValue = [NSString stringWithFormat:@"Duration: %ld minutes",programme.duration];
            else
                self->durationField.stringValue = @"";
            
            if (programme.categories)
                self->categoriesField.stringValue = [NSString stringWithFormat:@"Categories: %@",programme.categories];
            else
                self->categoriesField.stringValue = @"";
            
            if (programme.firstBroadcast) {
                NSString *firstBcastString = [NSDateFormatter localizedStringFromDate:programme.firstBroadcast dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterNoStyle];
                self->firstBroadcastField.stringValue = [NSString stringWithFormat:@"First Broadcast: %@", firstBcastString];
            }
            else
                self->firstBroadcastField.stringValue = @"";
            
            if (programme.lastBroadcastString)
                self->lastBroadcastField.stringValue = [NSString stringWithFormat:@"Last Broadcast: %@", programme.lastBroadcastString];
            else
                self->lastBroadcastField.stringValue = @"";
            
            self->descriptionView.string = programme.desc;
            
            if (programme.modeSizes)
                self->modeSizeController.content = programme.modeSizes;
            else
                self->modeSizeController.content = @[];
            
            self->typeField.stringValue = [NSString stringWithFormat:@"Type: %@",[programme typeDescription]];

            [self->retrievingInfoIndicator stopAnimation:self];
            self->infoView.alphaValue = 1.0;
            self->loadingView.alphaValue = 0.0;
            DDLogDebug(@"%@: Successfully retrieved metadata", self.description);
        }
        else {
            [self->retrievingInfoIndicator stopAnimation:self];
            self->loadingLabel.stringValue = @"Info could not be retrieved.";
            DDLogDebug(@"%@: Failed to retrieve metadata", self.description);
        }
    });
}

@synthesize modeSizeSorters;

@end
