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

class StreamNode: AudioScheduledSourceNode { // Use for streaming
    
    public typealias Callback = (
        _ node: StreamNode,
        _ buffer: UnsafeMutablePointer<Scalar>,
        _ frameCount: Int,
        _ numChannels: Int) -> ()
    
    fileprivate var _now: Float = 0
    fileprivate var _callback: Callback?
    
    /// Call this method to initialize a callback node
    ///
    /// - parameter channels: A number of channels
    init(channels: Int) {
        super.init()
        addOutput(output: AudioNodeOutput(audioNode: self, numberOfChannels: channels))
        print("log.io.init.\(debugDescription))")
        initialize()
    }
    
    /// Call this method to configure the render callback
    ///
    /// - parameter callback: A given callback
    public func set(callback: @escaping Callback) {
        _callback = callback
    }
    
    /// Call this method to process the given node
    ///
    /// - parameter lock: An inout render lock
    /// - parameter framesToProcess: A frame amount to process
    public override func process(lock: inout ContextRenderLock, framesToProcess: Int) {
        guard let destination = output(index: 0)?.bus(lock: &lock) else { return }
        
        guard isInitialized && destination.numberOfChannels > 0 && _callback != nil else {
            return destination.zero()
        }
        
        var quantumFrameOffset: Int = 0
        var nonSilentFramesToProcess: Int = 0
        
        updateSchedulingInfo(
            lock: &lock,
            quantumFrameSize: framesToProcess,
            outputBus: destination,
            quantumFrameOffset: &quantumFrameOffset,
            nonSilentFramesToProcess: &nonSilentFramesToProcess)
        
        for i in 0...destination.numberOfChannels {
            guard let destChannel = destination.channel(index: i) else { continue }
            let frames = nonSilentFramesToProcess
            let numberOfChannels = destination.numberOfChannels
            _callback?(self, destChannel.data().advanced(by: quantumFrameOffset), frames, numberOfChannels)
        }
        
        _now += Float(framesToProcess) / Float(lock.context.sampleRate)
        destination.clearSilent()
        
    }
    
    /// Call this method to get the current time
    ///
    /// - returns: A floatValue with the current time
    public func now() -> Float {
        return _now
    }
    
    /// Call this method to propagate silence
    ///
    /// - parameter lock: Any context render lock
    /// - returns: A boolValue that indicates if should propagate silence
    public func propagateSilence(lock: inout ContextRenderLock) -> Bool {
        return !isPlayingOrScheduled || isFinished
    }
    
    /// Called to get the current node tail time
    ///
    /// - parameter lock: A given context render lock
    /// - returns: A floatValue that indicates the tail time
    override func tailTime(lock: inout ContextRenderLock) -> TimeInterval {
        return AudioNode.zero
    }
    
    /// Called to get the current node latency time
    ///
    /// - parameter lock: A given context render lock
    /// - returns: A floatValue that indicates the latency time
    override func latencyTime(lock: inout ContextRenderLock) -> TimeInterval {
        return AudioNode.zero
    }
    
    /// Called on reset
    ///
    /// - parameter lock: A context render lock
    public override func reset(lock: inout ContextRenderLock) {
        print("log.io.reset.\(debugDescription))")
    }
    
    deinit {
        uninitialize()
        print("log.io.deinit.\(debugDescription))")
    }
    
}
