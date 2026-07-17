#if DEBUG
import AppKit

// Phase 39 Plan 01 / HUD-03 / HUD-04 — THROWAWAY on-device spike, deleted in 39-07 once the
// architecture is locked into the real `OSDInterceptor.swift`. Answers ROADMAP Phase 39 Success
// Criterion #1 and RESEARCH.md Open Question 2: does a `.listenOnly` CGEventTap on
// `.cgSessionEventTap` for NX_SYSDEFINED intercept volume/brightness keys without Accessibility
// (Input Monitoring only, or nothing at all), and does a `.defaultTap` variant actually suppress
// the native OSD without ever touching the 4 media transport keys. Mirrors
// `DropInterceptTap.swift`'s proven CGEventTap lifecycle (AXIsProcessTrustedWithOptions →
// tapCreate → CFMachPortCreateRunLoopSource → 5s health-check timer), with two deliberate
// deviations documented inline below.
final class OSDInterceptionSpike {
    enum SpikeMode: String {
        case detectOnly
        case detectAndSuppress
    }

    private let mode: SpikeMode
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthCheckTimer: Timer?

    init(mode: SpikeMode) {
        self.mode = mode
    }

    func start() {
        guard machPort == nil else { return }

        // Deviation 1 — this asymmetry IS the question being tested: does `.listenOnly` on
        // `.cgSessionEventTap` for NX_SYSDEFINED need Accessibility at all, or does it succeed
        // (or prompt for Input Monitoring) without it? `.detectOnly` deliberately skips the
        // Accessibility request entirely; `.detectAndSuppress` requests it exactly like
        // `DropInterceptTap.start()` does, before `tapCreate`.
        if mode == .detectAndSuppress {
            _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        }

        // Deviation 2 — `.defaultTap` (can swallow) for detectAndSuppress, `.listenOnly`
        // (detect-only, can never swallow) for detectOnly.
        let tapOptions: CGEventTapOptions = (mode == .detectAndSuppress) ? .defaultTap : .listenOnly

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,          // NEVER .cgAnnotatedSessionEventTap — Pitfall 1
            place: .headInsertEventTap,
            options: tapOptions,
            // NX_SYSDEFINED (raw 14) has no case in the public CGEventType enum on this SDK
            // (confirmed: CoreGraphics/CGEventTypes.h omits it) — build the mask from the raw
            // value directly, exactly like `type.rawValue == 14` already does in handle() below.
            eventsOfInterest: CGEventMask(1 << 14), // NX_SYSDEFINED
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let spike = Unmanaged<OSDInterceptionSpike>.fromOpaque(userInfo).takeUnretainedValue()
                return spike.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        print("[OSDSpike][\(mode)] tapCreate result: \(tap == nil ? "nil (no tap)" : "success")")
        guard let tap else { return }   // silent no-op — mirrors DropInterceptTap D-12

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        machPort = tap
        runLoopSource = source

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

    // Pattern 2 (39-RESEARCH.md) — decode NX_KEYTYPE_* from data1's bit layout, verified
    // on-device against real hardware key presses rather than assumed from community sources
    // alone (Assumptions Log A1).
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type.rawValue == 14 /* NX_SYSDEFINED */ else { return Unmanaged.passUnretained(event) }
        // Never force-unwrap — a nil NSEvent(cgEvent:) must fall through as a passthrough.
        guard let nsEvent = NSEvent(cgEvent: event) else { return Unmanaged.passUnretained(event) }

        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF0000) >> 16
        let keyFlags = data1 & 0x0000FFFF
        let keyDown = ((keyFlags & 0xFF00) >> 8) == 0x0A

        // Printed for EVERY decoded key, not just volume/brightness — confirms which raw codes
        // the 4 transport keys and Caps Lock produce too, so 39-03's allowlist can be double-checked.
        print("[OSDSpike][\(mode)] keyCode=\(keyCode) keyDown=\(keyDown)")

        // SOUND_UP=0, SOUND_DOWN=1, MUTE=7, BRIGHTNESS_UP=2, BRIGHTNESS_DOWN=3.
        if mode == .detectAndSuppress, [0, 1, 7, 2, 3].contains(keyCode), keyDown {
            print("[OSDSpike][detectAndSuppress] SWALLOWING keyCode=\(keyCode)")
            return nil   // the actual suppression test
        }

        // Every other key code in EITHER mode — critical transport-key safety check
        // (Pitfall 1): PLAY/FAST/REWIND/PREVIOUS must never enter the swallow branch.
        print("[OSDSpike][\(mode)] PASSTHROUGH keyCode=\(keyCode)")
        return Unmanaged.passUnretained(event)
    }

    nonisolated func stop() {
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let machPort { CGEvent.tapEnable(tap: machPort, enable: false) }
        machPort = nil
        runLoopSource = nil
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
}
#endif
