---
phase: 48-audio-output-switcher-ui-wiring
plan: 02
subsystem: audio-ui
tags: [swiftui, output-switcher, notchpillview, geometry, row-as-volume-bar]

# Dependency graph
requires:
  - phase: 48-01
    provides: "setSystemVolume(_:), IslandPresentationState.output* @Published fields, live AudioOutputMonitor wiring"
provides:
  - "3 NotchPillView closures: onToggleOutputPanel, onSelectOutputDevice, onVolumeChange (unaffected by this revision, re-verified)"
  - "Real speaker-icon TransportButton in mediaContent's control row (unaffected by this revision, re-verified)"
  - "outputVolumeSlider<Content: View>(...) — content-wrapping helper (replaces the removed standalone OutputVolumeSlider struct), mirrors wingsShape<Content: View>'s generic-func convention"
  - "outputPanel(devices:) — row-as-volume-bar design: active row IS the draggable Capsule volume bar, inactive rows are plain dimmed text, full-white-vs-dimmed text opacity is the sole active-device signal (no checkmark)"
  - "outputActiveRowHeight/outputInactiveRowHeight constants"
  - "tabHeight Site 1 (CR-01 geometry three-site rule) — outputPanelExtraHeight bump, structurally unchanged, doc comment updated for new row math"
affects: [48-03-audio-output-switcher-controller-handlers]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "outputVolumeSlider<Content: View>(...) mirrors wingsShape<Content: View>'s established 'generic private func with a trailing @ViewBuilder content:' convention, NOT a generic View struct with a stored @ViewBuilder property (no precedent for that shape anywhere in this file)"
    - "GeometryReader.init(content:) stores its closure for later evaluation (escaping) — a @ViewBuilder content: parameter (non-escaping by default) cannot be called directly inside it; content() must be evaluated into a local `let` binding BEFORE entering GeometryReader's closure, then that local view is referenced inside"
    - "Disabled-state dimming is scoped to a Group{} wrapping only the two Capsule layers, with .opacity(enabled ? 1 : 0.35) applied to that Group — never to the row's Text content — so D-13's 'text stays full white even when the bar dims' rule holds structurally, not just by convention"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "REVISION of Plan 48-02 (originally shipped standalone-slider design in commits b9f247a/a58607e): on-device UAT of that design (technically matching the locked discuss-phase decisions, but not the user's actual mental model) triggered a context revision (48-CONTEXT.md D-10..D-13) and a full plan rewrite (commit 9cf0cbb). This SUMMARY documents the re-execution against the CURRENT plan content, superseding 48-02-SUMMARY.md.pre-redesign."
  - "content() (the row's Text) must be evaluated into a `let rowContent = content()` local BEFORE the GeometryReader{...} closure, not called from inside it — GeometryReader's own content closure is @escaping (it stores the closure on the View struct for later body evaluation), and Swift rejects capturing a non-escaping @ViewBuilder parameter inside an escaping closure. This is a mechanical Swift-compiler constraint discovered during this plan's own execution, not present in the interfaces block's TARGET-shape reference code (which would not have compiled as literally written)."

requirements-completed: [OUTPUT-01, OUTPUT-02, OUTPUT-03]

# Metrics
duration: ~15min
completed: 2026-07-20
---

# Phase 48 Plan 02: NotchPillView Output-Switcher UI Wiring (Row-as-Volume-Bar Revision) Summary

**Restructured the output-switcher panel so the active device's row itself IS the draggable volume bar (Capsule track/fill as the row's own background) instead of a standalone slider above a checkmarked list — full-white-vs-dimmed text opacity is now the sole active-device signal.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-20
- **Tasks:** 2 completed (Task 1 verified as an unaffected no-op, Task 2 did the actual restructuring)
- **Files modified:** 1

