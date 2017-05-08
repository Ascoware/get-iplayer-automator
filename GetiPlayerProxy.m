//
//  GetiPlayerProxy.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/7/14.
//
//

#import "GetiPlayerProxy.h"

@implementation GetiPlayerProxy

- (instancetype)init
{
    if (self = [super init]) {
        _proxyDict = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithLogger:(LogController *)logger {
    if (self = [self init]) {
        _logger = logger;
    }
    return self;
}

- (void)loadProxyInBackgroundForSelector:(SEL)selector withObject:(id)object onTarget:(id)target silently:(BOOL)silent
{
    [self updateProxyLoadStatus:YES message:@"Loading proxy settings..."];
    NSLog(@"INFO: Loading proxy settings...");
    [_logger addToLog:@"\n\nINFO: Loading proxy settings..."];
    [_proxyDict removeAllObjects];
    _proxyDict[@"selector"] = [NSValue valueWithPointer:selector];
    _proxyDict[@"target"] = target;
    _currentIsSilent = silent;
    if (object)
        _proxyDict[@"object"] = object;
    NSString *proxyOption = [[NSUserDefaults standardUserDefaults] valueForKey:@"Proxy"];
    if ([proxyOption isEqualToString:@"Custom"])
    {
        NSString *customProxy = [[NSUserDefaults standardUserDefaults] valueForKey:@"CustomProxy"];
        NSLog(@"INFO: Custom Proxy: address=[%@] length=%ld", customProxy, customProxy.length);
        [_logger addToLog:[NSString stringWithFormat:@"INFO: Custom Proxy: address=[%@] length=%ld", customProxy, customProxy.length]];
        NSString *proxyValue = [customProxy stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (proxyValue.length == 0)
        {
            NSLog(@"WARNING: Custom proxy setting was blank. No proxy will be used.");
            [_logger addToLog:@"WARNING: Custom proxy setting was blank. No proxy will be used."];
            if (!_currentIsSilent)
            {
                NSAlert *alert = [NSAlert alertWithMessageText:@"Custom proxy setting was blank.\nDownloads may fail.\nDo you wish to continue?"
                                                 defaultButton:@"No"
                                               alternateButton:@"Yes"
                                                   otherButton:nil
                                     informativeTextWithFormat:@""];
                alert.alertStyle = NSCriticalAlertStyle;
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
            _proxyDict[@"proxy"] = [[HTTPProxy alloc] initWithString:proxyValue];
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
        request.userInfo = userInfo;
        request.delegate = self;
        request.didFailSelector = @selector(providedProxyDidFinish:);
        request.didFinishSelector = @selector(providedProxyDidFinish:);
        request.timeOutSeconds = 10;
        request.numberOfTimesToRetryOnTimeout = 2;
        [self updateProxyLoadStatus:YES message:[NSString stringWithFormat:@"Loading provided proxy (may take up to %ld seconds)...", (NSInteger)request.timeOutSeconds]];
        NSLog(@"INFO: Loading provided proxy (may take up to %ld seconds)...", (NSInteger)request.timeOutSeconds);
        [_logger addToLog:[NSString stringWithFormat:@"INFO: Loading provided proxy (may take up to %ld seconds)...", (NSInteger)request.timeOutSeconds*2]];
        [request startAsynchronous];
    }
    else
    {
        NSLog(@"INFO: No proxy to load");
        [_logger addToLog:@"INFO: No proxy to load"];
        [self finishProxyLoad];
    }
}

- (void)providedProxyDidFinish:(ASIHTTPRequest *)request
{
    NSData *urlData = [request responseData];
    if (request.responseStatusCode != 200 || !urlData)
    {
        NSLog(@"WARNING: Provided proxy could not be retrieved. No proxy will be used.");
        [_logger addToLog:@"WARNING: Provided proxy could not be retrieved. No proxy will be used."];
        if (!_currentIsSilent)
        {
            NSError *error = request.error;
            NSAlert *alert = [NSAlert alertWithMessageText:@"Provided proxy could not be retrieved.\nDownloads may fail.\nDo you wish to continue?"
                                             defaultButton:@"No"
                                           alternateButton:@"Yes"
                                               otherButton:nil
                                 informativeTextWithFormat:@"Error: %@", (error ? error.localizedDescription : @"Unknown error")];
            alert.alertStyle = NSCriticalAlertStyle;
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
        NSString *proxyValue = [[[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding].lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (proxyValue.length == 0)
        {
            NSLog(@"WARNING: Provided proxy value was blank. No proxy will be used.");
            [_logger addToLog:@"WARNING: Provided proxy value was blank. No proxy will be used."];
            if (!_currentIsSilent)
            {
                NSAlert *alert = [NSAlert alertWithMessageText:@"Provided proxy value was blank.\nDownloads may fail.\nDo you wish to continue?"
                                                 defaultButton:@"No"
                                               alternateButton:@"Yes"
                                                   otherButton:nil
                                     informativeTextWithFormat:@""];
                alert.alertStyle = NSCriticalAlertStyle;
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
            _proxyDict[@"proxy"] = [[HTTPProxy alloc] initWithString:proxyValue];
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
    [_logger addToLog:@"INFO: Proxy load complete."];
    if (_proxyDict[@"proxy"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"TestProxy"])
    {
        [self testProxyOnLoad];
        return;
    }
    [self returnFromProxyLoadWithError:nil];
}

- (void)testProxyOnLoad
{
    HTTPProxy *proxy = _proxyDict[@"proxy"];
    
    if (proxy)
    {
        if (!proxy.host || (proxy.host).length == 0 || [proxy.host rangeOfString:@"(null)"].location != NSNotFound)
        {
            NSLog(@"WARNING: Invalid proxy host: address=%@ length=%ld", proxy.host, (proxy.host).length);
            [_logger addToLog:[NSString stringWithFormat:@"WARNING: Invalid proxy host: address=%@ length=%ld", proxy.host, (proxy.host).length]];
            if (!_currentIsSilent)
            {
                NSAlert *alert = [NSAlert alertWithMessageText:@"Invalid proxy host.\nDownloads may fail.\nDo you wish to continue?"
                                                 defaultButton:@"No"
                                               alternateButton:@"Yes"
                                                   otherButton:nil
                                     informativeTextWithFormat:@"Invalid proxy host: address=[%@] length=%ld", proxy.host, (proxy.host).length];
                alert.alertStyle = NSCriticalAlertStyle;
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
        request.delegate = self;
        request.didFailSelector = @selector(proxyTestDidFinish:);
        request.didFinishSelector = @selector(proxyTestDidFinish:);
        request.timeOutSeconds = 30;
        request.proxyType = proxy.type;
        request.proxyHost = proxy.host;
        if (proxy.port) {
            request.proxyPort = proxy.port;
        } else {
            if ([proxy.type isEqualToString:(NSString *)kCFProxyTypeHTTPS]) {
                request.proxyPort = 443;
            } else  {
                request.proxyPort = 80;
            }
        }
        if (proxy.user) {
            request.proxyUsername = proxy.user;
            request.proxyPassword = proxy.password;
        }
        [self updateProxyLoadStatus:YES message:[NSString stringWithFormat:@"Testing proxy (may take up to %ld seconds)...", (NSInteger)request.timeOutSeconds]];
        NSLog(@"INFO: Testing proxy (may take up to %ld seconds)...", (NSInteger)request.timeOutSeconds);
        [_logger addToLog:[NSString stringWithFormat:@"INFO: Testing proxy (may take up to %ld seconds)...", (NSInteger)request.timeOutSeconds]];
        [request startAsynchronous];
    }
    else
    {
        NSLog(@"INFO: No proxy to test");
        [_logger addToLog:@"INFO: No proxy to test"];
        [self finishProxyTest];
    }
}

- (void)proxyTestDidFinish:(ASIHTTPRequest *)request
{
    if (request.responseStatusCode != 200)
    {
        NSLog(@"WARNING: Proxy failed to load test page: %@", request.url);
        [_logger addToLog:[NSString stringWithFormat:@"WARNING: Proxy failed to load test page: %@", request.url]];
        if (!_currentIsSilent)
        {
            NSError *error = request.error;
            NSAlert *alert = [NSAlert alertWithMessageText:@"Proxy failed to load test page.\nDownloads may fail.\nDo you wish to continue?"
                                             defaultButton:@"No"
                                           alternateButton:@"Yes"
                                               otherButton:nil
                                 informativeTextWithFormat:@"Failed to load %@ within %ld seconds\nUsing proxy: %@\nError: %@", request.url, (NSInteger)request.timeOutSeconds, [_proxyDict[@"proxy"] url], (error ? error.localizedDescription : @"Unknown error")];
            alert.alertStyle = NSCriticalAlertStyle;
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
    [_logger addToLog:@"INFO: Proxy test complete."];
    [self returnFromProxyLoadWithError:nil];
}

- (void)returnFromProxyLoadWithError:(NSError *)error
{
    if (_proxyDict[@"proxy"])
    {
        NSLog(@"INFO: Using proxy: %@", [_proxyDict[@"proxy"] url]);
        [_logger addToLog:[NSString stringWithFormat:@"INFO: Using proxy: %@", [_proxyDict[@"proxy"]url]]];
    }
    else
    {
        NSLog(@"INFO: No proxy will be used");
        [_logger addToLog:@"INFO: No proxy will be used"];
    }
    [self updateProxyLoadStatus:NO message:nil];
    if (error) {
        _proxyDict[@"error"] = error;
    }
    SEL proxySelector = [_proxyDict[@"selector"] pointerValue];
    id proxyTarget = _proxyDict[@"target"];
    
    if (proxySelector && proxyTarget) {
        [proxyTarget performSelector:proxySelector withObject:_proxyDict[@"object"] withObject:_proxyDict];
    }
}

- (void)updateProxyLoadStatus:(BOOL)working message:(NSString *)message
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (working)
    {
        userInfo[@"indeterminate"] = @YES;
        userInfo[@"animated"] = @YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"setPercentage" object:self userInfo:userInfo];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"setCurrentProgress" object:self userInfo:@{@"string" : message}];
    }
    else
    {
        userInfo[@"indeterminate"] = @NO;
        userInfo[@"animated"] = @NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"setPercentage" object:self userInfo:userInfo];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"setCurrentProgress" object:self userInfo:@{@"string" : @""}];
    }
}

@end
