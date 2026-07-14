---
phase: 32-tray-widening
plan: 01
subsystem: ui
tags: [swiftui, notch-overlay, appkit-panel, layout]

# Dependency graph
requires:
  - phase: 31-shelf-consolidation-to-tray-only
    provides: shelfStripVisible gate + trayFullView/.trayExpanded as the sole file-shelf presentation, visibleContentZone() already simplified once for TRAY-01
provides:
  - Tray presentation widened to 650pt (traySize) with a content-hugging 128pt height (trayContentHeight), independent from the shared 420pt/196pt Home/Calendar/Weather box
  - 40x40pt ShelfItemView file icons (up from 28x28pt) with proportionally larger caption/trash-icon/spacing
  - All 4 geometry sync points kept in lockstep (blobShape height ternary, outer body frame, AppKit panel-frame union, visibleContentZone() click-through) — new isTrayPresentation branch pattern for any future Tray-only geometry override
  - Root-cause fix for ScrollView(.horizontal) content vertically centering when its cross-axis frame is forced taller than its content — `.frame(maxHeight: .infinity, alignment: .top)` pattern now available for any future horizontal-scroll-content top-alignment need
affects: [33-weather-widget-redesign, 34-quick-action-destination-picker]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "blobShape(fillOverride:)-style optional-parameter overrides for one-caller-only debug/behavior variance, default nil so every other caller is untouched"
    - "shelfRow(_:rowHeight:topInset:) per-caller override parameters, mirroring blobShape's existing height:-override-wins-over-showSwitcher precedent from this same plan"
    - "ScrollView(.horizontal) top-alignment fix: `.frame(maxHeight: .infinity, alignment: .top)` on the content BEFORE the ancestor's fixed .frame(height:) — prevents SwiftUI's default cross-axis centering when a ScrollView's own frame is forced taller than its content"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/ShelfItemView.swift
    - IsletTests/NotchGeometryTests.swift

key-decisions:
  - "Tray width settled at 650pt (not the plan's initial 840pt target) after 3 on-device narrowing rounds — 840 and 750 both read too wide to the user"
  - "trayShelfRowTopInset (10pt) + trayShelfRowHeight (70pt) + trayContentHeight (128pt) converged back to values close to the plan's original estimates once the real ScrollView-centering bug (not a sizing bug) was fixed in round 8 — rounds 4-5's much larger compensating numbers (20pt inset, 85pt/150pt heights) were undone once the actual mechanism was corrected"
  - "shelfRow's row-padding raised from the original 16pt to 32pt (in two on-device rounds) to give the filename caption's 8pt overhang past the 40pt icon real clearance from the shape's rounded corner — same fix applied to shelfRow's other (dormant, TRAY-01-gated) caller since the overhang math is identical for both icon sizes"

requirements-completed: [TRAY-05]

# Metrics
duration: 1h46m
completed: 2026-07-15
---

# Phase 32 Plan 01: Tray Widening Summary

**Tray widened to 650pt with 40x40pt file tiles via 4 synchronized geometry points (SwiftUI render, outer frame, AppKit panel reservation, click-through zone), plus a root-cause fix for ScrollView(.horizontal) content-centering that had been silently defeating top-clearance padding for 4 rounds.**

## Performance

- **Duration:** 1h 46m
- **Started:** 2026-07-14T22:37:19+02:00
- **Completed:** 2026-07-15T00:22:58+02:00
- **Tasks:** 3 (all plan tasks) + 8 on-device gap-closure rounds
- **Files modified:** 4

## Accomplishments

