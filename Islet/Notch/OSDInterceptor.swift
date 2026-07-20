import AppKit

// Phase 39 Plan 08 / HUD-03 / HUD-04 (D-14/D-15) — production OSD key interceptor, rebuilt as a
// dual-mode `.cghidEventTap` interceptor after 39-01's original session-level tap + `.defaultTap`
// spike was confirmed `suppression-unreliable` (see 39-01-SUMMARY.md): that tap decoded and
// swallowed events correctly but never actually hid the native OSD. `dannystewart/volumeHUD`
// (MIT, actively maintained for Tahoe) proves `.cghidEventTap` — a LOWER, HID-level interception
// point, before the Window Server session layer — works as the real fix. When armed
// (`.detectAndSuppress`/`.defaultTap`), this interceptor swallows the key event AND self-drives
// the real system volume/brightness/mute value via `VolumeReader.swift`/`BrightnessReader.swift`
// (D-15), so the key press still has a real effect. A per-type kill switch
// (`volumeSelfDriveWorking`/`brightnessSelfDriveWorking`) falls a key type back to plain
// passthrough the instant a self-drive write fails, mirroring `dannystewart/volumeHUD`'s own
// "intelligent fallback" — this key type never sits silently swallowed-and-dead. When unarmed
// (Settings toggle off, or Accessibility not trusted), this stays a pure `.detectOnly`/
// `.listenOnly` detector exactly like the prior implementation — never swallows anything.
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

    // Read FRESH on every single key event (never cached) — this is what desiredMode() consults
    // to decide whether suppression should be armed.
    private let suppressionArmed: () -> Bool
    private let onKeyPress: (OSDKeyKind) -> Void
    // Phase 39 Plan 08 / D-15 — the controller's OWN BrightnessReader instance, injected rather
    // than constructed here (a second instance would dlopen/CFBundleLoadExecutable the private
    // DisplayServices framework a second time for no reason).
    private let brightnessReader: BrightnessReader

    // No-prompt Accessibility query — desiredMode() gates suppression on this being true, exactly
    // like `.defaultTap` requires; D-08 unchanged, this file never calls
    // AXIsProcessTrustedWithOptions(prompt: true).
    static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    // Phase 39 Plan 08 / D-14 — dual-mode tap: `.detectOnly` (today's safe `.listenOnly`
    // behavior) vs `.detectAndSuppress` (NEW `.defaultTap`, only when armed).
    private enum TapMode: Equatable {
        case detectOnly
        case detectAndSuppress
    }

    // Same 39-01-confirmed NX_SYSDEFINED keyCode values, now expressed as one enum instead of
    // two separate `Set<Int>` constants (`volumeCodes`/`brightnessCodes`) — the decode itself is
    // unchanged, only the tap TYPE changes with D-14.
    private enum RawOSDKey: Int {
        case soundUp = 0
        case soundDown = 1
        case brightnessUp = 2
        case brightnessDown = 3
        case mute = 7
    }

    // Read/written across both the tap-queue callback thread and the main thread — no actor
    // isolation is available for a CGEventTap callback, so this file uses `nonisolated(unsafe)`
    // throughout, matching this file's own pre-existing convention for exactly this situation.
    private nonisolated(unsafe) var currentMode: TapMode = .detectOnly
    private nonisolated(unsafe) var volumeSelfDriveWorking = true
    private nonisolated(unsafe) var brightnessSelfDriveWorking = true

    init(
        suppressionArmed: @escaping () -> Bool,
        onKeyPress: @escaping (OSDKeyKind) -> Void,
        brightnessReader: BrightnessReader
    ) {
        self.suppressionArmed = suppressionArmed
        self.onKeyPress = onKeyPress
        self.brightnessReader = brightnessReader
    }

    // Idempotent (mirrors DropInterceptTap.start()). Resets both self-drive kill switches to
    // `true` on every start — a fresh per-launch chance, mirroring `dannystewart/volumeHUD`'s own
    // `start()` reset.
    func start() {
        guard machPort == nil else { return }
        volumeSelfDriveWorking = true
        brightnessSelfDriveWorking = true
        installTap(mode: desiredMode())

        // Pitfall C precedent (DropInterceptTap.swift, this codebase): a tap can go silently
        // inert after a Release re-sign/re-launch without tapCreate/tapIsEnabled reporting a
        // problem at creation time. Also: D-07's mid-session auto-upgrade (Accessibility just
        // granted, or the Settings toggle just flipped) needs a live poll to notice and react.
        // Poll every 5s and reconcile.
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.reconcileMode()
        }
    }

    // `.detectAndSuppress` only when BOTH the Settings toggle is on AND Accessibility is
    // trusted — otherwise `.detectOnly`, the safe fallback.
    private func desiredMode() -> TapMode {
        (suppressionArmed() && Self.isAccessibilityTrusted) ? .detectAndSuppress : .detectOnly
    }

    // D-14 — NEVER the session-level tap variant in this file anymore. `.cghidEventTap`
    // intercepts at the HID level, before the Window Server session layer, which is the
    // mechanism difference from the already-failed 39-01 attempt.
    private func installTap(mode: TapMode) {
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: mode == .detectAndSuppress ? .defaultTap : .listenOnly,
            eventsOfInterest: CGEventMask(1 << 14),   // NX_SYSDEFINED (no CGEventType case on this SDK)
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let interceptor = Unmanaged<OSDInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
                return interceptor.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }   // silent no-op — mirrors DropInterceptTap D-12

        currentMode = mode
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
    }

    // Tears down just the tap itself (NOT the healthCheckTimer) so installTap(mode:) can be
    // called again with a different mode. Mirrors stop()'s tap-teardown steps exactly, minus the
    // timer invalidation.
    private func teardownTapOnly() {
        if let runLoopSource, let tapRunLoop {
            CFRunLoopRemoveSource(tapRunLoop, runLoopSource, .commonModes)
            CFRunLoopStop(tapRunLoop)
        }
        if let machPort { CGEvent.tapEnable(tap: machPort, enable: false) }
        machPort = nil
        runLoopSource = nil
        tapRunLoop = nil
    }

    // D-07 — mid-session auto-upgrade in both directions: Accessibility just granted (or the
    // toggle just flipped on) upgrades .detectOnly -> .detectAndSuppress live; flipping the
    // toggle off (or Accessibility revoked) downgrades back, all without a relaunch.
    private func reconcileMode() {
        if machPort == nil {
            // Never installed at all (e.g. Accessibility wasn't trusted at launch) — install now.
            installTap(mode: desiredMode())
        } else if let machPort, !CGEvent.tapIsEnabled(tap: machPort) {
            teardownTapOnly()
            installTap(mode: desiredMode())
        } else if desiredMode() != currentMode {
            teardownTapOnly()
            installTap(mode: desiredMode())
        }
    }

    // Bounded key-code allowlist (T-39-08-01) — every other code, including all 4 media
    // transport keys, falls out of `RawOSDKey(rawValue:)` as `nil` and is passed through
    // UNCONDITIONALLY before any decision is evaluated. NSEvent(cgEvent:) construction MUST
    // happen on main (Pitfall 3 — Caps Lock/TSM crash); this sync block is kept tiny — decode +
    // classify only, no I/O.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type.rawValue == 14 /* NX_SYSDEFINED */ else { return Unmanaged.passUnretained(event) }
        #if DEBUG
        let debugT0 = CFAbsoluteTimeGetCurrent()
        print("[OSD-TIMING] a) tap callback fired t=\(String(format: "%.2f", debugT0 * 1000))ms (tapQueue)")
        #endif

        let rawKey: RawOSDKey? = DispatchQueue.main.sync {
            guard let nsEvent = NSEvent(cgEvent: event) else { return nil }
            let data1 = nsEvent.data1
            let keyCode = (data1 & 0xFFFF0000) >> 16
            let keyFlags = data1 & 0x0000FFFF
            let keyDown = ((keyFlags & 0xFF00) >> 8) == 0x0A
            guard keyDown else { return nil }
            return RawOSDKey(rawValue: keyCode)
        }

        guard let rawKey else { return Unmanaged.passUnretained(event) }   // transport keys + everything else

        let kind: OSDKeyKind
        switch rawKey {
        case .soundUp, .soundDown, .mute: kind = .volume
        case .brightnessUp, .brightnessDown: kind = .brightness
        }

        let shouldSwallow = currentMode == .detectAndSuppress && (
            kind == .volume ? volumeSelfDriveWorking : brightnessSelfDriveWorking
        )

        #if DEBUG
        let debugT1 = CFAbsoluteTimeGetCurrent()
        print("[OSD-TIMING] b) before main.async dispatch t=\(String(format: "%.2f", debugT1 * 1000))ms +\(String(format: "%.2f", (debugT1 - debugT0) * 1000))ms since (a)")
        #endif
        DispatchQueue.main.async { [weak self, onKeyPress] in
            #if DEBUG
            let debugT2 = CFAbsoluteTimeGetCurrent()
            print("[OSD-TIMING] b) main.async closure entered t=\(String(format: "%.2f", debugT2 * 1000))ms +\(String(format: "%.2f", (debugT2 - debugT0) * 1000))ms since (a)")
            #endif
            if shouldSwallow {
                self?.applySelfDrive(rawKey)
            }
            onKeyPress(kind)   // handleOSDKeyPress re-reads the NOW-current system state
        }   // level-read/enqueue, kept off the tap's critical return path — Pitfall 3

        return shouldSwallow ? nil : Unmanaged.passUnretained(event)
    }

    // Phase 39 Plan 08 / D-15 — self-drive: the real system volume/brightness/mute value is
    // written HERE, before onKeyPress(kind) re-reads it. On a nil (failed) write, this key TYPE's
    // kill switch flips off for the rest of this running session — it falls back to plain
    // passthrough, never left silently swallowed-and-dead (T-39-08-02).
    private func applySelfDrive(_ rawKey: RawOSDKey) {
        switch rawKey {
        case .soundUp:
            if adjustSystemVolume(increase: true) == nil { volumeSelfDriveWorking = false }
        case .soundDown:
            if adjustSystemVolume(increase: false) == nil { volumeSelfDriveWorking = false }
        case .mute:
            if toggleSystemMute() == nil { volumeSelfDriveWorking = false }
        case .brightnessUp:
            if brightnessReader.adjustBrightness(increase: true) == nil { brightnessSelfDriveWorking = false }
        case .brightnessDown:
            if brightnessReader.adjustBrightness(increase: false) == nil { brightnessSelfDriveWorking = false }
        }
    }

    // Full teardown — this remains the class's own lifecycle-teardown entry point, never called
    // from reconcileMode()'s internal mode-switch path (which only tears down the tap itself via
    // teardownTapOnly(), not the timer).
    nonisolated func stop() {
        teardownTapOnly()
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
}
