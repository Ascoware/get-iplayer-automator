//
//  SBApplicationProtocol.swift
//  draperiez
//
//  Created by Leo Dion on 5/29/17.
//  Copyright © 2017 Leo Dion. All rights reserved.
//

import Foundation
import ScriptingBridge

@objc public protocol SBApplicationProtocol: SBObjectProtocol {
    func activate()
    var delegate: SBApplicationDelegate! { get set }
    var isRunning: Bool { get }
}
