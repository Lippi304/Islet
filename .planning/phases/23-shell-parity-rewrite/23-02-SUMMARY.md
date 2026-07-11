---
phase: 23-shell-parity-rewrite
plan: 02
subsystem: ui
tags: [swift, appkit, nspanel, notchwindowcontroller, cgs-space, click-through]

# Dependency graph
requires:
  - phase: 16-device-coordinator-extraction
    provides: DeviceCoordinator/ActivityCoordinator extraction precedent (evaluated, not repeated here)
  - phase: 20-shelf-view
    provides: CR-01 click-through fix (visibleContentZone(), preserved verbatim)
  - phase: 9-fullscreen-flash-window-space-retry
    provides: FS-01 dedicated max-level CGSSpace fix (preserved verbatim)
provides:
  - Line-by-line re-verified NotchWindowController.swift (properties, start(), monitor lifecycle, hosting-view/settings-apply, Now-Playing handlers, shelf handlers, deinit) — confirmed to already match every documented invariant, zero functional edit required
affects: [23-03-safety-critical-core-rewrite, 23-04-consolidated-uat]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified: []

key-decisions:
  - "No functional edit made to NotchWindowController.swift — full line-by-line read (all 1378 lines) against RESEARCH.md's quoted code excerpts and PATTERNS.md's pattern map found the file already matches every documented invariant byte-for-byte, per the plan's own explicit 'do not fabricate a diff for its own sake' instruction"
  - "pendingLockoutHide (D-11/D-12/D-13) confirmed to remain a plain inline field, not extracted into its own coordinator — a single boolean guard with 3 call sites (updateVisibility, handleHoverExit, handleClick) does not warrant a whole ActivityCoordinator-conforming type per CONTEXT.md's explicit guidance against forcing risk into a zero-regression phase"
  - "deviceCoordinator confirmed constructed at start()-time (line 281), never at property-declaration scope (line 130 is `private var deviceCoordinator: DeviceCoordinator!`, no inline initializer) — Phase 16 precedent preserved"

patterns-established: []

requirements-completed: []

# Metrics
duration: 25min
completed: 2026-07-11
---

# Phase 23 Plan 02: Shell Parity Rewrite — Non-Safety-Critical Reconstruction Summary

**Line-by-line audit of `NotchWindowController.swift`'s properties, `start()`, monitor lifecycle, hosting-view/settings-apply, Now-Playing handlers, shelf handlers, and `deinit` confirmed zero drift from documented invariants — no functional edit required.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-07-11T01:09:00Z
- **Completed:** 2026-07-11T01:34:10Z
- **Tasks:** 2 completed (both audit-only, zero functional diff)
- **Files modified:** 0

