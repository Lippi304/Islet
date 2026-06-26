import SwiftUI

struct SettingsView: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @Environment(\.appearsActive) private var appearsActive   // refocus → re-sync

    var body: some View {
        Form {
            Toggle("Launch Islet at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        // Apply the change; reflect the TRUE resulting state.
                        launchAtLogin = try LaunchAtLogin.set(on)
                        if LaunchAtLogin.requiresApproval {
                            LaunchAtLogin.openLoginItemsSettings()
                        }
                    } catch {
                        // Revert the UI to the real system state on failure.
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                }

            LabeledContent("Version") {
                Text(Self.versionString)   // D-09: version/build label
            }
        }
        // Re-read the system state on appear and whenever the window's app
        // becomes active again — the user can flip the login item in System
        // Settings behind the app's back, so the toggle must never desync
        // (RESEARCH Pitfall 3). `appearsActive` is the macOS env value for
        // "this window's app is the active app".
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
        .onChange(of: appearsActive) { _, active in
            if active { launchAtLogin = LaunchAtLogin.isEnabled }
        }
        .padding(20)
        .frame(width: 360)
    }

    static var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
