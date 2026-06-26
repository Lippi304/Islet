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
