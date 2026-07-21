# Phase 54: Permissions Overview & Onboarding Replay - Pattern Map

**Mapped:** 2026-07-22
**Files analyzed:** 5 (2 modified existing, 1 new source file, 2 test files — 1 modified, 1 new)
**Analogs found:** 5 / 5 (all files have a same-codebase analog; Input Monitoring's own status-read sub-block has no analog and is called out separately below)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|---------------|
| `Islet/SettingsView.swift` (modify: `SidebarSection` + `permissionsSection` + About's Replay button) | component (SwiftUI view) | request-response (status read + tap-to-act) | itself — `SidebarSection` enum (lines 95-131) + `diagnosticsSection`/`aboutSection` (lines 408-417, 505-543) + `osdPermissionExplanationView`'s deep-link (lines 459-483) | exact (same file, same established enum/section pattern) |
| `Islet/PermissionStatus.swift` (new) | utility (pure status-read + status-resolution helpers) | transform (framework enum → 3-state `PermissionStatus`) | `Islet/Notch/OnboardingFlow.swift` (pure enum + total-function reducer/gate discipline) | role-match (closest "pure Foundation-only helper file" precedent in the codebase) |
| `Islet/Notch/NotchWindowController.swift` (modify: `replayOnboarding()` + `finishOnboardingReplay()` + `replayPriorPhase`) | controller (`@MainActor` window/interaction controller) | event-driven (phase-machine mutation) | itself — `finishOnboarding()` (lines 1917-1929) + `start(isFirstLaunch:)`'s onboarding-gate tail (lines 441-456, 627-633) | exact (same file, same controller, sibling method to the one being narrowed) |
| `IsletTests/SettingsViewTests.swift` (modify: add Permissions-section tests) | test | transform (pure-function assertions) | itself — `testVisibleSectionsIncludesSwitcherWhenHasNotchIsTrue`/`testVisibleSectionsExcludesSwitcherWhenHasNotchIsFalse` (lines 10-20) | exact |
| `IsletTests/PermissionStatusTests.swift` (new) | test | transform (pure-function assertions) | `IsletTests/OnboardingFlowTests.swift` (pure total-function test shape, e.g. `testShouldShowOnboardingTrueForGenuinelyFreshInstall`) | role-match (closest "pure Foundation-only reducer/gate test file" precedent) |

## Pattern Assignments

### `Islet/SettingsView.swift` — `SidebarSection` extension (component)

**Analog:** itself, `SidebarSection` enum (`Islet/SettingsView.swift:95-131`)

**Core pattern to copy verbatim shape** (lines 95-131):
```swift
enum SidebarSection: String, CaseIterable, Identifiable {
    case activities, appearance, switcher, fullscreen, weather, diagnostics, workspace, about
    // D-10: add `permissions` as a new case here — exact ordinal position is Claude's
    // discretion (CONTEXT.md doesn't lock an order); RESEARCH.md suggests near
    // "diagnostics"/"about" (both status/info-oriented sections).

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activities: return "Activities"
        // ...
        case .about: return "About"
        // + case .permissions: return "Permissions"
        }
    }

    var icon: String {
        switch self {
        case .activities: return "bolt"
        // ...
        case .about: return "info.circle"
        // + case .permissions: return "hand.raised"  // SF Symbol suggestion, Claude's discretion
        }
    }

    static func visibleSections(hasNotch: Bool) -> [SidebarSection] {
        hasNotch ? SidebarSection.allCases : SidebarSection.allCases.filter { $0 != .switcher }
    }
}
```
Note: `visibleSections(hasNotch:)` filters out ONLY `.switcher` — the new `.permissions` case does not need a filter entry (it should be visible on both notch and non-notch displays), so this function needs no change beyond `allCases` picking it up automatically.

**Detail-switch wiring pattern** (`body`'s `detail:` switch, lines 170-191): add a `case .permissions: permissionsSection` arm alongside the other 8 cases — same shape, no special-casing needed.

**Section-view shape to copy** — smallest existing precedent (`diagnosticsSection`, lines 408-417):
```swift
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
```
The new `permissionsSection` should follow this exact `ScrollView(.vertical) { Form { Section(...) { ... } } .padding(20) }` shape — a summary `LabeledContent`/`Text` row for "X of 5 granted" above a `ForEach` of 5 tappable rows (per D-11), not a nested `Section` per permission.

**Refresh-on-appear/refocus pattern to copy** (lines 197-208, mirrors D-04's "re-read on refocus" requirement from RESEARCH's Pitfall/Security table):
```swift
.onAppear {
    launchAtLogin = LaunchAtLogin.isEnabled
    licenseStatus = LicenseState.shared.status
    refreshNotchAvailability()
    // + read all 5 permission statuses into @State here
}
.onChange(of: appearsActive) { _, active in
    if active {
        launchAtLogin = LaunchAtLogin.isEnabled
        licenseStatus = LicenseState.shared.status
        refreshNotchAvailability()
        // + re-read all 5 permission statuses here too
    }
}
```

**Deep-link pattern to copy verbatim** (lines 473-477, the ONE existing working System-Settings deep-link in this app):
```swift
Button("Open System Settings") {
    NSWorkspace.shared.open(URL(string:
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    showOSDPermissionExplanation = false
}
.keyboardShortcut(.defaultAction)
```
Reuse the exact `x-apple.systempreferences:com.apple.preference.security?Privacy_X` scheme/prefix for all 5 new anchors (`Privacy_LocationServices`, `Privacy_Calendars`/`Privacy_Reminders`, `Privacy_Bluetooth`, `Privacy_ListenEvent`, `Privacy_Focus` — MEDIUM confidence per RESEARCH.md Assumptions A1/A2, verify on-device before wiring).

**Native re-request pattern to copy** (lines 434-446, Focus's existing "Continue" button — the one proven live re-request call in this codebase):
```swift
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
```
The new Permissions rows' "not yet asked" tap action (D-06) should call each service's own already-existing request function directly (`CLLocationManager().requestWhenInUseAuthorization()`, `EKEventStore().requestFullAccessToEvents()/requestFullAccessToReminders()`, `INFocusStatusCenter.default.requestAuthorization`, `BluetoothMonitor.start()` per RESEARCH's Pitfall 3) — no new request API needed.

**Replay Onboarding button placement (D-09) — About section** (lines 505-543, `aboutSection`):
```swift
private var aboutSection: some View {
    ScrollView(.vertical) {
        Form {
            Section("License") { /* ... existing ... */ }
            LabeledContent("Version") { Text(Self.versionString) }
            Section("Credits") { /* ... existing ... */ }
            // + new: Button("Replay Onboarding") { (NSApp.delegate as? AppDelegate)?.notchController?.replayOnboarding() }
            //   mirrors the EXISTING cross-window call precedent at line 439
            //   ((NSApp.delegate as? AppDelegate)?.notchController?.focusPermissionGranted())
        }
        .padding(20)
    }
}
```

---

### `Islet/PermissionStatus.swift` (new file — pure status-read/resolution helpers)

**Analog:** `Islet/Notch/OnboardingFlow.swift` (pure, Foundation-only, total-function discipline)

**File-header/discipline pattern to copy** (`Islet/Notch/OnboardingFlow.swift:1-18`):
```swift
import Foundation
// [module doc: PURE seam like nextOnboardingStep(...)/shouldShowOnboarding(...) —
//  Foundation-only where possible, no AppKit; framework status reads (CLLocationManager,
//  EKEventStore, CBManager, INFocusStatusCenter, IOHIDCheckAccess) are the necessary
//  exception since this file's whole job IS reading those frameworks — but the
//  RESOLUTION logic (raw enum → PermissionStatus, worst-of-two combine) should be
//  factored into small pure functions the same way nextOnboardingStep(...) is, so they
//  are unit-testable without mocking a single framework.]

enum PermissionStatus: Equatable { case granted, denied, notYetAsked }
```

**3-state read pattern** (from RESEARCH.md Code Examples, cross-referenced against `LocationProvider.swift:28`, `FocusModeMonitor.swift:60/69-71`, `NotchWindowController.swift:1896`):
```swift
// Location — mirrors LocationProvider.swift:28's read (CLLocationManager() constructed
// fresh for a read-only check; authorizationStatus is process-wide TCC state, not
// per-instance — safe to not reuse LocationProvider's own instance).
func locationPermissionStatus() -> PermissionStatus {
    switch CLLocationManager().authorizationStatus {
    case .authorizedAlways, .authorized: return .granted
    case .denied, .restricted: return .denied
    case .notDetermined: return .notYetAsked
    @unknown default: return .notYetAsked
    }
}

// Bluetooth — CBManager.authorization already proven at NotchWindowController.swift:1896
// (CBManager.authorization == .allowedAlways). Do NOT add a status property to
// BluetoothMonitor — this is a static, instance-independent framework read.
func bluetoothPermissionStatus() -> PermissionStatus {
    switch CBManager.authorization {
    case .allowedAlways: return .granted
    case .denied, .restricted: return .denied
    case .notDetermined: return .notYetAsked
    @unknown default: return .notYetAsked
    }
}

// Focus — FocusModeMonitor.isAuthorized (FocusModeMonitor.swift:69-71) already exists;
// reuse it directly for the "granted" branch rather than re-deriving.
func focusPermissionStatus() -> PermissionStatus {
    switch INFocusStatusCenter.default.authorizationStatus {
    case .authorized: return .granted
    case .denied, .restricted: return .denied
    case .notDetermined: return .notYetAsked
    @unknown default: return .notYetAsked
    }
}
```

**Calendar+Reminders combined-row worst-of-two resolution** (D-13 — new logic, no direct codebase precedent, but mirrors `LocationProvider`'s D-01 "silent degrade to least-permissive" convention referenced in RESEARCH.md Open Question 2):
```swift
// D-13: denied beats notYetAsked beats granted — the row shows the WORST of the two
// underlying EKEventStore.authorizationStatus(for:) reads (mirrors this codebase's
// existing degrade-to-least-permissive convention, e.g. LocationProvider.requestOnce's
// D-01 "any non-authorized status settles nil, no exceptions").
func combinedCalendarReminderStatus(event: PermissionStatus, reminder: PermissionStatus) -> PermissionStatus {
    if event == .denied || reminder == .denied { return .denied }
    if event == .notYetAsked || reminder == .notYetAsked { return .notYetAsked }
    return .granted
}
```
Note Pitfall 5 from RESEARCH.md: `EKAuthorizationStatus.fullAccess` (not the legacy `.authorized`) is the "granted" case this codebase's own `requestFullAccessToEvents()`/`requestFullAccessToReminders()` calls already assume — verify the exhaustive switch treats `.fullAccess` as granted, matching `CalendarService.swift`'s own `createEvent`/`createReminder` assumptions.

**Input Monitoring — no analog, new territory** (see "No Analog Found" below).

---

### `Islet/Notch/NotchWindowController.swift` — `replayOnboarding()` / `finishOnboardingReplay()` (controller)

**Analog:** itself — `finishOnboarding()` (lines 1917-1929) is the direct sibling this new pair must NOT reuse verbatim (Pitfall 2); `start(isFirstLaunch:)`'s onboarding-gate tail (lines 441-456, 627-633) is the entry-side precedent.

**Existing `finishOnboarding()` to deliberately NOT copy verbatim** (lines 1917-1929):
```swift
private func finishOnboarding() {
    UserDefaults.standard.set(true, forKey: ActivitySettings.onboardingCompletedKey)
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        isOnboardingActive = false
        onboardingStep = nil
        interaction.phase = nextState(interaction.phase, .clicked)
        renderPresentation()
    }
    updateVisibility()
    syncClickThrough()
    if activityEnabled(ActivitySettings.deviceKey) { startBluetoothMonitor() }
    startOutfitRefresh()
}
```
Do NOT call this for replay — it writes `onboardingCompletedKey` (harmless no-op but wrong to touch per D-08), forces `interaction.phase = nextState(interaction.phase, .clicked)` (can clobber a legitimately-showing island state, e.g. mid-Now-Playing — Pitfall 2), and restarts monitors (idempotent but pointless).

**Properties to add** (mirrors `onboardingStep`/`isOnboardingActive`'s own declaration site, lines 337-338):
```swift
private(set) var onboardingStep: OnboardingStep?
private var isOnboardingActive = false
// + private var replayPriorPhase: InteractionPhase?   // captured at replay-entry, restored at replay-exit
```

**New `replayOnboarding()` — entry, mirrors `start(isFirstLaunch:)`'s onboarding-gate tail shape (lines 452-456, 627-633) but WITHOUT the `UserDefaults` gate reads/writes:**
```swift
func replayOnboarding() {
    guard onboardingStep == nil else { return }   // idempotent — already-in-progress re-tap is a no-op
    replayPriorPhase = interaction.phase
    onboardingStep = .welcome
    isOnboardingActive = true
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        interaction.phase = .expanded
        renderPresentation()
    }
    syncClickThrough()
}
```

**New `finishOnboardingReplay()` — exit, mirrors `finishOnboarding()`'s shape (lines 1917-1929) minus the `UserDefaults` write and monitor restarts, restoring the captured phase instead of `nextState(...,.clicked)`:**
```swift
private func finishOnboardingReplay() {
    let restorePhase = replayPriorPhase ?? .collapsed
    replayPriorPhase = nil
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        isOnboardingActive = false
        onboardingStep = nil
        interaction.phase = restorePhase
        renderPresentation()
    }
    updateVisibility()
    syncClickThrough()
}
```

**Wiring precedent for `onOnboardingFinish`** (`NotchWindowController.swift:2222`, `NotchPillView.swift:267`, `NotchPillView.swift:1945` — the existing closure-injection pattern to extend so the SAME closure routes to `finishOnboarding()` vs `finishOnboardingReplay()` based on whether `replayPriorPhase` is non-nil):
```swift
// NotchWindowController.swift:2222 (existing, in NotchPillView(...) construction)
onOnboardingFinish: { [weak self] in self?.finishOnboarding() },
// → needs to branch: replayPriorPhase != nil ? finishOnboardingReplay() : finishOnboarding()
```

**Cross-window call precedent to copy for wiring the Replay button** (`SettingsView.swift:439`, already-proven pattern for a SwiftUI view reaching into the controller):
```swift
(NSApp.delegate as? AppDelegate)?.notchController?.focusPermissionGranted()
// → new: (NSApp.delegate as? AppDelegate)?.notchController?.replayOnboarding()
```

**D-12 replay-only close button** — no existing analog (`onboardingNavRow`, `NotchPillView.swift:1935-1951`, has only Back/Next/Finish, no X). New affordance needed, scoped ONLY to replay mode (check `isOnboardingActive`+some replay flag, or thread a `isReplay: Bool` through to `onboardingNavRow`/`onboardingCarousel`). See "No Analog Found" below.

---

### `IsletTests/SettingsViewTests.swift` (modify)

**Analog:** itself (lines 10-20) — same file, same `XCTestCase`, no `@MainActor` needed for pure functions.

```swift
func testVisibleSectionsIncludesSwitcherWhenHasNotchIsTrue() {
    let sections = SettingsView.SidebarSection.visibleSections(hasNotch: true)
    XCTAssertEqual(sections.count, SettingsView.SidebarSection.allCases.count)
    XCTAssertTrue(sections.contains(.switcher))
}
```
Add a parallel assertion that `.permissions` IS included in both the `hasNotch: true` and `hasNotch: false` cases (unlike `.switcher`, it should never be filtered out).

---

### `IsletTests/PermissionStatusTests.swift` (new)

**Analog:** `IsletTests/OnboardingFlowTests.swift` (pure total-function test shape)

```swift
// Source: IsletTests/OnboardingFlowTests.swift:50-58 shape — plain XCTestCase, no
// @MainActor, no framework mocking (the functions under test take already-resolved
// PermissionStatus values, not live framework reads — mirrors shouldShowOnboarding(...)
// taking already-read Bool/Bool? rather than reading UserDefaults itself).
final class PermissionStatusTests: XCTestCase {
    func testCombinedCalendarReminderStatusDeniedWinsOverNotYetAsked() {
        XCTAssertEqual(
            combinedCalendarReminderStatus(event: .denied, reminder: .notYetAsked),
            .denied)
    }
    func testCombinedCalendarReminderStatusNotYetAskedWinsOverGranted() {
        XCTAssertEqual(
            combinedCalendarReminderStatus(event: .granted, reminder: .notYetAsked),
            .notYetAsked)
    }
    func testCombinedCalendarReminderStatusGrantedOnlyWhenBothGranted() {
        XCTAssertEqual(
            combinedCalendarReminderStatus(event: .granted, reminder: .granted),
            .granted)
    }
}
```

## Shared Patterns

### Refresh-on-appear/refocus discipline
**Source:** `Islet/SettingsView.swift:197-208` (`.onAppear` / `.onChange(of: appearsActive)`)
**Apply to:** `permissionsSection`'s 5-status read — TCC state can change behind the app's back in System Settings while Settings is open (RESEARCH.md Security Domain table), so every status must be re-read on appear AND on refocus, exactly like `launchAtLogin`/`licenseStatus` already are.

### System Settings deep-link (exact working precedent, reuse verbatim)
**Source:** `Islet/SettingsView.swift:474-475`
```swift
NSWorkspace.shared.open(URL(string:
    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
```
**Apply to:** All 5 denied-state tap handlers (D-05) — same `x-apple.systempreferences:com.apple.preference.security?Privacy_X` prefix, only the anchor suffix changes per permission. No new URL-building abstraction needed (RESEARCH.md Don't-Hand-Roll table) — a plain `[Permission: String]` lookup is sufficient.

### Cross-window controller call from SwiftUI
**Source:** `Islet/SettingsView.swift:439`
```swift
(NSApp.delegate as? AppDelegate)?.notchController?.focusPermissionGranted()
```
**Apply to:** The Replay Onboarding button (`replayOnboarding()`) and any "not yet asked" Bluetooth tap (`BluetoothMonitor.start()` is owned by the controller, per Pitfall 3) — same optional-chain-through-`AppDelegate` pattern, no new plumbing.

### Pure total-function discipline for status resolution
**Source:** `Islet/Notch/OnboardingFlow.swift` (`nextOnboardingStep`, `shouldShowOnboarding`, `shouldSeedOnboardingCompletedForExistingUser` — all Foundation-only, no AppKit, exhaustive switches, unit-tested in isolation)
**Apply to:** `PermissionStatus`'s enum-mapping functions and `combinedCalendarReminderStatus` — factor the RESOLUTION logic (raw framework enum → 3-state, worst-of-two combine) as small pure functions separable from the actual framework calls, mirroring this codebase's established "pure seam + thin framework glue" split (also seen in `NotchInteractionState.swift`'s `nextState(...)` and `IslandResolver.resolve(...)`).

### Spring-animated phase mutation
**Source:** `Islet/Notch/NotchWindowController.swift` — every `interaction.phase` mutation site (e.g. lines 1687-1688, 1878-1879, 1917-1924)
```swift
withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
    interaction.phase = /* new value */
    renderPresentation()
}
```
**Apply to:** Both `replayOnboarding()` and `finishOnboardingReplay()` — every `interaction.phase` write in this codebase goes through this exact `withAnimation` wrapper; never mutate `interaction.phase` bare.

## No Analog Found

| File/Section | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `Islet/PermissionStatus.swift` — Input Monitoring status read (`IOHIDCheckAccess`) | utility | request-response | No existing codebase precedent reads `IOKit.hid`/`IOHIDCheckAccess` at all (RESEARCH.md confirms: "no monitor precedent exists in this codebase" — Pitfall 4). Follow RESEARCH.md's Code Examples/Standard Stack section directly: `import IOKit.hid; IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)` mapping `.kIOHIDAccessTypeGranted`/`.kIOHIDAccessTypeDenied`/`.kIOHIDAccessTypeUnknown` to `PermissionStatus`. Document the known limitation (no reliable "not yet asked" trigger exists — Pitfall 4) inline as a code comment. |
| `Islet/Notch/NotchPillView.swift` — replay-only close/X affordance (D-12) | component | event-driven | `onboardingNavRow` (lines 1935-1951) has zero close/X precedent — Pitfall 1 confirms the original carousel was designed with NO cancel concept. This is new UI, not a copy-from-elsewhere pattern; the nearest structural precedent is `navCircleButton`'s existing Back/Next/Finish circular-button shape (immediately below `onboardingNavRow`, ~line 1953+), which the new X button should reuse for visual consistency even though its behavior (call `finishOnboardingReplay()` without advancing to `.done`) has no prior analog. |

## Metadata

**Analog search scope:** `Islet/SettingsView.swift`, `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/NotchPillView.swift`, `Islet/Notch/OnboardingFlow.swift`, `Islet/Notch/NotchInteractionState.swift`, `Islet/Notch/OnboardingViewState.swift`, `Islet/Notch/FocusModeMonitor.swift`, `Islet/Location/LocationProvider.swift`, `Islet/Calendar/CalendarService.swift`, `IsletTests/SettingsViewTests.swift`, `IsletTests/OnboardingFlowTests.swift`
**Files scanned:** 11 (all read fully except `NotchWindowController.swift`, 2740 lines — targeted non-overlapping reads via grep-located line ranges: 330-460, 590-640, 725-755, 1860-1940)
**Pattern extraction date:** 2026-07-22
