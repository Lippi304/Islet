---
phase: quick-260709-gvy
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Islet/SettingsView.swift
autonomous: true
requirements: []
user_setup: []

must_haves:
  truths:
    - "Opening Settings shows a native TabView with exactly 3 tabs: General, Appearance, Activities."
    - "General tab shows License section, 'Launch Islet at login' toggle, Diagnostics section, and Version row — same content and behavior as the old single-Form layout."
    - "Appearance tab shows the Accent color picker (moved out of the old Activities section) and the 'Hide notch in fullscreen' toggle — same behavior as before."
    - "Activities tab shows only Charging, Now Playing, and Devices toggles — Accent is no longer here."
    - "Every toggle/button still reads/writes the exact same @AppStorage key or calls the exact same function as before the refactor — zero behavior change, only view-hierarchy reorganization."
  artifacts:
    - path: "Islet/SettingsView.swift"
      provides: "TabView-based SettingsView with 3 tabs (General, Appearance, Activities) replacing the single Form"
      contains: "TabView"
  key_links:
    - from: "General tab License section"
      to: "LicenseState.shared.status / licenseService.activate"
      via: "unchanged @State licenseStatus, unchanged activate() function"
      pattern: "licenseStatus"
    - from: "Appearance tab Accent picker"
      to: "ActivitySettings.accentIndexKey"
      via: "unchanged @AppStorage(ActivitySettings.accentIndexKey) private var accentIndex"
      pattern: "AppStorage\\(ActivitySettings\\.accentIndexKey\\)"
    - from: "Appearance tab Fullscreen toggle"
      to: "ActivitySettings.hideInFullscreenKey"
      via: "unchanged @AppStorage(ActivitySettings.hideInFullscreenKey) private var hideInFullscreen"
      pattern: "AppStorage\\(ActivitySettings\\.hideInFullscreenKey\\)"
    - from: "Activities tab toggles"
      to: "ActivitySettings.chargingKey / nowPlayingKey / deviceKey"
      via: "unchanged @AppStorage bindings, unchanged Toggle views"
      pattern: "chargingEnabled|nowPlayingEnabled|deviceEnabled"
---

<objective>
Restructure `SettingsView.swift`'s `body` from a single long `Form` into a native SwiftUI
`TabView` with 3 tabs — General, Appearance, Activities — so future settings have a home
without building a full sidebar-navigation window (like macOS System Settings) yet.

This is a pure view-hierarchy reorganization. No new state, no new `@AppStorage` keys, no
changed persistence keys, no changed function signatures. Every `@State`/`@AppStorage`
property, `.onAppear`/`.onChange(of: appearsActive)` observer, and helper (`buyNowButton`,
`licenseEntry`, `statusLine`, `activate()`, `saveDiagnosticReport()`, `versionString`) stays
declared on the top-level `SettingsView` struct exactly as today — only which tab's `Form`
renders which `Section` changes.

Purpose: create room for the settings the user plans to add in upcoming sessions, without
prematurely building a sidebar-style settings window.
Output: `Islet/SettingsView.swift` with a `TabView` `body` grouped into General / Appearance
/ Activities tabs, behaviorally identical to the current single-Form layout.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

<interfaces>
<!-- Full current content of Islet/SettingsView.swift (244 lines) — this is the exact
     "before" state. Do not re-read the file; use this as the source of truth. -->

