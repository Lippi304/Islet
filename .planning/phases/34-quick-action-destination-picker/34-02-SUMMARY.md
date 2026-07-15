---
phase: 34-quick-action-destination-picker
plan: 02
subsystem: ui
tags: [appkit, nssharingservice, notch, drag-and-drop, click-through]

# Dependency graph
requires:
  - phase: 34-quick-action-destination-picker
    provides: "Plan 01's PendingDrop/IslandPresentation.quickActionPicker seam, QuickActionSharingService, NotchPillView.quickActionPickerView — this plan wires all three into the real controller"
provides:
  - "handleDragApproachEnd() branches to PendingDrop instead of auto-staging into the shelf"
  - "handleQuickActionDrop/AirDrop/Mail + discardPendingDrop + finishQuickActionSharing controller handlers, wired into makeRootView's NotchPillView(...) closures"
  - "CR-01 geometry three-site rule for .quickActionPicker: positionAndShow's panel-frame union + visibleContentZone()'s branch, both agreeing with NotchPillView.quickActionPickerContentHeight"
affects: ["34-verify-work"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Controller-owned transient state read fresh every currentPresentation() call (pendingDrop mirrors TransientQueue's own head/pending split — resolve() itself stays pure)"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/QuickActionSharingService.swift
    - IsletTests/QuickActionSharingServiceTests.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "Regenerated Islet.xcodeproj via `xcodegen generate` (Rule 3 blocking fix) — Plan 01 added QuickActionSharingService.swift/Tests but never regenerated the pbxproj, so this plan's very first build failed with 'cannot find QuickActionSharingService in scope'"
  - "Corrected SharingServicePerforming's canPerform(withItems:)/perform(withItems:) signatures to match the real NSSharingService API on this SDK ([Any]? / [Any] respectively, not both [Any]) — Plan 01's protocol didn't actually conform, a second build-blocking bug found on this same first build attempt"

patterns-established: []

requirements-completed: []  # TRAY-02/03/04 are code-complete but NOT yet human-verified — see checkpoint below. Do not mark complete until Task 3's on-device UAT is approved.

# Metrics
duration: 7min (Tasks 1-2 only; Task 3 is the pending on-device checkpoint)
completed: 2026-07-15
---

# Phase 34 Plan 02: Quick Action Destination Picker — Controller Wiring Summary

**Real drop events now store a PendingDrop and show the Drop/AirDrop/Mail picker (replacing silent auto-stage-into-shelf); Drop/AirDrop/Mail button handlers, dismiss-discard lifecycle, and the CR-01 geometry three-site rule are all wired and build-green — Task 3's on-device UAT checkpoint is the one remaining gate before TRAY-02/03/04 can be marked complete.**

## Performance

- **Duration:** ~7 min (Tasks 1-2; base commit 19:35:20 -> Task 2 commit 19:41:50)
- **Started:** 2026-07-15T19:35:20+02:00
- **Completed (Tasks 1-2):** 2026-07-15T19:41:50+02:00
- **Tasks:** 2 of 3 (Task 3 is the mandatory on-device checkpoint, not yet run)
- **Files modified:** 4

## Accomplishments
- `NotchWindowController` gained the controller-owned `pendingDrop: PendingDrop?` (read fresh every `currentPresentation()` call, mirroring `TransientQueue`'s own head/pending split) and `quickActionSharingService`
- `handleDragApproachEnd()` now stores a `PendingDrop` from the exact same `ShelfFileStore.makeSessionCopy` + `ShelfItem` construction as before, but no longer calls `shelfCoordinator.append` directly — that's deferred to the "Drop" choice
- `positionAndShow`'s panel-frame union and `visibleContentZone()`'s branch ladder both reserve/scope a `.quickActionPicker` case at `NotchPillView.quickActionPickerContentHeight` (CR-01 geometry three-site rule, same commit)
- `handleQuickActionDrop()` (TRAY-03), `handleQuickActionAirDrop()`/`handleQuickActionMail()` (TRAY-04, via `QuickActionSharingService`), `finishQuickActionSharing()` (cleanup), and `discardPendingDrop()` (D-06/D-07) are all implemented and wired into `makeRootView`'s `NotchPillView(...)` call and both existing dismiss paths (`handleHoverExit`'s grace-elapsed collapse, `handleClick`'s toggle-shut)
- Two Plan-01 build-blocking bugs found and fixed on this plan's very first build attempt (see Deviations) — `xcodebuild build` and `xcodebuild build-for-testing` are both green after Task 2

## Task Commits

Each task was committed atomically:

1. **Task 1: Pending-drop state, drop-site branch, and geometry three-site rule** - `9bfb67b` (feat)
2. **Task 2: Button handlers, dismiss/discard lifecycle, makeRootView wiring** - `7040223` (feat)

Task 3 (on-device UAT checkpoint) has NOT run — see "CHECKPOINT REACHED" below.

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` - `pendingDrop`/`quickActionSharingService` properties; `currentPresentation()`'s `resolve(...)` call gained `pendingDrop:`; `handleDragApproachEnd()`'s drop-site branch; `positionAndShow`'s `quickActionPickerFrame` union member; `visibleContentZone()`'s `.quickActionPicker` branch; `handleQuickActionDrop/AirDrop/Mail`, `finishQuickActionSharing`, `discardPendingDrop`; discard wired into `handleHoverExit`/`handleClick`; 3 new closures in `makeRootView`
- `Islet/Notch/QuickActionSharingService.swift` - `SharingServicePerforming.canPerform(withItems:)` corrected to `[Any]?` (matches real `NSSharingService` signature on this SDK; Plan 01's `[Any]` didn't conform)
- `IsletTests/QuickActionSharingServiceTests.swift` - `FakeSharingService.canPerform(withItems:)` signature updated to match
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to register Plan 01's `QuickActionSharingService.swift`/`QuickActionSharingServiceTests.swift` (never registered when Plan 01 landed)

## Decisions Made
- Placed the 5 new Quick-Action handler functions directly after `handleDragApproachEnd()` (same drop-flow neighborhood) rather than near the switcher/calendar handlers further down the file — keeps the whole drop → picker → destination flow contiguous for a future reader.
- Left `requirements-completed` empty in this summary's frontmatter (rather than listing TRAY-02/03/04) since the code is unverified on real hardware — the plan's own checkpoint gate is the authority on when these requirements are actually done.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Islet.xcodeproj never regenerated after Plan 01 added new files**
- **Found during:** Task 1's first `xcodebuild build` verification run
- **Issue:** `error: cannot find 'QuickActionSharingService' in scope` — Plan 01 created `Islet/Notch/QuickActionSharingService.swift` and `IsletTests/QuickActionSharingServiceTests.swift` on disk (its own SUMMARY claims a green build), but `Islet.xcodeproj/project.pbxproj` (this XcodeGen project's generated build manifest) was never regenerated to register them as build-file entries, so this plan's first build failed immediately on Task 1's unrelated changes.
- **Fix:** Ran `xcodegen generate` (per `project.yml`'s own stated discovery convention: "adding a new .swift file there and regenerating automatically includes it in the build"). This added exactly the 2 missing file/build-file entries — no other project structure changed.
- **Files modified:** `Islet.xcodeproj/project.pbxproj`
- **Verification:** `git diff --stat` showed a minimal 8-line diff (2 `PBXFileReference` + 2 `PBXBuildFile` + 2 group/sources-phase membership lines each); `xcodebuild build` proceeded past the "cannot find in scope" error afterward.
- **Committed in:** `9bfb67b` (Task 1)

**2. [Rule 1 - Bug] SharingServicePerforming protocol didn't actually conform to NSSharingService**
- **Found during:** Task 1's same first `xcodebuild build` run, immediately after the pbxproj fix above
- **Issue:** `error: type 'NSSharingService' does not conform to protocol 'SharingServicePerforming'` — Plan 01's protocol declared both `canPerform(withItems items: [Any]) -> Bool` and `perform(withItems items: [Any])` as non-optional-array signatures; the real `NSSharingService` API on this SDK is `canPerform(withItems: [Any]?) -> Bool` (optional) but `perform(withItems: [Any])` (non-optional) — a mixed signature Plan 01's protocol got only half right, so `extension NSSharingService: SharingServicePerforming {}` never actually compiled (Plan 01's own "build succeeded" claim in 34-01-SUMMARY.md predates this file ever being included in a real build, per Deviation 1 above — the two bugs were masking each other).
- **Fix:** Corrected `SharingServicePerforming.canPerform(withItems:)` to `[Any]?`, left `perform(withItems:)` as `[Any]` (both confirmed by the compiler's own "candidate has non-matching type" notes across two iterations); updated the test file's `FakeSharingService` fake to the same corrected signature.
- **Files modified:** `Islet/Notch/QuickActionSharingService.swift`, `IsletTests/QuickActionSharingServiceTests.swift`
- **Verification:** `xcodebuild build -scheme Islet` and `xcodebuild build-for-testing -scheme Islet` both green afterward (`** BUILD SUCCEEDED **` / `** TEST BUILD SUCCEEDED **`).
- **Committed in:** `9bfb67b` (Task 1)

---

**Total deviations:** 2 auto-fixed (both Rule 1/3 build-blocking bugs inherited from Plan 01, surfaced on this plan's first build attempt)
**Impact on plan:** Both fixes are mechanical correctness fixes with zero behavior change to this plan's own scope — no scope creep. Plan 01's "build succeeded" claim in its own SUMMARY was evidently never re-verified after `QuickActionSharingService.swift` was added (the file compiled in isolation via `swiftc` perhaps, or the claim predates a later edit) — worth a note for future plan-checker passes on this project.

## Issues Encountered
None beyond the two build-blocking bugs documented above.

## User Setup Required
None - no external service configuration required. No new dependencies installed.

## CHECKPOINT REACHED

**Type:** human-verify
**Plan:** 34-02
**Progress:** 2/3 tasks complete

### Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Pending-drop state, drop-site branch, and geometry three-site rule | `9bfb67b` | `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/QuickActionSharingService.swift`, `IsletTests/QuickActionSharingServiceTests.swift`, `Islet.xcodeproj/project.pbxproj` |
| 2 | Button handlers, dismiss/discard lifecycle, makeRootView wiring | `7040223` | `Islet/Notch/NotchWindowController.swift` |

### Current Task

**Task 3:** On-device UAT — D-08 spike, CR-01 trace, transient-interrupt-resume, Drop/AirDrop/Mail hand-off
**Status:** awaiting verification (human action required, not attempted by this executor)
**Blocked by:** Requires real hardware — dragging real files onto the physical notch, invoking the real system AirDrop share sheet / Mail.app, plugging in a real charger mid-picker. None of this can be faked or simulated by an agent.

### Checkpoint Details

Build and run Islet (Debug), then in order, per 34-02-PLAN.md Task 3:

1. **Spike (RESEARCH.md Open Question 1):** Drag a single small file onto the collapsed island from Finder. Confirm the 3-button picker appears with a correct icon+filename preview. Click "AirDrop" — confirm the real system AirDrop share sheet appears WITHOUT Islet's Dock icon appearing, WITHOUT any other app losing focus, and without the foreground app changing. Click "Mail" on a second drop — confirm Mail.app opens a new compose window with the file attached, again with no unexpected focus/activation side effects on Islet itself.
   - If either fails to appear at all (not just "no nearby device"): this is the D-09 fallback trigger — do NOT attempt D-08's key-window workaround live; flag it, set `airDropAvailable`/`mailAvailable` to `false` in `NotchPillView.swift` for the failing destination, and file a fast-follow.
2. **CR-01 click-through trace:** With the picker open, hover over each of the 3 buttons and the preview area — confirm every part of the visible card is clickable and moving the mouse DOWN past the bottom edge of the picker's visible shape does NOT register a click on whatever is behind Islet.
3. **Drop destination (TRAY-03):** Drag a file, click "Drop" — confirm it switches to Tray and the file appears there exactly as before this phase.
4. **Dismiss-without-choosing (D-06/D-07):** Drag a file, move the mouse away without clicking any button — confirm the picker grace-collapses and the file does NOT appear in Tray afterward.
5. **Transient interrupt + resume (D-04/D-05):** Drag a file so the picker opens, then plug in the charger (or connect/disconnect Bluetooth) while it's open — confirm the Charging/Device splash briefly takes over, then the SAME picker reappears with the SAME pending file once the splash clears.
6. **Ordinary hover/click regression check:** With no drop pending, confirm normal hover-to-expand, click-to-expand-collapse, and the existing switcher tabs still work exactly as before.

### Outcome: CHANGES REQUESTED (2026-07-15, on real notch hardware)

User ran the build and reported concrete issues from step 1 of the checkpoint (screenshots provided):

1. **Bug — drag-hover shows the wrong presentation.** While the file is still being dragged
   (before release), the island auto-expands via `recheckDragAcceptRegion()`'s `.dragEntered`
   transition, but `pendingDrop` is only set in `handleDragApproachEnd()` (on `.leftMouseUp`,
   i.e. after release). So during the hover, `IslandResolver.resolve()` has no pending-drop
   signal to act on and falls through to whatever else is active (observed: the Now Playing
   card for the currently-playing track) instead of any drop-affordance. The picker only
   appears AFTER the mouse is released.
2. **Product change — real drag targets, not a post-drop click picker.** On seeing the actual
   behavior, the user confirmed (after clarifying the alternative) that they want the 3
   destination buttons to already be showing DURING the drag-hover, and to be able to release
   the file directly on top of "Drop"/"AirDrop"/"Mail" as 3 independent drop targets — i.e.
   drop-target selection, not hover-then-release-then-click. This is a materially different
   interaction model than 34-CONTEXT.md's locked D-01 framing ("a full-takeover presentation...
   interactive instead of auto-dismissing" was interpreted as click-after-drop) and than this
   plan's `handleDragApproachEnd()` implementation, which only supports a single global accept
   region (`expandedZone`), not per-button hit-testing during a raw `NSEvent`-monitor-based drag
   (there is no `draggingUpdated`-equivalent — see `handleDragApproachTick()`'s own comment).
   Needs real per-button frame tracking during the drag, which nothing in RESEARCH.md/UI-SPEC.md
   covers today.
3. **Visual polish requested on the released build (Image 2):**
   - Remove the top file-preview (icon + filename) entirely — show only the 3 buttons.
   - AirDrop's icon may need a better match (current: SF Symbol `personalhotspot`).
   - The "Drop" button renders at a slightly different height than "AirDrop"/"Mail" — a
     layout inconsistency across the 3 `quickActionButton` calls.

**Decision (user, 2026-07-15):** route through a clean replan rather than patch in place —
`/gsd-discuss-phase 34` next, to properly scope the drag-target redesign (issue 2) before a
gap-closure plan is written, rather than improvising the new hit-testing mechanism live inside
this checkpoint.

**requirements-completed stays empty** — TRAY-02/03/04 are NOT complete; the click-based picker
this plan built is being superseded by the drag-target model above, pending replanning.

## Next Phase Readiness
- Code-complete for the click-based picker (build-green on both `xcodebuild build` and
  `xcodebuild build-for-testing`), but on-device UAT rejected the interaction model — see
  "Outcome: CHANGES REQUESTED" above. Do NOT mark TRAY-02/03/04 complete in REQUIREMENTS.md, and
  do NOT advance STATE.md's plan counter to phase-complete, until a follow-up gap-closure plan
  (post `/gsd-discuss-phase 34`) implements the drag-target model and a fresh on-device round
  passes.
- The 2 auto-fixed Plan-01 bugs (pbxproj registration, `SharingServicePerforming` signature) and
  the CR-01 geometry three-site wiring remain valid and should NOT be redone by the follow-up
  plan — only the interaction model (drag-hover trigger + per-button drop targets) and the 3
  visual-polish items need new work.

---
*Phase: 34-quick-action-destination-picker*
*Completed: 2026-07-15 (Tasks 1-2 only; Task 3 checkpoint pending)*

## Self-Check: PASSED
All modified files verified present on disk; both task commit hashes (`9bfb67b`, `7040223`) verified present in `git log --oneline --all`.
