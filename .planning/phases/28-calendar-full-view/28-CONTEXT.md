# Phase 28: Calendar Full View - Context

**Gathered:** 2026-07-13
**Status:** Ready for planning

<domain>
## Phase Boundary

A third notch view — month grid + selected day's event list, reached via a new 3-icon switcher pill (Home / Tray / Calendar) below the expanded island — alongside a lightweight quick-add that can create either a calendar event or a reminder. The full view and the existing `expandedIdle` "next event" glance both read through the existing `CalendarService`/`EventKitService` layer (Phase 14) rather than duplicating fetch/mapping logic. Reminders is new surface area for this codebase (no existing `EKReminder` code, no Reminders Info.plist keys) and gets its own lazy, first-use permission request — not folded into the already-shipped Phase 26 onboarding flow.

Out of scope: full calendar CRUD (edit/delete/recurring, multi-calendar management — Out of Scope table in REQUIREMENTS.md), `EventKitUI`/`EKEventEditViewController` (confirmed no macOS availability), gesture-based swipe navigation between views (deferred to v2), any change to the existing `expandedIdle` glance's own content/layout.

</domain>

<decisions>
## Implementation Decisions

### View switcher (new UI, not previously scoped in any prior phase's build)
- **D-01 (LOCKED):** A 3-icon switcher pill (Home / Tray / Calendar) sits below the expanded island, Droppy-style — the active view highlighted. This resolves the deferred idea from `25-CONTEXT.md` ("3-icon view-switcher pill... likely home: Phase 28"), which flagged this as a new navigation capability, not a material question.
- **D-02:** Today's codebase has no Home/Tray "view switching" at all — `IslandPresentation` (`IslandPresentationState.swift`/`IslandResolver.swift`) is a single-arbiter enum switched over in `NotchPillView`, and the Phase 24 shelf is rendered *additively* (grows the pill height by `shelfRowHeight` whenever `shelfViewState.items` is non-empty) on top of whatever presentation is active — it is not its own presentation case. The Calendar Full View should become a new `IslandPresentation` case (e.g. `.calendarExpanded`), and the switcher pill's "Tray" icon most likely needs to force-reveal the shelf strip as its own selectable state rather than only appearing when items exist. Exact reconciliation between "switcher selects Tray" and "shelf auto-grows on drop" is Claude's/planner's discretion — must not break Phase 24's existing auto-expand-on-drop behavior.

#### Addendum — 28-04 round 4 (on-device UAT, user-confirmed decision reversal)

During 28-04's Task 3 on-device UAT checkpoint (round 4), the user reported two real bugs and
requested a genuine, explicitly-confirmed scope expansion beyond this phase's original locked
design (confirmed via the orchestrator's clarifying questions before implementation — not a
guess):

1. **Resolver precedence bug fixed:** `IslandResolver.resolve(...)`'s `isExpanded` branch
   checked Now-Playing BEFORE `selectedView`, so once `nowPlaying != .none` (true even while
   merely PAUSED) Calendar became permanently unreachable via the switcher — "clicking
   Calendar shows nothing" / "navigation disappears during music". Explicit switcher selection
   (Calendar, Weather) is now checked BEFORE Now-Playing in `resolve(...)`.
2. **"Smart Home" — a DELIBERATE REVERSAL of this phase's earlier research note.**
   `.planning/research/inspiration/notes.md` originally stated: "Islet should **keep its
   current default** (date/time/weather/calendar), not copy [Droppy's] Now Playing default."
   The user re-decided this ON-DEVICE during round 4: **Home now shows Now-Playing controls
   when something is playing, and falls back to the idle date/time glance when nothing is
   playing** — i.e. Home itself became "smart" the way Droppy's own default view already is,
   but ONLY for Home; selecting Tray/Calendar/Weather is never hijacked by Now-Playing. This
   was confirmed explicitly via the orchestrator's clarifying question before any code was
   written, per this project's deviation-authorization discipline (a locked decision may only
   be reversed with explicit, traceable user re-confirmation, never silently overwritten).
