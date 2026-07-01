---
phase: 06-priority-resolver-settings-v1-ship
reviewed: 2026-07-02T01:12:00Z
depth: standard
files_reviewed: 16
files_reviewed_list:
  - Islet.xcodeproj/project.pbxproj
  - Islet/ActivitySettings.swift
  - Islet/AppDelegate.swift
  - Islet/Notch/BatteryIndicator.swift
  - Islet/Notch/BluetoothMonitor.swift
  - Islet/Notch/DeviceActivity.swift
  - Islet/Notch/IslandPresentationState.swift
  - Islet/Notch/IslandResolver.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/Notch/NowPlayingMonitor.swift
  - Islet/Notch/NowPlayingPresentation.swift
  - Islet/SettingsView.swift
  - IsletTests/DeviceActivityTests.swift
  - IsletTests/IslandResolverTests.swift
  - IsletTests/NowPlayingPresentationTests.swift
  - scripts/release.sh
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-07-02T01:12:00Z
**Depth:** standard
**Files Reviewed:** 16
**Status:** issues_found

## Summary

This is a fresh, full-scope standard-depth review of the complete file list supplied for this
phase (superseding the narrower 06-07..06-12-diff-only review previously written to this path).
It covers the pure `IslandResolver`/`TransientQueue` seam, `DeviceActivity`/`BluetoothMonitor`, the
`NotchWindowController` orchestration (toggle-gated monitor lifecycle, transient queue wiring,
device battery-poll gap-closure fixes), `NotchPillView`, `SettingsView`/`ActivitySettings`, the
three pure-seam test files, the Xcode project file, and `scripts/release.sh`.

Verified: the previously-reported gap-closure defects (the FIFO/identity battery-poll desync and
the always-reset dismiss timer on `flushTransients`) are present and correctly fixed in the current
code (`matchPendingBatteryPoll` / `PendingBatteryPoll` matching by `DeviceActivity` identity, and
`flushTransients`'s `oldHead != transientQueue.head` guard) — no regression found there.

No Critical/security issues were found: no injection, no hardcoded secrets, no force-unwraps or
obvious crash paths, `release.sh` handles the placeholder/notarize branches safely, and the
project file's target-membership wiring for every new source/test file checks out. The pure seams
(`IslandResolver.swift`, `DeviceActivity.swift`, `NowPlayingPresentation.swift`) are well-tested and
internally consistent with their test suites.

The issues found below are concentrated in `NotchWindowController.swift`'s live-state plumbing (an
animation-consistency gap in the health-check callback, a full view-tree rehost on accent change
that undermines the `matchedGeometryEffect` morph it's built around, a documented-but-theoretical
Bluetooth token data race) and a genuine visual inconsistency in `NotchPillView.swift` where the
charging/device wings tint the opposite element from what the code's own D-11 design comment says
should be tinted. Several smaller dead-parameter / magic-number / asymmetric-cleanup findings round
out the list.

## Warnings

### WR-01: Charging/device wings tint the wrong element relative to the documented D-11 spec

**File:** `Islet/Notch/NotchPillView.swift:223-229` (charging wing) and `Islet/Notch/NotchPillView.swift:275-302` (device wing)

**Issue:** `ActivitySettings.swift` and `NotchPillView.swift`'s own header comment both state the
D-11 invariant: the persisted accent tints exactly **three lively leaf elements** — "charging
filling glyph, equalizer bars, device icon" — and nothing else. The implementation does the
opposite of that for the two battery-adjacent glances:

- In `wings(for:)` (charging), the **glyph** (`bolt.fill`) is hardcoded to
  `isCharging ? Color.green : Color.white.opacity(0.6)` — it does **not** use `accent` at all,
  even though "charging filling glyph" is explicitly one of the three elements the accent is
  supposed to tint. Meanwhile the charging wing's `BatteryIndicator(level: percent, accent: accent)`
  *does* receive the accent — an element the spec never lists.
- In `deviceWings(for:)` / `deviceTrailing(...)`, the **device glyph** correctly receives
  `accent.opacity(iconOpacity)` (matches the spec), but its `BatteryIndicator(level: battery)` is
  called with no `accent` argument (defaults to `.green`), which is explicitly called out in a
  comment as intentional ("Battery is rendered GREEN … regardless of the accent").

