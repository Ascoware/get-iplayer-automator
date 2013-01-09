//
//  FourODDownload.h
//  Get_iPlayer GUI
//
//  Created by Thomas E. Willson on 7/29/12.
//
//

#import "Download.h"

@interface FourODDownload : Download
{
    BOOL resolveHostNamesForProxy;
    BOOL skipMP4Search;
    NSInteger mp4SearchRange;
}
- (id)initWithProgramme:(Programme *)tempShow proxy:(HTTPProxy *)aProxy;
@end
