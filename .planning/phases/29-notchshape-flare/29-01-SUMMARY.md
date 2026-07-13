---
phase: 29-notchshape-flare
plan: 01
subsystem: ui
tags: [swiftui, shape, notch, geometry]

# Dependency graph
requires: []
provides:
  - Larger `topCornerRadius` (24pt blob / 12pt wings) at every expanded presentation's top corners, giving the "flare" look via the existing quad-curve corner mechanism instead of new geometry
affects: [30-home-music-only, 32-tray-widening, 33-weather-widget-redesign]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - Islet/Notch/NotchShape.swift (net zero-diff vs. pre-Phase-29 — reverted back to original after detour)
    - Islet/Notch/NotchPillView.swift (7 blobShape call sites 6→24, wingsShape 6→12; collapsedIsland/mediaWingsOrToast untouched)
    - IsletTests/NotchShapeTests.swift (added testLargerTopCornerRadiusProducesAClosedNonEmptyPath)

key-decisions:
  - "SHAPE-01 shipped as a plain topCornerRadius increase (24pt blob, 12pt wings) at 2 call sites — no new NotchShape property, no new path geometry, superseding every other geometry design explored during the same session (concave sweep, shoulder bulge, centered camera-notch dip)"
  - "wingsShape uses 12pt (not the blob's 24pt) because the wings' 32pt-tall strip can't fit a 24pt top radius alongside its existing 6pt bottom radius without squeezing the side wall to near-zero"
  - "collapsedIsland and mediaWingsOrToast stay at topCornerRadius: 6 (D-03/D-04, unchanged) — confirmed pixel-identical on-device"

patterns-established: []

requirements-completed: [SHAPE-01]

# Metrics
duration: 5h 58min (on-device UAT iteration across ~22 commits, single overnight session)
completed: 2026-07-14
---

# Phase 29 Plan 01: NotchShape Flare Summary

**SHAPE-01 shipped as a simple `topCornerRadius` bump (6→24 at the blob, 6→12 at wings) on the 2 expanded-presentation call sites — not the `topFlareWidth` geometry the plan originally specified, which was built, iterated through 3 distinct designs across ~17 on-device UAT rounds, and ultimately abandoned as unnecessary.**

## Performance

