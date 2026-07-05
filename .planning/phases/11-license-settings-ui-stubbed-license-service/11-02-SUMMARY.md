---
phase: 11-license-settings-ui-stubbed-license-service
plan: 02
subsystem: settings-ui
tags: [swift, swiftui, settings, license, state-machine, live-unlock]

# Dependency graph
requires:
  - phase: 11-license-settings-ui-stubbed-license-service
    plan: 01
    provides: "LicenseService protocol + StubLicenseService + LicenseActivationError + LicenseState.sessionActivated short-circuit"
  - phase: 10-trial-state
    provides: "NotchWindowController.updateVisibility() live-unlock path + AppDelegate.licenseObserver + LicenseState.status/isEntitled"
provides:
  - "Adaptive License Section at the top of the Settings Form (trial / expired / licensed) — the phase's user-visible surface"
  - "idle→validating→success/failure activation state machine driven by the Plan 01 stub"
  - "Buy Now handoff (NSWorkspace → https://getislet.app)"
  - "License activation live-unlock wiring via the existing UserDefaults.didChangeNotification trigger (no new show/hide site)"
affects: [12-polar-license-service]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Non-observable singleton state re-read into @State on appear + appearsActive refocus (Pitfall 4 — LicenseState stays a plain type, not ObservableObject)"
    - "Adaptive Section body via switch over LicenseStatus (one Section, three layouts)"
    - "Service emits verdict on main thread, caller mutates @State/LicenseState in the completion closure"
    - "Live-unlock by writing a TRIGGER-ONLY UserDefaults key that fires didChangeNotification → updateVisibility() (reuse Phase 10, no second show/hide call site)"

key-files:
  created: []
  modified:
    - Islet/SettingsView.swift

key-decisions:
  - "licenseEntry built as a placeholder @ViewBuilder subview in Task 1, fleshed out in Task 2 — keeps each task atomically buildable while the trial/expired branches reference one named subview"
  - "Added explicit `import AppKit` (NSWorkspace) to match NotchWindowController's convention rather than relying on SwiftUI's transitive AppKit re-export"
  - "Live-unlock uses the `license.activationNudge` key as a pure trigger (T-11-02) — never read back as entitlement truth; entitlement stays in the in-memory sessionActivated"

requirements-completed: [TRIAL-03]

# Metrics
duration: ~15min
completed: 2026-07-05
---

# Phase 11 Plan 02: License Settings UI + Activation State Machine Summary

**The adaptive License section now sits at the top of the Settings Form — showing the trial days-remaining countdown, the expired Buy-Now call-to-action, or the `Licensed ✓` confirmation — with an idle→validating→success/failure activation state machine that flips the in-memory session entitlement and live-unlocks the island through Phase 10's existing `updateVisibility()` path, no restart and no second show/hide site.**

## Performance
- **Duration:** ~15 min
- **Completed:** 2026-07-05
- **Tasks:** 2
- **Files modified:** 1 (`Islet/SettingsView.swift`)

## Accomplishments
- Replaced the old fixed end-date trial notice with the days-remaining countdown (`"n days left in your trial."`, singular for 1) — TRIAL-03 / D-03.
- Added `Section("License")` as the FIRST child of the Form, above Launch-at-login (D-02), whose body switches on `LicenseState.status`:
  - `.trial(daysRemaining:)` → secondary countdown + Buy Now + license field/Activate.
  - `.trialExpired` → `"3-day trial period expired"` `.headline` + Buy Now + field/Activate.
  - `.licensed` → `"Licensed ✓"` only (Buy Now + field hidden) — D-01.
- `licenseStatus` is re-read from `LicenseState.shared.status` into `@State` on `.onAppear` and on `appearsActive` refocus (Pitfall 4); `LicenseState` stays a plain type.
- Buy Now (`"Buy Islet — €7.99"`) opens `https://getislet.app` via `NSWorkspace.shared.open` (D-07 placeholder URL).
- Activation state machine: `ActivationPhase { idle, validating, success, failure }`, `enteredKey`, and the `LicenseService` protocol seam held as `StubLicenseService()`.
- Inline `statusLine`: idle → nothing; `⟳ Validating…` (`.secondary`); `✓ License activated` (`.green`); `✗ That key wasn't recognized.` (`.red`). Activate is disabled while validating and when the trimmed field is empty.
- `activate()` on `.success` sets `LicenseState.shared.sessionActivated = true`, writes the trigger-only `license.activationNudge` key (fires the existing `UserDefaults.didChangeNotification` → `updateVisibility()` live-unlock), sets `licenseStatus = .licensed`, and shows the success line. No second `orderFront`/`orderOut` call site was added.