```swift
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

    // Quick task 260709-glz — default true mirrors the controller's default (matches
    // today's behavior for existing users, no regression).
    @AppStorage(ActivitySettings.hideInFullscreenKey) private var hideInFullscreen = true

    var body: some View {
        Form {
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
                            launchAtLogin = true
                            LaunchAtLogin.openLoginItemsSettings()
                        } else {
                            launchAtLogin = result
                        }
                    } catch {
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                }

            Section("Activities") {
                Toggle("Charging", isOn: $chargingEnabled)
                Toggle("Now Playing", isOn: $nowPlayingEnabled)
                Toggle("Devices", isOn: $deviceEnabled)

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

            Section("Fullscreen") {
                Toggle("Hide notch in fullscreen", isOn: $hideInFullscreen)
            }

            Section("Diagnostics") {
                Button("Save Diagnostic Report…") { saveDiagnosticReport() }
            }

            LabeledContent("Version") {
                Text(Self.versionString)
            }
        }
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

    private var buyNowButton: some View {
        Button("Buy Islet — €7.99") {
            NSWorkspace.shared.open(URL(string: "https://lippi304.xyz/projects/islet/buy")!)
        }
    }

    @ViewBuilder private var licenseEntry: some View {
        TextField("Enter your license key", text: $enteredKey)
            .frame(maxWidth: .infinity)
        Button("Activate") { activate() }
            .disabled(activationPhase == .validating
                      || enteredKey.trimmingCharacters(in: .whitespaces).isEmpty)
        statusLine
    }

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
            Text("⚠ Server not reachable.").foregroundStyle(.secondary)
            Button("Retry") { activate() }
        }
    }

    private func activate() {
        activationPhase = .validating
        licenseService.activate(key: enteredKey) { result in
            switch result {
            case .success(let validated):
                LicenseState.shared.sessionActivated = true
                UserDefaults.standard.set(Date().timeIntervalSince1970,
                                          forKey: "license.activationNudge")
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
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Replace the single Form with a 3-tab TabView</name>
  <files>Islet/SettingsView.swift</files>
  <action>
Rewrite only the `body` computed property (everything else in the struct — every `@State`,
`@Environment`, `@AppStorage`, the `ActivationPhase` enum, `licenseService`, and every
helper computed property/function below `body` — stays byte-identical to the "before"
content in the `<interfaces>` block above; do not move any of it into the tab views' scope
and do not duplicate any of it per tab).

Replace the top-level `Form { ... }` with a `TabView { ... }` containing exactly 3 tabs,
each its own `Form` wrapped in `.tabItem { Label(...) }`, distributing the existing
`Section`s as follows (content of every section is copied verbatim — same switch cases,
same modifiers, same closures, same bindings — only which tab it lives under changes):

1. **General tab** — `Form` containing, in this order: the existing `Section("License")`
   unchanged (the `switch licenseStatus` with `buyNowButton`/`licenseEntry` as today), the
   `Toggle("Launch Islet at login", isOn: $launchAtLogin)` with its `.onChange(of:
   launchAtLogin)` handler unchanged, the existing `Section("Diagnostics")` with the "Save
   Diagnostic Report…" button unchanged, and the existing `LabeledContent("Version")` row
   unchanged. Wrap in `.tabItem { Label("General", systemImage: "gearshape") }`.

2. **Appearance tab** — `Form` containing: the Accent color picker — the
   `LabeledContent("Accent") { HStack { ForEach(...) { Circle... } } }` block, taken out of
   the old "Activities" section verbatim (same `accentIndex` binding, same
   `ActivitySettings.palette`), wrapped in a new `Section("Appearance")`; followed by the
   existing `Section("Fullscreen")` with `Toggle("Hide notch in fullscreen", isOn:
   $hideInFullscreen)` unchanged. Wrap in `.tabItem { Label("Appearance", systemImage:
   "paintbrush") }`.

3. **Activities tab** — `Form` containing only the existing `Section("Activities")` with
   `Toggle("Charging", isOn: $chargingEnabled)`, `Toggle("Now Playing", isOn:
   $nowPlayingEnabled)`, `Toggle("Devices", isOn: $deviceEnabled)` — the Accent
   `LabeledContent` is REMOVED from this section (it now lives only in the Appearance tab).
   Wrap in `.tabItem { Label("Activities", systemImage: "bolt") }`.

Move the `.onAppear { ... }` and `.onChange(of: appearsActive) { ... }` modifiers (both
unchanged in content) from the old `Form` onto the new `TabView` itself, so they still fire
exactly once regardless of which tab is active — do not attach them per-tab.

Replace `.padding(20).frame(width: 360)` (previously on the `Form`) with `.padding(20)
.frame(width: 360, height: 280)` on the `TabView` — a `TabView` needs an explicit height
(unlike the old auto-sizing `Form`); 280 is a judgment call sized to fit the tallest tab
(General: License section + Launch toggle + Diagnostics + Version). If any tab's content
is visibly clipped when manually checked, this height can be adjusted later — not a
blocking concern for this refactor.

Do not change any `@AppStorage` key string, any function body, any `enum` case, or any
import statement.
  </action>
  <verify>
    <automated>xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug 2>&1 | tail -5 | grep -q "BUILD SUCCEEDED"</automated>
  </verify>
  <done>
`xcodebuild build -scheme Islet` reports BUILD SUCCEEDED. `Islet/SettingsView.swift`'s
`body` is a `TabView` with exactly 3 `.tabItem`s (General, Appearance, Activities).
`grep -c 'tabItem' Islet/SettingsView.swift` reports 3. The Accent `LabeledContent` appears
exactly once in the file (in the Appearance tab, not in Activities).
`chargingEnabled`/`nowPlayingEnabled`/`deviceEnabled` toggles remain grouped together in
the Activities tab. Every `@AppStorage`/`@State` property declaration and every helper
function/computed property below `body` is unchanged from the pre-refactor file.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| None crossed | Pure local SwiftUI view-hierarchy reorganization — no new input, no new UserDefaults key, no new external call |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-gvy-01 | Tampering | Islet/SettingsView.swift | accept | Refactor moves existing `Section`s between tabs; no new UserDefaults key, no new trust boundary, no behavior change to any toggle's read/write path |
</threat_model>

<verification>
- Build gate: `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` → BUILD SUCCEEDED.
- Manual (Xcode GUI, Cmd-R then open Settings — not terminal, per project memory feedback-xcode-gui-not-terminal): confirm 3 tabs appear (General, Appearance, Activities). Confirm General shows License/Launch-at-login/Diagnostics/Version. Confirm Appearance shows the Accent swatches and the Fullscreen toggle. Confirm Activities shows only Charging/Now Playing/Devices. Flip a toggle in each tab, quit and relaunch the app, reopen Settings, confirm the value persisted (proves the underlying `@AppStorage` keys are untouched).
</verification>

<success_criteria>
- `Islet/SettingsView.swift` body is a `TabView` with 3 tabs: General, Appearance, Activities.
- General: License section, Launch-at-login toggle, Diagnostics section, Version row.
- Appearance: Accent color picker, Fullscreen ("Hide notch in fullscreen") toggle.
- Activities: Charging, Now Playing, Devices toggles only.
- No `@AppStorage` key, function signature, or persisted behavior changed.
- `xcodebuild build -scheme Islet -configuration Debug` succeeds.
</success_criteria>

<output>
Create `.planning/quick/260709-gvy-settingsview-tabview-umbau-general-appea/260709-gvy-SUMMARY.md` when done.
</output>
