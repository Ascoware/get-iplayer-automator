//  Converted to Swift 5.7 by Swiftify v5.7.28606 - https://swiftify.com/
//
//  GetiPlayerArgumentsController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/3/14.
//
//

//
//  GetiPlayerArgumentsController.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/3/14.
//
//

import Foundation

private var sharedController: GetiPlayerArguments? = nil

class GetiPlayerArguments: NSObject {
    var cacheExpiryArg: String {
        return "--expiry=9999999999"
    }

    var profileDirArg: String {
        return "--profile-dir=\(FileManager.default.applicationSupportDirectory)"
    }

    var noWarningArg: String {
        return "--nocopyright"
    }

    override init() {
        super.init()
        if sharedController == nil {
            sharedController = self
        }
    }

    class func sharedController() -> GetiPlayerArguments? {
        if sharedController == nil {
            sharedController = self.init()
        }
        return sharedController
    }

    func typeArgument(forCacheUpdate: Bool) -> String? {
        // There's no harm in passing 'itv' as a cache type, but it will report 0 shows cached
        // which can be confusing.
        let includeITV = !forCacheUpdate

        var cacheTypes = ""

        if UserDefaults.standard.value(forKey: "CacheBBC_TV")?.isEqual(to: NSNumber(value: true)) ?? false || !forCacheUpdate {
            cacheTypes += "tv,"
        }
        if (UserDefaults.standard.value(forKey: "CacheITV_TV")?.isEqual(to: NSNumber(value: true)) ?? false && includeITV) || !forCacheUpdate {
            cacheTypes += "itv,"
        }
        if UserDefaults.standard.value(forKey: "CacheBBC_Radio")?.isEqual(to: NSNumber(value: true)) ?? false || !forCacheUpdate {
            cacheTypes += "radio,"
        }

        if cacheTypes.count > 0 {
            if let subRange = Range<String.Index>(NSRange(location: cacheTypes.count - 1, length: 1), in: cacheTypes) { cacheTypes.removeSubrange(subRange) }
            cacheTypes = "--type=\(cacheTypes)"
        }

        return cacheTypes
    }
}
