//
//  ResponseAnalyzer.swift
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

/// Object, responsible for server response analysis. It analyzes status codes, previous actions on specified URL, as well as `Retry-After` HTTP header to determine next course of action.
open class ResponseAnalyzer {
    
    /// Action, that should be taken after response analysis
    public enum Action: Equatable {
        
        // Request was successful, proceed to next URL
        case success
        
        // Request should be repeated after `timeInterval`
        case repeatRequest(after: TimeInterval)
        
        // Request should be considered as failed, reported to delegate. After that - proceed to next URL.
        case failure
        
        /// Action suggested is a retry action
        public var isRetry: Bool {
            switch self {
                case .repeatRequest: return true
                default: return false
            }
        }
    }
    
    /// Analyze response to propose next course of action.
    /// - Parameters:
    ///   - response: object, containing both original request and response received from the server
    ///   - configuration: current `SwarmConfiguration` object
    ///   - previousActions: previous actions taken on URL, that is currently being scraped
    /// - Returns: Proposed action.
    open func analyzeResponse(_ response: VisitedURL, configuration: SwarmConfiguration, previousActions: [Action]) -> Action {
        if response.response == nil, response.data == nil {
            // Server timeout
            if previousActions.retryCount() < configuration.delayedRequestRetries {
                return .repeatRequest(after: configuration.delayedRetryDelay)
            } else {
                return .failure
            }
        }
        guard let httpResponse = response.response as? HTTPURLResponse else {
            // Non-HTTP response? Cannot analyze that.
            return .failure
        }
        switch httpResponse.statusCode {
            case configuration.successStatusCodes: return .success
            case configuration.delayedRetryStatusCodes:
                if previousActions.retryCount() < configuration.delayedRequestRetries {
                    return .repeatRequest(after: configuration.delayedRetryDelay)
                } else {
                    return .failure
                }
            case configuration.autoThrottleHTTPStatusCodes:
                if previousActions.retryCount() < configuration.autoThrottleRequestRetries {
                    if let retryAfter = httpResponse.allHeaderFields["Retry-After"] as? String,
                       let retryAfterValue = TimeInterval(retryAfter) {
                        return .repeatRequest(after: min(retryAfterValue, configuration.maxAutoThrottleDelay))
                    } else {
                        return .repeatRequest(after: configuration.maxAutoThrottleDelay)
                    }
                } else {
                    return .failure
                }
            default: return .failure
        }
    }
}

extension Array where Element == ResponseAnalyzer.Action {
    /// Calculates number of retries for current URL
    /// - Returns: number of retries
    func retryCount() -> Int {
        filter { $0.isRetry }.count
    }
}

func ~=<T: Equatable>(pattern: [T], value: T) -> Bool {
    pattern.contains(value)
}
