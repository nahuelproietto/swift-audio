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

import IO
import Foundation
import AVFoundation

class AudioTester {
    
    // Use 44.1khz + stereo
    public func startPlayback() {
        let url = URL.projectFolderURL.appendingPathComponent("test.mp3")
        let player = AudioPlayer(contentsOf: url)
        player.gain.setValue(value: 1.0)
        
        let context = AudioContext.shared
        try? context.connect(destination: context.destination, source: player)

        player.play(after: 0, completion: nil)
    }
    
    public func startRecording() {
        
        let context = AudioContext.shared
        requestPermissionIfNeeded()
        
        let recorder = AudioRecorderNode(outputChannelCount: 1)
        context.addAutomaticPullNode(node: recorder)
        
        try? context.connect(destination: recorder, source: context.destination)
        recorder.startRecording()
        
        Timer.scheduledTimer(withTimeInterval: 5, repeats: false, block: { timer in
            recorder.stopRecording()
            let url = URL(fileURLWithPath: "/Users/nahuelproietto/Desktop/test.wav")
            try? recorder.writeToDisk(to: url)
        })
    }
    
    func requestPermissionIfNeeded() {
        if #available(OSX 10.14, *) {
            // 1. Just in case the authorization is not achieved
            guard AVCaptureDevice.authorizationStatus(for: .audio) != .authorized else { return }
            // 2. We call the capture device for request access
            AVCaptureDevice.requestAccess(for: .audio, completionHandler: { result in
                print(result)
            })
        }
    }
    
}


@_silgen_name("Runloop_")
public func Runloop_() {
    assert(Thread.current.isMainThread, "Should only be called from main thread")

    let runloop = RunLoop.current
    let framesPerSecond = 1 / 60.0
    let _ = 1000 / framesPerSecond

    while true {
        let start = DispatchTime.now()
        runloop.run(mode: .default, before: Date() + (1 / framesPerSecond))

        let end = DispatchTime.now()
        let _ = end.uptimeNanoseconds - start.uptimeNanoseconds
    }
}

extension URL {
    
    #if os(Linux) || os(macOS)
    private static let sourceFileURL: URL = URL(fileURLWithPath: #file)
    
    public static let projectFolderURL: URL = { () -> URL in
        return projectHeadIterator(sourceFileURL) ?? sourceFileURL
    }().standardized
    
    private static let executableFolderURL: URL = { () -> URL in
        let sourceFile = sourceFileURL.path
        if let range = sourceFile.range(of: "/checkouts/") {
            return URL(fileURLWithPath: sourceFile[..<range.lowerBound] + "/debug")
        } else if let range = sourceFile.range(of: "/Packages/") {
            return URL(fileURLWithPath: sourceFile[..<range.lowerBound] + "/.build/debug")
        }
        return executableURL.appendingPathComponent("..")
        
    }().standardized
    
    public static let executableURL: URL = { () -> URL in
        #if os(Linux)
            return URL(fileURLWithPath: "/proc/self/exe")
        #else
            return (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
        #endif
    }().resolvingSymlinksInPath()
    #endif
    
    #if os(Linux) || os(macOS)
    private static let projectHeadIterator = { (startingDir: URL) -> URL? in
        let fileManager = FileManager()
        var startingDir = startingDir.appendingPathComponent("dummy")
        
        repeat {
            startingDir.appendPathComponent("..")
            startingDir.standardize()
            let packageFilePath = startingDir.appendingPathComponent("Package.swift").path
            
            if fileManager.fileExists(atPath: packageFilePath) {
                return startingDir
            }
        } while startingDir.path != "/"
        
        return nil
    }
    #endif
    
}

let tester = AudioTester()
tester.startPlayback()

Runloop_()
