import CoreAudio
import AudioToolbox

// Phase 47 Plan 02 — the ONLY place AudioDeviceID / CoreAudio device-list types are touched.
// Mirrors this codebase's other IOKit/IOBluetooth-style device monitors' "one fragile system
// surface, one file" convention and VolumeReader.swift's guarded-call discipline (safe default,
// never force-unwrap).
//
// Pitfall 6: this monitor is DELIBERATELY independent from the existing device-connect activity
// monitor — it never reads that monitor's state to build/filter its device list, and this plan
// never modifies that file or VolumeReader.swift. The two monitors are independent event
// sources; any reconciliation between them is a future display-layer concern, not this file's.
@MainActor
final class AudioOutputMonitor {
    // Pitfall 5: idempotent start() guard — never double-register the listener blocks.
    private nonisolated(unsafe) var running = false
    // Retained so stop() can remove the SAME block reference — CoreAudio's block-listener API
    // requires passing back the identical block for AudioObjectRemovePropertyListenerBlock to
    // succeed. This project's equivalent of the existing device-connect monitor's token
    // retention (Pitfall 4's retention discipline generalized).
    private nonisolated(unsafe) var listenerBlock: AudioObjectPropertyListenerBlock?
    private let onDevicesChanged: ([AudioOutputDevice]) -> Void

    init(onDevicesChanged: @escaping ([AudioOutputDevice]) -> Void) {
        self.onDevicesChanged = onDevicesChanged
    }

    func start() {
        guard !running else { return }   // Pitfall 5: idempotent — never double-register.
        running = true

        // CRITICAL: AudioObjectAddPropertyListenerBlock delivers this block on a CoreAudio-
        // internal dispatch queue (nil inDispatchQueue), NOT the main thread. @MainActor on this
        // class does NOT retroactively main-isolate a system-framework-invoked callback — MUST
        // hop to main ourselves before touching stored state or calling onDevicesChanged, exactly
        // like this codebase's other off-main system callbacks already do (Pitfall 5).
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onDevicesChanged(self.currentDevices())
            }
        }
        listenerBlock = block

        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, nil, block)

        var defaultOutputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddr, nil, block)

        // Give callers an initial snapshot without waiting for the first system event — already
        // on main since start() is @MainActor.
        onDevicesChanged(currentDevices())
    }

    // Full teardown (mirrors this codebase's other monitors' stop()): remove both registered listeners so no
    // callback can outlive this monitor's owner. nonisolated so a future owner's nonisolated
    // deinit can call it, per this project's established convention.
    nonisolated func stop() {
        if let block = listenerBlock {
            var devicesAddr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, nil, block)

            var defaultOutputAddr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddr, nil, block)
        }
        listenerBlock = nil
        running = false
    }

    // Re-implemented from VolumeReader.swift:14-24's exact literal pattern — that function is
    // `private` to its own file, so it is NOT imported or modified here (Anti-Pattern 3).
    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var deviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var outputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &outputAddr, 0, nil, &deviceIDSize, &deviceID) == noErr
        else { return nil }
        return deviceID
    }

    // Guarded "get size, then get data" two-call idiom for kAudioHardwarePropertyDevices,
    // filtered to output-capable devices (Pitfall 4: keyed by UID, never AudioDeviceID) and
    // returned already-sorted via sortedAudioOutputDevices (AudioOutputPresentation.swift).
    private func currentDevices() -> [AudioOutputDevice] {
        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, 0, nil, &dataSize) == noErr
        else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard deviceCount > 0 else { return [] }
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, 0, nil, &dataSize, &deviceIDs) == noErr
        else { return [] }

        let defaultDeviceID = defaultOutputDeviceID()

        var devices: [AudioOutputDevice] = []
        for deviceID in deviceIDs {
            guard let uid = deviceUID(for: deviceID) else { continue }   // Pitfall 4: never surface an unresolvable UID.
            let name = deviceName(for: deviceID) ?? uid
            let channelCount = outputChannelCount(for: deviceID)
            guard isOutputCapableDevice(outputChannelCount: channelCount) else { continue }
            devices.append(AudioOutputDevice(uid: uid, name: name, isDefault: deviceID == defaultDeviceID))
        }
        return sortedAudioOutputDevices(devices)
    }

    private func deviceUID(for deviceID: AudioDeviceID) -> String? {
        var uid: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.size)
        var uidAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(deviceID, &uidAddr, 0, nil, &uidSize, &uid) == noErr
        else { return nil }
        return uid as String
    }

    private func deviceName(for deviceID: AudioDeviceID) -> String? {
        var name: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        var nameAddr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(deviceID, &nameAddr, 0, nil, &nameSize, &name) == noErr
        else { return nil }
        return name as String
    }

    private func outputChannelCount(for deviceID: AudioDeviceID) -> Int {
        var streamAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &streamAddr, 0, nil, &dataSize) == noErr, dataSize > 0
        else { return 0 }

        let bufferListPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { bufferListPointer.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &streamAddr, 0, nil, &dataSize, bufferListPointer) == noErr
        else { return 0 }

        let audioBufferListPointer = bufferListPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferListPointer)
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }
}
