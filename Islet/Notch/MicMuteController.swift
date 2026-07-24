import CoreAudio
import AudioToolbox

// Phase 63 Plan 01 / MEET-02 — the shared system-wide INPUT-mute primitive (D-02/D-04).
// Deliberately a near-literal sibling of VolumeReader.swift with the scope swapped from
// Output to Input, following this codebase's "one fragile system surface, one file"
// convention: kAudioDevicePropertyScopeInput is the ONLY device scope this file ever uses —
// the Output device scope stays VolumeReader.swift's job, so the two files can never fight
// over the same property.
//
// D-04 scope discipline: mute READ + TOGGLE only. No input-volume, no gain, no device
// enumeration — AudioOutputMonitor.swift owns device lists, and it owns them for OUTPUT only.
//
// T-63-01 / Pitfall 3: unlike VolumeReader.swift (which relies on the Get/Set call itself
// failing with a non-noErr status), every Get/Set here is preceded by an explicit
// AudioObjectHasProperty guard — some Bluetooth input devices do not implement
// kAudioDevicePropertyMute at all. On a missing property we return the safe default
// (false / nil) WITHOUT ever issuing the Get/Set, so a change is never partially applied.

// The Input counterpart to VolumeReader.swift's private defaultOutputDeviceID(). Deliberately
// internal, NOT private: Plan 63-02's MeetingMonitor needs this exact lookup and re-implementing
// the identical boilerplate there would be a second copy to keep in sync.
func defaultInputDeviceID() -> AudioDeviceID? {
    var deviceID = AudioDeviceID(0)
    var deviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var inputAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &inputAddr, 0, nil, &deviceIDSize, &deviceID) == noErr
    else { return nil }
    // A device ID of 0 is kAudioObjectUnknown — treat it as "no default input device".
    guard deviceID != AudioDeviceID(0) else { return nil }
    return deviceID
}

// Safe default `false` (not muted) whenever the device or its Mute property can't be resolved —
// mirrors readSystemVolume()'s "(0, false) on any guard failure" discipline.
func readSystemInputMuted() -> Bool {
    guard let deviceID = defaultInputDeviceID() else { return false }

    // Address built inline at each call site rather than via a shared helper, mirroring
    // VolumeReader.swift's own style verbatim so the two files stay trivially diffable.
    var muteAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectHasProperty(deviceID, &muteAddr) else { return false }

    var muted: UInt32 = 0
    var mutedSize = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &mutedSize, &muted) == noErr
    else { return false }

    return muted == 1
}

// Returns the NEW muted state, or nil if any guard fails — in which case nothing was written
// (the Set is the last step, reached only after the has-property guard and the Get both pass),
// so a failure never partially applies a change. No volume-percent return value: this scope has
// no volume concept Meeting-HUD needs (D-04).
func toggleSystemInputMute() -> Bool? {
    guard let deviceID = defaultInputDeviceID() else { return nil }

    var muteAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectHasProperty(deviceID, &muteAddr) else { return nil }

    var currentMuted: UInt32 = 0
    var mutedSize = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &mutedSize, &currentMuted) == noErr
    else { return nil }

    var newMuted: UInt32 = currentMuted == 1 ? 0 : 1
    guard AudioObjectSetPropertyData(deviceID, &muteAddr, 0, nil, mutedSize, &newMuted) == noErr
    else { return nil }

    return newMuted == 1
}
