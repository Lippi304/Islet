---
phase: 66-men-bar-overflow-ice-style-mvp
plan: 04
subsystem: menu-bar
tags: [NSStatusItem, autosaveName, checkpoint, human-verify, spike]

# Dependency graph
requires:
  - phase: 66-02
    provides: "MenuBarOverflowController (public NSStatusItem-based chevron + spacer mechanism)"
  - phase: 66-03
    provides: "Removal of stale Settings toggle and superseded private-API (66-01) spike files"
provides:
  - "On-device NO-GO verdict on MENUBAR-02/MENUBAR-03: the public NSStatusItem.length spacer mechanism does not reclaim/hide layout space on real macOS 27 Tahoe beta hardware, and Cmd-drag across the chevron does not work"
affects: [66-discuss-phase-followup]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - .planning/phases/66-men-bar-overflow-ice-style-mvp/66-04-SUMMARY.md
  modified: []

key-decisions:
  - "No code changes made in this plan (pure human-verify checkpoint, files_modified: [] per plan frontmatter) — verdict is recorded, no auto-fix attempted, per the plan's own resume-signal rule requiring a return to /gsd:discuss-phase 66 on any NO-GO"

requirements-completed: []  # NO-GO — MENUBAR-01/02/03 remain incomplete; public NSStatusItem mechanism does not reclaim/hide layout space or accept Cmd-drag reassignment on this hardware

# Metrics
duration: single round (no code changes)
completed: 2026-07-28
---

# Phase 66 Plan 04: On-Device UAT — Chevron/Drag/Reveal/Persistence Checkpoint Summary

**On-device verdict: NO-GO. The click handler and glyph-swap (< / >) work, but the core mechanism — Cmd-drag reassignment of a real third-party icon across the chevron, and the spacer `NSStatusItem`'s `.length` toggle actually reclaiming or hiding menu-bar layout space — does not function on real macOS 27 Tahoe beta hardware.**

## Status: NO-GO — checkpoint closed, phase execution halted

This plan is a single `checkpoint:human-verify` task (gate=blocking) with no code changes (`files_modified: []`). The user ran the 8-step on-device checklist from `66-04-PLAN.md` on real hardware and reported failures on steps 4, 5, and 6.

## On-device verdict: NO-GO

Reported by the user, in their own words:

1. **Step 4 (Cmd-drag, MENUBAR-02) — FAIL.** Cmd-dragging a real third-party menu-bar icon (the "arrow/connected-dots" icon) leftward past the chevron did not work at all — the icon could not be grabbed/moved into position across the chevron, even after repeated attempts.
2. The user then manually repositioned icons around the chevron outside of Cmd-drag (screenshot confirmed: chevron is leftmost overall, with system/third-party icons — WiFi, battery, magnifier, ladybug, ring icon, white circle, connected-dots, circle-slash — then the clock, all sitting to its right).
3. Even after this manual repositioning, no icon could be made to land to the left of the chevron via Cmd-drag.
4. **Steps 5/6 (click-to-reveal/hide, MENUBAR-03) — FAIL.** Clicking the chevron toggles the glyph (`chevron.left` <-> `chevron.right`) correctly, but causes NO icon to appear or disappear on either side, in any configuration tested. Two independent screenshots across two testing rounds confirmed no icon ever moved to a hidden zone and no reclaim/hide effect was observed — the spacer's `.length` toggle has no visible effect on real menu-bar layout.

**Conclusion:** The click handler and glyph-swap logic built in Plan 66-02 work correctly, but the core mechanism this phase depends on — a spacer `NSStatusItem` whose `.length` change genuinely reclaims/hides layout space (RESEARCH.md Assumption A2/A3), and native Cmd-drag reassignment of third-party icons relative to that spacer — does not produce any observable effect on this hardware/macOS version. This is a NO-GO on both MENUBAR-02 and MENUBAR-03, and by extension MENUBAR-01 (the chevron does not genuinely separate a visible/hidden section, since nothing is ever hidden or revealed).

Per this plan's own verification clause: **"A NO-GO on any step (especially step 5/6's reclamation check) requires returning to `/gsd:discuss-phase 66` before this phase is considered complete, mirroring Plan 66-01's own precedent."** Phase 66 execution halts here. No further Phase 66 plans proceed under the current scope.

## Performance

- **Duration:** single round (no code changes; verification-only task)
- **Tasks:** 1 of 1 (checkpoint) — resolved with NO-GO verdict
- **Files modified:** 0

## Accomplishments

- Confirmed (via the parts of the checklist that did pass) that the chevron appears leftmost with no Settings/permission surface, and click glyph-swap behaves correctly — the UI shell from Plan 66-02 is sound.
- Isolated the failure precisely to the two claims RESEARCH.md flagged as needing on-device confirmation (Assumption A2/A3): public `NSStatusItem.length` reclaiming layout, and native Cmd-drag interaction with the spacer item.

## Task Commits

Task 1 is a `checkpoint:human-verify` with no code changes — no commit for this task, consistent with `files_modified: []` in the plan frontmatter.

## Files Created/Modified

None — this plan performs no code changes (pure verification task).

## Decisions Made

- No auto-fix attempted. Per the plan's explicit resume-signal rule and RULE 4 (architectural changes require user decision), a failed core-mechanism assumption is not something an executor auto-fixes — it requires a design discussion (`/gsd:discuss-phase 66`) to choose a new direction (different mechanism, different API, or descoping SC#4/MENUBAR-01..03 for this milestone), mirroring the precedent set by Plan 66-01's NO-GO.

## Deviations from Plan

None — plan executed exactly as written (present checklist, record verdict). The verdict itself was NO-GO; that is a checkpoint outcome, not a deviation.

## Issues Encountered

The public `NSStatusItem`-based mechanism (chosen in Plan 66-02 specifically to avoid the fragile private-CGS approach that failed in Plan 66-01) also fails on-device, but for a different reason: rather than a data-read failure (Plan 66-01's CGS enumeration bug), here the spacer's `.length` toggle produces no observable layout effect at all, and Cmd-drag — a native OS gesture Apple documents as working with any `NSStatusItem`, not something the app implements — does not engage with the spacer either. This suggests the spacer item is not being treated as a real, drag-interactive layout participant by the menu-bar layout system on this macOS 27 Tahoe beta, contrary to RESEARCH.md's assumption that this is long-established, stable public API behavior.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness — NO-GO, halted

Phase 66 is **NOT complete**. MENUBAR-01/02/03 remain unmet. **Next step: `/gsd:discuss-phase 66`** to decide direction — options to weigh there include: investigating whether the spacer item needs additional configuration (e.g. `isVisible`, `autosaveName` collisions, `behavior` flags) to be treated as a real layout participant, testing on non-beta macOS to isolate a Tahoe-beta-specific regression, revisiting the private-CGS approach with different symbols now that two independent public/private mechanisms have both failed, or descoping the Ice-style overflow mechanism (SC#4) for this milestone entirely.

---
*Phase: 66-men-bar-overflow-ice-style-mvp*
*Checkpoint resolved: 2026-07-28 — NO-GO*

## Self-Check: PASSED

- FOUND: .planning/phases/66-men-bar-overflow-ice-style-mvp/66-04-SUMMARY.md
- No commit hashes to verify (no code changes this plan, per files_modified: [])
