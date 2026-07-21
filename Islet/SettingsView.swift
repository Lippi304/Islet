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
    // Phase 41 / HUD-08 (D-03) — default ON, matches Charging/Device's opt-out convention;
    // no permission popover needed (CalendarService's existing EventKit authorization,
    // Phase 14/28, is reused as-is).
    @AppStorage(ActivitySettings.calendarCountdownKey) private var calendarCountdownEnabled = true
    // Phase 38 / HUD-05 (D-01) — the ONE activity toggle that defaults OFF (permission-gated,
    // opt-in). @State drives the one-time explanation popover (D-02: shown only at the moment
    // the toggle flips on, never at launch).
    @AppStorage(ActivitySettings.focusKey) private var focusEnabled = false
    @State private var showFocusPermissionExplanation = false
    // Phase 39 / HUD-03/HUD-04 (D-05): identical shape to focusEnabled above — off by default,
    // permission-gated. NOTE: per 39-03-SUMMARY.md's on-device spike finding
    // (suppression-unreliable), OSDInterceptor is a PERMANENT .listenOnly-only detector that
    // NEVER suppresses the native OSD regardless of this toggle's value — flipping it on
    // currently has no visible effect on the system OSD. The toggle/popover UI is still built
    // per the locked UI-SPEC contract (D-06/D-08) since Accessibility could become viable again
    // in a future macOS/permission-tier change; see 39-06-SUMMARY.md for the full no-op note.
    @AppStorage(ActivitySettings.osdSuppressionKey) private var osdSuppressionEnabled = false
    @State private var showOSDPermissionExplanation = false
    // Phase 40 / HUD-06 (D-11/D-12) — default true: the one deliberate exception among the
    // Activities toggles (besides osdSuppression's off-default), since this gates no system
    // permission, just a background network check.
    @AppStorage(ActivitySettings.autoUpdateCheckKey) private var autoUpdateCheckEnabled = true
    // Quick task 260709-glz — default true mirrors the controller's default (matches
    // today's behavior for existing users, no regression).
    @AppStorage(ActivitySettings.hideInFullscreenKey) private var hideInFullscreen = true
    // Phase 33 / WEATHER-01/02 (D-03/D-04) — a String-backed enum selector, same
    // @AppStorage-is-the-source-of-truth convention as the Activities toggles above; no
    // .onChange handler needed (NotchPillView/NotchWindowController each read the same key
    // independently). Mirrors materialStyle's fully-qualified-type-annotation convention below.
    @AppStorage(ActivitySettings.weatherStyleKey) private var weatherStyle: ActivitySettings.WeatherStyle = .medium

    // Phase 52 / SWITCH-03/SWITCH-04 (D-02) — the Switcher section's layout picker + 4
    // independent per-slot icon-placement pickers. Same keys/defaults as NotchPillView's
    // own @AppStorage reads (Plan 52-02) — both files are independent readers of the same
    // shared UserDefaults source, mirroring weatherStyle's existing dual-reader relationship.
    @AppStorage(ActivitySettings.switcherLayoutKey) private var switcherLayout: ActivitySettings.SwitcherLayout = .pill
    @AppStorage(ActivitySettings.switcherSlotLeftOuterKey) private var slotLeftOuter: SelectedView = .home
    @AppStorage(ActivitySettings.switcherSlotLeftInnerKey) private var slotLeftInner: SelectedView = .tray
    @AppStorage(ActivitySettings.switcherSlotRightInnerKey) private var slotRightInner: SelectedView = .calendar
    @AppStorage(ActivitySettings.switcherSlotRightOuterKey) private var slotRightOuter: SelectedView = .weather

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

    // Phase 51 / SETTINGS-02/SETTINGS-03 (D-01–D-06) — sidebar section identity.
    // Order and copy are locked: Activities, Appearance, Fullscreen, Weather,
    // Diagnostics, Workspace, About.
    // Phase 52 / SWITCH-03/SWITCH-04 (D-08) — bumped private -> internal so
    // IsletTests/SettingsViewTests.swift can reference it via @testable import Islet,
    // mirroring this codebase's existing private-to-internal testability-bump precedent
    // (NotchPillView.shelfStripVisible/tabWidth/tabHeight).
    enum SidebarSection: String, CaseIterable, Identifiable {
        case activities, appearance, switcher, fullscreen, weather, diagnostics, workspace, about

        var id: String { rawValue }

        var title: String {
            switch self {
            case .activities: return "Activities"
            case .appearance: return "Appearance"
            case .switcher: return "Switcher"
            case .fullscreen: return "Fullscreen"
            case .weather: return "Weather"
            case .diagnostics: return "Diagnostics"
            case .workspace: return "Workspace"
            case .about: return "About"
            }
        }

        var icon: String {
            switch self {
            case .activities: return "bolt"
            case .appearance: return "paintbrush"
            case .switcher: return "square.grid.2x2"
            case .fullscreen: return "arrow.up.left.and.arrow.down.right"
            case .weather: return "cloud.sun"
            case .diagnostics: return "stethoscope"
            case .workspace: return "tray"
            case .about: return "info.circle"
            }
        }

        // D-08 — on a display without a physical camera notch, the entire Switcher
        // section is not reachable in the sidebar. Pure filter, unit-tested below.
        static func visibleSections(hasNotch: Bool) -> [SidebarSection] {
            hasNotch ? SidebarSection.allCases : SidebarSection.allCases.filter { $0 != .switcher }
        }
    }
    @State private var selection: SidebarSection? = .activities
    // D-08 — refreshed independently on appear/refocus via refreshNotchAvailability(),
    // mirroring NotchPillView's own independent hasNotch read (Plan 52-02, RESEARCH.md
    // Pattern 2) — no new controller plumbing.
    @State private var hasNotchDisplay: Bool = false

    var body: some View {
        NavigationSplitView {
            // Plan 27-04 checkpoint fix: List(selection:) never registered a single click
            // on-device across 3 attempts (Scene-hosted, AppKit-hosted, .sidebar list style +
            // .contentShape) — confirmed via diagnostic instrumentation that `selection` never
            // changed regardless. Falling back to plain Buttons (already proven to respond
            // reliably in this same window, e.g. "Save Diagnostic Report…") bypasses whatever
            // is wrong with List's row-selection routing on this setup entirely.
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SidebarSection.visibleSections(hasNotch: hasNotchDisplay)) { section in
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
            // UAT fix (51-01): narrowed from min160/ideal180/max220 — "Diagnostics" (the
            // longest sidebar label) still fits with room to spare at 150. Combined with
            // the window widening to 600pt (D-05 revised), this gives appearanceSection's
            // segmented picker comfortable margin after it clipped "Liquid Glass" at 520pt.
            .navigationSplitViewColumnWidth(min: 140, ideal: 150, max: 190)
        } detail: {
            switch selection {
            case .activities:
                activitiesSection
            case .appearance:
                appearanceSection
            case .switcher:
                switcherSection
            case .fullscreen:
                fullscreenSection
            case .weather:
                weatherSection
            case .diagnostics:
                diagnosticsSection
            case .workspace:
                workspaceSection
            case .about:
                aboutSection
            case .none:
                activitiesSection
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
            refreshNotchAvailability()
        }
        .onChange(of: appearsActive) { _, active in
            if active {
                launchAtLogin = LaunchAtLogin.isEnabled
                licenseStatus = LicenseState.shared.status
                refreshNotchAvailability()
            }
        }
        // Phase 35 / GLASS-01 (D-08/D-09) — a separate integration point from the
        // island shell's `islandFill`: this file has no shader/distortion code at
        // all. D-08 approved extending Liquid Glass to the Settings window (with
        // Onboarding explicitly excluded); D-09 calls for the CALMER variant here —
        // half the island shell's gradient alpha at every stop, a frost material,
        // and a rim-light stroke, with NO distortion shader (readability risk on a
        // text-heavy form). D-08's scope extension is specific to the Liquid Glass
        // style, so this only applies when that style is selected (35-REVIEW.md
        // CR-01) — Gradient/Solid Black keep the pre-Phase-35 default background.
        .background {
            if materialStyle == .liquidGlass {
                ZStack {
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.25), location: 0.0),
                            .init(color: .black.opacity(0.15), location: 0.65),
                            .init(color: .black.opacity(0.05), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Color.clear.background(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                }
            }
        }
        .frame(width: 600, height: 380)
    }

    // Phase 51 / SETTINGS-03 (D-02) — Activities: Launch-at-login folded in alongside
    // the 8 activity toggles. The tallest section (D-05) — wrapped in ScrollView so
    // its last toggle ("Automatically Check for Updates") stays reachable within the
    // fixed 600x380 window (SETTINGS-02 scroll fix).
    private var activitiesSection: some View {
        ScrollView(.vertical) {
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
                    Toggle("Calendar Countdown", isOn: $calendarCountdownEnabled)
                    // Phase 38 / HUD-05 — D-02: the permission ask happens ONLY at this exact
                    // off-to-on flip, never at launch. D-04: declining the explanation leaves the
                    // toggle ON with the inert hint — the tap-to-retry gesture below is the ONLY way
                    // the explanation re-appears, never automatically.
                    Toggle("Focus Mode HUD", isOn: $focusEnabled)
                        .onChange(of: focusEnabled) { _, on in
                            if on && !FocusModeMonitor.isAuthorized {
                                showFocusPermissionExplanation = true
                            }
                        }
                        .popover(isPresented: $showFocusPermissionExplanation) {
                            focusPermissionExplanationView
                        }
                    if let hint = ActivitySettings.focusPermissionStatusHint(
                        toggleOn: focusEnabled, granted: FocusModeMonitor.isAuthorized
                    ) {
                        Text(hint)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .onTapGesture { showFocusPermissionExplanation = true }
                    }

                    // Phase 39 / HUD-03/HUD-04 — D-05/D-06/D-08: identical shape to the Focus Mode
                    // toggle above. Label is the exact locked string from 39-UI-SPEC.md — never
                    // "Volume/Brightness HUD" (that would incorrectly imply this toggle gates the
                    // HUD's own visibility, which it does not per D-06; the HUD keeps showing
                    // regardless of this toggle's value).
                    Toggle("Replace System Volume/Brightness OSD", isOn: $osdSuppressionEnabled)
                        .onChange(of: osdSuppressionEnabled) { _, on in
                            if on && !OSDInterceptor.isAccessibilityTrusted {
                                showOSDPermissionExplanation = true
                            }
                        }
                        .popover(isPresented: $showOSDPermissionExplanation) {
                            osdPermissionExplanationView
                        }
                    if let hint = ActivitySettings.osdPermissionStatusHint(
                        toggleOn: osdSuppressionEnabled, granted: OSDInterceptor.isAccessibilityTrusted
                    ) {
                        Text(hint)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .onTapGesture { showOSDPermissionExplanation = true }
                    }

                    // Phase 40 / HUD-06 (D-11) — automatic-check scheduling requires no macOS
                    // privacy grant, unlike Focus/OSD's permission-gated toggles above: no
                    // .onChange, no .popover, no status-hint Text (40-UI-SPEC.md Settings Toggle
                    // Contract).
                    Toggle("Automatically Check for Updates", isOn: $autoUpdateCheckEnabled)
                }
            }
            .padding(20)
        }
    }

    // Quick task 260709-glz — a fullscreen-visibility preference, its own dedicated
    // sidebar section (D-06).
    private var fullscreenSection: some View {
        ScrollView(.vertical) {
            Form {
                Section("Fullscreen") {
                    Toggle("Hide notch in fullscreen", isOn: $hideInFullscreen)
                }
            }
            .padding(20)
        }
    }

    // Phase 52 / SWITCH-03/SWITCH-04 (D-02/D-07) — the Switcher section: a Pill/Top-Edge
    // layout picker plus 4 independent per-slot icon-placement dropdowns. Mirrors
    // fullscreenSection's exact ScrollView(.vertical) { Form { ... }.padding(20) } shape.
    private var switcherSection: some View {
        ScrollView(.vertical) {
            Form {
                Section("Layout") {
                    Picker("Layout", selection: $switcherLayout) {
                        Text("Pill").tag(ActivitySettings.SwitcherLayout.pill)
                        Text("Top Edge").tag(ActivitySettings.SwitcherLayout.topEdge)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                // D-01: each of the 4 slots is fully independent — any icon can go in any
                // slot, not a fixed-pair swap. No duplicate-assignment validation (matches
                // this codebase's existing no-Picker-validation convention).
                Section("Icon Placement") {
                    Picker("Left Outer", selection: $slotLeftOuter) { slotOptions }
                        .pickerStyle(.menu)
                    Picker("Left Inner", selection: $slotLeftInner) { slotOptions }
                        .pickerStyle(.menu)
                    Picker("Right Inner", selection: $slotRightInner) { slotOptions }
                        .pickerStyle(.menu)
                    Picker("Right Outer", selection: $slotRightOuter) { slotOptions }
                        .pickerStyle(.menu)
                }
            }
            .padding(20)
        }
    }

    // Shared option rows for all 4 slot dropdowns above — one place mapping SelectedView to
    // its Label(name, systemImage:), reused verbatim by all 4 Pickers.
    @ViewBuilder private var slotOptions: some View {
        Label("Home", systemImage: "house.fill").tag(SelectedView.home)
        Label("Tray", systemImage: "tray.fill").tag(SelectedView.tray)
        Label("Calendar", systemImage: "calendar").tag(SelectedView.calendar)
        Label("Weather", systemImage: "cloud.sun.fill").tag(SelectedView.weather)
    }

    // Phase 33 / WEATHER-01/02 (D-03/D-04/D-05) — live-switches the Weather card between
    // its Medium and Large layouts, no relaunch (NotchPillView's @AppStorage on the
    // same key re-renders immediately). Mirrors appearanceSection's materialStyle segmented
    // Picker exactly, using the bare WeatherStyle module-level alias for the tags.
    private var weatherSection: some View {
        ScrollView(.vertical) {
            Form {
                Section("Weather") {
                    Picker("Weather Style", selection: $weatherStyle) {
                        Text("Medium").tag(WeatherStyle.medium)
                        Text("Large").tag(WeatherStyle.large)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(20)
        }
    }

    // Quick task 260708-u47: a point-in-time diagnostic SNAPSHOT for bug
    // reports — no new logging subsystem, nothing written unless clicked. Its own
    // dedicated sidebar section (D-03), not folded into About.
    private var diagnosticsSection: some View {
        ScrollView(.vertical) {
            Form {
                Section("Diagnostics") {
                    Button("Save Diagnostic Report…") { saveDiagnosticReport() }
                }
            }
            .padding(20)
        }
    }

    // Phase 38 / HUD-05 — D-02/D-03/D-04's one-time explanation popover, shown at the moment
    // the Focus Mode HUD toggle flips on while unauthorized. 38-01-SUMMARY.md's on-device spike
    // locked detection to Path A (INFocusStatusCenter) — this builds ONLY that variant's copy
    // from 38-UI-SPEC.md's Settings Permission Contract, not the Full Disk Access variant.
    private var focusPermissionExplanationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Allow Focus Status Access")
                .font(.system(size: 15, weight: .semibold))
            Text("Islet needs permission to detect when Focus or Do Not Disturb is on.")
                .font(.system(size: 12))
                .lineSpacing(12 * 0.4)
            HStack {
                Button("Not Now") {
                    showFocusPermissionExplanation = false
                }
                Spacer()
                Button("Continue") {
                    FocusModeMonitor.requestAuthorization { granted in
                        DispatchQueue.main.async {
                            if granted {
                                (NSApp.delegate as? AppDelegate)?.notchController?.focusPermissionGranted()
                            }
                            showFocusPermissionExplanation = false
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    // Phase 39 / HUD-03/HUD-04 — D-08's one-time explanation popover, shown at the moment the
    // OSD suppression toggle flips on while Accessibility is untrusted. This is the ONE
    // genuinely new mechanism in this phase: Accessibility has no `requestAuthorization(
    // completion:)`-style re-request API the way Focus's `INFocusStatusCenter` does, so the
    // primary action deep-links to System Settings' Accessibility pane instead. This button's
    // job ends at opening the pane — OSDInterceptor's own health-check timer (Plan 39-03) is
    // the sole mechanism that later confirms a grant, not this view.
    private var osdPermissionExplanationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Replace System OSD")
                .font(.system(size: 15, weight: .semibold))
            Text("Islet needs Accessibility access to hide the native volume/brightness indicator. Islet only intercepts volume and brightness key presses — it never reads, modifies, or sends anything else on your Mac.")
                .font(.system(size: 12))
                .lineSpacing(12 * 0.4)
            HStack {
                // D-06: declining leaves the toggle ON — the HUD keeps showing (unsuppressed)
                // regardless of this dismissal. Do NOT revert osdSuppressionEnabled here.
                Button("Not Now") {
                    showOSDPermissionExplanation = false
                }
                Spacer()
                Button("Open System Settings") {
                    NSWorkspace.shared.open(URL(string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    showOSDPermissionExplanation = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    // D-03 — Workspace: no shelf-specific settings exist today; a quiet centered
    // placeholder literally satisfies the 4-section sidebar contract (UI-SPEC
    // §Section Content Specs/Workspace). No Form/Section wrapper.
    private var workspaceSection: some View {
        ScrollView(.vertical) {
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
    }

    // D-02 — About: the adaptive License block (all 3 states) + Version label,
    // relocated verbatim — nothing else moves here.
    private var aboutSection: some View {
        ScrollView(.vertical) {
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

                // EQ-01 Registry Safety — Skiper UI's free-tier license requires visible
                // attribution since Islet holds no Pro license. Locked exact credit string,
                // 36-UI-SPEC.md.
                Section("Credits") {
                    Text("Equalizer bar animation inspired by Skiper UI (skiper25.com)")
                }
            }
            .padding(20)
        }
    }

    // D-01/D-04/D-05/D-07 — Appearance (renamed from System, Phase 51): material-style
    // segmented picker + 3 independent per-element accent swatch rows.
    private var appearanceSection: some View {
        ScrollView(.vertical) {
            Form {
                Section("Appearance Style") {
                    // UAT fix (51-01): the row label ("Style") duplicated the section
                    // header ("Appearance Style") and its reserved column width was what
                    // pushed "Liquid Glass" past the window's right edge. Hiding it is a
                    // pure space reclaim, not a functionality change.
                    Picker("Style", selection: $materialStyle) {
                        Text("Gradient").tag(MaterialStyle.gradient)
                        Text("Solid Black").tag(MaterialStyle.solidBlack)
                        Text("Liquid Glass").tag(MaterialStyle.liquidGlass)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section("Accent Colors") {
                    LabeledContent("Now Playing") { swatchRow(selection: $nowPlayingAccentIndex) }
                    LabeledContent("Charging") { swatchRow(selection: $chargingAccentIndex) }
                    LabeledContent("Device") { swatchRow(selection: $deviceAccentIndex) }
                }
            }
            .padding(20)
        }
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

    // Phase 52 / SWITCH-03/SWITCH-04 (D-08, RESEARCH.md Pattern 2) — independently resolves
    // the live built-in notched display, mirroring NotchPillView.topEdgeCutoutWidth's exact
    // pattern (selectTargetScreen + ScreenDescriptor.hasNotch) rather than plumbing a signal
    // through NotchWindowController. Falls back to false (Switcher section hidden) when no
    // notched built-in screen is present.
    private func refreshNotchAvailability() {
        hasNotchDisplay = selectTargetScreen(from: NSScreen.screens.map { $0.descriptor })?.hasNotch ?? false
    }

    static var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
