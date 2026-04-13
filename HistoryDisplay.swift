//
//  HistoryDisplay.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 6/29/25.
//

import Foundation

@objc class HistoryDisplay: NSObject {
    @objc var programmeNameString: String?
    @objc var lineNumber: Int
    @objc var pageNumber: Int
    @objc var networkNameString: String?

    init(itemString: String?, tvChannel: String?, lineNumber: Int, pageNumber: Int) {
        self.programmeNameString = itemString
        self.lineNumber = lineNumber
        self.pageNumber = pageNumber
        self.networkNameString = tvChannel
    }
}

