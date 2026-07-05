# Phase 11: License Settings UI (Stubbed License Service) - Research

**Researched:** 2026-07-05
**Domain:** SwiftUI Settings UI + a protocol-isolated stub service driving an async validation state machine, integrated into an existing single-arbiter macOS menu-bar (LSUIElement) app
**Confidence:** HIGH (this is a spot-check of the real Islet codebase — every integration point below was read directly, not inferred; the one genuinely new decision, the in-memory session-entitlement seam, is reasoned from the existing proven Phase-10 unlock path)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** One adaptive `License` section whose content swaps by `LicenseState.status`:
  - `.trial(daysRemaining:)` → days-remaining line + Buy Now button + license key field/Activate.
  - `.trialExpired` → "3-day trial period expired" message (prominent) + Buy Now + license field/Activate.
  - `.licensed` → "Licensed ✓" confirmation; Buy Now and key field are **hidden**.
- **D-02:** The License section sits at the **top of the Settings `Form`**, above "Launch Islet at login" / Activities / Accent.
- **D-03:** During an active trial, show a **countdown only**: e.g. *"2 days left in your trial."* — replaces the current end-date notice line. Driven by `LicenseState.status → .trial(daysRemaining:)` (already rounds up / clamps min 1).
- **D-04:** Feedback is an **inline status line below the field**: idle (no line) → `⟳ Validating…` → green `✓ License activated` or red `✗ That key wasn't recognized.` Activate button **disabled while validating** (and when the field is empty).
- **D-05:** The fake stub uses a **magic key** (`ISLET-DEMO-OK`): a known test key validates successfully; every other **non-empty** input fails. Empty input triggers no attempt. Magic key is a stub/DEBUG-documented detail, not a shipped credential.
- **D-06:** The fake "validating" state lasts **~1 second** (simulated round-trip) so the transition is visibly observable.
- **D-07:** Buy Now opens placeholder URL **`https://getislet.app`** in the default browser. Button label: **"Buy Islet — €7.99"**. Hidden in `.licensed`.

### Claude's Discretion

- **Successful stub activation flips license state to entitled for the session** (in-memory only; persistence is Phase 12) and reuses **Phase 10's live-unlock path** so a locked island reappears at the next natural UI transition without an app restart. Whether modeled by extending `LicenseState` or by the new `LicenseService` stub feeding into it is a researcher/planner call — but the observable behavior (activate → island unlocks live) is locked.
- **`LicenseService` protocol shape** (async validate(key:) return, error taxonomy, threading) is left to research/planning — must be shaped so Phase 12's real `PolarLicenseService` is a drop-in swap (mirrors the `NowPlayingService` protocol-isolation pattern).
- Exact copy/wording, spacing, spinner styling, and SwiftUI control choices within the D-04 inline-status pattern are Claude's to refine (a UI-SPEC exists — see below).

### Deferred Ideas (OUT OF SCOPE)

- Persisting an activated license across restarts / offline Keychain cache — **Phase 12 (LIC-02)**. Phase 11's stub activation is in-memory for the session only.
- Real Polar.sh checkout URL and online validation — **Phase 12 (LIC-01/LIC-02)**.
- Deep-link auto-fill of the license key (`islet://license?...`) — **v2 (LIC-04)**.
- Last-day nudge notification before lockout — **v2 (TRIAL-04)**.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRIAL-03 | User can see the number of trial days remaining at any time from the Settings window | `LicenseState.shared.status` already exposes `.trial(daysRemaining:)` with round-up/clamp-to-1 (via `TrialLogic.trialStatus`). The days-remaining line in the adaptive License section (D-03) reads it directly — no new computation. Section 5 (Code Examples) shows the exact binding + copy. |
</phase_requirements>

## Summary

This phase is **~90% UI wiring plus one small, well-precedented new subsystem**. The Settings window, the menu-bar one-click path, the trial/day-remaining computation, and the live-unlock plumbing all already exist and are proven — this phase renders them and adds a fake `LicenseService`.

