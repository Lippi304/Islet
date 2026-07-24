# Phase 62: Timer/Pomodoro - Context

**Gathered:** 2026-07-24
**Status:** Ready for planning

<domain>
## Phase Boundary

The user starts a countdown or Pomodoro session from a new "Start Timer" button in the Home view. The collapsed island shows a live mm:ss countdown (plus segment/cycle label in Pomodoro mode); expanding it offers pause, reset, add-time, and stop controls. On completion, the island shows a splash and plays a sound — even if the user isn't looking. Pomodoro mode auto-cycles work/break segments with the same completion treatment at every transition.

This phase also generalizes `TransientQueue.preempt()` / `ActiveTransient.isPersistent` (`Islet/Notch/IslandResolver.swift`) beyond the single hardcoded `.focus` case — Timer is the first of two persistent-transient activities this milestone (Meeting-HUD, Phase 63, depends on this generalization landing correctly first). This is a technical/architectural requirement from ROADMAP.md SC5, not a user-facing decision — Claude/research/planning own how the generalization is implemented.

</domain>

<decisions>
## Implementation Decisions

### Start Flow & Duration Picker
- **D-01:** Entry point is a dedicated **"Start Timer" button in the Home view** (where Now-Playing/idle glance already lives) — not the Settings card. Settings' existing Timer card stays an on/off toggle only.
- **D-02:** Duration picker offers **preset chips (5 / 10 / 20 / 30 min) plus a custom-entry option** for an exact minute count.
- **D-03:** Countdown vs. Pomodoro is chosen via a **segmented toggle above the picker** — switching to Pomodoro swaps the duration chips for work/break preset chips in the same sheet.

### Pomodoro Session Structure
- **D-04:** Pomodoro's default preset is the **classic 25 min work / 5 min break** split.
- **D-05:** Work and break durations are **customizable**, via the same chip + custom-entry picker pattern as D-02, applied per segment.
- **D-06:** A Pomodoro session **runs until manually stopped** — no fixed cycle count or target; cycles increment indefinitely until the user taps stop.
- **D-07:** The collapsed pill shows **"Work · Cycle N" / "Break · Cycle N"** alongside the live mm:ss countdown, so the current segment and cycle number are both visible without expanding.

### Expanded Controls Layout
- **D-08:** Pause, reset, add-time, and stop use **circular icon buttons** matching the onboarding carousel's `navCircleButton` style (`NotchPillView.swift:1978`) — not the text-chip `chipButton` style (`:2013`).
- **D-09:** Add-time adds **+1 min per tap, repeatable** (tap multiple times to add more).
- **D-10:** There is a **distinct 4th stop/cancel button** that ends the session entirely and returns the island to idle — separate from reset (restarts the current segment at full duration) and pause (holds indefinitely).

### Completion & Segment Transitions
- **D-11:** Pomodoro **auto-advances immediately** between work and break segments — no "tap to start the next segment" step; the next segment's countdown begins right away.
- **D-12:** A plain countdown's completion (SC3) plays the **standard system notification sound** (via `NSSound`/`UserNotifications` default), not a custom bundled chime.
- **D-13:** The **same sound + splash treatment fires at every Pomodoro segment transition** (work↔break), not just when the whole session is stopped — consistent with D-11's hands-off auto-advance, the user needs an audible cue at every switch.

### Claude's Discretion
- Exact SF Symbol icons for pause/reset/add-time/stop and their color treatment.
- Splash visual content/copy and its on-screen duration (distinct question from *whether* it fires, which D-13 answers).
- Internal `TimerActivityState`/monitor class naming and file layout.
- How `ActiveTransient.isPersistent` is generalized in code (new case vs. shared protocol/flag) — `IslandResolver.swift:137-144` currently special-cases only `.focus`; the mechanism is a technical call for research/planning, not asked here.
- Whether a running timer's state survives an app quit/relaunch or system sleep — not raised during discussion; flagging as a real open question research should surface explicitly rather than assume either way.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & Requirements
- `.planning/ROADMAP.md` §Phase 62: Timer/Pomodoro (line 1071) — Goal, SC1-5, depends on Phase 59
- `.planning/REQUIREMENTS.md` §v1.10 Requirements — Live Activities Suite § Timer/Pomodoro (line 93) — TIMER-01, TIMER-02, TIMER-03, TIMER-04

