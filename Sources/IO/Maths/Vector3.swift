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

public struct Vector3: Hashable {
    
    public var x: Scalar
    public var y: Scalar
    public var z: Scalar
    
    public var stringValue: String {
        return "x:\(x) y:\(y) z:\(z)"
    }
    
    public func compare(with current: Vector3, with steps: Vector3) -> Vector3 {
        
        var transition = Vector3(x: current.x, y: current.y, z: current.z)
        
        if self.x > current.x { transition.x = transition.x + steps.x }
        if self.y > current.y { transition.y = transition.y + steps.y }
        if self.z > current.z { transition.z = transition.z + steps.z }
        
        if self.x < current.x { transition.x = transition.x - steps.x }
        if self.y < current.y { transition.y = transition.y - steps.y }
        if self.z < current.z { transition.z = transition.z - steps.z }
        
        return transition
    }
    
}

public extension Vector3 {
    
    static let x = Vector3(1, 0, 0)
    static let y = Vector3(0, 1, 0)
    static let z = Vector3(0, 0, 1)
    
    static let zero         = Vector3(0, 0, 0)
    static let foreground   = Vector3(0, 0, 0)
    static let middle       = Vector3(0, 0, -100)
    static let background   = Vector3(0, 0, -200)
    static let backgroundL  = Vector3(-200, 0, -200)
    static let backgroundR  = Vector3(200, 0, -200)
    
    var lengthSquared: Scalar {
        return x * x + y * y + z * z
    }

    var length: Scalar {
        return sqrt(lengthSquared)
    }

    var inverse: Vector3 {
        return -self
    }

    var xy: Vector2 {
        get {
            return Vector2(x, y)
        }
        set(v) {
            x = v.x
            y = v.y
        }
    }

    var xz: Vector2 {
        get {
            return Vector2(x, z)
        }
        set(v) {
            x = v.x
            z = v.y
        }
    }

    var yz: Vector2 {
        get {
            return Vector2(y, z)
        }
        set(v) {
            y = v.x
            z = v.y
        }
    }

    init(_ x: Scalar, _ y: Scalar, _ z: Scalar) {
        self.init(x: x, y: y, z: z)
    }

    init(_ v: [Scalar]) {
        assert(v.count == 3, "array must contain 3 elements, contained \(v.count)")
        self.init(v[0], v[1], v[2])
    }

    func toArray() -> [Scalar] {
        return [x, y, z]
    }

    func dot(_ v: Vector3) -> Scalar {
        return x * v.x + y * v.y + z * v.z
    }

    func cross(_ v: Vector3) -> Vector3 {
        return Vector3(y * v.z - z * v.y, z * v.x - x * v.z, x * v.y - y * v.x)
    }

    func normalized() -> Vector3 {
        let lengthSquared = self.lengthSquared
        if lengthSquared ~= 0 || lengthSquared ~= 1 {
            return self
        }
        return self / sqrt(lengthSquared)
    }

    func interpolated(with v: Vector3, by t: Scalar) -> Vector3 {
        return self + (v - self) * t
    }

    static prefix func - (v: Vector3) -> Vector3 {
        return Vector3(-v.x, -v.y, -v.z)
    }

    static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return Vector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return Vector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    static func * (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return Vector3(lhs.x * rhs.x, lhs.y * rhs.y, lhs.z * rhs.z)
    }

    static func * (lhs: Vector3, rhs: Scalar) -> Vector3 {
        return Vector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    static func / (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return Vector3(lhs.x / rhs.x, lhs.y / rhs.y, lhs.z / rhs.z)
    }

    static func / (lhs: Vector3, rhs: Scalar) -> Vector3 {
        return Vector3(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
    }

    static func ~= (lhs: Vector3, rhs: Vector3) -> Bool {
        return lhs.x ~= rhs.x && lhs.y ~= rhs.y && lhs.z ~= rhs.z
    }
    
    static func ==(lhs: Vector3, rhs: Vector3) -> Bool {
        return (lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z)
    }
    
    static func !=(lhs: Vector3, rhs: Vector3) -> Bool {
        return !(lhs==rhs)
    }
    
}
