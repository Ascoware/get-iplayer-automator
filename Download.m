//
//  Download.m
//  
//
//  Created by Thomas Willson on 12/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Download.h"

@implementation Download
- (void)cancelDownload:(id)sender
{
    NSLog(@"Cancel Download");
}
- (id)init
{
    [super init];
    
    //Prepare Time Remaining
	rateEntries = [[NSMutableArray alloc] init];
	lastDownloaded=0;
	outOfRange=0;
    
    return self;
}
@synthesize show;
#pragma mark Notification Posters
- (void)addToLog:(NSString *)logMessage noTag:(BOOL)b
{
	if (b)
	{
		[nc postNotificationName:@"AddToLog" object:nil userInfo:[NSDictionary dictionaryWithObject:logMessage forKey:@"message"]];
        NSLog(@"%@",logMessage);
	}
	else
	{
		[nc postNotificationName:@"AddToLog" object:self userInfo:[NSDictionary dictionaryWithObject:logMessage forKey:@"message"]];
        NSLog(@"%@",logMessage);
	}
	[log appendFormat:@"%@\n", logMessage];
}
- (void)addToLog:(NSString *)logMessage
{
	[nc postNotificationName:@"AddToLog" object:self userInfo:[NSDictionary dictionaryWithObject:logMessage forKey:@"message"]];
	[log appendFormat:@"%@\n", logMessage];
}
- (void)setCurrentProgress:(NSString *)string
{
	[nc postNotificationName:@"setCurrentProgress" object:self userInfo:[NSDictionary dictionaryWithObject:string forKey:@"string"]];
}
- (void)setPercentage:(double)d
{
	if (d<=100.0)
	{
		NSNumber *value = [[NSNumber alloc] initWithDouble:d];
		[nc postNotificationName:@"setPercentage" object:self userInfo:[NSDictionary dictionaryWithObject:value forKey:@"nsDouble"]];
	}
	else
	{
		[nc postNotificationName:@"setPercentage" object:self userInfo:nil];
	}
}
#pragma mark Message Processers
- (void)processFLVStreamerMessage:(NSString *)message
{
    NSScanner *scanner = [NSScanner scannerWithString:message];
    [scanner setScanLocation:0];
    [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
    double downloaded, elapsed, percent, total;
    if ([scanner scanDouble:&downloaded])
    {
        [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
        if (![scanner scanDouble:&elapsed]) elapsed=0.0;
        [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
        if (![scanner scanDouble:&percent]) percent=102.0;
        if (downloaded>0 && percent>0 && percent!=102) total = ((downloaded/1024)/(percent/100));
        else total=0;
        if (percent != 102)
            [self setCurrentProgress:[NSString stringWithFormat:@"%.1f%% - (%.2f MB/~%.0f MB) -- %@",percent,downloaded/1024,total,[show valueForKey:@"showName"]]];
        else
            [self setCurrentProgress:[NSString stringWithFormat:@"%.2f MB Downloaded -- %@",downloaded/1024,[show showName]]];
        [self setPercentage:percent];
        if (percent != 102)
            [show setValue:[NSString stringWithFormat:@"Downloading: %.1f%%", percent] forKey:@"status"];
        else 
            [show setValue:@"Downloading..." forKey:@"status"];
        
        //Calculate Time Remaining
        downloaded=downloaded/1024;
        if (total>0 && downloaded>0 && percent>0)
        {
            if ([rateEntries count] == 100)
            {
                
                double rate = ((downloaded-lastDownloaded)/(-[lastDate timeIntervalSinceNow]));
                if (rate < (oldRateAverage*5) && rate > (oldRateAverage/5) && rate < 50)
                {
                    [rateEntries removeObjectAtIndex:0];
                    [rateEntries addObject:[NSNumber numberWithDouble:rate]];
                    outOfRange=0;
                }
                else 
                {
                    outOfRange++;
                    if (outOfRange>10)
                    {
                        rateEntries = [[NSMutableArray alloc] init];
                        outOfRange=0;
                    }
                }
                
                
                double rateSum=0;
                for (NSNumber *tempRate in rateEntries)
                {
                    rateSum=rateSum+[tempRate doubleValue];
                }
                double rateAverage = oldRateAverage = rateSum/100;
                lastDownloaded=downloaded;
                lastDate = [NSDate date];
                NSDate *predictedFinished = [NSDate dateWithTimeIntervalSinceNow:(total-downloaded)/rateAverage];
                
                unsigned int unitFlags = NSHourCalendarUnit | NSMinuteCalendarUnit;
                NSDateComponents *conversionInfo = [[NSCalendar currentCalendar] components:unitFlags fromDate:lastDate toDate:predictedFinished options:0];
                
                [self setCurrentProgress:[NSString stringWithFormat:@"%.1f%% - (%.2f MB/~%.0f MB) - %2d:%2d Remaining -- %@",percent,downloaded,total,[conversionInfo hour],[conversionInfo minute],[show valueForKey:@"showName"]]];
            }
            else 
            {
                if (lastDownloaded>0 && lastDate)
                {
                    double rate = ((downloaded-lastDownloaded)/(-[lastDate timeIntervalSinceNow]));
                    if (rate<50)
                        [rateEntries addObject:[NSNumber numberWithDouble:rate]];
                    lastDownloaded=downloaded;
                    lastDate = [NSDate date];
                    if ([rateEntries count]>98)
                    {
                        double rateSum=0;
                        for (NSNumber *entry in rateEntries)
                        {
                            rateSum = rateSum+[entry doubleValue];
                        }
                        oldRateAverage = rateSum/[rateEntries count];
                    }
                }
                else 
                {
                    lastDownloaded=downloaded;
                    lastDate = [NSDate date];
                }
                if (percent != 102)
                    [self setCurrentProgress:[NSString stringWithFormat:@"%.1f%% - (%.2f MB/~%.0f MB) -- %@",percent,downloaded,total,[show valueForKey:@"showName"]]];
                else
                    [self setCurrentProgress:[NSString stringWithFormat:@"%.2f MB Downloaded -- %@",downloaded/1024,[show showName]]];
            }
        }
        
        
    }
}
@end
