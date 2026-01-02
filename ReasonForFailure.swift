//
//  ReasonForFailure.swift
//  Get iPlayer Automator
//

import Foundation

@objc
public class ReasonForFailure : NSObject {
    @objc public var showName: String = ""
    @objc public var solution: String = ""

    public override init() {
        super.init()
    }

    public init(showName: String = "", solution: String = "") {
        self.showName = showName
        self.solution = solution
    }
}
