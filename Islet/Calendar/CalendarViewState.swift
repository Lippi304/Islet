import Foundation

// Phase 28 / CALVIEW-01/02/04 — the @Published carrier for the calendar full view's
// visibleMonth/selectedDay/monthEvents. Mirrors NotchInteractionState/ChargingActivityState's
// own pattern: `Date()` here is the ObservableObject's INITIAL SEED value, evaluated once at
// construction -- not a violation of CalendarGlance.swift's "now: explicit parameter" pure-
// function discipline, which applies only to that file's functions.
//
// `monthEvents == nil` means "not yet fetched for this month" (distinguishes loading from a
// confirmed-zero-events month) so the calendar's empty state never flashes before the first
// EventKit fetch settles (Pitfall 4).
final class CalendarViewState: ObservableObject {
    @Published var visibleMonth: Date = Date()
    @Published var selectedDay: Date = Date()
    @Published var monthEvents: [EventInput]?
}

// Phase 28 / CALVIEW-03 — mirrors OnboardingPermission's placement precedent (a small
// UI-facing enum living in its domain's own file, not the view file).
enum QuickAddKind: Equatable {
    case event
    case reminder
}
