//
//  DownloadHistoryEntry.swift
//  Get iPlayer Automator
//

@objcMembers public class DownloadHistoryEntry : NSObject {
    var pid: String = ""
    var showName: String = ""
    var episodeName: String = ""
    var type: String = ""
    var someNumber: String = ""
    var downloadFormat: String = ""
    var downloadPath: String = ""

    var entryString: String {
        return "\(pid)|\(showName)|\(episodeName)|\(type)|\(someNumber)|\(downloadFormat)|\(downloadPath)"
    }
}