The single genuinely new design decision is **how a successful stub activation makes `LicenseState.isEntitled` return `true` in-memory and triggers the island to re-appear.** Phase 10 already ships the exact live-unlock mechanism: writing to `UserDefaults` fires `UserDefaults.didChangeNotification`, which `NotchWindowController.defaultsObserver` → `handleSettingsChanged()` → `updateVisibility()` (the single arbiter) consumes, re-reading `licenseState.isEntitled` fresh. This is literally how the DEBUG `forceLicensed` override already unlocks the island live. Phase 11 reuses that path: add a real (non-DEBUG) in-memory `sessionActivated` flag to `LicenseState`, and on stub success flip it + fire the same re-evaluation. Because entitlement truth stays an in-memory bool (never a persisted `UserDefaults`/Keychain value this phase), the "in-memory for the session only" constraint is honored automatically and Phase 12's flippable-bool pitfall (Pitfall 3) is dodged.

The `LicenseService` protocol mirrors `NowPlayingService` verbatim: a tiny closure-based protocol with one concrete conformer, so Phase 12's `PolarLicenseService` is a one-file swap. Keep the stub **pure** (key → `Result`, no singleton side effects) so it's trivially unit-testable; do the `LicenseState` flip + re-eval trigger in the caller's completion closure (mirrors how `NowPlayingMonitor` emits and `NotchWindowController` mutates state).

**Primary recommendation:** Add `Islet/Licensing/LicenseService.swift` (protocol + `StubLicenseService` conformer, closure-based, main-thread completion contract) and a real in-memory `sessionActivated` flag on `LicenseState`. Extend `SettingsView` with the adaptive License `Section` driven by a local `@State` copy of `LicenseState.status` (re-read via the existing `.appearsActive` pattern) and a `@State` activation-phase enum. On stub success, set `LicenseState.shared.sessionActivated = true` and fire the existing `UserDefaults.didChangeNotification` unlock path. No new packages, no network, no persistence.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Render days-remaining / adaptive License section | SwiftUI View (`SettingsView`) | Domain (`LicenseState`) | View reads status; domain owns the trial→status computation (already built) |
| Async validation state machine (idle→validating→success/failure) | SwiftUI View (`@State` phase enum) | Service (`LicenseService`) | View owns transient UI phase; service owns the (fake) validation verdict |
| Validate a key | Service (`StubLicenseService`) | — | The swap seam for Phase 12's `PolarLicenseService`; keep it pure |
| Flip entitlement + trigger unlock | App glue (completion closure) → `LicenseState` + `updateVisibility()` | AppKit (`NotchWindowController` arbiter) | Mirrors NowPlayingMonitor-emits / controller-mutates split; the single arbiter owns show/hide |
| Open Settings one-click from menu bar | AppKit (`AppDelegate` + `IsletApp` Window scene) | — | **Already built + proven in Phase 10** — no new work |
| Open Buy Now URL | AppKit (`NSWorkspace.open`) | — | Trivial default-browser handoff |
| Persist entitlement | **None this phase** | — | In-memory only (D — persistence is Phase 12) |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | macOS 14+ SDK (built on Tahoe/macOS 26, Xcode 26.6) | The adaptive License `Section`, `TextField`, `Button`, inline status `Text` | Already the app's UI layer; UI-SPEC maps every control to a native SwiftUI primitive |
| AppKit (`NSWorkspace`) | macOS SDK | `NSWorkspace.shared.open(url)` for Buy Now | First-party default-browser handoff; the documented LSUIElement pattern (Pitfall 6) |
| Foundation (`DispatchQueue.main.asyncAfter`) | macOS SDK | The ~1s simulated round-trip in the stub (D-06) | Matches the codebase's one-shot `DispatchWorkItem`/`asyncAfter` idiom used ~5× in `NotchWindowController` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| XCTest | bundled w/ Xcode 26.6 | Unit-test the stub's key→Result mapping | The `IsletTests` target already exists and runs via `xcodebuild test -scheme Islet` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Closure-based `LicenseService` (`Result` completion) | Swift `async/await` | The Architecture research explicitly recommends **closures**, to match the existing `NowPlayingService`/`PowerSourceMonitor` closure idiom throughout this codebase; also the project runs in **Swift 5 language mode** (CLAUDE.md) to dodge strict-concurrency friction. `async/await` would introduce a second callback style for no benefit here. `[ASSUMED]` — recommended, not user-locked. |
| Local `@State` copy of `LicenseState.status` in the view | Make `LicenseState` an `ObservableObject` w/ `@Published status` | The view-owned re-read via `.appearsActive` matches the **existing** `SettingsView`/`ActivitySettings` non-observable pattern (launch-at-login is already done this way). Converting `LicenseState` to `@Published` is a broader-milestone idea (Architecture doc) but is unnecessary churn for Phase 11 and would touch the read-hot `NotchWindowController` path. `[ASSUMED]` |

