import Foundation

// Phase 47 / D-01 + D-02 — the PURE audio-output-device presentation seam (Pattern 1).
//
// Like NowPlayingPresentation and OSDActivity, these are plain values + total functions
// importing ONLY Foundation — no CoreAudio, no AppKit, no SwiftUI here. AudioOutputMonitor
// (Plan 47-02, system glue) is the only place AudioDeviceID/CoreAudio types are ever
// touched; it computes the real facts (output channel count, current default) and calls
// these functions with them. Tests build AudioOutputDevice by hand, so the riskiest
// classification/ordering logic is unit-tested in milliseconds.

// A stable-UID-keyed device value (Pitfall 4 — never an AudioDeviceID, which can change
// across reconnects/reboots). `id` derives from `uid` so this is Identifiable for SwiftUI
// list rendering (Plan 48) without any additional bookkeeping.
struct AudioOutputDevice: Equatable, Identifiable {
    let uid: String
    let name: String
    let isDefault: Bool

    var id: String { uid }
}

// TOTAL pure classification — D-01: any positive output-channel count is output-capable
// (covers physical hardware, AirPlay, and aggregate/Multi-Output device kinds, all of which
// CoreAudio reports via `kAudioDevicePropertyStreamConfiguration` under
// `kAudioObjectPropertyScopeOutput` with >0 channels). A non-positive count (0, or a
// defensive floor for a malformed negative read from the glue layer) is never capable —
// mirrors osdVolumeActivity's clamp discipline.
func isOutputCapableDevice(outputChannelCount: Int) -> Bool {
    outputChannelCount > 0
}