### Prior phases (prerequisites this phase builds on)
- `.planning/phases/59-settings-redesign/59-CONTEXT.md` — Settings-grid card model; `ActivitySettings.timerKey` already wired (default OFF), this phase reads it but does NOT add options-sheet config there (see D-01)
- `.planning/phases/60-caps-lock-hud-update-activity-restyle/60-CONTEXT.md` — wings pattern precedent (collapsed HUD shape), rank-placement decision shape
- `.planning/phases/61-download-progress/61-CONTEXT.md` — closest existing precedent for a **sub-state-persistent** transient (D-02/D-13 there: `.inProgress` persistent, `.done` not) — the pattern this phase's running-vs-completed persistence split should likely follow

### Resolver / priority (the SC5 generalization target)
- `Islet/Notch/IslandResolver.swift:86` — the reserved forward-looking comment already flagging Timer/Pomodoro as "persistent transient, generalizes ActiveTransient.isPersistent beyond Focus — rank TBD — confirm in that activity's own phase discussion"
- `Islet/Notch/IslandResolver.swift:96-127` — `IslandPresentation`/`ActiveTransient` enums, named-rank-comment convention
- `Islet/Notch/IslandResolver.swift:136-145` — `ActiveTransient.isPersistent` — currently `if case .focus = self { return true }` plus the Phase 61 sub-state case for `.downloadProgress(.inProgress)`; this is the exact extension point
- `Islet/Notch/IslandResolver.swift:162-227` — `resolve(...)`, the single ranking-authority reducer where a new `.timer` case's collapsed-only/persistent branch gets added
- `Islet/Notch/IslandResolver.swift:339-378` — `TransientQueue` struct; `preempt(_:)` (364-370) is the literal single-`.focus`-case hardcode SC5 requires generalizing (`guard case .focus = head else { return enqueue(t) }`)

### Settings wiring (already done, Phase 59)
- `Islet/ActivitySettings.swift:38` — `timerKey` constant, already in `defaultsToFalseKeys` (default OFF)
- `Islet/SettingsView.swift:69,234-237` — `timerEnabled` binding and the Timer `ActivityCardData` entry; **note `onOptionsTap: nil`** — per D-01 this stays nil/unused since the picker lives on Home, not in an options sheet (flag this for research/planning to confirm, not silently leave dangling)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Notch/NotchPillView.swift:1978-1987` (`navCircleButton(systemName:filled:action:)`) — direct template for the pause/reset/add-time/stop button row per D-08
- `Islet/ActivitySettings.swift:38` — `timerKey` already exists, default OFF; no new Settings toggle work needed
- `Islet/Notch/NowPlayingPresentation.swift` — closest existing precedent for a multi-button expanded control row (transport controls); worth checking during research even though its button style differs from D-08's choice

### Established Patterns
- Named-rank-comment convention in `TransientQueue`/`IslandPresentation`/`ActiveTransient` — the new `.timer` case slots in per the existing convention; `IslandResolver.swift:86`'s reserved comment already anticipates this
- Sub-state-persistent split (Phase 61 D-02/D-13: `.inProgress` persistent, `.done` not) — the closest in-codebase precedent for Timer's own running/paused/completed persistence needs
- Separate `@Published` state-holder model per activity (`ChargingActivityState.swift`'s "Pattern 2") — likely shape for a `TimerActivityState`
- Every prior monitor/state class follows a start()/stop()/`nonisolated deinit` lifecycle skeleton

### Integration Points
- **No existing "start a session" picker/sheet pattern anywhere in this codebase** — the closest analog is the onboarding carousel's step-based flow (`NotchPillView.swift` onboarding views), not a duration/mode picker. This is genuinely new UI, not a reskin.
- Home tab (`homeLastPlayed`/`homeEmpty`, Phase 30) is where the new "Start Timer" button must slot in without breaking those existing no-media states.
- `IslandResolver.swift`'s `resolve(...)` and `TransientQueue.preempt(_:)`/`enqueue(_:)` are the two places the new persistent-transient case and its generalized preemption logic land — mirroring how `.focus` was added in Phase 38, but generalized per SC5.

</code_context>

<specifics>
## Specific Ideas

- Circular icon buttons (onboarding-carousel style), not text chips, for the expanded control row (D-08).
- Live "Work · Cycle N" / "Break · Cycle N" label in the collapsed pill during Pomodoro (D-07).
- Every Pomodoro segment transition gets the full sound+splash treatment, not a lesser cue — it should feel like a real event each time, not just at the very end (D-13).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

### Reviewed Todos (not folded)
- `2026-07-19-calendar-month-grid-polish.md`, `2026-07-19-island-briefly-disappears-during-click-through.md`, `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — same three keyword false-positives surfaced for Phases 60/61 (matched on generic words like "notch"/"phase"/"grid"/"state"); none are substantively about timers or Pomodoro sessions. Reviewed and left out of scope again.

</deferred>

---

*Phase: 62-Timer/Pomodoro*
*Context gathered: 2026-07-24*