3. **New 4th switcher tab: Weather**, user-specified order Home / Tray / Calendar / Weather
   (the existing three left untouched, Weather simply appended). Weather is
   **current-conditions-only** (see `28-UI-SPEC.md`'s "Weather full view" section) — no
   forecast fetch was added; whether a real forecast is wanted is an open follow-up question
   for the user, not decided in this round.
4. A visual restyle pass was applied to the calendar full view — see `28-UI-SPEC.md`'s
   "28-04 round 4 visual pass" note for the Droppy-reference-image caveat (the images
   `notes.md` cites for the calendar grid/switcher do not actually exist in
   `.planning/research/inspiration/` — all 31 files on disk are Settings screenshots).

#### Addendum — 28-04 round 5 (on-device UAT, real Droppy reference screenshots + further UX fixes)

The user attached two GENUINE Droppy notch-overlay screenshots this round (the switcher pill
+ month grid — unlike round 4, which only had 31 Settings screenshots to work from), plus
reported one real functional regression and one further scope refinement:

1. **Calendar grid too spacious, event list too cramped (visual density fix, using the new
   real references).** The round-4 circular-badge visual language was confirmed correct by the
   real screenshots, but the cell SIZE was not — Droppy's grid is small/tight/numeral-only and
   claims a smaller width fraction than the day-list column. `NotchPillView.calendarCellSize`/
   `calendarCellGap` shrunk from 28×28pt/4px to 18×18pt/2px, which both matches the reference
   density and automatically frees width for the day-list column (see `28-UI-SPEC.md`'s
   round-5 density note).
2. **Misclick / notch-close bug switching between tabs (D-02 root-cause fix, not cosmetic).**
   Diagnosed root cause: `blobShape`'s content box used a PER-CASE height (144pt for
   Home/Weather/NowPlaying, 266pt for Calendar), and the switcher row is stacked immediately
   after that content in the same VStack — so the switcher pill's on-screen Y position shifted
   by ~122pt depending on which tab was active, and a click landing where it USED to be (before
   the reflow settled) could miss it and collapse the island instead of switching tabs. Fixed
   by making `blobShape` itself force every switcher-row presentation to ONE shared content
   height (`NotchPillView.switcherContentHeight`, renamed from `calendarContentHeight` and
   recomputed for the new grid density: 196pt), so the switcher pill's screen position is now
   PERFECTLY CONSTANT across every tab switch. `positionAndShow`'s separate `calendarFrame`
   panel-geometry reservation and `visibleContentZone`'s `isCalendarActive`-only branch both
   collapsed into their respective shared-height equivalents (simplification, not just an
   addition — matches this project's own repeated lesson from 3 prior "mismatched reserved
   height" bug classes this session: shelf, onboarding, calendar-round-2).
3. **Tray should show ONLY the files, like Droppy's own File-Tray page (D-02 amendment #2).**
   User: the current "select Tray -> force-reveal the small additive shelf strip under
   whatever Home showed" behavior (28-03/28-04's original D-02 reconciliation) does not match
   what they wanted — explicit Tray selection should show a DEDICATED, focused files-only view,
   mirroring Calendar/Weather's own dedicated resolver cases. `IslandResolver.swift` gained a
   new `.trayExpanded` case, checked at the SAME priority tier as Calendar/Weather (before
   Now-Playing). `ShelfViewState.forcedByTray` — the flag the old reconciliation depended on —
   is now dead code and was removed: since Tray always resolves to `.trayExpanded`, no OTHER
   presentation's additive shelf strip can ever observe a `forcedByTray` flag anymore. Phase
   24's auto-reveal-on-drop (a dropped file appearing under Home/Calendar/Weather/NowPlaying
   when NOT on Tray) is UNCHANGED — it only ever depended on `ShelfViewState.isVisible`'s
   `!items.isEmpty` half, never on `forcedByTray`.

### Quick-add: Event vs. Reminder + permission timing
- **D-03 (LOCKED):** Quick-add lets the user choose per-entry: Calendar Event or Reminder (CALVIEW-03, both literally required).
- **D-04 (LOCKED):** The Reminders (`EKReminder`/`EKReminderStore`) permission prompt fires lazily, the first time the user picks "Reminder" in quick-add — not during onboarding (Phase 26 is already shipped and scoped to only Bluetooth/Calendar/Location) and not eagerly at app launch. Mirrors `LocationProvider`'s existing lazy-request-on-first-use pattern.
- **D-05:** This requires adding both `NSRemindersUsageDescription` and `NSRemindersFullAccessUsageDescription` to `project.yml` (repo root) — neither key exists today (confirmed via scout: zero `EKReminder` references anywhere, only Calendar keys present at project.yml L62-65).
- **D-06 (confirmed, no new work needed):** Calendar event creation needs **no new entitlement** — `EventKitService` already calls `store.requestFullAccessToEvents()` (full read/write access, not the deprecated read-only `requestAccess(to:)`), so `EKEventStore.save(_:span:)` works under the existing granted access once the user has gone through the flow once (glance already triggers this on first launch).

