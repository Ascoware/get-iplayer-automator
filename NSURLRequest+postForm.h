/*******************************************************************************
	NSURLRequest+postForm.h
		Copyright (c) 2008-2009 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
		Some rights reserved: <http://opensource.org/licenses/mit-license.php>

	***************************************************************************/

#import <Cocoa/Cocoa.h>

@interface NSURLRequest (postForm)

+ (instancetype)requestWithURL:(NSURL*)url postForm:(NSDictionary*)values;

@end
