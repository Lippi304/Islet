import Foundation

// Phase 63 / MEET-01 — the PURE Meeting-HUD value-type model (Pattern 1), mirroring
// TimerActivity.swift / DownloadActivity.swift's shape: plain Foundation-only types +
// stateless helpers, no AppKit/SwiftUI, no current-time lookup inside any function (every
// function takes `now` as an explicit parameter), no state across calls.
//
// Deliberate simplification (deviates from 63-RESEARCH.md/63-PATTERNS.md's suggested file
// list): there is NO `MeetingActivityState` @Published holder. This mirrors
// CapsLockActivity/UpdateActivity's simpler shape rather than TimerActivityState's —
// `TransientQueue.head` (`ActiveTransient.meeting(MeetingActivity)`, Plan 63-03) already IS
// the live payload Plan 63-04's controller reads and writes directly, so a second stateful
// layer would just duplicate state the queue already owns.

// The presentation payload `ActiveTransient.meeting(...)` carries (Plan 63-03).
struct MeetingActivity: Equatable {
    let callStart: Date
    let isMuted: Bool
}

// The minimal raw reading MeetingMonitor (Plan 63-02) emits on an actual on/off
// transition. Plain values so tests construct it by hand, mirroring DownloadReading.
//
// CR-01 (63-REVIEW.md) — `isMuted` is carried HERE, not sampled once by the controller at call
// start. The mute property is owned by whatever input device happens to be default, and it can
// flip under us at any moment (an AirPods swap mid-call re-points the default input device to a
// device with its own independent mute, the hardware mic-mute key, another app). A one-shot
// sample meant the HUD could keep asserting "muted" for a live microphone for the whole call —
// the exact opposite of 63-UI-SPEC's "truthful indicator, never an optimistic local flip".
// The monitor now re-reads mute on every evaluation and emits when it differs.
struct MeetingReading: Equatable {
    let detectedAt: Date
    let isMuted: Bool
}

// D-13: plain minutes:seconds, forever — past 59:59 the minutes field just keeps counting
// (60:32, 75:32, 120:00). NEVER an h:mm:ss branch; that matches the existing
// Timer/CalendarCountdown label convention (NotchPillView.swift's own "%02d:%02d").
// A backwards clock jump (or a callStart in the future) clamps to 00:00 rather than
// rendering a negative label.
func meetingElapsedLabel(callStart: Date, now: Date) -> String {
    let elapsed = max(0, Int(now.timeIntervalSince(callStart)))
    return String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
}
