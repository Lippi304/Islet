import IOBluetooth
import AppKit

// Phase 5 / DEV-01 + DEV-02 — the THIN IOBluetooth connect/disconnect glue (Plan 02).
//
// Mirrors PowerSourceMonitor's discipline exactly: a small @MainActor system-framework
// wrapper that holds OS notification tokens and feeds a plain value (DeviceReading) into
// an injected closure. It does NO classification itself — the riskiest logic (connected vs
// disconnected, name/class→glyph, nil-name fallback, the D-04 burst/debounce) lives in the
// PURE, unit-tested DeviceActivity.swift seam (Plan 01). This file is verified ON-DEVICE
// (real Bluetooth connect/disconnect events can't be unit-tested) — the deferred UAT.
//
// SCOPE (deliberately minimal — RESEARCH Pitfall 6 / the verified spike scope):
//   - registers ONLY +registerForConnectNotifications:selector: (class-wide connect) and the
//     per-device -registerForDisconnectNotification:selector: token (Pitfall 4 retention).
//   - NO paired-device list read, NO scanning/inquiry, NO connection opening — those are the
//     prompt-sensitive calls; passively observing notifications avoids them (A1 deferred).
//
// LIFECYCLE (mirrors PowerSourceMonitor):
//   - @MainActor: start()/stop() land on the main run loop. NOTE: IOBluetooth delivers the
//     connect/disconnect @objc callbacks on its OWN coordinator queue (NOT main) — the ObjC
//     runtime ignores Swift actor isolation — so connected/disconnected EXPLICITLY hop to main
//     via DispatchQueue.main.async before touching the token dict or onReading (exactly like
//     PowerSourceMonitor's notification callback). Without this, onReading → handleDevice →
//     updateVisibility → NSWindow.setFrame/orderFront ran off-main and corrupted the overlay.
//   - start() is IDEMPOTENT (Pitfall 5: a `running` guard so a re-entrant start can't
//     double-register the class connect token).
//   - stop() is FULL teardown: it unregisters the connect token AND every retained per-device
//     disconnect token (T-06-04 resource-leak mitigation). The controller (Plan 04) is
//     @MainActor, owns the monitor for the app lifetime, and calls stop() from its deinit —
//     mirroring PowerSourceMonitor's owner-driven teardown.
@MainActor
final class BluetoothMonitor: NSObject {
    // The class-wide connect notification token (retained so it stays live — Pitfall 4).
    // nonisolated(unsafe) so the nonisolated stop() can run from NotchWindowController's
    // nonisolated deinit (mirroring PowerSourceMonitor.runLoopSource / NowPlayingMonitor). These
    // are only ever written on main (start/connect/disconnect/stop) and IOBluetoothUserNotification
    // .unregister() is itself thread-safe — the deinit teardown at app-quit is the sole nonisolated
    // reader, so there is no concurrent access.
    private nonisolated(unsafe) var connectToken: IOBluetoothUserNotification?
    // Per-device disconnect tokens, keyed by address so the disconnect callback / stop() can
    // drop them individually. Retained (Pitfall 4: a dropped token stops firing).
    private nonisolated(unsafe) var disconnectTokens: [String: IOBluetoothUserNotification] = [:]
    // Pitfall 5: idempotent start() — guards against a second registration of the class token.
    private nonisolated(unsafe) var running = false
    // The controller (Plan 04) passes a closure already on main; this glue lifts a DeviceReading
    // out of each callback and hands it over (so this file never touches @Published / SwiftUI).
    private let onReading: (DeviceReading) -> Void

    init(onReading: @escaping (DeviceReading) -> Void) {
        self.onReading = onReading
        super.init()   // NSObject — the selector targets below require @objc on an NSObject.
    }

    func start() {
        guard !running else { return }   // Pitfall 5: idempotent — never double-register.
        running = true
        // Class-wide connect: fires for ANY device connecting (D-01 all-devices). The selector
        // takes (IOBluetoothUserNotification, IOBluetoothDevice) — the verified SDK shape.
        connectToken = IOBluetoothDevice.register(forConnectNotifications: self,
                                                  selector: #selector(connected(_:device:)))
    }

    @objc private func connected(_ n: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // CRITICAL: IOBluetooth delivers this @objc selector on its OWN dispatch queue
        // (com.apple.bluetooth.iobluetooth.coordinatorQueue) — NOT the main thread. The
        // @MainActor annotation does NOT make an ObjC-runtime selector callback main-isolated,
        // so we MUST hop to main ourselves before touching the retained-token dict or calling
        // onReading (which drives @Published / AppKit via handleDevice → updateVisibility →
        // NSWindow). Mirrors PowerSourceMonitor's DispatchQueue.main.async discipline.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Register + retain the per-device disconnect token (Pitfall 4 — it must outlive the
            // registration). Keyed by address so the disconnect callback / stop() can drop it.
            if let addr = device.addressString, self.disconnectTokens[addr] == nil {
                self.disconnectTokens[addr] = device.register(forDisconnectNotification: self,
                                                              selector: #selector(self.disconnected(_:device:)))
            }
            self.emit(device, connected: true)
        }
    }

    @objc private func disconnected(_ n: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // Same off-main delivery as connected(_:device:) — hop to main before mutating the
        // token dict or calling onReading.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let addr = device.addressString {
                self.disconnectTokens[addr]?.unregister()   // drop the now-spent token (no leak).
                self.disconnectTokens[addr] = nil
            }
            self.emit(device, connected: false)
        }
    }

    // Lift the minimal raw reading out of the IOBluetooth device and hand it to the pure seam.
    // device.name is UNTRUSTED (T-05-01 / T-06-03) — passed as a plain String into DeviceReading
    // only; it is NEVER interpolated into a format string or shell here.
    private func emit(_ d: IOBluetoothDevice, connected: Bool) {
        onReading(DeviceReading(name: d.name,
                                classMajor: d.deviceClassMajor,
                                address: d.addressString,
                                connected: connected))
    }

    // Full teardown (Pitfall 5 / T-06-04): unregister the connect token AND every per-device
    // disconnect token so no OS-held token outlives the owner. Mirrors PowerSourceMonitor.stop()'s
    // owner-driven teardown; the unregister() calls are safe to invoke during the owner's deinit.
    // nonisolated so the controller's nonisolated deinit can call it (Plan 04 / T-06-12), mirroring
    // PowerSourceMonitor.stop() / NowPlayingMonitor.stop(). The body is thread-safe token
    // unregistration on the nonisolated(unsafe) tokens.
    nonisolated func stop() {
        connectToken?.unregister()
        connectToken = nil
        disconnectTokens.values.forEach { $0.unregister() }
        disconnectTokens.removeAll()
        running = false
    }
}
