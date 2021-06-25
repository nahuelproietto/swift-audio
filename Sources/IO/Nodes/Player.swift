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

open class AudioPlayer: AudioScheduledSourceNode {
    
    public var gain: AudioParam
    
    public private(set) var sourceBus: AudioBus?
    
    public var duration: Float {
        guard let source = sourceBus else { return 0 }
        return Float(source.length) / Float(source.sampleRate)
    }
    
    public var numberOfChannels: Int {
        return output(index: 0)?.numberOfChannels ?? 0
    }
    
    public private(set) var lastGain: Float = 1
    
    private var virtualReadIndex: Float = 0
    
    /// Call this method to initialize the current audio player
    ///
    /// - parameter url: A given url with source data
    /// - parameter playbackState: A current playbackState
    public init(contentsOf url: URL, playbackState: AudioScheduledSourceNode.PlaybackState = .unscheduled) {
        gain = AudioParam(name: "gain", defaultValue: 1, minValue: 0, maxValue: 1)
        super.init(playbackState: playbackState)
        let source = AudioFileReader.makeBusFromFile(url: url)
        self.initialize(with: source)
    }
    
    /// Call this method to initialize the current audio player
    ///
    /// - parameter data: A given data file with audio samples
    /// - parameter playbackState: A current playbackState
    public init(data: Data, format: URL.Stream, playbackState: AudioScheduledSourceNode.PlaybackState = .unscheduled) {
        gain = AudioParam(name: "gain", defaultValue: 1, minValue: 0, maxValue: 1)
        super.init(playbackState: playbackState)
        let source = AudioFileReader.makeBusFromFileData(data: data, format: format)
        self.initialize(with: source)
    }
    
    /// Call this method to initialize the current audio player
    ///
    /// - parameter source: A given source bus
    /// - parameter playbackState: A current playbackState
    public init(source: AudioBus?, playbackState: AudioScheduledSourceNode.PlaybackState = .unscheduled) {
        gain = AudioParam(name: "gain", defaultValue: 1, minValue: 0, maxValue: 1)
        super.init(playbackState: playbackState)
        self.initialize(with: source)
    }
    
    /// Call this method to initialize the node
    public func initialize(with source: AudioBus?) {
        super.initialize()
        var lock = ContextRenderLock(context: AudioContext.shared)
        addOutput(output: AudioNodeOutput(audioNode: self, numberOfChannels: 2))
        print("log.io.init.\(debugDescription))")
        setSource(lock: &lock, source: source)
        params.append(gain)
    }
    
    /// Call this method to process the given node
    ///
    /// - parameter lock: An inout render lock
    /// - parameter framesToProcess: A frame amount to process
    public override func process(lock: inout ContextRenderLock, framesToProcess: Int) {
        guard let outputBus = output(index: 0)?.bus(lock: &lock) else { return }
        guard let bus = sourceBus, isInitialized else { return outputBus.zero() }
        
        let numberOfChannel = numberOfChannels
        guard numberOfChannel == bus.numberOfChannels else { return outputBus.zero() }
        
        var quantumFrameOfsset: Int = 0
        var bufferFramesToProcess: Int = 0
        
        updateSchedulingInfo(
            lock: &lock,
            quantumFrameSize: framesToProcess,
            outputBus: outputBus,
            quantumFrameOffset: &quantumFrameOfsset,
            nonSilentFramesToProcess: &bufferFramesToProcess)
        
        guard bufferFramesToProcess > 0 else { return outputBus.zero() }
        
        guard renderFromBuffer(
                lock: &lock,
                destination: outputBus,
                destinationFrameOffset: quantumFrameOfsset,
                numberOfFrames: bufferFramesToProcess) else {
            return outputBus.zero()
        }

        let totalGain = gain.value(lock: &lock)
        outputBus.copyWithGain(from: outputBus, lastMixGain: &lastGain, targetGain: totalGain)
        outputBus.clearSilent()
    }
    
    /// Call this methos to know if this node should propagate silence
    ///
    /// - parameter lock: A current context render lock
    /// - returns: A boolValue the indicates if indicates if should propagate silence
    public override func propagatesSilence(lock: inout ContextRenderLock) -> Bool {
        return !isPlayingOrScheduled || isFinished || sourceBus == nil
    }
    
    /// Call this method to reset the current node
    ///
    /// - parameter lock: A given context render lock
    public override func reset(lock: inout ContextRenderLock) {
        print("log.io.reset.\(debugDescription))")
        virtualReadIndex = 0
        lastGain = gain.value(lock: &lock)
        super.reset(lock: &lock)
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
    
    deinit {
        uninitialize()
        print("log.io.deinit.\(debugDescription))")
    }
    
}

extension AudioPlayer {
    
