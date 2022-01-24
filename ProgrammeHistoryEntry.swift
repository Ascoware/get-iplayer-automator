//
//  ProgrammeHistoryObject.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 3/16/18.
//

import Foundation

@objc public class ProgrammeHistoryObject: NSObject, NSCoding {
    @objc public var sortKey: TimeInterval = 0
    @objc public var programmeName: String = ""
    @objc public var dateFound: String = ""
    @objc public var tvChannel: String = ""
    @objc public var networkName: String = ""

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(sortKey, forKey: "sortKey")
        aCoder.encode(programmeName, forKey: "programmeName")
        aCoder.encode(dateFound, forKey: "dateFound")
        aCoder.encode(tvChannel, forKey: "tvChannel")
        aCoder.encode(networkName, forKey: "networkName")
    }

    @objc public convenience init(sortKey: TimeInterval, programmeName: String, dateFound: String, tvChannel: String, networkName: String) {
        self.init()
        self.sortKey = sortKey
        self.programmeName = programmeName
        self.dateFound = dateFound
        self.tvChannel = tvChannel
        self.networkName = networkName
    }
    
    @objc public override init() {
        super.init()
    }
    
    public required init?(coder: NSCoder) {
        super.init()

        sortKey = TimeInterval(coder.decodeDouble(forKey: "sortKey"))
        programmeName = coder.decodeObject(forKey: "programmeName") as? String ?? ""
        dateFound = coder.decodeObject(forKey: "dateFound") as? String ?? ""
        tvChannel = coder.decodeObject(forKey: "tvChannel") as? String ?? ""
        networkName = coder.decodeObject(forKey: "networkName") as? String ?? ""
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if let entry = object as? ProgrammeHistoryObject {
            return programmeName == entry.programmeName
        } else {
            return false
        }
    }

    public override var hash: Int {
        return programmeName.hash
    }
}
