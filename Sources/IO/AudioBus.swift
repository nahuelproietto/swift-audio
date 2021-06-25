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
import CIO

//MARK:

public class AudioBus: NSObject {
    
    enum Layout: String {
        case layoutCanonical
    }
    
    public static let maxBusChannels: Int = 32
    
    public var sampleRate: Int = AudioContext.defaultSampleRate
    
    public private(set) var length: Int = 0
    public private(set) var isFirstTime: Bool = false
    
    private var busGain: Float = 1.0
    private var channels: [AudioChannel]
    private var dezipperGainValues: AudioArray<Float>
    private var layout: Layout = .layoutCanonical
    
    internal var uuid: UUID = UUID()
    
    public var numberOfChannels: Int {
        channels.count
    }
    
    public var isSilent: Bool {
        return channels.allSatisfy { $0.isSilent }
    }
    
    /// Call this initializer to create a new audio bus
    ///
    /// - parameter numberOfChannels: An intValue for the channels
    /// - parameter lenght: An intValue for the buffer lenght
    init(numberOfChannels: Int, lenght: Int) {
        self.length = lenght
        self.dezipperGainValues = AudioArray<Float>(size: 0)
        self.channels = [AudioChannel]()
        
        super.init()
        
        guard numberOfChannels < AudioBus.maxBusChannels else { return }
        guard numberOfChannels > 0 else { return }
        
        print("log.io.init.\(debugDescription)")
        
        for _ in 0..<numberOfChannels {
            channels.append(AudioChannel(length: lenght))
        }
        
    }
    
    /// Call this method to compare <AudioBus> topology
    ///
    /// - parameter source: Any given audiobus source
    /// - returns: A boolValue that indicates if topology matches
    public func topologyMatches(source: AudioBus) -> Bool {
        guard numberOfChannels == source.numberOfChannels else { return false }
        return length <= source.length
    }
    
    /// Call this method to set the buffer for a given channel
    ///
    /// - parameter channelIndex: An intValue that identifies the channel
    /// - parameter storage: A buffer to copy into the channel
    /// - parameter lenght: A size for the buffer
    public func setChannelMemory(at index: Int, storage: AudioArray<Scalar>) {
        guard index < channels.count else { return }
        channel(index: index)?.copy(from: storage)
        self.length = storage.size
    }
    
    deinit {
        print("log.io.deinit.\(debugDescription)")
    }
    
}

extension AudioBus {
    
    /// Call this method to copy values from source
    ///
    /// - parameter sourceBus: Any source bus
    /// - parameter interpretation: Any given interpretation
    public func copy(from source: AudioBus, interpretation: ChannelInterpretation = .speakers) {
        guard source.uuid != uuid else { return }
        
        let numberOfSourceChannels = source.numberOfChannels
        let numberOfDestinationChannels = numberOfChannels
        
        if numberOfDestinationChannels == numberOfSourceChannels {
            for (i, e) in channels.enumerated() {
                guard let sourceChannel = source.channel(index: i) else { continue }
                e.copy(from: sourceChannel)
            }
        }
        else {
            switch interpretation {
            case .speakers:
                speakersCopy(from: source)
            case .discrete:
                discreteCopy(from: source)
            }
        }
    }
    
    /// Call this method to sum values from source
    ///
    /// - parameter sourceBus: Any source bus
    /// - parameter interpretation: Any given interpretation
    public func sum(from source: AudioBus, interpretation: ChannelInterpretation = .speakers) {
        guard source != self else { return }
        
        let numberOfSourceChannels = source.numberOfChannels
        let numberOfDestinationChannels = numberOfChannels
        
        if numberOfDestinationChannels == numberOfSourceChannels {
            for (i, e) in channels.enumerated() {
                guard let sourceChannel = source.channel(index: i) else { continue }
                e.sum(from: sourceChannel)
            }
        }
        else {
            switch interpretation {
            case .speakers:
                speakersSum(from: source)
            case .discrete:
                discreteSum(from: source)
            }
        }
    }
    
