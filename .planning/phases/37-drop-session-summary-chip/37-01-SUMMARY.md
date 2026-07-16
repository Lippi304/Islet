---
phase: 37-drop-session-summary-chip
plan: 01
subsystem: shelf
tags: [swift, foundation, pure-functions, tdd, resolver, shelf]

# Dependency graph
requires:
  - phase: 19-shelf-data-model
    provides: ShelfCoordinator/ShelfItem/ShelfLogic/ShelfFileStore data-and-lifecycle stack
  - phase: 18-song-change-toast
    provides: songChangeToastGate's 3-input suppression-gate shape mirrored here
provides:
  - "ShelfCoordinator.sessionFilesSaved gross per-session drop counter (survives remove()/clear())"
  - "ShelfCoordinator.resetSession() atomic read-and-zero claim contract"
  - "IslandResolver.dropSessionChipGate(activeTransient:isExpanded:) pure suppression gate"
  - "ShelfViewState.SessionSummaryChip struct + dropSessionChipContent(count:) pure content seam"
  - "ShelfViewState.sessionSummaryChip @Published field for controller wiring"
affects: [37-02-view-rendering, 37-03-controller-wiring]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Gross vs. net counter: sessionFilesSaved increments on append but is immune to remove()/clear(), mirroring D-03's requirement that a mid-session delete never under-reports what the user actually dropped"
    - "Atomic read-and-zero via resetSession() — captures into a local before mutating, so no caller can observe a torn read/clear state"
    - "2-input pure suppression gate mirroring songChangeToastGate's shape, minus the Settings-toggle param this chip doesn't have"

key-files:
  created: []
  modified:
    - Islet/Shelf/ShelfCoordinator.swift
    - IsletTests/ShelfCoordinatorTests.swift
    - Islet/Notch/IslandResolver.swift
    - IsletTests/IslandResolverTests.swift
    - Islet/Shelf/ShelfViewState.swift
    - IsletTests/ShelfViewStateTests.swift

key-decisions:
  - "dropSessionChipGate takes only 2 params (activeTransient, isExpanded), not 3 — no Settings toggle exists for this chip, so D-06's 'identical shape' claim covers only the shared pair with songChangeToastGate"
  - "sessionSummaryChip.count stays a raw Int — pluralization ('1 file saved' vs 'N files saved') deferred to Plan 02's view layer"

patterns-established:
  - "Pure-seams-first: this plan adds zero AppKit/SwiftUI, zero controller wiring — later waves (rendering, controller) consume these exact 3 artifacts"

requirements-completed: [HUD-07]

# Metrics
duration: 25min
completed: 2026-07-17
---

# Phase 37 Plan 01: Shelf-Session-Boundary Prerequisites Summary

**Added the gross per-session drop counter, its atomic reset contract, and the two pure suppression/content seams the drop-session summary chip's rendering and controller wiring will consume in later waves — zero AppKit, zero SwiftUI, zero controller code.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-07-17T00:19Z (approx, first test run)
- **Completed:** 2026-07-17T00:25Z (approx)
- **Tasks:** 2/2 completed
- **Files modified:** 6

## Accomplishments

- `ShelfCoordinator.sessionFilesSaved`/`resetSession()` — a gross counter that survives `remove()`/`clear()` (D-03), claimed atomically by a single caller (D-02)
- `IslandResolver.dropSessionChipGate(activeTransient:isExpanded:)` — pure suppression gate mirroring `songChangeToastGate`'s shape (D-06)
- `ShelfViewState.SessionSummaryChip`/`dropSessionChipContent(count:)`/`sessionSummaryChip` — pure content derivation (zero-drop session renders no chip) plus the `@Published` field the controller will set

## Task Commits

Each task followed the TDD RED→GREEN cycle:

1. **Task 1: ShelfCoordinator gross session counter (D-02/D-03)**
   - RED: `0e933ec` (test)
   - GREEN: `ccfcb8c` (feat)
2. **Task 2: Suppression gate + content-derivation pure seams (D-05/D-06)**
   - RED: `1617f60` (test)
   - GREEN: `8972763` (feat)

## Files Created/Modified

- `Islet/Shelf/ShelfCoordinator.swift` — `sessionFilesSaved` stored property + `resetSession()` method
- `IsletTests/ShelfCoordinatorTests.swift` — 5 new tests covering append-increment, duplicate-reject, remove/clear survival, atomic reset
- `Islet/Notch/IslandResolver.swift` — `dropSessionChipGate(activeTransient:isExpanded:)` top-level function
- `IsletTests/IslandResolverTests.swift` — 4 new tests covering charging/device/expanded suppression + ambient-allow
- `Islet/Shelf/ShelfViewState.swift` — `SessionSummaryChip` struct, `dropSessionChipContent(count:)` function, `sessionSummaryChip` `@Published` field
- `IsletTests/ShelfViewStateTests.swift` — 2 new tests covering zero-count-nil and positive-count-chip

## Decisions Made

- `dropSessionChipGate` intentionally has 2 params, not 3 (no Settings toggle for this chip) — per plan's explicit instruction, deviating in shape from `songChangeToastGate`'s 3-param signature while matching its 2-input suppression logic exactly.
- No deviations beyond what the plan itself specified.

## Deviations from Plan

None — plan executed exactly as written. Both tasks followed the TDD RED→GREEN cycle exactly as specified (`<behavior>` tests written first and confirmed failing via compile error, then `<action>` implemented to green).

## Verification

- `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/ShelfCoordinatorTests` — 12/12 passed (5 new + 7 pre-existing, no regression)
- `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/IslandResolverTests -only-testing:IsletTests/ShelfViewStateTests` — 64/64 passed (57 IslandResolverTests incl. 4 new + 7 ShelfViewStateTests incl. 2 new, no regression)
- `xcodebuild build -scheme Islet -destination 'platform=macOS'` — BUILD SUCCEEDED (full-project regression check)
- All acceptance-criteria greps confirmed: `sessionFilesSaved` count=5, `func resetSession` count=1, `func dropSessionChipGate` count=1, `struct SessionSummaryChip` count=1, `func dropSessionChipContent` count=1, `sessionSummaryChip` count=1
- `remove(id:)`/`clear()` method bodies confirmed byte-identical to before this task — no `sessionFilesSaved` reference inside either

## Known Stubs

None — this plan is pure logic with no rendering or controller wiring; the `sessionSummaryChip` field is correctly `nil` by default until Plan 03 wires a controller to set it.

## Self-Check: PASSED

- FOUND: Islet/Shelf/ShelfCoordinator.swift
- FOUND: IsletTests/ShelfCoordinatorTests.swift
- FOUND: Islet/Notch/IslandResolver.swift
- FOUND: IsletTests/IslandResolverTests.swift
- FOUND: Islet/Shelf/ShelfViewState.swift
- FOUND: IsletTests/ShelfViewStateTests.swift
- FOUND: 0e933ec, ccfcb8c, 1617f60, 8972763 (all in git log)