So the two wings are inconsistent with each other and with the documented spec: charging tints its
battery bar but not its glyph; device tints its glyph but not its battery bar. A user who picks a
non-default accent (e.g. purple) will see the charging wing's percentage bar turn purple while the
bolt glyph stays green/white — the opposite of the "device icon" precedent set two paragraphs
below it in the same file.

**Fix:** Make the charging glyph accent-driven like the device glyph, and drop the accent from the
charging `BatteryIndicator` call to match the device wing's (documented) precedent:
```swift
Image(systemName: "bolt.fill")
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(isCharging ? accent : Color.white.opacity(0.6))   // was: Color.green
    .padding(.leading, 12)
Spacer()
BatteryIndicator(level: percent)   // was: BatteryIndicator(level: percent, accent: accent)
    .padding(.trailing, 14)
```

---

### WR-02: Live accent change re-hosts the entire SwiftUI view tree instead of updating in place

**File:** `Islet/Notch/NotchWindowController.swift:922-929` (`applyAccentIfChanged`), also `:471-480`

**Issue:** Every other live-state mutation in this controller (charging/device/now-playing
transients, expand/collapse) updates an existing `@Published` model that the already-hosted
`NotchPillView` observes, so SwiftUI animates the change in place via the shared
`matchedGeometryEffect` namespace. Accent changes instead do this:
```swift
if let panel { panel.contentView = NSHostingView(rootView: makeRootView(accentIndex: index)) }
```
This discards the existing `NSHostingView` and constructs a **brand-new** `NotchPillView` (with a
brand-new `@Namespace private var ns`, and brand-new `EqualizerBars` — whose per-bar random
`profiles` are generated once at `init` and would reshuffle). If the user changes the accent swatch
while a splash is standing, mid-morph, or while expanded, the entire island will visibly
flash/reset instead of live-updating, and the `matchedGeometryEffect` continuity the rest of the
file is carefully built around is broken exactly at this one mutation site.

**Fix:** Thread the accent through a small `@Published`/`ObservableObject` holder (mirroring
`IslandPresentationState`) that `NotchPillView` observes via `@ObservedObject`, instead of an
`EnvironmentValue` fixed at hosting time; update that holder's value in `applyAccentIfChanged()`
instead of rebuilding `NSHostingView`.

---

### WR-03: Health-check-driven presentation update is not wrapped in `withAnimation`

**File:** `Islet/Notch/NotchWindowController.swift:331-343`

**Issue:** In `startNowPlayingMonitor()`, the `runHealthCheck` completion does:
```swift
guard healthy || !self.nowPlayingState.isHealthy else { return }
self.nowPlayingState.isHealthy = healthy   // D-12
self.renderPresentation()
```
Every other call site that mutates `nowPlayingState`/`transientQueue`/`interaction` and then calls
`renderPresentation()` (`handleNowPlaying`, `handleAdapterTerminated`, `scheduleActivityDismiss`,
`handleClick`, `handleHoverExit`'s grace branch, `handleSettingsChanged`) wraps the mutation in
`withAnimation(.spring(response:dampingFraction:))`. This one does not. If the island happens to be
expanded when the launch health probe settles (flipping between the "nicht verfügbar" state and
normal media), the transition will snap instantly instead of springing like every other transition
in the app — an inconsistent, jarring one-off.

**Fix:**
```swift
guard healthy || !self.nowPlayingState.isHealthy else { return }
withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
    self.nowPlayingState.isHealthy = healthy   // D-12
    self.renderPresentation()
}
```

---

### WR-04: `BluetoothMonitor` token dictionaries can be mutated from two threads without synchronization

**File:** `Islet/Notch/BluetoothMonitor.swift:40-45, 150-156`

**Issue:** `connectToken`, `disconnectTokens`, and `running` are declared
`nonisolated(unsafe)` and are written only inside `DispatchQueue.main.async` blocks scheduled from
the (off-main) IOBluetooth callbacks. `stop()` is `nonisolated` and is called from
`NotchWindowController`'s `deinit` (itself `nonisolated` because the class is `@MainActor`). Swift
does **not** guarantee that a class's `deinit` runs on any particular thread/queue — it runs on
whichever thread drops the last strong reference. If `deinit` happens to run on a background thread
at the exact moment a previously-scheduled `connected(_:device:)`/`disconnected(_:device:)`
`DispatchQueue.main.async` closure is executing on main, `disconnectTokens` (a `Dictionary`, not
thread-safe for concurrent mutation) can be read/written from two threads at once — undefined
behavior, up to and including a corrupted dictionary or a double-unregister of an
`IOBluetoothUserNotification` token. The in-file comment acknowledges the pattern is "mirrored"
from `PowerSourceMonitor`, so this is a pre-existing project-wide pattern rather than something
newly introduced here, but it is a real (if low-probability, exercised mainly at app-quit) data
race worth closing rather than carrying forward into new monitors.

**Fix:** Either hop `stop()`'s body onto main explicitly (`DispatchQueue.main.async { ... }` inside
`stop()`, accepting the token teardown may complete after `deinit` returns) or protect the token
state with an `NSLock`/serial queue shared between the callback closures and `stop()`.

