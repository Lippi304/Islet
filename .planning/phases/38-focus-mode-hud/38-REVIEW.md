---
phase: 38-focus-mode-hud
reviewed: 2026-07-17T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - Islet/ActivitySettings.swift
  - Islet/Notch/FocusActivity.swift
  - Islet/Notch/FocusModeMonitor.swift
  - Islet/Notch/IslandResolver.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/SettingsView.swift
  - IsletTests/ActivitySettingsTests.swift
  - IsletTests/FocusActivityTests.swift
  - IsletTests/IslandResolverTests.swift
findings:
  critical: 2
  warning: 2
  info: 0
  total: 4
status: issues_found
---

# Phase 38: Code Review Report

**Reviewed:** 2026-07-17T00:00:00Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

The pure seams (`FocusActivity.swift`, the `resolve(...)`/`ActiveTransient.isPersistent` additions in
`IslandResolver.swift`) are well tested and correct — `IslandResolverTests.swift` and
`FocusActivityTests.swift` cover the documented precedence (D-07 collapsed-only, D-06 persistent/no
auto-dismiss, D-08 preempt-pushes-to-front) and the exhaustive `ActiveTransient`/`IslandPresentation`
switches in `NotchPillView.swift`/`NotchWindowController.swift` were extended correctly with no missed
case (compiler-enforced exhaustiveness, and `visibleContentZone()`/`showsSwitcherRow` correctly treat
`.focus` as collapsed-only, matching every other wing state).

However, the system-glue wiring between the Settings permission flow and the controller's monitor
lifecycle has two BLOCKER-level gaps that mean the feature this phase implements can end up either
silently OFF-by-default-but-secretly-ON, or ON-in-Settings-but-never-actually-running — the opposite
failure modes of the same root cause: `NotchWindowController` reads Focus's enabled/authorized state
independently in two places with no reactive link to the moment permission is actually granted. There
is also a queue-invariant bug in the new `TransientQueue.preempt(_:)` that can silently violate the
documented "displaced Focus resumes on the very next advance()" and D-03 bound guarantees under a
specific interleaving.

## Critical Issues

### CR-01: `activityEnabled(_:)`'s default-true fallback silently overrides Focus's documented default-OFF, auto-starting the monitor without consent whenever OS authorization is already granted

**File:** `Islet/Notch/NotchWindowController.swift:561-563` (helper), consumed at `:474` and `:1713`

**Issue:** `activityEnabled(_:)` is the single UserDefaults read helper for every activity toggle:

```swift
private func activityEnabled(_ key: String) -> Bool {
    UserDefaults.standard.object(forKey: key) as? Bool ?? true
}
```

Its doc comment explicitly says "Defaults to TRUE (D-07 all default ON) when the key is absent". That
is correct for `chargingKey`/`nowPlayingKey`/`deviceKey`/`songChangeToastKey` — but `focusKey` is the
*one* toggle this phase deliberately defaults OFF (`ActivitySettings.swift:19-22`, `SettingsView.swift:37`
`@AppStorage(focusKey) private var focusEnabled = false`). On a fresh install nothing has ever written
`focusKey` to `UserDefaults`, so `activityEnabled(ActivitySettings.focusKey)` incorrectly returns `true`.

Both call sites gate on `activityEnabled(...) && FocusModeMonitor.isAuthorized`:

```swift
// start(), line 474
if activityEnabled(ActivitySettings.focusKey) && FocusModeMonitor.isAuthorized { startFocusModeMonitor() }
// handleSettingsChanged(), line 1713
if activityEnabled(ActivitySettings.focusKey) && FocusModeMonitor.isAuthorized {
    startFocusModeMonitor()
}
```