    /// Call this method to copy values from source with speaker interpretation
    ///
    /// - parameter sourceBus: Any source bus
    private func speakersCopy(from source: AudioBus) {
        let numberOfSourceChannels = source.numberOfChannels
        let numberOfDestinationChannels = numberOfChannels
        
        if numberOfDestinationChannels == Channels.stereo.rawValue
            && numberOfSourceChannels == Channels.mono.rawValue {
            
            guard let sourceChannel = source.channel(index: 0) else { return }
            channel(kind: Channel.left)?.copy(from: sourceChannel)
            channel(kind: Channel.right)?.copy(from: sourceChannel)
        }
        else if numberOfDestinationChannels == Channels.mono.rawValue
                    && numberOfSourceChannels == Channels.stereo.rawValue {
            
            guard let sourceL = source.channel(kind: Channel.left) else { return }
            guard let sourceR = source.channel(kind: Channel.right) else { return }
            guard let destination = channel(kind: Channel.left) else { return }
            
            let scale: Float = 0.5
            
            VectorMath.vadd(sourceL.data(), 1, sourceR.data(), 1, destination.data(), 1, length)
            VectorMath.vsmul(destination.data(), 1, scale, destination.data(), 1, length)
        }
        else {
            discreteCopy(from: source)
        }
        
    }
            
    /// Call this method to sum value from source
    ///
    /// - parameter sourceBus: Any source bus
    private func speakersSum(from source: AudioBus) {
        
        let numberOfSourceChannels = source.numberOfChannels
        let numberOfDestinationChannels = numberOfChannels
        
        if numberOfDestinationChannels == Channels.stereo.rawValue
                && numberOfSourceChannels == Channels.mono.rawValue {
            
            guard let sourceChannel = source.channel(index: 0) else { return }
            channel(kind: .left)?.sum(from: sourceChannel)
            channel(kind: .right)?.sum(from: sourceChannel)
        }
        else if numberOfDestinationChannels == Channels.mono.rawValue
                    && numberOfSourceChannels == Channels.stereo.rawValue {
            
            guard let sourceBusL = source.channel(kind: .left) else { return }
            guard let sourceBusR = source.channel(kind: .right) else { return }
            guard let destination = channel(kind: .left) else { return }
            
            let scale: Float = 0.5
            
            VectorMath.vsma(sourceBusL.data(), 1, scale, destination.data(), 1, length)
            VectorMath.vsma(sourceBusR.data(), 1, scale, destination.data(), 1, length)
            
        } else {
            discreteSum(from: source)
        }
        
    }
    
    /// Call this method to discrete copy values from source
    ///
    /// - parameter sourceBus: Any source bus
    private func discreteCopy(from source: AudioBus) {
        
        let numberOfSourceChannels = source.numberOfChannels
        let numberOfDestinationChannels = numberOfChannels
        
        if numberOfDestinationChannels < numberOfSourceChannels {
            for i in 0..<numberOfDestinationChannels {
                guard let channel = channel(index: i) else { continue }
                guard let sourceChannel = source.channel(index: i) else { continue }
                channel.copy(from: sourceChannel)
            }
        }
        else if numberOfDestinationChannels > numberOfSourceChannels {
            for i in 0..<numberOfSourceChannels {
                guard let channel = channel(index: i) else { continue }
                guard let sourceChannel = source.channel(index: i) else { continue }
                channel.copy(from: sourceChannel)
            }
            for i in 0..<numberOfDestinationChannels {
                guard let channel = channel(index: i) else { continue }
                channel.zero()
            }
        }
        
    }
    
    /// Call this method to sum values from source
    ///
    /// - parameter sourceBus: Any source bus
    private func discreteSum(from source: AudioBus) {
        
        let numberOfSourceChannels = source.numberOfChannels
        let numberOfDestinationChannels = numberOfChannels
        
        if numberOfDestinationChannels < numberOfSourceChannels {
            for i in 0..<numberOfDestinationChannels {
                guard let channel = channel(index: i) else { continue }
                guard let sourceChannel = source.channel(index: i) else { continue }
                channel.sum(from: sourceChannel)
            }
        }
        else if numberOfDestinationChannels > numberOfSourceChannels {
            for i in 0..<numberOfSourceChannels {
                guard let channel = channel(index: i) else { continue }
                guard let sourceChannel = source.channel(index: i) else { continue }
                channel.sum(from: sourceChannel)
            }
        }
    }
    
