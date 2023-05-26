//
//  URLSessionSpider.swift
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

/// `Spider` based on `Foundation.URLSession` class.
open class URLSessionSpider: Spider {
    
    /// URLSession to use for sending requests. Defaults to URLSession.shared.
    public var session: URLSession = .shared
    
    /// Whether cookies should be handled by `URLRequest` that is created
    public var httpShouldHandleCookies: Bool = false
    
    /// Defines user agent to set for current request
    public var userAgent: UserAgent = .none
    
    /// Defines set of HTTP headers to be set on each URLRequest.
    public var httpHeaders : [String: String?] = [
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en",
        "Accept-Encoding": "br,gzip,deflate"
    ]
    
    /// Closure, that is run just before URLRequest is sent, to allow last-minute modifications to URLRequest.
    public var requestModifier : (URLRequest) -> URLRequest = { $0 }
    
    /// Creates `URLSessionSpider`
    required public init() {
    }
    
    deinit {
        currentTask = nil
    }
    
    /// Creates `URLRequest` to send for `url`.
    /// - Parameter url: web address of the page to scrap
    /// - Returns: Configured `URLRequest` instance.
    open func urlRequest(for url: ScrappableURL) -> URLRequest {
        var request = URLRequest(url: url.url)
        request.httpShouldHandleCookies = httpShouldHandleCookies
        request.setValue(userAgent.value, forHTTPHeaderField: "User-Agent")
        for header in httpHeaders.keys {
            request.setValue(httpHeaders[header] ?? "", forHTTPHeaderField: header)
        }
        return requestModifier(request)
    }
    
    var currentTask: URLSessionTask?
    
    /// Sends request to `url`.
    /// - Parameter completion: completion closure to run when response is received.
    public func request(url: ScrappableURL, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        currentTask = session.dataTask(with: urlRequest(for: url)) { data, response, error in
            completion(data, response, error)
        }
        currentTask?.resume()
    }
}
