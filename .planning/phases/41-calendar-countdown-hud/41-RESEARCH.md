# Phase 41: Calendar Countdown HUD - Research

**Researched:** 2026-07-18
**Domain:** Native macOS/SwiftUI ambient-tier resolver extension + minute-boundary timer scheduling + EventKit event selection
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Calendar Countdown ALWAYS wins the single ambient slot over Now-Playing (playing or paused) whenever both would otherwise apply. Now-Playing's ambient wings are suppressed for the duration the countdown is active — no time-based threshold, no "only near the end" nuance. Phase 42 later adds a secondary bubble so both can show at once; until then this is a hard override, not a negotiation.
- **D-02:** The Phase 18 song-change toast is UNCHANGED — it keeps firing independently of the ambient state (it already can appear over the idle glance today), including while the Countdown owns the ambient pill. No new suppression gate on `songChangeToastGate()`.
- **D-03:** Calendar Countdown gets its own Settings toggle, default ON — matches the established per-activity convention (Focus, OSD, Charging, Device are all default-enabled opt-out, not opt-in).
- **D-04:** Countdown text renders as `mm:ss` (e.g. "23:14"), not minutes-only. Flagged in tension with PITFALLS.md Pitfall 7's minute-boundary timer-hygiene convention — the underlying scheduling timer stays minute-boundary/deadline-based; the live `mm:ss` display needs a separate, tightly-gated per-second UI refresh (resolved by `41-UI-SPEC.md` as a `TimelineView(.periodic(from:by:1))` scoped to the wing's own mount lifecycle).
- **D-05:** Urgency coloring, explicitly modeled on the iPhone Dynamic Island's Live Activity countdown convention: **orange** for the full countdown window, switching to **red** in the final minute before the event starts.
- **D-06:** Icon + time only on the collapsed pill — the event title is never shown there (matches the ROADMAP wording exactly). Title is only visible by expanding to the Calendar tab.
- **D-07:** Clicking the Countdown pill expands to Home — identical to Now-Playing's existing ambient click behavior today. No new deep-link-to-Calendar-tab special case.
- **D-08:** No hover-reveal. Hovering the Countdown pill does nothing extra (no tooltip, no title reveal) — consistent with D-06 and with every other ambient/idle state today.
- **D-09:** When the current countdown dismisses at its event's start time, if another event starts within the next hour immediately after, the pill immediately re-arms for that next event rather than going idle first. The countdown monitor must re-check for the next relevant event on every dismiss, not only on the next scheduled minute-boundary tick.

### Claude's Discretion

