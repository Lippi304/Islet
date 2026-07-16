import IOKit.ps
import CoreFoundation

// Phase 3 / CHG-01 + CHG-02 — the THIN IOKit power glue (Plan 03).
//
// This is the ONLY file in the phase that touches a system power framework. Like
// NSScreen+Notch.swift and FullscreenSpaceProbe.swift, it is a thin system-call
// wrapper — NOT a pure fixture-tested seam. The riskiest CLASSIFICATION logic
// (charging vs full vs on-battery vs no-battery, percent clamp, splash debounce)
// lives in the PURE PowerActivity.swift seam (Plan 01) and is unit-tested in ms;
// this glue is verified ON-DEVICE (real hardware power events can't be unit-tested).
//
// Two parts, both compile-verified in RESEARCH (Code Examples 1 & 2, Swift 5 mode):
//   A. readCurrentPower() — lift a PowerReading out of the IOPS dictionary using the
//      CORRECT Unmanaged ownership (Copy/Create → takeRetainedValue, Get →
//      takeUnretainedValue; the Get-with-retain bug over-releases → crash, Pitfall 1).
//   B. PowerSourceMonitor — the LIVE plug/unplug notification source. Event-driven via
//      IOPSNotificationCreateRunLoopSource: NO polling clock / repeating schedule of any
//      kind anywhere here (idle CPU ~0%, locked criterion). The C callback cannot capture
//      self (Pitfall 2) → self is passed via the context pointer and the callback hops to
//      MAIN before any @Published/AppKit touch.

// Lift the current internal-battery power state into a PowerReading.
// (RESEARCH Code Example 1 — verbatim. PowerReading is defined in PowerActivity.swift;
//  do NOT redefine it here.)
func readCurrentPower() -> PowerReading {
    // Copy → owned → takeRetainedValue. Imported as Unmanaged<CFTypeRef>? → optional-chain.
    // Pitfall 3: an empty / absent source list (desktop, transient) → isPresent:false →
    // powerActivity(from:) returns nil → no splash, no crash.
    guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
    else {
        return PowerReading(isPresent: false, isOnAC: false, isCharging: false, isCharged: false, percent: 0)
    }
    for ps in sources {
        // Get → NOT owned → takeUnretainedValue (Pitfall 1: retaining a Get over-releases → crash).
        guard let d = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any]
        else { continue }
        // Internal laptop battery only (ignore UPS / external sources).
        guard (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }

        // DEFENSIVE (security T-03-05): every dictionary value is read with an optional
        // cast + a default — a missing / malformed key never force-unwraps or crashes.
        let state    = d[kIOPSPowerSourceStateKey] as? String
        let isOnAC   = (state == kIOPSACPowerValue)
        let charging = d[kIOPSIsChargingKey] as? Bool ?? false
        let charged  = d[kIOPSIsChargedKey] as? Bool ?? false
        let cur      = d[kIOPSCurrentCapacityKey] as? Int ?? 0
        let mx       = d[kIOPSMaxCapacityKey] as? Int ?? 100
        let pct      = mx > 0 ? Int((Double(cur) / Double(mx) * 100).rounded()) : cur
        return PowerReading(isPresent: true, isOnAC: isOnAC, isCharging: charging, isCharged: charged, percent: pct)
    }
    // No internal battery found in the list → no-op reading (no splash, no crash).
    return PowerReading(isPresent: false, isOnAC: false, isCharging: false, isCharged: false, percent: 0)
}

// The LIVE plug/unplug notification source (RESEARCH Code Example 2 — verbatim).
// @MainActor: the source is added to the MAIN run loop and the callback hops to main
// before touching onChange (which the controller uses to mutate @Published/AppKit).
@MainActor
final class PowerSourceMonitor {
    // nonisolated(unsafe) so stop() can run from NotchWindowController's nonisolated deinit.
    // This is only ever written on main (start/stop), and CFRunLoopRemoveSource is itself
    // thread-safe — the deinit teardown at app-quit is the sole nonisolated reader.
    private nonisolated(unsafe) var runLoopSource: CFRunLoopSource?
    // The controller passes a closure that is already on main and hops the @Published
    // mutation through handlePower (so this glue never touches SwiftUI/AppKit itself).
    private let onChange: (PowerReading) -> Void

    init(onChange: @escaping (PowerReading) -> Void) { self.onChange = onChange }

    func start() {
        // Pitfall 2: the @convention(c) callback CANNOT capture self → pass self through
        // the void* context pointer and recover it inside.
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { ctx in
            guard let ctx = ctx else { return }
            let monitor = Unmanaged<PowerSourceMonitor>.fromOpaque(ctx).takeUnretainedValue()
            // Pitfall 2: hop to MAIN before touching @Published / AppKit (the source is on
            // the main run loop, but this makes correctness independent of that).
            DispatchQueue.main.async {
                monitor.onChange(readCurrentPower())
            }
        }
        // Create → owned → takeRetainedValue.
        guard let src = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        runLoopSource = src
        // Emit the initial state once so launch state is correct. The controller must NOT
        // show a splash for this initial reading (it seeds lastActivity without firing — see
        // NotchWindowController.handlePower's didSeedInitialPower gate).
        onChange(readCurrentPower())
    }

    // nonisolated so the controller's nonisolated deinit can call it. The body is pure
    // thread-safe CF source removal on the nonisolated(unsafe) runLoopSource.
    nonisolated func stop() {
        // Remove the source (it holds the context pointer) so the pointer can't be used
        // after the owner is freed (security T-03-06).
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            runLoopSource = nil
        }
    }

    deinit {
        // deinit can't be @MainActor in Swift 5 mode, so it does NOT call stop() here.
        // The controller is @MainActor and owns the monitor for the app lifetime; its
        // deinit calls powerMonitor.stop() to remove the run-loop source — mirroring the
        // existing observer-removal discipline in NotchWindowController.deinit.
    }
}
