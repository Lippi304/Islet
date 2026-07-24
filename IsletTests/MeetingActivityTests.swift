import XCTest
@testable import Islet

// Phase 63 / MEET-01 — pure MeetingActivity/MeetingReading/helper tests. Mirrors
// TimerActivityTests' plain XCTAssert style, no shared fixture/setUp.
final class MeetingActivityTests: XCTestCase {

    // A fixed reference instant so no test ever depends on the wall clock.
    private let t = Date(timeIntervalSince1970: 1_700_000_000)

    func testElapsedLabelIsZeroAtCallStart() {
        XCTAssertEqual(meetingElapsedLabel(callStart: t, now: t), "00:00")
    }

    func testElapsedLabelFormatsMinutesAndSeconds() {
        XCTAssertEqual(meetingElapsedLabel(callStart: t, now: t.addingTimeInterval(75)), "01:15")
        XCTAssertEqual(meetingElapsedLabel(callStart: t, now: t.addingTimeInterval(9)), "00:09")
        XCTAssertEqual(meetingElapsedLabel(callStart: t, now: t.addingTimeInterval(3599)), "59:59")
    }

    // D-13: past 59:59 the label keeps rolling PLAIN minutes:seconds — it must NEVER
    // switch to an h:mm:ss format (matches Timer/CalendarCountdown's existing convention).
    func testElapsedLabelRollsPastFiftyNineMinutesWithoutHourFormat() {
        XCTAssertEqual(meetingElapsedLabel(callStart: t, now: t.addingTimeInterval(3632)), "60:32")
        XCTAssertEqual(meetingElapsedLabel(callStart: t, now: t.addingTimeInterval(4532)), "75:32")
        XCTAssertEqual(meetingElapsedLabel(callStart: t, now: t.addingTimeInterval(7200)), "120:00")
    }

    // A clock jump backwards (or a callStart in the future) must clamp to 00:00, never
    // render a negative label.
    func testElapsedLabelClampsNegativeElapsedToZero() {
        XCTAssertEqual(meetingElapsedLabel(callStart: t, now: t.addingTimeInterval(-500)), "00:00")
    }

    func testMeetingActivityIsEquatable() {
        XCTAssertEqual(MeetingActivity(callStart: t, isMuted: false),
                       MeetingActivity(callStart: t, isMuted: false))
        XCTAssertNotEqual(MeetingActivity(callStart: t, isMuted: false),
                          MeetingActivity(callStart: t, isMuted: true))
        XCTAssertNotEqual(MeetingActivity(callStart: t, isMuted: false),
                          MeetingActivity(callStart: t.addingTimeInterval(1), isMuted: false))
    }

    func testMeetingReadingIsEquatable() {
        XCTAssertEqual(MeetingReading(detectedAt: t), MeetingReading(detectedAt: t))
        XCTAssertNotEqual(MeetingReading(detectedAt: t),
                          MeetingReading(detectedAt: t.addingTimeInterval(1)))
    }
}
