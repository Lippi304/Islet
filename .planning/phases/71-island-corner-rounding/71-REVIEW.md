---
phase: 71-island-corner-rounding
reviewed: 2026-07-30T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - Islet/ActivitySettings.swift
  - Islet/AppDelegate.swift
  - Islet/Notch/NotchPillView.swift
  - IsletTests/ActivitySettingsTests.swift
  - IsletTests/NotchShapeTests.swift
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
status: resolved
resolved: 2026-07-30T00:00:00Z
---

# Phase 71: Code Review Report

**Reviewed:** 2026-07-30T00:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** resolved (see Resolution section at end)

## Summary

Reviewed the SHAPE-02/SHAPE-03 corner-radius work and the post-UAT freeze fixes: the two new
`.clipShape(shape)` safety nets (`wingsShape`, `mediaWingsOrToast`, `resumePreviewWings`) are
correctly applied and use the right rect (frame-before-clip ordering is right in all three
spots). DEBUG gating for the new "Corner Radius" Wing Tuner axis is consistent everywhere it
appears (`ActivitySettings.swift` key, `NotchPillView`'s always-compiled `wingCornerRadiusNudge`
computed property, and `AppDelegate`'s menu/actions) — Release builds compile out the
`@AppStorage` property and the menu construction and always fold the nudge to `0`.

The one thing that does NOT hold up under adversarial tracing: `wingsShape()`'s new clamp
(`maxCornerRadiusNudge`/`clampedCornerRadiusNudge`, lines 3056-3064) only protects the **height**
axis of the `NotchShape` path. It clamps `topCornerRadius + bottomCornerRadius` against
`size.height`, but `NotchShape.path(in:)`'s bottom edge (`NotchShape.swift:24`) also requires
`2 * (topCornerRadius + bottomCornerRadius) <= size.width`, and nothing clamps that. The sibling
nudges that feed `leftWidth`/`rightWidth` into `wingsShape` — `wingLeadingNudge`,
`wingTrailingNudge`, `wingMarginNudge` — are still completely unbounded (no `min`/`max` anywhere
in their computed properties or at any of their ~15 call sites), so a large enough nudge on any
of those three axes reproduces the exact freeze class this phase's fix was written to close, just
via the width dimension instead of height. Given this is precisely the failure mode called out in
this phase's own on-device UAT notes, and the "other wing-margin/padding constants" the task
explicitly asked to check, this is flagged as a Critical/blocker finding below.

## Critical Issues

### CR-01: Corner-radius clamp only guards the height axis — unclamped Leading/Trailing/Margin nudges can still drive `wingsShape()` into the same self-intersecting-path freeze

**File:** `Islet/Notch/NotchPillView.swift:3048-3164` (clamp at 3056-3064; unclamped nudge sources at 192-219; a representative call site at 3144-3166)

**Issue:**
`NotchShape.path(in:)` (`Islet/Notch/NotchShape.swift:16-32`) draws two line segments whose
direction depends on the rect's dimensions relative to the radii:

- The left/right walls (`NotchShape.swift:21,27`) require `topCornerRadius + bottomCornerRadius
  <= rect.height` — this is the axis `wingsShape()`'s new clamp protects.
- The top/bottom edges (`NotchShape.swift:24`, from `x: minX+topR+bottomR` to `x:
  maxX-topR-bottomR`) require `2 * (topCornerRadius + bottomCornerRadius) <= rect.width` — **this
  axis has no clamp at all.** If violated, the bottom edge line runs backwards, producing the
  same self-intersecting path class that froze `clipShape` rendering in the original UAT bug.

`wingsShape()`'s `size.width` comes from `leftWidth + rightWidth`, which every call site derives
from `wingLeadingNudge` / `wingTrailingNudge` / `wingMarginNudge` (e.g. `wings(for:)` at lines
3144-3166: `leftWidth = leadingPad + iconWidth + cameraBlockWidth / 2`, where `leadingPad = 30 +
wingLeadingNudge` and `cameraBlockWidth = (rawNotchHalfWidth + margin) * 2` with `margin = 34 +
wingMarginNudge`). None of `wingLeadingNudge`, `wingTrailingNudge`, or `wingMarginNudge`
(computed properties at lines 192-212) clamp their `@AppStorage` value in any way — unlike
`wingCornerRadiusNudge`, which this phase correctly bounded. The existing `assert(cameraBlockWidth
> 0, ...)` / `assert(rightWidth < 325 && leftWidth < 325, ...)` guards present at every wing call
site (lines 3162-3164, 3442-3443, 3493-3494, 3556-3557, 3743-3744, 3822-3823, 3878-3879,
3938-3939, 4043, 4177-4180) only check an *upper* bound and a positivity condition on
`cameraBlockWidth` — none of them check that `leftWidth + rightWidth` stays large enough relative
to the (possibly nudged) corner radii.

Concrete repro path (DEBUG Wing Tuner, on-device): open the "Corner Radius" submenu and push the
nudge to its clamped maximum (e.g. `+5` a few times so `topCornerRadius + bottomCornerRadius`
approaches the full wing height), then click "Leading -2" repeatedly (or "Margin -20" a couple of
times) on a wing whose `leftWidth` is not compensated by `rightWidth` (e.g. Charging's
`wings(for:)`, where `wingLeadingNudge` only affects `leftWidth`, not `rightWidth` — see the
derivation at lines 3159-3161). Once `leftWidth + rightWidth < 2 * (topCornerRadius +
bottomCornerRadius)`, the next re-render reproduces the same freeze the height-axis clamp was
added to fix.

This is DEBUG-only surface area (the Wing Tuner menu is gated `#if DEBUG` in both
`ActivitySettings.swift:112-118` and `AppDelegate.swift:499-689`), so it cannot ship in Release,
but it is the exact developer-facing tool that caused the original freeze, and the "fix" for that
freeze does not actually close the failure mode — it only closes the one axis that happened to be
hit during UAT.

**Fix:** Clamp `wingsShape()`'s corner-radius nudge against **both** dimensions, not just height,
and/or floor the three sibling nudges so they can never shrink `leftWidth + rightWidth` below
what the (already-clamped) radii need:

```swift
// wingsShape(), after computing `size`:
let maxCornerRadiusNudgeForHeight = (size.height - Self.wingBaseTopCornerRadius - Self.wingBaseBottomCornerRadius) / 2
let maxCornerRadiusNudgeForWidth  = (size.width / 2 - Self.wingBaseTopCornerRadius - Self.wingBaseBottomCornerRadius) / 2
let maxCornerRadiusNudge = min(maxCornerRadiusNudgeForHeight, maxCornerRadiusNudgeForWidth)
let clampedCornerRadiusNudge = max(min(wingCornerRadiusNudge, maxCornerRadiusNudge), -Self.wingBaseBottomCornerRadius)
```

and/or clamp the leading/trailing/margin nudges themselves at their source (e.g. floor them so
`leadingPad`/`trailingPad`/`margin` can never go low enough to make `leftWidth`/`rightWidth`
negative or implausibly small), mirroring the discipline already applied to
`wingCornerRadiusNudge`.

## Warnings

### WR-01: `clampedCornerRadiusNudge`'s bound order silently breaks if `maxCornerRadiusNudge` ever drops below `-wingBaseBottomCornerRadius`

**File:** `Islet/Notch/NotchPillView.swift:3062-3063`

**Issue:** The clamp is written as
`max(min(wingCornerRadiusNudge, maxCornerRadiusNudge), -Self.wingBaseBottomCornerRadius)`. This
is only a correct clamp into `[-8, maxCornerRadiusNudge]` when `maxCornerRadiusNudge >= -8`. If
`maxCornerRadiusNudge` ever drops below `-8` (which happens when `size.height < 8`, i.e.
`Self.wingBaseTopCornerRadius + Self.wingBaseBottomCornerRadius - 2 * 8 = 8`), the `min(...)`
result is `<= maxCornerRadiusNudge < -8`, and the outer `max(..., -8)` then clamps it back UP to
`-8` — a value that is *larger* than the actual safe bound (`maxCornerRadiusNudge`), reproducing
`topCornerRadius + bottomCornerRadius > size.height` again (the exact bug this clamp exists to
prevent).

This is currently unreachable in practice only because `resolvedWingDepthScale` routes through
`resolvedIslandScale(auto:manualOffset:range:)` (`Islet/Notch/NotchGeometry.swift:120`), whose
default `range` parameter is hard-floored at `0.8`, so `size.height = wingsSize.height *
depthScale >= 32 * 0.8 = 25.6`, well above the `8pt` danger threshold. But that invariant lives in
a completely different file with no comment or assertion here connecting the two — a future
change to that range (e.g. a more aggressive "compact" scale option) would silently reintroduce
the freeze with no local signal that this clamp depends on it.

**Fix:** Make the dependency self-defending instead of implicit. Either add a local
`assert(size.height >= Self.wingBaseTopCornerRadius + Self.wingBaseBottomCornerRadius - 2 *
Self.wingBaseBottomCornerRadius, ...)` documenting the invariant, or restructure the clamp so the
lower bound can never exceed the upper bound regardless of `size.height`:

```swift
let safeLowerBound = min(-Self.wingBaseBottomCornerRadius, maxCornerRadiusNudge)
let clampedCornerRadiusNudge = max(min(wingCornerRadiusNudge, maxCornerRadiusNudge), safeLowerBound)
```

### WR-02: New SHAPE-02 regression tests only cover the un-nudged base radii, not the clamp's own boundary case

**File:** `IsletTests/NotchShapeTests.swift:55-73`

**Issue:** `testWingBaseRadiiProduceAClosedNonEmptyPathAtNominalSize` and
`testWingBaseRadiiProduceAClosedNonEmptyPathAtDepthScaleFloor` both construct `NotchShape(
topCornerRadius: 16, bottomCornerRadius: 8)` — the unnudged base values. Neither test exercises
the actual boundary state `wingsShape()`'s clamp is designed to produce and stop just short of
(`topCornerRadius + bottomCornerRadius == size.height`, e.g. `topCornerRadius: 20,
bottomCornerRadius: 12` at height `32`, which is exactly what a maxed-out corner-radius nudge
clamps to per the formula in `NotchPillView.swift:3062-3064`). As a result, a regression in the
clamp formula itself (see WR-01) would not be caught by this test file — it only proves the base
radii are safe, which was never in question.

**Fix:** Add a boundary test that mirrors the clamp's own computed maximum, e.g.:

```swift
func testWingCornerRadiiAtClampedMaximumProduceAClosedNonEmptyPath() {
    // Mirrors wingsShape()'s maxCornerRadiusNudge formula at the nominal 32pt height:
    // (32 - 16 - 8) / 2 = 4 -> top 20 / bottom 12, radii sum == rect height (the boundary
    // the clamp is designed to never exceed).
    let path = NotchShape(topCornerRadius: 20, bottomCornerRadius: 12).path(in: CGRect(x: 0, y: 0, width: 290, height: 32))
    XCTAssertFalse(path.cgPath.isEmpty)
}
```

Consider also extracting the clamp math out of the private `wingsShape()` view builder into a
small, directly-testable pure function (e.g. `static func clampedWingCornerRadiusNudge(_ nudge:
CGFloat, wingSize: CGSize) -> CGFloat`), so WR-01's fix can be unit tested without going through
SwiftUI view construction.

## Info

### IN-01: `debugWingTunerPrint`'s guidance string doesn't mention the corner-radius axis's own margin/padding constant names

**File:** `Islet/AppDelegate.swift:628-635`

**Issue:** `debugWingTunerPrint()`'s printed message tells the developer to add the printed
deltas to "the ONE wing's own margin/leadingPad-or-.padding(.leading,)/trailingPad-or-.padding(.trailing,)/gap
constants" but never mentions where the printed `cornerRadiusNudge` value should be applied (there
is no per-wing corner-radius constant to bake it into — `wingBaseTopCornerRadius`/
`wingBaseBottomCornerRadius` at `NotchPillView.swift:483-484` are shared across all wings, not
per-wing like the other four axes). A developer following the printed instructions literally has
nowhere to paste the corner-radius delta.

