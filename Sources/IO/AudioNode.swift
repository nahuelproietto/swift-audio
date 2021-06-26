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

public typealias NodeCompletion = () -> ()

open class AudioNode: NSObject {
    
    public var uuid = UUID()
    
    static let processingSizeInFrames: Int = 128
    
    public internal(set) var numberOfInputs: Int = 0
    public internal(set) var numberOfOutputs: Int = 0
    public internal(set) var channelCount: Int = 0
    public internal(set) var channelCountMode: ChannelCountMode = .max
    public internal(set) var channelIntepretation: ChannelInterpretation = .speakers
    
    public private(set) var isInitialized: Bool = false
    
    internal var params: [AudioParam] = []
    internal var settings: [AudioSetting] = []
    internal var outputs: [AudioNodeOutput] = []
    internal var inputs: [AudioNodeInput] = []
    
    internal var lastProcessingTime: TimeInterval = -1.0
    internal var lastNonSilentTime: TimeInterval = -1.0
    
    internal static let zero: TimeInterval = 0.0
    
    private var sampleRate: Float = 0.0
    private var audibleThreashold: Float = 0.05
    private var disconnectSchedule: Float = 1
    private var connectSchedule: Float = 1
    
    open var isScheduledNode: Bool {
        return false
    }
    
    public var isConnectionReady: Bool {
        connectSchedule > (1 - audibleThreashold)
    }
    
    public var isDisconnectionReady: Bool {
        return disconnectSchedule >= 0 && disconnectSchedule <= audibleThreashold
    }
    
    enum AudioNodeError: Swift.Error {
        case custom(String)
    }
    
    /// Call this method to initialize an audio node
    /// Use this function on subclasses to call the initialize function
    public override init() {
        super.init()
        self.initialize()
    }
    
    /// Call this method to initialize the audio node
    /// Use this method to set the initialized boolean to true
    public func initialize() {
        print("log.node.initialized.\(debugDescription)")
        isInitialized = true
    }
    
    /// Call this method to pull inputs from node
    ///
    /// - parameter lock: A given context render lock
    /// - parameter framesToProcess: An amount of frames to be processed
    public func pullInputs(lock: inout ContextRenderLock, framesToProcess: Int) {
        inputs.forEach { $0.pull(lock: &lock, inPlaceBus: nil, framesToProcess: framesToProcess) }
    }
    
    /// Call this method to update all the channels for inputs
    ///
    /// - parameter lock: A given context render lock
    private func updateChannelsForInputs(lock: inout ContextGraphLock) {
        inputs.forEach { $0.changedOutputs(lock: &lock) }
    }
    
    /// Call this method to check the number of channels for a given input
    ///
    /// - parameter lock: A given context render lock
    /// - parameter input: A given audio node input to be compared
    public func checkNumberOfChannelsForInput(lock: inout ContextRenderLock, input: AudioNodeInput) {
        inputs.filter { $0.uuid == input.uuid }.forEach { $0.updateInternalBus(lock: &lock) }
    }
    
    /// Call this method to silence every ouput of the node
    ///
    /// - parameter lock: A given context render lock
    public func silenceOutputs(lock: inout ContextRenderLock) {
        outputs.forEach { $0.bus(lock: &lock).zero() }
    }
    
    /// Call this method to unsilence every ouput of the node
    ///
    /// - parameter lock: A given context render lock
    public func unsilenceOutputs(lock: inout ContextRenderLock) {
        outputs.forEach { $0.bus(lock: &lock).clearSilent()}
    }
    
    /// Call this method to process inputs and ouputs if necessary
    /// Use this method to check is this node needs to process inputs or outputs
    ///
    /// - parameter lock: A given context render lock
    /// - parameter framesToProcess: A given number of frames to be processed
    public func processIfNecessary(lock: inout ContextRenderLock, framesToProcess: Int) {
        
        let ac = lock.context
        let currentTime = ac.currentTime
        
        guard isInitialized else { return }
        guard lastProcessingTime != currentTime else { return }
        
        lastProcessingTime = currentTime
        pullInputs(lock: &lock, framesToProcess: framesToProcess)
        
        let silentInputs = inputsAreSilent(lock: &lock)
        
        if !silentInputs {
            lastNonSilentTime = Double((ac.currentSampleFrame + framesToProcess)) / Double(ac.sampleRate)
        }
        
        guard silentInputs && propagatesSilence(lock: &lock) else {
            process(lock: &lock, framesToProcess: framesToProcess)
            return unsilenceOutputs(lock: &lock)
        }
        
        return silenceOutputs(lock: &lock)
    }
    
    /// Call this method to process the current inputs and outputs
    ///
    /// - parameter lock: A given context render lock
    /// - parameter framesToProcess: A given number of frames to be processed
    open func process(lock: inout ContextRenderLock, framesToProcess: Int) {
        fatalError("should be overriden")
    }
    
    /// Call this method to know if this node should propagate silence
    ///
    /// - parameter lock: A given context render lock
    /// - returns: A boolValue that indicates if should propagate the silence
    public func propagatesSilence(lock: inout ContextRenderLock) -> Bool {
        return lastNonSilentTime + latencyTime(lock: &lock) + tailTime(lock: &lock) < lock.context.currentTime
    }
    
