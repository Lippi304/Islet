---
phase: 61-download-progress
plan: 03
subsystem: ui
tags: [swiftui, wingsShape, notchpillview, download-progress]

# Dependency graph
requires:
  - phase: 61-download-progress (Plan 01)
    provides: DownloadActivity.swift (.inProgress/.done(filename:)) and IslandPresentation.downloadProgress case, rank-5 in the resolver, with the presentationSwitch EmptyView() placeholder this plan replaces
provides:
  - "downloadWings(for: DownloadActivity) — the real wing UI for both .inProgress (icon+'Downloading…' left, ProgressView() right) and .done(filename:) (green checkmark+filename left, empty right) states"
  - "presentationSwitch's .downloadProgress arm now renders downloadWings instead of the Plan 61-01 EmptyView() placeholder"
affects: [61-04-download-monitor, 61-05-on-device-uat]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "downloadWings(for:) switches on DownloadActivity's two cases internally and returns AnyView from each branch (divergent HStack content per branch, unlike capsLockWings/updateWings which are single-branch) — the one new structural wrinkle vs. the plan's other wing-function precedents"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "downloadWings(for:) wraps each switch-case's wingsShape(...) call in AnyView — the two DownloadActivity cases render structurally different HStack content, so a plain `some View` return type across a switch would not type-check without either AnyView or a @ViewBuilder helper; AnyView was the smaller, more local change since neither capsLockWings nor updateWings had this shape (both are single-branch)."

patterns-established: []

requirements-completed: [DL-01, DL-02]

# Metrics
duration: 8min
completed: 2026-07-24
---

# Phase 61 Plan 03: NotchPillView Download-Progress Wing UI Summary

**`downloadWings(for:)` renders the real HUD for both download states using the shared `wingsShape` template — icon+"Downloading…"+spinner while in progress, green checkmark+filename when done — replacing Plan 61-01's placeholder `EmptyView()` arm in `presentationSwitch`**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-23T22:57:00Z
- **Completed:** 2026-07-23T23:05:34Z
- **Tasks:** 1 completed
- **Files modified:** 1

## Accomplishments
- `downloadWings(for: DownloadActivity)` added to `NotchPillView.swift`, structured like `updateWings(for:)`'s icon+label-left / compact-element-right split, using `capsLockWings`' `margin = 65` starting point per 61-UI-SPEC.md
- `.inProgress`: leading `arrow.down.circle` icon + fixed `"Downloading…"` label on the left flank, trailing `ProgressView()` (`.controlSize(.small)`, `.tint(.white)`) on the right flank — no filename ever shown while downloading
- `.done(filename:)`: leading green `checkmark.circle.fill` + the real filename (`.lineLimit(1)`, `.truncationMode(.middle)`, fixed ~140pt frame) on the left flank, empty right flank besides camera-block clearance + trailing pad
- No `onTap` argument passed to either `wingsShape(...)` call (D-11) — taps fall through to the universal `onClick()` expand-to-Home, same as `capsLockWings`
- `presentationSwitch`'s `.downloadProgress` case now calls `downloadWings(for: activity)`, replacing Plan 61-01's `EmptyView()` placeholder
- Debug build green

## Task Commits

Each task was committed atomically:

1. **Task 1: downloadWings(for:) + presentationSwitch wiring** - `5c318b8` (feat)

**Plan metadata:** (this commit, follows)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - new `downloadWings(for:)` function (both `DownloadActivity` states) + `presentationSwitch`'s `.downloadProgress` arm wired to it

## Decisions Made
- `downloadWings(for:)` returns `AnyView` from each switch branch rather than restructuring as two single-branch sibling functions — the plan's interfaces block specified one function taking `DownloadActivity`, and `capsLockWings`/`updateWings` (the two precedents cited) are both single-branch, so neither offered a direct multi-branch `some View` pattern to copy; `AnyView` is the smallest deviation-free way to satisfy a switch with structurally different content per case.

## Deviations from Plan

None - plan executed exactly as written. (The `AnyView` wrapping above is an implementation detail necessary to make the plan's literal per-case `HStack` content compile under a single `some View`-returning function — not a scope or behavior deviation from anything the plan specified.)

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness

`downloadWings(for:)` renders both `DownloadActivity` states per 61-UI-SPEC.md's Icon & Layout Contract; `presentationSwitch` is exhaustive with zero default-case fallback needed. This was the only plan touching `NotchPillView.swift` this phase (per the plan's own objective) — unblocks:
- Plan 61-04 (`DownloadMonitor`) — FSEvents-driven production of `DownloadReading`s that flow into the now-real wing UI via the existing resolver/coordinator wiring from Plan 61-01/61-02.
- Plan 61-05 (on-device UAT) — the visual/margin-tuning checkpoint this plan's `margin = 65` starting value explicitly flags as on-device-tunable.

No blockers.

## Self-Check: PASSED

- FOUND: Islet/Notch/NotchPillView.swift (modified)
- FOUND commit 5c318b8 in git log

---
*Phase: 61-download-progress*
*Completed: 2026-07-24*
