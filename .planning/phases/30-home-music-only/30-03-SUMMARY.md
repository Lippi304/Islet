# Plan 30-03 Summary: On-Device UAT — Home Music-Only Sub-States

## Outcome
User ran the 5-point on-device checklist on the real notch MacBook. Two issues surfaced on the
first pass (D-05 hover background never appeared; media display slightly overlapped the camera).
Both were root-caused and fixed via gap-closure Plan 30-04 (in 3 iterative on-device tuning
rounds), then re-verified. User typed **"approved"** confirming:

1. HOME-01 (live): transport controls, title/artist, art, equalizer, progress bar render as before.
2. D-05 (hover): rounded-rectangle hover background appears on all 3 transport buttons, settled at
   0.40 white opacity after an on-device A/B comparison (0.30/0.40/0.50).
3. HOME-02 (last-played): real last track cover art + title with the same transport controls and
   hover, with corrected camera clearance (32 → 42pt).
4. HOME-03 (empty): music-note icon, "Nothing Playing", "Start something in Spotify or Music."
5. Regression: Weather/Calendar switcher tabs unaffected.

## Related work
See `30-04-SUMMARY.md` for the gap-closure fixes (acceptsMouseMovedEvents, cameraClearance,
hover opacity) this checkpoint round required.

## Verification
`xcodebuild build -scheme Islet -destination 'platform=macOS'` green throughout. On-device
checklist fully approved by the user — phase 30 goal (HOME-01/02/03) achieved.
