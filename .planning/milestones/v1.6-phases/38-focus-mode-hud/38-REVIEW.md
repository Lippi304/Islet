---
phase: 38-focus-mode-hud
reviewed: 2026-07-17T03:10:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - Islet.xcodeproj/project.pbxproj
  - Islet/Notch/FocusActivity.swift
  - Islet/Notch/IslandResolver.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/SettingsView.swift
  - IsletTests/FocusActivityTests.swift
  - IsletTests/IslandResolverTests.swift
findings:
  critical: 1
  warning: 1
  info: 1
  total: 3
status: issues_found
---

# Phase 38: Code Review Report

**Reviewed:** 2026-07-17T03:10:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

This is a full, independent re-review of all 8 listed files, not a diff review. Gap-closure plan
38-08 is confirmed to have correctly fixed the two prior BLOCKER findings:

- **CR-01 (prior, `activityEnabled(_:)` default)** — **RESOLVED**. `NotchWindowController.swift:566-569`
  now special-cases `ActivitySettings.focusKey` to a `false` default, matching
  `SettingsView.swift:37`'s `@AppStorage(focusKey) private var focusEnabled = false`. A fresh
  install with pre-existing OS-level Focus authorization no longer silently auto-starts the monitor.
- **CR-02/WR-02 (prior, permission-grant never wired to controller)** — **RESOLVED**.
  `SettingsView.swift:273-282`'s "Continue" button now calls
  `FocusModeMonitor.requestAuthorization` and, inside the completion (hopped to main), calls
  `NotchWindowController.focusPermissionGranted()` (`NotchWindowController.swift:627-629`), which
  re-runs `handleSettingsChanged()` — the same start-gate logic launch/toggle already use. As a
  side effect, moving `showFocusPermissionExplanation = false` inside the completion (rather than
  firing synchronously before the async result returns) also fixes WR-02's second half: the
  inline-computed `ActivitySettings.focusPermissionStatusHint(...)` hint text now re-renders with
  the correct, post-grant `FocusModeMonitor.isAuthorized` value.

**WR-01 (prior, `TransientQueue.preempt(_:)` bypasses `maxDepth`)** — **STILL OPEN**, confirmed
unchanged at `IslandResolver.swift:257-263` (explicitly out of scope for 38-08 per the gap-closure
plan). Carried forward below as WR-01.

This review also found one **new BLOCKER**: the controller path that reacts to the real macOS
Focus/DND state turning back OFF (`NotchWindowController.handleFocusChange(false)`) never re-renders
the resolver's verdict, so the island can get stuck showing the Focus wing indefinitely after Focus
actually deactivates — see CR-01 below (renumbered for this fresh review; distinct from the
now-resolved prior CR-01).

## Critical Issues

### CR-01: `handleFocusChange(false)` flushes the Focus transient but never re-renders — the island can get stuck showing "Focus" after the real Focus/DND state turns off

**File:** `Islet/Notch/NotchWindowController.swift:1593-1602` (caller), `:1784-1805` (`flushTransients`)

**Issue:** `FocusModeMonitor` polls every 2.5s and calls `onChange(isFocused)` unconditionally on
every successful read (no change-detection inside the monitor itself —
`FocusModeMonitor.swift:56-63`). When Focus turns off, this lands in:

```swift
private func handleFocusChange(_ isFocused: Bool) {
    if isFocused {
        guard let activity = focusActivity(from: true) else { return }
        let changed = transientQueue.enqueue(.focus(activity))
        if changed {
            presentTransientChange()
        }
    } else {
        flushTransients(.focus)
    }
}
```

`flushTransients(_:)` mutates the queue, conditionally re-arms the shared dismiss timer, but never
calls `renderPresentation()` or `updateVisibility()` itself:

```swift
private func flushTransients(_ category: TransientCategory) {
    let oldHead = transientQueue.head
    ...
    transientQueue.removeAll(where: matches)
    switch category {
    case .charging: chargingState.activity = nil
    case .device:   deviceCoordinator.clearPendingBatteryPolls()
    case .focus: break
    }
    guard transientQueue.head != oldHead else { return }   // WR-2 guard
    dismissWorkItem?.cancel()
    if transientQueue.head != nil {
        deviceCoordinator.activityPromoted()
        scheduleActivityDismiss()
    }
}
```

Every OTHER caller of `flushTransients` is `handleSettingsChanged()`, whose function tail
unconditionally calls `renderPresentation()` + `updateVisibility()` after every branch runs
(`NotchWindowController.swift:1762-1765`) — so the Charging/Device disable-in-Settings path is
fine. `handleFocusChange`'s `else` branch is the *only* call site that invokes `flushTransients`
with nothing after it.

