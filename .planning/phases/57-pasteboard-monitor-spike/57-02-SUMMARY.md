---
phase: 57-pasteboard-monitor-spike
plan: 02
subsystem: infra
tags: [nspasteboard, clipboard, debug-spike, appkit]

# Dependency graph
requires:
  - phase: 57-01
    provides: ClipboardMonitor (changeCount-gated poll, concealed/transient/self-capture-marker filtering, classification, D-07 accessBehavior check)
provides:
  - 4 DEBUG-only spike menu actions in AppDelegate proving ClipboardMonitor against real NSPasteboard.general
  - On-device confirmation of all 4 ROADMAP Phase 57 success criteria (PRIV-01)
affects: [58-menu-wiring-ui-assembly]

# Tech tracking
tech-stack:
  added: []
  patterns: ["DEBUG-only spike-hook + on-device-checkpoint pattern (Phase 49-01/56-02 precedent) extended to ClipboardMonitor"]

key-files:
  created: []
  modified: [Islet/AppDelegate.swift]

key-decisions:
  - "Session-scoped in-memory one-time-gate flag (debugHasShownPasteboardAccessExplanation) is sufficient for this spike per D-07 — Phase 58 builds the real persisted UX"
  - "No coordinator/manager type introduced; ClipboardMonitor owned directly by a #if DEBUG stored property on AppDelegate since no real menu UI (Phase 58) exists yet"

patterns-established:
  - "Phase 57 spike hooks — see 57-02-SUMMARY.md for the on-device verdict (comment convention matching Phase 49/56 precedent)"

requirements-completed: [PRIV-01]

# Metrics
duration: multi-session (checkpoint)
completed: 2026-07-22
---

# Phase 57 Plan 02: Pasteboard Monitor DEBUG Spike Hooks + On-Device Verification Summary

**4 DEBUG-only spike menu actions wired ClipboardMonitor to real NSPasteboard.general, and on-device testing across two verification rounds confirmed all 4 ROADMAP Phase 57 success criteria, closing PRIV-01.**

## Performance

- **Duration:** multi-session (checkpoint)
- **Started:** 2026-07-22T21:29:00Z (approx, per STATE.md `last_updated`)
- **Completed:** 2026-07-22T21:46:24Z
- **Tasks:** 2 (1 auto + 1 checkpoint:human-verify)
- **Files modified:** 1

## Accomplishments

- 4 DEBUG-only spike menu actions (`debugSpikeStartClipboardMonitor`, `debugSpikeWriteConcealedTestItem`, `debugSpikeSimulateSelfCaptureWrite`, `debugSpikeCheckPasteboardAccessBehavior`) added to `AppDelegate`'s existing debug menu, all wired to Plan 57-01's `ClipboardMonitor` via a throwaway console-print sink (never `ClipboardStore`/`ClipboardFileStore`, per D-09).
- All 4 ROADMAP Phase 57 success criteria verified on real hardware (see Task Commits / on-device verdicts below).
- PRIV-01 requirement satisfied at the monitor layer.

## Task Commits

Each task was committed atomically:

1. **Task 1: 4 DEBUG-only spike hooks wired to ClipboardMonitor** - `89035cb` (feat)

Task 2 (checkpoint:human-verify) required no code changes — verification-only, all 9 how-to-verify steps passed as documented below.

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified

- `Islet/AppDelegate.swift` - Added `debugClipboardMonitor: ClipboardMonitor?` and `debugHasShownPasteboardAccessExplanation` DEBUG-only stored properties, 4 new debug-menu items, and 4 new `@objc private func` spike handlers exercising `ClipboardMonitor` against real `NSPasteboard.general`.

## On-Device Verification Results (Task 2)

All 9 how-to-verify steps in `57-02-PLAN.md` Task 2 passed, across two verification rounds:

- **SC#1 (capture + classify, changeCount-diff detection within ~1s):** Confirmed for BOTH text and image.
  - Text: `[Spike-ClipboardMonitor] captured kind=text(...)` printed correctly, including a stress-test of large recursive copy-paste content.
  - Image: `[Spike-ClipboardMonitor] captured kind=image(5246006 bytes)` printed correctly via a Cmd+Ctrl+Shift+4 region screenshot copied direct-to-clipboard.
- **SC#2 (concealed-type exclusion, D-08):** "wrote concealed test item..." printed by `debugSpikeWriteConcealedTestItem`; no subsequent `captured` line appeared — the `org.nspasteboard.ConcealedType`-tagged item was correctly excluded.
- **SC#3 (self-capture guard):** "wrote self-capture-marker test item..." printed by `debugSpikeSimulateSelfCaptureWrite`; no subsequent `captured` line appeared — the `ClipboardMonitor.restoreMarkerType`-tagged write was correctly excluded.
- **SC#4 (access-behavior one-time-gate, D-07):**
  - First click: "accessBehavior already .always — no explanation needed" printed (this test Mac's `accessBehavior` is already `.alwaysAllow`, matching the plan's documented alternate branch — no alert expected here).
  - Second click: "explanation already shown this session — one-time-gate holding" printed and no alert appeared — proving the session-scoped one-time-gate flag (`debugHasShownPasteboardAccessExplanation`) itself works correctly regardless of which accessBehavior branch fired first.
- **Step 9 (native pasteboard-access system prompt):** None appeared during testing on this hardware — informational only per the plan, not a pass/fail gate.

## Decisions Made

- Session-scoped in-memory one-time-gate flag is sufficient for this DEBUG spike (D-07 explicitly frames the explanation UX as a placeholder; Phase 58 builds the real persisted UX).
- No coordinator/manager type introduced — `ClipboardMonitor` owned directly by a `#if DEBUG` stored property on `AppDelegate`, since no real menu UI exists yet to own that role in production.

## Deviations from Plan

None - plan executed exactly as written. Task 1 landed with zero deviations (build succeeded on first attempt, all acceptance-criteria greps matched); Task 2 was verification-only and all 9 steps passed without needing a code fix.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 3 pieces of the v1.9 Clipboard History milestone's spike/infrastructure work are now proven: data model + store (Phase 55), encrypted persistence (Phase 56), and the pasteboard monitor (Phase 57) — all verified on real hardware where required.
- Phase 58 (Menu Wiring & UI Assembly, CLIP-01/02/03/05) can now proceed: it wires `ClipboardMonitor`'s real `onChange` callback into `ClipboardStore`/`ClipboardFileStore` (replacing this plan's throwaway console-print sink) and builds the actual status-item menu UI.
- No blockers identified.

---
*Phase: 57-pasteboard-monitor-spike*
*Completed: 2026-07-22*

## Self-Check: PASSED

- FOUND: Islet/AppDelegate.swift
- FOUND: .planning/phases/57-pasteboard-monitor-spike/57-02-SUMMARY.md
- FOUND: 89035cb (git log --oneline --all)
