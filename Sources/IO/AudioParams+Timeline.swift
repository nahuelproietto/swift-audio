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

class AudioParamsTimeline: NSObject {
    
    public var events: [AudioScheduledEvent] = []
    public var hasValues: Bool { return events.count > 0 }
    
    internal var mutex = UnsafeMutex()
    
    struct AudioScheduledEvent: Equatable {
        
        var kind: AudioScheduledEventKind
        var parameters: AudioScheduledParameters
        
        struct AudioScheduledParameters {
            var value: Float
            var time: TimeInterval
            var timeConstant: Float
            var duration: TimeInterval
            var curve: [Float]
        }
        
        static let defaultValue: Float = 0.0
        
        enum AudioScheduledEventKind: Int {
            case setValue = 0
            case linerRampToValue = 1
            case exponentialRampToValue = 2
            case lastType = 3
        }
        
        /// Call this method to initialize the scheduled event
        ///
        /// - parameter kind: A given kind of the event
        /// - parameter parameters: A wrapper for parameters
        public init(
            kind: AudioScheduledEventKind,
            parameters: AudioScheduledParameters) {
            self.parameters = parameters
            self.kind = kind
        }
        
        /// Call this method to compare any event
        ///
        /// - parameter lhs: An input bus
        /// - parameter rhs: Anothe bus to compare
        /// - returns: A boolValue that indicates if equals
        public static func ==(lhs: AudioScheduledEvent, rhs: AudioScheduledEvent) -> Bool {
            return lhs.parameters.time == rhs.parameters.time
                && lhs.kind == rhs.kind
        }
        
    }
    
    struct TimeRange {
        var startTime: TimeInterval
        var endTime: TimeInterval
    }
    
    enum AudioParamError: Swift.Error {
        case custom(String)
    }
    
    deinit {
        print("log.io.deinit.\(debugDescription)")
    }

}

extension AudioParamsTimeline {
    
    /// Call this method to set value at time
    ///
    /// - parameter value: A floatValue
    /// - parameter time: A floatValue that represent the time
    public func setValueAtTime(value: Float, time: TimeInterval) throws {
        typealias Parameters = AudioScheduledEvent.AudioScheduledParameters
        let parameters = Parameters(value: value, time: time, timeConstant: 0, duration: 0, curve: [])
        let event = AudioScheduledEvent(kind: .setValue, parameters: parameters)
        try insertEvent(event: event)
    }
    
    /// Call this method to set value at time
    ///
    /// - parameter value: A floatValue
    /// - parameter time: A floatValue that represent the time
    public func linearRampToValueAtTime(value: Float, time: TimeInterval) throws {
        typealias Parameters = AudioScheduledEvent.AudioScheduledParameters
        let parameters = Parameters(value: value, time: time, timeConstant: 0, duration: 0, curve: [])
        let event = AudioScheduledEvent(kind: .linerRampToValue, parameters: parameters)
        try insertEvent(event: event)
    }
    
    /// Call this method to set value at time
    ///
    /// - parameter value: A floatValue
    /// - parameter time: A floatValue that represent the time
    public func exponentialRampToValueAtTime(value: Float, time: TimeInterval) throws {
        typealias Parameters = AudioScheduledEvent.AudioScheduledParameters
        let parameters = Parameters(value: value, time: time, timeConstant: 0, duration: 0, curve: [])
        let event = AudioScheduledEvent(kind: .exponentialRampToValue, parameters: parameters)
        try insertEvent(event: event)
    }
    
}

extension AudioParamsTimeline {
    
    /// Call this method to insert some event in timeline
    ///
    /// - parameter event: A given scheduled event
    private func insertEvent(event: AudioScheduledEvent) throws {
        defer { mutex.unlock() }; mutex.lock();
        let lastType = AudioScheduledEvent.AudioScheduledEventKind.lastType.rawValue
        guard event.kind.rawValue < lastType && event.parameters.duration >= 0 else { return }
        
        guard let firstIndex = events.firstIndex(of: event) else {
            let time = event.parameters.time
            guard let middleIndex = events.firstIndex(where: { $0.parameters.time >= time }) else {
                return events.append(event)
            }
            return events.insert(event, at: middleIndex)
        }
        
        events[firstIndex] = event
    }
    
    /// Call this method to cancel an scheduled value on given startTime
    ///
    /// - parameter startTime: A given startTime
    public func cancelScheduledValues(startTime: TimeInterval) {
        defer { mutex.unlock() }; mutex.lock();
        for (index,event) in events.enumerated() {
            if event.parameters.time >= startTime { events.remove(at: index) }
        }
    }
    
}

extension AudioParamsTimeline {
    
