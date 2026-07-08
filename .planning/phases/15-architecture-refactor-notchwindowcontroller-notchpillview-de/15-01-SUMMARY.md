---
phase: 15-architecture-refactor-notchwindowcontroller-notchpillview-de
plan: 01
subsystem: ui
tags: [swiftui, refactor, notch-geometry, dry]

# Dependency graph
requires: []
provides:
  - "topPinnedFrame(collapsed:size:) shared geometry helper in NotchGeometry.swift"
  - "blobShape(topCornerRadius:bottomCornerRadius:alignment:content:) shared SwiftUI helper in NotchPillView.swift"
affects: [15-architecture-refactor-notchwindowcontroller-notchpillview-de]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Private helper extraction for byte-identical duplicate code (mirrors existing wingsShape(content:) precedent)"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchGeometry.swift
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "blobShape gained an alignment parameter (default .center) instead of hardcoding .center, so mediaExpanded's camera-clearance .top pinning survives the extraction unchanged"
  - "collapsedIsland intentionally excluded from blobShape (DEBUG tint, hover scale, dev offset make it not a clean fit per CONTEXT.md)"

patterns-established:
  - "Pure structural DRY extractions (zero behavior change) verified via existing test suite / DEBUG #Preview compile gate rather than new tests"

requirements-completed: [P15-ITEM1, P15-ITEM2]

# Metrics
duration: 12min
completed: 2026-07-08
---

# Phase 15 Plan 01: Mechanical DRY Extractions Summary

**Collapsed two independent byte-for-byte code duplications (frame-geometry math in NotchGeometry.swift, blob-shape SwiftUI chain in NotchPillView.swift) into shared private helpers with zero output change.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-07-08
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `topPinnedFrame(collapsed:size:)` now backs both `expandedNotchFrame` and `wingsFrame`, eliminating the duplicate x/y formula while keeping both public signatures byte-identical.
- `blobShape(topCornerRadius:bottomCornerRadius:alignment:content:)` now backs `expandedIsland`, `mediaExpanded`, and `mediaUnavailable`, eliminating the duplicate `NotchShape → .fill → .matchedGeometryEffect → .frame → .overlay → .onTapGesture` chain (mirrors the existing `wingsShape(content:)` precedent, "Finding 12").
- `mediaExpanded`'s camera-clearance top-pinning (`alignment: .top`) is preserved explicitly through the new `alignment` parameter — confirmed by grep and by the passing build.
- `collapsedIsland` was left completely untouched, per its documented "not a clean fit" exclusion (DEBUG tint, hover scale, dev offset).

## Task Commits

Each task was committed atomically:

1. **Task 1: DRY expandedNotchFrame/wingsFrame via topPinnedFrame** - `daed80f` (refactor)
2. **Task 2: Extract blobShape() for expandedIsland/mediaExpanded/mediaUnavailable** - `ce0ba35` (refactor)

_No TDD — pure structural refactor with existing regression gates (NotchGeometryTests.swift, DEBUG #Preview compile checks)._

## Files Created/Modified
- `Islet/Notch/NotchGeometry.swift` - added private `topPinnedFrame(collapsed:size:)`; `expandedNotchFrame`/`wingsFrame` now one-line delegating wrappers
- `Islet/Notch/NotchPillView.swift` - added private `blobShape<Content: View>(topCornerRadius:bottomCornerRadius:alignment:content:)`; `expandedIsland`/`mediaExpanded`/`mediaUnavailable` rewritten to call it

## Decisions Made
- Gave `blobShape` an `alignment: Alignment = .center` parameter (not present in the plan's `wingsShape` analog) specifically so `mediaExpanded` could pass `.top` explicitly and preserve its camera-clearance pinning byte-for-byte — this was the plan's own called-out nuance, not a new decision, but recorded here since it's the one meaningful design choice in an otherwise mechanical extraction.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Verification

- `xcodebuild build-for-testing -project Islet.xcodeproj -scheme Islet -configuration Debug -destination 'platform=macOS'` succeeded after both tasks (confirmed twice: once after Task 1, once after Task 2 — includes compiling all 8 `#Preview` blocks in NotchPillView.swift and the `IsletTests` target).
- Source-level acceptance criteria confirmed via diff review: `topPinnedFrame` private func present with correct signature; `expandedNotchFrame`/`wingsFrame` are single-line delegating calls; `blobShape` attaches `.overlay(alignment: alignment) { content() }` (trailing-closure form, not a bare value); `expandedIsland`/`mediaUnavailable` call `blobShape(...)` with no explicit `alignment:` (defaults to `.center`); `mediaExpanded` calls `blobShape(..., alignment: .top)` explicitly and still contains its own inner `.onTapGesture { onClick() }` on the top HStack and `.padding(.top, 32)`; `collapsedIsland` untouched (`NotchShape()`, `.fill(collapsedFill)`, `.scaleEffect(`, `.offset(y: devOffset)` all still present).
- Manual on-device / Xcode-canvas checks (13 `NotchGeometryTests.swift` cases via Cmd-U; visual camera-clearance check in the "Media Expanded" preview) were **not run by this agent** — they require Xcode GUI interaction, per this plan's own verification notes and project memory (`xcodebuild-test-headless-hang`, `feedback-xcode-gui-not-terminal`). The automated `build-for-testing` gate (which compiles the test target and all previews) passed, which is the scriptable proxy the plan itself specifies.

## Next Phase Readiness

Plan 15-01 is code-complete and build-verified. The two remaining manual checks (NotchGeometryTests Cmd-U run, camera-clearance visual check in Xcode canvas) are recommended before/alongside the next plan's on-device verification pass, consistent with this project's established "automated build is the gate, Cmd-U is manual" convention.

---
*Phase: 15-architecture-refactor-notchwindowcontroller-notchpillview-de*
*Completed: 2026-07-08*
