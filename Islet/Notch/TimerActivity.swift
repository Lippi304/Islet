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

// ASVS V5 mitigation (T-62-01): the trust-boundary input validator the picker UI calls.
// Never used in a shell/path/format-string context — the returned Int only ever feeds
// Date.addingTimeInterval (Plan 62-02).
// Phase 62-04 UAT round 5 feature (item I, simplified per round-6 correction — no "Ns"
// seconds-suffix format, only ":") — supersedes validateCustomDurationMinutes: returns
// whole SECONDS (was whole minutes) so the picker can express sub-minute durations,
// parsed in priority order:
//   1. contains ":"  -> "M:SS" (e.g. "5:30" -> 330s, "0:30" -> 30s)
//   2. otherwise -> plain whole minutes, unchanged existing behavior (e.g. "5" -> 300s)
// Bounds: 1...59_940s (1s .. 999min, the same ceiling item 4 already set, expressed in
// seconds instead of minutes).
func parseCustomDurationSeconds(_ text: String) -> Int? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    let seconds: Int
    if trimmed.contains(":") {
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]), m >= 0, (0..<60).contains(s) else { return nil }
        seconds = m * 60 + s
    } else {
        guard let m = Int(trimmed) else { return nil }
        seconds = m * 60
    }
    guard (1...59_940).contains(seconds) else { return nil }
    return seconds
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
