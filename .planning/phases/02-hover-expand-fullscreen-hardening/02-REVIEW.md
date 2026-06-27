---
phase: 02-hover-expand-fullscreen-hardening
reviewed: 2026-06-27T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - Islet/Notch/FullscreenDetector.swift
  - Islet/Notch/FullscreenSpaceProbe.swift
  - Islet/Notch/NotchGeometry.swift
  - Islet/Notch/NotchInteractionState.swift
  - Islet/Notch/NotchPanel.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchShape.swift
  - Islet/Notch/NotchWindowController.swift
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 2: Code Review Report

**Reviewed:** 2026-06-27T00:00:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Reviewed the eight Phase-2 source files for the notch overlay: pure seams (`NotchGeometry`,
`NotchShape`, `NotchInteractionState`, `FullscreenDetector`), the private-CGS fullscreen probe
(`FullscreenSpaceProbe`), the SwiftUI view (`NotchPillView`), the AppKit panel (`NotchPanel`),
and the controller glue (`NotchWindowController`).

Overall the code is careful and well-reasoned. The focus-safety invariants hold:
`NotchPanel` sets `.nonactivatingPanel` + `canBecomeKey/Main == false` once at init and the
controller shows only via `orderFrontRegardless()` — no focus-stealing call exists. The
`FullscreenSpaceProbe` private-API casting is fully defensive: every `as?` cast and key lookup
falls through to `return false`, with no force-unwrap or crash path (the private-API use itself
is an accepted project decision, not a finding). The `deinit` teardown correctly removes the
default-center observer and the two `NSWorkspace` observers from their respective centers, and
all closures capture `[weak self]`.

The concerns below are concentrated in the hover/expand interaction logic in
`NotchWindowController`, where conflating "hovering" and "expanded" in the pointer-edge tracking
produces a stuck/collapse-under-pointer race and leaves `ignoresMouseEvents` in a wrong state on
two paths. None are security issues; all three warnings are concrete logic/interaction bugs.

## Warnings

### WR-01: Re-entry while expanded never cancels the pending grace collapse — island collapses out from under the pointer

**File:** `Islet/Notch/NotchWindowController.swift:197-208, 240-258`
**Issue:** `handlePointer` only acts on edge transitions, and it tracks the previous edge with
`wasInside = interaction.isHovering`. But `isHovering` is `true` for BOTH `.hovering` AND
`.expanded` (see `NotchInteractionState.isHovering`, line 30). Consider: island is `.expanded`,
pointer leaves the hot-zone → `handleHoverExit` schedules `graceWorkItem`; phase stays `.expanded`
so `isHovering` remains `true`. The pointer then re-enters the hot-zone before the grace fires:

```
inside = true
wasInside = interaction.isHovering   // == true, because phase is .expanded
// neither `inside && !wasInside` nor `!inside && wasInside` is satisfied
```

So `handleHoverEnter` is NOT called, and the line `graceWorkItem?.cancel()` (line 228) never runs.
The grace timer then fires while the pointer is still inside the island, transitioning
`.expanded` → `.collapsed` (line 249) and restoring `ignoresMouseEvents = true` (line 253). The
island collapses out from under the user's pointer, and clicks now pass through even though the
pointer is over the pill. This is the exact "grace-delay race" the state machine was meant to
prevent. The cancel-on-re-entry guarantee only holds while phase is `.hovering`, not `.expanded`.

**Fix:** Track the pointer-in-zone edge from the raw geometry, not from the phase. Keep an explicit
`private var pointerInZone = false` and drive enter/exit from it, and cancel the pending grace on
ANY re-entry (including while expanded):

```swift
private func handlePointer(at point: CGPoint) {
    guard let zone = hotZone else { return }
    let inside = zone.contains(point)
    if inside && !pointerInZone {
        pointerInZone = true
        handleHoverEnter()          // cancels graceWorkItem inside
    } else if !inside && pointerInZone {
        pointerInZone = false
        handleHoverExit()
    }
}
```

Reset `pointerInZone = false` in the hide branch of `updateVisibility()` (alongside `hotZone = nil`)
so it cannot go stale across a hide/show cycle.

### WR-02: `ignoresMouseEvents` is left `false` (window stays click-blocking) after a toggle-shut click followed by pointer exit

**File:** `Islet/Notch/NotchWindowController.swift:251-254, 263-267`
**Issue:** `handleHoverEnter` sets `ignoresMouseEvents = false`. The ONLY place it is restored to
`true` is inside the grace work item, guarded by `if !isHovering && !isExpanded` (lines 252-254).
Consider the documented toggle-shut path: pointer inside, island `.expanded`, user clicks again →
`handleClick` → `.expanded` + `.clicked` → `.collapsed` (state machine line 20). No grace timer is
scheduled by `handleClick`, and `ignoresMouseEvents` is left `false`. If the pointer now leaves the
hot-zone, `handlePointer` sees `wasInside = isHovering`, which is now `false` (phase is `.collapsed`),
so the `!inside && wasInside` branch does NOT fire → `handleHoverExit` is never called → no grace
timer is ever scheduled → `ignoresMouseEvents` stays `false` indefinitely. The collapsed (idle)
window then keeps swallowing mouse events over the notch band, violating the idle click-through
invariant (D-07 / Pitfall 3) until the next hover-enter/exit cycle happens to reset it.

