---
phase: 29-notchshape-flare
reviewed: 2026-07-14T00:22:00+02:00
depth: standard
files_reviewed: 3
files_reviewed_list:
  - Islet/Notch/NotchShape.swift
  - Islet/Notch/NotchPillView.swift
  - IsletTests/NotchShapeTests.swift
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Phase 29: Code Review Report

**Reviewed:** 2026-07-14T00:22:00+02:00
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Phase 29 shipped SHAPE-01 as a minimal value-only change: `NotchShape.swift` is confirmed byte-identical to its pre-Phase-29 form (no new stored properties, no new path branches — verified by direct read, not just trusting the SUMMARY's claim). `NotchPillView.swift`'s diff is exactly the 7 `blobShape(topCornerRadius: 24, bottomCornerRadius: 32, ...)` call sites (lines 443, 477, 661, 727, 775, 1497, 1566 — grep-confirmed, none missed, none inconsistent) plus `wingsShape()`'s internal `NotchShape(topCornerRadius: 12, bottomCornerRadius: 6)` (line 1178). `collapsedIsland` (plain `NotchShape()`, defaults 6/14) and `mediaWingsOrToast` (line 1242, `topCornerRadius: 6` explicit) are confirmed untouched.

Arithmetic check on the flagged risk area (wingsShape's 290×32 rect at topR 12 / bottomR 6): the shape's side-wall length is `height − (topR + bottomR) = 32 − 18 = 14pt` and the bottom-edge width is `width − 2×(topR+bottomR) = 290 − 36 = 254pt` — both comfortably positive, no wall inversion, no degenerate path. The comment's stated reason for not using 24pt here (`24 + 6 = 30`, leaving only a 2pt wall) is arithmetically correct. No BLOCKER-class defects found in the touched regions. Two WARNINGs concern test-coverage placement and a magic-number/duplication regression risk that this file's own conventions elsewhere avoid.

## Warnings

### WR-01: New regression test covers the safe geometry, not the tight one the review brief flags as risky

**File:** `IsletTests/NotchShapeTests.swift:47-53`
**Issue:** The only new test added for SHAPE-01 (`testLargerTopCornerRadiusProducesAClosedNonEmptyPath`) exercises `NotchShape(topCornerRadius: 24, bottomCornerRadius: 32)` against a `360×144` rect — the blob case, which has huge margin (`144 − 56 = 88pt` of wall) and was never at risk of inversion. The actually tight configuration shipped in this same phase — `wingsShape()`'s `NotchShape(topCornerRadius: 12, bottomCornerRadius: 6)` against the real `290×32` wings rect (only a 14pt wall) — has no dedicated test at all. If a future tuning pass bumps the wings' `topCornerRadius` toward 24 (as the inline comment warns not to), nothing in the test suite would catch the resulting near-zero/negative wall before it reached an on-device UAT cycle — exactly the class of regression this phase spent ~22 commits chasing manually.
**Fix:**
```swift
func testWingsTightRadiiStillProduceAClosedNonEmptyPath() {
    // wingsShape()'s real geometry: 290x32 rect, topCornerRadius:12, bottomCornerRadius:6 —
    // the tight case flagged in NotchPillView.swift:1178 (only a 14pt side wall).
    let path = NotchShape(topCornerRadius: 12, bottomCornerRadius: 6)
        .path(in: CGRect(x: 0, y: 0, width: 290, height: 32))
    let cgBounds = path.cgPath.boundingBox
    XCTAssertFalse(path.cgPath.isEmpty)
    XCTAssertGreaterThan(cgBounds.width, 0)
    XCTAssertGreaterThan(cgBounds.height, 0)
}
```

### WR-02: Flare corner radii are bare magic numbers duplicated across 7+ call sites, breaking this file's own established constant convention

**File:** `Islet/Notch/NotchPillView.swift:443,477,661,727,775,1497,1566,1178`
**Issue:** `NotchPillView.swift` consistently extracts every other tunable geometry value into a named `static let` (`collapsedSize`, `expandedSize`, `wingsSize`, `shelfRowHeight`, `switcherRowHeight`, `cameraClearance`, `calendarCellSize`, `onboardingSize`, etc.) specifically so "a single tuning pass updates every consumer" (see `cameraClearance`'s own doc comment, line ~261-264, making exactly this argument). SHAPE-01 breaks that convention: `topCornerRadius: 24, bottomCornerRadius: 32` is a literal repeated verbatim at 7 separate call sites, and `wingsShape()`'s `12`/`6` is a separate inline literal. The 22-commit UAT history for this exact phase (per `29-01-SUMMARY.md`) shows these values were tuned repeatedly during the session — the next tuning pass (e.g., Phase 30+ widening per the plan's own `affects:` list) has to find and edit 7 call sites by hand with no compiler help if one is missed.
**Fix:**
```swift
// Phase 29 / SHAPE-01 — the flare treatment: every expanded blob presentation shares one
// larger top-corner radius; single source of truth for the next tuning pass.
static let flareTopCornerRadius: CGFloat = 24
static let flareBottomCornerRadius: CGFloat = 32
```
Then use `blobShape(topCornerRadius: Self.flareTopCornerRadius, bottomCornerRadius: Self.flareBottomCornerRadius, ...)` at all 7 sites, and add a `wingsFlareTopCornerRadius: CGFloat = 12` constant for `wingsShape()`'s line 1178.

## Info

### IN-01: Path-validity tests only assert non-empty/positive bounding box, not the actual wall/edge-width invariants

**File:** `IsletTests/NotchShapeTests.swift:31-53`
**Issue:** Both `testCustomRadiiProduceAClosedNonEmptyPath` and the new `testLargerTopCornerRadiusProducesAClosedNonEmptyPath` only check `cgPath.isEmpty` and that the bounding box has positive width/height. A degenerate case where the bottom-edge line (`rect.minX + topCornerRadius + bottomCornerRadius` vs. `rect.maxX - topCornerRadius - bottomCornerRadius`) crosses over (radii sum exceeding half the rect) would still likely produce a non-empty, positive-area `CGPath` (the curves would simply overlap/self-intersect), so this test style would not reliably catch a true wall-inversion regression — only a total-degenerate case would. This is a pre-existing weakness in the test's assertion style (not introduced by this phase), but worth strengthening given the phase's whole point was tuning corner radii near their safe limits.
**Fix:** Add an assertion directly on the algebraic invariant, e.g. `XCTAssertGreaterThan(rect.width, 2 * (topCornerRadius + bottomCornerRadius))` and `XCTAssertGreaterThan(rect.height, topCornerRadius + bottomCornerRadius)` alongside the existing bounding-box checks, so the test fails loudly and specifically rather than relying on incidental `CGPath` bounding-box behavior.

---

_Reviewed: 2026-07-14T00:22:00+02:00_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
