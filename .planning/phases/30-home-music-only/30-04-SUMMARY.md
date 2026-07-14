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
   32pt to 37pt (+5pt). This is a single shared constant used by every switcher-row presentation
   that pins content under the camera band (`mediaExpanded`, `mediaUnavailable`, etc.), so all of
   them gain the same extra headroom.

## Commits
- `bf9109e`: fix(30-04): enable acceptsMouseMovedEvents so SwiftUI .onHover fires
- `b1a24f7`: fix(30-04): add 5pt camera clearance to mediaExpanded content

## Key files modified
- `Islet/Notch/NotchPanel.swift` — `acceptsMouseMovedEvents = true` added to init
- `Islet/Notch/NotchPillView.swift` — `cameraClearance` 32 → 37

## Verification
`xcodebuild build -scheme Islet -destination 'platform=macOS'` succeeded after each change.
No deviations from the gap-closure plan. Re-running the relevant items of Plan 30-03's on-device
checklist (D-05 hover, HOME-02 camera clearance) is the remaining step before the phase closes.
