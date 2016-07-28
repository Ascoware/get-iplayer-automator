//
//  ExtendedShowInformationController.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/7/14.
//
//

#import <Foundation/Foundation.h>
#import "Programme.h"

@interface ExtendedShowInformationController : NSObject {
   IBOutlet NSTableView *searchResultsTable;
   IBOutlet NSArrayController *searchResultsArrayController;
   
   IBOutlet NSProgressIndicator *retrievingInfoIndicator;
   IBOutlet NSTextField *loadingLabel;
   IBOutlet NSView *loadingView;
   IBOutlet NSView *infoView;
   IBOutlet NSPopover *popover;
   IBOutlet NSImageView *imageView;
   IBOutlet NSTextField *seriesNameField;
   IBOutlet NSTextField *episodeNameField;
   IBOutlet NSTextField *numbersField;
   IBOutlet NSTextField *durationField;
   IBOutlet NSTextField *categoriesField;
   IBOutlet NSTextField *firstBroadcastField;
   IBOutlet NSTextField *lastBroadcastField;
   IBOutlet NSTextView *descriptionView;
   IBOutlet NSTextField *typeField;
    IBOutlet NSArrayController *modeSizeController;
    NSArray *modeSizeSorters;
}
@property (readonly) NSArray *modeSizeSorters;
@end
