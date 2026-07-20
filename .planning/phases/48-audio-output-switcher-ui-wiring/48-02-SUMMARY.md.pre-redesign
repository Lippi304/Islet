---
phase: 48-audio-output-switcher-ui-wiring
plan: 02
subsystem: audio-ui
tags: [swiftui, output-switcher, notchpillview, geometry]

# Dependency graph
requires:
  - phase: 48-01
    provides: "setSystemVolume(_:), IslandPresentationState.output* @Published fields, live AudioOutputMonitor wiring"
provides:
  - "3 new NotchPillView closures: onToggleOutputPanel, onSelectOutputDevice, onVolumeChange"
  - "Real speaker-icon TransportButton in mediaContent's control row (replaces the unbuilt Repeat placeholder)"
  - "OutputVolumeSlider (private struct) — draggable, dimmable volume control"
  - "outputPanel(devices:) — sorted device list with D-05 checkmark + D-07 stay-open tap"
  - "tabHeight Site 1 (CR-01 geometry three-site rule) — outputPanelExtraHeight bump"
affects: [48-03-audio-output-switcher-controller-handlers]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "OutputVolumeSlider copies OSDLevelBar's Capsule/GeometryReader visual verbatim but stays a distinct private struct (D-03: reuse the visual style, not the component) — OSDLevelBar itself is untouched"
    - "Disabled-slider handling is a guard-clause inside the DragGesture closure (not a conditional ternary on .gesture(_:)) — functionally identical to 'skip attaching the gesture' but avoids a SwiftUI Optional-Gesture type-unification issue"
    - "CR-01 geometry three-site rule Site 1: tabHeight's default case reads presentationState.outputPanelOpen directly, ternary-adding outputPanelExtraHeight — Plan 48-03 must mirror this exact boolean at Site 2 (positionAndShow) and Site 3 (visibleContentZone())"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "OutputVolumeSlider's disabled state is enforced via a guard clause inside the drag gesture's onChanged closure rather than conditionally omitting .gesture(_:) — SwiftUI's .gesture(_:) modifier has no built-in Optional<Gesture> overload, so a ternary between a DragGesture and nil does not type-check without extra boilerplate; the guard clause is functionally equivalent (no onChange forwarding while disabled) with a smaller diff"
  - "outputPanelExtraHeight set to 140pt — a reasoned first-pass estimate (slider 12pt + spacing + ~3 device rows at ~24pt + row spacing), documented as 'tune on-device' matching this codebase's homeContentHeight/onboardingSize convention"

requirements-completed: [OUTPUT-01, OUTPUT-02, OUTPUT-03]

# Metrics
duration: ~15min
completed: 2026-07-20
---

# Phase 48 Plan 02: NotchPillView Output-Switcher UI Wiring Summary

**Real speaker-icon toggle button, a genuinely draggable OutputVolumeSlider, and a sorted/checkmarked device-list panel wired into mediaContent's reserved right slot — pure SwiftUI, no CoreAudio/AppKit code added to this file.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-20
- **Tasks:** 2 completed
- **Files modified:** 1

## Accomplishments
- `NotchPillView` gains 3 new closures (`onToggleOutputPanel`, `onSelectOutputDevice(AudioOutputDevice)`, `onVolumeChange(Float)`) declared immediately after `onPrevious`, matching every existing closure's doc-comment/no-op-default convention so `#Preview` blocks keep compiling untouched.
- The right reserved control-row slot in `mediaContent` (formerly an unbuilt "Repeat" placeholder, same fate as the already-dropped Star/favorite slot) is now a real `TransportButton(systemName: "speaker.wave.2.fill", action: onToggleOutputPanel)` — tapping it is the single, symmetric open/close toggle (D-08). The left reserved Shuffle slot is untouched.
- `OutputVolumeSlider` (new private struct near `OSDLevelBar`) copies `OSDLevelBar`'s exact `GeometryReader`/`Capsule` visual language but thickened to 12pt (D-03: reuse the visual style, not the component — `OSDLevelBar` itself is unmodified, still used only by the OSD wing). No numeric/percentage text anywhere (D-04); the live-updating fill is the entire readout, tracking the drag in real time. When `enabled` (`presentationState.outputHasVolumeControl`) is `false`, the view dims to 0.35 opacity and a guard clause inside the drag handler drops all forwarding (D-06).
- `outputPanel(devices:)` renders the slider plus a `ForEach` device list (already sorted default-first by `sortedAudioOutputDevices`, Phase 47). Each row shows the device name and, only for the default device, an accent-tinted checkmark (D-05 — single-signal, no row-background highlight). Tapping any row calls `onSelectOutputDevice(device)` as its entire tap behavior — the panel deliberately stays open (D-07). The device-list `VStack` carries `.animation(.spring(response: 0.15, dampingFraction: 0.86), value: devices)` so a re-sorted list visibly slides the newly-selected device to the top (D-02/OUTPUT-03) purely from `presentationState.outputDevices` changing.
- `tabHeight`'s `default` case (Site 1 of the CR-01 geometry three-site rule) now reads `presentationState.outputPanelOpen` and adds a new `outputPanelExtraHeight` constant (140pt, documented "tune on-device" like `homeContentHeight`/`onboardingSize`) when the panel is open; unchanged (170pt) when closed. `NotchPillViewTests.testTabWidthHeightMatchesKnownPerCaseValues` re-run via `xcodebuild test` and still passes unmodified (every existing test construction leaves `outputPanelOpen` at its `false` default).

