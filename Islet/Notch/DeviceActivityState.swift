import Foundation

// Phase 5 / DEV-01 + DEV-02 — Pattern 2: the device-connected splash is a SEPARATE
// @Published model alongside the untouched NotchInteractionState 3-state machine and the
// sibling ChargingActivityState / NowPlayingState. It is a 1:1 clone of ChargingActivityState:
// a plain published holder — no methods, no timers, no IOBluetooth. Keeping it as its own
// model (not a NotchInteractionState phase) keeps the Phase-2 gesture tests intact and lets
// Phase-6's resolver (Plan 04) treat device activity as one more orthogonal input.
//
// The controller (Plan 04) owns it: BluetoothMonitor lifts a DeviceReading out of the
// IOBluetooth callbacks, maps via deviceActivity(from:), and sets `.activity` (nil → no
// splash). This view-bound state never touches a system framework itself.
final class DeviceActivityState: ObservableObject {
    @Published var activity: DeviceActivity?
}
