---
phase: 29-notchshape-flare
verified: 2026-07-14T00:35:00+02:00
status: passed
score: 4/4 must-haves verified
overrides_applied: 3
overrides:
  - must_have: "NotchShape.swift artifact contains: var topFlareWidth: CGFloat = 0"
    reason: "Entire topFlareWidth geometry mechanism (property + path branch) was built, iterated through 3 redesigns across ~17 on-device UAT rounds, and abandoned in favor of a plain topCornerRadius value increase at 2 call sites — user-driven, on-device-confirmed final direction (29-CONTEXT.md 'FINAL CORRECTION' section, 2026-07-14). NotchShape.swift ships byte-identical to its pre-Phase-29 form; the ROADMAP-level intent (expanded presentations get a visually distinct, larger top-corner treatment) is satisfied by the simpler mechanism."
    accepted_by: "user (on-device UAT checkpoint, Task 3, '29-01-PLAN.md')"
    accepted_at: "2026-07-14T00:08:38+02:00"
  - must_have: "NotchShapeTests.swift artifact contains: topFlareWidth (4 new tests for zero/non-zero cases)"
    reason: "No topFlareWidth exists in shipped code, so no topFlareWidth tests are needed. One new test (testLargerTopCornerRadiusProducesAClosedNonEmptyPath) was added instead, proving the actually-shipped large-topCornerRadius path stays closed/non-empty — correct regression coverage for what was actually built."
    accepted_by: "user (on-device UAT checkpoint, Task 3)"
    accepted_at: "2026-07-14T00:08:38+02:00"
  - must_have: "NotchPillView.swift artifact contains: static let topFlareWidth: CGFloat = 10, key_links Self.topFlareWidth threading + NotchWindowController.swift panel-frame reservation"
    reason: "No shared flare constant or panel-frame widening is needed for a topCornerRadius-only change — the value never draws outside the shape's own rect, so the plan's panel-frame-clipping contingency in NotchWindowController.swift never applies. 7 blobShape() call sites pass topCornerRadius:24 directly, wingsShape() passes 12, both literal per-callsite (flagged as WR-02 in code review — a real but non-blocking maintainability warning, not a functional gap)."
    accepted_by: "user (on-device UAT checkpoint, Task 3)"
    accepted_at: "2026-07-14T00:08:38+02:00"
---

# Phase 29: NotchShape Flare Verification Report

**Phase Goal:** The expanded island's top edge gains an outward-flaring transition into the screen bezel, threaded through the shared `blobShape()`/`wingsShape()` helpers so every expanded presentation picks it up automatically; the collapsed/idle pill stays pixel-identical to today. (SHAPE-01)

**Verified:** 2026-07-14T00:35:00+02:00
**Status:** passed
**Re-verification:** No — initial verification

## Important note on this verification

