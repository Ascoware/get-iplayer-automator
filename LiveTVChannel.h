//
//  LiveTVChannel.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 10/3/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface LiveTVChannel : NSObject {
	NSString *channel;
}
@property (readwrite) NSString *channel;
-(id)initWithChannelName:(NSString *)channelName;
@end
