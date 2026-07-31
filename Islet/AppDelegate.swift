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
    // Phase 66 / MENUBAR-01/02/03 (D-02) — retained for the app's lifetime, parallel to
    // notchController/statusItem. Implicitly-unwrapped + constructed inside
    // applicationDidFinishLaunching (like statusItem below): MenuBarOverflowController is
    // @MainActor, so a class-scope default initializer here would run in a synchronous
    // nonisolated context and fail to compile. Activated unconditionally, no Settings
    // toggle, no permission gate.
    private var menuBarOverflowController: MenuBarOverflowController!

    // Phase 58 / CLIP-01/02/03 — production (non-DEBUG) clipboard wiring.
    private var clipboardStore = ClipboardStore()
    private var clipboardMonitor: ClipboardMonitor?
    // Phase 64 / NOTES-01/02/03 — Quick Notes menu-bar capture (D-13: menu-bar-only, zero
    // notch/IslandResolver participation). Parallel to clipboardStore/clipboardMonitor above.
    private var quickNotesStore = QuickNotesStore()
    private let quickNotesController = QuickNotesController()
    private lazy var quickNotesPopover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: QuickNotesPopoverView(controller: quickNotesController))
        return popover
    }()
    // Plan 64-08 (bug fix, root cause) — SwiftUI's Menu (the file-picker added in this plan's
    // Task 1) is a documented AppKit/SwiftUI interop gap: once a Menu exists anywhere in a
    // popover's hosted content, NSPopover.behavior = .transient's own outside-click/app-switch
    // auto-dismiss silently stops firing, even though `.transient` above was never changed.
    // This observer restores exactly the missing half of that contract (closing when the user
    // switches away to another app) via the supported NSApplication notification, rather than
    // fighting SwiftUI's internal Menu/NSMenu tracking machinery, which isn't ours to control.
    private var quickNotesPopoverDeactivationObserver: NSObjectProtocol?
    // Plan 64-08 (bug fix, root-cause round 2) — didResignActiveNotification above turned out
    // to only cover SOME app-switch paths (confirmed working for Cmd+Tab) but not a direct
    // click on an already-visible background app's window, which doesn't reliably produce the
    // same active-app resign transition. A global mouse-down monitor is the correct
    // complement: per Apple's own documented contract, addGlobalMonitorForEvents only ever
    // receives events landing in ANOTHER application's windows, so it structurally can never
    // see a click inside this popover's own Menu (a same-app event) — it cannot regress the
    // already-approved Menu-click behavior from earlier in this plan.
    private var quickNotesOutsideClickMonitor: Any?
    // D-revised (2026-07-23, on-device UAT amendment): rows moved into a flyout
    // submenu, but Cmd+0-9 must still restore instantly on icon-click without
    // requiring the submenu to be hovered open first — NSMenuItem keyEquivalents
    // nested in an unopened submenu never fire, so this local monitor intercepts
    // Cmd+0-9 directly while the top-level menu is tracking, independent of
    // whatever submenu state the user is in.
    private var clipboardHotkeyMonitor: Any?
    // D-11/D-12/D-13: persisted (not in-session) one-time gate for the pasteboard-access
    // explanation — matches ActivitySettings' domain.key UserDefaults-key naming
    // convention, defined locally since this phase's scope is limited to AppDelegate.swift.
    private static let clipboardAccessExplanationShownKey = "clipboard.pasteboardAccessExplanationShown"

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
        // Phase 64 / NOTES-01 (Plan 64-06 Task 3, on-device-revised order) — "New Note…" is
        // now the very first item so the dynamic Clipboard History block (inserted right
        // after it in menuNeedsUpdate, ending in its own separator) renders above
        // Settings/Check for Updates, not below.
        menu.addItem(withTitle: "New Note…",
                     action: #selector(openQuickNotesPopover), keyEquivalent: "")
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

        // Plan 64-08 (bug fix) — see quickNotesPopoverDeactivationObserver's declaration
        // comment: restores .transient's "closes when the app is deactivated" behavior, which
        // broke once the file-picker Menu was added to the popover's hosted content.
        quickNotesPopoverDeactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let popover = self?.quickNotesPopover, popover.isShown else { return }
            popover.close()
        }
        // Plan 64-08 (bug fix, root-cause round 2) — see quickNotesOutsideClickMonitor's
        // declaration comment: covers the missing case (a direct click into an already-visible
        // background app's window) that the observer above doesn't reliably catch.
        quickNotesOutsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            guard let popover = self?.quickNotesPopover, popover.isShown else { return }
            popover.close()
        }

        // Phase 1: build and show the notch overlay on the built-in notched display.
        // The controller resolves the correct screen, positions the panel on the
        // notch, and re-positions on every screen-configuration change.
        let controller = NotchWindowController()
        controller.start(isFirstLaunch: isFirstLaunch)
        self.notchController = controller
        // Phase 60 / UPDATE-01 (Plan 02) — the Update wing's tap reaches Sparkle's real
        // checkForUpdates() through this closure.
        controller.onUpdateInstallRequested = { [weak self] in self?.checkForUpdates() }

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

        // Phase 64 / NOTES-02/03 — seed the local recent-notes list from disk before the
        // popover can ever be opened, then wire the controller's closures so a submit/delete
        // in the popover reaches this AppDelegate's handlers (D-12's guard lives there).
        let loadedQuickNotes = QuickNotesFileStore.load(root: QuickNotesFileStore.storageRoot())
        for note in loadedQuickNotes { quickNotesStore.append(note) }
        refreshQuickNotesList()
        quickNotesController.onSubmit = { [weak self] text in self?.handleQuickNoteSubmit(text) }
        quickNotesController.onDelete = { [weak self] id in self?.handleQuickNoteDelete(id) }
        // Plan 64-08 (Task 2) — persists the picker's selection immediately so it survives
        // relaunch (self-healed back to the default on the next open if the file's gone).
        // Additional scope (coordinator-requested) — switching files re-filters the visible
        // list to only that file's notes; the underlying quickNotesStore.items is untouched.
        quickNotesController.onSelectFile = { [weak self] fileName in
            guard let self else { return }
            UserDefaults.standard.set(fileName, forKey: ActivitySettings.quickNotesSelectedFileNameKey)
            self.quickNotesController.selectedFileName = fileName
            self.refreshQuickNotesList()
        }
        // Plan 64-08 (additional scope) — a typed "New File…" name isn't created on disk here;
        // it's just added to availableFiles and selected, then the normal submit path
        // (handleQuickNoteSubmit -> QuickNotesVaultWriter.append) lazily creates the real file
        // on its first note, same as any other selected filename.
        quickNotesController.onCreateFile = { [weak self] fileName in
            guard let self else { return }
            if !self.quickNotesController.availableFiles.contains(fileName) {
                self.quickNotesController.availableFiles = (self.quickNotesController.availableFiles + [fileName]).sorted()
            }
            UserDefaults.standard.set(fileName, forKey: ActivitySettings.quickNotesSelectedFileNameKey)
            self.quickNotesController.selectedFileName = fileName
            self.refreshQuickNotesList()
        }

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

        // Phase 66 / MENUBAR-01/02/03 — PAUSED 2026-07-28 after a third consecutive on-device
        // NO-GO (see .planning/phases/66-.../66-CONTEXT.md third revision, project memory
        // phase66_menubar_overflow_second_nogo). Even the reference implementation (real Ice.app)
        // stopped working on this machine — the underlying mechanism itself is broken, not just
        // this port of it. User still wants the feature eventually, just not right now, so the
        // chevron construction+start is disabled here rather than deleted — no revisit trigger,
        // resume via a fresh /gsd-discuss-phase 66 whenever there's appetite.
        // menuBarOverflowController = MenuBarOverflowController()
        // menuBarOverflowController.start()
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

    // Phase 64 / NOTES-01 — D-11: re-checks the vault path fresh every time the popover
    // opens, never cached from a prior open.
    @objc private func openQuickNotesPopover() {
        guard let button = statusItem.button else { return }
        let path = UserDefaults.standard.string(forKey: ActivitySettings.quickNotesVaultFolderPathKey) ?? ""
        quickNotesController.vaultConfigured = QuickNotesVaultWriter.isValidVaultFolder(atPath: path)
        quickNotesController.errorMessage = nil

        // Plan 64-08 (additional scope, user-approved during 64-06's on-device UAT) — re-read
        // each note's own vault file and prune any note whose line was deleted directly in
        // the file (outside the app), before the file list/selection below is computed.
        if quickNotesController.vaultConfigured {
            reconcileQuickNotesWithVault(vaultFolderPath: path)
        }

        // Plan 64-08 (Task 2) — list the real .md files in the vault folder every open (D-11
        // discipline, never cached), always offering the fixed default name even when it
        // doesn't exist as a real file yet in a brand-new vault folder.
        if quickNotesController.vaultConfigured {
            let files = QuickNotesVaultWriter.listMarkdownFiles(inFolder: path)
            quickNotesController.availableFiles = Array(Set(files + [ActivitySettings.quickNotesDefaultFileName])).sorted()
            let stored = UserDefaults.standard.string(forKey: ActivitySettings.quickNotesSelectedFileNameKey) ?? ActivitySettings.quickNotesDefaultFileName
            quickNotesController.selectedFileName = quickNotesController.availableFiles.contains(stored) ? stored : ActivitySettings.quickNotesDefaultFileName
        } else {
            quickNotesController.availableFiles = []
        }
        // selectedFileName may have just changed above (or reconciliation may have pruned
        // notes before it settled) — refresh the filtered list against its final value.
        refreshQuickNotesList()

        quickNotesPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Plan 64-06 (Task 1) — fixes UAT tests 2 and 8: no focus request of any kind is
        // issued when the vault isn't configured, so the disabled empty state is never
        // touched by a first-responder call, removing the responder-chain interference that
        // was blocking the popover's .transient outside-click/Escape dismissal.
        guard quickNotesController.vaultConfigured else { return }
        DispatchQueue.main.async { [weak self] in
            self?.quickNotesController.focusRequestToken += 1
        }
    }

    // Phase 64 / NOTES-02 — D-12's locked data-loss guard: quickNotesStore.append only runs
    // inside the vault write's success path, never before it and never in the catch.
    private func handleQuickNoteSubmit(_ text: String) {
        let path = UserDefaults.standard.string(forKey: ActivitySettings.quickNotesVaultFolderPathKey) ?? ""
        // Plan 64-08 (Task 2) — targets whichever file the popover's picker currently has
        // selected, not a fixed hardcoded filename literal.
        let fileURL = URL(fileURLWithPath: path).appendingPathComponent(quickNotesController.selectedFileName)
        do {
            try QuickNotesVaultWriter.append(note: text, to: fileURL, at: Date())
            let note = QuickNote(id: UUID(), text: text, timestamp: Date(), fileName: quickNotesController.selectedFileName)
            quickNotesStore.append(note)
            refreshQuickNotesList()
            quickNotesController.errorMessage = nil
            try? QuickNotesFileStore.save(quickNotesStore.items, root: QuickNotesFileStore.storageRoot())
        } catch {
            quickNotesController.errorMessage = "Couldn't save — check your vault folder in Settings."
        }
    }

    // Phase 64-08 (Task 2) — D-17 REVISED: delete now also removes the matching line from
    // the vault file the note was actually written to (note.fileName, never the currently
    // selected file), only mutating the local list on a genuine success (T-64-15).
    private func handleQuickNoteDelete(_ id: UUID) {
        guard let note = quickNotesStore.items.first(where: { $0.id == id }) else { return }
        let path = UserDefaults.standard.string(forKey: ActivitySettings.quickNotesVaultFolderPathKey) ?? ""
        let fileURL = URL(fileURLWithPath: path).appendingPathComponent(note.fileName)

        // T-64-17: occurrence rank from quickNotesStore.items' append-order position (matches
        // the file's own line order) disambiguates byte-identical duplicate entries.
        let targetBlock = QuickNotesFormatter.formatEntry(text: note.text, at: note.timestamp)
        let occurrence = quickNotesStore.items.prefix(while: { $0.id != note.id })
            .filter { $0.fileName == note.fileName && QuickNotesFormatter.formatEntry(text: $0.text, at: $0.timestamp) == targetBlock }
            .count

        do {
            _ = try QuickNotesVaultWriter.removeEntry(matching: note, occurrence: occurrence, from: fileURL)
            quickNotesStore.remove(id: id)
            refreshQuickNotesList()
            quickNotesController.errorMessage = nil
            try? QuickNotesFileStore.save(quickNotesStore.items, root: QuickNotesFileStore.storageRoot())
        } catch {
            quickNotesController.errorMessage = "Couldn't delete from vault — check your vault folder in Settings."
        }
    }

    // Plan 64-08 (additional scope, user-approved during 64-06's on-device UAT) — the other
    // direction of vault/local-list sync from handleQuickNoteDelete above: a note deleted
    // directly in the vault file (outside the app, e.g. in Obsidian or a text editor) is
    // pruned from quickNotesStore too, not just app-side deletes reaching the file. Runs once
    // per popover-open (not on every keystroke), so a plain full-file read is fine here — no
    // need for QuickNotesVaultWriter's append-path tail-read optimization.
    private func reconcileQuickNotesWithVault(vaultFolderPath path: String) {
        let fileNames = Set(quickNotesStore.items.map(\.fileName))
        guard !fileNames.isEmpty else { return }

        // A file that can't be read at all (missing, permissions error) is "unknown", not
        // "deleted" — its notes are left untouched below to avoid a false-positive data loss.
        var fileContents: [String: String] = [:]
        for fileName in fileNames {
            let fileURL = URL(fileURLWithPath: path).appendingPathComponent(fileName)
            if let data = try? Data(contentsOf: fileURL), let content = String(data: data, encoding: .utf8) {
                fileContents[fileName] = content
            }
        }
        guard !fileContents.isEmpty else { return }

        // Same occurrence-by-append-order disambiguation as handleQuickNoteDelete's
        // duplicate-entry logic, computed here across ALL notes in one forward pass instead
        // of per-note, so a byte-identical duplicate isn't wrongly pruned just because ONE of
        // several identical lines was removed from the file.
        var occurrenceSeen: [String: Int] = [:]
        var idsToKeep: Set<UUID> = []
        for note in quickNotesStore.items {
            guard let content = fileContents[note.fileName] else {
                idsToKeep.insert(note.id)
                continue
            }
            let block = QuickNotesFormatter.formatEntry(text: note.text, at: note.timestamp)
            let key = "\(note.fileName)\u{0}\(block)"
            let occurrence = occurrenceSeen[key, default: 0]
            occurrenceSeen[key] = occurrence + 1
            let matchCount = content.components(separatedBy: block).count - 1
            if occurrence < matchCount {
                idsToKeep.insert(note.id)
            }
        }

        guard idsToKeep.count != quickNotesStore.items.count else { return }
        quickNotesStore.prune(keepingIDs: idsToKeep)
        refreshQuickNotesList()
        try? QuickNotesFileStore.save(quickNotesStore.items, root: QuickNotesFileStore.storageRoot())
    }

    // Additional scope (coordinator-requested) — the popover's recent-notes list is filtered
    // to the currently selected file only; quickNotesStore.items itself always holds every
    // note across every file (delete/reconciliation logic reads from that full list, keyed by
    // id/fileName, never from this filtered display projection).
    private func refreshQuickNotesList() {
        quickNotesController.notes = Array(
            quickNotesStore.items.filter { $0.fileName == quickNotesController.selectedFileName }.reversed()
        )
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

        // Quick task 260728-wg7 — DEBUG-only "Wing Tuner": 4 live nudge axes (Leading/Trailing/
        // Margin/Gap) applied additively on top of every collapsed-wing's own existing
        // constants (all default 0 -> zero visual change until nudged). Since only one wing is
        // visible on real hardware at a time, the intended workflow is: trigger one wing (e.g.
        // play music for Now Playing, or press a volume/brightness key for the OSD wing), nudge
        // until it looks right, click "Print Wing Tuner Values", paste the 4 printed deltas to
        // Claude for THAT ONE wing's own constants, click "Reset Wing Tuner", move to the next wing.
        let wingTunerMenu = NSMenu()
        wingTunerMenu.addItem(withTitle: "Leading -2", action: #selector(debugWingLeadingMinus), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Leading +2", action: #selector(debugWingLeadingPlus), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Trailing -2", action: #selector(debugWingTrailingMinus), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Trailing +2", action: #selector(debugWingTrailingPlus), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Margin -20", action: #selector(debugWingMarginMinus20), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Margin -10", action: #selector(debugWingMarginMinus10), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Margin -5", action: #selector(debugWingMarginMinus), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Margin +5", action: #selector(debugWingMarginPlus), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Margin +10", action: #selector(debugWingMarginPlus10), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Margin +20", action: #selector(debugWingMarginPlus20), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Gap -1", action: #selector(debugWingGapMinus), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Gap +1", action: #selector(debugWingGapPlus), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Corner Radius -5", action: #selector(debugWingCornerRadiusMinus5), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Corner Radius -1", action: #selector(debugWingCornerRadiusMinus1), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Corner Radius +1", action: #selector(debugWingCornerRadiusPlus1), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Corner Radius +5", action: #selector(debugWingCornerRadiusPlus5), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Height -5", action: #selector(debugWingHeightMinus5), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Height -1", action: #selector(debugWingHeightMinus1), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Height +1", action: #selector(debugWingHeightPlus1), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Height +5", action: #selector(debugWingHeightPlus5), keyEquivalent: "")
        wingTunerMenu.addItem(.separator())
        wingTunerMenu.addItem(withTitle: "Reset Wing Tuner", action: #selector(debugWingTunerReset), keyEquivalent: "")
        wingTunerMenu.addItem(withTitle: "Print Wing Tuner Values", action: #selector(debugWingTunerPrint), keyEquivalent: "")
        for item in wingTunerMenu.items { item.target = self }
        let wingTunerItem = NSMenuItem(title: "Wing Tuner", action: nil, keyEquivalent: "")
        wingTunerItem.submenu = wingTunerMenu
        debugMenu.addItem(wingTunerItem)

        // Phase 72.1 / D-05 — DEBUG-only "OSD Bar/Counter Tuner": Roll Speed live nudge axis
        // for the digit-roll counter (the opacity ramp's Opacity Min/Max axes were reverted by
        // quick task 260731-61m), same live-tune-then-bake-into-source workflow as Wing Tuner
        // above. Use the existing "Preview: OSD (Volume/Brightness)" items below to trigger
        // the OSD wing on-device while nudging.
        let osdTunerMenu = NSMenu()
        osdTunerMenu.addItem(withTitle: "Roll Speed -0.05", action: #selector(debugOSDRollSpeedMinus), keyEquivalent: "")
        osdTunerMenu.addItem(withTitle: "Roll Speed +0.05", action: #selector(debugOSDRollSpeedPlus), keyEquivalent: "")
        osdTunerMenu.addItem(.separator())
        osdTunerMenu.addItem(withTitle: "Reset OSD Tuner", action: #selector(debugOSDTunerReset), keyEquivalent: "")
        osdTunerMenu.addItem(withTitle: "Print OSD Tuner Values", action: #selector(debugOSDTunerPrint), keyEquivalent: "")
        for item in osdTunerMenu.items { item.target = self }
        let osdTunerItem = NSMenuItem(title: "OSD Bar/Counter Tuner", action: nil, keyEquivalent: "")
        osdTunerItem.submenu = osdTunerMenu
        debugMenu.addItem(osdTunerItem)

        // Phase 72.1.1 / GLASS-01 — DEBUG-only "Liquid Glass Tuner": 5 live nudge axes
        // (native tint/gloss + legacy-shader edgeOpacity/centerOpacity/borderWidth), same
        // live-tune-then-bake-into-source workflow as Wing Tuner/OSD Tuner above. Pure
        // scaffolding — nothing reads these nudges until Plan 72.1.1-03 wires them in.
        let glassTunerMenu = NSMenu()
        glassTunerMenu.addItem(withTitle: "Glass Tint -0.05", action: #selector(debugGlassTintMinus), keyEquivalent: "")
        glassTunerMenu.addItem(withTitle: "Glass Tint +0.05", action: #selector(debugGlassTintPlus), keyEquivalent: "")
        glassTunerMenu.addItem(withTitle: "Glass Gloss -0.05", action: #selector(debugGlassGlossMinus), keyEquivalent: "")
        glassTunerMenu.addItem(withTitle: "Glass Gloss +0.05", action: #selector(debugGlassGlossPlus), keyEquivalent: "")
        glassTunerMenu.addItem(withTitle: "Legacy Edge Opacity -0.05", action: #selector(debugGlassLegacyEdgeOpacityMinus), keyEquivalent: "")
        glassTunerMenu.addItem(withTitle: "Legacy Edge Opacity +0.05", action: #selector(debugGlassLegacyEdgeOpacityPlus), keyEquivalent: "")
        glassTunerMenu.addItem(withTitle: "Legacy Center Opacity -0.05", action: #selector(debugGlassLegacyCenterOpacityMinus), keyEquivalent: "")
        glassTunerMenu.addItem(withTitle: "Legacy Center Opacity +0.05", action: #selector(debugGlassLegacyCenterOpacityPlus), keyEquivalent: "")
        glassTunerMenu.addItem(withTitle: "Legacy Border Width -0.02", action: #selector(debugGlassLegacyBorderWidthMinus), keyEquivalent: "")
        glassTunerMenu.addItem(withTitle: "Legacy Border Width +0.02", action: #selector(debugGlassLegacyBorderWidthPlus), keyEquivalent: "")
        glassTunerMenu.addItem(.separator())
        glassTunerMenu.addItem(withTitle: "Reset Liquid Glass Tuner", action: #selector(debugGlassTunerReset), keyEquivalent: "")
        glassTunerMenu.addItem(withTitle: "Print Liquid Glass Tuner Values", action: #selector(debugGlassTunerPrint), keyEquivalent: "")
        for item in glassTunerMenu.items { item.target = self }
        let glassTunerItem = NSMenuItem(title: "Liquid Glass Tuner", action: nil, keyEquivalent: "")
        glassTunerItem.submenu = glassTunerMenu
        debugMenu.addItem(glassTunerItem)

        // Quick task 260729-0b5 — DEBUG-only "Preview Wing": fake-triggers every
        // collapsed-state HUD wing on demand (no need to actually play music, press volume
        // keys, toggle real DND, plug in a charger, connect a device, start a download,
        // etc.), mirroring the pre-existing per-activity fake-trigger precedent this plan's
        // interfaces section documented — one function, one menu item, per activity.
        let previewWingMenu = NSMenu()
        previewWingMenu.addItem(withTitle: "Preview: Now Playing", action: #selector(debugPreviewNowPlaying), keyEquivalent: "")
        previewWingMenu.addItem(withTitle: "Preview: OSD (Volume)", action: #selector(debugPreviewOSDVolume), keyEquivalent: "")
        previewWingMenu.addItem(withTitle: "Preview: OSD (Brightness)", action: #selector(debugPreviewOSDBrightness), keyEquivalent: "")
        previewWingMenu.addItem(withTitle: "Preview: Focus/DND", action: #selector(debugPreviewFocus), keyEquivalent: "")
        previewWingMenu.addItem(withTitle: "Preview: Caps Lock", action: #selector(debugPreviewCapsLock), keyEquivalent: "")
        previewWingMenu.addItem(withTitle: "Preview: Charging", action: #selector(debugPreviewCharging), keyEquivalent: "")
        previewWingMenu.addItem(withTitle: "Preview: Device", action: #selector(debugPreviewDevice), keyEquivalent: "")
        previewWingMenu.addItem(withTitle: "Preview: Update", action: #selector(debugPreviewUpdate), keyEquivalent: "")
        previewWingMenu.addItem(withTitle: "Preview: Download", action: #selector(debugPreviewDownload), keyEquivalent: "")
        previewWingMenu.addItem(withTitle: "Preview: Timer", action: #selector(debugPreviewTimer), keyEquivalent: "")
        previewWingMenu.addItem(withTitle: "Preview: Countdown", action: #selector(debugPreviewCountdown), keyEquivalent: "")
        previewWingMenu.addItem(withTitle: "Preview: Meeting", action: #selector(debugPreviewMeeting), keyEquivalent: "")
        for item in previewWingMenu.items { item.target = self }
        let previewWingItem = NSMenuItem(title: "Preview Wing", action: nil, keyEquivalent: "")
        previewWingItem.submenu = previewWingMenu
        debugMenu.addItem(previewWingItem)

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

    // Quick task 260728-wg7 — Wing Tuner actions. Plain UserDefaults.standard.set(...), no new
    // persistence mechanism, mirroring debugForceExpired()'s own style — these live-update
    // NotchPillView's @AppStorage-backed nudge properties with zero plumbing between the files.
    private func adjustWingNudge(_ key: String, by delta: Double) {
        let current = UserDefaults.standard.double(forKey: key)
        UserDefaults.standard.set(current + delta, forKey: key)
    }

    @objc private func debugWingLeadingMinus() { adjustWingNudge(ActivitySettings.debugWingLeadingNudgeKey, by: -2) }
    @objc private func debugWingLeadingPlus() { adjustWingNudge(ActivitySettings.debugWingLeadingNudgeKey, by: 2) }
    @objc private func debugWingTrailingMinus() { adjustWingNudge(ActivitySettings.debugWingTrailingNudgeKey, by: -2) }
    @objc private func debugWingTrailingPlus() { adjustWingNudge(ActivitySettings.debugWingTrailingNudgeKey, by: 2) }
    @objc private func debugWingMarginMinus20() { adjustWingNudge(ActivitySettings.debugWingMarginNudgeKey, by: -20) }
    @objc private func debugWingMarginMinus10() { adjustWingNudge(ActivitySettings.debugWingMarginNudgeKey, by: -10) }
    @objc private func debugWingMarginMinus() { adjustWingNudge(ActivitySettings.debugWingMarginNudgeKey, by: -5) }
    @objc private func debugWingMarginPlus() { adjustWingNudge(ActivitySettings.debugWingMarginNudgeKey, by: 5) }
    @objc private func debugWingMarginPlus10() { adjustWingNudge(ActivitySettings.debugWingMarginNudgeKey, by: 10) }
    @objc private func debugWingMarginPlus20() { adjustWingNudge(ActivitySettings.debugWingMarginNudgeKey, by: 20) }
    @objc private func debugWingGapMinus() { adjustWingNudge(ActivitySettings.debugWingGapNudgeKey, by: -1) }
    @objc private func debugWingGapPlus() { adjustWingNudge(ActivitySettings.debugWingGapNudgeKey, by: 1) }
    @objc private func debugWingCornerRadiusMinus5() { adjustWingNudge(ActivitySettings.debugWingCornerRadiusNudgeKey, by: -5) }
    @objc private func debugWingCornerRadiusMinus1() { adjustWingNudge(ActivitySettings.debugWingCornerRadiusNudgeKey, by: -1) }
    @objc private func debugWingCornerRadiusPlus1() { adjustWingNudge(ActivitySettings.debugWingCornerRadiusNudgeKey, by: 1) }
    @objc private func debugWingCornerRadiusPlus5() { adjustWingNudge(ActivitySettings.debugWingCornerRadiusNudgeKey, by: 5) }
    @objc private func debugWingHeightMinus5() { adjustWingNudge(ActivitySettings.debugWingHeightNudgeKey, by: -5) }
    @objc private func debugWingHeightMinus1() { adjustWingNudge(ActivitySettings.debugWingHeightNudgeKey, by: -1) }
    @objc private func debugWingHeightPlus1() { adjustWingNudge(ActivitySettings.debugWingHeightNudgeKey, by: 1) }
    @objc private func debugWingHeightPlus5() { adjustWingNudge(ActivitySettings.debugWingHeightNudgeKey, by: 5) }

    // Phase 72.1 / D-05 — OSD Bar/Counter Tuner actions, reusing the existing
    // adjustWingNudge(_:by:) helper above (no new helper).
    @objc private func debugOSDRollSpeedMinus() { adjustWingNudge(ActivitySettings.debugOSDRollSpeedNudgeKey, by: -0.05) }
    @objc private func debugOSDRollSpeedPlus() { adjustWingNudge(ActivitySettings.debugOSDRollSpeedNudgeKey, by: 0.05) }

    @MainActor @objc private func debugOSDTunerReset() {
        UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugOSDRollSpeedNudgeKey)
        notchController?.debugClearAllPreviews()
    }

    @objc private func debugOSDTunerPrint() {
        let rollSpeed = UserDefaults.standard.double(forKey: ActivitySettings.debugOSDRollSpeedNudgeKey)
        print("[OSDTuner] rollSpeedNudge=\(rollSpeed) — bake this confirmed delta into DigitRollText's own rollResponse constant in NotchPillView.swift before clicking Reset OSD Tuner.")
    }

    // Phase 72.1.1 / GLASS-01 — Liquid Glass Tuner actions, reusing the existing
    // adjustWingNudge(_:by:) helper above (no new helper).
    @objc private func debugGlassTintMinus() { adjustWingNudge(ActivitySettings.debugGlassTintNudgeKey, by: -0.05) }
    @objc private func debugGlassTintPlus() { adjustWingNudge(ActivitySettings.debugGlassTintNudgeKey, by: 0.05) }
    @objc private func debugGlassGlossMinus() { adjustWingNudge(ActivitySettings.debugGlassGlossNudgeKey, by: -0.05) }
    @objc private func debugGlassGlossPlus() { adjustWingNudge(ActivitySettings.debugGlassGlossNudgeKey, by: 0.05) }
    @objc private func debugGlassLegacyEdgeOpacityMinus() { adjustWingNudge(ActivitySettings.debugGlassLegacyEdgeOpacityNudgeKey, by: -0.05) }
    @objc private func debugGlassLegacyEdgeOpacityPlus() { adjustWingNudge(ActivitySettings.debugGlassLegacyEdgeOpacityNudgeKey, by: 0.05) }
    @objc private func debugGlassLegacyCenterOpacityMinus() { adjustWingNudge(ActivitySettings.debugGlassLegacyCenterOpacityNudgeKey, by: -0.05) }
    @objc private func debugGlassLegacyCenterOpacityPlus() { adjustWingNudge(ActivitySettings.debugGlassLegacyCenterOpacityNudgeKey, by: 0.05) }
    @objc private func debugGlassLegacyBorderWidthMinus() { adjustWingNudge(ActivitySettings.debugGlassLegacyBorderWidthNudgeKey, by: -0.02) }
    @objc private func debugGlassLegacyBorderWidthPlus() { adjustWingNudge(ActivitySettings.debugGlassLegacyBorderWidthNudgeKey, by: 0.02) }

    @MainActor @objc private func debugGlassTunerReset() {
        UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugGlassTintNudgeKey)
        UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugGlassGlossNudgeKey)
        UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugGlassLegacyEdgeOpacityNudgeKey)
        UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugGlassLegacyCenterOpacityNudgeKey)
        UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugGlassLegacyBorderWidthNudgeKey)
    }

    @objc private func debugGlassTunerPrint() {
        let tint = UserDefaults.standard.double(forKey: ActivitySettings.debugGlassTintNudgeKey)
        let gloss = UserDefaults.standard.double(forKey: ActivitySettings.debugGlassGlossNudgeKey)
        let edgeOpacity = UserDefaults.standard.double(forKey: ActivitySettings.debugGlassLegacyEdgeOpacityNudgeKey)
        let centerOpacity = UserDefaults.standard.double(forKey: ActivitySettings.debugGlassLegacyCenterOpacityNudgeKey)
        let borderWidth = UserDefaults.standard.double(forKey: ActivitySettings.debugGlassLegacyBorderWidthNudgeKey)
        print("[GlassTuner] tintNudge=\(tint) glossNudge=\(gloss) legacyEdgeOpacityNudge=\(edgeOpacity) legacyCenterOpacityNudge=\(centerOpacity) legacyBorderWidthNudge=\(borderWidth) — bake tintNudge/glossNudge into the native tint/gloss literals in liquidGlassEffectLayer, and legacyEdgeOpacityNudge/legacyCenterOpacityNudge/legacyBorderWidthNudge into LiquidGlassParameters.collapsed/.expanded's edgeOpacity/centerOpacity/borderWidth in LiquidGlassShader.swift, then click Reset Liquid Glass Tuner.")
    }

    @MainActor @objc private func debugWingTunerReset() {
        UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugWingLeadingNudgeKey)
        UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugWingTrailingNudgeKey)
        UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugWingMarginNudgeKey)
        UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugWingGapNudgeKey)
        UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugWingCornerRadiusNudgeKey)
        UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugWingHeightNudgeKey)
        notchController?.debugClearAllPreviews()
    }

    @objc private func debugWingTunerPrint() {
        let leading = UserDefaults.standard.double(forKey: ActivitySettings.debugWingLeadingNudgeKey)
        let trailing = UserDefaults.standard.double(forKey: ActivitySettings.debugWingTrailingNudgeKey)
        let margin = UserDefaults.standard.double(forKey: ActivitySettings.debugWingMarginNudgeKey)
        let gap = UserDefaults.standard.double(forKey: ActivitySettings.debugWingGapNudgeKey)
        let cornerRadius = UserDefaults.standard.double(forKey: ActivitySettings.debugWingCornerRadiusNudgeKey)
        let height = UserDefaults.standard.double(forKey: ActivitySettings.debugWingHeightNudgeKey)
        print("[WingTuner] leadingNudge=\(leading) trailingNudge=\(trailing) marginNudge=\(margin) gapNudge=\(gap) cornerRadiusNudge=\(cornerRadius) heightNudge=\(height) — add the leading/trailing/margin/gap deltas to the ONE wing's own margin/leadingPad-or-.padding(.leading,)/trailingPad-or-.padding(.trailing,)/gap constants you were just tuning in NotchPillView.swift; cornerRadiusNudge has no per-wing home, it bakes into Self.wingBaseTopCornerRadius/wingBaseBottomCornerRadius instead; heightNudge also has no per-wing home, it bakes into wingsShape's own shared size.height line (and mediaWingsOrToast's own separate inline height calc) instead — then click Reset Wing Tuner before tuning the next wing.")
    }

    // Quick task 260729-0b5 — "Preview Wing" fake-trigger actions. Each mirrors the
    // pre-existing per-activity fake-trigger precedent's exact one-line-body
    // @MainActor @objc private shape.
    @MainActor @objc private func debugPreviewNowPlaying() {
        notchController?.handleNowPlaying(TrackSnapshot(bundleIdentifier: "com.spotify.client", isPlaying: true, title: "Preview Track", artist: "Preview Artist"), nil)
    }
    @MainActor @objc private func debugPreviewOSDVolume() {
        notchController?.handleOSDKeyPress(.volume)
        notchController?.debugCancelPendingDismiss()
    }
    @MainActor @objc private func debugPreviewOSDBrightness() {
        notchController?.handleOSDKeyPress(.brightness)
        notchController?.debugCancelPendingDismiss()
    }
    @MainActor @objc private func debugPreviewFocus() {
        notchController?.handleFocusChange(true)
    }
    @MainActor @objc private func debugPreviewCapsLock() {
        notchController?.handleCapsLockChange(true)
        notchController?.debugCancelPendingDismiss()
    }
    @MainActor @objc private func debugPreviewCharging() {
        // Quick task 260729-2td — force a genuine AC-edge transition first: on a dev machine
        // already AC-connected, calling only the charging reading below is a same-category tick
        // (isOnAC(next)==isOnAC(previous)==true) and shouldTriggerSplash silently no-ops. This
        // .onBattery reading flips lastActivity away from charging first, so the real call after
        // it is guaranteed to be detected as a fresh connect.
        notchController?.handlePower(PowerReading(isPresent: true, isOnAC: false, isCharging: false, isCharged: false, percent: 63))
        notchController?.handlePower(PowerReading(isPresent: true, isOnAC: true, isCharging: true, isCharged: false, percent: 63))
        notchController?.debugCancelPendingDismiss()
    }
    @MainActor @objc private func debugPreviewDevice() {
        notchController?.debugPreviewDevice()
        notchController?.debugCancelPendingDismiss()
    }
    @MainActor @objc private func debugPreviewUpdate() {
        notchController?.handleUpdateAvailable(version: "1.99")
        notchController?.debugCancelPendingDismiss()
    }
    @MainActor @objc private func debugPreviewDownload() {
        notchController?.debugPreviewDownload()
    }
    @MainActor @objc private func debugPreviewTimer() {
        notchController?.debugPreviewStartCountdown(seconds: 60)
    }
    @MainActor @objc private func debugPreviewCountdown() {
        notchController?.handleCalendarCountdownChange(CalendarCountdownActivity(eventStart: Date().addingTimeInterval(20 * 60)))
        notchController?.debugCancelPendingDismiss()
    }
    @MainActor @objc private func debugPreviewMeeting() {
        notchController?.handleMeetingActivityChange(MeetingReading(detectedAt: Date(), isMuted: false))
    }
    #endif
}

// Phase 40 / HUD-06 (D-13, RESEARCH.md Pattern 2) — no updaterDidNotFindUpdate override: the
// dot only needs to go visible on a genuine find, nothing needs to actively hide it again (a
// successful install relaunches the app, resetting it to hidden on next launch).
extension AppDelegate: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        updateDotView?.isHidden = false
        // Phase 60 / UPDATE-01 (Plan 02, D-02) — additive second signal off the same callback;
        // the menu-bar dot is not removed.
        notchController?.handleUpdateAvailable(version: item.displayVersionString)
    }
}

// Phase 58 / CLIP-01/02/03 — dynamic clipboard-history section, rebuilt from
// `clipboardStore.items` every time the status-item menu opens (AppKit calls this
// reliably before every display, including key-equivalent-triggered validation).
extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // D-11/D-12/D-13: one-time pasteboard-access explanation, gated on a persisted
        // UserDefaults flag (not an in-session Bool like Phase 57's DEBUG placeholder) so
        // it fires on the very first menu open ever and never again after that. The flag
        // is set BEFORE presenting the alert so an interrupted runModal() still can't
        // reshow it — matches D-11's "shown on first menu open" intent.
        if !UserDefaults.standard.bool(forKey: Self.clipboardAccessExplanationShownKey),
           ClipboardMonitor.needsAccessExplanation {
            UserDefaults.standard.set(true, forKey: Self.clipboardAccessExplanationShownKey)
            let alert = NSAlert()
            alert.messageText = "Clipboard Access"
            alert.informativeText = "Islet reads your clipboard to build a history of recent copies. Items marked sensitive — like passwords from a password manager — are never captured."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }

        // Identifier-prefix removal (never positional index math — the static
        // Settings/Check-for-Updates/Quit block's positions are fixed but this
        // section's item count varies 0-31).
        menu.items.removeAll { $0.identifier?.rawValue.hasPrefix("clip.") == true }

        // Plan 64-06 (Task 3) — inserts the dynamic Clipboard History section right after
        // the static "New Note…" item instead of at the very top, so "New Note…" renders
        // above it. Selector-based lookup (not a positional literal), matching this
        // method's existing identifier-prefix-removal preference above.
        var insertionIndex = menu.indexOfItem(withTarget: self, andAction: #selector(openQuickNotesPopover)) + 1
        // Plan 64-06 (menu-order re-fix) — a visual break between "New Note…" and the
        // Clipboard History block, same clip.-tagged rebuild-every-time pattern as the
        // existing trailing separator below so it stays in sync with removeAll above.
        let leadingSeparator = NSMenuItem.separator()
        leadingSeparator.identifier = NSUserInterfaceItemIdentifier("clip.leadingSeparator")
        menu.insertItem(leadingSeparator, at: insertionIndex); insertionIndex += 1
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

        // CLIP-05/D-14: a top-level item next to the anchor (not nested inside its
        // submenu) — the D-15-REVISED anchor+submenu shape only holds the dynamic rows,
        // so "Delete All History" stays a plain, always-visible sibling of the anchor,
        // disabled while the history is empty.
        let deleteAll = NSMenuItem(title: "Delete All History", action: #selector(confirmDeleteAllHistory), keyEquivalent: "")
        deleteAll.identifier = NSUserInterfaceItemIdentifier("clip.deleteAll")
        deleteAll.target = self
        deleteAll.isEnabled = !clipboardStore.items.isEmpty
        menu.insertItem(deleteAll, at: insertionIndex); insertionIndex += 1

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

    // CLIP-05/T-58-05/T-58-06: destructive confirm — runModal() blocks until the user
    // picks a button, and only an explicit "Delete" click (.alertFirstButtonReturn)
    // proceeds; Cancel or dismissing the dialog any other way is a no-op.
    @objc private func confirmDeleteAllHistory() {
        let alert = NSAlert()
        alert.messageText = "Delete all clipboard history?"
        alert.informativeText = "This cannot be undone."
        alert.addButton(withTitle: "Delete")
        alert.buttons.first?.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        clipboardStore.clear()
        // RESEARCH.md Pitfall 2: clear() is a pure in-memory reducer and never touches
        // index.json.enc — without this on-disk empty-rewrite, the "deleted" history
        // would still be readable on disk after a relaunch.
        try? ClipboardFileStore.save([], root: ClipboardFileStore.storageRoot(), key: KeychainClipboardKeyStore().readOrCreateKey())
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