## Accomplishments
- Read `Islet/Notch/NotchWindowController.swift` in full (all 1378 lines) and diffed it mentally, section by section, against RESEARCH.md's quoted code excerpts (`updateVisibility()`, `positionAndShow(on:)`, `syncClickThrough()`, `handlePointer(at:)`) and PATTERNS.md's pattern map (imports/class header, `deinit`, hosting-view/settings-apply/Now-Playing/shelf handlers) — found the current implementation already IS the documented target verbatim.
- Confirmed every stored property inventory (Task 1's exhaustive list: panel/notchSpace/observers/licenseState/pendingLockoutHide/interaction/all activity states/shelf state/outfit state/transientQueue/monitors/deviceCoordinator/accent tracking/work items/drag-pin fields/pointer tracking/zones/springs/DEBUG probe) matches exactly, with correct types and default values.
- Confirmed `start()`'s exact registration order: `deviceCoordinator` construction (start()-time, `[weak self]` closures) → `updateVisibility()` → screen-parameters observer → 2 NSWorkspace observers → global `.mouseMoved` monitor → 3 toggle-gated monitor starts → unconditional `startOutfitRefresh()` → DEBUG-only `seedDebugShelfItems()` → `defaultsObserver` → `renderPresentation()` → `scheduleTrialExpiryCheck()`.
- Confirmed the toggle-gated monitor helpers (`startPowerMonitor`, `startNowPlayingMonitor`, `startBluetoothMonitor`, `startOutfitRefresh`) all preserve the idempotent `guard ... == nil else { return }` pattern (Pitfall 5).
- Confirmed `handleSettingsChanged()`'s exact per-toggle branch order (Charging → Devices → Now Playing → song-toast-off-clears-live-toast → `applyAccentIfChanged()` → re-render + `updateVisibility()`) and the "prefer stop" idle-CPU discipline.
- Confirmed `flushTransients(_:)`'s WR-2 "only reset the dismiss timer if the actual head changed" gate (`oldHead` captured before `removeAll(where:)`).
- Confirmed `handleNowPlaying(_:_:)`'s capture-before-overwrite ordering (`previous`, `previousPosition`, `hadPlayedSinceLaunch` all captured before mutation) and the song-change-toast gate evaluated before any mutation.
- Confirmed the Phase-20 shelf handlers preserve their exact bodies, including `resyncShelfViewState`'s CR-01-era `syncClickThrough()` (not `updateVisibility()`) call.
- Confirmed `deinit`'s exact teardown order and completeness: default-center observer, the two NSWorkspace-center observer removals, defaults observer, mouse monitor, `graceWorkItem?.cancel()`, drag-pin safety-net cancel + release-monitor removal, `powerMonitor.stop()` + `dismissWorkItem?.cancel()`, `bluetoothMonitor?.stop()` + `deviceCoordinator?.cancelPendingWork()`, `nowPlayingMonitor?.stop()` + `mediaDismissWorkItem?.cancel()`, `notchSpace.windows.remove(panel)` (FS-01 teardown), `trialExpiryWorkItem?.cancel()`, `outfitRefreshTimer?.invalidate()`.
- Verified all acceptance-criteria greps from both tasks and a clean `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` (BUILD SUCCEEDED).

## Task Commits

Neither task produced a functional code change — the file already matched every documented invariant, so no `Islet/Notch/NotchWindowController.swift` diff exists to commit (per the plan's explicit "if the section already matches exactly, no functional edit is required beyond confirming it — do not fabricate a diff for its own sake"). This SUMMARY documents the audit outcome for both tasks.

1. **Task 1: Reconstruct properties, start(), and toggle-gated monitor lifecycle** — audit only, zero diff, confirmed via full read + grep acceptance criteria + build.
2. **Task 2: Reconstruct hosting-view/settings-apply, Now-Playing handlers, shelf handlers, and deinit** — audit only, zero diff, confirmed via full read + grep acceptance criteria + build.

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified
None — `Islet/Notch/NotchWindowController.swift` was read in full and verified but not edited.

## Decisions Made
- Confirmed (not forced) the CONTEXT.md/RESEARCH.md-flagged discretionary decision: `pendingLockoutHide` stays inline, no `LicenseGatingCoordinator` extraction — its 3 call sites (`updateVisibility()`, `handleHoverExit()`'s grace-elapsed recheck, `handleClick()`'s toggle-shut recheck) don't warrant the `DeviceCoordinator`-style protocol extraction per CONTEXT.md's explicit "do not force an extraction that adds risk" guidance.
- Confirmed the in-place rewrite strategy (vs. parallel-build-then-swap) required no actual parallel construction — since the file already matched, there was nothing to "swap."

## Deviations from Plan

None — plan executed exactly as written. The plan itself anticipated this outcome explicitly: "if the section already matches exactly, no functional edit is required beyond confirming it — do not fabricate a diff for its own sake."

## Acceptance Criteria Verification

All grep-based acceptance criteria from both tasks passed:

| Criterion | Result |
|---|---|
| `xcodebuild build` succeeds | ✅ BUILD SUCCEEDED |
| `private let notchSpace = CGSSpace(level: 2147483647)` matches exactly once | ✅ line 39 |
| `deviceCoordinator = DeviceCoordinator(` is inside `start()`, not at declaration | ✅ line 281 (inside start()); line 130 declaration has no inline initializer |
| `pendingLockoutHide` count unchanged (no extraction happened) | ✅ 7 occurrences (field decl + 3 doc comments + 3 call sites) |
| `func start()` exists exactly once | ✅ line 277 |
| `notchSpace.windows.remove(panel)` count is 1, inside `deinit` | ✅ line 1366, inside deinit (1328-1377) |
| `wc.removeObserver` count is 2 (spaceObserver + appActivateObserver) | ✅ lines 1334, 1335 |
| All 4 monitor-teardown calls present in `deinit` | ✅ `powerMonitor.stop()` (1349), `bluetoothMonitor?.stop()` (1355), `deviceCoordinator?.cancelPendingWork()` (1356), `nowPlayingMonitor?.stop()` (1361) — note: the plan's literal grep pattern also matches doc-comment mentions of these same calls elsewhere in the file (raw count 10, not 4), a pre-existing calibration quirk in the grep, not a code defect; manual line-by-line confirmation above is authoritative |
| `func handleSettingsChanged\|flushTransients\|handleNowPlaying\|makeRootView` count is 4 | ✅ one occurrence each |

## Issues Encountered
None. The full-file read (1378 lines) confirmed the codebase's own RESEARCH.md/PATTERNS.md excerpts were themselves transcribed directly from this exact file this session, so an exact match was expected and found.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- `NotchWindowController.swift`'s non-safety-critical two-thirds (properties, `start()`, monitor lifecycle, hosting-view/settings-apply, Now-Playing handlers, shelf handlers, `deinit`) are re-verified, compiling, and unchanged.
- Plan 23-03 can now proceed to reconstruct the remaining safety-critical third of this same file (`updateVisibility()`, `positionAndShow()`, `syncClickThrough()`, `handlePointer()`, hover/click handlers) — this plan deliberately left every one of those functions untouched (they were read only as context, never edited), so 23-03 inherits a clean, fully-committed file with no merge conflicts expected against this parallel wave's other worktree (23-01, `NotchPanel.swift`/`NotchPanelTests.swift`, disjoint files).
- No blockers.

---
*Phase: 23-shell-parity-rewrite*
*Completed: 2026-07-11*
