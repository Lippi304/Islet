# Plan 30-04 Summary: Gap Closure — Hover + Camera Clearance

## What was built
Two fixes closing findings from Plan 30-03's on-device checkpoint:

1. **D-05 hover never appeared.** `NotchPanel.init` never set `acceptsMouseMovedEvents`. Every
   hover interaction in the app up to now (notch expand-on-hover) was driven by a manual global
   `NSEvent` monitor, never native window `mouseMoved` events. `TransportButton.onHover` (30-02)
   is the first native SwiftUI `.onHover` in the codebase — without this flag the window never
   receives `mouseMoved`, so `.onHover` could never fire regardless of button position or
   click-through state. Fix: `acceptsMouseMovedEvents = true` added alongside the other one-time
   window flags in `NotchPanel.init`.

2. **Camera overlap.** User confirmed a minor overlap between the media display (art/title/
   transport row) and the physical camera cutout. `NotchPillView.cameraClearance` bumped from
   32pt to 42pt (+10pt across two on-device tuning rounds, +5pt each). This is a single shared
   constant used by every switcher-row presentation that pins content under the camera band
   (`mediaExpanded`, `mediaUnavailable`, etc.), so all of them gain the same extra headroom.

3. **Hover brightness tuning.** After confirming hover now fires, user iterated on brightness:
   0.12 → 0.20 → 0.40 (test) → a temporary 3-way on-device A/B test (0.30/0.40/0.50 across the
   3 real transport buttons, via a `hoverOpacity` param added to `TransportButton`) → user picked
   0.40 for all three. The temporary per-button parameter was removed again; `TransportButton`
   is back to a single hardcoded `Color.white.opacity(0.40)`.

## Commits
- `bf9109e`: fix(30-04): enable acceptsMouseMovedEvents so SwiftUI .onHover fires
- `b1a24f7`: fix(30-04): add 5pt camera clearance to mediaExpanded content
- `f5c6289`: fix(30-04): brighten D-05 hover, add 5 more pt of camera clearance
- `731b73e`: fix(30-04): settle D-05 hover opacity at 0.40 (user A/B comparison)

## Key files modified
- `Islet/Notch/NotchPanel.swift` — `acceptsMouseMovedEvents = true` added to init
- `Islet/Notch/NotchPillView.swift` — `cameraClearance` 32 → 42 (two rounds), hover opacity settled at 0.40

## Verification
`xcodebuild build -scheme Islet -destination 'platform=macOS'` succeeded after every change. User
approved all 3 Home sub-states, the D-05 hover background (0.40 opacity), and the camera clearance
on-device — Plan 30-03's checkpoint is satisfied.
