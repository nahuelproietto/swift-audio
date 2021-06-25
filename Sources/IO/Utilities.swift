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

public typealias Scalar = Float32
public typealias FloatPoint3D = Vector3

//MARK:

struct AudioUtilities {
    
    /// Call this method to get linear to decibles
    ///
    /// - parameter parameter: Any floatValue
    static func linearToDecibels(parameter: Float) -> Float {
        guard parameter > 0 else { return -1000 }
        return 20 * log10f(parameter)
    }

    /// Call this method to get decibels to linear
    ///
    /// - parameter parameter: Any floatValue
    static func decibelsToLinear(parameter: Float) -> Float{
        return powf(10, 0.05 * parameter)
    }

    /// Call this method to get discrite time constant for sampleRate
    ///
    /// - parameter timeConstant: A floatValue
    /// - parameter sampleRate: Any sampleRate
    static func discreteTimeConstantForSampleRate(timeConstant: Float, sampleRate: Int) -> Float {
        return 1 - exp(-1 / (Float(sampleRate) * timeConstant))
    }

    /// Call this method to round time to sample frame
    ///
    /// - parameter time: Any timeInterval
    /// - parameter sampleRate: A current sampleRate
    static func timeToSampleFrame(time: TimeInterval, sampleRate: Int) -> Int {
        return Int(round(time * Double(sampleRate)))
    }

    /// Call this method to clamp values
    ///
    /// - parameter value: A value to clamp
    /// - parameter minValue: A minValue
    /// - parameter maxValue: A maxValue
    static func clamp(value: Float, to minValue: Float, to maxValue: Float) -> Float {
        return min(max(value, minValue), maxValue)
    }
    
    /// Call this method to flush to zero
    ///
    /// - parameter f: Any floatValue
    static func flushDenormalFloatToZero(f: Float) -> Float {
        return (abs(f) < 0.0) ? 0.0: f
    }
    
}

//MARK:

public extension URL {
    
    #if canImport(Foundation)
    enum Stream {
        case mp3, wav, unknown
    }
    
    /// Call this method to lookup the stream format in the path extension
    ///
    /// - returns: A kind of supported format
    func streamFormat() -> Stream {
        switch self.pathExtension {
        case "mp3":
            return .mp3
        case "wav":
            return .wav
        default:
            return .unknown
        }
    }
    #endif
    
}

//MARK:

extension String {
    #if canImport(Foundation)
    /// Call this method to make a c string
    /// - returns: An unsafe pointer
    func makeCString() -> UnsafeMutablePointer<Int8> {
        let result: UnsafeMutableBufferPointer<Int8> = UnsafeMutableBufferPointer<Int8>.allocate(capacity: self.utf8CString.count)
        _ = result.initialize(from: self.utf8CString)
        return result.baseAddress!
    }
    #endif
}
