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

    // Phase 58 / CLIP-01/02/03 — production (non-DEBUG) clipboard wiring. Distinct from
    // the #if DEBUG-only `debugClipboardMonitor` below; this is the real, always-on path.
    private var clipboardStore = ClipboardStore()
    private var clipboardMonitor: ClipboardMonitor?
    // D-revised (2026-07-23, on-device UAT amendment): rows moved into a flyout
    // submenu, but Cmd+0-9 must still restore instantly on icon-click without
    // requiring the submenu to be hovered open first — NSMenuItem keyEquivalents
    // nested in an unopened submenu never fire, so this local monitor intercepts
    // Cmd+0-9 directly while the top-level menu is tracking, independent of
    // whatever submenu state the user is in.
    private var clipboardHotkeyMonitor: Any?

    #if DEBUG
    // D-08/D-09: a SEPARATE status item for the 3 stub-flip testing actions, kept
    // apart from `statusItem` so the debug controls stay reachable even while the
    // primary item is in the D-05 locked-click state (nil-ing `statusItem.menu`
    // while locked would otherwise make debug items unreachable exactly when a
    // developer most needs to flip the stub back to licensed). Absent from Release.
    private var debugStatusItem: NSStatusItem!
    // Phase 57 spike hooks — see 57-02-SUMMARY.md for the on-device verdict.
    private var debugClipboardMonitor: ClipboardMonitor?
    private var debugHasShownPasteboardAccessExplanation = false
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
        menu.delegate = self
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

        // Phase 58 / CLIP-01/04 — seed in-memory history from the encrypted on-disk store
        // BEFORE the menu can ever be opened, then start the real (non-DEBUG) monitor so
        // every new genuine copy is captured and persisted for the app's whole lifetime.
        let loadedClipboardItems = ClipboardFileStore.load(root: ClipboardFileStore.storageRoot(), key: KeychainClipboardKeyStore().readOrCreateKey())
        for item in loadedClipboardItems { clipboardStore.append(item) }
        clipboardMonitor = ClipboardMonitor(onChange: { [weak self] item in
            guard let self else { return }
            self.clipboardStore.append(item)
            try? ClipboardFileStore.save(self.clipboardStore.items, root: ClipboardFileStore.storageRoot(), key: KeychainClipboardKeyStore().readOrCreateKey())
        })
        clipboardMonitor?.start()

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
        debugMenu.addItem(withTitle: "Spike: Like Current Track",
                          action: #selector(debugSpikeLikeCurrentTrack), keyEquivalent: "")
        debugMenu.addItem(withTitle: "Spike: Trigger Automation Prompt",
                          action: #selector(debugSpikeTriggerAutomationPrompt), keyEquivalent: "")
        debugMenu.addItem(withTitle: "Spike: Seed Clipboard Test Data",
                          action: #selector(debugSpikeSeedClipboardData), keyEquivalent: "")
        debugMenu.addItem(withTitle: "Spike: Print Clipboard Reload Result",
                          action: #selector(debugSpikePrintClipboardReload), keyEquivalent: "")
        debugMenu.addItem(withTitle: "Spike: Start Clipboard Monitor",
                          action: #selector(debugSpikeStartClipboardMonitor), keyEquivalent: "")
        debugMenu.addItem(withTitle: "Spike: Stop Clipboard Monitor",
                          action: #selector(debugSpikeStopClipboardMonitor), keyEquivalent: "")
        debugMenu.addItem(withTitle: "Spike: Write Concealed Test Item",
                          action: #selector(debugSpikeWriteConcealedTestItem), keyEquivalent: "")
        debugMenu.addItem(withTitle: "Spike: Simulate Self-Capture Write",
                          action: #selector(debugSpikeSimulateSelfCaptureWrite), keyEquivalent: "")
        debugMenu.addItem(withTitle: "Spike: Check Pasteboard Access Behavior",
                          action: #selector(debugSpikeCheckPasteboardAccessBehavior), keyEquivalent: "")
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

    // Phase 49 spike hooks — see 49-01-SUMMARY.md for the on-device verdict.
    // @MainActor required: NotchWindowController (and its spike methods) are @MainActor-
    // isolated; menu-item actions run on main but this method itself isn't inferred
    // @MainActor by default (not a protocol requirement like applicationDidFinishLaunching).
    @MainActor @objc private func debugSpikeLikeCurrentTrack() {
        notchController?.spikeLikeCurrentTrack()
    }

    @MainActor @objc private func debugSpikeTriggerAutomationPrompt() {
        notchController?.spikeTriggerAutomationPrompt()
    }

    // Phase 56 spike hooks — see 56-02-SUMMARY.md for the on-device verdict.
    @objc private func debugSpikeSeedClipboardData() {
        let items: [ClipboardItem] = [
            ClipboardItem(id: UUID(), kind: .text("Spike seed item A"), timestamp: Date()),
            ClipboardItem(id: UUID(), kind: .text("Spike seed item B"), timestamp: Date()),
            ClipboardItem(id: UUID(), kind: .image(Data([0x01, 0x02, 0x03, 0x04])), timestamp: Date())
        ]
        try? ClipboardFileStore.save(items, root: ClipboardFileStore.storageRoot(), key: KeychainClipboardKeyStore().readOrCreateKey())
        print("[Spike-Clipboard] seeded \(items.count) items to \(ClipboardFileStore.storageRoot().path)")
    }

    @objc private func debugSpikePrintClipboardReload() {
        let loaded = ClipboardFileStore.load(root: ClipboardFileStore.storageRoot(), key: KeychainClipboardKeyStore().readOrCreateKey())
        print("[Spike-Clipboard] reloaded \(loaded.count) items:")
        for item in loaded {
            print("  - id=\(item.id) kind=\(item.kind) timestamp=\(item.timestamp)")
        }
    }

    // Phase 57 spike hooks — see 57-02-SUMMARY.md for the on-device verdict.
    @MainActor @objc private func debugSpikeStartClipboardMonitor() {
        guard debugClipboardMonitor == nil else {
            print("[Spike-ClipboardMonitor] already running")
            return
        }
        debugClipboardMonitor = ClipboardMonitor(onChange: { item in
            print("[Spike-ClipboardMonitor] captured kind=\(item.kind) timestamp=\(item.timestamp)")
        })
        debugClipboardMonitor?.start()
        print("[Spike-ClipboardMonitor] monitor started")
    }

    // WR-01 fix: pairs with debugSpikeStartClipboardMonitor() so the class's documented
    // "owner calls stop() on teardown" contract has an actual call site — the debug menu
    // couldn't stop a running monitor before this.
    @MainActor @objc private func debugSpikeStopClipboardMonitor() {
        guard let monitor = debugClipboardMonitor else {
            print("[Spike-ClipboardMonitor] not running")
            return
        }
        monitor.stop()
        debugClipboardMonitor = nil
        print("[Spike-ClipboardMonitor] monitor stopped")
    }

    @objc private func debugSpikeWriteConcealedTestItem() {
        let item = NSPasteboardItem()
        item.setString("fake-password-123", forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([item])
        print("[Spike-ClipboardMonitor] wrote concealed test item to NSPasteboard.general — the running monitor must NOT print a captured line for this")
    }

    @objc private func debugSpikeSimulateSelfCaptureWrite() {
        let item = NSPasteboardItem()
        item.setString("simulated restored content", forType: .string)
        item.setData(Data(), forType: ClipboardMonitor.restoreMarkerType)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([item])
        print("[Spike-ClipboardMonitor] wrote self-capture-marker test item to NSPasteboard.general — the running monitor must NOT print a captured line for this")
    }

    @MainActor @objc private func debugSpikeCheckPasteboardAccessBehavior() {
        guard !debugHasShownPasteboardAccessExplanation else {
            print("[Spike-ClipboardMonitor] explanation already shown this session — one-time-gate holding")
            return
        }
        debugHasShownPasteboardAccessExplanation = true
        if ClipboardMonitor.needsAccessExplanation {
            let alert = NSAlert()
            alert.messageText = "Clipboard Access"
            alert.informativeText = "Islet checks your clipboard to show recent copies. This is a one-time explanation (spike placeholder — Phase 58 will replace this with final copy)."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } else {
            print("[Spike-ClipboardMonitor] accessBehavior already .always — no explanation needed")
        }
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

// Phase 58 / CLIP-01/02/03 — dynamic clipboard-history section, rebuilt from
// `clipboardStore.items` every time the status-item menu opens (AppKit calls this
// reliably before every display, including key-equivalent-triggered validation).
extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Identifier-prefix removal (never positional index math — the static
        // Settings/Check-for-Updates/Quit block's positions are fixed but this
        // section's item count varies 0-31).
        menu.items.removeAll { $0.identifier?.rawValue.hasPrefix("clip.") == true }

        var insertionIndex = 0
        // MRU-first: ClipboardStore.append pushes newest to the array's END, so
        // .reversed() renders newest-first (RESEARCH.md Pitfall 4).
        let items = Array(clipboardStore.items.reversed())

        let anchor = NSMenuItem(title: items.isEmpty ? "No items yet" : "Clipboard History", action: nil, keyEquivalent: "")
        anchor.identifier = NSUserInterfaceItemIdentifier("clip.anchor")
        anchor.isEnabled = !items.isEmpty

        if !items.isEmpty {
            let submenu = NSMenu()
            for (index, item) in items.enumerated() {
                let menuItem = NSMenuItem(title: "", action: #selector(restoreClipboardItem(_:)), keyEquivalent: index < 10 ? "\(index)" : "")
                menuItem.target = self
                menuItem.representedObject = item.id
                let rowFrame = NSRect(x: 0, y: 0, width: ClipboardRowView.rowWidth, height: 22)
                let container = ClipboardRowContainerView(frame: rowFrame)
                let rowView = ClipboardRowView(item: item, onSelect: { [weak self] in self?.restore(item) }, hoverState: container.hoverState)
                let hostingView = NSHostingView(rootView: rowView)
                // NSMenuItem.view is never auto layout-sized by NSMenu itself — without
                // an explicit frame the hosting view stays at .zero and the row renders
                // invisibly (item exists in menu.items but occupies no visible space).
                hostingView.frame = rowFrame
                hostingView.autoresizingMask = [.width, .height]
                container.addSubview(hostingView)
                menuItem.view = container
                submenu.addItem(menuItem)
            }
            anchor.submenu = submenu
        }
        menu.insertItem(anchor, at: insertionIndex); insertionIndex += 1

        // Plan 58-02 will insert "Delete All History" BEFORE this separator, between
        // the anchor and the boundary — left as the section's trailing marker for now.
        let separator = NSMenuItem.separator()
        separator.identifier = NSUserInterfaceItemIdentifier("clip.separator")
        menu.insertItem(separator, at: insertionIndex)
    }

    // Fires while the top-level status-item menu is tracking (open), independent
    // of the flyout submenu's own open/closed state — see clipboardHotkeyMonitor's
    // declaration comment for why this can't just be per-item keyEquivalents.
    func menuWillOpen(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        clipboardHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  let chars = event.charactersIgnoringModifiers,
                  chars.count == 1, let digit = Int(chars), (0...9).contains(digit)
            else { return event }
            let items = Array(self.clipboardStore.items.reversed())
            guard digit < items.count else { return event }
            self.restore(items[digit])
            self.menu.cancelTracking()
            return nil // consume — don't also let AppKit's own key-equivalent matching or a beep fire
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        if let monitor = clipboardHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            clipboardHotkeyMonitor = nil
        }
    }

    // Mouse path when the submenu is open — keyEquivalent here only fires while
    // AppKit's submenu is actually displayed (see menuWillOpen for the Cmd+0-9
    // path that must work before the submenu is opened).
    @objc private func restoreClipboardItem(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let item = clipboardStore.items.first(where: { $0.id == id })
        else { return }
        restore(item)
    }

    // The only place that writes to the system pasteboard for this feature — never
    // synthesizes a paste keystroke (CLIP-02 forbids auto-paste).
    private func restore(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        let pbItem = NSPasteboardItem()
        switch item.kind {
        case .text(let text):
            pbItem.setString(text, forType: .string)
        case .image(let data):
            pbItem.setData(data, forType: .tiff)
        }
        // Self-capture guard (T-58-04): tag this write so ClipboardMonitor's next poll
        // tick skips re-ingesting it.
        pbItem.setData(Data(), forType: ClipboardMonitor.restoreMarkerType)
        pb.writeObjects([pbItem])
    }
}

// D-revised (2026-07-23, on-device UAT amendment): SwiftUI's onHover misses
// mouseExited reliably during NSMenu's tracking-mode run loop, leaving a row's
// highlight stuck "on" after the pointer actually left. NSTrackingArea receives
// enter/exit via the AppKit responder chain directly and doesn't have that gap.
final class ClipboardHoverState: ObservableObject {
    @Published var isHovering = false
}

final class ClipboardRowContainerView: NSView {
    let hoverState = ClipboardHoverState()
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { hoverState.isHovering = true }
    override func mouseExited(with event: NSEvent) { hoverState.isHovering = false }
}

// Phase 58 / D-10 — a single clipboard-history row hosted via NSHostingView inside an
// NSMenuItem.view. Text rows single-line-truncate; image rows show a small inline
// thumbnail (~16-20pt, matching row height) rather than a generic icon + label.
struct ClipboardRowView: View {
    // Fixed row width — NSMenuItem.view's NSHostingView has no auto layout
    // driven by the menu, so both this view and the hostingView.frame set in
    // menuNeedsUpdate must agree on a concrete width or the row renders at
    // zero size (invisible, though technically present in the menu).
    static let rowWidth: CGFloat = 260

    let item: ClipboardItem
    let onSelect: () -> Void
    @ObservedObject var hoverState: ClipboardHoverState

    var body: some View {
        HStack(spacing: 6) {
            switch item.kind {
            case .text(let text):
                Text(text)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
            case .image(let data):
                // T-58-01: never force-unwrap — a corrupted/truncated decrypted image
                // degrades to a missing thumbnail, never a crash (D-04 discipline).
                if let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text("Image")
                    .font(.system(size: 13))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(width: ClipboardRowView.rowWidth, height: 22, alignment: .leading)
        .contentShape(Rectangle())
        .background(hoverState.isHovering ? Color.primary.opacity(0.08) : Color.clear)
        .onTapGesture { onSelect() }   // mouse-click path — NSMenuItem.action does not
                                        // reliably fire once .view is set (Pitfall 1)
    }
}
