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
    func start() {
        guard monitorToken == nil, Self.isAccessibilityTrusted else { return }
        monitorToken = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.onChange(event.modifierFlags.contains(.capsLock))
        }
    }

    // Pitfall 3 (RESEARCH.md, unresolved/flagged): it's unverified whether re-checking
    // Self.isAccessibilityTrusted inside start() is enough to live-reconcile a mid-session
    // Accessibility grant (like OSDInterceptor's proven reconcileMode() health-check), or
    // whether an NSEvent global monitor genuinely needs a relaunch after the grant for event
    // delivery to start. Not assumed either way here — flagged for Plan 60-05's on-device
    // checkpoint to resolve empirically.

    // nonisolated so the controller's nonisolated deinit can call it — mirrors
    // PowerSourceMonitor.stop()'s exact nonisolated-teardown shape.
    nonisolated func stop() {
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
