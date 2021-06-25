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

public class AudioNodeInput: AudioSummingJunction {
    
    var uuid: UUID = UUID()
    
    public var node: AudioNode
    
    private var internalSummingBus: AudioBus
    
    /// Call this method to initialize the audio node input
    ///
    /// - parameter audioNode: A reference to the audio node
    /// - parameter processingSizeInFrame: The processing size for the audio input
    init(audioNode: AudioNode, processingSizeInFrames: Int = AudioNode.processingSizeInFrames) {
        node = audioNode
        internalSummingBus = AudioBus(numberOfChannels: Channels.mono.rawValue, lenght: processingSizeInFrames)
        super.init()
    }
    
    /// Call this method to notify every node that audio input has updated
    ///
    /// - parameter lock: A given context render lock
    public override func didUpdate(lock: inout ContextRenderLock) {
        node.checkNumberOfChannelsForInput(lock: &lock, input: self)
    }

    /// Call this method to connect any audio input to a given output
    ///
    /// - parameter lock: A given context render lock
    /// - parameter junction: A given audio node input
    /// - parameter output: A given audio node output
    static func connect(lock: inout ContextGraphLock, from junction: AudioNodeInput?, to output: AudioNodeOutput?) {
        guard let junction = junction, let output = output else { return }
        guard !junction.isConnected(output: output) else { return }
        output.addInput(lock: &lock, input: junction)
        junction.junctionConnectOutput(output: output)
    }
    
    /// Call this method to disconnect any audio input to a given output
    ///
    /// - parameter lock: A given context render lock
    /// - parameter junction: A given audio node input
    /// - parameter output: A given audio node output
    static func disconnect(lock: inout ContextGraphLock, from junction: AudioNodeInput?, to output: AudioNodeOutput?) {
        guard let junction = junction, let output = output else { return }
        guard junction.isConnected(output: output) else { return }
        junction.junctionDisconnectOutput(output: output)
        output.removeInput(lock: &lock, input: junction)
    }
    
    /// Call this method to pull samples
    ///
    /// - parameter lock: A given context render lock
    /// - parameter inPlaceBus: A given audio bus to place samples
    /// - parameter framesToProcess: A given number of frames to process
    @discardableResult
    public func pull(lock: inout ContextRenderLock, inPlaceBus: AudioBus?, framesToProcess: Int) -> AudioBus {
        updateRenderingState(lock: &lock)
        
        var numberOfConnections = numberOfRenderingConnections(lock: &lock)
        
        if numberOfConnections == 1 {
            if let output = renderingOutput(lock: &lock, i: 0) {
                return output.pull(lock: &lock, inPlaceBus: inPlaceBus, framesToProcess: framesToProcess)
            }
            numberOfConnections = 0
        }
        
        guard numberOfConnections > 0 else {
            internalSummingBus.zero()
            return internalSummingBus
        }
        
        internalSummingBus.zero()
        
        for i in 0..<numberOfConnections {
            if let output = renderingOutput(lock: &lock, i: i) {
                let connectionBus = output.pull(lock: &lock, inPlaceBus: nil, framesToProcess: framesToProcess)
                internalSummingBus.sum(from: connectionBus)
            }
        }
        
        return internalSummingBus
    }
    
    /// Call this method to get the current bus for the audio node input
    ///
    /// - parameter lock: A given context render lock
    /// - returns: A optional audio bus
    public func bus(lock: inout ContextRenderLock) -> AudioBus? {
        if numberOfRenderingConnections(lock: &lock) == 1 {
            let output = renderingOutput(lock: &lock, i: 0)
            return output?.bus(lock: &lock)
        }
        return internalSummingBus
    }
    
    /// Call this method to update the internal bus
    ///
    /// - parameter lock: A given context render lock
    public func updateInternalBus(lock: inout ContextRenderLock) {
        let lenght = AudioNode.processingSizeInFrames
        let numberOfInputChannels = numberOfChannels(lock: &lock)
        guard numberOfInputChannels != internalSummingBus.numberOfChannels else { return }
        internalSummingBus = AudioBus(numberOfChannels: numberOfInputChannels, lenght: lenght)
    }
    
    /// Call this method to get the current number of channels
    ///
    /// - parameter lock: A given context render lock
    public func numberOfChannels(lock: inout ContextRenderLock) -> Int {
        var maxChannels = 1
        
        let mode = node.channelCountMode
        let numberOfConnections = numberOfRenderingConnections(lock: &lock)
        
        guard mode != ChannelCountMode.explicit else { return node.channelCount }
        
        for i in 0..<numberOfConnections {
            guard let output = renderingOutput(lock: &lock, i: i) else { continue }
            maxChannels = max(maxChannels, output.bus(lock: &lock).numberOfChannels)
        }
        
        if mode == ChannelCountMode.clampedMax {
            maxChannels = min(maxChannels, node.channelCount)
        }
        
        return maxChannels
    }
    
    deinit {
        print("log.io.deinit.\(debugDescription)")
    }
    
}
