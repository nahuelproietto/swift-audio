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

public struct RenderQuantumDesc {
    
    public var frame: Int
    public var samplerate: Int
    public var time: TimeInterval
    
    static var `default` = RenderQuantumDesc(0, 0, AudioContext.defaultSampleRate)
    
    /// Call this method to initialize the audio sampling info
    ///
    /// - parameter frame: A number of frame
    /// - parameter time: A current sampling time
    /// - parameter samplerate: A given samplerate
    /// - parameter epoch: A given array of epochs
    public init(_ frame: Int, _ time: TimeInterval, _ samplerate: Int) {
        self.frame = frame
        self.samplerate = samplerate
        self.time = time
    }
    
}

extension RenderQuantumDesc: Equatable {
    
    /// Use this static function to compate two different sampling infos
    ///
    /// - parameter lhs: A left sampling info to be compared
    /// - parameter rhs: A right sampling info to be compared
    public static func == (lhs: RenderQuantumDesc, rhs: RenderQuantumDesc) -> Bool {
        return lhs.frame == rhs.frame
            && lhs.samplerate == rhs.samplerate
            && lhs.time == rhs.time
    }
}
