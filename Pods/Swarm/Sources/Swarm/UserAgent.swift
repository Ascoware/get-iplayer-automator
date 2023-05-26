//
//  UserAgent.swift
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

/// Defines what user agent should be used while sending scraping requests.
public enum UserAgent {
    
    // User-Agent header is empty
    case none
    
    // User-Agent header is set to provided string
    case `static`(String)
    
    // User-Agent header is randomly selected from provided values
    case randomized([String])
    
    /// Get User-Agent header for current request
    var value: String? {
        switch self {
            case .none: return nil
            case .static(let value): return value
            case .randomized(let values): return values.randomElement()
        }
    }
}
