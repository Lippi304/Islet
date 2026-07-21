---
phase: 54-permissions-overview-onboarding-replay-settings-rollup-showi
reviewed: 2026-07-22T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - Islet/PermissionStatus.swift
  - IsletTests/PermissionStatusTests.swift
  - Islet/Notch/OnboardingViewState.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/SettingsView.swift
  - IsletTests/SettingsViewTests.swift
findings:
  critical: 3
  warning: 3
  info: 1
  total: 7
status: issues_found
---

# Phase 54: Code Review Report

**Reviewed:** 2026-07-22T00:00:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

`PermissionStatus.swift` and its tests are solid: the pure mapping functions are total, well-named, and thoroughly covered (`PermissionStatusTests.swift`). `OnboardingViewState.swift` is a trivial, correctly-scoped published-state carrier. `SettingsViewTests.swift` correctly locks the new `.permissions` sidebar-filter behavior.

The problems are in how the new Settings "Permissions" rollup (`SettingsView.swift`) wires its Grant actions into `NotchWindowController.swift`'s real permission-consuming code paths, and in the new mid-session onboarding replay entry point. Three of the five permission rows use inconsistent grant-wiring compared to the existing (pre-Phase-54) onboarding carousel's equivalent grant actions: Bluetooth over-fires (bypasses the "Devices" toggle and starts a live monitor the user explicitly turned off), Location under-fires (never reaches the app's real one-shot location fetch, so a grant has no effect for the rest of the session), and Focus discards its authorization result (so an already-enabled toggle doesn't actually start polling until manually re-toggled). Separately, the new `replayOnboarding()` entry point is missing the `updateVisibility()` call every sibling onboarding-lifecycle method (`finishOnboarding()`, `finishOnboardingReplay()`) makes, so triggering a replay while the panel is currently hidden (fullscreen, or an expired-trial lockout) shows nothing.

## Critical Issues

### CR-01: Settings "Bluetooth" permission tap starts the monitor even when the "Devices" activity toggle is off

**File:** `Islet/SettingsView.swift:526-527`
**Issue:** `handlePermissionTap(kind: .bluetooth, status: .notYetAsked)` calls `notchController?.requestBluetoothPermission()`, which unconditionally calls `startBluetoothMonitor()` (`Islet/Notch/NotchWindowController.swift:748-750`, `705-713`). Every other start site for this monitor (`start()` line 556, `handleSettingsChanged()` lines 2309-2315) gates it on `activityEnabled(ActivitySettings.deviceKey)` and the file's own documented D-09 "prefer stop" discipline. `requestBluetoothPermission()` has no such gate, so a user who has explicitly switched "Devices" OFF in Activities but taps "Bluetooth" in the new Permissions section will silently start live Bluetooth connect/disconnect monitoring (and its device-splash transients) for the rest of the session, directly contradicting their own toggle setting. Nothing turns it back off again except manually toggling "Devices" on then off, or relaunching the app.
**Fix:** Gate the call, mirroring every other start site:
```swift
func requestBluetoothPermission() {
    guard activityEnabled(ActivitySettings.deviceKey) else { return }
    startBluetoothMonitor()
}
```
(or, if the intent is "always trigger the OS prompt regardless of the toggle," start the monitor only to trigger the TCC prompt and then immediately `stop()`/release it again when the toggle is off, instead of leaving it running.)

### CR-02: Settings "Location" permission tap never reaches the app's real location fetch — granting has no effect for the rest of the session

**File:** `Islet/SettingsView.swift:519-522`
**Issue:** `handlePermissionTap(kind: .location, status: .notYetAsked)` only calls a throwaway `CLLocationManager().requestWhenInUseAuthorization()` — a fresh, disconnected manager instance that shows the OS prompt but is never connected to the app's actual weather pipeline. The app's real fetch, `startLocationOnce()` (`Islet/Notch/NotchWindowController.swift:803-819`), is a genuine one-shot per its own D-01 contract ("never re-request here") and is only invoked from `startOutfitRefresh()` at launch (line 823) and from the onboarding carousel's `grantOnboardingPermission(.location)` (line 1916) — never from `SettingsView`. If location wasn't granted at launch, granting it later via this new Permissions row leaves `outfitState.location`/weather permanently unpopulated until the app is relaunched, because the one-shot request already fired (and failed) at launch and nothing here re-triggers it.
**Fix:** Add a bridge method mirroring `requestBluetoothPermission()`/`focusPermissionGranted()` and call the real fetch:
```swift
// NotchWindowController.swift
func requestLocationPermission() {
    startLocationOnce()
}
```
```swift
// SettingsView.swift
case .location:
    (NSApp.delegate as? AppDelegate)?.notchController?.requestLocationPermission()
```

### CR-03: `replayOnboarding()` never calls `updateVisibility()` — replay can be a silent no-op when the panel is currently hidden

