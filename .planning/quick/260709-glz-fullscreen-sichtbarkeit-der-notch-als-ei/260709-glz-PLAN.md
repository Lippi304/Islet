---
phase: quick-260709-glz
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Islet/ActivitySettings.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/SettingsView.swift
autonomous: true
requirements: []
user_setup: []

must_haves:
  truths:
    - "A toggle in Settings lets the user control whether the notch/island hides itself while another app is in true fullscreen."
    - "A fresh install (toggle never touched) behaves exactly as today: the island hides in fullscreen (no regression)."
    - "Flipping the toggle live-applies without restarting the app (same UserDefaults.didChangeNotification path every other activity toggle already uses)."
  artifacts:
    - path: "Islet/ActivitySettings.swift"
      provides: "hideInFullscreenKey — the single source-of-truth UserDefaults key string, shared by SettingsView and the controller"
      contains: "hideInFullscreenKey"
    - path: "Islet/Notch/NotchWindowController.swift"
      provides: "hideInFullscreen becomes a computed property reading the persisted preference (default true) instead of a hardcoded constant"
      contains: "hideInFullscreenKey"
    - path: "Islet/SettingsView.swift"
      provides: "Toggle row bound to the new @AppStorage key, defaulting to true"
      contains: "hideInFullscreenKey"
  key_links:
    - from: "SettingsView Toggle(\"Hide notch in fullscreen\")"
      to: "Islet/ActivitySettings.swift hideInFullscreenKey"
      via: "@AppStorage(ActivitySettings.hideInFullscreenKey)"
      pattern: "AppStorage\\(ActivitySettings\\.hideInFullscreenKey\\)"
    - from: "NotchWindowController.hideInFullscreen"
      to: "Islet/ActivitySettings.swift hideInFullscreenKey"
      via: "activityEnabled(ActivitySettings.hideInFullscreenKey) — same UserDefaults-default-true helper every other toggle uses"
      pattern: "activityEnabled\\(ActivitySettings\\.hideInFullscreenKey\\)"
---

<objective>
Make the existing fullscreen-hide behavior of the notch/island user-configurable via a
Settings toggle, instead of the current hardcoded-always-on `hideInFullscreen = true`.

