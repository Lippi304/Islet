---
phase: 39-volume-brightness-hud
plan: 02
subsystem: ui
tags: [swift, swiftui, resolver, tdd, pure-value-types]

# Dependency graph
requires:
  - phase: 38-focus-mode-hud
    provides: "The IslandResolver.swift extension pattern (new transient case + resolver tier + updateHead arm) proven cheaply on Focus, reapplied here for Volume/Brightness"
provides:
  - "OSDActivity.swift: a pure, Foundation-only enum (.volume/.brightness) + total mapping functions (osdVolumeActivity/osdBrightnessActivity) with clamped percent and a single-source-of-truth isMuted"
  - "IslandResolver.swift extended with ActiveTransient.osd/IslandPresentation.osd, a rank-4 collapsed-only resolver tier, and a same-category TransientQueue.updateHead arm covering both D-09 scrub refresh and D-12 cross-category instant replace"
affects: [39-03-volume-glue, 39-04-brightness-glue, 39-05-controller-wiring]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure value + total mapping function seam (Pattern 1), mirrored a third time from FocusActivity/PowerActivity"
    - "Single shared enum with inner case split (OSDActivity.volume/.brightness) instead of two separate types, so ONE TransientQueue.updateHead arm covers same-activity refresh AND cross-category instant replace"

key-files:
  created:
    - Islet/Notch/OSDActivity.swift
    - IsletTests/OSDActivityTests.swift
  modified:
    - Islet/Notch/IslandResolver.swift
    - IsletTests/IslandResolverTests.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "OSDActivity is a single enum with .volume/.brightness inner cases (not two types), per CONTEXT.md's discretion note, so the resolver's same-category updateHead match gives D-12's instant Volume<->Brightness replace for free"
  - "isMuted is the SINGLE source of truth (hardwareMuted OR percent == 0) — later view-layer plans must read this property, never re-derive the OR"

patterns-established:
  - "Rank-4 collapsed-only transient tier below Focus, NOT persistent (self-elapses), reusing TransientQueue.preempt()/enqueue() verbatim with zero changes to either"

requirements-completed: [HUD-03, HUD-04]

# Metrics
duration: 25min
completed: 2026-07-17
---

# Phase 39 Plan 02: OSDActivity + IslandResolver Extension Summary

**Pure, framework-free Volume/Brightness value type and resolver wiring — a single `OSDActivity` enum with clamped total mapping functions and a rank-4 collapsed-only `IslandResolver` tier, giving Plans 39-03 through 39-05 a locked, unit-tested contract before any CGEventTap/CoreAudio/DisplayServices glue exists.**

## Performance

- **Duration:** ~25 min
- **Tasks:** 2/2 completed
- **Files modified:** 6 (2 created, 4 modified)

## Accomplishments
- `OSDActivity.swift` — a total, Foundation-only pure value type mirroring `FocusActivity.swift`'s shape, with clamped mapping functions and a single-source-of-truth `isMuted` covering both D-03 trigger paths (hardware mute OR zero level)
- `IslandResolver.swift` extended with `.osd(OSDActivity)` on both `IslandPresentation` and `ActiveTransient`, a rank-4 collapsed-only resolver tier (D-11), and a `(.osd, .osd)` `updateHead` arm that covers BOTH D-09 (same-activity scrub refresh) and D-12 (Volume↔Brightness instant cross-category replace) with one switch arm — zero changes to `preempt()`/`enqueue()`
- Full test coverage: 8 new `OSDActivityTests` (RED→GREEN via TDD) + 4 new/extended `IslandResolverTests` cases

## Task Commits

Each task was committed atomically:

