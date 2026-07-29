---
phase: 70-file-tray-convert-button
plan: 04
subsystem: ui
tags: [swiftui, appkit, nsevent, cgeventtap, click-through, dedup]

# Dependency graph
requires:
  - phase: 70-01-file-tray-convert-button
    provides: "ImageConversionService, generalized quickActionButtonFrames geometry"
  - phase: 70-02-file-tray-convert-button
    provides: "Convert chip + format-tile row view layer"
  - phase: 70-03-file-tray-convert-button
    provides: "Controller wiring: D-06 gate fix, stage-entry dispatch, handleQuickActionConvert"
provides:
  - "Working end-to-end Convert flow: real on-device drag → format-tile pick → converted file in Tray"
  - "Correct dispatch model for any picker interaction that spans TWO separate mouse gestures (not just one drag-release)"
  - "ShelfLogic dedup keyed on (originalURL, filename), not originalURL alone"
affects: [any future picker/tray feature involving a second, drag-free click stage]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NSEvent.addGlobalMonitorForEvents never sees events delivered to the app's own window — only SwiftUI's local gesture recognizers (onTapGesture) reliably see ordinary in-app clicks. Any interaction stage reached by a second, drag-free click must dispatch from the SwiftUI gesture handler, not from the drag-release global-monitor path."
    - "syncClickThrough() is a pure recomputation from current state (interaction.isExpanded, pointerInZone, lastPointerLocation) — safe and sometimes necessary to call defensively/redundantly after a dismiss reached from an unusual call context (SwiftUI gesture callback vs. raw AppKit event callback)."

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Shelf/ShelfLogic.swift
    - IsletTests/ShelfLogicTests.swift

key-decisions:
  - "Format-tile pick dispatch lives in handleClick() (SwiftUI onTapGesture), not handleDragApproachEnd() (AppKit global .leftMouseUp monitor) — the latter structurally cannot see an ordinary click landing on the app's own window. Discovered only via on-device console tracing after two earlier fix attempts (dedup-by-time, dedup-by-position) chased the wrong mechanism."
  - "Hover-exit's 0.4s grace-collapse auto-dismiss is suppressed while presentationState.isShowingConvertFormats is true — the format-tile stage requires the pointer to travel across the card without an active OS drag pinning it in place, which the original assumption (mouse never leaves the zone before a drag-release) didn't anticipate."
  - "ShelfLogic.append's duplicate-detection key changed from originalURL alone to (originalURL, filename) — Convert legitimately produces multiple different output files from one source; the old key rejected every conversion after the first from a given source as a false-positive duplicate, silently deleting the freshly-converted file with no user-visible error."

patterns-established:
  - "Any picker/interaction design with more than one mouse gesture per resolution must route each gesture's dispatch through the mechanism that actually observes it (SwiftUI local gesture vs. AppKit global monitor vs. CGEventTap) — do not assume the mechanism that worked for gesture 1 also sees gesture 2."

requirements-completed: [D-01, D-02, D-03, D-04, D-05, D-06]

# Metrics
duration: ~5h (extensive on-device UAT iteration)
completed: 2026-07-30
---

# Phase 70: File Tray Convert Button Summary

**Convert button + 2-step format-tile picker (Drop/AirDrop/Mail/Convert row → JPG/PNG/HEIC/TIFF row) landing real ImageIO-converted files in Tray, after fixing five real bugs surfaced only by on-device UAT.**

## Performance

- **Duration:** ~5h (Task 1 automated gate: minutes; Task 2 on-device UAT: many iterative rounds)
- **Tasks:** 2 (Task 1 auto test/build gate, Task 2 human-verify checkpoint)
- **Files modified:** 3 (NotchWindowController.swift, ShelfLogic.swift, ShelfLogicTests.swift)

## Accomplishments
- Full XCTest suite + Release build gate passed before UAT began (Task 1)
- On-device UAT (Task 2) surfaced and fixed five real, distinct bugs the automated suite could not catch — all now resolved and re-verified on real hardware
- Established a reusable pattern for this codebase: any interaction spanning two separate mouse gestures must dispatch each gesture through the mechanism that actually observes it

## Task Commits

1. **Task 1: Full test suite + Release build gate** — verification-only, no commit (580 tests, 0 new failures; Release build succeeded)
2. **Task 2: On-device UAT — Convert flow (D-01..D-06)** — five fix commits during iterative UAT:
   - `bde503e` — fix: convert from item.localURL, not the transient originalURL (bug 1: silent no-op on any conversion)
   - `59748db` — fix: format-tile pick dispatch, hover-exit suppression, ShelfLogic dedup key, click-through resync (bugs 2–5)

