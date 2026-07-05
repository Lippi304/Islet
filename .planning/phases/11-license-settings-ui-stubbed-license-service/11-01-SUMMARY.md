---
phase: 11-license-settings-ui-stubbed-license-service
plan: 01
subsystem: licensing
tags: [swift, xctest, protocol-isolation, license, stub-service, dispatchqueue]

# Dependency graph
requires:
  - phase: 10-trial-state
    provides: "LicenseState singleton + LicenseStatus enum (.trial/.trialExpired/.licensed) + isEntitled arbiter"
  - phase: 04-now-playing
    provides: "NowPlayingService protocol-isolation precedent (AnyObject protocol + one final-class conformer + asyncAfter main-thread completion)"
provides:
  - "LicenseService protocol (AnyObject) — the one seam Phase 12's PolarLicenseService drops into with zero protocol change"
  - "LicenseActivationError enum (invalidKey + forward-declared unreachable(String))"
  - "StubLicenseService — pure key->Result validator, DEBUG-only ISLET-DEMO-OK magic key, ~1s main-thread async completion"
  - "LicenseState.sessionActivated (in-memory-only) + .licensed short-circuit in status"
  - "IsletTests/LicenseServiceTests.swift — async XCTestExpectation harness locking D-05/D-06"
affects: [11-02-settings-ui, 12-polar-license-service]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Protocol-isolation for a fragile/replaceable external (LicenseService mirrors NowPlayingService)"
    - "Closure-based Result completion with a documented MAIN-thread contract (no async/await; Swift 5 language mode)"
    - "DispatchQueue.main.asyncAfter one-shot as simulated round-trip + main-thread guarantee"
    - "Service emits verdict, caller mutates state (stub stays pure; SettingsView will do the LicenseState flip in Plan 02)"
    - "In-memory-only entitlement flag (never persisted) to dodge the flippable-bool bypass"
    - "Async XCTest via XCTestExpectation + wait(for:timeout:) (new vs the repo's synchronous suites)"

key-files:
  created:
    - Islet/Licensing/LicenseService.swift
    - IsletTests/LicenseServiceTests.swift
  modified:
    - Islet/Licensing/LicenseState.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "Magic-key comparison is #if DEBUG-gated (belt-and-suspenders T-11-01): in Release every key is rejected, so the scaffold never validates in a shipped build"
  - "sessionActivated kept as a plain in-memory var (T-11-02): resets to false every launch, never written to UserDefaults/Keychain"
  - "unreachable(String) error case added now though the stub never emits it — Phase 12's network path needs zero protocol change"
  - "Stub left pure (no LicenseState mutation) so it is deterministically unit-testable; the state flip is deferred to SettingsView (Plan 02)"

patterns-established:
  - "LicenseService protocol-isolation seam: caller holds the protocol type, Phase 12 swaps the concrete conformer in one file"
  - "Async XCTestExpectation harness for closure-completion services"

requirements-completed: [TRIAL-03]

# Metrics
duration: ~20min
completed: 2026-07-05
---

# Phase 11 Plan 01: License Service Seam + Session Entitlement Summary

**Protocol-isolated StubLicenseService (DEBUG magic-key `ISLET-DEMO-OK`, ~1s main-thread async `Result` completion) plus an in-memory-only `LicenseState.sessionActivated` short-circuit to `.licensed`, with an async XCTestExpectation harness — the exact one-file swap seam Phase 12's real Polar.sh service drops into.**

## Performance

- **Duration:** ~20 min (wall time dominated by a headless test-runner host-launch hang; see Issues)
- **Completed:** 2026-07-05
- **Tasks:** 2
- **Files created/modified:** 4 (2 created, 1 modified, 1 regenerated project file)

## Accomplishments
- New `LicenseService` protocol (`AnyObject`) mirroring the `NowPlayingService` isolation precedent, with a documented "completion always on MAIN thread" contract ready for Phase 12's URLSession implementation.
- `StubLicenseService`: pure, dependency-free, validates the DEBUG-only `ISLET-DEMO-OK` key via a `DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)` one-shot; the compare is `#if DEBUG`-gated so it never validates in a Release build (T-11-01).
- `LicenseActivationError` enum carries a forward-declared `unreachable(String)` case so Phase 12 needs zero protocol change.
- `LicenseState` gained an in-memory-only `sessionActivated` flag (never persisted — T-11-02) and an `if sessionActivated { return .licensed }` short-circuit placed after the DEBUG override and before the trial computation. `isEntitled` unchanged (`.licensed → true` already held).
- `IsletTests/LicenseServiceTests.swift`: async `XCTestExpectation` harness covering the D-05 key→verdict mapping (success / invalidKey / whitespace-trim) and the D-06 async main-thread completion contract, including a test proving completion is NOT synchronous.

## Task Commits

Each task was committed atomically:

1. **Task 1: LicenseService seam + in-memory session entitlement flag** - `3c85487` (feat)
2. **Task 2: Wave 0 async LicenseService unit tests** - `7ebd79e` (test)

