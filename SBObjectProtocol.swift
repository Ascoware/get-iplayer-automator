//
//  SBObjectProtocol.swift
//  draperiez
//
//  Created by Leo Dion on 5/29/17.
//  Copyright © 2017 Leo Dion. All rights reserved.
//

import Foundation

@objc public protocol SBObjectProtocol: NSObjectProtocol {
  func get() -> Any!
}