## Task Commits
1. **Task 1: Adaptive License section (days-remaining, expired CTA, licensed) + Buy Now** — `cebb25a` (feat)
2. **Task 2: Activation state machine + live-unlock wiring** — `583c773` (feat)

**Plan metadata:** committed with this SUMMARY (docs).

## Files Modified
- `Islet/SettingsView.swift` — added the adaptive License `Section`, `buyNowButton`, `licenseEntry`/`statusLine` subviews, the `ActivationPhase` machine, the `licenseService` seam, `activate()`, the `licenseStatus` @State + refocus re-read, and `import AppKit`. Removed the old `TrialManager` end-date notice block.

## Decisions Made
- **Placeholder `licenseEntry` in Task 1, fleshed out in Task 2:** keeps both commits independently buildable while the trial/expired branches reference a single named subview (no churn on the Section body between tasks).
- **Explicit `import AppKit`:** `NSWorkspace` is AppKit; added the import to match `NotchWindowController`'s convention rather than depend on SwiftUI's transitive re-export.
- **`license.activationNudge` is a trigger only (T-11-02):** it is written to fire `didChangeNotification` and never read as entitlement truth; entitlement lives in the in-memory `sessionActivated`, which resets on relaunch.

## Deviations from Plan
None — both tasks were implemented to the locked UI-SPEC copy/typography/color and the PATTERNS live-unlock mechanism. The `licenseEntry` placeholder-then-flesh-out approach is exactly the sequencing the plan's Task 1 `<action>` prescribed.

## TDD Gate Compliance
Both tasks are marked `tdd="true"`, but the plan itself scopes them as SwiftUI view glue with **no unit target** (`<verify>`: "SwiftUI glue, no unit target for view code"), and the behaviors are explicitly "not unit-observable" / "non-unit-reachable" (view rendering + `LicenseState`'s `private init()` short-circuit). `files_modified` is `Islet/SettingsView.swift` only — no test file. Accordingly the RED/GREEN gate is satisfied by the plan's declared automated gate (`xcodebuild build -scheme Islet` → BUILD SUCCEEDED) per task, with the interaction/visual behaviors routed to `/gsd:verify-work` (see Manual Verification Required). No `test(...)` commit exists because the plan specifies none for view code; this is by design, not an omitted gate.

## Issues Encountered
None. `xcodebuild build -scheme Islet -destination 'platform=macOS'` reported **BUILD SUCCEEDED** after each task. As documented in the executor context and the Plan 01 summary, `xcodebuild test` hangs headlessly (the test bundle is hosted in the full `Islet.app`, which boots the NSPanel/MediaRemote/IOBluetooth stack on launch and never yields to the runner without a GUI session). The build gate was used as the automated gate per the plan; the full suite must be run interactively in Xcode.

## Manual Verification Required
Routed to `/gsd:verify-work` (on-device DEBUG build; mirrors the Phase 10 manual precedent):
- [ ] **Adaptive layout across states (D-01):** Drive `.trial` / `.trialExpired` / `.licensed` via the DEBUG stub-flips (`forceExpired` / `forceLicensed`) + magic key; confirm each layout matches UI-SPEC (days line + Buy Now + field for trial/expired; `Licensed ✓` only, Buy Now + field hidden, for licensed).
- [ ] **Live unlock:** In an expired/trial state, open Settings → paste `ISLET-DEMO-OK` → Activate → observe `⟳ Validating…` for ~1s → `✓ License activated`, section switches to `Licensed ✓`, and the island re-appears WITHOUT restart (no abrupt yank).
- [ ] **Buy Now (D-07):** Click "Buy Islet — €7.99"; confirm the default browser opens `https://getislet.app`.
- [ ] **No persistence (T-11-02):** Activate with the magic key, quit + relaunch; confirm the app is back in trial/expired (island locked) — entitlement did not survive relaunch.
- [ ] **Full suite:** Run `xcodebuild test -scheme Islet` interactively in Xcode (Cmd-U) — cannot run headlessly in this executor.

## User Setup Required
None — no external service configuration required (stub service).

## Next Phase Readiness
- The Settings License surface is complete and consumes the Plan 01 seam. Phase 12's `PolarLicenseService` drops into `private let licenseService: LicenseService = StubLicenseService()` with zero SettingsView change (only the concrete type swaps), and the real checkout URL replaces the `https://getislet.app` placeholder in `buyNowButton`.

## Self-Check: PASSED
- File verified on disk: `Islet/SettingsView.swift`, `.planning/phases/11-license-settings-ui-stubbed-license-service/11-02-SUMMARY.md`.
- Commits verified in git log: `cebb25a` (Task 1 feat), `583c773` (Task 2 feat).
- `xcodebuild build -scheme Islet` reported BUILD SUCCEEDED after both tasks.

---
*Phase: 11-license-settings-ui-stubbed-license-service*
*Completed: 2026-07-05*
