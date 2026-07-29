---
phase: quick-260729-5vl
plan: 01
status: complete
---

# Quick Task 260729-5vl: Bake In OSD Wing Tuning Deltas Summary

User ran the on-device DEBUG Wing Tuner against the OSD (Brightness/Volume) wing after the
percent-number addition (260729-5jc/5pv) and reported:
`[WingTuner] leadingNudge=0.0 trailingNudge=-6.0 marginNudge=20.0 gapNudge=0.0`

## What changed

In `osdWings(for:)` (`Islet/Notch/NotchPillView.swift`):

- `margin`: `40 + wingMarginNudge` → `60 + wingMarginNudge` (+20).
- `trailingPad`: `24 * wScale + wingTrailingNudge` → `18 * wScale + wingTrailingNudge` (-6).
- `iconLeadingPad` untouched (leadingNudge was 0.0).
- No gap constant in this wing carries a `wingGapNudge` term, so `gapNudge=0.0` required no change.

## Build Verification

- Debug: BUILD SUCCEEDED
- Release: BUILD SUCCEEDED

User will click "Reset Wing Tuner" in the debug menu before tuning the next wing.

## Files Modified

- `Islet/Notch/NotchPillView.swift`
