---
status: resolved
trigger: "battery-indicator-accent-not-tinted: charging battery indicator ignored accent swatch, confirmed on-device (06-UAT.md Test 4)"
created: 2026-07-01T00:00:00Z
updated: 2026-07-02T04:39:00Z
---

# Debug: battery-indicator-accent-not-tinted

## Resolution

Fixed in plan 06-06: charging wing's `BatteryIndicator` call site now forwards `accent: accent` (`Islet/Notch/NotchPillView.swift:228`). The device wing's `BatteryIndicator` (line 296) deliberately stays untinted per PROJECT.md's Key Decisions — "device battery's fixed green/amber/red is an intentional design decision, not a bug" — confirmed by the user during the 06-04 checkpoint.

## Symptom
Picking a different accent swatch in Settings correctly re-tints the Now-Playing
equalizer bars, but the charging battery indicator's fill color never changes —
it stays green (or amber/red at low levels) regardless of the chosen accent.

## Status: ROOT CAUSE FOUND (diagnosis only — no fix applied)

## Root cause

`BatteryIndicator` (`Islet/Notch/BatteryIndicator.swift:16-26`) DOES support an
accent parameter:

```swift
struct BatteryIndicator: View {
    let level: Int
    var accent: Color = .green          // <- defaults to hardcoded green

    private var fillColor: Color {
        if clamped <= 10 { return .red }
        if clamped <= 20 { return .orange }
        return accent                    // only reached above 20% — and only if `accent` was passed in
    }
```

The environment plumbing itself is intact and correct:
- `ActivitySettings.swift:38-44` defines `\.activityAccent` (default `.white`).
- `NotchWindowController.swift:733-744` (`makeRootView`) applies
  `.environment(\.activityAccent, ActivitySettings.accent(for: accentIndex))`
  directly on the `NotchPillView` root, so every leaf inside `NotchPillView`
  receives it.
- `NotchPillView.swift:60` reads it into a local `@Environment(\.activityAccent)
  private var accent`.
- `NotchPillView.swift:241` (media wings) correctly forwards it:
  `EqualizerBars(isPlaying: isPlaying, tint: accent)` — this is why the
  equalizer bars pick up the new color.

**The break is at the two `BatteryIndicator(...)` call sites in
`NotchPillView.swift` — neither one forwards the local `accent` into the
component's `accent:` parameter:**

1. **Charging wings** (`NotchPillView.swift:216`, inside `wings(for
   activity:)`):
   ```swift
   BatteryIndicator(level: percent)   // no `accent:` argument — falls back to the struct default `.green`
   ```
   This is the one the UAT (Test 4, `06-UAT.md`) flags as broken — nothing in
   the surrounding code documents an intentional reason to keep this one
   untinted, unlike the device case below. This reads as a plain oversight:
   `accent: accent` was never added when `BatteryIndicator` was wired in
   post-checkpoint (06-04, after the accent-injection work landed in 06-03).

2. **Device wings** (`NotchPillView.swift:295`, inside `deviceTrailing`):
   ```swift
   BatteryIndicator(level: battery)   // also no `accent:` argument
   ```
   This one is *documented as intentional* in the comment directly above it
   (`NotchPillView.swift:288-291`): "Battery is rendered GREEN … regardless of
   the accent — a battery reads as a battery; the accent still tints the
   device GLYPH on the left." The device glyph a few lines up (`line 278`,
   `.foregroundStyle(accent.opacity(iconOpacity))`) does pick up the accent,
   matching that stated design.

## Why "equalizer bars pass, battery doesn't" (matches reported symptom exactly)

- `EqualizerBars` receives `tint: accent` explicitly → tinted. ✅
- `BatteryIndicator` receives no `accent:` argument at either call site →
  always uses its own default (`.green`, or `.orange`/`.red` under the
  low-battery thresholds) → never tinted. ❌

## Ruled out
- Environment injection point (`NotchWindowController.makeRootView`) does
  cover the call site — it's applied on `NotchPillView` itself, which is the
  parent of both `wings(for:)` and `deviceTrailing`. Not a scope/coverage bug.
- `BatteryIndicator` is not fully hardcoded/tint-ignoring — it has a working
  `accent` parameter and uses it in `fillColor` when level > 20%. The
  component itself is capable of tinting; it's just never given the value.

## Scope note for the eventual fix
- The **charging** battery indicator (`NotchPillView.swift:216`) appears to be
  the one actually expected to tint per the symptom's "expected" behavior
  ("the charging battery glyph … pick up the new color") — missing
  `accent: accent`.
- The **device** battery indicator (`NotchPillView.swift:295`) has an explicit
  design comment saying it should stay green/amber/red regardless of accent —
  any fix should confirm with the user/PROJECT decisions (D-11 or similar)
  whether that documented intent still holds, since the symptom report only
  mentions "the charging battery indicator," not the device one.

## Files involved
- `Islet/Notch/BatteryIndicator.swift` — component with unused `accent:` param (lines 16-26)
- `Islet/Notch/NotchPillView.swift` — call sites missing `accent: accent` (lines 216, 295); correct forwarding example at line 241; environment read at line 60
- `Islet/Notch/NotchWindowController.swift` — correct injection point (lines 733-744)
- `Islet/ActivitySettings.swift` — `\.activityAccent` EnvironmentKey definition (lines 33-44)
- `.planning/phases/06-priority-resolver-settings-v1-ship/06-04-SUMMARY.md` — confirms `BatteryIndicator` was added post-checkpoint (06-04), after the accent-injection work (06-03), supporting the "simply missed" theory for the charging call site
