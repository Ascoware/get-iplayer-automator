//
//  GetiPlayerAutomator-Header.h
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 11/1/22.
//

#ifndef GetiPlayerAutomator_Header_h
#define GetiPlayerAutomator_Header_h

#import <Cocoa/Cocoa.h>
@import CocoaLumberjack;


#if (GIA_DEBUG==1)
    static DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
    static DDLogLevel ddLogLevel = DDLogLevelDebug;
#endif

#endif /* GetiPlayerAutomator_Header_h */
