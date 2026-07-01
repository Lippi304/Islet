---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Phase 6 complete (06-05 ship gate closed out)
last_updated: "2026-07-01T00:38:41Z"
last_activity: 2026-07-01 -- Phase 06 closed out (06-05 SUMMARY written from existing commits)
progress:
  total_phases: 7
  completed_phases: 6
  total_plans: 26
  completed_plans: 23
  percent: 88
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-26)

**Core value:** The notch becomes a beautiful, reliable island that shows now-playing media and reacts when you plug in the charger or connect a device — native, smooth, and as polished as the iPhone Dynamic Island.
**Current focus:** v1.0 milestone wrap-up — Phase 5's remaining scope is a deferred carry-over (see below)

## Current Position

Phase: 06 (priority-resolver-settings-v1-ship) — COMPLETE (5/5 plans)
Status: Phase 06 closed out. Milestone v1.0 feature-complete; one carry-over remains (below).
Last activity: 2026-07-01 -- 06-05 SUMMARY written from pre-existing commits (version bump, release dry-run, on-device D-16 re-check + UI fixes), ROADMAP/STATE updated to match.

### Phase 5 status note (not a resume point — informational)

Phase 5 (device-connected-activity) still shows 0/3 plans executed in ROADMAP.md, but per
`06-CONTEXT.md`: "Phase 5 device wiring is finished INSIDE this phase" — Phase 6 built the
remaining device pieces (`DeviceActivityState`, `BluetoothMonitor`, device wings) that Phase 5
left blocked on Waves 2-3. DEV-01/DEV-02 are code-complete and on-device verified (see
06-02-SUMMARY.md, 06-04-SUMMARY.md). The only actual carry-over is the **on-device Bluetooth
permission spike** from 05-01 Task 3 (needs a real BT test device — see git history around
commit 3652b92 for the throwaway spike, `#if DEBUG_BT_SPIKE`). This is a deliberate scope
merge (like the D-15 Developer-ID carry-over), not neglected work. Whether to formally close
Phase 5 in ROADMAP.md (as superseded) or leave it open pending the BT hardware spike is a
call for the user — not made automatically here.

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**

- Total plans completed: 18
- Average duration: — min
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 00 | 4 | - | - |
| 01 | 3 | - | - |
| 02 | 4 | - | - |
| 03 | 3 | - | - |
| 04 | 4 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 00 P03 | 3 | 3 tasks | 3 files |
| Phase 02 P01 | 4 | 3 tasks | 8 files |
| Phase 02 P02 | 4 | 2 tasks | 3 files |
| Phase 02 P03 | 4 | 2 tasks | 3 files |
| Phase 02 P04 | 180 | 2 tasks | 3 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap] Charging (Phase 3) is built before Now Playing (Phase 4): proves the activity→island loop on the safest public API (IOKit) before the fragile MediaRemote landmine. (Diverges from research SUMMARY's "Now Playing first"; activity-arbitration nuance deferred to Phase 6 resolver.)
- [Roadmap] Notarization toolchain proven in Phase 0 on a hello-world build, not deferred to release — the single biggest first-timer footgun.
- [Roadmap] Fullscreen-hide (ISL-05) and multi-display/clamshell correctness (ISL-06) are CORE success criteria in Phases 1–2, not polish.
- [Roadmap] All MediaRemote access isolated behind one NowPlayingService with a launch-time health check (Phase 4); a future Apple change is a one-file fix.
- [Phase 00]: [00-03] Release script uses hdiutil (UDZO) for the DMG; create-dmg noted as Phase-6 polish (not installed).
- [Phase 00]: [00-03] release.sh placeholder-gates Developer-ID/notary steps; ad-hoc fallback exits 0 with a loud SKIP banner — runs unchanged at Phase 6 (D-01/D-02/D-03).
- [Phase 02]: [02-01] isTrueFullscreen maps nil built-in to false: clamshell is NOT fullscreen; the no-target path is owned by shouldShow's hasTarget term, keeping the two concerns untangled.
- [Phase 02]: [02-01] shouldShow = hasTarget && !(hideInFullscreen && isFullscreen): single D-10 gating flag so a future Phase-6 fullscreen toggle is a one-flag change, no logic edit.
- [Phase 02]: [02-02] NotchPillView morph: collapsed+expanded share one matchedGeometryEffect(id: "island") on a single @Namespace; view holds no animation driver (D-08), Plan 03 wraps state mutation in withAnimation(.spring).
- [Phase 02]: [02-02] Expanded size seed 360×72 / collapsed 200×38 exposed as NotchPillView.expandedSize/.collapsedSize so Plan 03 passes the SAME expandedSize to expandedNotchFrame (no view/panel drift).
- [Phase 02]: [02-03] Focus-safe ISL-03: global NSEvent .mouseMoved monitor drives nextState; hover fires haptic+bounce (no expand), click expands with the spring, 0.4s grace-delay collapse; ignoresMouseEvents flipped false only in the hot-zone, restored true when collapsed (Pitfall 3); shown only via orderFrontRegardless (no focus-stealing call).
- [Phase 02]: [02-03] Tuning seeds single-sourced in NotchWindowController for Plan 05: graceDelay 0.4s, spring response 0.35/damping 0.65, hotZonePadding 6, expandedSize from NotchPillView.expandedSize (360×72). A1 DEBUG hover-tick probe ready; NSTrackingArea (Pattern 1b) documented as the permission-free fallback.
- [Phase 02]: [02-04] ISL-05 runtime fullscreen signal pivoted from the safe-area heuristic to a CGS managed-display-spaces probe (built-in current-space type==4): a background agent (LSUIElement) can never observe another app's fullscreen from its own physical display's safe area, so the safe-area predicate is superseded (kept only as a pure test-covered heuristic). No AX/TCC prompt; fails safe to false.
- [Phase 02]: [02-04] Native fullscreen ISL-05 on-device VERIFIED (Tahoe); a ~1-frame island flash at the END of the fullscreen-ENTER transition is product-deferred — root-caused as window-server compositing the all-Spaces panel onto the activating fullscreen Space (our orderOut is reactive, can't pre-empt it); a show-debounce was tried and reverted (f706f66, nothing to debounce). Q2 items (FS video, QuickLook, maximized-stays, clamshell, focus-safe restore) remain pending UAT.

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

None yet.

### Blockers/Concerns

[Issues that affect future work]

- [Phase 4] MediaRemote longevity is unknowable. Verify the mediaremote-adapter version against the *currently installed* macOS at Phase-4 planning; treat each macOS update as a Now-Playing regression event.
- [Phase 1] Open decision: DynamicNotchKit vs. a custom NSPanel for the overlay. Decide at Phase-1 planning (prototype-with-it then graduate, or roll the panel directly).
- [Phase 0] Confirm the macOS deployment floor (14.0 recommended for reach vs 15.0) before starting.
- [Phase 4] No Apple Developer account yet — only needed for notarization. Phase 0's dry run and Phase 6's release both require it ($99/yr).

## Session Continuity

Last session: 2026-06-28T01:05:24.423Z
Stopped at: Phase 6 context gathered
Resume file: .planning/phases/06-priority-resolver-settings-v1-ship/06-CONTEXT.md
