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

public struct StreamSource {
    
    public var index: Int
    public var samplerate: Int
    public var channels: Int
    
    public static let mono = StreamSource(index: 0, channels: 1)
    public static let stereo = StreamSource(index: 0, channels: 2)
    
    
    /// Call this method to initialize the audio stream info
    ///
    /// - parameter index: A given index for the stream
    /// - parameter samplerate: A given samplerate for the stream
    public init(index: Int, channels: Int, samplerate: Int = AudioContext.defaultSampleRate) {
        self.index = index
        self.channels = channels
        self.samplerate = samplerate
    }

}

extension StreamSource: Equatable {
    
    /// Use this static function to compate two different infos
    ///
    /// - parameter lhs: A left info to be compared
    /// - parameter rhs: A right info to be compared
    public static func == (lhs: StreamSource, rhs: StreamSource) -> Bool {
        return lhs.index == rhs.index
            && lhs.channels == rhs.channels
            && lhs.samplerate == rhs.samplerate
    }
    
}
