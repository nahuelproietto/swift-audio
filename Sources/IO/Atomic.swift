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

public protocol Lock {
    func lock()
    func unlock()
}

public struct AtomicProperty<Value> {
    
    private let lock: Lock
    private var underlyingValue: Value

    /// Call this method to initialize an atomic property
    ///
    /// - parameter value: Any generic value
    /// - parameter lock: A given lock
    init(value: Value, lock: Lock = UnsafeMutex()) {
        self.lock = lock
        self.underlyingValue = value
    }

    var value: Value {
        get {
            lock.lock()
            let value = underlyingValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            underlyingValue = newValue
            lock.unlock()
        }
    }
    
}

//MARK:

public final class UnsafeMutex: Lock {

    public func lock() {
        pthread_mutex_lock(&mutex)
    }

    private var mutex: pthread_mutex_t = {
        var mutex = pthread_mutex_t(); pthread_mutex_init(&mutex, nil)
        return mutex
    }()
    
    public func unlock() {
        pthread_mutex_unlock(&mutex)
    }
    
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
}
