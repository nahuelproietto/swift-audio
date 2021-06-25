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

public class AudioEncoder: NSObject {
    
    internal var channels: Int
    internal var samplerate: Int
    
    /// Call this method to initialize an audio decoder
    ///
    /// - parameter samplerate: An intValue to configure the decoding
    /// - parameter channels: A given number for the channels
    public required init(samplerate: Int = AudioContext.defaultSampleRate, channels: Int = 1) {
        self.channels = channels
        self.samplerate = samplerate
        super.init()
    }
    
    /// Call this method to decode from url with an accepted format
    ///
    /// - parameter url: Any given url with data
    /// - returns: An optional audio stream
    open func encode(stream: UnsafeRawAudioStream<Scalar>, to destination: URL) { }
    
    /// Call this method to decode from data with an accepted format
    ///
    /// - parameter data: Any given data
    /// - returns: An optional audio stream
    open func encode(stream: UnsafeRawAudioStream<Scalar>) -> Data? {
        return nil
    }
    
}

public class AudioEncodable<T: AudioEncoder>: AudioEncoder {
    
    /// Call this method to decode from url with an accepted format
    ///
    /// - parameter url: Any given url with data
    /// - returns: An optional audio stream
    override public func encode(stream: UnsafeRawAudioStream<Scalar>, to destination: URL) {
        return T().encode(stream: stream, to: destination)
    }
    
    /// Call this method to decode from data with an accepted format
    ///
    /// - parameter data: Any given data
    /// - returns: An optional audio stream
    override public func encode(stream: UnsafeRawAudioStream<Scalar>) -> Data? {
        return T().encode(stream: stream)
    }
    
    deinit {
        print("log.io.deinit.\(debugDescription)")
    }
    
    public class WAV: AudioEncoder {
        
        private var encoder = ma_encoder()
        
        /// Call this method to decode from url with an accepted format
        ///
        /// - parameter url: Any given url with data
        /// - returns: An optional audio stream
        public override func encode(stream: UnsafeRawAudioStream<Scalar>, to destination: URL) {
            var config = ma_encoder_config_init(ma_resource_format_wav, ma_format_f32, UInt32(stream.channels), UInt32(samplerate))
            
            let cString = destination.path.makeCString()
            
            ma_encoder_init_file(cString, &config, &encoder)
            ma_encoder_write_pcm_frames(&encoder, stream.buffer, ma_uint64(stream.bufferSize))
            ma_encoder_uninit(&encoder)
            
            cString.deallocate()
            
        }
        
        /// Call this method to decode from data with an accepted format
        ///
        /// - parameter data: Any given data
        /// - returns: An optional audio stream
        public override func encode(stream: UnsafeRawAudioStream<Scalar>) -> Data? {
            let temporaryURL: URL = URL(fileURLWithPath: "/Users/nahuelproietto/Desktop/sample.wav")
            encode(stream: stream, to: temporaryURL)
            return try? Data(contentsOf: temporaryURL)
        }
        
    }

}

