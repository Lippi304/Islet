import Foundation

// Phase 16 / D-02 — the narrow contract every extracted activity coordinator conforms to.
//
// Deliberately sized to exactly what DeviceCoordinator (Plan 16-01) needs today — a
// deliberate first slice, NOT pre-sketched for the future Charging/NowPlaying/Outfit
// coordinators the ROADMAP anticipates. Only two operations exist because only two call
// sites in NotchWindowController.swift ever needed a device coordinator: feeding a new
// raw reading in (`handleDevice(_:)`) and reacting to the shared TransientQueue's head
// changing for a reason outside the coordinator's own call (`triggerDeviceBatteryRefreshIfPromoted()`
// — dismiss-timer advance, flushTransients promotion).
//
// The lifecycle-reset, pending-work-cancellation, and launch-grace-stamping methods living
// on the concrete DeviceCoordinator type are deliberately NOT part of this protocol — only
// the controller calls those directly today, never through a protocol-typed reference
// (RESEARCH.md Open Question 1, RESOLVED per Plan 16-02).
@MainActor
protocol ActivityCoordinator {
    associatedtype Reading

    // Feed a new reading in; the conformer internally debounces/gates/enqueues. No return
    // value — the coordinator owns its own presentation side effects.
    func handle(_ reading: Reading)

    // React to the shared TransientQueue's head changing for a reason outside this
    // coordinator's own handle(_:) call (dismiss-timer advance, flushTransients promotion).
    func activityPromoted()
}
