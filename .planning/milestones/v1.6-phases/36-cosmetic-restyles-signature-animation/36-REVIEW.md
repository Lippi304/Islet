---
phase: 36-cosmetic-restyles-signature-animation
reviewed: 2026-07-16T20:44:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - Islet.xcodeproj/project.pbxproj
  - Islet/Fonts/DancingScript-OFL.txt
  - Islet/Fonts/DancingScript-Variable.ttf
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/Notch/PowerActivity.swift
  - Islet/Notch/PowerSourceMonitor.swift
  - Islet/Notch/SignatureHeading.swift
  - Islet/SettingsView.swift
  - IsletTests/EqualizerBarsTests.swift
  - IsletTests/PowerActivityTests.swift
  - IsletTests/SignatureHeadingTests.swift
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
status: issues_found
---

# Phase 36: Code Review Report

**Reviewed:** 2026-07-16T20:44:00Z
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

Reviewed the phase 36 cosmetic-restyle diff (charging/device wing label restyle, EqualizerBars
reroll-and-spring rewrite, the charging classification fix, and the ONBOARD-04 SignatureHeading
scope pivot to a static rainbow-gradient heading). `Islet/Fonts/DancingScript-Variable.ttf`
(binary font) and `Islet/Fonts/DancingScript-OFL.txt` (license text) are non-code assets — not
applicable for source review; verified only that `project.pbxproj` wires both into the Resources
build phase correctly (matching file references + build-file entries, no orphaned/duplicate IDs).

`Islet/Notch/SignatureHeading.swift` was reviewed in its final, post-pivot state (static
`HStack` of two gradient `Text` views + `loadSignatureFont`), per the task instruction — not the
earlier stroke-reveal implementation superseded by commit `e3398d2`.

No blocker-level defects found. Two warnings: a theoretical (astronomically unlikely but real)
trap in `EqualizerBars.targetHeight`, and a geometry gap where the newly widened wing labels
("Charging"/"Connected") extend into a region the click-through hot-zone doesn't cover while the
island is collapsed. Three minor info-level cleanliness items.

## Warnings

### WR-01: `EqualizerBars.targetHeight` can trap via `abs(Int.min)`

**File:** `Islet/Notch/NotchPillView.swift:421-427`
**Issue:** The new hash-based bar-height factory does:
```swift
static func targetHeight(bar: Int, bucket: Int) -> CGFloat {
    var hasher = Hasher()
    hasher.combine(bucket)
    hasher.combine(bar)
    let bucketed = abs(hasher.finalize()) % 1000
    return 4 + Double(bucketed) / 1000.0 * 10
}
```
`Hasher.finalize()` returns a signed `Int` whose full range includes `Int.min`
(`-9223372036854775808`). `abs(Int.min)` traps (crashes) in Swift because the positive
counterpart isn't representable in `Int`. The odds of any single `(bar, bucket)` pair hashing to
exactly `Int.min` are ~1 in 2^64, so in practice this will effectively never fire, but the
function is called continuously (every ~100ms per bar) for the app's entire Now-Playing lifetime,
so the crash surface is technically live and unbounded over time. This is exactly the kind of
"never happens until it does, then it's unreproducible" defect that's cheap to close off now.

**Fix:** Avoid signed overflow entirely by working in unsigned space:
```swift
let bucketed = Int(UInt(bitPattern: hasher.finalize()) % 1000)
```

### WR-02: Widened wing labels extend past the click-through hot-zone

**File:** `Islet/Notch/NotchPillView.swift:263, 1972-1990, 2111-2127`; `Islet/Notch/NotchWindowController.swift:877, 1099-1101`
**Issue:** This phase adds `wingsLabelWidth = 400` and widens `wings(for:)`/`deviceWings(for:)`'s
`leftWidth` to `wingsLabelWidth / 2` (200pt) whenever the "Charging"/"Connected" text label is
shown — up from the prior symmetric 145pt half-width. The panel-frame reservation
(`positionAndShow`'s `expandedFrame.union(wings)...`) is wide enough to contain this (verified:
±210pt vs. the new ±200pt), so nothing is visually clipped.

