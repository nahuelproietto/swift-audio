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

open class AudioScheduledSourceNode: AudioNode {
    
    static let unknown: TimeInterval = -1;
    
    fileprivate var onEnded: NodeCompletion?
    
    public private(set) var startTime: TimeInterval
    public private(set) var endTime: TimeInterval
    public private(set) var playbackState: PlaybackState
    
    private var pendingEndTime: TimeInterval
    private var pendingStartTime: TimeInterval
    
    public override var isScheduledNode: Bool { return true }
    
    public var isFinished: Bool { return playbackState == .finished }
    public var isPlayingOrScheduled: Bool {
        return playbackState == .playing || playbackState == .scheduled
    }
    
    public enum PlaybackState: Int {
        case unscheduled = 0
        case scheduled
        case playing
        case finished
    }
    
    /// Call this method to initialize the current audio scheduled source node
    ///
    /// - parameter playbackState: A given playback state
    public init(playbackState: PlaybackState = .unscheduled) {
        self.startTime = 0
        
        let unknown = AudioScheduledSourceNode.unknown
        
        self.pendingStartTime = unknown
        self.pendingEndTime = unknown
        self.endTime = unknown
        self.playbackState = playbackState
        
        super.init()
    }
    
    /// Call this method to start playback
    ///
    /// - parameter when: A time offset
    /// - parameter completion: A node completion handler
    public func play(after timeInterval: TimeInterval, completion: NodeCompletion?) {
        guard timeInterval >= 0, playbackState != .playing else { return }
        onEnded = completion
        pendingStartTime = timeInterval
        playbackState = .scheduled
    }
    
    /// Call this method to stop playback
    ///
    /// - parameter when: A time offset
    public func stop(after timeInterval: TimeInterval) {
        guard timeInterval >= 0 else { return }
        pendingEndTime = max(0, timeInterval)
    }
    
    /// Called to update the scheduling information
    ///
    /// - parameter lock: A context render lock
    /// - parameter quantumFrameSize: An intvalue
    /// - parameter outputBus: A reference to the output bus
    /// - parameter quantumFrameOffset: A intValue
    /// - parameter nonSilentFramesToProcess: A intValue
    internal func updateSchedulingInfo(
        lock: inout ContextRenderLock,
        quantumFrameSize: Int,
        outputBus: AudioBus,
        quantumFrameOffset: inout Int,
        nonSilentFramesToProcess: inout Int) {
        
        let context = lock.context
        guard quantumFrameSize == AudioNode.processingSizeInFrames else { return }
        
        if pendingEndTime > AudioScheduledSourceNode.unknown {
            endTime = pendingEndTime
            pendingEndTime = AudioScheduledSourceNode.unknown
        }

        if pendingStartTime > AudioScheduledSourceNode.unknown {
            startTime = pendingStartTime
            pendingStartTime = AudioScheduledSourceNode.unknown
        }
        
        let sampleRate = context.sampleRate
        
        let quantumStartFrame = context.currentSampleFrame
        let quantumEndFrame = quantumStartFrame + quantumFrameSize
        
        let startFrame = AudioUtilities.timeToSampleFrame(time: startTime, sampleRate: sampleRate)
        let timeToEndFrame = AudioUtilities.timeToSampleFrame(time: endTime, sampleRate: sampleRate)
        let endFrame = Int(endTime) == Int(AudioScheduledSourceNode.unknown) ? 0 : timeToEndFrame
        
        if endTime != AudioScheduledSourceNode.unknown && endFrame <= quantumStartFrame {
            finish(lock: &lock)
        }
        
        if playbackState == .unscheduled || playbackState == .finished || startFrame >= quantumEndFrame {
            outputBus.zero()
            nonSilentFramesToProcess = 0
            return
        }
        
        if playbackState == .scheduled {
            playbackState = .playing
        }
        
        quantumFrameOffset = startFrame > quantumStartFrame ? startFrame - quantumStartFrame : 0
        quantumFrameOffset = min(quantumFrameOffset, quantumFrameSize)
        nonSilentFramesToProcess = quantumFrameSize - quantumFrameOffset
        
        if nonSilentFramesToProcess == 0 {
            outputBus.zero()
            return
        }
        
        if quantumFrameOffset > 0 {
            for i in 0...outputBus.numberOfChannels {
                let size = MemoryLayout<Scalar>.size
                guard let channel = outputBus.channel(index: i) else { continue }
                memset(channel.data(), 0, size * quantumFrameOffset)
            }
        }
        
        if endTime != AudioScheduledSourceNode.unknown && endFrame >= quantumStartFrame && endFrame < quantumEndFrame {
            
            let zeroStartFrame = endFrame - quantumStartFrame
            let framesToZero = quantumFrameSize - zeroStartFrame
            
            let isSafe = zeroStartFrame < quantumFrameSize
                && framesToZero <= quantumFrameSize
                && zeroStartFrame + framesToZero <= quantumFrameSize
            
            guard isSafe else { return finish(lock: &lock) }
            
            if framesToZero > nonSilentFramesToProcess {
                nonSilentFramesToProcess = 0
            }
            else {
                nonSilentFramesToProcess -= framesToZero
            }
            
            for i in 0...outputBus.numberOfChannels {
                let size = MemoryLayout<Scalar>.size
                guard let destination = outputBus.channel(index: i) else { continue }
                memset(destination.data().advanced(by: zeroStartFrame), 0, (size * framesToZero))
            }
            
            finish(lock: &lock)
        }
        
    }
    
    /// Called on scheduling finish
    ///
    /// - parameter lock: A context render lock
    internal func finish(lock: inout ContextRenderLock) {
        playbackState = .finished
        guard let event = onEnded else { return }
        
        let context = lock.context
        context.dispatcher.enqueue(lock: &lock, event: event)
    }
    
    /// Called to get the current node tail time
    ///
    /// - parameter lock: A given context render lock
    public override func tailTime(lock: inout ContextRenderLock) -> TimeInterval {
        return AudioNode.zero
    }
    
    /// Called to get the current node latency time
    ///
    /// - parameter lock: A given context render lock
    public override func latencyTime(lock: inout ContextRenderLock) -> TimeInterval {
        return AudioNode.zero
    }
    
    /// Call this method to reset the current node
    ///
    /// - parameter lock: A given context render lock
    public override func reset(lock: inout ContextRenderLock) {
        print("log.io.reset.\(debugDescription))")
        pendingEndTime = TimeInterval(AudioScheduledSourceNode.unknown)
        playbackState = .unscheduled
    }
    
    /// Call this method to uninitialze the current node
    public override func uninitialize() {
        super.uninitialize()
    }
    
    deinit {
        uninitialize()
        print("log.io.deinit.\(debugDescription))")
    }
    
}
