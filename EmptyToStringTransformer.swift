//
//  EmptyToStringTransformer.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 7/10/25.
//

import Foundation

@objc(EmptyToStringTransformer)
class EmptyToStringTransformer: ValueTransformer {
    @objc private var string: String

    @objc override init() {
        self.string = ""
        super.init()
    }

    @objc init(string: String) {
        self.string = string
        super.init()
    }

    @objc override class func transformedValueClass() -> AnyClass {
        return NSString.self
    }

    @objc override class func allowsReverseTransformation() -> Bool {
        return true
    }

    @objc override func transformedValue(_ value: Any?) -> Any? {
        if let str = value as? String, str == "" {
            return string
        }
        return value
    }

    @objc override func reverseTransformedValue(_ value: Any?) -> Any? {
        if let str = value as? String, str == string {
            return ""
        }
        return value
    }
}
