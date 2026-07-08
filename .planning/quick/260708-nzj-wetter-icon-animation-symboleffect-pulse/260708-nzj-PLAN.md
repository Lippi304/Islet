---
quick_id: 260708-nzj
type: execute
files_modified: [Islet/Notch/NotchPillView.swift]
autonomous: true
must_haves:
  truths:
    - "Weather icon in the expanded island glance renders as a plain static SF Symbol — no pulse/variableColor animation, no motion at all"
  artifacts:
    - path: "Islet/Notch/NotchPillView.swift"
      provides: "weatherIcon(for:) with no .symbolEffect(...) calls on any of the four WeatherCategory cases"
  key_links: []
---

<objective>
Remove the `.symbolEffect(...)` animation modifier from all four cases of `weatherIcon(for:)` in `NotchPillView.swift`, per user feedback (verbatim, German): "Lass diese blink animation raus einfach nur das icon stehen lassen" — the icon must render statically, no animation whatsoever.

This supersedes the earlier quick task (260708-nnu, commit e8f195c) that only slowed the animation to `.speed(0.4)`. That speed tweak is being fully replaced, not adjusted further.

Purpose: match the user's explicit "no animation" preference for the weather glyph in the expanded 3-column glance (Phase 14 / D-06).
Output: `weatherIcon(for:)` renders `sun.max.fill` / `cloud.fill` / `cloud.rain.fill` / `cloud.snow.fill` with `.symbolRenderingMode(.multicolor)` only — no `.symbolEffect` anywhere in the function.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

Current code (Islet/Notch/NotchPillView.swift, lines 361-388) — the function to modify:

```swift
    // Phase 14 / D-06 — the ONLY animation in this glance (D-05). Each case gets its OWN
    // concrete Image + symbolEffect chain: `.pulse` and `.variableColor.iterative` are
    // different concrete SymbolEffect types and cannot share one call site.
    // `options: .repeating` is REQUIRED on every case — the default symbolEffect behavior is
    // one-shot per value change, not continuous (RESEARCH.md Pitfall 2). Idle-CPU discipline
    // is by construction: this view (and its symbolEffect driver) only exists while
    // `presentation == .expandedIdle`, one case of the switch in `body`.
    @ViewBuilder
    private func weatherIcon(for category: WeatherCategory) -> some View {
        switch category {
        case .sunny:
            Image(systemName: "sun.max.fill")
                .symbolRenderingMode(.multicolor)
                .symbolEffect(.pulse, options: .repeating.speed(0.4), isActive: true)
        case .cloudy:
            Image(systemName: "cloud.fill")
                .symbolRenderingMode(.multicolor)
                .symbolEffect(.variableColor.iterative, options: .repeating.speed(0.4), isActive: true)
        case .rain:
            Image(systemName: "cloud.rain.fill")
                .symbolRenderingMode(.multicolor)
                .symbolEffect(.variableColor.iterative, options: .repeating.speed(0.4), isActive: true)
        case .snow:
            Image(systemName: "cloud.snow.fill")
                .symbolRenderingMode(.multicolor)
                .symbolEffect(.variableColor.iterative, options: .repeating.speed(0.4), isActive: true)
        }
    }
```
</context>

<tasks>

<task type="auto">
  <name>Task 1: Remove weather-icon symbolEffect animation entirely</name>
  <files>Islet/Notch/NotchPillView.swift</files>
  <action>
  In `weatherIcon(for:)`, delete the `.symbolEffect(...)` line from all four cases (`.sunny`, `.cloudy`, `.rain`, `.snow`), leaving only `Image(systemName:)` + `.symbolRenderingMode(.multicolor)` per case. Do not touch `symbolRenderingMode` or the SF Symbol names — only the `.symbolEffect(...)` modifier line goes.

  Also update the doc comment directly above the function (currently starting "Phase 14 / D-06 — the ONLY animation in this glance (D-05)...") to reflect that the icon is now fully static per user request — no `.symbolEffect`, no animation. Keep it short; don't rewrite the whole function's surrounding comments beyond this one block, and don't touch any other part of the file (EqualizerBars, ProgressBar, etc. keep their existing animations — this removal is scoped to the weather icon only).
  </action>
  <verify>
    <automated>grep -c "symbolEffect" Islet/Notch/NotchPillView.swift | grep -qx 0 && echo OK</automated>
  </verify>
  <done>`weatherIcon(for:)` has zero `.symbolEffect(...)` calls across all four cases; `.symbolRenderingMode(.multicolor)` remains on each; project still builds.</done>
</task>

</tasks>

<verification>
`grep -n "symbolEffect" Islet/Notch/NotchPillView.swift` returns no matches. `xcodebuild -scheme Islet build` succeeds (or equivalent project build check).
</verification>

<success_criteria>
The four weather SF Symbols in the expanded glance render motionless — no pulse, no variableColor animation — matching the user's explicit "just leave the icon still" instruction.
</success_criteria>

<output>
Create `.planning/quick/260708-nzj-wetter-icon-animation-symboleffect-pulse/260708-nzj-SUMMARY.md` when done
</output>
