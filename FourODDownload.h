//
//  FourODDownload.h
//  Get_iPlayer GUI
//
//  Created by Thomas E. Willson on 7/29/12.
//
//

#import "Download.h"

@interface FourODDownload : Download
- (id)initWithProgramme:(Programme *)tempShow;
- (NSString *)decodeToken:(NSString *)string;
@end
