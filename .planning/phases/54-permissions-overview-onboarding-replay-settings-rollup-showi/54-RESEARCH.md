# Phase 54: Permissions Overview & Onboarding Replay - Research

**Researched:** 2026-07-21
**Domain:** macOS TCC/privacy authorization status reads + System Settings deep-linking + SwiftUI Settings sidebar extension + safe onboarding-carousel replay
**Confidence:** HIGH for 4 of 5 permission status reads and the Settings/onboarding architecture (all directly confirmed in this exact codebase); MEDIUM for System Settings deep-link anchor names (community-sourced, not yet on-device-verified on macOS 26); LOW-MEDIUM for Input Monitoring's "not yet asked" trigger path (no official API exists on macOS at all)

## Summary

This phase is almost entirely a **read-and-wire** phase, not a new-subsystem phase: 4 of the 5 permissions already have a proven, synchronous, side-effect-free authorization-status read somewhere in this exact codebase (`CLLocationManager.authorizationStatus`, `EKEventStore.authorizationStatus(for:)`, `INFocusStatusCenter.default.authorizationStatus`, and — critically, confirmed during this research — `CBManager.authorization` for Bluetooth, already used at `NotchWindowController.swift:1896`). Only Input Monitoring has no official macOS read API; the best-effort technique is `IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)`, an Apple-documented (if sparsely) IOKit call.

The System Settings deep-link scheme this app already uses in production (`x-apple.systempreferences:com.apple.preference.security?Privacy_X`, confirmed working for Accessibility in `SettingsView.swift:475`) should be reused verbatim for all 5 anchors rather than switching to a newer, untested URL scheme — consistency with an already-proven mechanism beats an unverified "more modern" alternative.

The onboarding-replay requirement (D-07/D-08) is the one genuinely tricky part of this phase: `NotchWindowController.finishOnboarding()` (the only existing exit path from the carousel) unconditionally forces `interaction.phase = nextState(interaction.phase, .clicked)` and restarts several monitors — both are safe for a real first-launch (where there is no prior state to clobber) but **not safe to reuse verbatim for a replay** triggered mid-session, where the island may already be showing something (Now Playing, a device wing, etc.). A new, narrower replay-entry/replay-exit pair is needed that captures and restores `interaction.phase` and skips the monitor-restart/UserDefaults-write side effects.

**Primary recommendation:** Read all 5 statuses via direct, synchronous, framework-native calls (no new monitor classes, no new services); reuse `SidebarSection`'s exact enum-based pattern for the new "Permissions" case; add two small new methods to `NotchWindowController` (`replayOnboarding()` / a replay-specific finish path) rather than calling `start(isFirstLaunch:)` or `finishOnboarding()` directly for replay.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Permission status reads (5x) | API/Backend-equivalent (native service wrappers: `LocationProvider`, `CalendarService`, `FocusModeMonitor`, `BluetoothMonitor`/`CBManager`, new Input Monitoring check) | — | These are OS-facing status reads, not UI; SettingsView should call them, not reimplement them |
| Permissions rollup UI (list + summary row) | Client/Frontend (SwiftUI `SettingsView`) | — | Pure display, mirrors existing `SidebarSection` pattern |
| Deep-link to System Settings | Client (SwiftUI, `NSWorkspace.shared.open`) | — | Already the exact mechanism used for Accessibility today |
| Native re-request dialogs (D-06) | Client → OS (via `CLLocationManager`/`EKEventStore`/`INFocusStatusCenter` calls) | — | These are OS API calls triggered from SwiftUI button actions, no backend involved (this app has no backend) |
| Onboarding replay state machine | Client (`NotchWindowController`, `@MainActor`) | — | Mirrors the existing forced-flow `onboardingStep` mechanism exactly; must not touch persisted UserDefaults |

