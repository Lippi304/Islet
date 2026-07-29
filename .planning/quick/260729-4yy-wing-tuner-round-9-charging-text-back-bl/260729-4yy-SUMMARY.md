---
phase: quick-260729-4yy
plan: 01
status: complete
---

# Quick Task 260729-4yy: Wing Tuner Round 9 Summary

Third small on-device feedback wave following 260729-4oi (rounds 7-8), same session.

1. **Charging — "Charging..." text added back** on the right side (the battery+bolt icon alone
   wasn't enough per user feedback). Reserved `rightContentWidth = 80` (estimate, matching
   `deviceWings`' old "Connected" 70pt estimate + a couple points for the 2 extra characters).
2. **Device — Bluetooth icon enlarged.** Inner scale in `bluetoothGlyph(size:opacity:)` bumped from
   `s * 0.7` to `s * 0.98` per the user's explicit "0.4 nochmal größer" (current size × 1.4 = 0.7 ×
   1.4 = 0.98).
3. **Timer — confirmed good**, no further change needed.
4. **Countdown — baked in final tuned deltas**: `margin` 20 → 45 (+25), `leadingPad` 14 → 20 (+6),
   `trailingPad` 20 → 2 (-18). Confirms round 8's margin/cameraBlockWidth conversion for this wing
   works as intended.

## Build Verification

- Debug: BUILD SUCCEEDED
- Release: BUILD SUCCEEDED

## Files Modified

- `Islet/Notch/NotchPillView.swift`
