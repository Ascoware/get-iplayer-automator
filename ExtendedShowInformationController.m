//
//  ExtendedShowInformationController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/7/14.
//
//

#import "ExtendedShowInformationController.h"

@implementation ExtendedShowInformationController
#pragma mark Extended Show Information
- (IBAction)showExtendedInformationForSelectedProgramme:(id)sender {
   popover.behavior = NSPopoverBehaviorTransient;
   [[NSNotificationCenter defaultCenter] postNotificationName:@"AddToLogNotification" object:self userInfo:@{@"message": @"Retrieving Information"}];
   Programme *programme = searchResultsArrayController.arrangedObjects[[searchResultsTable selectedRow]];
   if (programme) {
      infoView.alphaValue = 0.1;
      loadingView.alphaValue = 1.0;
      [retrievingInfoIndicator startAnimation:self];
      
      @try {
         [popover showRelativeToRect:[searchResultsTable frameOfCellAtColumn:1 row:[searchResultsTable selectedRow]] ofView:(NSView *)searchResultsTable preferredEdge:NSMaxYEdge];
      }
      @catch (NSException *exception) {
         NSLog(@"%@",[exception description]);
         NSLog(@"%@",searchResultsTable);
         return;
      }
      if (!programme.extendedMetadataRetrieved.boolValue) {
         [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(informationRetrieved:) name:@"ExtendedInfoRetrieved" object:programme];
         [programme retrieveExtendedMetadata];
         [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(timeoutTimer:) userInfo:nil repeats:NO];
      }
      else {
         [self informationRetrieved:[NSNotification notificationWithName:@"" object:programme]];
      }
   }
}
- (void)timeoutTimer:(NSTimer *)timer
{
   Programme *programme = searchResultsArrayController.arrangedObjects[[searchResultsTable selectedRow]];
   if (!programme.extendedMetadataRetrieved.boolValue) {
      [[NSNotificationCenter defaultCenter] postNotificationName:@"AddToLogNotification" object:self userInfo:@{@"message":@"Metadata Retrieval Timed Out"}];
      [programme cancelMetadataRetrieval];
      loadingLabel.stringValue = @"Programme Information Retrieval Timed Out";
   }
}
- (void)informationRetrieved:(NSNotification *)note {
   Programme *programme = note.object;
   
   if (programme.successfulRetrieval.boolValue) {
      if (programme.thumbnail)
         imageView.image = programme.thumbnail;
      else
         imageView.image = nil;
      
      if (programme.seriesName)
         seriesNameField.stringValue = programme.seriesName;
      else
         seriesNameField.stringValue = @"Unable to Retrieve";
      
      if (programme.episodeName)
         episodeNameField.stringValue = programme.episodeName;
      else
         seriesNameField.stringValue = @"";
      
      if (programme.season && programme.episode)
         numbersField.stringValue = [NSString stringWithFormat:@"Series: %ld Episode: %ld",(long)programme.season,(long)programme.episode];
      else
         numbersField.stringValue = @"";
      
      if (programme.duration)
         durationField.stringValue = [NSString stringWithFormat:@"Duration: %d minutes",programme.duration.intValue];
      else
         durationField.stringValue = @"";
      
      if (programme.categories)
         categoriesField.stringValue = [NSString stringWithFormat:@"Categories: %@",programme.categories];
      else
         categoriesField.stringValue = @"";
      
      if (programme.firstBroadcast)
         firstBroadcastField.stringValue = [NSString stringWithFormat:@"First Broadcast: %@",[programme.firstBroadcast description]];
      else
         firstBroadcastField.stringValue = @"";
      
      if (programme.lastBroadcast)
         lastBroadcastField.stringValue = [NSString stringWithFormat:@"Last Broadcast: %@", [programme.lastBroadcast description]];
      else
         lastBroadcastField.stringValue = @"";
      
      if (programme.desc)
         descriptionView.string = programme.desc;
      else
         descriptionView.string = @"";
      
      if (programme.modeSizes)
         modeSizeController.content = programme.modeSizes;
      else
         modeSizeController.content = [NSDictionary dictionary];
      
      if ([programme typeDescription])
         typeField.stringValue = [NSString stringWithFormat:@"Type: %@",[programme typeDescription]];
      else
         typeField.stringValue = @"";
      
      [retrievingInfoIndicator stopAnimation:self];
      infoView.alphaValue = 1.0;
      loadingView.alphaValue = 0.0;
      [[NSNotificationCenter defaultCenter] postNotificationName:@"AddToLogNotification" object:self userInfo:@{@"message":@"Info Retrieved"}];
   }
   else {
      [retrievingInfoIndicator stopAnimation:self];
      loadingLabel.stringValue = @"Info could not be retrieved.";
       [[NSNotificationCenter defaultCenter] postNotificationName:@"AddToLogNotification" object:self userInfo:@{@"message":@"Info could not be retrieved."}];
   }
}
@end
