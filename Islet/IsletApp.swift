import SwiftUI
import AppKit

extension Notification.Name {
    // AppDelegate posts this; the settings window's content observes it and
    // calls openWindow. (A small, decoupled bridge between AppKit and SwiftUI.)
    static let openIsletSettings = Notification.Name("openIsletSettings")
}

@main
struct IsletApp: App {
    // The ONLY AppKit we need: a delegate that owns the menu-bar status item.
    // SwiftUI's `App` alone cannot create a classic NSStatusItem dropdown,
    // so we bridge into AppKit via NSApplicationDelegateAdaptor and keep that
    // surface as small as possible.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // A normal Window scene — NOT the SwiftUI `Settings` scene.
        // On macOS 26 a menu-bar (LSUIElement) agent cannot reliably open the
        // `Settings` scene via `openSettings`, so we use a plain Window we open
        // ourselves through the notification bridge below.
        //
        // Plan 27-04 checkpoint fix: this file previously also had
        // `.defaultLaunchBehavior(.suppressed)` (added for a round-6 restoration
        // bug — see below) — on-device diagnostic instrumentation proved that
        // modifier keeps this Scene's underlying NSWindow from being created AT
        // ALL (not merely hidden): `NSApp.windows` never contained a
        // "settings"-identified window at click time with `.suppressed` present.
        // Since `OpenSettingsOnNotification`'s `.onReceive` listener lives INSIDE
        // this window's own content, that meant the open-request notification had
        // no listener to receive it — Settings could never open.
        //
        // An AppKit-owned NSWindow (bypassing this Scene) was tried as the fix,
        // but broke NavigationSplitView's List row-selection on-device (confirmed:
        // Toggle/Button controls in the same window worked fine, but sidebar
        // clicks never changed the detail pane) — NavigationSplitView/List
        // selection apparently depends on being hosted inside a genuine SwiftUI
        // Scene, which a hand-rolled NSHostingController-backed NSWindow doesn't
        // provide. Reverting to this Scene-hosted design restores that support;
        // `hideSettingsWindowOnLaunch()` (AppDelegate) is the mechanism that keeps
        // the window from being visible at launch, not `.defaultLaunchBehavior`.
        //
        // Original Phase 26 round-6 on-device UAT bug: Settings kept appearing at launch
        // despite AppDelegate's unconditional hideSettingsWindowOnLaunch(). Root cause:
        // AppKit's own window-state restoration re-shows a `Window(id:)` scene's window
        // automatically at launch if it was left open/visible in a PRIOR run's saved state
        // (macOS persists this independent of anything AppDelegate does, and restoration can
        // win the race against the async hide) -- repeated Xcode Stop/Cmd-R cycles during
        // that UAT session were exactly the kind of abrupt-process-death that leaves that
        // saved state behind. `hideSettingsWindowOnLaunch()` sets `window.isRestorable =
        // false` as soon as it finds the window each launch, which prevents NEW stale state
        // from being saved going forward — the actual persistent mitigation for that bug,
        // now that `.defaultLaunchBehavior(.suppressed)` has proven to cause a worse problem.
        Window("Islet Settings", id: "settings") {
            SettingsView()
                .modifier(OpenSettingsOnNotification())  // Notification bridge
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

// Notification bridge: a view modifier that, when the .openIsletSettings
// notification fires, activates the app and opens the "settings" window.
private struct OpenSettingsOnNotification: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: .openIsletSettings)) { _ in
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }
    }
}
