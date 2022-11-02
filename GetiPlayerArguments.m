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
    // There's no harm in passing 'itv' as a cache type, but it will report 0 shows cached
    // which can be confusing.
    BOOL includeITV = !forCacheUpdate;

    NSMutableString *cacheTypes = [[NSMutableString alloc] initWithString:@""];

    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_TV"] isEqualTo:@YES] || !forCacheUpdate)
        [cacheTypes appendString:@"tv,"];
    if (([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheITV_TV"] isEqualTo:@YES] && includeITV) || !forCacheUpdate)
        [cacheTypes appendString:@"itv,"];
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_Radio"] isEqualTo:@YES] || !forCacheUpdate)
        [cacheTypes appendString:@"radio,"];

    if (cacheTypes.length > 0) {
        [cacheTypes deleteCharactersInRange:NSMakeRange(cacheTypes.length-1,1)];
        cacheTypes = [NSMutableString stringWithFormat:@"--type=%@", cacheTypes];
    }

    return cacheTypes;
}

- (NSString *)cacheExpiryArg
{
	return @"--expiry=9999999999";
}

- (NSString *)profileDirArg
{
   return [NSString stringWithFormat:@"--profile-dir=%@", [NSFileManager defaultManager].applicationSupportDirectory];
}

- (NSString *)noWarningArg
{
   return @"--nocopyright";
}

@end
