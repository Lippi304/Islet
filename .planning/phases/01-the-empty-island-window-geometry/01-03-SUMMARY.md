---
phase: 01-the-empty-island-window-geometry
plan: 03
subsystem: notch-overlay
tags: [on-device-verification, window-level, clamshell, multi-display, manual-uat, isl-01, isl-02, isl-06, isl-07]

# Dependency graph
requires:
  - phase: 01-the-empty-island-window-geometry
    provides: NotchPanel/NotchPillView/NotchWindowController overlay from Plan 02
provides:
  - A2 resolved on-device — shipped NotchPanel.level = .statusBar confirmed to win over the macOS 26 menu bar at the notch (no bump needed)
  - A3 resolved on-device — clamshell hides the pill and lid-open recovers it (built-in drops out of NSScreen.screens)
  - The four MANUAL-only visual criteria from VALIDATION.md signed off (ISL-01/02/06/07)
affects: [phase-2-hover-expand, activity-island]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "On-device human-verify checkpoint plan: agent builds+launches DEBUG/RELEASE, pauses for physical verification, applies one-line fallback only if the user reports a failure"

key-files:
  created: []
  modified: []

key-decisions:
  - "A2: ship NotchPanel.level = .statusBar — confirmed on macOS 26 hardware to render the pill OVER the transparent menu bar at the notch band; the .mainMenu + 1 fallback was NOT needed"
  - "A3: hide-in-clamshell via the built-in display dropping out of NSScreen.screens is correct on real hardware — no extra guard needed; lid-open recovers via the existing didChangeScreenParametersNotification observer"
  - "No constants nudged: widthFudge stays 4, NotchShape radii stay top 6 / bottom 14, release fill stays Color.black with devOffset 0 — the pill hugged the notch and shipped invisibly without adjustment"

patterns-established:
  - "Manual UAT criteria that no agent can assert (visual notch-hug, cross-Spaces layering, focus/click-through, clamshell) are converted into explicit blocking human-verify gates rather than left buried in VALIDATION.md"

requirements-completed: [ISL-01, ISL-02, ISL-06, ISL-07]

# Metrics
duration: on-device session
completed: 2026-06-26
---

# Phase 1 Plan 03: On-Device Verification (A2/A3 + manual visual criteria) Summary

**All four MANUAL-only Phase-1 criteria signed off on real macOS 26 notch hardware with zero code changes: the pill hugs the notch over the menu bar (A2 → `.statusBar` ships), stays above all windows across Spaces with no focus theft / full click-through (ISL-02 / D-07), tracks the built-in display and hides+recovers across clamshell (ISL-06 / A3), and ships near-invisible and static in release (ISL-07).**

## Performance

- **Completed:** 2026-06-26 (interactive on-device session, executed inline on the workspace tree)
- **Tasks:** 4 (all `checkpoint:human-verify`, gate=blocking)
- **Files modified:** 0 — every checkpoint passed as shipped from Plan 02; no fallback edit was triggered.

## Outcome of the Open Questions

### A2 — window level vs the macOS 26 menu bar  →  RESOLVED, ships `.statusBar`
The Plan 02 default `NotchPanel.level = .statusBar` was confirmed on-device to render the pill **over** the Tahoe (macOS 26) transparent/floating menu bar at the notch band. The pill is **not** clipped or occluded at the notch. The one-line fallback (`level = .mainMenu + 1`) was **not** needed and was not applied. `NotchPanelTests` remains green at the shipped level (6 tests).

### A3 — built-in display drop-out in clamshell  →  RESOLVED
With an external monitor attached, closing the lid drops the built-in display out of `NSScreen.screens`; the overlay **hides entirely** (does not relocate to the external) and **recovers** on lid-open via the existing `didChangeScreenParametersNotification` observer. No extra guard in `NotchWindowController` was needed. `DisplayResolverTests` remains green (7 tests).

## Manual Visual Criteria — Sign-off Checklist

| # | Criterion | Requirement | Result |
|---|-----------|-------------|--------|
| 1 | Pill hugs the physical notch (width, corner radius, position); renders over the menu bar | ISL-01 + A2 | ✅ Approved |
| 2 | Stays above all windows, visible across all Spaces; no focus theft; clicks pass through | ISL-02 + D-07 | ✅ Approved |
| 3 | Correct built-in display across plug/unplug + resolution change; hides in clamshell; recovers | ISL-06 + A3 | ✅ Approved (external monitor present) |
| 4 | Release-config idle pill near-invisible and completely static | ISL-07 + D-01/D-03 | ✅ Approved |

## Constants Nudged During Verification
None. `widthFudge = 4`, `NotchShape` radii top 6 / bottom 14, release `NotchPillView` fill `Color.black` with `devOffset == 0` all confirmed correct without adjustment.

## Automated Gates Run (all green)
- Task 1: `xcodebuild test -only-testing:IsletTests/NotchPanelTests` → 6/6, TEST SUCCEEDED.
- Task 2: grep — `ignoresMouseEvents = true` + `canBecomeKey` present → PANEL_CONFIG_OK.
- Task 3: `xcodebuild test -only-testing:IsletTests/DisplayResolverTests` → 7/7, TEST SUCCEEDED.
- Task 4: grep — `Color.black` present and no animation modifiers → IDLE_STATIC_OK.
- Full suite confirmed earlier on the integrated tree: 24/24, 0 failures.

## Threat Model Disposition
- **T-01-07 (overlay traps input / focus theft):** Checkpoint 2 confirmed on real hardware that clicking the pill does not activate Islet and menu-bar/desktop clicks pass through — the Plan 02 click-through + non-activating mitigations hold. Gate satisfied.
- **T-01-08 (info disclosure):** No new data, network, persistence, or entitlement surface touched. Accepted (LOW).

## Deviations from Plan
None. All four blocking checkpoints were approved on first presentation; no fallback edit (level bump, constant nudge, release-fill fix) was required.

## Execution Note (orchestrator)
This `autonomous: false` plan was executed **inline on the workspace tree** (not in a throwaway worktree subagent), because every task is a blocking human-verify gate requiring the user to physically inspect the notch, switch Spaces, click around, and operate an external monitor + lid. The orchestrator built/launched the DEBUG build (Tasks 1–3) and the RELEASE build (Task 4), presented each checkpoint, and collected sign-off.

## Next Phase Readiness
- The "empty island" is fully verified on real hardware: a correctly-placed, layered, focus-safe, click-through, idle-invisible black pill. Phase 2 (hover/expand) can build the interactive morph on top of this stable overlay.

## Self-Check: PASSED

No files were created or modified by this plan (all checkpoints passed as-is). The four manual criteria and both open questions (A2, A3) are signed off; all referenced automated gates exit 0.

---
*Phase: 01-the-empty-island-window-geometry*
*Completed: 2026-06-26*
