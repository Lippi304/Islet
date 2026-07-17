import AppKit

// Phase 39 Plan 03 / HUD-03 / HUD-04 — production OSD key interceptor.
//
// Architecture implemented: `suppression-unreliable` (39-01-SUMMARY.md's on-device spike
// finding — see that file for the full checkpoint results). The spike confirmed that
// `.defaultTap` + returning `nil` from the tap callback does NOT actually suppress the native
// macOS volume/brightness OSD on this dev machine/macOS Tahoe, despite the swallow decision
// itself decoding and firing correctly (SWALLOWING was logged, the OSD still appeared). Per the
// spike's own recommendation, this interceptor is therefore a PERMANENT `.listenOnly`-only
// detector: it never swallows any event, regardless of `suppressionArmed()`'s value, and the
// dual-mode/single-mode swallow-decision code paths described elsewhere in this plan are never
// built at all. Plan 39-06's Settings toggle for "suppress the native OSD" becomes a documented
// no-op as a direct result of this finding — flagged for that plan's own SUMMARY.md.
//
// Mirrors `DropInterceptTap.swift`'s permission/health-check/lifecycle skeleton, with the one
// required structural deviation from that file (Pitfall 1, 39-RESEARCH.md): the tap's run loop
// runs on a DEDICATED background DispatchQueue, not the main run loop — rapid key-repeat
// scrubbing risks Droppy's documented main-thread-contention "double HUD" bug.
enum OSDKeyKind {
    case volume
    case brightness
}

final class OSDInterceptor {
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapRunLoop: CFRunLoop?
    private var healthCheckTimer: Timer?
    private let tapQueue = DispatchQueue(label: "com.islet.osd-tap", qos: .userInteractive)

    // Read FRESH on every single key event (never cached) inside handle(), even though this
    // suppression-unreliable branch never actually swallows — keeps the contract identical to
    // what a future suppress-capable branch would need, should Apple's OSD behavior ever change.
    private let suppressionArmed: () -> Bool
    private let onKeyPress: (OSDKeyKind) -> Void

    // No-prompt Accessibility query, exposed for Plan 39-05/39-06 to read (e.g. an accurate
    // "suppression unavailable" hint) — never used internally to gate this tap, since
    // `.listenOnly` requires no Accessibility grant and suppression is never attempted here.
    static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    init(suppressionArmed: @escaping () -> Bool, onKeyPress: @escaping (OSDKeyKind) -> Void) {
        self.suppressionArmed = suppressionArmed
        self.onKeyPress = onKeyPress
    }

    // Idempotent (mirrors DropInterceptTap.start()). D-08 / T-39-03-03: never requests
    // Accessibility from this file — `.listenOnly` needs no permission grant to detect
    // NX_SYSDEFINED (spike-confirmed: 39-01-SUMMARY.md's detect-only checkpoint succeeded with
    // no permission dialog observed), and suppression is never attempted in this branch, so
    // there is nothing to prompt for.
    func start() {
        guard machPort == nil else { return }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,                 // NEVER .cgAnnotatedSessionEventTap — Pitfall 1
            place: .headInsertEventTap,
            options: .listenOnly,                     // permanent — this branch never swallows
            eventsOfInterest: CGEventMask(1 << 14),   // NX_SYSDEFINED (no CGEventType case on this SDK)
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let interceptor = Unmanaged<OSDInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
                return interceptor.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }   // silent no-op — mirrors DropInterceptTap D-12

        machPort = tap
        tapQueue.async { [weak self] in
            guard let self else { return }
            let runLoop = CFRunLoopGetCurrent()
            self.tapRunLoop = runLoop
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(runLoop, source, .commonModes)
            self.runLoopSource = source
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()   // keeps this dedicated queue's run loop alive
        }

        // Pitfall C precedent (DropInterceptTap.swift, this codebase): a tap can go silently
        // inert after a Release re-sign/re-launch without tapCreate/tapIsEnabled reporting a
        // problem at creation time. Poll every 5s and reinstall if needed.
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkHealthAndReinstallIfNeeded()
        }
    }

    private func checkHealthAndReinstallIfNeeded() {
        guard let machPort else { return }
        if !CGEvent.tapIsEnabled(tap: machPort) {
            stop()
            start()
        }
    }

    private static let volumeCodes: Set<Int> = [0, 1, 7]    // SOUND_UP, SOUND_DOWN, MUTE
    private static let brightnessCodes: Set<Int> = [2, 3]   // BRIGHTNESS_UP, BRIGHTNESS_DOWN

    // Bounded key-code allowlist (T-39-03-01) — every other code, including all 4 media
    // transport keys, falls out of the switch with `kind == nil` and is passed through
    // UNCONDITIONALLY before any decision is evaluated. NSEvent(cgEvent:) construction MUST
    // happen on main (Pitfall 3 — Caps Lock/TSM crash); this sync block is kept tiny — decode +
    // classify only, no I/O.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type.rawValue == 14 /* NX_SYSDEFINED */ else { return Unmanaged.passUnretained(event) }

        let kind: OSDKeyKind? = DispatchQueue.main.sync {
            guard let nsEvent = NSEvent(cgEvent: event) else { return nil }
            let data1 = nsEvent.data1
            let keyCode = (data1 & 0xFFFF0000) >> 16
            let keyFlags = data1 & 0x0000FFFF
            let keyDown = ((keyFlags & 0xFF00) >> 8) == 0x0A
            guard keyDown else { return nil }
            if Self.volumeCodes.contains(keyCode) { return .volume }
            if Self.brightnessCodes.contains(keyCode) { return .brightness }
            return nil
        }

        guard let kind else { return Unmanaged.passUnretained(event) }   // transport keys + everything else

        // `.listenOnly` can never swallow regardless of `suppressionArmed()` — read it anyway
        // (fresh, never cached) so a future re-enable of a suppress-capable tap variant is a
        // one-line call-site change, not a rediscovery of this contract.
        _ = suppressionArmed()
        DispatchQueue.main.async { [onKeyPress] in onKeyPress(kind) }   // level-read/enqueue, kept off the tap's critical return path — Pitfall 3
        return Unmanaged.passUnretained(event)   // always passthrough — this branch never swallows
    }

    nonisolated func stop() {
        if let runLoopSource, let tapRunLoop {
            CFRunLoopRemoveSource(tapRunLoop, runLoopSource, .commonModes)
            CFRunLoopStop(tapRunLoop)
        }
        if let machPort { CGEvent.tapEnable(tap: machPort, enable: false) }
        machPort = nil
        runLoopSource = nil
        tapRunLoop = nil
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
}
