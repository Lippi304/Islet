import Foundation
import ServiceManagement

// A small wrapper over SMAppService.mainApp so the SwiftUI view stays clean.
//
// For a first-time programmer: `mainApp` registers the app ITSELF as a login
// item — there is NO separate helper bundle and NO LaunchAgent plist. It is
// keyed to the app's bundle id (com.lippi304.islet, D-08). The system, not the
// app, is the source of truth: we always READ the real status and never persist
// our own flag. `.requiresApproval` means macOS wants the user to confirm the
// login item in System Settings.
enum LaunchAtLogin {
    /// The single source of truth — the actual system login-item state.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns the resulting enabled-state after attempting the change.
    /// Throws if register/unregister fails so the caller can revert the UI.
    @discardableResult
    static func set(_ enabled: Bool) throws -> Bool {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        return isEnabled
    }

    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Deep-link to System Settings → General → Login Items
    /// (used when status == .requiresApproval).
    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
