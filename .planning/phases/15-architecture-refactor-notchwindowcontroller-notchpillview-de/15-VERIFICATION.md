---
phase: 15-architecture-refactor-notchwindowcontroller-notchpillview-de
verified: 2026-07-08T19:58:00Z
status: passed
score: 7/7 must-haves verified
overrides_applied: 0
---

# Phase 15: Architecture Refactor — Mechanical Fixes & DI Seams Verification Report

**Phase Goal:** Fix the audit's small, well-understood issues with no architectural risk: DRY the
duplicate frame-geometry formula (NotchGeometry.swift), extract a shared blobShape() helper in
NotchPillView.swift, protocolize LocationProvider and add its missing main-thread contract, give
LicenseState a dependency-injection seam, close the weather/calendar refresh-while-hidden gap,
persist the real Polar.sh license payload, and fix EqualizerBars' broken profile-stability
contract — all with zero unintended behavior change except the two explicit exceptions (Polar
payload widening, EqualizerBars stability fix).

**Verified:** 2026-07-08T19:58:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (7 CONTEXT.md scope items — no formal REQUIREMENTS.md exists for this phase)

| # | Truth (Item) | Status | Evidence |
|---|---------------|--------|----------|
| 1 | `NotchGeometry.swift`'s duplicate `expandedNotchFrame`/`wingsFrame` formula is DRY'd | ✓ VERIFIED | `NotchGeometry.swift:62-83` — private `topPinnedFrame(collapsed:size:)` holds the shared body; `expandedNotchFrame`/`wingsFrame` are one-line delegating wrappers with unchanged signatures. |
| 2 | `NotchPillView.swift` gets a shared `blobShape()` helper mirroring `wingsShape()`; `collapsedIsland` stays distinct; `mediaExpanded`'s tap/top-pinning invariants hold | ✓ VERIFIED | `NotchPillView.swift:220-230` defines `blobShape<Content: View>(topCornerRadius:bottomCornerRadius:alignment:content:)`. `expandedIsland` (line 195) and `mediaUnavailable` (line 564) call it with default `.center`; `mediaExpanded` (line 499) calls it with explicit `alignment: .top` and retains its own inner `.onTapGesture` (line 525) and `.padding(.top, 32)` (line 542). `collapsedIsland` (lines 170-184) is untouched — still has its own `NotchShape()`, `.fill(collapsedFill)`, `.scaleEffect(`, `.offset(y: devOffset)`. |
| 3 | `LocationProvider` is protocolized with a main-thread contract; `BasicOutfitState` is `@MainActor` | ✓ VERIFIED | `LocationProvider.swift:11-18` — `protocol LocationService: AnyObject` with a "CONTRACT — delivered on MAIN thread" doc comment; `final class LocationProvider: NSObject, CLLocationManagerDelegate, LocationService` — delegate body byte-identical to before. `BasicOutfitState.swift:7-8` — `@MainActor` added above `final class BasicOutfitState: ObservableObject`. |
| 4 | `LicenseState` gets a DI seam (protocol-typed `TrialManager`/`LicenseManager` collaborators) | ✓ VERIFIED | `LicenseState.swift:23-43` — `protocol LicenseManaging`/`protocol TrialStatusProviding`, `extension LicenseManager: LicenseManaging {}`/`extension TrialManager: TrialStatusProviding {}`, injectable `init(licenseManager:trialManager:)` with `.shared`-backed defaults. `status`/`trialExpiryDate` read through the injected collaborators (lines 77, 84, 106), not `.shared` literals. |
| 5 | The weather/calendar 15-min refresh timer respects fullscreen/license visibility gating (arbiter gap closed) | ✓ VERIFIED | `NotchWindowController.swift:239` — `isCurrentlyVisible` flag; `updateVisibility()` (517-572) sets it true/false on show/hide and fires an immediate `refreshWeather()`/`refreshCalendar()` on the hidden→visible edge (lines 552-559); the recurring timer closure guards on `self.isCurrentlyVisible` before fetching (line 439). |
| 6 | `EqualizerBars`' random-profile reshuffle-on-re-render bug is fixed | ✓ VERIFIED | `NotchPillView.swift:616` — `@State private var profiles: [...] = EqualizerBars.makeProfiles()` replaces the old stored `let` + custom-init pattern; `makeProfiles()` (line 627) is a pure static factory. Custom `init(isPlaying:tint:)` removed — call sites use the implicit memberwise init. |
| 7 | The real Polar.sh validation payload (`id`/`status`/`expiresAt`) is persisted instead of discarded | ✓ VERIFIED | `LicenseService.swift:38-48` — `struct ValidatedLicense{id,status,expiresAt}`, protocol widened to `Result<ValidatedLicense, LicenseActivationError>`. `PolarLicenseService.swift:111` — 200-branch returns `ValidatedLicense(id: validated.id, status: validated.status, expiresAt: validated.expiresAt)` (previously discarded). `KeychainLicenseStore.swift:104-105` — `recordValidation(key:validated:)` builds `LicenseRecord(... licenseID: validated.id, status: validated.status ...)` instead of hardcoded placeholders. `SettingsView.swift:174,186` — `case .success(let validated):` threads it to `recordValidation(key:..., validated: validated)`. |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/NotchGeometry.swift` | `topPinnedFrame` helper | ✓ VERIFIED | Present, backs both frame functions |
| `Islet/Notch/NotchPillView.swift` | `blobShape()` helper + `EqualizerBars` fix | ✓ VERIFIED | Both present and wired |
| `Islet/Location/LocationProvider.swift` | `LocationService` protocol + contract comment | ✓ VERIFIED | Present |
| `IsletTests/LocationServiceTests.swift` | Fake-injectable proof tests | ✓ VERIFIED | Exists, 2 test methods, compiled into `IsletTests` target (confirmed in `project.pbxproj`) |
| `Islet/Notch/NotchWindowController.swift` | `isCurrentlyVisible` gate + protocol-typed `locationProvider` | ✓ VERIFIED | Both present |
| `Islet/Licensing/LicenseState.swift` | DI seam | ✓ VERIFIED | Present |
| `IsletTests/LicenseStateTests.swift` | 5+ precedence-order tests | ✓ VERIFIED | Exists, 6 test methods, compiled into target |
| `Islet/Licensing/LicenseService.swift` | `ValidatedLicense` result type | ✓ VERIFIED | Present |
| `Islet/Licensing/KeychainLicenseStore.swift` | `recordValidation(key:validated:)` | ✓ VERIFIED | Present |
| `IsletTests/EqualizerBarsTests.swift` | `makeProfiles()` sanity tests | ✓ VERIFIED | Exists, 2 test methods, compiled into target |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `NotchGeometry.swift:expandedNotchFrame` | `topPinnedFrame(collapsed:size:)` | single-line delegating call | ✓ WIRED | `return topPinnedFrame(collapsed: collapsed, size: expandedSize)` |
| `NotchPillView.swift:expandedIsland` | `blobShape(...)` | single-line delegating call | ✓ WIRED | line 195 |
| `NotchWindowController.swift` | `LocationService` | `private let locationProvider: LocationService = LocationProvider()` | ✓ WIRED | line 93 |
| `NotchWindowController.swift:outfitRefreshTimer` | `isCurrentlyVisible` | `guard let self, self.isCurrentlyVisible else { return }` | ✓ WIRED | line 439 |
| `LicenseState.swift:status` | `licenseManager.isLicensed` / `trialManager.trialStartDate()` | injected protocol-typed collaborators | ✓ WIRED | lines 77, 84 |
| `PolarLicenseService.swift:activate` | `ValidatedLicense` | 200-branch success payload | ✓ WIRED | line 111 |
| `SettingsView.swift:activate` | `LicenseManager.recordValidation(key:validated:)` | `case .success(let validated): ...` | ✓ WIRED | lines 174, 186 |
| `NotchPillView.swift:EqualizerBars` | `makeProfiles()` | `@State private var profiles: [...] = EqualizerBars.makeProfiles()` | ✓ WIRED | line 616 |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full app + test target compiles clean after all 5 plans merged | `xcodebuild build-for-testing -project Islet.xcodeproj -scheme Islet -configuration Debug -destination 'platform=macOS'` | `** TEST BUILD SUCCEEDED **` | ✓ PASS (run directly by verifier, not sourced from SUMMARY) |
| All 3 new test files registered in Xcode project | `grep -c` on `project.pbxproj` | 12 matches (4 each: file ref, build file, group, sources phase) | ✓ PASS |
| No debt markers (TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER) in any of the 16 touched files | `grep -n -E` across all modified files | zero matches | ✓ PASS |

### Requirements Coverage

No formal `REQUIREMENTS.md` exists in this project (confirmed: file absent). The phase's coverage
unit is the 7 CONTEXT.md scope items (P15-ITEM1..P15-ITEM7), cross-referenced against each PLAN's
own `requirements:` frontmatter:

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| P15-ITEM1 | 15-01 | DRY frame-geometry formula | ✓ SATISFIED | Truth #1 |
| P15-ITEM2 | 15-01 | Extract `blobShape()` helper | ✓ SATISFIED | Truth #2 |
| P15-ITEM3 | 15-02 | Protocolize `LocationProvider` | ✓ SATISFIED | Truth #3 |
| P15-ITEM4 | 15-03 | `LicenseState` DI seam | ✓ SATISFIED | Truth #4 |
| P15-ITEM5 | 15-02 | Close weather/calendar arbiter gap | ✓ SATISFIED | Truth #5 |
| P15-ITEM6 | 15-05 | Fix `EqualizerBars` reshuffle bug | ✓ SATISFIED | Truth #6 |
| P15-ITEM7 | 15-04 | Persist real Polar.sh payload | ✓ SATISFIED | Truth #7 |

No orphaned requirements — all 7 CONTEXT.md scope items map to exactly one plan each, and all 5
plans' `requirements:` frontmatter fields are accounted for above.

### Anti-Patterns Found

None. Scanned all 16 files touched across the phase's 5 plans (production + test files) for
`TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER|not yet implemented|not available` — zero matches.

The independent code review (`15-REVIEW.md`, run earlier this session) found 2 warnings and 1 info
item, all on **pre-existing** behavior explicitly preserved by this phase's zero-behavior-change
mandate (D-01/D-02), not regressions introduced by Phase 15:

- **WR-01** (`KeychainLicenseStore.swift`/`SettingsView.swift`): a failed Keychain write is
  silently swallowed — but `SettingsView.activate()` already discarded the `@discardableResult`
  return value before this phase (confirmed against `15-04-PLAN.md`'s "current" interface
  snippet); this phase only widened what's written, not the discard behavior.
- **WR-02** (`LocationProvider.swift`): a concurrent second `requestOnce` call would silently drop
  the first caller's completion — but Plan 15-02 explicitly made "NO other change to
  LocationProvider's body" per its own acceptance criteria; this is pre-existing Phase-14 behavior.
- **IN-01** (`LocationServiceTests.swift`): one of the two new tests
  (`testLocationProviderConformsToLocationServiceProtocol`) asserts nothing beyond "the file
  compiles" — a test-quality nit, not a functional gap; the second test in the same file
  (`FakeLocationService`-based) does assert real behavior.

None of these block the phase goal — they are candidates for a future quick-fix, not Phase 15
regressions.

### Human Verification Required

None outstanding. This phase's 4 `checkpoint:human-verify` gates (Task 3 in 15-02, Task 2 in
15-03, Task 3 in 15-04, Task 2 in 15-05) are blocking gates that require the developer to type
"approved" before the workflow proceeds — they already ran during execution with documented
approval evidence in each SUMMARY.md (distinct from an executor's unilateral self-report):
- 15-02 Task 3: on-device arbiter-gap check — "approved"
- 15-03 Task 2: full-suite Cmd-U — "approved"
- 15-04 Task 3: on-device Polar activation check — "approved — activation UX unchanged, app stays unlocked, Keychain confirmed to hold real server-supplied id/status/expiresAt"
- 15-05 Task 2: on-device equalizer stability check — "verified by user, no separate commit"

### Gaps Summary

None. All 7 phase items verified directly against source (not inferred from SUMMARY.md prose).
Build compiles clean (`** TEST BUILD SUCCEEDED **`, run directly by this verifier). All 3 new test
files exist, are registered in the Xcode project, and contain the expected test counts. No debt
markers introduced. The 3 code-review findings are pre-existing conditions explicitly protected by
this phase's zero-behavior-change contract, not new regressions — informational only, not blocking.

---

_Verified: 2026-07-08T19:58:00Z_
_Verifier: Claude (gsd-verifier)_
