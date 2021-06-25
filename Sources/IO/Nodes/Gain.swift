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

open class GainNode: AudioNode {
    
    public var gain: AudioParam
    
    private var lastGain: Float = 0
    private var sampleAccurateGainValues: AudioArray<Scalar>
    
    public var gainValue: Float {
        return lastGain
    }
    
    /// Call this method to initialize the gain node
    ///
    /// - parameter defaultGain: A floatValue for the initial gain
    public init(defaultGain: Float = 1.0) {
        gain = AudioParam(name: "gain", defaultValue: defaultGain, minValue: 0, maxValue: 10000.0)
        sampleAccurateGainValues = AudioArray<Scalar>(size: AudioNode.processingSizeInFrames)
        super.init()
        addInput(input: AudioNodeInput(audioNode:self))
        addOutput(output: AudioNodeOutput(audioNode: self, numberOfChannels: 2))
        params.append(gain)
        print("log.io.init.\(debugDescription))")
        initialize()
    }
    
    /// Call this method to process the given node
    ///
    /// - parameter lock: An inout render lock
    /// - parameter framesToProcess: A frame amount to process
    public override func process(lock: inout ContextRenderLock, framesToProcess: Int) {
        guard let input = input(index: 0) else { return }
        guard let outputBus = output(index: 0)?.bus(lock: &lock) else { return }
        
        if !isInitialized || !input.isConnected {
            outputBus.zero()
        }
        else {
            guard let inputBus = input.bus(lock: &lock) else { return }
            if gain.hasSampleAccurateValues() {
                if framesToProcess <= sampleAccurateGainValues.size {
                    var gainValues = sampleAccurateGainValues.pointer
                    gain.calculateSampleAccurateValues(lock: &lock, values: &gainValues, numberOfValues: framesToProcess)
                    outputBus.copyWithSampleAccurateGainValues(from: inputBus, gainValues: gainValues, numberOfGainValues: framesToProcess)
                }
            }
            else {
                let targetGain = gain.value(lock: &lock)
                outputBus.copyWithGain(from: inputBus, lastMixGain: &lastGain, targetGain: targetGain)
            }
        }
    }
    
    /// Call this method to check number of channels for input
    ///
    /// - parameter lock: Any context render lock
    /// - parameter input: An audio node input
    public override func checkNumberOfChannelsForInput(lock: inout ContextRenderLock, input: AudioNodeInput?) {
        guard let input = input else { return }
        guard let current = self.input(index: 0), current.uuid == input.uuid else { return }
        
        let numberOfChannels = input.numberOfChannels(lock: &lock)
        
        if let output = output(index: 0), output.numberOfChannels != numberOfChannels && isInitialized { uninitialize() }
        
        if !isInitialized {
            output(index: 0)?.setNumberOfChannels(lock: &lock, numberOfChannels: numberOfChannels)
            initialize()
        }
        
        super.checkNumberOfChannelsForInput(lock: &lock, input: input)
    }
    
    /// Called to get the current node tail time
    ///
    /// - parameter lock: A given context render lock
    /// - returns: A floatValue that indicates the tail time
    public override func tailTime(lock: inout ContextRenderLock) -> TimeInterval {
        return AudioNode.zero
    }
    
    /// Called to get the current node latency time
    ///
    /// - parameter lock: A given context render lock
    /// - returns: A floatValue that indicates the latency time
    public override func latencyTime(lock: inout ContextRenderLock) -> TimeInterval {
        return AudioNode.zero
    }
    
    /// Call this method to reset the current node
    ///
    /// - parameter lock: A given context render lock
    public override func reset(lock: inout ContextRenderLock) {
        print("log.io.reset.\(debugDescription))")
        lastGain = gain.value(lock: &lock)
    }

    deinit {
        uninitialize()
        print("log.io.deinit.\(debugDescription))")
    }
}
