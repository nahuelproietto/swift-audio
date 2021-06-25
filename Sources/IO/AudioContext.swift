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

public class AudioContext: NSObject {
    
    public static let maxNumberOfChannels: Int = 32
    
    public private(set) var isInitialized: Bool = false
    public private(set) var configuration: AudioHardwareDeviceNode.AudioDeviceConfiguration
    
    public let mainQueue: DispatchQueue
    public let lockQueue: DispatchQueue
    
    public var cv = NSCondition()
    public var dispatcher: Dispatcher = Dispatcher()
    
    public var lockGraph = UnsafeMutex()
    public var lockRender = UnsafeMutex()
    public var lockUpdate = UnsafeMutex()
    
    private var updateThreadShouldRun: Bool = true // atomic
    private var graphKeepAlive: TimeInterval = 0.0
    private var lastGraphUpdateTime: TimeInterval = 0.0
    private var isAudioThreadFinished: Bool = false
    private var automaticPullNodesNeedUpdating: Bool = false
    private var automaticPullNodes: [AudioNode] = [] // Set
    private var renderingAutomaticPullNodes: [AudioNode] = []
    private var pendingNodeConnections = PriorityQueue<PendingConnection>()
    private var pendingParamConnections = Queue<(AudioParam, AudioNode, Int)>()
    private var automaticSources: [AudioScheduledSourceNode] = []
    
    public static let defaultSampleRate: Int = 44100
    
    public static let shared = AudioContext(configuration: AudioHardwareDeviceNode.defaultConfiguration)
    
    enum ConnectionType : Int {
        case disconnect = 0
        case connect
        case finishDisconnect
    }
    
    public class Dispatcher: NSObject {
        
        var enqueuedEvents: Queue<NodeCompletion> = Queue()
        var autoDispatchEvents: Bool = false
        
        /// Call this method to enqueue events used mainly for scheduled playbacks
        ///
        /// - parameter lock: A given context render lock
        /// - parameter event: A given closure to schedule on queue
        public func enqueue(lock: inout ContextRenderLock, event: @escaping NodeCompletion) {
            enqueuedEvents.enqueue(event)
            lock.context.cv.signal()
        }
        
        /// Call this method to dispatch events from queue
        /// Use this function when the audio playback finished with playback
        public func dispatch() {
            while !enqueuedEvents.isEmpty {
                guard let event = enqueuedEvents.dequeue() else { continue }
                DispatchQueue.main.async {
                    event()
                }
            }
        }
    }
    
    struct PendingConnection: Comparable {

        typealias `Type` = ConnectionType
        
        struct Indexes {
            var destinationIndex: Int
            var sourceIndex: Int
        }
        
        public var source: AudioNode
        public var destination: AudioNode
        public var connection: Type = .connect
        public var destIndex: Int = 0
        public var duration: TimeInterval = 0.1
        public var srcIndex: Int = 0
        
        /// Call this method to initialized a connection
        ///
        /// - parameter source: Any given source
        /// - parameter destination: Any given destination
        /// - parameter connection: Any given connection type
        /// - parameter indexes: Any given indexes
        init(
            source: AudioNode,
            destination: AudioNode,
            connection: ConnectionType,
            indexes: Indexes) {
            self.source = source
            self.destination = destination
            self.connection = connection
            self.destIndex = indexes.destinationIndex
            self.srcIndex = indexes.sourceIndex
        }
        
        /// Use this static function to compate two different connections
        ///
        /// - parameter lhs: A left connection to be compared
        /// - parameter rhs: A right connection to be compared
        static func <(lhs: AudioContext.PendingConnection, rhs: AudioContext.PendingConnection) -> Bool {
            lhs.connection.rawValue < rhs.connection.rawValue
        }
        
        /// Use this static function to compate two different connections
        ///
        /// - parameter lhs: A left connection to be compared
        /// - parameter rhs: A right connection to be compared
        static func ==(lhs: AudioContext.PendingConnection, rhs: AudioContext.PendingConnection) -> Bool {
            return lhs.source.uuid == rhs.source.uuid && lhs.destination.uuid == rhs.destination.uuid
        }
        
    }
    
