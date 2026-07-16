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
    // Phase 18 / NOW-06 — default true, matching nowPlayingEnabled's default (no regression
    // for existing users, fresh installs read ON).
    @AppStorage(ActivitySettings.songChangeToastKey) private var songChangeToastEnabled = true
    @AppStorage(ActivitySettings.deviceKey)     private var deviceEnabled = true
    // Quick task 260709-glz — default true mirrors the controller's default (matches
    // today's behavior for existing users, no regression).
    @AppStorage(ActivitySettings.hideInFullscreenKey) private var hideInFullscreen = true
    // Phase 33 / WEATHER-01/02 (D-03/D-04) — a String-backed enum selector, same
    // @AppStorage-is-the-source-of-truth convention as the Activities toggles above; no
    // .onChange handler needed (NotchPillView/NotchWindowController each read the same key
    // independently). Mirrors materialStyle's fully-qualified-type-annotation convention below.
    @AppStorage(ActivitySettings.weatherStyleKey) private var weatherStyle: ActivitySettings.WeatherStyle = .medium

    // Phase 27 / VISUAL-03 (D-05/D-07) — the material-style preset and the 3
    // independent per-element accent indices, replacing the single global
    // accentIndexKey. SwiftUI's native `@AppStorage` overload for any
    // `RawRepresentable where RawValue == String` reads/writes/falls back to
    // the declared default automatically (T-27-06) — no manual Binding needed.
    // Phase 35 / GLASS-01 (D-06): default flipped .gradient -> .liquidGlass — the
    // second of the two independently-hardcoded default locations (the other is
    // ActivitySettings.swift's IslandMaterialStyleKey.defaultValue, Plan 35-01).
    @AppStorage(ActivitySettings.materialStyleKey) private var materialStyle: ActivitySettings.MaterialStyle = .liquidGlass
    @AppStorage(ActivitySettings.nowPlayingAccentKey) private var nowPlayingAccentIndex = ActivitySettings.defaultAccentIndex
    @AppStorage(ActivitySettings.chargingAccentKey) private var chargingAccentIndex = ActivitySettings.defaultAccentIndex
    @AppStorage(ActivitySettings.deviceAccentKey) private var deviceAccentIndex = ActivitySettings.defaultAccentIndex

    // Phase 27 / SETTINGS-01 — sidebar section identity (D-01–D-04, UI-SPEC §Sidebar
    // Structure). Order and copy are locked: General, Workspace, System, About.
    private enum SidebarSection: String, CaseIterable, Identifiable {
        case general, workspace, system, about

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: return "General"
            case .workspace: return "Workspace"
            case .system: return "System"
            case .about: return "About"
            }
        }

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .workspace: return "tray"
            case .system: return "paintbrush"
            case .about: return "info.circle"
            }
        }
    }
    @State private var selection: SidebarSection? = .general

    var body: some View {
        NavigationSplitView {
            // Plan 27-04 checkpoint fix: List(selection:) never registered a single click
            // on-device across 3 attempts (Scene-hosted, AppKit-hosted, .sidebar list style +
            // .contentShape) — confirmed via diagnostic instrumentation that `selection` never
            // changed regardless. Falling back to plain Buttons (already proven to respond
            // reliably in this same window, e.g. "Save Diagnostic Report…") bypasses whatever
            // is wrong with List's row-selection routing on this setup entirely.
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SidebarSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        Label(section.title, systemImage: section.icon)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selection == section ? Color.accentColor.opacity(0.25) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(8)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            switch selection {
            case .general:
                generalSection
            case .workspace:
                workspaceSection
            case .system:
                systemSection
            case .about:
                aboutSection
            case .none:
                generalSection
            }
        }
        // Re-read the system state on appear and whenever the window's app
        // becomes active again — the user can flip the login item in System
        // Settings behind the app's back, so the toggle must never desync
        // (RESEARCH Pitfall 3). `appearsActive` is the macOS env value for
        // "this window is the active app".
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
        .frame(width: 520, height: 380)
    }

    // D-01 — General: 4 activity toggles + Launch-at-login + Fullscreen toggle +
    // Diagnostics button — a deliberate catch-all section (27-CONTEXT.md D-01).
    private var generalSection: some View {
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

            // APP-03: four independent activity on/off toggles (D-06/D-07),
            // pure on/off — no master switch, no per-activity duration (D-08).
            Section("Activities") {
                Toggle("Charging", isOn: $chargingEnabled)
                Toggle("Now Playing", isOn: $nowPlayingEnabled)
                Toggle("Song-Change Toast", isOn: $songChangeToastEnabled)
                Toggle("Devices", isOn: $deviceEnabled)
            }

            // Quick task 260709-glz — a fullscreen-visibility preference, distinct from
            // the activity on/off toggles above (not a live-activity source).
            Section("Fullscreen") {
                Toggle("Hide notch in fullscreen", isOn: $hideInFullscreen)
            }

            // Phase 33 / WEATHER-01/02 (D-03/D-04/D-05) — live-switches the Weather card between
            // its Medium and Large layouts, no relaunch (NotchPillView's @AppStorage on the
            // same key re-renders immediately). Mirrors systemSection's materialStyle segmented
            // Picker exactly, using the bare WeatherStyle module-level alias for the tags.
            Section("Weather") {
                Picker("Weather Style", selection: $weatherStyle) {
                    Text("Medium").tag(WeatherStyle.medium)
                    Text("Large").tag(WeatherStyle.large)
                }
                .pickerStyle(.segmented)
            }

            // Quick task 260708-u47: a point-in-time diagnostic SNAPSHOT for bug
            // reports — no new logging subsystem, nothing written unless clicked.
            Section("Diagnostics") {
                Button("Save Diagnostic Report…") { saveDiagnosticReport() }
            }
        }
        .padding(20)
    }

    // D-03 — Workspace: no shelf-specific settings exist today; a quiet centered
    // placeholder literally satisfies the 4-section sidebar contract (UI-SPEC
    // §Section Content Specs/Workspace). No Form/Section wrapper.
    private var workspaceSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Nothing to configure yet")
                .font(.headline)
            Text("The Shelf works automatically — no settings needed right now.")
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // D-02 — About: the adaptive License block (all 3 states) + Version label,
    // relocated verbatim — nothing else moves here.
    private var aboutSection: some View {
        Form {
            // D-01/D-02: the adaptive License section swaps on the current
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

            LabeledContent("Version") {
                Text(Self.versionString)   // D-09: version/build label
            }
        }
        .padding(20)
    }

    // D-04/D-05/D-07 — System (Theming): material-style segmented picker + 3
    // independent per-element accent swatch rows (UI-SPEC §System/Theming).
    private var systemSection: some View {
        Form {
            Section("Appearance Style") {
                Picker("Style", selection: $materialStyle) {
                    Text("Gradient").tag(MaterialStyle.gradient)
                    Text("Solid Black").tag(MaterialStyle.solidBlack)
                    Text("Liquid Glass").tag(MaterialStyle.liquidGlass)
                }
                .pickerStyle(.segmented)
            }

            Section("Accent Colors") {
                LabeledContent("Now Playing") { swatchRow(selection: $nowPlayingAccentIndex) }
                LabeledContent("Charging") { swatchRow(selection: $chargingAccentIndex) }
                LabeledContent("Device") { swatchRow(selection: $deviceAccentIndex) }
            }
        }
        .padding(20)
    }

    // D-07 — the existing curated swatch-circle picker (today's Appearance-tab
    // Accent row), factored into a reusable row bound to any of the 3
    // independent accent Bindings so each lively leaf element gets its own
    // picker without a second color-picker component (UI-SPEC Don't-Hand-Roll).
    @ViewBuilder private func swatchRow(selection: Binding<Int>) -> some View {
        HStack(spacing: 10) {
            ForEach(ActivitySettings.palette.indices, id: \.self) { i in
                Circle()
                    .fill(ActivitySettings.palette[i])
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle().strokeBorder(.primary, lineWidth: selection.wrappedValue == i ? 2 : 0)
                    )
                    .onTapGesture { selection.wrappedValue = i }
            }
        }
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
            nowPlayingAccentIndex: nowPlayingAccentIndex,
            chargingAccentIndex: chargingAccentIndex,
            deviceAccentIndex: deviceAccentIndex,
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
