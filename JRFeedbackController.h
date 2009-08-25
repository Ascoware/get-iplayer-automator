/*******************************************************************************
    JRFeedbackController.h
        Copyright (c) 2008-2009 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
        Some rights reserved: <http://opensource.org/licenses/mit-license.php>

    ***************************************************************************/

#import <Cocoa/Cocoa.h>

/*
 OPTIONAL: use Growl to post the 'thank you' message after feedback is sent.
 If your app includes the Growl framework, set USE_GROWL to 1 and JRFeedbackController.m 
 will include the GrowlApplicationBridge.h file required, and post a Growl message when
 the feedback is sent.
 NOTE: you must add an entry to your Growl Dict plist to register this new message
 */
#define USE_GROWL 1

typedef enum {
    JRFeedbackController_BugReport,
    JRFeedbackController_FeatureRequest,
    JRFeedbackController_SupportRequest,
    JRFeedbackController_SectionCount
} JRFeedbackController_Section;

@interface JRFeedbackController : NSWindowController {
    IBOutlet NSTextView *textView;
    IBOutlet NSButton *includeHardwareDetailsCheckbox;
	IBOutlet NSButton *includeLogCheckbox;
    IBOutlet NSTextField *nameTextField;
    IBOutlet NSComboBox *emailAddressComboBox;
    IBOutlet NSProgressIndicator *progress;
    IBOutlet NSSegmentedControl *segmentedControl;
    
    IBOutlet NSButton *cancelButton;
    IBOutlet NSButton *sendButton;
    
    NSAttributedString *sectionStrings[JRFeedbackController_SectionCount];
    JRFeedbackController_Section currentSection;
    BOOL includeContactInfo;
	NSMutableDictionary *form;
}

+ (void)showFeedback;
+ (void)showFeedbackWithBugDetails:(NSString *)details;

- (BOOL)includeContactInfo;
- (void)setIncludeContactInfo:(BOOL)flag;

- (IBAction)switchSectionAction:(NSSegmentedControl*)sender;
- (IBAction)submitAction:(id)sender;
- (IBAction)cancelAction:(id)sender;
- (void)postFeedback:(NSString*)systemProfile;
- (void)setTextViewStringTo:(NSString *)details;

- (void)displayAlertMessage:(NSString *)message 
		withInformativeText:(NSString *)text 
			  andAlertStyle:(NSAlertStyle)alertStyle;

- (void)finish;


@end
