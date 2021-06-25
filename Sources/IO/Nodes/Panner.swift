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

public enum PanningMode: Int {
    case none = 0
    case equalPower
    case hrtf
}

//MARK:

public class PannerNode: AudioNode {
    
    public var pan: AudioParam
    
    private var stereoPanner: Panner
    private var sampleAccuratePanValues: AudioArray<Scalar>
    
    class Panner: NSObject {
        
        private var samplerate: Int = 0
        private var smoothingTimeConstant: Float = 0.050
        private var panningMode: PanningMode?
        private var isFirstRender: Bool = true
        private var pan: Float = 0
        
        static let smoothingTimeConstant: Float = 0.050
        
        /// Call this method to initialize the panner
        ///
        /// - parameter sampleRate: A given sample rate
        /// - parameter model: A selected panning mode
        init(sampleRate: Int, model: PanningMode) {
            smoothingTimeConstant = AudioUtilities.discreteTimeConstantForSampleRate(
                timeConstant: Panner.smoothingTimeConstant, sampleRate: sampleRate)
            panningMode = model
            super.init()
        }
        
        /// Call this method to pan current with value
        ///
        /// - parameter input: An input audio bus
        /// - parameter output: An output audio bus
        /// - parameter value: A value
        /// - parameter framesToProcess: An amout of samples to process
        public func panToTargetValue(input: AudioBus, output: AudioBus, value: Float, framesToProcess: Int) {
            
            let numberOfInputChannels = input.numberOfChannels
            let isInputStereo = input.numberOfChannels == Channels.stereo.rawValue
            let isInputSafe = input.numberOfChannels == Channels.mono.rawValue
                || isInputStereo && framesToProcess <= input.length
            let isOutputStereo = output.numberOfChannels == Channels.stereo.rawValue
            let isOutputSafe = output.numberOfChannels == Channels.mono.rawValue
                || isOutputStereo && framesToProcess <= output.length
            
            guard isInputSafe, isOutputSafe else { return }
            guard let sourceL = input.channel(index: 0)?.data() else { return }
            guard let sourceR = numberOfInputChannels > Channels.mono.rawValue
                    ? input.channel(index: 1)?.data() : sourceL else { return }
            guard let destinationL = output.channel(kind: .left)?.data() else { return }
            guard let destinationR = output.channel(kind: .right)?.data() else { return }
            
            let targetPan = AudioUtilities.clamp(value: value, to: -1, to: 1)
            
            if isFirstRender {
                isFirstRender = false
                pan = targetPan
            }
            
            var gainL: Float = 0
            var gainR: Float = 0
            var panRadian: Float = 0
            
            let smoothingConstant = smoothingTimeConstant

            if numberOfInputChannels == Channels.mono.rawValue {
                
                var index = 0
                while index < framesToProcess {
                    
                    let inputL = sourceL.advanced(by: index).pointee
                    
                    pan += (targetPan - pan) * smoothingConstant
                    
                    panRadian = (pan * 0.5 + 0.5) * Float(Double.pi / 2)
                    
                    gainL = cos(panRadian)
                    gainR = sin(panRadian)
                    
                    destinationL.advanced(by: index).pointee = Scalar(Float(inputL) * gainL)
                    destinationR.advanced(by: index).pointee = Scalar(Float(inputL) * gainR)
                    
                    index += 1
                }
            }
            else {
                
                var index = 0
                while index < framesToProcess {
                    
                    let inputL = sourceL.advanced(by: index).pointee
                    let inputR = sourceR.advanced(by: index).pointee
                    
                    pan += (targetPan - pan) * smoothingConstant;
                    panRadian = (pan <= 0 ? pan + 1 : pan) * Float(Double.pi / 2)
                    
                    gainL = cos(panRadian)
                    gainR = sin(panRadian)
                    
                    if pan <= 0 {
                        destinationL.advanced(by: index).pointee = Scalar(inputL + inputR * gainL)
                        destinationR.advanced(by: index).pointee = Scalar(Float(inputR) * gainR)
                    }
                    else {
                        destinationL.advanced(by: index).pointee = Scalar(Float(inputL) * gainL)
                        destinationR.advanced(by: index).pointee = Scalar(inputL + inputR * gainR)
                    }
                    
                    index += 1
                }
                
            }
        }
        
        deinit {
            print("log.io.deinit.\(debugDescription)")
        }
        
    }

    
    /// Call this method to initialize a panner node
    ///
    /// - parameter sampleRate: An intValue for the sample rate
    public init(sampleRate: Int) {
        pan = AudioParam(name: "pan", defaultValue: 0.5, minValue: -1, maxValue: 1)
        sampleAccuratePanValues = AudioArray<Scalar>(size: AudioNode.processingSizeInFrames)
        stereoPanner = Panner(sampleRate: sampleRate, model: .equalPower)
        
        super.init()
        
        addInput(input: AudioNodeInput(audioNode: self))
        addOutput(output: AudioNodeOutput(audioNode: self, numberOfChannels: 2))
        
        params.append(pan)
        
        print("log.io.init.\(debugDescription))")
        initialize()
    }
    
    /// Call this method to initialize
    public override func initialize() {
        super.initialize()
    }
    
    /// Call this method to process the given node
    ///
    /// - parameter lock: An inout render lock
    /// - parameter framesToProcess: A frame amount to process
    public override func process(lock: inout ContextRenderLock, framesToProcess: Int) {
        guard let output = output(index: 0)?.bus(lock: &lock) else { return }
        guard isInitialized, let input = input(index: 0), input.isConnected else { return output.zero() }
        
        guard let inputBus = input.bus(lock: &lock) else { return }
        stereoPanner.panToTargetValue(input: inputBus, output: output, value: pan.value(lock: &lock), framesToProcess: framesToProcess)
    }
    
    /// Called to get the current node tail time
    ///
    /// - parameter lock: A given context render lock
    /// - returns: A floatValue that indicates the tail
    public override func tailTime(lock: inout ContextRenderLock) -> TimeInterval {
        return AudioNode.zero
    }
    
    /// Called to get the current node latency time
    ///
    /// - parameter lock: A given context render lock
    /// - returns: A floatValue that indicates the latency
    public override func latencyTime(lock: inout ContextRenderLock) -> TimeInterval {
        return AudioNode.zero
    }
    
    /// Call this method to reset the current node
    ///
    /// - parameter lock: A given context render lock
    public override func reset(lock: inout ContextRenderLock) {
        print("log.io.reset.\(debugDescription))")
    }
    
    /// Call this method to initialize
    public override func uninitialize() {
        super.uninitialize()
    }
    
    deinit {
        uninitialize()
        print("log.io.deinit.\(debugDescription))")
    }
    
}
