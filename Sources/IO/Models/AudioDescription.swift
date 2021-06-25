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

public struct AudioDeviceDescription {
    var index: Int
    var identifier: String
    var nuoutput_channles: Int
    var nuinput_channels: Int
    var supported_samplerates: [Float]
    var nominal_samplerate: Float
    var is_default_output: Bool
    var is_default_input: Bool
}

extension AudioDeviceDescription: Equatable {
    
    /// Use this static function to compate two different descriptions
    ///
    /// - parameter lhs: A left descriptions to be compared
    /// - parameter rhs: A right descriptions to be compared
    public static func == (lhs: AudioDeviceDescription, rhs: AudioDeviceDescription) -> Bool {
        return lhs.index == rhs.index
            && lhs.identifier == rhs.identifier
            && lhs.nuoutput_channles == rhs.nuoutput_channles
            && lhs.nuinput_channels == rhs.nuinput_channels
            && lhs.supported_samplerates == rhs.supported_samplerates
            && lhs.nominal_samplerate == rhs.nominal_samplerate
            && lhs.is_default_output == rhs.is_default_output
            && lhs.is_default_input == rhs.is_default_input
    }
    
}
