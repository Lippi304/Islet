import IOKit.pwr_mgt

// Phase 65 Plan 02 / QACTION-01 — Keep Awake / Caffeinate, an IOKit power assertion held
// across calls. Deviation from RESEARCH.md's class-instance example (deliberate, see
// 65-02-PLAN.md <interfaces>): a STATIC-STATE enum, not a `final class` instance — this avoids
// a new controller-owned instance the wiring plan (65-07) would otherwise have to
// allocate/hold/pass down just to expose `isActive` to the view. A static enum keeps the
// toggle mechanism AND its live-read state colocated in this one file, matching
// ScreenLockAction.swift's/MicMuteController.swift's own static/top-level-function style.
enum CaffeinateToggleAction {
    private static var assertionID: IOPMAssertionID = 0
    private(set) static var isActive = false

    static func toggle() {
        if isActive {
            IOPMAssertionRelease(assertionID)
            isActive = false
        } else {
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Islet Quick Actions — keep awake" as CFString,
                &assertionID)
            isActive = (result == kIOReturnSuccess)
        }
    }
}
