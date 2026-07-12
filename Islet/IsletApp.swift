import SwiftUI
import AppKit

extension Notification.Name {
    // Posted by AppDelegate.openSettings() and by NotchWindowController's
    // onboarding Settings-hop. AppDelegate itself listens (see
    // applicationDidFinishLaunching) and shows its own AppKit-owned window —
    // see AppDelegate.showSettingsWindow() for why this replaced a SwiftUI
    // `Window(id:)` scene (Plan 27-04 checkpoint fix).
    static let openIsletSettings = Notification.Name("openIsletSettings")
}

@main
struct IsletApp: App {
    // The ONLY AppKit we need: a delegate that owns the menu-bar status item,
    // the notch overlay panel, AND the Settings window. SwiftUI's `App` alone
    // cannot create a classic NSStatusItem dropdown, so we bridge into AppKit
    // via NSApplicationDelegateAdaptor and keep that surface as small as possible.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Islet has no SwiftUI-managed windows: the notch overlay is an AppKit
        // NSPanel (NotchWindowController) and Settings is a plain AppKit NSWindow
        // owned directly by AppDelegate. `App` still requires at least one Scene,
        // so this is an inert placeholder — it is never opened or shown.
        //
        // Plan 27-04 checkpoint fix: this used to be a `Window(id: "settings")`
        // scene whose content held the open-request notification listener —
        // circular, since that content only exists once the window itself has
        // been created. Confirmed on-device: `NSApp.windows` never contained a
        // "settings"-identified window at click time once `.defaultLaunchBehavior
        // (.suppressed)` (added for an earlier, different restoration bug) kept
        // the scene from ever auto-creating at launch. AppDelegate now owns the
        // window directly — see AppDelegate.showSettingsWindow().
        Settings {
            EmptyView()
        }
    }
}
