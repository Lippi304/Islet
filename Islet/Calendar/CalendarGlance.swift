import Foundation

// Phase 14 / CAL-01 — the PURE event-selection seam (D-04), mirroring
// Islet/Notch/DeviceActivity.swift's framework-free discipline exactly: Foundation only, no
// EventKit import here. 14-03's `EventKitService` converts real `EKEvent`s into `EventInput`
// plain values before calling in, so this file stays deterministically unit-testable without
// any calendar permission or async context.
//
// `now` is ALWAYS an explicit parameter -- never Date()/Date.now inside this function --
// mirroring DeviceActivity.swift's "caller passes now" discipline so tests stay deterministic.

// A plain, hand-constructible event value. The RGB components let the calendar's own color
// (EKCalendar.color) reach the render layer without this pure seam importing AppKit/SwiftUI
// for NSColor/Color.
struct EventInput: Equatable {
    let title: String
    let start: Date
    let end: Date
    let colorRed: Double
    let colorGreen: Double
    let colorBlue: Double
}

// The presentation nextRelevantEvent(events:now:) picks.
struct CalendarGlance: Equatable {
    let title: String
    let startDate: Date
    let isToday: Bool
    let colorRed: Double
    let colorGreen: Double
    let colorBlue: Double
}

// D-04: today's next in-progress-or-upcoming event, else tomorrow's first event, else nil.
// Total function -- an empty or entirely-past `events` array returns nil, never crashes
// (T-14-02).
func nextRelevantEvent(events: [EventInput], now: Date) -> CalendarGlance? {
    let calendar = Calendar.current

    if let todayEvent = events
        .filter({ calendar.isDate($0.start, inSameDayAs: now) && $0.end > now })
        .sorted(by: { $0.start < $1.start })
        .first {
        return CalendarGlance(title: todayEvent.title, startDate: todayEvent.start, isToday: true,
                               colorRed: todayEvent.colorRed, colorGreen: todayEvent.colorGreen, colorBlue: todayEvent.colorBlue)
    }

    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
    if let tomorrowEvent = events
        .filter({ calendar.isDate($0.start, inSameDayAs: tomorrow) })
        .sorted(by: { $0.start < $1.start })
        .first {
        return CalendarGlance(title: tomorrowEvent.title, startDate: tomorrowEvent.start, isToday: false,
                               colorRed: tomorrowEvent.colorRed, colorGreen: tomorrowEvent.colorGreen, colorBlue: tomorrowEvent.colorBlue)
    }

    return nil   // D-04: neither today nor tomorrow has a relevant event
}

// Phase 28 / CALVIEW-01 — the calendar grid's day-cell generator. Total function: never
// crashes, returns `[]` if the Calendar API can't resolve the month (T-14-02 precedent).
// Leading `nil` entries pad the grid so the 1st of the month lands in its correct weekday
// column relative to `calendar.firstWeekday`.
func daysInMonth(for date: Date, calendar: Calendar = .current) -> [Date?] {
    guard let monthInterval = calendar.dateInterval(of: .month, for: date),
          let dayRange = calendar.range(of: .day, in: .month, for: date) else {
        return []
    }

    let monthStart = monthInterval.start
    let firstWeekday = calendar.component(.weekday, from: monthStart)
    let leadingEmptyCount = (firstWeekday - calendar.firstWeekday + 7) % 7

    var days: [Date?] = Array(repeating: nil, count: leadingEmptyCount)
    for dayOffset in 0..<dayRange.count {
        guard let day = calendar.date(byAdding: .day, value: dayOffset, to: monthStart) else { continue }
        days.append(day)
    }
    return days
}

// Phase 28 / CALVIEW-02 — the day-detail event filter Plan 03's calendarFullView reads
// through. Identical contract to nextRelevantEvent: Foundation-only, total, never crashes on
// an empty `events` array.
func events(on day: Date, events: [EventInput], calendar: Calendar = .current) -> [EventInput] {
    events
        .filter { calendar.isDate($0.start, inSameDayAs: day) }
        .sorted { $0.start < $1.start }
}
