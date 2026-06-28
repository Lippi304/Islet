import SwiftUI

struct SettingsView: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @Environment(\.appearsActive) private var appearsActive   // refocus → re-sync

    // APP-03 activity preferences — app-owned, so @AppStorage IS the source of
    // truth (D-09). All three default ON (D-06/D-07): `@AppStorage(key) var x =
    // true` returns `true` when the key is ABSENT, so a fresh install reads ON
    // without writing anything. Keys + palette come from ActivitySettings so the
    // controller (Plan 04) reads the identical values.
    @AppStorage(ActivitySettings.chargingKey)   private var chargingEnabled = true
    @AppStorage(ActivitySettings.nowPlayingKey) private var nowPlayingEnabled = true
    @AppStorage(ActivitySettings.deviceKey)     private var deviceEnabled = true
    @AppStorage(ActivitySettings.accentIndexKey) private var accentIndex = ActivitySettings.defaultAccentIndex

    var body: some View {
        Form {
            Toggle("Launch Islet at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        let result = try LaunchAtLogin.set(on)
                        if on && LaunchAtLogin.requiresApproval {
                            // macOS needs the user to approve the login item:
                            // keep the toggle ON (pending) to match the System
                            // Settings deep-link we open, instead of snapping it
                            // back OFF.
                            launchAtLogin = true
                            LaunchAtLogin.openLoginItemsSettings()
                        } else {
                            // Reflect the TRUE resulting system state.
                            launchAtLogin = result
                        }
                    } catch {
                        // Revert the UI to the real system state on failure.
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                }

            // APP-03: three independent activity on/off toggles (D-06/D-07),
            // pure on/off — no master switch, no per-activity duration (D-08).
            Section("Activities") {
                Toggle("Charging", isOn: $chargingEnabled)
                Toggle("Now Playing", isOn: $nowPlayingEnabled)
                Toggle("Devices", isOn: $deviceEnabled)

                // D-12: a curated swatch palette (a fixed preset row, not a free
                // color wheel) with a selected ring. Tapping persists the index
                // via @AppStorage and
                // (once Plan 04 wires it) live-applies the accent.
                LabeledContent("Accent") {
                    HStack(spacing: 10) {
                        ForEach(ActivitySettings.palette.indices, id: \.self) { i in
                            Circle()
                                .fill(ActivitySettings.palette[i])
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle().strokeBorder(.primary, lineWidth: accentIndex == i ? 2 : 0)
                                )
                                .onTapGesture { accentIndex = i }
                        }
                    }
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
