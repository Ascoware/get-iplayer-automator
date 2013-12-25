//
//  ASDownloadShows.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 12/25/13.
//
//

#import "ASDownloadShows.h"

@implementation ASDownloadShows
- (void)performDefaultImplementation {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"StartDownloads" object:self];
}
@end

