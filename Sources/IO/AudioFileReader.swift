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

public class AudioFileReader: NSObject {
    
    /// Call this method to make a bus using a wave file
    ///
    /// - parameter url: A reference to the file
    /// - returns: An optional audio bus
    public static func makeBusFromFileWAV(url: URL) -> AudioBus? {
        guard let source = AudioDecodable<AudioDecodable.WAV>().decode(from: url) else { return nil }
        return makeBusFromMemory(source: source)
    }
    
    /// Call this method to make a bus using a wave file data
    ///
    /// - parameter data: A reference to the data
    /// - returns: An optional audio bus
    public static func makeBusFromDataWAV(data: Data) -> AudioBus? {
        guard let source = AudioDecodable<AudioDecodable.WAV>().decode(from: data) else { return nil }
        return makeBusFromMemory(source: source)
    }
    
    /// Call this method to make a bus using a mp3 file
    ///
    /// - parameter url: A reference to the file
    /// - returns: An optional audio bus
    public static func makeBusFromFileMP3(url: URL) -> AudioBus? {
        guard let source = AudioDecodable<AudioDecodable.MP3>().decode(from: url) else { return nil }
        return makeBusFromMemory(source: source)
    }
    
    /// Call this method to make a bus using a mp3 file
    ///
    /// - parameter data: A reference to the file
    /// - returns: An optional audio bus
    public static func makeBusFromDataMP3(data: Data) -> AudioBus? {
        guard let source = AudioDecodable<AudioDecodable.MP3>().decode(from: data) else { return nil }
        return makeBusFromMemory(source: source)
    }
    
    deinit {
        print("log.io.deinit.\(debugDescription)")
    }
    
}

extension AudioFileReader {
    
    /// Call this method to make a bus using an audio file
    ///
    /// - parameter url: A reference to the file
    /// - returns: An optional audio bus
    public static func makeBusFromFile(url: URL) -> AudioBus? {
        switch url.streamFormat() {
        case .mp3: return makeBusFromFileMP3(url: url)
        case .wav: return makeBusFromFileWAV(url: url)
        default: return nil
        }
    }
    
    /// Call this method to make a bus using data
    ///
    /// - parameter data: Any audio data
    /// - parameter format: A given audio format
    public static func makeBusFromFileData(data: Data, format: URL.Stream) -> AudioBus? {
        switch format {
        case .mp3: return makeBusFromDataMP3(data: data)
        case .wav: return makeBusFromDataWAV(data: data)
        default: return nil
        }
    }
    
}

extension AudioFileReader {
    
    /// Call this method to make a bus using a wave file data
    ///
    /// - parameter data: A reference to the data
    /// - returns: An optional audio bus
    public static func makeDataFromMonoBus(source: AudioBus) -> Data? {
        let stream = UnsafeRawAudioStream<Scalar>(capacity: source.length, numberOfChannels: 1)
        guard let source = source.channel(index: 0) else { return nil }
        stream.copy(from: source.data(), lenght: source.length)
        return AudioEncodable<AudioEncodable.WAV>().encode(stream: stream)
    }
    
    /// Call this method to make a bus using a wave file
    ///
    /// - parameter url: A reference to the file
    /// - returns: An optional audio bus
    public static func makeDataFromMonoBuffer(source: UnsafeMutablePointer<Scalar>, lenght: Int) -> Data? {
        let stream = UnsafeRawAudioStream<Scalar>(capacity: lenght, numberOfChannels: 1)
        stream.copy(from: source, lenght: lenght)
        return AudioEncodable<AudioEncodable.WAV>().encode(stream: stream)
    }
    
    /// Call this method to make a bus using a wave file data
    ///
    /// - parameter data: A reference to the data
    /// - returns: An optional audio bus
    public static func writeBusToDisk(source: AudioBus, destination: URL) {
        let stream = UnsafeRawAudioStream<Scalar>(capacity: source.length, numberOfChannels: 1)
        guard let source = source.channel(index: 0) else { return }
        stream.copy(from: source.data(), lenght: source.length)
        return AudioEncodable<AudioEncodable.WAV>().encode(stream: stream, to: destination)
    }
    
    /// Call this method to make a bus using a wave file data
    ///
    /// - parameter data: A reference to the data
    /// - returns: An optional audio bus
    public static func writeBufferToDisk(source: UnsafeMutablePointer<Scalar>, lenght: Int, destination: URL) {
        let stream = UnsafeRawAudioStream<Scalar>(capacity: lenght, numberOfChannels: 1)
        stream.copy(from: source, lenght: lenght)
        return AudioEncodable<AudioEncodable.WAV>().encode(stream: stream, to: destination)
    }
    
}

extension AudioFileReader {
    
    /// Call this method to create a bus using an unsafe raw audio stream
    ///
    /// - parameter source: A reference to the audio stream
    /// - returns: An optional audio bus
    public static func makeBusFromMemory(source: UnsafeRawAudioStream<Scalar>) -> AudioBus {
        guard source.interleaved else { return makeBusFromNonInterleaved(source: source) }
        return makeBusFromInterleaved(source: source)
    }
    
    /// Call this method to create a bus using an unsafe raw audio stream @interleaved
    ///
    /// - parameter source: A reference to the audio stream
    /// - returns: An optional audio bus
    static func makeBusFromInterleaved(source: UnsafeRawAudioStream<Scalar>) -> AudioBus {
        let numFramesPerChannel = source.bufferSize / source.channels
        let destination = AudioBus(numberOfChannels: source.channels, lenght: numFramesPerChannel)
        destination.sampleRate = source.sampleRate

        var numOfSample: Int = 0
        for j in 0..<numFramesPerChannel {
            for k in 0..<source.channels {
                guard let channel = destination.channel(index: k) else { continue }
                channel.data()[j] = source.buffer[numOfSample]
                numOfSample += 1
            }
        }
        
        return destination
    }
    
    /// Call this method to create a bus using an unsafe raw audio stream @non-interleaved
    ///
    /// - parameter source: A reference to the audio stream
    /// - returns: An optional audio bus
    static func makeBusFromNonInterleaved(source: UnsafeRawAudioStream<Scalar>) -> AudioBus {
        let numFramesPerChannel = source.bufferSize / source.channels
        let destination = AudioBus(numberOfChannels: source.channels, lenght: numFramesPerChannel)
        destination.sampleRate = source.sampleRate
        
        var numOfSample: Int = 0
        for j in 0..<numFramesPerChannel {
            for k in 0..<source.channels {
                guard let channel = destination.channel(index: j) else { continue }
                channel.data()[j] = source.buffer.advanced(by: j + (k * numFramesPerChannel)).pointee
                numOfSample += 1
            }
        }
        return destination
    }
    
}

