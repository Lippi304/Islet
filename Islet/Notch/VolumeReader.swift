import CoreAudio
import AudioToolbox

// Phase 39 Plan 03 / HUD-03 — thin CoreAudio glue, isolated per "one fragile system surface,
// one file" convention. Mirrors PowerSourceMonitor.readCurrentPower()'s defensive-optional-cast
// discipline: every step is guarded and a missing/malformed value never force-unwraps or
// crashes, falling back to a safe (0, false) reading instead.

// Phase 39 Plan 08 / D-15 — matches macOS's own default volume-key step (1/16 = 6.25%).
private let volumeStep: Float = 1.0 / 16.0

// Phase 39 Plan 08 / D-15 — factored out of readSystemVolume() so adjustSystemVolume()/
// toggleSystemMute() can share the identical lookup instead of duplicating it.
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

func readSystemVolume() -> (percent: Int, muted: Bool) {
    guard let deviceID = defaultOutputDeviceID() else { return (0, false) }

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

// Phase 39 Plan 08 / D-15 — self-drive write path: the OSDInterceptor swallows the physical key
// press, so Islet itself must apply the real system volume change (mirrors
// dannystewart/volumeHUD's setVolume(_:deviceID:)). ANY failed Get/Set call in this chain aborts
// the whole adjustment and returns nil immediately — never partially applies a change, matching
// readSystemVolume()'s "safe default, never force-unwrap" discipline.
func adjustSystemVolume(increase: Bool) -> (percent: Int, muted: Bool)? {
    guard let deviceID = defaultOutputDeviceID() else { return nil }

    var volAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    var muteAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    let volumeSize = UInt32(MemoryLayout<Float32>.size)
    let mutedSize = UInt32(MemoryLayout<UInt32>.size)

    var currentVolume = Float32(0)
    var volumeSizeVar = volumeSize
    guard AudioObjectGetPropertyData(deviceID, &volAddr, 0, nil, &volumeSizeVar, &currentVolume) == noErr
    else { return nil }

    var currentMuted: UInt32 = 0
    var mutedSizeVar = mutedSize
    guard AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &mutedSizeVar, &currentMuted) == noErr
    else { return nil }

    var target = max(0, min(1, currentVolume + (increase ? volumeStep : -volumeStep)))
    target = (target * 16).rounded() / 16

    // Auto-unmute FIRST if currently muted and the new target is audible — mirrors the native
    // OSD's own behavior when pressing Volume Up while muted.
    if currentMuted == 1 && target > 0 {
        var unmute: UInt32 = 0
        guard AudioObjectSetPropertyData(deviceID, &muteAddr, 0, nil, mutedSize, &unmute) == noErr
        else { return nil }
    }

    guard AudioObjectSetPropertyData(deviceID, &volAddr, 0, nil, volumeSize, &target) == noErr
    else { return nil }

    // Auto-mute if the new target bottomed out at 0 and it wasn't already muted.
    if target <= 0 && currentMuted == 0 {
        var mute: UInt32 = 1
        guard AudioObjectSetPropertyData(deviceID, &muteAddr, 0, nil, mutedSize, &mute) == noErr
        else { return nil }
    }

    var finalMuted: UInt32 = 0
    var finalMutedSize = mutedSize
    guard AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &finalMutedSize, &finalMuted) == noErr
    else { return nil }

    return (Int((target * 100).rounded()), finalMuted == 1)
}

// Phase 48 Plan 01 / OUTPUT-01 — absolute-set counterpart to adjustSystemVolume's relative step,
// needed because the draggable output-panel slider computes a continuous target fraction from
// drag position rather than a fixed +/-1/16 step. Same guarded Get/Set/auto-(un)mute discipline;
// never partially applies a change, never force-unwraps.
func setSystemVolume(_ target: Float) -> (percent: Int, muted: Bool)? {
    guard let deviceID = defaultOutputDeviceID() else { return nil }

    var volAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    var muteAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    let volumeSize = UInt32(MemoryLayout<Float32>.size)
    let mutedSize = UInt32(MemoryLayout<UInt32>.size)

    var currentMuted: UInt32 = 0
    var mutedSizeVar = mutedSize
    guard AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &mutedSizeVar, &currentMuted) == noErr
    else { return nil }

    // Defensively re-clamp — never trust the caller's computed fraction.
    let clampedTarget = max(0, min(1, target))

    // Auto-unmute FIRST if currently muted and the new target is audible — mirrors
    // adjustSystemVolume's own behavior.
    if currentMuted == 1 && clampedTarget > 0 {
        var unmute: UInt32 = 0
        guard AudioObjectSetPropertyData(deviceID, &muteAddr, 0, nil, mutedSize, &unmute) == noErr
        else { return nil }
    }

    var targetVar = clampedTarget
    guard AudioObjectSetPropertyData(deviceID, &volAddr, 0, nil, volumeSize, &targetVar) == noErr
    else { return nil }

    // Auto-mute if the new target bottomed out at 0 and it wasn't already muted.
    if clampedTarget <= 0 && currentMuted == 0 {
        var mute: UInt32 = 1
        guard AudioObjectSetPropertyData(deviceID, &muteAddr, 0, nil, mutedSize, &mute) == noErr
        else { return nil }
    }

    var finalMuted: UInt32 = 0
    var finalMutedSize = mutedSize
    guard AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &finalMutedSize, &finalMuted) == noErr
    else { return nil }

    return (Int((clampedTarget * 100).rounded()), finalMuted == 1)
}

// Phase 39 Plan 08 / D-15 — self-drive write path for the Mute transport key.
func toggleSystemMute() -> (percent: Int, muted: Bool)? {
    guard let deviceID = defaultOutputDeviceID() else { return nil }

    var muteAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    var volAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)

    var currentMuted: UInt32 = 0
    var mutedSize = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &mutedSize, &currentMuted) == noErr
    else { return nil }

    var newMuted: UInt32 = currentMuted == 1 ? 0 : 1
    guard AudioObjectSetPropertyData(deviceID, &muteAddr, 0, nil, mutedSize, &newMuted) == noErr
    else { return nil }

    var currentVolume = Float32(0)
    var volumeSize = UInt32(MemoryLayout<Float32>.size)
    guard AudioObjectGetPropertyData(deviceID, &volAddr, 0, nil, &volumeSize, &currentVolume) == noErr
    else { return nil }

    return (Int((currentVolume * 100).rounded()), newMuted == 1)
}
