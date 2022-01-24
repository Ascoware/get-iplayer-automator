//
//  GetiPlayerProxy.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/7/14.
//
//

#import "GetiPlayerProxy.h"
#import <CFNetwork/CFNetwork.h>

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
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Custom proxy setting was blank.\nDownloads may fail.\nDo you wish to continue?";
                [alert addButtonWithTitle:@"No"];
                [alert addButtonWithTitle:@"Yes"];
                alert.alertStyle = NSAlertStyleCritical;

                if ([alert runModal] == NSAlertFirstButtonReturn)
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
    else
    {
        NSLog(@"INFO: No proxy to load");
        [_logger addToLog:@"INFO: No proxy to load"];
        [self finishProxyLoad];
    }
}

//- (void)providedProxyDidFinish:(ASIHTTPRequest *)request
//{
//    NSData *urlData = [request responseData];
//    if (request.responseStatusCode != 200 || !urlData)
//    {
//        NSLog(@"WARNING: Provided proxy could not be retrieved. No proxy will be used.");
//        [_logger addToLog:@"WARNING: Provided proxy could not be retrieved. No proxy will be used."];
//        if (!_currentIsSilent)
//        {
//            NSError *error = request.error;
//            NSAlert *alert = [NSAlert alertWithMessageText:@"Provided proxy could not be retrieved.\nDownloads may fail.\nDo you wish to continue?"
//                                             defaultButton:@"No"
//                                           alternateButton:@"Yes"
//                                               otherButton:nil
//                                 informativeTextWithFormat:@"Error: %@", (error ? error.localizedDescription : @"Unknown error")];
//            alert.alertStyle = NSCriticalAlertStyle;
//            if ([alert runModal] == NSAlertDefaultReturn)
//                [self cancelProxyLoad];
//            else
//                [self failProxyLoad];
//        }
//        else
//        {
//            [self failProxyLoad];
//        }
//    }
//    else
//    {
//        NSString *proxyValue = [[[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding].lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//        if (proxyValue.length == 0)
//        {
//            NSLog(@"WARNING: Provided proxy value was blank. No proxy will be used.");
//            [_logger addToLog:@"WARNING: Provided proxy value was blank. No proxy will be used."];
//            if (!_currentIsSilent)
//            {
//                NSAlert *alert = [NSAlert alertWithMessageText:@"Provided proxy value was blank.\nDownloads may fail.\nDo you wish to continue?"
//                                                 defaultButton:@"No"
//                                               alternateButton:@"Yes"
//                                                   otherButton:nil
//                                     informativeTextWithFormat:@""];
//                alert.alertStyle = NSCriticalAlertStyle;
//                if ([alert runModal] == NSAlertDefaultReturn)
//                    [self cancelProxyLoad];
//                else
//                    [self failProxyLoad];
//            }
//            else
//            {
//                [self failProxyLoad];
//            }
//        }
//        else
//        {
//            _proxyDict[@"proxy"] = [[HTTPProxy alloc] initWithString:proxyValue];
//            [self finishProxyLoad];
//        }
//    }
//}

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
    
    if (!proxy) {
        NSLog(@"INFO: No proxy to test");
        [_logger addToLog:@"INFO: No proxy to test"];
        [self finishProxyTest];
        return;
    }
    
    
    if (!proxy.host || (proxy.host).length == 0 || [proxy.host rangeOfString:@"(null)"].location != NSNotFound)
    {
        NSLog(@"WARNING: Invalid proxy host: address=%@ length=%ld", proxy.host, (proxy.host).length);
        [_logger addToLog:[NSString stringWithFormat:@"WARNING: Invalid proxy host: address=%@ length=%ld", proxy.host, (proxy.host).length]];
        if (!_currentIsSilent)
        {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Invalid proxy host.\nDownloads may fail.\nDo you wish to continue?";
            [alert addButtonWithTitle:@"No"];
            [alert addButtonWithTitle:@"Yes"];
            alert.informativeText = [NSString stringWithFormat:@"Invalid proxy host: address=[%@] length=%ld", proxy.host, (proxy.host).length];
            alert.alertStyle = NSAlertStyleCritical;
            if ([alert runModal] == NSAlertFirstButtonReturn)
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
    
    // ==============================
    NSUInteger port;
    if (proxy.port) {
        port = proxy.port;
    } else {
        if ([proxy.type isEqualToString:(NSString *)kCFProxyTypeHTTPS]) {
            port = 443;
        } else  {
            port = 80;
        }
    }
    
    // Create an NSURLSessionConfiguration that uses the proxy
    NSMutableDictionary *proxyDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:

                                      @(1),
                                      kCFNetworkProxiesHTTPEnable,

                                      proxy.host,
                                      kCFNetworkProxiesHTTPProxy,

                                      @(port),
                                      kCFNetworkProxiesHTTPSPort,

                                      @(1),
                                      kCFNetworkProxiesHTTPSEnable,

                                      proxy.host,
                                      kCFNetworkProxiesHTTPSProxy,

                                      @(port),
                                      kCFNetworkProxiesHTTPSPort,
                                      nil];
    
    if (proxy.user) {
        proxyDict[(NSString *)kCFProxyUsernameKey] = proxy.user;
        proxyDict[(NSString *)kCFProxyPasswordKey] = proxy.password;
    }
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.connectionProxyDictionary = proxyDict;
    configuration.timeoutIntervalForResource = 30;
    
    // Create a NSURLSession with our proxy aware configuration
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:[NSOperationQueue mainQueue]];
    
    NSURLSessionDataTask *task = [session dataTaskWithURL:[NSURL URLWithString:testURL] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            [self proxyTestDidFinish:(NSHTTPURLResponse *)response withError:error];
        }
    }];
    
    NSString *testingMessage = @"Testing proxy (may take up to 30 seconds)...";
    [self updateProxyLoadStatus:YES message:testingMessage];
    NSLog(@"INFO: %@", testingMessage);
    [_logger addToLog:[NSString stringWithFormat:@"INFO: %@", testingMessage]];
    [task resume];
}

- (void)proxyTestDidFinish:(NSHTTPURLResponse *)response withError:(NSError *)error
{
    if (response.statusCode != 200)
    {
        NSLog(@"WARNING: Proxy failed to load test page: %@", response.URL);
        [_logger addToLog:[NSString stringWithFormat:@"WARNING: Proxy failed to load test page: %@", response.URL]];
        if (!_currentIsSilent)
        {
            NSAlert *alert = [NSAlert new];
            alert.messageText = @"Proxy failed to load test page.\nDownloads may fail.\nDo you wish to continue?";
            [alert addButtonWithTitle:@"No"];
            [alert addButtonWithTitle:@"Yes"];
            alert.informativeText = [NSString stringWithFormat: @"Failed to load %@ within 30 seconds\nUsing proxy: %@\nError: %@", response.URL, [_proxyDict[@"proxy"] url], (error ? error.localizedDescription : @"Unknown error")];
            alert.alertStyle = NSAlertStyleCritical;
            if ([alert runModal] == NSAlertFirstButtonReturn)
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
