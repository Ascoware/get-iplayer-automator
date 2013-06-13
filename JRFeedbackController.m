/*******************************************************************************
    JRFeedbackController.m
        Copyright (c) 2008-2009 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
        Some rights reserved: <http://opensource.org/licenses/mit-license.php>

    ***************************************************************************/

#import "JRFeedbackController.h"
#import <AddressBook/AddressBook.h>
#import "NSURLRequest+postForm.h"
#import <SystemConfiguration/SCNetwork.h>

#if USE_GROWL
	#import "Growl.framework/Headers/GrowlApplicationBridge.h"
#endif

JRFeedbackController *gFeedbackController = nil;

NSString *JRFeedbackType[JRFeedbackController_SectionCount] = {
    @"BUG", // JRFeedbackController_BugReport
    @"FEATURE", // JRFeedbackController_FeatureRequest
    @"SUPPORT" // JRFeedbackController_SupportRequest
};

@interface JRFeedbackController ()
+ (NSURL*)postURL;
@end

@implementation JRFeedbackController

+ (void)showFeedback {
    [self showFeedbackWithBugDetails:nil];
}

+ (void)showFeedbackWithBugDetails:(NSString *)details {
    SCNetworkConnectionFlags reachabilityFlags;
    Boolean reachabilityResult = SCNetworkCheckReachabilityByName([[[JRFeedbackController postURL] host] UTF8String], &reachabilityFlags);
    
    //NSLog(@"reachabilityFlags: %lx", reachabilityFlags);
    BOOL showFeedbackWindow = reachabilityResult
        && (reachabilityFlags & kSCNetworkFlagsReachable)
        && !(reachabilityFlags & kSCNetworkFlagsConnectionRequired)
        && !(reachabilityFlags & kSCNetworkFlagsConnectionAutomatic)
        && !(reachabilityFlags & kSCNetworkFlagsInterventionRequired);
    
    if (!showFeedbackWindow) {
        int alertResult = [[NSAlert alertWithMessageText:NSLocalizedStringFromTable(@"Feedback Host Not Reachable", @"JRFeedbackProvider", nil)
                                           defaultButton:NSLocalizedStringFromTable(@"Proceed Anyway", @"JRFeedbackProvider", nil)
                                         alternateButton:NSLocalizedStringFromTable(@"Cancel", @"JRFeedbackProvider", nil)
                                             otherButton:nil
                               informativeTextWithFormat:NSLocalizedStringFromTable(@"Unreachable Explanation", @"JRFeedbackProvider", nil), [[JRFeedbackController postURL] host]
                            ] runModal];
        if (NSAlertDefaultReturn == alertResult) {
            showFeedbackWindow = YES;
        }
    }
    
    if (showFeedbackWindow) {
        if (!gFeedbackController) {
            gFeedbackController = [[JRFeedbackController alloc] init];
        }
        [gFeedbackController showWindow:self];
        
        // There is an assumption here that bug report is the first and default view of the window.
        if (details) {
            [gFeedbackController setTextViewStringTo:details];
        }
    }
}

- (id)init {
    self = [super initWithWindowNibName:@"JRFeedbackProvider"];
    if (self) {
        //[self window];
        includeContactInfo = YES;
    }
    return self;
}

