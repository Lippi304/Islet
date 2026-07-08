---
phase: 15-architecture-refactor-notchwindowcontroller-notchpillview-de
plan: 05
subsystem: ui
tags: [swiftui, state, equalizer, notch-pill]

# Dependency graph
requires:
  - phase: 15-01
    provides: "blobShape() extraction from NotchPillView.swift (this plan's edits land after it to avoid a same-file merge conflict)"
provides:
  - "EqualizerBars.profiles seeded once per view identity via @State + EqualizerBars.makeProfiles(), fixing a visible bar-reshuffle-on-every-re-render bug"
  - "IsletTests/EqualizerBarsTests.swift sanity tests on the extracted factory"
affects: [16-notchwindowcontroller-coordinator-extraction]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SwiftUI struct View random/derived per-identity state: seed via @State's initial-value expression (evaluated once per view identity), never a plain stored `let` computed in a custom init (re-runs on every parent re-render)."

key-files:
  created:
    - IsletTests/EqualizerBarsTests.swift
  modified:
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "EqualizerBars.makeProfiles() made internal (not private, as the plan's action text literally specified) — private is file-scoped in Swift and would not compile from EqualizerBarsTests.swift even under @testable import; this is required for the plan's own acceptance criteria (test file calling the factory) to be satisfiable at all."

patterns-established:
  - "makeProfiles()-style pure static factories for @State initial values: keeps SwiftUI's re-render immunity testable via plain XCTest, no ViewInspector/hosting needed."

requirements-completed: [P15-ITEM6]

# Metrics
duration: ~25min
completed: 2026-07-08
---

# Phase 15 Plan 05: EqualizerBars Re-render Stability Fix Summary

**EqualizerBars' random per-bar profile moved from a stored `let` (re-rolled every parent re-render) to `@State`, seeded once per view identity via a new `EqualizerBars.makeProfiles()` factory — confirmed visually stable on-device.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-07-08T17:12:00Z (approx, from worktree base)
- **Completed:** 2026-07-08T17:46:00Z
- **Tasks:** 2 (1 auto, 1 checkpoint:human-verify)
- **Files modified:** 3 (2 source, 1 xcodeproj)

## Accomplishments
- Fixed the audit's one confirmed rendering bug: the equalizer bars' random height/period/phase profile no longer reshuffles on every Now Playing position tick (previously re-rolled every parent `body` pass because `EqualizerBars` is a plain `struct View` and its custom `init` re-ran `CGFloat.random` on every reconstruction).
- Doc comment above `EqualizerBars` now accurately describes the `@State` mechanism that delivers the stability it always claimed.
- Added `IsletTests/EqualizerBarsTests.swift` sanity-checking `makeProfiles()`'s count and value ranges.
- On-device checkpoint confirmed: stable bar pattern across ~30s, across hover/expand toggles, and pause still freezes bars flat with idle CPU back to ~0 (D-04 unaffected).

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix EqualizerBars re-render reshuffle via @State + makeProfiles()** - `fa5940e` (fix)
2. **Task 2: On-device equalizer stability check** - checkpoint, no code changes; verified by user, no separate commit

**Plan metadata:** (this commit) `docs: complete 15-05 plan`

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - `EqualizerBars.profiles` changed from stored `let` + custom init to `@State private var profiles = EqualizerBars.makeProfiles()`; new `static func makeProfiles()` factory; doc comment updated to explain the `@State`-per-identity mechanism
- `IsletTests/EqualizerBarsTests.swift` - new file, 2 test methods: profile count == `barCount` (5), and value-range checks on `low`/`high`/`period`/`phase`
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to register the new test file

## Decisions Made
- Made `makeProfiles()` `internal` instead of `private` as the plan's action text literally specified. Swift's `private` is file-scoped (not just type-scoped) — a `private` static member is not visible from `EqualizerBarsTests.swift`, a different file, even under `@testable import`. The plan's own acceptance criteria required the test file to call `EqualizerBars.makeProfiles()` directly, which is only satisfiable with `internal` (or looser) access. Documented as a Rule 3 auto-fix below.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `makeProfiles()` access level widened from `private` to `internal`**
- **Found during:** Task 1 (writing `EqualizerBarsTests.swift`)
- **Issue:** Plan's action text specified `private static func makeProfiles()`, but its own acceptance criteria required a test in a separate file (`IsletTests/EqualizerBarsTests.swift`) to call it directly. `private` in Swift is file-scoped; `@testable import` elevates `internal` access, not `private`/`fileprivate` file-scoping. As literally specified, the plan's two requirements (private access + external test call) were mutually unsatisfiable — `xcodebuild build-for-testing` would fail to compile.
- **Fix:** Dropped the `private` modifier, making `makeProfiles()` `internal` (default access), matching the struct's own access level. Left a comment explaining why.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** `xcodebuild build-for-testing -project Islet.xcodeproj -scheme Islet -configuration Debug -destination 'platform=macOS'` succeeded (TEST BUILD SUCCEEDED).
- **Committed in:** `fa5940e` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to make the plan's own stated acceptance criteria buildable at all. No scope creep — access level only, no behavior change beyond what the plan intended (call sites, `barCount`, `boxHeight`, `height(_:at:)`, and `body` all untouched).

## Issues Encountered
None beyond the deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Item 6 (P15-ITEM6) closed; EqualizerBars' stability guarantee now matches its doc comment and is regression-covered by `EqualizerBarsTests.swift`.
- No blockers for Phase 16 (NotchWindowController coordinator extraction) — this plan touched only `NotchPillView.swift`'s `EqualizerBars` struct, not `NotchWindowController`.

---
*Phase: 15-architecture-refactor-notchwindowcontroller-notchpillview-de*
*Completed: 2026-07-08*