(This is a single-tier native macOS app — no browser/server split. "Tiers" above map to this app's own existing layering: SwiftUI views vs. `NotchWindowController`/service wrappers vs. raw OS frameworks.)

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ARCH-P2 | "Permissions Overview — X of Y granted" rollup row in Settings + a "Replay onboarding" button in About | Architecture Patterns (Permissions section shape, per-permission status reads), Code Examples (deep-link + replay), Common Pitfalls (replay state-clobber risk, Input Monitoring false-negative risk) |

</phase_requirements>

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Exactly 5 permissions are listed: Location (WeatherKit), Calendar+Reminders (as ONE combined row, even though they are 2 separate TCC entries under the hood), Bluetooth, Focus, and Input Monitoring.
- **D-02:** Automation/Apple Events is explicitly EXCLUDED from this rollup — it backs the paused/never-shipped Favorite/Like feature (Phase 49/50 aborted after weak spike results). Revisit if/when Phase 50 is picked back up.
- **D-03:** Input Monitoring IS included despite having no official "is granted" read API on macOS — use a best-effort check (research during planning should confirm the most reliable available technique, e.g. `IOHIDCheckAccess` or an equivalent undocumented-but-commonly-used check). Best-effort status beats omitting it entirely.
- **D-04:** Each permission shows a 3-state status: **granted** / **denied** (actively refused) / **not yet asked** (never prompted).
- **D-05:** Tapping a permission in **denied** state deep-links directly to that permission's specific System Settings > Privacy & Security pane (e.g. via `x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices`-style URLs) — macOS does not allow an app to re-trigger its own native permission dialog once a user has actively denied it. Research during planning should confirm the exact deep-link URL scheme constant for each of the 5 permissions (some, like Input Monitoring, may need `Privacy_ListenEvent` or similar — verify per-permission, don't assume one pattern fits all).
- **D-06:** Tapping a permission in **not yet asked** state triggers the normal native system permission dialog directly (calls the same `requestAuthorization`/`requestAccess`-style API each underlying service already uses) — no need to route through System Settings when a live prompt is actually available.
- Tapping a permission already **granted** has no action (or, at Claude's discretion, could simply do nothing / show a checkmark with no tap target).
- **D-07:** The button re-shows Phase 26's full existing onboarding carousel (Welcome → Trial/License/Buy → Permissions → Done) via `OnboardingFlow`/`OnboardingViewState` — not a new "permissions-only" partial mode. Reuses what already exists; no new onboarding-subset UI needed.
- **D-08:** Replaying is a PURE DISPLAY ACTION — it does NOT reset `hasCompletedOnboarding`/`isFirstLaunch` or any other persisted onboarding-related flag. If the user backs out mid-replay, the app must be left in exactly the same state as before the replay started (no half-onboarded state, no altered trial/license gating behavior).
- **D-09:** The "Replay Onboarding" button stays in the existing **About** section (matches ARCH-P2's original scoping exactly) — NOT moved into the new Permissions section.
- **D-10:** New dedicated top-level Settings sidebar section named "Permissions", alongside the existing 7 sections from Phase 51 — not folded into an existing section.
- **D-11:** Each of the 5 permissions renders as its own row: name/icon on the left, a status indicator on the right, the whole row tappable per D-05/D-06. Not a single collapsed "X of Y granted" summary line with a drill-down — the per-row list is always visible.
- A top-of-section "X of Y granted" summary row is still expected (matches ARCH-P2's literal wording) — it sits ABOVE the always-visible per-row list.

### Claude's Discretion

- Exact SF Symbol/glyph choices for the 3 status states.
- Whether a granted-permission row is tappable at all (no-op) or fully inert.
- Exact deep-link URL constants per permission (research at planning time — do not guess/hardcode without verifying against current macOS System Settings anchor names).
- Best-effort Input Monitoring status-check technique (document the chosen approach's known limitations, since no official API exists).

### Deferred Ideas (OUT OF SCOPE)

None beyond 3 reviewed-but-not-folded todos (calendar-month-grid-polish, island-briefly-disappears-during-click-through, quick-action-disabled-state-has-no-controller-gate) — all unrelated to this phase, stay deferred.

</user_constraints>

## Project Constraints (from CLAUDE.md)

- Native Swift/SwiftUI/AppKit only — no new third-party dependencies. This phase needs none (CoreLocation, EventKit, CoreBluetooth, Intents, IOKit.hid are all first-party Apple frameworks already linked or trivially linkable).
- "First-time programmer" project — avoid unnecessary complexity; this phase's own CONTEXT.md already steers toward reuse (D-07) over new abstractions, consistent with that constraint.
- No project-specific `.claude/skills/` exist yet (checked, none found) — no additional skill-sourced conventions apply beyond the codebase's own established patterns (documented below).
- GSD workflow enforcement note in CLAUDE.md is process-level only, not a code constraint.

## Standard Stack

### Core

| Framework | Min OS | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `CoreLocation` (`CLLocationManager.authorizationStatus`) | 15.0 (project floor) | Location permission status | Already used in `LocationProvider.swift:28` |
| `EventKit` (`EKEventStore.authorizationStatus(for:)`) | 15.0 | Calendar + Reminders permission status | `EKEventStore` already wrapped in `CalendarService.swift`; the static/class status read is the standard companion to the already-used `requestFullAccessToEvents()/requestFullAccessToReminders()` |
| `CoreBluetooth` (`CBManager.authorization`) | 15.0 | Bluetooth permission status | **Already used** in this exact codebase — `NotchWindowController.swift:1896`: `CBManager.authorization == .allowedAlways` |
| `Intents` (`INFocusStatusCenter.default.authorizationStatus`) | 15.0 | Focus permission status | Already used in `FocusModeMonitor.swift:60/70`, plus `.requestAuthorization` at line 78 |
| `IOKit.hid` (`IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)`) | 10.15+ | Input Monitoring best-effort status | No official alternative exists on macOS; documented by Apple (see Sources) though sparsely |

No new package/dependency install is required for this phase — every read is a direct call against a framework already linked in this project (`project.yml`'s existing target already links `IOKit` transitively via `AppKit`/system frameworks; `IOKit.hid` just needs `import IOKit.hid` in the new file).

### Package Legitimacy Audit

**Not applicable — this phase installs zero external packages.** All 5 status reads and all re-request calls are first-party Apple framework APIs already present in the toolchain. No `npm view`/`pip index`/`cargo search`/slopcheck run was needed.

## Architecture Patterns

### System Architecture Diagram

```
User opens Settings → clicks "Permissions" sidebar row
        │
        ▼
SettingsView.permissionsSection (NEW)
        │
        ├─► reads 5 statuses synchronously on .onAppear / .onChange(of: appearsActive)
        │     (mirrors existing launchAtLogin/licenseStatus refresh pattern, SettingsView.swift:197-208)
        │     ├─ CLLocationManager().authorizationStatus            → granted/denied/notYetAsked
        │     ├─ EKEventStore().authorizationStatus(for: .event)     ┐ combined into ONE row (D-01)
        │     ├─ EKEventStore().authorizationStatus(for: .reminder)  ┘ per PermissionStatus.combine(...)
        │     ├─ CBManager.authorization                            → granted/denied/notYetAsked
        │     ├─ INFocusStatusCenter.default.authorizationStatus     → granted/denied/notYetAsked
        │     └─ IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)      → granted/denied/unknown(best-effort)
        │
        ├─► renders "X of 5 granted" summary row (top, always visible)
        ├─► renders 5 always-visible per-row list (D-11)
        │
        └─► row tapped:
              ├─ granted   → no-op (or inert, Claude's discretion)
              ├─ denied    → NSWorkspace.shared.open(deepLinkURL(for: permission))
              └─ notYetAsked → calls the SAME request function each service already exposes
                    (CLLocationManager().requestWhenInUseAuthorization(),
                     EKEventStore().requestFullAccessToEvents()/requestFullAccessToReminders(),
                     INFocusStatusCenter.default.requestAuthorization { },
                     Bluetooth: no explicit request call exists/needed — see Pitfall 3,
                     Input Monitoring: no reliable trigger exists — see Pitfall 4)

Separately, in About section:
"Replay Onboarding" button
        │
        ▼
(NSApp.delegate as? AppDelegate)?.notchController?.replayOnboarding()   ── NEW method
        │  (mirrors the EXISTING cross-window precedent:
        │   SettingsView.swift:439 already calls
        │   notchController?.focusPermissionGranted() the same way)
        ▼
NotchWindowController.replayOnboarding()  ── NEW
        │  captures priorPhase = interaction.phase
        │  sets onboardingStep = .welcome, isOnboardingActive = true, interaction.phase = .expanded
        │  renderPresentation(); syncClickThrough()
        ▼
IslandResolver.resolve(...) sees onboardingStep != nil → returns .onboarding(step)  (existing, untouched)
        ▼
NotchPillView.onboardingCarousel(step)  (existing, untouched — Welcome→Trial→Permissions→Done)
        │  user clicks through, OR clicks Back repeatedly (no close/X exists today — see Pitfall 1)
        ▼
On .done + checkmark tap → onOnboardingFinish → NEW replay-exit path (NOT finishOnboarding() verbatim)
        │  restores interaction.phase = priorPhase (NOT nextState(...,.clicked))
        │  does NOT rewrite ActivitySettings.onboardingCompletedKey (already true — D-08)
        │  does NOT re-call startBluetoothMonitor()/startOutfitRefresh() (already running — D-08 no side effects)
        │  isOnboardingActive = false; onboardingStep = nil; renderPresentation(); updateVisibility(); syncClickThrough()
```

### Recommended Project Structure

No new files needed. Changes land in 3 existing files:

```
Islet/SettingsView.swift        # + permissionsSection, + SidebarSection.permissions case,
                                 #   + PermissionStatus enum/read helpers (or a small new file,
                                 #   e.g. Islet/PermissionStatus.swift, if SettingsView.swift
                                 #   growth is a concern — Claude's discretion, this codebase
                                 #   already tolerates a large SettingsView.swift)
Islet/Notch/NotchWindowController.swift  # + replayOnboarding(), + replay-exit path
Islet/Notch/BluetoothMonitor.swift       # NOT modified — CBManager.authorization is a static
                                          #   read independent of the monitor instance
```

### Pattern 1: Extend `SidebarSection` exactly like Phase 51/52 did

`Islet/SettingsView.swift`'s `SidebarSection` enum (lines 95-131) is a `String, CaseIterable, Identifiable` enum with a `title`/`icon` computed property per case and a `visibleSections(hasNotch:)` static filter. Adding "Permissions" means:

```swift
// Source: Islet/SettingsView.swift:95-131 (existing pattern, confirmed in codebase)
enum SidebarSection: String, CaseIterable, Identifiable {
    case activities, appearance, switcher, permissions, fullscreen, weather, diagnostics, workspace, about
    // D-10 places "Permissions" as a new top-level section; exact ordinal position among
    // the other 7 is Claude's discretion (CONTEXT.md doesn't lock an order), but placing it
    // near "about"/"diagnostics" (both status/info-oriented) reads naturally.

    var title: String {
        switch self {
        // ...existing cases...
        case .permissions: return "Permissions"
        }
    }
    var icon: String {
        switch self {
        // ...existing cases...
        case .permissions: return "hand.raised"   // SF Symbol suggestion — Claude's discretion
        }
    }
}
```

Then add a `case .permissions: permissionsSection` arm to the `detail:` switch (line 171-190), following the exact same `ScrollView(.vertical) { Form { ... } }` shape every other section uses (e.g. `diagnosticsSection`, lines 408-417 — the smallest, simplest precedent to mirror).

### Pattern 2: Per-permission synchronous status read (no monitor classes needed)

```swift
// Location — mirrors LocationProvider.swift:28's own authorizationStatus read.
// CLLocationManager() can be constructed fresh for a read-only status check; it does NOT
// need to be the same instance LocationProvider owns (Apple's authorizationStatus is a
// process-wide TCC-backed value, not per-instance state).
CLLocationManager().authorizationStatus   // .notDetermined / .denied / .restricted / .authorizedAlways

// Calendar + Reminders — combined per D-01. EKEventStore() can likewise be constructed fresh.
EKEventStore.authorizationStatus(for: .event)      // .notDetermined / .denied / .restricted / .fullAccess / .writeOnly
EKEventStore.authorizationStatus(for: .reminder)    // same enum, .writeOnly is reminder-specific

// Bluetooth — CONFIRMED already in this codebase: NotchWindowController.swift:1896
import CoreBluetooth
CBManager.authorization   // .notDetermined / .restricted / .denied / .allowedAlways

// Focus — CONFIRMED already in this codebase: FocusModeMonitor.swift:60/70 (as a static helper
// FocusModeMonitor.isAuthorized already exists — reuse it directly, don't re-derive)
INFocusStatusCenter.default.authorizationStatus   // .notDetermined / .denied / .restricted / .authorized

// Input Monitoring — best-effort, no monitor precedent exists in this codebase (see Pitfall 4)
import IOKit.hid
IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)   // .kIOHIDAccessTypeGranted / .kIOHIDAccessTypeDenied / .kIOHIDAccessTypeUnknown
```

All 5 reads are synchronous, side-effect-free, and safe to call on every `.onAppear`/`.onChange(of: appearsActive)` refresh — mirroring `SettingsView`'s existing `launchAtLogin`/`licenseStatus` re-sync discipline (lines 197-208) exactly.

### Pattern 3: Deep-link to System Settings (reuse the exact working precedent)

```swift
// Source: Islet/SettingsView.swift:474-475 (EXISTING, confirmed working in this app on
// macOS 26/Tahoe for Accessibility — reuse the identical URL scheme prefix for consistency,
// rather than switching to the newer, untested com.apple.settings.PrivacySecurity.extension
// scheme community sources also document).
NSWorkspace.shared.open(URL(string:
    "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
```

Per-permission anchor names (community-sourced — see Assumptions Log A1):

| Permission | Anchor |
|---|---|
| Location | `Privacy_LocationServices` |
| Calendar | `Privacy_Calendars` |
| Reminders | `Privacy_Reminders` (D-01 combines Calendar+Reminders into one row — if BOTH are denied, either anchor is defensible; if only one is denied, deep-link to the specific denied one) |
| Bluetooth | `Privacy_Bluetooth` |
| Input Monitoring | `Privacy_ListenEvent` |
| Focus | `Privacy_Focus` (lowest-confidence anchor — see Assumptions Log A1) |

### Pattern 4: Replay Onboarding — new narrow entry/exit, NOT `finishOnboarding()` reuse

See Code Examples below for the concrete diff shape. The key structural insight: `start(isFirstLaunch:)` and `finishOnboarding()` were both written assuming onboarding only ever happens ONCE, at launch, with no prior island state to preserve. A mid-session replay breaks that assumption, so a replay needs its OWN entry (skip the `UserDefaults` gate reads, skip the deferred-monitor-start logic since everything is already running) and its OWN exit (skip the `UserDefaults` write since it's already `true`, skip the monitor restarts since they're idempotent-but-pointless, and — critically — restore `interaction.phase` to whatever it was before replay started instead of forcing a `.clicked` transition).

### Anti-Patterns to Avoid

- **Building a second permanent `CGEventTap` just to probe Input Monitoring:** `DropInterceptTap` (`.cgSessionEventTap`) is gated by **Accessibility**, not Input Monitoring (confirmed by this project's own code comment: `DropInterceptTap.swift:36`, "Assumption A6 (confirmed on-device): Accessibility, not Input Monitoring, gates tap creation"). Do not reuse it as an Input Monitoring trigger — it is the wrong permission entirely.
- **Re-deriving Bluetooth authorization via `BluetoothMonitor`:** `BluetoothMonitor` has no authorization-status property and doesn't need one added — `CBManager.authorization` is a static, framework-level read completely independent of any `BluetoothMonitor` instance, already proven in this codebase.
- **Calling `finishOnboarding()` verbatim from a replay-done handler:** it forces `interaction.phase = nextState(interaction.phase, .clicked)`, which assumes a "coming from nothing" state that is only true at real launch.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Location/Calendar/Bluetooth/Focus status read | A new "PermissionMonitor" polling class | Direct synchronous framework calls (`CLLocationManager().authorizationStatus`, `EKEventStore.authorizationStatus(for:)`, `CBManager.authorization`, `INFocusStatusCenter.default.authorizationStatus`) on `.onAppear`/refocus | These are already-synchronous, side-effect-free reads — a polling monitor would add complexity (timers, `@Published` state, lifecycle) for zero benefit over "read it when Settings is opened/refocused," exactly like this file already does for `launchAtLogin`/`licenseStatus` |
| Input Monitoring trigger-on-tap | A dedicated, permanently-running `CGEventTap` solely to nudge the TCC prompt | Rely on `OSDInterceptor`'s existing **unconditional**, launch-time `.cghidEventTap` (`OSDInterceptor.swift:112-113`, HID-level — the tap type that actually gates on Input Monitoring, unlike `DropInterceptTap`'s Accessibility-gated `.cgSessionEventTap`) having already triggered the OS prompt on first launch | By the time a user ever opens the Permissions rollup, Input Monitoring is very likely already in a determined state (granted/denied) because `OSDInterceptor` already asked at launch — see Pitfall 4 for the residual "not yet asked" edge case and what to do about it |
| Deep-link URL construction | A hand-rolled URL-string-building helper with per-permission string interpolation logic | A plain `[Permission: String]` anchor-name lookup dictionary/switch, passed straight into the SAME `NSWorkspace.shared.open(URL(string:))` one-liner already used at `SettingsView.swift:474-475` | No dynamic/user-controlled input feeds these URLs (all 5 anchors are hardcoded constants) — a lookup table is simpler and safer than any string-building abstraction |

**Key insight:** every non-Input-Monitoring permission in this phase already has a proven, working precedent somewhere in this exact codebase. The work here is almost entirely "read it once more, in a new place" — resist the urge to introduce a new abstraction layer (a `PermissionService` protocol, a unified enum-driven monitor, etc.) for what is fundamentally 5 independent, unrelated framework calls with no shared lifecycle.

## Common Pitfalls

### Pitfall 1: The onboarding carousel has NO close/dismiss affordance today — "backing out mid-replay" may be structurally impossible via the UI
**What goes wrong:** D-08 says "if the user backs out mid-replay, the app must be left in exactly the same state." But `onboardingNavRow` (`NotchPillView.swift:1935-1951`) only ever renders Back (hidden on `.welcome`) and Next/Finish (checkmark on `.done`) — there is no X/close button anywhere in the carousel, and `isOnboardingActive` actively suppresses the normal hover-exit-collapse and click-elsewhere-dismiss paths (`NotchWindowController.swift:627,1491,1633,1685`) while onboarding is showing.
**Why it happens:** the original Phase 26 design intentionally makes onboarding a forced, uninterruptible flow at first launch, where "backing out" was never a supported concept.
**How to avoid:** the plan should explicitly decide one of: (a) the only real "back out" during replay is force-quitting/losing focus, which is already safe as long as the replay-exit path never touches persisted state before the user reaches Done (a mid-replay quit just discards the in-memory `onboardingStep`/`isOnboardingActive` state — nothing was ever written), or (b) add a minimal close affordance scoped ONLY to replay mode (a small extra tap target, e.g. tapping the collapsed pill again, or clicking outside — needs its own on-device UAT). Flagged as an Open Question below — do not assume either resolution without deciding it explicitly during planning.
**Warning signs:** if the plan's tasks silently assume a "Cancel" button exists in the existing carousel, that assumption is wrong and needs correcting before implementation.

### Pitfall 2: `finishOnboarding()` cannot be called verbatim for a replay
**What goes wrong:** `finishOnboarding()` (`NotchWindowController.swift:1917-1929`) does 4 things: (1) writes `onboardingCompletedKey = true` (harmless no-op during replay, already true), (2) forces `interaction.phase = nextState(interaction.phase, .clicked)` (NOT harmless — this can clobber whatever the island was legitimately showing before replay started, e.g. mid-Now-Playing), (3) restarts `startBluetoothMonitor()`/`startOutfitRefresh()` (idempotent, so harmless but pointless), (4) calls `updateVisibility()`/`syncClickThrough()`.
**Why it happens:** the function was written under the single-use "this only ever runs once, at launch" assumption.
**How to avoid:** write a distinct replay-exit function that captures `interaction.phase` at replay-entry time and restores that captured value (not a `nextState` transition) at replay-exit, and skip the monitor-restart calls entirely (they're pure no-ops during replay since everything they'd start is already running).
**Warning signs:** if a plan task literally says "wire the Done button's checkmark to call `finishOnboarding()`" for the replay path, that's the bug — it needs to call the new replay-exit function instead, with the existing `finishOnboarding()` untouched for the real first-launch path.

### Pitfall 3: Bluetooth has no in-app "request authorization" call to mirror for D-06
**What goes wrong:** unlike Location (`requestWhenInUseAuthorization()`), Calendar (`requestFullAccessToEvents()`), and Focus (`requestAuthorization(completion:)`), CoreBluetooth's `CBManager`/`CBCentralManager` does not expose an explicit "please prompt now" method — the Bluetooth TCC prompt is triggered as a side effect of actually constructing/using a `CBCentralManager` (or, in this codebase's actual working mechanism, `IOBluetoothDevice.register(forConnectNotifications:selector:)`, which `BluetoothMonitor.start()` calls).
**Why it happens:** Apple's Bluetooth privacy model ties the prompt to actual API usage, not to a standalone permission-request call, unlike the other 3 permissions.
**How to avoid:** for "not yet asked" Bluetooth, tapping the row should call `BluetoothMonitor`'s existing `start()` (already idempotent, already the app's own established trigger for this exact prompt via `grantOnboardingPermission(.bluetooth)` at `NotchWindowController.swift:1889-1897`) rather than inventing a new Bluetooth-specific request call.
**Warning signs:** searching for a `CBCentralManager.requestAuthorization()`-style method that doesn't exist and building a workaround around its absence.

### Pitfall 4: Input Monitoring's "not yet asked" state may be practically unreachable — but must still degrade safely if hit
**What goes wrong:** `OSDInterceptor` is started **unconditionally** at every launch (`NotchWindowController.swift:565`, `startOSDInterceptor()`, no `activityEnabled(...)` gate) and its tap type (`.cghidEventTap`) is the one that actually gates on Input Monitoring (not `DropInterceptTap`'s `.cgSessionEventTap`, which gates on Accessibility instead — see Anti-Patterns). This means by the time a user has ever launched the app once, Input Monitoring has almost certainly already moved out of "not yet asked" — the D-06 tap-to-trigger-native-dialog affordance for Input Monitoring may rarely if ever actually fire in practice.
**Why it happens:** `IOHIDCheckAccess` is a read of a state the OS already resolved at first launch via an unrelated feature (OSD suppression), not something this phase's own code triggers for the first time.
**How to avoid:** document this explicitly in the plan; for the rare edge case where `IOHIDCheckAccess` still reports `.kIOHIDAccessTypeUnknown` at Settings-open time (e.g., very first launch, before `OSDInterceptor.start()` has run), the tap-to-request action should be a no-op or a soft "check again" (re-read the status) rather than attempting to construct a NEW, separate `CGEvent.tapCreate(tap: .cghidEventTap, ...)` purely to nudge the prompt — that would duplicate `OSDInterceptor`'s own responsibility.
**Warning signs:** a plan task that adds a brand-new HID-level event tap solely for this phase, when `OSDInterceptor` already owns that concern.

### Pitfall 5: `EKEventStore.authorizationStatus(for:)` enum cases differ between "legacy" and "full access" tiers
**What goes wrong:** on macOS 14+ SDKs (this project's 15.0 floor), `EKAuthorizationStatus` includes `.fullAccess` and `.writeOnly` (reminder-only) alongside the older `.authorized` (now effectively legacy/deprecated). A naive `status == .authorized` check will read as "denied" even when the user has actually granted full access via the newer API tier this codebase's own `requestFullAccessToEvents()`/`requestFullAccessToReminders()` calls already use.
**Why it happens:** Apple extended the enum without deprecating old call sites' compile-time behavior, so it's easy to check the wrong case.
**How to avoid:** treat `.fullAccess` as "granted" for both Calendar and Reminders sub-checks (matching what this codebase's own `createEvent`/`createReminder` already assume they have after their `requestFullAccess...()` calls succeed); do not special-case `.writeOnly` as granted for the Calendar+Reminders combined row unless a plan explicitly decides write-only reminders access should count (Claude's discretion, not locked).
**Warning signs:** the Xcode compiler will immediately flag any wrong/missing case in an exhaustive `switch` — verify at build time, not just by inspection.

## Code Examples

### Replay-entry (new method on `NotchWindowController`)

```swift
// Source: pattern derived from Islet/Notch/NotchWindowController.swift:441-456's existing
// start(isFirstLaunch:) onboarding-gate tail (lines 627-633) — NOT a verbatim reuse, since
// start(isFirstLaunch:) also does UserDefaults reads/writes and deferred-monitor-start logic
// that a mid-session replay must NOT repeat.
private var replayPriorPhase: NotchInteractionPhase?   // captured so replay-exit can restore it

func replayOnboarding() {
    guard onboardingStep == nil else { return }   // idempotent — a replay already in progress is a no-op re-tap
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

### Replay-exit (new method, wired to the SAME `onOnboardingFinish` closure NotchPillView already calls — routed by whether `replayPriorPhase` is non-nil)

```swift
// Source: pattern derived from finishOnboarding() (NotchWindowController.swift:1917-1929),
// deliberately OMITTING the UserDefaults write (D-08: no persisted-flag change) and the
// monitor-restart calls (idempotent but unnecessary — everything is already running), and
// restoring the CAPTURED prior phase instead of forcing nextState(...,.clicked).
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

### Permissions section row model (new, small, pure — mirrors `ActivitySettings.focusPermissionStatusHint`'s existing style of small pure helper functions)

```swift
// Source: pattern only — no direct codebase precedent for a 3-state enum yet, but mirrors
// OnboardingViewState's own D-03 "nil/false/true" tri-state discipline (Islet/Notch/OnboardingViewState.swift:11-15)
enum PermissionStatus { case granted, denied, notYetAsked }

func locationPermissionStatus() -> PermissionStatus {
    switch CLLocationManager().authorizationStatus {
    case .authorizedAlways, .authorized: return .granted
    case .denied, .restricted: return .denied
    case .notDetermined: return .notYetAsked
    @unknown default: return .notYetAsked
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Per-feature ad-hoc permission popovers (`showFocusPermissionExplanation`, `showOSDPermissionExplanation`) | A single generalized Permissions list/section | This phase | Consolidates 2 one-off booleans into one structured, extensible list — future permissions (if any) get a row, not a new bool |
| `EKAuthorizationStatus.authorized` (legacy, pre-iOS17/macOS14) | `.fullAccess`/`.writeOnly` tiered access | Already adopted by this codebase's `requestFullAccessToEvents()`/`requestFullAccessToReminders()` (Phase 14/28) | The new Permissions rollup must check the SAME newer enum cases this codebase's request calls already assume, or granted state will read as denied |

**Deprecated/outdated:**
- `EKAuthorizationStatus.authorized` — superseded by `.fullAccess` for new code, though the case still compiles (deprecated, not removed).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | System Settings deep-link anchor names: `Privacy_LocationServices`, `Privacy_Calendars`, `Privacy_Reminders`, `Privacy_Bluetooth`, `Privacy_ListenEvent`, `Privacy_Focus` | Architecture Patterns / Pattern 3 | Sourced from a community-maintained GitHub gist (not official Apple documentation), cross-referenced against Apple support articles that confirm the FEATURE names but not the literal anchor strings. `Privacy_Accessibility` (already used in this app) and the general `com.apple.preference.security` scheme prefix ARE confirmed working on this project's own macOS 26 dev machine — the other 5 anchors follow the same naming convention but are unverified on this specific OS version. If wrong, the deep-link opens System Settings' root pane instead of the specific Privacy row — a minor, easily-caught-in-UAT degradation, not a crash. Recommend a cheap on-device `open "x-apple.systempreferences:..."` Terminal check per anchor during planning/Wave 0, before wiring 5 button actions around unverified strings. |
| A2 | `Privacy_Focus` in particular (lowest confidence of the 6) — whether INFocusStatusCenter's permission surfaces under this exact anchor, a differently-named anchor, or has no dedicated deep-linkable Privacy & Security row at all on macOS 26 | Architecture Patterns / Pattern 3 | If no such pane/anchor exists, D-05's "denied → deep-link" behavior for Focus specifically has no valid target; the plan should have a fallback (e.g., deep-link to the general Privacy & Security root pane, `x-apple.systempreferences:com.apple.preference.security`, with no anchor) if on-device verification finds this anchor invalid. |
| A3 | `IOHIDCheckAccess` requires no extra entitlement/Info.plist key beyond `NSInputMonitoringUsageDescription` (already present, `project.yml:109`) | Standard Stack / Package Legitimacy Audit | If an entitlement gap exists, the read would still compile/run but might report inaccurate results; low risk since the same usage-description key already backs Input Monitoring's existing (if unused-until-now) purpose in this app. |

**If this table is empty:** N/A — see entries above.

## Open Questions

1. **Does the onboarding replay need an explicit cancel/close affordance, or is "no supported cancel, only complete-or-quit" acceptable?**
   - What we know: today's carousel has zero close/X button anywhere (`onboardingNavRow`, `NotchPillView.swift:1935-1951`); `isOnboardingActive` actively blocks the normal hover-exit/click-away dismissal paths while onboarding shows.
   - What's unclear: whether D-08's "if the user backs out mid-replay" wording anticipates a UI affordance that doesn't exist yet, or whether it's only describing the "force-quit/relaunch mid-replay" case (which is already safe as long as the replay-exit path is the only place persisted state changes, and it only runs on Done).
   - Recommendation: the plan should explicitly decide and state which interpretation it's building for — this is a UX decision, not a technical one, and is cheap to resolve with a one-line clarification before planning locks task shape.

2. **What should the "X of Y granted" summary count as "granted" for the combined Calendar+Reminders row — does a partial grant (Calendar full-access but Reminders denied, or vice versa) count as 1 toward the summary, 0, or a distinct partial state?**
   - What we know: D-01 locks Calendar+Reminders as ONE row; D-04 locks a 3-state model (granted/denied/notYetAsked) per permission overall.
   - What's unclear: the combined row's own tri-state resolution when its two underlying TCC entries disagree (e.g. Calendar full-access, Reminders never asked).
   - Recommendation: default to "most-restrictive wins" (if either sub-permission is denied, the row shows denied; if neither is denied but either is not-yet-asked, the row shows not-yet-asked; only both-granted shows granted) — matches this codebase's general silent-degrade-to-least-permissive convention (`LocationProvider`'s D-01, `CalendarService`'s D-03) — but flag this as a planner decision to state explicitly, not silently assume.

## Environment Availability

Not applicable — this phase has no external tool/service/runtime dependencies beyond the Apple frameworks already linked in this Xcode project (all first-party, all already present in the SDK for the existing 15.0 deployment target).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (existing target: `IsletTests`) |
| Config file | `project.yml` (XcodeGen-generated Xcode project; no separate XCTest config file) |
| Quick run command | Xcode Cmd-U (single test class), or `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/OnboardingFlowTests` |
| Full suite command | `xcodebuild test -scheme Islet -destination 'platform=macOS'` (STATE.md references a "403-test regression suite" run this way as of Phase 52) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ARCH-P2 | `SidebarSection.visibleSections(hasNotch:)` still includes/excludes the new `.permissions` case correctly on notch/no-notch displays | unit | `xcodebuild test -only-testing:IsletTests/SettingsViewTests` | ✅ `IsletTests/SettingsViewTests.swift` exists (Phase 52 precedent — extend, don't replace) |
| ARCH-P2 | Combined Calendar+Reminders status-resolution logic (Open Question 2's chosen rule) is a pure function, unit-testable in isolation | unit | new test file/method, e.g. `PermissionStatusTests.swift` | ❌ Wave 0 — new file needed if status-resolution logic is factored into a pure function (recommended, mirrors `nextOnboardingStep`'s own pure-function precedent) |
| ARCH-P2 | `replayOnboarding()`/replay-exit correctly restore `interaction.phase` and never touch `onboardingCompletedKey` | manual-only (on-device UAT) | — | Not automatable: requires observing real island visual state across a live replay session, mirrors this codebase's own precedent of on-device UAT for all `NotchWindowController` interaction-state changes (e.g. Phase 43/45/48's UAT-gated closes) |
| ARCH-P2 | 5 permission status reads reflect real System Settings state | manual-only (on-device UAT) | — | TCC-gated reads cannot be simulated in a unit test without mocking every framework (`CLLocationManager`, `EKEventStore`, `CBManager`, `INFocusStatusCenter`, `IOHIDCheckAccess`) — not worth the abstraction cost per this codebase's existing precedent of leaving `LocationProvider`/`CalendarService`/`FocusModeMonitor`/`BluetoothMonitor` themselves UAT-verified, not unit-tested, for their live OS-facing behavior |

### Sampling Rate

- **Per task commit:** `xcodebuild test -only-testing:IsletTests/SettingsViewTests -only-testing:IsletTests/OnboardingFlowTests` (or the new pure-function test file, if added)
- **Per wave merge:** full `xcodebuild test -scheme Islet` suite
- **Phase gate:** full suite green + on-device UAT (5 permission rows in each of granted/denied/not-yet-asked states as feasible, plus a full replay-onboarding walkthrough) before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] If status-resolution logic for the combined Calendar+Reminders row is factored into a pure function (recommended — see Open Question 2), a new `PermissionStatusTests.swift` (or similar) is needed — no existing file covers this.
- [ ] No other gaps — `SettingsViewTests.swift` and `OnboardingFlowTests.swift` both already exist and can be extended.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | This app has no user auth/login |
| V3 Session Management | No | N/A |
| V4 Access Control | No | Single-user local app; no privilege boundaries to enforce |
| V5 Input Validation | Marginal | The 5 deep-link URLs are hardcoded constants (no user input feeds them) — no injection surface, matching this codebase's own existing precedent note at `SettingsView.swift:592-593` ("hardcoded constant with no user input, so there is no injection surface") |
| V6 Cryptography | No | No secrets/crypto involved in this phase |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Untrusted string interpolated into a `URL(string:)`/deep link | Tampering | Not applicable here — all 5 anchor strings are compile-time constants, never built from user/external input (mirrors the existing Accessibility deep-link precedent) |
| A TCC status read silently reporting stale/wrong data after the user changes it in System Settings while the app is running | (Not a security vulnerability, but a correctness pitfall) | Re-read on `.onAppear`/`.onChange(of: appearsActive)`, matching this file's existing `launchAtLogin`/`licenseStatus` refresh discipline — already the plan's own Architecture Pattern above |

## Sources

### Primary (HIGH confidence)
- `Islet/Notch/NotchWindowController.swift` (this codebase) — `CBManager.authorization == .allowedAlways` (line 1896), `onboardingStep`/`isOnboardingActive` gate mechanics (lines 337-338, 441-456, 550, 578, 627-633, 1877-1929), `focusPermissionGranted()` cross-window-call precedent (line 733, invoked from `SettingsView.swift:439`)
- `Islet/Location/LocationProvider.swift`, `Islet/Calendar/CalendarService.swift`, `Islet/Notch/FocusModeMonitor.swift` (this codebase) — existing synchronous authorization reads and request calls
- `Islet/Notch/DropInterceptTap.swift` (line 36) — "Accessibility, not Input Monitoring, gates tap creation" (own project's confirmed on-device finding, 24-03-SUMMARY.md)
- `Islet/Notch/OSDInterceptor.swift` (lines 108-113) — `.cghidEventTap`, the HID-level tap type, confirmed via 39-08's on-device finding (STATE.md)
- `Islet/SettingsView.swift` — `SidebarSection` enum pattern (lines 95-131), existing Accessibility deep-link (lines 474-475)
- [IOHIDCheckAccess | Apple Developer Documentation](https://developer.apple.com/documentation/iokit/3181573-iohidcheckaccess?language=objc) — official (if minimal) Apple doc confirming the function/enum shape

### Secondary (MEDIUM confidence)
- [Apple System Preferences URL Schemes gist](https://gist.github.com/rmcdongit/f66ff91e0dad78d4d6346a75ded4b751) — community-maintained anchor-name list, cross-checked against the codebase's own already-working `Privacy_Accessibility` usage for scheme-prefix consistency
- WebSearch results on `IOHIDRequestAccess`/`IOHIDCheckAccess` usage in Karabiner-Elements (open-source, actively maintained) — corroborates the function's real-world reliability

### Tertiary (LOW confidence)
- `Privacy_Focus` anchor name — single community source, not cross-verified against an official Apple document or this project's own on-device test (see Assumptions Log A2)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 4 of 5 status reads are directly confirmed already-working code in this exact codebase; Input Monitoring's `IOHIDCheckAccess` is Apple-documented (if sparse)
- Architecture: HIGH — extends an existing, well-established `SidebarSection` pattern with zero new plumbing; the onboarding-replay design is derived directly from reading the actual `NotchWindowController`/`OnboardingFlow` source
- Pitfalls: HIGH for the replay-state-clobber and Bluetooth/Input-Monitoring-trigger findings (all directly traced through this codebase's own source and comments); MEDIUM for the exact deep-link anchor strings (community-sourced, cheap to verify on-device before/during execution)

**Research date:** 2026-07-21
**Valid until:** 30 days (stable Apple frameworks; the one fast-moving risk is System Settings anchor names across macOS point releases — re-verify anchors if the dev machine's macOS version changes before this phase executes)
