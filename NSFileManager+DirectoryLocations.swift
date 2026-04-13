//
//  NSFileManager+DirectoryLocations.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 7/9/25.
//

import Foundation
import CocoaLumberjackSwift

enum DirectoryLocationError: Int, Error {
    case noPathFound
    case fileExistsAtLocation
}

let DirectoryLocationDomain = "DirectoryLocationDomain"

extension FileManager {
    func findOrCreateDirectory(
        searchPathDirectory: FileManager.SearchPathDirectory,
        domainMask: FileManager.SearchPathDomainMask,
        appendPathComponent: String?,
        errorOut: inout Error?
    ) -> String? {
        let paths = NSSearchPathForDirectoriesInDomains(searchPathDirectory, domainMask, true)
        guard let resolvedPath = paths.first else {
            let userInfo: [String: Any] = [
                NSLocalizedDescriptionKey: NSLocalizedString("No path found for directory in domain.", comment: ""),
                "NSSearchPathDirectory": searchPathDirectory.rawValue,
                "NSSearchPathDomainMask": domainMask.rawValue
            ]
            errorOut = NSError(domain: DirectoryLocationDomain,
                               code: DirectoryLocationError.noPathFound.rawValue,
                               userInfo: userInfo)
            return nil
        }

        var finalPath = resolvedPath
        if let appendComponent = appendPathComponent {
            finalPath = (finalPath as NSString).appendingPathComponent(appendComponent)
        }

        do {
            try self.createDirectory(atPath: finalPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            errorOut = error
            return nil
        }

        errorOut = nil
        return finalPath
    }

    @objc func applicationSupportDirectory() -> String? {
        let executableName = Bundle.main.infoDictionary?["CFBundleExecutable"] as? String ?? "UnknownApp"
#if GIA_DEBUG
        let dirName = executableName + "_debug"
#else
        let dirName = executableName
#endif
        var error: Error?
        let result = findOrCreateDirectory(
            searchPathDirectory: .applicationSupportDirectory,
            domainMask: .userDomainMask,
            appendPathComponent: dirName,
            errorOut: &error
        )

        if result == nil {
            DDLogError("Unable to find or create application support directory:\n\(String(describing: error))")
        }

        return result
    }
}
