//
//  SwarmDelegate.swift
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

/// Interface for communicating with `Swarm` object.
public protocol SwarmDelegate: AnyObject {
    
    /// Networking transport for scrapping provided `url`.
    /// - Parameter url: url to scrap
    func spider(for url: ScrappableURL) -> Spider
    
    /// Reports failure of scrapping a URL. This method is not called for failures, that resulted in retries, and is only called after all retries have been performed.
    /// - Parameter url: server response for last request sent to this URL.
    func failedToScrapURL(_ url: VisitedURL)
    
    /// Reports successful visit to `url`, allowing developer to scrap its contents. You can use `url.htmlString()` method to retrieve HTML string from Data object.
    /// - Parameters:
    ///   - url: visited url along with it's data
    ///   - nextScrappableURLs: callback to add additional URLS to scrapping queue
    /// - Important: `nextScrappableURLs` closure must be called, otherwise Swarm will never complete scrapping, as it waits for each of those closures.
    func scrappedURL(_ url: VisitedURL, nextScrappableURLs: @escaping ([ScrappableURL]) -> Void)
    
    /// Request to `url` is being delayed either because error was received, or server asks to retry or slow-down. Reason can be found by inspecting server `response`.
    /// - Parameters:
    ///   - url: URL that is being scrapped
    ///   - timeInterval: Timeout before next request to this URL
    ///   - response: response from the server that led to delay. Usually an `HTTPURLResponse` instance.
    func delayingRequest(to url: ScrappableURL, for timeInterval: TimeInterval, becauseOf response: URLResponse?)
    
    /// Reports completion for all urls, that were added to Swarm.
    func scrappingCompleted()
}

public extension SwarmDelegate {
    
    /// Default protocol implementation, creates `URLSessionSpider` with `url`.
    func spider(for url: ScrappableURL) -> Spider {
        URLSessionSpider()
    }
    
    /// Default empty protocol implementation
    func failedToScrapURL(_ url: VisitedURL) {}
    
    /// Default empty protocol implementation
    func delayingRequest(to url: ScrappableURL, for timeInterval: TimeInterval, becauseOf response: URLResponse?) {}
}
