import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var licenseObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    // Plan 27-04 checkpoint fix: a plain AppKit NSWindow that AppDelegate owns
    // and creates lazily on first real open request. Replaces a SwiftUI
    // `Window(id: "settings")` scene whose notification bridge lived INSIDE
    // that window's own (not-yet-created) content view — a circular
    // dependency that silently never bootstrapped once `.defaultLaunchBehavior
    // (.suppressed)` kept the scene from auto-creating at launch (confirmed
    // on-device: `NSApp.windows` never contained a "settings"-identified
    // window at click time). AppDelegate is unconditionally alive for the
    // app's whole lifetime, so this has no equivalent "never created" failure
    // mode, and needs no restoration/suppression handling at all.
    private var settingsWindow: NSWindow?
    // Phase 1: owns the notch overlay panel. Retained for the app's lifetime so the
    // panel and its screen-change observer stay alive (a dropped controller would
    // tear down the overlay). Parallel to `statusItem`.
    // Quick task 260708-u47: not `private` so SettingsView can read the live
    // nowPlayingState.isHealthy via the standard `NSApp.delegate as? AppDelegate` idiom.
    var notchController: NotchWindowController?

    #if DEBUG
    // D-08/D-09: a SEPARATE status item for the 3 stub-flip testing actions, kept
    // apart from `statusItem` so the debug controls stay reachable even while the
    // primary item is in the D-05 locked-click state (nil-ing `statusItem.menu`
    // while locked would otherwise make debug items unreachable exactly when a
    // developer most needs to flip the stub back to licensed). Absent from Release.
    private var debugStatusItem: NSStatusItem!
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        // TRIAL-01/D-10: must run before controller.start() so LicenseState.shared
        // already has a valid trial start date the first time updateVisibility()
        // runs inside start().
        let isFirstLaunch = TrialManager.shared.recordFirstLaunchIfNeeded()

        // Phase 27 / VISUAL-03 / D-08: must run before controller.start() so the
        // panel's first show already reads the migrated (not default) accent —
        // same "before controller.start()" ordering constraint as the trial
        // recording above.
        ActivitySettings.migrateLegacyAccentIfNeeded()

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
        menu = NSMenu()
        menu.addItem(withTitle: "Settings…",
                     action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Islet",
                     action: #selector(quit), keyEquivalent: "q")
        // Menu items send their actions to this delegate.
        for item in menu.items { item.target = self }
        statusItem.menu = menu
        // D-05: route the initial click behavior to the live license state.
        applyMenuBarClickRouting(isLicensed: LicenseState.shared.isEntitled)

        // Re-apply D-05 routing whenever license state changes (e.g. a DEBUG
        // stub-flip writes UserDefaults) — mirrors NotchWindowController's
        // existing defaultsObserver pattern.
        licenseObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.applyMenuBarClickRouting(isLicensed: LicenseState.shared.isEntitled)
        }

        // Plan 27-04 checkpoint fix: AppDelegate itself listens for the open-request
        // (posted by this file's openSettings() and by NotchWindowController's
        // onboarding Settings-hop) and shows its own AppKit-owned window. Since
        // AppDelegate exists for the app's entire lifetime, this observer is always
        // registered by the time either caller can possibly post — no ordering
        // dependency on a SwiftUI Scene/View having been created first.
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .openIsletSettings, object: nil, queue: .main
        ) { [weak self] _ in
            self?.showSettingsWindow()
        }

        // Phase 1: build and show the notch overlay on the built-in notched display.
        // The controller resolves the correct screen, positions the panel on the
        // notch, and re-positions on every screen-configuration change.
        let controller = NotchWindowController()
        controller.start(isFirstLaunch: isFirstLaunch)
        self.notchController = controller

        #if DEBUG
        setupDebugMenu()
        #endif
    }

    // Plan 27-04 checkpoint fix: created lazily on first real request instead of
    // at launch, so there is no "auto-appears on launch" class of bug to guard
    // against at all (the pre-existing hideSettingsWindowOnLaunch()/
    // .defaultLaunchBehavior(.suppressed)/window-restoration workarounds this
    // replaces all existed only because the old SwiftUI Window(id:) scene DID
    // auto-create+auto-show at launch and had to be fought back into hiding).
    private func showSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Islet Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        // Matches the identifier the pre-existing NotchWindowController.swift
        // onboarding-hop fallback (`NSApp.windows.first { $0.identifier?.rawValue
        // == "settings" }`) already looks for — no change needed there.
        window.identifier = NSUserInterfaceItemIdentifier("settings")
        window.isReleasedWhenClosed = false  // keep it alive across close, like the old window
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    // D-05: while locked, a click has nothing useful to do except jump straight
    // to Settings, so `statusItem.menu` and `button.action` must be mutually
    // exclusive — AppKit shows the assigned `.menu` automatically on click and
    // silently ignores `button.action` while `.menu` is non-nil (Pitfall 3).
    // Per D-06, this method never touches `statusItem.button.image` — the
    // menu-bar icon's own appearance never changes across states.
    private func applyMenuBarClickRouting(isLicensed: Bool) {
        if isLicensed {
            statusItem.menu = menu
            statusItem.button?.action = nil
        } else {
            statusItem.menu = nil
            statusItem.button?.target = self
            statusItem.button?.action = #selector(openSettings)
        }
    }

    @objc private func openSettings() {
        NotificationCenter.default.post(name: .openIsletSettings, object: nil)
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

    #if DEBUG
    // D-08: the sole testing seam for the license/trial gate — 3 stub-flip
    // actions, no shortened-trial-length action (D-09). Fully absent from
    // Release builds.
    private func setupDebugMenu() {
        debugStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        debugStatusItem.button?.title = "🐞"

        let debugMenu = NSMenu()
        debugMenu.addItem(withTitle: "Debug: Force Expired",
                          action: #selector(debugForceExpired), keyEquivalent: "")
        debugMenu.addItem(withTitle: "Debug: Force Licensed",
                          action: #selector(debugForceLicensed), keyEquivalent: "")
        debugMenu.addItem(withTitle: "Debug: Reset Trial",
                          action: #selector(debugResetTrial), keyEquivalent: "")
        for item in debugMenu.items { item.target = self }
        debugStatusItem.menu = debugMenu
    }

    @objc private func debugForceExpired() {
        UserDefaults.standard.set(LicenseState.DebugOverride.forceExpired.rawValue,
                                   forKey: LicenseState.debugOverrideKey)
    }

    @objc private func debugForceLicensed() {
        UserDefaults.standard.set(LicenseState.DebugOverride.forceLicensed.rawValue,
                                   forKey: LicenseState.debugOverrideKey)
    }

    @objc private func debugResetTrial() {
        UserDefaults.standard.removeObject(forKey: LicenseState.debugOverrideKey)
        TrialManager.shared.debugResetTrial()
        // Gap closure (Plan 10-04 manual verification): a reset with no re-seed leaves
        // trialStartDate() nil for the rest of the running process — the trial only
        // "restarted" on the next actual app relaunch, not live. Re-recording here
        // makes Reset Trial usable for on-device testing without quitting the app.
        TrialManager.shared.recordFirstLaunchIfNeeded()
    }
    #endif
}
