---
phase: 03-charging-activity
reviewed: 2026-06-27T17:31:29Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - Islet/Notch/PowerSourceMonitor.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/Notch/PowerActivity.swift
  - Islet/Notch/ChargingActivityState.swift
  - Islet/Notch/NotchGeometry.swift
  - Islet/Notch/NotchPillView.swift
  - IsletTests/PowerActivityTests.swift
  - IsletTests/NotchGeometryTests.swift
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-06-27T17:31:29Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Phase 3 wires a live IOKit power-source monitor into a pure `power -> presentation`
mapping that drives a SwiftUI "wings" charging splash. The riskiest areas called out
for scrutiny are all implemented correctly:

- **IOKit Unmanaged ownership is correct throughout.** Copy/Create results
  (`IOPSCopyPowerSourcesInfo`, `IOPSCopyPowerSourcesList`,
  `IOPSNotificationCreateRunLoopSource`) use `takeRetainedValue()`; the Get result
  (`IOPSGetPowerSourceDescription`) uses `takeUnretainedValue()`. The "retain a Get"
  over-release crash (Pitfall 1) is avoided.
- **The `@convention(c)` callback context pointer is handled safely.** `self` is passed
  via `passUnretained(...).toOpaque()` and recovered with `takeUnretainedValue()`; the
  monitor is owned by the controller for the entire app lifetime (held by `AppDelegate`),
  `stop()` removes the run-loop source in the controller's `deinit`, and `onChange`
  captures `[weak self]`. The `DispatchQueue.main.async` hop occurs before any
  `@Published`/AppKit touch. No use-after-free or data race was found.
- **`shouldTriggerSplash` and the launch-seed guard are correct.** The connect-only
  predicate (`isOnAC(next) && !isOnAC(previous)`) matches the documented matrix, and
  `didSeedInitialPower` correctly seeds `lastActivity` without firing on the first reading.
- **Main-actor and SwiftUI correctness is sound.** `PowerSourceMonitor` is `@MainActor`
  with a deliberately `nonisolated stop()`/`deinit` for the controller's `nonisolated`
  deinit; mutations to `chargingState.activity` happen on main inside `withAnimation`.

The pure seams (`powerActivity`, `shouldTriggerSplash`, `wingsFrame`) are well covered by
unit tests. The findings below are a defensive-correctness gap in `readCurrentPower`, one
behavioral edge in `handlePower`, and three minor maintainability notes. None are blocking.

## Warnings

### WR-01: Malformed-capacity branch can emit an out-of-range percent into a sized glyph

