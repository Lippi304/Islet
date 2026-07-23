---
phase: 60-caps-lock-hud-update-activity-restyle
reviewed: 2026-07-23T20:35:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - Islet/ActivitySettings.swift
  - Islet/AppDelegate.swift
  - Islet/Notch/CapsLockActivity.swift
  - Islet/Notch/CapsLockMonitor.swift
  - Islet/Notch/IslandResolver.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/Notch/UpdateActivity.swift
  - Islet/SettingsView.swift
  - IsletTests/ActivitySettingsTests.swift
  - IsletTests/IslandResolverTests.swift
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: clean
resolved: 2026-07-23T20:45:00Z
resolution: >
  WR-01, WR-02 fixed as suggested. WR-03's suggested fix was verified INCORRECT (removing the
  dispatch reintroduces a real compiler warning under this project's Swift 5 language mode) —
  kept the dispatch, added the explanation the review flagged as missing instead. IN-03 (trivial
  style) fixed. IN-01/IN-02 left as explicitly-optional per the review's own text.
---

# Phase 60: Code Review Report

**Reviewed:** 2026-07-23T20:35:00Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Phase 60 adds two new transient HUDs (Caps Lock on/off, Update Available) by mechanically
reapplying the codebase's existing "pure activity → resolver → wings" pattern. The pure layers
(`CapsLockActivity.swift`, `UpdateActivity.swift`, `IslandResolver.swift`'s new cases/branches)
are correct, total, and well covered by `IslandResolverTests.swift`. The three on-device
checkpoint bugfixes described in the task (stale `AXIsProcessTrusted()` health-check retry,
`.flagsChanged`-fires-on-every-modifier-key dedup, and the two Spacer()-based wing rebuilds) are
all present, internally consistent, and I found no leftover debug prints, `CAPSDEBUG` artifacts,
or commented-out code specific to Phase 60's own iteration (the `[OSD-GEOM]`/`[OSD-TIMING]`
`print()`/`#if DEBUG` instrumentation still in `NotchPillView.swift`/`NotchWindowController.swift`
predates this phase — it is Phase 39's own debt, not introduced here, and is left out of scope).

Real gaps found: (1) toggling the Update HUD off while a transient is showing/queued does not
flush it, unlike every other toggle-gated activity including its own sibling Caps Lock; (2)
`capsLockWings`/`updateWings` duplicate `osdWings`' fragile inline camera-block geometry math but
dropped the `assert()` sanity checks that make `osdWings` self-defending against a future
`wingsShape`/`interaction.collapsedNotchSize` change; (3) `CapsLockMonitor`'s health-check timer
closure contains a redundant, confusing nested `DispatchQueue.main.async` hop that muddies the
exact actor-isolation reasoning the surrounding comments otherwise carefully document. None of
these are blocking on their own, but they are worth fixing before this ships as the reference
pattern for the next 8 v1.10 activities (60-RESEARCH.md's reserved-slot table explicitly expects
Phases 61-67 to clone this phase's shape).

## Warnings

### WR-01: Disabling the Update HUD toggle live does not dismiss/flush a standing or queued Update transient

**File:** `Islet/Notch/NotchWindowController.swift:2445-2453`
**Issue:** The live-settings reconciliation block explicitly handles Caps Lock's toggle-off by
calling `capsLockMonitor?.stop(); flushTransients(.capsLock)` (mirroring every other toggle-gated
activity: Device, Focus, Calendar Countdown, Now Playing, song-change toast). The adjacent comment
for Update HUD says "nothing to start/stop, its only gate is the guard inside
`handleUpdateAvailable(version:)`" and therefore has no block at all. That guard
(`NotchWindowController.swift:2154`) only prevents a *future* `didFindValidUpdate` callback from
enqueuing a new transient — it does nothing for an Update transient that is already the queue
head or already sitting in `pending` (up to `maxDepth = 2`) at the moment the user flips the
toggle off in Settings. Because `.updateAvailable` is not `isPersistent`
(`IslandResolver.swift:134-137`), the window is bounded by `activityDuration` (3.0s) per
occurrence, but a queued copy can sit behind other transients (Charging/Device/Focus/OSD/CapsLock)
for much longer before it is promoted and shown — after the user has already turned the feature
off. This is a real, reachable inconsistency, not just a theoretical one, since the reconciliation
function runs on *every* UserDefaults write, including the toggle flip itself.
**Fix:** Add a Caps-Lock-mirroring branch for the Update key:
```swift
// Phase 60 / UPDATE-01 — Update HUD has no monitor to stop, but a standing/queued transient
// must still be flushed on live toggle-off, mirroring capsLock's block above.
if !activityEnabled(ActivitySettings.updateHudKey) {
    flushTransients(.updateAvailable)
}
```

### WR-02: `capsLockWings`/`updateWings` drop the sanity-check `assert()`s their sibling `osdWings` relies on

**File:** `Islet/Notch/NotchPillView.swift:2879-2960` (compare `osdWings` at `2829-2831`)
**Issue:** All three wings (`osdWings`, `capsLockWings`, `updateWings`) compute their
`leftWidth`/`rightWidth`/`cameraBlockWidth` from the same fragile shape:
`rawNotchHalfWidth = (interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width) / 2`
plus an on-device-tuned `margin` constant. `osdWings` — the very function this pattern was copied
from — was hardened with two runtime `assert()`s after its own multi-round debugging saga:
```swift
assert(cameraBlockWidth > 0, "OSD camera block width (\(cameraBlockWidth)) must be positive")
assert(rightWidth < 325 && leftWidth < 325, "OSD wing footprint ... must stay inside the ~325pt safe panel-frame budget")
```
`capsLockWings` and `updateWings` reproduce the exact math these asserts protect (same
`notchHalfWidth`/`cameraBlockWidth` derivation, same 325pt panel-frame budget referenced in
`osdWings`' own comment) but neither carries the asserts. If `wingsShape`'s corner radii/height,
`interaction.collapsedNotchSize`'s reporting, or a future device's physical notch width changes
these two wings' footprint past the panel's safe frame, `osdWings` will trip a debug-build assert
immediately; `capsLockWings`/`updateWings` will silently clip/mis-position with no signal at all —
precisely the failure mode this phase's on-device checkpoint spent a whole round fixing for Caps
Lock's text clipping under the camera.
**Fix:** Carry the same two asserts into both functions (same values — `cameraBlockWidth > 0`,
`leftWidth < 325 && rightWidth < 325`), e.g. immediately after each function's `rightWidth`
computation.

### WR-03: Redundant nested `DispatchQueue.main.async` inside `CapsLockMonitor`'s health-check timer obscures the actor-isolation reasoning

**File:** `Islet/Notch/CapsLockMonitor.swift:73-81`
**Issue:**
```swift
private func armHealthCheck() {
    guard healthCheckTimer == nil else { return }
    healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
        DispatchQueue.main.async { [weak self] in
            guard let self, self.monitorToken == nil, Self.isAccessibilityTrusted else { return }
            self.install()
        }
    }
}
```
`armHealthCheck()` is a plain (non-`nonisolated`) method on a `@MainActor` class, so the
`Timer.scheduledTimer(withTimeInterval:repeats:block:)` trailing closure is itself created — and,
per Swift's closure-isolation inference, isolated to — the main actor already (this is exactly
why the closure is allowed to read/write `self.monitorToken`, a main-actor-isolated property,
without a compiler error). The inner `DispatchQueue.main.async { [weak self] in ... }` is therefore
a second, unnecessary hop to the same queue the closure is already running on, with a second,
unnecessary `[weak self]` capture. This reads as leftover defensive code from the on-device
debugging session (the task description notes this fix was iterated on-device) rather than a
deliberate design choice — nothing in the surrounding comments explains why the extra hop exists,
and it actively works against this file's otherwise careful actor-isolation documentation by
making a reviewer second-guess whether the outer closure's isolation can actually be trusted.
**Fix:** Drop the inner dispatch and act directly in the Timer closure:
```swift
healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
    guard let self, self.monitorToken == nil, Self.isAccessibilityTrusted else { return }
    self.install()
}
```
If there is a real reason the extra hop is needed (e.g. an observed case where the Timer callback
does *not* run on the main actor), it should be captured as a comment — currently nothing
documents it.

## Info

### IN-01: `CapsLockMonitor` has no detection path for Accessibility trust being *revoked* after being granted

**File:** `Islet/Notch/CapsLockMonitor.swift:49-71`
**Issue:** `armHealthCheck()`/`install()` handle the "not yet trusted → becomes trusted" direction
(the on-device checkpoint's Bug 1 fix) but there is no equivalent check for the reverse: once
`monitorToken != nil`, `start()`'s idempotent guard (`guard monitorToken == nil else { return }`)
means nothing re-checks `AXIsProcessTrusted()` again for the lifetime of that monitor instance. If
a user revokes Accessibility access in System Settings while the app is running, the existing
global monitor token is not proactively invalidated by this class, and there's no user-visible
signal that the HUD silently stopped working (the Settings toggle still reads "on"). This is a
narrower/rarer case than the two on-device-confirmed bugs and may be accepted scope, but is worth
a conscious decision rather than an implicit gap.
**Fix:** Not necessarily required for this phase, but consider: either periodically re-validate
trust (extend the health-check timer to also run while `monitorToken != nil`), or explicitly
document this as an accepted limitation.

### IN-02: `capsLockWings`/`updateWings`/`osdWings` triplicate the same camera-block geometry pattern inline

**File:** `Islet/Notch/NotchPillView.swift:2791-2816, 2879-2908, 2920-2960`
**Issue:** Three separate wing functions each independently compute
`rawNotchHalfWidth`/`notchHalfWidth`/`cameraBlockWidth` from `interaction.collapsedNotchSize`, with
only the tuning constants (`margin`, content-box widths) differing. This is consistent with the
phase's own stated approach ("mechanical reapplication," each margin independently on-device
tuned), so is not a defect, but it does mean any future correction to the *shared* part of this
math (e.g. if `interaction.collapsedNotchSize` semantics change) must be applied identically in
three places by hand, with no compiler help if one call site is missed.
**Fix:** Optional: factor the `notchHalfWidth`/`cameraBlockWidth` computation into a small shared
helper (e.g. `private func cameraBlockWidth(margin: CGFloat) -> CGFloat`) that all three wings
call, leaving only the margin/content-width tuning as each function's own concern. Not urgent —
flagging for awareness given Phases 61-67 are expected to clone this same pattern per
60-RESEARCH.md's reserved-slot table.

### IN-03: Inconsistent optional-unwrap style for `capsLockMonitor.stop()` in `deinit`

**File:** `Islet/Notch/NotchWindowController.swift:2909`
**Issue:** Every other monitor teardown in `deinit` uses `foo?.stop()` (e.g.
`bluetoothMonitor?.stop()`, `focusModeMonitor?.stop()`, `osdInterceptor?.stop()`), but the Caps
Lock line uses `if let capsLockMonitor { capsLockMonitor.stop() }`. Functionally identical, purely
a style inconsistency with the surrounding code it explicitly claims to mirror ("mirrors
`focusModeMonitor?.stop()`'s owner-driven teardown discipline exactly").
**Fix:** `capsLockMonitor?.stop()` for consistency with the rest of the function.

---

_Reviewed: 2026-07-23T20:35:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
