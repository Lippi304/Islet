---
type: quick
quick_id: 260708-nnu
files_modified: [Islet/Notch/NotchPillView.swift]
autonomous: true
requirements: []
---

<objective>
Slow down the weather icon animation in the notch pill so it no longer blinks/pulses too fast and too strongly.

Purpose: User feedback (verbatim German): "Was mich gerade noch stört ist das diese Wolken Symbol viel zu sehr bzw schnell blinkt" — the cloud/weather icon animates too fast/intensely.
Output: Same visual effect (pulse for sunny, variableColor.iterative for cloudy/rain/snow) but running at reduced speed via `SymbolEffectOptions.speed(_:)`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@Islet/Notch/NotchPillView.swift

<interfaces>
Current code (Islet/Notch/NotchPillView.swift, lines 369-388), `weatherIcon(for:)`:

```swift
@ViewBuilder
private func weatherIcon(for category: WeatherCategory) -> some View {
    switch category {
    case .sunny:
        Image(systemName: "sun.max.fill")
            .symbolRenderingMode(.multicolor)
            .symbolEffect(.pulse, options: .repeating, isActive: true)
    case .cloudy:
        Image(systemName: "cloud.fill")
            .symbolRenderingMode(.multicolor)
            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: true)
    case .rain:
        Image(systemName: "cloud.rain.fill")
            .symbolRenderingMode(.multicolor)
            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: true)
    case .snow:
        Image(systemName: "cloud.snow.fill")
            .symbolRenderingMode(.multicolor)
            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: true)
    }
}
```

`SymbolEffectOptions` (SF Symbols framework, ships with SwiftUI on macOS 14+) has a chainable
`.speed(_ speed: Double)` method. `.repeating` alone runs at the default speed (1.0). Chaining
`.repeating.speed(0.4)` keeps the same continuous-repeat behavior but plays it back at 40% speed
— slower cadence, same effect type, no new imports or state needed.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Reduce weather icon animation speed</name>
  <files>Islet/Notch/NotchPillView.swift</files>
  <action>
  In `weatherIcon(for:)` (around lines 369-388), change all four `options: .repeating` arguments
  to `options: .repeating.speed(0.4)` — for `.sunny` (`.pulse`), and for `.cloudy`, `.rain`,
  `.snow` (`.variableColor.iterative`). This slows the perceived blink/pulse rate without
  changing the effect type, `isActive` gating, or any other view logic. Do not touch the
  idle-CPU discipline noted in the comment above the function (the view still only exists while
  `presentation == .expandedIdle`) — this is a pure speed tweak, no new state.
  </action>
  <verify>
    <automated>xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build 2>&1 | tail -20</automated>
  </verify>
  <done>Build succeeds; all four `symbolEffect(...)` calls in `weatherIcon(for:)` use `options: .repeating.speed(0.4)`.</done>
</task>

</tasks>

<verification>
Build succeeds. Manual check (Xcode GUI, not terminal — build machine has no live notch weather state to script): run Islet.app, trigger the weather glance in the expanded-idle notch state, confirm the cloud/sun icon animates noticeably slower/calmer than before.
</verification>

<success_criteria>
Weather icon in the notch pill animates at a visibly reduced speed; no new files, no new state, no regression to idle-CPU gating (animation still only runs while `presentation == .expandedIdle`).
</success_criteria>

<output>
Create `.planning/quick/260708-nnu-das-wetter-icon-wolken-symbol-im-notch-b/260708-nnu-SUMMARY.md` when done
</output>
