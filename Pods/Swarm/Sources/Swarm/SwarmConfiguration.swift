//
//  SwarmConfiguration.swift
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

/// Enum, defining order in which URL's will be scrapped
public enum ScrappingBehavior {
    
    // URLs with larger depth will be prioritized
    case depthFirst
    
    // URLs with less depth will be prioritized
    case breadthFirst
    
    // Depth parameter is ignored. Swarm will operate as LIFO queue.
    case anyOrder
}

/// Configuration object for `Swarm`
public struct SwarmConfiguration {
    
    /// Creates configuration object
    public init(successStatusCodes: [Int] = [200],
                  delayedRetryStatusCodes: [Int] = [202],
                  delayedRetryDelay: TimeInterval = 5.0,
                  delayedRequestRetries: Int = 2,
                  autoThrottleHTTPStatusCodes: [Int] = [500, 502, 503, 504, 522, 524, 408, 429],
                  maxAutoThrottleDelay: TimeInterval = 30.0,
                  autoThrottleRequestRetries: Int = 2,
                  downloadDelay: TimeInterval = 1.0,
                  maxConcurrentConnections: Int = 8,
                  scrappingBehavior : ScrappingBehavior = .anyOrder) {
        self.successStatusCodes = successStatusCodes
        self.delayedRetryStatusCodes = delayedRetryStatusCodes
        self.delayedRetryDelay = delayedRetryDelay
        self.delayedRequestRetries = delayedRequestRetries
        self.autoThrottleHTTPStatusCodes = autoThrottleHTTPStatusCodes
        self.maxAutoThrottleDelay = maxAutoThrottleDelay
        self.autoThrottleRequestRetries = autoThrottleRequestRetries
        self.downloadDelay = downloadDelay
        self.maxConcurrentConnections = maxConcurrentConnections
        self.scrappingBehavior = scrappingBehavior
    }
    
    // HTTP status codes, that are considered successful. Defaults to 200.
    public var successStatusCodes : [Int]
    
    // HTTP status codes, that are interpreted as suggesting delayed retry. Defaults to 202.
    public var delayedRetryStatusCodes: [Int]
    
    // Delay before retry if performed. Defaults to 5 seconds.
    public var delayedRetryDelay : TimeInterval
    
    // Number of request retries before giving up. Defaults to 2.
    public var delayedRequestRetries: Int
    
    /// HTTP status codes, that are interpreted as suggesting delayed retry. Defaults to [500, 502, 503, 504, 522, 524, 408, 429].
    public var autoThrottleHTTPStatusCodes: [Int]
    
    /// Max auto-throttling delay (Swarm will try to adhere to "Retry-After" response header, but delay will not be larger than specified in this variable)
    public var maxAutoThrottleDelay: TimeInterval
    
    /// Number of request retries before giving up. Defaults to 2.
    public var autoThrottleRequestRetries: Int
    
    /// Download delay before downloading next page.
    public var downloadDelay: TimeInterval
    
    /// Maximum number of spiders working concurrently.
    public var maxConcurrentConnections: Int
    
    /// Order, in which scrapping queue is being processed.
    public var scrappingBehavior: ScrappingBehavior
}
