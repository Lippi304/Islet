import SwiftUI
import AppKit
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    // Phase 40 / HUD-06 (redesign) — a small red dot on the menu-bar icon itself, shown when
    // Sparkle finds an update. Replaces the earlier collapsed-pill badge overlay (D-05), which
    // needed the pointer to land inside NotchWindowController's click-through hot-zone to be
    // tappable at all — the status item's button is always fully clickable, so this sidesteps
    // that whole class of bug instead of fixing it.
    private var updateDotView: NSView!
    private var didHideSettingsAtLaunch = false
    private var licenseObserver: NSObjectProtocol?
    // Phase 40 / HUD-06 — owns the Sparkle updater for the app's lifetime, parallel to
    // notchController. `userDriverDelegate: nil` means Sparkle's own default
    // SPUStandardUserDriver renders the standard alert (no custom SPUUserDriver, explicitly
    // out of scope per REQUIREMENTS.md).
    private var updaterController: SPUStandardUpdaterController!
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
        // Debug session old-islet-instance-stays-open (2026-07-19): Xcode's Stop button is
        // documented to not always reliably kill LSUIElement/background-agent apps (Apple
        // Developer Forums thread 47777) — a stopped debug process can keep running
        // invisibly with its menu-bar icon still live. Self-heal on every launch by force-
        // terminating any other running Islet process first, so a fresh Cmd+R always
        // converges to exactly one instance instead of requiring a manual quit.
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        for other in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        where other != .current {
            other.forceTerminate()
        }

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

            // Phase 40 / HUD-06 (redesign) — fixed-size red dot, top-trailing corner of the
            // icon, hidden until an update is found. A plain colored NSView (not baked into the
            // template image) so it keeps its red color regardless of the auto-tinted icon.
            let dot = NSView()
            dot.wantsLayer = true
            dot.layer?.backgroundColor = NSColor.systemRed.cgColor
            dot.layer?.cornerRadius = 3
            dot.isHidden = true
            dot.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 6),
                dot.heightAnchor.constraint(equalToConstant: 6),
                dot.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -1),
                dot.topAnchor.constraint(equalTo: button.topAnchor, constant: 1)
            ])
            updateDotView = dot
        }

        // The dropdown menu shown when the status item is clicked.
        menu = NSMenu()
        menu.addItem(withTitle: "Settings…",
                     action: #selector(openSettings), keyEquivalent: ",")
        // Phase 40 / HUD-06 — sits between "Settings…" and the separator (40-UI-SPEC.md Menu
        // Item Contract).
        menu.addItem(withTitle: "Check for Updates…",
                     action: #selector(checkForUpdates), keyEquivalent: "")
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
            // Phase 40 / HUD-06 (D-11) — re-apply the auto-update-check toggle live, mirrors
            // applyMenuBarClickRouting's own re-apply-on-change pattern above.
            // Guarded by equality: Sparkle's setter itself writes back to UserDefaults
            // (SUHost setBool:forUserDefaultsKey:), which re-posts didChangeNotification —
            // an unconditional set here re-triggers this closure forever (crash-loop).
            let desired = UserDefaults.standard.object(forKey: ActivitySettings.autoUpdateCheckKey) as? Bool ?? true
            if self?.updaterController?.updater.automaticallyChecksForUpdates != desired {
                self?.updaterController?.updater.automaticallyChecksForUpdates = desired
            }
        }

        // Phase 1: build and show the notch overlay on the built-in notched display.
        // The controller resolves the correct screen, positions the panel on the
        // notch, and re-positions on every screen-configuration change.
        let controller = NotchWindowController()
        controller.start(isFirstLaunch: isFirstLaunch)
        self.notchController = controller

        // Phase 40 / HUD-06 — construct Sparkle after the notch controller.
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        // D-12: the `UserDefaults.standard.object(forKey:) as? Bool ?? true` shape mirrors
        // NotchWindowController.activityEnabled(_:)'s pattern but with a `true` default,
        // distinct from that method's focusKey-only `false` branch.
        updaterController.updater.automaticallyChecksForUpdates = UserDefaults.standard.object(forKey: ActivitySettings.autoUpdateCheckKey) as? Bool ?? true

        // A menu-bar agent must NOT show its Settings window on launch — once
        // "Launch at login" is enabled it would otherwise pop up on every login.
        // The SwiftUI Window(id:) scene creates its window at launch, so hide it
        // right after launch. orderOut keeps the window object alive, so
        // "Settings…" can re-show it instantly via makeKeyAndOrderFront below.
        // Phase 26 / D-08: onboarding now lives entirely inside the notch panel
        // (NotchWindowController.start(isFirstLaunch:)), so Settings must never
        // auto-open on any launch, first or not — unconditionally hide it.
        DispatchQueue.main.async { [weak self] in
            self?.hideSettingsWindowOnLaunch()
        }

        #if DEBUG
        setupDebugMenu()
        #endif
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
        // macOS-26-correct: activate the (background-agent) app first, THEN open
        // the window, or it appears behind other apps / silently no-ops.
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openIsletSettings, object: nil)
        // Fallback to ensure the window is front-most even on first open, before
        // the SwiftUI notification bridge has a chance to run.
        NSApp.windows.first { $0.identifier?.rawValue == "settings" }?
            .makeKeyAndOrderFront(nil)
    }

    // Phase 40 / HUD-06 — RESEARCH.md Pitfall 2 / 40-UI-SPEC.md Menu Item Contract: unlike
    // openSettings(), no NSApp.activate(ignoringOtherApps:) here — this is an explicit
    // user-initiated click, so Sparkle's own dialog activating/stealing focus on tap is
    // expected and acceptable.
    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
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

// Phase 40 / HUD-06 (D-13, RESEARCH.md Pattern 2) — no updaterDidNotFindUpdate override: the
// dot only needs to go visible on a genuine find, nothing needs to actively hide it again (a
// successful install relaunches the app, resetting it to hidden on next launch).
extension AppDelegate: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        updateDotView?.isHidden = false
    }
}
