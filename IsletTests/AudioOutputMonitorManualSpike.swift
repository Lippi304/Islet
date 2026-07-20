import XCTest
@testable import Islet

// MANUAL SPIKE — DO NOT RUN VIA `xcodebuild test` (the full Islet.app test host hangs
// headless — this project's established xcodebuild-test-headless-hang precedent). Run via
// Xcode Cmd-U for THIS single test method only, then read the Xcode console and follow the
// D-03 on-device verification steps in 47-03-PLAN.md Task 2.
final class AudioOutputMonitorManualSpike: XCTestCase {

    @MainActor
    func testManualDeviceEnumerationAndSwitch() {
        var lastDevices: [AudioOutputDevice] = []
        var monitor: AudioOutputMonitor!
        monitor = AudioOutputMonitor(onDevicesChanged: { devices in
            lastDevices = devices
            devices.forEach { device in
                print("[AudioOutputSpike] uid=\(device.uid) name=\(device.name) isDefault=\(device.isDefault) hasVolumeControl=\(monitor.hasVolumeControl(deviceUID: device.uid))")
            }
        })
        monitor.start()

        // Let the initial onDevicesChanged print settle.
        RunLoop.current.run(until: Date().addingTimeInterval(15))

        if let switchTarget = lastDevices.first(where: { !$0.isDefault }) {
            monitor.setDefaultOutput(switchTarget) { success in
                print("[AudioOutputSpike] switch result: \(success)")
            }
        }

        // Window for the developer to manually connect/disconnect the 2 Bluetooth devices and
        // the USB/wired device per 47-03-PLAN.md Task 2 while console output keeps updating.
        RunLoop.current.run(until: Date().addingTimeInterval(45))

        monitor.stop()

        // Always green — the real pass/fail criteria is the human-read console output plus
        // Task 2's on-device checkpoint, never this trivial assertion.
        XCTAssertTrue(true, "manual spike — see console output and 47-03-PLAN.md Task 2 for the real pass/fail criteria")
    }
}
