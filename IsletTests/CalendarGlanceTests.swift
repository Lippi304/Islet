import XCTest
@testable import Islet

// Phase 14 / CAL-01: the PURE nextRelevantEvent(events:now:) selection seam (D-04), mirroring
// DeviceActivity.swift's discipline — Foundation-only, `now` always an explicit parameter
// (never Date()/Date.now inside), so tests stay deterministic. EventInput is hand-constructed
// here; no EventKit import in this test file.
final class CalendarGlanceTests: XCTestCase {

    func testInProgressEventTodayIsReturned() {
        // Given one event today that started 10 min ago and ends in 20 min (now is between
        // start and end -- in-progress), nextRelevantEvent returns it with isToday == true.
        let now = Date()
        let event = EventInput(title: "Standup",
                                start: now.addingTimeInterval(-10 * 60),
                                end: now.addingTimeInterval(20 * 60),
                                colorRed: 1, colorGreen: 0, colorBlue: 0)
        let result = nextRelevantEvent(events: [event], now: now)
        XCTAssertEqual(result, CalendarGlance(title: "Standup", startDate: event.start, isToday: true,
                                               colorRed: 1, colorGreen: 0, colorBlue: 0))
    }

    func testEndedEventTodayIsSkippedInFavorOfUpcomingOne() {
        // Given two events today, one already ended (end <= now) and one starting in 1 hour,
        // nextRelevantEvent returns the one starting in 1 hour (the ended one is skipped).
        let now = Date()
        let ended = EventInput(title: "Ended Meeting",
                                start: now.addingTimeInterval(-2 * 3600),
                                end: now.addingTimeInterval(-1 * 3600),
                                colorRed: 0, colorGreen: 1, colorBlue: 0)
        let upcoming = EventInput(title: "Upcoming Meeting",
                                   start: now.addingTimeInterval(3600),
                                   end: now.addingTimeInterval(2 * 3600),
                                   colorRed: 0, colorGreen: 0, colorBlue: 1)
        let result = nextRelevantEvent(events: [ended, upcoming], now: now)
        XCTAssertEqual(result, CalendarGlance(title: "Upcoming Meeting", startDate: upcoming.start, isToday: true,
                                               colorRed: 0, colorGreen: 0, colorBlue: 1))
    }

    func testNoEventsTodayFallsBackToTomorrowsFirstEvent() {
        // Given zero events today but one event tomorrow, nextRelevantEvent returns tomorrow's
        // event with isToday == false.
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let event = EventInput(title: "Tomorrow Event", start: tomorrow, end: tomorrow.addingTimeInterval(3600),
                                colorRed: 0.5, colorGreen: 0.5, colorBlue: 0.5)
        let result = nextRelevantEvent(events: [event], now: now)
        XCTAssertEqual(result, CalendarGlance(title: "Tomorrow Event", startDate: tomorrow, isToday: false,
                                               colorRed: 0.5, colorGreen: 0.5, colorBlue: 0.5))
    }

    func testNoEventsTodayOrTomorrowReturnsNil() {
        // Given zero events today AND zero events tomorrow (only an event 3 days out),
        // nextRelevantEvent returns nil.
        let now = Date()
        let calendar = Calendar.current
        let threeDaysOut = calendar.date(byAdding: .day, value: 3, to: now)!
        let event = EventInput(title: "Far Future Event", start: threeDaysOut, end: threeDaysOut.addingTimeInterval(3600),
                                colorRed: 0, colorGreen: 0, colorBlue: 0)
        let result = nextRelevantEvent(events: [event], now: now)
        XCTAssertNil(result)
    }

    func testMultipleRelevantEventsTodayReturnsEarliestStarting() {
        // Given multiple events today all still relevant, nextRelevantEvent returns the
        // EARLIEST-starting one (sorted by start).
        let now = Date()
        let later = EventInput(title: "Later Event", start: now.addingTimeInterval(2 * 3600),
                                end: now.addingTimeInterval(3 * 3600), colorRed: 1, colorGreen: 1, colorBlue: 0)
        let earlier = EventInput(title: "Earlier Event", start: now.addingTimeInterval(3600),
                                  end: now.addingTimeInterval(2 * 3600), colorRed: 0, colorGreen: 1, colorBlue: 1)
        let result = nextRelevantEvent(events: [later, earlier], now: now)
        XCTAssertEqual(result, CalendarGlance(title: "Earlier Event", startDate: earlier.start, isToday: true,
                                               colorRed: 0, colorGreen: 1, colorBlue: 1))
    }

    func testEmptyEventsListReturnsNilWithoutCrashing() {
        // T-14-02: an empty events array must never force-unwrap or crash -- returns nil.
        let result = nextRelevantEvent(events: [], now: Date())
        XCTAssertNil(result)
    }
}