1. **Task 1: OSDActivity.swift pure value + total mapping (TDD)**
   - RED: `f8031c8` (test) — `OSDActivityTests` added, confirmed failing via `xcodebuild build-for-testing` compile failure (type doesn't exist yet)
   - GREEN: `9e1a700` (feat) — `OSDActivity.swift` implemented, build succeeds
2. **Task 2: IslandResolver.swift extension** - `d39f7b4` (feat) — `.osd` case, resolver tier, `updateHead` arm, plus 2 compiler-forced exhaustive-switch fixes

**Plan metadata:** committed separately after this SUMMARY.

_Note: Task 1 followed the RED→GREEN TDD cycle per its `tdd="true"` flag; Task 2 is `type="auto"` and committed source + tests together in one commit._

## Files Created/Modified
- `Islet/Notch/OSDActivity.swift` - Pure `OSDActivity` enum (`.volume`/`.brightness`) + `osdVolumeActivity`/`osdBrightnessActivity` total mapping functions + `isMuted`
- `IsletTests/OSDActivityTests.swift` - 8 behaviors: in-range mapping, high/low clamp for both volume and brightness, both `isMuted` trigger paths independently, brightness never muted
- `Islet/Notch/IslandResolver.swift` - `.osd(OSDActivity)` added to `IslandPresentation`/`ActiveTransient`; `resolve(...)`'s transient switch gained a rank-4 `case .osd(let o) where !isExpanded: return .osd(o)` tier below Focus; `TransientQueue.updateHead` gained a `(.osd, .osd): head = t` arm
- `IsletTests/IslandResolverTests.swift` - New: `testOSDWinsWhenCollapsed`, `testOSDFallsThroughWhenExpanded`, `testOSDPreemptsStandingFocusHead`, `testUpdateHeadReplacesOSDAcrossInnerCasesInstantly`; extended `testActiveTransientIsPersistentFlags` with the `.osd` non-persistence assertion
- `Islet/Notch/NotchWindowController.swift` - `syncActivityModels()`'s exhaustive switch over `transientQueue.head` gained a `.osd` arm (clears `chargingState.activity`, mirrors `.device`/`.focus`) — compiler-forced by adding the new `ActiveTransient` case
- `Islet/Notch/NotchPillView.swift` - `presentationSwitch`'s exhaustive switch over `IslandPresentation` gained a `.osd` arm rendering `EmptyView()` as a compiler-forced stub — mirrors the identical 38-02 precedent for `.focus`; the real HUD wing view belongs to a later plan (39-04+)

## Decisions Made
- OSDActivity is one shared enum with `.volume`/`.brightness` inner cases rather than two separate types (per plan's explicit instruction, tracing to CONTEXT.md's discretion note) — this is what makes the single `(.osd, .osd)` `updateHead` arm cover both D-09 and D-12 with zero extra logic
- `isMuted` centralizes both OR-paths in one property so no later view-layer plan re-derives the check

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking build issue] Two exhaustive switches broke after adding `.osd` to `ActiveTransient`/`IslandPresentation`**
- **Found during:** Task 2, immediately after the resolver edit, via `xcodebuild build-for-testing`
- **Issue:** `NotchWindowController.syncActivityModels()` switches exhaustively over `transientQueue.head: ActiveTransient?`; `NotchPillView.presentationSwitch` switches exhaustively over `presentation: IslandPresentation`. Both became non-exhaustive compile errors the instant `.osd` was added to their respective enums.
- **Fix:** `syncActivityModels()` gained `case .osd: chargingState.activity = nil` (mirrors the existing `.device`/`.focus` arms — not charging, so no standing charging splash). `presentationSwitch` gained `case .osd: EmptyView()` as a compiler-forced stub only, with a comment noting the real Volume/Brightness HUD wing view belongs to a later plan (39-04+). This is the EXACT SAME pattern the project's own 38-02 commit (`1ded108`) used for the equivalent `.focus` case addition — confirmed via `git log`/`git show` before applying.
- **Files modified:** `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/NotchPillView.swift`
- **Verification:** `xcodebuild build-for-testing -project Islet.xcodeproj -scheme Islet -configuration Debug` succeeded; `xcodebuild build` (plain, matching the plan's `<verify>` command) also succeeded
- **Committed in:** `d39f7b4` (part of Task 2's commit)

## Known Stubs

- `Islet/Notch/NotchPillView.swift`'s `presentationSwitch` renders `EmptyView()` for `.osd` — this is an intentional, compiler-forced placeholder (identical precedent to Focus in 38-02), not a gap in this plan's own scope. The real Volume/Brightness HUD wing view is Plan 39-04+'s responsibility per the phase's own dependency ordering; `.osd` cannot be constructed by any live code path yet (no controller wiring exists until Plan 39-05), so this stub is unreachable at runtime today.

## Self-Check: PASSED

- FOUND: Islet/Notch/OSDActivity.swift
- FOUND: IsletTests/OSDActivityTests.swift
- FOUND: Islet/Notch/IslandResolver.swift (`.osd` case present)
- FOUND: commit f8031c8 (RED)
- FOUND: commit 9e1a700 (GREEN)
- FOUND: commit d39f7b4 (Task 2)
