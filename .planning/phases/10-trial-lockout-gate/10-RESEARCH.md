# Phase 10: Trial & Lockout Gate - Research

**Researched:** 2026-07-05
**Domain:** Keychain-backed trial persistence + single-arbiter visibility-gate integration in an existing, shipped native macOS menu-bar app (Swift 5 mode / AppKit / SwiftUI, no new external dependencies)
**Confidence:** HIGH on integration points (verified by reading the actual files this session) and on Keychain/AppKit mechanics (well-documented, stable APIs); MEDIUM on the exact DEBUG-stub wiring shape (a synthesis of locked decisions + milestone research, left partly to planner/executor discretion per CONTEXT.md)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**First-launch trial notice (TRIAL-02)**
- **D-01:** No island-native animated card, no native macOS notification (`UNUserNotificationCenter`) for the trial start. The download/marketing page already says "3-day trial" before download — the in-app moment doesn't need to re-sell that.
- **D-02:** TRIAL-02's "one-time explicit notice" is satisfied by the existing Settings window auto-opening exactly once on first launch, showing a short line like "Your 3-day trial started — ends [date]". Reuses the existing window (`SettingsView.swift`) rather than a new alert/notification/island-transient type.
- **D-03:** This auto-open happens on first launch **regardless** of whether the built-in display is currently the notch target (clamshell/external-only at that moment) — Settings is an ordinary window, not tied to island visibility. Do not add an observer/wait for the island to become visible before showing it.

