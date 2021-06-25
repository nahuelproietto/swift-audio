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

public class AudioDecoder: NSObject {
    
    internal var channels: Int
    internal var samplerate: Int
    
    /// Call this method to initialize an audio decoder
    ///
    /// - parameter samplerate: An intValue to configure the decoding
    /// - parameter channels: A given number for the channels
    public required init(samplerate: Int = AudioContext.defaultSampleRate, channels: Int = 2) {
        self.channels = channels
        self.samplerate = samplerate
        super.init()
    }
    
    /// Call this method to decode from url with an accepted format
    ///
    /// - parameter url: Any given url with data
    /// - returns: An optional audio stream
    open func decode(from url: URL) -> UnsafeRawAudioStream<Scalar>? {
        return nil
    }
    
    /// Call this method to decode from data with an accepted format
    ///
    /// - parameter data: Any given data
    /// - returns: An optional audio stream
    open func decode(from data: Data) -> UnsafeRawAudioStream<Scalar>? {
        return nil
    }
    
}

public class AudioDecodable<T: AudioDecoder>: AudioDecoder {
    
    /// Call this method to decode from url with an accepted format
    ///
    /// - parameter url: Any given url with data
    /// - returns: An optional audio stream
    override public func decode(from url: URL) -> UnsafeRawAudioStream<Scalar>? {
        return T().decode(from: url)
    }
    
    /// Call this method to decode from data with an accepted format
    ///
    /// - parameter data: Any given data
    /// - returns: An optional audio stream
    override public func decode(from data: Data) -> UnsafeRawAudioStream<Scalar>? {
        return T().decode(from: data)
    }
    
    deinit {
        print("log.io.deinit.\(debugDescription)")
    }
    
    public class WAV: AudioDecoder {
        
        private var decoder = ma_decoder()
        
        /// Call this method to decode from url with an accepted format
        ///
        /// - parameter url: Any given url with data
        /// - returns: An optional audio stream
        public override func decode(from url: URL) -> UnsafeRawAudioStream<Float32>? {

            var config = ma_decoder_config_init(ma_format_f32, UInt32(channels), UInt32(samplerate))
            
            let cString = url.path.makeCString()
            ma_decoder_init_file_wav(cString, &config, &decoder)
            
            let bufferSize = ma_decoder_get_length_in_pcm_frames(&decoder) * UInt64(channels)
            
            let stream = UnsafeRawAudioStream<Float32>(capacity: Int(bufferSize))
            stream.channels = Int(decoder.outputChannels)
            stream.sampleRate = Int(decoder.outputSampleRate)
            
            ma_decoder_read_pcm_frames(&decoder, stream.buffer, ma_uint64(bufferSize))
            ma_decoder_uninit(&decoder);

            cString.deallocate()
            
            return stream
        }
        
        /// Call this method to decode from data with an accepted format
        ///
        /// - parameter data: Any given data
        /// - returns: An optional audio stream
        public override func decode(from data: Data) -> UnsafeRawAudioStream<Scalar>? {
            let bufferSize = data.count
            
            return data.withUnsafeBytes{ (rawBufferPointer) in
                guard let baseAddress = rawBufferPointer.bindMemory(to: Scalar.self).baseAddress else { return nil }
                
                var config = ma_decoder_config_init(ma_format_f32, UInt32(channels), UInt32(samplerate))
                ma_decoder_init_memory(baseAddress, bufferSize, &config, &decoder)
                
                let bufferSize = ma_decoder_get_length_in_pcm_frames(&decoder) * UInt64(channels)
                
                let stream = UnsafeRawAudioStream<Scalar>(capacity: Int(bufferSize))
                stream.channels = Int(decoder.outputChannels)
                stream.sampleRate = Int(decoder.outputSampleRate)
                
                ma_decoder_read_pcm_frames(&decoder, stream.buffer, ma_uint64(bufferSize))
                ma_decoder_uninit(&decoder);

                return stream
            }
        }
        
    }

    public class MP3: AudioDecoder {
        
        private var decoder = ma_decoder()
        
        /// Call this method to decode from url with an accepted format
        ///
        /// - parameter url: Any given url with data
        /// - returns: An optional audio stream
        public override func decode(from url: URL) -> UnsafeRawAudioStream<Scalar>? {
            
            var config = ma_decoder_config_init(ma_format_f32, UInt32(channels), UInt32(samplerate))
            
            let cString = url.path.makeCString()
            ma_decoder_init_file_mp3(cString, &config, &decoder)
            
            let bufferSize = ma_decoder_get_length_in_pcm_frames(&decoder) * UInt64(channels)
            
            let stream = UnsafeRawAudioStream<Scalar>(capacity: Int(bufferSize))
            stream.channels = Int(decoder.outputChannels)
            stream.sampleRate = Int(decoder.outputSampleRate)
            
            ma_decoder_read_pcm_frames(&decoder, stream.buffer, ma_uint64(bufferSize))
            ma_decoder_uninit(&decoder);
            
            cString.deallocate()
            
            return stream
        }
        
        /// Call this method to decode from data with an accepted format
        ///
        /// - parameter data: Any given data
        /// - returns: An optional audio stream
        public override func decode(from data: Data) -> UnsafeRawAudioStream<Scalar>? {
            let bufferSize = data.count
            
            return data.withUnsafeBytes{ (rawBufferPointer) in
                guard let baseAddress = rawBufferPointer.bindMemory(to: Scalar.self).baseAddress else { return nil }
                
                var config = ma_decoder_config_init(ma_format_f32, UInt32(channels), UInt32(samplerate))
                ma_decoder_init_memory_mp3(baseAddress, bufferSize, &config, &decoder)
                
                let bufferSize = ma_decoder_get_length_in_pcm_frames(&decoder) * UInt64(channels)
                
                let stream = UnsafeRawAudioStream<Scalar>(capacity: Int(bufferSize))
                stream.channels = Int(decoder.outputChannels)
                stream.sampleRate = Int(decoder.outputSampleRate)
                
                ma_decoder_read_pcm_frames(&decoder, stream.buffer, ma_uint64(bufferSize))
                ma_decoder_uninit(&decoder);

                return stream
            }
        }
        
    }
    
}
