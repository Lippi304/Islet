---
phase: 11-license-settings-ui-stubbed-license-service
reviewed: 2026-07-05T14:45:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - Islet/Licensing/LicenseService.swift
  - Islet/Licensing/LicenseState.swift
  - Islet/SettingsView.swift
  - IsletTests/LicenseServiceTests.swift
findings:
  critical: 0
  warning: 1
  info: 5
  total: 6
status: issues-found
---

# Phase 11: Code Review Report

**Reviewed:** 2026-07-05T14:45:00Z
**Depth:** standard (Swift/SwiftUI per-file analysis)
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the stubbed license-service seam (`LicenseService.swift`), the in-memory
session-entitlement addition (`LicenseState.swift`), the adaptive License Settings UI +
activation state machine (`SettingsView.swift`), and the async unit harness
(`LicenseServiceTests.swift`).

The security-critical invariants of the phase hold and were verified:

- **Stub purity** — `StubLicenseService.activate` returns a verdict only; it does NOT
  touch `LicenseState.shared` (LicenseService.swift:45-60). Confirmed.
- **Main-thread contract** — completion always fires via `DispatchQueue.main.asyncAfter`
  (LicenseService.swift:48); the test asserts `Thread.isMainThread`. Confirmed.
- **In-memory-only entitlement** — `sessionActivated` is a plain `var`, never written to
  UserDefaults/Keychain (LicenseState.swift:29). The `license.activationNudge` key is a
  fire-and-forget trigger and is never read back as entitlement truth. Confirmed.
- **Live-unlock actually works** — cross-checked `AppDelegate.licenseObserver`
  (AppDelegate.swift:57-60) and `NotchWindowController.defaultsObserver`
  (NotchWindowController.swift:322-323): both observe `UserDefaults.didChangeNotification`
  with `object: nil, queue: .main` and re-read `LicenseState.isEntitled`. `sessionActivated`
  is set BEFORE the nudge write (SettingsView.swift:170 → 177), so `isEntitled` reads `true`
  by the time `updateVisibility()` runs. Ordering is correct.
- **No injection** — the entered key is passed only to `activate` (opaque `==`) and to a
  local `trimmingCharacters` empty-check; never interpolated into a URL/shell/log. The Buy Now
  URL is a hardcoded constant with no user input. Confirmed (T-11-03 / T-11-04).
- **No retain cycle** — `SettingsView` is a value-type `struct`; the escaping `activate`
  completion captures a view snapshot whose `@State` storage persists. No leak.

Per the review brief, the documented headless-test-hang caveat and the intentional
`#if DEBUG` magic-key scaffold are NOT flagged (accepted decisions for this phase).

One material UI-correctness defect and several minor quality items follow.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: The `.success` status line ("✓ License activated") is unreachable — the locked UI-SPEC confirmation copy never renders

**File:** `Islet/SettingsView.swift:169-180` (and the dead branch at `150-161`)
**Issue:** On a successful activation, `activate()` sets **both** `licenseStatus = .licensed`
and `activationPhase = .success` inside the same completion closure:

```swift
licenseStatus = .licensed
activationPhase = .success
```

SwiftUI coalesces both mutations into a single render pass. Because the `Section("License")`
body switches on `licenseStatus`, the `.licensed` case renders **only** `Text("Licensed ✓")`
(SettingsView.swift:52-54) — it does NOT include `licenseEntry`, and `statusLine` lives inside
`licenseEntry`. Therefore the `.success` branch of `statusLine`
(`Text("✓ License activated").foregroundStyle(.green)`, line 157) is removed from the view
tree in the very same update that sets `activationPhase = .success`. The `✓ License activated`
copy — a LOCKED UI-SPEC deliverable for D-04 — is displayed for zero frames and the
`activationPhase = .success` assignment is effectively dead code. The behavior contract in
11-02-PLAN Task 2 lists both "`✓ License activated` (.green)" **and** "section switches to
`Licensed ✓`" as outcomes; only the second is observable.

**Fix:** Decide which confirmation the UX wants and make it reachable. Simplest options:
- Drop the now-dead `activationPhase = .success` assignment and rely on the `Licensed ✓`
  section flip as the confirmation (update the plan/UI-SPEC to match), OR
- Briefly show the success line before flipping, e.g. delay the `licenseStatus` flip:
```swift
case .success:
    LicenseState.shared.sessionActivated = true
    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "license.activationNudge")
    activationPhase = .success            // show "✓ License activated" first
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        licenseStatus = .licensed         // then collapse to "Licensed ✓"
    }
```
At minimum, remove the unreachable assignment so the code does not imply a UI state that can
never render.

## Info

### IN-01: Empty-input guard trims `.whitespaces`, but the service trims `.whitespacesAndNewlines` — inconsistent enablement

**File:** `Islet/SettingsView.swift:144` vs `Islet/Licensing/LicenseService.swift:51`
**Issue:** The Activate button is disabled when
`enteredKey.trimmingCharacters(in: .whitespaces).isEmpty`, but the stub trims
`.whitespacesAndNewlines`. A key consisting solely of newlines (e.g. `"\n"`) is NOT empty under
`.whitespaces`, so Activate becomes enabled, the ~1s round-trip runs, and it resolves to
`.failure(.invalidKey)` after trimming to empty. Not a crash — just a wasted validation the
"empty is inert" rule (D-05) intends to prevent.
**Fix:** Use `.whitespacesAndNewlines` in the disabled check so the guard matches the service's
trimming exactly.

### IN-02: Trial length `3` is hardcoded in two places instead of derived from `TrialManager.trialLength`

**File:** `Islet/Licensing/LicenseState.swift:59` and `Islet/SettingsView.swift:48`
**Issue:** The no-start-date fallback returns `.trial(daysRemaining: 3)` and the expired
heading is the literal `"3-day trial period expired"`. Both duplicate the trial length as a
magic number. If `TrialManager.trialLength` ever changes, the fallback and the heading silently
disagree with the actual trial window.
**Fix:** Derive the day count from `TrialManager.trialLength` (e.g. compute days once and
interpolate into the heading), keeping a single source of truth.

### IN-03: `license.activationNudge` key is written but never cleaned up

**File:** `Islet/SettingsView.swift:177`
**Issue:** The trigger key is written to `UserDefaults` on every successful activation and never
removed. It is correctly never read as entitlement truth (so no bypass), but it accumulates as
permanent cruft and slightly muddies the "no persisted entitlement" story for a future reader.
**Fix:** Optional — either document it as an intentional permanent no-op trigger, or write a
transient marker and `removeObject(forKey:)` after the notification round-trip. Low priority.

### IN-04: `activationPhase` is never reset to `.idle` after a failure

**File:** `Islet/SettingsView.swift:181-182`
**Issue:** After `.failure`, the red `✗ That key wasn't recognized.` line remains visible until
the next Activate tap flips the phase back to `.validating`. Editing the key does not clear the
stale error. Minor UX polish, not a correctness bug.
**Fix:** Optional — reset `activationPhase = .idle` in an `.onChange(of: enteredKey)` so the
error clears as the user corrects the key.

### IN-05: Force-unwrapped `URL(string:)!` for the Buy Now link

**File:** `Islet/SettingsView.swift:132`
**Issue:** `URL(string: "https://getislet.app")!` force-unwraps. Per the review brief this is
acceptable for a hardcoded, valid constant and **cannot** crash as written — noted only so the
Phase 12 swap to the real checkout URL keeps the same guarantee.
**Fix:** No action required now. When the URL becomes dynamic/configurable in Phase 12, replace
the force-unwrap with a `guard let`.

---

_Reviewed: 2026-07-05T14:45:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