- **Duration:** ~5h 58min wall-clock (18:10 → 00:08), almost entirely on-device UAT iteration
- **Started:** 2026-07-13T18:10:00+02:00
- **Completed:** 2026-07-14T00:08:38+02:00
- **Tasks:** 3 (Task 1 + Task 2 implemented as planned; Task 3's on-device checkpoint drove ~17 additional correction rounds before final approval)
- **Files modified:** 3 (`NotchShape.swift`, `NotchPillView.swift`, `NotchShapeTests.swift`)

## Accomplishments
- Every expanded presentation (Home, Tray, Calendar, Weather, Charging/Device wings) now shows a visibly larger, smoother top-corner radius than the collapsed pill and media toast, satisfying ROADMAP Phase 29 Success Criterion #1.
- Collapsed/idle pill and Now-Playing media wings/toast confirmed pixel-identical to pre-Phase-29 (Success Criterion #2) — their `NotchShape` call sites were never touched.
- Morph between collapsed and expanded states stays smooth (Success Criterion #3) — `topCornerRadius` was already a plain animatable `Shape` property before this phase; no new animation mechanism was needed.
- `NotchShape.swift` itself ends this plan byte-identical to its pre-Phase-29 state — all geometry experiments were fully reverted.

## What Was Actually Shipped (read this before touching `NotchShape`/`NotchPillView` again)

The plan's `must_haves` (see `29-01-PLAN.md` frontmatter) describe a `topFlareWidth: CGFloat` stored property on `NotchShape` that widens the top edge outward past the shape's own rect. **That design was built and then fully abandoned.** It does not exist in the shipped code. Anyone reading the plan literally will be confused by the current diff — this section is the authoritative record of what the code actually does and why.

**Final shipped mechanism:**
- `NotchShape.swift` — **zero diff** from its pre-Phase-29 form. No `topFlareWidth`, no new path branch, no `addArc`/`addCurve`. Still just `topCornerRadius`/`bottomCornerRadius` quad-curves, exactly as before Phase 29.
- `NotchPillView.swift`:
  - The 7 `blobShape(topCornerRadius: ..., bottomCornerRadius: 32, ...)` call sites (Home/Tray/Calendar/Weather, lines 443/477/661/727/775/1497/1566) now pass `topCornerRadius: 24` (was `6`).
  - `wingsShape()`'s internal `NotchShape(topCornerRadius: 12, bottomCornerRadius: 6)` (line 1178) — was `topCornerRadius: 6`, raised to `12` (not `24`, because the wings' 32pt-tall strip can't fit the blob's full 24pt radius alongside its own 6pt bottom radius without squeezing the side wall to almost nothing — documented inline at that line).
  - `collapsedIsland` (line 416, plain `NotchShape()`) and `mediaWingsOrToast` (line 1242, `NotchShape(topCornerRadius: 6, bottomCornerRadius: ...)`) are **untouched** — still `topCornerRadius: 6`, confirmed pixel-identical on-device (D-03/D-04).
- `IsletTests/NotchShapeTests.swift` — the plan's originally-specified 4 new tests (for `topFlareWidth: 0`/non-zero behavior) do not exist; instead one new test, `testLargerTopCornerRadiusProducesAClosedNonEmptyPath`, proves a large `topCornerRadius` (24/32) still produces a valid closed path — the correct regression coverage for what was actually shipped. The original 3 tests are unchanged.

**Why the abandoned designs failed on-device (in order, all same session, all reverted):**
1. **Original plan's subtle `topFlareWidth` widen (~10pt outward bulge, D-01 original):** built first, per plan. On-device it read as imperceptible — no visible change from today's existing 6pt corner curve.
2. **Pronounced concave sweep (D-01/D-05 REVISED):** user referenced Droppy's shelf widget — narrow flat top band (notch-width) sweeping concave out to full width. Built; hit multiple geometry/rendering bugs (path discontinuity, bulge clipped by the panel's own render frame — root-caused to bounds overflowing the SwiftUI content root's frame). Fixed through several rounds, but the *design* itself was then reconsidered.
3. **Shoulder-bulge (flush full-width top, with a bump swinging out then back in):** built after the concave sweep's wide body reads as "recessed away from the true screen edge." On-device this read as **"eine Kugel"** (a ball/knob) — a round protrusion, not the continuous flowing funnel the Droppy reference actually shows.
4. **Centered camera-notch dip (flush sides, narrow center recesses downward like a dimple):** user's own re-examination of the reference suggested the geometry was inverted — sides flush, center dips, rather than center narrow/sides flare. Built, tuned across several width/depth rounds — still read as "nothing changes" on-device.
5. **FINAL, correct answer (2026-07-14):** user provided a tight crop of the actual reference detail — it was **just a big, smooth, simple quarter-circle top-corner radius**, nothing to do with a notch/dip/bulge at all. This collapsed the entire feature to "increase `topCornerRadius` at 2 call sites," reverting all prior geometry work.

All intermediate designs (2 through 4) are visible in the git history as `feat(29-01)`/`fix(29-01)`/`debug(29-01)` commits between `0fcd2de` and `16d6340` — kept for historical traceability, fully superseded by `dd3bfed`.

## Task Commits

Task 1/2 (as planned) plus the full on-device UAT correction arc (Task 3, checkpoint-gated):

1. **Task 1: NotchShape topFlareWidth property + path geometry** — `0fcd2de` (feat) — original plan design, later fully reverted
2. **Task 2: Wire the flare into blobShape()/wingsShape()** — `93a9a74` (feat) — original plan design, later fully reverted
3. **Task 3: On-device UAT** — checkpoint-gated, ~19 iterative commits from `cc62263` through `16d6340` covering the panel-clipping fix, concave-sweep redesign, shoulder-bulge detour, centered-notch-dip detour, and their respective diagnostic/tuning rounds
4. **Final correction (superseding all of the above):** `dd3bfed` (fix) — replaced all flare geometry with a simple larger `topCornerRadius`; this is the commit that matches the code currently on disk

**Plan metadata:** this commit (docs: complete plan)

_Full commit range: `0fcd2de..dd3bfed` (22 commits total, single session 2026-07-13 18:10 → 2026-07-14 00:08)._

## Files Created/Modified
- `Islet/Notch/NotchShape.swift` — net zero-diff vs. pre-Phase-29 (all experimental geometry reverted)
- `Islet/Notch/NotchPillView.swift` — 7 `blobShape` call sites raised `topCornerRadius` 6→24; `wingsShape()` raised 6→12; `collapsedIsland`/`mediaWingsOrToast` untouched
- `IsletTests/NotchShapeTests.swift` — added `testLargerTopCornerRadiusProducesAClosedNonEmptyPath`

## Decisions Made
- SHAPE-01 implemented as a `topCornerRadius` value change only — no new `NotchShape` parameter, no new path geometry (final user-confirmed direction, 2026-07-14, superseding D-01/D-02/D-05 and every geometry variant explored this session).
- Wings get `12pt` (not the blob's `24pt`) due to the wings' fixed 32pt height leaving no room for a 24pt top radius alongside the existing 6pt bottom radius.
- The plan's `must_haves` artifacts (topFlareWidth property, its threading, its 4 new tests) are **not** present in the final code — see "What Was Actually Shipped" above for the full rationale. This is documented here rather than silently diverging so future readers of `29-01-PLAN.md` aren't misled by its literal wording.

## Deviations from Plan

### Architectural deviation (superseding, user-approved on-device across the same UAT session — not a Rule 1-3 auto-fix)

**1. Entire `topFlareWidth` geometry mechanism replaced with a `topCornerRadius` value bump**
- **Found during:** Task 3 (on-device UAT), across ~17 rounds spanning 2026-07-13 18:16 through 2026-07-14 00:08
- **Issue:** The plan's `topFlareWidth` design (and its 3 subsequent redesigns — concave sweep, shoulder bulge, centered notch dip) never matched the user's actual visual reference on-device, despite multiple rounds of geometry/rendering-pipeline bug fixes along the way (path discontinuities, panel-frame clipping, SwiftUI content-root frame overflow).
- **Fix:** Reverted `NotchShape.swift` to its exact pre-Phase-29 form and instead raised the existing `topCornerRadius` argument at the 2 relevant call sites (`blobShape()` to 24, `wingsShape()` to 12). This is the code currently on disk.
- **Files modified:** `Islet/Notch/NotchShape.swift`, `Islet/Notch/NotchPillView.swift`, `IsletTests/NotchShapeTests.swift`
- **Verification:** On-device UAT approved 2026-07-14 — all 7 of Task 3's original checklist items reconfirmed against the final simple-radius implementation (flare look on all 5 presentations, wings proportions at 12pt, collapsed pill and media toast pixel-identical/zero-diff, morph smoothness, click-through unaffected).
- **Committed in:** `dd3bfed`

This was driven entirely by iterative on-device visual feedback against a user-supplied reference (not a bug in the traditional sense) — flagged here as an architectural-scope deviation from the plan's literal `must_haves`, not a Rule 1/2/3 auto-fix, since the user was actively steering the design across the session.

---

**Total deviations:** 1 (design-superseding, user-driven, not a Rule 1-3 category)
**Impact on plan:** The plan's literal `must_haves` (topFlareWidth property/tests/threading) are not what shipped. SHAPE-01's actual requirement — expanded presentations get a visually distinct, larger top-corner treatment than the collapsed pill/media toast — is satisfied by the simpler mechanism. No scope creep; net line count decreased (all experimental geometry reverted).

## Issues Encountered
- Multiple on-device rendering bugs surfaced and were fixed during the abandoned geometry designs (path discontinuity in the shoulder-bulge curve, flare bulge clipped by the SwiftUI content-root's own frame, panel-frame reservation logic) — all became moot once the design collapsed to a plain `topCornerRadius` change, since that value never draws outside the shape's own rect. No outstanding issues remain in the shipped code.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 29 (SHAPE-01) is complete and approved on-device. `NotchShape.swift` is back to its simple, well-understood pre-Phase-29 form — no lingering complexity for Phase 30+ to build on top of.
- No blockers for Phase 30 (Home Music-Only) or any other v1.5 phase — this phase touched only 2 `topCornerRadius` call-site values plus test coverage, nothing structural.

---
*Phase: 29-notchshape-flare*
*Completed: 2026-07-14*

## Self-Check: PASSED

- FOUND: `Islet/Notch/NotchShape.swift` (verified zero-diff vs. pre-Phase-29)
- FOUND: `Islet/Notch/NotchPillView.swift` (verified 7 blobShape sites at 24, wingsShape at 12, collapsedIsland/mediaWingsOrToast untouched)
- FOUND: `IsletTests/NotchShapeTests.swift` (verified `testLargerTopCornerRadiusProducesAClosedNonEmptyPath` present)
- FOUND: commit `0fcd2de` (Task 1)
- FOUND: commit `93a9a74` (Task 2)
- FOUND: commit `cc62263` (Task 3 iteration start)
- FOUND: commit `16d6340` (Task 3 iteration, pre-final)
- FOUND: commit `dd3bfed` (final shipped mechanism)
