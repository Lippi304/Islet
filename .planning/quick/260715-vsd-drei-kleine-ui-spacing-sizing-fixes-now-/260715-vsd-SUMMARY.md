---
phase: quick-260715-vsd
plan: 01
subsystem: ui

# Dependency graph
requires:
  - phase: quick-260714-3k6
    provides: 420pt expandedSize width, tray-only shelf strip gating, mediaExpanded's `.frame(maxWidth: 322)` density cap
provides:
  - mediaExpanded's switcher-row gap shrunk from ~38pt to ~10pt (bottom padding 12 -> 40)
  - trayEmptyState's icon-to-text gap grown from 4pt to 9pt via nested VStack
  - NotchPillView.calendarWidth (460pt) + isCalendarPresentation + calendarFullView 4% scale-down, keeping the Calendar "+ Add" button inside the island's curved wall
  - NotchWindowController.visibleContentZone() .calendarExpanded branch mirroring the new width (geometry three-site rule)
affects: [ui, calendar, tray, now-playing]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-presentation size override: named `static let <name>Width/Size` constant + `is<Name>Presentation` boolean, mirrored across body's outer .frame ternary, blobShape's width: argument, and NotchWindowController.visibleContentZone()'s contentSize branch (the file's documented 'geometry three-site rule')"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "Worktree HEAD was stuck on a stale commit (d1fb5f6, 2026-07-08 era) despite the branch namespace check passing; the mandatory merge-base/hard-reset step (per execute-plan.md worktree_branch_check) corrected it forward to the plan's actual base commit 4173b80 (2026-07-15, includes all Phase 26-34 work) before any file was read or edited — this was a forward-only reset (d1fb5f6 is an ancestor of 4173b80), not data loss"
  - "blobShape's width: parameter must be passed in declaration order (topCornerRadius, bottomCornerRadius, alignment, width, height, shelfItems, ...) — Swift enforces keyword-argument order for parameters with defaults; a first attempt placing width: after showSwitcher: failed to compile"

patterns-established: []

requirements-completed: []

# Metrics
duration: 20min
completed: 2026-07-15
---

# Quick Task 260715-vsd: Three UI Spacing/Sizing Fixes Summary

**Shrunk the Now Playing switcher-row gap, added breathing room in the Tray empty state, and widened the Calendar box (+scaled its content 4%) so the "+ Add" button no longer clips past the island's curved edge.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-07-15T23:05:00+02:00
- **Completed:** 2026-07-15T23:08:00+02:00
- **Tasks:** 3 of 4 (auto tasks complete; checkpoint task not fully resolved — see below)
- **Files modified:** 2

## Accomplishments
- `mediaExpanded`'s content bottom padding grew 12 -> 40pt, shrinking the empty gap above the switcher-icon row from ~38pt to ~10pt without touching `switcherContentHeight` (so the switcher row's Y position stays identical across every presentation — the documented 28-04-round-5 misclick-regression invariant)
- `trayEmptyState` restructured into a nested `VStack(spacing: 9)` (icon) / `VStack(spacing: 4)` (title+subtitle), growing the icon-to-text gap by the requested ~5pt while the icon's own `.padding(.top, 24)` position is unchanged
- Calendar's "+ Add" button now renders inside the visible black shape: new `NotchPillView.calendarWidth` (460pt, +40pt over `expandedSize.width`) plus a 4% `.scaleEffect` on the calendar content, mirrored into `NotchWindowController.visibleContentZone()`'s `.calendarExpanded` branch so the click-through hit-zone stays in sync with the wider rendered box

## Task Commits

Each task was committed atomically:

1. **Task 1: Shrink the Now Playing expanded gap** - `80ca760` (fix)
2. **Task 2: Add breathing room in the Tray empty state** - `171cdba` (fix)
3. **Task 3: Widen the Calendar box and fit the Add button inside it** - `45cd22b` (fix)

**Plan metadata:** (docs commit handled by orchestrator, not this executor)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - Task 1 padding change; Task 2 nested-VStack restructure; Task 3's new `calendarWidth` constant, `isCalendarPresentation`, body frame ternary branch, and `calendarFullView`'s `blobShape(width:)` + `.scaleEffect(0.96)`
- `Islet/Notch/NotchWindowController.swift` - Task 3's `.calendarExpanded` branch in `visibleContentZone()`