- (void)windowDidLoad {
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5
    // Not sure why, but you have to call this twice to "take" (10.5.7).
    // First call always sets it to NSSegmentStyleRounded.
    [segmentedControl setSegmentStyle:NSSegmentStyleTexturedSquare];
    [segmentedControl setSegmentStyle:NSSegmentStyleTexturedSquare];
#endif
    NSString* fmt = NSLocalizedStringFromTable(@"Title", @"JRFeedbackProvider", nil);
    NSString* title = [NSString stringWithFormat:fmt, [[NSBundle bundleForClass:[self class]] infoDictionary][(NSString*)kCFBundleNameKey]];
    [[self window] setTitle:title];
    
    NSTextStorage *text = [textView textStorage];
    
    NSString *separator = @"\n\n--\n\n";
    
    NSRange separatorRange = [[text string] rangeOfString:separator];
    sectionStrings[JRFeedbackController_BugReport] = [text attributedSubstringFromRange:NSMakeRange(0, separatorRange.location)];
    [text deleteCharactersInRange:NSMakeRange(0, separatorRange.location + [separator length])];
    //NSLog(@"bugReport: <%@>", [sectionStrings[JRFeedbackController_BugReport] string]);
    
    separatorRange = [[text string] rangeOfString:separator];
    sectionStrings[JRFeedbackController_FeatureRequest] = [text attributedSubstringFromRange:NSMakeRange(0, separatorRange.location)];
    [text deleteCharactersInRange:NSMakeRange(0, separatorRange.location + [separator length])];
    //NSLog(@"featureRequest: <%@>", [sectionStrings[JRFeedbackController_FeatureRequest] string]);
    
    sectionStrings[JRFeedbackController_SupportRequest] = [text attributedSubstringFromRange:NSMakeRange(0, [text length])];
    //NSLog(@"supportRequest: <%@>", [sectionStrings[JRFeedbackController_SupportRequest] string]);
    
    [text setAttributedString:sectionStrings[JRFeedbackController_BugReport]];
    [textView moveToBeginningOfDocument:self];
    [textView moveDown:self];
    
    ABPerson *me = [[ABAddressBook sharedAddressBook] me];
    if (me) {
        [nameTextField setStringValue:[NSString stringWithFormat:@"%@ %@", [me valueForProperty:kABFirstNameProperty], [me valueForProperty:kABLastNameProperty]]];
        ABMutableMultiValue *emailAddresses = [me valueForProperty:kABEmailProperty];
        unsigned addyIndex = 0, addyCount = [emailAddresses count];
        if (addyCount) {
            for (; addyIndex < addyCount; addyIndex++) {
                [emailAddressComboBox addItemWithObjectValue:[emailAddresses valueAtIndex:addyIndex]];
            }
            [emailAddressComboBox selectItemAtIndex:0];
        }
    }
}

- (BOOL)includeContactInfo {
    return includeContactInfo;
}
- (void)setIncludeContactInfo:(BOOL)flag {
    includeContactInfo = flag;
}

- (IBAction)switchSectionAction:(NSSegmentedControl*)sender {
    sectionStrings[currentSection] = [[textView textStorage] copy];
    
    currentSection = [sender selectedSegment];
    [[textView textStorage] setAttributedString:sectionStrings[currentSection]];
    [textView moveToBeginningOfDocument:self];
    [textView moveDown:self];
    
    if (JRFeedbackController_SupportRequest == currentSection) {
        [self setIncludeContactInfo:YES];
    }
}

- (IBAction)submitAction:(id)sender 
{
    if (!([[emailAddressComboBox stringValue] isEqualToString:@""] && includeContactInfo))
	{
		[sendButton setEnabled:NO];
		[cancelButton setEnabled:NO];
		
		sectionStrings[currentSection] = [[textView textStorage] copy];
		[textView setEditable:NO];
		
		[progress startAnimation:self];
		
		// if they checked not to include hardware, don't scan. Post right away.
		if ([includeHardwareDetailsCheckbox intValue] == 1) 
		{
			[NSThread detachNewThreadSelector:@selector(system_profilerThread:)
									 toTarget:self
								   withObject:nil];
		} 
		else 
		{
			[self postFeedback:@"<systemProfile suppressed>"];
		}
	}
	else 
	{
		NSAlert *noEmailAddress = [NSAlert alertWithMessageText:@"No Email Address" 
												  defaultButton:@"OK" 
												alternateButton:nil 
													otherButton:nil 
									  informativeTextWithFormat:@"Please specify an email address so that I can follow up with you regarding your request."];
		[noEmailAddress runModal];
	}

}

- (void)system_profilerThread:(id)ignored {
    @autoreleasepool {
    
        NSString *systemProfile = nil;
        {
            NSPipe *inputPipe = [NSPipe pipe];
            NSPipe *outputPipe = [NSPipe pipe];
            
            NSTask *scriptTask = [[NSTask alloc] init];
            [scriptTask setLaunchPath:@"/usr/sbin/system_profiler"];
            [scriptTask setArguments:@[@"-detailLevel", @"mini"]];
            [scriptTask setStandardOutput:outputPipe];
            [scriptTask launch];
            
            [[inputPipe fileHandleForWriting] closeFile];
            systemProfile = [[NSString alloc] initWithData:[[outputPipe fileHandleForReading] readDataToEndOfFile]
                                                   encoding:NSUTF8StringEncoding];
        }
        [self performSelectorOnMainThread:@selector(postFeedback:)
                               withObject:systemProfile
                            waitUntilDone:NO];
    }
}

