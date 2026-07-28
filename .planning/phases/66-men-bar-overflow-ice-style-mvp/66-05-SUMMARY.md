---
phase: 66-men-bar-overflow-ice-style-mvp
plan: 05
subsystem: menu-bar
tags: [private-api, CGS, AXIsProcessTrusted, spike, checkpoint, NO-GO]

# Dependency graph
requires: [66-01]
provides:
  - "Restored, Accessibility-gated MenuBarOverflowBridging.swift/MenuBarOverflowManualSpike.swift (commit 7e8fadd)"
  - "Real Ice.app reinstalled and present on disk (was a dangling Caskroom symlink)"
  - "DEBUG-only real-launch enumeration hook (debugSpikePrintMenuBarOverflowEnumeration)"
  - "Third NO-GO verdict: the live Ice.app reference itself is broken on this machine — root cause still unknown"
affects: [66-06, 66-07, 66-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Private CGS*/@_silgen_name symbol shim, isolated to one file, restored verbatim from git history rather than rewritten"

key-files:
  created: []
  modified:
    - Islet/Notch/MenuBarOverflowBridging.swift
    - IsletTests/MenuBarOverflowManualSpike.swift
    - Islet/AppDelegate.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "Did not attempt any further code fix after the NO-GO, per this plan's own explicit rule and this project's established NO-GO precedent (Plans 66-01/66-04) — the finding goes back to /gsd:discuss-phase 66, not to another blind fix attempt"

requirements-completed: []  # MENUBAR-01..04 remain incomplete — Task 2's on-device checkpoint returned NO-GO before Islet's own gate could even be tested

# Metrics
duration: Task 1 ~20min; Task 2 on-device checkpoint (Step 1 only, failed immediately)
completed: 2026-07-28 — Task 2 checkpoint returned NO-GO
---

# Phase 66 Plan 05: Reinstall Ice + Restore CGS Spike + On-Device Pattern 1 Checkpoint Summary

**Task 1 (automated) complete and committed: real Ice.app reinstalled, the 66-01 spike restored from git history with a genuine `AXIsProcessTrusted()` gate (was previously print-only) and a real-launch debug hook, Release build clean. Task 2's on-device checkpoint returned NO-GO — not on Islet's own gate, but on Step 1: the live reference itself, real Ice.app's own Cmd-drag hide/reveal mechanism, does not work on this machine at all.**

## Status: NO-GO — checkpoint closed, phase execution halted

Task 1 completed and committed (`7e8fadd`). Task 2 (`checkpoint:human-verify`, gate=blocking) ran on real hardware. Per this plan's own explicit instruction ("do not attempt further fixes here per this project's own NO-GO precedent from Plans 66-01/66-04"), execution stops here. **Plans 66-06, 66-07, and 66-08 do not proceed under current scope.**

## On-device verdict: NO-GO

The how-to-verify sequence's **Step 1** ("Re-validate the live reference — confirm real Ice.app still genuinely hides/shows a real third-party menu-bar icon today") **failed**. The user reports Ice's own Cmd-drag hide/reveal mechanism does not work on this machine at all — the reference app itself is broken, before Islet's own Accessibility gate (Steps 2-5) was ever reached or tested.

**Root cause status: UNKNOWN.** This is neither of the two hypotheses this phase's own RESEARCH.md and CONTEXT.md were built around:
- **Not the permission-gate hypothesis** (RESEARCH.md's leading candidate — Islet's spike never gating on `AXIsProcessTrusted()`) — untested, because Step 1 failed before Islet's own gate was ever exercised.
- **Not the launch-context hypothesis** (Cmd-U test-host vs. real `open` launch) — same reason, untested.
- **A third possibility neither prior NO-GO round (66-01, 66-04) considered:** the underlying private-CGS menu-bar-item mechanism class itself may no longer function on the current macOS version for **any** app, not just Islet — since even the reference implementation (real, currently-installed Ice.app) fails at the identical class of interaction (Cmd-drag across the menu bar to hide/reveal an icon).

**User-supplied hypothesis (unconfirmed — report as hypothesis, not verified fact):** this may be caused by the macOS 27 "Golden Gate" update, and/or the machine's Developer Mode setting. **Neither was independently verified this session.** Recorded here for `/gsd:discuss-phase 66` to investigate, not as a confirmed root cause.

This also directly contradicts this phase's own CONTEXT.md's central premise for the D-07 pivot — "the user confirmed that real Ice ... currently works on this exact machine" — which was the fact that justified reverting from the abandoned public-spacer technique (D-06) back to debugging the private-CGS mechanism. That premise no longer holds as of this checkpoint.

## Performance

- **Task 1 duration:** ~20 min
- **Task 2:** on-device checkpoint, Step 1 of 6 executed — failed immediately, Steps 2-5 never reached
- **Tasks:** 1 of 2 complete (Task 2 returned NO-GO, not a code-completion state)
- **Files modified:** 4

## Accomplishments (Task 1)

- Reinstalled real Ice.app via `brew reinstall --cask jordanbaird-ice` — confirmed the Caskroom entry was a dangling symlink to a deleted `/Applications/Ice.app` (RESEARCH.md Pitfall 4), now genuinely present (`test -d /Applications/Ice.app` → PRESENT).
- Restored `Islet/Notch/MenuBarOverflowBridging.swift` and `IsletTests/MenuBarOverflowManualSpike.swift` verbatim from git history (`git show adfbd70`) — no redesign, per RESEARCH.md's finding that the CGS signatures are byte-for-byte verified correct against Ice's real source.
- Added `guard AXIsProcessTrusted() else { return [] }` as the literal first line of `menuBarItemWindows()` — was previously only a diagnostic print (RESEARCH.md Pitfall 1), never a gate.
- Upgraded the manual spike's console output to explicitly print the gate's pass/block state ("gate PASSES"/"gate BLOCKS").
- Added a DEBUG-only debug-menu action (`debugSpikePrintMenuBarOverflowEnumeration`) that runs the identical enumeration from a genuine `open`-launched instance, to independently test the Cmd-U test-host-launch hypothesis (RESEARCH.md Pitfall 2) — never actually exercised, since Task 2 halted at Step 1.
- `xcodegen generate` re-registered both restored files in `project.pbxproj` (removed by Plan 66-03's cleanup).
- `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'` — BUILD SUCCEEDED, zero errors.
- All 6 acceptance criteria from the plan verified via grep + build output before commit.

## Task Commits

1. **Task 1: Reinstall Ice, restore the 66-01 spike, add the Accessibility gate, add a real-launch debug hook** - `7e8fadd` (feat)

Task 2 has no code commit — it is a human-verification checkpoint; this SUMMARY.md documents its NO-GO verdict.

## Files Modified

- `Islet/Notch/MenuBarOverflowBridging.swift` - restored + `AXIsProcessTrusted()` gate added
- `IsletTests/MenuBarOverflowManualSpike.swift` - restored + gate-state console output upgraded
- `Islet/AppDelegate.swift` - new DEBUG-only `debugSpikePrintMenuBarOverflowEnumeration()` debug-menu action
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate`

## Deviations from Plan

None — plan executed exactly as written through Task 1. Task 2 halted per the plan's own explicit checkpoint instruction the moment Step 1 failed; no code fix was attempted, matching the plan's own rule and this project's established NO-GO precedent (66-01, 66-04).

## Issues Encountered

Task 2's on-device verification could not proceed past Step 1: the real Ice.app reference itself does not currently work on this machine (Cmd-drag hide/reveal non-functional), so Islet's own restored/gated mechanism (Steps 2-5) was never exercised. This is a new, third failure mode this phase has not previously encountered — see "On-device verdict" above.

## User Setup Required

None from this plan. The next step requires a `/gsd:discuss-phase 66` session to decide direction, potentially informed by further investigation of the user's macOS 27 "Golden Gate" / Developer Mode hypothesis.

## Next Phase Readiness — NO-GO, halted

Per the plan's own resume-signal rule, Phase 66 execution stops here. **Plans 66-06, 66-07, and 66-08 must NOT proceed until this is resolved via `/gsd:discuss-phase 66`.** This is the third consecutive NO-GO for this phase (66-01: private-CGS enumeration mechanism bug; 66-04: public-spacer technique non-functional; 66-05: the private-CGS mechanism's own live reference implementation, real Ice.app, is itself broken on this machine) — options to weigh at the next discussion include investigating the user's macOS 27 "Golden Gate"/Developer Mode hypothesis, checking whether Ice's mechanism ever genuinely worked on this specific OS build, or descoping Menübar-Overflow (SC#2-5) from v1.10 entirely.

---
*Phase: 66-men-bar-overflow-ice-style-mvp*
*Task 1 completed: 2026-07-28 — Task 2 checkpoint NO-GO*

## Self-Check: PASSED

- FOUND: Islet/Notch/MenuBarOverflowBridging.swift
- FOUND: IsletTests/MenuBarOverflowManualSpike.swift
- FOUND commit: 7e8fadd
