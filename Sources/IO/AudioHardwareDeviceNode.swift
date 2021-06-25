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

public class AudioHardwareDeviceNode: AudioNode {
    
    private var context: AudioContext
    
    public internal(set) var inputConfig: StreamSource
    public internal(set) var outputConfig: StreamSource
    public internal(set) var lastSampling: AtomicProperty<RenderQuantumDesc>
    
    public struct AudioDeviceIndex {
        var index: Int
        var valid: Bool
    }
    
    public static var defaultConfiguration = AudioDeviceConfiguration()
    
    public struct AudioDeviceConfiguration {
        var input = StreamSource.mono
        var output = StreamSource.stereo
    }
    
    /// Call this method to initialize a hardware device node
    ///
    /// - parameter context: A current audio context
    /// - parameter configuration: An struct containing the current configuration for playback
    public init(context: AudioContext, configuration: AudioDeviceConfiguration) {
        
        self.context = context
        self.outputConfig = configuration.output
        self.inputConfig = configuration.input
        self.lastSampling = AtomicProperty<RenderQuantumDesc>(value: RenderQuantumDesc.default)
        
        super.init()
        
        addInput(input: AudioNodeInput(audioNode: self))
        addOutput(output: AudioNodeOutput(audioNode: self, numberOfChannels: configuration.input.channels))
        
        channelCountMode = .explicit
        channelIntepretation = .speakers
        
        var lock = ContextGraphLock(context: context)
        
        setChannelCount(lock: &lock, count: outputConfig.channels)
        lastSampling.value = RenderQuantumDesc.default
        
        initialize()
    }
    
    /// Call this method to initialize the audio hardware engine
    public override func initialize() {
        super.initialize()
    }
    
    /// Called to render samples from device, this method should be called from the render callback
    ///
    /// - parameter source: Any source bus
    /// - parameter source: Any destination bus
    /// - parameter framesToProcess: An intValue for frames to render
    /// - parameter info: A sampling info
    open func render(source: AudioBus, destination: AudioBus, framesToProcess: Int, info: RenderQuantumDesc) {
        
        guard context.isInitialized else { return destination.zero() }
        guard let input = self.input(index: 0) else { return destination.zero() }

        var lock = ContextRenderLock(context: context)
        context.handlePreRenderTasks(lock: &lock)
        
        let renderedBus = input.pull(lock: &lock, inPlaceBus: destination, framesToProcess: framesToProcess)
        destination.copy(from: renderedBus)

        context.processAutomaticPullNodes(lock: &lock, framesToProcess: framesToProcess)
        context.handlePostRenderTasks(lock: &lock)
        
        let automaticPullNodeBus = output(index: 0)?.bus(lock: &lock)
        automaticPullNodeBus?.copy(from: source)
        
        self.lastSampling.value = info
    }
    
    /// Call this method to process inputs and ouputs if necessary
    /// Use this method to check is this node needs to process inputs or outputs
    ///
    /// - parameter lock: A given context render lock
    /// - parameter framesToProcess: A given number of frames to be processed
    public override func processIfNecessary(lock: inout ContextRenderLock, framesToProcess: Int) {
        let ac = lock.context
        let currentTime = ac.currentTime
        
        // This method should be called on processAutomaticPullNodes since inputs are pulled on render()
        
        guard isInitialized else { return }
        guard lastProcessingTime != currentTime else { return }
        
        lastProcessingTime = currentTime
        process(lock: &lock, framesToProcess: framesToProcess)
        
        return unsilenceOutputs(lock: &lock)
    }
    
    /// Call this method to process the inputs and outputs from the node
    ///
    /// - parameter lock: A current context render lock by reference
    /// - parameter framesToProcess: A number of frames to process
    public override func process(lock: inout ContextRenderLock, framesToProcess: Int) { }
    
    /// Call this method to start rendering from the device
    /// Use this method only when the device is correctly configured
    open func start() {
        fatalError("should be overriden")
    }
    
    /// Call this method to stop rendering from the device
    /// Use this method only when the device is properly configured and running
    open func stop() {
        fatalError("should be overriden")
    }
    
    /// Call this method to get the default input index, you should override this method
    ///
    /// - returns: An audio device output
    open func getDefaultOutputAudioDeviceIndex() -> AudioDeviceIndex {
        return AudioDeviceIndex(index: 0, valid: false)
    }
    
    /// Call this method to get the default input index, you should override this method
    ///
    /// - returns: An audio device index
    open func getDefaultInputAudioDeviceIndex() -> AudioDeviceIndex {
        return AudioDeviceIndex(index: 0, valid: false)
    }
    
    /// Call this method to reset the current node
    ///
    /// - parameter lock: A given context render lock
    public override func reset(lock: inout ContextRenderLock) {
        self.stop()
        self.start()
    }
    
    /// Call this method to unitialize the current audio device node
    public override func uninitialize() {
        super.uninitialize()
        self.stop()
    }
    
    deinit {
        uninitialize()
        print("log.io.deinit.\(debugDescription)")
    }
    
}
