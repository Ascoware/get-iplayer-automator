//
//  GetCurrentWebpageController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/3/14.
//
//

#import "GetCurrentWebpage.h"

@implementation GetCurrentWebpage
+ (Programme *)getCurrentWebpage:(LogController *)logger
{
    NSString *newShowName=nil;
    //Get Default Browser
    NSString *browser = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultBrowser"];
    
    //Prepare Pointer for URL
    NSString *url = nil;
    NSString *source = nil;
    
    //Prepare Alert in Case the Browser isn't Open
    NSAlert *browserNotOpen = [[NSAlert alloc] init];
    [browserNotOpen addButtonWithTitle:@"OK"];
    browserNotOpen.messageText = [NSString stringWithFormat:@"%@ is not open.", browser];
    browserNotOpen.informativeText = @"Please ensure your browser is running and has at least one window open.";
    browserNotOpen.alertStyle = NSWarningAlertStyle;
    
    //Get URL
    if ([browser isEqualToString:@"Safari"])
    {
        BOOL foundURL=NO;
        SafariApplication *Safari = [SBApplication applicationWithBundleIdentifier:@"com.apple.Safari"];
        if (Safari.running)
        {
            @try
            {
                SBElementArray *windows = [Safari windows];
                if ((@(windows.count)).intValue)
                {
                    for (SafariWindow *window in windows)
                    {
                        SafariTab *tab = window.currentTab;
                        if ([tab.URL hasPrefix:@"http://www.bbc.co.uk/iplayer/episode/"] ||
                            [tab.URL hasPrefix:@"http://bbc.co.uk/iplayer/episode/"] ||
                            [tab.URL hasPrefix:@"http://bbc.co.uk/sport"] ||
                            [tab.URL hasPrefix:@"https://www.bbc.co.uk/iplayer/episode/"] ||
                            [tab.URL hasPrefix:@"https://bbc.co.uk/iplayer/episode/"] ||
                            [tab.URL hasPrefix:@"https://bbc.co.uk/sport"])
                        {
                            url = [NSString stringWithString:tab.URL];
                            NSScanner *nameScanner = [NSScanner scannerWithString:tab.name];
                            [nameScanner scanString:@"BBC iPlayer - " intoString:nil];
                            [nameScanner scanString:@"BBC Sport - " intoString:nil];
                            [nameScanner scanUpToString:@"kjklgfdjfgkdlj" intoString:&newShowName];
                            foundURL=YES;
                        }
                        else if ([tab.URL hasPrefix:@"http://www.bbc.co.uk/programmes/"] ||
                                 [tab.URL hasPrefix:@"https://www.bbc.co.uk/programmes/"]) {
                            url = [NSString stringWithString:tab.URL];
                            NSScanner *nameScanner = [NSScanner scannerWithString:tab.name];
                            [nameScanner scanUpToString:@"- " intoString:nil];
                            [nameScanner scanString:@"- " intoString:nil];
                            [nameScanner scanUpToString:@"kjklgfdjfgkdlj" intoString:&newShowName];
                            foundURL=YES;
                            source = tab.source;
                        }
                        else if ([tab.URL hasPrefix:@"http://www.itv.com/hub/"] ||
                                 [tab.URL hasPrefix:@"https://www.itv.com/hub/"])
                        {
                            url = [NSString stringWithString:tab.URL];
                            source = tab.source;
                            newShowName = [tab.name stringByReplacingOccurrencesOfString:@" - The ITV Hub" withString:@""];
                            foundURL=YES;
                        }
                    }
                    if (foundURL==NO)
                    {
                        url = [NSString stringWithString:[windows[0] currentTab].URL];
                        //Might be incorrect
                    }
                }
                else
                {
                    [browserNotOpen runModal];
                    return nil;
                }
            }
            @catch (NSException *e)
            {
                [browserNotOpen runModal];
                return nil;
            }
        }
        else
        {
            [browserNotOpen runModal];
            return nil;
        }
    }
    else if ([browser isEqualToString:@"Chrome"])
    {
        BOOL foundURL=NO;
        ChromeApplication *Chrome = [SBApplication applicationWithBundleIdentifier:@"com.google.Chrome"];
        if (Chrome.running)
        {
            @try
            {
                SBElementArray *windows = [Chrome windows];
                if ((@(windows.count)).intValue)
                {
                    for (ChromeWindow *window in windows)
                    {
                        ChromeTab *tab = window.activeTab;
                        if ([tab.URL hasPrefix:@"http://www.bbc.co.uk/iplayer/episode/"] ||
                            [tab.URL hasPrefix:@"http://bbc.co.uk/iplayer/episode/"] ||
                            [tab.URL hasPrefix:@"https://www.bbc.co.uk/iplayer/episode/"] ||
                      [tab.URL hasPrefix:@"https://bbc.co.uk/iplayer/episode/"] ||
                            [tab.URL hasPrefix:@"https://bbc.co.uk/iplayer/episode/"])
                        {
                            url = [NSString stringWithString:tab.URL];
                            NSScanner *nameScanner = [NSScanner scannerWithString:tab.title];
                            [nameScanner scanString:@"BBC iPlayer - " intoString:nil];
                            [nameScanner scanString:@"BBC Sport - " intoString:nil];
                            [nameScanner scanUpToString:@"kjklgfdjfgkdlj" intoString:&newShowName];
                            foundURL=YES;
                        }
                        else if ([tab.URL hasPrefix:@"http://www.bbc.co.uk/programmes/"] ||
                                 [tab.URL hasPrefix:@"https://www.bbc.co.uk/programmes/"]) {
                            url = [NSString stringWithString:tab.URL];
                            NSScanner *nameScanner = [NSScanner scannerWithString:tab.title];
                            [nameScanner scanUpToString:@"- " intoString:nil];
                            [nameScanner scanString:@"- " intoString:nil];
                            [nameScanner scanUpToString:@"kjklgfdjfgkdlj" intoString:&newShowName];
                            foundURL=YES;
                            source = [tab executeJavascript:@"document.documentElement.outerHTML"];
                        }
                        else if ([tab.URL hasPrefix:@"http://www.itv.com/hub/"] ||
                                 [tab.URL hasPrefix:@"https://www.itv.com/hub/"])
                        {
                            url = [NSString stringWithString:tab.URL];
                            source = [tab executeJavascript:@"document.documentElement.outerHTML"];
                            newShowName = [tab.title stringByReplacingOccurrencesOfString:@" - The ITV Hub" withString:@""];
                            foundURL=YES;
                        }
                    }
                    if (foundURL==NO)
                    {
                        url = [NSString stringWithString:[windows[0] activeTab].URL];
                        //Might be incorrect
                    }
                }
                else
                {
                    [browserNotOpen runModal];
                    return nil;
                }
            }
            @catch (NSException *e)
            {
                [browserNotOpen runModal];
                return nil;
            }
        }
        else
        {
            [browserNotOpen runModal];
            return nil;
        }
        
    }
    else
    {
        [[NSAlert alertWithMessageText:@"Get iPlayer Automator currently only supports Safari and Chrome." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Please change your preferred browser in the preferences and try again."] runModal];
        return nil;
    }
    
    //Process URL
    if([url hasPrefix:@"http://www.bbc.co.uk/iplayer/episode/"] || [url hasPrefix:@"https://www.bbc.co.uk/iplayer/episode/"])
    {
        NSString *pid = nil;
        NSScanner *urlScanner = [[NSScanner alloc] initWithString:url];
        [urlScanner scanUpToString:@"/episode/" intoString:nil];
        if (urlScanner.atEnd) {
            urlScanner.scanLocation = 0;
            [urlScanner scanUpToString:@"/console/" intoString:nil];
        }
        [urlScanner scanString:@"/" intoString:nil];
        [urlScanner scanUpToString:@"/" intoString:nil];
        [urlScanner scanString:@"/" intoString:nil];
        [urlScanner scanUpToString:@"/" intoString:&pid];
        Programme *newProg = [[Programme alloc] initWithLogController:logger];
        [newProg setValue:pid forKey:@"pid"];
        if (newShowName) newProg.showName = newShowName;
        newProg.status = @"Processing...";
        [newProg performSelectorInBackground:@selector(getName) withObject:nil];
        return newProg;
    }
    else if([url hasPrefix:@"http://www.bbc.co.uk/programmes/"] || [url hasPrefix:@"https://www.bbc.co.uk/programmes/"] )
    {
        NSString *pid = nil;
        NSScanner *urlScanner = [[NSScanner alloc] initWithString:url];
        [urlScanner scanUpToString:@"/programmes/" intoString:nil];
        [urlScanner scanString:@"/" intoString:nil];
        [urlScanner scanUpToString:@"/" intoString:nil];
        [urlScanner scanString:@"/" intoString:nil];
        [urlScanner scanUpToString:@"#" intoString:&pid];
        NSScanner *scanner = [NSScanner scannerWithString:source];
        [scanner scanUpToString:[NSString stringWithFormat:@"bbcProgrammes.programme = { pid : '%@', type : 'episode' }", pid] intoString:nil];
        if (scanner.atEnd) {
            scanner.scanLocation = 0;
            [scanner scanUpToString:[NSString stringWithFormat:@"bbcProgrammes.programme = { pid : '%@', type : 'clip' }", pid] intoString:nil];
        }
        if (scanner.atEnd) {
            NSAlert *invalidPage = [[NSAlert alloc] init];
            [invalidPage addButtonWithTitle:@"OK"];
            invalidPage.messageText = [NSString stringWithFormat:@"Invalid Page: %@",url];
            invalidPage.informativeText = @"Please ensure the frontmost browser tab is open to an iPlayer episode page or programme clip page.";
            invalidPage.alertStyle = NSWarningAlertStyle;
            [invalidPage runModal];
            return nil;
        }
        Programme *newProg = [[Programme alloc] init];
        [newProg setValue:pid forKey:@"pid"];
        if (newShowName) newProg.showName = newShowName;
        newProg.status = @"Processing...";
        [newProg performSelectorInBackground:@selector(getName) withObject:nil];
        return newProg;
    }
    else if ([url hasPrefix:@"http://www.itv.com/hub/"] || [url hasPrefix:@"https://www.itv.com/hub/"])
    {
        NSString *progname = nil, *productionId = nil, *title = nil, *desc = nil, *timeString = nil;
        NSInteger seriesnum = 0, episodenum = 0;
        progname = newShowName;
        NSScanner *scanner = [NSScanner scannerWithString:source];
        [scanner scanUpToString:@"<meta property=\"og:title\" content=\"" intoString:nil];
        [scanner scanString:@"<meta property=\"og:title\" content=\"" intoString:nil];
        [scanner scanUpToString:@"\"" intoString:&title];
        if (title) progname = [title stringByDecodingHTMLEntities];
        [scanner scanUpToString:@"<meta property=\"og:description\" content=\"" intoString:nil];
        [scanner scanString:@"<meta property=\"og:description\" content=\"" intoString:nil];
        [scanner scanUpToString:@"\"" intoString:&desc];
        
        NSString *dateTimePrefix = @"episode-info__meta-item--pipe-after\"><time datetime=\"";
        [scanner scanUpToString:dateTimePrefix intoString:nil];
        [scanner scanString:dateTimePrefix intoString:nil];
        [scanner scanUpToString:@"\"" intoString:&timeString];
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mmZ";
        dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        NSDate *parsedDate = [dateFormatter dateFromString:timeString];
        NSString *shortDate = [NSDateFormatter localizedStringFromDate:parsedDate
                                                             dateStyle:NSDateFormatterMediumStyle
                                                             timeStyle:NSDateFormatterNoStyle];
        
        productionId = [[NSURL URLWithString:url] lastPathComponent];
        
        if (!progname || !productionId) {
            NSAlert *invalidPage = [[NSAlert alloc] init];
            [invalidPage addButtonWithTitle:@"OK"];
            invalidPage.messageText = [NSString stringWithFormat:@"Invalid Page: %@",url];
            invalidPage.informativeText = @"Please ensure the frontmost browser tab is open to an ITV Hub episode page.";
            invalidPage.alertStyle = NSWarningAlertStyle;
            [invalidPage runModal];
            return nil;
        }
        NSString *pid = [productionId stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *showName = [NSString stringWithFormat:@"%@ - %@", progname, pid];
        Programme *newProg = [[Programme alloc] init];
        newProg.pid = pid;
        newProg.showName = showName;
        newProg.tvNetwork = @"ITV Player";
        newProg.processedPID = @YES;
        newProg.url = url;
        newProg.lastBroadcastString = shortDate;
        newProg.lastBroadcast = parsedDate;
        newProg.episodeName = shortDate;
        
        scanner = [NSScanner scannerWithString:title];
        [scanner scanUpToString:@"Series " intoString:nil];
        [scanner scanString:@"Series " intoString:nil];
        [scanner scanInteger:&seriesnum];
        scanner.scanLocation = 0;
        [scanner scanUpToString:@"Episode " intoString:nil];
        [scanner scanString:@"Episode " intoString:nil];
        [scanner scanInteger:&episodenum];
        scanner = [NSScanner scannerWithString:desc];
        if ( seriesnum == 0 ) {
            [scanner scanUpToString:@"Series " intoString:nil];
            [scanner scanString:@"Series " intoString:nil];
            [scanner scanInteger:&seriesnum];
        }
        if ( episodenum == 0 ) {
            scanner.scanLocation = 0;
            [scanner scanUpToString:@"Episode " intoString:nil];
            [scanner scanString:@"Episode " intoString:nil];
            [scanner scanInteger:&episodenum];
        }
        newProg.season = seriesnum;
        newProg.episode = episodenum;
        return newProg;
    }
    else
    {
        NSAlert *invalidPage = [[NSAlert alloc] init];
        [invalidPage addButtonWithTitle:@"OK"];
        invalidPage.messageText = [NSString stringWithFormat:@"Invalid Page: %@",url];
        invalidPage.informativeText = @"Please ensure the frontmost browser tab is open to an iPlayer episode page or ITV Hub episode page.";
        invalidPage.alertStyle = NSWarningAlertStyle;
        [invalidPage runModal];
        return nil;
    }
    
}

@end