**Plan metadata:** this commit (docs: complete plan)

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` — conversion source fixed to localURL; format-tile pick dispatch moved to handleClick(); hover-exit grace-collapse suppressed during format stage; explicit syncClickThrough() resync after tile-pick dispatch
- `Islet/Shelf/ShelfLogic.swift` — dedup key changed from `originalURL` to `(originalURL, filename)`
- `IsletTests/ShelfLogicTests.swift` — two new regression tests for the dedup key change

## Decisions Made

See `key-decisions` in frontmatter. The most consequential: routing the format-tile pick through `handleClick()` instead of the drag-release path, once on-device console tracing proved `NSEvent.addGlobalMonitorForEvents` structurally cannot observe clicks delivered to the app's own window.

## Deviations from Plan

### Auto-fixed Issues

**1. [Bug found during UAT] Convert read from the wrong ShelfItem field**
- **Found during:** Task 2, first on-device attempt (PNG→HEIC produced no file)
- **Issue:** `handleQuickActionConvert` read `item.originalURL` (the transient drag-pasteboard URL) as the ImageIO conversion source instead of `item.localURL` (the durable session copy every other handler uses)
- **Fix:** Changed the conversion source to `item.localURL`
- **Committed in:** `bde503e`

**2. [Bug found during UAT] Format-tile pick dispatched nowhere**
- **Found during:** Task 2, multiple rounds — the fix went through several wrong hypotheses (duplicate-delivery dedup by time, then by position) before on-device console tracing (`[dragEnd]`/`[click]` prints) proved `handleDragApproachEnd`'s global `.leftMouseUp` monitor never receives an ordinary click on the app's own window
- **Issue:** The format-tile stage's second click needed its own dispatch path
- **Fix:** Moved the hit-test/dispatch logic into `handleClick()` (SwiftUI's `onTapGesture`), which reliably receives every in-app click; reverted the now-unneeded dedup machinery in `handleDragApproachEnd` back to its original simple form
- **Committed in:** `59748db`

**3. [Bug found during UAT] Hover-exit auto-collapse discarded the pending drop mid-repositioning**
- **Found during:** Task 2 — moving the cursor from Convert's slot toward a tile briefly left the hoverable zone, arming a 0.4s grace-collapse that discarded everything before the click landed
- **Fix:** Suppressed the grace-collapse's collapse-and-discard behavior while `presentationState.isShowingConvertFormats` is true
- **Committed in:** `59748db`

**4. [Bug found during UAT] Converting the same source file twice silently failed**
- **Found during:** Task 2, after the above fixes — converting JPG→PNG then JPG→HEIC produced no second file
- **Issue:** `ShelfLogic.append`'s duplicate-detection keyed on `originalURL` alone rejected the second conversion as a false-positive duplicate (same source, different output), and `ShelfCoordinator.append` silently deleted the rejected file
- **Fix:** Compound dedup key `(originalURL, filename)`; added regression tests
- **Committed in:** `59748db`

**5. [Bug found during UAT] Screen-wide click-through got stuck after a Convert dispatch**
- **Found during:** Task 2, final round — after converting, the whole screen became unclickable until reopening/closing the island
- **Issue:** The tile-pick's dispatch, reached via SwiftUI's `onTapGesture`, runs in a different call context than the main row's raw-AppKit-event dispatch; `dismissExpandedImmediately()`'s own `handlePointer()` call skips its `syncClickThrough()` branch once already collapsed
- **Fix:** Added an explicit, defensive `syncClickThrough()` call right after the tile-pick dispatch
- **Committed in:** `59748db`

---

**Total deviations:** 5 auto-fixed, all found via on-device UAT (none catchable by the automated test suite — each involves real OS event delivery, real timing, or real click-through state)
**Impact on plan:** All five were necessary correctness fixes for the Convert flow's actual, on-device behavior. No scope creep — Drop/AirDrop/Mail were untouched and unaffected throughout.

## Issues Encountered

Two intermediate fix attempts (duplicate-delivery dedup by time window, then by screen position) were built, tested on-device, found insufficient, and reverted before the real root cause (wrong dispatch mechanism entirely) was identified via direct console tracing. This is documented in the git history's commit progression and is not itself a remaining concern — the final `handleClick()`-based dispatch is architecturally correct, not another heuristic.

A parallel `xcodebuild test` invocation run by the assistant briefly collided with the user's live Xcode build session (shared DerivedData, codesign conflict), producing a transient false regression (picker not opening at all) that a clean rebuild resolved. No further parallel builds were run during active on-device testing after this was identified.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Phase 70 (File Tray Convert Button) is functionally complete and on-device verified: D-01 through D-06 all confirmed working on real hardware, including the two-conversion-from-one-source edge case. Ready for phase-level verification and completion.

---
*Phase: 70-file-tray-convert-button*
*Completed: 2026-07-30*
