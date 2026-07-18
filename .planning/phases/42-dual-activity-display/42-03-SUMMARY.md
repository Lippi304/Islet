---
phase: 42-dual-activity-display
plan: 03
subsystem: ui
tags: [swiftui, matchedgeometryeffect, dynamic-island, view-layer]

# Dependency graph
requires:
  - phase: 42-01
    provides: "SecondaryActivity enum + resolveSecondary(primary:nowPlaying:) + IslandPresentationState.secondary"
provides:
  - "secondaryBubble(_:) — the round bubble view for SecondaryActivity"
  - "artThumbnailCircular(_:diameter:) — circular artwork thumbnail helper"
  - "onSecondaryTap closure property"
  - "Bubble composed as a sibling in body's ZStack, offset 220pt right of notch center"
affects: [42-04-dual-activity-display]

# Tech tracking
tech-stack:
  added: []
  patterns: ["two simultaneous matchedGeometryEffect shapes in one frame, distinct namespace ids"]

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "liquidGlassEffectLayer(shape:...) is typed to concrete NotchShape (legacy branch reads shape.topCornerRadius/bottomCornerRadius directly, LiquidGlassRimRingShape stores a NotchShape base) — cannot accept Circle(). The bubble instead applies the native macOS 26 .glassEffect(.regular.tint(...)) directly against Circle(), full-fill rather than rim-only-band, since a thin rim would be barely visible at 24pt. No legacy (<26) glass variant exists for the bubble specifically (documented ponytail-style as an intentional gap, not a regression, since this build machine is already macOS 26)."
  - ".offset(x: 220) used for positioning per plan's first-attempt instruction; flagged by 42-RESEARCH.md as unverified in this specific top-level ZStack context (distinct from the documented 39-07 nested-ZStack offset failure) — needs Xcode Preview / on-device confirmation this agent cannot perform"

requirements-completed: [DUAL-01]

# Metrics
duration: 15min
completed: 2026-07-18
---

# Phase 42 Plan 03: Secondary Bubble View Summary

