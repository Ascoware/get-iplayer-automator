//
//  SafeArchiver.h
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 1/2/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SafeArchiver : NSObject

+ (nullable NSObject *) unarchive:(nullable NSData *)data;

@end

NS_ASSUME_NONNULL_END
