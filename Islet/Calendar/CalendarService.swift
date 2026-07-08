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
            let mapped = events.map { ek -> EventInput in
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
            let glance = nextRelevantEvent(events: mapped, now: Date())
            await MainActor.run { completion(glance) }
        }
    }
}
