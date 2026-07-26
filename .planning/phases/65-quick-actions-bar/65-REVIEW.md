---
phase: 65-quick-actions-bar
reviewed: 2026-07-26T02:16:17Z
depth: standard
files_reviewed: 18
files_reviewed_list:
  - Islet/ActivitySettings.swift
  - Islet/Notch/IslandResolver.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/Notch/QuickActionsBar/CaffeinateToggleAction.swift
  - Islet/Notch/QuickActionsBar/DarkModeToggleAction.swift
  - Islet/Notch/QuickActionsBar/DisplaySleepAction.swift
  - Islet/Notch/QuickActionsBar/EmptyTrashAction.swift
  - Islet/Notch/QuickActionsBar/FocusToggleAction.swift
  - Islet/Notch/QuickActionsBar/LaunchAction.swift
  - Islet/Notch/QuickActionsBar/QuickActionsBarCatalog.swift
  - Islet/Notch/QuickActionsBar/QuickActionsBarFeedbackState.swift
  - Islet/Notch/QuickActionsBar/QuickActionsBarManualSpike.swift
  - Islet/Notch/QuickActionsBar/ScreenLockAction.swift
  - Islet/Notch/ViewSwitcherState.swift
  - Islet/SettingsView.swift
  - IsletTests/FocusToggleActionTests.swift
  - IsletTests/IslandResolverTests.swift
  - IsletTests/NotchPillViewTests.swift
findings:
  critical: 1
  warning: 4
  info: 2
  total: 7
status: issues_found
---

# Phase 65: Code Review Report

**Reviewed:** 2026-07-26T02:16:17Z
**Depth:** standard
**Files Reviewed:** 18
**Status:** issues_found

## Summary

Reviewed the Quick Actions Bar feature end to end: the 8-slot catalog/config layer
(`QuickActionsBarCatalog`, `ActivitySettings`), the per-action system-call helpers
(`CaffeinateToggleAction`, `DarkModeToggleAction`, `DisplaySleepAction`, `EmptyTrashAction`,
`FocusToggleAction`, `LaunchAction`, `ScreenLockAction`), the SwiftUI rendering
(`NotchPillView`), the controller wiring/dispatch and click-through geometry
(`NotchWindowController`), the Settings popover (`SettingsView`), and existing tests.

The resolver-level precedence logic (`IslandResolver.swift`) is solid and well covered by
`IslandResolverTests`. The system-call action helpers correctly avoid shell/command injection
(fixed executables, argv arrays, no string interpolation into AppleScript/shell) and degrade
safely on failure.

The one BLOCKER is a real, reproducible regression against this codebase's own established
"geometry three-site rule": `NotchWindowController.visibleContentZone()` has no dedicated
branch for `.quickActionsBarExpanded`, unlike every sibling switcher-row tab whose content is
shorter than the shared `switcherContentHeight` box (Tray already has this exact branch). This
reopens the specific "CR-01/WR-02 click-swallowing dead-zone" bug class this file's own comments
repeatedly warn about, for the newly added Quick Actions tab.

Several WARNING-level gaps also stand out: the Quick Actions switcher-tab icon isn't gated on
the feature's own enable toggle (unlike Timer's precedent), the DND/Focus failure-flash flag has
no per-attempt identity and can go stale in both directions, a flaky test timeout, and missing
unit coverage for the new pure/security-relevant helper functions.

## Critical Issues

### CR-01: Missing `.quickActionsBarExpanded` branch in `visibleContentZone()` reopens the click-swallowing dead-zone bug class

**File:** `Islet/Notch/NotchWindowController.swift:1833-1925` (specifically the final `else` at 1904-1921)

