---
phase: 38-focus-mode-hud
plan: 01
subsystem: infra
tags: [intents, INFocusStatusCenter, focus-mode, spike, macos-tahoe]

# Dependency graph
requires: []
provides:
  - "Confirmed on-device go/no-go decision for Focus/DND detection: Path A (INFocusStatusCenter) is viable on this dev machine"
  - "DEBUG-only throwaway spike (Islet/FocusDetectionSpike.swift) proving both detection paths compile and run"
affects: [38-03-focus-mode-monitor, 38-07-cleanup]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "DEBUG-only throwaway spike file, entirely wrapped in a single #if DEBUG/#endif block, called once from AppDelegate.applicationDidFinishLaunching"

key-files:
  created: [Islet/FocusDetectionSpike.swift]
  modified: [Islet/AppDelegate.swift]

key-decisions:
  - "Detection path decision: path-a — INFocusStatusCenter reaches .authorized and is usable on this dev machine (macOS 26/Tahoe), contradicting 38-RESEARCH.md's Architecture Patterns §1 prediction that Path A was a near-certain structural dead end gated behind the Communication Notifications capability"
  - "Plan 38-03 (FocusModeMonitor) MUST implement the INFocusStatusCenter path (Path A), NOT the Assertions.json + Full Disk Access path (Path B) — this is the load-bearing fact all downstream Phase 38 plans depend on"

patterns-established: []

requirements-completed: []  # HUD-05 is NOT complete — this plan only records the detection-path decision; the actual Focus Mode HUD ships in later Phase 38 plans (38-03+)

# Metrics
duration: ~3min (Task 2 checkpoint response only; Task 1 spike authored in prior session)
completed: 2026-07-17
---

# Phase 38 Plan 01: Focus Mode HUD Detection-Path Spike Summary

**On-device spike confirms `INFocusStatusCenter` (Path A) reaches `.authorized` on this dev machine — Phase 38's Focus/DND detection will use Path A, not the Assertions.json/FDA fallback (Path B) that 38-RESEARCH.md predicted as the likely winner.**

## Performance

- **Duration:** ~3 min (Task 2 checkpoint recording only; Task 1 code authored and committed in a prior session)
- **Started:** 2026-07-17T00:54:02Z (Task 1 commit)
- **Completed:** 2026-07-16T23:56:47Z (recording, this session)
- **Tasks:** 2 (1 auto, 1 checkpoint:human-verify)
- **Files modified:** 2 (Islet/FocusDetectionSpike.swift created, Islet/AppDelegate.swift modified)

## Accomplishments
- Wrote a DEBUG-only throwaway spike (`Islet/FocusDetectionSpike.swift`) probing both candidate Focus/DND detection mechanisms side by side
- Wired the spike into `AppDelegate.applicationDidFinishLaunching(_:)` behind `#if DEBUG`, confirmed absent from Release builds
- Ran the spike on real hardware (macOS 26/Tahoe) and obtained a definitive go/no-go signal, resolving the open question from 38-RESEARCH.md before any `FocusModeMonitor` implementation begins

## Task Commits

Each task was committed atomically:

1. **Task 1: Write the throwaway detection-path spike** - `5748fc4` (feat)
2. **Task 2: On-device detection-path go/no-go** - checkpoint:human-verify, no code changes; result recorded in this SUMMARY

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/FocusDetectionSpike.swift` - DEBUG-only spike probing `INFocusStatusCenter` (Path A) and `~/Library/DoNotDisturb/DB/Assertions.json` (Path B), printing labeled `[FocusSpike][PathA]` / `[FocusSpike][PathB]` console output
- `Islet/AppDelegate.swift` - One `#if DEBUG`-gated call to `runFocusDetectionSpike()` added to `applicationDidFinishLaunching(_:)`

## On-Device Verification Result

**Overall call: `path-a`**

- **Path A (`INFocusStatusCenter`):** Reached `.authorized` on this dev machine (macOS 26/Tahoe) and is usable — the app can read Focus/DND state via `INFocusStatusCenter.default.focusStatus.isFocused` once authorized.
- **Path B (`~/Library/DoNotDisturb/DB/Assertions.json`):** Not the selected path; superseded by Path A's success. The user's report did not include granular per-line console output for Path B beyond the final overall call.
- **Console output detail:** The user's response reported the final go/no-go decision (`path-a`) without pasting raw line-by-line console output from the Xcode Debug Console. The decision itself — Path A reaching `.authorized` — is treated as authoritative per the resume instructions for this continuation.

**This directly contradicts 38-RESEARCH.md's Architecture Patterns §1**, which rated Path A (`INFocusStatusCenter`) as a near-certain structural dead end on the assumption it requires the Communication Notifications capability, and rated Path B (Assertions.json + Full Disk Access) as the likely winner. The on-device test is authoritative over the research prediction.

## Decisions Made
- **Detection path locked to Path A.** Plan 38-03 (`FocusModeMonitor`) MUST implement Focus/DND detection via `INFocusStatusCenter`, NOT via `~/Library/DoNotDisturb/DB/Assertions.json` + Full Disk Access polling. This is the single load-bearing fact this plan exists to establish, and every downstream Phase 38 plan (Monitor, Controller wiring, Settings UI, 38-07 cleanup of this spike) depends on it.
- D-12 clean-descope path was NOT taken — a viable detection mechanism was confirmed, so Phase 38 proceeds with implementation rather than descoping HUD-05.

## Deviations from Plan

None - plan executed exactly as written. Task 1's code matches the plan's acceptance criteria (verified in the prior session's commit); Task 2 is a recording-only checkpoint task with no code changes.

## Issues Encountered
- The user's checkpoint response provided the final go/no-go call (`path-a`) but not granular per-line console transcripts for both probes. This is recorded as a known gap in verification granularity above — the overall decision is still authoritative since it came from an actual on-device run, not a prediction.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- **Plan 38-03 (`FocusModeMonitor`) is unblocked** and must implement Focus/DND detection using `INFocusStatusCenter` (Path A) exclusively — do not build the Assertions.json/FDA fallback (Path B) as the primary mechanism.
- **Plan 38-07** must delete `Islet/FocusDetectionSpike.swift` and its `AppDelegate.swift` call site once Path A is implemented for real in `FocusModeMonitor.swift` (this spike is throwaway per its `#if DEBUG` design).
- HUD-05 requirement remains **not yet complete** — this plan only resolves the detection-path unknown; the actual visible Focus Mode HUD ships in later Phase 38 plans.

---
*Phase: 38-focus-mode-hud*
*Completed: 2026-07-17*
