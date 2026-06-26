---
phase: 01-the-empty-island-window-geometry
reviewed: 2026-06-26T21:11:22Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - Islet/AppDelegate.swift
  - Islet/Notch/DisplayResolver.swift
  - Islet/Notch/NSScreen+Notch.swift
  - Islet/Notch/NotchGeometry.swift
  - Islet/Notch/NotchPanel.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchShape.swift
  - Islet/Notch/NotchWindowController.swift
  - IsletTests/DisplayResolverTests.swift
  - IsletTests/NotchGeometryTests.swift
  - IsletTests/NotchPanelTests.swift
  - IsletTests/NotchShapeTests.swift
  - project.yml
findings:
  critical: 0
  warning: 2
  info: 4
  total: 6
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-06-26T21:11:22Z
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

Phase 1 builds the always-on notch overlay window and its geometry/selection
seam. The architecture is clean and notably disciplined for a first-time
programmer: pure, side-effect-free geometry/selection functions
(`NotchGeometry.swift`, `DisplayResolver.swift`) are isolated from the AppKit
glue (`NSScreen+Notch.swift`, `NotchWindowController.swift`), which makes the
math unit-testable without a live display. The test suite is thorough and the
fixtures correctly target the real-world pitfalls (display reordering, the
coordinate flip, incomplete aux-area data).

I verified the core correctness concerns from the review brief:

- **Coordinate-flip math is correct.** `notchFrame` uses `y = maxY - height`
  with `maxY = origin.y + height`, which is the right AppKit bottom-left-origin
  formula. Recomputed `x=610, y=944` for the origin fixture and `x=2530` for the
  shifted-origin fixture — both match the asserted test values exactly.
- **No retain cycle in the screen-change observer.** The
  `didChangeScreenParametersNotification` closure captures `[weak self]`, and the
  inner `DispatchQueue.main.async` also uses `self?`, so the controller is not
  retained by `NotificationCenter`. `deinit` removes the observer.
- **NSPanel configuration is correct.** `.nonactivatingPanel` is set once at init
  (never toggled), `canBecomeKey`/`canBecomeMain` are overridden to `false`, and
  the collection behavior / level / transparency all match D-07 intent.
- **No force-unwraps in risky paths.** `statusItem: NSStatusItem!` is the standard
  implicitly-unwrapped-optional AppKit idiom, assigned in `didFinishLaunching`
  before any use. Optional chaining (`image?`, `statusItem.button` via `if let`)
  is used correctly elsewhere.

No critical issues. The two warnings are robustness gaps that won't bite in the
single-built-in-display v1 happy path but are cheap to harden. The info items are
minor.

## Warnings

### WR-01: Panel is never hidden/closed on controller teardown

**File:** `Islet/Notch/NotchWindowController.swift:57-59`
**Issue:** `deinit` removes the `NotificationCenter` observer but never orders the
panel out or closes it. The panel is only hidden in the *no-notch* branch of
`resolveAndPosition` (line 45, `panel?.orderOut(nil)`). If the controller is ever
deallocated while a notch screen is present, the `NotchPanel` it created — which
has `isReleasedWhenClosed = false` and is `orderFrontRegardless`-shown — can
remain on screen as an orphaned window with no owner to reposition or dismiss it.
In Phase 1 the controller is intentionally retained for the app's lifetime
(`AppDelegate.notchController`), so this is latent, not active. But it makes the
class non-self-contained: a future caller that creates a transient controller (or
a test that instantiates and drops one) would leak a visible window.
**Fix:** Order the panel out (and drop the reference) in `deinit` so teardown is
symmetric:
```swift
deinit {
    if let o = observer { NotificationCenter.default.removeObserver(o) }
    panel?.orderOut(nil)
    panel = nil
}
```

### WR-02: `start()` can be called more than once, double-registering the observer

**File:** `Islet/Notch/NotchWindowController.swift:17-30`
**Issue:** `start()` unconditionally assigns `observer = NotificationCenter.default.addObserver(...)`.
If `start()` is ever invoked twice on the same instance, the first observer token
is overwritten and leaks (it is never removed because `deinit` only sees the
second token), and `resolveAndPosition` then runs twice per screen-parameter
change. The current single call site in `AppDelegate.applicationDidFinishLaunching`
(line 40) makes this safe today, but there is no guard preventing a regression.
**Fix:** Guard against re-entry, or remove any prior observer before adding:
```swift
func start() {
    guard observer == nil else { return }   // already started
    resolveAndPosition()
    observer = NotificationCenter.default.addObserver(...)
}
```

## Info

### IN-01: NotchShape degenerates for rect widths below ~40pt

**File:** `Islet/Notch/NotchShape.swift:20`
**Issue:** The bottom edge line goes from `x = minX + top + bottom` to
`x = maxX - top - bottom`. With the default radii (top 6, bottom 14), if the rect
width is less than `2*(top+bottom) = 40`, the end x is left of the start x and the
path folds back on itself, producing a malformed silhouette. The real notch frame
is ~292pt wide so this is never hit in practice, and `NotchShapeTests` only
exercises a 200pt rect. Recording it because the radii are described as "tunable
in dev" — a builder bumping `bottomCornerRadius` high while testing on a narrow
preview rect could be confused by the result.
**Fix:** None required for v1. Optionally clamp the radii to the rect, e.g.
`let b = min(bottomCornerRadius, (rect.width/2) - topCornerRadius)`, before
building the path, or add a comment noting the minimum width assumption.

### IN-02: Debug-only red tint and peek offset rely solely on `#if DEBUG`

**File:** `Islet/Notch/NotchPillView.swift:16-17, 24`
**Issue:** The pill renders semi-transparent red and offset 8pt down in DEBUG
builds (`fillColor` / `devOffset`). This is intentional and well-commented (D-02),
but it means the *only* thing separating the dev appearance from the shipping
black-and-flush appearance is the build configuration. If a release/archive build
is ever produced with the Debug configuration by mistake, the red dev pill ships.
**Fix:** No change needed — the scheme's `archive` config is `Release`
(`project.yml:81-82`), so this is correctly wired. Noting only as a thing to keep
in mind when adding new build configs.

### IN-03: `versionString` / Info.plist reads are duplicated string keys

**File:** `Islet/SettingsView.swift:48-49` (context file, not in change set)
**Issue:** `"CFBundleShortVersionString"` and `"CFBundleVersion"` are referenced as
raw string literals. Not a defect; mentioned only because it is the one place a
typo would silently yield `"?"` instead of a compile error. Out of scope for this
phase's changed files — listed for completeness since `AppDelegate` and the app
scene reference it.
**Fix:** None for Phase 1.

### IN-04: `openSettings` intentionally uses two redundant show paths

**File:** `Islet/AppDelegate.swift:71-80`
**Issue:** `openSettings` both posts `.openIsletSettings` (handled by the SwiftUI
`OpenSettingsOnNotification` modifier, which activates + `openWindow`) and then
directly calls `makeKeyAndOrderFront` on the same "settings" window. Both paths
also call `NSApp.activate`. This is deliberate belt-and-suspenders for the
first-open race (commented), not a bug, but the dual path means two slightly
different show mechanisms must stay in agreement if the window identifier or
behavior changes.
**Fix:** None required. If simplified later, prefer the notification bridge as the
single source of truth and drop the direct `makeKeyAndOrderFront`.

---

_Reviewed: 2026-06-26T21:11:22Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
