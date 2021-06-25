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

public class AudioParam: AudioSummingJunction {
    
    var uuid: UUID = UUID()
    
    static let snapThreashold: Float = 0
    static let defaultSmoothingConstant: Float = 0
    
    public struct AudioParamData {
        public var internalSummingBus: AudioBus?
    }
    
    public var name: String
    public var minValue: Float
    public var maxValue: Float = 1.0
    public var defaultValue: Float
    public var units: Int
    public var smoothedValue: Float = 0
    public var data: AudioParamData
    
    private var internalValue: Float
    private var timeline = AudioParamsTimeline()
    private var smoothingConstant: Float = 0
    
    /// Call this method to initialize a current param
    ///
    /// - parameter name: A stringValue for the name
    /// - parameter defaultValue: A default floatValue
    /// - parameter minValue: A minValue
    /// - parameter maxValue: A maxValue
    /// - parameter units: A intValue to specify units
    init(
        name: String,
        defaultValue: Float,
        minValue: Float,
        maxValue: Float,
        units: Int = 0) {
        self.name = name
        self.internalValue = defaultValue
        self.minValue = minValue
        self.units = units
        self.defaultValue = defaultValue
        self.maxValue = maxValue
        self.smoothedValue = defaultValue
        self.smoothingConstant = AudioParam.defaultSmoothingConstant
        self.data = AudioParamData()
        super.init()
    }
    
    /// Call this method to get the current value of the param
    ///
    /// - parameter lock: A given context render lock
    /// - returns: A current floatValue after evaluating timeline
    public func value(lock: inout ContextRenderLock) -> Float {
        var hasValue: Bool = false
        let timelineValue = timeline.valueForContextTime(lock: &lock, defaultValue: internalValue, hasValues: &hasValue)
        guard hasValue else { return internalValue }
        internalValue = timelineValue
        return internalValue
    }
    
    /// Call this method to set a floatValue to the current param
    ///
    /// - parameter value: A floatValue for the current param
    public func setValue(value: Float) {
        self.internalValue = value
    }
    
    /// Call this method to set a valueAtTime
    ///
    /// - parameter value: A value to be configured
    /// - parameter time: A given time for the timeline
    public func cancelScheduledValues(startTime: TimeInterval) {
        timeline.cancelScheduledValues(startTime: startTime)
    }
    
    /// Call this method to know if the current param has accurate values
    ///
    /// - returns: A boolValue that indicates if the timeline was configured
    public func hasSampleAccurateValues() -> Bool {
        return timeline.hasValues || numberOfConnections() > 0
    }
    
    /// Call this method to calculate the final values
    ///
    /// - parameter lock: A given context render lock
    /// - parameter values: A given buffer with values
    /// - parameter numberOfValues: A given numberOfValues
    /// - parameter sampleAccurate: A boolValue to know if has sample accurate values
    public func calculateSampleAccurateValues(
        lock: inout ContextRenderLock,
        values: inout UnsafeMutablePointer<Scalar>, numberOfValues: Int) {
        guard numberOfValues > 0 else { return }
        
        calculateTimelineValues(lock: &lock, values: &values, numberOfValues: numberOfValues)
        
        updateRenderingState(lock: &lock)
        
        let connectionCount = numberOfRenderingConnections(lock: &lock)
        guard connectionCount > 0 else { return }
        
        if data.internalSummingBus != nil && data.internalSummingBus!.length < numberOfValues {
            data.internalSummingBus!.reset()
        }
        
        if data.internalSummingBus == nil {
            data.internalSummingBus = AudioBus(numberOfChannels: 1, lenght: numberOfValues)
        }

        data.internalSummingBus?.channel(index: 0)?.copy(from: values, lenght: numberOfValues)
        
        for i in 0..<connectionCount {
            let output = renderingOutput(lock: &lock, i: i)
            let framesToProcess = AudioNode.processingSizeInFrames
            guard let bus = output?.pull(lock: &lock, inPlaceBus: nil, framesToProcess: framesToProcess) else { continue }
            data.internalSummingBus?.sum(from: bus)
        }
        
    }
    
    /// Call this method to calculate the timeline values
    ///
    /// - parameter lock: A given context render lock
    /// - parameter values: A given buffer with values
    /// - parameter numberOfValues: A given numberOfValues
    private func calculateTimelineValues(
        lock: inout ContextRenderLock,
        values: inout UnsafeMutablePointer<Scalar>, numberOfValues: Int) {
        
        let sampleRate = lock.context.sampleRate
        let startTime = lock.context.currentTime
        let endTime = startTime + Double(numberOfValues) / Double(sampleRate)
        
        let timeRange = AudioParamsTimeline.TimeRange(startTime: startTime, endTime: endTime)
        internalValue = timeline.valuesForTimeRange(
            timeRange: timeRange,
            defaultValue: internalValue,
            value: &values,
            numberOfValues: numberOfValues,
            sampleRate: sampleRate,
            controlRate: sampleRate)
    }
    
    deinit {
        print("log.graph.deinit.\(debugDescription)")
    }
    
}

extension AudioParam {
    
    /// Call this method to connect an audio param to output
    ///
    /// - parameter lock: A given context render lock
    /// - parameter param: A given audio param
    /// - parameter output: A given audio node output
    static func connect(lock: inout ContextGraphLock, param: AudioParam, output: AudioNodeOutput?) {
        guard let output = output else { return }
        guard param.isConnected(output: output) else { return }
        param.junctionConnectOutput(output: output)
        output.addParam(lock: &lock, param: param)
    }
    
    /// Call this method to disconnect all from param
    ///
    /// - parameter lock: A given context render lock
    /// - parameter param: A given audio param
    static func disconnectAll(lock: inout ContextGraphLock, param: AudioParam) {
        param.connectedOutputs.forEach { $0.removeParam(lock: &lock, param: param)}
        param.junctionDisconnectAllOutputs()
    }
    
    /// Call this method to disconnect an audio param to output
    ///
    /// - parameter lock: A given context render lock
    /// - parameter param: A given audio param
    /// - parameter output: A given audio node output
    public func disconnect(lock: inout ContextGraphLock, param: AudioParam, output: AudioNodeOutput?) {
        guard let output = output else { return }
        if param.isConnected(output: output) { param.junctionDisconnectOutput(output: output) }
        output.removeParam(lock: &lock, param: param)
    }
    
}

extension AudioParam {
    
    /// Call this method to set a valueAtTime
    ///
    /// - parameter value: A value to be configured
    /// - parameter time: A given time for the timeline
    public func setValueAtTime(value: Float, time: TimeInterval) {
        try? timeline.setValueAtTime(value: value, time: time)
    }
    
    /// Call this method to set a linear ramp to value
    ///
    /// - parameter value: A value to be configured
    /// - parameter time: A given time for the timeline
    public func linearRampToValueAtTime(value: Float, time: TimeInterval) {
        try? timeline.linearRampToValueAtTime(value: value, time: time)
    }
    
    /// Call this method to set an exponential ramp to value
    ///
    /// - parameter value: A value to be configured
    /// - parameter time: A given time for the timeline
    public func exponentialRampToValueAtTime(value: Float, time: TimeInterval) {
        try? timeline.exponentialRampToValueAtTime(value: value, time: time)
    }
    
}