**`secondaryBubble(_:)` + `artThumbnailCircular(_:diameter:)` added to `NotchPillView.swift` — a round, circularly-cropped-artwork bubble with its own `matchedGeometryEffect` id, composed as a sibling to `presentationSwitch` (never a case inside it), positioned 220pt right of the notch center via `.offset(x:)`.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-18T21:35:00Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- `secondaryBubbleDiameter` (24pt) and `secondaryBubbleGap` (8pt) constants added below `wingsLabelWidth`
- `onSecondaryTap: () -> Void = {}` closure property added, matching `onClick`'s exact declaration style
- `artThumbnailCircular(_:diameter:)` added directly below `artThumbnail(_:side:corner:)` — same nil-fallback structure with `Circle()` in place of `RoundedRectangle`
- `secondaryBubble(_:)` added — switches on `SecondaryActivity` (currently one case, `.nowPlaying`), builds a `Circle().fill(islandFill)` with `matchedGeometryEffect(id: "secondaryBubble", in: ns)` (preceding `.frame`, per this file's 3x-documented ordering rule), a glass overlay, the circular artwork overlay, and `.onTapGesture { onSecondaryTap() }`. No `.onHover` anywhere (D-13).
- Bubble composed as a sibling to `presentationSwitch` inside `body`'s `ZStack(alignment: .top)`, conditioned on `if let secondary = presentationState.secondary`, with `.offset(x: 220)` and `.transition(.scale.combined(with: .opacity))`
- New `#Preview("Secondary Bubble")` hand-seeds a `.calendarCountdown` primary + `.nowPlaying` secondary to enable visual verification
- `presentationSwitch`'s own switch statement (lines 716-757) confirmed byte-identical before/after via direct diff — ROADMAP success criterion 4 held

## Task Commits

1. **Task 1: artThumbnailCircular + secondaryBubble + onSecondaryTap** - `861f837` (feat)
2. **Task 2: Compose secondaryBubble into body's ZStack** - `b42b195` (feat)

**Plan metadata:** (this commit, following SUMMARY.md creation)

## Files Created/Modified

- `Islet/Notch/NotchPillView.swift` — `secondaryBubbleDiameter`/`secondaryBubbleGap` constants, `onSecondaryTap` property, `artThumbnailCircular(_:diameter:)`, `secondaryBubble(_:)`, `secondaryBubbleGlassOverlay`, composition into `body`, `#Preview("Secondary Bubble")`

## Decisions Made

- `liquidGlassEffectLayer(shape:...)`'s NotchShape-specific typing meant it could not be reused verbatim for a `Circle()` as the plan literally described (Rule 3 — blocking compile issue, see Deviations below).
- Kept `.offset(x: 220)` as the plan's specified first attempt rather than pre-emptively switching to the HStack fallback, since this ZStack context differs from the documented 39-07 failure mode and the plan explicitly wants the simpler approach tried first.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking compile issue] `liquidGlassEffectLayer(shape:...)` cannot accept `Circle()`**
- **Found during:** Task 1
- **Issue:** The plan's action specified `.overlay(liquidGlassEffectLayer(shape: Circle(), size: ..., parameters: .expanded))`, but `liquidGlassEffectLayer` is typed to the concrete `NotchShape` struct (its legacy pre-macOS-26 branch reads `shape.topCornerRadius`/`shape.bottomCornerRadius` directly as stored properties, and the private `LiquidGlassRimRingShape` helper stores a `NotchShape` base) — `Circle()` does not type-check there. Genericizing that whole subsystem (4+ existing call sites, 2 files, a Metal shader pipeline) for one 24pt bubble would be a much larger diff than this plan's scope.
- **Fix:** Added a small dedicated `secondaryBubbleGlassOverlay` computed property that applies the same native macOS 26 `.glassEffect(.regular.tint(Color.black.opacity(0.35)), in: Circle())` API directly (which IS generic over `Shape`), filling the whole circle instead of extracting a rim-only band (a full-fill tint is the natural look at this size; a thin rim would be nearly invisible on a 24pt circle). No legacy (<26) variant exists for the bubble specifically — this build machine is already macOS 26 (Tahoe), matching this file's own established precedent that the native branch is what actually executes here.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Commit:** `861f837`

Otherwise the plan was executed exactly as written.

## Issues Encountered

- The plan's Task 2 `<verify>` calls for confirming the bubble's `.offset(x: 220)` positioning via an Xcode `#Preview` — this agent has no GUI access to actually render and visually inspect that Preview. The `#Preview("Secondary Bubble")` block was added per the plan's spec (hand-seeding `.calendarCountdown` primary + `.nowPlaying` secondary), and the build compiles clean, but the visual confirmation that the bubble lands 220pt right of center with a non-overlapping gap (as opposed to reproducing the documented 39-07 `.offset()` symptom in this different ZStack context) is still owed to the user. If the offset proves broken on real inspection, the code comment at the composition site documents the HStack(spacing: secondaryBubbleGap) fallback per 42-UI-SPEC.md.

## User Setup Required

None — no external service configuration required. Recommended: open `NotchPillView.swift` in Xcode and view the "Secondary Bubble" Preview (Editor > Canvas) to confirm the bubble renders to the right of the countdown wing with a visible gap and no overlap, per this plan's own verification step.

## Next Phase Readiness

- `secondaryBubble(_:)`, `artThumbnailCircular(_:diameter:)`, and `onSecondaryTap` are live exactly as specified in this plan's `<interfaces>`/output — Plan 42-04 (controller wiring: widening the click-through hot-zone to cover the bubble's tap target, and wiring `onSecondaryTap` to real behavior) can consume them without further exploration.
- **Recommended before Plan 42-04:** open the "Secondary Bubble" Preview in Xcode to confirm the `.offset(x: 220)` positioning visually — if it reproduces the 39-07 symptom, switch to the documented HStack fallback before wiring the tap target's geometry in 42-04.
- No blockers.

---
*Phase: 42-dual-activity-display*
*Completed: 2026-07-18*