**Plan metadata:** committed with this SUMMARY (docs).

## Files Created/Modified
- `Islet/Licensing/LicenseService.swift` (created) - `LicenseService` protocol + `LicenseActivationError` enum + pure `StubLicenseService` conformer; header documents the main-thread contract, the DEBUG magic-key scaffold, and the Phase 12 file-deletion.
- `Islet/Licensing/LicenseState.swift` (modified) - added in-memory `sessionActivated` var and the `.licensed` short-circuit in `status`.
- `IsletTests/LicenseServiceTests.swift` (created) - async unit tests locking D-05 + D-06.
- `Islet.xcodeproj/project.pbxproj` (regenerated via `xcodegen generate`) - includes the two new source files in the build.

## Decisions Made
- **DEBUG-gated magic-key compare** (T-11-01 belt-and-suspenders): in a Release build every key is rejected, so the scaffold cannot validate even if the file were accidentally shipped before Phase 12 removes it.
- **In-memory-only `sessionActivated`** (T-11-02): a persisted bool would be a trivially flippable entitlement bypass, so entitlement is process-lifetime only.
- **Forward-declared `unreachable(String)`** error case: the stub never emits it, but its presence means Phase 12's real network path is a pure conformer swap with no protocol edit.
- **Stub kept pure** (no `LicenseState` mutation inside `activate`): keeps it deterministically unit-testable; the state flip is Plan 02's SettingsView responsibility.

## Deviations from Plan

None functionally — both files were implemented exactly to the locked contract (PATTERNS §Target shape) and the `LicenseState` edits match the specified positions. The only divergence is in **verification execution**, documented under Issues Encountered below (the host-app test cannot run headlessly in this background executor).

## Issues Encountered

**Test-runner host-launch hang under a headless background executor (environmental, not a code defect).**
- **What happened:** `xcodebuild test -scheme Islet -only-testing:IsletTests/LicenseServiceTests` runs the test bundle hosted inside the full `Islet.app` (TEST_HOST / BUNDLE_LOADER in `project.yml`). Two clean runs each ran >5 min and failed with `The test runner hung before establishing connection.` The app host launches the notch `NSPanel` overlay, the MediaRemote perl-bridge spawn, IOBluetooth and power monitors on `applicationDidFinishLaunching`; from a headless background agent (no interactive window-server session) the host never returns control to the test runner.
- **Why it is not a code defect:** `xcodebuild build-for-testing -scheme Islet` reports **`** TEST BUILD SUCCEEDED **`** — the test target and both new source files compile cleanly. The hang is at host-app runtime launch, before any test method executes.
- **Root cause is pre-existing and out of scope:** `IsletApp.swift` / `AppDelegate.swift` have **no test-mode guard** (`XCTest`/`NSClassFromString` short-circuit), so *every* host-app test in the repo boots the full notch UI and would hang the same way from a headless agent. This matches the project's established pattern (memory: "Xcode: GUI not terminal" — host tests are verified interactively). Adding a startup test-guard would touch app-boot behavior for the whole suite (Rule 4 / scope boundary — this plan's `files_modified` is only the two Licensing files + the test), so it was intentionally NOT changed here.
- **Resolution / required manual step:** Run the suite in an interactive session to go green:
  - In **Xcode**: open `Islet.xcodeproj`, select the `Islet` scheme, press **Cmd-U** (or run only `IsletTests/LicenseServiceTests`).
  - The four tests assert: `ISLET-DEMO-OK` → `.success` on `Thread.isMainThread`; `NOPE-1234` → `.failure(.invalidKey)`; `"  ISLET-DEMO-OK \n"` → `.success` (trimming); and that completion is asynchronous (a flag is still `false` immediately after `activate` returns).

## Manual Verification Required
- [ ] Run `IsletTests/LicenseServiceTests` in Xcode (Cmd-U) and confirm all 4 tests pass — the D-05/D-06 gate could not be executed headlessly in the background executor (see Issues). Code compiles cleanly (`TEST BUILD SUCCEEDED`).

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- The `LicenseService` seam, `LicenseActivationError`, `StubLicenseService`, and `LicenseState.sessionActivated` are all in place and compile — Plan 02 (SettingsView) can consume `StubLicenseService()` and flip `sessionActivated` in the success completion.
- Blocker/caveat for the wave gate: the full-suite `xcodebuild test -scheme Islet` will also hang in a headless context; run it interactively in Xcode before `/gsd:verify-work`.

## Self-Check: PASSED

- Files verified on disk: `Islet/Licensing/LicenseService.swift`, `Islet/Licensing/LicenseState.swift`, `IsletTests/LicenseServiceTests.swift`, `11-01-SUMMARY.md`.
- Commits verified in git log: `3c85487` (Task 1 feat), `7ebd79e` (Task 2 test).

---
*Phase: 11-license-settings-ui-stubbed-license-service*
*Completed: 2026-07-05*
