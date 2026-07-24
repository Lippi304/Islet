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

    // Phase 62-04 UAT round 5 feature (item I, simplified round 6 — no "Ns" seconds-suffix
    // format) — supersedes testValidateCustomDurationMinutes: parseCustomDurationSeconds
    // returns whole SECONDS and accepts 2 formats (plain minutes, "M:SS").
    func testParseCustomDurationSecondsPlainMinutes() {
        XCTAssertEqual(parseCustomDurationSeconds("45"), 45 * 60)
        XCTAssertNil(parseCustomDurationSeconds("0"))
        XCTAssertNil(parseCustomDurationSeconds("1000"))   // 1000min > 999min cap
        XCTAssertNil(parseCustomDurationSeconds("abc"))
        XCTAssertEqual(parseCustomDurationSeconds("1"), 60)
        XCTAssertEqual(parseCustomDurationSeconds("999"), 999 * 60)
    }

    func testParseCustomDurationSecondsColonFormat() {
        XCTAssertEqual(parseCustomDurationSeconds("5:30"), 330)
        XCTAssertEqual(parseCustomDurationSeconds("0:45"), 45)
        XCTAssertNil(parseCustomDurationSeconds("5:60"))   // seconds part must be 0..<60
        XCTAssertNil(parseCustomDurationSeconds("5:"))
        XCTAssertNil(parseCustomDurationSeconds(":30"))
    }

    func testParseCustomDurationSecondsBounds() {
        XCTAssertEqual(parseCustomDurationSeconds("999:00"), 59_940)   // exactly the 999min ceiling
        XCTAssertNil(parseCustomDurationSeconds("999:01"))              // 1s over the ceiling
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
