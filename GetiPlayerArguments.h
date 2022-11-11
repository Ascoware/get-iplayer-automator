//
//  GetiPlayerArgumentsController.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/3/14.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GetiPlayerArguments : NSObject 

+ (GetiPlayerArguments *)sharedController;

- (NSString *)typeArgumentForCacheUpdate:(BOOL)forCacheUpdate;

@property (readonly, nonnull) NSString *cacheExpiryArg;
@property (readonly, nonnull) NSString *profileDirArg;
@property (readonly, nonnull) NSString *noWarningArg;

@end

NS_ASSUME_NONNULL_END