## Info

### IN-01: `deviceSuppressedAtLaunch` is dead state — always empty, never populated

**File:** `Islet/Notch/NotchWindowController.swift:81, 738-744`

**Issue:** `private var deviceSuppressedAtLaunch: Set<String> = []` is declared and threaded into
every `shouldShowDeviceSplash(...)` call as the `suppressedAtLaunch:` argument, but nothing in the
file ever inserts into it — confirmed by search, it is permanently empty. The actual at-launch
burst suppression is implemented separately (and correctly) via `bluetoothStartedAt` /
`deviceLaunchGrace` a few lines above. The header comment acknowledges this is "left empty for v1"
as a deferred carry-over, but as shipped it is dead weight: a reader has to trace both mechanisms
to realize only one of them is live.

**Fix:** Either remove `deviceSuppressedAtLaunch` (and the corresponding pure-function parameter
support, or leave the pure function's parameter for future use but stop threading an always-empty
set through it) until it is actually wired from `IOBluetoothDevice.pairedDevices()`, or seed it at
`startBluetoothMonitor()` time and drop the separate `bluetoothStartedAt`/`deviceLaunchGrace`
mechanism so there is a single suppression path instead of two.

### IN-02: Magic-number duplication for queue/debounce bounds

**File:** `Islet/Notch/NotchWindowController.swift:82, 167, 765`

**Issue:** `pendingDeviceBatteryPolls` is capped with a hardcoded literal
(`if pendingDeviceBatteryPolls.count > 2 { pendingDeviceBatteryPolls.removeFirst() }`) that is
meant to mirror `TransientQueue.maxDepth` (also `2`), and `deviceDebounce: TimeInterval = 3.0` is a
separate literal meant to mirror `activityDuration: TimeInterval = 3.0`. Both relationships are
called out only in comments ("capped at 2 to mirror TransientQueue.maxDepth", "mirror
activityDuration"). If either source value changes later, these dependent literals will silently
drift out of sync.

**Fix:** Reference the source of truth directly, e.g.
`if pendingDeviceBatteryPolls.count > transientQueue.maxDepth { pendingDeviceBatteryPolls.removeFirst() }`,
and/or derive `deviceDebounce` from `activityDuration`.

### IN-03: Disabling "Devices" doesn't cancel the in-flight battery-poll work item

**File:** `Islet/Notch/NotchWindowController.swift:853-860` vs. `:791-819`

**Issue:** `handleSettingsChanged()` explicitly cancels `mediaDismissWorkItem` when Now Playing is
disabled, and resets `lastActivity`/`didSeedInitialPower` when Charging is disabled, but the
Devices-disable branch does not cancel `deviceBatteryWork` or reset `pollingAddress`. This is
harmless only because `scheduleDeviceBatteryRefresh`'s work-item body separately guards on
`transientQueue.head` still being the matching connected device (which `flushTransients(.device)`
will have already cleared) — so it happens to no-op safely today, but it's inconsistent cleanup
discipline compared to the other two toggles and leaves a scheduled `DispatchWorkItem` dangling
until it fires and self-aborts.

**Fix:** Add `deviceBatteryWork?.cancel(); pollingAddress = nil` alongside the other Devices-disable
cleanup in `handleSettingsChanged()`, mirroring the Now Playing branch's `mediaDismissWorkItem?.cancel()`.

---

_Reviewed: 2026-07-02T01:12:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
