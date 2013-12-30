//
//  main.m
//  GetiPlayerProxyUpdater
//  The goal of this application is to automatically update the provided proxy on the server as needed.
//
//  Created by Thomas Willson on 12/29/13.
//
//

#import <Foundation/Foundation.h>
#import "ASIHTTPRequest.h"

#define ProxyFilePath @"/Users/thomaswillson/Documents/proxy.txt"

//Function Prototypes
bool basicProxyTest(NSURL *proxyURL);
bool itvDownloadTest(NSURL *proxyURL);
bool bbcDownloadTest(NSURL *proxyURL);


int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        NSLog(@"Proxy Updater Started");
        
        NSString *proxyString = [@"http://" stringByAppendingString:[[NSString stringWithContentsOfFile:ProxyFilePath encoding:NSUTF8StringEncoding error:nil] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        
        NSURL *proxyURL = [NSURL URLWithString:proxyString];
        
        NSLog(@"Proxy: %@",proxyURL);
        
        bool proxyOK = TRUE;
        
        //Perform Basic Test on Proxy first
        proxyOK = basicProxyTest(proxyURL);
        
        //Test Download
        if (proxyOK) proxyOK = itvDownloadTest(proxyURL);
        if (proxyOK) proxyOK = bbcDownloadTest(proxyURL);
        
        
        if (proxyOK)
        {
            NSLog(@"Existing Proxy Works");
            return 0;
        }
        
        //If program reaches this point, a new proxy needs to be found.
        NSLog(@"Need to find new proxy");
        
        //Download Proxy List
        ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:@"http://www.xroxy.com/proxylist.php?port=&type=All_http&ssl=nossl&country=GB&latency=&reliability=#table"]];
        [request setTimeOutSeconds:10];
        [request setNumberOfTimesToRetryOnTimeout:3];
        [request startSynchronous];
        
        if ([request responseStatusCode] != 200) return 10; //Couldn't retrieve page.
        NSLog(@"Retrieved Page");
        
        NSScanner *listScanner = [NSScanner scannerWithString:[request responseString]];
        
        [listScanner scanUpToString:@"proxy:name=XROXY" intoString:nil];
        
        if (![listScanner scanString:@"proxy:name=XROXY " intoString:nil]) return 20; //Format not as expected.
        NSMutableArray *proxyListArr = [NSMutableArray arrayWithCapacity:20];
        
        while ([listScanner scanString:@"proxy&host=" intoString:nil])
        {
            NSString *host, *port;
            [listScanner scanUpToString:@"&port=" intoString:&host];
            [listScanner scanString:@"&port=" intoString:nil];
            [listScanner scanUpToString:@"&notes" intoString:&port];
            NSString *proxy = [NSString stringWithFormat:@"http://%@:%@",host,port];
            [proxyListArr addObject:[NSURL URLWithString:proxy]];
            
            [listScanner scanUpToString:@"proxy&host=" intoString:nil];
        }
        NSLog(@"Processed Page");
        NSURL *workingProxy = nil;
        for (NSURL *proxy in proxyListArr)
        {
            proxyOK = TRUE;
            
            //Perform Basic Test on Proxy first
            proxyOK = basicProxyTest(proxy);
            
            //Test Download
            if (proxyOK) proxyOK = itvDownloadTest(proxy);
            if (proxyOK) proxyOK = bbcDownloadTest(proxy);
            
            if (proxyOK)
            {
                workingProxy = proxy;
                break;
            }
        }
        NSLog(@"Processed Array");
        
        if (!workingProxy) return 30; //Could not find working proxy.
        
        NSString *newProxy = [NSString stringWithFormat:@"%@:%@",[workingProxy host],[workingProxy port]];
        NSLog(@"New Proxy: %@",newProxy);
        [newProxy writeToFile:ProxyFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NSLog(@"New Proxy saved");
    }
    return 0;
}

bool basicProxyTest(NSURL *proxyURL)
{
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com"]];
    [request setTimeOutSeconds:5];
    [request setNumberOfTimesToRetryOnTimeout:1];
    [request setProxyHost:[proxyURL host]];
    [request setProxyPort:[[proxyURL port] intValue]];
    
    [request startSynchronous];
    
    return [request responseStatusCode] == 200;
}

bool itvDownloadTest(NSURL *proxyURL)
{
    return true;
}

bool bbcDownloadTest(NSURL *proxyURL)
{
    return true;
}

