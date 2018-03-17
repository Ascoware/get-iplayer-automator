//
//  GetITVListings.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 1/4/18.
//

import Foundation
import Kanna

@objc public class GetITVListingsParser : NSObject {
    
    var htmlPage: HTMLDocument?
    
    public init(html: String) throws {
        htmlPage = try? Kanna.HTML(html: html, encoding: .utf8)
        super.init()
    }
    
}