    struct CompareScheduledTime {
        
        /// Use this static function to compate two different scheduled times
        ///
        /// - parameter p1: A left connection to be compared
        /// - parameter p2: A right connection to be compared
        static func compare(p1: inout PendingConnection, p2: inout PendingConnection) -> Bool {
            if !p2.destination.isScheduledNode { return false }
            if !p1.destination.isScheduledNode { return false }
            guard let ap2 = p2.destination as? AudioScheduledSourceNode else { return false }
            guard let ap1 = p1.destination as? AudioScheduledSourceNode else { return false }
            return ap2.startTime < ap1.startTime
        }
        
    }
    
    public var currentTime: TimeInterval {
        return destination.lastSampling.value.time
    }
    
    public var sampleRate: Int {
        return destination.lastSampling.value.samplerate
    }

    public var currentSampleFrame: Int {
        return destination.lastSampling.value.frame
    }
    
    public private(set) lazy var destination: AudioHardwareDeviceNode = {
        return AudioDeviceMiniAudio(context: self, configuration: configuration)
    }()
    
    /// Call this method to initialize the current context
    ///
    /// - parameter configuration: An audio hardware device configuration
    /// - parameter autoDispatchEvents: A boolValue to indicate auto dispatch
    init(configuration: AudioHardwareDeviceNode.AudioDeviceConfiguration, autoDispatchEvents: Bool = true) {
        self.dispatcher = Dispatcher()
        self.configuration = configuration
        
        self.lockQueue = DispatchQueue(label: .lockQueue)
        self.mainQueue = DispatchQueue(label: .mainQueue)
        
        super.init()
        self.lazyInitialize()
    }
    
    /// Call this method to initialize the context
    ///
    /// Use this method to start the main update context loop
    /// Update context loop is used to schedule node connections
    public func lazyInitialize() {
        guard !isInitialized else { return }
        guard !isAudioThreadFinished else { return }
        
        destination.initialize()
        graphKeepAlive = 0.25
        isInitialized = true
        
        mainQueue.async { self.update() }
        
        startRendering()
        cv.signal()
    }

    /// Call this method to handle automatic pull nodes
    ///
    /// - parameter lock: A context render lock
    public func handlePreRenderTasks(lock: inout ContextRenderLock) {
        AudioSummingJunction.handleDirtyAudioSummingJunctions(lock: &lock)
        updateAutomaticPullNodes()
    }

    /// Call this method to handle automatic pull nodes
    ///
    /// - parameter lock: A context render lock
    public func handlePostRenderTasks(lock: inout ContextRenderLock) {
        AudioSummingJunction.handleDirtyAudioSummingJunctions(lock: &lock)
        updateAutomaticPullNodes()
        handleAutomaticSources()
    }
    
    /// Call this method to handle automatic sources
    private func handleAutomaticSources() {
        lockQueue.async {
            for i in 0..<self.automaticSources.count {
                let destination = self.automaticSources[i]
                guard destination.isFinished else { continue }
                let indexes = PendingConnection.Indexes(destinationIndex: 0, sourceIndex: 0)
                let connection = PendingConnection(source: AudioNode(), destination: destination, connection: .disconnect, indexes: indexes)
                self.pendingNodeConnections.push(connection)
                self.automaticSources.remove(at: i)
                if i == self.automaticSources.endIndex { break }
            }
        }
    }

    /// Call this method to hold source node until finished
    ///
    /// - parameter node: Any schedule node
    public func holdSourceNodeUntilFinished(node: AudioScheduledSourceNode) {
        lockQueue.async { self.automaticSources.append(node) }
    }
    
    enum AudioContextError: Swift.Error {
        case custom(String)
    }
    
    /// Call this method to start rendering from device node
    /// Should initialize the device before calling this function, see <AudioDevice>
    public func startRendering() {
        destination.start()
    }
    
