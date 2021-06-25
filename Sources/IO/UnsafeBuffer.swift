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

public class UnsafeBuffer<Element: Numeric> {

    private var items: UnsafeMutablePointer<Element>
    private let lock = DispatchSemaphore(value: 1)
    private var _count = 0
    
    private(set) var head = 0
    private(set) var capacity = 0
    private(set) var tail = 0
        
    var availableForWriting: Int {
        return capacity - count
    }
    
    var availableForReading: Int {
        return abs(head - tail)
    }
    
    var isFull: Bool {
        return capacity == count
    }
    
    var count: Int {
        defer { lock.signal() }; lock.wait()
        return _count
    }
    
    var isEmpty: Bool {
        return head == tail && !isFull
    }

    public init(capacity: Int) {
        self.capacity = capacity
        items = UnsafeMutablePointer<Element>.allocate(capacity: capacity)
    }

    public func push(_ values: UnsafePointer<Element>, amount: Int) {
        guard !(isFull) else { return }

        let available: Int = capacity - (head % capacity)
        let remaining: Int = amount - available
        
        if amount > available {
            memcpy(items.advanced(by: head % capacity), values, MemoryLayout<Element>.size * available)
            memcpy(items.advanced(by: 0), values.advanced(by: remaining), MemoryLayout<Element>.size * remaining)
        }
        else {
            memcpy(items.advanced(by: head % capacity), values, MemoryLayout<Element>.size * amount)
        }
        
        head = (head + amount) % capacity
        atomicCountAdd(amount)
    }

    public func pop(amount: Int) -> UnsafeMutablePointer<Element>? {
        guard !isEmpty && amount <= availableForWriting else { return nil }

        let buffer = UnsafeMutablePointer<Element>.allocate(capacity: amount)
        
        let available = capacity - (tail % capacity)
        let remaining: Int = amount - available
        
        if amount > available {
            memcpy(buffer, items.advanced(by: tail % capacity), MemoryLayout<Element>.size * available)
            memcpy(buffer.advanced(by: available), items.advanced(by: 0), MemoryLayout<Element>.size * remaining)
        }
        else {
            memcpy(buffer, items.advanced(by: tail % capacity), MemoryLayout<Element>.size * amount)
        }
        
        tail = (tail + amount) % capacity
        atomicCountAdd(-amount)

        return buffer
    }

    private func atomicCountAdd(_ value: Int) {
        lock.wait()
        defer { lock.signal() }
        if _count + value > capacity {
            _count = (_count + value) % capacity
        } else {
            _count += value
        }
    }
    
    deinit {
        items.deallocate()
    }
    
}
