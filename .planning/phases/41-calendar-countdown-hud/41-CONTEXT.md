# Phase 41: Calendar Countdown HUD - Context

**Gathered:** 2026-07-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Starting 1 hour before a real calendar event, the collapsed island pill shows a live countdown (calendar icon left, mm:ss remaining right), driven by its own persistent per-minute-boundary timer — never the shared 3s `activityDuration` auto-dismiss pattern every existing transient uses. The countdown participates in `IslandResolver` as a new **ambient** activity (the same tier Now-Playing already occupies), not as an `ActiveTransient`, so it automatically yields to every higher-priority transient (Charging, Device, Focus, OSD) for free by construction. This phase does not touch the expanded Calendar tab, does not build the dual-activity "main pill + secondary bubble" combination with Now-Playing (that's Phase 42, which depends on this phase existing as a proven single-winner case first), and does not add new EventKit fetching — `CalendarService`/`nextRelevantEvent()` (Phase 28) already provide the next relevant event.

</domain>

<decisions>
## Implementation Decisions

### Countdown vs Now-Playing priority
- **D-01:** Calendar Countdown ALWAYS wins the single ambient slot over Now-Playing (playing or paused) whenever both would otherwise apply. Now-Playing's ambient wings are suppressed for the duration the countdown is active — no time-based threshold, no "only near the end" nuance. Phase 42 later adds a secondary bubble so both can show at once; until then this is a hard override, not a negotiation.
- **D-02:** The Phase 18 song-change toast is UNCHANGED — it keeps firing independently of the ambient state (it already can appear over the idle glance today), including while the Countdown owns the ambient pill. No new suppression gate on `songChangeToastGate()`.
- **D-03:** Calendar Countdown gets its own Settings toggle, default ON — matches the established per-activity convention (Focus, OSD, Charging, Device are all default-enabled opt-out, not opt-in).

### Visual format & urgency
- **D-04:** Countdown text renders as `mm:ss` (e.g. "23:14"), not minutes-only. **Flag for research/planning:** this is in tension with `PITFALLS.md` Pitfall 7's already-researched timer-hygiene convention (one-shot timers scheduled to real minute boundaries, not per-second polling, to avoid idle-wakeup regressions). The underlying scheduling timer should stay minute-boundary-based per Pitfall 7; the live `mm:ss` *display* likely needs a separate, tightly-gated per-second UI refresh (e.g. a `TimelineView` bounded to only while the countdown pill is the active ambient presentation, mirroring `EqualizerBars`' existing `TimelineView(.animation(paused:))` gate-while-visible precedent) rather than a second always-running `Timer`. Researcher/planner must resolve the concrete mechanism — this is not a re-opened product question, just an implementation detail to get right.
- **D-05:** Urgency coloring, explicitly modeled on the iPhone Dynamic Island's Live Activity countdown convention: **orange** for the full countdown window, switching to **red** in the final minute before the event starts.
- **D-06:** Icon + time only on the collapsed pill — the event title is never shown there (matches the ROADMAP wording exactly). Title is only visible by expanding to the Calendar tab.

### Tap/click behavior
- **D-07:** Clicking the Countdown pill expands to Home — identical to Now-Playing's existing ambient click behavior today. No new deep-link-to-Calendar-tab special case.
- **D-08:** No hover-reveal. Hovering the Countdown pill does nothing extra (no tooltip, no title reveal) — consistent with D-06 (title never shown on the collapsed pill) and with every other ambient/idle state today.

### Back-to-back events
- **D-09:** When the current countdown dismisses at its event's start time, if another event starts within the next hour immediately after, the pill immediately re-arms for that next event rather than going idle first. The countdown monitor must re-check for the next relevant event on every dismiss, not only on the next scheduled minute-boundary tick.

