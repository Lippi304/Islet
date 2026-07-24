# Phase 62: Timer/Pomodoro - Research

**Researched:** 2026-07-24
**Domain:** Native macOS/SwiftUI live-activity state machine (countdown scheduling, persistent-transient generalization, local audio notification)
**Confidence:** HIGH (architecture/resolver), MEDIUM (notification/sound API choice), MEDIUM (completion-splash sizing — flagged as Open Question)

## Summary

Phase 62 is primarily an **architecture-generalization phase wearing a feature costume**. The user-facing surface (duration picker, countdown pill, pause/reset/add-time/stop, Pomodoro cycling, completion splash) is entirely new UI but built from existing, proven primitives (`navCircleButton`, `wingsShape`, `blobShape`, `TimelineView`-driven `mm:ss` rendering, the `formatMMSS` helper, the shared ~3s `scheduleActivityDismiss`). The real risk (SC5) is generalizing `TransientQueue.preempt()` and `ActiveTransient.isPersistent` from a single hardcoded `.focus` case into a reusable "persistent transient" concept, and — more subtly than the phase description implies — giving a transient its own **expanded** presentation for the first time in this codebase (every existing collapsed-only transient falls through to Home/Calendar/etc. when the island is expanded; Timer must not).

`TransientQueue.preempt()`'s guard is already 90% generalized: `ActiveTransient.isPersistent` (line 137) already handles two cases (`.focus` and `.downloadProgress(.inProgress)`), but `preempt(_:)`'s own guard (line 365, `guard case .focus = head else { return enqueue(t) }`) still only special-cases `.focus` literally — meaning a `.downloadProgress(.inProgress)` head today is NOT correctly preempted by an incoming Charging/Device transient, it just queues behind it via plain `enqueue`. The one-line fix (`guard let head, head.isPersistent else { return enqueue(t) }`) is the actual SC5 generalization and directly benefits Timer, Meeting-HUD (Phase 63), and retroactively fixes a latent Download-Progress gap, at effectively zero added complexity.

