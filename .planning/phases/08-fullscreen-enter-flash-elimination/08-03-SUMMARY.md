---
phase: 08-fullscreen-enter-flash-elimination
plan: 03
subsystem: fullscreen-detection
tags: [fullscreen, cgs, escalation, wave-1, decision-pending]

# Dependency graph
requires:
  - phase: 08-fullscreen-enter-flash-elimination
    provides: "08-01's Wave-0 on-device D-05 trigger-matrix evidence and the recorded option-c decision (Candidate A disproven), which unblocks this plan's escalation path"
provides:
  - "Islet/Notch/FullscreenSpaceProbe.swift and NotchWindowController.swift reverted byte-for-byte to their pre-Phase-8 state (no exploratory probe code ships)"
  - "08-ESCALATION.md: a written, evidence-grounded root-cause escalation report for FS-01"
  - "A pending, blocking checkpoint awaiting the user's explicit FS-01 scope decision (option-accept/option-descope/option-investigate-b)"
affects: [08-fullscreen-enter-flash-elimination-phase-close, REQUIREMENTS.md-FS-01-traceability]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - .planning/phases/08-fullscreen-enter-flash-elimination/08-ESCALATION.md
  modified:
    - Islet/Notch/FullscreenSpaceProbe.swift
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "Task 0 precondition guard confirmed 08-01-SUMMARY.md recorded option-c (Candidate A disproven) - the escalation path (this plan) is the correct one to execute, not 08-02 (fix path)"
  - "Task 1: reverted both Wave-0 probe files byte-for-byte to their pre-Phase-8 state (git checkout dea30c1~1), per D-03 - no code change ships when no proactive signal was found"
  - "Task 2: wrote 08-ESCALATION.md citing this phase's own on-device evidence (08-01's raw [FS-01 probe] Console capture showing zero CGS event 106/107 firings across 3 enter/exit cycles, all 3 D-05 trigger methods) rather than restating prior Phase-2/Phase-6 conclusions, per D-07"
  - "Task 3 (checkpoint:decision, gate=blocking) has NOT been resolved - execution halts here pending the user's explicit choice among option-accept/option-descope/option-investigate-b, per D-04"

requirements-completed: []

# Metrics
duration: "~15 min (Tasks 0-2)"
completed: 2026-07-04
---

# Phase 8 Plan 03: FS-01 Escalation Path (Wave 1) Summary

**Reverted all Wave-0 exploratory CGS-probe code byte-for-byte to its pre-Phase-8 state and produced a written root-cause escalation report for FS-01, grounded in this phase's own on-device evidence that the CGS event 106/107 candidate never fires cross-process — the phase now awaits the user's explicit scope decision (Task 3, blocking checkpoint, NOT yet resolved).**

## Performance

