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

#if os(macOS) || os(iOS)
import Accelerate
#endif

//MARK:

struct VectorMath {
    
    /// Call this method to add between two sources
    ///
    /// - parameter source1P: An unsafe pointer with samples
    /// - parameter sourceStride1: A number of samples to stride
    /// - parameter source2P: An unsafe pointer with samples
    /// - parameter sourceStride2: A number of samples to stride
    /// - parameter destP: An unsafe pointer to copy all the samples
    /// - parameter destStride: A number of samples to stride
    /// - parameter framesToProcess: A number of frames to process
    static func vadd(
        _ source1P: UnsafeMutablePointer<Scalar>,
        _ sourceStride1: Int,
        _ source2P: UnsafeMutablePointer<Scalar>,
        _ sourceStride2: Int,
        _ destP: UnsafeMutablePointer<Scalar>,
        _ destStride: Int,
        _ framesToProcess: Int) {
        
        #if os(macOS) || os(iOS)
        #endif
        
        var destIdx: Int = 0
        var sourceIdx1: Int = 0
        var sourceIdx2: Int = 0
        for _ in 0..<framesToProcess {
            let source1 = source1P.advanced(by: sourceIdx1).pointee
            let source2 = source2P.advanced(by: sourceIdx2).pointee
            destP.advanced(by: destIdx).pointee = source1 + source2
            destIdx += destStride
            sourceIdx1 += sourceStride1
            sourceIdx2 += sourceStride2
        }
    
    }
    
    /// Call this method to multiple between two sources
    ///
    /// - parameter source1P: An unsafe pointer with samples
    /// - parameter sourceStride1: A number of samples to stride
    /// - parameter source2P: An unsafe pointer with samples
    /// - parameter sourceStride2: A number of samples to stride
    /// - parameter destP: An unsafe pointer to copy all the samples
    /// - parameter destStride: A number of samples to stride
    /// - parameter framesToProcess: A number of frames to process
    static func vmul(
        _ source1P: UnsafeMutablePointer<Scalar>,
        _ sourceStride1: Int,
        _ source2P: UnsafeMutablePointer<Scalar>,
        _ sourceStride2: Int,
        _ destP: UnsafeMutablePointer<Scalar>,
        _ destStride: Int,
        _ framesToProcess: Int) {
        
        #if os(macOS) || os(iOS)
        #endif
        
        var destIdx: Int = 0
        var sourceIdx1: Int = 0
        var sourceIdx2: Int = 0
        for _ in 0..<framesToProcess {
            let source1 = source1P.advanced(by: sourceIdx1).pointee
            let source2 = source2P.advanced(by: sourceIdx2).pointee
            destP.advanced(by: destIdx).pointee = Scalar(Float(source1) * Float(source2))
            destIdx += destStride
            sourceIdx1 += sourceStride1
            sourceIdx2 += sourceStride2
        }
    }
    
    /// Call this method to add and multiply between a source and scale
    ///
    /// - parameter source1P: An unsafe pointer with samples
    /// - parameter sourceStride1: A number of samples to stride
    /// - parameter scale: A floatValue to scale source1P
    /// - parameter destP: An unsafe pointer to copy all the samples
    /// - parameter destStride: A number of samples to stride
    /// - parameter framesToProcess: A number of frames to process
    static func vsma(
        _ source1P: UnsafeMutablePointer<Scalar>,
        _ sourceStride1: Int,
        _ scale: Float,
        _ destP: UnsafeMutablePointer<Scalar>,
        _ destStride: Int,
        _ framesToProcess: Int) {
      
        #if os(macOS) || os(iOS)
        #endif
        
        var destIdx: Int = 0
        var sourceIdx1: Int = 0
        for _ in 0..<framesToProcess {
            let source1 = source1P.advanced(by: sourceIdx1).pointee
            destP.advanced(by: destIdx).pointee += Scalar(Float(source1) * scale)
            destIdx += destStride
            sourceIdx1 += sourceStride1
        }
        
    }
    
    /// Call this method to multiply from two sources
    ///
    /// - parameter source1P: An unsafe pointer with samples
    /// - parameter sourceStride1: A number of samples to stride
    /// - parameter scale: A floatValue to scale source1P
    /// - parameter destP: An unsafe pointer to copy all the samples
    /// - parameter destStride: A number of samples to stride
    /// - parameter framesToProcess: A number of frames to process
    static func vsmul(
        _ source1P: UnsafeMutablePointer<Scalar>,
        _ sourceStride1: Int,
        _ scale: Float,
        _ destP: UnsafeMutablePointer<Scalar>,
        _ destStride: Int,
        _ framesToProcess: Int) {
        
        #if os(macOS) || os(iOS)
        #endif
        
        let k = scale
        var destIdx: Int = 0
        var sourceIdx1: Int = 0
        for _ in 0..<framesToProcess {
            let doubleValue = Double(Double(k) * Double(source1P[sourceIdx1]))
            destP[destIdx] = Scalar(doubleValue)
            destIdx += destStride
            sourceIdx1 += sourceStride1
        }
        
    }
    
}