    /// Call this method to stop rendering from device node
    /// Use this function only if the current device is initialized, see <AudioDevice>
    public func stopRendering() {
        destination.stop()
    }
    
    /// Call this method to initialize
    private func uninitialize() {
        guard isInitialized else { return }
        
        destination.uninitialize()
        updateAutomaticPullNodes()
        
        isAudioThreadFinished = true
        isInitialized = false
    }
    
    deinit {
        cv.signal()
        graphKeepAlive = 0.25
        print("log.io.deinit.\(debugDescription)")
        updateThreadShouldRun = false
        uninitialize()
    }
    
}

extension AudioContext {
    
    /// Use this method to perform the main context loop
    /// On every interation this class will try to find new connections/disconnections
    private func update() {
        
        let sizeInFrames: Float = Float(AudioNode.processingSizeInFrames)
        let framesPerSecond = Double(sampleRate) / Double(sizeInFrames) / 1000 // 0.34 ms @ 44.1/128
        
        while (updateThreadShouldRun || graphKeepAlive > 0) {

            defer { lockUpdate.unlock() }; lockUpdate.lock()
            
            if (currentTime + graphKeepAlive) > currentTime {
                cv.wait(until: Date().addingTimeInterval(TimeInterval(framesPerSecond*16)))
            }
            else {
                cv.wait()
            }
            
            lockQueue.async {
                if self.dispatcher.autoDispatchEvents {
                    self.dispatcher.dispatch()
                }
            }
            
            guard updateThreadShouldRun || graphKeepAlive > 0 else { continue }
            
            let now = currentTime
            let delta = now - lastGraphUpdateTime
            
            var lock = ContextGraphLock(context: self)
            
            lastGraphUpdateTime = now
            graphKeepAlive -= delta
            
            lockQueue.async {
                repeat {
                    guard let connection = self.pendingParamConnections.dequeue() else { continue }
                    let output = connection.1.output(index: connection.2)
                    AudioParam.connect(lock: &lock, param: connection.0, output: output)
                    
                } while !self.pendingParamConnections.isEmpty
                
                var skippedConnections: [PendingConnection] = []
                
                repeat {
                    guard var connection = self.pendingNodeConnections.pop() else { continue }
                    
                    switch connection.connection {
                    case .connect:
                        
                        guard connection.destination.isScheduledNode else {
                            connection.source.scheduleConnect()
                            let source = connection.source.output(index: connection.srcIndex)
                            let destination = connection.destination.input(index: connection.destIndex)
                            AudioNodeInput.connect(lock: &lock, from: destination, to: source)
                            break
                        }
                        
                        print("log.io.connect.\(self.debugDescription)")
                        
                        guard let node = connection.destination as? AudioScheduledSourceNode else { continue }
                        guard node.startTime > TimeInterval(now) + 0.1 else { continue }
                        
                        skippedConnections.append(connection)
                        continue
                        
                    case .disconnect:
                        
                        connection.connection = .finishDisconnect
                        skippedConnections.append(connection)
                        
                        connection.source.scheduleDisconnect()
                        connection.destination.scheduleDisconnect()
                        
                        self.mainQueue.async {
                            self.graphKeepAlive = self.updateThreadShouldRun ? connection.duration : self.graphKeepAlive
                        }
                        
                        print("log.io.disconnect.\(self.debugDescription)")
                        
                    case .finishDisconnect:
                        
                        guard connection.duration > 0 else {
                            let source = connection.source.output(index: connection.srcIndex)
                            let destination = connection.destination.input(index: connection.destIndex)
                            AudioNodeInput.disconnect(lock: &lock, from: destination, to: source)
                            break
                        }
                        
                        connection.duration -= delta
                        skippedConnections.append(connection)
                        continue
                    }
                    
                } while !self.pendingNodeConnections.isEmpty
                
                for (_, e) in skippedConnections.enumerated() {
                    self.pendingNodeConnections.push(e)
                }
            }
        }
    }
    
}

extension AudioContext {
    