**Locked-state behavior (LIC-03)**
- **D-04:** When trial expired / no valid stub license, the island itself is fully hidden (no pill, no activities, no expansion) — reuses the exact same hide path as the existing clamshell/fullscreen-hide branch in `updateVisibility()` (`panel?.orderOut(nil)`), not a new visual state.
- **D-05:** Clicking the menu-bar status item while locked jumps straight to Settings (skips the normal "Settings…/Quit Islet" dropdown) — a small, explicit modification to the existing status-item click handler, gated on the same license/trial state Phase 10 introduces.
- **D-06:** The menu-bar icon itself does NOT change appearance (no dimming, no badge) between trial/expired/licensed states. The only signals are: island presence/absence, and what Settings shows when opened.
- **D-07 (user's described end-to-end vision, informs Phase 11 too):** On expiry, opening Settings should show an explicit "3-day trial period expired" message with a link to the website and a field to paste the license key. **Phase 10 itself does not build this content** (TRIAL-03/LIC-01/LIC-02 are Phase 11/12) — it only needs to expose the license/trial state (the shared `LicenseState`/stub) that Phase 11 will read.

**Debug/testing seam (cross-cutting, TRIAL-01/LIC-03)**
- **D-08:** Add a DEBUG-only menu item (or submenu) to force the stub license state — e.g. "Debug: Force Expired" / "Debug: Force Licensed" / "Debug: Reset Trial" — so trial/expired/licensed states can be flipped instantly while running from Xcode. Must not appear/compile into release builds (mirrors the existing `#if DEBUG` discipline already used in `NotchWindowController.swift`, e.g. the A1 hover-probe log).
- **D-09:** Explicitly NOT building a shortened DEBUG trial length — the debug menu item is the sole testing seam; no separate fast-countdown mode.

**Storage mechanism (locked by REQUIREMENTS.md — not re-discussed, flagged for planner awareness)**
- **D-10:** Trial start date persists to the **Keychain** (`kSecClassGenericPassword`), not UserDefaults — locked by TRIAL-01 and matching research `PITFALLS.md` Pitfall 1. Note: `ARCHITECTURE.md` Recommendation 4 (line ~171) argues UserDefaults is acceptable for the trial date specifically ("not a secret, low stakes") — that recommendation is **superseded** by the locked TRIAL-01 requirement and PITFALLS.md's explicit guidance. Follow Keychain for the trial-start timestamp, not ARCHITECTURE.md's Recommendation 4 table on this one specific row.
- **D-11:** The `isLicensed` gate is added as a new AND-term inside `NotchWindowController`'s existing `shouldShow(hasTarget:hideInFullscreen:isFullscreen:)` predicate in `updateVisibility()` — the single arbiter, no second show/hide site. Matches the already-established Pattern 7 discipline in that file.
- **D-12:** Trial expiry is detected via a single one-shot `DispatchWorkItem` scheduled at the exact computed expiry instant (mirrors the file's existing four one-shot-timer idiom: `dismissWorkItem`, `graceWorkItem`, `mediaDismissWorkItem`, `deviceBatteryWork`) — no polling/recurring timer.
- **D-13:** Lockout enforcement defers to the next natural UI transition, never an abrupt mid-interaction yank — already a locked Phase 10 success criterion (research `PITFALLS.md` Pitfall 5).

### Claude's Discretion
- Exact Keychain item attributes (`kSecAttrAccount` naming, `kSecAttrAccessible` level) — research recommends `kSecAttrAccessibleAfterFirstUnlock`; planner/executor can finalize.
- Exact wording of the first-launch Settings notice text and the DEBUG menu item labels/placement.
- Whether the DEBUG menu items live under the existing status-item menu or a separate DEBUG-only menu — implementation detail.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope. The user's described "expired Settings screen with buy link + license field" is not deferred exactly — it's already correctly scoped to Phase 11 per the existing roadmap.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-------------------|
| TRIAL-01 | Trial starts silently on first launch, start date persisted tamper-resistantly (Keychain, survives reinstall) | Keychain API pattern in Code Examples; Pitfall 1 (UserDefaults-only reset attack) with the "earliest-of-two-wins" reconciliation detail; `TrialManager`/`TrialLogic` file split in Architecture Patterns |
| TRIAL-02 | One-time, explicit "3-day trial started" notice on first launch | `AppDelegate`/`SettingsView` integration points; the `hideSettingsWindowOnLaunch()` race flagged in Common Pitfalls; first-launch-flag design in Code Examples |
| LIC-03 | Trial expired + no valid license → island fully locked until valid key entered | `shouldShow(...)` AND-term extension (Architecture Patterns, Recommendation 1 carried from `ARCHITECTURE.md`); `VisibilityDecisionTests.swift` regression impact; `NSStatusItem.menu` vs `button.action` pitfall for D-05; DEBUG-stub design for the manually-settable license state |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Native Swift/SwiftUI/AppKit only — no new cross-platform or web tooling (not relevant here; this phase adds zero UI surface beyond one Settings section and a debug menu).
- Swift 5 **language mode** (not Swift 6 strict concurrency) — `project.yml` already sets `SWIFT_VERSION: "5.0"` for both targets; new files must not introduce actor-isolation complexity beyond the existing `@MainActor`-class idiom already used by `PowerSourceMonitor`/`NowPlayingMonitor`.
- macOS 14.0 deployment target — all Keychain/AppKit APIs used below are available since well before 10.9 / macOS 14, no version gating needed.
- App is **not sandboxed** (`ENABLE_APP_SANDBOX: NO`) — Keychain access needs no keychain-access-group entitlement; a plain `kSecClassGenericPassword` item is sufficient.
- Anti-speculative-complexity stance — no third-party Keychain wrapper library (`KeychainAccess`, etc.), no HMAC/integrity-binding gold-plating for the trial date (that proportionate hardening is scoped to the Phase 12 license *cache*, per `PITFALLS.md` Pitfall 3, not the Phase 10 trial date).
- Only change what needs to change — the `shouldShow(...)` signature change is the one deliberately invasive edit; every other change is additive (new files, new small blocks in existing files).
- Security has precedence — the DEBUG-only stub override must be verifiably inert in a Release build (see Common Pitfalls).

## Summary

Phase 10 adds exactly three small, well-precedented pieces to an app whose architecture already has strong conventions to mirror: (1) a Keychain-backed trial-start timestamp read/written by a new thin glue file (`TrialManager.swift`) wrapping a new pure classification file (`TrialLogic.swift`), following the same pure/glue split already used for `PowerActivity`/`PowerSourceMonitor` and `NowPlayingPresentation`/`NowPlayingMonitor`; (2) a one-time first-launch auto-open of the existing `SettingsView` Settings window showing a short trial-started notice; and (3) a new `isLicensed` AND-term added to the existing `shouldShow(hasTarget:hideInFullscreen:isFullscreen:)` pure predicate in `FullscreenDetector.swift`, consumed by `NotchWindowController.updateVisibility()` — the app's single, already-proven show/hide arbiter (Pattern 7). A new `LicenseState` model (a manually-settable stub for this phase; the real `LicenseService`/Polar.sh wiring is Phase 12) supplies `isEntitled`.

The milestone-level `.planning/research/ARCHITECTURE.md` and `PITFALLS.md` already answer most of the "where does this go" and "what goes wrong" questions in detail (verified against the real codebase in that research pass) — this document does not re-derive those, it (a) locks in the Phase-10-specific slice of that research against the actual current file contents read this session, and (b) surfaces three integration details that milestone research did not cover because they only become visible once you look at the *exact* existing code the phase touches: the `NSStatusItem.menu` vs `button.action` conflict for D-05, the `hideSettingsWindowOnLaunch()` race for D-02/D-03, and the long-duration `DispatchWorkItem`-across-sleep behavior for D-12's 3-day timer.

**Primary recommendation:** Add `TrialLogic.swift` (pure) + `TrialManager.swift` (Keychain glue) + `LicenseState.swift` (stub model) under a new `Islet/Licensing/` group; extend `shouldShow(...)` in `FullscreenDetector.swift` with an `isLicensed: Bool` parameter and update all 6 existing `VisibilityDecisionTests` call sites; wire `NotchWindowController.start()`/`deinit` with one more one-shot `DispatchWorkItem` mirroring the existing four; wire `AppDelegate` for the first-launch Settings auto-open (guarding against the existing `hideSettingsWindowOnLaunch()` race) and the D-05 locked-click behavior (toggling `statusItem.menu` between `nil` and the real menu, since AppKit does not let a click both show a menu and fire a custom action).

## Architectural Responsibility Map

*(Tiers adapted for a native macOS app rather than a web stack — this app has no browser/server/CDN tiers.)*

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Trial-start persistence | Persistence (Keychain via `TrialManager`) | Pure Logic (`TrialLogic`) | Keychain is the tamper-resistant store (D-10); `TrialLogic` is the zero-I/O classification function `TrialManager` wraps |
| First-launch trial notice | SwiftUI View Layer (`SettingsView`) | AppKit Glue (`AppDelegate`) | Reuses the existing Settings window as-is (D-02); `AppDelegate` decides *when* to auto-open it |
| Lockout gate (`isLicensed` AND-term) | Controller/Glue (`NotchWindowController.updateVisibility()`) | Pure Logic (`shouldShow(...)` in `FullscreenDetector.swift`) | The single arbiter already owns all show/hide decisions (Pattern 7); the boolean algebra itself stays in the pure, unit-tested predicate |
| Locked-state menu-bar click routing | AppKit Glue (`AppDelegate` status-item handler) | — | Status-item click handling is entirely `AppDelegate`'s existing responsibility (D-05) |
| DEBUG stub license-state toggle | AppKit Glue (`AppDelegate` DEBUG menu) | Persistence (`LicenseState` / UserDefaults override key) | The debug menu action mutates the same persisted/observed state the gate already reads — no separate plumbing (D-08) |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|---------------|
| `Security` framework (`Security.framework`) | System (macOS 14.0+, unchanged since 10.x) | `SecItemAdd`/`SecItemCopyMatching`/`SecItemUpdate` for the Keychain-backed trial-start timestamp | The only Apple-sanctioned tamper-resistant local persistence API; already the milestone's locked choice (D-10, `PITFALLS.md` Pitfall 1) [CITED: developer.apple.com Security framework — stable, no version concerns] |
| `Foundation` (`UserDefaults`) | System | Mirror/cache copy of the trial date for convenience reads; `UserDefaults.didChangeNotification` as the existing live-update signal the controller already observes | Matches the existing `ActivitySettings`/`defaultsObserver` pattern (`NotchWindowController.swift:302-305`) — zero new plumbing for live state propagation [VERIFIED: read directly from `NotchWindowController.swift` this session] |
| `AppKit` (`NSStatusItem`, `NSMenu`, `NSWindow`) | System | Menu-bar click routing (D-05), first-launch Settings window show/hide | Already the app's only window/menu-bar layer (`AppDelegate.swift`) [VERIFIED: read directly this session] |
| `SwiftUI` | System (macOS 14/15 SDK) | The trial-notice line inside the existing `SettingsView` `Form` | Matches the existing `Section("Activities")` style (`SettingsView.swift:42-64`) [VERIFIED: read directly this session] |
| `XCTest` | System (bundled with Xcode 26.6 on this build machine) | Unit tests for `TrialLogic` and the extended `shouldShow(...)` | Existing test target `IsletTests`, run via `xcodebuild test -scheme Islet` [VERIFIED: `project.yml` + `IsletTests/` directory listing this session] |

### Supporting
None — this phase introduces no new library dependency. `project.yml`'s `packages:` block (currently just `MediaRemoteAdapter`) is unchanged (`ARCHITECTURE.md` Recommendation 2, confirmed: "no new package dependency is required for the license/trial pieces themselves").

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw `Security` framework calls | `KeychainAccess`/`KeychainSwift` (SPM wrapper libraries) | A wrapper trims boilerplate but is unjustified here — the surface area is 2-3 calls (one read, one write, called once per app launch), and CLAUDE.md's anti-speculative-complexity stance + the project's existing zero-third-party-wrapper precedent (IOKit/IOBluetooth used directly, not wrapped) argue against adding a dependency for this |
| `DispatchWorkItem` one-shot expiry timer | A recurring `Timer`/polling loop | Explicitly an anti-pattern per `ARCHITECTURE.md` Anti-Pattern 3 and the codebase's own "idle CPU ~0%" discipline — never use for this phase |

**Installation:**
No installation step — this phase adds only new Swift source files under `Islet/Licensing/` (auto-discovered by `xcodegen generate` per `project.yml`'s `createIntermediateGroups`/source-path convention) plus edits to existing files. No `project.yml` changes needed.

**Version verification:** N/A — no new package/library versions to pin. Confirmed via direct inspection: `project.yml` line 15-17 (packages block unchanged for this phase), `grep` across `Islet/` for `kSecClass|Security` returned zero existing hits (genuinely new subsystem, not extending partial work) [VERIFIED: ran this session].

## Package Legitimacy Audit

**Not applicable to this phase.** No new external packages, SPM dependencies, or registry installs are introduced — every API used (`Security`, `Foundation`, `AppKit`, `SwiftUI`, `XCTest`) is a first-party Apple system framework already linked into the `Islet` target. `slopcheck`/registry verification was not run because there is nothing to verify; this is a deliberate scope note, not a skipped step.

## Architecture Patterns

### System Architecture Diagram

```
App launch
   │
   ▼
AppDelegate.applicationDidFinishLaunching()
   │
   ├─▶ TrialManager.recordFirstLaunchIfNeeded()
   │        │  reads Keychain for existing start-date item
   │        │  ├─ absent → SecItemAdd(now) + mirror to UserDefaults, returns isFirstLaunch=true
   │        │  └─ present → no write, returns isFirstLaunch=false
   │        ▼
   ├─▶ (if isFirstLaunch) schedule the one-time Settings auto-open
   │        — MUST run AFTER / instead of the existing hideSettingsWindowOnLaunch() hide
   │          (see Common Pitfalls — these two behaviors currently collide)
   │
   ├─▶ construct NotchWindowController(), controller.start()
   │        │
   │        ├─▶ compute trialExpiryDate from the Keychain-sourced start date
   │        ├─▶ schedule ONE DispatchWorkItem at trialExpiryDate
   │        │        (mirrors dismissWorkItem / mediaDismissWorkItem / deviceBatteryWork /
   │        │         graceWorkItem — the file's existing 4-timer idiom, now a 5th)
   │        │        on fire → updateVisibility()  (wall-clock recheck, not blind trust — see Pitfalls)
   │        │
   │        └─▶ updateVisibility()  ◀── the SOLE show/hide site (Pattern 7, unchanged)
   │                 │
   │                 ▼
   │            shouldShow(hasTarget, hideInFullscreen, isFullscreen, isLicensed) ── NEW param
   │                 │
   │      isLicensed = licenseState.isEntitled
   │                 │            ┌─ true  → existing target/fullscreen logic decides (unchanged behavior)
   │                 └────────────┴─ false → panel?.orderOut(nil)  (same hide branch as clamshell/fullscreen)
   │
   └─▶ status-item click (AppDelegate)
            │
            │  isLicensed == false?
            ├─ yes → statusItem.menu = nil, click jumps straight to openSettings() (D-05)
            └─ no  → statusItem.menu = normal menu (Settings…/Quit), AppKit shows it automatically

DEBUG build only:
  AppDelegate DEBUG menu item ("Force Expired"/"Force Licensed"/"Reset Trial")
       │
       ▼
  writes a DEBUG-only UserDefaults override key
       │
       ▼
  UserDefaults.didChangeNotification  (existing observer, NotchWindowController.swift:302-305)
       │
       ▼
  handleSettingsChanged() (or a new sibling) re-reads LicenseState.status → updateVisibility()
```

### Recommended Project Structure
```
Islet/
├── Licensing/                      # NEW group (mirrors Islet/Notch/'s pure-seam + thin-glue split)
│   ├── TrialLogic.swift            # PURE: trialStatus(startDate:now:length:) -> .active(daysRemaining) | .expired
│   ├── TrialManager.swift          # GLUE: Keychain read/write, UserDefaults mirror, first-launch check
│   └── LicenseState.swift          # @Published stub model: status, isEntitled; DEBUG override read
├── Notch/
│   ├── FullscreenDetector.swift    # MODIFIED: shouldShow(...) gains isLicensed: Bool param
│   └── NotchWindowController.swift # MODIFIED: licenseState property, expiry DispatchWorkItem, isLicensed AND-term
├── AppDelegate.swift                # MODIFIED: first-launch Settings auto-open, D-05 click routing, DEBUG menu
└── SettingsView.swift               # MODIFIED: one new line/section for the trial-started notice

IsletTests/
├── TrialLogicTests.swift            # NEW: mirrors PowerActivityTests.swift's pure-seam test style
└── VisibilityDecisionTests.swift    # MODIFIED: all 6 existing tests updated for the new isLicensed param + new cases
```

### Pattern 1: Pure/glue split for trial classification (mirrors `PowerActivity`/`PowerSourceMonitor`)
**What:** `TrialLogic.swift` is a zero-I/O pure function; `TrialManager.swift` is the thin Keychain-touching glue that calls it.
**When to use:** Any time domain logic (here: "is the trial still active, and for how many more days") needs to be unit-tested in milliseconds without touching the Keychain/filesystem in the test run.
**Example:**
```swift
// TrialLogic.swift — mirrors the shape of PowerActivity.swift / FullscreenDetector.swift's
// existing pure predicates (no I/O, no Date() call inside — `now` is always passed in).
enum TrialStatus: Equatable {
    case active(daysRemaining: Int)
    case expired
}

func trialStatus(startDate: Date, now: Date, trialLength: TimeInterval) -> TrialStatus {
    let elapsed = now.timeIntervalSince(startDate)
    guard elapsed < trialLength else { return .expired }
    let remaining = trialLength - elapsed
    let days = Int((remaining / 86400).rounded(.up))
    return .active(daysRemaining: max(days, 1))
}
```
*(Trial length as a `TimeInterval` constant, e.g. `3 * 86400`, lives in `TrialManager` — D-09 explicitly rules out a shortened DEBUG variant of this constant.)*

### Pattern 2: Keychain read/write for the trial-start timestamp (D-10)
**What:** A single `kSecClassGenericPassword` item, account-keyed, storing the ISO-8601/epoch start date as `Data`.
**When to use:** Exactly once per app lifetime (first launch) for the write; once per launch for the read.
**Example:**
```swift
// TrialManager.swift — the ONLY file that imports Security for this purpose (mirrors the
// NowPlayingMonitor precedent: one file owns the fragile/system-specific surface).
import Foundation
import Security

enum KeychainTrialStore {
    private static let service = "com.lippi304.islet.trial"
    private static let account = "trialStartDate"

    static func read() -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let timestamp = TimeInterval(String(data: data, encoding: .utf8) ?? "")
        else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    @discardableResult
    static func write(_ date: Date) -> Bool {
        let payload = String(date.timeIntervalSince1970).data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // Delete-then-add is the simplest correct upsert for a single-item store (no update-vs-add
        // branching); this write happens once per app lifetime so simplicity wins over efficiency.
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = payload
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }
}
```
`kSecAttrAccessibleAfterFirstUnlock` is the right accessibility level here: it survives reboot without requiring the more restrictive "device unlocked right now" gymnastics, and (per this session's WebSearch confirmation) makes the key material available from first-unlock-after-restart until the next restart — appropriate for a background agent that may run before an interactive unlock in some flows [MEDIUM confidence — WebSearch-verified description, not Context7-fetched]. Because the app is not sandboxed, no `kSecAttrAccessGroup`/App Group entitlement is required [VERIFIED: `project.yml` `ENABLE_APP_SANDBOX: NO` this session].

**Reconciliation per `PITFALLS.md` Pitfall 1:** also mirror the same date to UserDefaults for convenience/live-update-signal purposes (see Pattern 3 below), and when both exist, **trust the earliest of the two** for enforcement — a user editing only the UserDefaults copy can't extend their trial by picking a later date.

### Pattern 3: `isLicensed` as a new AND-term in the existing single arbiter (D-11)
**What:** Extend the pure `shouldShow(...)` predicate, not `updateVisibility()`'s call site logic.
**When to use:** Any new condition that should gate island visibility — this is the established, enforced convention (Pattern 7) across Phases 2/6/8/9.
**Example:**
```swift
// FullscreenDetector.swift — BEFORE (current, verified this session):
func shouldShow(hasTarget: Bool, hideInFullscreen: Bool, isFullscreen: Bool) -> Bool {
    hasTarget && !(hideInFullscreen && isFullscreen)
}

// AFTER:
func shouldShow(hasTarget: Bool, hideInFullscreen: Bool, isFullscreen: Bool, isLicensed: Bool) -> Bool {
    isLicensed && hasTarget && !(hideInFullscreen && isFullscreen)
}
```
```swift
// NotchWindowController.swift updateVisibility() — the ONE call site that changes:
if shouldShow(hasTarget: target != nil,
              hideInFullscreen: hideInFullscreen,
              isFullscreen: fullscreen,
              isLicensed: licenseState.isEntitled),   // NEW
   let target {
    positionAndShow(on: target)
} else {
    panel?.orderOut(nil)   // same single hide branch — no new visual state (D-04)
    hotZone = nil
    expandedZone = nil
    pointerInZone = false
}
```
This is a **breaking signature change**: all 6 existing `VisibilityDecisionTests` call sites must be updated to pass `isLicensed: true` to preserve their current pass/fail meaning, plus new tests added for `isLicensed: false` (see Validation Architecture below).

### Pattern 4: D-05 locked-state click routing — `NSStatusItem.menu` vs `button.action`
**What:** AppKit's `NSStatusItem` only shows a click-driven `NSMenu` automatically when `.menu` is non-nil; when `.menu` is non-nil, any `button.target`/`button.action` you also set is **ignored** for that click. To make a click go straight to `openSettings()` while locked (skipping the dropdown), the code must set `statusItem.menu = nil` while locked and rely on `button.action`, then restore `statusItem.menu = menu` once entitled again.
**When to use:** Exactly the D-05 behavior.
**Example:**
```swift
// AppDelegate.swift — sketch of the toggle point (called from the same UserDefaults.didChangeNotification
// observer / license-state-change hook the controller uses):
private func applyMenuBarClickRouting(isLicensed: Bool) {
    if isLicensed {
        statusItem.menu = menu                                  // normal dropdown restored
        statusItem.button?.action = nil
    } else {
        statusItem.menu = nil                                   // AppKit will no longer auto-show a menu
        statusItem.button?.target = self
        statusItem.button?.action = #selector(openSettings)     // plain click -> Settings directly
    }
}
```
This detail is **not** covered in the milestone-level `ARCHITECTURE.md`/`PITFALLS.md` (those documents focus on the trial/Polar/notarization domains generically) — it only surfaces when reading `AppDelegate.swift`'s actual current menu-construction code (lines 26-34), which this session did.

### Anti-Patterns to Avoid
- **A second show/hide call site for "locked out":** e.g. an early-return in some other method instead of composing into `shouldShow(...)`. Reintroduces the exact bug class Phases 2/6/8/9 fixed (`ARCHITECTURE.md` Anti-Pattern 1).
- **Polling for trial expiry** with a repeating `Timer`: violates the codebase's stated idle-CPU-~0% discipline (`ARCHITECTURE.md` Anti-Pattern 3).
- **Trusting the `DispatchWorkItem` firing instant as the sole source of truth:** see Common Pitfalls — a long-duration one-shot timer across sleep can fire late; the *wall-clock* `TrialLogic` computation on every `updateVisibility()` call (which already fires on wake/space-change) is the actual authority, the timer is just a proactive nudge.
- **Gating `LicenseState`'s DEBUG override only at the menu-item level:** if the *reading* of the override key is not also `#if DEBUG`-gated, a stray UserDefaults key surviving into a Release build (e.g. copied user defaults from a dev machine) could silently unlock a shipped build. Gate both the writer (menu action) and the reader.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Tamper-resistant local persistence | A custom obfuscated file/plist scheme | `Security` framework `kSecClassGenericPassword` | Apple's Keychain already solves "survive reinstall, not casually editable via a documented CLI" — exactly TRIAL-01's bar. Building a custom scheme would be strictly worse and violate the anti-speculative-complexity stance. |
| Recurring "is it expired yet" check | A repeating `Timer`/polling loop | One `DispatchWorkItem` at the computed expiry instant + the app's existing wake/space-change-triggered `updateVisibility()` calls | Matches the file's own 4x-repeated one-shot idiom; a poll loop is both an anti-pattern here and unnecessary given how often `updateVisibility()` already re-runs incidentally. |
| First-launch-only notice | A new alert/notification/toast type | The existing `SettingsView` window, auto-opened once | D-01/D-02 explicitly rule out anything new; reuse is both the locked decision and the simpler build. |

**Key insight:** every piece of infrastructure this phase needs (tamper-resistant storage, one-shot scheduling, a settings surface, a live-update signal) already exists in this codebase in a directly reusable, precedented form. The entire phase should read as "one more instance of an existing pattern," not "new machinery."

## Common Pitfalls

### Pitfall 1: Long-duration `DispatchWorkItem` (3 days) behaves differently from the file's existing short-duration timers across system sleep
**What goes wrong:** All four existing one-shot timers in `NotchWindowController.swift` (`dismissWorkItem` ~3s, `mediaDismissWorkItem` ~15s, `graceWorkItem` ~0.4s, `deviceBatteryWork` ~0.6s) are short enough that Mac sleep during their window is a non-issue in practice. The new trial-expiry timer spans up to 3 *days*, during which the Mac will almost certainly sleep at least once. `DispatchQueue.main.asyncAfter` deadlines are computed from Mach absolute time, which **pauses while the CPU sleeps** — so the timer does not fire "on schedule" in wall-clock terms; it fires **later** than the wall-clock expiry instant, by roughly the accumulated sleep duration.
**Why it happens:** The existing four timers never exposed this because their windows are shorter than any realistic sleep cycle; this is a genuinely new failure mode introduced specifically by a multi-day duration, not something the existing pattern already handled.
**How to avoid:** Do not treat the `DispatchWorkItem` firing as the authoritative "expire now" signal. Compute trial status from **wall-clock `Date()` vs. the Keychain-sourced start date** every time `updateVisibility()` runs (which already happens on `didChangeScreenParametersNotification`, `activeSpaceDidChangeNotification`, `didActivateApplicationNotification`, and every transient enqueue/dismiss) — the one-shot timer is a *best-effort proactive nudge* for the case where none of those incidental triggers happen to fire near the exact expiry instant, not the sole enforcement mechanism. Since it only ever fires *late* (never early), there is no under-enforcement risk from the delay itself — worst case the user gets a few extra hours/minutes of trial if the Mac happened to be asleep at the exact instant, which is an acceptable, self-limiting cost (matches the project's own stated tolerance for casual trial-abuse cost, per `PITFALLS.md` Pitfall 1).
**Warning signs:** Code that assumes "the work item fired" is equivalent to "exactly N seconds have elapsed"; no fallback wall-clock check anywhere else in the visibility path.
[MEDIUM confidence — WebSearch-confirmed general Dispatch/Mach-time sleep behavior, not Apple-official-doc-verified this session]

### Pitfall 2: `hideSettingsWindowOnLaunch()` races the new first-launch auto-open
**What goes wrong:** `AppDelegate.swift`'s existing `applicationDidFinishLaunching` unconditionally schedules `hideSettingsWindowOnLaunch()` (a retry loop up to ~1s that hides the Settings window the instant it exists, specifically so a "Launch at Login" relaunch never pops Settings open). If the new first-launch trial-notice logic (D-02/D-03) also tries to show that same window around the same moment, the two behaviors directly conflict — whichever runs last on the retry-loop timing wins, non-deterministically.
**Why it happens:** This interaction is invisible until you read `AppDelegate.swift`'s actual existing code (lines 43-69) — the milestone-level `ARCHITECTURE.md`/`PITFALLS.md` research didn't have this file open when discussing the notice.
**How to avoid:** Make the two behaviors explicitly mutually exclusive: e.g., check `TrialManager.recordFirstLaunchIfNeeded()`'s `isFirstLaunch` return value **before** scheduling `hideSettingsWindowOnLaunch()`, and skip the hide entirely (going straight to an explicit show-and-focus) when it's the very first launch. Do not let both code paths race against the same window on the same run-loop.
**Warning signs:** On a genuinely fresh install, the Settings window either doesn't appear at all, or flickers open-then-closed.

### Pitfall 3: `NSStatusItem.menu` vs `button.action` mutual exclusivity breaks D-05 if implemented naively
**What goes wrong:** Setting `button.action = #selector(openSettings)` on the status item's button while `statusItem.menu` is still assigned has **no effect** — AppKit always shows the assigned menu on click when one is present, silently ignoring the button's own action/target. A naive first attempt at D-05 ("just add a click handler that checks lock state") will appear to do nothing.
**How to avoid:** Explicitly toggle `statusItem.menu` between `nil` (locked — click goes to `button.action`) and the real `NSMenu` (unlicensed — normal dropdown), as shown in Pattern 4 above.
**Warning signs:** Clicking the status item while "locked" still shows the normal Settings…/Quit dropdown instead of jumping directly to Settings.
[HIGH confidence — well-established, stable AppKit behavior; not re-verified via Apple docs this session, so tagged ASSUMED per provenance rules despite high certainty]

### Pitfall 4: DEBUG-only stub must be inert by construction, not just hidden from the UI
**What goes wrong:** If only the *menu item* that writes the override is `#if DEBUG`-gated, but the *code path that reads* the override value is compiled unconditionally, a stray leftover UserDefaults key (e.g. copied user defaults from a developer's machine, or a manual `defaults write` someone tries after reading this very research doc) could still silently force `isEntitled = true` in a shipped Release build.
**How to avoid:** Gate both sides — the menu item AND the read of the override key inside `LicenseState`/`TrialManager` — behind `#if DEBUG`, mirroring the existing `didLogFirstHover` discipline in `NotchWindowController.swift` (lines 231-239) where the entire probe, not just its trigger, is compiled out of Release.
**Warning signs:** `grep -n "DEBUG" ` across the new Licensing files shows the write path gated but not the read path.

### Pitfall 5: Keychain/UserDefaults reconciliation must favor the earliest date, not the latest
**What goes wrong:** If `TrialManager` blindly trusts whichever of the two stores it reads first (or the most-recently-written one), a user can extend their trial by editing only the UserDefaults mirror to a later date, since that read might win.
**How to avoid:** Per `PITFALLS.md` Pitfall 1: when both a Keychain and a UserDefaults copy exist and disagree, **the earliest of the two known dates wins for enforcement**. Only write, never trust-on-read, from the "more convenient" store.
**Warning signs:** Any code path that reads trial start exclusively from `UserDefaults.standard` without a Keychain cross-check.

## Code Examples

### Extending the arbiter call site (full before/after, verified against the actual file)
```swift
// NotchWindowController.swift updateVisibility() — verified current state, lines 421-448 this session.
// The only change needed at the call site is the one new argument; the hide branch (panel?.orderOut(nil)
// etc.) is untouched — D-04's "reuse the exact same hide path" falls out for free.
private func updateVisibility() {
    let descriptors = NSScreen.screens.map { $0.descriptor }
    let target = selectTargetScreen(from: descriptors)
    let fullscreen = isBuiltinDisplayInFullscreenSpace(builtinUUID: currentBuiltin()?.uuid)

    if shouldShow(hasTarget: target != nil,
                  hideInFullscreen: hideInFullscreen,
                  isFullscreen: fullscreen,
                  isLicensed: licenseState.isEntitled),      // NEW
       let target {
        positionAndShow(on: target)
    } else {
        panel?.orderOut(nil)
        hotZone = nil
        expandedZone = nil
        pointerInZone = false
    }
}
```

### One-shot expiry timer mirroring the file's existing idiom
```swift
// NotchWindowController.swift — a 5th one-shot DispatchWorkItem, same shape as dismissWorkItem/
// mediaDismissWorkItem/graceWorkItem/deviceBatteryWork (property + cancel-in-deinit + asyncAfter).
private var trialExpiryWorkItem: DispatchWorkItem?

private func scheduleTrialExpiryCheck() {
    trialExpiryWorkItem?.cancel()
    guard let expiry = licenseState.trialExpiryDate, expiry > Date() else { return }
    let work = DispatchWorkItem { [weak self] in self?.updateVisibility() }
    trialExpiryWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + expiry.timeIntervalSinceNow, execute: work)
}
// Called once from start(); torn down in deinit alongside the other four:
//   trialExpiryWorkItem?.cancel()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|-------------------|----------------|--------|
| `dlopen`-ing `MediaRemote.framework` directly (n/a to this phase, noted for context) | `mediaremote-adapter` bridge | macOS 15.4 | Not this phase's concern, but confirms the codebase's general "isolate fragile externals behind one protocol/file" discipline this phase's `LicenseState` design should also follow ahead of Phase 12 |
| N/A — no prior trial/licensing code exists in this codebase | This phase introduces the first trial/licensing subsystem | 2026-07-05 | Confirmed via `grep -rn "keychain|license|polar|trial"` across the repo this session (via `ARCHITECTURE.md`'s own audit, re-confirmed by this session's `grep -rln "kSecClass"` returning zero hits) — genuinely new, not an extension |

**Deprecated/outdated:** Nothing in this phase's scope is deprecated; all APIs used (`Security` Keychain functions, `NSStatusItem`, `DispatchWorkItem`) are current, stable, long-lived Apple APIs with no announced replacement.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|-----------------|
| A1 | `kSecAttrAccessibleAfterFirstUnlock` is the correct accessibility level for this use case | Architecture Patterns, Pattern 2 | Low — worst case is a slightly wrong accessibility window (e.g. item unavailable before first unlock after a reboot on a background-agent launch); does not affect tamper-resistance, easily correctable in code review |
| A2 | `NSStatusItem.menu` fully suppresses `button.action` on click (no partial/dual-firing behavior) | Common Pitfalls, Pitfall 3 / Architecture Patterns, Pattern 4 | Medium — if AppKit's actual behavior differs slightly (e.g. on a specific macOS version), D-05's click routing could either double-fire or never fire; verify on-device during Phase 10 execution before considering D-05 done |
| A3 | A DEBUG-only UserDefaults override key, reused through the existing `UserDefaults.didChangeNotification` mechanism, is the right shape for the D-08 stub (vs. e.g. an in-memory-only override, or a separate DEBUG-only settings UI) | Architecture Patterns, Summary/Recommendation synthesis | Low-Medium — this is a design synthesis beyond what CONTEXT.md explicitly locked (CONTEXT.md left the exact DEBUG menu wiring to discretion); if the planner picks a different shape, no requirement is violated, but the "reuses existing live-update plumbing" benefit would need to be re-derived |
| A4 | Mach-time-based `DispatchQueue.main.asyncAfter` deadlines only ever fire *late* (never early) across sleep, never causing an under-enforcement security gap | Common Pitfalls, Pitfall 1 | Low — if this is wrong (i.e., if sleep could somehow cause an *early* fire), the practical impact is still bounded because the actual enforcement authority is the wall-clock `TrialLogic` check on every `updateVisibility()` call, not the timer itself |

## Open Questions

1. **Does `applicationDidFinishLaunching`'s existing `didHideSettingsAtLaunch` retry-loop need a parameter, or a full bypass, for the first-launch case?**
   - What we know: the retry loop hides the window up to ~1s after launch; the first-launch notice needs the window to end up *shown*, not hidden.
   - What's unclear: whether the cleanest fix is "skip `hideSettingsWindowOnLaunch()` entirely on first launch" vs. "let it hide, then immediately re-show via the same `openSettings()` path used for the menu item" — both satisfy D-02/D-03's literal requirement, but have different flash/flicker risk.
   - Recommendation: planner should pick "skip the hide entirely on first launch" — it has zero flicker risk and is a one-line `guard` addition, consistent with the project's low-complexity bias.

2. **Should `LicenseState`'s stub have a real "licensed" case at all in Phase 10, or only `.trial`/`.trialExpired`?**
   - What we know: CONTEXT.md D-08 explicitly asks for a "Force Licensed" debug option, implying `LicenseState` needs a third case now even though no real Polar validation exists until Phase 12.
   - What's unclear: nothing structurally — `LicenseState.status` should be a 3-case enum (`.trial(daysRemaining:)` / `.trialExpired` / `.licensed`) from the start, per `ARCHITECTURE.md`'s own `LicenseStatus` shape, so Phase 11/12 don't need to re-shape it later.
   - Recommendation: build the 3-case enum now; only the "how does `.licensed` become true for real" wiring (Polar validation) is deferred.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (bundled with Xcode 26.6 on this build machine) |
| Config file | `project.yml` (`IsletTests` target, `xcodegen generate` → `.xcodeproj`) |
| Quick run command | `xcodebuild test -scheme Islet -only-testing:IsletTests/TrialLogicTests -only-testing:IsletTests/VisibilityDecisionTests` |
| Full suite command | `xcodebuild test -scheme Islet` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|---------------------|---------------|
| TRIAL-01 | `trialStatus(startDate:now:length:)` classifies active vs. expired correctly at the boundary | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/TrialLogicTests` | ❌ Wave 0 (new file, mirrors `PowerActivityTests.swift`) |
| TRIAL-01 | Trial start survives `defaults delete` + app reinstall (Keychain, not UserDefaults, is authoritative) | manual | — (inherently requires an actual delete/reinstall cycle) | manual-only, per `PITFALLS.md`'s own "Looks Done But Isn't" checklist item |
| TRIAL-02 | First-launch-only Settings auto-open fires exactly once, never on subsequent launches | unit (the `isFirstLaunch` boolean logic) + manual (visual confirmation of window + text) | `xcodebuild test -scheme Islet -only-testing:IsletTests/TrialManagerTests` | ❌ Wave 0 (new file; needs an injectable Keychain seam — see below) |
| LIC-03 | `shouldShow(..., isLicensed: false)` always hides regardless of target/fullscreen state | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/VisibilityDecisionTests` | ✅ exists, needs signature update to all 6 current tests + new `isLicensed: false` cases |
| LIC-03 | Flipping the DEBUG stub from invalid→valid unlocks at the next natural transition, not mid-interaction | manual | — (interaction-state timing, matches `PITFALLS.md` Pitfall 5's own manual-only verification) | manual-only |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Islet -only-testing:IsletTests/TrialLogicTests -only-testing:IsletTests/VisibilityDecisionTests`
- **Per wave merge:** `xcodebuild test -scheme Islet` (full suite)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `IsletTests/TrialLogicTests.swift` — new file, covers TRIAL-01's pure classification boundary (active at 2.99 days, expired at exactly 3.0 days, etc.), mirrors `IsletTests/PowerActivityTests.swift`'s style
- [ ] `IsletTests/TrialManagerTests.swift` — new file; needs a small injection seam (e.g. `TrialManager` taking a `KeychainReading`/`KeychainWriting` protocol, or simply testing `TrialLogic` + a fake-clock wrapper around `TrialManager`'s pure decision surface) so the "first launch vs. not" boolean logic is testable without touching the real Keychain in CI
- [ ] `IsletTests/VisibilityDecisionTests.swift` — MODIFY existing file: all 6 current test bodies need `isLicensed: true` added to their `shouldShow(...)` calls (breaking signature change), plus new tests for `isLicensed: false` dominating every other combination
- [ ] No new test-framework installation needed — `IsletTests` target and `xcodebuild test -scheme Islet` are already fully wired (`project.yml` lines 66-99, confirmed this session)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|-----------------|---------|---------------------|
| V2 Authentication | No | No user accounts/login in this app — N/A |
| V3 Session Management | No | No sessions — N/A |
| V4 Access Control | Partially (local feature-entitlement, not classic multi-user access control) | The `isLicensed` AND-term in `shouldShow(...)` is the app's entire "access control" surface for this phase — enforced in exactly one place (Pattern 7), not scattered |
| V5 Input Validation | No (this phase) | The DEBUG stub selection is a fixed enum choice from a menu, not free text; the actual license-key text field is Phase 11/12's scope, not this phase's |
| V6 Cryptography | Yes (narrowly) | Trial-start timestamp stored via system Keychain (`Security` framework) — do **not** hand-roll encryption/obfuscation/HMAC for this value; that proportionate integrity-binding effort is explicitly scoped to the Phase 12 license *cache* (`PITFALLS.md` Pitfall 3), not the Phase 10 trial date, which even `ARCHITECTURE.md` (pre-supersession) correctly characterized as "not a secret, low stakes" |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|------------------------|
| Trial reset via `defaults delete <bundle-id>` or app reinstall | Tampering | Keychain-backed start date (non-sandboxed macOS Keychain items persist independently of app bundle lifecycle) — D-10, `PITFALLS.md` Pitfall 1 |
| Trial extension by editing only the UserDefaults mirror to a later date | Tampering | Earliest-of-two-known-dates wins for enforcement (Common Pitfalls, Pitfall 5) |
| DEBUG stub override leaking into a Release build (free unlock) | Elevation of Privilege | Gate both the writer (menu item) and the reader (override lookup) behind `#if DEBUG` — verify via grep and via an actual Release-configuration build before considering the phase done (Common Pitfalls, Pitfall 4) |
| Mid-interaction abrupt lockout eroding trust in a "polished" app | (UX-adjacent, not classic STRIDE) | Defer enforcement application to the next natural UI transition, not a synchronous yank — D-13, `PITFALLS.md` Pitfall 5 |

## Sources

### Primary (HIGH confidence)
- Direct reads of the actual current codebase this session: `Islet/Notch/NotchWindowController.swift` (all 1086 lines), `Islet/Notch/FullscreenDetector.swift`, `Islet/AppDelegate.swift`, `Islet/SettingsView.swift`, `Islet/ActivitySettings.swift`, `Islet/Notch/NowPlayingState.swift`, `Islet/Notch/PowerSourceMonitor.swift`, `Islet/IsletApp.swift`, `IsletTests/VisibilityDecisionTests.swift`, `project.yml`, `.planning/config.json`.
- `.planning/phases/10-trial-lockout-gate/10-CONTEXT.md` — locked decisions D-01 through D-13.
- `.planning/REQUIREMENTS.md`, `.planning/STATE.md` — requirement text and roadmap sequencing rationale.
- `grep -rn "func shouldShow"`, `grep -rln "kSecClass"` across the repo this session — confirmed `shouldShow(...)`'s current signature and the total absence of any existing Keychain code.
- `xcodebuild -version` / `swift --version` on this build machine this session — Xcode 26.6, Swift 6.3.3 (project's own `SWIFT_VERSION: "5.0"` language-mode setting is what matters for source compatibility, per prior project memory `build-machine-macos26-toolchain`).

### Secondary (MEDIUM confidence)
- `.planning/research/ARCHITECTURE.md` — milestone-level integration research (verified against the codebase in its own research pass on 2026-07-05); this document's Recommendations 1-6 are treated as the baseline design, refined here against this session's fresh file reads.
- `.planning/research/PITFALLS.md` — milestone-level pitfalls research (Pitfalls 1, 3, 5 directly apply to this phase).
- WebSearch: "DispatchQueue.main.asyncAfter long duration days macOS sleep wake" — confirms Mach-time-based dispatch timers pause during sleep (Apple Developer Forums thread 687170, cited below).
- WebSearch: Keychain `SecItemAdd`/`kSecAttrAccessibleAfterFirstUnlock` semantics — cross-referenced across multiple community sources, directionally consistent, not Apple-official-doc-fetched this session.

### Tertiary (LOW confidence)
- None flagged beyond what's captured in the Assumptions Log above.

- [Apple Developer Forums — Running Timer inside NetworkExtension (Mach-time/sleep behavior)](https://developer.apple.com/forums/thread/687170)
- [Apple Developer Documentation — `asyncAfter(deadline:execute:)`](https://developer.apple.com/documentation/dispatch/dispatchqueue/2300020-asyncafter)
- [Concurrency, (a)synchronicity and background processing — fulmanski.pl](https://fulmanski.pl/tutorials/apple/macos/concurrency-asynchronicity-and-background-processing/)
- [oneuptime.com — How to Use Keychain for Secure Storage in Swift](https://oneuptime.com/blog/post/2026-02-02-swift-keychain-secure-storage/view)
- [swiftdevjournal.com — Saving Passwords in the Keychain in Swift](https://swiftdevjournal.com/saving-passwords-in-the-keychain-in-swift/)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; existing system frameworks only, verified against `project.yml`
- Architecture: HIGH — every integration point (`shouldShow`, `updateVisibility`, `AppDelegate`, `SettingsView`) verified by direct file reads this session, not inferred
- Pitfalls: MEDIUM-HIGH — the three phase-specific pitfalls (sleep/timer, `hideSettingsWindowOnLaunch` race, `NSStatusItem.menu`/`button.action`) are derived from direct code reading + one WebSearch cross-check each, not yet verified on-device

**Research date:** 2026-07-05
**Valid until:** 30 days (stable Apple system APIs; the only fast-moving risk is if the executor changes `AppDelegate.swift`/`NotchWindowController.swift` again before this phase starts, which would require a quick re-read, not a re-research)
