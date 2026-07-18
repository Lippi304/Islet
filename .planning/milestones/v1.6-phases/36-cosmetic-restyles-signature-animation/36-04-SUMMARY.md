---
phase: 36-cosmetic-restyles-signature-animation
plan: 4
subsystem: ui
tags: [swiftui, coretext, onboarding, signature-heading, gradient]

# Dependency graph
requires:
  - phase: 36-03
    provides: Dancing Script Bold font bundling + registration (loadSignatureFont), glyph-extraction contract (superseded, no longer used post-pivot)
provides:
  - Static, non-animated "Meet Islet" signature heading on the onboarding Welcome step, rendered in Dancing Script Bold with two independent linear gradients ("Meet" blue→purple→pink, "Islet" orange→yellow→green)
affects: [onboarding-flow, future-onboarding-visual-polish]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Static per-word LinearGradient .foregroundStyle on a Text view, reusing an existing CTFont-loading helper — no TimelineView/per-frame clock required for this kind of decorative heading"]

key-files:
  created: []
  modified:
    - Islet/Notch/SignatureHeading.swift
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "D-14: scope pivot — abandoned the per-glyph stroke-reveal animation (Core Text glyph paths + TimelineView + .trim) entirely in favor of a fully static two-word rainbow-gradient heading, mirroring Droppy's own 'meet droppy' static heading, after repeated stroke-weight tuning friction and no clean resolution"
  - "Font-licensing swap from Plan 36-03 (D-12) stays locked: Dancing Script Bold (OFL) instead of the reference's all-rights-reserved Lastoria Bold"

requirements-completed: [ONBOARD-04]

# Metrics
duration: multi-session (spans several on-device UAT rounds + 1 scope pivot)
completed: 2026-07-16
---

# Phase 36 Plan 4: Signature Heading (Static Rainbow-Gradient Pivot) Summary

**Onboarding "Meet Islet" heading ships as a static, non-animated two-word script heading — "Meet" in a blue→purple→pink gradient, "Islet" in an orange→yellow→green gradient, both in bundled Dancing Script Bold — after abandoning the originally-planned per-glyph stroke-reveal animation mid-execution.**

## Performance

- **Duration:** Multi-session, spanning several on-device UAT rounds and one full scope pivot
- **Tasks:** 3 (Task 1 + Task 2 as originally planned were fully superseded in content by the pivot commit; Task 3 checkpoint carried through to the final static design and was approved)
- **Files modified:** 2 (`SignatureHeading.swift`, `NotchPillView.swift`)

## Accomplishments
- Onboarding Welcome step's heading is now a static, legible, rainbow-gradient "Meet Islet" in a script font, matching the Droppy reference precedent the user pivoted to
- Font-licensing risk (D-12) resolved and stays resolved: Dancing Script Bold (SIL OFL 1.1) is the shipped font, not the reference's all-rights-reserved Lastoria Bold
- `onboardingWelcomeStep` wiring (`SignatureHeading()` in place of the old plain `Text("Meet Islet")`) is intact; body subtext untouched (D-13)
- Full project build verified clean (`xcodebuild build -scheme Islet -destination 'platform=macOS'` — BUILD SUCCEEDED) as the final gate before closing this plan
- User confirmed the final static design on-device: "passt"

## Task Commits

Each task was committed atomically as execution progressed, including two dead ends that were later superseded:

1. **Task 1: Staggered stroke-then-fill reveal animation** — `b3b9f36` (feat) — original stroke-reveal mechanism; **superseded** by the later pivot commit
2. **Task 2: Wire SignatureHeading into onboardingWelcomeStep** — `b334c37` (feat) — wiring itself carried through unchanged in substance (still `SignatureHeading()` call site), only the component's internals changed later
3. `be4bdbf` (debug) — diagnostic logging added to trace an onboarding-not-appearing UAT issue; root cause turned out to be a stray background app instance, not a code bug
4. `981f20c` (debug) — diagnostic logging from `be4bdbf` removed once the root cause was identified
5. `a58fc64` (fix) — stroke-weight tuning (6.16pt → 1.75pt) on the stroke-reveal mechanism; **superseded** — the entire stroke mechanism this commit tunes was deleted in the next commit
6. **Task 3 (scope pivot): replace stroke-reveal with static rainbow-gradient heading** — `e3398d2` (feat) — the ACTUAL final shipped `SignatureHeading.swift`; supersedes commits 1 and 5 above in full; also updated `36-CONTEXT.md` (D-14), `36-UI-SPEC.md` (Signature Heading Contract), and `.planning/REQUIREMENTS.md` (ONBOARD-04 reworded)

**Plan metadata:** (this commit) `docs(36-04): complete plan with SUMMARY after scope pivot to static gradient heading`

_Note: this plan's commit history includes two "dead end" implementation attempts (the stroke-reveal mechanism and its stroke-weight tuning) that were fully replaced by the final pivot commit. They are retained in git history for traceability but no longer exist in the shipped code._

## Files Created/Modified
- `Islet/Notch/SignatureHeading.swift` - Renders "Meet Islet" as two `Text` views, each with a `LinearGradient` `.foregroundStyle`, in bundled Dancing Script Bold (28pt). No animation, no `TimelineView`, no per-frame clock. The glyph-path-extraction infra from Plan 36-03 (`glyphPaths`/`totalWidth`) is no longer used by this view (superseded by the pivot) but the file itself was rewritten rather than deleted — `loadSignatureFont` is reused as-is.
- `Islet/Notch/NotchPillView.swift` - `onboardingWelcomeStep` calls `SignatureHeading()` in place of the old plain `Text("Meet Islet")`; body subtext line is byte-identical to before this phase (D-13).

