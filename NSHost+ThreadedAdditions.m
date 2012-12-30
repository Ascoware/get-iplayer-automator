//
//  NSHost+ThreadSafety.m
//
//  Created by Matt Gallagher on 2009/11/14.
//  Copyright 2009 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import "NSHost+ThreadedAdditions.h"
#import "objc/runtime.h"

static void SwizzleClassMethods(Class class, SEL firstSelector, SEL secondSelector)
{
	Method firstMethod = class_getClassMethod(class, firstSelector);
	Method secondMethod = class_getClassMethod(class, secondSelector);
	if (!firstMethod || !secondMethod)
	{
		NSLog(@"Unable to swizzle class methods for selectors %@ and %@ on class %@",
			NSStringFromSelector(firstSelector),
			NSStringFromSelector(secondSelector),
			NSStringFromClass(class));
		return;
	}
	
	method_exchangeImplementations(firstMethod, secondMethod);
}


@interface HostLookupOperation : NSOperation
{
	id receiver;
	SEL receiverSelector;
	NSThread *receivingThread;
	SEL lookupSelector;
	id parameter;
}

@end

@implementation HostLookupOperation

- (id)initWithReceiver:(id)aReceiver receiverSelector:(SEL)aReceiverSelector
	receivingThread:(NSThread *)aReceivingThread
	lookupSelector:(SEL)aLookupSelector lookupParameter:(id)aParameter
{
	self = [super init];
	if (self)
	{
		receiver = [aReceiver retain];
		receiverSelector = aReceiverSelector;
		receivingThread = [aReceivingThread retain];
		lookupSelector = aLookupSelector;
		parameter = [aParameter retain];
	}
	return self;
}

- (void)main
{
	[receiver
		performSelector:receiverSelector
		onThread:receivingThread
		withObject:[NSHost performSelector:lookupSelector withObject:parameter]
		waitUntilDone:NO];
}

- (void)dealloc
{
	[receiver release];
	[receivingThread release];
	[parameter release];
	[super dealloc];
}

@end

@implementation NSHost (ThreadSafety)

+ (void)load
{
	SwizzleClassMethods(self, @selector(_fixNSHostLeak), @selector(threadSafe_fixNSHostLeak));
	SwizzleClassMethods(self, @selector(currentHost), @selector(threadSafeCurrentHost));
	SwizzleClassMethods(self, @selector(hostWithName:), @selector(threadSafeHostWithName:));
	SwizzleClassMethods(self, @selector(hostWithAddress:), @selector(threadSafeHostWithAddress:));
	SwizzleClassMethods(self, @selector(isHostCacheEnabled), @selector(threadSafeIsHostCacheEnabled));
	SwizzleClassMethods(self, @selector(setHostCacheEnabled:), @selector(threadSafeSetHostCacheEnabled:));
	SwizzleClassMethods(self, @selector(flushHostCache), @selector(threadSafeFlushHostCache));
}

+ (NSOperationQueue *)hostLookupQueue
{
	static NSOperationQueue *hostLookupQueue = nil;
	if (!hostLookupQueue)
	{
		@synchronized(self)
		{
			if (!hostLookupQueue)
			{
				hostLookupQueue = [[NSOperationQueue alloc] init];
			}
		}
	}
	return hostLookupQueue;
}

+ (void)currentHostInBackgroundForReceiver:(id)receiver selector:(SEL)receiverSelector
{
	[[self hostLookupQueue]
		addOperation:
			[[HostLookupOperation alloc]
				initWithReceiver:receiver
				receiverSelector:receiverSelector
				receivingThread:[NSThread currentThread]
				lookupSelector:@selector(currentHost)
				lookupParameter:nil]];
}

+ (void)hostWithName:(NSString *)name
	inBackgroundForReceiver:(id)receiver
	selector:(SEL)receiverSelector
{
	[[self hostLookupQueue]
		addOperation:
			[[HostLookupOperation alloc]
				initWithReceiver:receiver
				receiverSelector:receiverSelector
				receivingThread:[NSThread currentThread]
				lookupSelector:@selector(hostWithName:)
				lookupParameter:name]];
}

+ (void)hostWithAddress:(NSString *)address inBackgroundForReceiver:(id)receiver selector:(SEL)receiverSelector
{
	[[self hostLookupQueue]
		addOperation:
			[[HostLookupOperation alloc]
				initWithReceiver:receiver
				receiverSelector:receiverSelector
				receivingThread:[NSThread currentThread]
				lookupSelector:@selector(hostWithAddress:)
				lookupParameter:address]];
}

+ (void)threadSafe_fixNSHostLeak
{
	@synchronized(self)
	{
		objc_msgSend(self, @selector(threadSafe_fixNSHostLeak));
	}
}

+ (id)threadSafeCurrentHost
{
	@synchronized(self)
	{
		return [self threadSafeCurrentHost];
	}
}

+ (id)threadSafeHostWithName:(NSString *)name
{
	@synchronized(self)
	{
		return [self threadSafeHostWithName:name];
	}
}

+ (id)threadSafeHostWithAddress:(NSString *)address
{
	@synchronized(self)
	{
		return [self threadSafeHostWithAddress:address];
	}
}

+ (BOOL)threadSafeIsHostCacheEnabled
{
	@synchronized(self)
	{
		return [self threadSafeIsHostCacheEnabled];
	}
}

+ (void)threadSafeSetHostCacheEnabled:(BOOL)enabled
{
	@synchronized(self)
	{
		[self threadSafeSetHostCacheEnabled:enabled];
	}
}

+ (void)threadSafeFlushHostCache
{
	@synchronized(self)
	{
		[self threadSafeFlushHostCache];
	}
}

@end
