import EventKit
import AppKit

// Phase 14 / CAL-01 — the EventKit fetch SEAM (D-02/D-03), mirroring
// LicenseService.swift's protocol-isolation convention: a fragile/replaceable external
// is quarantined behind ONE `AnyObject` protocol with a single `final class` conformer.
//
// CONTRACT — `completion` is ALWAYS delivered on the MAIN thread (mirrors
// LicenseService.swift's file-header contract).
//
// SECURITY (T-14-06): `EKEvent.title` is UNTRUSTED external data (subscribed/shared
// calendars) — passed through as a plain `String` only, never interpolated into any
// format/log/shell string here. Render-time bounding (.lineLimit(1)/.truncationMode(.tail))
// is enforced in 14-04's view layer, mirroring the Bluetooth device-name precedent (T-05-01).
protocol CalendarService: AnyObject {
    /// Fetch the next relevant calendar event.
    /// - Note: `completion` is ALWAYS delivered on the MAIN thread (contract — see file header).
    ///   Settles `nil` on Calendar access denial (D-03) — never retries, never re-prompts.
    func fetchUpcoming(completion: @escaping (CalendarGlance?) -> Void)

    /// Fetch all events in the calendar month containing `date`, for the full calendar view.
    /// - Note: `completion` is ALWAYS delivered on the MAIN thread (contract — see file header).
    ///   Settles `[]` (never `nil`) on Calendar access denial — never retries, never re-prompts.
    func fetchMonth(containing date: Date, completion: @escaping ([EventInput]) -> Void)

    /// Create a new Calendar event via the quick-add UI.
    /// - Note: `completion` is ALWAYS delivered on the MAIN thread (contract — see file header).
    ///   D-06: no new permission request here — Calendar write access is already covered by
    ///   `requestFullAccessToEvents()` elsewhere in this file. Settles `false` on any save error.
    func createEvent(title: String, start: Date, end: Date, completion: @escaping (Bool) -> Void)

    /// Create a new Reminder via the quick-add UI.
    /// - Note: `completion` is ALWAYS delivered on the MAIN thread (contract — see file header).
    ///   D-04 (LOCKED): this is the ONLY call site in the codebase allowed to request Reminders
    ///   access, requested lazily on first invocation — never at launch/onboarding. Settles
    ///   `false` on denial or any save error, never retries/nags (mirrors LocationProvider.requestOnce).
    func createReminder(title: String, dueDate: Date?, completion: @escaping (Bool) -> Void)
}

final class EventKitService: CalendarService {
    private let store = EKEventStore()

    func fetchUpcoming(completion: @escaping (CalendarGlance?) -> Void) {
        Task {
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            guard granted else {
                // D-03: access denied — settle nil, no retry, no re-prompt.
                await MainActor.run { completion(nil) }
                return
            }

            // D-02: ALL active calendars, no per-calendar filter.
            let calendars = store.calendars(for: .event)
            let predicate = store.predicateForEvents(withStart: Date(),
                                                      end: Date().addingTimeInterval(2 * 24 * 3600),
                                                      calendars: calendars)
            let events = store.events(matching: predicate)
            let mapped = events.map { mapToEventInput($0) }
            let glance = nextRelevantEvent(events: mapped, now: Date())
            await MainActor.run { completion(glance) }
        }
    }

    func fetchMonth(containing date: Date, completion: @escaping ([EventInput]) -> Void) {
        Task {
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            guard granted else {
                // D-03 (mirrored): access denied — settle [], no retry, no re-prompt.
                await MainActor.run { completion([]) }
                return
            }

            let calendar = Calendar.current
            guard let interval = calendar.dateInterval(of: .month, for: date) else {
                await MainActor.run { completion([]) }
                return
            }

            // D-02: ALL active calendars, no per-calendar filter (same as fetchUpcoming).
            let calendars = store.calendars(for: .event)
            let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end,
                                                      calendars: calendars)
            let events = store.events(matching: predicate)
            let mapped = events.map { mapToEventInput($0) }
            await MainActor.run { completion(mapped) }
        }
    }

    // WR-04 fix (28-REVIEW.md) — factored out of fetchUpcoming/fetchMonth, which each
    // hand-rolled an identical ~10-line EKEvent -> EventInput RGB-extraction block with the
    // same 1.0/1.0/1.0 fallback. A future fix (e.g. a colorspace edge case) now applies to
    // both call sites at once.
    private func mapToEventInput(_ ek: EKEvent) -> EventInput {
        var red = 1.0, green = 1.0, blue = 1.0
        if let rgb = ek.calendar.color.usingColorSpace(.deviceRGB) {
            red = Double(rgb.redComponent)
            green = Double(rgb.greenComponent)
            blue = Double(rgb.blueComponent)
        }
        // T-14-06: ek.title is UNTRUSTED — passed through as a plain String only.
        return EventInput(title: ek.title ?? "", start: ek.startDate, end: ek.endDate,
                          colorRed: red, colorGreen: green, colorBlue: blue)
    }

    func createEvent(title: String, start: Date, end: Date, completion: @escaping (Bool) -> Void) {
        // D-06: no new permission request needed — full write access to Events is already
        // granted via requestFullAccessToEvents() (called from fetchUpcoming/fetchMonth).
        let event = EKEvent(eventStore: store)
        event.title = title // T-14-06: plain String, never interpolated.
        event.startDate = start
        event.endDate = end
        event.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent)
            completion(true)
        } catch {
            completion(false) // T-28-05: never crash on a thrown save error.
        }
    }

    func createReminder(title: String, dueDate: Date?, completion: @escaping (Bool) -> Void) {
        Task {
            // D-04 (LOCKED): the ONLY call site in the codebase allowed to request Reminders
            // access — fired lazily here, on first invocation, never at launch/onboarding.
            let granted = (try? await store.requestFullAccessToReminders()) ?? false
            guard granted else {
                // Silent degrade, no retry/nag (mirrors LocationProvider.requestOnce's D-01 shape).
                await MainActor.run { completion(false) }
                return
            }
            let reminder = EKReminder(eventStore: store)
            reminder.title = title // T-14-06: plain String, never interpolated.
            reminder.calendar = store.defaultCalendarForNewReminders()
            if let dueDate {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: dueDate)
            }
            do {
                try store.save(reminder, commit: true)
                await MainActor.run { completion(true) }
            } catch {
                // T-28-05: never crash on a thrown save error (also covers a nil default calendar).
                await MainActor.run { completion(false) }
            }
        }
    }
}
