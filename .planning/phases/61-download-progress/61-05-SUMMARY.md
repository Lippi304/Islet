---
phase: 61-download-progress
plan: 05
subsystem: ui

tags: [swift, swiftui, fsevents, on-device-uat, gap-closure]

# Dependency graph
requires:
  - phase: 61-download-progress
    plan: 01
    provides: DownloadActivity.swift, IslandResolver rank-5 .downloadProgress wiring
  - phase: 61-download-progress
    plan: 02
    provides: DownloadCoordinator per-file in-flight correlation (D-05/D-06/D-08/D-15)
  - phase: 61-download-progress
    plan: 03
    provides: downloadWings(for:) real wing UI, replacing the Plan 61-01 placeholder
  - phase: 61-download-progress
    plan: 04
    provides: DownloadMonitor (real FSEventStreamCreate watcher) + NotchWindowController wiring
provides:
  - Build/test gate confirmation (Debug + Release green, 98/98 scoped tests green)
  - On-device UAT closing all 4 ROADMAP Phase 61 Success Criteria (DL-01, DL-02)
  - Icon-only downloadWings redesign (fixed-left download icon, swap-right spinner<->checkmark)
  - Tightened camera-cutout margin (55 -> 30 -> 20, plus 12 -> 16 edge padding)
  - Real bug fix: DownloadCoordinator now dismisses a standing .inProgress transient on cancel (removeInProgress closure)
affects: [62-timer-pomodoro, 67-coding-progress]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "removeInProgress closure gated on inFlightDownloads.isEmpty — DownloadCoordinator's .removed case now explicitly tells TransientQueue to dismiss a standing .inProgress transient instead of relying on TransientQueue's own advance/enqueue mechanics to eventually clear it (they never did, for the currently-showing head)"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/DownloadCoordinator.swift
    - Islet/Notch/NotchWindowController.swift
    - IsletTests/DownloadCoordinatorTests.swift

key-decisions:
  - "downloadWings(for:) redesigned mid-UAT from icon+text-label wings to icon-only both flanks — text labels were too wide for the collapsed pill on real hardware, discovered only once actually visible on-device (mirrors the Phase 38 Focus-wing precedent of the pill's true width only being provable on real hardware)"
  - "Download icon fixed on the left flank in both .inProgress/.done states; the right flank swaps between a spinner (in progress) and a checkmark (done) instead of swapping which flank the icon lives on — reduces perceived layout jump between states"
  - ".hierarchical symbol rendering mode swapped for .monochrome + .bold — user reported the icon fill read as too dim/washed out against the black pill background"
  - "Camera-cutout margin tightened over 2 rounds (55 -> 30 -> 20) plus edge padding widened 12 -> 16, net narrower wing footprint despite the padding increase — user reported too much dead space between the icon and the physical camera cutout"
  - "DownloadCoordinator gained a removeInProgress closure, invoked from handle(_:) when a .removed reading empties inFlightDownloads while a .downloadProgress(.inProgress) transient is still the standing head — closes the real bug found during UAT step 6 (cancelling a download never dismissed the spinner)"

patterns-established:
  - "On-device UAT gap-closure loop for wing geometry: ship a starting value from the UI-spec, then iterate margin/padding purely from live visibility-percentage feedback rather than theoretical notch-geometry math (same lesson as Phase 39's OSD wing saga, reapplied here in fewer rounds)"

requirements-completed: [DL-01, DL-02]

# Metrics
duration: multi-session (checkpoint, 5 gap-closure commits across 2 real bug/polish rounds)
completed: 2026-07-24
---

# Phase 61 Plan 05: Build/Test Gate + On-Device UAT Summary

**Consolidated on-device UAT (all 4 ROADMAP Phase 61 Success Criteria, 11/11 checklist steps) closed after 5 gap-closure commits — an icon-only wing redesign, two rounds of camera-margin/edge-padding tuning, and a real cancel-bug fix (spinner never dismissed) with 2 new regression tests**

## Performance

- **Duration:** multi-session (checkpoint) — Task 1 (build/test gate) ran in a prior executor session with no commit needed (verification-only); Task 2's on-device checkpoint paused, then the user ran the real UAT directly with the orchestrator across 5 follow-up commits before giving final approval ("nein es klappt doch alles das ist das was ich meinte")
- **Tasks:** 2 completed (Task 1: build/test gate; Task 2: on-device UAT + 5 gap-closure commits + final re-verification)
- **Files modified this plan's follow-up round:** 4 (`NotchPillView.swift`, `DownloadCoordinator.swift`, `NotchWindowController.swift`, `DownloadCoordinatorTests.swift`)

