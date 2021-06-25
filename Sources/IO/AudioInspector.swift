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

public class AudioBasicInspectorNode: AudioNode {
    
    /// Call this method to initialize the basic inspector node
    ///
    /// - parameter outputChannelCount: A number of channels for output
    init(outputChannelCount: Int) {
        super.init()
        
        addInput(input: AudioNodeInput(audioNode:self))
        addOutput(output: AudioNodeOutput(audioNode: self, numberOfChannels: outputChannelCount))
        
        print("log.io.init.\(debugDescription))")
        initialize()
    }
    
    /// Call this method to pull inputs from node
    ///
    /// - parameter lock: A given context render lock
    /// - parameter framesToProcess: An amount of frames to be processed
    override public func pullInputs(lock: inout ContextRenderLock, framesToProcess: Int) {
        guard let input = input(index: 0) else { return }
        guard let output = output(index: 0)?.bus(lock: &lock) else { return }
        
        input.pull(lock: &lock, inPlaceBus: output, framesToProcess: framesToProcess)
    }
    
    /// Call this method to check number of channels for input
    ///
    /// - parameter lock: Any context render lock
    /// - parameter input: A node input
    override public func checkNumberOfChannelsForInput(lock: inout ContextRenderLock, input: AudioNodeInput) {
        guard let current = self.input(index: 0), current.uuid == input.uuid else { return }
        guard let output = output(index: 0) else { return }
        
        let numberOfChannel = input.numberOfChannels(lock: &lock)
        
        if numberOfChannel != output.numberOfChannels {
            output.setNumberOfChannels(lock: &lock, numberOfChannels: numberOfChannel)
        }
        
        super.checkNumberOfChannelsForInput(lock: &lock, input: input)
    }
    
    /// Called to get the current node tail time
    ///
    /// - parameter lock: A given context render lock
    override public func tailTime(lock: inout ContextRenderLock) -> TimeInterval {
        return AudioNode.zero
    }
    
    /// Called to get the current node latency time
    ///
    /// - parameter lock: A given context render lock
    override public func latencyTime(lock: inout ContextRenderLock) -> TimeInterval {
        return AudioNode.zero
    }
    
    /// Called on node-reset
    /// 
    /// - parameter lock: Any context render lock
    public override func reset(lock: inout ContextRenderLock) {
        print("log.io.reset.\(debugDescription))")
        super.reset(lock: &lock)
    }
    
    deinit {
        uninitialize()
        print("log.io.deinit.\(debugDescription))")
    }

}
