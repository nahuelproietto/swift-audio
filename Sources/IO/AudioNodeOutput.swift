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

public class AudioNodeOutput: NSObject {
    
    var uuid: UUID = UUID()
    
    public var node : AudioNode
    
    public var numberOfChannels: Int = 0
    public var desiredNumberOfChannels: Int = 0
    public var renderingFanOutCount: Int = 0
    
    private var inPlaceBus: AudioBus?
    private var internalBus: AudioBus
    private var inputs: [AudioNodeInput] = [AudioNodeInput]()
    private var params: [AudioParam] = [AudioParam]() // TODO: adopt hashable and convert to set
    
    private var renderingParamFanOutCount: Int = 0
    
    /// Call this method to initialize the audio node output
    ///
    /// - parameter audioNode: A reference to the audio node
    /// - parameter processingSizeInFrame: The processing size for the audio input
    init(audioNode: AudioNode, numberOfChannels: Int, processingSizeInFrames: Int = AudioNode.processingSizeInFrames) {
        self.node = audioNode
        self.numberOfChannels = numberOfChannels
        self.desiredNumberOfChannels = numberOfChannels
        self.renderingFanOutCount = 0
        self.renderingParamFanOutCount = 0
        internalBus = AudioBus(numberOfChannels: numberOfChannels, lenght: processingSizeInFrames)
        super.init()
    }
    
    /// Call this method to pull samples
    ///
    /// - parameter lock: A given context render lock
    /// - parameter inPlaceBus: A given audio bus to place samples
    /// - parameter framesToProcess: A given number of frames to process
    @discardableResult
    public func pull(lock: inout ContextRenderLock, inPlaceBus: AudioBus?, framesToProcess: Int) -> AudioBus {
        updateRenderingState(lock: &lock)
        
        let inPlaceBusIsNotNil = inPlaceBus != nil
        let inPlaceBusNumberOfChannelsIsEqual = inPlaceBusIsNotNil ? inPlaceBus!.numberOfChannels == numberOfChannels : false
        let useInPlaceBus = inPlaceBusNumberOfChannelsIsEqual && (renderingFanOutCount + renderingParamFanOutCount == 1)
        
        self.inPlaceBus = useInPlaceBus ? inPlaceBus : nil
        node.processIfNecessary(lock: &lock, framesToProcess: framesToProcess)
        
        return bus(lock: &lock)
    }
    
    /// Call this method to get the current bus for the audio node output
    ///
    /// - parameter lock: A given context render lock
    /// - returns: A optional audio bus
    public func bus(lock: inout ContextRenderLock) -> AudioBus {
        return inPlaceBus != nil ? inPlaceBus! : internalBus
    }
    
    /// Call this method to set the number of channels of the audio node output
    ///
    /// - parameter lock: A given context render lock
    /// - parameter numberOfChannels: A current number of channels
    public func setNumberOfChannels(lock: inout ContextRenderLock, numberOfChannels: Int) {
        guard numberOfChannels != numberOfChannels else { return }
        desiredNumberOfChannels = numberOfChannels
        internalBus = AudioBus(numberOfChannels: numberOfChannels, lenght: AudioNode.processingSizeInFrames)
    }
    
    /// Call this method to add an input to the current audio node output
    ///
    /// - parameter lock: A given context render lock
    /// - parameter input: A given audio node input
    public func addInput(lock: inout ContextGraphLock, input: AudioNodeInput) {
        inputs.append(input)
        input.setDirty()
    }
    
    /// Call this method to remove an input to the current audio node output
    ///
    /// - parameter lock: A given context render lock
    /// - parameter input: A given audio node input
    public func removeInput(lock: inout ContextGraphLock, input: AudioNodeInput) {
        guard let firstIndex = inputs.firstIndex(where: { $0.uuid == input.uuid }) else { return }
        let input = inputs[firstIndex]
        input.setDirty()
        inputs.remove(at: firstIndex)
    }
    
    /// Call this method to update the internal bus from the audio node output
    private func updateInternalBus() {
        guard numberOfChannels != internalBus.numberOfChannels else { return }
        internalBus = AudioBus(numberOfChannels: numberOfChannels, lenght: AudioNode.processingSizeInFrames)
    }
    
    /// Call this method to update the rendering state
    ///
    /// - parameter lock: A given context render lock
    public func updateRenderingState(lock: inout ContextRenderLock) {
        if numberOfChannels != desiredNumberOfChannels {
            numberOfChannels = desiredNumberOfChannels
            updateInternalBus()
            propagateChannelCount(lock: &lock)
        }
        renderingFanOutCount = fanOutCount()
        renderingParamFanOutCount = paramFanCount()
    }
    
    /// Call this method to propagate channel count changed
    ///
    /// - parameter lock: A given context render lock
    private func propagateChannelCount(lock: inout ContextRenderLock) {
        if isChannelCountKnown() {
            for (_, e) in inputs.enumerated() {
                let connectionNode = e.node
                connectionNode.checkNumberOfChannelsForInput(lock: &lock, input: e)
            }
        }
    }
    
    deinit {
        print("log.io.deinit.\(debugDescription)")
    }
    
}

extension AudioNodeOutput {
    
    
    /// Call this method to know if audio node output is connected
    ///
    /// - returns: A boolValue that indicates if this audio node output is connected
    public func isConnected() -> Bool {
        return fanOutCount() > 0 || paramFanCount() > 0
    }
    
    /// Call this method to know if channel count is known
    ///
    /// - returns: A boolValue that indicates if the number of channels is known
    public func isChannelCountKnown() -> Bool {
        return numberOfChannels > 0
    }
    
    /// Call this method to add a given param
    ///
    /// - parameter lock: A given context render lock
    /// - parameter param: A given param to be connected
    public func addParam(lock: inout ContextGraphLock, param: AudioParam) {
        params.append(param)
    }
    
    /// Call this method to remove a given param
    ///
    /// - parameter lock: A given context render lock
    /// - parameter param: A given param to be connected
    public func removeParam(lock: inout ContextGraphLock, param: AudioParam) {
        guard let firstIndex = params.firstIndex(where: { $0.uuid == param.uuid }) else { return }
        params.remove(at: firstIndex)
    }
    
    /// Call this method to get the fan out count
    ///
    /// - returns: A given number of inputs
    private func fanOutCount() -> Int {
        return inputs.count
    }
    
    /// Call this method to get the param fan count
    ///
    /// - returns: A given number of params
    private func paramFanCount() -> Int {
        return params.count
    }
    
}
