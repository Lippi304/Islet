import Foundation

// Phase 62 / TIMER-01/TIMER-04 — the PURE countdown/Pomodoro value-type model (Pattern 1),
// mirroring DownloadActivity.swift's shape: plain Foundation-only types + stateless
// helpers, no AppKit/SwiftUI, no `Date()` calls inside any function (every function takes
// plain values), no state across calls. `TimerActivityState`'s stateful pause/resume/
// deadline-math (Plan 62-02) is a SEPARATE, later layer — nothing here holds state.

// The two shapes a timer can take.
enum TimerMode: Equatable {
    case countdown
    case pomodoro
}

// The two Pomodoro segment kinds. `nil` for a plain countdown (D-02: no label).
enum TimerPhase: Equatable {
    case work
    case breakTime
}

// `phase`/`cycle` are nil for `.countdown`, populated for `.pomodoro`.
struct TimerContext: Equatable {
    let mode: TimerMode
    let phase: TimerPhase?
    let cycle: Int?
}

// D-12/D-13: `.completed` is a plain countdown finishing; `.segmentDone` is a Pomodoro
// segment transition, `cycle` is the number of the segment that JUST finished.
enum TimerActivity: Equatable {
    case running(deadline: Date, context: TimerContext)
    case paused(remaining: TimeInterval, context: TimerContext)
    case completed
    case segmentDone(finishedPhase: TimerPhase, cycle: Int)
}

extension TimerActivity {
    // The exact seam ActiveTransient.isPersistent (Islet/Notch/IslandResolver.swift) reads.
    var isRunningOrPaused: Bool {
        switch self {
        case .running, .paused: return true
        case .completed, .segmentDone: return false
        }
    }
}

// D-07 exact wording — countdown mode shows no label (mm:ss only).
func timerPillLabel(for context: TimerContext) -> String? {
    guard let phase = context.phase, let cycle = context.cycle else { return nil }
    switch phase {
    case .work: return "Work · Cycle \(cycle)"
    case .breakTime: return "Break · Cycle \(cycle)"
    }
}

// Pure toggle, no Date, no state. D-11's auto-advance target.
func nextPhase(after phase: TimerPhase) -> TimerPhase {
    switch phase {
    case .work: return .breakTime
    case .breakTime: return .work
    }
}

// ASVS V5 mitigation (T-62-01): the trust-boundary input validator Plan 62-03's picker UI
// calls. Never used in a shell/path/format-string context — the value only ever feeds
// Date.addingTimeInterval (Plan 62-02).
// Phase 62-04 UAT revision (item 4) — cap raised 180 -> 999 (user request: "as long a
// custom duration as they want"; 999min/~16.65h is a generous ceiling that still keeps
// the value comfortably inside Int/TimeInterval range, never truly unbounded).
func validateCustomDurationMinutes(_ text: String) -> Int? {
    guard let value = Int(text), (1...999).contains(value) else { return nil }
    return value
}

// Locked 62-UI-SPEC.md copy.
func completionSplashText(for activity: TimerActivity) -> String? {
    switch activity {
    case .completed: return "Timer Done"
    case .segmentDone(let finishedPhase, _):
        switch finishedPhase {
        case .work: return "Work Done"
        case .breakTime: return "Break Done"
        }
    case .running, .paused: return nil
    }
}
