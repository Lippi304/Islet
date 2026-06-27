---
phase: 02-hover-expand-fullscreen-hardening
plan: 01
subsystem: ui
tags: [swift, swiftui, state-machine, geometry, fullscreen, tdd, xctest, pure-functions]

# Dependency graph
requires:
  - phase: 01-the-empty-island
    provides: "pure NotchGeometry seam (hasNotch/notchSize/notchFrame), ScreenDescriptor + selectTargetScreen in DisplayResolver, hosted IsletTests bundle with @testable import Islet"
provides:
  - "expandedNotchFrame(collapsed:expandedSize:) — pure centered+top-pinned expanded island frame (ISL-04)"
  - "InteractionPhase/InteractionEvent enums + pure nextState(_:_:) transition table (ISL-03)"
  - "NotchInteractionState ObservableObject (phase/isExpanded/isHovering) for SwiftUI binding"
  - "isTrueFullscreen(builtin:) pure predicate distinguishing fullscreen vs maximized vs clamshell (ISL-05)"
  - "shouldShow(hasTarget:hideInFullscreen:isFullscreen:) — the ONE unified visibility decision (Pattern 7, D-10 flag)"
affects: [02-02, 02-03, 02-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure-logic test seam: bug-prone choreography lives in pure CoreGraphics/Foundation functions, unit-tested in <30s before any AppKit/SwiftUI wiring exists"
    - "RED->GREEN TDD with separate committed RED (failing test) and GREEN (implementation) commits per seam"
    - "ObservableObject state holder kept thin; the transition logic is a free pure function the holder/controller calls"

key-files:
  created:
    - "Islet/Notch/NotchInteractionState.swift"
    - "Islet/Notch/FullscreenDetector.swift"
    - "IsletTests/InteractionStateTests.swift"
    - "IsletTests/FullscreenDetectorTests.swift"
    - "IsletTests/VisibilityDecisionTests.swift"
  modified:
    - "Islet/Notch/NotchGeometry.swift"
    - "IsletTests/NotchGeometryTests.swift"
    - "IsletTests/NotchPanelTests.swift"

key-decisions:
  - "isTrueFullscreen maps nil built-in to false (clamshell is NOT fullscreen; the no-target path is handled by the shouldShow AND, not by the fullscreen predicate)"
  - "shouldShow body is `hasTarget && !(hideInFullscreen && isFullscreen)` — target presence dominates; fullscreen-hide is gated by the single D-10 flag so a future Phase-6 toggle is a one-flag change"
  - "InteractionEvent models four discrete inputs (pointerEntered/pointerExited/clicked/graceElapsed) so Plan 03's monitor+timer just translates OS events into these and calls nextState"
  - "NotchPanel.swift left byte-identical this plan; only its test was renamed to document the now-conditional ignoresMouseEvents model (Plan 03 owns the real toggle)"

patterns-established:
  - "Pure test seam before AppKit wiring: NotchGeometry/FullscreenDetector import CoreGraphics only; NotchInteractionState imports Foundation only — no AppKit in this plan"
  - "Stable signatures published in PLAN <interfaces> are honored verbatim so Plans 02/03/04 wire against them without refactor"

requirements-completed: [ISL-03, ISL-04, ISL-05]

# Metrics
duration: 4min
completed: 2026-06-27
---

# Phase 2 Plan 01: Pure Interaction/Geometry/Fullscreen Seams Summary

**Four pure, unit-tested logic seams — expandedNotchFrame geometry (ISL-04), the hover/click/grace nextState machine + NotchInteractionState (ISL-03), and isTrueFullscreen + the unified shouldShow visibility decision (ISL-05) — established RED→GREEN before any AppKit/SwiftUI wiring exists.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-06-27T00:30:30Z
- **Completed:** 2026-06-27T00:34:43Z
- **Tasks:** 3
- **Files modified:** 8 (5 created, 3 modified)

## Accomplishments

- **ISL-04 — expandedNotchFrame:** pure `expandedNotchFrame(collapsed:expandedSize:)` returning a CGRect centered on the collapsed pill's midX and pinned to the top edge (AppKit bottom-left origin → top = maxY). Three green cases: origin-screen centering+top-pin, non-zero-origin (right-arrangement) screen, and the degenerate `expandedSize == collapsed.size → frame == collapsed` no-jump case.
- **ISL-03 — interaction state machine:** `InteractionPhase`/`InteractionEvent` enums + total, deterministic `nextState(_:_:)` encoding the Alcove model — hover gives an affordance but NEVER expands (D-01), only a click opens (D-02), grace defers collapse on pointer-leave (D-03). Plus `NotchInteractionState: ObservableObject` exposing `phase`/`isExpanded`/`isHovering` for SwiftUI. 15 green cases (12 transitions + hover-never-expands invariant + 3 derived-property checks).
- **ISL-05 — fullscreen + visibility:** `isTrueFullscreen(builtin:)` distinguishes true-fullscreen (built-in present but notch safe area collapsed) from merely maximized (safe area intact) from clamshell (nil → false), and `shouldShow(hasTarget:hideInFullscreen:isFullscreen:)` is the single visibility AND with the D-10 gating flag. 3 + 6 green cases (full 6-row truth table incl. the flag-OFF seam).
- **NotchPanel test retargeted:** `testPanelIsClickThrough` → `testPanelStartsClickThrough`, documenting that `ignoresMouseEvents` is now CONDITIONAL (controller flips it on hover in Plan 03) while still asserting the freshly constructed panel starts click-through. NotchPanel.swift itself untouched.
- **Full suite green:** 51 tests pass (Phase-1's 24 + 27 new), across all 7 suites. Two new source files picked up by `xcodegen generate`; project builds.

## Task Commits

Each task was committed atomically (TDD RED → GREEN):

1. **Task 1: expandedNotchFrame geometry seam (ISL-04) + NotchPanel test**
   - `98734ed` (test) — failing expandedNotchFrame cases
   - `e397ca4` (feat) — expandedNotchFrame geometry seam
   - `52a20b2` (test) — document conditional click-through in NotchPanelTests
2. **Task 2: Interaction state machine seam (ISL-03)**
   - `b32c95a` (test) — failing interaction state-machine cases
   - `76bb058` (feat) — pure interaction state machine + ObservableObject
3. **Task 3: Fullscreen predicate + unified-visibility decision (ISL-05)**
   - `de518e5` (test) — failing fullscreen predicate + visibility decision
   - `324a0fe` (feat) — pure fullscreen predicate + unified visibility decision

## Final Pure-Function Signatures (consume verbatim in Plans 02–04)

```swift
// NotchGeometry.swift (ISL-04)
func expandedNotchFrame(collapsed: CGRect, expandedSize: CGSize) -> CGRect
// x = collapsed.midX - expandedSize.width/2 ; y = collapsed.maxY - expandedSize.height (bottom-left origin)

// NotchInteractionState.swift (ISL-03)
enum InteractionPhase: Equatable { case collapsed, hovering, expanded }
enum InteractionEvent: Equatable { case pointerEntered, pointerExited, clicked, graceElapsed }
func nextState(_ current: InteractionPhase, _ event: InteractionEvent) -> InteractionPhase
final class NotchInteractionState: ObservableObject {
    @Published var phase: InteractionPhase = .collapsed
    var isExpanded: Bool { phase == .expanded }
    var isHovering: Bool { phase == .hovering || phase == .expanded }
}

// FullscreenDetector.swift (ISL-05)
func isTrueFullscreen(builtin: ScreenDescriptor?) -> Bool          // nil -> false (clamshell ≠ fullscreen)
func shouldShow(hasTarget: Bool, hideInFullscreen: Bool, isFullscreen: Bool) -> Bool
// body: hasTarget && !(hideInFullscreen && isFullscreen)
```

The `nextState` transition table (the rest are idempotent no-ops):

| from \ event | pointerEntered | pointerExited | clicked | graceElapsed |
|---|---|---|---|---|
| collapsed | hovering (D-01) | collapsed | expanded | collapsed |
| hovering | hovering | hovering (D-03 defer) | expanded (D-02) | collapsed (D-03) |
| expanded | expanded | expanded (D-03 defer) | collapsed (toggle) | collapsed (D-03) |

## Files Created/Modified

- `Islet/Notch/NotchGeometry.swift` — appended pure `expandedNotchFrame` (notchFrame/notchSize/hasNotch untouched)
- `Islet/Notch/NotchInteractionState.swift` (new) — InteractionPhase/InteractionEvent + nextState + NotchInteractionState ObservableObject
- `Islet/Notch/FullscreenDetector.swift` (new) — isTrueFullscreen + shouldShow (CoreGraphics only)
- `IsletTests/NotchGeometryTests.swift` — 3 new expandedNotchFrame cases
- `IsletTests/NotchPanelTests.swift` — testPanelIsClickThrough renamed/retargeted to testPanelStartsClickThrough
- `IsletTests/InteractionStateTests.swift` (new) — 15 cases (12 transitions + invariant + 3 derived props)
- `IsletTests/FullscreenDetectorTests.swift` (new) — 3 fullscreen-vs-maximized-vs-clamshell cases
- `IsletTests/VisibilityDecisionTests.swift` (new) — 6-row shouldShow truth table

## Decisions Made

- **nil → false in isTrueFullscreen:** an absent built-in is clamshell, not fullscreen. Keeping the predicate concerned only with "present-but-collapsed safe area" lets `shouldShow`'s `hasTarget` term own the no-target/clamshell path, so the two concerns never tangle.
- **Single gating flag in shouldShow:** `hideInFullscreen` is the one D-10 lever; default-true ships the hide, and the (true, false, true) → true case proves a future settings toggle flips behavior with no logic change.
- **Thin ObservableObject:** all decision logic stays in the free pure `nextState`; the ObservableObject only holds `phase` and derives booleans, so Plan 03 mutates state inside `withAnimation` without duplicating any branching.

## Deviations from Plan

None - plan executed exactly as written. Every new function existed in a committed RED state before its GREEN implementation; FullscreenDetector.swift and NotchGeometry.swift's new function import no AppKit; NotchPanel.swift is byte-identical to its Phase-1 state; `xcodegen generate` picked up both new source files and the project builds.

## Issues Encountered

None affecting correctness. The `xcodebuild` runs emit benign environment noise (`CoreSimulator out of date`, `com.apple.linkd.autoShortcut` connection errors) on this macOS 26 / Xcode 26 build machine; these are unrelated to the macOS test destination and all 51 tests pass.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All four seams expose the stable signatures from the PLAN `<interfaces>` block, so Plan 02 (SwiftUI morph binding), Plan 03 (NSEvent monitor + grace timer + conditional `ignoresMouseEvents`), and Plan 02-04 (NSWorkspace/AX observers feeding `isTrueFullscreen` + `shouldShow`) wire against them verbatim.
- Carry-forward: the focus/event-hijacking HIGH threat is intentionally deferred to Plan 03, where the real global NSEvent monitor and the conditional `ignoresMouseEvents` toggle land; this plan only constrains it (hover can never reach `.expanded`).
- No blockers.

## Self-Check: PASSED

All 5 created source/test files and the SUMMARY exist on disk; all 7 task commits (`98734ed`, `e397ca4`, `52a20b2`, `b32c95a`, `76bb058`, `de518e5`, `324a0fe`) are present in git history. Full suite: 51 tests, 0 failures.

---
*Phase: 02-hover-expand-fullscreen-hardening*
*Completed: 2026-06-27*
