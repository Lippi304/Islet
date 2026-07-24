import Foundation

// Phase 62 / TIMER-02 + TIMER-04 — the one-shot deadline scheduler for TimerActivityState's
// `deadline`. Mirrors CalendarCountdownMonitor.swift's proven cancel-then-reschedule
// discipline exactly (armTimer(at:)/stop()), but is deliberately simpler: no start()/running
// guard, no EventKit query, no notification observer. `arm(at:)` is idempotent by
// construction (every call cancels first) and is called by the controller (Plan 62-04)
// every time TimerActivityState's deadline changes (start/resume/reset/add-time/segment-
// advance) or clears (pause/stop).
@MainActor
final class TimerMonitor {
    private let onFire: () -> Void
    private nonisolated(unsafe) var timer: DispatchSourceTimer?

    init(onFire: @escaping () -> Void) {
        self.onFire = onFire
    }

    // Cancel-then-reschedule discipline, applied on EVERY call. A nil date (pause/stop) just
    // cancels with no replacement — mirrors CalendarCountdownMonitor's "no event -> no timer
    // armed" branch.
    func arm(at date: Date?) {
        timer?.cancel()
        timer = nil
        guard let date else { return }

        let t = DispatchSource.makeTimerSource(queue: .main)
        // T-62-03: max(0, ...) guards against a negative deadline ever reaching schedule(),
        // which would otherwise fire immediately in a tight loop if misused.
        t.schedule(deadline: .now() + max(0, date.timeIntervalSinceNow))
        t.setEventHandler { [weak self] in self?.onFire() }
        t.resume()
        timer = t
    }

    nonisolated func stop() {
        timer?.cancel()
        timer = nil
    }

    deinit {
        // deinit can't be @MainActor in Swift 5 mode, so it does NOT call stop() here.
        // The owner (NotchWindowController) is @MainActor and owns this monitor for its
        // active lifetime; its deinit calls timerMonitor.stop() — mirrors
        // CalendarCountdownMonitor.deinit's owner-driven-teardown discipline exactly.
    }
}
