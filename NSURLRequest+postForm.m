/*******************************************************************************
	NSURLRequest+postForm.m
		Copyright (c) 2008 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
		Some rights reserved: <http://opensource.org/licenses/mit-license.php>

	***************************************************************************/

#import "NSURLRequest+postForm.h"
#include <unistd.h>

@interface NSMutableData (append)
- (void)appendString:(NSString*)string;
- (void)appendFormat:(NSString *)format, ...;
@end
@implementation NSMutableData (append)
- (void)appendString:(NSString*)string {
    [self appendData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}
- (void)appendFormat:(NSString *)format, ... {
    va_list args;
	va_start(args, format);
	NSString *string = [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
	va_end(args);
    [self appendString:string];
}
@end

@implementation NSURLRequest (postForm)

/*
 Generates formData something like this:
 
 --x-mime-boundary://BB2CAC15-E3EC-4B91-9102-68B02AEA5BBB
 Content-Disposition: form-data; name="firstName"
 Content-Type: text/plain; charset=utf-8
 
 fred
 --x-mime-boundary://BB2CAC15-E3EC-4B91-9102-68B02AEA5BBB
 Content-Disposition: form-data; name="lastName"
 Content-Type: text/plain; charset=utf-8
 
 flintstone
 --x-mime-boundary://BB2CAC15-E3EC-4B91-9102-68B02AEA5BBB--
*/

+ (id)requestWithURL:(NSURL*)url postForm:(NSDictionary*)values {
    //--
    // Create the mime multipart boundary.
    
    // TODO scan `values` to ensure uniqueness of `boundary`. Loop+regen UUID if collision is discovered.
    CFUUIDRef cfUuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString * uuid = (id)CFUUIDCreateString(kCFAllocatorDefault, cfUuid);
    CFRelease(cfUuid);
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5
    uuid = NSMakeCollectable(uuid);
#endif
    uuid = [uuid autorelease];
    NSString *boundary = [NSString stringWithFormat:@"x-mime-boundary://%@", uuid];
    
    //--
    // Create the formData.
    NSMutableData *formData = [NSMutableData data];
#if defined(OBJC_API_VERSION) && OBJC_API_VERSION >= 2
    for (NSString *key in [values allKeys]) {
#else
    NSEnumerator *e = [[values allKeys] objectEnumerator];
    NSString* key;
    while ((key = [e nextObject]) != nil) {
#endif
        [formData appendFormat:@"\r\n--%@\r\n", boundary];
        // TODO escape keys with quotes in them.
        [formData appendFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n", key];
        id value = [values objectForKey:key];
        if ([value isKindOfClass:[NSData class]]) {
            [formData appendString:@"\r\n"];
            [formData appendData:value];
        } else if ([value isKindOfClass:[NSString class]]) {
            [formData appendFormat:@"Content-Type: text/plain; charset=utf-8\r\n\r\n"];
            [formData appendString:value];
        } else {
            NSAssert1(NO, @"unknown value class: %@", [value className]);
        }
    }
    [formData appendFormat:@"\r\n--%@--\r\n", boundary];
    
    //--
    // 
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", [formData length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:formData];
    
    return request;
}

@end