- (void)postFeedback:(NSString*)systemProfile {
    
    form = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 JRFeedbackType[currentSection], @"feedbackType",
                                 [sectionStrings[currentSection] string], @"feedback",
                                 [[NSBundle bundleForClass:[self class]] infoDictionary][@"CFBundleName"], @"appName",
                                 [[NSBundle bundleForClass:[self class]] infoDictionary][@"CFBundleIdentifier"], @"bundleID",
                                 [[NSBundle bundleForClass:[self class]] infoDictionary][@"CFBundleShortVersionString"], @"version",
                                 nil];
    if (systemProfile) {
        form[@"systemProfile"] = systemProfile;
    }
    if ([self includeContactInfo]) {
        if ([[emailAddressComboBox stringValue] length]) {
            form[@"email"] = [emailAddressComboBox stringValue];
        }
        if ([[nameTextField stringValue] length]) {
            form[@"name"] = [nameTextField stringValue];
        }
    }
	if ([includeLogCheckbox state] == NSOnState)
	{
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(recieveLog:) name:@"Log" object:nil];
		[nc postNotificationName:@"NeedLog" object:nil];
	}
	else
	{
		[self finish];
	}
}

- (void)closeFeedback {
    if (gFeedbackController) {
        assert(gFeedbackController == self);
        [[gFeedbackController window] orderOut:self];
        gFeedbackController = nil;
    }
}

- (IBAction)cancelAction:(id)sender {
    [self closeFeedback];
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection {
#if USE_GROWL
	[GrowlApplicationBridge setGrowlDelegate:@""];
	[GrowlApplicationBridge notifyWithTitle:@"Thank you!"
								description:@"Your feedback has been sent"
						   notificationName:@"Feedback Sent"
								   iconData:nil
								   priority:0
								   isSticky:NO
							   clickContext:nil];
	[self closeFeedback];
#else
	//	drop thank you sheet
	[self displayAlertMessage:@"Thank you for your feedback!"
		  withInformativeText:@"Your feedback has been sent"
				andAlertStyle:NSInformationalAlertStyle];
#endif
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[self closeFeedback];//moved from connectionDidFinishLoading:
}

- (void)displayAlertMessage:(NSString *)message 
		withInformativeText:(NSString *)text 
			  andAlertStyle:(NSAlertStyle)alertStyle
{
	NSAlert *thankYouAlert = [[NSAlert alloc] init];
	[thankYouAlert addButtonWithTitle:@"OK"];
	[thankYouAlert setMessageText:message];
	[thankYouAlert setInformativeText:text];
	[thankYouAlert setAlertStyle:alertStyle];
	
	//	stop the animation of the progress indicator, so user doesn't think 
	//	something is still going on
	[progress stopAnimation:self];
	
	//	disply thank you
    [thankYouAlert beginSheetModalForWindow:[gFeedbackController window]
							  modalDelegate:self 
							 didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
								contextInfo:nil];
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error {
    NSLog(@"-[JRFeedback connection:didFailWithError:%@]", error);
	
	//	drop fail sheet
	[self displayAlertMessage:@"An Error Occured"
		  withInformativeText:@"There was a problem sending your feedback.  Please try again at another time"
				andAlertStyle:NSInformationalAlertStyle];

}

- (void)windowWillClose:(NSNotification*)notification {
    [self closeFeedback];
}

- (void)setTextViewStringTo:(NSString *)details
{
    NSFont *resetFontWeight = [[textView textStorage] font];
	[[textView textStorage] setFont:[NSFont fontWithName:[resetFontWeight familyName] size:[resetFontWeight pointSize]]];
    [textView setString:details];
}

+ (NSURL*)postURL {
    NSString *postURLString = [[NSBundle bundleForClass:[self class]] infoDictionary][@"JRFeedbackURL"];
    if ([[NSUserDefaults standardUserDefaults] stringForKey:@"JRFeedbackURL"]) {
        postURLString = [[NSUserDefaults standardUserDefaults] stringForKey:@"JRFeedbackURL"];
    }
    NSAssert(postURLString, @"JRFeedbackURL not defined");
    return [NSURL URLWithString:postURLString];
}
- (void)finish
{
	NSURLRequest *request = [NSURLRequest requestWithURL:[JRFeedbackController postURL] postForm:form];
    [NSURLConnection connectionWithRequest:request delegate:self];
}
- (void)recieveLog:(NSNotification *)note
{
	NSString *log = [note object];
	log = [log stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
	form[@"log"] = [log copy];
	[self finish];
}

@end
