import Foundation

@objc
class GetiPlayerArguments: NSObject {
    @objc public static let shared = GetiPlayerArguments()

    private override init() {}

    @objc func typeArgument(forCacheUpdate: Bool) -> String {
        // There's no harm in passing 'itv' as a cache type, but it will report 0 shows cached
        // which can be confusing.
        let includeITV = !forCacheUpdate
        var cacheTypes: [String] = []

        let userDefaults = UserDefaults.standard

        if userDefaults.bool(forKey: "CacheBBC_TV") || !forCacheUpdate {
            cacheTypes.append("tv")
        }
        if (userDefaults.bool(forKey: "CacheITV_TV") && includeITV) || !forCacheUpdate {
            cacheTypes.append("itv")
        }
        if userDefaults.bool(forKey: "CacheBBC_Radio") || !forCacheUpdate {
            cacheTypes.append("radio")
        }

        if !cacheTypes.isEmpty {
            return "--type=\(cacheTypes.joined(separator: ","))"
        } else {
            return ""
        }
    }

    @objc var cacheExpiryArg: String {
        return "--expiry=9999999999"
    }

    @objc var profileDirArg: String {
        let appSupportDir = FileManager.default.applicationSupportDirectory() ?? "GetiPlayerAutomator"
        return "--profile-dir=\(appSupportDir)"
    }

    @objc var noWarningArg: String {
        return "--nocopyright"
    }
}