**Fix:** Either drop `cornerRadiusNudge` from the printed message if it's meant to stay a
global/live-only tuning knob, or clarify in the string that it's shared (edit
`wingBaseTopCornerRadius`/`wingBaseBottomCornerRadius` directly) rather than per-wing.

---

## Resolution

All four findings addressed in commit `24d2474` (fix(71-REVIEW): move corner-radius clamp into NotchShape (CR-01)):

- **CR-01 (fixed, stronger than the suggested fix):** Rather than clamping `wingsShape()`'s corner-radius nudge against both height and width (the suggested fix, which still leaves the sibling leading/trailing/margin nudges able to shrink the rect unclamped), the clamp was moved into `NotchShape.path(in:)` itself — the one path builder every caller routes through. It now scales both radii down together whenever `topCornerRadius + bottomCornerRadius > rect.height` OR `2 * (topCornerRadius + bottomCornerRadius) > rect.width`, regardless of which nudge or caller (`blobShape`/`wingsShape`/`mediaWingsOrToast`/`resumePreviewWings`) produced the offending rect/radii. This closes the width-axis gap CR-01 identified without needing to floor `wingLeadingNudge`/`wingTrailingNudge`/`wingMarginNudge` individually. `wingsShape()`'s now-redundant local height-only clamp was removed.
- **WR-01 (moot):** The bound-order edge case was specific to the removed `wingsShape()`-local clamp expression. It no longer exists in the codebase; `NotchShape`'s new clamp has no equivalent lower/upper-bound-order dependency (it uses a single proportional `scale` factor, not a two-sided `min`/`max` on the nudge itself).
- **WR-02 (fixed, different approach):** Since the clamp now lives in `NotchShape` rather than in a private `wingsShape()` local, the suggested "extract to a testable pure function" refactor is no longer needed — `NotchShape.path(in:)` is already the directly-testable unit. Added `testPathologicalRadiiAreClampedToAValidPathAtWingSize` (radii of 1000/1000 at the 290×32 wing rect) and `testDefaultRadiiAreClampedToAValidPathAtNarrowWidth` (default 16/8 radii at a 20pt-wide rect, exercising the width axis specifically) to `NotchShapeTests.swift`.
- **IN-01 (fixed):** `debugWingTunerPrint()`'s guidance string now explicitly calls out that `cornerRadiusNudge` has no per-wing home and should be baked into `Self.wingBaseTopCornerRadius`/`wingBaseBottomCornerRadius` instead of the per-wing leading/trailing/margin/gap constants.

Verified: `xcodebuild build -configuration Debug` succeeded; `IsletTests/NotchShapeTests` + `IsletTests/ActivitySettingsTests` — 30/30 passed (28 prior + 2 new).

_Reviewed: 2026-07-30T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