## Accomplishments

**Task 1 — Build/test gate:** Debug and Release builds both succeeded; the scoped `DownloadActivityTests`/`DownloadCoordinatorTests`/`IslandResolverTests` suite was green (97/97 at the time). No commit — verification-only, `files_modified: []`.

**Task 2 — On-device UAT, all 11 checklist steps confirmed**, closing all 4 ROADMAP Phase 61 Success Criteria:
1. Fresh-defaults check (SC4) — Download Progress toggle OFF by default. Confirmed.
2. Toggle ON + basic flow (SC1/SC2) — Chrome/Edge download shows spinner + "Downloading…" within seconds, then a checkmark + real filename for ~3s, auto-clears. Confirmed (after the icon-only redesign below).
3. Firefox variant (`.part` suffix) — identical behavior. Confirmed.
4. Safari variant (Pitfall 1 sanity check) — `.download` bundle handled correctly, no flicker/re-trigger from the bundle's internal writes. Confirmed.
5. Two rapid downloads (SC3, D-05/D-06) — one HUD throughout, each file gets its own correct "done" splash, neither dropped. Confirmed.
6. Cancelled download (D-15) — **initially FAILED**: the "Downloading…" HUD kept animating forever after cancel. Root-caused and fixed (see Deviations below), then reconfirmed passing.
7. Manual-expand cuts a done splash short (D-04) — confirmed.
8. Collapsed-only gating (D-03) — confirmed.
9. Priority (D-01, rank 5) — standing Charging/Device splash not interrupted by a new download. Confirmed.
10. Settings toggle gating (SC4) — toggling OFF then downloading shows no indicator. Confirmed.
11. Regression check — Charging/Device/Focus/OSD/Caps Lock/Update HUDs unaffected. Confirmed.

Plus 2 rounds of visual/UX polish the user requested live during the UAT (see Deviations), and a final re-verification build + scoped test run performed by this closing session confirming everything still green after all 5 follow-up commits.

## Task Commits

Task 1 had no commit (verification-only). Task 2's on-device UAT round-trip produced 5 follow-up commits, already on disk from the live session with the orchestrator (not created by this closing session):

1. `9a062ab` — fix(61-03): rebuild download wing icon-only per on-device UAT feedback
2. `d438ad1` — fix(61-03): fixed download icon left, status swaps right, brighter icons
3. `75de768` — fix(61-03): tighten download wing camera margin 55->30
4. `b35991b` — fix(61-03): more edge padding, tighter camera margin (round 4)
5. `7b2c59e` — fix(61-02/61-04): cancelling a download never dismissed the spinner

**Plan metadata:** (this commit, follows)

## Files Created/Modified

- `Islet/Notch/NotchPillView.swift` — `downloadWings(for:)` rebuilt icon-only both flanks (text labels dropped), download icon fixed on the left in both states, right flank swaps spinner<->checkmark, `.monochrome`+`.bold` symbol rendering (brighter fill), camera-cutout margin 55->30->20, edge padding 12->16
- `Islet/Notch/DownloadCoordinator.swift` — new `removeInProgress` closure, invoked from `handle(_:)`'s `.removed` branch when `inFlightDownloads` becomes empty while a `.downloadProgress(.inProgress)` transient is still the standing head
- `Islet/Notch/NotchWindowController.swift` — `downloadCoordinator` construction wired the new `removeInProgress` closure to the `transientQueue`'s dismiss path
- `IsletTests/DownloadCoordinatorTests.swift` — 2 new regression tests for the cancel-bug fix (bringing the suite from 9 to 11 tests)

## Decisions Made

