//
//  GIPArguments.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/7/20.
//  Copyright © 2020 Ascoware LLC. All rights reserved.
//
import Foundation

public func progTypeArgument(forCacheUpdate: Bool) -> String {
    // There's no harm in passing 'itv' as a cache type, but it will report 0 shows cached
    // which can be confusing.
    let includeITV = !forCacheUpdate

    var cacheTypes = ""

    if UserDefaults.standard.bool(forKey: "CacheBBC_TV") || !forCacheUpdate {
        cacheTypes += "tv,"
    }
    if (UserDefaults.standard.bool(forKey: "CacheITV_TV") && includeITV) || !forCacheUpdate {
        cacheTypes += "itv,"
    }
    if UserDefaults.standard.bool(forKey: "CacheBBC_Radio") || !forCacheUpdate {
        cacheTypes += "radio,"
    }

    if cacheTypes.count > 0 {
        if let subRange = Range<String.Index>(NSRange(location: cacheTypes.count - 1, length: 1), in: cacheTypes) { cacheTypes.removeSubrange(subRange) }
        cacheTypes = "--type=\(cacheTypes)"
    }

    return cacheTypes
}

public var noWarningArg: String {
    return "--nocopyright"
}

public var profileDirArg: String {
    return "--profile-dir=\(FileManager.default.applicationSupportDirectory)"
}

public let cacheExpiryArg = "--expiry=9999999999"

// Set this for testing.
public var baseLocation = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")

var gipInstallation: URL {
    return baseLocation.appendingPathComponent("get_iplayer")
}

var extraBinariesPath: URL {
    return gipInstallation.appendingPathComponent("bin")
}

var getIPlayerPath: URL {
    return gipInstallation.appendingPathComponent("perl-darwin-2level/bin/get_iplayer")
}

var perlBinaryPath: URL {
    return gipInstallation.appendingPathComponent("perl-darwin-2level/bin/perl")
}

var perlEnvironmentPath: URL {
    return gipInstallation.appendingPathComponent("perl-darwin-2level/bin")
}

extension NSCoding where Self: NSObject {
    static func unsecureUnarchived(from data: Data) -> Self? {
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            let obj = unarchiver.decodeObject(of: self, forKey: NSKeyedArchiveRootObjectKey)
            if let error = unarchiver.error {
                print("Error:\(error)")
            }
            return obj
        } catch {
            print("Error:\(error)")
        }
        return nil
    }
}
