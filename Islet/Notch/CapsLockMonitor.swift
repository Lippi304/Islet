import AppKit

// Phase 60 / CAPS-01 (Plan 02) — the LIVE global Caps Lock modifier-key monitor. Net-new
// pattern in this codebase: the first `NSEvent.addGlobalMonitorForEvents` global monitor
// gated on Accessibility trust (every prior global monitor here — mouseMonitor,
// dragApproachMonitor — is a `.mouseMoved`/`.leftMouseDragged` monitor, which does NOT
// require Accessibility trust; `.flagsChanged` is a key-event type and does, per
// RESEARCH.md Pitfall 2).
//
// Lifecycle skeleton cloned from PowerSourceMonitor.swift:60-112 (start()/stop()/deinit
// shape); the Accessibility gate is cloned from OSDInterceptor.isAccessibilityTrusted.
@MainActor
final class CapsLockMonitor {
    // nonisolated(unsafe) so stop() can run from NotchWindowController's nonisolated deinit —
    // mirrors the codebase's existing mouseMonitor/dragApproachMonitor stored-token type
    // (`Any?`, the type NSEvent.addGlobalMonitorForEvents itself returns), NOT
    // NSObjectProtocol?.
    private nonisolated(unsafe) var monitorToken: Any?
    // Same nonisolated(unsafe) treatment as monitorToken, for the same reason (stop() must
    // reach it from a nonisolated deinit).
    private nonisolated(unsafe) var healthCheckTimer: Timer?
    // On-device report: the HUD kept re-appearing/never dismissing during normal typing —
    // `.flagsChanged` fires on EVERY modifier key (Shift, Cmd, Option, Fn...), not just Caps
    // Lock, so without this the callback re-fired (re-arming the dismiss timer or re-enqueuing
    // the HUD) on unrelated keystrokes whenever they happened to report the same capsLock bit.
    // Dedupe against the last reported state so onChange only fires on an ACTUAL transition.
    private var lastCapsLockState: Bool?
    private let onChange: (Bool) -> Void

    init(onChange: @escaping (Bool) -> Void) { self.onChange = onChange }

    // Cloned verbatim (RESEARCH.md Pitfall 2 / OSDInterceptor.isAccessibilityTrusted) — the
    // single gate every start() call checks before ever installing the monitor.
    static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    // Idempotent start (Pitfall 5 — never double-register on a fast toggle on/off/on),
    // gated on Accessibility trust. Deliberately never force-prompts for Accessibility
    // (never calls the "with options" variant that requests trust with a prompt) — the
    // established anti-pattern this codebase avoids everywhere else (Accessibility has no
    // re-request API; the user must grant it themselves in System Settings, mirrored by
    // OSDInterceptor's own discipline). Untrusted → silent no-op, not a crash — same
    // graceful-degrade shape as OSD suppression.
    //
    // Pitfall 3 (RESEARCH.md), resolved empirically in Plan 60-05's on-device checkpoint: a
    // single AXIsProcessTrusted() check at toggle-time can still read false even when System
    // Settings already shows the grant checked — the same mid-session-grant race
    // OSDInterceptor.reconcileMode() exists to cover. Mirrors that precedent: if untrusted
    // right now, arm a 5s health-check retry instead of giving up until the next relaunch.
    func start() {
        guard monitorToken == nil else { return }
        guard Self.isAccessibilityTrusted else {
            armHealthCheck()
            return
        }
        install()
    }

    private func install() {
        // Seed with the REAL current state (not nil) so the next unrelated flagsChanged event
        // (e.g. Shift while typing) is correctly recognized as a non-transition and suppressed.
        lastCapsLockState = NSEvent.modifierFlags.contains(.capsLock)
        monitorToken = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return }
            let isOn = event.modifierFlags.contains(.capsLock)
            guard isOn != self.lastCapsLockState else { return }
            self.lastCapsLockState = isOn
            self.onChange(isOn)
        }
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    private func armHealthCheck() {
        guard healthCheckTimer == nil else { return }
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.monitorToken == nil, Self.isAccessibilityTrusted else { return }
                self.install()
            }
        }
    }

    // nonisolated so the controller's nonisolated deinit can call it — mirrors
    // PowerSourceMonitor.stop()'s exact nonisolated-teardown shape.
    nonisolated func stop() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        if let token = monitorToken {
            NSEvent.removeMonitor(token)
            monitorToken = nil
        }
    }

    deinit {
        // Empty by design — the owning NotchWindowController's own @MainActor deinit calls
        // stop(), matching powerMonitor's documented ownership discipline (mirrors
        // PowerSourceMonitor.deinit's own empty body + comment).
    }
}
