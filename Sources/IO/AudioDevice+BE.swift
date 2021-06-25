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

#if os(macOS)
import AVFoundation
#endif

//MARK:

class AudioDeviceMiniAudio: AudioHardwareDeviceNode {
        
    private var inputbus: AudioBus
    private var renderbus: AudioBus
    
    private var device: ma_device
    private let renderQuantum = AudioNode.processingSizeInFrames
    private let requiredRenderQuantum = AudioContext.defaultSampleRate
    private var listener = AudioDeviceMiniAudioListener()
    private var g_context: ma_context = ma_context()
    
    private var inputRingBuffer: UnsafeBuffer<Scalar>
    
    var authoritativeDeviceSampleRateAtRuntime: Int = AudioContext.defaultSampleRate
    
    public typealias AudioDeviceMiniAudioRenderCallback = @convention(c) (
        Optional<UnsafeMutablePointer<ma_device>>,
        Optional<UnsafeMutableRawPointer>,
        Optional<UnsafeRawPointer>,
        UInt32) -> ()
    
    /// Use this render callback to feed the device buffer with sample data
    static var renderCallback: AudioDeviceMiniAudioRenderCallback =  { device, output, input, frameCount in
        guard let device = device?.pointee else { return }
        let ad = unsafeBitCast(device.pUserData, to: AudioDeviceMiniAudio.self)
        
        let inRef = input?.assumingMemoryBound(to: Scalar.self)
        let outRef = output?.bindMemory(to: Scalar.self, capacity: Int(frameCount) * ad.outputConfig.channels)
        
        memset(outRef, 0, MemoryLayout<Scalar>.size * Int(frameCount) * ad.outputConfig.channels)
        ad.process(numberOfFrames: Int(frameCount), outputBuffer: outRef, inputBuffer: inRef)
    }

    /// Call this method to initialize a miniaudio device
    ///
    /// - parameter callback: A render callback
    /// - parameter outputConfig: A stream info for output
    /// - parameter inputConfigu: A stream info for input
    public override init(context: AudioContext, configuration: AudioDeviceConfiguration) {
        
        let sample_rate = configuration.output.samplerate
        authoritativeDeviceSampleRateAtRuntime = sample_rate
        
        device = ma_device()
        
        renderbus = AudioBus(numberOfChannels: configuration.output.channels, lenght: renderQuantum)
        renderbus.sampleRate = sample_rate
        
        inputbus = AudioBus(numberOfChannels: configuration.input.channels, lenght: renderQuantum)
        inputbus.sampleRate = sample_rate

        inputRingBuffer = UnsafeBuffer<Scalar>.init(capacity: requiredRenderQuantum*2)
        
        super.init(context: context, configuration: configuration)
        
        guard ma_context_init(nil, 0, nil, &g_context) == MA_SUCCESS else { return }

        var deviceConfiguration = ma_device_config_init(ma_device_type_duplex)
        
        deviceConfiguration.playback.format = ma_format_f32
        deviceConfiguration.playback.channels = ma_uint32(configuration.output.channels)
        deviceConfiguration.sampleRate = ma_uint32(configuration.output.samplerate)
        deviceConfiguration.capture.format = ma_format_f32
        deviceConfiguration.capture.channels = ma_uint32(configuration.input.channels)
        deviceConfiguration.dataCallback = AudioDeviceMiniAudio.renderCallback
        deviceConfiguration.pUserData = Unmanaged.passUnretained(self).toOpaque()
        deviceConfiguration.performanceProfile = ma_performance_profile_conservative
        
        guard ma_device_init(&g_context, &deviceConfiguration, &device) == MA_SUCCESS else { return }        
    }
    
    /// Call this method to start rendering
    /// Use this method to start the miniaudio I/O engine
    public override func start() {
        guard ma_device_start(&device) == MA_SUCCESS else { return print("error while starting audio") }
        print("log.io.start.\(debugDescription)")
    }
    
    var numberOfRemainingFrames: Int = 0
    
