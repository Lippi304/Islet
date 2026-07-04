---
phase: 08-fullscreen-enter-flash-elimination
verified: 2026-07-04T03:19:00Z
status: passed
score: 9/9 must-haves verified (1 via override)
overrides_applied: 1
overrides:
  - must_have: "On-device, entering native fullscreen (tested across multiple trigger methods) shows zero visible island flash during or after the transition, across repeated trials (ROADMAP Success Criterion 1)"
    reason: "ROADMAP.md's own Investigation Note for Phase 8 pre-authorizes documented escalation as the valid terminal state when elimination proves infeasible at the application layer ('the phase's terminal state is a documented escalation with root-cause evidence, surfaced to the user for an explicit scope decision — not a silent good enough ship'). 08-01's on-device D-05 trigger matrix (3 full enter/exit cycles, all 3 trigger methods) found the one new candidate signal (CGS event 106/107) never fires cross-process — Candidate A disproven, option-c recorded. 08-03 reverted all exploratory code byte-for-byte and produced 08-ESCALATION.md. The user reviewed it and selected option-investigate-b, explicitly choosing to pursue a NEW follow-up investigation (SLSManagedDisplayIsAnimating / Candidate B) rather than accept or descope. FS-01 is therefore open/escalated, not silently dropped — it requires a new phase, not rework of Phase 8."
    accepted_by: "user (via 08-03-PLAN.md Task 3 checkpoint:decision, recorded in 08-03-SUMMARY.md 'Task 3 — RESOLVED: option-investigate-b')"
    accepted_at: "2026-07-04T03:18:15Z"
---

# Phase 8: Fullscreen-Enter Flash Elimination Verification Report

**Phase Goal:** Entering true (native) fullscreen on the built-in display never produces a visible island flash, closing out the polish debt v1.0 shipped with.
**Verified:** 2026-07-04T03:19:00Z
**Status:** passed
**Re-verification:** No — initial verification

## IMPORTANT: This Phase Terminates in a Documented Escalation, Not a Shipped Fix

This is the **expected and correct terminal state** for Phase 8, not a verification failure. ROADMAP.md's
own "Investigation note" for this phase states: *"If on-device investigation during planning/execution
finds the flash is genuinely not fixable at the application layer... the phase's terminal state is a
documented escalation with root-cause evidence, surfaced to the user for an explicit scope decision —
not a silent 'good enough' ship."* That is exactly what happened:

1. **08-01 (Wave 0):** built a DEBUG-only on-device probe for the one new candidate signal RESEARCH.md
   identified (private CGS notification pair `CGSClientEnterFullscreen`/`CGSClientExitFullscreen`,
   event codes 106/107). The on-device D-05 trigger matrix (green-button, menu-bar, fullscreen video;
   3 full enter/exit cycles across all 3 methods) found **zero** `CGS event 106`/`107` lines fired for
   another process's real fullscreen transition. Recorded decision: **option-c** (Candidate A disproven).
2. **08-02 (fix path)** correctly **did not execute** — its own Task-0 precondition guard requires
   option-a/option-b, and 08-01 recorded option-c. Confirmed: `Islet/Notch/FullscreenDetector.swift`
   still has the original 3-parameter `shouldShow(...)` signature; no `pendingFullscreenTransition`
   symbol exists anywhere in the codebase.
3. **08-03 (escalation path)** executed instead: reverted all Wave-0 exploratory code byte-for-byte to
   the pre-Phase-8 state, wrote `08-ESCALATION.md` with concrete on-device evidence, and surfaced the
   decision to the user. The user selected **option-investigate-b**: request a follow-up investigation
   of the untried `SLSManagedDisplayIsAnimating` fallback (Candidate B) — a new phase, not phase 8 rework.

