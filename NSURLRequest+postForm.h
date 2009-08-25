/*******************************************************************************
	NSURLRequest+postForm.h
		Copyright (c) 2008 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
		Some rights reserved: <http://opensource.org/licenses/mit-license.php>

	***************************************************************************/

#import <Cocoa/Cocoa.h>

@interface NSURLRequest (postForm)

+ (id)requestWithURL:(NSURL*)url postForm:(NSDictionary*)values;

@end
