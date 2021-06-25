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

public class ContextGraphLock: NSObject {
    
    public var context: AudioContext
    
    /// Call this method to initilize a context graph lock
    ///
    /// - parameter context: A unique context
    init(context: AudioContext) {
        context.lockGraph.lock()
        self.context = context
        super.init()
    }

    deinit {
        context.lockGraph.unlock() // Called on graph defer
    }
    
}

//MARK:

public class ContextRenderLock: NSObject {
    
    public var context: AudioContext
    
    /// Call this method to initilize a context render lock
    ///
    /// - parameter context: A unique context
    public init(context: AudioContext) {
        context.lockRender.lock()
        self.context = context
        super.init()
    }
    
    deinit {
        context.lockRender.unlock() // Called on render defer
    }
    
}