**Installation:** No packages to install. All frameworks are system-provided; no `project.yml` dependency change.

## Package Legitimacy Audit

> Not applicable — **this phase installs no external packages.** No SPM dependency, no `project.yml` change. The three existing project dependencies (`mediaremote-adapter`, `DynamicNotchKit`, `Sparkle`) are untouched and unrelated. slopcheck gate: N/A (nothing to check).

## Architecture Patterns

### System Architecture Diagram

```
   User clicks menu-bar icon (NSStatusItem)
          │
          │  licensed/trial → dropdown "Settings…"    locked → single click = openSettings()   [ALL EXISTING — Phase 10]
          ▼
   AppDelegate.openSettings()
     · NSApp.activate(ignoringOtherApps:true)
     · post .openIsletSettings  ──►  IsletApp Window(id:"settings") opens SettingsView
          │
          ▼
 ┌─────────────────────────── SettingsView (EXTENDED) ───────────────────────────┐
 │  @State licenseStatus  ◄── re-read LicenseState.shared.status                  │
 │        (refreshed onAppear + onChange(appearsActive))                          │
 │                                                                                │
 │  adaptive Section(License)  switches on licenseStatus:                         │
 │    .trial(n)      → "n days left…"  + BuyNow + keyField/Activate               │
 │    .trialExpired  → "3-day trial period expired" + BuyNow + keyField/Activate  │
 │    .licensed      → "Licensed ✓"   (BuyNow + field hidden)                     │
 │                                                                                │
 │  @State activationPhase: .idle→.validating→.success/.failure  (D-04 status line)│
 │                                                                                │
 │  BuyNow tap ─────────────► NSWorkspace.open(https://getislet.app)              │
 │  Activate tap (key non-empty) ─┐                                               │
 └────────────────────────────────┼──────────────────────────────────────────────┘
                                   ▼
                     licenseService.activate(key) { result }   [NEW seam]
                                   │  (~1s simulated round-trip, completes on MAIN)
                        ┌──────────┴───────────┐
                    .success                .failure(.invalidKey)
                        │                        │
   LicenseState.shared.sessionActivated = true   └─► activationPhase = .failure
   + fire UserDefaults.didChangeNotification          "✗ That key wasn't recognized."
   + activationPhase = .success / licenseStatus=.licensed
                        │
                        ▼   (EXISTING Phase-10 live-unlock path — no new plumbing)
   AppDelegate.licenseObserver ─► applyMenuBarClickRouting(isLicensed:true)
   NotchWindowController.defaultsObserver ─► handleSettingsChanged() ─► updateVisibility()
                        │
                        ▼
   updateVisibility() re-reads licenseState.isEntitled == true ─► positionAndShow(): island re-appears
```

### Recommended Project Structure
```
Islet/Licensing/
├── LicenseState.swift      # EXISTING — add real in-memory `var sessionActivated` + .licensed short-circuit
├── TrialLogic.swift        # EXISTING — pure days-remaining (untouched)
├── TrialManager.swift      # EXISTING — Keychain glue (untouched)
└── LicenseService.swift    # NEW — protocol + StubLicenseService (mirrors NowPlayingService)

Islet/
└── SettingsView.swift      # EXISTING — add adaptive License Section at top of Form

IsletTests/
└── LicenseServiceTests.swift  # NEW (Wave 0) — stub key→Result mapping
```