**Fix:** Restoring click-through should not depend solely on the grace timer. With the
`pointerInZone` tracking from WR-01, restore deterministically whenever the island is collapsed and
the pointer is out — e.g. in `handleClick` after a toggle-shut, and/or centralize the
`ignoresMouseEvents` decision in one helper called after every phase mutation:

```swift
private func syncClickThrough() {
    let interactive = pointerInZone || interaction.isExpanded
    panel?.ignoresMouseEvents = !interactive
}
```

Call `syncClickThrough()` at the end of `handleHoverEnter`, the grace work item, and `handleClick`.

### WR-03: `widthFudge` makes `notchSize` width-positivity unchecked — a narrow/odd screen can yield a zero-or-negative window width

**File:** `Islet/Notch/NotchGeometry.swift:20-28`
**Issue:** `notchSize` returns `screenWidth - left - right + widthFudge` with no lower-bound check.
`hasNotch` only guarantees `safeAreaTop > 0` and that both aux widths are non-nil — it does NOT
guarantee `left + right < screenWidth`. On malformed or transitional `NSScreen` data (mid display
reconfiguration, the exact window where `didChangeScreenParameters` can fire — see the controller's
own note at line 96 about firing mid-transition), `auxLeftWidth + auxRightWidth` could momentarily
equal or exceed `screenWidth`, producing a zero or negative width. That flows into
`notchFrame` → `setFrame` with a non-positive width `NSRect`, which AppKit treats as degenerate
(invisible/clipped panel) and is a latent crash surface for downstream geometry math.

**Fix:** Clamp and fail safe to `nil` when the computed width is not positive:

```swift
let width = screenWidth - left - right + widthFudge
guard width > 0 else { return nil }
return CGSize(width: width, height: safeAreaTop)
```

`notchFrame` already propagates `nil` (returns early), so the panel simply isn't repositioned that
frame — consistent with the fail-safe-hide philosophy elsewhere.

## Info

### IN-01: `expandedIsland` renders `Date.now` once with no clock — the time readout is frozen until the next morph

**File:** `Islet/Notch/NotchPillView.swift:86`
**Issue:** The expanded placeholder shows `Text(Date.now, ...)`, evaluated when the view body is
built. The file comment (lines 11-15) deliberately keeps the view animation-free with "no driving
clock," so this timestamp is captured at expand time and never updates while the island stays open.
This is explicitly a "Phase-2 placeholder only" (line 85), so it is not a defect of this phase — but
flagging so the Phase-3 activity content does not inherit a static-time surprise. A `TimelineView`
or an injected clock will be needed when this becomes real content.
**Fix:** When replaced in Phase 3+, drive the time from `TimelineView(.periodic(...))` or a published
clock rather than a one-shot `Date.now`.

### IN-02: `NotchShape.path` is robust but undefined for very small rects where `2*topCornerRadius + bottomCornerRadius > rect.width`

**File:** `Islet/Notch/NotchShape.swift:16-32`
**Issue:** The top-edge line at line 24 runs to `rect.maxX - topCornerRadius - bottomCornerRadius`,
and the left corner consumes `topCornerRadius + bottomCornerRadius` from the start. If a future caller
animates/passes radii whose sum exceeds the rect width (or height for the vertical segments at lines
21/27), the curve control points cross over and the path self-intersects (cosmetic glitch, not a
crash). With the current fixed seeds (collapsed 200x38, expanded 360x72; radii 6/14 and 6/20) this
never triggers, so it is informational only.
**Fix:** If radii ever become user-tunable, clamp them to `min(radius, rect.width/2, rect.height/2)`
inside `path(in:)`.

### IN-03: `kCGSSpaceFullscreen` is a hardcoded private constant (`4`) verified only by a DEBUG log

**File:** `Islet/Notch/FullscreenSpaceProbe.swift:32, 81-84`
**Issue:** The fullscreen-space type is hardcoded to `4`, with a DEBUG-only `print` to confirm the
value on-device (Tahoe). The fail-safe is correct (any mismatch → returns `false` → island shows,
never wrongly hides), so this is low-risk by design. Noting it because the magic number's correctness
is OS-version-dependent and currently rests on a manual DEBUG check that will not run in release; if
Apple changes the constant on a future OS, fullscreen-hide silently stops working with no signal in
production.
**Fix:** No change needed for v1. Optionally, when the value is confirmed on-device, record the
observed constant in a comment with the OS version, and consider a lightweight release-side signal
(e.g. a one-time non-PII log) if fullscreen-hide regressions need to be diagnosable in the field.

---

_Reviewed: 2026-06-27T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
