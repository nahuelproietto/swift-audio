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

//MARK:

public class AudioArray<T>: NSObject {
    
    public var size: Int = 0
    public var pointer: UnsafeMutablePointer<T>
    
    /// Call this method to initialize the current audio array
    ///
    /// - parameter size: An intValue that represents the lenght of the buffer
    init(size: Int) {
        self.size = size
        self.pointer = UnsafeMutablePointer<T>.allocate(capacity: size)
        super.init()
    }
    
    /// Call this method to copy samples from a given source
    ///
    /// - parameter source: Any <UnsafeMutablePointer> with scalar samples
    /// - parameter range: Any tuple of valid range
    public func copy(source: UnsafeMutablePointer<T>, to range: (Int, Int)) {
        guard (range.0 <= range.1) && range.1 <= size else { return }
        memcpy(pointer + range.0, source, MemoryLayout<T>.size * (range.1 - range.0))
    }
    
    /// Call this method to replace current samples with zero values
    /// Use this function only when the audio array is initialized
    public func zero() {
        memset(pointer, 0, MemoryLayout<T>.size * size)
    }
    
    /// Call this method to reset the current audio array
    /// Use this function to deallocate all the current values and allocate again with size
    public func reset() {
        pointer.deallocate()
        print("log.io.reset.\(debugDescription)")
        pointer = UnsafeMutablePointer<T>.allocate(capacity: size)
    }
    
    deinit {
        pointer.deallocate()
        print("log.io.deinit.\(debugDescription)")
    }
    
}