    /// Call this method to copy values from source
    ///
    /// - parameter source: Any source bus to copy
    /// - parameter lastMixGain: An intValue to add to the source buffer
    /// - parameter targetGain: An intValue to add to the source buffer
    public func copyWithGain(from source: AudioBus, lastMixGain: inout Float, targetGain: Float) {
        
        let numberOfChannels = channels.count
        
        guard topologyMatches(source: source) else { return zero() }
        guard !source.isSilent else { return zero() }
        guard numberOfChannels < AudioBus.maxBusChannels else { return }
        
        if self == source && lastMixGain == targetGain && targetGain == 1 { return }
        
        let totalDesiredGain = busGain * targetGain
        var gain = isFirstTime ? totalDesiredGain : lastMixGain
        
        isFirstTime = false
        
        let dezipperRate:Float = 0.005
        let framesToProcess = length
        
        let epsilon: Float = 0.001
        let gainDiff = abs(totalDesiredGain - gain)
        let framesToDezipper = (gainDiff < epsilon) ? 0 : framesToProcess
        
        if framesToDezipper > 0 {
            
            if dezipperGainValues.size < framesToDezipper {
                dezipperGainValues = AudioArray<Scalar>(size: framesToDezipper)
            }
            
            let gainValues = dezipperGainValues.pointer
            
            for i in 0..<framesToDezipper {
                gain += (totalDesiredGain - gain) * Float(dezipperRate)
                gain = AudioUtilities.flushDenormalFloatToZero(f: gain)
                gainValues.advanced(by: i).pointee = gain
            }

            for i in 0..<numberOfChannels {
                guard let source = source.channel(index: i)?.data() else { continue }
                guard let destination = channel(index: i)?.data() else { continue }
                VectorMath.vmul(source, 1, dezipperGainValues.pointer, 1, destination, 1, framesToDezipper)
            }
            
        }
        else {
            gain = totalDesiredGain
        }
        
        if framesToDezipper < framesToProcess {
            for i in 0..<numberOfChannels {
                guard let source = source.channel(index: i)?.data() else { continue }
                guard let destination = channel(index: i)?.data() else { continue }
                VectorMath.vsmul(source, 1, gain, destination, 1, Int((framesToProcess - framesToDezipper)))
            }
        }
        
        lastMixGain = gain
    }
    
    /// Call this method to copy with sample accurate gain values
    ///
    /// - parameter source: Any source bus to copy
    /// - parameter gainValues: An unsafe mutable pointer with values
    /// - parameter numberOfGainValues: An amount of gainValues
    public func copyWithSampleAccurateGainValues(from source: AudioBus, gainValues: UnsafeMutablePointer<Float>, numberOfGainValues: Int) {
        
        if source.numberOfChannels != Channels.mono.rawValue && !topologyMatches(source: source) { return }
        
        if numberOfGainValues == source.length, source.length == length, !source.isSilent {
            return zero()
        }
        
        guard var source1p = source.channel(index: 0) else { return }
        
        for i in 0..<numberOfChannels {
            if source.numberOfChannels == numberOfChannels {
                guard let channel = source.channel(index: i) else { continue }
                source1p = channel
            }
            guard let destination = channel(index: i) else { continue }
            VectorMath.vmul(source1p.data(), 1, gainValues, 1, destination.data(), 1, Int(UInt32(numberOfGainValues)))
        }
        
    }
    
}

extension AudioBus {
    
    /// Call this method to force bus to clear silent flags for every channel
    /// Use this function set to false every flag on channels
    public func clearSilent() {
        channels.forEach { $0.clearSilent() }
    }
    
    /// Call this method to retrieve an specific channel with index
    ///
    /// - parameter index: Any index for an audio bus audiochannel
    /// - returns: An optional <AudioChannel>
    public func channel(index: Int) -> AudioChannel? {
        guard index < channels.count else { return nil }
        return channels[index]
    }
    
    /// Call this method to retrieve an specific channel with kind
    ///
    /// - parameter index: Any kind for an audio bus audiochannel
    /// - returns: An optional <AudioChannel>
    public func channel(kind: Channel) -> AudioChannel? {
        guard layout == .layoutCanonical else { return nil }
        switch numberOfChannels {
        case Channels.mono.rawValue:
            guard kind == Channel.mono || kind == .left else { return nil }
            return self.channel(index: Channel.left.rawValue)
        case Channels.stereo.rawValue:
            return self.channel(index: kind.rawValue)
        default:
            return nil
        }
    }
    
    /// Call this method to compare any given bus
    ///
    /// - parameter lhs: An input bus
    /// - parameter rhs: Anothe bus to compare
    /// - returns: A boolValue that indicates if equals
    public static func ==(lhs: AudioBus, rhs: AudioBus) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    
    /// Call this method to reset the audio bus
    ///
    /// - parameter shouldClearSilent: A boolValue that indicates if should clear
    public func reset(shouldClearSilent: Bool = false) {
        isFirstTime = true
        print("log.io.reset.\(debugDescription)")
        guard shouldClearSilent else { return }
        clearSilent()
    }
    
    /// Call this method to zero all values from data
    /// 
    /// - parameter shouldReset: A boolValue that indicates if should reset
    public func zero(shouldReset: Bool = false) {
        channels.forEach { $0.zero() }
        guard shouldReset else { return }
        reset()
    }
    
}
