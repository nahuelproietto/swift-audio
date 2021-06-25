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

public class AudioRecorderNode: AudioBasicInspectorNode {
    
    public var data: [Scalar] = []
    public var dataSize: Int { return data.count }
    
    public private(set) var isRecording: Bool = false
    
    /// Call this method to initialize an audio recorder node
    ///
    /// - parameter outputChannelCount: A number of channels
    public override init(outputChannelCount: Int) {
        super.init(outputChannelCount: outputChannelCount)
        print("log.io.init.\(debugDescription))")
    }
    
    /// Call this method to process the given node
    ///
    /// - parameter lock: An inout render lock
    /// - parameter framesToProcess: A frame amount to process
    public override func process(lock: inout ContextRenderLock, framesToProcess: Int) {
        guard let input = input(index: 0), let output = output(index: 0) else { return }
        
        guard isInitialized && input.isConnected else { return }
        
        guard let inputBus = input.bus(lock: &lock) else { return }
        guard let inputChannel = inputBus.channel(index: 0) else { return }
        
        let outputBus = output.bus(lock: &lock)
        
        guard inputBus.numberOfChannels > 0 && inputChannel.length >= framesToProcess else { return outputBus.zero() }
        
        if isRecording {
            var channels: [UnsafeMutablePointer<Scalar>] = []
            let numberOfChannels = inputBus.numberOfChannels
            
            for i in 0..<numberOfChannels {
                guard let inputChannel = inputBus.channel(index: i) else { return }
                channels.append(inputChannel.data())
            }
            
            if numberOfChannels == Channels.mono.rawValue {
                for i in 0..<framesToProcess {
                    data.append(channels[0].advanced(by: i).pointee)
                }
            }
            else {
                for i in 0..<framesToProcess {
                    var value: Scalar = 0
                    for j in 0..<numberOfChannels { value += channels[j].advanced(by: i).pointee }
                    value *= Scalar(1.0 / Float(numberOfChannels))
                    data.append(value)
                }
            }
        }
        
        if inputBus.uuid != outputBus.uuid {
            outputBus.copy(from: inputBus)
        }
        
    }
    
    /// Call this method to start recording
    ///
    /// Use this method to put the recording flag so the node can start to process input
    public func startRecording() {
        isRecording = true
    }
    
    /// Call this method to stop recording
    ///
    /// Use this method to put the recording flag in false so the node can stop to process input
    public func stopRecording() {
        isRecording = false
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
        clear()
    }
    
    deinit {
        uninitialize()
        print("log.io.deinit.\(debugDescription))")
    }
    
}

extension AudioRecorderNode {
    
    enum AudioRecorderError: Swift.Error {
        case unknow(String)
    }
    
    /// Call this method to write samples to disk
    ///
    /// - parameter destination: A given url for the destination
    public func writeToDisk(to destination: URL) throws {
        guard let source = getUnsafeData() else { throw AudioRecorderError.unknow("no data available") }
        AudioFileReader.writeBufferToDisk(source: source, lenght: dataSize, destination: destination)
    }
    
    /// Call this method to get the final sample array from recorder
    ///
    /// - returns: An unsafemutable pointer with samples
    public func getUnsafeData() -> UnsafeMutablePointer<Scalar>? {
        return data.withUnsafeBytes{ (rawBufferPointer) in
            let baseAddress = rawBufferPointer.bindMemory(to: Scalar.self).baseAddress
            return UnsafeMutablePointer<Scalar>.init(mutating: baseAddress)
        }
    }
    
    /// Call this method to clear all the recorded samples
    public func clear() {
        data.removeAll()
    }
    
}
