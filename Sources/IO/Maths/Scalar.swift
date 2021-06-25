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

public extension Scalar {
    
    func distance(from scalar: Scalar) -> Scalar {
        
        var retValue: Scalar = 0
        
        if self == scalar {
            return retValue
        }
        
        if self > 0 && scalar > 0 {
            if self > scalar { retValue = self - scalar }
            else { retValue = scalar - self }
        }
        
        if self > 0 && scalar < 0 {
            retValue = abs(self) + abs(scalar)
        }
        
        if self < 0 && scalar > 0 {
            retValue = abs(self) + abs(scalar)
        }
        
        if self < 0 && scalar < 0 {
            retValue = scalar + self
        }
        
        return retValue
    }
    
}

public extension Scalar {
    
    static let halfPi = pi / 2
    static let quarterPi = pi / 4
    static let twoPi = pi * 2
    static let degreesPerRadian = 180 / pi
    static let radiansPerDegree = pi / 180
    static let epsilon: Scalar = 0.0001

    static func ~= (lhs: Scalar, rhs: Scalar) -> Bool {
        return Swift.abs(lhs - rhs) < .epsilon
    }

    fileprivate var sign: Scalar {
        return self > 0 ? 1 : -1
    }
    
}
