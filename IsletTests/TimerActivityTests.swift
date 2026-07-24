import XCTest
@testable import Islet

// Phase 62 / TIMER-01/TIMER-04 — pure TimerActivity/TimerContext/helper tests. Mirrors
// DownloadActivityTests' plain XCTAssert style, no shared fixture/setUp.
final class TimerActivityTests: XCTestCase {

    func testTimerPillLabelNilForCountdownContext() {
        let context = TimerContext(mode: .countdown, phase: nil, cycle: nil)
        XCTAssertNil(timerPillLabel(for: context))
    }

    func testTimerPillLabelWorkCycle3() {
        let context = TimerContext(mode: .pomodoro, phase: .work, cycle: 3)
        XCTAssertEqual(timerPillLabel(for: context), "Work · Cycle 3")
    }

    func testTimerPillLabelBreakCycle1() {
        let context = TimerContext(mode: .pomodoro, phase: .breakTime, cycle: 1)
        XCTAssertEqual(timerPillLabel(for: context), "Break · Cycle 1")
    }

    func testNextPhaseTogglesWorkAndBreak() {
        XCTAssertEqual(nextPhase(after: .work), .breakTime)
        XCTAssertEqual(nextPhase(after: .breakTime), .work)
    }

    // Phase 62-04 UAT revision (item 4) — cap raised 180 -> 999.
    func testValidateCustomDurationMinutes() {
        XCTAssertEqual(validateCustomDurationMinutes("45"), 45)
        XCTAssertNil(validateCustomDurationMinutes("0"))
        XCTAssertNil(validateCustomDurationMinutes("1000"))
        XCTAssertNil(validateCustomDurationMinutes("abc"))
        XCTAssertEqual(validateCustomDurationMinutes("1"), 1)
        XCTAssertEqual(validateCustomDurationMinutes("999"), 999)
    }

    func testCompletionSplashText() {
        XCTAssertEqual(completionSplashText(for: .completed), "Timer Done")
        XCTAssertEqual(completionSplashText(for: .segmentDone(finishedPhase: .work, cycle: 1)), "Work Done")
        XCTAssertEqual(completionSplashText(for: .segmentDone(finishedPhase: .breakTime, cycle: 1)), "Break Done")
    }

    func testIsRunningOrPaused() {
        let context = TimerContext(mode: .countdown, phase: nil, cycle: nil)
        let deadline = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(TimerActivity.running(deadline: deadline, context: context).isRunningOrPaused)
        XCTAssertTrue(TimerActivity.paused(remaining: 60, context: context).isRunningOrPaused)
        XCTAssertFalse(TimerActivity.completed.isRunningOrPaused)
        XCTAssertFalse(TimerActivity.segmentDone(finishedPhase: .work, cycle: 1).isRunningOrPaused)
    }

    func testTimerActivityEquatableDistinguishesCases() {
        let context = TimerContext(mode: .countdown, phase: nil, cycle: nil)
        let a = TimerActivity.running(deadline: Date(timeIntervalSince1970: 1000), context: context)
        let b = TimerActivity.running(deadline: Date(timeIntervalSince1970: 2000), context: context)
        XCTAssertNotEqual(a, b)
        XCTAssertNotEqual(TimerActivity.completed, TimerActivity.segmentDone(finishedPhase: .work, cycle: 1))
    }
}
