//
//  DownloadQueue.swift
//  Get iPlayer Automator 3
//
//  Created by Scott Kovatch on 7/19/20.
//

import Foundation
import SwiftUI
import CocoaLumberjackSwift

class DownloadQueue: ObservableObject {
    var programs: [Programme] = []

    public func loadFromDisk() {
        let filename = "Queue.automatorqueue"
        let appSupportFolder = FileManager.default.applicationSupportDirectory
        let filePath = appSupportFolder.appendingPathComponent(filename)

        do {
            let fileContents = try Data(contentsOf: filePath)
            let rootObject = NSDictionary.unsecureUnarchived(from: fileContents)
            let tempQueue = rootObject?["queue"] as? [Programme]

            if let tempQueue {
                programs.append(contentsOf: tempQueue)
            }
        } catch {

        }
    }
}