**File:** `Islet/Notch/PowerSourceMonitor.swift:48-51`
**Issue:** When `kIOPSMaxCapacityKey` is missing/malformed, `mx` defaults to `100` and the
percent is computed as `cur / mx * 100`. But when `mx <= 0` (e.g. a transient `0` reported
by the OS during a power transition), the code falls through to `: cur` and returns the raw
`kIOPSCurrentCapacityKey` value **unclamped**. For most batteries `cur` is already 0..100,
but the IOPS contract does not guarantee that — some sources report `CurrentCapacity` as an
absolute mAh value rather than a percentage. `powerActivity(from:)` does clamp to 0..100
downstream, so this cannot crash or escape the UI as a negative/huge number. However, it
relies entirely on the *consumer* to clamp; the raw reading itself is contractually "0..100,
clamped" per `PowerReading`'s own doc comment (`percent: Int // 0...100, clamped`), which it
violates in this branch. The defensive intent stated in the comment ("a missing / malformed
key never force-unwraps or crashes") is met, but the *clamp* invariant the struct advertises
is not.
**Fix:** Clamp at the source so `PowerReading.percent` always honors its documented contract,
independent of the downstream consumer:
```swift
let rawPct = mx > 0 ? Int((Double(cur) / Double(mx) * 100).rounded()) : cur
let pct = min(max(rawPct, 0), 100)
return PowerReading(isPresent: true, isOnAC: isOnAC, isCharging: charging, isCharged: charged, percent: pct)
```

### WR-02: A standing on-battery splash never updates its percent while it stands

**File:** `Islet/Notch/NotchWindowController.swift:390-395`
**Issue:** The "pure % tick" branch updates a standing splash only when
`chargingState.activity != nil`. That is correct, but combined with the connect-only
`shouldTriggerSplash`, the *only* way a non-nil `activity` can stand is after a connect
edge (charging/full). An `.onBattery` activity is therefore never shown by the live path
(it can never be the `next` of a fire, and the seed never fires) — yet `powerActivity`
still produces `.onBattery` readings and `handlePower` still assigns them via
`lastActivity = next`. This is consistent with the documented "connect-only" product
decision, so it is not a logic *error*. The latent risk is the second branch's condition:
if a future change ever lets `.onBattery` stand (e.g. re-enabling CHG-02's unplug cue),
this branch would silently update an on-battery splash's percent without restarting the
timer, which is the intended behavior — but there is no test asserting the standing-splash
percent-refresh path at the controller level (the pure tests cover `shouldTriggerSplash`
only). The branch is currently unreachable for `.onBattery` and only reachable for
charging/full ticks.
**Fix:** No code change required for current behavior. To prevent silent regressions when
Phase 6 wires the preferences toggle, add a controller-level (or extracted-helper) test that
a same-category percent tick updates `chargingState.activity` without rescheduling
`dismissWorkItem`, and document that `.onBattery` is intentionally never a standing splash in
v1. Consider extracting the `handlePower` decision (fire / tick / ignore) into a small pure
function so it can be unit-tested like `shouldTriggerSplash`.

## Info

### IN-01: Monitor `deinit` is an empty teardown that depends on an external contract

**File:** `Islet/Notch/PowerSourceMonitor.swift:106-111`
**Issue:** `PowerSourceMonitor.deinit` is intentionally empty; the run-loop source is torn
down by `NotchWindowController.deinit` calling `powerMonitor.stop()`. This works because the
controller owns the monitor for the app lifetime and both deinit on main at process exit. But
the safety of the context pointer (`passUnretained(self)`) now depends on a *cross-object*
contract: if the monitor were ever owned by something that releases it without calling
`stop()`, the live run-loop source would hold a dangling `void*` to a freed monitor. The
comment documents this, but the invariant is enforced only by convention.
**Fix:** Make the object self-cleaning so the contract cannot be violated. Since `stop()` is
already `nonisolated` and `CFRunLoopRemoveSource` is thread-safe, call it from `deinit`:
```swift
deinit { stop() }
```
This is redundant with the controller's call (and harmless — `stop()` nils `runLoopSource`)
but removes the dependence on the external teardown.

### IN-02: `wingsSize` width comment and test seed diverge from the shipped constant

**File:** `Islet/Notch/NotchPillView.swift:57`
**Issue:** The shipped `wingsSize` is `305 x 32`, but `NotchGeometryTests` exercises
`wingsFrame` with a `360 x 40` seed and `expandedNotchFrame` with `360 x 72`. The tests
explicitly build their own size (correctly noted in the comment), so this is not a test bug.
It is a maintainability snag: the panel-union math in `positionAndShow`
(`expandedFrame.union(wings)`) depends on the *real* `wingsSize`, and the 32 pt wings height
is shorter than the 38 pt collapsed pill — the union is dominated by the 72 pt expanded
height, so the wings strip fits. No correctness issue, but the divergence between the
documented "tuned 305 x 32" and the test seeds means the union geometry is only ever
validated on-device, never in a test.
**Fix:** Add one `wingsFrame` test using the *actual* `NotchPillView.wingsSize` and assert
`expandedFrame.union(wingsFrame)` fully contains both, so a future tuning of either constant
that breaks the union (e.g. a wings width exceeding the expanded width on a narrow notch) is
caught in CI rather than on-device.

### IN-03: `expandedIsland` renders `Date.now` once with no live clock (stale time)

**File:** `Islet/Notch/NotchPillView.swift:112`
**Issue:** The expanded island shows `Text(Date.now, format: ...)`. `Date.now` is evaluated
when the view body recomputes, not on a timer, so the displayed time freezes at the moment
the island last re-rendered and will be stale on a long-standing expanded island. The code
comment explicitly flags this as a "Phase-2 placeholder only — real activity content arrives
Phase 3+", so it is known and out of this phase's scope.
**Fix:** No action this phase. When real expanded content lands, drive the time from a
`TimelineView(.periodic(...))` or a `Text(timerInterval:)`/`Text(_:style:)` so it stays live
without a manual clock.

---

_Reviewed: 2026-06-27T17:31:29Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
