import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @Environment(\.appearsActive) private var appearsActive   // refocus → re-sync

    // TRIAL-03 / D-01 — the License section adapts to LicenseState.status. `status`
    // is a plain computed property (NOT observable), so it is re-read into @State on
    // appear and on refocus (Pitfall 4); LicenseState is intentionally NOT an
    // ObservableObject. Values: .trial(daysRemaining:) | .trialExpired | .licensed.
    @State private var licenseStatus = LicenseState.shared.status

    // D-04/D-05 — the activation state machine: idle (no status line) → validating
    // (~1s, Activate disabled) → success/failure inline status. The seam is held as
    // the PROTOCOL type (Plan 01) so Phase 12's PolarLicenseService is a one-line swap.
    private enum ActivationPhase { case idle, validating, success, failure, unreachable }
    @State private var enteredKey = ""
    @State private var activationPhase: ActivationPhase = .idle
    private let licenseService: LicenseService = PolarLicenseService()

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
            // D-01/D-02: the adaptive License section is the FIRST element in the
            // Form, above Launch-at-login. Its body swaps on the current
            // LicenseStatus — during an active trial it shows the days-remaining
            // countdown (D-03/TRIAL-03) that REPLACES the old fixed end-date notice.
            Section("License") {
                switch licenseStatus {
                case .trial(let days):
                    Text(days == 1
                         ? "1 day left in your trial."
                         : "\(days) days left in your trial.")
                        .foregroundStyle(.secondary)
                    buyNowButton
                    licenseEntry
                case .trialExpired:
                    Text("3-day trial period expired")
                        .font(.headline)
                    buyNowButton
                    licenseEntry
                case .licensed:
                    Text("Licensed ✓")
                }
            }

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

            // Quick task 260708-u47: a point-in-time diagnostic SNAPSHOT for bug
            // reports — no new logging subsystem, nothing written unless clicked.
            Section("Diagnostics") {
                Button("Save Diagnostic Report…") { saveDiagnosticReport() }
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
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            licenseStatus = LicenseState.shared.status
        }
        .onChange(of: appearsActive) { _, active in
            if active {
                launchAtLogin = LaunchAtLogin.isEnabled
                licenseStatus = LicenseState.shared.status
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    // D-07: opens the purchase page in the default browser. The URL is a hardcoded
    // constant with no user input, so there is no injection surface (T-11-04).
    private var buyNowButton: some View {
        Button("Buy Islet — €7.99") {
            NSWorkspace.shared.open(URL(string: "https://lippi304.xyz/projects/islet/buy")!)
        }
    }

    // D-04/D-05 — license key entry + Activate. Activate is disabled while
    // validating and when the trimmed field is empty (empty input is inert — no
    // validation attempt, no status change). The field fills the Form width.
    @ViewBuilder private var licenseEntry: some View {
        TextField("Enter your license key", text: $enteredKey)
            .frame(maxWidth: .infinity)
        Button("Activate") { activate() }
            .disabled(activationPhase == .validating
                      || enteredKey.trimmingCharacters(in: .whitespaces).isEmpty)
        statusLine
    }

    // D-04 — inline status line. Idle shows nothing; color is reserved for the
    // terminal success/failure outcome only (validating stays neutral .secondary).
    @ViewBuilder private var statusLine: some View {
        switch activationPhase {
        case .idle:
            EmptyView()
        case .validating:
            Text("⟳ Validating…").foregroundStyle(.secondary)
        case .success:
            Text("✓ License activated").foregroundStyle(.green)
        case .failure:
            Text("✗ That key wasn't recognized.").foregroundStyle(.red)
        case .unreachable:
            // D-04 — distinct from `.failure`: a network/server problem is NOT an
            // invalid key, so it gets its own non-red message plus a manual Retry
            // (no silent auto-retry).
            Text("⚠ Server not reachable.").foregroundStyle(.secondary)
            Button("Retry") { activate() }
        }
    }

    // D-04/D-05 — drive the state machine. The service completes on the MAIN thread
    // (Plan 01 contract), so @State/LicenseState are mutated directly without a hop.
    private func activate() {
        activationPhase = .validating
        licenseService.activate(key: enteredKey) { result in
            switch result {
            case .success(let validated):
                LicenseState.shared.sessionActivated = true
                // TRIGGER ONLY (T-11-02): any defaults write fires the existing
                // UserDefaults.didChangeNotification path — AppDelegate.licenseObserver
                // + NotchWindowController.defaultsObserver → updateVisibility() — which
                // re-reads isEntitled and live-unlocks the island (Phase 10 path, no
                // second show/hide site). This nudge key is NEVER read as entitlement
                // truth; entitlement lives in the in-memory sessionActivated.
                UserDefaults.standard.set(Date().timeIntervalSince1970,
                                          forKey: "license.activationNudge")
                // Phase 12 / LIC-02 — persist the granted record so the next launch
                // short-circuits LicenseState.status offline, with zero network call.
                LicenseManager.shared.recordValidation(
                    key: enteredKey.trimmingCharacters(in: .whitespacesAndNewlines),
                    validated: validated)
                licenseStatus = .licensed
                activationPhase = .success
            case .failure(.invalidKey):
                activationPhase = .failure
            case .failure(.unreachable):
                activationPhase = .unreachable
            }
        }
    }

    // Quick task 260708-u47 — builds the report from this view's already-bound state
    // (no new UserDefaults reads) and lets the user save it via a native NSSavePanel.
    // Fire-and-forget: nothing here needs to live-update while Settings is open.
    private func saveDiagnosticReport() {
        let text = DiagnosticReport.text(
            licenseStatus: LicenseState.shared.status,
            launchAtLogin: launchAtLogin,
            chargingEnabled: chargingEnabled,
            nowPlayingEnabled: nowPlayingEnabled,
            deviceEnabled: deviceEnabled,
            accentIndex: accentIndex,
            nowPlayingHealthy: (NSApp.delegate as? AppDelegate)?.notchController?.nowPlayingState.isHealthy
        )

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Islet-Diagnostic-Report.txt"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