    /// Call this method to set a source audio bus to the current node
    ///
    /// - parameter lock: A current context render lock
    /// - parameter buffer: A reference to the new input buss
    /// - returns: A boolValue that indicates if the operaation succedeed
    @discardableResult
    public func setSource(lock: inout ContextRenderLock, source: AudioBus?) -> Bool {
        guard let buffer = source else { return false }
        let numberOfChannels = buffer.numberOfChannels
        guard numberOfChannels < AudioContext.maxNumberOfChannels else { return false }
        output(index: 0)?.setNumberOfChannels(lock: &lock, numberOfChannels: numberOfChannels)
        virtualReadIndex = 0
        sourceBus = buffer
        return true
    }
    
    /// Call this method to render samples from buffer
    ///
    /// - parameter lock: A current context render lock
    /// - parameter destination: A current destination bus to copy samples
    /// - parameter destinationFrameOffset: A destination frame offset
    /// - parameter numberOfFrames: A number of frames to be processed from bus
    /// - returns: A boolValue that indicates if the operation could be completed
    private func renderFromBuffer(lock: inout ContextRenderLock,
        destination: AudioBus, destinationFrameOffset: Int, numberOfFrames: Int) -> Bool {
        guard let sourceBus = self.sourceBus else { return false }
        
        let bufferLength = sourceBus.length
        let numChannels = self.numberOfChannels
        let busNumberOfChannels = destination.numberOfChannels
        let destinationLength = destination.length
        let isDestinationSafe = destinationFrameOffset + numberOfFrames <= destinationLength
        
        guard numChannels > 0 && numChannels == busNumberOfChannels else { return false }
        guard destinationLength <= 4096 && numberOfFrames <= 4096 else { return false }
        guard destinationFrameOffset <= destinationLength && isDestinationSafe else { return false }
        
        var writeIndex: Int = destinationFrameOffset
        var endFrame = bufferLength
        
        if Int(virtualReadIndex) >= endFrame {
            virtualReadIndex = 0
        }
        
        let virtualEndFrame = endFrame
        let virtualDeltaFrame = virtualEndFrame
        let virtualReadIndex: Int = Int(self.virtualReadIndex)
        let deltaFrames = virtualDeltaFrame
        
        var framesToProcess = numberOfFrames
        var readIndex: Int = Int(virtualReadIndex)
        
        endFrame = virtualEndFrame
        
        let framesToEnd = endFrame - Int(readIndex)
        
        var framesThisTime = min(framesToProcess, framesToEnd)
        framesThisTime = max(0, framesThisTime)
        
        let size = MemoryLayout<Scalar>.size * framesToProcess
        
        if virtualReadIndex+size <= sourceBus.length {
            switch numChannels {
            case Channels.stereo.rawValue:
                guard let sourceL = sourceBus.channel(index: 0) else { return false }
                guard let sourceR = sourceBus.channel(index: 1) else { return false }
                guard let destinationL = destination.channel(index: 0) else { return false }
                guard let destinationR = destination.channel(index: 1) else { return false }
                memcpy(destinationL.data(), sourceL.data().advanced(by: virtualReadIndex), size)
                memcpy(destinationR.data(), sourceR.data().advanced(by: virtualReadIndex), size)
            case Channels.mono.rawValue:
                guard let source = sourceBus.channel(index: 0) else { return false }
                guard let destination = destination.channel(index: 0) else { return false }
                memcpy(destination.data(), source.data().advanced(by: virtualReadIndex), size)
            default:
                return false
            }
        }
        
        writeIndex += framesThisTime
        framesToProcess -= framesThisTime
        readIndex += Int(framesThisTime)
        
        if Int(readIndex) >= endFrame {
            readIndex -= Int(deltaFrames)
            renderSilenceAndFinishIfNotLooping(
                lock: &lock, audioBus: destination, index: writeIndex,  framesToProcess: framesToProcess)
        }
        
        destination.clearSilent()
        self.virtualReadIndex += Float(numberOfFrames)
        
        return true
    }
    
    /// Call this method to render silence and finish the current playback
    ///
    /// - parameter lock: A current context render lock
    /// - parameter audioBus: A current destination bus to copy samples
    /// - parameter index: An index of the channel
    /// - parameter framesToProcess: A number of frames to be processed
    @discardableResult
    private func renderSilenceAndFinishIfNotLooping(
        lock: inout ContextRenderLock, audioBus: AudioBus, index: Int, framesToProcess: Int) -> Bool {
        if framesToProcess > 0 {
            for i in 0...numberOfChannels {
                let size = MemoryLayout<Scalar>.size
                guard let destination = audioBus.channel(index: i) else { continue }
                memset(destination.data() + index, 0, size * framesToProcess)
            }
        }
        finish(lock: &lock)
        return true
    }
    
}
