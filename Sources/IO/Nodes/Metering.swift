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

public class MeteringNode: AudioBasicInspectorNode {
    
    public var db: Float { _db }
    public var windowSize: Int { _windowSize.intValue }
    
    private var _db: Float = 0
    private var _windowSize: AudioSetting
    
    /// Called to initialize the metering node
    ///
    /// - parameter outputChannelCount: An intValue
    public override init(outputChannelCount: Int) {
        _windowSize = AudioSetting(name: "windowSize")
        _windowSize.intValue = 128
        
        super.init(outputChannelCount: outputChannelCount)
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
        
        guard let input = input(index: 0), let output = output(index: 0) else { return }
        guard let inputBus = input.bus(lock: &lock) else { return }
        
        let outputBus = output.bus(lock: &lock)
        
        guard isInitialized, input.isConnected else { return outputBus.zero() }
        guard let channel = inputBus.channel(index: 0) else { return outputBus.zero() }
        guard inputBus.numberOfChannels > 0 && channel.length >= framesToProcess else { return outputBus.zero() }
        
        let numberOfChannels = inputBus.numberOfChannels
        
        var channels: [AudioChannel] = []
        
        for i in 0..<inputBus.numberOfChannels {
            guard let channel = inputBus.channel(index: i) else { continue }
            channels.append(channel)
        }
        
        var start = framesToProcess - _windowSize.intValue
        let end = framesToProcess
        
        if start < 0 { start = 0 }
        
        var power: Double = 0
        
        for i in 0..<numberOfChannels {
            for j in start..<end {
                let p = Double(channels[i].data().advanced(by: j).pointee)
                if !p.isInfinite && !p.isNaN {
                    let doubleValue = p * p
                    power += doubleValue
                }
            }
        }
        
        let min: Double = 0.000125
        
        if power.isInfinite || power.isNaN || power < min {
            power = min
        }
        
        let rms = sqrt(power / Double((numberOfChannels * framesToProcess)))
        
        _db = 20.0 * log10(Float(rms))
        
        if input.uuid != outputBus.uuid {
            outputBus.copy(from: inputBus)
        }
        
    }
    
    /// Called to set the window size
    ///
    /// - parameter value: An intValue
    public func setWindowSize(value: Int) {
        _windowSize.intValue = value
    }
    
    /// Call this method to reset the current node
    ///
    /// - parameter lock: A given context render lock
    public override func reset(lock: inout ContextRenderLock) {
        print("log.io.reset.\(debugDescription))")
        _db = 0
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
    
    /// Call this method to initialize
    public override func uninitialize() {
        super.uninitialize()
    }
    
    deinit {
        uninitialize()
        print("log.io.deinit.\(debugDescription))")
    }
    
}
