# Phase 26: Onboarding Flow - Research

**Researched:** 2026-07-11
**Domain:** SwiftUI/AppKit notch-hosted UI state machine, in-app onboarding flow, cross-window (NSPanel ↔ NSWindow) handoff, permission-request sequencing
**Confidence:** HIGH (all findings grounded in direct codebase reads, no external library research needed — this phase adds zero new dependencies)

## Summary

Phase 26 replaces `AppDelegate`'s current `isFirstLaunch → openSettings()` branch with a new
notch-hosted onboarding presentation. The codebase already has every architectural piece this
phase needs to lean on: a pure single-arbiter resolver (`IslandResolver.resolve()`) that picks
ONE `IslandPresentation` case per render, a `syncClickThrough()` single-decision-point for
click-through hit-testing, an established `blobShape()` content-composition helper every
expanded-style case already renders through, a fully-built (but currently unused-by-onboarding)
license entry UI in `SettingsView.swift`, and three already-isolated permission-request call
sites (`BluetoothMonitor.start()`, `LocationProvider.requestOnce()`,
`EventKitService.fetchUpcoming()`). No third-party library is needed or recommended — this is a
pure application of the codebase's own existing patterns to a new presentation case.

The two hardest architectural questions — "how does an `IslandPresentation` case coexist with a
forced, non-collapsible carousel" and "how does the notch hand off to Settings and get a signal
back" — both have concrete, code-grounded answers below, but the second one surfaces a real gap:
**there is no existing "Settings window closed" or "resume onboarding" signal anywhere in the
codebase.** The `.openIsletSettings` notification is a one-way, payload-less, fire-and-forget
bridge (`AppDelegate.openSettings()` posts it; `IsletApp.swift`'s `OpenSettingsOnNotification`
view modifier is the only listener). This phase must decide whether to build a new "resume"
signal or rely on the already-proven `UserDefaults.didChangeNotification` state-resync idiom
(used 3× already: `AppDelegate.licenseObserver`, `NotchWindowController.defaultsObserver`,
`SettingsView`'s own `onAppear`/`onChange(appearsActive)`) — the research recommendation below is
the latter, since it requires zero new plumbing and the codebase already leans on it for every
comparable "something changed elsewhere, re-sync" case.

**Primary recommendation:** Add a new `.onboarding(OnboardingStep)` case to `IslandPresentation`,
checked FIRST in `resolve()` (ahead of `activeTransient`) so it is the single highest-priority
render for the whole session, gated by a new plain `UserDefaults` boolean flag
(`"onboarding.completed"`, following `ActivitySettings`'s app-owned-flag pattern, NOT
`TrialManager`'s Keychain pattern — onboarding is not a security gate). Route the license-key
step and any "grant a skipped permission later" step through the EXISTING `.openIsletSettings`
bridge (Settings' License section is already the first thing shown in the first tab — zero new
navigation/payload needed for D-05). Resume the onboarding flow after a Settings round-trip via
the existing `UserDefaults.didChangeNotification` resync idiom, not a new notification.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Onboarding carousel rendering (hero/trial-choice/permissions/done) | Browser/Client (SwiftUI, `NotchPillView`) | — | Same tier as every other island presentation (wings/expanded/idle) — D-06 locks this explicitly |
| Onboarding step sequencing / forced-flow state | AppKit glue (`NotchWindowController`) | Pure logic (`IslandResolver.swift`) | Mirrors the existing split: pure `resolve()` picks the presentation, the controller owns the mutable step index and wraps changes in `withAnimation(.spring)` |
| Permission system-prompt triggering (Bluetooth/Calendar/Location) | AppKit glue (`NotchWindowController` + `BluetoothMonitor`/`LocationProvider`/`EventKitService`) | — | Existing thin-glue-wrapper convention (`BluetoothMonitor`, `LocationProvider`, `EventKitService` already isolate each system framework) |
| License-key entry + validation | Frontend Server-equivalent (focusable `Window("settings")` scene, `SettingsView.swift`) | — | D-07 hard constraint: `NotchPanel.canBecomeKey == false` structurally cannot host a text field; license entry MUST live in the focusable Settings window |
| Onboarding-shown-once persistence | Storage (`UserDefaults`) | — | App-owned, non-security-critical flag — same tier as `ActivitySettings`'s toggles, not `TrialManager`'s Keychain tier |
| Launch-at-Login toggle (D-10, mirrored on Done screen) | AppKit/System (`SMAppService.mainApp` via `LaunchAtLogin.swift`) | Browser/Client (both Settings' and onboarding's toggle UI) | System is the source of truth (no app-owned flag) — both UI surfaces just read/write the same `SMAppService` call, per `LaunchAtLogin.swift`'s own doc comment |

## Standard Stack

### Core
No new libraries. This phase is 100% first-party Swift/SwiftUI/AppKit code built on top of
existing project infrastructure (`IslandResolver.swift`, `NotchWindowController.swift`,
`NotchPillView.swift`, `SettingsView.swift`, `LicenseState.swift`, `TrialManager.swift`,
`LaunchAtLogin.swift`). No `npm install`/SPM package addition applies.

### Package Legitimacy Audit

Not applicable — this phase adds zero external packages. Skipping the slopcheck/registry gate per
the protocol's own scope ("whenever this phase installs external packages").

## Architecture Patterns

### System Architecture Diagram

```
AppDelegate.applicationDidFinishLaunching
  │
  ├─ TrialManager.recordFirstLaunchIfNeeded() ─────────────► (unchanged, still runs first — D-04)
  │
  ├─ isFirstLaunch == true?
  │     │
  │     ├─ NO  → existing eager path (unchanged):
  │     │         NotchWindowController.start() calls startPowerMonitor/startNowPlayingMonitor/
  │     │         startBluetoothMonitor/startOutfitRefresh unconditionally (today's behavior)
  │     │
  │     └─ YES → NEW: read UserDefaults "onboarding.completed"
  │               │
  │               ├─ already true (e.g. debug reset without onboarding reset)
  │               │     → fall through to the NO branch above (no regression)
  │               │
  │               └─ false → NotchWindowController.start() SKIPS startBluetoothMonitor +
  │                           the two permission-triggering calls inside startOutfitRefresh
  │                           (location + calendar), but STILL starts power/now-playing
  │                           monitors (D-01 only gates Bluetooth/Location/Calendar) —
  │                           renderPresentation() resolves to .onboarding(.welcome) because
  │                           the new resolver branch checks the flag FIRST
  │
  ▼
IslandResolver.resolve(...)                         [PURE — IslandResolver.swift]
  │  NEW: if !onboardingCompleted { return .onboarding(currentStep) }   ← checked BEFORE
  │        activeTransient, so onboarding wins over charging/device/media unconditionally
  │        for the whole forced-flow session (D-09: no early exit)
  ▼
NotchPillView.body switch(presentation)             [VIEW — NotchPillView.swift]
  │  NEW: case .onboarding(let step): onboardingCarousel(step)
  │        renders via the EXISTING blobShape(topCornerRadius:bottomCornerRadius:shelfItems: [])
  │        helper (same shape/material/matchedGeometryEffect every other expanded case uses)
  ▼
   ┌─────────────────────┬──────────────────────────┬───────────────────────┐
   │ .welcome             │ .trialLicenseBuy          │ .permissions           │ .done
   │ Next only            │ Next / Enter Key / Buy    │ 3 independent Grant    │ Launch-at-Login
   │                       │  "Enter Key"/"Buy" open   │  rows, each fires ONE  │  toggle + Finish
   │                       │  Settings via existing    │  system prompt via     │
   │                       │  .openIsletSettings       │  BluetoothMonitor/     │
   │                       │  bridge (License section  │  LocationProvider/     │
   │                       │  already first-shown)     │  EventKitService       │
   └───────────┬───────────┴──────────────┬────────────┴───────────┬───────────┘
               │                          │                        │
               ▼                          ▼                        ▼
     Settings Window (focusable)   direct system TCC prompt   UserDefaults.set(true,
     SettingsView.swift's          (no Settings hop needed)   forKey: "onboarding.completed")
     existing License section                                 on reaching .done → next
     (General tab, already first)                              renderPresentation() call
     UserDefaults.didChangeNotification fires on license       naturally resolves back to
     activation → existing defaultsObserver/licenseObserver    normal .idle/.expandedIdle/etc,
     idiom resyncs state — onboarding controller listens the   the .onboarding branch is now
     SAME way to auto-advance past the trial/license step      permanently skipped
```

### Recommended Project Structure

No new files are strictly required — every existing file that owns a piece of this flow already
exists and has an established extension point. If the plan wants a dedicated pure-seam file for
the new step-sequencing logic (mirroring `IslandResolver.swift`'s "no AppKit/SwiftUI import" pure
discipline), the natural new file is:

```
Islet/Notch/
├── OnboardingFlow.swift        # NEW (optional) — pure step enum + advance/back reducer,
│                                #   mirroring InteractionPhase/InteractionEvent's shape in
│                                #   NotchInteractionState.swift (import Foundation only)
├── IslandResolver.swift        # MODIFIED — resolve() gains the onboarding-first check;
│                                #   IslandPresentation gains .onboarding(OnboardingStep) case
├── NotchWindowController.swift # MODIFIED — start() gates 3 permission call sites; owns the
│                                #   mutable currentOnboardingStep + advance/back handlers
├── NotchPillView.swift         # MODIFIED — new switch case + onboardingCarousel(step) helper
│                                #   using the existing blobShape() composition pattern
Islet/
├── AppDelegate.swift            # MODIFIED — isFirstLaunch branch no longer calls openSettings()
│                                 #   directly; instead lets NotchWindowController's resolver
│                                 #   render .onboarding (no Settings auto-open per D-08)
├── ActivitySettings.swift (or a small new OnboardingSettings.swift) # NEW KEY:
│                                 #   "onboarding.completed" — same enum-namespace convention
```

### Pattern 1: Single-arbiter presentation extension (the codebase's own established pattern)

**What:** `IslandResolver.resolve()` is a `Foundation`-only pure function that is the SOLE
place presentation precedence is decided (D-05, `IslandResolver.swift` header comment). Every
existing extension to what the island can show (charging, device, now-playing, expanded-idle)
was added as a new `IslandPresentation` case handled inside this one function — never as a
parallel state machine or a second `if`-chain in the view.

**When to use:** Any time the island needs to show something new. This is exactly onboarding's
shape: a new presentation the view renders via `switch presentation`.

**Example (from the real file):**
```swift
// Source: Islet/Notch/IslandResolver.swift lines 34-54 (existing code, read verbatim)
func resolve(activeTransient: ActiveTransient?,
             nowPlaying: NowPlayingPresentation,
             nowPlayingHealthy: Bool,
             hasPlayedSinceLaunch: Bool,
             isExpanded: Bool) -> IslandPresentation {
    switch activeTransient {                              // D-04: transient wins even over expanded
    case .charging(let a): return .charging(a)           // D-02 rank 1
    case .device(let d):   return .device(d)             // D-02 rank 2
    case nil: break
    }
    if isExpanded {
        if !nowPlayingHealthy { return .nowPlayingExpanded(nowPlaying, healthy: false) } // D-12
        if nowPlaying != .none { return .nowPlayingExpanded(nowPlaying, healthy: true) }
        return .expandedIdle
    }
    // ...
}
```
**Recommended extension:** add an `onboardingStep: OnboardingStep?` parameter, checked as the
VERY FIRST branch (before `activeTransient`) so a forced-flow onboarding session can never be
interrupted/pre-empted by a charging or device transient — this satisfies D-09's "once started,
always reaches Done" requirement structurally, at the single arbiter, rather than as a
special-cased guard scattered through the controller.

### Pattern 2: `blobShape()` — the shared expanded-content composition helper

**What:** Every "downward expanded" case (`expandedIsland`, `mediaExpanded`, `mediaUnavailable`)
renders through one private helper that owns the `NotchShape` fill, `matchedGeometryEffect`,
frame sizing, and the shelf-row appendage. `NotchPillView.swift` lines 286-311.

**When to use:** The onboarding carousel is visually and architecturally identical in kind to
these three cases (a black rounded blob grown downward from the collapsed pill) — it should call
`blobShape(topCornerRadius:bottomCornerRadius:shelfItems: [])` (always empty shelf items — the
shelf never shows during onboarding) rather than inventing a second shape/fill/morph mechanism.
This is the direct implementation of D-06's "renders inside the real expanded notch panel...
matching Droppy's reference" requirement.

**Example:**
```swift
// Source: Islet/Notch/NotchPillView.swift lines 251-266 (existing code, read verbatim)
private var expandedIsland: some View {
    blobShape(topCornerRadius: 6, bottomCornerRadius: 32, shelfItems: shelfViewState.items) {
        HStack(spacing: 0) { /* ...content... */ }
            .padding(.horizontal, 16)
    }
}
```

### Pattern 3: `syncClickThrough()` — the CR-01 single-decision-point (READ THIS BEFORE WRITING ANY CODE)

**What:** `NotchWindowController.swift` lines 903-917 is the ONE place `panel.ignoresMouseEvents`
is decided. While `interaction.isExpanded`, interactivity is granted ONLY by
`visibleContentZone()?.contains(lastPointerLocation)` — never OR'd with the broader
`pointerInZone` (which tracks the padded panel union, including the invisible reserved shelf
band). The project's own carried-forward lesson (`cr01-clickthrough-or-defeat-gotcha`) is that
OR-ing `pointerInZone` back in here silently reintroduces the empty-shelf click-swallowing
regression.

**Why this matters for onboarding:** for Next/Back/Grant buttons to be clickable, the panel must
be interactive (`ignoresMouseEvents = false`) for the ENTIRE duration the onboarding carousel is
shown — not just while the pointer sits in a narrow hot-zone, since the user will be reading text
and moving the pointer around the whole expanded card. Two concrete, code-grounded options:

1. **Force `interaction.phase = .expanded` for the whole onboarding session** (set once when
   onboarding starts, never toggled back to `.collapsed`/`.hovering` until `.done`). Then
   `syncClickThrough()`'s EXISTING `interaction.isExpanded` branch already does the right thing
   with ZERO changes to `syncClickThrough()` itself — `visibleContentZone()` already computes the
   correct visible-blob rect from `expandedSize`/shelf state, and since onboarding never shows
   shelf items, `visibleContentZone()` narrows correctly to the onboarding card's own bounds
   automatically (it derives from `expandedNotchFrame(collapsed:expandedSize:)`, not from the
   presentation enum). **This is the recommended approach — no `syncClickThrough()` diff needed.**
2. (Not recommended) Add a new `isOnboardingActive` flag ORed into the branch condition inside
   `syncClickThrough()`. Rejected: this duplicates the exact shape of the CR-01 regression this
   codebase already fixed once — the branch SELECTOR may check a new flag, but the interactive
   VALUE itself must stay pure `visibleContentZone()`-derived, and option 1 achieves that for
   free by reusing the existing `.isExpanded` machinery instead of parallel-tracking a second one.

**Secondary consequence of option 1:** the existing grace-collapse timer
(`handleHoverExit`'s `graceWorkItem`, lines 921-960) must be prevented from collapsing the island
mid-onboarding when the pointer momentarily leaves the hot-zone. The codebase already has a
precedent for exactly this kind of "pin open, ignore the grace timer" gate:
`isDraggingShelfItem` (line 216, checked at line 930 inside the grace `DispatchWorkItem`:
`guard !self.isDraggingShelfItem else { return }`). Add a parallel
`guard !self.isOnboardingActive else { return }` at the same call site.

### Pattern 4: Panel sizing — the union-of-frames convention (relevant if onboarding needs more than 360×144)

**What:** `positionAndShow()` (`NotchWindowController.swift` lines 650-720) sizes the ONE AppKit
panel ONCE, to the union of `expandedNotchFrame(...)` and `wingsFrame(...)` — chosen specifically
so no runtime panel resize ever races the SwiftUI morph (CHG-01/Pattern 4 comment, lines 685-688).
`NotchPillView.expandedSize` (`360×144`) is the single source of truth both the panel frame and
the SwiftUI content frame read.

**Recommendation:** If the onboarding carousel's content (hero text + Next button, or 3
permission rows + per-row Grant buttons, or the Done screen's Launch-at-Login toggle) does not
comfortably fit in the existing 144pt height, add a THIRD constant
(`NotchPillView.onboardingSize`) and extend the `panelFrame` union at
`NotchWindowController.swift` line 690 (`let panelFrame = expandedFrame.union(wings)` →
`.union(onboardingFrame)`), mirroring exactly how `wingsFrame` was added as a second union member
in Phase 3. Do NOT attempt a live panel resize mid-flow — every prior phase's own comments
explicitly warn against this ("resizing mid-activity would race the morph and hot-zone math").
Whether 360×144 is sufficient for a 3-row permissions screen with individual Grant buttons is a
concrete on-device layout question the plan/execution should resolve early (Task 1-equivalent
spike), not assume.

### Anti-Patterns to Avoid

- **A parallel onboarding state machine outside `IslandResolver`/`resolve()`:** the codebase's
  own carried-forward architecture-risk note (`Established Patterns` in CONTEXT.md, echoing
  Phase 22/24's drag-state discussion) explicitly warns against this. Route onboarding through
  the existing single arbiter.
- **ORing a new flag into `syncClickThrough()`'s interactive VALUE** (as opposed to its branch
  selector) — this is the exact CR-01 regression shape. See Pattern 3 above.
- **A brand-new AppKit↔SwiftUI notification for "Settings closed, resume onboarding"** — no such
  hook exists today (`grep` for `willCloseNotification`/`windowShouldClose` returns zero matches
  in `Islet/`), and building one is unnecessary: the existing `UserDefaults.didChangeNotification`
  resync idiom already fires on every relevant state change (license activation writes
  `"license.activationNudge"` to UserDefaults specifically to trigger this exact bus — see
  `SettingsView.swift` lines 217-218). Reuse it.
- **Re-deriving `startOutfitRefresh()`'s bundled location+calendar call as a single atomic gate**
  — D-02 requires INDEPENDENT per-permission Grant buttons. `startOutfitRefresh()` currently
  calls both `locationProvider.requestOnce()` and `refreshCalendar()` together
  (`NotchWindowController.swift` lines 494 and 498) — this function needs splitting so the
  onboarding Permissions screen can trigger each independently, exactly like `startBluetoothMonitor()`
  already is independently callable.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| License key entry/validation/checkout | A new onboarding-only text field + Polar.sh call | Existing `SettingsView.swift` `licenseEntry`/`activate()`/`PolarLicenseService` (D-05, LOCKED) | Zero new validation logic; idle/validating/success/failure states, retry-on-unreachable, and the Buy Now URL are all already correct and tested (`LicenseServiceTests.swift`, `PolarLicenseServiceTests.swift`) |
| Bluetooth/Calendar/Location permission requests | Custom `IOBluetoothDevice`/`CLLocationManager`/`EKEventStore` calls inside the onboarding view | `BluetoothMonitor.start()`, `LocationProvider.requestOnce()`, `EventKitService.fetchUpcoming()` | These are already the project's thin, silent-degrade-on-denial wrappers (D-01 pattern); calling the raw frameworks a second time from a new file would duplicate authorization-state handling and risk double-registering (`BluetoothMonitor` isn't idempotent against concurrent registration) |
| "Onboarding shown once" persistence | A new Keychain-backed store (mirroring `TrialManager`) | Plain `UserDefaults`/`@AppStorage` boolean, mirroring `ActivitySettings`'s key-namespace convention | CONTEXT.md's own reasoning: onboarding isn't a security/anti-tampering gate — Keychain's extra complexity (delete-then-add upsert, `earliest-of-two` reconciliation) solves a problem onboarding doesn't have |
| Launch-at-Login toggle logic | A second wrapper around `SMAppService.mainApp` | `LaunchAtLogin.swift` (`isEnabled`/`set(_:)`/`requiresApproval`/`openLoginItemsSettings()`) | Already handles the `.requiresApproval` deep-link edge case (Settings' own toggle at `SettingsView.swift` lines 67-86 is the exact behavior D-10 asks to mirror) |

**Key insight:** this phase's entire scope is new UI sequencing and gating around existing,
already-correct business logic. Every "hard part" (license validation, permission requests,
trial timing, login-item registration) is already solved elsewhere in the codebase — the risk
in this phase is 100% in the notch-hosted presentation/state-machine wiring, not in any new
domain logic.

## Common Pitfalls

### Pitfall 1: `syncClickThrough()` OR-defeat regression (CR-01, already happened once)
**What goes wrong:** Onboarding's Next/Back/Grant buttons become unclickable, or (worse) clicks
meant for the app underneath the notch get silently swallowed by an invisible reserved band.
**Why it happens:** Widening the click-through interactive check to accommodate a new
presentation state by ORing a broad flag (`pointerInZone`, or a new `isOnboardingActive`) directly
into the interactive boolean, instead of keeping the interactive VALUE derived purely from
`visibleContentZone()`.
**How to avoid:** Force `interaction.phase = .expanded` for the onboarding session (Pattern 3,
option 1) so the EXISTING `visibleContentZone()`-only branch handles it with no new code path.
**Warning signs:** A grep for `pointerInZone` appearing inside the `if interaction.isExpanded`
branch of `syncClickThrough()` — that shape is the regression signature.

### Pitfall 2: Permission gating breaks the "later launches stay eager" invariant (D-01)
**What goes wrong:** A returning user (onboarding already complete) suddenly sees a permission
prompt delay or a missing Bluetooth/Location/Calendar feature at launch.
**Why it happens:** The new `"onboarding.completed"` gate is checked in the wrong place, or is
never SET to true, or is read with the wrong default (should default to `false` only for a
GENUINELY fresh install — an existing user upgrading to this version must not be treated as
"not yet onboarded").
**How to avoid:** The gate must default such that any user with an EXISTING trial/license state
(i.e., `TrialManager.trialStartDate() != nil` before this phase ships) is treated as already
onboarded on their first launch of the new version — otherwise every existing user gets forced
through the flow. Concretely: seed `"onboarding.completed" = true` at the same call site as
`recordFirstLaunchIfNeeded()` returning `false` (i.e., NOT a genuinely fresh install), or check
`TrialManager.trialStartDate()` directly as an additional OR-condition. This is a real migration
edge case CONTEXT.md does not explicitly address — flag as an Open Question below.
**Warning signs:** An existing beta tester relaunching post-upgrade suddenly sees the onboarding
carousel.

### Pitfall 3: Settings' License section is NOT scrolled/highlighted for onboarding context
**What goes wrong:** User taps "Enter License Key" during onboarding, Settings opens, but lands
on a generic License section indistinguishable from the normal Settings entry point — mildly
confusing but not broken (License is already the FIRST section of the FIRST tab, so this is a
minor polish gap, not a blocker).
**Why it happens:** `openSettings()`/the `.openIsletSettings` notification carries no payload —
there's no way to say "and scroll to/focus the key field" today.
**How to avoid:** Given License is already first-shown by default, this is likely acceptable
as-is for v1 of this phase (confirmed: `SettingsView.swift` line 41 `TabView` — General tab is
first, License section is `Form`'s first `Section` at line 48). If sharper focus (auto-focusing
the `TextField`) is wanted, that requires a `@FocusState` binding threaded through a NEW payload
on the notification — out of scope unless explicitly requested.

### Pitfall 4: No existing "permission re-grant" trigger in Settings (CONTEXT.md's own flagged gap)
**What goes wrong:** A user skips a permission during onboarding, later opens Settings hoping to
grant it, and finds nothing — `SettingsView.swift` has ZERO permission-status rows or re-request
buttons today (confirmed by grep — only License/LaunchAtLogin/Diagnostics/Version/
Appearance/Activities sections exist).
**Why it happens:** D-07 says a skipped permission "later wants to grant... both route through
Settings" but no Settings UI currently exposes a way to re-trigger
`BluetoothMonitor.start()`/`LocationProvider.requestOnce()`/`EventKitService.fetchUpcoming()`
on demand from Settings.
**How to avoid:** This is a genuine open question, not a research-resolvable fact — CONTEXT.md
marks it "Claude's Discretion... likely nothing needed" but that reasoning ("Settings' existing
permission-status display, if any, already reflects live system state") is WRONG per this
research: no such display exists. Planner must either (a) explicitly descope re-grant UI for this
phase (the user can always use System Settings → Privacy directly, which is the standard macOS
mechanism regardless of what Islet does), or (b) add a minimal Settings row per permission. See
Open Questions.
**Warning signs:** A plan task that assumes a "Grant" button already exists somewhere in Settings.

## Runtime State Inventory

Not applicable — this is a net-new feature phase (no rename/refactor/migration of existing
identifiers, data, or registered state). Skipped per the trigger condition in this template.

## Code Examples

### Exact D-01 gate call sites (verified line numbers, `NotchWindowController.swift`)
```swift
// Source: Islet/Notch/NotchWindowController.swift lines 380-397 (existing code, read verbatim)
if activityEnabled(ActivitySettings.chargingKey) { startPowerMonitor() }
if activityEnabled(ActivitySettings.nowPlayingKey) { startNowPlayingMonitor() }
if activityEnabled(ActivitySettings.deviceKey) { startBluetoothMonitor() }   // ← gate this (Bluetooth)
startOutfitRefresh()                                                         // ← gate this (Location + Calendar)
```
```swift
// Source: Islet/Notch/NotchWindowController.swift lines 492-505 (existing code, read verbatim)
// startOutfitRefresh() bundles BOTH location and calendar — D-02 needs these SEPARATELY
// callable for independent per-row Grant buttons. Recommend splitting this function.
private func startOutfitRefresh() {
    guard outfitRefreshTimer == nil else { return }
    locationProvider.requestOnce { [weak self] location in            // ← Location permission trigger
        self?.lastLocation = location
        self?.refreshWeather()
    }
    refreshCalendar()                                                  // ← Calendar permission trigger
    outfitRefreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { ... }
}
```

### Exact permission-triggering internals (for the plan to reference precisely)
```swift
// Source: Islet/Notch/BluetoothMonitor.swift line 55 (Bluetooth — fires TCC prompt on first call)
func start() {
    connectToken = IOBluetoothDevice.register(forConnectNotifications: self, selector: ...)
}
```
```swift
// Source: Islet/Location/LocationProvider.swift lines 25-39 (Location — fires TCC prompt on first call)
func requestOnce(completion: @escaping (CLLocation?) -> Void) {
    self.completion = completion
    manager.delegate = self
    switch manager.authorizationStatus {
    case .notDetermined:
        manager.requestWhenInUseAuthorization()   // ← the actual system prompt
    case .authorizedAlways, .authorized:
        manager.requestLocation()
    default:
        completion(nil)   // D-01/D-03 silent degrade — mirror this for onboarding row state
    }
}
```
```swift
// Source: Islet/Calendar/CalendarService.swift lines 25-32 (Calendar — fires TCC prompt on first call)
func fetchUpcoming(completion: @escaping (CalendarGlance?) -> Void) {
    Task {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false   // ← the actual system prompt
        guard granted else {
            await MainActor.run { completion(nil) }   // D-03 silent degrade
            return
        }
        // ...
    }
}
```

### Exact D-05 reuse targets (for the plan to reference precisely)
```swift
// Source: Islet/SettingsView.swift lines 173-180 (existing code, read verbatim) — REUSE AS-IS
@ViewBuilder private var licenseEntry: some View {
    TextField("Enter your license key", text: $enteredKey)
        .frame(maxWidth: .infinity)
    Button("Activate") { activate() }
        .disabled(activationPhase == .validating
                  || enteredKey.trimmingCharacters(in: .whitespaces).isEmpty)
    statusLine
}
```
`buyNowButton` (lines 164-168) opens `https://lippi304.xyz/projects/islet/buy` via
`NSWorkspace.shared.open`. `activate()` (lines 205-232) drives the idle/validating/success/failure
state machine and, on success, sets `LicenseState.shared.sessionActivated = true` +
`LicenseManager.shared.recordValidation(...)` + writes the `"license.activationNudge"`
UserDefaults key that fires the resync bus every observer already listens to.

### Exact D-10 reuse target
```swift
// Source: Islet/SettingsView.swift line 6 + lines 67-86 (existing code, read verbatim) — MIRROR AS-IS
@State private var launchAtLogin = LaunchAtLogin.isEnabled
// ...
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
```
The onboarding Done screen's toggle should be a near-verbatim copy of this block, bound to its
own local `@State` seeded from `LaunchAtLogin.isEnabled` — same underlying `SMAppService` call,
per D-10's "not a separate/duplicate flag" requirement.

### The `.openIsletSettings` bridge — exact current shape (one-way, no payload)
```swift
// Source: Islet/AppDelegate.swift lines 131-140 (existing code, read verbatim)
@objc private func openSettings() {
    NSApp.activate(ignoringOtherApps: true)
    NotificationCenter.default.post(name: .openIsletSettings, object: nil)
    NSApp.windows.first { $0.identifier?.rawValue == "settings" }?
        .makeKeyAndOrderFront(nil)
}
```
```swift
// Source: Islet/IsletApp.swift lines 32-42 (existing code, read verbatim) — the ONLY listener
private struct OpenSettingsOnNotification: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: .openIsletSettings)) { _ in
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }
    }
}
```
This confirms: no payload, no "which section" parameter, no return signal. Reusable as-is for
D-05/D-07's forward hop (open Settings); the RETURN signal must come from the existing
`UserDefaults.didChangeNotification` resync idiom instead (see Pattern 1 / Anti-Patterns above),
since building a matching reverse notification is unnecessary extra plumbing.

## State of the Art

Not applicable in the traditional "library version drift" sense — this is a pure application of
the codebase's own existing, already-current architecture. No external ecosystem to be stale
against.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | 360×144 (`NotchPillView.expandedSize`) may not be tall/wide enough for a 3-row permissions screen with individual Grant buttons plus Next/Back controls | Pattern 4 | If wrong in the "too small" direction, content clips or requires an on-device sizing spike before the plan can commit to a layout — flagged as a concrete early-task risk, not assumed either way |
| A2 | An existing user (pre-Phase-26 install, already has a `TrialManager.trialStartDate()`) must NOT see the onboarding carousel on their first post-upgrade launch | Pitfall 2 | If the migration/seeding logic is wrong, every existing beta tester is forced through onboarding unexpectedly — a real regression, not just cosmetic |
| A3 | Reusing `UserDefaults.didChangeNotification` (rather than a new dedicated notification) is sufficient to resume the onboarding flow after a Settings round-trip | Anti-Patterns, Pitfall 3 | If the existing observer granularity is too coarse (fires on ANY UserDefaults write, not just the relevant key), the onboarding controller may need to explicitly re-check its own step's completion condition on every fire — a minor extra-work risk, not a correctness risk, since the existing 3 call sites already do exactly this (re-read the authoritative state, not the notification payload) |

## Open Questions

1. **Does the onboarding permissions screen's 3-row layout fit in the existing 360×144
   `expandedSize`, or does it need a larger, dedicated `onboardingSize` panel union member?**
   - What we know: the existing panel-sizing convention (Pattern 4) supports adding a third
     union member cleanly, following the exact precedent `wingsSize` set.
   - What's unclear: the actual pixel layout of 3 permission rows + independent Grant buttons +
     bottom-corner Next/Back — this is a visual/layout question, not an architectural one.
   - Recommendation: treat as an early on-device layout spike/task in the plan, not an assumption
     baked into Task 1. Reference `.planning/research/inspiration/notes.md` for Droppy's exact
     visual proportions if available.

2. **How should a genuinely-existing user (pre-Phase-26 trial/license state) be prevented from
   seeing onboarding on their first post-upgrade launch?**
   - What we know: `isFirstLaunch` (from `TrialManager.recordFirstLaunchIfNeeded()`) is FALSE for
     any user who already has a trial start date — so the naive gate
     (`if isFirstLaunch && !onboardingCompleted`) already correctly excludes them, since
     `isFirstLaunch` only returns `true` exactly once, ever, for a given Keychain-backed trial
     record.
   - What's unclear: whether `AppDelegate.applicationDidFinishLaunching`'s existing `isFirstLaunch`
     local (line 29) is the SAME signal the new onboarding gate should key off, or whether a
     SEPARATE `"onboarding.completed"` UserDefaults flag is needed in addition. Given
     `isFirstLaunch` is a one-shot Keychain-derived boolean (not independently re-readable later
     in the process), the plan likely needs BOTH: `isFirstLaunch` decides whether to even consider
     showing onboarding at app-launch time, and a separate persisted `"onboarding.completed"` flag
     is what the resolver checks on every render (so a mid-flow app quit/relaunch resumes
     correctly rather than re-triggering from `isFirstLaunch`, which would already be `false` on
     relaunch).
   - Recommendation: use `isFirstLaunch` (existing) only as the initial trigger to show onboarding
     at all; use a new independent `"onboarding.completed"` UserDefaults flag, defaulted to
     `false`, set `true` only when the Done screen's Finish action fires — this correctly handles
     both "existing user, never sees it" (isFirstLaunch is false) and "mid-flow quit/relaunch"
     (onboarding.completed is still false, resume from wherever `resolve()`'s onboarding-step
     state left off — though NOTE: if step state is only held in-memory in
     `NotchWindowController`, a quit mid-flow restarts from `.welcome`, not the exact step; decide
     if that's acceptable or if the step index itself needs persisting too).

3. **Should skipped-permission re-grant get any Settings UI in this phase, or is it fully
   descoped to "user goes to System Settings → Privacy directly"?**
   - What we know: no Settings UI for this exists today (Pitfall 4).
   - What's unclear: whether D-07's wording ("later granted via Settings") implies Islet's OWN
     Settings window needs a new row, or whether "Settings" there means the SYSTEM's Settings app
     (ambiguous in CONTEXT.md's phrasing).
   - Recommendation: flag for the planner to confirm with the user before committing engineering
     time — building a new Settings permission-status section is a non-trivial scope addition
     (SETTINGS-01's sidebar redesign is explicitly Phase 27, not this phase) that CONTEXT.md's
     "Claude's Discretion" note may not have intended to authorize.

## Project Constraints (from CLAUDE.md)

- Swift 5 language mode preferred over Swift 6 strict concurrency for beginner-friendliness
  (though the build machine's actual toolchain is Tahoe/Xcode 26.6/Swift 6.3.3 per project
  memory `build-machine-macos26-toolchain` — `NotchWindowController` is already `@MainActor`,
  consistent with this).
- SwiftUI for all island UI/animation; AppKit kept to a minimal surface (window shell, status
  item, event monitors) — this phase's onboarding view must stay SwiftUI-only inside
  `NotchPillView.swift`, with any new AppKit touch points (permission framework calls) staying
  inside the already-existing thin wrapper files.
- No Core Animation / hand-rolled `CALayer` — use `matchedGeometryEffect` + spring animations
  (already the established pattern this phase reuses via `blobShape()`).
- No new third-party dependencies without explicit justification — this phase needs none.
- App is unsandboxed, notarized-direct-distribution only (MediaRemote/IOBluetooth constraints) —
  unaffected by this phase's scope.
- GSD workflow discipline (project + global CLAUDE.md): plan must go through
  `/gsd:plan-phase` → user confirmation → `/gsd:execute-phase` → `/gsd:verify-work`, no direct
  edits outside that flow.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (native Xcode test target `IsletTests`) |
| Config file | none — standard Xcode scheme, no `.xctestplan` found |
| Quick run command | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` (build-only gate — see below) |
| Full suite command | Manual `Cmd-U` in Xcode (per project memory `xcodebuild-test-headless-hang`: `xcodebuild test` hangs because tests are hosted inside the full `Islet.app`, which boots the real `NSPanel`/MediaRemote/IOBluetooth stack — route the actual test RUN to Xcode's GUI, use `xcodebuild build` only as the CI-safe gate) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ONBOARD-01 | New `.onboarding` case wins over `.idle`/transients in `resolve()` when the onboarding flag is unset | unit | `IslandResolverTests.swift` — add `testOnboardingOutranksEverything()` mirroring `testChargingOutranksDeviceAndMedia()`'s existing shape | ❌ Wave 0 (extend existing file) |
| ONBOARD-01 | Onboarding step sequencing (welcome → trial/license/buy → permissions → done, Next/Back) | unit | New `OnboardingFlowTests.swift` mirroring `InteractionStateTests.swift`'s pure-reducer-testing shape (if a dedicated `OnboardingFlow.swift` pure seam is added per the Recommended Project Structure) | ❌ Wave 0 |
| ONBOARD-02 | Permission gating: `startBluetoothMonitor`/location/calendar are NOT called when `onboarding.completed == false` at a genuinely fresh launch | unit (pure gate function) or manual-only | Extract the gate as a small pure function (`shouldGatePermissionCallsAtLaunch(isFirstLaunch:onboardingCompleted:) -> Bool`) mirroring `activityEnabled`'s testable shape; test with `VisibilityDecisionTests.swift`-style pure assertions | ❌ Wave 0 |
| ONBOARD-02 | Each permission row fires exactly its own system prompt (Bluetooth/Calendar/Location independently) | manual-only | On-device Cmd-U cannot exercise real TCC prompts (memory: real IOBluetooth/CLLocationManager/EKEventStore calls hang/misbehave outside a real launch) — this is inherently a manual on-device UAT step | N/A — manual |
| ONBOARD-03 | Onboarding flag persists, flow shows exactly once | unit | `UserDefaults`-backed flag — testable with an injected `UserDefaults(suiteName:)` fixture, mirroring `TrialManagerTests.swift`'s fake-store injection pattern | ❌ Wave 0 |
| ONBOARD-03 | No gesture/tutorial screen exists in the flow | manual/code-review | Grep-verifiable: no new view named anything gesture/tutorial-related — a code-review-depth check, not a runtime test | N/A |

### Sampling Rate
- **Per task commit:** `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` (build gate only, per the project's own documented `xcodebuild test` hang workaround)
- **Per wave merge:** full Cmd-U run in Xcode GUI for the pure-logic suites (`IslandResolverTests`, `InteractionStateTests`, any new `OnboardingFlowTests`/gate tests) + a Release-configuration build pass (per project memory `release-library-validation-crash` — Release-only failures have bitten this project before)
- **Phase gate:** on-device manual UAT for all 3 permission prompts + the full carousel flow (skippable-per-step behavior, Settings round-trip for license entry, Done screen's Launch-at-Login toggle) before `/gsd:verify-work` — this phase is unusually manual-UAT-heavy because its core behaviors (real system permission prompts, real window focus handoff, real animation feel) are exactly the categories XCTest cannot exercise, per this project's own established `xcodebuild-test-headless-hang` and `feedback-xcode-gui-not-terminal` memories.

### Wave 0 Gaps
- [ ] `OnboardingFlowTests.swift` — if a dedicated pure `OnboardingFlow.swift` seam is added, needs its own test file from the start (Wave 1, not retrofitted)
- [ ] Extend `IslandResolverTests.swift` with the onboarding-precedence case
- [ ] Extend `TrialManagerTests.swift`-style fixture pattern for the new `"onboarding.completed"` flag if it needs Keychain-style injectable testing (likely NOT needed — plain `UserDefaults` suffices per the Don't-Hand-Roll recommendation)
- [ ] No framework install needed — XCTest is already fully wired

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | This phase has no authentication surface |
| V3 Session Management | No | N/A |
| V4 Access Control | Marginal | The `"onboarding.completed"` flag is a UX gate, not an access-control boundary — a tampered flag at worst re-shows onboarding or skips it, never bypasses licensing (licensing itself is `LicenseState`'s existing, unmodified concern) |
| V5 Input Validation | Yes (inherited, unmodified) | License key entry validation is entirely reused from `SettingsView.swift`/`PolarLicenseService.swift` — already handles untrusted pasted input as an opaque string, never interpolated (existing `T-11-03`/`T-12-02` mitigations, unchanged by this phase) |
| V6 Cryptography | No (inherited, unmodified) | No new crypto surface — Keychain usage stays confined to the existing `TrialManager`, untouched by this phase |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| A tampered `"onboarding.completed"` UserDefaults value forces onboarding to always/never show | Tampering | Low severity by design (CONTEXT.md's own reasoning: not a security gate) — no mitigation needed beyond what already exists; explicitly NOT using Keychain here is the correct proportionate response, not a gap |
| Onboarding carousel accidentally exposes a way to bypass `LicenseState`'s trial/license check (e.g. a "skip" path that sets `sessionActivated = true` without validation) | Elevation of Privilege | The plan must ensure the onboarding flow NEVER writes to `LicenseState.shared.sessionActivated` or any licensing UserDefaults key directly — only the existing, unmodified `activate()` path in `SettingsView.swift` may do so. This is a code-review-depth check, not a new control to build. |
| A malformed/corrupted onboarding step index causes a crash or an infinite Next/Back loop | Denial of Service (minor) | Mirror `ActivitySettings.accent(for:)`'s existing defensive-clamp pattern (line 33-35: any out-of-range index clamps to default) — any new step-index persistence should clamp to a valid enum case rather than force-unwrap |

## Sources

### Primary (HIGH confidence — direct codebase reads, this session)
- `Islet/AppDelegate.swift` — full file read, `isFirstLaunch` branch (lines 77-89), `openSettings()` (131-140)
- `Islet/IsletApp.swift` — full file read, `.openIsletSettings` bridge definition and sole listener
- `Islet/Notch/NotchPanel.swift` — full file read, `canBecomeKey`/`canBecomeMain` hard-lock (lines 35-36)
- `Islet/Notch/NotchWindowController.swift` — read lines 1-720 + 830-1000 (properties, `start()`, `positionAndShow()`, `syncClickThrough()`, `updateVisibility()`, hover handlers)
- `Islet/Notch/NotchInteractionState.swift` — full file read, `InteractionPhase`/`InteractionEvent`/`nextState`
- `Islet/Notch/IslandResolver.swift` — full file read, `IslandPresentation` enum + `resolve()` pure reducer
- `Islet/Notch/NotchPillView.swift` — read lines 1-330 (properties, `body`, `collapsedIsland`, `expandedIsland`, `blobShape()`)
- `Islet/Notch/NotchShape.swift` — full file read
- `Islet/Notch/NotchGeometry.swift` — full file read, `expandedNotchFrame`/`wingsFrame`/`topPinnedFrame`
- `Islet/Licensing/TrialManager.swift` — full file read, Keychain store + `recordFirstLaunchIfNeeded()`
- `Islet/Licensing/LicenseState.swift` — full file read, `LicenseStatus`/`status`/`isEntitled`
- `Islet/Licensing/PolarLicenseService.swift` — partial read (header + `HTTPSession` seam)
- `Islet/SettingsView.swift` — read lines 1-250 (full License section, Launch-at-Login toggle, `activate()`, `licenseEntry`, `statusLine`)
- `Islet/LaunchAtLogin.swift` — full file read
- `Islet/ActivitySettings.swift` — full file read, key-namespace convention
- `Islet/Location/LocationProvider.swift` — full file read
- `Islet/Calendar/CalendarService.swift` — full file read
- `Islet/Notch/BluetoothMonitor.swift` — partial read (`start()` call site, line 55)
- `.planning/phases/26-onboarding-flow/26-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md` — full reads
- `IsletTests/` directory listing — confirmed existing test-file naming/coverage conventions
- `grep` verification: zero matches for `willCloseNotification`/`windowShouldClose`/`windowWillClose` anywhere in `Islet/` — confirms no existing Settings-close hook

### Secondary (MEDIUM confidence)
- Project memory `xcodebuild-test-headless-hang`, `release-library-validation-crash`,
  `feedback-xcode-gui-not-retriveral` (sic, `feedback-xcode-gui-not-terminal`) — referenced for
  the Validation Architecture section's test-execution guidance, consistent with this session's
  own `IsletTests/` directory read.

### Tertiary (LOW confidence)
- None — this phase required no external web research; all findings are direct codebase reads.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no external libraries involved, this is entirely internal architecture reuse
- Architecture: HIGH — every recommended extension point is a direct read of the actual current code, with exact line numbers
- Pitfalls: HIGH — Pitfall 1 (CR-01) is a documented, previously-real regression in this exact codebase (project memory `cr01-clickthrough-or-defeat-gotcha`); Pitfalls 2-4 are logically derived from direct reads of the actual gating/UI code, not speculation

**Research date:** 2026-07-11
**Valid until:** Until the underlying files change — this is internal-codebase research, not
subject to external ecosystem drift. Re-verify exact line numbers if this phase is planned more
than a few commits after this research (Phase 25 already touched `NotchPillView.swift`/
`NotchWindowController.swift` recently, so re-confirm no further drift before planning if time
has passed).
