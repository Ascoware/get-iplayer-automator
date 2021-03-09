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
- (instancetype)init
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
- (NSString *)typeArgumentForCacheUpdate:(BOOL)forCacheUpdate andIncludeITV:(BOOL)includeITV
{
   if (forCacheUpdate) {
      runCacheUpdateSinceChange = YES;
   }
   
	if (runCacheUpdateSinceChange || !currentTypeArgument)
	{
        currentTypeArgument = @"";
        NSMutableString *cacheTypes = [[NSMutableString alloc] initWithString:@""];

		if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_TV"] isEqualTo:@YES] || !forCacheUpdate)
         [cacheTypes appendString:@"tv,"];
		if (([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheITV_TV"] isEqualTo:@YES] && includeITV) || !forCacheUpdate)
         [cacheTypes appendString:@"itv,"];
		if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_Radio"] isEqualTo:@YES] || !forCacheUpdate)
         [cacheTypes appendString:@"radio,"];

        if (cacheTypes.length > 0) {
            [cacheTypes deleteCharactersInRange:NSMakeRange(cacheTypes.length-1,1)];
            currentTypeArgument = [NSString stringWithFormat:@"--type=%@", cacheTypes];
        }
	}

    return currentTypeArgument;
}

- (IBAction)typeChanged:(id)sender
{
    runCacheUpdateSinceChange=YES;
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
   return @"--listformat=<pid>|<type>|<name>|<episode>|<channel>|<web>|<available>";
}


@end
