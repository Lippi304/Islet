import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var didHideSettingsAtLaunch = false
    // Phase 1: owns the notch overlay panel. Retained for the app's lifetime so the
    // panel and its screen-change observer stay alive (a dropped controller would
    // tear down the overlay). Parallel to `statusItem`.
    private var notchController: NotchWindowController?
    #if DEBUG_BT_SPIKE
    // Phase 5 / Plan 01 Task 3 — THROWAWAY IOBluetooth permission spike. Retained so its
    // connect/disconnect registrations stay alive while the user tests connect/disconnect.
    // Gated behind DEBUG_BT_SPIKE — NOT in a normal build. Removed before Plan 02.
    private var bluetoothSpike: BluetoothSpike?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the menu-bar status item. variableLength = sized to its content.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // A monochrome SF Symbol used as a TEMPLATE image: macOS auto-tints
            // it for light/dark menu bars (the `isTemplate = true` line is the key).
            let image = NSImage(systemSymbolName: "capsule.fill",
                                accessibilityDescription: "Islet")
            image?.isTemplate = true        // template image = the key line
            button.image = image
        }

        // The dropdown menu shown when the status item is clicked.
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…",
                     action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Islet",
                     action: #selector(quit), keyEquivalent: "q")
        // Menu items send their actions to this delegate.
        for item in menu.items { item.target = self }
        statusItem.menu = menu

        // Phase 1: build and show the notch overlay on the built-in notched display.
        // The controller resolves the correct screen, positions the panel on the
        // notch, and re-positions on every screen-configuration change.
        let controller = NotchWindowController()
        controller.start()
        self.notchController = controller

        #if DEBUG_BT_SPIKE
        // Phase 5 / Plan 01 Task 3 spike: register the IOBluetooth connect/disconnect
        // observers (no pairedDevices()/scanning) so the user can settle the macOS-26
        // permission question (A1). Throwaway — gated behind DEBUG_BT_SPIKE.
        let spike = BluetoothSpike()
        spike.start()
        self.bluetoothSpike = spike
        #endif

        // A menu-bar agent must NOT show its Settings window on launch — once
        // "Launch at login" is enabled it would otherwise pop up on every login.
        // The SwiftUI Window(id:) scene creates its window at launch, so hide it
        // right after launch. orderOut keeps the window object alive, so
        // "Settings…" can re-show it instantly via makeKeyAndOrderFront below.
        DispatchQueue.main.async { [weak self] in
            self?.hideSettingsWindowOnLaunch()
        }
    }

    // The SwiftUI Window(id:) NSWindow may not exist yet on the first run-loop
    // pass after launch, so a single orderOut can match nothing and let the
    // window flash on screen. Retry briefly until the window appears, hide it
    // once, then stop (so a window the user later opens is never re-hidden).
    private func hideSettingsWindowOnLaunch(attempt: Int = 0) {
        guard !didHideSettingsAtLaunch else { return }
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
            window.isRestorable = false          // don't let macOS restore it next launch
            window.isReleasedWhenClosed = false  // keep the window alive after a close
            window.orderOut(nil)                 // hide without destroying the window
            didHideSettingsAtLaunch = true
        } else if attempt < 50 {                 // ~1s of 20ms retries until it exists
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
                self?.hideSettingsWindowOnLaunch(attempt: attempt + 1)
            }
        }
    }

    @objc private func openSettings() {
        // macOS-26-correct: activate the (background-agent) app first, THEN open
        // the window, or it appears behind other apps / silently no-ops.
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openIsletSettings, object: nil)
        // Fallback to ensure the window is front-most even on first open, before
        // the SwiftUI notification bridge has a chance to run.
        NSApp.windows.first { $0.identifier?.rawValue == "settings" }?
            .makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // Keep the agent alive when the Settings window is hidden or closed — only
    // "Quit Islet" should terminate Islet. Without this, a SwiftUI app quits
    // when its last window closes, which would kill the menu-bar agent (and
    // would make the launch-time window-hiding above terminate the app).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
