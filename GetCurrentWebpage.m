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
	[browserNotOpen setMessageText:[NSString stringWithFormat:@"%@ is not open.", browser]];
	[browserNotOpen setInformativeText:@"Please ensure your browser is running and has at least one window open."];
	[browserNotOpen setAlertStyle:NSWarningAlertStyle];
	
	//Get URL
	if ([browser isEqualToString:@"Safari"])
	{
		BOOL foundURL=NO;
		SafariApplication *Safari = [SBApplication applicationWithBundleIdentifier:@"com.apple.Safari"];
		if ([Safari isRunning])
		{
			@try
			{
				SBElementArray *windows = [Safari windows];
				if ([@([windows count]) intValue])
				{
					for (SafariWindow *window in windows)
 					{
                  SafariTab *tab = [window currentTab];
                  if ([[tab URL] hasPrefix:@"http://www.bbc.co.uk/iplayer/episode/"] ||
                      [[tab URL] hasPrefix:@"http://bbc.co.uk/iplayer/episode/"] ||
                      [[tab URL] hasPrefix:@"http://bbc.co.uk/iplayer/console/"] ||
                      [[tab URL] hasPrefix:@"http://www.bbc.co.uk/iplayer/console/"] ||
                      [[tab URL] hasPrefix:@"http://bbc.co.uk/sport"])
                  {
                     url = [NSString stringWithString:[tab URL]];
                     NSScanner *nameScanner = [NSScanner scannerWithString:[tab name]];
                     [nameScanner scanString:@"BBC iPlayer - " intoString:nil];
                     [nameScanner scanString:@"BBC Sport - " intoString:nil];
                     [nameScanner scanUpToString:@"kjklgfdjfgkdlj" intoString:&newShowName];
                     foundURL=YES;
                  }
                  else if ([[tab URL] hasPrefix:@"http://www.bbc.co.uk/programmes/"]) {
                     url = [NSString stringWithString:[tab URL]];
                     NSScanner *nameScanner = [NSScanner scannerWithString:[tab name]];
                     [nameScanner scanUpToString:@"- " intoString:nil];
                     [nameScanner scanString:@"- " intoString:nil];
                     [nameScanner scanUpToString:@"kjklgfdjfgkdlj" intoString:&newShowName];
                     foundURL=YES;
                     source = [Safari doJavaScript:@"document.documentElement.outerHTML" in:tab];
                  }
                  else if ([[tab URL] hasPrefix:@"https://www.itv.com/itvplayer/"] ||
                           [[tab URL] hasPrefix:@"http://www.channel4.com/programmes/"] ||
                           [[tab URL] hasPrefix:@"http://ps3.channel4.com"])
                  {
                     url = [NSString stringWithString:[tab URL]];
                     source = [Safari doJavaScript:@"document.documentElement.outerHTML" in:tab];
                     newShowName = [[[tab name] stringByReplacingOccurrencesOfString:@" | itvplayer" withString:@""] stringByReplacingOccurrencesOfString:@" - 4oD - Channel 4" withString:@""];
                     foundURL=YES;
                  }
					}
					if (foundURL==NO)
					{
						url = [NSString stringWithString:[[windows[0] currentTab] URL]];
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
		if ([Chrome isRunning])
		{
			@try
			{
				SBElementArray *windows = [Chrome windows];
				if ([@([windows count]) intValue])
				{
					for (ChromeWindow *window in windows)
 					{
                  ChromeTab *tab = [window activeTab];
                  if ([[tab URL] hasPrefix:@"http://www.bbc.co.uk/iplayer/episode/"] ||
                      [[tab URL] hasPrefix:@"http://bbc.co.uk/iplayer/episode/"] ||
                      [[tab URL] hasPrefix:@"http://bbc.co.uk/iplayer/console/"] ||
                      [[tab URL] hasPrefix:@"http://www.bbc.co.uk/iplayer/console/"] ||
                      [[tab URL] hasPrefix:@"http://bbc.co.uk/sport"])
                  {
                     url = [NSString stringWithString:[tab URL]];
                     NSScanner *nameScanner = [NSScanner scannerWithString:[tab title]];
                     [nameScanner scanString:@"BBC iPlayer - " intoString:nil];
                     [nameScanner scanString:@"BBC Sport - " intoString:nil];
                     [nameScanner scanUpToString:@"kjklgfdjfgkdlj" intoString:&newShowName];
                     foundURL=YES;
                  }
                  else if ([[tab URL] hasPrefix:@"http://www.bbc.co.uk/programmes/"]) {
                     url = [NSString stringWithString:[tab URL]];
                     NSScanner *nameScanner = [NSScanner scannerWithString:[tab title]];
                     [nameScanner scanUpToString:@"- " intoString:nil];
                     [nameScanner scanString:@"- " intoString:nil];
                     [nameScanner scanUpToString:@"kjklgfdjfgkdlj" intoString:&newShowName];
                     foundURL=YES;
                     source = [tab executeJavascript:@"document.documentElement.outerHTML"];
                  }
                  else if ([[tab URL] hasPrefix:@"https://www.itv.com/itvplayer/"] ||
                           [[tab URL] hasPrefix:@"http://www.channel4.com/programmes/"] ||
                           [[tab URL] hasPrefix:@"http://ps3.channel4.com"])
                  {
                     url = [NSString stringWithString:[tab URL]];
                     source = [tab executeJavascript:@"document.documentElement.outerHTML"];
                     newShowName = [[[tab title] stringByReplacingOccurrencesOfString:@" | itvplayer" withString:@""] stringByReplacingOccurrencesOfString:@" - 4oD - Channel 4" withString:@""];
                     foundURL=YES;
                  }
					}
					if (foundURL==NO)
					{
						url = [NSString stringWithString:[[windows[0] activeTab] URL]];
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
	if([url hasPrefix:@"http://www.bbc.co.uk/iplayer/episode/"] || [url hasPrefix:@"http://beta.bbc.co.uk/iplayer/episode"])
	{
		NSString *pid = nil;
		NSScanner *urlScanner = [[NSScanner alloc] initWithString:url];
		[urlScanner scanUpToString:@"/episode/" intoString:nil];
		if ([urlScanner isAtEnd]) {
			[urlScanner setScanLocation:0];
			[urlScanner scanUpToString:@"/console/" intoString:nil];
		}
		[urlScanner scanString:@"/" intoString:nil];
		[urlScanner scanUpToString:@"/" intoString:nil];
		[urlScanner scanString:@"/" intoString:nil];
		[urlScanner scanUpToString:@"/" intoString:&pid];
		Programme *newProg = [[Programme alloc] initWithLogController:logger];
		[newProg setValue:pid forKey:@"pid"];
      if (newShowName) [newProg setShowName:newShowName];
//        newProg.status = @"Processing...";
//        [newProg performSelectorInBackground:@selector(getName) withObject:nil];
      return newProg;
	}
	else if([url hasPrefix:@"http://www.bbc.co.uk/programmes/"])
	{
		NSString *pid = nil;
		NSScanner *urlScanner = [[NSScanner alloc] initWithString:url];
		[urlScanner scanUpToString:@"/programmes/" intoString:nil];
		[urlScanner scanString:@"/" intoString:nil];
		[urlScanner scanUpToString:@"/" intoString:nil];
		[urlScanner scanString:@"/" intoString:nil];
		[urlScanner scanUpToString:@"/" intoString:&pid];
		NSScanner *scanner = [NSScanner scannerWithString:source];
      [scanner scanUpToString:[NSString stringWithFormat:@"bbcProgrammes.programme = { pid : '%@', type : 'episode' }", pid] intoString:nil];
		if ([scanner isAtEnd]) {
         NSAlert *invalidPage = [[NSAlert alloc] init];
         [invalidPage addButtonWithTitle:@"OK"];
         [invalidPage setMessageText:[NSString stringWithFormat:@"Invalid Page: %@",url]];
         [invalidPage setInformativeText:@"Please ensure the frontmost browser tab is open to an iPlayer episode page."];
         [invalidPage setAlertStyle:NSWarningAlertStyle];
         [invalidPage runModal];
         return nil;
      }
		Programme *newProg = [[Programme alloc] init];
		[newProg setValue:pid forKey:@"pid"];
      if (newShowName) [newProg setShowName:newShowName];
//        newProg.status = @"Processing...";
//        [newProg performSelectorInBackground:@selector(getName) withObject:nil];
        return newProg;
   }
   else if ([url hasPrefix:@"http://www.bbc.co.uk/sport/olympics/2012/live-video/"])
   {
      NSString *pid = nil;
      NSScanner *urlScanner = [NSScanner scannerWithString:url];
      [urlScanner scanString:@"http://www.bbc.co.uk/sport/olympics/2012/live-video/" intoString:nil];
      [urlScanner scanUpToString:@"kfejklfjklj" intoString:&pid];
      return [[Programme alloc] initWithInfo:nil pid:pid programmeName:newShowName network:@"BBC Sport" logController:logger];
   }
	else if ([url hasPrefix:@"https://www.itv.com/itvplayer/"])
	{
      NSString *progname = nil, *productionId = nil, *pay_rights = nil, *title = nil, *action_type = nil;
      progname = newShowName;
		NSScanner *scanner = [NSScanner scannerWithString:source];
      [scanner scanUpToString:@"\"productionId\":" intoString:nil];
      [scanner scanString:@"\"productionId\":\"" intoString:nil];
      [scanner scanUpToString:@"\"" intoString:&productionId];
      [scanner scanUpToString:@"\"action_type\":" intoString:nil];
      [scanner scanString:@"\"action_type\":\"" intoString:nil];
      [scanner scanUpToString:@"\"" intoString:&action_type];
      [scanner scanUpToString:@"\"pay_rights\":" intoString:nil];
      [scanner scanString:@"\"pay_rights\":\"" intoString:nil];
      [scanner scanUpToString:@"\"" intoString:&pay_rights];
      [scanner scanUpToString:@"<h1 class=\"title episode-title\"" intoString:nil];
      [scanner scanUpToString:@">" intoString:nil];
      [scanner scanString:@">" intoString:nil];
      [scanner scanUpToString:@"<" intoString:&title];
      if (title) progname = title;
      if (!progname || !productionId || (![pay_rights isEqualToString:@"free"] && ![action_type isEqualToString:@"free_taster"])) {
         NSAlert *invalidPage = [[NSAlert alloc] init];
         [invalidPage addButtonWithTitle:@"OK"];
         [invalidPage setMessageText:[NSString stringWithFormat:@"Invalid Page: %@",url]];
         [invalidPage setInformativeText:@"Please ensure the frontmost browser tab is open to an ITV Player free catch-up episode page."];
         [invalidPage setAlertStyle:NSWarningAlertStyle];
         [invalidPage runModal];
         return nil;
      }
      NSString *pid = [productionId stringByReplacingOccurrencesOfString:@"\\" withString:@""];
      NSString *showName = [NSString stringWithFormat:@"%@ - %@", progname, pid];
		Programme *newProg = [[Programme alloc] init];
      [newProg setPid:pid];
      [newProg setShowName:showName];
      [newProg setTvNetwork:@"ITV"];
      [newProg setProcessedPID:@YES];
      [newProg setUrl:url];
		return newProg;
	}
	else
	{
		NSAlert *invalidPage = [[NSAlert alloc] init];
		[invalidPage addButtonWithTitle:@"OK"];
		[invalidPage setMessageText:[NSString stringWithFormat:@"Invalid Page: %@",url]];
		[invalidPage setInformativeText:@"Please ensure the frontmost browser tab is open to an iPlayer episode page or ITV Player free catch-up episode page. 4oD is no longer supported."];
		[invalidPage setAlertStyle:NSWarningAlertStyle];
		[invalidPage runModal];
      return nil;
	}
   
}

@end
