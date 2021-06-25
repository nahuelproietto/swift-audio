// Copyright (c) 2012-2021 Nahuel Proietto
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation

public struct Queue<T> {
    
    public var isEmpty: Bool {
        return size == 0
    }
    
    fileprivate var size: Int = 0
    fileprivate var startIndex : Int?
    fileprivate var array: [T] = [T]()
    fileprivate var endIndex: Int?
    
    public init() { }
    
    /// Call this method to enqueue an element
    ///
    /// - parameter element: Any element
    public mutating func enqueue(_ element: T) {
        array.append(element)
        size += 1
        if let index = endIndex {
            endIndex = index + 1
        } else {
            endIndex = array.count - 1
        }
        startIndex = array.count - size
    }
    
    /// Call this method to peak
    ///
    /// - returns : Any optional element
    public func peek() -> T? {
        guard !isEmpty else { return nil }
        guard let startIndex = startIndex else { return nil }
        return array[startIndex]
    }
    
    /// Call this method to dequeue an element
    /// 
    /// - returns : Any optional element
    public mutating func dequeue() -> T? {
        guard let _ = endIndex else { return nil }
        guard !isEmpty, let start = startIndex else { return nil }
        let element = array[start]
        size -= 1
        startIndex = isEmpty ? nil : start + 1
        endIndex   = isEmpty ? nil : endIndex
        return element
    }
    
}