## Accomplishments
- **Task 1 (verification only, no edits):** Confirmed the 3 output-panel closures (`onToggleOutputPanel`, `onSelectOutputDevice`, `onVolumeChange`) and the real speaker-icon `TransportButton` in `mediaContent`'s control row still match exactly what shipped in commit `b9f247a` — this presentation-only revision (per `48-CONTEXT.md`'s Integration Points note) never touched them.
- **Task 2:** Removed the top-level `private struct OutputVolumeSlider: View` (and its explanatory comment block) entirely. `OSDLevelBar` immediately above it in the file is untouched (still the OSD wing's own display-only bar).
- Added a new `private func outputVolumeSlider<Content: View>(fraction:tint:enabled:onChange:content:) -> some View` method, placed immediately after `outputPanel(devices:)`'s closing brace — mirrors `wingsShape<Content: View>`'s established "generic function with a trailing `@ViewBuilder content:` parameter" convention. Reuses the deleted struct's exact `GeometryReader`/Capsule-track+fill/`DragGesture` visual and clamp logic byte-for-byte, but restructured so `.opacity(enabled ? 1 : 0.35)` applies ONLY to a `Group` wrapping the two Capsule layers — the row's own `content()` (its `Text`) renders as a separate `ZStack` layer on top, unaffected by that dimming (D-13: the active row's text stays full white even when its bar dims because the device lacks volume control).
- Rewrote `outputPanel(devices: [AudioOutputDevice]) -> some View` entirely: a single `VStack(spacing: 4)` around `ForEach(devices)`, branching on `device.isDefault`. The active branch wraps an `HStack` (device name + `Spacer`) in `outputVolumeSlider(...)`, with `Text(device.name).foregroundStyle(.white)` — unconditionally full white (D-12), no checkmark anywhere in the function. The inactive branch is a plain `HStack` with `.foregroundStyle(.white.opacity(0.5))` (D-12's sole inactive signal), `.padding(.horizontal, 10)`, `.frame(height: Self.outputInactiveRowHeight)`, `.contentShape(Rectangle())`, `.onTapGesture { onSelectOutputDevice(device) }` (D-07 unchanged — panel stays open). The `.animation(.spring(response: 0.15, dampingFraction: 0.86), value: devices)` reorder-animation modifier stays on the outer `VStack`, unaffected by this revision (D-02/OUTPUT-03).
- Added `outputActiveRowHeight: CGFloat = 32` and `outputInactiveRowHeight: CGFloat = 28` constants next to `outputPanelExtraHeight`; updated `outputPanelExtraHeight`'s own doc comment to describe the new row-based height math (its declared VALUE, 140, is unchanged — the row math reduces to approximately the same total). `tabHeight`'s Site 1 (`NotchPillView.swift:107`) and the constant's value are both structurally untouched, so Plan 48-03's already-shipped Sites 2/3 (`positionAndShow`/`visibleContentZone()`) need no changes.
- `NotchPillViewTests.testTabWidthHeightMatchesKnownPerCaseValues` re-run via `xcodebuild test` and still passes (0.006s) — confirms Site 1 is structurally unregressed by the row restructuring.

## Task Commits

Each task was committed atomically:

1. **Task 1: Verify closures + speaker-icon button unaffected** — no edits, no commit (confirmed as a safe no-op per the plan's own instructions; already-shipped code matches the `<interfaces>` "Task 1 target" block exactly).
2. **Task 2: Restructure outputPanel(devices:) to row-as-volume-bar (D-10..D-13)** — `1b13dd1` (feat)

_No TDD tasks in this plan._

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` — removed `OutputVolumeSlider` struct; added `outputVolumeSlider<Content: View>(...)` content-wrapping helper method; rewrote `outputPanel(devices:)` to branch per-row on `device.isDefault`; added `outputActiveRowHeight`/`outputInactiveRowHeight` constants; updated `outputPanelExtraHeight`'s doc comment

## Decisions Made
- `content()` (the `@ViewBuilder` trailing closure parameter) must be evaluated into a `let rowContent = content()` local binding BEFORE entering `GeometryReader { geo in ... }`, not called from inside that closure. `GeometryReader.init(content:)` stores its own content closure for later body evaluation (i.e. it is `@escaping`), and Swift's compiler rejects capturing a non-escaping `@ViewBuilder` parameter inside an escaping closure (`error: escaping closure captures non-escaping parameter 'content'`). This is a mechanical Swift-compiler constraint the plan's own `<interfaces>` TARGET-shape reference code did not account for (that literal code would not have compiled) — fixed inline as part of Task 2, same acceptance criteria satisfied (D-10/D-13's visual/gesture contract unchanged), smaller diff than an `@escaping` annotation on `content` (which would change the parameter's semantics and diverge further from `wingsShape`'s own non-escaping convention).

## Deviations from Plan

**1. [Rule 1 - Bug] `content()` evaluated outside GeometryReader's escaping closure, not inside it as literally shown in the plan's TARGET-shape reference**
- **Found during:** Task 2, first build attempt
- **Issue:** The plan's `<interfaces>` "TARGET shape to build" reference code calls `content()` directly inside `GeometryReader { geo in ... }`'s trailing closure. This does not compile: `GeometryReader.init(content:)` takes an `@escaping` closure (SwiftUI stores it on the view struct for later evaluation), and the `@ViewBuilder content: () -> Content` parameter is implicitly non-escaping — Swift rejects capturing a non-escaping parameter inside an escaping closure.
- **Fix:** Added `let rowContent = content()` immediately before `return GeometryReader { ... }`, then referenced `rowContent` (not `content()`) inside the `ZStack`. Identical rendered output and gesture behavior — `content()` is still evaluated exactly once per `outputVolumeSlider(...)` call, just hoisted one line earlier.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Commit:** `1b13dd1`

## Issues Encountered

None beyond the deviation above (caught and fixed on the first build attempt).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plan 48-03's controller-level handlers (`handleToggleOutputPanel`/`handleSelectOutputDevice`/`handleVolumeChange`) and geometry Sites 2/3 (`positionAndShow`/`visibleContentZone()`) were confirmed to need NO changes: they forward opaque `AudioOutputDevice`/`Float` values and read the same `presentationState.outputPanelOpen` boolean regardless of how the panel renders internally — the closure signatures this plan preserves (`onToggleOutputPanel: () -> Void`, `onSelectOutputDevice: (AudioOutputDevice) -> Void`, `onVolumeChange: (Float) -> Void`) are byte-identical to what 48-03 Task 1 already wired up.
- Plan 48-03's Task 3 on-device UAT checkpoint (previously blocked — see STATE.md's "Plan 48-03 blocked" note) can now proceed against the real row-as-volume-bar UI: the active device's row is a real draggable Capsule volume bar, inactive rows are plain dimmed text, and there is no checkmark anywhere in the panel.
- Full interactive behavior (real drag-to-volume on the active row, real tap-to-select on inactive rows, real live device-list updates, D-13's per-row `hasVolumeControl` gating) remains to be exercised end-to-end on real hardware via Plan 48-03 Task 3's on-device checkpoint.

---
*Phase: 48-audio-output-switcher-ui-wiring*
*Completed: 2026-07-20*

## Self-Check: PASSED

Modified file (`Islet/Notch/NotchPillView.swift`) and this SUMMARY.md both found on disk; both commit hashes (`1b13dd1`, `d68676d`) found in git log.
