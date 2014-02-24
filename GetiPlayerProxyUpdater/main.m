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
#import "ITVDownload.h"
#import "Programme.h"
#import "HTTPProxy.h"


@interface ITVDownloadTest : NSObject {
    bool itvComplete;
    bool itvSuccess;
}
- (bool)itvDownloadTest:(NSURL *)proxyURL;
- (void)itvFinished:(NSNotification *)note;
@end



//Function Prototypes
bool basicProxyTest(NSURL *proxyURL);
bool bbcDownloadTest(NSURL *proxyURL);
int processProxyList(NSArray *proxyListArr);


//Global
bool runDownloads=false;

//Constant
NSString *ProxyFilePath = @"/Volumes/Server Storage/Web Root/get_iplayer/proxy.txt";
//NSString *ProxyFilePath = @"/Users/thomaswillson/proxy.txt";



int main(int argc, const char * argv[])
{
    @autoreleasepool {
        
        NSLog(@"Proxy Updater Started");
        
        //NSString *ProxyFilePath = [[[NSProcessInfo processInfo] environment] objectForKey:@"PROXY_LOC"];
        
        NSString *proxyString = [@"http://" stringByAppendingString:[[NSString stringWithContentsOfFile:ProxyFilePath encoding:NSUTF8StringEncoding error:nil] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        
        NSURL *proxyURL = [NSURL URLWithString:proxyString];
        
        NSLog(@"Proxy: %@",proxyURL);
        
        bool proxyOK = TRUE;
        
        //Perform Basic Test on Proxy first
        proxyOK = basicProxyTest(proxyURL);
        
        //Test Download
        ITVDownloadTest *itvDownloadTest = [[ITVDownloadTest alloc] init];
        if (proxyOK) proxyOK = [itvDownloadTest itvDownloadTest:proxyURL];
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
           NSString *host = [[NSString alloc] init];
           NSString *port = [[NSString alloc] init];
            [listScanner scanUpToString:@"&port=" intoString:&host];
            [listScanner scanString:@"&port=" intoString:nil];
            [listScanner scanUpToString:@"&notes" intoString:&port];
            NSString *proxy = [NSString stringWithFormat:@"http://%@:%@",host,port];
            [proxyListArr addObject:[NSURL URLWithString:proxy]];
            
            [listScanner scanUpToString:@"proxy&host=" intoString:nil];
        }
        NSLog(@"Processed Page");
        for (NSURL *proxy in proxyListArr)
            NSLog(@"%@\n",proxy);
       
       int returnCode;
       if ((returnCode = processProxyList(proxyListArr))) {
          NSLog(@"XRoxy Failed Me: %d",returnCode);
          
          proxyListArr = [NSMutableArray array];
          
          NSPipe *output = [[NSPipe alloc] init];
          NSTask *phantomBrowser = [[NSTask alloc] init];
          
          [phantomBrowser setLaunchPath:@"/opt/local/bin/phantomjs"];
          [phantomBrowser setArguments:@[@"/opt/local/open_page.js"]];
          [phantomBrowser setStandardOutput:output];
          
          [phantomBrowser launch];
          [phantomBrowser waitUntilExit];
          
          NSLog(@"Retrieved Proxy Solutions List\n");
          
          NSString *webpage  = [[NSString alloc] initWithData:[[output fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
          
          if ([webpage hasPrefix:@"<!-- <!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\""]) {
             NSString *host = [[NSString alloc] init];
             NSString *port = [[NSString alloc] init];
             NSScanner *scanner = [NSScanner scannerWithString:webpage];
             
             [scanner scanUpToString:@"<a href=\"http://www.proxysolutions.net/ref/35791/6ea52832/ban.html\" target=\"_top\"><img src=\"http://www.proxysolutions.net/affiliates/accounts/default1/banners/pslogo4682.jpg\"" intoString:nil];
             while ([scanner scanUpToString:@"unescape(" intoString:nil]) {
                [scanner scanUpToString:@"</script>" intoString:nil];
                [scanner scanString:@"</script>" intoString:nil];
                [scanner scanUpToString:@"<" intoString:&host];
                [scanner scanUpToString:@"</td><td>" intoString:nil];
                [scanner scanString:@"</td><td>" intoString:nil];
                [scanner scanUpToString:@"</" intoString:&port];
                
                host = [host stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSString *proxy = [NSString stringWithFormat:@"http://%@:%@",host,port];
                [proxyListArr addObject:[NSURL URLWithString:proxy]];
             }
             
             return processProxyList(proxyListArr);
             
          }
          else return 500; //Processing Proxy page failed.
          
       }
        
       
}
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
   
int processProxyList(NSArray *proxyListArr)
{
   NSURL *workingProxy = nil;
   for (NSURL *proxy in proxyListArr)
   {
      bool proxyOK;
      ITVDownloadTest *itvDownloadTest = [[ITVDownloadTest alloc] init];
      
      //Perform Basic Test on Proxy first
      proxyOK = basicProxyTest(proxy);
      NSLog(@"Basic Proxy Test: %d",proxyOK);
      
      //Test Download
      if (proxyOK) proxyOK = [itvDownloadTest itvDownloadTest:proxy];
      
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
   return 0;
}

@implementation ITVDownloadTest
-(bool)itvDownloadTest:(NSURL *)proxyURL
{
    NSLog(@"Starting ITV Test with Proxy: %@",proxyURL);
    itvComplete = false;
    itvSuccess = false;
    
    NSString *itvCache = [NSString stringWithContentsOfFile:@"/Volumes/Server Storage/Web Root/get_iplayer/cache/itv.cache" encoding:NSUTF8StringEncoding error:nil];
    
    NSScanner *scanner = [NSScanner scannerWithString:itvCache];
    
    [scanner scanUpToString:@"|Coronation Street|" intoString:nil];
    
    if (![scanner scanString:@"|Coronation Street|" intoString:nil]) return true;
    NSString *pid;
    
    [scanner scanUpToString:@"|" intoString:&pid];
    NSString *url = [NSString stringWithFormat:@"http://www.itv.com/CatchUp/Video/default.html?ViewType=5&amp;Filter=%@",pid];
    Programme *testShow = [[Programme alloc] init];
    [testShow setUrl:url];
    [testShow setPid:pid];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itvFinished:) name:@"DownloadFinished" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itvFinished:) name:@"MetadataSuccessful" object:nil];
    
    [[ITVDownload alloc] initTest:testShow proxy:[[HTTPProxy alloc] initWithURL:proxyURL]];
    
    while (!itvComplete)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];

    NSLog(@"ITV Success: %d",itvSuccess);
    return itvSuccess;
}
- (void)itvFinished:(NSNotification *)note
{
    if ([[note name] isEqualToString:@"DownloadFinished"])
        itvSuccess=false;
    else
        itvSuccess=true;
    itvComplete=true;
}
@end

bool bbcDownloadTest(NSURL *proxyURL)
{
    return true;
}

