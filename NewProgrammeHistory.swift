//
//  NewProgrammeHistory.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 3/16/18.
//

import Foundation

@objc public class NewProgrammeHistory: NSObject {
    @objc public var programmeHistoryArray = [ProgrammeHistoryObject]()

    var itemsAdded = false
    var timeIntervalSince1970UTC: TimeInterval = 0
    var dateFound = ""
    
    static let _sharedInstance = NewProgrammeHistory()

    @objc public static func sharedInstance() -> NewProgrammeHistory {
        return _sharedInstance
    }

    var historyFile: URL {
        if let applicationSupportPath = FileManager.default.applicationSupportDirectory() {
            return URL(fileURLWithPath: applicationSupportPath.appending("/").appending("history.gia"))
        }
        
        return URL(fileURLWithPath: NSHomeDirectory().appending("/.get_iplayer/history.gia"))
    }

    private override init() {
        timeIntervalSince1970UTC = Date().timeIntervalSince1970
        timeIntervalSince1970UTC += Double(NSTimeZone.system.secondsFromGMT(for: Date()))
        timeIntervalSince1970UTC /= 24 * 60 * 60
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE MMM dd"
        dateFound = dateFormatter.string(from: Date())
        super.init()

        do {
            let data = try Data(contentsOf: historyFile)
            if let unarchivedHistory = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [ProgrammeHistoryObject] {
                programmeHistoryArray = unarchivedHistory
            }
        } catch {
            print("Couldn't read program history file.")
        }

        /* Cull history if > 3,000 entries */
        while programmeHistoryArray.count > 3000 {
            programmeHistoryArray.remove(at: 0)
        }
        
    }
    
    @objc func add(name: String?, tvChannel: String?, networkName: String?) {
        itemsAdded = true
        let newEntry = ProgrammeHistoryObject(sortKey: timeIntervalSince1970UTC, programmeName: name ?? "", dateFound: dateFound, tvChannel: tvChannel ?? "", networkName: networkName ?? "")
        programmeHistoryArray.append(newEntry)
    }
    
    @objc func flushHistoryToDisk() {
        itemsAdded = false
        /* Sort history array and flush to disk */
        let sort1 = NSSortDescriptor(key: "sortKey", ascending: true)
        let sort2 = NSSortDescriptor(key: "programmeName", ascending: true)
        let sort3 = NSSortDescriptor(key: "tvChannel", ascending: true)
        programmeHistoryArray = (programmeHistoryArray as NSArray).sortedArray(using: [sort1, sort2, sort3]) as? [ProgrammeHistoryObject] ?? programmeHistoryArray

        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: programmeHistoryArray, requiringSecureCoding: false)
            try data.write(to: historyFile)
        } catch {
            print("Couldn't write program history file")
        }
    }
    
}

