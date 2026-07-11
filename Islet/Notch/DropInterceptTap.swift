import AppKit

// Phase 24 / SHELF-01 / SHELF-02 (D-10) — closes the drop-interception gap Plan 24-02's Task 3
// UAT surfaced: because NotchPanel is deliberately click-through and never a registered
// NSDraggingDestination, a real drop used to fall through to Finder's Desktop underneath, which
// performed its own same-volume MOVE, relocating the user's original file. This CGEventTap
// swallows the terminating .leftMouseUp for a drag landing in the already-armed accept region —
// stopping Finder's Desktop from ever seeing the drop complete — while still landing the file in
// the shelf via a DIRECTLY-invoked callback (Pitfall A: Plan 24-03 Task 2's on-device spike
// confirmed the existing dragEndMonitor NSEvent path never fires for a tap-swallowed event, so
// shelf-landing must not depend on it).
//
// Lifecycle mirrors BluetoothMonitor.swift (the closest analog in this codebase): idempotent
// start(), full stop() teardown, nonisolated stop() callable from a nonisolated deinit.
final class DropInterceptTap {
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthCheckTimer: Timer?

    // Reads the controller's EXISTING isDragApproaching flag — no new parallel state (CR-01).
    private let shouldSwallow: () -> Bool
    // Invokes the controller's EXISTING handleDragApproachEnd() directly from the swallow branch
    // (Pitfall A) — never relies on the separate dragEndMonitor NSEvent consumer.
    private let onIntercept: () -> Void

    init(shouldSwallow: @escaping () -> Bool, onIntercept: @escaping () -> Void) {
        self.shouldSwallow = shouldSwallow
        self.onIntercept = onIntercept
    }

    // Idempotent (mirrors BluetoothMonitor.start()'s `guard !running`). Safe to call on every
    // drag-approach edge, not just the first.
    func start() {
        guard machPort == nil else { return }

        // Assumption A6 (confirmed on-device, 24-03-SUMMARY.md): Accessibility, not Input
        // Monitoring, gates tap creation. Request/prompt if not already trusted, then proceed
        // regardless of the return value — tapCreate below is the authoritative gate (D-12: a nil
        // tap is a silent no-op, no crash, no dialog).
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.leftMouseUp.rawValue),
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<DropInterceptTap>.fromOpaque(userInfo).takeUnretainedValue()
                return tap.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }   // D-12 — permission likely not granted, silently disabled

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        machPort = tap
        runLoopSource = source

        // Pitfall C (this project's own prior Release-only signing incident): a tap can go
        // silently inert after a Release re-sign/re-launch without tapCreate/tapIsEnabled
        // reporting a problem at creation time. Poll every 5s and reinstall if needed.
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

    // Pitfall B — pass through unmodified for EVERY event except the single specific
    // .leftMouseUp where shouldSwallow() is freshly re-evaluated (never cached) and true.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .leftMouseUp, shouldSwallow() else { return Unmanaged.passUnretained(event) }
        onIntercept()   // Pitfall A — shelf-landing invoked BEFORE returning nil
        return nil
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