### Pattern 1: Protocol-isolated fake service (mirror `NowPlayingService`)
**What:** A tiny closure-based protocol with one concrete conformer; the caller holds the protocol type, not the concrete class.
**When to use:** For the fragile external Phase 12 will replace (Polar.sh HTTP), exactly as `NowPlayingService` quarantines MediaRemote.
**Example:**
```swift
// Islet/Licensing/LicenseService.swift
// Mirrors NowPlayingService (Islet/Notch/NowPlayingMonitor.swift:40-47): the ONE seam
// Phase 12's PolarLicenseService drops into. A future Polar API change is a one-file swap.

enum LicenseActivationError: Error, Equatable {
    case invalidKey            // explicit "key not recognized/revoked" (stub: any non-magic key)
    case unreachable(String)   // transient/network — Phase 12 (Pitfall 2); the stub NEVER emits this,
                               // but the case exists NOW so Phase 12 needs zero protocol changes.
}

protocol LicenseService: AnyObject {
    /// Completion is ALWAYS delivered on the MAIN thread (contract). The stub already runs on
    /// main; Phase 12's URLSession impl MUST hop (URLSession callbacks are background by default —
    /// Architecture Recommendation 6 / Anti-Pattern 4). Callers may mutate @State directly.
    func activate(key: String, completion: @escaping (Result<Void, LicenseActivationError>) -> Void)
}
```
Keep the stub **pure** — no singleton mutation inside it (that's the caller's job, Pattern 2):
```swift
final class StubLicenseService: LicenseService {
    // D-05 magic key. DEBUG-documented scaffold; Phase 12 deletes this whole file. Trimmed before compare.
    static let validKey = "ISLET-DEMO-OK"

    func activate(key: String, completion: @escaping (Result<Void, LicenseActivationError>) -> Void) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {          // D-06 visible ~1s round-trip
            completion(trimmed == Self.validKey ? .success(()) : .failure(.invalidKey))
        }
    }
}
```

### Pattern 2: Service emits, caller mutates state (mirror monitor→controller split)
**What:** The service returns a verdict; the entitlement flip + re-evaluation trigger live in the completion closure at the call site — NOT inside the service.
**When to use:** Keeps the stub trivially testable (no singleton coupling) and matches `NowPlayingMonitor` (emits) / `NotchWindowController` (mutates `@Published`).
**Example:**
```swift
// In SettingsView's Activate button action:
activationPhase = .validating
licenseService.activate(key: enteredKey) { result in            // completes on main (contract)
    switch result {
    case .success:
        LicenseState.shared.sessionActivated = true             // in-memory session entitlement (NEW)
        UserDefaults.standard.set(Date().timeIntervalSince1970,  // fire the EXISTING didChangeNotification
                                  forKey: "license.activationNudge") //   live-unlock path (Pattern 3)
        licenseStatus = .licensed                               // instant local switch to .licensed layout
        activationPhase = .success
    case .failure:
        activationPhase = .failure                              // "✗ That key wasn't recognized."
    }
}
```

