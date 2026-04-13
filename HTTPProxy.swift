//
//  HTTPProxy.m
//  Get_iPlayer GUI
//

import Foundation
import CoreFoundation

@objc
public class HTTPProxy: NSObject {
    @objc public var url: URL
    @objc public var type: String
    @objc public var host: String?
    @objc public var port: Int
    @objc public var user: String?
    @objc public var password: String?

    @objc
    public init(url: URL) {
        self.url = url
        if url.scheme?.lowercased() == "https" {
            self.type = kCFProxyTypeHTTPS as String
        } else {
            self.type = kCFProxyTypeHTTP as String
        }
        self.host = url.host
        self.port = url.port ?? 0
        self.user = url.user
        self.password = url.password
    }

    @objc
    public convenience init(string: String) {
        let lowercased = string.lowercased()
        let urlString: String
        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
            urlString = string
        } else {
            urlString = "http://\(string)"
        }
        self.init(url: URL(string: urlString)!)
    }
}

