import AppKit

// Phase 66 Plan 02 / MENUBAR-01/02/03 — the public-API spacer-NSStatusItem technique
// (Hidden Bar reference), replacing the superseded private-CGS approach that returned
// NO-GO in Plan 66-01 (see 66-01-SUMMARY.md).
//
// Mechanism: two NSStatusItems — a visible chevron (button, click-toggle) and an
// invisible spacer (no button content, pure width). Toggling the spacer's `.length`
// between a small "revealed" value and a screen-width-clamped "hidden" value pushes
// every menu-bar item to its LEFT off-screen (hidden) or lets them settle back
// (revealed). D-02: activates unconditionally at launch, no Settings toggle, no
// permission gate — this is long-established public API, not a private symbol.

// Pure, testable clamp — no NSScreen/NSStatusItem dependency, mirrors
// DisplayResolver.swift's pure-function style. T-66-01: never produces a negative or
// runaway length even for a degenerate/zero/negative screenWidth (external-display
// disconnect race).
func clampedExpandedSpacerLength(candidate: CGFloat, screenWidth: CGFloat) -> CGFloat {
    min(max(candidate, 0), max(screenWidth, 0))
}

@MainActor
final class MenuBarOverflowController {
    private nonisolated(unsafe) var running = false
    private var chevronItem: NSStatusItem!
    private var spacerItem: NSStatusItem!
    private nonisolated(unsafe) var screenObserver: NSObjectProtocol?
    private let defaults: UserDefaults

    private static let expandedLengthCandidate: CGFloat = 2000
    private static let collapsedSpacerLength: CGFloat = 20

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func start() {
        guard !running else { return }
        running = true

        // Created BEFORE spacerItem: RESEARCH.md Pitfall 1 — later-created status items
        // land further left/outer, so spacerItem (created second) lands left of
        // chevronItem, and both land left of AppDelegate's statusItem/debugStatusItem
        // (constructed before this start() call — see AppDelegate wiring), satisfying
        // D-01's "chevron is leftmost among Islet's own menu-bar items".
        chevronItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        spacerItem = NSStatusBar.system.statusItem(withLength: 1)

        chevronItem.autosaveName = "IsletMenuBarOverflowChevron"
        spacerItem.autosaveName = "IsletMenuBarOverflowSpacer"

        chevronItem.button?.target = self
        chevronItem.button?.action = #selector(chevronPressed)
        chevronItem.menu = nil

        spacerItem.button?.image = nil
        spacerItem.button?.title = ""
        spacerItem.button?.action = nil

        let revealed = defaults.bool(forKey: ActivitySettings.menuBarOverflowRevealedKey)
        applyRevealedState(revealed)

        // ISL-06-style re-clamp on every screen-config change (verbatim shape from
        // NotchWindowController.swift:601-611) — the hidden/expanded length depends on
        // screen width, so plug/unplug or resolution changes must recompute it.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.recomputeIfHidden() }
        }
    }

    nonisolated func stop() {
        if let token = screenObserver {
            NotificationCenter.default.removeObserver(token)
        }
        screenObserver = nil
        running = false
    }

    deinit {
        // Empty by design — owner calls stop(), matches MeetingMonitor's convention.
    }

    private func applyRevealedState(_ revealed: Bool) {
        spacerItem.length = revealed ? Self.collapsedSpacerLength : Self.currentExpandedLength()

        let symbolName = revealed ? "chevron.right" : "chevron.left"
        let accessibilityDescription = revealed ? "Hide Menu Bar Icons" : "Show Hidden Menu Bar Icons"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)
        image?.isTemplate = true
        chevronItem.button?.image = image
    }

    private static func currentExpandedLength() -> CGFloat {
        clampedExpandedSpacerLength(
            candidate: expandedLengthCandidate,
            screenWidth: NSScreen.main?.visibleFrame.width ?? expandedLengthCandidate
        )
    }

    private func recomputeIfHidden() {
        let revealed = defaults.bool(forKey: ActivitySettings.menuBarOverflowRevealedKey)
        guard !revealed else { return }
        spacerItem.length = Self.currentExpandedLength()
    }

    @objc private func chevronPressed() {
        let revealed = !defaults.bool(forKey: ActivitySettings.menuBarOverflowRevealedKey)
        defaults.set(revealed, forKey: ActivitySettings.menuBarOverflowRevealedKey)
        applyRevealedState(revealed)
    }
}
