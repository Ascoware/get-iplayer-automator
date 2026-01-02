//
//  ApplicationPaths.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 7/10/25.
//

import Foundation

@objc class ApplicationPaths: NSObject {
    private static let getiPlayerInstallation = Bundle.main.bundlePath.appending("/Contents/Resources/get_iplayer")
    @objc static let extraBinariesPath = getiPlayerInstallation.appending("/utils/bin")
    @objc static let getiPlayerPath = getiPlayerInstallation.appending("/perl/bin/get_iplayer")
    @objc static let perlBinaryPath = getiPlayerInstallation.appending("/perl/bin/perl")
    @objc static let perlEnvironmentPath = getiPlayerInstallation.appending("/perl/lib")
}
