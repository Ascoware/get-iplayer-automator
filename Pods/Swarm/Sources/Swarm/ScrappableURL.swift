//
//  ScrappableURL.swift
//  Swarm
//
//  Created by Denys Telezhkin on 12.01.21.
//  Copyright © 2021 Denys Telezhkin. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Object, containing URL to be scraped and it's depth
public struct ScrappableURL: Hashable {
    
    /// Arbitrary number, displaying how deep this URL is in website hierarchy
    public let depth: Int
    
    /// URL to be scraped
    public let url : URL
    
    /// Storage for values or objects related to this scrappable URL
    public let userInfo: [AnyHashable: AnyHashable]
    
    /// Creates `ScrappableURL` object.
    /// - Parameters:
    ///   - url: address of the web page to be scrapped
    ///   - depth: depth of URL in website hierarchy. Defaults to 1.
    public init(url: URL, depth: Int = 1, userInfo: [AnyHashable: AnyHashable] = [:]) {
        self.depth = depth
        self.url = url
        self.userInfo = userInfo
    }
}

/// Object, containing original `ScrappableURL`, as well as server response.
public struct VisitedURL {
    
    /// Original `ScrappableURL`
    public let origin: ScrappableURL
    
    /// Receive HTML string from data, received in the response, using `encoding`.
    /// - Parameter encoding: Encoding to use while converting to HTML string. Defaults to .utf8.
    /// - Returns: HTML string or nil if conversion failed or data is nil.
    public func htmlString(using encoding: String.Encoding = .utf8) -> String? {
        guard let data = data else { return nil }
        return String(data: data, encoding: encoding)
    }
    
    /// Data, received from web page
    public let data: Data?
    
    /// Response, received from the server. Usually, this is `HTTPURLResponse` instance.
    public let response: URLResponse?
    
    /// Error, received from the server, or nil if request was successful.
    public let error: Error?
}
