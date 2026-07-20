import Foundation
import EventKit

// Phase 41 / HUD-08 — the LIVE calendar-countdown scheduling monitor (Plan 02).
//
// Event-driven + one-shot-deadline scheduling, mirroring FocusModeMonitor.swift's
// idempotent start()/nonisolated stop()/@MainActor lifecycle shape — but NEVER a
// repeating poll timer (Pitfall 1/Pitfall 7): every re-check arms AT MOST one
// `DispatchSourceTimer` deadline (either the "enter the 1hr countdown window" instant or
// the "event starts, dismiss + re-arm" instant), cancelled and rescheduled on every
// re-check (the same cancel-then-reschedule discipline DropInterceptTap's health-check
// timer and this project's own one-shot activity-dismiss timer both already use).
//
// All EventKit access stays behind the injected `CalendarService` — this file imports
// EventKit ONLY for `NSNotification.Name.EKEventStoreChanged`, never constructs its own
// `EKEventStore`/`EventKitService`.
@MainActor
final class CalendarCountdownMonitor {
    private let calendarService: CalendarService
    private let onChange: (CalendarCountdownActivity?) -> Void

    private nonisolated(unsafe) var timer: DispatchSourceTimer?
    private nonisolated(unsafe) var running = false
    private nonisolated(unsafe) var eventStoreObserver: NSObjectProtocol?

    // D-04/HUD-08's 1hr countdown window.
    private let lookahead: TimeInterval = 3600
    // Mirrors fetchUpcoming's own 2-day predicate — wide enough to find "the next event,
    // whenever it is" so the arm-instant for an event still beyond the 1hr lookahead can
    // be computed.
    private let fetchWindow: TimeInterval = 2 * 24 * 3600

    init(calendarService: CalendarService, onChange: @escaping (CalendarCountdownActivity?) -> Void) {
        self.calendarService = calendarService
        self.onChange = onChange
    }

    // Idempotent — never double-register the EKEventStoreChanged observer.
    func start() {
        guard !running else { return }
        running = true
        eventStoreObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: nil, queue: .main
        ) { [weak self] _ in self?.recheck() }
        recheck()
    }

    // Pitfall 4: each re-check is cheap — one EventKit query + one pure function call +
    // at most one timer reschedule. Deliberately NO debounce/coalesce here — that's
    // explicitly deferred unless Plan 04's on-device UAT observes measurable Idle-Wakeup
    // bursts correlated with calendar sync churn (T-41-04, accepted).
    private func recheck() {
        calendarService.fetchUpcomingRaw { [weak self] events in self?.scheduleNext(from: events) }
    }

    private func scheduleNext(from events: [EventInput]) {
        // Cancel-then-reschedule discipline, applied on EVERY re-check (deadline fire,
        // .EKEventStoreChanged fire, or the initial start() call).
        timer?.cancel()
        timer = nil

        let now = Date()
        // WIDE 2-day window — the same pure selector Plan 01 unit-tested, called here with
        // a different lookahead argument than the countdown's own 1hr.
        guard let candidate = nextUpcomingEvent(events: events, now: now, lookahead: fetchWindow) else {
            // No event at all — rely purely on .EKEventStoreChanged to wake this monitor
            // again (Pitfall 1's "no event exists" case). No timer armed.
            onChange(nil)
            return
        }

        if candidate.start <= now.addingTimeInterval(lookahead) {
            // Already inside the 1hr countdown window — countdown is ACTIVE now.
            onChange(CalendarCountdownActivity(eventStart: candidate.start))
            // Dismiss + D-09 re-arm instant: when this fires, recheck() runs again and
            // naturally finds whatever event is next.
            armTimer(at: candidate.start)
        } else {
            // Still beyond the 1hr window — not active yet.
            onChange(nil)
            // The exact moment the event enters the 1hr lookahead window (Pattern 3's
            // "arm instant").
            armTimer(at: candidate.start.addingTimeInterval(-lookahead))
        }
    }

    private func armTimer(at date: Date) {
        let t = DispatchSource.makeTimerSource(queue: .main)
        // Deliberately no repeat/interval argument — one-shot divergence from FocusModeMonitor's polling shape.
        t.schedule(deadline: .now() + max(0, date.timeIntervalSinceNow))
        t.setEventHandler { [weak self] in self?.recheck() }
        t.resume()
        timer = t
    }

    nonisolated func stop() {
        timer?.cancel()
        timer = nil
        if let eventStoreObserver { NotificationCenter.default.removeObserver(eventStoreObserver) }
        eventStoreObserver = nil
        running = false
    }

    deinit {
        // deinit can't be @MainActor in Swift 5 mode, so it does NOT call stop() here.
        // The owner (NotchWindowController) is @MainActor and owns this monitor for its
        // active lifetime; its deinit calls calendarCountdownMonitor.stop() — mirrors
        // FocusModeMonitor.deinit's owner-driven-teardown discipline exactly.
    }
}
