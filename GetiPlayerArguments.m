//
//  GetiPlayerArgumentsController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/3/14.
//
//

#import "GetiPlayerArguments.h"
#import "NSFileManager+DirectoryLocations.h"

static GetiPlayerArguments *sharedController = nil;

@implementation GetiPlayerArguments
- (id)init
{
   self = [super init];
   if (self) {
      runCacheUpdateSinceChange = NO;
      currentTypeArgument = nil;
      if (!sharedController) {
         sharedController = self;
      }
   }
   return self;
}
+ (GetiPlayerArguments *)sharedController {
   if (!sharedController) {
      sharedController = [[self alloc] init];
   }
   return sharedController;
}
- (NSString *)typeArgumentForCacheUpdate:(BOOL)forCacheUpdate
{
   if (forCacheUpdate) {
      runCacheUpdateSinceChange = YES;
   }
   
	if (runCacheUpdateSinceChange || !currentTypeArgument)
	{
		NSMutableString *typeArgument = [[NSMutableString alloc] initWithString:@"--type="];
		if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_TV"] isEqualTo:@YES])
         [typeArgument appendString:@"tv,"];
		if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheITV_TV"] isEqualTo:@YES])
         [typeArgument appendString:@"itv,"];
		if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_Radio"] isEqualTo:@YES])
         [typeArgument appendString:@"radio,"];
		if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_Podcasts"] isEqualTo:@YES])
         [typeArgument appendString:@"podcast,"];
		[typeArgument deleteCharactersInRange:NSMakeRange([typeArgument length]-1,1)];
		currentTypeArgument = [typeArgument copy];
		return [NSString stringWithString:typeArgument];
	}
	else {
		return currentTypeArgument;
   }
}
- (IBAction)typeChanged:(id)sender
{
	if ([sender state] == NSOffState)
		runCacheUpdateSinceChange=NO;
}
- (NSString *)cacheExpiryArgument:(id)sender
{
	//NSString *cacheExpiryArg = [[NSString alloc] initWithFormat:@"-e%d", ([[[NSUserDefaults standardUserDefaults] objectForKey:@"CacheExpiryTime"] intValue]*3600)];
	//return cacheExpiryArg;
	return @"-e60480000000000000";
}

- (NSString *)profileDirArg
{
   return [NSString stringWithFormat:@"--profile-dir=%@", [NSFileManager defaultManager].applicationSupportDirectory];
}

- (NSString *)noWarningArg
{
   return @"--nocopyright";
}

- (NSString *)standardListFormat
{
   return @"--listformat=<pid>: <type>, ~<name> - <episode>~, <channel>, <web>";
}


@end