**Issue:** This codebase enforces a documented "geometry three-site rule" for every switcher-row
tab whose content height differs from the shared `NotchPillView.switcherContentHeight` (196pt)
box: Site 1 is `NotchPillView.tabHeight`, Site 2 is the per-presentation `*Frame` reservation in
`positionAndShow()`, and Site 3 is the matching branch in `visibleContentZone()`. Every existing
tab that renders shorter than 196pt already gets its own Site-3 branch — most tellingly
`.trayExpanded` (real height 117pt) at line 1860-1862 — specifically to prevent the panel from
staying mouse-interactive (`ignoresMouseEvents = false`) over a phantom region below the actual
visible black island shape (documented at length as the "CR-01/WR-02 click-swallowing/dead-zone
regression class", e.g. comments at lines 1851-1856, 1866-1867, 1876-1881).

`.quickActionsBarExpanded` renders at `NotchPillView.quickActionsBarContentHeight` (150pt, see
`NotchPillView.swift:994` and the `tabHeight` switch at `NotchPillView.swift:121`) — shorter than
the 196pt shared box, exactly like Tray. But `visibleContentZone()` has no `else if case
.quickActionsBarExpanded` branch, so it falls into the final `else` (line 1904), which computes:

```swift
contentSize = CGSize(width: expandedSize.width,
                     height: (switcherRowShowing ? NotchPillView.switcherContentHeight : expandedSize.height) + switcherHeight)
```

Since `.quickActionsBarExpanded` is one of the `showsSwitcherRow` cases (`IslandResolver.swift:172`),
`switcherRowShowing` is `true`, so this yields `196 + 44 = 240pt` of "interactive" height. The
real rendered blob (Site 1 + `NotchPillView.switcherRowHeight`) is only `150 + 44 = 194pt` — a
46pt band of panel that stays click-interactive (per `syncClickThrough()`,
`NotchWindowController.swift:1982-1991`, which gates `ignoresMouseEvents` directly off
`visibleContentZone()`) despite having nothing visibly rendered there. Any click landing in that
46pt band while the Quick Actions tab is open is swallowed by the transparent panel instead of
passing through to whatever is underneath (desktop, another app, menu bar extras near the notch)
— the exact defect this file's own comments name and have fixed multiple times for other tabs.

**Fix:** Add a dedicated branch mirroring the `.trayExpanded` pattern, using
`NotchPillView.quickActionsBarContentHeight` instead of falling through to `switcherContentHeight`:

```swift
} else if case .quickActionsBarExpanded = presentationState.presentation {
    // Mirrors trayExpanded's precedent: quickActionsBarContentHeight (150) is shorter
    // than the shared switcherContentHeight box, so it needs its own Site-3 branch or the
    // panel stays interactive over an invisible region below the real content (CR-01 class).
    contentSize = CGSize(width: expandedSize.width,
                         height: NotchPillView.quickActionsBarContentHeight + switcherHeight)
}
```
Place it alongside the other explicit branches (before the generic `else`), and add a regression
test analogous to whatever locks the Tray/Weather geometry today.

## Warnings

### WR-01: Quick Actions switcher-tab icon isn't gated on the feature's own enable toggle

**File:** `Islet/Notch/NotchPillView.swift:202-204` (`orderedSlotViews`), `2749-2769`
(`switcherRow`), `2792-2826` (`topEdgeSwitcherRow`)

**Issue:** `Timer` is a fixed switcher tab explicitly gated on its own enable flag: both
`switcherRow` (line 2761: `if timerEnabled { ... }`) and `topEdgeSwitcherRow` (line 2817:
`if timerEnabled { ... }`) only render the Timer icon when `ActivitySettings.timerKey` is on.
`NotchWindowController.currentPresentation()` (`NotchWindowController.swift:1174-1180`) applies
the analogous gate for Quick Actions at the *content* level — a stale `.quickActions` selection
while the toggle is off falls back to `.home` — but the *icon* itself has no equivalent gate.
`orderedSlotViews` (`NotchPillView.swift:202-204`) simply projects the 4 raw configured slot
values (which may include `.quickActions`, per `SettingsView.swift:534`'s `slotOptions`) with no
filtering on `ActivitySettings.quickActionsKey`.

Reproduction: assign "Quick Actions" to any of the 4 configurable switcher slots in Settings,
then turn the "Quick Actions" activity toggle off. The bolt-icon tile remains visible and
tappable in the switcher row; tapping it sets `viewSwitcherState.selectedView = .quickActions`
(so `filled:` renders it as the "selected" tab, since `filled:` compares against the raw,
ungated `selectedView` at lines 2754/2797/2801/2808/2812), while the actual rendered content
silently falls back to Home — a dead, misleading control that contradicts the documented intent
at `NotchWindowController.swift:1175-1177` ("must fall back to .home instead of leaving the bar
reachable").

**Fix:** Gate the Quick Actions slot the same way Timer is gated — either filter it out of
`orderedSlotViews`'s rendering when `quickActionsEnabled` is false, or skip rendering that
specific tile in `switcherRow`/`topEdgeSwitcherRow` (mirroring the `if timerEnabled` pattern) so
a disabled Quick Actions bar is fully unreachable, not just content-gated.

### WR-02: DND/Focus failure-flash flag has no per-attempt identity — can go stale in both directions

**File:** `Islet/Notch/NotchWindowController.swift:2621-2637` (`handleQuickActionFocusToggle`)

**Issue:**
```swift
private func handleQuickActionFocusToggle() {
    FocusToggleAction.toggle { [weak self] success in
        guard let self else { return }
        guard !success else { return }
        self.quickActionsBarFeedback.lastFailedAction = .focusToggle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.quickActionsBarFeedback.lastFailedAction == .focusToggle {
                self?.quickActionsBarFeedback.lastFailedAction = nil
            }
        }
    }
}
```
1. **Stale failure survives a later success:** on `success == true` the function returns without
   ever clearing `lastFailedAction`. If a prior tap had failed (flag set, auto-clear scheduled
   for T+1.2s) and the user taps again within that window and it *succeeds*, the tile
   (`NotchPillView.swift:1464-1469`) keeps showing the red "failed" exclamation icon — the wrong
   state — until the earlier timer happens to fire.
2. **Premature clear on repeat failures:** the comment at lines 2629-2630 claims the
   `if ... == .focusToggle` guard "prevents a stale timer from clobbering a NEWER failure flash",
   but since `QuickActionsBarCatalog.Action` carries no attempt identity/timestamp and only one
   action (`.focusToggle`) can ever populate this field, the guard cannot distinguish "the same
   failure" from "a second, independent failure". Two rapid failed taps schedule two 1.2s timers
   against the same enum value; the first timer clears the flag at T+1.2s from the *first*
   failure, even though the *second* failure's own indicator should still have ~1.2s left to
   show.

**Fix:** Give the auto-clear a per-attempt token (e.g. a monotonically increasing counter or a
`UUID` stored alongside `lastFailedAction`), and clear the flag unconditionally on success:
```swift
guard !success else { self.quickActionsBarFeedback.lastFailedAction = nil; return }
```
plus compare the scheduled clear against the specific attempt it was scheduled for, not just the
action's identity.

### WR-03: No unit test coverage for the new pure/security-relevant helper functions

**File:** `Islet/Notch/QuickActionsBar/QuickActionsBarCatalog.swift`,
`Islet/Notch/QuickActionsBar/LaunchAction.swift`

**Issue:** `orderedQuickActionsBarSlots(_:)` (`QuickActionsBarCatalog.swift:33-35`) and
`LaunchAction.resolvedURL(from:)` (`LaunchAction.swift:13-20`) are both plain, dependency-free
pure functions — exactly the shape this codebase otherwise tests exhaustively (see
`IslandResolverTests`/`NotchPillViewTests` covering every sibling pure helper, including
`orderedSlotIcons` which `orderedQuickActionsBarSlots` explicitly mirrors). `LaunchAction`'s own
doc comment calls `resolvedURL(from:)` "the ONE validation chokepoint" guarding against a stored
string being string-interpolated into a shell/AppleScript call — exactly the kind of function
that should have a regression test locking its accept/reject boundaries (empty string, existing
file path, well-formed URL with scheme, schemeless string, relative path). Neither function has
any test in `IsletTests/` (confirmed: no `QuickActionsBarCatalogTests.swift` /
`LaunchActionTests.swift` exist).

**Fix:** Add a small `QuickActionsBarCatalogTests.swift` (filter/order behavior) and
`LaunchActionTests.swift` (accept/reject boundary cases for `resolvedURL(from:)`), mirroring the
existing `FocusToggleActionTests.swift`'s "test the one pure piece" discipline.

### WR-04: `FocusToggleActionTests.testToggleDoesNotCrashAndReportsFalseWhenUnauthorized` is flaky by construction

**File:** `IsletTests/FocusToggleActionTests.swift:30-43`

**Issue:** The test wraps a real `FocusToggleAction.toggle` call (which spawns
`INFocusStatusCenter.default.requestAuthorization`, then a real `/usr/bin/shortcuts` `Process`)
in a 2-second `waitForExpectations` timeout. The test's own comment acknowledges authorization
"fires... after a system prompt otherwise" — i.e. on a machine/CI runner where Focus
authorization is still undecided, this can require human interaction and will not resolve within
2 seconds, failing the test for reasons unrelated to the code under test (this is explicitly
flagged as out of scope to report per review guidelines unless it affects test reliability —
it does: a hang/timeout here is indistinguishable from a real regression in CI).

**Fix:** Either skip this test when `FocusModeMonitor.isAuthorized` is `false` (can't be
determined synchronously before the async completion, so consider gating on a `CI` environment
variable or restructuring to avoid the live authorization round-trip in an automated suite), or
document it as a manual/on-device-only test.

## Info

### IN-01: `ScreenLockAction` depends on an undocumented private symbol (already flagged as accepted risk)

**File:** `Islet/Notch/QuickActionsBar/ScreenLockAction.swift:11-20`

**Issue:** `dlopen`/`dlsym` into `login.framework`'s private `SACLockScreenImmediate` symbol has
no public API equivalent and is unconfirmed on very recent macOS versions per the file's own
comment (RESEARCH.md Pitfall 3, "mandatory on-device verification deferred to Plan 65-08"). Not a
new defect — flagging only to ensure the mandatory on-device verification this comment defers
actually happened before this ships, since a symbol removal in a future macOS silently degrades
to "nothing happens" (guarded, no crash) rather than surfacing to the user.

**Fix:** N/A — confirm the deferred on-device verification (Plan 65-08) was completed; no code
change implied by this review.

### IN-02: Inconsistent `@MainActor` annotation across the Quick Actions system-call helpers

**File:** `Islet/Notch/QuickActionsBar/CaffeinateToggleAction.swift`,
`DisplaySleepAction.swift`, `DarkModeToggleAction.swift`, `EmptyTrashAction.swift`,
`ScreenLockAction.swift` vs. `FocusToggleAction.swift`

**Issue:** `FocusToggleAction` is explicitly marked `@MainActor` (with a doc comment explaining
why). The sibling action enums hold their own mutable static state (`CaffeinateToggleAction.
isActive`/`assertionID`) or make otherwise-identical system calls but carry no actor isolation at
all, relying entirely on the informal convention that every call site happens to be on the main
thread today (`NotchWindowController.handleQuickActionTap`, `NotchPillView`'s body reads).
Nothing currently violates this, but it's an easy invariant to break silently (e.g. a future
background-queue call site) since the compiler won't catch it for these types the way it would
for `FocusToggleAction`.

**Fix:** Consider marking `CaffeinateToggleAction` (and the other static-state-holding actions)
`@MainActor` for consistency and compiler-enforced safety, matching `FocusToggleAction`'s
precedent.

---

_Reviewed: 2026-07-26T02:16:17Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
