---
phase: quick-260729-5pv
plan: 01
status: complete
---

# Quick Task 260729-5pv: Smooth OSD Percent-Number Transition + 10pt Gap Summary

Follow-up polish on the OSD (Brightness/Volume) percent number added in quick task 260729-5jc.
User reported the digit swap when the value changes was an abrupt cut with no transition, and
asked for 10pt of space between the level bar and the number (was 4pt).

## What changed

In `osdWings(for:)` (`Islet/Notch/NotchPillView.swift`):

- `percentGap` raised from `4` to `10`.
- The `Text("\(percent)")` gained `.contentTransition(.numericText(value: Double(percent)))` plus
  its own local `.animation(.spring(response: 0.15, dampingFraction: 0.86), value: percent)` —
  reusing the exact spring constants `OSDLevelBar`'s own fill animation already uses elsewhere in
  this file (its "D-16 retuned value" comment), for visual consistency between the bar's fill
  motion and the number's roll/fade motion. This gives the digits a smooth roll+fade between old
  and new values instead of a hard cut, and is independent of the outer wing's own
  appear/disappear transaction (which only covers presence, not in-place value changes — this is
  why a local animation modifier was needed here, same reasoning as `OSDLevelBar`'s existing one).

No other constants (icon padding, bar width, trailingPad, camera-block margin) were touched.

## Build Verification

- Debug: BUILD SUCCEEDED
- Release: BUILD SUCCEEDED

## Files Modified

- `Islet/Notch/NotchPillView.swift`