This closes the seam the codebase already documents and reserves for exactly this
(`NotchWindowController.swift` line 52 comment: "Phase 6 (APP-03) will flip `let`→`var`
and wire a preferences toggle to THIS property — it is the only seam"). No new
fullscreen-detection logic is touched — `FullscreenSpaceProbe.swift` and
`FullscreenDetector.swift` keep working exactly as they do today; only the flag that
gates their result changes from a compile-time constant to a persisted, live-editable
preference.

Purpose: the user asked to be able to choose whether the island disappears in fullscreen
apps (some may want it to stay visible even in fullscreen).
Output: a new `ActivitySettings.hideInFullscreenKey`, `NotchWindowController.hideInFullscreen`
turned into a computed property reading that key (default true — matches today's
behavior for existing users, no regression), and a Toggle row in `SettingsView.swift`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@Islet/ActivitySettings.swift
@Islet/SettingsView.swift

<interfaces>
<!-- Contracts the executor needs. Extracted from the codebase — no exploration required. -->

Islet/ActivitySettings.swift — the single source-of-truth key namespace, shared verbatim
between SettingsView and NotchWindowController (per the file's own header comment):
```swift
enum ActivitySettings {
    static let chargingKey   = "activity.charging"
    static let nowPlayingKey = "activity.nowPlaying"
    static let deviceKey     = "activity.device"
    static let accentIndexKey = "accentIndex"
}
```

Islet/Notch/NotchWindowController.swift (line 49-52) — the exact seam to change, with its
own comment predicting this task:
```swift
// D-10 (ISL-05) — the SINGLE fullscreen-hide gating flag. Default true ships the hide.
// Phase 6 (APP-03) will flip `let`→`var` and wire a preferences toggle to THIS property —
// it is the only seam, so build NO preferences UI / stored-defaults read here.
private let hideInFullscreen = true
```

Islet/Notch/NotchWindowController.swift (line 352-354) — the existing default-true reader
every other activity toggle already uses; reuse it verbatim rather than inventing a new
UserDefaults read:
```swift
private func activityEnabled(_ key: String) -> Bool {
    UserDefaults.standard.object(forKey: key) as? Bool ?? true
}
```

Islet/Notch/NotchWindowController.swift (line 519-524) — the ONLY read site of
`hideInFullscreen`, inside `updateVisibility()`, called fresh (no caching) on every
visibility decision:
```swift
if shouldShow(hasTarget: target != nil,
              hideInFullscreen: hideInFullscreen,
              isFullscreen: fullscreen,
              isLicensed: licenseState.isEntitled),
```

Islet/Notch/NotchWindowController.swift (line 846-885) — `handleSettingsChanged()`, the
existing `UserDefaults.didChangeNotification` handler that ALREADY calls `updateVisibility()`
at its end (line 885) on every defaults write, for every key. This means a computed
`hideInFullscreen` needs NO new observer wiring — flipping the new toggle in Settings
posts `didChangeNotification` just like every other `@AppStorage` write, which this
existing handler already routes into a fresh `updateVisibility()` call.

Islet/SettingsView.swift (line 28-31, 81-103) — the exact `@AppStorage` + `Toggle` pattern
to mirror for the new row:
```swift
@AppStorage(ActivitySettings.deviceKey) private var deviceEnabled = true
...
Section("Activities") {
    Toggle("Charging", isOn: $chargingEnabled)
    Toggle("Now Playing", isOn: $nowPlayingEnabled)
    Toggle("Devices", isOn: $deviceEnabled)
    ...
}
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add the persisted key and turn hideInFullscreen into a read</name>
  <files>Islet/ActivitySettings.swift, Islet/Notch/NotchWindowController.swift</files>
  <action>
In `Islet/ActivitySettings.swift`, add a new key to the `enum ActivitySettings` alongside
the existing three activity keys: `static let hideInFullscreenKey = "notch.hideInFullscreen"`.
Add a one-line comment noting it is NOT an "activity" toggle (it gates fullscreen
visibility, not a live-activity source) but lives in this same enum because this file is
the shared key namespace between SettingsView and the controller.

In `Islet/Notch/NotchWindowController.swift`, replace the hardcoded constant at line 52
(`private let hideInFullscreen = true`) with a computed property that reads the new key
through the existing `activityEnabled(_:)` helper (line 352-354), which already defaults
to `true` when the key is absent — preserving today's behavior for every existing user
with zero UserDefaults migration needed:

```swift
private var hideInFullscreen: Bool {
    activityEnabled(ActivitySettings.hideInFullscreenKey)
}
```

Update the comment above it (lines 49-51) to reflect that this is now wired rather than a
pending seam — the "Phase 6 will flip let→var" note is now stale and should be replaced
with a short note that this property is read fresh (per Swift computed-property semantics)
on every `updateVisibility()` call, matching the file's existing "read fresh, no caching"
convention used for `licenseState.isEntitled` two properties below it.

Do NOT touch `FullscreenSpaceProbe.swift`, `FullscreenDetector.swift`, or the
`shouldShow(...)`/`updateVisibility()` call site itself (line 519-524) — the parameter
name and call shape stay identical; only where the value comes from changes.
  </action>
  <verify>
    <automated>xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug 2>&1 | tail -5 | grep -q "BUILD SUCCEEDED"</automated>
  </verify>
  <done>
`xcodebuild build -scheme Islet` reports BUILD SUCCEEDED. `hideInFullscreen` is a computed
`Bool` property reading `ActivitySettings.hideInFullscreenKey` via `activityEnabled(_:)`,
defaulting to `true` when unset. `updateVisibility()`'s call site is unchanged.
  </done>
</task>

<task type="auto">
  <name>Task 2: Add the Settings toggle</name>
  <files>Islet/SettingsView.swift</files>
  <action>
In `Islet/SettingsView.swift`, add a new `@AppStorage` property alongside the existing
four (line 28-31): `@AppStorage(ActivitySettings.hideInFullscreenKey) private var
hideInFullscreen = true` (default `true` in the property wrapper mirrors the controller's
default and matches this file's existing convention — see the comment at lines 23-27
explaining `@AppStorage` IS the source of truth for app-owned preferences).

Add a `Toggle("Hide notch in fullscreen", isOn: $hideInFullscreen)` row. Place it in its
own new `Section("Fullscreen")` (do not add it inside the existing "Activities" section —
this is not a live-activity on/off switch like Charging/Now Playing/Devices, it is a
fullscreen-visibility preference, a distinct concern), positioned after the "Activities"
section and before the "Diagnostics" section in the `Form`.
  </action>
  <verify>
    <automated>xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug 2>&1 | tail -5 | grep -q "BUILD SUCCEEDED"</automated>
  </verify>
  <done>
`xcodebuild build -scheme Islet` reports BUILD SUCCEEDED. The Settings window shows a
"Fullscreen" section with a "Hide notch in fullscreen" toggle, defaulting to on. Flipping
it off and putting another app into true fullscreen keeps the island visible; flipping it
back on hides it again — verified manually since `xcodebuild test` hangs headless in this
project (see project memory: xcodebuild-test-headless-hang) and there is no existing
automated fullscreen-integration test harness to extend for this UI-only wiring change.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Settings UI → UserDefaults | User-controlled toggle write, local-only, no untrusted input crosses a process/network boundary |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-glz-01 | Tampering | UserDefaults `notch.hideInFullscreen` key | accept | Same trust model as the three existing activity keys — local plist, no PII, user's own machine; a corrupted/tampered value simply falls back to `true` (hide) via `activityEnabled`'s `?? true`, never crashes or exposes data |
</threat_model>

<verification>
- Build gate: `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` → BUILD SUCCEEDED after each task (`test` is not used here per project memory: xcodebuild-test-headless-hang).
- Manual: open Settings, confirm the new "Fullscreen" section and toggle appear, default ON. Put another app into true fullscreen with the toggle ON — island hides (unchanged from today). Turn the toggle OFF, re-enter fullscreen (or trigger `updateVisibility()` by any other toggle flip while already fullscreen) — island stays visible. Turn it back ON — island hides again.
</verification>

<success_criteria>
- `ActivitySettings.hideInFullscreenKey` exists as the single shared key string.
- `NotchWindowController.hideInFullscreen` reads that key via the existing `activityEnabled(_:)` helper, defaulting to `true`.
- A fresh install (key never written) hides in fullscreen exactly as before — no regression.
- SettingsView shows a "Fullscreen" section with a working, live-applying "Hide notch in fullscreen" toggle.
- `FullscreenSpaceProbe.swift` and `FullscreenDetector.swift` are untouched.
</success_criteria>

<output>
Create `.planning/quick/260709-glz-fullscreen-sichtbarkeit-der-notch-als-ei/260709-glz-SUMMARY.md` when done.
</output>