## Decisions Made
- See `key-decisions` in frontmatter: the worktree-base correction (mandatory per execute-plan.md, not a deviation from the plan itself) and the `blobShape` keyword-argument-order fix.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] blobShape's `width:` keyword argument reordered to match declaration order**
- **Found during:** Task 3 build verification
- **Issue:** `blobShape(topCornerRadius:bottomCornerRadius:alignment:shelfItems:shelfVisible:showSwitcher:width:)` call order didn't match the function's declared parameter order (`width:` must precede `shelfItems:`); `xcodebuild` failed with "argument 'width' must precede argument 'shelfItems'"
- **Fix:** Moved `width: Self.calendarWidth` to immediately after `alignment: .top`, matching the function signature's declared order
- **Files modified:** Islet/Notch/NotchPillView.swift
- **Verification:** `xcodebuild build -scheme Islet -configuration Debug` -> BUILD SUCCEEDED
- **Committed in:** 45cd22b (part of Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Cosmetic compile-order fix only, no scope creep. The pre-task worktree base correction (stale HEAD -> plan's actual base commit) was mandatory setup per execute-plan.md's `worktree_branch_check`, not a plan deviation.

## Issues Encountered
- This worktree's HEAD was on a stale commit (`d1fb5f6`, dated 2026-07-08) when execution started, even though the branch-namespace check (`worktree-agent-a7226794abbde3b40`) passed — the file line numbers/content did not match the plan's `<interfaces>` section at all (e.g. `NotchPillView.swift` was 858 lines instead of the expected ~2460). Running the plan's own mandated `worktree_branch_check` Step 2 (`git merge-base HEAD 4173b80...` followed by `git reset --hard 4173b80...`) corrected this: `4173b80` is the actual tip of the `gsd-new-project-setup` branch (verified via `git merge-base --is-ancestor 67d00a6 4173b80` -> yes, confirming all Phase-34 work is included), and the stale `d1fb5f6` was confirmed to be an ancestor of `4173b80` before resetting, so no work was lost. After the reset, all file line numbers matched the plan's `<interfaces>` section exactly.

## User Setup Required
None - no external service configuration required.

## Checkpoint Status (Task 4 - not resolved by this executor run)

Per this run's explicit constraints, the final `checkpoint:human-verify` task was **not** answered inside this agent invocation. Self-verification performed instead:

- **Automated build gate:** `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` reported **BUILD SUCCEEDED** after each of the 3 tasks (80ca760, 171cdba, 45cd22b).
- **Code-level self-check:** all 4 `<done>` criteria across the 3 tasks were verified by direct inspection of the edited source (padding value, nested-VStack structure, `calendarWidth` constant + all 4 call sites listed in the plan's `key_links`).
- **Still pending:** on-device visual/interaction verification (the plan's Task 4 `<how-to-verify>` steps 1-4: Now Playing gap, Tray icon/text gap, Calendar Add-button clip + click-through, and the cross-tab switcher-row-Y-position regression check) has **not** been performed. The user will run this directly in Xcode (Cmd-R, Debug scheme) outside this agent session, per this run's instructions.

**This plan is NOT fully complete until the user performs and approves the on-device checkpoint.**

## Next Phase Readiness
- All 3 code changes are committed and build-clean; no blockers for the user's own on-device pass.
- If the on-device check finds an issue, it should be filed as a new `/gsd-quick` task (or reopen this one) rather than assumed resolved.

---
*Phase: quick-260715-vsd*
*Completed: 2026-07-15 (code changes only; on-device checkpoint pending)*

## Self-Check: PASSED

- FOUND: Islet/Notch/NotchPillView.swift
- FOUND: Islet/Notch/NotchWindowController.swift
- FOUND: 80ca760 (Task 1 commit)
- FOUND: 171cdba (Task 2 commit)
- FOUND: 45cd22b (Task 3 commit)
- Confirmed `calendarWidth` constant + `isCalendarPresentation` + body frame ternary branch + `blobShape(width:)` + `.calendarExpanded` branch in `visibleContentZone()` all present via grep
- Confirmed `.padding(.bottom, 40)` (Task 1) and `VStack(spacing: 9)` (Task 2) present via grep

## On-Device Verification: 5 Gap-Closure Rounds — CONFIRMED PASSED

The Calendar fix (Task 3) passed on-device verification on the first try. The Now Playing gap (Task 1) and Tray spacing (Task 2) required 4 further rounds before the user confirmed "passt":

- **Round 2** (`727ba72`): Replaced round-1's guessed `.padding(.bottom, 40)` on `mediaExpanded` with a `Spacer(minLength:)`, and grew `trayContentHeight` 128→133 to match round 1's trayEmptyState spacing growth. On-device result: no visible change on either.
- **Round 3** (`d6c27b8`): Diagnosed that a `Spacer` inside `content()` cannot move the switcher row (its Y position is fixed entirely by the shared box-height constant, not by content's internal layout) — removed the ineffective Spacers. Also corrected a mistranslation: the original request "Text muss 5pt höher" meant "move text up" (more distance from the switcher row), not "add more space below the icon" — round 1 had pushed the text the wrong direction. Tightened `trayEmptyState`'s icon-to-text spacing 9pt→2pt.
- **Debug session** (`.planning/debug/resolved/tray-spacing-fix-not-applying.md`, commits `32def20`/`6439e8f`): user reported literally zero visual change across all 3 rounds even after a full quit + Clean Build Folder + rebuild. Root cause: `NotchWindowController.seedDebugShelfItems()` re-seeded 3 hardcoded demo files into the shelf on every Debug launch with no guard, so `trayEmptyState` was never actually reachable — every round's spacing edits were invisible by construction, not a build/cache issue. Fixed with a one-time `UserDefaults` seed guard.
- **Round 4** (`568079c`): Now that `trayEmptyState` was confirmed reachable, round 3's 2pt spacing delta was confirmed too subtle to notice. Went more assertive: spacing 2pt→0pt, `trayContentHeight` 133→145pt. User confirmed Tray fixed.
- **Round 5** (`2c7904f`): User correction — the switcher row is NOT actually pinned to one shared height across all 4 tabs; Tray (`trayContentHeight`) and Weather (`weatherMediumContentHeight`/`weatherLargeContentHeight`) already have their own shorter, content-hugging overrides, shipped through Phase 32/33 with no misclick regression. Added `homeContentHeight` (170pt) and applied it to `homeEmptyState`, `mediaExpanded`, and `mediaUnavailable` (one shared value across all three so the switcher row doesn't jump when music starts/stops while on the Home tab), replacing the generic 196pt `switcherContentHeight` box for all of Home's sub-states.

**User confirmation:** "passt" (2026-07-16).

**Final state of the touched constants:** `trayContentHeight = 145` (was 128), `homeContentHeight = 170` (new), `trayEmptyState`'s icon-to-text `VStack(spacing: 0)` (was 4).