    /// Callback for audio rendering, this method is called from the render callback
    ///
    /// - parameter numberOfFrames: A frameCount
    /// - parameter outputBuffer: A pointer to the output buffers
    /// - parameter inputBuffer: A pointer to the input buffer
    public func process(numberOfFrames: Int, outputBuffer: UnsafeMutablePointer<Scalar>?, inputBuffer: UnsafePointer<Scalar>?) {

        let numberOfInputs = inputConfig.channels
        let numberOfOutputs = outputConfig.channels
        
        guard let inputBuffer = inputBuffer else { return }
        guard let outputBuffer = outputBuffer else { return }
        
        guard numberOfInputs >= Channels.mono.rawValue else { return }
        guard numberOfOutputs >= Channels.mono.rawValue else { return }

        var numberOfFrames_ = numberOfFrames
        var numberOfOutputPointer: Int = 0
        
        inputRingBuffer.push(inputBuffer, amount: numberOfFrames)
        guard inputRingBuffer.availableForReading > renderQuantum*4 else { return } // 1024
        
        let leftChannel = renderbus.channel(index: Channel.left.rawValue)
        let rigthChannel = renderbus.channel(index: Channel.right.rawValue)
        let inputChannel = inputbus.channel(index: Channel.left.rawValue)
        
        while numberOfFrames_ > 0 {
            
            if numberOfRemainingFrames > 0 {
                
                let numberOfSamples = min(numberOfRemainingFrames, numberOfFrames)
                let index = renderQuantum - numberOfSamples
                
                switch renderbus.numberOfChannels {
                case Channels.stereo.rawValue:
                    guard let l = leftChannel else { continue }
                    guard let r = rigthChannel else { continue }
                    outputBuffer[numberOfOutputPointer] = l.data()[index]
                    outputBuffer[numberOfOutputPointer+1] = r.data()[index]
                    numberOfOutputPointer += 2
                case Channels.mono.rawValue:
                    guard let l = leftChannel else { continue }
                    outputBuffer[numberOfOutputPointer] = l.data()[index]
                    numberOfOutputPointer += 1
                default:
                    break
                }
                
                numberOfRemainingFrames -= 1
                numberOfFrames_ -= 1
                
            }
            else {
                
                if inputRingBuffer.availableForReading >= renderQuantum {
                    switch numberOfInputs {
                    case Channels.mono.rawValue:
                        if let input = inputChannel, let pointer = inputRingBuffer.pop(amount: renderQuantum) {
                            memcpy(input.data(), pointer, MemoryLayout<Scalar>.size * renderQuantum)
                            pointer.deallocate()
                        }
                    default:
                        print("log.io.no.input")
                    }
                }
                
                let frame = lastSampling.value.frame
                let sampleframe = frame + renderQuantum
                let samplerate = authoritativeDeviceSampleRateAtRuntime
                let time = TimeInterval(lastSampling.value.frame) / TimeInterval(lastSampling.value.samplerate)
                let info = RenderQuantumDesc(sampleframe, time, samplerate)
                
                // We need to pull a fixed size of renderQuantum and push those samples to the buffer
                // Since the expected number of frames could be variable we need to use a ring buffer
                render(source: inputbus, destination: renderbus, framesToProcess: renderQuantum, info: info)
                numberOfRemainingFrames = renderQuantum
            }
            
        }
        
    }
    
    /// Call this method to stop rendering
    /// Use this function to stop the miniaudio I/O engine
    public override func stop() {
        guard ma_device_stop(&device) == MA_SUCCESS else { return print("error while stoping audio") }
        print("log.io.stop.\(debugDescription)")
    }
    
    /// Call this method to get the default audio device index
    ///
    /// - returns: An audio device index to configure the default input
    override func getDefaultInputAudioDeviceIndex() -> AudioDeviceIndex {
        return listener.getDefaultInputAudioDeviceIndex()
    }
    
    /// Call this method to get the default audio device output index
    ///
    /// - returns: An audio device index to configure the default output
    override func getDefaultOutputAudioDeviceIndex() -> AudioDeviceIndex {
        return listener.getDefaultOutputAudioDeviceIndex()
    }
    
    deinit {
        print("log.io.deinit.\(debugDescription)")
    }
    
}

//MARK:

class AudioDeviceMiniAudioListener: NSObject {
    
    private var probed: Bool = false
    private var devices: [AudioDeviceDescription] = [AudioDeviceDescription]()
    private var g_context: ma_context = ma_context()
    
    /// Call this method to get an array of audio device descriptions
    ///
    /// - returns: An array of audio devices with supported configurations
    public func listAudioDevice() -> [AudioDeviceDescription] {
        
        guard !probed else { return devices }
        
        probed = true
        
        var result = ma_result()
        var pPlaybackDeviceInfos: UnsafeMutablePointer<ma_device_info>?
        var playbackDeviceCount: ma_uint32 = 0
        var pCaptureDeviceInfos: UnsafeMutablePointer<ma_device_info>?
        var captureDeviceCount: ma_uint32 = 0
        
        pPlaybackDeviceInfos = UnsafeMutablePointer<ma_device_info>.allocate(capacity: 1)
        pCaptureDeviceInfos = UnsafeMutablePointer<ma_device_info>.allocate(capacity: 1)
        
        result = ma_context_get_devices(
            &g_context,
            &pPlaybackDeviceInfos,
            &playbackDeviceCount,
            &pCaptureDeviceInfos,
            &captureDeviceCount)
        
        if result != MA_SUCCESS { return [] }
        
        guard playbackDeviceCount > 0 else { return devices }
        
        for i in 0...Int(playbackDeviceCount)-1 {
            
            guard let playbackCurrent = pPlaybackDeviceInfos?.advanced(by: i) else { continue }
            
            let identifier = withUnsafePointer(to: playbackCurrent.pointee.name) {
                $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: $0)) {
                    String(cString: $0)
                }
            }
            
