import CoreAudio
import AudioToolbox

// Phase 39 Plan 03 / HUD-03 — thin CoreAudio glue, isolated per "one fragile system surface,
// one file" convention. Mirrors PowerSourceMonitor.readCurrentPower()'s defensive-optional-cast
// discipline: every step is guarded and a missing/malformed value never force-unwraps or
// crashes, falling back to a safe (0, false) reading instead.
func readSystemVolume() -> (percent: Int, muted: Bool) {
    var deviceID = AudioDeviceID(0)
    var deviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var outputAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &outputAddr, 0, nil, &deviceIDSize, &deviceID) == noErr
    else { return (0, false) }

    var volume = Float32(0)
    var volumeSize = UInt32(MemoryLayout<Float32>.size)
    var volAddr = AudioObjectPropertyAddress(
        // NEVER the pre-Xcode-13 "VirtualMaster"-prefixed symbol name (Pitfall 4) — it was
        // renamed to "VirtualMain" and the old symbol will not resolve on this project's SDK.
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(deviceID, &volAddr, 0, nil, &volumeSize, &volume) == noErr
    else { return (0, false) }

    var muted: UInt32 = 0
    var mutedSize = UInt32(MemoryLayout<UInt32>.size)
    var muteAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &mutedSize, &muted) == noErr
    else { return (0, false) }

    return (Int((volume * 100).rounded()), muted == 1)
}
