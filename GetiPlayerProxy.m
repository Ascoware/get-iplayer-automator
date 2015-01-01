//
//  GetiPlayerProxy.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/7/14.
//
//

#import "GetiPlayerProxy.h"

@implementation GetiPlayerProxy

- (id)init
{
   if (!(self = [super init])) return nil;
   
   proxyDict = [NSMutableDictionary dictionary];
   
   return self;
}

- (id)initWithLogger:(LogController *)logger {
   if (![self init]) return nil;
   
   self->logger = logger;
   
   return self;
}

- (void)loadProxyInBackgroundForSelector:(SEL)selector withObject:(id)object onTarget:(id)target silently:(BOOL)silent
{
   [self updateProxyLoadStatus:YES message:@"Loading proxy settings..."];
   NSLog(@"INFO: Loading proxy settings...");
   [logger addToLog:@"\n\nINFO: Loading proxy settings..."];
   [proxyDict removeAllObjects];
   proxyDict[@"selector"] = [NSValue valueWithPointer:selector];
   proxyDict[@"target"] = target;
   currentIsSilent = silent;
   if (object)
      proxyDict[@"object"] = object;
   NSString *proxyOption = [[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"];
	if ([proxyOption isEqualToString:@"Custom"])
	{
      NSString *customProxy = [[NSUserDefaults standardUserDefaults] valueForKey:@"CustomProxy"];
      NSLog(@"INFO: Custom Proxy: address=[%@] length=%ld", customProxy, [customProxy length]);
      [logger addToLog:[NSString stringWithFormat:@"INFO: Custom Proxy: address=[%@] length=%ld", customProxy, [customProxy length]]];
      NSString *proxyValue = [customProxy stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if ([proxyValue length] == 0)
      {
         NSLog(@"WARNING: Custom proxy setting was blank. No proxy will be used.");
         [logger addToLog:@"WARNING: Custom proxy setting was blank. No proxy will be used."];
         if (!currentIsSilent)
         {
            NSAlert *alert = [NSAlert alertWithMessageText:@"Custom proxy setting was blank.\nDownloads may fail.\nDo you wish to continue?"
                                             defaultButton:@"No"
                                           alternateButton:@"Yes"
                                               otherButton:nil
                                 informativeTextWithFormat:@""];
            [alert setAlertStyle:NSCriticalAlertStyle];
            if ([alert runModal] == NSAlertDefaultReturn)
            {
               [self cancelProxyLoad];
            }
            else
            {
               [self failProxyLoad];
            }
         }
         else
         {
             [self failProxyLoad];
         }
      }
      else
      {
         proxyDict[@"proxy"] = [[HTTPProxy alloc] initWithString:proxyValue];
         [self finishProxyLoad];
      }
	}
	else if ([proxyOption isEqualToString:@"Provided"])
	{
      NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithPointer:selector],@"selector",target,@"target", nil];
      if (object){
         [userInfo addEntriesFromDictionary:@{@"object": object}];
      }
      
      ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:@"http://tom-tech.com/get_iplayer/proxy.txt"]];
      [request setUserInfo:userInfo];
      [request setDelegate:self];
      [request setDidFailSelector:@selector(providedProxyDidFinish:)];
      [request setDidFinishSelector:@selector(providedProxyDidFinish:)];
      [request setTimeOutSeconds:10];
      [request setNumberOfTimesToRetryOnTimeout:2];
      [self updateProxyLoadStatus:YES message:[NSString stringWithFormat:@"Loading provided proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]]];
      NSLog(@"INFO: Loading provided proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]);
      [logger addToLog:[NSString stringWithFormat:@"INFO: Loading provided proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]*2]];
      [request startAsynchronous];
	}
   else
   {
      NSLog(@"INFO: No proxy to load");
      [logger addToLog:@"INFO: No proxy to load"];
      [self finishProxyLoad];
   }
}

- (void)providedProxyDidFinish:(ASIHTTPRequest *)request
{
   NSData *urlData = [request responseData];
   if ([request responseStatusCode] != 200 || !urlData)
   {
      NSLog(@"WARNING: Provided proxy could not be retrieved. No proxy will be used.");
      [logger addToLog:@"WARNING: Provided proxy could not be retrieved. No proxy will be used."];
      if (!currentIsSilent)
      {
         NSError *error = [request error];
         NSAlert *alert = [NSAlert alertWithMessageText:@"Provided proxy could not be retrieved.\nDownloads may fail.\nDo you wish to continue?"
                                          defaultButton:@"No"
                                        alternateButton:@"Yes"
                                            otherButton:nil
                              informativeTextWithFormat:@"Error: %@", (error ? [error localizedDescription] : @"Unknown error")];
         [alert setAlertStyle:NSCriticalAlertStyle];
         if ([alert runModal] == NSAlertDefaultReturn)
            [self cancelProxyLoad];
         else
            [self failProxyLoad];
      }
      else
      {
          [self failProxyLoad];
      }
   }
   else
   {
      NSString *proxyValue = [[[[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding] lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if ([proxyValue length] == 0)
      {
         NSLog(@"WARNING: Provided proxy value was blank. No proxy will be used.");
         [logger addToLog:@"WARNING: Provided proxy value was blank. No proxy will be used."];
         if (!currentIsSilent)
         {
            NSAlert *alert = [NSAlert alertWithMessageText:@"Provided proxy value was blank.\nDownloads may fail.\nDo you wish to continue?"
                                             defaultButton:@"No"
                                           alternateButton:@"Yes"
                                               otherButton:nil
                                 informativeTextWithFormat:@""];
            [alert setAlertStyle:NSCriticalAlertStyle];
            if ([alert runModal] == NSAlertDefaultReturn)
               [self cancelProxyLoad];
            else
               [self failProxyLoad];
         }
         else
         {
             [self failProxyLoad];
         }
      }
      else
      {
         proxyDict[@"proxy"] = [[HTTPProxy alloc] initWithString:proxyValue];
         [self finishProxyLoad];
      }
   }
}

- (void)cancelProxyLoad
{
   [self returnFromProxyLoadWithError:[NSError errorWithDomain:@"Proxy" code:kProxyLoadCancelled userInfo:@{NSLocalizedDescriptionKey: @"Proxy Load Cancelled"}]];
}

- (void)failProxyLoad
{
   [self returnFromProxyLoadWithError:[NSError errorWithDomain:@"Proxy" code:kProxyLoadFailed userInfo:@{NSLocalizedDescriptionKey: @"Proxy Load Failed"}]];
}

- (void)finishProxyLoad
{
   NSLog(@"INFO: Proxy load complete.");
   [logger addToLog:@"INFO: Proxy load complete."];
   if (proxyDict[@"proxy"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"TestProxy"])
   {
      [self testProxyOnLoad];
      return;
   }
   [self returnFromProxyLoadWithError:nil];
}

- (void)testProxyOnLoad
{
   HTTPProxy *proxy = proxyDict[@"proxy"];
   
   if (proxy)
   {
      if (!proxy.host || [proxy.host length] == 0 || [proxy.host rangeOfString:@"(null)"].location != NSNotFound)
      {
         NSLog(@"WARNING: Invalid proxy host: address=%@ length=%ld", proxy.host, [proxy.host length]);
         [logger addToLog:[NSString stringWithFormat:@"WARNING: Invalid proxy host: address=%@ length=%ld", proxy.host, [proxy.host length]]];
         if (!currentIsSilent)
         {
            NSAlert *alert = [NSAlert alertWithMessageText:@"Invalid proxy host.\nDownloads may fail.\nDo you wish to continue?"
                                             defaultButton:@"No"
                                           alternateButton:@"Yes"
                                               otherButton:nil
                                 informativeTextWithFormat:@"Invalid proxy host: address=[%@] length=%ld", proxy.host, [proxy.host length]];
            [alert setAlertStyle:NSCriticalAlertStyle];
            if ([alert runModal] == NSAlertDefaultReturn)
               [self cancelProxyLoad];
            else
               [self failProxyTest];
         }
         else
         {
             [self failProxyLoad];
         }
         return;
      }
      NSString *testURL = [[NSUserDefaults standardUserDefaults] stringForKey:@"ProxyTestURL"];
      if (!testURL)
         testURL = @"http://www.google.com";
      ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:testURL]];
      [request setDelegate:self];
      [request setDidFailSelector:@selector(proxyTestDidFinish:)];
      [request setDidFinishSelector:@selector(proxyTestDidFinish:)];
      [request setTimeOutSeconds:30];
      [request setProxyType:proxy.type];
      [request setProxyHost:proxy.host];
      if (proxy.port) {
         [request setProxyPort:proxy.port];
      } else {
         if ([proxy.type isEqualToString:(NSString *)kCFProxyTypeHTTPS]) {
            [request setProxyPort:443];
         } else  {
            [request setProxyPort:80];
         }
      }
      if (proxy.user) {
         [request setProxyUsername:proxy.user];
         [request setProxyPassword:proxy.password];
      }
      [self updateProxyLoadStatus:YES message:[NSString stringWithFormat:@"Testing proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]]];
      NSLog(@"INFO: Testing proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]);
      [logger addToLog:[NSString stringWithFormat:@"INFO: Testing proxy (may take up to %ld seconds)...", (NSInteger)[request timeOutSeconds]]];
      [request startAsynchronous];
   }
   else
   {
      NSLog(@"INFO: No proxy to test");
      [logger addToLog:@"INFO: No proxy to test"];
      [self finishProxyTest];
   }
}

- (void)proxyTestDidFinish:(ASIHTTPRequest *)request
{
   if ([request responseStatusCode] != 200)
   {
      NSLog(@"WARNING: Proxy failed to load test page: %@", [request url]);
      [logger addToLog:[NSString stringWithFormat:@"WARNING: Proxy failed to load test page: %@", [request url]]];
      if (!currentIsSilent)
      {
         NSError *error = [request error];
         NSAlert *alert = [NSAlert alertWithMessageText:@"Proxy failed to load test page.\nDownloads may fail.\nDo you wish to continue?"
                                          defaultButton:@"No"
                                        alternateButton:@"Yes"
                                            otherButton:nil
                              informativeTextWithFormat:@"Failed to load %@ within %ld seconds\nUsing proxy: %@\nError: %@", [request url], (NSInteger)[request timeOutSeconds], [proxyDict[@"proxy"] url], (error ? [error localizedDescription] : @"Unknown error")];
         [alert setAlertStyle:NSCriticalAlertStyle];
         if ([alert runModal] == NSAlertDefaultReturn)
            [self cancelProxyLoad];
         else
            [self failProxyTest];
      }
      else
      {
          [self failProxyTest];
      }
   }
   else
   {
      [self finishProxyTest];
   }
}

- (void)failProxyTest
{
   [self returnFromProxyLoadWithError:[NSError errorWithDomain:@"Proxy" code:kProxyLoadFailed userInfo:@{NSLocalizedDescriptionKey: @"Proxy Test Failed"}]];
}

- (void)finishProxyTest
{
   NSLog(@"INFO: Proxy test complete.");
   [logger addToLog:@"INFO: Proxy test complete."];
   [self returnFromProxyLoadWithError:nil];
}

- (void)returnFromProxyLoadWithError:(NSError *)error
{
   if (proxyDict[@"proxy"])
   {
      NSLog(@"INFO: Using proxy: %@", [proxyDict[@"proxy"] url]);
      [logger addToLog:[NSString stringWithFormat:@"INFO: Using proxy: %@", [proxyDict[@"proxy"]url]]];
   }
   else
   {
      NSLog(@"INFO: No proxy will be used");
      [logger addToLog:@"INFO: No proxy will be used"];
   }
   [self updateProxyLoadStatus:NO message:nil];
   if (error) {
      proxyDict[@"error"] = error;
   }
   [proxyDict[@"target"] performSelector:[proxyDict[@"selector"] pointerValue] withObject:proxyDict[@"object"] withObject:proxyDict];
}

- (void)updateProxyLoadStatus:(BOOL)working message:(NSString *)message
{
   NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
   NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
   if (working)
   {
      userInfo[@"indeterminate"] = @YES;
      userInfo[@"animated"] = @YES;
      [nc postNotificationName:@"setPercentage" object:self userInfo:userInfo];
      [nc postNotificationName:@"setCurrentProgress" object:self userInfo:@{@"string" : message}];
   }
   else
   {
      userInfo[@"indeterminate"] = @NO;
      userInfo[@"animated"] = @NO;
      [nc postNotificationName:@"setPercentage" object:self userInfo:userInfo];
      [nc postNotificationName:@"setCurrentProgress" object:self userInfo:@{@"string" : @""}];
   }
}

@end