- Tray now renders at 650pt (vs 420pt Home/Calendar/Weather), 128pt content-hugging height (vs the shared 196pt `switcherContentHeight` box), with the Home/Tray/Calendar/Weather switcher row width/height branch pattern (`isTrayPresentation`) established for any future Tray-only override.
- `ShelfItemView` file icons grown 28x28pt → 40x40pt with proportionally larger caption, trash icon, and row spacing — more files visible per row than the original narrower/smaller layout, single-row `ScrollView` structure unchanged (no grid rework, per locked design).
- All 4 geometry synchronization points (blobShape's fixed-frame box, the outer body `.frame()`, `positionAndShow()`'s panel-frame union, `visibleContentZone()`'s click-through rect) kept in lockstep across the whole plan — the CR-01/CR-02 click-through class of regression this project has hit twice before did not recur.
- Root-caused and fixed a genuine SwiftUI layout bug: `ScrollView(.horizontal)` vertically centers its content by default once an ancestor forces the ScrollView's own cross-axis frame taller than its content — this had been silently absorbing every `topInset` padding bump across 4 gap-closure rounds, making the fix look like it had "no effect" until the actual mechanism (`.frame(maxHeight: .infinity, alignment: .top)`) was identified via an on-device debug-border + live-value diagnostic build.

## Task Commits

Each task was committed atomically, followed by 8 on-device gap-closure rounds (all also individually committed):

1. **Task 1: NotchPillView.swift — traySize/trayContentHeight constants, blobShape height-ternary fix, trayFullView override, outer-frame branch** - `06e960f` (feat)
2. **Task 2: NotchWindowController.swift — panel-frame union + visibleContentZone Tray branch** - `1007698` (feat)
3. **Task 3: ShelfItemView/shelfRow tile sizing + on-device CR-01 verification** - `57a541c` (feat)

**Gap-closure rounds** (on-device UAT, all part of Task 3's checkpoint verification cycle):

4. Round 1 — `0213bd1` (fix): outer body content wasn't centered within the widened (up to 840pt) AppKit panel canvas — the island rendered far-left with a mismatched click-through zone. Fixed by wrapping the existing fixed-size box in `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)`.
5. Round 2 — `b47efcc` (fix): width narrowed 840→750pt per user feedback; file tiles weren't filling/insetting into the wider card (`trayFullView`'s Group had an extra ancestor-level flex-frame wrapper that neither `calendarFullView` nor `weatherFullView` use — dropped it, `shelfRow` self-declares its own `maxWidth: .infinity` instead).
6. Round 3 — `482c0f9` (fix): width narrowed 750→650pt; filename captions were rendering past the shape's bottom edge (`shelfRowHeight`, shared with the 28x28pt-icon callers, was too short for the new 40x40pt icons) — added a `trayShelfRowHeight` per-caller override.
7. Round 4 — `15d50a2` (fix): added a `topInset` parameter to give the file-tile row deterministic top clearance from the shape's rounded corner.
8. Round 5 — `db0d999` (fix): bumped `topInset` to a deliberately large, unmissable value after the user reported zero visible change, specifically to rule in/out a stale-build theory (later disproven — the shape did visibly grow, confirming fresh builds were landing).
9. Rounds 6-7 — `926425a`, `c76a44e` (debug, later fully reverted): on-device debug-border-and-live-value diagnostic build, since 3 rounds of `topInset` changes had produced no visible top-clearance shift despite sound-looking arithmetic each time.
10. Round 8 — `68d10d3` (fix): root cause found via the diagnostic build — `ScrollView(.horizontal)`'s content vertically centers by default when an ancestor forces the ScrollView's own frame taller than its content, so every prior `topInset` bump was just growing content that got re-centered, netting to the same visible gap each round. Fixed with `.frame(maxHeight: .infinity, alignment: .top)` on the content; walked the compensating numbers back down to sane values (`trayShelfRowTopInset` 20→10, `trayShelfRowHeight` 85→70, `trayContentHeight` 150→128). All debug instrumentation removed.
11. Round 9 — `e3c8298` (debug, later fully reverted): user reported the round-8 fix was ALSO invisible ("same spot as the last 10 fixes") despite the fix being structurally sound on inspection — added a magenta fill override + on-screen build-marker text to conclusively test the stale-binary theory.
12. Round 10 — `cf4c358` (fix): stale-binary theory disproven (magenta + marker both confirmed visible on-device) — the actual, never-previously-touched bug was horizontal, not vertical: the filename caption (`.frame(maxWidth: 56)`) overhangs 8pt past the 40pt icon's own bounds on each side, and the shelf row's 16pt padding only left 8pt of real clearance next to the shape's rounded corner. Fixed by raising `shelfRow`'s row padding to 24pt; reverted all round-9 debug code.
13. Round 11 — `5c5f4cf` (fix): user confirmed round 10 was the right direction, asked for more spacing — row padding raised 24pt → 32pt.

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified

- `Islet/Notch/NotchPillView.swift` - `traySize`/`trayContentHeight`/`trayShelfRowHeight`/`trayShelfRowTopInset` constants, `blobShape()`'s height-ternary fix and shape/content wiring, `isTrayPresentation` outer-frame branch, `trayFullView`'s override call, `shelfRow(_:rowHeight:topInset:)` sizing + top-alignment fix, `shelfRow`'s row padding (16→32pt)
- `Islet/Notch/NotchWindowController.swift` - `positionAndShow()`'s `trayFrame` panel-union member, `visibleContentZone()`'s `.trayExpanded` branch
- `Islet/Notch/ShelfItemView.swift` - icon 28x28pt→40x40pt, caption `maxWidth` 44pt→56pt, trash-badge icon size + inward offset
- `IsletTests/NotchGeometryTests.swift` - `testExpandedNotchFrameCentersTraySizedContent`, updated across rounds to track the final 650x128 Tray size

## Decisions Made

- Tray width settled at 650pt after 3 narrowing rounds (840 → 750 → 650), all direct user on-device calls — the plan's original "~840pt, roughly double" target read too wide in practice.
- `trayShelfRowTopInset`/`trayShelfRowHeight`/`trayContentHeight` converged back down near the plan's original estimates once the actual ScrollView-centering bug (not a real space shortage) was fixed in round 8 — the much larger intermediate values from rounds 4-5 were compensating for a bug, not a real sizing need.
- `shelfRow`'s row-padding fix (16pt → 24pt → 32pt) was applied to the shared function (affecting both the active Tray caller and the dormant TRAY-01-gated additive-strip caller), since the filename-overhang math is identical regardless of icon size — root-cause fix at the one shared call site rather than a Tray-specific patch.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Outer body content not centered within the widened AppKit panel canvas**
- **Found during:** Task 3 on-device checkpoint (round 1 of gap-closure)
- **Issue:** `positionAndShow()`'s panel-frame union grew to include Tray's wider frame, but the outer SwiftUI body `.frame(width:...)` for every non-Tray presentation still requested only the narrower 420pt box — rendering pinned to the hosting view's origin instead of centered, while the AppKit hot-zone/click-through math stayed correctly centered, causing a visual/hit-test mismatch across every presentation (not just Tray).
- **Fix:** Wrapped the existing fixed-size outer frame in `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)`.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** On-device confirmed centered rendering across all presentations, CR-01/CR-02 trace re-run clean.
- **Committed in:** `0213bd1`

**2. [Rule 1 - Bug] shelfRow's ScrollView vertically centering content, defeating top-inset padding**
- **Found during:** Task 3 on-device checkpoint (rounds 4-8 of gap-closure)
- **Issue:** `ScrollView(.horizontal)` centers its content on the cross axis by default once an ancestor forces the ScrollView's own frame taller than the content — every `topInset` padding bump across 4 rounds was silently absorbed by re-centering instead of producing a real visible shift.
- **Fix:** `.frame(maxHeight: .infinity, alignment: .top)` on the padded content inside the ScrollView, so it reports wanting to fill all available height and top-aligns within it — removing the "smaller content in a taller box" condition that triggers centering.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** On-device debug-border diagnostic build confirmed the mechanism before the fix; user confirmed no further top-clearance complaints in the rounds after.
- **Committed in:** `68d10d3`

**3. [Rule 1 - Bug] Filename caption overhanging past the icon's bounds with insufficient row clearance**
- **Found during:** Task 3 on-device checkpoint (rounds 10-11 of gap-closure)
- **Issue:** `ShelfItemView`'s filename caption (`.frame(maxWidth: 56)`) is wider than the 40pt icon above it, overhanging 8pt on each side; the shared `shelfRow`'s 16pt row padding only left 8pt of real clearance from the shape's rounded top corner, letting the caption visibly clip past the shape's edge — this was the actual root cause of the "files sticking out of the island" complaint, misdiagnosed as a vertical/top-clearance issue for several earlier rounds.
- **Fix:** Raised `shelfRow`'s `.padding(.horizontal, 16)` to 32pt (in two on-device increments, 24pt then 32pt) so the caption gets equivalent real clearance to what the icon itself already had.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** On-device confirmed by user across two rounds ("Ja bisschen weiter nach Abstand" confirmed direction, then approved at 32pt).
- **Committed in:** `cf4c358`, `5c5f4cf`

---

**Total deviations:** 3 auto-fixed (all Rule 1 - bugs surfaced only once real on-device rendering was possible; none were scope creep, all were required to meet the plan's own `must_haves` truths about tile inset and click-through correctness).
**Impact on plan:** No scope creep — all three fixes were required to satisfy the plan's own locked truths ("Click-through hit-testing exactly matches the new wider/shorter Tray geometry", implicit tile-containment expectations). The bulk of this plan's 11 commits are iterative on-device tuning, not net-new scope.

## Issues Encountered

Two false leads were investigated and closed out before the real horizontal-overhang bug was found:

1. **ScrollView-centering top-clearance investigation (rounds 3-8):** genuinely real bug (see Deviation #2 above), correctly root-caused and fixed via an on-device debug-border + live-parameter-value diagnostic build after 3 rounds of numeric-only tweaks failed to visibly change anything.
2. **Stale-binary theory (round 9):** after the round-8 ScrollView-centering fix also appeared to produce "zero visible change" per the user's report, a magenta-fill + on-screen build-marker debug build was shipped to conclusively rule this in/out. It was ruled out — fresh builds had been landing correctly the whole time. The actual explanation was that round 8's fix was working correctly, but the user's attention (and the coordinator's re-reading of screenshots) had been on vertical clearance the whole time, when the real, never-previously-touched complaint was horizontal (filename overhang past the icon width, clipping near the shape's rounded corner) — found only once the magenta debug build made it possible to look at the geometry with fresh eyes.

Both investigations are preserved in this SUMMARY and in the commit history (rounds 6-7 and round 9 debug commits, later fully reverted) since they document real, non-obvious SwiftUI behavior (`ScrollView(.horizontal)` cross-axis centering) that's worth knowing for any future horizontal-scroll-content work in this codebase.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- TRAY-05 fully implemented and on-device verified (all checkpoint items approved, including the CR-01/CR-02 hover→expand→move-down trace with zero click-through regressions).
- The `.frame(maxHeight: .infinity, alignment: .top)` ScrollView-centering fix and the `blobShape`/`shelfRow` per-caller override-parameter pattern are both reusable precedents for Phase 33 (Weather Widget Redesign) if its extended/forecast card needs similar height-budget or ScrollView-alignment handling.
- No blockers for Phase 33 or Phase 34.

---
*Phase: 32-tray-widening*
*Completed: 2026-07-15*

## Self-Check: PASSED

All 4 modified files confirmed present on disk; all 14 task/gap-closure commit hashes confirmed present in git log.