### Pattern 3: Reuse the proven Phase-10 live-unlock path
**What:** A `UserDefaults` write fires `UserDefaults.didChangeNotification`, which two existing observers already consume: `AppDelegate.licenseObserver` (re-routes the menu-bar click) and `NotchWindowController.defaultsObserver` → `handleSettingsChanged()` → `updateVisibility()` (the single arbiter re-reads `licenseState.isEntitled` and shows the island).
**When to use:** For the activate→island-unlocks-live behavior. This is the identical mechanism Phase 10's DEBUG `forceLicensed` already uses — no new plumbing, no second show/hide site.
**Note on the nudge key:** the written key is a **trigger only, never read as entitlement truth** — entitlement lives in the in-memory `sessionActivated`. So a leftover `UserDefaults` value does NOT grant entitlement on next launch (honors "in-memory for the session only" and dodges Pitfall 3's flippable-bool). Planner may alternatively add a dedicated `Notification.Name` + two one-line observers if a stray defaults key is undesirable — both are acceptable; the `UserDefaults` nudge reuses proven wiring with zero new observer code.

### `LicenseState` change (real, non-DEBUG session seam)
```swift
final class LicenseState {
    static let shared = LicenseState()
    private init() {}

    var sessionActivated = false   // NEW — in-memory session entitlement (Phase 11). NOT persisted.

    var status: LicenseStatus {
        #if DEBUG
        // ... existing DEBUG override block (forceExpired / forceLicensed) stays FIRST ...
        #endif
        if sessionActivated { return .licensed }   // NEW — wins over trial/expired; skips Keychain read
        // ... existing trial-status computation ...
    }
    // isEntitled unchanged: .licensed → true.
}
```

### Anti-Patterns to Avoid
- **A second show/hide call site for "unlocked".** Do NOT add `panel?.orderFrontRegardless()` or an early-return in the activation closure. The ONLY show/hide site is `updateVisibility()` (enforced across Phases 2/6/8/9). Trigger it via the `didChangeNotification` path; let the arbiter decide. (Architecture Anti-Pattern 1.)
- **Persisting the entitlement to `UserDefaults`/Keychain this phase.** That's Phase 12 and re-introduces the flippable-bool pitfall (Pitfall 3). Keep `sessionActivated` in-memory only.
- **Putting the `LicenseState.shared` flip inside `StubLicenseService`.** Couples the stub to a singleton and makes it hard to unit-test in isolation. Keep the stub pure; flip at the call site (Pattern 2).
- **Blocking / instant validation.** D-06 requires the ~1s validating state to be *observed*. Don't return synchronously.
- **Force-collapsing the island synchronously.** Not relevant to unlock (showing is never abrupt), but note the reverse lock path is already handled by Phase 10's `pendingLockoutHide` — don't touch it.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Making the unlocked island re-appear | A new show/hide call, panel ordering, or interaction re-enable code | The existing `updateVisibility()` arbiter via `didChangeNotification` | Single-arbiter discipline; `hotZone=nil`/`orderOut` already fully disables interaction, and `positionAndShow` re-enables it — hand-rolling races the fullscreen/clamshell observers |
| Days-remaining math | New date/countdown computation | `LicenseState.shared.status → .trial(daysRemaining:)` | Already rounds up + clamps to min 1 (`TrialLogic.trialStatus`), already unit-tested in `TrialLogicTests` |
| Opening the browser from an agent app | Custom `NSTask`/`open` shell-out | `NSWorkspace.shared.open(url)` | The documented LSUIElement default-browser handoff (Pitfall 6) |
| Menu-bar → Settings one-click | Any new window/activation code | The existing `AppDelegate.openSettings()` + `applyMenuBarClickRouting()` + `IsletApp` Window(id:) notification bridge | Fully built and proven in Phase 10; success criterion #4 is already satisfied |
| Async delay | `Timer`/`Thread.sleep` | `DispatchQueue.main.asyncAfter` | Matches the app's one-shot idiom; no recurring timer (idle-CPU discipline) |

**Key insight:** Almost everything this phase "needs" already exists. The only new code is `LicenseService.swift`, one `LicenseState` field, and the `SettingsView` section. Resist re-implementing anything in the "Use Instead" column.

## Common Pitfalls

### Pitfall 1: Entitlement leaks across restarts (violates "in-memory only")
**What goes wrong:** Storing the activated state in `UserDefaults`/Keychain so the app is still "licensed" after quit — that's Phase 12's job and creates the flippable-bool bypass (research Pitfall 3).
**Why it happens:** `UserDefaults` is the reflexive place to "remember" a flag, and the unlock trigger itself writes to `UserDefaults`.
**How to avoid:** Entitlement truth is the in-memory `sessionActivated` bool (resets to `false` on every launch). The `UserDefaults` nudge key is a trigger only, **never read as entitlement**. Verify: quit + relaunch after activating → app is back in trial/expired state.
**Warning signs:** Any code that reads a `UserDefaults`/Keychain key to decide `isEntitled`; `status` returning `.licensed` on a fresh launch without a DEBUG override.

### Pitfall 2: Completion handler assumed off-main / or on-main incorrectly for Phase 12
**What goes wrong:** The stub happens to complete on main (via `asyncAfter`), so the view mutates `@State` safely. Phase 12's `URLSession` callback is background by default — copying the stub's "no hop needed" assumption crashes when touching UI (Architecture Anti-Pattern 4).
**Why it happens:** The `NowPlayingService` comment says "no second main-hop" (its wrapper already hops); a first-timer over-generalizes that.
**How to avoid:** Bake the **main-thread completion contract** into the `LicenseService` protocol doc comment NOW (shown in Pattern 1). Then Phase 12 adds the `DispatchQueue.main.async` hop inside `PolarLicenseService` and the view code never changes.
**Warning signs:** No documented threading contract on the protocol; view mutating `@State` from a service that doesn't promise main.

### Pitfall 3: Magic key reachable in a shipped build
**What goes wrong:** `ISLET-DEMO-OK` unlocks the app for free if `StubLicenseService` reaches a public release.
**Why it happens:** The stub ships in the Phase 11 build (it IS the only LicenseService until Phase 12).
**How to avoid:** Phase 12 **replaces** `StubLicenseService` with `PolarLicenseService` before Phase 13 (distribution), so the magic key never reaches a notarized public build. Optionally `#if DEBUG`-gate the magic-key comparison as belt-and-suspenders (mirrors Phase 10's Pitfall-4 DEBUG-gating discipline). Phase 11 is not a public release, so this is a note, not a blocker.
**Warning signs:** A public/notarized build (Phase 13) still importing `StubLicenseService`.

### Pitfall 4: Stale License section content while Settings stays open
**What goes wrong:** Days-remaining or the activated state doesn't refresh because `LicenseState` isn't observable and the view cached a stale `status`.
**Why it happens:** `LicenseState.status` is a plain computed property, not `@Published`.
**How to avoid:** Re-read into the `@State licenseStatus` on `.onAppear` and `.onChange(of: appearsActive)` (the exact pattern `SettingsView` already uses for `launchAtLogin`), and set `licenseStatus = .licensed` directly on activation success for instant feedback.
**Warning signs:** License section never updating on window refocus; activation success not switching to the `.licensed` layout.

## Code Examples

### Days-remaining + adaptive section (TRIAL-03, D-01/D-03)
```swift
// At top of SettingsView.body's Form (D-02), before the Launch-at-login toggle:
Section("License") {
    switch licenseStatus {                                   // @State, re-read from LicenseState.shared.status
    case .trial(let days):
        Text(days == 1 ? "1 day left in your trial."
                       : "\(days) days left in your trial.") // D-03 copy, singular/plural
            .foregroundStyle(.secondary)
        buyNowButton
        licenseEntry
    case .trialExpired:
        Text("3-day trial period expired")                   // D-01 prominent CTA when locked
            .font(.headline)
        buyNowButton
        licenseEntry
    case .licensed:
        Text("Licensed ✓")                                   // Buy Now + field hidden (D-01)
    }
}
```

### Inline validation status line (D-04)
```swift
@ViewBuilder private var statusLine: some View {
    switch activationPhase {
    case .idle:       EmptyView()                                              // no line (D-04)
    case .validating: Text("⟳ Validating…").foregroundStyle(.secondary)       // neutral (D-06 ~1s)
    case .success:    Text("✓ License activated").foregroundStyle(.green)
    case .failure:    Text("✗ That key wasn't recognized.").foregroundStyle(.red)
    }
}
// Activate button:
Button("Activate") { activate() }
    .disabled(activationPhase == .validating ||
              enteredKey.trimmingCharacters(in: .whitespaces).isEmpty)         // D-04/D-05 empty inert
```

### Buy Now (D-07, LIC-01 placeholder)
```swift
private var buyNowButton: some View {
    Button("Buy Islet — €7.99") {
        if let url = URL(string: "https://getislet.app") {   // placeholder; real Polar URL = Phase 12
            NSWorkspace.shared.open(url)
        }
    }
}
```

### Menu-bar one-click (success criterion #4 — ALREADY BUILT, verify only)
```swift
// AppDelegate.applyMenuBarClickRouting(isLicensed:) — EXISTING:
//   locked  → statusItem.menu = nil; button.action = openSettings   (single click opens Settings)
//   licensed/trial → statusItem.menu = menu ("Settings…" item)
// AppDelegate.openSettings() — EXISTING: activate app + post .openIsletSettings + makeKeyAndOrderFront.
// No change required in Phase 11.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| End-date notice line (*"Your 3-day trial started — ends …"*) in `SettingsView` | Countdown line (*"n days left in your trial."*) inside the adaptive License section | This phase (D-03) | The existing `if let start = TrialManager.shared.trialStartDate()` block at `SettingsView.swift:23-28` is **replaced** by the License section — remove it, don't leave both |

**Deprecated/outdated:** none introduced. No framework version changes.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Closure-based `Result` completion (not async/await) is the right protocol shape | Standard Stack / Pattern 1 | Low — Architecture research explicitly recommends it; if planner prefers async/await the seam still works, just a different callback style |
| A2 | View-owned `@State` re-read (not making `LicenseState` `@Published`) is sufficient | Standard Stack / Pitfall 4 | Low — matches existing `SettingsView` pattern; if refresh proves flaky on-device, promoting `LicenseState` to `ObservableObject` is a contained follow-up |
| A3 | The `UserDefaults` nudge-key trigger is acceptable (vs a dedicated `Notification.Name`) | Pattern 3 | Low — reuses proven Phase-10 wiring; planner may swap to a custom notification with two one-line observers. Either satisfies the locked "activate → island unlocks live" behavior |
| A4 | `ISLET-DEMO-OK` as the literal magic key | Pattern 1 / D-05 | None — CONTEXT calls it a naming suggestion; planner may pick any literal |

## Open Questions

1. **Should the magic-key comparison be `#if DEBUG`-gated in Phase 11?**
   - What we know: Phase 11 is not a public release; Phase 12 replaces the stub before Phase 13 (distribution).
   - What's unclear: whether the on-device tester wants `ISLET-DEMO-OK` to work in the DEBUG build they run (yes — they need it to exercise success/failure per D-05) while being inert in a hypothetical Release.
   - Recommendation: keep the comparison active in DEBUG (needed for on-device testing); note that the entire `StubLicenseService` is deleted in Phase 12, so no Release exposure survives to Phase 13. A `#if DEBUG` guard is optional belt-and-suspenders.

2. **Where is `LicenseService` instantiated / injected into `SettingsView`?**
   - What we know: the stub is stateless; `SettingsView` is created in `IsletApp`'s Window scene with no current dependencies.
   - Recommendation: `SettingsView` owns `private let licenseService: LicenseService = StubLicenseService()` (default-injected so Phase 12 swaps the default, or the planner threads it from `IsletApp`). Keep it simple — no DI framework.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / `xcodebuild` | Build + test | ✓ | 26.6 (build machine, per MEMORY) | — |
| XCTest / `IsletTests` target | Stub unit test | ✓ | bundled | — |
| Network / Polar.sh | — | N/A | — | Not used this phase (stub only) |

**Missing dependencies with no fallback:** none — Phase 11 is code-only, no external services.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (bundled with Xcode 26.6) |
| Config file | `project.yml` (`IsletTests` target; `xcodegen generate` → `.xcodeproj`) |
| Quick run command | `xcodebuild test -scheme Islet -only-testing:IsletTests/LicenseServiceTests` |
| Full suite command | `xcodebuild test -scheme Islet` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRIAL-03 | `LicenseState.status → .trial(daysRemaining:)` produces correct clamped day count | unit (already covered) | `xcodebuild test -scheme Islet -only-testing:IsletTests/TrialLogicTests` | ✅ existing |
| TRIAL-03 | Days-remaining line renders from `licenseStatus` (SwiftUI glue) | build | `xcodebuild build -scheme Islet` | ✅ N/A (view glue, no unit target) |
| D-05 | `StubLicenseService.activate("ISLET-DEMO-OK")` → `.success`; any other non-empty key → `.failure(.invalidKey)`; trims whitespace | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/LicenseServiceTests` | ❌ Wave 0 |
| D-06 | Completion is delivered asynchronously (~1s), on the main thread | unit (XCTestExpectation + `Thread.isMainThread`) | `xcodebuild test -scheme Islet -only-testing:IsletTests/LicenseServiceTests` | ❌ Wave 0 |
| D-04 / Discretion | Activate → validating → success flips `LicenseState.sessionActivated`, island unlocks live via `updateVisibility()` | manual (on-device) | — | ✅ N/A (interaction/visibility timing, mirrors Phase 10 manual precedent) |
| D-01 | Adaptive section swaps layout across `.trial`/`.trialExpired`/`.licensed` (use DEBUG stub-flips + magic key) | manual (on-device) | — | ✅ N/A |
| D-07 | Buy Now opens `https://getislet.app` in default browser | manual | — | ✅ N/A |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Islet -only-testing:IsletTests/LicenseServiceTests` (service tasks) or `xcodebuild build -scheme Islet` (SwiftUI glue tasks with no unit target)
- **Per wave merge:** `xcodebuild test -scheme Islet` (full suite)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `IsletTests/LicenseServiceTests.swift` — covers D-05 (key→Result mapping) + D-06 (async, main-thread), mirrors `IsletTests/PowerActivityTests.swift`/`TrialManagerTests.swift` style. Use `XCTestExpectation` for the async completion.
- [ ] Framework install: none — `IsletTests` + `xcodebuild test -scheme Islet` already wired (`project.yml` lines 66-99).

*Note on testing the `sessionActivated → .licensed` mapping:* `LicenseState` is a singleton with `private init()`, so a fresh instance can't be created in a test without relaxing `init()` to internal (or adding a `#if DEBUG` reset). Since the observable payoff (activate → island unlocks) is inherently an on-device visibility/timing behavior — mirroring Phase 10's manual `10-02-02` stub-flip verification — the recommendation is: **unit-test the pure stub (`LicenseServiceTests`), verify the state flip + live unlock manually on-device.** If the planner wants a unit test for the `.licensed` short-circuit, relaxing `LicenseState.init()` to internal is the minimal seam.

## Security Domain

> `security_enforcement` is not disabled in config — treated as enabled. Phase 11 is a **stub, no-network, no-persistence** phase, so most categories are N/A this phase and land in Phase 12.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth; the "key" is a local string compare against a magic value |
| V3 Session Management | no | No sessions/tokens |
| V4 Access Control | partial | Entitlement gate is `LicenseState.isEntitled` via the single arbiter — but this phase's entitlement is in-memory only; real enforcement hardening is Phase 12 |
| V5 Input Validation | yes | Trim the license-key `TextField` input; treat as an opaque untrusted string (no interpolation, no shell/URL injection — it's only `==`-compared). Empty input is inert (D-05) |
| V6 Cryptography | no | No crypto this phase (no key hashing/HMAC — that's Phase 12's Keychain cache integrity, Pitfall 3) |

### Known Threat Patterns for this phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Persisted flippable entitlement bool | Elevation of Privilege | Keep entitlement in-memory (`sessionActivated`); never persist this phase (Pitfall 1 / research Pitfall 3 deferred to Phase 12) |
| Magic key in a shipped build | Elevation of Privilege | Phase 12 replaces `StubLicenseService` before Phase 13 distribution; optional `#if DEBUG` gate (Pitfall 3) |
| Untrusted key string | Tampering | Opaque `==` compare only; trim whitespace; no interpolation into any sink |

## Sources

### Primary (HIGH confidence)
- Direct reads of the actual codebase (verified, not inferred): `Islet/SettingsView.swift`, `Islet/IsletApp.swift`, `Islet/AppDelegate.swift`, `Islet/Notch/NotchWindowController.swift` (full, incl. `handleSettingsChanged()` → `updateVisibility()` at lines 916-956), `Islet/Notch/NowPlayingMonitor.swift` (the `NowPlayingService` protocol precedent), `Islet/Licensing/LicenseState.swift`, `Islet/Licensing/TrialLogic.swift`, `Islet/Licensing/TrialManager.swift`, `IsletTests/TrialManagerTests.swift`, `project.yml`.
- `.planning/phases/11-.../11-CONTEXT.md` (D-01–D-07, discretion, deferred) and `11-UI-SPEC.md` (approved visual/copy contract).
- `.planning/research/ARCHITECTURE.md` — protocol-isolation + single-arbiter recommendations, closure-not-async guidance, main-thread hop warning (Recommendation 6 / Anti-Pattern 4).
- `.planning/research/PITFALLS.md` — Pitfall 3 (flippable bool), Pitfall 5 (mid-session yank), Pitfall 6 (LSUIElement one-click).
- `.planning/phases/10-trial-lockout-gate/10-VALIDATION.md` — the validation-doc format + manual-verification precedent this phase mirrors.

### Secondary (MEDIUM confidence)
- `.planning/REQUIREMENTS.md` — TRIAL-03 text, LIC-01/02/03 scope, €7.99 one-time price, in-app-checkout out-of-scope rows.

### Tertiary (LOW confidence)
- None — no WebSearch was needed; every claim is grounded in the codebase or approved planning docs.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all first-party frameworks already in use; no new packages.
- Architecture: HIGH — the unlock path was verified by reading `handleSettingsChanged()` → `updateVisibility()` directly; it's the same path Phase 10's DEBUG override proves.
- Pitfalls: HIGH — derived from the project's own PITFALLS.md + the observed in-memory-vs-persisted constraint.

**Research date:** 2026-07-05
**Valid until:** ~2026-08-05 (stable — no fast-moving external dependency; the only external, Polar.sh, is not touched until Phase 12)
</content>
</invoke>