The plan's (`29-01-PLAN.md`) `must_haves` frontmatter describes an abandoned `topFlareWidth` geometry design. Per `29-01-SUMMARY.md` and `29-CONTEXT.md`'s "FINAL CORRECTION" section, that design was built, iterated through 4 distinct geometry variants across ~17 on-device UAT rounds within the same session's blocking `checkpoint:human-verify` task, and superseded by a much simpler mechanism: a plain `topCornerRadius` value increase at 2 call sites. This is a legitimate, user-approved architectural deviation, not an unauthorized shortcut — the human-verify checkpoint (Task 3, 7-item on-device checklist) was re-run against the final simple-radius implementation and explicitly "approved" before the plan closed. This verification checks the ROADMAP-level Success Criteria and requirement intent against the code actually on disk, not the plan's superseded literal wording.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Every expanded presentation (Home, Tray, Calendar, Weather, Charging/Device wings) shows a visually larger/distinct top-corner treatment vs. the flush pre-Phase-29 edge (ROADMAP SC#1) | VERIFIED | `grep` confirms all 7 `blobShape(topCornerRadius: 24, bottomCornerRadius: 32, ...)` call sites (`NotchPillView.swift:443,477,661,727,775,1497,1566`, covering Home/Tray/Calendar/Weather) and `wingsShape()`'s `NotchShape(topCornerRadius: 12, bottomCornerRadius: 6)` (line 1178, covering Charging/Device wings) — both raised from the pre-Phase-29 baseline of `6`. Wall-thickness arithmetic re-checked independently (14pt side wall for the 290×32 wings rect at 12/6 — positive, non-degenerate, matches code review's own check). |
| 2 | The collapsed/idle pill renders pixel-identical to today — no shape, size, or position regression (ROADMAP SC#2, D-03) | VERIFIED | `collapsedIsland` (`NotchPillView.swift:416`) still calls plain `NotchShape()` (defaults `topCornerRadius: 6, bottomCornerRadius: 14`) — confirmed byte-identical via direct read, zero diff from pre-phase. |
| 3 | The Now-Playing media wings / song-change toast (`mediaWingsOrToast`) stays flush like the collapsed pill — no flare (D-03/D-04) | VERIFIED | `NotchPillView.swift:1242` — `NotchShape(topCornerRadius: 6, bottomCornerRadius: toast != nil ? 16 : 6)`, untouched, `topCornerRadius: 6` unchanged from baseline. |
| 4 | The flare animates smoothly as part of the existing collapse↔expand spring morph, no dropped frames/artifacts/clipping (ROADMAP SC#3) | VERIFIED | `NotchShape.topCornerRadius`/`bottomCornerRadius` are plain `CGFloat` stored properties on a SwiftUI `Shape` (own doc comment: "Plain CGFloat stored properties → SwiftUI's Shape animation INTERPOLATES these across the ... morph") — this interpolation mechanism pre-dates Phase 29 and needed no new code. The topCornerRadius-only design draws entirely within each presentation's own rect, so `NotchWindowController.swift`'s panel-frame reservation needs no widening (confirmed: only a documentation comment was added there, no `CGSize` math changed — `git diff` shows a comment-only hunk). This truth was also directly confirmed by the phase's own blocking `checkpoint:human-verify` Task 3 (7-item on-device checklist, re-run against the final implementation, resolved "approved" 2026-07-14 per `29-01-SUMMARY.md`) — on-device visual/animation behavior is not independently re-testable by this verifier and the checkpoint already constitutes the on-device evidence this class of truth requires. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected (plan's literal wording) | Actual (shipped) | Status |
|----------|-----------|--------|--------|
| `Islet/Notch/NotchShape.swift` | `topFlareWidth` stored property + widened path math | Zero-diff vs. pre-Phase-29 — confirmed by direct read matching plan's own quoted "before" snapshot exactly | PASSED (override) — design superseded, ROADMAP intent met via simpler mechanism |
| `IsletTests/NotchShapeTests.swift` | 4 new tests covering `topFlareWidth` zero/non-zero cases | 1 new test `testLargerTopCornerRadiusProducesAClosedNonEmptyPath` (24/32 radii, 360×144 rect) — existing 3 tests unmodified | PASSED (override) — correct coverage for what shipped; WR-01 (below) flags a real but non-blocking coverage gap for the tighter wings geometry |
| `Islet/Notch/NotchPillView.swift` | `static let topFlareWidth: CGFloat = 10` + threading into `blobShape()`/`wingsShape()` | 7 `blobShape()` call sites at literal `topCornerRadius: 24`; `wingsShape()` at literal `12`; `collapsedIsland`/`mediaWingsOrToast` untouched | PASSED (override) — functionally complete; WR-02 (below) flags the literal-value duplication (no shared constant) as a maintainability warning |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `NotchPillView.swift blobShape()/wingsShape()` | `NotchShape(..., topFlareWidth: Self.topFlareWidth)` | shared constant | N/A — superseded | No `topFlareWidth` parameter exists anywhere in the codebase (`grep -rn "topFlareWidth" Islet/ IsletTests/` = 0 hits); design abandoned per override above |
| `NotchWindowController.swift positionAndShow(on:)` | `NotchPillView.topFlareWidth` | panel-frame width reservation contingency | N/A — contingency never triggered | `git diff` on `NotchWindowController.swift` since before this phase shows only a documentation comment added (no `CGSize` math changed) — correct, since a within-rect `topCornerRadius` change never needs extra panel width |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SHAPE-01 | 29-01-PLAN.md | "The expanded-state notch silhouette gains an outward-flaring top-edge transition into the screen bezel; the idle/collapsed pill shape stays exactly as it is today" | SATISFIED | Truths 1-4 above; `REQUIREMENTS.md:69` already marks `SHAPE-01 | Phase 29 | Complete`; `REQUIREMENTS.md:31` checkbox `[x]` |

No orphaned requirements — `REQUIREMENTS.md` maps only SHAPE-01 to Phase 29, and it is the sole ID declared in `29-01-PLAN.md`'s frontmatter.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `IsletTests/NotchShapeTests.swift` | 47-53 | New regression test (`testLargerTopCornerRadiusProducesAClosedNonEmptyPath`) only exercises the safe 360×144/24×32 blob case, not the tight 290×32/12×6 wings case actually shipped | ⚠️ Warning (carried from 29-REVIEW.md WR-01) | A future tuning pass bumping wings' `topCornerRadius` toward 24 (explicitly warned against in the inline comment) would have no test catching a near-zero/negative wall regression |
| `Islet/Notch/NotchPillView.swift` | 443,477,661,727,775,1497,1566,1178 | Flare corner radii (`24`/`32`/`12`) are bare literals repeated across 8 call sites instead of a named `static let`, breaking this file's own established single-source-of-truth convention (`expandedSize`, `wingsSize`, `cameraClearance`, etc.) | ⚠️ Warning (carried from 29-REVIEW.md WR-02) | Next tuning pass (Phase 30+ per plan's own `affects:` list) must find/edit 8 call sites by hand with no compiler assistance if one is missed |

No `TBD`/`FIXME`/`XXX`/`HACK` debt markers found in any of the 3 files modified by this phase (`NotchShape.swift`, `NotchPillView.swift`, `NotchShapeTests.swift`) — grep matches on "placeholder" in `NotchPillView.swift` are all pre-existing, unrelated references to album-art fallback icon text, not Phase-29 debt.

Both warnings above are pre-existing findings from `29-REVIEW.md` (issues_found: 0 critical / 2 warning / 1 info) — re-confirmed present in the current code, not fixed since that review, but neither blocks SHAPE-01's goal achievement; both are quality/maintainability concerns for future tuning passes, not functional defects.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Project builds with the shipped geometry | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` | `** BUILD SUCCEEDED **` | ✓ PASS |
| No leftover `topFlareWidth` references anywhere in source/tests | `grep -rn "topFlareWidth" Islet/ IsletTests/` | 0 matches | ✓ PASS (confirms full revert, matching SUMMARY's claim) |
| Wings tight-geometry wall arithmetic (12/6 radii on 290×32 rect) is non-degenerate | manual arithmetic: `height - (topR+bottomR) = 32-18 = 14pt`, `width - 2*(topR+bottomR) = 290-36 = 254pt` | both positive | ✓ PASS |

Unit test execution (`IsletTests/NotchShapeTests.swift`, all 4 tests) was not re-run by this verifier — per project memory `xcodebuild-test-headless-hang`, `xcodebuild test` hangs booting the full `Islet.app`; the project's established convention routes actual test runs to manual Cmd-U in Xcode, already covered by the phase's Task 3 on-device checkpoint. Test *compilation* is covered by the successful `xcodebuild build` above (test target compiles as part of the scheme).

### Human Verification Required

None. The phase's own blocking `checkpoint:human-verify` Task 3 (7-item on-device checklist: flare look, panel-edge clipping, all-5-presentation coverage, both zero-diff exclusions, morph smoothness, click-through regression) was already run on real notch hardware within this phase's execution and resolved "approved" before the plan closed (`29-01-SUMMARY.md`, `29-01-PLAN.md` Task 3 `resume-signal`). Re-running the same on-device checks in this verification pass would be redundant — per project convention (memory: `feedback-skip-verify-work-after-checkpoints`), phase-internal human-verify checkpoints that already covered the ROADMAP success criteria on-device are not re-solicited here.

### Gaps Summary

No blocking gaps. All 4 observable truths (mapped from ROADMAP Phase 29's 3 Success Criteria plus the D-03/D-04 exclusion truth) are verified against the code actually on disk. The plan's literal `must_haves` artifacts/key_links describe an abandoned `topFlareWidth` design that was fully reverted after ~17 on-device UAT rounds in favor of a simpler `topCornerRadius` value bump — this is documented as a user-approved override above, not a failure. Two non-blocking WARNINGs carried over from `29-REVIEW.md` (missing tight-geometry regression test, duplicated magic-number radii instead of a shared constant) remain unaddressed in the current code — worth a follow-up quick-fix before Phase 30+ tunes these same values again, but they do not block Phase 29's goal achievement or Phase 30's start.

---

_Verified: 2026-07-14T00:35:00+02:00_
_Verifier: Claude (gsd-verifier)_
