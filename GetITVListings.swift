//
//  GetITVListings.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 1/4/18.
//

import Foundation
import Kanna

@objc public class GetITVListingsParser : NSObject {
    
    let htmlPage: HTMLDocument?
    
    public init(html: String) {
        htmlPage = Kanna.HTML(html: html, encoding: .utf8)
        super.init()
    }
    
}