However, `NotchWindowController.handlePointer(at:)` decides whether the pointer is "in zone" (and
therefore whether the panel is click-through-disabled, i.e. whether a tap can even reach the
SwiftUI view) using:
```swift
let activeZone = interaction.isExpanded ? (expandedZone ?? hotZone) : hotZone
```
and `hotZone` is set once, in `positionAndShow`, to only the tiny **collapsed pill** frame padded
by `hotZonePadding` (6pt) — it does not grow for the wings' width at all, symmetric or otherwise.
While a charging/device wing glance is showing, `interaction.isExpanded` is false, so
`hotZone` (not the wider `expandedZone`) governs click-through. The new "Charging"/"Connected"
label now visibly renders up to ~200pt left of center, well outside the ~99pt half-width hot-zone
(measured notch ≈179-187pt + 12pt padding) — a gap that already existed for the old 145pt
half-width wings, but this phase's widening measurably enlarges it specifically over the new,
most-likely-to-be-tapped label text. A user who taps directly on the "Charging"/"Connected" text
will very likely have that click pass straight through to whatever app sits behind the notch
instead of registering `onClick()`, rather than expanding the island as they'd expect.

**Fix:** Either widen `hotZone` to also cover the currently-visible wing content (not just the
collapsed pill) when a wing presentation is active, or accept this as a known trade-off and
document it explicitly next to `wingsLabelWidth`'s existing comment (the comment currently only
reasons about panel-frame containment, not hot-zone/click-through coverage — this project treats
click-through correctness as a locked, previously-regressed concern per its own CR-01 precedent
elsewhere in this file, so a silent gap here is worth calling out even if the fix is deferred).

## Info

### IN-01: `EqualizerBars.tint` parameter is now dead in practice

**File:** `Islet/Notch/NotchPillView.swift:384-385, 2061, 2280`
**Issue:** `EqualizerBars` still declares `var tint: Color = .white`, but this phase removed the
only two call sites that passed a non-default value (`tint: nowPlayingAccent`) — both remaining
call sites now construct `EqualizerBars(isPlaying:)` with no `tint:` argument. The parameter is
harmless but no longer exercised anywhere.
**Fix:** If EQ-01's fixed-white bars are permanent by design (per the Skiper UI reference), drop
the parameter entirely; otherwise leave a short comment noting it's intentionally unused for now.

### IN-02: "Now Playing" accent swatch no longer affects the equalizer bars

**File:** `Islet/SettingsView.swift:301`; `Islet/Notch/NotchPillView.swift:2061, 2280`
**Issue:** `SettingsView`'s Theming section still exposes a "Now Playing" accent-color picker
(`nowPlayingAccentIndex`), but as of this phase's EQ-01 rewrite the equalizer bars are hardcoded
white and no longer read `nowPlayingAccent` — the picker now only affects the playback progress
bar. Users changing this swatch to see the equalizer bars change color will observe no effect,
which may read as a regression/bug even though it's a deliberate design choice.
**Fix:** If intentional, consider a one-line label/tooltip clarifying scope, or leave as-is if
already covered by 36-UI-SPEC.md.

### IN-03: Unnecessary variable extraction in `start(isFirstLaunch:)`

**File:** `Islet/Notch/NotchWindowController.swift:375-379`
**Issue:** `shouldShowOnboarding(...)`'s result is now bound to a `let shouldShow` before the
`if shouldShow { ... }` check, where the prior code just used the call directly in the `if`. The
call is used exactly once immediately after, so this is a no-op extraction — likely a leftover
from the (already-removed) `36-04` diagnostic logging that once printed this value.
**Fix:** Harmless; inline back to `if shouldShowOnboarding(...) {` next time this line is touched,
or leave as-is — flagged only for completeness, not worth a standalone change.

---

_Reviewed: 2026-07-16T20:44:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
