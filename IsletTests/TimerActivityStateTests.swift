import XCTest
@testable import Islet

// Phase 62 / TIMER-02 + TIMER-04 — regression coverage for TimerActivityState's D-08/D-09/
// D-10/D-11 mutation logic. Mirrors DownloadCoordinatorTests.swift's "no fakes, plain
// XCTAssert, testable `now:` overload" convention. All tests run against a fixed base
// instant so deadline math is deterministic.
@MainActor
final class TimerActivityStateTests: XCTestCase {

    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    // Phase 62-04 UAT round 5 feature (item I) — TimerActivityState.startCountdown/
    // startPomodoro widened from minutes: Int to seconds: Int; every call site below
    // multiplies its old minute literal by 60 (10min -> 600s, 25min -> 1500s, etc.) — no
    // behavior change, purely a unit-of-argument rename.

    func testStartCountdownSetsRunningWithDeadlineTenMinutesOut() {
        let state = TimerActivityState()
        state.startCountdown(seconds: 600, now: t0)
        XCTAssertEqual(
            state.activity,
            .running(deadline: t0.addingTimeInterval(600), context: TimerContext(mode: .countdown, phase: nil, cycle: nil))
        )
    }

    func testStartPomodoroDefaultsToWorkPhaseCycleOne() {
        let state = TimerActivityState()
        state.startPomodoro(workSeconds: 1500, breakSeconds: 300, now: t0)
        XCTAssertEqual(
            state.activity,
            .running(deadline: t0.addingTimeInterval(1500), context: TimerContext(mode: .pomodoro, phase: .work, cycle: 1))
        )
    }

    func testPauseCapturesRemainingAndClearsRunning() {
        let state = TimerActivityState()
        state.startCountdown(seconds: 600, now: t0)
        state.pause(now: t0.addingTimeInterval(60))
        XCTAssertEqual(
            state.activity,
            .paused(remaining: 540, context: TimerContext(mode: .countdown, phase: nil, cycle: nil))
        )
    }

    func testPauseIsNoOpWhenNotRunning() {
        let state = TimerActivityState()
        state.pause(now: t0)
        XCTAssertNil(state.activity)
    }

    func testResumeRecomputesDeadlineFromRemaining() {
        let state = TimerActivityState()
        state.startCountdown(seconds: 600, now: t0)
        state.pause(now: t0.addingTimeInterval(60))
        state.resume(now: t0.addingTimeInterval(90))
        XCTAssertEqual(
            state.activity,
            .running(deadline: t0.addingTimeInterval(90 + 540), context: TimerContext(mode: .countdown, phase: nil, cycle: nil))
        )
    }

    func testResetRestartsCurrentSegmentAtFullDuration() {
        // Running-then-reset.
        let runningState = TimerActivityState()
        runningState.startCountdown(seconds: 600, now: t0)
        runningState.reset(now: t0.addingTimeInterval(400))
        XCTAssertEqual(
            runningState.activity,
            .running(deadline: t0.addingTimeInterval(400 + 600), context: TimerContext(mode: .countdown, phase: nil, cycle: nil))
        )

        // Paused-then-reset — reset still restarts at full duration and lands .running, not .paused.
        let pausedState = TimerActivityState()
        pausedState.startCountdown(seconds: 600, now: t0)
        pausedState.pause(now: t0.addingTimeInterval(60))
        pausedState.reset(now: t0.addingTimeInterval(400))
        XCTAssertEqual(
            pausedState.activity,
            .running(deadline: t0.addingTimeInterval(400 + 600), context: TimerContext(mode: .countdown, phase: nil, cycle: nil))
        )
    }

    func testAddMinuteExtendsDeadlineWhileRunning() {
        let state = TimerActivityState()
        state.startCountdown(seconds: 600, now: t0)
        state.addMinute(now: t0)
        XCTAssertEqual(
            state.activity,
            .running(deadline: t0.addingTimeInterval(660), context: TimerContext(mode: .countdown, phase: nil, cycle: nil))
        )
    }

    func testAddMinuteExtendsRemainingWhilePaused() {
        let state = TimerActivityState()
        state.startCountdown(seconds: 600, now: t0)
        state.pause(now: t0.addingTimeInterval(60))
        state.addMinute(now: t0.addingTimeInterval(60))
        XCTAssertEqual(
            state.activity,
            .paused(remaining: 600, context: TimerContext(mode: .countdown, phase: nil, cycle: nil))
        )
    }

    func testStopClearsActivityAndResetsSessionFields() {
        let state = TimerActivityState()
        state.startPomodoro(workSeconds: 1500, breakSeconds: 300, now: t0)
        // Advance to cycle 2 / .breakTime: work(c1)->break(c1)->work(c2)->break(c2).
        _ = state.handleDeadlineReached(now: t0.addingTimeInterval(1500))
        _ = state.handleDeadlineReached(now: t0.addingTimeInterval(1500 + 300))
        _ = state.handleDeadlineReached(now: t0.addingTimeInterval(1500 + 300 + 1500))

        state.stop()
        XCTAssertNil(state.activity)

        state.startCountdown(seconds: 300, now: t0)
        XCTAssertEqual(
            state.activity,
            .running(deadline: t0.addingTimeInterval(300), context: TimerContext(mode: .countdown, phase: nil, cycle: nil))
        )

        // No leaked Pomodoro phase/cycle — a subsequent startPomodoro begins fresh at .work/cycle 1.
        state.startPomodoro(workSeconds: 1500, breakSeconds: 300, now: t0)
        XCTAssertEqual(
            state.activity,
            .running(deadline: t0.addingTimeInterval(1500), context: TimerContext(mode: .pomodoro, phase: .work, cycle: 1))
        )
    }

    func testHandleDeadlineReachedCountdownReturnsCompletedWithNoNext() {
        let state = TimerActivityState()
        state.startCountdown(seconds: 300, now: t0)
        let result = state.handleDeadlineReached(now: t0.addingTimeInterval(300))
        XCTAssertEqual(result.splash, .completed)
        XCTAssertNil(result.next)
        XCTAssertEqual(state.activity, .completed)
    }

    func testHandleDeadlineReachedPomodoroWorkToBreakReturnsSegmentDoneAndAdvances() {
        let state = TimerActivityState()
        state.startPomodoro(workSeconds: 1500, breakSeconds: 300, now: t0)
        let result = state.handleDeadlineReached(now: t0.addingTimeInterval(1500))
        XCTAssertEqual(result.splash, .segmentDone(finishedPhase: .work, cycle: 1))
        XCTAssertEqual(
            result.next,
            .running(deadline: t0.addingTimeInterval(1500 + 300), context: TimerContext(mode: .pomodoro, phase: .breakTime, cycle: 1))
        )
        XCTAssertEqual(state.activity, result.next)
    }

    func testHandleDeadlineReachedPomodoroBreakToWorkIncrementsCycle() {
        let state = TimerActivityState()
        state.startPomodoro(workSeconds: 1500, breakSeconds: 300, now: t0)
        _ = state.handleDeadlineReached(now: t0.addingTimeInterval(1500))

        let result = state.handleDeadlineReached(now: t0.addingTimeInterval(1500 + 300))
        XCTAssertEqual(result.splash, .segmentDone(finishedPhase: .breakTime, cycle: 1))
        XCTAssertEqual(
            result.next,
            .running(deadline: t0.addingTimeInterval(1500 + 300 + 1500), context: TimerContext(mode: .pomodoro, phase: .work, cycle: 2))
        )
    }
}