**File:** `Islet/Notch/NotchWindowController.swift:1951-1965`
**Issue:** `replayOnboarding()` mutates `onboardingStep`/`isOnboardingActive`/`interaction.phase` and calls `renderPresentation()` + `syncClickThrough()`, but — unlike its own counterpart `finishOnboardingReplay()` (line 1983) and the original `finishOnboarding()` (line 1940) — it never calls `updateVisibility()`, which is documented elsewhere in this same file as "the ONE visibility decision and the SOLE show/hide site" (line 955-959). If the panel is currently hidden when the user clicks "Replay Onboarding" in Settings — e.g. another app is in fullscreen with `hideInFullscreen` on, or the trial has expired and the pointer isn't currently hovering the (now-invisible) hot-zone — `panel?.orderOut(nil)` was the last state applied to the real NSPanel, and nothing in this function brings it back on-screen. The onboarding state is fully set and `presentationState.presentation` is updated, but the window itself stays off-screen, so the user sees nothing happen.
**Fix:**
```swift
func replayOnboarding() {
    guard onboardingStep == nil else { return }
    replayPriorPhase = interaction.phase
    onboardingStep = .welcome
    isOnboardingActive = true
    onboardingState.isReplay = true
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        interaction.phase = .expanded
        renderPresentation()
    }
    updateVisibility()
    syncClickThrough()
}
```

## Warnings

### WR-01: Settings "Focus" permission tap discards the grant result — an already-enabled toggle doesn't start polling until manually re-toggled

**File:** `Islet/SettingsView.swift:528-529`
**Issue:** `handlePermissionTap(kind: .focus, status: .notYetAsked)` calls `FocusModeMonitor.requestAuthorization { _ in }`, discarding the outcome. Compare to the existing (pre-Phase-54) `focusPermissionExplanationView`'s "Continue" button (`SettingsView.swift:577-586`), which on `granted == true` calls `notchController?.focusPermissionGranted()` to actually start the monitor. If a user already has "Focus Mode HUD" toggled ON in Activities (but permission wasn't granted yet, so the monitor never started — see the `activityEnabled(focusKey) && FocusModeMonitor.isAuthorized` gate at `NotchWindowController.swift:561`/`2320`) and grants the permission via this new Permissions row instead of the existing popover, the toggle stays on but the monitor never starts — the user has no indication anything is wrong and must retoggle Focus off/on (or relaunch) to get it running.
**Fix:**
```swift
case .focus:
    FocusModeMonitor.requestAuthorization { granted in
        DispatchQueue.main.async {
            if granted {
                (NSApp.delegate as? AppDelegate)?.notchController?.focusPermissionGranted()
            }
        }
    }
```

### WR-02: `handlePermissionTap` calls `refreshPermissionStatuses()` before any of the async grant requests can possibly have resolved

**File:** `Islet/SettingsView.swift:512-535`
**Issue:** For `.location`, `.calendarReminders`, `.bluetooth`, and `.focus`, the grant action is asynchronous (a `CLLocationManager` callback, `Task { await ... }`, an async framework callback, or an OS-prompt round trip) but `refreshPermissionStatuses()` runs synchronously immediately afterward, before the OS has resolved anything. The call is not incorrect (it's harmless), but it cannot do what its placement implies — the actual UI refresh only happens later, incidentally, via `.onChange(of: appearsActive)` when the modal system prompt steals and returns focus. This makes the code read as "refresh after granting" when it functionally isn't, which will mislead future maintainers.
**Fix:** Either move the call to only the `.denied` case (where it's genuinely a no-op reflecting "nothing changed"), or add a short comment clarifying that the real refresh happens via the refocus-triggered `.onChange(of: appearsActive)` path, not this call.

### WR-03: Settings "Calendar" permission tap uses a disconnected `EKEventStore`, inconsistent with the onboarding grant path

**File:** `Islet/SettingsView.swift:523-525`
**Issue:** `handlePermissionTap(kind: .calendarReminders, status: .notYetAsked)` fires two `Task { EKEventStore().requestFullAccessTo... }` blocks against fresh, throwaway `EKEventStore` instances, instead of calling the app's real `refreshCalendar()` the way the onboarding carousel's `grantOnboardingPermission(.calendar)` does (`NotchWindowController.swift:1913-1914`). Unlike Location, this self-heals because `outfitRefreshTimer` recurs every 15 minutes while the panel is visible (`NotchWindowController.swift:825-831`), but until that next tick (or if the panel stays hidden) the just-granted permission has no visible effect and the pattern is inconsistent with the analogous onboarding code path just a few hundred lines away in the same codebase.
**Fix:** Add a bridge call mirroring CR-02's suggested fix, e.g. `notchController?.requestCalendarPermission()` → `refreshCalendar()`.

## Info

### IN-01: Force-unwrapped `URL(string:)` for the deep-link anchor

**File:** `Islet/SettingsView.swift:517-518`
**Issue:** `URL(string: "x-apple.systempreferences:...\(kind.deepLinkAnchor)")!` force-unwraps. Currently safe because `PermissionKind.deepLinkAnchor` is a closed set of hardcoded, URL-safe literals (`PermissionStatus.swift:33-43`), but the force-unwrap gives no defense if a future `PermissionKind` case's anchor ever needs percent-encoding (e.g. contains a space) — it would crash instead of failing gracefully.
**Fix:** `guard let url = URL(string: ...) else { return }` instead of `!`.

---

_Reviewed: 2026-07-22T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