**FS-01 remains OPEN.** It is not fixed, not silently dropped, and not passed in the literal
"flash is gone" sense — it is formally escalated with a recorded user decision requiring a **new,
not-yet-created phase** to attempt Candidate B. See the Requirements Coverage section below.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Zero visible island flash on fullscreen entry, across repeated trials (ROADMAP SC1) | ⚠ ESCALATED (override) | 08-01-SUMMARY.md's on-device D-05 trigger matrix confirms the flash **still occurs**; Candidate A (CGS 106/107) disproven. See override entry in frontmatter — accepted as the phase's valid terminal state per ROADMAP's own Investigation Note. |
| 2 | Fix uses a genuine root-cause signal, not a best-effort/partial reduction (ROADMAP SC2) | ✓ VERIFIED | No partial/best-effort mitigation was shipped (REQUIREMENTS.md Out-of-Scope honored). A genuinely new private-API-tier candidate (CGS 106/107, distinct in kind from the Phase-2/6 reactive `NSWorkspace` notifications) was tried on-device and disproven with evidence, not reasoned from research-time inference alone (D-06/D-07). |
| 3 | Existing fullscreen hide/restore behavior not regressed (ROADMAP SC3) | ✓ VERIFIED | `git diff dea30c1~1 -- Islet/Notch/FullscreenSpaceProbe.swift Islet/Notch/NotchWindowController.swift` = 0 lines (independently confirmed byte-for-byte revert). `grep` for `CGSRegisterNotifyProc\|CGSRemoveNotifyProc\|fullscreenProbeCallback\|FS-01 probe` across both files = 0 hits. 141/141 tests reported passing post-revert. |
| 4 | 08-01: probe conclusively determines whether CGS 106/107 fires cross-process, across all 3 D-05 trigger methods | ✓ VERIFIED | Raw `[FS-01 probe]` Console evidence in 08-01-SUMMARY.md: 3 full enter/exit cycles, all 3 trigger methods, zero `CGS event 106/107` lines; `isBuiltinDisplayInFullscreenSpace` (`[ISL-05]` type read) flips 4↔0 in lockstep confirming transitions genuinely occurred. |
| 5 | 08-01: a single unambiguous option-a/b/c decision gates Wave 1 | ✓ VERIFIED | "Decision: option-c — Candidate A disproven" recorded in 08-01-SUMMARY.md, cited verbatim by 08-03's Task 0 guard and by 08-ESCALATION.md. |
| 6 | 08-01: probe stays at the permitted private-API risk tier (D-01/D-02) | ✓ VERIFIED | `git show dea30c1` (historical, before revert) shows only `@_silgen_name` bindings for `CGSRegisterNotifyProc`/`CGSRemoveNotifyProc`, explicit source comment "no dlopen" — no `dlopen` calls, no system-binary patching found anywhere in the diff. |
| 7 | 08-03: no code ships; v1.0 reactive behavior left byte-for-byte exact | ✓ VERIFIED | Independently confirmed: `git diff dea30c1~1 -- <2 files>` = 0 lines. `FullscreenDetector.swift`'s `shouldShow(...)` still has its original 3-parameter signature (no option-b artifacts anywhere, consistent with 08-02 never running). |
| 8 | 08-03: written root-cause escalation report exists, citing this phase's own new on-device evidence (not a restatement) | ✓ VERIFIED | `08-ESCALATION.md` exists with all 4 required headings (`## Root Cause`, `## What Was Tried This Phase`, `## Untried Fallback`, `## Requested Decision`). Quotes the specific raw `[FS-01 probe]` Console capture from 08-01-SUMMARY.md verbatim, distinguishing this phase's new CGS-106/107 investigation from the Phase-2/Phase-6 conclusions it corroborates. |
| 9 | 08-03: escalation surfaced to user for an explicit, recorded scope decision (not silently shipped) | ✓ VERIFIED | 08-03-SUMMARY.md's "Task 3 — RESOLVED: option-investigate-b" section records the user's explicit selection and framing (commit `14f4f52`, "docs(08-03): record option-investigate-b decision, closing phase 8"). |