See `key-decisions` in frontmatter — icon-only redesign, fixed-left-icon/swap-right-icon layout, `.monochrome`+`.bold` symbol rendering, and the 2-round margin/padding tightening were all live user-directed changes during on-device UAT, not pre-planned. The cancel-bug fix (`removeInProgress`) is a genuine Rule 1 bug fix found during UAT step 6.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Cancelling a download never dismissed the spinner**
- **Found during:** Task 2, UAT step 6 (cancelled download)
- **Issue:** `DownloadCoordinator`'s `.removed` case never told `TransientQueue` to dismiss a standing `.inProgress` transient — cancelling a download left the "Downloading…" spinner animating forever, since neither `enqueue` nor `replaceHead` are called on a plain removal and nothing else in the resolver/queue mechanics naturally clears an already-standing head.
- **Fix:** Root-caused via systematic-debugging; added a new `removeInProgress` closure to `DownloadCoordinator`'s init, gated on `inFlightDownloads.isEmpty` after the removal, wired at the `NotchWindowController` construction site to dismiss the transient queue's head.
- **Files modified:** `Islet/Notch/DownloadCoordinator.swift`, `Islet/Notch/NotchWindowController.swift`, `IsletTests/DownloadCoordinatorTests.swift` (2 new regression tests)
- **Verification:** Full `IsletTests` suite (`DownloadCoordinatorTests`/`DownloadActivityTests`/`IslandResolverTests`, 98 tests) confirmed green after the fix; re-confirmed on-device that a cancelled download's spinner now disappears with no done state.
- **Committed in:** `7b2c59e`

**2. [Rule 4-adjacent, user-directed] Icon-only wing redesign + 2 rounds of margin/padding tuning**
- **Found during:** Task 2, UAT step 2 (basic flow) — the first time the wing was actually visible on real hardware
- **Issue:** The original icon+text-label wing design (from Plan 61-03) was too wide for the collapsed pill in practice; separately, too much dead space existed between the icon and the physical camera cutout.
- **Fix:** User-directed live redesign across 4 commits: icon-only both flanks (no more text labels), download icon fixed on the left in both states with the right flank swapping spinner<->checkmark, `.monochrome`+`.bold` symbol rendering for a brighter icon fill, and camera-cutout margin tightened 55->30->20 with edge padding widened 12->16 (net narrower footprint).
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** User confirmed on-device after each round; final approval "nein es klappt doch alles das ist das was ich meinte".
- **Committed in:** `9a062ab`, `d438ad1`, `75de768`, `b35991b`

---

**Total deviations:** 1 auto-fixed bug (Rule 1) + 1 user-directed live visual redesign (4 commits, mirrors the Phase 38 Focus-wing and Phase 39 OSD-wing precedent of geometry only being provable once the wing is actually visible on real hardware)
**Impact on plan:** The cancel-bug fix is a correctness fix, not scope creep — cancelling a download is one of the plan's own 11 explicit checklist steps (D-15). The visual redesign changes 61-03's shipped wing appearance but not its behavioral contract (still 2 states, same resolver/coordinator wiring); `61-UI-SPEC.md` was not updated in this pass — same known gap as the Phase 38 Focus-wing precedent (flagged there too, never retroactively fixed).

## Issues Encountered

None beyond the two items documented above (both resolved before final approval).

## User Setup Required

None - no external service configuration required.

## Final Re-Verification (this closing session)

Ran a full confirmation pass after all 5 follow-up commits, since none of them had been re-verified against the full build/test gate:
- `xcodebuild -configuration Debug build` — **BUILD SUCCEEDED**
- `xcodebuild -configuration Release build` — **BUILD SUCCEEDED**
- Scoped test run (`DownloadActivityTests` + `DownloadCoordinatorTests` + `IslandResolverTests`): **98/98 tests passed, 0 failures** (8 + 11 + 79 — `DownloadCoordinatorTests` grew from 9 to 11 with the cancel-bug fix's 2 new regression tests)

## Next Phase Readiness

Phase 61 (Download-Progress) is fully shipped and on-device UAT-confirmed — all 4 ROADMAP Success Criteria hold, DL-01/DL-02 closed. `DownloadMonitor.swift`'s FSEvents pattern (top-level-path filtering, cross-batch rename correlation via file ID) is proven on real hardware and ready for Phase 67 (Coding-Progress) to reuse per the roadmap's own stated dependency. No blockers for Phase 62 (Timer/Pomodoro), which has no dependency on this phase's specifics beyond shared `TransientQueue`/`ActiveTransient` infrastructure already in place.

## Self-Check: PASSED

- FOUND: Islet/Notch/DownloadCoordinator.swift (removeInProgress present)
- FOUND: Islet/Notch/NotchPillView.swift (icon-only downloadWings present)
- FOUND commit 9a062ab in git log
- FOUND commit d438ad1 in git log
- FOUND commit 75de768 in git log
- FOUND commit b35991b in git log
- FOUND commit 7b2c59e in git log
- CONFIRMED: Debug build green, Release build green, 98/98 scoped tests green (this session's re-verification)

---
*Phase: 61-download-progress*
*Completed: 2026-07-24*
