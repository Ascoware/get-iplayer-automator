//
//  SafeArchiver.m
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 1/2/19.
//

#import "SafeArchiver.h"

@implementation SafeArchiver

+(NSObject *)unarchive:(NSData *)data {
    @try {
        id object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        return object;
    } @catch (NSException *exception) {
        DDLogError(@"ERROR attempting to unarchive object: %@", exception);
    }
    return nil;
}

@end