    /// Call this method to add automatic pull nodes
    ///
    /// - parameter node: Any audio node
    public func addAutomaticPullNode(node: AudioNode) {
        guard let _ = automaticPullNodes.firstIndex(where: { $0.uuid == node.uuid }) else {
            return lockQueue.async { self.automaticPullNodes.append(node); self.automaticPullNodesNeedUpdating = true }
            
        }
    }
    
    /// Call this method to process automatic pull nodes
    ///
    /// - parameter lock: A context render lock
    /// - parameter framesToProcess: An intValue
    public func processAutomaticPullNodes(lock: inout ContextRenderLock, framesToProcess: Int) {
        for e in renderingAutomaticPullNodes {
            e.processIfNecessary(lock: &lock, framesToProcess: framesToProcess)
        }
    }
    
    /// Call this method to remove automatic pull nodes
    ///
    /// - parameter node: Any audio node
    public func removeAutomaticPullNode(node: AudioNode) {
        guard let firstIndex = automaticPullNodes.firstIndex(where: { $0.uuid == node.uuid }) else { return }
        lockQueue.async { self.automaticPullNodes.remove(at: firstIndex); self.automaticPullNodesNeedUpdating = true; }
    }
    
    /// Call this method to update automatic pull nodes
    private func updateAutomaticPullNodes() {
        guard automaticPullNodesNeedUpdating else { automaticPullNodesNeedUpdating = false; return }
        lockQueue.async { self.renderingAutomaticPullNodes.append(contentsOf: self.automaticPullNodes) }
        automaticPullNodesNeedUpdating = false
    }
    
}

extension AudioContext {
    
    /// Call this method to connect a param
    ///
    /// - parameter param: A param to connect
    /// - parameter driver: A  node
    /// - parameter index: An index for the destination
    public func connect(parameter: AudioParam, driver: AudioNode, index: Int) throws {
        guard index < driver.numberOfOutputs else { throw AudioContextError.custom("output is greater than available outputs")}
        lockQueue.async { self.pendingParamConnections.enqueue((parameter, driver, index)) }
        cv.signal()
    }
    
    /// Call this method to connect a node
    ///
    /// - parameter destination: A destination node
    /// - parameter source: A source node
    /// - parameter destinationIdx: An index for the destination
    /// - parameter sourceIdx: An index for the source
    public func connect(destination: AudioNode, source: AudioNode, destinationIdx: Int = 0, sourceIdx: Int = 0) throws {
        if sourceIdx > source.numberOfOutputs { throw AudioContextError.custom("output greater than available output") }
        if destinationIdx > destination.numberOfInputs { throw AudioContextError.custom("input greater than available inputs") }
        let indexes = PendingConnection.Indexes(destinationIndex: destinationIdx, sourceIndex: sourceIdx)
        let connection = PendingConnection(source: source, destination: destination, connection: .connect, indexes: indexes)
        lockQueue.async { self.pendingNodeConnections.push(connection) }
        cv.signal()
    }
    
    /// Call this method to disconnect a node
    ///
    /// - parameter destination: A destination node
    /// - parameter source: A source node
    /// - parameter destinationIdx: An index for the destination
    /// - parameter sourceIdx: An index for the source
    public func disconnect(destination: AudioNode, source: AudioNode, destinationIdx: Int = 0, sourceIdx: Int = 0) throws {
        if sourceIdx > source.numberOfOutputs { throw AudioContextError.custom("output greater than available output") }
        if destinationIdx > destination.numberOfInputs { throw AudioContextError.custom("input greater than available inputs") }
        let indexes = PendingConnection.Indexes(destinationIndex: destinationIdx, sourceIndex: sourceIdx)
        let connection = PendingConnection(source: source, destination: destination, connection: .disconnect, indexes: indexes)
        lockQueue.async { self.pendingNodeConnections.push(connection) }
        cv.signal()
    }
    
}

fileprivate extension String {
    static let mainQueue: String = "log.io.context.main"
    static let lockQueue: String = "log.io.context.lock"
}
