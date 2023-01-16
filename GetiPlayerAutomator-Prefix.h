//
//  GetiPlayerAutomator-Header.h
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 11/1/22.
//

#ifndef GetiPlayerAutomator_Header_h
#define GetiPlayerAutomator_Header_h

#import <Cocoa/Cocoa.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

#if (GIA_DEBUG==1)
    static DDLogLevel ddLogLevel = DDLogLevelVerbose;
    #define GIA_DEBUG_PROFILE @"_debug"
#else
    static DDLogLevel ddLogLevel = DDLogLevelDebug;
    #define GIA_DEBUG_PROFILE @""
#endif

#endif /* GetiPlayerAutomator_Header_h */