### Month grid / day list interaction
- **D-07 (LOCKED):** Selecting a day in the month grid filters the day list on the right to that day's events (Droppy reference: grid left, "Today" list right). On open, today is selected by default.
- **D-08 (LOCKED):** The month grid supports prev/next month navigation (not locked to the current month only).

### Claude's Discretion
- Exact switcher-pill visual treatment (icon set, spacing, active-state highlight styling) — Droppy reference exists (`.planning/research/inspiration/notes.md` §"Default/home view + view switcher"), exact SwiftUI layout is a planning/UI-phase decision.
- Whether `CalendarService`/`EventKitService` gets a new protocol method (e.g. `fetchMonth(...)`) alongside the existing `fetchUpcoming`, or whether month-range fetching is built as a separate method on the same conformer — CALVIEW-04 requires no duplicated date/event logic, but the exact seam shape is implementation judgment, informed by `CalendarGlance.swift`'s existing pure/framework-free `nextRelevantEvent(events:now:)` convention (Foundation-only, `now` always passed explicitly, never `Date()` internally — the month-view's own day-bucketing logic should follow the same discipline).
- Exact `IslandPresentation` case naming and how the switcher pill's selection state is wired into `IslandResolver`'s single-arbiter reducer.
- Exact empty-state copy/visual for a day with no events (CALVIEW-02) — an explicit empty state is required, exact wording/icon is Claude's discretion.
- Whether the switcher pill is visible in all `IslandPresentation` states or only when the island is expanded with no more time-sensitive activity showing (e.g., does it hide during Charging/Device/Now-Playing wings, matching SHELF-09's existing suppression precedent) — not discussed, needs research/planning judgment against the existing suppression pattern.
- New `EKReminder`-mapping types (mirroring `EventInput`/`CalendarGlance`'s plain-struct, untrusted-title-as-plain-String convention from T-14-06) — implementation detail.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements source
- `.planning/REQUIREMENTS.md` §"Calendar Full View" — CALVIEW-01 (third view alongside Home/Tray), CALVIEW-02 (explicit empty state), CALVIEW-03 (quick-add event or reminder, user's choice), CALVIEW-04 (shared EventKit service layer, no duplication)
- `.planning/REQUIREMENTS.md` §"Out of Scope" — full calendar CRUD explicitly excluded; `EventKitUI`/`EKEventEditViewController` confirmed unavailable on macOS, quick-add is hand-built SwiftUI calling `EKEventStore`/`EKReminder` directly
- `.planning/ROADMAP.md` §"Phase 28: Calendar Full View" (lines 397-407) — Goal, Depends on (none), 4 Success Criteria, "UI hint: yes"

### Design reference (Droppy competitor app)
- `.planning/research/inspiration/notes.md` §"Default/home view + view switcher (images 5, 10, 12)" — the 3-icon Home/Tray/[3rd slot] switcher pill; user explicitly wants the 3rd slot to be Calendar full view instead of Droppy's quick-launch-apps slot (already reflected in Out of Scope table)
- `.planning/research/inspiration/notes.md` §"Calendar full view (images 6-7)" — month grid + "Today" event list on the right (image 6), "New Task" quick-add popover + empty-state "No upcoming events" (image 7) — direct visual reference for D-07/D-08 and the quick-add/empty-state requirements

### Prior-phase decisions this phase builds on
- `.planning/phases/25-visual-material-theming-redesign/25-CONTEXT.md` §Deferred Ideas — the 3-icon view-switcher pill idea, explicitly flagged "Likely home: Phase 28... Surface this explicitly when discussing Phase 28" — resolved by D-01/D-02 in this phase.
- `.planning/phases/26-onboarding-flow/26-CONTEXT.md` D-01/D-02/D-03 — the existing permission-request sequencing/gating pattern (lazy, silent-degrade, per-permission) that D-04's Reminders lazy-ask follows, without reopening the already-shipped onboarding flow itself.

### Existing code this phase modifies/extends
- `Islet/Calendar/CalendarService.swift` — `CalendarService` protocol + `EventKitService` conformer. `fetchUpcoming(completion:)` (L19-54) is the existing single method; this phase adds new capability (month-range fetch, and reminder creation/fetch) to this same protocol/conformer per CALVIEW-04, rather than a parallel service.
- `Islet/Calendar/CalendarGlance.swift` — pure, Foundation-only seam (`EventInput`, `CalendarGlance`, `nextRelevantEvent(events:now:)`, D-04 from Phase 14). New pure day/month-bucketing logic for the grid should follow this file's existing "no `Date()`/`Date.now` inside, `now` always an explicit parameter" discipline (T-14 convention).
- `Islet/Notch/IslandPresentationState.swift` / `Islet/Notch/IslandResolver.swift` — the single-arbiter `IslandPresentation` enum + `resolve(...)` reducer `NotchPillView` switches over; the new Calendar Full View becomes a new case here (D-02).
- `Islet/Notch/NotchPillView.swift` — shelf's additive-strip mechanism (`shelfRowHeight`, `shelfViewState.items` non-empty check, L279/L323/L1022/L1087) that D-02's switcher-pill/Tray-selection interaction must reconcile with, without regressing Phase 24's auto-expand-on-drop behavior.
- `project.yml` (repo root, L62-65) — existing `INFOPLIST_KEY_NSCalendarsUsageDescription`/`INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription`; D-05 adds `INFOPLIST_KEY_NSRemindersUsageDescription`/`INFOPLIST_KEY_NSRemindersFullAccessUsageDescription`.

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Calendar/CalendarService.swift`'s `CalendarService` protocol/`EventKitService` — the one EventKit integration point (CALVIEW-04's mandated shared layer); already requests full (not read-only) Calendar access, so event quick-add needs no new entitlement work.
- `Islet/Calendar/CalendarGlance.swift`'s pure-seam convention (`EventInput`, Foundation-only, explicit `now:` parameter, deterministic/unit-testable) — the pattern the new month/day-bucketing logic should extend, not replace.

### Established Patterns
- **Protocol-isolation for fragile externals** (mirrors `LicenseService.swift`) — `CalendarService` is already isolated behind one `AnyObject` protocol with a single conformer; Reminders access should extend this same protocol/conformer, not introduce a second isolated service.
- **Single-arbiter presentation state** (`IslandResolver`'s `resolve(...)`, same principle as `syncClickThrough()` flagged in Phase 26's context) — any new "which view is showing" state must route through the existing single arbiter, not a parallel flag.
- **Lazy, silent-degrade permission requests** (`LocationProvider` D-01, Phase 26 D-01/D-03) — D-04's Reminders lazy-ask follows this exact precedent.
- **Untrusted external text passed through as plain `String`, never interpolated** (T-14-06) — any new Reminder-title handling must follow the same discipline as `EKEvent.title` today.
- **On-device iterative tuning is normal in this project** — exact switcher-pill sizing/spacing, month-grid cell sizing, etc. expected to be tuned after first implementation (Phase 7, 18, 20/21/23, 25, 26 precedent).

### Integration Points
- `CalendarService`/`EventKitService` — the sole EventKit integration point, extended (not duplicated) for month-range fetch + Reminder read/write.
- `IslandPresentationState`/`IslandResolver` — the sole integration point for adding the new Calendar Full View as a presentation case.
- `NotchPillView.swift`'s shelf-additive mechanism — the integration point the switcher pill's Tray-selection state must reconcile with.
- `project.yml` — the sole integration point for the 2 new Reminders Info.plist keys (D-05).

</code_context>

<specifics>
## Specific Ideas

- Droppy's month-grid + right-side "Today" list (image 6) and its "New Task" quick-add popover + empty state (image 7) are the direct visual references — see `.planning/research/inspiration/notes.md`.
- Droppy's 3-icon Home/Tray/[3rd slot] switcher pill (images 5, 10, 12) is the direct reference for D-01, with the 3rd slot substituted for Calendar per the user's earlier (Phase 25) explicit preference.

</specifics>

<deferred>
## Deferred Ideas

None beyond what's already captured as Claude's Discretion above — discussion stayed within phase scope.

</deferred>

---

*Phase: 28-Calendar-Full-View*
*Context gathered: 2026-07-13*
