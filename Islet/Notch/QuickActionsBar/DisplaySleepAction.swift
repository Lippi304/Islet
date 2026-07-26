import Foundation

// Phase 65 Plan 02 / QACTION-01 — Display Sleep Now, a fire-and-forget system primitive.
// Mirrors MicMuteController.swift's "guard failure = safe default, no crash" discipline: `try?`
// swallows any launch failure into a silent no-op. There is no UI failure-state for this action
// per UI-SPEC — a launch failure degrades to "the D-04 pulse fired, nothing else happened",
// the documented, accepted limitation for the actions with no read-back.
enum DisplaySleepAction {
    static func sleepNow() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["displaysleepnow"]
        try? task.run()
    }
}