Trace the common case: Focus is the standing head (`.focus(.on)`, never auto-dismissing per D-06 —
`scheduleActivityDismiss()` explicitly skips arming a timer for a persistent head), nothing else is
queued (Charging/Device always *preempt* Focus rather than queuing behind it, so `pending` is empty
while Focus is head). The real Focus/DND state turns off. `handleFocusChange(false)` →
`flushTransients(.focus)` removes the head, `transientQueue.head` goes from `.focus(.on)` to `nil` —
the `oldHead` guard passes (a change did occur) — but since the new head is `nil`, the
`if transientQueue.head != nil` branch never runs either, so **nothing calls `renderPresentation()`**.
`presentationState.presentation` (the `@Published` value `NotchPillView` renders) is never
recomputed and stays frozen at `.focus(.on)`.

Because the monitor calls `onChange(false)` again every subsequent 2.5s poll, `flushTransients`
runs again each time — but `transientQueue.head` no longer differs from `oldHead` (both `nil`), so
the guard returns early every time. The stale presentation is never corrected by this code path at
all; it only self-heals incidentally the next time some *unrelated* event calls
`renderPresentation()` (e.g. a hover-enter/exit cycle's grace-collapse, a click, a Now-Playing
update, a Charging/Device event). Until then, the island visibly keeps showing the "Focus" wing long
after the user has turned Focus/DND off — directly contradicting D-06's "stays standing until the
underlying Focus state itself turns off."

**Fix:** Re-render (and re-run the sole visibility gate) after the flush, mirroring
`handleSettingsChanged`'s tail:

```swift
private func handleFocusChange(_ isFocused: Bool) {
    if isFocused {
        guard let activity = focusActivity(from: true) else { return }
        let changed = transientQueue.enqueue(.focus(activity))
        if changed {
            presentTransientChange()
        }
    } else {
        flushTransients(.focus)
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            renderPresentation()
        }
        updateVisibility()
    }
}
```

## Warnings

### WR-01: `TransientQueue.preempt(_:)` bypasses the `maxDepth` bound and conflicts with `enqueue(_:)`'s overflow-eviction order (carried forward, still unfixed)

**File:** `Islet/Notch/IslandResolver.swift:257-263`

**Issue:** Unchanged from the prior review. `preempt(_:)` inserts the displaced Focus at
`pending[0]` with no bound check:

```swift
mutating func preempt(_ t: ActiveTransient) -> Bool {
    guard case .focus = head else { return enqueue(t) }
    let displaced = head!
    head = t
    pending.insert(displaced, at: 0)
    return true
}
```

while `enqueue(_:)` bounds `pending` by appending to the back and trimming the *front* on overflow.
If `pending` is already at `maxDepth` when a `preempt` runs, the insert grows it to 3 (bound
violation); and because the displaced Focus sits at index 0 — the exact index `enqueue`'s overflow
logic evicts from — two subsequent ordinary `enqueue` calls (Charging/Device queuing behind the new,
non-Focus head) can silently evict the just-displaced Focus before `advance()` ever reaches it,
breaking the documented "resumes on the very next `advance()`" guarantee. (Focus self-heals within
~2.5s via the next `FocusModeMonitor` poll re-enqueueing it, so this is not a permanent loss, but the
queue-ordering/bound contract is violated for Focus specifically, and no test exercises the
3-plus-entry interleaving.)

**Fix:** Trim after the insert, symmetric with `enqueue`'s own bound:

```swift
mutating func preempt(_ t: ActiveTransient) -> Bool {
    guard case .focus = head else { return enqueue(t) }
    let displaced = head!
    head = t
    pending.insert(displaced, at: 0)
    if pending.count > maxDepth { pending.removeLast() }   // trim from the back, never the just-reinserted front
    return true
}
```

## Info

### IN-01: `handleFocusChange`'s `guard let activity = focusActivity(from: true)` is dead code

**File:** `Islet/Notch/NotchWindowController.swift:1594-1595`

**Issue:** `focusActivity(from:)` is `isFocused ? .on : nil` (`FocusActivity.swift:19-21`). The call
site is inside `if isFocused { guard let activity = focusActivity(from: true) else { return } ... }`
— the argument is the literal `true`, so `focusActivity(from: true)` always returns `.on` and the
`else` branch of the guard can never execute. It reads as if some future case could make this
mapping fail, but it structurally cannot given the call site always passes a literal.

**Fix:** Either drop the indirection (`transientQueue.enqueue(.focus(.on))` directly) or, if the
mirrored-pattern-with-PowerActivity style is intentional (consistency with other transient handlers
that map a live reading through a pure function), leave a short comment noting the guard is
unreachable by construction so a future reader isn't confused into thinking it's meaningful dead
code protecting against something.

---

_Reviewed: 2026-07-17T03:10:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