**Primary recommendation:** Add `.timer(TimerActivity)` to both `IslandPresentation` and `ActiveTransient` (mirroring Download's sub-state-persistent shape: `.running`/`.paused` persistent, `.completed`/`.segmentDone` not); fix `preempt()`'s guard to key off the existing `isPersistent` property instead of `case .focus`; add a **new** `.timerExpanded(TimerActivity)` `IslandPresentation` case with its own `resolve()` branch that returns eagerly on `isExpanded` (the first transient to ever need this — do not model it as collapsed-only). Build the countdown UI on the existing 13px `monospacedDigit()` precedent and `formatMMSS` helper; schedule real countdown completion via a one-shot `DispatchSourceTimer` (`CalendarCountdownMonitor`'s proven deadline-scheduling pattern), not a repeating poll; fire completion audio via `NSSound.beep()` (plays the user's configured System Settings alert sound — matches D-12's "standard system notification sound" exactly, zero permission/entitlement needed) rather than `UNUserNotificationCenter`, which has a documented macOS reliability gap for `LSUIElement` agent apps (this app's own `Info.plist` shape).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Entry point is a dedicated **"Start Timer" button in the Home view** (where Now-Playing/idle glance already lives) — not the Settings card. Settings' existing Timer card stays an on/off toggle only.
- **D-02:** Duration picker offers **preset chips (5 / 10 / 20 / 30 min) plus a custom-entry option** for an exact minute count.
- **D-03:** Countdown vs. Pomodoro is chosen via a **segmented toggle above the picker** — switching to Pomodoro swaps the duration chips for work/break preset chips in the same sheet.
- **D-04:** Pomodoro's default preset is the **classic 25 min work / 5 min break** split.
- **D-05:** Work and break durations are **customizable**, via the same chip + custom-entry picker pattern as D-02, applied per segment.
- **D-06:** A Pomodoro session **runs until manually stopped** — no fixed cycle count or target; cycles increment indefinitely until the user taps stop.
- **D-07:** The collapsed pill shows **"Work · Cycle N" / "Break · Cycle N"** alongside the live mm:ss countdown, so the current segment and cycle number are both visible without expanding.
- **D-08:** Pause, reset, add-time, and stop use **circular icon buttons** matching the onboarding carousel's `navCircleButton` style (`NotchPillView.swift:1978`) — not the text-chip `chipButton` style (`:2013`).
- **D-09:** Add-time adds **+1 min per tap, repeatable** (tap multiple times to add more).
- **D-10:** There is a **distinct 4th stop/cancel button** that ends the session entirely and returns the island to idle — separate from reset (restarts the current segment at full duration) and pause (holds indefinitely).
- **D-11:** Pomodoro **auto-advances immediately** between work and break segments — no "tap to start the next segment" step; the next segment's countdown begins right away.
- **D-12:** A plain countdown's completion (SC3) plays the **standard system notification sound** (via `NSSound`/`UserNotifications` default), not a custom bundled chime.
- **D-13:** The **same sound + splash treatment fires at every Pomodoro segment transition** (work↔break), not just when the whole session is stopped — consistent with D-11's hands-off auto-advance, the user needs an audible cue at every switch.

### Claude's Discretion

- Exact SF Symbol icons for pause/reset/add-time/stop and their color treatment.
- Splash visual content/copy and its on-screen duration (distinct question from *whether* it fires, which D-13 answers).
- Internal `TimerActivityState`/monitor class naming and file layout.
- How `ActiveTransient.isPersistent` is generalized in code (new case vs. shared protocol/flag) — `IslandResolver.swift:137-144` currently special-cases only `.focus`; the mechanism is a technical call for research/planning, not asked here.
- Whether a running timer's state survives an app quit/relaunch or system sleep — not raised during discussion; flagging as a real open question research should surface explicitly rather than assume either way.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope. (Three unrelated todo files reviewed and confirmed out of scope: `2026-07-19-calendar-month-grid-polish.md`, `2026-07-19-island-briefly-disappears-during-click-through.md`, `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — keyword false-positives, not substantively about timers/Pomodoro.)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-------------------|
| TIMER-01 | User can start a countdown timer from the notch with a chosen duration; the collapsed island shows a live mm:ss countdown while running | Architecture Patterns Pattern 1 (deadline scheduling) + Pattern 2 (`.timer` case shape); Code Examples (`timerWings(for:)` off `countdownWings` precedent, `formatMMSS` reuse) |
| TIMER-02 | The expanded island offers pause/reset/add-time controls for a running timer | Architecture Patterns Pattern 4 (new `.timerExpanded` resolver shape — the phase's core novel risk); Don't Hand-Roll (`navCircleButton` reuse per D-08); Common Pitfalls #4 (`updateHead` wiring so pause/add-time never mis-arm the shared dismiss timer) |
| TIMER-03 | When the timer completes, the island shows a completion HUD splash and the system plays a notification/sound | Standard Stack (`NSSound.beep()` recommendation); Common Pitfalls #1 (`UNUserNotificationCenter`/`LSUIElement` reliability gap) and #3 (completion-splash container-size ambiguity, Open Question 2); Validation Architecture (manual-only test classification) |
| TIMER-04 | A Pomodoro mode cycles work/break durations with a session counter, selectable as an alternative to a plain one-shot countdown | Architecture Patterns Pattern 2 (sub-state-persistent split, `.running`/`.paused` vs `.completed`/`.segmentDone`); Pattern 1 (segment-transition re-arm via cancel-then-reschedule) |
| SC5 (generalize `TransientQueue.preempt()`/`ActiveTransient.isPersistent`) | Timer proves the persistent-transient concept generalizes beyond the single hardcoded `.focus` case, ahead of Meeting-HUD (Phase 63) | Summary + Architecture Patterns Pattern 3 (the literal one-guard-clause fix); Common Pitfalls #2 (the latent Download-Progress preemption gap this fix also closes) |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Duration/mode picker (Home "Start Timer" sheet) | View (SwiftUI, `NotchPillView.swift`) | Controller (`NotchWindowController`) | New UI, but same sheet-presentation shape as onboarding carousel; controller owns the resulting `TimerActivityState` |
| Countdown/Pomodoro state machine (running/paused/segment/cycle count) | Controller-owned state holder (`TimerActivityState`, Pattern 2, mirrors `ChargingActivityState`) | Resolver (pure mapping to `TimerActivity`) | Stateful over time (pause holds elapsed, add-time mutates deadline) — cannot live in the pure `resolve()` reducer |
| Completion-instant scheduling (fires even if app isn't visible) | Controller / dedicated monitor class (`TimerMonitor`, one-shot `DispatchSourceTimer`, mirrors `CalendarCountdownMonitor`) | — | Must fire a real callback at the deadline; `TimelineView` alone only re-renders, it never invokes app logic |
| Persistent-transient generalization (`isPersistent`, `preempt()`) | Resolver (`IslandResolver.swift`, pure) | — | Single ranking authority (D-05 precedent) — never duplicated in the controller |
| Collapsed pill rendering (`mm:ss`, "Work · Cycle N") | View (`timerWings(for:)`, mirrors `downloadWings`/`countdownWings`) | — | Pure rendering off `TimerActivity`, no state of its own |
| Expanded controls (pause/reset/add-time/stop) | View (new `.timerExpanded` presentation branch) | Controller (button actions call back into `TimerActivityState`) | First transient in this codebase needing dedicated expanded content — see Architecture Patterns below |
| Completion sound | AppKit (`NSSound.beep()`) | — | Zero-entitlement, respects user's System Settings alert-sound choice; avoids `UNUserNotificationCenter`'s LSUIElement reliability gap |
| Completion splash visual | View (new content, size/shape TBD — see Open Questions) | — | UI-SPEC's 28px icon token doesn't cleanly fit the existing 32pt-tall wing container other splashes use |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation (`DispatchSourceTimer`, `Date`) | macOS 15.0+ (project's `MACOSX_DEPLOYMENT_TARGET`) | One-shot completion-deadline scheduling | `CalendarCountdownMonitor.swift` already establishes this exact "cancel-then-reschedule one-shot deadline" pattern in this codebase — reuse verbatim, do not introduce a new scheduling primitive `[VERIFIED: codebase]` |
| SwiftUI `TimelineView(.periodic(from:by:))` | macOS 15.0+ | Live `mm:ss` re-render every second | Proven in `countdownWings(for:)` (Phase 41) — the exact same "compute remaining from a stored deadline `Date`, re-render on a 1s tick" shape Timer needs `[VERIFIED: codebase]` |
| AppKit `NSSound.beep()` | macOS 15.0+ | Completion sound (D-12/D-13) | Plays the user's System Settings > Sound > Alert Sound choice — literally "the standard system notification sound," zero entitlement, zero permission prompt `[CITED: developer.apple.com/documentation/appkit/nssound/beep()]` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `UserNotifications` (`UNUserNotificationCenter`) | macOS 15.0+ | Alternative/enhancement: a real banner notification when Islet isn't frontmost | Only if a future phase wants an actual system notification banner (not required by TIMER-03's wording, which only asks for "a completion HUD splash" + "sound") — carries a documented reliability risk for `LSUIElement` agents (see Common Pitfalls) and a first-run permission prompt; the completion splash itself is Islet's own SwiftUI view, not a system banner, so this is not needed to satisfy TIMER-03 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `NSSound.beep()` | `UNUserNotificationCenter` + `UNNotificationSound.default` | Requires a permission prompt (friction, and it can be denied), and this codebase's own `Info.plist` sets `LSUIElement: YES` (menu-bar agent, no Dock icon) — multiple developer-forum reports describe local notifications from `LSUIElement` agents silently failing (`UNErrorCodeNotificationsNotAllowed`) even after authorization is granted. `NSSound.beep()` has no such gap and is a one-line call. |
| One-shot `DispatchSourceTimer` deadline | Repeating `Timer.scheduledTimer(withTimeInterval: 1, repeats: true)` that decrements a counter | A repeating 1s timer is the naive approach and works, but this codebase's own `RESEARCH.md`-documented convention (see `CalendarCountdownMonitor.swift`'s header comment, "Pitfall 1/Pitfall 7") explicitly avoids repeating poll timers in favor of one-shot deadline scheduling — cancel-then-reschedule on every state change (pause/resume/add-time) is the established idiom here and trivially survives app-relaunch-adjacent edge cases better (deadline is an absolute `Date`, not an accumulating counter that drifts) |

**Installation:** None — every recommended API is a first-party Apple framework already linked by the target (`Foundation`, `SwiftUI`, `AppKit`). No `Package.swift`/SPM changes needed.

**Version verification:** N/A — no external package versions to verify; APIs used (`DispatchSourceTimer`, `TimelineView`, `NSSound.beep()`) are all available since macOS 10.x/11, well below this project's `MACOSX_DEPLOYMENT_TARGET = 15.0` floor.

## Package Legitimacy Audit

**Not applicable.** This phase installs zero external packages — every recommended API (`Foundation`, `SwiftUI`, `AppKit`, optionally `UserNotifications`) is a first-party Apple system framework already linked into the `Islet` target. The Package Legitimacy Gate protocol (slopcheck, registry verification) is scoped to third-party dependency installs and does not apply here.

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│  Home view — "Start Timer" button (new, D-01)                       │
│  → presents duration/mode picker sheet (new UI, D-02/D-03/D-04/D-05) │
└──────────────────────────┬────────────────────────────────────────┬─┘
                            │ user picks duration/mode               │
                            ▼                                        │
┌───────────────────────────────────────────────────────────────────┐│
│  TimerActivityState (new, @Published, Pattern 2 — mirrors          ││
│  ChargingActivityState.swift's "plain published holder" shape)     ││
│  holds: mode (.countdown/.pomodoro), phase (.work/.break),         ││
│  cycle count, deadline: Date, isPaused: Bool                       ││
└──────────────────────────┬───────────────────────────────────────┬─┘│
              pause/reset/  │ deadline reached                     │  │
              add-time/stop │ (one-shot DispatchSourceTimer fires) │  │
                            ▼                                       │  │
┌───────────────────────────────────────────────────────────────────┐│ │
│  TimerMonitor (new, mirrors CalendarCountdownMonitor.swift):        ││ │
│  arms exactly ONE DispatchSourceTimer deadline at a time, cancel-   ││ │
│  then-reschedule on every pause/resume/add-time/segment-advance.    ││ │
│  On fire: plays NSSound.beep(), tells TimerActivityState to         ││ │
│  auto-advance to next Pomodoro segment (or clears if plain          ││ │
│  countdown), feeds a `.completed`/`.segmentDone` sub-state into      ││ │
│  the transient queue (self-elapses via the shared ~3s dismiss).     ││ │
└──────────────────────────┬────────────────────────────────────────┘│ │
                            │ TimerActivity value                     │ │
                            ▼                                         │ │
┌───────────────────────────────────────────────────────────────────┐  │
│  IslandResolver.swift (pure, unmodified signature — new inputs      │  │
│  threaded through the SAME `resolve(...)` call):                    │  │
│  - ActiveTransient.isPersistent: .timer(.running/.paused) → true;    │  │
│    .timer(.completed/.segmentDone) → false (falls through to shared │  │
│    ~3s auto-dismiss, exact Download-Progress precedent)              │  │
│  - TransientQueue.preempt(): guard generalized from `case .focus`     │  │
│    to `head.isPersistent` — ANY persistent head (Focus, Download-     │  │
│    in-progress, now Timer) gets displaced+requeued, not stuck ahead    │  │
│  - resolve()'s switch: NEW pattern — `.timer` returns `.timerExpanded` │
│    when isExpanded, instead of `break`-ing through to Home/Calendar    │
└──────────────────────────┬────────────────────────────────────────┘  │
                            │ IslandPresentation                        │
                            ▼                                            │
┌───────────────────────────────────────────────────────────────────┐   │
│  NotchPillView.swift — presentationSwitch:                          │   │
│  case .timer(let a): timerWings(for: a)     // collapsed pill        │   │
│  case .timerExpanded(let a): timerExpandedContent(a) // NEW           │   │
│    (pause/reset/add-time/stop navCircleButton row, D-08)              │◄─┘
└───────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

No new folders — this codebase is flat within `Islet/Notch/`, one file per activity concern (mirrors `DownloadActivity.swift`/`DownloadCoordinator.swift`/`DownloadMonitor.swift` split exactly):

```
Islet/Notch/
├── TimerActivity.swift        # NEW — pure enum/struct + TOTAL mapping helpers (Pattern 1, Foundation-only)
├── TimerActivityState.swift   # NEW — @Published state holder (Pattern 2, mirrors ChargingActivityState.swift)
├── TimerMonitor.swift         # NEW — one-shot DispatchSourceTimer scheduling (mirrors CalendarCountdownMonitor.swift)
├── IslandResolver.swift       # MODIFIED — new .timer/.timerExpanded cases, isPersistent extension, preempt() guard generalization
├── NotchPillView.swift        # MODIFIED — timerWings(for:), timerExpandedContent(for:), Home "Start Timer" button + duration sheet
└── NotchWindowController.swift # MODIFIED — TimerActivityState wiring, toggle-gate (mirrors startDownloadMonitor()'s exact shape)
```

### Pattern 1: One-shot deadline scheduling, not a repeating poll
**What:** Store the timer's completion instant as an absolute `Date` (the "deadline"). Arm exactly one `DispatchSourceTimer` at that deadline. On any state change (pause, resume, add-time, segment transition), cancel the existing timer and re-arm a fresh one at the new deadline.
**When to use:** Any time the app needs a callback to fire at a future instant, especially one that must survive brief foreground/background transitions.
**Example:**
```swift
// Source: Islet/Notch/CalendarCountdownMonitor.swift:87-94 (existing codebase pattern)
private func armTimer(at date: Date) {
    let t = DispatchSource.makeTimerSource(queue: .main)
    t.schedule(deadline: .now() + max(0, date.timeIntervalSinceNow))
    t.setEventHandler { [weak self] in self?.recheck() }
    t.resume()
    timer = t
}
```
Pausing a Timer/Pomodoro session means: capture `remaining = deadline.timeIntervalSinceNow`, cancel the armed timer, and do NOT re-arm until Resume — at which point compute a new `deadline = Date().addingTimeInterval(remaining)` and re-arm. Add-time (D-09) simply extends the current `deadline` by 60s and re-arms (cancel-then-reschedule), whether running or paused (extending a paused deadline is a no-op display-wise until resumed, but keeps the model consistent — confirm with planner whether add-time should be disabled while paused, not specified in CONTEXT.md).

### Pattern 2: Sub-state-persistent transient (the Download-Progress precedent)
**What:** A single `ActiveTransient` case whose `isPersistent` value depends on its *associated value*, not just the case itself — exactly Phase 61's `DownloadActivity.inProgress` (persistent) vs `.done(filename:)` (not persistent, self-dismisses).
**When to use:** Timer's `.running`/`.paused` sub-states must never self-elapse (there's no natural timeout while the user is actively managing a session); its `.completed`/`.segmentDone` sub-state (the splash) SHOULD self-elapse via the existing shared ~3s dismiss timer, exactly like `.done(filename:)` does.
**Example:**
```swift
// Source: Islet/Notch/IslandResolver.swift:136-144 (existing, extend this exact function)
extension ActiveTransient {
    var isPersistent: Bool {
        if case .focus = self { return true }
        if case .downloadProgress(.inProgress) = self { return true }
        // NEW — Phase 62:
        if case .timer(let t) = self, t.isRunningOrPaused { return true }
        return false
    }
}
```

### Pattern 3: Generalizing `preempt()` off the existing `isPersistent` property
**What:** The literal SC5 fix. `preempt()`'s guard currently hardcodes `.focus`; it should key off the SAME `isPersistent` property `resolve()`/tests already treat as the generalized concept.
**Example:**
```swift
// Source: Islet/Notch/IslandResolver.swift:364-370 — BEFORE
mutating func preempt(_ t: ActiveTransient) -> Bool {
    guard case .focus = head else { return enqueue(t) }
    let displaced = head!
    head = t
    pending.insert(displaced, at: 0)
    return true
}

// AFTER (the SC5 generalization — one guard clause changes)
mutating func preempt(_ t: ActiveTransient) -> Bool {
    guard let currentHead = head, currentHead.isPersistent else { return enqueue(t) }
    head = t
    pending.insert(currentHead, at: 0)
    return true
}
```
This is a **behavior change** for the existing Download-Progress case too (today, a `.downloadProgress(.inProgress)` head is NOT preempted by Charging/Device — it silently queues behind, contradicting Download's own documented "never self-elapses" persistence). Flag this to the planner as an incidental bugfix that should be covered by a regression test (`IslandResolverTests.swift` already has the `preempt`/`isPersistent` test scaffolding at lines 649-841 to extend).

### Pattern 4: A transient with its OWN expanded content (genuinely new in this codebase)
**What:** Every existing collapsed-only `ActiveTransient` (`.focus`, `.osd`, `.downloadProgress`, `.capsLock`, `.updateAvailable`) uses `case X(let a) where !isExpanded: return .x(a)` then `case X: break` — meaning when the island is expanded, these transients yield entirely to whatever Home/Calendar/Tray/NowPlaying content would otherwise show. Charging/Device (D-04, true "wins even over expanded") have NO `where !isExpanded` guard at all — they render unconditionally, but via the SAME small collapsed wing regardless of expand state (no distinct "big" content).

Timer needs a **third** shape neither of these covers: a collapsed pill (mm:ss) AND a genuinely different, bigger expanded view (pause/reset/add-time/stop circular buttons, per D-08/TIMER-02) — and expanding the island while Timer runs must show THAT view, not fall through to Home.

**Example:**
```swift
// Source: Islet/Notch/IslandResolver.swift:175-189 — the switch(activeTransient) block.
// Existing collapsed-only shape (unchanged for Focus/OSD/Download/CapsLock/Update):
case .focus(let f) where !isExpanded: return .focus(f)
case .focus: break // falls through to isExpanded branch, unmodified

// NEW shape for Timer — does NOT break; returns its OWN expanded case instead:
case .timer(let t) where !isExpanded: return .timer(t)         // collapsed pill
case .timer(let t): return .timerExpanded(t)                    // NEW: dedicated expanded controls, takes priority over selectedView/pendingDrop/nowPlaying
```
This is placed inside the initial `switch activeTransient` block (same tier as Charging/Device, i.e., checked before the `if isExpanded { ... }` block's `pendingDrop`/`selectedView` reads), so a running Timer's expanded controls take priority over an active Calendar/Weather/Tray tab selection or even a pending file drop. **This priority choice is not explicitly specified in CONTEXT.md/UI-SPEC — flagged as Open Question 1 below.**

### Anti-Patterns to Avoid
- **Repeating 1s `Timer.scheduledTimer` for completion detection:** Fine for the *display* tick (`TimelineView` handles that declaratively), but wrong for firing the actual completion callback (sound + splash) — use the one-shot deadline pattern instead, matching this codebase's own documented convention.
- **A second, independent "is this expanded" check duplicated in the controller:** `resolve()` is the single ranking authority (D-05) — Timer's expanded-vs-collapsed branch belongs entirely inside `resolve()`, never as a parallel `if interaction.isExpanded` check in `NotchWindowController` or the view layer.
- **Threading `Date()`/`Date.now` calls into the pure resolver or `TimerActivity` mapping functions:** Every existing pure seam (`focusActivity(from:)`, `downloadFilename(fromPath:)`) takes plain values, never reads the live clock — `TimerActivityState`/`TimerMonitor` (the stateful, system-glue layer) own all `Date()` reads, mirroring `DownloadCoordinator.handle(_:now:)`'s explicit "testable overload, no live Date() inside" discipline.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Completion sound | A custom `AVAudioPlayer`-based chime player, or bundling an audio asset | `NSSound.beep()` | D-12 explicitly locks "standard system notification sound," and `NSSound.beep()` already plays exactly that (the user's configured System Settings alert sound) with zero code beyond one call |
| Live mm:ss countdown re-render | A custom `Timer`/`@State` ticking loop inside the SwiftUI view | `TimelineView(.periodic(from:by:))` computing `remaining` from a stored `deadline: Date` | Already proven in `countdownWings(for:)` (Phase 41) for exactly this shape; re-deriving it risks the icon/text color-desync bug that file's own header comment warns against |
| mm:ss string formatting | A new formatter | The existing `private func formatMMSS(_ seconds: TimeInterval) -> String` in `NotchPillView.swift` (line ~2638) | Already handles zero-padding and (confirmed by inspection) does NOT cap at 59:59 — `Int(seconds)/60` grows past 2 digits naturally for a 180-minute custom duration, so it is safe to reuse as-is despite being written for Calendar Countdown's 1-hour window |
| Circular pause/reset/add-time/stop buttons | A new button component | `navCircleButton(systemName:filled:action:)` (`NotchPillView.swift:1977`) | D-08 explicitly locks this exact style; it already supports the filled/outlined distinction D-08's "exactly one filled action" convention needs |
| Persistent-transient bookkeeping | A second, timer-specific "don't auto-dismiss" flag threaded through the controller | Extend the existing `ActiveTransient.isPersistent` property | This is the literal generalization SC5 asks for — a parallel flag would defeat the purpose and reintroduce the exact hardcoding problem being fixed |

**Key insight:** Nothing in this phase's UI surface is genuinely novel at the widget level — every visual element has a direct, locked precedent (UI-SPEC explicitly states "this phase adds zero new visual primitives"). The actual engineering risk is entirely in the resolver's state-machine shape (Pattern 4 above), not in building new views.

## Common Pitfalls

### Pitfall 1: `UNUserNotificationCenter` local notifications are unreliable from an `LSUIElement` agent
**What goes wrong:** Requesting authorization succeeds and is granted, but `UNUserNotificationCenter.current().add(request:)` silently fails or the notification never appears, sometimes surfacing `UNErrorCodeNotificationsNotAllowed` even after a granted authorization.
**Why it happens:** This project's `Info.plist` sets `INFOPLIST_KEY_LSUIElement: YES` (menu-bar agent, no Dock icon, per `APP-01`). Multiple Apple Developer Forum threads report that local notifications from `LSUIElement`/background agents behave inconsistently, independent of authorization status — a documented, unresolved platform gap, not a bug in this codebase `[CITED: developer.apple.com/forums/thread/804854, developer.apple.com/forums/tags/usernotifications]` (MEDIUM confidence — multiple corroborating forum reports, no single authoritative root-cause doc found).
**How to avoid:** Use `NSSound.beep()` for the audio cue (D-12 already permits this exact API) instead of routing through `UserNotifications`. The visual "completion HUD splash" is Islet's own SwiftUI content rendered in its own always-visible `NotchPanel`, not a system notification banner — so `UserNotifications` was never required to satisfy TIMER-03's literal wording ("shows a completion HUD splash and the system plays a notification/sound"), only the "plays a sound" half needs system-level reach, and `NSSound.beep()` covers that without any of `UserNotifications`' overhead or reliability risk.
**Warning signs:** If a future phase does want a real system notification banner, budget an explicit on-device spike (mirroring this project's own Phase 38/49 spike-first precedent) before committing to it as a load-bearing requirement.

### Pitfall 2: `preempt()`'s hardcoded `.focus` guard silently breaks Download-Progress preemption today
**What goes wrong:** A `.downloadProgress(.inProgress)` head is `isPersistent == true`, but if a Charging/Device transient arrives while it's head, the controller likely calls `preempt(_:)` (mirroring Focus's own D-08 "must immediately preempt" requirement) — and today's `preempt()` guard (`case .focus = head`) does NOT match `.downloadProgress`, so it falls through to plain `enqueue(_:)`, silently queuing Charging/Device BEHIND a persistent Download splash that will never self-elapse to let it through.
**Why it happens:** `isPersistent` was generalized in Phase 61 (adding the `.downloadProgress(.inProgress)` case), but `preempt()`'s own guard was never updated to match — the two are conceptually the same "does this head need active displacement" question but are implemented as two independently-hardcoded checks.
**How to avoid:** Generalize `preempt()`'s guard to `guard let head, head.isPersistent else { return enqueue(t) }` (Pattern 3 above) as part of this phase's SC5 work — this is in-scope regardless of whether Download's own call sites currently invoke `preempt()` for it, since Timer's own persistent case needs the SAME generalized guard to work correctly.
**Warning signs:** A regression test asserting `TransientQueue().preempt(_:)` against a `.downloadProgress(.inProgress)` head (mirroring the existing Focus-preemption tests at `IslandResolverTests.swift:663-670`) should be added; if it's not already covered, that gap itself is evidence this pitfall was never caught.

### Pitfall 3: Completion splash's 28px icon doesn't fit the existing 32pt-tall collapsed wing
**What goes wrong:** UI-SPEC locks the completion splash's icon at 28px (`checkmark.circle.fill`), explicitly citing `homeEmptyContent`'s 28px `music.note` as the precedent — but `homeEmptyContent` renders inside an EXPANDED blob-shaped view (`blobShape`, much taller than a wing), not inside the 32pt-tall collapsed `wingsShape` every other transient splash (Charging, Focus, CapsLock, Download-done) uses. A 28px icon does not fit inside a 32pt-tall wing alongside its own padding without visually cramming/clipping.
**Why it happens:** The UI-SPEC's Typography section reused the 28px token purely to stay within the phase's stated 4-size typography budget ("collapsing what would otherwise be two separate sizes"), which may not have accounted for the container-size mismatch between `homeEmptyContent`'s expanded box and the wing splash pattern every prior transient uses.
**How to avoid:** Flag this explicitly to the UI-checker/planner as Open Question 1 below rather than guessing a container shape. Two candidate resolutions: (a) render the completion splash at collapsed-wing scale with a SMALLER icon (e.g. 14-20px, matching every other wing's icon size) and treat the 28px UI-SPEC line as aspirational/needing revision; or (b) genuinely make the completion splash its own brief "auto-expand-then-collapse" presentation at `blobShape` scale — this would be a fourth, novel resolver shape beyond even Pattern 4 above, and should not be assumed without explicit confirmation.
**Warning signs:** If planning proceeds by guessing container shape without flagging this, expect an on-device UAT round dedicated entirely to re-sizing the splash (mirrors this project's own repeated wing-geometry sagas — Phase 39's 16-round OSD wing saga, Phase 60/61's multi-round margin tuning — all caused by exactly this kind of un-verified container-size assumption).

### Pitfall 4: Add-time/pause interacting with a persistent, non-self-elapsing head
**What goes wrong:** Because `.timer(.running)`/`.timer(.paused)` will be `isPersistent`, the shared ~3s auto-dismiss timer (`scheduleActivityDismiss`) must NEVER be armed while the timer is running/paused — only when it transitions to `.completed`/`.segmentDone`. If the controller's toggle-gate/replace-head wiring accidentally re-arms the shared dismiss timer on every state mutation (pause tap, add-time tap), the running/paused pill could get incorrectly dismissed mid-session.
**Why it happens:** `TransientQueue.updateHead(_:)` (the in-place refresh mechanism Download's `.done` transition and OSD's scrub-refresh both use) is the established "mutate the head without re-arming dismiss" primitive — but a naive implementation might instead call `enqueue`/`replaceHead` patterns that DO re-arm the timer, mirroring Charging's percent-tick refresh (which correctly re-arms because Charging is NOT persistent).
**How to avoid:** Route every pause/reset/add-time/segment-advance mutation through `TransientQueue.updateHead(_:)` (never `enqueue`/`preempt` for same-category updates), exactly mirroring `.osd, .osd): head = t` and `.downloadProgress, .downloadProgress): head = t` cases already in that function — add a `(.timer, .timer): head = t` case there. Only the FINAL transition into `.completed`/`.segmentDone` should trigger the real dismiss-timer arm (mirrors Download's `.inProgress` → `.done(filename:)` transition, which correctly re-arms via `replaceHead` + a fresh `scheduleActivityDismiss()` call per `DownloadCoordinator`'s own header comment).
**Warning signs:** An on-device test where pausing/resuming repeatedly over >3s makes the pill vanish mid-session would indicate this wiring was done incorrectly.

## Code Examples

### One-shot deadline timer (Pattern 1)
```swift
// Source: Islet/Notch/CalendarCountdownMonitor.swift:87-94 (existing codebase precedent, reuse verbatim)
private func armTimer(at date: Date) {
    let t = DispatchSource.makeTimerSource(queue: .main)
    t.schedule(deadline: .now() + max(0, date.timeIntervalSinceNow))
    t.setEventHandler { [weak self] in self?.recheck() }
    t.resume()
    timer = t
}
```

### Live mm:ss render off a stored deadline (Pattern already proven)
```swift
// Source: Islet/Notch/NotchPillView.swift:2649-2675 (countdownWings, Phase 41 — direct template)
private func timerWings(for activity: TimerActivity) -> some View {
    wingsShape(leftWidth: /* icon */ 38, rightWidth: Self.wingsLabelWidth / 2) {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, activity.deadline.timeIntervalSince(context.date))
            HStack(spacing: 0) {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Spacer()
                Text(formatMMSS(remaining))   // reuse existing helper — NotchPillView.swift:2638
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
}
```

### Completion sound (D-12, avoids UNUserNotificationCenter's LSUIElement gap)
```swift
// AppKit — zero permission/entitlement required
import AppKit
NSSound.beep()   // plays the user's System Settings > Sound > Alert Sound choice
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `ActiveTransient.isPersistent` hardcodes `.focus` only | Generalized to also cover `.downloadProgress(.inProgress)` | Phase 61 (already landed) | `preempt()` was NOT updated to match — this phase must close that gap (Pitfall 2) |

**Deprecated/outdated:** None — no APIs used here are deprecated; `DispatchSourceTimer`/`TimelineView`/`NSSound` are all current, actively-maintained Apple APIs.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `NSSound.beep()` plays the user's configured System Settings alert sound (satisfying D-12's "standard system notification sound") | Standard Stack, Code Examples | If wrong, D-12 isn't actually satisfied and a different API (e.g. `AudioServicesPlayAlertSound(kSystemSoundID_UserPreferredAlert)` from AudioToolbox) would be needed instead — low risk, same effort to swap |
| A2 | `UNUserNotificationCenter` local notifications are unreliable specifically because of this app's `LSUIElement` flag | Common Pitfalls #1 | Based on multiple developer-forum reports, not a single authoritative Apple statement — if wrong (i.e. it actually works fine), the recommendation to avoid it is merely over-cautious, not harmful, since `NSSound.beep()` satisfies D-12 either way |
| A3 | Timer's expanded controls (`.timerExpanded`) should take priority over an active Calendar/Weather/Tray tab selection when the user expands the island | Architecture Patterns, Pattern 4 | If wrong (user actually wants to keep browsing Calendar/Weather with the timer running quietly in the background, only intercepting expand when `selectedView == .home`), the resolver branch placement needs to change — flagged explicitly as Open Question 1, not silently assumed into the plan |
| A4 | The completion splash renders as a normal collapsed-wing-scale splash (not a brief auto-expand-to-blob-scale presentation) despite the UI-SPEC's 28px icon citing `homeEmptyContent` | Common Pitfalls #3 | If wrong, a genuinely new "auto-expand-then-collapse" resolver/view shape is needed — meaningfully more work than assumed; flagged as Open Question 2 |
| A5 | Add-time (+1 min) should be a no-op-until-resumed extension of the stored deadline even while paused (rather than disabled while paused) | Pattern 1 | If wrong, add-time needs an explicit disabled-while-paused guard in the expanded control row — small UI change, not architecture-level |

## Open Questions

1. **Does a running Timer's expanded control view take priority over an active Calendar/Weather/Tray tab selection?**
   - What we know: D-04's "wins even over expanded" precedent exists only for Charging/Device (unconditional `return`, no distinct expanded content); every other transient yields entirely on expand. Timer needs a THIRD shape (dedicated expanded content) that has no existing precedent to copy exactly.
   - What's unclear: CONTEXT.md and the UI-SPEC describe the picker/controls/splash in isolation but never address what happens if the user has, say, Calendar open when the timer completes or when they try to expand.
   - Recommendation: Default to Timer's expanded controls taking priority (simplest resolver branch, mirrors Pattern 4 above) unless the planner/discuss-phase surfaces a reason the user wants simultaneous Calendar+Timer access — this is a one-line branch-ordering decision, cheap to revisit later if wrong.

2. **What container/shape does the completion splash actually render in — collapsed wing or a brief expanded blob?**
   - What we know: UI-SPEC locks a 28px icon + text pairing, explicitly citing `homeEmptyContent` (an EXPANDED-view precedent) for icon size, but every other transient splash in this codebase (Charging, Focus, CapsLock, Download-done) renders in the much-shorter (32pt-tall) collapsed `wingsShape` container.
   - What's unclear: whether the UI-SPEC intends a literal container-shape change (a new "big" splash) or just reused the 28px size token for typography-budget reasons without checking wing-height feasibility.
   - Recommendation: Surface to the UI-checker before planning locks a container shape — this genuinely changes the resolver architecture (a 4th presentation shape) if the answer is "big blob," vs. zero extra architecture if the answer is "normal wing, icon size should shrink."

3. **Does a running timer's state survive an app quit/relaunch or system sleep?**
   - What we know: CONTEXT.md's own "Claude's Discretion" section flags this explicitly as unresolved ("not raised during discussion... flagging as a real open question").
   - What's unclear: whether `TimerActivityState` needs any persistence (e.g. `UserDefaults`-backed deadline + mode) to resurrect a session after a relaunch, or whether it's acceptable for a quit/relaunch to simply lose the running timer (matching this app's existing behavior for, e.g., a running Charging/Download splash, which also don't persist across relaunch today).
   - Recommendation: Default to NO persistence (matches every existing transient's behavior — none of Charging/Device/Focus/Download/CapsLock persist across a relaunch either), unless the planner/user explicitly wants Timer to be the first exception. Cheap to add later if needed (a `UserDefaults`-backed `deadline`/`mode` restore on `NotchWindowController.init`).

## Environment Availability

Not applicable — this phase has no external tool/service/runtime dependencies beyond Xcode's already-configured build toolchain (macOS 15.0 deployment target, already in use project-wide). All APIs (`DispatchSourceTimer`, `TimelineView`, `NSSound`) are first-party frameworks already linked.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing target `IsletTests`) |
| Config file | `project.yml` (XcodeGen-managed target, no separate test-plan file) |
| Quick run command | Manual Cmd-U in Xcode (headless `xcodebuild test` is documented to hang in this repo — a pre-existing Bluetooth-TCC-authorization wait affects the full app's boot path, per `.planning/PROJECT.md` line 425 and `.planning/phases/09-fullscreen-flash-window-space-retry/deferred-items.md`) |
| Full suite command | Manual Cmd-U (same caveat — no separate "full" vs "quick" split exists in this project; `xcodebuild build` is used for CI-style gating instead) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TIMER-01 | Countdown starts, collapsed pill shows live mm:ss | unit (pure `TimerActivity`/`formatMMSS` mapping) + manual on-device (live TimelineView render) | Cmd-U: `TimerActivityTests.swift` (new) | ❌ Wave 0 |
| TIMER-02 | Pause/reset/add-time take effect immediately when expanded | unit (`TimerActivityState` mutation logic, deadline math) + manual on-device (button taps, immediate effect) | Cmd-U: `TimerActivityStateTests.swift` (new) | ❌ Wave 0 |
| TIMER-03 | Completion fires splash + sound even if app isn't focused | manual-only (system audio + splash timing cannot be asserted headlessly; `NSSound.beep()` has no XCTest-observable return value) | Manual on-device checkpoint | ❌ Wave 0 (no automated coverage possible for the audio/visual firing itself; the deadline-scheduling LOGIC — "did the timer fire at the right instant" — IS unit-testable via a fake clock, mirroring `DownloadCoordinator.handle(_:now:)`'s testable-overload convention) |
| TIMER-04 | Pomodoro cycles work/break, session counter increments | unit (`TimerActivity` segment-advance pure logic) + manual on-device (full cycle observation) | Cmd-U: `TimerActivityTests.swift` (new) | ❌ Wave 0 |
| SC5 (resolver generalization) | `TransientQueue.preempt()`/`isPersistent` correctly handle `.timer`, and a Charging/Device interruption correctly resumes a running Timer afterward | unit (extend `IslandResolverTests.swift`'s existing `preempt`/`isPersistent` test blocks, mirrors lines 649-841's exact shape) | Cmd-U: `IslandResolverTests.swift` (extend, not new) | ✅ file exists, needs new test cases |

### Sampling Rate
- **Per task commit:** Manual Cmd-U for the touched test file(s) (this project has no faster automated quick-run given the headless-hang constraint)
- **Per wave merge:** Full manual Cmd-U pass across `IsletTests` target
- **Phase gate:** Full manual Cmd-U green + on-device UAT (TIMER-03's audio/splash firing, SC5's preempt-and-resume behavior) before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `IsletTests/TimerActivityTests.swift` — pure `TimerActivity`/`formatMMSS`-adjacent mapping tests (mirrors `DownloadActivityTests.swift`'s plain-XCTAssert style, no shared fixture)
- [ ] `IsletTests/TimerActivityStateTests.swift` — pause/resume/add-time deadline-math tests, using a testable overload (no live `Date()` calls), mirroring `DownloadCoordinatorTests.swift`'s "testable overload takes `now:`" convention
- [ ] Extend `IsletTests/IslandResolverTests.swift` — new `.timer`/`.timerExpanded` resolve() branch tests, plus a regression test for the generalized `preempt()` guard against a `.downloadProgress(.inProgress)` head (closing Pitfall 2's gap)
- [ ] Framework install: none — XCTest is already fully configured project-wide

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | No auth surface in this phase |
| V3 Session Management | No | No session/network surface |
| V4 Access Control | No | Single-user local desktop app, no multi-tenant boundary |
| V5 Input Validation | Yes | Custom-duration entry (D-02/D-05, "1-180" minute range) — UI-SPEC already locks the exact validation message ("Enter a number between 1 and 180.") and range; implement via a plain `Int(text).map { (1...180).contains($0) }` guard, no new validation library needed |
| V6 Cryptography | No | No secrets/crypto touched by this phase |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| Custom-duration text field accepting non-numeric/out-of-range input | Tampering (of app state, not a security boundary) | Plain `Int()` parse + range guard, matching the already-locked UI-SPEC copy — no injection risk since this value never reaches a shell command, file path, or format string beyond a plain integer used for `Date.addingTimeInterval` |

No other ASVS-relevant surface exists in this phase — Timer/Pomodoro touches no network, no credentials, no persisted user data beyond (optionally, per Open Question 3) a `UserDefaults`-backed timer-state restore, which mirrors this app's existing non-sensitive `@AppStorage` usage pattern throughout `ActivitySettings.swift`.

## Sources

### Primary (HIGH confidence)
- `Islet/Notch/IslandResolver.swift` (this repo) — `ActiveTransient.isPersistent` (lines 136-145), `TransientQueue.preempt()` (lines 364-370), `resolve(...)` (lines 162-227), `IslandPresentation`/`ActiveTransient` enums (lines 96-127)
- `Islet/Notch/CalendarCountdownMonitor.swift` (this repo) — one-shot `DispatchSourceTimer` deadline-scheduling pattern (lines 87-94)
- `Islet/Notch/DownloadActivity.swift` / `DownloadCoordinator.swift` (this repo) — sub-state-persistent transient precedent, testable-overload (`handle(_:now:)`) convention
- `Islet/Notch/NotchPillView.swift` (this repo) — `navCircleButton` (line 1977), `formatMMSS` (line 2638), `countdownWings` (line 2649), `capsLockWings`/`updateWings`/`downloadWings` (lines 2880-3030), `homeEmptyContent` (line 1144)
- `IsletTests/IslandResolverTests.swift` (this repo) — existing `preempt`/`isPersistent` test coverage shape (lines 649-841)
- `.planning/phases/62-timer-pomodoro/62-CONTEXT.md`, `62-UI-SPEC.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md` (this repo)
- `developer.apple.com/documentation/appkit/nssound/beep()` — `NSSound.beep()` API reference

### Secondary (MEDIUM confidence)
- WebSearch: `NSSound.beep()` plays the user's System Settings alert-sound preference, cross-referenced against `AudioServicesPlayAlertSound(kSystemSoundID_UserPreferredAlert)`'s documented equivalent behavior
- WebSearch: multiple Apple Developer Forum threads reporting `UNUserNotificationCenter` local-notification unreliability from `LSUIElement`/agent-flagged apps

### Tertiary (LOW confidence)
- None — every finding above was either grounded directly in this repo's own code or cross-referenced against at least one additional source

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every recommended API is a first-party framework verified directly against this codebase's own existing usage
- Architecture (resolver generalization): HIGH — grounded in direct reading of `IslandResolver.swift` and its test suite; the `preempt()` gap (Pitfall 2) was discovered by close reading, not assumed
- Architecture (expanded-transient shape, Pattern 4): MEDIUM — the mechanism (new resolver case, eager `return` instead of `break`) is a natural extension of the existing pattern, but its exact interaction with `selectedView`/`pendingDrop` priority is flagged as Open Question 1, not locked
- Notification/sound API choice: MEDIUM — `NSSound.beep()` recommendation is corroborated by Apple docs + community sources but not a first-party "this is definitively correct" statement; the `UNUserNotificationCenter`-avoidance rationale rests on forum reports, not an Apple engineering statement
- Completion-splash container shape: LOW — genuinely unresolved (Open Question 2), flagged rather than guessed
- Pitfalls: HIGH — all four pitfalls are grounded in direct code reading of this repository, not generic macOS folklore

**Research date:** 2026-07-24
**Valid until:** 30 days (native macOS SDK APIs used here are stable; the codebase-specific findings will go stale as soon as Phase 62 itself lands, since they describe pre-Phase-62 state)
