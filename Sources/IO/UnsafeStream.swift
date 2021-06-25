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

public class UnsafeRawAudioStream<T>: NSObject {
    
    public var channels: Int = 2
    public var bufferSize: Int = 0
    public var interleaved: Bool = true
    public var buffer: UnsafeMutablePointer<T>
    public var sampleRate: Int = AudioContext.defaultSampleRate
    
    /// Call this method to initialize an unsafe raw audio stream
    ///
    /// - parameter capacity: An lenght for the pointer
    public init(capacity: Int, numberOfChannels: Int = 2) {
        channels = numberOfChannels
        buffer = UnsafeMutablePointer<T>.allocate(capacity: capacity)
        bufferSize = capacity
        super.init()
    }
    
    /// Call this method to replace samples
    ///
    /// - parameter source: Any unsafe mutable pointer with samples
    /// - parameter lenght: A given size for the buffer
    public func copy(from source: UnsafeMutablePointer<Scalar>, lenght: Int) {
        buffer = UnsafeMutablePointer<T>.allocate(capacity: lenght)
        memcpy(buffer, source, MemoryLayout<Float>.size * lenght)
        bufferSize = lenght
    }
    
    deinit {
        buffer.deallocate()
        print("log.io.deinit.\(debugDescription)")
    }
    
}