## Task Commits

Each task was committed atomically:

1. **Task 1: New closures + speaker-icon button** - `b9f247a` (feat)
2. **Task 2: OutputVolumeSlider + outputPanel(devices:) + tabHeight height bump** - `a58607e` (feat)

_No TDD tasks in this plan._

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - 3 new closures, real speaker-icon `TransportButton`, `OutputVolumeSlider` struct, `outputPanel(devices:)` method + its call site in `mediaContent`, `outputPanelExtraHeight` constant, `tabHeight`'s default-case height bump

## Decisions Made
- `OutputVolumeSlider`'s disabled behavior uses a guard clause inside the `DragGesture.onChanged` closure instead of conditionally attaching/omitting `.gesture(_:)` via a ternary — `.gesture(_:)` has no Optional<Gesture> overload, so a `condition ? DragGesture(...) : nil` ternary does not type-check. The guard clause achieves the identical outcome (no `onChange` forwarding while disabled) with a smaller diff than an `AnyGesture`/`EmptyGesture` workaround would need.
- `outputPanelExtraHeight` set to 140pt as a documented first-pass estimate, matching this codebase's own "size once, tune on-device" convention rather than trying to compute an exact SwiftUI layout height from source alone.

## Deviations from Plan

**1. [Rule 1 - Bug] Disabled-slider gesture attachment implemented as a guard clause, not a conditional `.gesture(_:)`**
- **Found during:** Task 2
- **Issue:** The plan's literal action text (`.gesture(enabled ? DragGesture(...).onChanged{...} : nil)`) does not compile — SwiftUI's `.gesture(_:)` modifier requires a concrete `Gesture`-conforming type, and a ternary between a `_ChangedGesture<DragGesture>` and `nil` fails to unify without an explicit `AnyGesture` wrapper.
- **Fix:** Attached the `DragGesture` unconditionally and added `guard enabled else { return }` as the first line of `onChanged`'s closure — identical runtime behavior (no forwarding while disabled), same D-06 acceptance criteria satisfied, no additional type-erasure boilerplate needed.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Commit:** `a58607e`

## Issues Encountered

None beyond the deviation above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 48-03 (controller handlers) can now forward `onToggleOutputPanel`/`onSelectOutputDevice`/`onVolumeChange` to `NotchWindowController`'s real CoreAudio calls (`setSystemVolume(_:)`, `setDefaultOutput(uid:)`, `presentationState.outputPanelOpen` toggling).
- Plan 48-03 must mirror the exact `presentationState.outputPanelOpen` boolean read at Site 2 (`positionAndShow`'s panel-frame union) and Site 3 (`visibleContentZone()`'s matching branch) to avoid the CR-01 click-through regression class this project has hit before (flagged in the plan's own threat model, T-48-05).
- Full interactive behavior (real drag-to-volume, real tap-to-select, real live device-list updates) remains to be exercised end-to-end once Plan 48-03 wires the closures to real CoreAudio behavior.

---
*Phase: 48-audio-output-switcher-ui-wiring*
*Completed: 2026-07-20*

## Self-Check: PASSED

Modified file (`Islet/Notch/NotchPillView.swift`) and this SUMMARY.md both found on disk; both task commit hashes (`b9f247a`, `a58607e`) found in git log.
