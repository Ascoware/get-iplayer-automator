//
//  GIPArguments.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/7/20.
//  Copyright © 2020 Ascoware LLC. All rights reserved.
//

import Foundation


public func typeArgumentForCacheUpdate(includeITV: Bool) -> String {
    var typeArgument = ""
    var cacheTypes = [String]()
    
    if let cacheBBC = UserDefaults.standard.value(forKey: "CacheBBC_TV") as? Bool, cacheBBC {
        cacheTypes.append("tv")
    }
    
    if let cacheITV = UserDefaults.standard.value(forKey: "CacheITV_TV") as? Bool, cacheITV {
        cacheTypes.append("itv")
    }
    
    if let cacheRadio = UserDefaults.standard.value(forKey: "CacheBBC_Radio") as? Bool, cacheRadio {
        cacheTypes.append("radio")
    }
    
    if cacheTypes.count == 0 {
        cacheTypes.append("tv")
    }

    typeArgument += "--type=" + cacheTypes.joined(separator: ",")    
    return typeArgument
}


public var profileDirArgument: String {
    let appSupportURL = FileManager.default.applicationSupportDirectory
    return "--profileDir=\"\(appSupportURL.path)\""
}

public let cacheExpiryArgument = "-e60480000000000000"

public let noWarningArg = "--nocopyright"

public let standardListFormat = "--listformat=<pid>|<type>|<name> - <episode>|<channel>|<web>|<available>"

public let searchResultFormat = "--listformat=SearchResult|<pid>|<available>|<type>|<name>|<episode>|<channel>|<seriesnum>|<episodenum>|<desc>|<thumbnail>|<web>|<available>"

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
