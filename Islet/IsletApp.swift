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
        // Phase 26 round-6 on-device UAT bug: Settings kept appearing at launch despite
        // AppDelegate's unconditional hideSettingsWindowOnLaunch(). Root cause: AppKit's own
        // window-state restoration re-shows a `Window(id:)` scene's window automatically at
        // launch if it was left open/visible in a PRIOR run's saved state (macOS persists this
        // independent of anything AppDelegate does, and restoration can win the race against
        // the async hide) -- repeated Xcode Stop/Cmd-R cycles during this UAT session are
        // exactly the kind of abrupt-process-death that leaves that saved state behind.
        // `.defaultLaunchBehavior(.suppressed)` (macOS 15+) is Apple's documented lever for
        // "never auto-present this Scene's window at launch, including from restoration" --
        // the correct fix at the source, not another after-the-fact hide. SwiftUI's
        // `SceneBuilder` has no `if #available`/type-eraser path (confirmed: it lacks
        // `buildLimitedAvailability`, and there is no `AnyScene`), so using this API at all
        // required bumping the project's deployment target 14.0 -> 15.0 (see project.yml) --
        // applied unconditionally here, no availability branch needed anymore.
        // hideSettingsWindowOnLaunch() stays as cheap defense-in-depth alongside this.
        Window("Islet Settings", id: "settings") {
            SettingsView()
                .modifier(OpenSettingsOnNotification())  // Notification bridge
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultLaunchBehavior(.suppressed)
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