            if (ma_context_get_device_info(
                    &g_context,
                    ma_device_type_playback,
                    &playbackCurrent.pointee.id,
                    ma_share_mode_shared,
                    &playbackCurrent.pointee) != MA_SUCCESS) {
                continue
            }
            
            
            let maxSampleRate = Float(playbackCurrent.advanced(by: i).pointee.minSampleRate)
            let minSampleRate = Float(playbackCurrent.advanced(by: i).pointee.maxSampleRate)
            let supported_samplerates: [Float] = [maxSampleRate, minSampleRate]
            
            let info: AudioDeviceDescription = AudioDeviceDescription(
                index: Int(devices.count),
                identifier: identifier,
                nuoutput_channles: Int(playbackCurrent.pointee.maxChannels),
                nuinput_channels: 0,
                supported_samplerates: supported_samplerates,
                nominal_samplerate: maxSampleRate,
                is_default_output: i == 0,
                is_default_input: false)
            
            devices.append(info)
            
        }
        
        guard captureDeviceCount > 0 else { return devices }
        
        for i in 0...Int(captureDeviceCount)-1 {
            
            guard let captureCurrent = pCaptureDeviceInfos?.advanced(by: i) else { continue }
            
            let identifier = withUnsafePointer(to: captureCurrent.pointee.name) {
                $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: $0)) {
                    String(cString: $0)
                }
            }
            
            if (ma_context_get_device_info(
                    &g_context,
                    ma_device_type_playback,
                    &captureCurrent.pointee.id,
                    ma_share_mode_shared,
                    &captureCurrent.pointee) != MA_SUCCESS) {
                continue
            }
            
            let maxSampleRate = Float(captureCurrent.advanced(by: i).pointee.minSampleRate)
            let minSampleRate = Float(captureCurrent.advanced(by: i).pointee.maxSampleRate)
            let supported_samplerates: [Float] = [maxSampleRate, minSampleRate]
            
            let info: AudioDeviceDescription = AudioDeviceDescription(
                index: Int(devices.count),
                identifier: identifier,
                nuoutput_channles: Int(captureCurrent.pointee.maxChannels),
                nuinput_channels: 0,
                supported_samplerates: supported_samplerates,
                nominal_samplerate: maxSampleRate,
                is_default_output: i == 0,
                is_default_input: false)
            
            devices.append(info)
        }
    
        self.printAudioDevices()
        
        return devices
    }
    
    /// Call this method to get the default audio device index
    ///
    /// - returns: An audio device index to configure the default input
    public func getDefaultInputAudioDeviceIndex() -> AudioDeviceMiniAudio.AudioDeviceIndex {
        let devices = listAudioDevice()
        for (i, e) in devices.enumerated() {
            guard e.is_default_input else { continue }
            return AudioDeviceMiniAudio.AudioDeviceIndex(index: i, valid: true)
        }
        return AudioDeviceMiniAudio.AudioDeviceIndex(index: 0, valid: false)
    }
    
    /// Call this method to get the default audio device output index
    ///
    /// - returns: An audio device index to configure the default output
    public func getDefaultOutputAudioDeviceIndex() -> AudioDeviceMiniAudio.AudioDeviceIndex {
        let devices = listAudioDevice()
        for (i, e) in devices.enumerated() {
            guard e.is_default_output else { continue }
            return AudioDeviceMiniAudio.AudioDeviceIndex(index: i, valid: true)
        }
        return AudioDeviceMiniAudio.AudioDeviceIndex(index: 0, valid: false)
    }
    
    /// Call this method ot print an audio device information
    internal func printAudioDevices() {
        for (_, e) in devices.enumerated() {
            print("----------------------\n")
            print("index:\(e.index)")
            print("identifier: \(e.identifier)")
            print("samplerate: \(e.nominal_samplerate)")
            print("ins: \(e.nuinput_channels)")
            print("outs: \(e.nuoutput_channles)")
            print("is_default_output: \(e.is_default_output)")
        }
    }
    
}
