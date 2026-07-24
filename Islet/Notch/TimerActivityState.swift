import Foundation

// Phase 62 / TIMER-02 + TIMER-04 — the STATEFUL session mutation layer built on top of
// Plan 62-01's pure TimerActivity contract. Mirrors DownloadCoordinator.swift's testable-
// overload discipline on every mutation method: a public no-arg wrapper reads the live
// clock and forwards to a `now:`-parameterized overload; the overload itself never reads
// the live clock directly.
// Unlike DownloadCoordinator, this class does NOT reach into TransientQueue itself — the
// controller (Plan 62-04) reads `.activity`/return values and pushes into the queue,
// mirroring ChargingActivityState's "controller reads @Published, controller enqueues"
// convention (simpler than DownloadCoordinator's closure-reach-back shape, since Timer's
// session state has no per-instance identity to track the way per-tempPath downloads do).
@MainActor
final class TimerActivityState: ObservableObject {
    @Published var activity: TimerActivity?

    // The sole non-fully-private session field — Plan 62-04's NotchWindowController.swift
    // reads this to re-arm TimerMonitor at presentNewTimerSession()/refreshTimerHeadInPlace()/
    // handleTimerDeadlineReached(). Every mutation of it still happens only from within this
    // class's own methods.
    private(set) var deadline: Date?

    private var mode: TimerMode = .countdown
    private var phase: TimerPhase = .work
    private var cycle: Int = 1
    private var workDuration: TimeInterval = 25 * 60
    private var breakDuration: TimeInterval = 5 * 60
    private var pausedRemaining: TimeInterval?

    private func currentContext() -> TimerContext {
        switch mode {
        case .countdown:
            return TimerContext(mode: .countdown, phase: nil, cycle: nil)
        case .pomodoro:
            return TimerContext(mode: .pomodoro, phase: phase, cycle: cycle)
        }
    }

    // Phase 62-04 UAT round 5 feature (item I) — widened from `minutes: Int` to
    // `seconds: Int` so the picker's parseCustomDurationSeconds(_:) (Plan 62-01/TimerActivity.swift)
    // can express sub-minute custom durations ("30s") end-to-end; preset chips (still
    // minute-granular) convert at the NotchPillView call site instead (`* 60`).
    func startCountdown(seconds: Int) { startCountdown(seconds: seconds, now: Date()) }
    func startCountdown(seconds: Int, now: Date) {
        mode = .countdown
        cycle = 1
        phase = .work
        workDuration = TimeInterval(seconds)
        pausedRemaining = nil
        let newDeadline = now.addingTimeInterval(workDuration)
        deadline = newDeadline
        activity = .running(deadline: newDeadline, context: currentContext())
    }

    func startPomodoro(workSeconds: Int, breakSeconds: Int) { startPomodoro(workSeconds: workSeconds, breakSeconds: breakSeconds, now: Date()) }
    func startPomodoro(workSeconds: Int, breakSeconds: Int, now: Date) {
        mode = .pomodoro
        cycle = 1
        phase = .work
        workDuration = TimeInterval(workSeconds)
        breakDuration = TimeInterval(breakSeconds)
        pausedRemaining = nil
        let newDeadline = now.addingTimeInterval(workDuration)
        deadline = newDeadline
        activity = .running(deadline: newDeadline, context: currentContext())
    }

    func pause() { pause(now: Date()) }
    func pause(now: Date) {
        guard let d = deadline else { return }
        let remaining = max(0, d.timeIntervalSince(now))
        pausedRemaining = remaining
        deadline = nil
        activity = .paused(remaining: remaining, context: currentContext())
    }

    func resume() { resume(now: Date()) }
    func resume(now: Date) {
        guard let remaining = pausedRemaining else { return }
        let newDeadline = now.addingTimeInterval(remaining)
        deadline = newDeadline
        pausedRemaining = nil
        activity = .running(deadline: newDeadline, context: currentContext())
    }

    func reset() { reset(now: Date()) }
    func reset(now: Date) {
        guard activity != nil else { return }
        let duration = phase == .work ? workDuration : breakDuration
        pausedRemaining = nil
        let newDeadline = now.addingTimeInterval(duration)
        deadline = newDeadline
        activity = .running(deadline: newDeadline, context: currentContext())
    }

    func addMinute() { addMinute(now: Date()) }
    func addMinute(now: Date) {
        if let d = deadline {
            let newDeadline = d.addingTimeInterval(60)
            deadline = newDeadline
            activity = .running(deadline: newDeadline, context: currentContext())
        } else if let remaining = pausedRemaining {
            let newRemaining = remaining + 60
            pausedRemaining = newRemaining
            activity = .paused(remaining: newRemaining, context: currentContext())
        }
    }

    // D-10 — full reset, no `now:` needed (no Date read).
    func stop() {
        activity = nil
        deadline = nil
        pausedRemaining = nil
        cycle = 1
        phase = .work
    }

    func handleDeadlineReached() -> (splash: TimerActivity, next: TimerActivity?) { handleDeadlineReached(now: Date()) }
    func handleDeadlineReached(now: Date) -> (splash: TimerActivity, next: TimerActivity?) {
        switch mode {
        case .countdown:
            deadline = nil
            activity = .completed
            return (.completed, nil)
        case .pomodoro:
            // Capture BEFORE mutating — the splash reports the segment that just ended.
            let finishedPhase = phase
            let finishedCycle = cycle
            phase = nextPhase(after: finishedPhase)
            // D-06/D-07 — a new cycle begins once work resumes after a break.
            if finishedPhase == .breakTime {
                cycle += 1
            }
            let nextDuration = phase == .work ? workDuration : breakDuration
            let nextDeadline = now.addingTimeInterval(nextDuration)
            deadline = nextDeadline
            pausedRemaining = nil
            let next = TimerActivity.running(deadline: nextDeadline, context: currentContext())
            activity = next
            return (.segmentDone(finishedPhase: finishedPhase, cycle: finishedCycle), next)
        }
    }
}