    /// Call this method to get values for context time
    ///
    /// - parameter lock: A given context render lock
    /// - parameter defaultValue: A floatValue to configure as default
    /// - parameter hasValue: A inout bool to know if has values
    /// - returns: A floatValue
    public func valueForContextTime(
        lock: inout ContextRenderLock, defaultValue: Float, hasValues: inout Bool) -> Float {
        mutex.lock();
        
        if let event = events.first, lock.context.currentTime < event.parameters.time || events.isEmpty {
            hasValues = false; mutex.unlock()
            return defaultValue
        }
        
        let sampleRate: Int = lock.context.sampleRate
        let startTime: TimeInterval = lock.context.currentTime
        let endTime: TimeInterval = startTime + 1.1 / Double(sampleRate)
        let controlRate: Float = Float(sampleRate) / Float(AudioNode.processingSizeInFrames)
        
        var value = UnsafeMutablePointer<Scalar>.allocate(capacity: 1)
        value.pointee = 0
        
        let timeRange = TimeRange(startTime: startTime, endTime: endTime)
        mutex.unlock()
        
        let retval = valuesForTimeRange(
            timeRange: timeRange,
            defaultValue: defaultValue,
            value: &value,
            numberOfValues: 1,
            sampleRate: sampleRate,
            controlRate: Int(controlRate))
        
        hasValues = true
        value.deallocate()
        
        return retval
    }
    
    /// Call this method to get values for a time range
    ///
    /// - parameter timeRange: A given timeRange
    /// - parameter defaultValue: A floatValue to configure as default
    /// - parameter value: A mutable pointer to store the value
    /// - parameter numberOfValues: A number of values
    /// - parameter sampleRate: A given sample rate
    /// - parameter controlRate: A given control rate
    public func valuesForTimeRange(
        timeRange: TimeRange,
        defaultValue: Float,
        value: inout UnsafeMutablePointer<Scalar>,
        numberOfValues: Int,
        sampleRate: Int,
        controlRate: Int) -> Float {
        defer { mutex.unlock() }; mutex.lock();
        
        guard numberOfValues > 0, !events.isEmpty else { return defaultValue }
        guard let firstEvent = events.first else { return defaultValue }
        
        guard timeRange.endTime > firstEvent.parameters.time else {
            for i in 0..<numberOfValues { value[i] = Scalar(defaultValue) }
            return defaultValue
        }
        
        var writeIndex = 0
        let firstEventTime = firstEvent.parameters.time
        
        var currentTime = timeRange.startTime
        
        if firstEventTime > timeRange.startTime {
            let fillToTIme = min(timeRange.endTime, firstEventTime)
            let fillToFrame = AudioUtilities.timeToSampleFrame(time: fillToTIme - timeRange.startTime, sampleRate: sampleRate)
            for i in writeIndex..<fillToFrame { value[i] = Scalar(defaultValue); writeIndex += 1 }
            currentTime = fillToTIme
        }
        
        var newValue = defaultValue
        
        let n = events.count
        
        for i in 0..<n {
            
            let event = events[i]
            let nextEvent = i < n - 1 ? events[i+1] : nil
            
            guard writeIndex < numberOfValues else { continue }
            if let e = nextEvent, e.parameters.time < currentTime { continue }
            
            let value1 = event.parameters.value
            let time1 = event.parameters.time
            let value2 = nextEvent?.parameters.value ?? value1
            let time2 = nextEvent?.parameters.time ?? timeRange.endTime + 1
            
            let deltaTime = time2 - time1
            let k = deltaTime > 0 ? 1 / deltaTime : 0
            let sampleFrameTimeIncr = 1 / sampleRate
            
            let fillToTime = min(timeRange.endTime, time2)
            let fillToTimeDiff = fillToTime - timeRange.startTime
            var fillToFrame = AudioUtilities.timeToSampleFrame(time: fillToTimeDiff, sampleRate: sampleRate)
            
            fillToFrame = min(fillToFrame, numberOfValues)
            
            let nextEventType: AudioScheduledEvent.AudioScheduledEventKind = nextEvent?.kind ?? .lastType
            
            if nextEventType == .linerRampToValue {
                for i in writeIndex..<fillToFrame {
                    let x: Float = Float(currentTime - time1) * Float(k)
                    newValue = (1 - x) * value1 + x * value2
                    value[i] = Scalar(newValue)
                    currentTime += Double(sampleFrameTimeIncr)
                    writeIndex += 1
                }
            }
            else if (nextEventType == .exponentialRampToValue) {
                
                if value1 <= 0 || value2 <= 0 {
                    for i in writeIndex..<fillToFrame { value[i] = Scalar(newValue); writeIndex += 1 }
                }
                else {
                    let numSamplesFrames = deltaTime * Double(sampleRate)
                    let multiplier = powf(value2 / value1, 1 / Float(numSamplesFrames))
                    let currentTimeDiff = currentTime - time1
                    let timeToSampleFrame = AudioUtilities
                        .timeToSampleFrame(time: currentTimeDiff, sampleRate: sampleRate)
                    newValue = value1 * powf(value2 / value1, Float(timeToSampleFrame) / Float(numSamplesFrames))
                    
                    for i in writeIndex..<fillToFrame {
                        value[i] = Scalar(newValue)
                        newValue *= multiplier
                        currentTime += TimeInterval(sampleFrameTimeIncr)
                        writeIndex += 1
                    }
                }
                
            } else {
                
                switch event.kind {
                case .setValue:
                    fallthrough
                case .linerRampToValue:
                    fallthrough
                case .exponentialRampToValue:
                    currentTime = fillToTime
                    newValue = event.parameters.value
                    for i in writeIndex..<fillToFrame {
                        value[i] = Scalar(newValue)
                        writeIndex += 1
                    }
                default:
                    break
                }
            }
        }
        
        for i in writeIndex..<numberOfValues {
            value[i] = Scalar(newValue)
        }
        
        return newValue
    }
    
}
