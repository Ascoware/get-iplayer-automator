//
//  StringTrimFormatter.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 7/10/25.
//

import Foundation

@objc class StringTrimFormatter: Formatter {
    override func string(for obj: Any?) -> String? {
        if let str = obj as? String {
            return str.trimmingCharacters(in: .whitespaces)
        }
        return ""
    }

    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        obj?.pointee = string.trimmingCharacters(in: .whitespaces) as NSString
        return true
    }
}
