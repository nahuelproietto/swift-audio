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
import CIO

//MARK:

public class AudioChannel: NSObject {
    
    public private(set) var length: Int
    public private(set) var isSilent: Bool
    
    private var buffer: AudioArray<Scalar>
    
    /// Call this method to initialize an audio channel
    ///
    /// - parameter lenght: A given size fo the audio channel
    public init(length: Int) {
        self.isSilent = false
        self.buffer = AudioArray<Scalar>(size: length)
        self.length = length
        super.init()
    }
    
    /// Call this method to initialize an audio channel
    ///
    /// - parameter storage: Any audio array with data
    /// - parameter lenght: A given size fo the audio channel
    public init(storage: AudioArray<Scalar>, length: Int) {
        self.isSilent = false
        self.buffer = storage
        self.length = length
        super.init()
    }
    
    /// Call this method to update the channel storage
    ///
    /// - parameter storage: Any initialized audio array
    public func copy(from storage: AudioArray<Scalar>) {
        self.buffer.reset()
        self.buffer = storage
        self.length = storage.size
        self.clearSilent()
    }
    
    /// Call this method to copy from channel
    ///
    /// - parameter channel: Any give channel
    public func copy(from channel: AudioChannel) {
        guard channel.length >= length else { return }
        guard !channel.isSilent else { return zero() }
        memcpy(data(), channel.data(), MemoryLayout<Scalar>.size * length)
    }
    
    /// Call this method to update the channel with a pointer
    ///
    /// - parameter storage: Any initialized audio array
    public func copy(from pointer: UnsafeMutablePointer<Scalar>, lenght: Int) {
        guard lenght == self.length else { return }
        self.buffer.reset()
        self.buffer.pointer = pointer
        self.length = lenght
        self.clearSilent()
    }
    
    /// Call this method to sum from channel
    ///
    /// - parameter channel: Any give channel
    public func sum(from channel: AudioChannel) {
        guard channel.length >= length, !channel.isSilent else { return }
        guard !isSilent else { return copy(from: channel) }
        VectorMath.vadd(data(), 1, channel.data(), 1, data(), 1, length)
    }
    
    /// Call this method to retrieve the sample data
    ///
    /// - returns: A <UnsafeMutablePointer<Scalar>> with audio data
    public func data() -> UnsafeMutablePointer<Scalar> {
        clearSilent()
        return buffer.pointer
    }
    
    /// Call this method to zero the audio channel
    public func zero() {
        guard !isSilent else { return }
        isSilent = true
        guard buffer.size > 0 else { return }
        buffer.zero()
    }
    
    /// Call this method to clear silent flags
    /// Use this method to set the current channel as silenced
    public func clearSilent() {
        isSilent = false
    }
    
    deinit {
        print("log.io.deinit.\(debugDescription)")
    }
    
}
