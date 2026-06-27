import Foundation

// Phase 3 / CHG-01 + CHG-02 — Pattern 2: the charging splash is a SEPARATE @Published
// model alongside the untouched NotchInteractionState 3-state machine. It is deliberately
// NOT folded into the user-gesture phase enum, so the Phase-2 hover/click/grace tests stay
// intact and the D-11 precedence (charging splash vs user gesture) is a one-line `if` in the view.
//
// Plain published holder: no methods, no timers, no IOKit. The controller (Plan 03)
// reads IOPS, maps via powerActivity(from:), and sets `.activity` (nil → no splash).
final class ChargingActivityState: ObservableObject {
    @Published var activity: ChargingActivity?
}
