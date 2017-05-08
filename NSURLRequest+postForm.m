/*******************************************************************************
	NSURLRequest+postForm.m
		Copyright (c) 2008-2009 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
		Some rights reserved: <http://opensource.org/licenses/mit-license.php>

	***************************************************************************/

#import "NSURLRequest+postForm.h"
#include <unistd.h>

@interface NSMutableData (append)
- (void)jr_appendString:(NSString*)string;
- (void)jr_appendFormat:(NSString *)format, ...;
@end
@implementation NSMutableData (append)
- (void)jr_appendString:(NSString*)string {
    [self appendData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}
- (void)jr_appendFormat:(NSString *)format, ... {
    va_list args;
	va_start(args, format);
	NSString *string = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
    [self jr_appendString:string];
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

+ (instancetype)requestWithURL:(NSURL*)url postForm:(NSDictionary*)values {
    //--
    // Create the mime multipart boundary.
    
    // TODO scan `values` to ensure uniqueness of `boundary`. Loop+regen UUID if collision is discovered.
    CFUUIDRef cfUuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString * uuid = CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, cfUuid));
    CFRelease(cfUuid);
    NSString *boundary = [NSString stringWithFormat:@"x-mime-boundary://%@", uuid];
    
    //--
    // Create the formData.
    NSMutableData *formData = [NSMutableData data];
#if defined(OBJC_API_VERSION) && OBJC_API_VERSION >= 2
    for (NSString *key in values.allKeys) {
#else
    NSEnumerator *e = [[values allKeys] objectEnumerator];
    NSString* key;
    while ((key = [e nextObject]) != nil) {
#endif
		[formData appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

        // TODO escape keys with quotes in them.
        [formData jr_appendFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n", key];
        
        id value = values[key];
        if ([value isKindOfClass:[NSData class]]) {
            [formData jr_appendString:@"\r\n"];
            [formData appendData:value];
        } else if ([value isKindOfClass:[NSString class]]) {
            //[formData appendFormat:@"Content-Type: text/plain; charset=utf-8\r\n\r\n"]; uncomment this if you want text to be interpreted as files!
            [formData jr_appendString:@"\r\n"];
            [formData jr_appendString:value];
            [formData jr_appendString:@"\r\n"];
        } else {
            NSAssert1(NO, @"unknown value class: %@", [value className]);
        }
    }
    [formData jr_appendFormat:@"\r\n--%@--\r\n", boundary];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", formData.length] forHTTPHeaderField:@"Content-Length"];
    request.HTTPBody = formData;
    
    return request;
}

@end