Since `activityEnabled` is wrong, the *only* thing currently preventing an unrequested auto-start is
`FocusModeMonitor.isAuthorized` happening to be `false`. But `FocusModeMonitor.swift`'s own header
comment documents that on the actual build/dev machine this project ships from, `INFocusStatusCenter`
already reports `.authorized` with no explicit request ("Path A won — `INFocusStatusCenter` reaches
`.authorized` on this dev machine (macOS 26/Tahoe)"). On any machine in that state, a fresh install —
Settings never opened, toggle showing OFF per its `@AppStorage` default — will silently start polling
Focus/DND status and show the Focus HUD at launch. This directly violates D-01 (toggle defaults OFF)
and D-02 ("the permission ask happens ONLY at this exact off-to-on flip, never at launch" — here no ask
is even needed because the buggy default already treated the toggle as ON).

**Fix:** Give `focusKey` its own explicit default instead of reusing the shared true-default helper, e.g.:

```swift
private func activityEnabled(_ key: String) -> Bool {
    let defaultValue = (key == ActivitySettings.focusKey) ? false : true
    return UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
}
```

## Warnings

### WR-01: `TransientQueue.preempt(_:)` bypasses the `maxDepth` bound and conflicts with `enqueue(_:)`'s overflow-eviction order, risking the displaced Focus never resuming

**File:** `Islet/Notch/IslandResolver.swift:241-263`

**Issue:** `enqueue(_:)` bounds `pending` by appending to the back and trimming the *front* (oldest) on
overflow:

```swift
mutating func enqueue(_ t: ActiveTransient) -> Bool {
    if head == nil { head = t; return true }
    if head == t || pending.contains(t) { return false }
    pending.append(t)
    if pending.count > maxDepth { pending.removeFirst() }   // drops the FRONT on overflow
    return false
}
```

`preempt(_:)` inserts the displaced Focus at the *front* of `pending` specifically so it is next in
line for `advance()` (which also pops from the front via `removeFirst()`), and it performs **no**
`maxDepth` check of its own:

```swift
mutating func preempt(_ t: ActiveTransient) -> Bool {
    guard case .focus = head else { return enqueue(t) }
    let displaced = head!
    head = t
    pending.insert(displaced, at: 0)   // no maxDepth trim here
    return true
}
```

This produces two related bugs, both reachable via ordinary Charging/Device flapping while Focus
stands:

1. **Bound violation:** if `pending` already holds `maxDepth` (2) entries at the moment Focus is
   promoted back to head (e.g. via a prior `advance()`), the next preempt (`pending.insert(displaced,
   at: 0)`) grows `pending` to 3, exceeding the documented "bounded... a flapping device can never back
   the queue up (T-06-01)" invariant — nothing ever trims it back down after an `insert`.
2. **Guarantee violation:** because the displaced Focus is inserted at *index 0* — the exact index
   `enqueue(_:)`'s overflow logic always evicts from (`removeFirst()`) — two subsequent distinct
   Charging/Device transients enqueuing behind the preempting one (ordinary `enqueue`, no preempt
   needed since head is no longer Focus) will silently evict the just-displaced Focus entry from
   `pending` before `advance()` ever reaches it, breaking the doc comment's explicit promise: "the
   displaced Focus is reinserted at the FRONT of `pending`... so the very next `advance()` resumes it."
   (Focus does self-heal within ~2.5s via `FocusModeMonitor`'s poll re-enqueuing it, so this is not a
   permanent loss, but the queue-ordering/bound contract this file otherwise tests exhaustively is
   violated for Focus specifically, and no test in `IslandResolverTests.swift` exercises the
   3-plus-entry interleaving.)

**Fix:** Apply the same overflow trim inside `preempt(_:)` after the insert (and treat the insert as
subject to the same bound as `enqueue`'s append), e.g.:

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

### WR-02: Granting Focus permission through the in-app flow never actually starts `FocusModeMonitor` (requires an undocumented toggle-off/toggle-on or app restart), and the Settings hint text does not live-update after granting

**File:** `Islet/SettingsView.swift:211-227, 261-282`; `Islet/Notch/NotchWindowController.swift:474, 1713`

**Issue:** The only two places `startFocusModeMonitor()` can be reached are `start()` (launch-time) and
`handleSettingsChanged()`, both fired from `UserDefaults.didChangeNotification`. The permission grant
itself does not write to `UserDefaults`:

```swift
// SettingsView.swift:273-276
Button("Continue") {
    FocusModeMonitor.requestAuthorization { _ in }   // result discarded
    showFocusPermissionExplanation = false
}
```

Typical flow for a user who has never granted Focus/DND access: flipping the toggle ON writes
`focusKey = true` to `UserDefaults`, which fires `handleSettingsChanged()` immediately — but at that
instant `FocusModeMonitor.isAuthorized` is still `false` (the OS dialog hasn't resolved yet), so the
`if activityEnabled(...) && FocusModeMonitor.isAuthorized` guard is false and the monitor is not
started. The user then taps "Continue" in the explanation popover, `requestAuthorization` completes
asynchronously — and nothing calls `startFocusModeMonitor()` or re-runs `handleSettingsChanged()`
afterward. `focusEnabled` stays `true` (matching D-04's "declining leaves the toggle ON"), so no further
`UserDefaults` write ever occurs to re-trigger the start path. The Focus Mode HUD therefore never
activates until the user manually toggles the switch off and back on again, or restarts the app —
neither of which is documented or discoverable, and this is the primary user-facing path for the
feature this phase implements.

Separately, `ActivitySettings.focusPermissionStatusHint(toggleOn:granted:)`'s result is read inline in
`generalSection`'s body (`SettingsView.swift:220-227`) with no `@State`/reactive binding to
`FocusModeMonitor.isAuthorized`. The one state mutation that happens synchronously right after
`requestAuthorization` is *called* (`showFocusPermissionExplanation = false`, fired before the async
completion returns) does trigger a re-render, but at that point authorization has not resolved yet, so
the hint still reads "Permission needed — tap to grant" even after the user successfully grants access,
until some unrelated state change (window refocus, another toggle) happens to force a re-render.

**Fix:** Thread the `requestAuthorization` completion back into the controller so a grant actually
starts the monitor, e.g. post a notification / call back into `AppDelegate`'s controller reference on
success, and mirror it into a local `@State` so the hint text re-renders immediately:

```swift
Button("Continue") {
    FocusModeMonitor.requestAuthorization { granted in
        DispatchQueue.main.async {
            if granted {
                (NSApp.delegate as? AppDelegate)?.notchController?.focusPermissionGranted()
            }
            showFocusPermissionExplanation = false
        }
    }
}
```
with a small `focusPermissionGranted()` on the controller that re-runs the same start-gate logic
`handleSettingsChanged()` already uses.

---

_Reviewed: 2026-07-17T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