- **Duration:** ~15 min (Tasks 0-2; Task 3 is a pending human decision, not time-bounded)
- **Started:** 2026-07-04T01:07:00Z (approx, following on from 08-01's on-device session)
- **Completed (this session):** 2026-07-04T01:13:15Z
- **Tasks:** 3 of 4 completed (Task 0, 1, 2); Task 3 halted at blocking checkpoint
- **Files modified:** 2 (reverted) + 1 created

## Accomplishments

- **Task 0 (precondition guard):** confirmed `08-01-SUMMARY.md`'s recorded decision is `option-c` (the last and authoritative decision-record entry: "Decision: option-c — Candidate A disproven"). This plan (the escalation path) is the correct one to execute; `08-02-PLAN.md` (fix path) must not run.
- **Task 1 (revert):** identified that both `Islet/Notch/FullscreenSpaceProbe.swift` and `Islet/Notch/NotchWindowController.swift` were last touched by the same commit (`dea30c1`, 08-01's Wave-0 probe). Reverted both files via `git checkout dea30c1~1 -- <files>`. Verified byte-for-byte equivalence: `git diff dea30c1~1 -- <files>` produced zero lines of diff, and `grep -c 'CGSRegisterNotifyProc\|CGSRemoveNotifyProc\|fullscreenProbeCallback\|FS-01 probe'` returned 0 across both files. `xcodebuild build -scheme Islet` succeeded; `xcodebuild test -scheme Islet` passed 141/141 (0 failures), matching the pre-Phase-8 baseline exactly.
- **Task 2 (escalation report):** wrote `08-ESCALATION.md` with all four required sections (`## Root Cause`, `## What Was Tried This Phase`, `## Untried Fallback`, `## Requested Decision`). The "What Was Tried This Phase" section quotes the specific `[FS-01 probe]` Console evidence from `08-01-SUMMARY.md` (the raw enter/exit cycle timestamps showing zero CGS event 106/107 lines). The "Requested Decision" section names all three options explicitly.
- **Task 3 (blocking checkpoint):** NOT executed by this session. This requires presenting `08-ESCALATION.md` to the user and recording their explicit choice — it cannot be made by an autonomous executor. See "Next Phase Readiness" below.

## Task Commits

1. **Task 0: Precondition guard** — no commit (read-only verification; confirmed option-c, proceeded to Task 1)
2. **Task 1: Revert all Wave-0 exploratory probe code** - `1ba86ba` (revert)
3. **Task 2: Write the root-cause escalation report** - `6a6f3be` (docs)

**Plan metadata:** (this docs commit, following STATE.md/ROADMAP.md updates)

## Files Created/Modified

- `Islet/Notch/FullscreenSpaceProbe.swift` - reverted to pre-Phase-8 state (removed the `kCGSClientEnterFullscreen`/`kCGSClientExitFullscreen` constants, `CGSNotifyProc` typealias, and `CGSRegisterNotifyProc`/`CGSRemoveNotifyProc` bindings added by 08-01)
- `Islet/Notch/NotchWindowController.swift` - reverted to pre-Phase-8 state (removed the `#if DEBUG`-gated `fullscreenProbeCallback`, `probeContext`, registration/teardown, `handleFullscreenProbeEvent(type:)`, and the temporary `[FS-01 probe]` prints inside `spaceObserver`/`appActivateObserver`)
- `.planning/phases/08-fullscreen-enter-flash-elimination/08-ESCALATION.md` - created; the written root-cause escalation report for FS-01

## Decisions Made

- **Precondition confirmed:** 08-01's recorded decision is `option-c` — this plan's escalation path is unblocked and correct to run (not `08-02`'s fix path).
- **Byte-for-byte revert, not partial cleanup:** per D-03/must_haves, chose `git checkout <pre-commit> -- <files>` over manual line-by-line removal, since both files were entirely and solely modified by the single `dea30c1` commit — this guarantees exact pre-Phase-8 equivalence rather than a hand-edited approximation.
- **Escalation report cites this phase's own evidence, not a restatement:** per D-07, `08-ESCALATION.md`'s "What Was Tried This Phase" section quotes the specific on-device `[FS-01 probe]` Console capture from `08-01-SUMMARY.md`, distinguishing this phase's new investigation (CGS event 106/107) from the two prior investigations (Phase 2, Phase 6) it corroborates.

## Deviations from Plan

None - plan executed exactly as written for Tasks 0-2.

## Issues Encountered

None. The revert was unambiguous (single source commit for both files), and the build/test verification matched the pre-Phase-8 baseline on the first attempt.

## User Setup Required

None - no external service configuration required. Task 3, however, requires the user to review `08-ESCALATION.md` and make an explicit scope decision (see below).

## Next Phase Readiness

**This plan is NOT fully complete.** Task 3 is a `checkpoint:decision` with `gate="blocking"` — it requires the user to review `.planning/phases/08-fullscreen-enter-flash-elimination/08-ESCALATION.md` and select one of:

- `option-accept` — Accept the fullscreen-enter flash as permanent technical debt (closes the phase now)
- `option-descope` — Formally descope FS-01 in `REQUIREMENTS.md`/`ROADMAP.md`
- `option-investigate-b` — Request a follow-up investigation of the untried `SLSManagedDisplayIsAnimating` fallback (a new investigation phase, not a quick fix)

No code change has shipped for FS-01 in this phase. The v1.0 reactive `updateVisibility()`/`orderOut` behavior is exactly as it was before Phase 8 began (verified byte-for-byte). The phase cannot close out until this decision is recorded.

## Self-Check: PASSED

- FOUND: `.planning/phases/08-fullscreen-enter-flash-elimination/08-ESCALATION.md` (contains `## Root Cause`, `## What Was Tried This Phase`, `## Untried Fallback`, `## Requested Decision`)
- FOUND: commit `1ba86ba` in `git log --oneline`
- FOUND: commit `6a6f3be` in `git log --oneline`
- Build: `xcodebuild build -scheme Islet` — BUILD SUCCEEDED
- Tests: `xcodebuild test -scheme Islet` — 141/141 passing, no regression
- Revert verification: `git diff dea30c1~1 -- Islet/Notch/FullscreenSpaceProbe.swift Islet/Notch/NotchWindowController.swift` — 0 lines (byte-for-byte match)

---
*Phase: 08-fullscreen-enter-flash-elimination*
*Completed: 2026-07-04 (Tasks 0-2 only; Task 3 pending)*
