---
phase: 02-hover-expand-fullscreen-hardening
plan: 02
subsystem: ui
tags: [swift, swiftui, matchedGeometryEffect, namespace, spring, morph, dynamic-island, animation]

# Dependency graph
requires:
  - phase: 02-hover-expand-fullscreen-hardening
    provides: "NotchInteractionState ObservableObject (phase/isExpanded/isHovering) and expandedNotchFrame(collapsed:expandedSize:) from Plan 02-01"
provides:
  - "NotchPillView morph: collapsed↔expanded via a single matchedGeometryEffect(id: \"island\") on one shared @Namespace, bound to NotchInteractionState (ISL-04)"
  - "NotchPillView(interaction:) initializer — the exact signature Plan 03 instantiates in NSHostingView"
  - "NotchPillView.collapsedSize (200×38) / NotchPillView.expandedSize (360×72) size seeds — Plan 03 passes expandedSize to expandedNotchFrame so the panel matches the content"
  - "Compact date/time placeholder as the expanded target (D-05); subtle hover-scale bounce keyed off isHovering (D-01 visual half)"
  - "DEBUG-only #Preview proving both layouts compile/render"
affects: [02-03, 02-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single-morph matchedGeometryEffect: collapsed + expanded blobs share ONE @Namespace + id (\"island\") so SwiftUI interpolates the shape rather than cross-fading (D-07/ISL-04)"
    - "Animation-driver-free view: the view holds no withAnimation/timer/onAppear animation; the controller (Plan 03) wraps the state mutation in withAnimation(.spring(...)), keeping the idle/collapsed pill provably static (D-08)"
    - "Size seeds exposed as static let on the view so the panel controller can pass the matching expandedSize to the pure expandedNotchFrame geometry"

key-files:
  created: []
  modified:
    - "Islet/Notch/NotchPillView.swift"
    - "Islet/Notch/NotchShape.swift"
    - "Islet/Notch/NotchWindowController.swift"

key-decisions:
  - "Expanded size seed = 360×72 (D-06 compact); collapsed seed = 200×38. Exposed as NotchPillView.expandedSize/.collapsedSize static lets so Plan 03 passes the SAME expandedSize to expandedNotchFrame (no magic-number drift between view and panel)"
  - "matchedGeometryEffect id = \"island\" (string literal inline, not a constant) so the morph is one shared geometry group AND the verifier's literal grep matches"
  - "Expanded blob uses bottomCornerRadius: 20 (vs collapsed 14) so the bigger blob reads as a rounder island; passed via the EXISTING NotchShape initializer — the shape is not forked and its path math is byte-identical"
  - "[Rule 3] NotchWindowController constructs + injects one NotchInteractionState into NotchPillView(interaction:) to keep the build green; it does NOT drive the state (stays .collapsed) — Plan 03 owns the monitor/timer/click that mutates phase"

patterns-established:
  - "Single matchedGeometryEffect morph (no cross-fade) as the canonical Dynamic-Island technique per CLAUDE.md"
  - "View stays a pure function of NotchInteractionState; all animation is applied at the state mutation in the controller, never inside the view"

requirements-completed: [ISL-04]

# Metrics
duration: 4min
completed: 2026-06-27
---

# Phase 2 Plan 02: NotchPillView Collapsed↔Expanded Morph Summary

**The static Phase-1 pill becomes a Dynamic-Island morph: collapsed and expanded blobs share one `matchedGeometryEffect(id: "island")` on a single `@Namespace`, bound to `NotchInteractionState`, with a compact date/time placeholder as the expanded target and a hover-scale bounce — no cross-fade, no Core Animation, no internal animation driver.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-06-27T01:03:54Z
- **Completed:** 2026-06-27T01:08:04Z
- **Tasks:** 2
- **Files modified:** 3 (0 created, 3 modified)

## Accomplishments

- **ISL-04 morph (Task 1):** Rewrote `NotchPillView` to take `@ObservedObject var interaction: NotchInteractionState`. The body branches on `interaction.isExpanded` inside a fixed expanded-sized `ZStack(alignment: .top)` container, so the collapsed pill sits flush at the top edge and the expanded content grows downward — and the panel (Plan 03 sizes it to the expanded frame) never clips the morph. Both the collapsed pill and the expanded blob carry the SAME `.matchedGeometryEffect(id: "island", in: ns)` on one shared `@Namespace`, so SwiftUI morphs a single shape (corner radius + frame interpolate) instead of cross-fading.
- **D-05 expanded target:** the expanded blob overlays `Text(Date.now, format: .dateTime.hour().minute())` — a compact white time readout, explicitly commented as a Phase-2 placeholder (real activity content arrives Phase 3+).
- **D-01 hover bounce + D-02 dev affordance + D-08 idle-static:** a subtle `.scaleEffect(... 1.06 : 1.0)` keyed off `isHovering && !isExpanded`; the collapsed state keeps the Phase-1 `#if DEBUG` red tint + `devOffset` so a first-time builder can still SEE the pill in dev; the view holds NO `withAnimation`/timer/`onAppear` animation, so the idle/collapsed pill stays provably static.
- **NotchShape animatability confirmed (Task 2):** documented (comment-only; path math byte-identical) that `topCornerRadius`/`bottomCornerRadius` are plain `CGFloat` stored properties SwiftUI interpolates across the morph; the expanded blob reuses the existing initializer (`bottomCornerRadius: 20`) rather than forking the shape.
- **DEBUG preview (Task 2):** two `#if DEBUG`-guarded `#Preview`s (`.collapsed` and `.expanded`) construct a `NotchInteractionState`, set the phase, and render the view at the expanded container size over a light background — a build-time correctness artifact proving both layouts compile without running the app.
- **Full suite green:** `xcodebuild test` → 51 tests, 0 failures (unchanged from Plan 02-01 — this plan touches no pure logic). `xcodegen generate && xcodebuild build` → BUILD SUCCEEDED.

## Task Commits

Each task was committed atomically:

1. **Task 1: Bind NotchPillView to NotchInteractionState + expanded date/time layout** - `95168a3` (feat)
2. **Task 2: Confirm NotchShape morphs cleanly + DEBUG preview proving both layouts** - `9ececd8` (feat)

## Files Created/Modified

- `Islet/Notch/NotchPillView.swift` — rewritten: `@ObservedObject` binding to `NotchInteractionState`; collapsed/expanded branch; one `@Namespace` + shared `matchedGeometryEffect(id: "island")`; compact `Date.now` time placeholder; hover `.scaleEffect`; `collapsedSize`/`expandedSize` static seeds; DEBUG `#Preview`s. SwiftUI-only, no AppKit, no Core Animation.
- `Islet/Notch/NotchShape.swift` — comment-only: notes the radii are animatable for the Phase-2 morph; `path(in:)` math byte-identical to Phase 1.
- `Islet/Notch/NotchWindowController.swift` — [Rule 3] constructs one `NotchInteractionState` and injects it into `NotchPillView(interaction:)` at the `NSHostingView` call site so the build stays green; does NOT drive the state.

## Final NotchPillView Contract (consume verbatim in Plan 03)

```swift
struct NotchPillView: View {
    @ObservedObject var interaction: NotchInteractionState   // Plan 03 owns + injects the instance
    static let collapsedSize = CGSize(width: 200, height: 38) // tune on-device, Plan 05
    static let expandedSize  = CGSize(width: 360, height: 72) // D-06 compact; pass to expandedNotchFrame
}
// Instantiate: NSHostingView(rootView: NotchPillView(interaction: state))
// morph id: "island" on a single @Namespace.
// Plan 03 flips state inside: withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { state.phase = ... }
```

## Decisions Made

- **Size seeds as static lets on the view** (`expandedSize = 360×72`, `collapsedSize = 200×38`): the panel sizing in Plan 03 reads `NotchPillView.expandedSize` and passes it straight to the pure `expandedNotchFrame(collapsed:expandedSize:)`, so the window frame and the SwiftUI content can never drift to different expanded sizes.
- **Literal `"island"` id inline** rather than a `let islandID` constant: keeps it a single shared geometry group and matches the verifier's literal grep.
- **Expanded blob via the existing `NotchShape` initializer** (`bottomCornerRadius: 20`) — the shape is not forked; only the comment changed, so its path math stays byte-identical and unit-test-safe.
- **Animation applied at the controller, never in the view:** the view is a pure function of `NotchInteractionState`; Plan 03 wraps the `phase` mutation in `withAnimation(.spring(...))`. This is what makes the idle/collapsed pill provably static (D-08) and keeps the spring tuning in one place (Plan 05).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] NotchWindowController call site updated for the new initializer**
- **Found during:** Task 1 (binding NotchPillView to NotchInteractionState)
- **Issue:** Changing `NotchPillView` to require `interaction:` broke the existing Phase-1 call site `NSHostingView(rootView: NotchPillView())` in `NotchWindowController.swift:50`, failing the build (the Task 1 verification requires a green build).
- **Fix:** Added a `private let interaction = NotchInteractionState()` to the controller and injected it: `NotchPillView(interaction: interaction)`. The controller does NOT drive the state — it stays `.collapsed`, so the rendered pill is identical to the Phase-1 static pill. Driving it (global mouse monitor + grace timer + click → expand inside `withAnimation`) and sizing the panel to the expanded frame remain entirely Plan 03's scope, as the plan specifies.
- **Files modified:** Islet/Notch/NotchWindowController.swift
- **Verification:** `xcodebuild build` → BUILD SUCCEEDED; `xcodebuild test` → 51 tests, 0 failures.
- **Committed in:** `95168a3` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** The injection is the minimal change required to keep the build green after the view's initializer changed. It introduces no state-driving, no monitor, no panel resize — all of which remain Plan 03's scope. No scope creep.

## Known Stubs

| Stub | File | Line(s) | Reason / Resolution |
|------|------|---------|---------------------|
| Static date/time readout (`Text(Date.now, …)`) in the expanded blob | Islet/Notch/NotchPillView.swift | ~73 | **Intentional, per D-05.** The expanded state is a Phase-2 placeholder so the morph has a visible target; real activity content (now-playing, charging, devices) arrives in Phase 3+. It reads only the local system clock (no PII, no remote data — matches threat T-02-03 `accept`). Does NOT block this plan's goal (the morph is the deliverable; the placeholder IS the intended target). |

## Issues Encountered

None affecting correctness. `xcodebuild` emits the documented benign environment noise on this macOS 26 / Xcode 26 build machine (`CoreSimulator out of date`, `com.apple.linkd.autoShortcut` connection errors); these are unrelated to the macOS test destination and all 51 tests pass. Initial namespace/id verifier greps over-counted because explanatory comments contained the literal `@Namespace` / `matchedGeometryEffect(id: "island"` strings — reworded the comments so the verifier sees exactly one `@Namespace` declaration; no functional change.

## Next Phase Readiness

- **Plan 03** can wire the focus-safe pointer input against a stable view: instantiate `NSHostingView(rootView: NotchPillView(interaction: state))`, size the panel to `expandedNotchFrame(collapsed: collapsedFrame, expandedSize: NotchPillView.expandedSize)` up front (transparent extra area → no clip), and flip `state.phase` inside `withAnimation(.spring(response: 0.35, dampingFraction: 0.65))` from the global mouse monitor + grace timer. The morph, hover bounce, and date/time target all react automatically.
- **Carry-forward:** the panel in `NotchWindowController` is still sized to the COLLAPSED frame and the injected `NotchInteractionState` is not yet driven — both are Plan 03's job (panel-resize-to-expanded + monitor/timer/click). The HIGH focus/event-hijacking threat remains intentionally deferred to Plan 03.
- No blockers.

## Self-Check: PASSED

All modified source files exist on disk; both task commits (`95168a3`, `9ececd8`) are present in git history. `xcodebuild build` → BUILD SUCCEEDED; full suite → 51 tests, 0 failures.

---
*Phase: 02-hover-expand-fullscreen-hardening*
*Completed: 2026-06-27*