## Decisions Made
- **D-14 (scope pivot, documented in `36-CONTEXT.md`):** After repeated implementation friction — the D-12 font-licensing swap, then multiple stroke-weight recalibrations that still didn't read right on-device, plus general Canvas/TimelineView/`.trim()` complexity for what is a single onboarding screen — the user made an explicit decision to abandon the stroke-reveal animation entirely in favor of a fully static two-word rainbow-gradient heading, mirroring Droppy's own "meet droppy" onboarding heading. Quote (German): "Lass uns keine Unterschrift Animation machen sondern einfach wie bei Droppy eben so eine Unterschrift Textart einfach in Regenbogen Farbverlauf."
- What stayed locked through the pivot: the text itself ("Meet Islet", D-09), the font substitute (Dancing Script Bold, OFL, D-12), and the untouched body subtext (D-13).
- What was superseded: D-10's stroke-reveal mechanism (Core Text glyph-path extraction + `.trim(from:to:)` animation + `TimelineView` clock) and D-11's single fixed-orange color — replaced by two `Text` views with per-word `LinearGradient` fills.
- `ONBOARD-04`'s own requirement wording in `.planning/REQUIREMENTS.md` was updated in commit `e3398d2` to drop "reveal animation," now reading "static rainbow-gradient signature-style script heading" — this SUMMARY flips its status to complete against that updated wording, not the plan's original literal wording.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 4 - Architectural/scope change, user-directed] Replaced the entire per-glyph stroke-reveal animation with a static rainbow-gradient heading**
- **Found during:** Task 3 (on-device UAT)
- **Issue:** The originally-planned stroke-reveal animation (Core Text glyph extraction, staggered `.trim()` reveal, `TimelineView` clock) went through repeated stroke-weight tuning rounds (6.16pt → 1.75pt) without ever reading correctly on real hardware, on top of a general complexity/fragility concern for a single onboarding screen.
- **Fix:** Per explicit user direction, the entire stroke-reveal mechanism was deleted and replaced with a fully static design: two `Text` views ("Meet", "Islet") each with their own `LinearGradient` `.foregroundStyle`, still in the Dancing Script Bold font from Plan 36-03. This is a Rule 4 (architectural change) deviation escalated to and resolved by the user directly, not auto-applied — recorded here for completeness since it happened mid-plan-execution rather than at planning time.
- **Files modified:** `Islet/Notch/SignatureHeading.swift`, `.planning/phases/36-cosmetic-restyles-signature-animation/36-CONTEXT.md` (new D-14), `.planning/phases/36-cosmetic-restyles-signature-animation/36-UI-SPEC.md`, `.planning/REQUIREMENTS.md` (ONBOARD-04 reworded)
- **Verification:** `xcodebuild build -scheme Islet -destination 'platform=macOS'` succeeds; user confirmed the final static design on-device ("passt")
- **Committed in:** `e3398d2`

---

**Total deviations:** 1 user-directed scope pivot (architectural, Rule 4). No auto-fixes beyond this were needed for the final shipped code.
**Impact on plan:** The plan's original Task 1 acceptance criteria (stroke-reveal grep checks, `TimelineView` idle-CPU threat mitigation T-36-07) no longer apply to the shipped code — they described a mechanism that was deleted. T-36-07 itself is moot post-pivot since there is no clock to leak. Task 2's wiring and Task 3's human-verify checkpoint both carried through to the final design unchanged in substance.

## Issues Encountered
- Onboarding didn't appear at all during an early UAT round — root cause was a stray background app instance already running, not a code bug. Diagnostic logging was added (`be4bdbf`) then removed (`981f20c`) once this was identified; no code fix was needed.
- The font-licensing concern (D-12) resurfaced during Task 1 execution: the reference's original font, Lastoria Bold, is confirmed all-rights-reserved and not legally shippable in a paid product. The user was informed and did not pursue seeking a commercial license; Dancing Script Bold (OFL, already bundled from Plan 36-03) remained the shipped substitute throughout, including after the pivot.
- Multiple stroke-weight tuning rounds on the (now-abandoned) stroke-reveal mechanism did not resolve the underlying visual-quality concern before the user decided to pivot away from the mechanism entirely.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- ONBOARD-04 is complete against its updated (post-pivot) requirement wording.
- This was the last plan in Phase 36 (Cosmetic Restyles & Signature Animation) — Phase 36's own remaining plans (36-01, 36-02, 36-03) were already complete; formal phase-level verification and ROADMAP phase-completion marking are left to the orchestrator, not done here.
- No blockers carried forward from this plan.

---
*Phase: 36-cosmetic-restyles-signature-animation*
*Completed: 2026-07-16*

## Self-Check: PASSED

- FOUND: Islet/Notch/SignatureHeading.swift (static rainbow-gradient implementation confirmed via direct read)
- FOUND: Islet/Notch/NotchPillView.swift (`SignatureHeading()` call site confirmed at line 1508)
- FOUND commit b3b9f36 (git log --oneline --all)
- FOUND commit b334c37 (git log --oneline --all)
- FOUND commit be4bdbf (git log --oneline --all)
- FOUND commit 981f20c (git log --oneline --all)
- FOUND commit a58fc64 (git log --oneline --all)
- FOUND commit e3398d2 (git log --oneline --all)
- FOUND: `xcodebuild build -scheme Islet -destination 'platform=macOS'` re-run for this finalization → BUILD SUCCEEDED