    /// Call this method to set the channel count for the current node
    ///
    /// - parameter lock: A given context render lock
    /// - parameter count: An intValue to specify the number of channels
    public func setChannelCount(lock: inout ContextGraphLock, count: Int) {
        guard channelCount <= AudioContext.maxNumberOfChannels, channelCount != count else { return }
        channelCount = count
        guard channelCount != ChannelCountMode.max.rawValue else { return }
        updateChannelsForInputs(lock: &lock)
    }
    
    /// Call this method to set the channel count mode
    ///
    /// - parameter lock: A given context render lock
    /// - parameter mode: A mode to be configured within this node
    public func setChannelCountMode(lock: inout ContextGraphLock, mode: ChannelCountMode) throws {
        guard mode.rawValue < ChannelCountMode.end.rawValue, channelCountMode != mode else { throw AudioNodeError.custom("no context") }
        channelCountMode = mode
        updateChannelsForInputs(lock: &lock)
    }
    
    /// Called to get the current node tail time
    ///
    /// - parameter lock: A given context render lock
    open func tailTime(lock: inout ContextRenderLock) -> TimeInterval {
        return 0
    }
    
    /// Called to get the current node latency time
    ///
    /// - parameter lock: A given context render lock
    open func latencyTime(lock: inout ContextRenderLock) -> TimeInterval {
        return 0
    }
    
    /// Call this method to uninitialize the current node
    /// Use this method to set the current isInitialized flag to false
    public func uninitialize() {
        print("log.node.uninitialized.\(debugDescription)")
        isInitialized = false
    }
    
    /// Call this method to reset the current node
    ///
    /// - parameter lock: A given context render lock
    open func reset(lock: inout ContextRenderLock) {
        fatalError("should be overriden")
    }
    
    deinit {
        print("log.io.deinit.\(debugDescription)")
    }
    
}

extension AudioNode {
    
    /// Call this method to schedule connection
    public func scheduleConnect() {
        disconnectSchedule = -1.0
        connectSchedule = 0.0
    }
    
    /// Call this method to add an input to the datasource
    ///
    /// - parameter input: A given audio node input
    internal func addInput(input: AudioNodeInput) {
        inputs.append(input)
    }
    
    /// Call this method to add an output to the datasource
    ///
    /// - parameter output: A given audio node output
    internal func addOutput(output: AudioNodeOutput) {
        outputs.append(output)
    }
    
    /// Call this method to retrieve an audio node input with a given index
    ///
    /// - parameter index: A given index to search within the array
    /// - returns: A optional audio node input
    public func input(index: Int) -> AudioNodeInput? {
        guard index < inputs.count else { return nil }
        return inputs[index]
    }
    
    /// Call this method to retrieve an audio node output with a given index
    ///
    /// - parameter index: A given index to search within the array
    /// - returns: A optional audio node output
    public func output(index: Int) -> AudioNodeOutput? {
        guard index < outputs.count else { return nil }
        return outputs[index]
    }
    
    /// Call this method to retrieve a setting with a name
    ///
    /// - parameter named: A stringValue that identifies the audio setting
    /// - returns: An optional audio setting
    public func setting(named: String) -> AudioSetting? {
        return settings.first(where: { $0.name == named })
    }
    
    /// Call this method to retrieve a param with a name
    ///
    /// - parameter named: A stringValue that identifies the audio param
    /// - returns: An optional audio param
    public func parameter(named: String) -> AudioParam? {
        return params.first(where: { $0.name == named })
    }
    
    /// Call this method to know if the inputs are silent
    ///
    /// - parameter lock: A given context render lock
    /// - returns: A boolValue that indicates if any input is silent
    public func inputsAreSilent(lock: inout ContextRenderLock) -> Bool {
        for (_, e) in inputs.enumerated() {
            guard let bus = e.bus(lock: &lock) else { continue }
            if !bus.isSilent { return false }
        }
        return true
    }
    
    /// Call this method to schedule disconnection
    public func scheduleDisconnect() {
        disconnectSchedule = 1.0
        connectSchedule = 1.0
    }
    
}

public extension AudioNode {

    /// Connect the current node to the context output
    ///
    /// - parameter context: The context
    func connect() {
        let context = AudioContext.shared
        try? context.connect(destination: context.destination, source: self)
    }

    /// Connect the current node to an output
    ///
    /// - parameter node: The safe cast output
    func connect(to node: AudioNode) {
        let context = AudioContext.shared
        try? context.connect(destination: node, source: self)
    }
    
    /// Connect the current node to the context output
    ///
    /// - parameter context: The context
    func disconnect() {
        let context = AudioContext.shared
        try? context.disconnect(destination: context.destination, source: self)
    }

    /// Disconnect the current node from an output
    ///
    /// - parameter node: The safe cast output
    func disconnect(from node: AudioNode) {
        let context = AudioContext.shared
        try? context.disconnect(destination: node, source: self)
    }

}
