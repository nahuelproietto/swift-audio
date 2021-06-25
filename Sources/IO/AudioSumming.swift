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

var s_dirtySummingJunctions = Queue<AudioSummingJunction>()

public class AudioSummingJunction: NSObject {
    
    private var mutex = UnsafeMutex()
    private var renderingStateNeedUpdating: Bool = false

    public var connectedOutputs: [AudioNodeOutput] = []
    public var renderingOutputs: [AudioNodeOutput] = []
    
    public var isConnected : Bool {
        return numberOfConnections() > 0
    }
    
    /// Call this method to initialize the current audio summing junction
    public override init() {
        super.init()
        renderingStateNeedUpdating = false
    }
    
    /// Call this method to notify every node that audio input has updated
    ///
    /// - parameter lock: A given context render lock
    open func didUpdate(lock: inout ContextRenderLock) { }
    
    /// Call this method to get the number of connections
    ///
    /// - returns: An intValue that indicates the number of connected outputs
    public func numberOfConnections() -> Int {
        return connectedOutputs.count
    }
    
    /// Call this method to get the number of rendering connections
    ///
    /// - parameter lock: A given context render lock
    /// - returns: An intValue that indicates the number of rendering conntections
    public func numberOfRenderingConnections(lock: inout ContextRenderLock) -> Int {
        return renderingOutputs.count
    }
    
    /// Call this method to get a rendering output at index
    ///
    /// - parameter lock: A given context render lock
    /// - returns: An optional audio node output
    public func renderingOutput(lock: inout ContextRenderLock, i: Int) -> AudioNodeOutput? {
        return (i < renderingOutputs.count) ? renderingOutputs[i] : nil
    }
    
    /// Call this method to connect an output to the current summing junction
    ///
    /// - parameter output: A given audio node output
    public func junctionConnectOutput(output: AudioNodeOutput) {
        defer { mutex.unlock() }; mutex.lock();
        guard let _ = connectedOutputs.firstIndex(where: { $0.uuid == output.uuid }) else {
            renderingStateNeedUpdating = true
            return connectedOutputs.append(output)
        }
    }
    
    /// Call this method to disconnect an output to the current summing junction
    ///
    /// - parameter output: A given audio node output
    public func junctionDisconnectOutput(output: AudioNodeOutput) {
        defer { mutex.unlock() }; mutex.lock();
        guard let firstIndex = connectedOutputs.firstIndex(where: { $0.uuid == output.uuid }) else { return }
        connectedOutputs.remove(at: firstIndex)
    }
    
    /// Call this method to disconnect all outputs from summing junction
    public func junctionDisconnectAllOutputs() {
        defer { mutex.unlock() }; mutex.lock();
        connectedOutputs.removeAll()
    }
    
    /// Call this method to change the rendering state needs updating flag
    ///
    /// - parameter lock: A given context render lock
    public func changedOutputs(lock: inout ContextGraphLock) {
        if !renderingStateNeedUpdating {
            renderingStateNeedUpdating = true
        }
    }
    
    /// Call this method to update the rendering state
    ///
    /// - parameter lock: A given context render lock
    public func updateRenderingState(lock: inout ContextRenderLock) {
        defer { mutex.unlock() }; mutex.lock();
        if renderingStateNeedUpdating {
            renderingOutputs.removeAll()
            for (_,e) in connectedOutputs.enumerated() {
                renderingOutputs.append(e)
                e.updateRenderingState(lock: &lock)
            }
            didUpdate(lock: &lock)
            renderingStateNeedUpdating = false
        }
    }
    
    /// Call this method to update the dirty status
    public func setDirty() {
        renderingStateNeedUpdating = true
    }
    
    /// Call this method to handle the dirty audio summing junction
    ///
    /// - parameter lock: A given context render lock
    static func handleDirtyAudioSummingJunctions(lock: inout ContextRenderLock) {
        repeat {
            guard let asj = s_dirtySummingJunctions.dequeue() else { continue }
            asj.updateRenderingState(lock: &lock)
        } while !s_dirtySummingJunctions.isEmpty
    }
    
    /// Call this method know if an output is connected to the current audio summing junction
    ///
    /// - parameter output: A given output
    public func isConnected(output: AudioNodeOutput) -> Bool {
        defer { mutex.unlock() }; mutex.lock();
        for (_, e) in connectedOutputs.enumerated() {
            if output.uuid == e.uuid { return true }
        }
        return false
    }
    
    deinit {
        print("log.io.deinit.\(debugDescription)")
    }
    
}
