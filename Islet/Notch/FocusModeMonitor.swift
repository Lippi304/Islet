import Foundation
import Intents

// Phase 38 / HUD-05 — the THIN Focus/DND detection glue (Plan 03).
//
// This is the ONE file in the project that touches `Intents`/`INFocusStatusCenter`
// directly (mirrors NowPlayingMonitor's/PowerSourceMonitor's "isolate the fragile
// system surface behind one file" discipline — RESEARCH.md's repeated mitigation).
// A future macOS restricting this API further is a one-file swap.
//
// PATH DECISION (38-01-SUMMARY.md, on-device spike): Path A won — `INFocusStatusCenter`
// reaches `.authorized` on this dev machine (macOS 26/Tahoe), contradicting
// 38-RESEARCH.md's prediction that it was a near-certain dead end gated behind the
// Communication Notifications capability. This file therefore implements Path A, NOT
// the `~/Library/DoNotDisturb/DB/Assertions.json` + Full Disk Access fallback (Path B)
// that 38-03-PLAN.md's Task 1 action text was written against by default — see this
// plan's SUMMARY.md "Deviations" section for the full substitution rationale.
//
// There is no push notification for Focus/DND changes on this path (confirmed by
// 38-RESEARCH.md Architecture Patterns §3 — `focusStatus` is not KVO/`@objc dynamic`),
// so this monitor polls like PowerSourceMonitor's IOKit sibling is event-driven and
// BluetoothMonitor's IOBluetooth sibling is event-driven — this one alone must poll,
// at a fixed, well-above-1s interval (CONTEXT.md's Claude's Discretion).
//
// Silent-degrade convention (mirrors LocationProvider.swift's D-01 shape): any
// non-`.authorized` status, or a `nil` `isFocused` read, is treated as "no data this
// tick" — `onChange` is simply not called. No crash, no spin, no stale-state
// assumption either way.
@MainActor
final class FocusModeMonitor {
    // nonisolated(unsafe) so stop() can run from the owner's nonisolated deinit —
    // mirrors PowerSourceMonitor.runLoopSource / BluetoothMonitor's tokens exactly.
    private nonisolated(unsafe) var timer: DispatchSourceTimer?
    // Idempotent start() guard (mirrors BluetoothMonitor.running) — a re-entrant
    // start() can't double-schedule the timer.
    private nonisolated(unsafe) var running = false
    // The owner (NotchWindowController, Plan 38-05) passes a closure already on main;
    // this glue never touches @Published/AppKit itself. true = Focus/DND is active.
    private let onChange: (Bool) -> Void

    init(onChange: @escaping (Bool) -> Void) { self.onChange = onChange }

    func start() {
        guard !running else { return }   // idempotent — never double-schedule.
        running = true
        let t = DispatchSource.makeTimerSource(queue: .main)
        // 2.5s poll, 500ms coalescing leeway — well above the 1s floor RESEARCH's
        // Technical Debt table requires; Focus toggles are a deliberate human action,
        // not something needing sub-second responsiveness.
        t.schedule(deadline: .now(), repeating: 2.5, leeway: .milliseconds(500))
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    private func poll() {
        // Any non-authorized status this tick → do nothing (no onChange call at all),
        // per RESEARCH's defensive-parsing requirement: "a read that can't be trusted
        // yet is 'no data yet', not 'Focus is off'".
        guard INFocusStatusCenter.default.authorizationStatus == .authorized else { return }
        guard let isFocused = INFocusStatusCenter.default.focusStatus.isFocused else { return }
        onChange(isFocused)
    }

    // Whether Path A's authorization has already been granted — read by the owner
    // before calling start() (mirrors how PowerSourceMonitor/BluetoothMonitor are only
    // started when their respective ActivitySettings key is enabled) and by
    // ActivitySettings.focusPermissionStatusHint(toggleOn:granted:)'s `granted` input.
    static var isAuthorized: Bool {
        INFocusStatusCenter.default.authorizationStatus == .authorized
    }

    // D-02: only ever called at the moment the user flips the Settings toggle on —
    // never at launch/onboarding. Substituted for the plan's default Path-B
    // `openFullDiskAccessSettings()` action, since Path A needs a real TCC-style
    // authorization request, not a System Settings deep link (see SUMMARY.md).
    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        INFocusStatusCenter.default.requestAuthorization { status in
            completion(status == .authorized)
        }
    }

    // nonisolated so the owner's nonisolated deinit can call it (mirrors
    // PowerSourceMonitor.stop() / BluetoothMonitor.stop()).
    nonisolated func stop() {
        timer?.cancel()
        timer = nil
        running = false
    }

    deinit {
        // deinit can't be @MainActor in Swift 5 mode, so it does NOT call stop() here.
        // The owner is @MainActor and owns this monitor for its active lifetime; its
        // deinit calls focusModeMonitor.stop() to cancel the timer — mirrors
        // PowerSourceMonitor.deinit's owner-driven-teardown discipline exactly.
    }
}