### Claude's Discretion
- Exact SF Symbol choice for the calendar icon, and the precise mechanism for the mm:ss live-refresh (D-04's flagged tension) are left to research/planning.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Timer hygiene (already researched for this exact phase)
- `.planning/research/PITFALLS.md` Pitfall 7 (lines 164-183) — "Calendar countdown HUD ticking every minute for up to an hour becomes an idle-CPU/wake-up regression if it doesn't follow the project's existing timer-hygiene convention." Directly governs D-04's implementation tension: one-shot timers to real minute boundaries, gated to "only run while an event exists within the lookahead window," reuse the resolver-visibility gate for fullscreen suppression. Verification method specified: Activity Monitor's Idle Wake Ups column with no imminent event.
- `.planning/research/PITFALLS.md` Pitfall 5/6 (lines 122-176) — the dual-activity risk this phase deliberately does NOT solve (deferred to Phase 42), and the "one pure arbiter" invariant (every new HUD type routes through `IslandResolver`/`TransientQueue`, no view-layer bypass) that D-01/D-09 must respect.
- `.planning/research/PITFALLS.md` line 240/262 — Calendar countdown HUD's Nyquist verification checklist entry: Activity Monitor Idle Wake Ups check with no imminent event; one-shot rescheduling verified, not perpetual polling.

### Resolver architecture (ambient tier precedent)
- `Islet/Notch/IslandResolver.swift` — the single pure arbiter. `IslandPresentation.nowPlayingWings` (line 61) is the only existing "ambient" case (D-02 rank 3 ambient, sits below all `ActiveTransient` ranks). The Countdown's new ambient case must follow this exact shape: reached only in the `activeTransient == nil` branch (line 128+), after the `isExpanded` branch, so it automatically yields to Charging/Device/Focus/OSD by construction — no new priority-check code needed for that part.
- `Islet/Notch/IslandResolver.swift:195-197` — `songChangeToastGate()`, the standalone toast-suppression function D-02 confirms stays untouched.
- `Islet/Notch/IslandResolver.swift:178-180` — `nowPlayingLaunchGate()`, the precedent for a "TOTAL pure helper, `now`/gate always passed as an explicit parameter, never `Date()` inside" discipline the Countdown's own gate function should mirror.

### Calendar data (already shipped, Phase 28)
- `Islet/Calendar/CalendarService.swift` — `fetchUpcoming(completion:)` already returns the next relevant event via EventKit, with the established silent-degrade-on-permission-denial convention (D-03 in that file: settles `nil` on denial, never retries/nags).
- `Islet/Calendar/CalendarGlance.swift` — `nextRelevantEvent(events:now:)` (line 37) is the PURE, Foundation-only event-selection seam already in use for the existing Calendar/Weather glance. **Note for planner:** this function includes in-progress events (`end > now`, even if `start <= now`) — a countdown-to-start needs a narrower selection restricted to NOT-YET-STARTED events within the 1-hour lookahead; either adapt this function or add a new one, planner's call on the cleanest shape.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Calendar/CalendarService.swift` / `CalendarGlance.swift` — EventKit fetch + pure event-selection already exist; no new permission flow or EventKit integration needed, only a new selection function/adaptation for "next NOT-YET-STARTED event within 1hr."
- `EqualizerBars` (`Islet/Notch/NotchPillView.swift:2757`) — the existing precedent for a `TimelineView`-gated-while-visible continuous UI refresh, directly relevant to resolving D-04's mm:ss live-display tension without an ungated timer.
- `ActivitySettings`/`SettingsView.swift` — established per-activity `@AppStorage` toggle pattern (Focus, OSD, etc.) that D-03's new toggle should follow exactly.

### Established Patterns
- Ambient tier in `IslandResolver`: exactly one case today (`nowPlayingWings`), sits below all `ActiveTransient` ranks, above `.idle`. D-01 requires this tier to become a priority-ordered pair (Countdown > Now-Playing) rather than the resolver simply appending a second independent ambient case.
- "One pure arbiter" discipline (PITFALLS.md Pitfall 6): every new HUD type must route through `IslandResolver`, confirmed applicable here per D-01/D-09.
- Silent-degrade-on-permission-denial convention (`CalendarService.swift`, `Islet/Notch/DropInterceptTap.swift` health-check-timer pattern) — Calendar Countdown should degrade the same way if Calendar access is denied (no countdown ever appears, no nag).

### Integration Points
- `IslandResolver.swift`'s `resolve(...)` ambient branch (after the `isExpanded` block, currently just the `nowPlayingLaunchGate` check) is where the new Countdown-vs-Now-Playing priority (D-01) gets wired in.
- A new `CalendarCountdownMonitor` (mirroring `DropInterceptTap`'s idempotent `start()`/`stop()` lifecycle and health-check-timer precedent) is the natural home for the minute-boundary scheduling + re-arm-on-dismiss logic (D-09).

</code_context>

<specifics>
## Specific Ideas

- Urgency coloring is explicitly modeled on the iPhone Dynamic Island's own Live Activity countdown treatment: orange for the countdown, red in the final minute (D-05).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (The dual-activity combination with Now-Playing is already correctly scoped to Phase 42, not this phase, and was never proposed as in-scope here.)

</deferred>

---

*Phase: 41-Calendar Countdown HUD*
*Context gathered: 2026-07-18*
