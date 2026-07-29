---
phase: quick-260729-4oi
plan: 01
status: complete
---

# Quick Task 260729-4oi: Wing Tuner Round 7-8 Summary

Grew across the session's own live feedback into 3 sub-rounds, all in `Islet/Notch/NotchPillView.swift` (+ 1 new asset):

## Round 7 (original scope)

1. **Charging — baked in tuned deltas** (margin -15 → 9, leading +6 → 18, trailing +6 → 20).
2. **Device — real Bluetooth icon.** User supplied an actual reference icon (icons8-bluetooth-48.png)
   instead of continuing with the round-6 hand-drawn `Path` approximation. Added
   `Islet/Assets.xcassets/BluetoothGlyph.imageset/` (the supplied 48x48 PNG, `template-rendering-intent`
   so it tints via `.foregroundStyle` like every other wing icon). `bluetoothGlyph(size:opacity:)`
   now renders `Image("BluetoothGlyph").renderingMode(.template).resizable().scaledToFit()` inside a
   `size * 0.7` frame (estimate — SF-Symbol-style icons usually have internal padding this glyph's
   edge-to-edge source doesn't, flagged for on-device sizing confirmation) instead of the old
   hand-drawn `Path`.

## Round 7b — Charging redesign to a single icon (came in before Round 7 was even reported)

User asked to consolidate the plug icon + separate `BatteryIndicator`+% into ONE "charging battery"
glyph, with no percentage shown at all ("man lädt sowieso nur auf, braucht keine Prozentzahl"),
referencing an image resembling a battery-with-bolt icon. Replaced `powerplug.fill` +
`BatteryIndicator(...)` with a single `Image(systemName: "battery.100.bolt")` on the left; the right
flank now has no content at all (just `trailingPad` breathing room past the camera block).
**Flag: `"battery.100.bolt"` was not on-device-verified this round — confirm it actually renders the
expected battery+bolt glyph, not a blank/missing-symbol placeholder.**

## Round 8 (came in mid-turn, same session)

3. **Timer — baked in tuned deltas** (margin -10 → 55/10 for Pomodoro/plain, leading +4 → 20,
   trailing +10 → 22). Timer already had a working margin mechanism (built correctly from its
   original Phase 62-04 implementation) — this is purely a constant bake-in, no mechanism change.
4. **Countdown — margin mechanism was completely missing** ("Ändert sich immer noch nichts bei
   Margin. Die Icons gehen aber nicht margin." — Leading/Trailing worked, Margin did nothing).
   `countdownWings(for:)` was the LAST wing still on the old fixed-half + `Spacer()` mechanism
   (never converted in any prior round). Converted to the same margin+cameraBlockWidth formula as
   every other wing, mirroring `timerWings`' own plain-Countdown margin estimate (20pt, "short mm:ss
   digits, no adjacent label" content class). Starting `margin = 20` is an estimate, not
   live-measured for this specific wing — flagged for live re-tune.

## Build Verification

- Debug: BUILD SUCCEEDED (after each sub-round's edits)
- Release: BUILD SUCCEEDED (confirmed twice — after the Bluetooth-asset/Charging-redesign changes, and again after Timer/Countdown)

## Known flags for the next on-device pass

- `"battery.100.bolt"` SF Symbol name not visually confirmed yet.
- `BluetoothGlyph` asset's `size * 0.7` inner scale is an estimate — may look too big/small relative
  to other wings' SF Symbol icons.
- Countdown's `margin = 20` starting value is an estimate — first time this wing has ever had a
  margin concept at all.
- All 4 wings converted this session (Focus, Device, Charging, Countdown) now support live Margin
  tuning identically to the wings that always had it (OSD, Caps Lock, Update, Download, Timer,
  Meeting) — every collapsed-state wing now shares the same mechanism.

## Files Modified

- `Islet/Notch/NotchPillView.swift`
- `Islet/Assets.xcassets/BluetoothGlyph.imageset/Contents.json` (new)
- `Islet/Assets.xcassets/BluetoothGlyph.imageset/icons8-bluetooth-48.png` (new)