- Exact SF Symbol choice for the calendar icon, and the precise mechanism for the mm:ss live-refresh (D-04's flagged tension) are left to research/planning. **Resolved by `41-UI-SPEC.md`:** icon is `"calendar"` (reused verbatim); mechanism is `TimelineView(.periodic(from: .now, by: 1))` scoped to the wing's own mount lifecycle, no `paused:` flag needed since the wing has no "present but inactive" state.
- Precise selection function for "next NOT-YET-STARTED event within the 1-hour lookahead" — whether to adapt `nextRelevantEvent()` or add a new pure function. **Resolved by this research (Pattern 4):** add a new sibling function, `nextUpcomingEvent(events:now:lookahead:)`, rather than modifying `nextRelevantEvent()` (which has its own existing callers that must keep their current in-progress-inclusive behavior).

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope. The dual-activity combination with Now-Playing is correctly scoped to Phase 42, not this phase, and was never proposed as in-scope here.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-------------------|
| HUD-08 | Starting 1 hour before a calendar event, the collapsed pill shows a live minute-countdown (calendar icon left, event time right) that updates continuously until the event starts — uses its own persistent timer, not the shared 3s `activityDuration` auto-dismiss | Architecture Patterns 1-4 (resolver ambient-pair extension, monitor lifecycle, deadline-not-polling scheduling, pure event selection); Code Examples (resolver extension, `CalendarCountdownActivity`, `countdownWings(for:)`); Common Pitfalls 1-5; Validation Architecture (resolver unit tests + on-device UAT for the idle-wakeup/live-countdown success criteria) |

</phase_requirements>

## Summary

This phase adds exactly one new resolver-driven ambient state to an already-mature, well-factored architecture (`IslandResolver.swift`, `NotchWindowController.swift`, `CalendarService`/`CalendarGlance.swift`). Every piece this phase needs already has a direct, on-disk precedent to mirror: `FocusModeMonitor` for a monitor's idempotent `start()`/`stop()` shape, `nowPlayingWings`/`focusWings` for the wing-view pattern, `EqualizerBars`' `TimelineView(.animation(paused:))` for a lifecycle-gated per-tick UI refresh (already resolved into a concrete mechanism by `41-UI-SPEC.md`), and `resolve()`'s existing ambient branch (`nowPlayingLaunchGate` → `.nowPlayingWings` → `.idle`) for where the new ranked-ambient-pair logic slots in.

The one genuinely new piece of engineering is the countdown's own scheduling: unlike every other monitor in this codebase (`PowerSourceMonitor` is IOKit-event-driven, `BluetoothMonitor` is IOBluetooth-event-driven, `FocusModeMonitor` polls because it has no alternative), the countdown has no low-level OS push for "a calendar event is about to start." `PITFALLS.md` Pitfall 7 (already researched for this exact phase) mandates one-shot timers scheduled to the actual next-relevant-instant (minute boundary is NOT actually the right unit here — see Open Questions), never a perpetual 60s repeater. EventKit does provide a genuine push signal for "the calendar data itself changed" (`NSNotification.Name.EKEventStoreChanged`), which this codebase does not yet use anywhere — adopting it here removes the need for any polling loop at all for the "did a new event just get added inside the lookahead window" case.

**Primary recommendation:** Add `CalendarCountdownMonitor` (mirrors `FocusModeMonitor`'s idempotent lifecycle shape, but event/deadline-driven, never polling), a new Foundation-only pure selection function in `CalendarGlance.swift`, and extend `IslandResolver`'s existing single-ambient-case branch into a checked-ordered pair (Countdown before Now-Playing, per D-01) — all additive, no existing case/function signature needs to change shape beyond `resolve(...)` gaining one new optional parameter.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Countdown priority vs. Now-Playing (D-01) | Pure Resolver (`IslandResolver.swift`) | — | The resolver is this project's single arbiter (Pitfall 6) — all ranking logic lives here, never in the view or controller |
| Event selection ("next not-yet-started event within 1hr") | Pure Data Seam (`CalendarGlance.swift`) | — | Mirrors `nextRelevantEvent(events:now:)`'s existing Foundation-only, framework-free, `now`-as-parameter discipline |
| EventKit fetch + permission | Data Source (`CalendarService`/`EventKitService`) | — | Already shipped (Phase 14/28); this phase adds at most one new sibling method, no new permission flow |
| Minute-boundary / event-start scheduling, re-arm-on-dismiss (D-09) | Controller Glue (`CalendarCountdownMonitor`, owned by `NotchWindowController`) | — | Mirrors `FocusModeMonitor`'s "one file touches the fragile/timing-sensitive system surface" isolation discipline |
| mm:ss live display refresh | SwiftUI View (`NotchPillView.swift`, new `countdownWings(for:)`) | — | Already resolved by `41-UI-SPEC.md`: `TimelineView(.periodic(from:by:1))` scoped to the wing's own mount lifecycle, mirroring `EqualizerBars` |
| Settings toggle (D-03) | View (`SettingsView.swift`) + Controller (`ActivitySettings.swift` key) | — | Established per-activity `@AppStorage` pattern, identical shape to `focusKey`/`osdSuppressionKey` |

## Standard Stack

### Core

No new third-party dependencies. This phase is 100% Apple-owned frameworks already linked in the project:

| Component | Source | Purpose | Why Standard |
|-----------|--------|---------|--------------|
| `EventKit` | Apple framework, already linked (Phase 14) | Calendar event fetch | Already the project's calendar data source; no alternative considered |
| `Foundation` (`DispatchSourceTimer`/`Timer`, `Calendar`, `Date`) | Apple framework | One-shot deadline scheduling | Matches `FocusModeMonitor`/`PowerSourceMonitor`'s existing timer/event-source conventions exactly |
| `SwiftUI` `TimelineView(.periodic(from:by:))` | Apple framework, macOS 15+ (project's deployment floor) | mm:ss live text refresh | Already resolved as the mechanism in `41-UI-SPEC.md`; mirrors `EqualizerBars`' `TimelineView(.animation(paused:))` precedent |
| `NSNotification.Name.EKEventStoreChanged` | Apple framework (EventKit) [CITED: developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/ekeventstorechanged] | Push signal for "calendar data changed" | Removes the only remaining reason this monitor would need to poll at all — not currently used anywhere else in this codebase (verified via grep, zero hits) |

**Installation:** none — no `project.yml` / SPM changes required for this phase.

**Version verification:** N/A — no package versions to pin; all APIs are part of the OS SDK already targeted (macOS 15.0 floor per `CLAUDE.md`, build machine on Tahoe/Xcode 26.6 per project memory).

## Package Legitimacy Audit

Not applicable — this phase adds zero external packages. Every API used (`EventKit`, `Foundation`, `SwiftUI`) is an Apple system framework already linked in the project. No `slopcheck`/registry verification is required.

## Architecture Patterns

### System Architecture Diagram

```
EventKit (EKEventStore)
        │  fetchUpcoming()-style query (existing EventKitService pattern)
        ▼
CalendarCountdownMonitor (new, owned by NotchWindowController)
        │  applies pure nextUpcomingEvent(events:now:lookahead:) selection
        │  schedules exactly ONE DispatchSourceTimer at the next relevant instant:
        │    - event enters 1hr lookahead → fire then
        │    - event start (dismiss + D-09 re-arm) → fire then
        │    - EKEventStoreChanged notification → re-check immediately (no polling)
        ▼
onChange(CalendarCountdownActivity?) closure
        │  (mirrors handleFocusChange/handleNowPlaying's exact wiring shape)
        ▼
NotchWindowController.calendarCountdown state → renderPresentation()
        │
        ▼
resolve(..., calendarCountdown: CalendarCountdownActivity?) — PURE arbiter
        │  ambient branch: countdown (D-01, always wins) → else nowPlayingWings → else idle
        ▼
IslandPresentation.calendarCountdown(activity)
        │
        ▼
NotchPillView.countdownWings(for:) — icon left (urgencyColor), TimelineView mm:ss right (urgencyColor)
```

### Recommended Project Structure

No new files/folders beyond what mirrors existing siblings:

```
Islet/
├── Notch/
│   ├── IslandResolver.swift        # + IslandPresentation.calendarCountdown case, resolve() param, CalendarCountdownActivity struct
│   ├── CalendarCountdownMonitor.swift   # NEW — mirrors FocusModeMonitor.swift's shape
│   ├── NotchWindowController.swift # + calendarCountdown @Published state, startCalendarCountdownMonitor(), handleCalendarCountdownChange()
│   └── NotchPillView.swift         # + countdownWings(for:) in the presentation switch (~line 776), + case in switcher-row switch if needed (it isn't — see below)
├── Calendar/
│   └── CalendarGlance.swift        # + nextUpcomingEvent(events:now:lookahead:) pure function
├── ActivitySettings.swift          # + calendarCountdownKey (default ON per D-03)
└── SettingsView.swift              # + Toggle("Calendar Countdown", isOn: $calendarCountdownEnabled)
```

### Pattern 1: Ranked-ambient-pair resolver extension (D-01)

**What:** `resolve(...)`'s existing ambient branch is exactly two lines today:
```swift
// Source: Islet/Notch/IslandResolver.swift (current, pre-Phase-41)
let ambient = nowPlayingLaunchGate(hasPlayedSinceLaunch: hasPlayedSinceLaunch, nowPlaying: nowPlaying)
if ambient != .none { return .nowPlayingWings(ambient) }   // D-02 ambient yield (rank 3)
return .idle
```
D-01 requires Countdown to unconditionally win this slot whenever both would apply. The minimal, resolver-idiomatic extension (matches this file's own "TOTAL pure reducer" discipline — no new branching complexity, just one new check ordered first):
```swift
// Recommended shape — add ONE new optional parameter to resolve(...):
if let countdown = calendarCountdown { return .calendarCountdown(countdown) }  // D-01: always wins the ambient slot
let ambient = nowPlayingLaunchGate(hasPlayedSinceLaunch: hasPlayedSinceLaunch, nowPlaying: nowPlaying)
if ambient != .none { return .nowPlayingWings(ambient) }
return .idle
```
**When to use:** This is the ONLY place D-01's priority rule should be expressed — never as a suppression flag checked inside `NowPlayingMonitor` or the view layer (Pitfall 6).
**Note on D-02 (song-change toast unchanged):** `songChangeToastGate(...)` is a deliberately standalone function (not threaded through `resolve(...)`, see its own doc comment) that only reads `activeTransient`/`isExpanded`/`toastEnabled` — it has no ambient-tier input at all today, so D-02's "toast keeps firing unchanged" requires **zero code change** to that function. Confirm this explicitly in the plan rather than re-deriving it — it falls out for free.

### Pattern 2: Monitor lifecycle — mirror `FocusModeMonitor`, but deadline-driven not polling

**What:** `FocusModeMonitor` is the closest existing precedent for "one file isolates a fragile/timing-sensitive system surface behind `init(onChange:)` + idempotent `start()`/`stop()` + `nonisolated func stop()` callable from a `nonisolated deinit`." `CalendarCountdownMonitor` should mirror this exact shape, but its `start()` must NOT arm a repeating poll timer the way `FocusModeMonitor.start()` does (that file polls only because Focus/DND genuinely has no better signal — Calendar does, via `EKEventStoreChanged`).
```swift
// Source: Islet/Notch/FocusModeMonitor.swift (existing, for the LIFECYCLE shape only —
// do NOT copy its polling `t.schedule(deadline: .now(), repeating: 2.5, ...)` call)
@MainActor
final class FocusModeMonitor {
    private nonisolated(unsafe) var timer: DispatchSourceTimer?
    private nonisolated(unsafe) var running = false
    private let onChange: (Bool) -> Void
    init(onChange: @escaping (Bool) -> Void) { self.onChange = onChange }
    func start() { guard !running else { return }; running = true; /* ... */ }
    nonisolated func stop() { timer?.cancel(); timer = nil; running = false }
}
```
**When to use:** `CalendarCountdownMonitor`'s `start()` should instead: (1) register an `NSNotificationCenter` observer for `.EKEventStoreChanged` that triggers an immediate re-check, (2) run one initial re-check, (3) each re-check computes the single next relevant instant (see Pattern 3) and reschedules exactly one `DispatchSourceTimer`/`Timer` for that instant — cancelling any prior one first, mirroring `scheduleActivityDismiss()`'s own cancel-then-reschedule discipline in `NotchWindowController.swift`.

### Pattern 3: Compute-next-relevant-instant, not minute-boundary polling

**What:** Pitfall 7 (already researched for this phase) says "schedule exactly one timer firing at the next relevant instant... not a perpetual 60s repeating timer." For this feature there are exactly three kinds of "next relevant instant," and the monitor's re-check function should compute whichever is soonest:
1. No countdown active, but a future event exists beyond the 1hr lookahead → fire at `event.start - 3600s` (the exact moment it enters the window).
2. Countdown active (event within 1hr, not yet started) → fire at `event.start` (dismiss instant, D-09 re-arm point).
3. No events found at all in the fetch window → arm NO timer; rely purely on `EKEventStoreChanged` to wake the monitor again (this is the case that most needs the notification-driven design — without it, a newly-created event would never be noticed until some other trigger).

**Note — the mm:ss *display* still needs a per-second tick, but that is `41-UI-SPEC.md`'s `TimelineView(.periodic(from:by:1))`, scoped to the view's own mount lifecycle, entirely separate from this monitor's own scheduling.** Do not conflate the two: the monitor's timer only ever fires 0-2 times per event (arm + dismiss), never once a second.

### Pattern 4: Pure event-selection function (mirrors `nextRelevantEvent`)

**What:** `nextRelevantEvent(events:now:)` in `CalendarGlance.swift` already establishes the exact shape to mirror — Foundation-only, `now` always an explicit parameter, total (never crashes on empty input). It is NOT directly reusable as-is because it deliberately includes in-progress events (`end > now`, even if `start <= now`) — 41-CONTEXT.md's canonical_refs section flags this explicitly. Add a sibling function:
```swift
// Recommended addition to Islet/Calendar/CalendarGlance.swift, mirroring nextRelevantEvent's
// exact signature/total-function/now-as-parameter discipline:
func nextUpcomingEvent(events: [EventInput], now: Date, lookahead: TimeInterval = 3600) -> EventInput? {
    events
        .filter { $0.start > now && $0.start <= now.addingTimeInterval(lookahead) }
        .sorted { $0.start < $1.start }
        .first
}
```
**When to use:** Called by `CalendarCountdownMonitor` after fetching raw events — see Open Questions for how the monitor obtains the raw `[EventInput]` array (this function needs the raw list, not the already-reduced `CalendarGlance`).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Detecting a newly-created/edited calendar event without waiting for the next poll | A tight/aggressive re-poll interval (e.g. every 30-60s "just in case") | `NotificationCenter.default` observer on `.EKEventStoreChanged` | Zero polling cost, immediate reactivity, standard EventKit idiom [CITED: developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/ekeventstorechanged] |
| Computing "next full-minute boundary" for a display refresh | A hand-rolled `Date` arithmetic helper | `TimelineView(.periodic(from: .now, by: 1))` (already resolved in `41-UI-SPEC.md`) | SwiftUI already provides exactly this scoped-clock primitive; hand-rolling risks re-litigating the idle-CPU trap `EqualizerBars`' own header comment warns against |
| Priority arbitration between Countdown and Now-Playing | A suppression flag inside `NowPlayingMonitor` or a view-layer `if` | `resolve(...)`'s single ambient branch (Pattern 1) | Pitfall 6 — every new HUD type must route through the one pure arbiter, no exceptions, "including ones that feel trivial" |

**Key insight:** every piece of "don't hand-roll" guidance here is really the same instruction restated for three different sub-problems: this codebase has already paid down the cost of building the general mechanism (resolver, `TimelineView` gating, `now`-as-parameter pure functions) — this phase's entire job is applying those mechanisms, not inventing new ones.

## Common Pitfalls

### Pitfall 1: Perpetual/naive polling timer for the countdown (Pitfall 7, already researched)
**What goes wrong:** A `Timer`/`DispatchSourceTimer` firing every 60s unconditionally, or gated only on "is Islet running" rather than "is there actually an event within the lookahead window."
**Why it happens:** "A per-minute countdown feels like it obviously needs a per-minute timer" (verbatim from `PITFALLS.md`).
**How to avoid:** Pattern 3 above — compute and schedule exactly one deadline at a time, reschedule on every fire/re-check.
**Warning signs:** Activity Monitor → Energy → Idle Wake Ups shows non-trivial Islet wakeups with no calendar event imminent (this phase's own Success Criterion #3's verification method).

### Pitfall 2: Reusing `nextRelevantEvent(events:now:)` unmodified
**What goes wrong:** That function returns an event that may have ALREADY STARTED (`start <= now`, only gated on `end > now`) — feeding its result straight into the countdown would show a negative or already-elapsed remaining time, or worse, arm the countdown for an event that should have already dismissed.
**Why it happens:** It's the existing, obviously-related function sitting right next to where new code would be added, and its name ("next relevant event") sounds like exactly what's needed.
**How to avoid:** Add the new `nextUpcomingEvent(events:now:lookahead:)` (Pattern 4) with a `start > now` filter instead of reusing/mutating `nextRelevantEvent` — that function has its own existing callers (`refreshCalendar()` → `outfitState.calendar`, feeding the Calendar tab glance) that must keep their current in-progress-inclusive behavior unchanged.
**Warning signs:** Countdown showing `00:00` or a wrapped-negative time on appearance.

### Pitfall 3: Bypassing the resolver because the countdown "just needs a one-off suppression rule"
**What goes wrong:** Implementing D-01 as `if calendarCountdownActive { nowPlayingMonitor.pause() }` or an `@State` flag in `NotchPillView` instead of a resolver branch.
**Why it happens:** Pitfall 6 (already researched) explicitly names this exact temptation for HUDs that "feel too simple to need the full resolver machinery."
**How to avoid:** Pattern 1 — the priority check lives in `resolve(...)` only.
**Warning signs:** A HUD-specific `@State`/`@Published` toggle set directly from a monitor callback rather than from `resolve(...)`'s return value (the exact grep-for-this-pattern warning sign `PITFALLS.md` names).

### Pitfall 4: `EKEventStoreChanged` firing far more often than expected
**What goes wrong:** This notification fires on essentially ANY change to the Calendar/Reminders database, including changes from unrelated apps, sync churn, or Reminders-only edits — a naive handler that always does a full re-fetch + timer-reschedule on every fire could become its own minor wakeup source if the user's calendar syncs frequently.
**Why it happens:** The notification's payload carries no fine-grained diff — "something changed" is the entire signal.
**How to avoid:** The re-check triggered by this notification is still cheap (one EventKit query + one pure function call + at most one timer reschedule) — this is NOT the same class of problem as Pitfall 1's perpetual timer, but debounce/coalesce rapid-fire notifications (e.g. a `DispatchWorkItem` debounce of ~1-2s) if on-device testing shows bursts, mirroring `DropInterceptTap`'s own defensive-timer-reinstall precedent.
**Warning signs:** Activity Monitor Idle Wake Ups still elevated with no imminent event, but correlated with calendar sync activity rather than a perpetual internal timer.

### Pitfall 5: Countdown re-arm (D-09) racing the resolver's spring-wrapped render
**What goes wrong:** `scheduleActivityDismiss()` (the EXISTING transient dismiss mechanism) and this phase's NEW countdown dismiss timer are structurally similar but must stay fully independent — the countdown is ambient (D-01: "not as an `ActiveTransient`"), so it must never touch `transientQueue`/`scheduleActivityDismiss()` at all.
**Why it happens:** The existing dismiss pattern (`dismissWorkItem`, `activityDuration`) is the most visible precedent in the file, and it's tempting to reuse its plumbing wholesale for "yet another timed dismiss."
**How to avoid:** `CalendarCountdownMonitor`'s own dismiss/re-arm timer is entirely self-contained (Pattern 2/3) — the controller only reacts to its `onChange` closure output (mirrors `handleFocusChange`'s shape: mutate `@Published` state, call `renderPresentation()`, call `updateVisibility()`), it never calls `scheduleActivityDismiss()`, `transientQueue.enqueue(...)`, or reads `activityDuration`.
**Warning signs:** Countdown visually flickering or dismissing early/late when a Charging/Device transient also happens to be resolving around the same moment — a sign the two independent timer mechanisms are cross-wired.

## Code Examples

### Ambient-tier resolver extension (Pattern 1, full context)
```swift
// Source: Islet/Notch/IslandResolver.swift — resolve(...)'s existing signature (for reference,
// the new `calendarCountdown:` parameter is additive, default nil so existing call sites/tests
// compile unchanged where irrelevant):
func resolve(activeTransient: ActiveTransient?,
             nowPlaying: NowPlayingPresentation,
             nowPlayingHealthy: Bool,
             hasPlayedSinceLaunch: Bool,
             isExpanded: Bool,
             selectedView: SelectedView = .home,
             onboardingStep: OnboardingStep? = nil,
             pendingDrop: PendingDrop? = nil,
             calendarCountdown: CalendarCountdownActivity? = nil) -> IslandPresentation {
    // ... onboarding + activeTransient switch + isExpanded branch UNCHANGED ...
    if let countdown = calendarCountdown { return .calendarCountdown(countdown) }  // D-01
    let ambient = nowPlayingLaunchGate(hasPlayedSinceLaunch: hasPlayedSinceLaunch, nowPlaying: nowPlaying)
    if ambient != .none { return .nowPlayingWings(ambient) }
    return .idle
}
```

### New pure value type (mirrors `DeviceActivity`/`FocusActivity`'s Foundation-only shape)
```swift
// Recommended: Islet/Notch/IslandResolver.swift, alongside the other case-payload types.
// Foundation-only — no AppKit/SwiftUI — same discipline as every other IslandPresentation payload.
struct CalendarCountdownActivity: Equatable {
    let eventStart: Date   // the view computes mm:ss + urgency color from (eventStart - now)
}
```

### Countdown wing (icon left, mm:ss text right) — per `41-UI-SPEC.md`, mirrors `focusWings(for:)`
```swift
// Recommended: Islet/Notch/NotchPillView.swift, alongside focusWings(for:) (~line 2259)
private func countdownWings(for activity: CalendarCountdownActivity) -> some View {
    wingsShape(leftWidth: 118, rightWidth: Self.wingsSize.width / 2) {
        HStack(spacing: 0) {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(urgencyColor(for: activity.eventStart))   // D-05: recolors with the text
                .padding(.leading, 14)
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, activity.eventStart.timeIntervalSince(context.date))
                Text(formatMMSS(remaining))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(urgencyColor(for: activity.eventStart, at: context.date))
                    .padding(.trailing, 20)
            }
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Every existing monitor is either IOKit/IOBluetooth event-driven, or polls (`FocusModeMonitor`, no alternative) | This phase introduces the codebase's first EventKit-change-notification-driven monitor | This phase | Sets the precedent for any future EventKit-adjacent feature to prefer `.EKEventStoreChanged` over polling |
| Ambient tier has exactly one case (`nowPlayingWings`) | Ambient tier becomes a ranked, checked-ordered pair | This phase | `resolve(...)`'s ambient branch pattern (Pattern 1) is now the template for a THIRD ambient case if one is ever added later — keep the same "checked-ordered `if`, first-wins" shape rather than a priority-number field, since only two cases exist |

**Deprecated/outdated:** None — no existing code in this phase's touch surface is being replaced, only extended.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|----------------|
| A1 | `NSNotification.Name.EKEventStoreChanged` fires promptly and reliably enough on this project's target macOS (15+/Tahoe) to serve as the sole "new event detected" signal, with no fallback poll needed | Pattern 2/3, Don't Hand-Roll | If it fires unreliably or with meaningful latency on-device, a newly-created event inside the lookahead window could be missed until some unrelated trigger (app relaunch, another notification) — mitigation: the existing 900s `outfitRefreshTimer` already re-fetches calendar data as a coarse safety net for the unrelated Calendar-tab glance; the monitor could piggyback on that as a fallback re-check if on-device testing shows gaps, at the cost of a much larger detection-latency window than D-09 arguably wants for back-to-back events |
| A2 | Reusing `calendarService.fetchMonth(containing: Date())` (returns raw `[EventInput]`) as the raw-event source for the new `nextUpcomingEvent(...)` selection, rather than adding a new `CalendarService` protocol method, is the lower-risk/smaller-diff choice | Architecture Patterns, Recommended Project Structure | `fetchMonth` fetches only the CURRENT calendar month — an event scheduled for 23:xx on the last day of the month whose 1hr lookahead crosses into next month would be missed by a same-day-only `fetchMonth(containing: now)` call; this is an extreme edge case (specific hour, specific day-of-month) but the planner should decide explicitly whether to accept it or add a small dedicated fetch method instead (mirrors `fetchUpcoming`'s own 2-day predicate, which already handles this cleanly) |

**If this table is empty:** N/A — see above, both entries are genuine open implementation choices flagged for planner/discuss-phase confirmation, not verified facts.

## Open Questions

1. **How does `CalendarCountdownMonitor` obtain the raw `[EventInput]` list?**
   - What we know: `CalendarService.fetchUpcoming(completion:)` only returns an already-reduced `CalendarGlance?` (via `nextRelevantEvent`), not the raw fetched events; `fetchMonth(containing:completion:)` DOES return raw `[EventInput]` but is scoped to a calendar month and was designed for the month-grid view (Phase 28), not for a lookahead-window query.
   - What's unclear: Whether to (a) call `fetchMonth(containing: Date())` and filter/select via the new `nextUpcomingEvent` function (zero protocol changes, smallest diff, A2's edge case), or (b) add a new `CalendarService` protocol method that mirrors `fetchUpcoming`'s exact 2-day-predicate query shape but returns raw `[EventInput]` instead of a reduced `CalendarGlance` (clean 2-day window, no month-boundary edge case, but touches the `CalendarService` protocol + both its `EventKitService` conformer and any test doubles).
   - Recommendation: Option (b) is the more correct/robust shape given this project's existing "mirror the exact fetch shape, factor only the truly duplicated part" convention (see `mapToEventInput`'s WR-04 factoring precedent) — flag this explicitly for the planner to lock in Wave 1, since it determines whether `CalendarService.swift` is a touched file for this phase.

2. **Does the countdown need to re-fetch from EventKit on every dismiss (D-09), or can it reuse a recently-cached event list?**
   - What we know: D-09 requires "the monitor must re-check for the next relevant event on every dismiss, not only on the next scheduled minute-boundary tick" — i.e., a fresh EventKit query at the exact moment the current countdown's event starts.
   - What's unclear: Whether a fresh `EKEventStore` query at that instant is fast/cheap enough to run synchronously inside the dismiss timer's fire handler without a visible gap, or whether it should kick off the async fetch slightly before the dismiss instant (e.g. a few seconds early) so the result is ready by the time the dismiss fires.
   - Recommendation: `EKEventStore.events(matching:)` is a synchronous, in-memory-indexed local query (not a network fetch) once `requestFullAccessToEvents()` has already resolved `true` earlier in the app's lifetime (which it will have, by the time any countdown is active) — a fresh query fired exactly at the dismiss instant should be fast enough with no pre-fetch needed; confirm via the phase's own on-device UAT (Success Criterion #1's "updates continuously without user interaction" already implicitly covers this).

## Environment Availability

Skipped — this phase adds no new external tool/runtime/service dependency. `EventKit` access is already an established, already-authorized dependency from Phase 14/28 (not newly introduced here), and the Xcode/Swift toolchain is already verified for this project (see project memory: macOS 26/Tahoe, Xcode 26.6, Swift 6.3.3).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest, `IsletTests` target (defined in `project.yml`) |
| Config file | `project.yml` (XcodeGen), `IsletTests` scheme |
| Quick run command | `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` — **use `build`, NOT `test`** (project memory: `xcodebuild test` hangs headless because `IsletTests` is hosted inside the full `Islet.app`, which boots the `NSPanel`/`MediaRemote`/`IOBluetooth` stack) |
| Full suite command | Manual `Cmd-U` in Xcode (routes around the headless-hang gap above) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|---------------------|-------------|
| HUD-08 | `resolve(...)` returns `.calendarCountdown` ahead of `.nowPlayingWings` when both inputs are present (D-01) | unit | add to `IsletTests/IslandResolverTests.swift`, run via Cmd-U | ✅ file exists, ❌ new test case — Wave 0/1 |
| HUD-08 | `resolve(...)` never returns `.calendarCountdown` while `isExpanded == true` or while any `ActiveTransient` is present | unit | same file | ❌ new test case — Wave 0/1 |
| HUD-08 | `nextUpcomingEvent(events:now:lookahead:)` excludes already-started events, includes events exactly at the 1hr boundary, returns nil on empty/all-past input | unit | new `IsletTests/CalendarGlanceTests.swift` test cases (or extend an existing calendar test file if one exists) | ❌ Wave 0 — confirm whether a `CalendarGlanceTests.swift` already exists before creating a new file |
| HUD-08 | Live minute-countdown visible, correct icon/side placement, urgency color switch at 60s, no idle-wakeup regression, re-arm on back-to-back events | manual-only | on-device UAT (Activity Monitor Idle Wake Ups check per Success Criterion #3; wall-clock observation for #1/#2/#4) | N/A — cannot be automated (real EventKit calendar + real wall-clock timing + Activity Monitor) |

### Sampling Rate
- **Per task commit:** `xcodebuild ... build` (compiles + runs no tests, per the headless-hang constraint above)
- **Per wave merge:** manual Cmd-U in Xcode for the full `IsletTests` suite
- **Phase gate:** Cmd-U green + the phase's own on-device UAT checkpoint (Activity Monitor Idle Wake Ups, live countdown observation) before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] Confirm whether `IsletTests` already has a `CalendarGlanceTests.swift` (grep found none as of this research pass — `nextRelevantEvent`/`daysInMonth`/`events(on:events:)` appear to have no dedicated test file yet); if absent, this phase's Wave 0 should create one covering both the pre-existing untested pure functions AND the new `nextUpcomingEvent` (small, in-scope addition, not scope creep — the new function lives in the same file and the same testing gap applies)
- [ ] No framework install needed — `IsletTests` target and XCTest are already fully configured

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|----------------|---------|-------------------|
| V2 Authentication | No | Not applicable — local single-user macOS app, no auth surface touched |
| V3 Session Management | No | Not applicable |
| V4 Access Control | No | Not applicable — EventKit's own OS-level TCC permission is the access boundary, already enforced/granted in Phase 14/28, unchanged by this phase |
| V5 Input Validation | Yes | `EKEvent.title`/event data is already established as UNTRUSTED external data in this codebase (T-14-06, `CalendarService.swift` file header) — this phase does NOT render the event title on the collapsed pill at all (D-06), so the countdown wing has strictly LESS untrusted-data exposure than the existing Calendar tab, not more. No new validation surface. |
| V6 Cryptography | No | Not applicable |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| Malicious/oversized event title from a subscribed calendar causing a rendering issue | Denial of Service (minor) | Already mitigated project-wide: not applicable to THIS phase specifically since D-06 means the countdown never renders the title at all — only `eventStart: Date` is consumed, which cannot carry adversarial string content |
| A flapping/rapidly-changing calendar (many `EKEventStoreChanged` fires) used to induce excess wakeups | Denial of Service (minor, local-only) | Pitfall 4's debounce recommendation — not a security boundary in the traditional sense (single-user local app, no remote attacker), but worth the same defensive-coalescing discipline `DropInterceptTap`'s health-check-timer already establishes |

## Sources

### Primary (HIGH confidence)
- Direct codebase reads (this session): `Islet/Notch/IslandResolver.swift`, `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/NotchPillView.swift`, `Islet/Notch/FocusModeMonitor.swift`, `Islet/Notch/DropInterceptTap.swift`, `Islet/Notch/PowerSourceMonitor.swift`, `Islet/Calendar/CalendarService.swift`, `Islet/Calendar/CalendarGlance.swift`, `Islet/ActivitySettings.swift`, `Islet/SettingsView.swift`, `IsletTests/IslandResolverTests.swift`, `project.yml`
- `.planning/research/PITFALLS.md` Pitfalls 5, 6, 7 — already researched for this exact phase, directly load-bearing for this document's timer-scheduling and resolver-routing recommendations
- `.planning/phases/41-calendar-countdown-hud/41-CONTEXT.md`, `41-UI-SPEC.md`, `41-DISCUSSION-LOG.md` — locked decisions and already-resolved UI mechanism

### Secondary (MEDIUM confidence)
- [EKEventStoreChanged | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/ekeventstorechanged) — WebSearch-surfaced, official Apple docs URL confirming the notification name and basic firing semantics; not independently verified via Context7 or on-device in this session (flagged as A1 in Assumptions Log for the reliability/latency claim specifically, not the existence/name of the API)

### Tertiary (LOW confidence)
None used — every non-codebase claim in this document is either tagged `[CITED: ...]` with an official Apple docs URL or explicitly logged in the Assumptions table.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, every component already linked and precedented in this exact codebase
- Architecture: HIGH — every pattern recommended has a direct, read, on-disk precedent in this codebase (not inferred from general SwiftUI/macOS knowledge)
- Pitfalls: HIGH — Pitfalls 5/6/7 were already researched specifically for this phase in a prior research pass (`PITFALLS.md`); this document only adds the concrete implementation-level pitfalls (2, 4, 5) that follow from applying those to this phase's actual code shape

**Research date:** 2026-07-18
**Valid until:** 30 days (stable, native-framework-only phase; no fast-moving external dependency to go stale)