**Score:** 9/9 must-haves verified (8 directly + 1 via documented override)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/FullscreenSpaceProbe.swift` | Reverted to exact pre-08-01 state | ✓ VERIFIED | 85 lines; 0-line diff vs. `dea30c1~1`; contains only `isBuiltinDisplayInFullscreenSpace` and pre-existing bindings |
| `Islet/Notch/NotchWindowController.swift` | Reverted to exact pre-08-01 state | ✓ VERIFIED | 1070 lines; 0-line diff vs. `dea30c1~1`; contains `func updateVisibility`; zero probe-scaffold symbols |
| `.planning/phases/08-fullscreen-enter-flash-elimination/08-ESCALATION.md` | Root-cause escalation report per D-04 | ✓ VERIFIED | Exists; all 4 required sections present; cites concrete phase-8 evidence and Candidate B as the untried fallback |
| `Islet/Notch/FullscreenDetector.swift` | Untouched (08-02 did not run) | ✓ VERIFIED | `shouldShow(hasTarget:hideInFullscreen:isFullscreen:)` — original 3-parameter signature, no `pendingFullscreenTransition` |
| `IsletTests/VisibilityDecisionTests.swift` | Untouched (08-02 did not run) | ✓ VERIFIED | `grep pendingFullscreenTransition` = 0 hits |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `08-ESCALATION.md` | `08-01-SUMMARY.md` | Cites 08-01's on-device timing evidence as the basis for the disproven verdict | ✓ WIRED | Escalation report's "What Was Tried This Phase" section quotes the raw `[FS-01 probe]` Console capture verbatim from 08-01-SUMMARY.md |
| `08-03-SUMMARY.md` Task 0 | `08-01-SUMMARY.md` recorded decision | Precondition guard reads the recorded option before acting | ✓ WIRED | Task 0 confirmed "option-c" before proceeding to Task 1's revert; consistent with 08-02 never touching any files (mutual-exclusivity guard held) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| FS-01 | 08-01, 08-02 (not run), 08-03 | Entering true fullscreen shows no visible island flash at any point during or after the transition | **ESCALATED / OPEN** — not satisfied, not silently dropped | Investigated on-device (Candidate A: CGS 106/107) and disproven; escalation report filed; user selected option-investigate-b (follow-up investigation of Candidate B: `SLSManagedDisplayIsAnimating`). **Requires a NEW phase** (not yet created in ROADMAP.md) to attempt Candidate B. `REQUIREMENTS.md` (line 45, line 16) and `ROADMAP.md`'s Phase 8 checkbox still show "Pending"/unchecked — these should be updated by the phase-completion step to reflect "Escalated, follow-up phase required" rather than left as a plain unresolved "Pending", to avoid this looking like an orphaned/forgotten requirement. |

**No orphaned requirements** — FS-01 is the only requirement mapped to Phase 8, and it is fully accounted for above.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None found | — | `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` scan across `08-ESCALATION.md`, `08-01-SUMMARY.md`, `08-03-SUMMARY.md`, and the two reverted source files returned zero matches |

### Behavioral Spot-Checks

Skipped — this phase's Task 1 verification (`xcodebuild build/test`) is documented in the SUMMARYs and
independently corroborated by the byte-for-byte revert check (a code-level guarantee stronger than a
build re-run for this specific claim: if the files are provably identical to the pre-Phase-8 commit,
the pre-Phase-8 test/build baseline necessarily still holds). Running `xcodebuild` from this
environment was not attempted since the revert-identity check already provides equivalent assurance for
the regression claim, and the flash itself is a real-hardware visual behavior no automated check can
observe.

### Probe Execution

N/A — this phase's "probe" (`FullscreenSpaceProbe.swift`'s DEBUG-only CGS instrumentation) was
diagnostic on-device instrumentation requiring physical notch hardware and human execution
(`checkpoint:decision`/`checkpoint:human-verify` gates in 08-01/08-02), not a `scripts/*/tests/probe-*.sh`
style automated probe. No such script exists in this repository for this phase.

### Human Verification Required

None. All items requiring human action for **this phase's own deliverables** (the D-05 on-device
trigger matrix in 08-01, and the escalation review/decision in 08-03) were already executed by the
user during phase execution and are recorded with raw evidence in 08-01-SUMMARY.md and
08-03-SUMMARY.md. There is nothing left to human-verify for Phase 8 itself.

### Gaps Summary

No blocking gaps in Phase 8's own execution. Both plans (08-01, 08-03) fully achieved their own
must-haves; 08-02 correctly did not execute per its precondition guard. The one ROADMAP success
criterion not literally met (zero flash) is covered by a documented override reflecting the
phase's pre-authorized escalation terminal state.

**Follow-up action required (not a Phase 8 gap, but should not be lost):**
1. FS-01 remains open. A **new phase** must be scoped to attempt Candidate B
   (`SLSManagedDisplayIsAnimating` via a new `SkyLight.framework` linker setting, a `CVDisplayLink`-driven
   poll, and a fullscreen-vs-ordinary-Space-switch disambiguator) — see `08-ESCALATION.md`'s "Untried
   Fallback" section for the full technical shape the user asked for.
2. `.planning/REQUIREMENTS.md` (FS-01 row, currently `[ ]`/"Pending") and `.planning/ROADMAP.md`
   (Phase 8 checkbox and Progress table, currently unchecked/"Not started") should be updated during
   phase-completion to reflect "Escalated — follow-up phase required" rather than plain "Pending", so
   the requirement doesn't read as simply forgotten to a future reader.
3. `.planning/STATE.md`'s `stopped_at`/`last_activity` frontmatter still describes Task 3 as "pending"
   even though it was resolved by commit `14f4f52` — this is normal staleness expected to be corrected
   by the next phase-completion/state-sync step, not a Phase 8 execution defect.

---

*Verified: 2026-07-04T03:19:00Z*
*Verifier: Claude (gsd-verifier)*
