#if DEBUG_BT_SPIKE
import IOBluetooth
import AppKit

// Phase 5 / Plan 01 Task 3 — THROWAWAY IOBluetooth permission spike.
//
// PURPOSE: settle the single MEDIUM-confidence unknown (RESEARCH A1 / Open Question 1)
// BEFORE Plan 02's BluetoothMonitor + Plan 03's UI are built on it — does PASSIVELY
// observing connect/disconnect notifications, from this un-sandboxed LSUIElement GUI
// agent on macOS 26, trigger a TCC "wants to use Bluetooth" prompt, and do callbacks
// fire? This decides Success Criterion 3 ("no intrusive permission prompts") and whether
// project.yml needs INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription.
//
// SCOPE (deliberately minimal — the prompt-sensitive calls are AVOIDED, RESEARCH Pitfall 6):
//   - registers ONLY +registerForConnectNotifications:selector: (class connect) and the
//     per-device -registerForDisconnectNotification:selector: (Pitfall 4 retention).
//   - NO pairedDevices() read, NO startInquiry/scanning, NO connection opening.
//   - prints "BT connect:" / "BT disconnect:" with name + class + address so the USER can
//     read the live run log / Console.app while connecting/disconnecting devices.
//
// THROWAWAY: this whole file is gated behind `#if DEBUG_BT_SPIKE` and is NOT compiled in a
// normal build. The real registration lives in Plan 02's BluetoothMonitor. Remove or leave
// disabled before Plan 02.
@MainActor
final class BluetoothSpike: NSObject {
    private var connectToken: IOBluetoothUserNotification?
    private var disconnectTokens: [String: IOBluetoothUserNotification] = [:]

    func start() {
        // Register on the MAIN run loop so callbacks arrive on main (Pitfall 5). The selector
        // target must be @objc (this is an NSObject subclass — Pitfall 5).
        connectToken = IOBluetoothDevice.register(forConnectNotifications: self,
                                                  selector: #selector(deviceConnected(_:device:)))
        NSLog("BT spike: registered for connect notifications (token=\(connectToken != nil ? "ok" : "nil"))")
    }

    // The selector takes (IOBluetoothUserNotification, IOBluetoothDevice) — verified SDK shape.
    @objc private func deviceConnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let addr = device.addressString
        // Register + retain the per-device disconnect token (Pitfall 4 — it must outlive the
        // registration). Keyed by address so stop()/the disconnect callback can drop it.
        if let addr, disconnectTokens[addr] == nil {
            disconnectTokens[addr] = device.register(forDisconnectNotification: self,
                                                     selector: #selector(deviceDisconnected(_:device:)))
        }
        // device.name is UNTRUSTED — printed only, never used in a format/shell (T-05-01).
        NSLog("BT connect: name=%@ class=%u addr=%@",
              device.name ?? "(nil)", device.deviceClassMajor, addr ?? "(nil)")
    }

    @objc private func deviceDisconnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let addr = device.addressString
        if let addr { disconnectTokens[addr]?.unregister(); disconnectTokens[addr] = nil }
        NSLog("BT disconnect: name=%@ class=%u addr=%@",
              device.name ?? "(nil)", device.deviceClassMajor, addr ?? "(nil)")
    }

    func stop() {
        connectToken?.unregister(); connectToken = nil
        disconnectTokens.values.forEach { $0.unregister() }
        disconnectTokens.removeAll()
    }
}
#endif
