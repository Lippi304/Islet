import Foundation
import Intents

// Phase 65 Plan 04 / QACTION-03 — best-effort Focus/DND toggle. There is no public write API
// for Focus (RESEARCH.md Pattern 2), so the ONLY available write path is invoking a fixed,
// user-configured Shortcut via `/usr/bin/shortcuts run`. Because that call's lack of a thrown
// error means nothing about whether Focus actually changed, this file NEVER trusts it alone —
// it always re-reads `INFocusStatusCenter` before and after and reports success only when the
// live state genuinely differs (T-65-07).
//
// This file isolates the `Intents` surface (mirrors FocusModeMonitor.swift's own isolation
// discipline, Pattern 1) so NotchPillView never imports `Intents` directly, and reuses
// FocusModeMonitor.isAuthorized/requestAuthorization verbatim rather than duplicating
// INFocusStatusCenter authorization logic (T-65-08's sibling concern).
//
// Deliberately decoupled from Phase 38's ambient Focus HUD: this file never touches the
// ActivitySettings key that HUD gates on — Quick Actions Bar availability is gated on the
// separate quickActionsKey only, in the controller wiring plan (65-07), not here.
//
// @MainActor because FocusModeMonitor.isAuthorized (called from toggle's first guard) is itself
// @MainActor-isolated — this file is only ever invoked from the UI's main-actor context anyway
// (a Quick Actions Bar tap), so this matches the caller's real isolation rather than working
// around it.
@MainActor
enum FocusToggleAction {
    // Fixed, documented Shortcut name (RESEARCH.md Open Question 1) — no per-call parameter,
    // no setup-flow UI this phase. If the user hasn't created a Shortcut with this exact name,
    // `shortcuts run` fails/no-ops and the read-back naturally reports failure: the required
    // "visible, not silent" behavior, with zero extra config surface.
    static let focusShortcutName = "Islet Toggle Focus"

    // Live read of current Focus/DND state — the green "confirmed-on" icon state Plan 65-05's
    // DND tile uses. Never force-unwraps; degrades to `false` (not authorized / no data yet).
    static var isConfirmedOn: Bool {
        INFocusStatusCenter.default.focusStatus.isFocused ?? false
    }

    // Pure before/after comparison, extracted so it's unit-testable without touching real
    // INFocusStatusCenter/Process state (mirrors MicMuteControllerTests' "assert the one
    // property that actually matters" discipline for code with no injectable seam).
    static func focusStateChanged(before: Bool, after: Bool) -> Bool {
        before != after
    }

    // Requests INFocusStatusCenter authorization itself rather than only reading
    // FocusModeMonitor.isAuthorized (pre-65-08-checkpoint bug): that flag was previously only
    // ever set true via the unrelated Phase-38 Focus HUD Settings toggle, so a user who never
    // touched that toggle got a silent, unexplained failure flash here forever. Mirrors
    // SettingsView.swift's own requestAuthorization call site — completion isn't guaranteed
    // to land on the main thread, so it's re-dispatched exactly the same way.
    static func toggle(onResult: @escaping (Bool) -> Void) {
        FocusModeMonitor.requestAuthorization { granted in
            DispatchQueue.main.async {
                guard granted else { onResult(false); return }
                let before = INFocusStatusCenter.default.focusStatus.isFocused ?? false
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                task.arguments = ["run", focusShortcutName]
                do {
                    try task.run()
                } catch {
                    onResult(false)
                    return
                }
                task.terminationHandler = { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let after = INFocusStatusCenter.default.focusStatus.isFocused ?? before
                        onResult(focusStateChanged(before: before, after: after))
                    }
                }
            }
        }
    }
}
