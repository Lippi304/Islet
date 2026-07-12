# Phase 28: Calendar Full View - Research

**Researched:** 2026-07-13
**Domain:** EventKit (Calendar + Reminders), SwiftUI notch-hosted UI, single-arbiter presentation state
**Confidence:** MEDIUM-HIGH (existing codebase patterns are HIGH confidence — direct code read; EventKit Reminders API surface is MEDIUM — WebSearch cross-referenced against training knowledge, not Context7/official-docs-verified line-by-line since Apple's docs pages are JS-rendered and returned no fetchable content this session)

## Summary

This phase adds no new third-party dependency and no new architectural primitive — it is a pure extension of four already-established patterns in this codebase: (1) `CalendarService`/`EventKitService`'s protocol-isolation seam, extended with a month-range fetch and new Reminders methods; (2) `CalendarGlance.swift`'s pure, Foundation-only, explicit-`now`-parameter day-bucketing discipline, extended with month/day-grouping logic; (3) `IslandResolver`'s single-arbiter `resolve(...)` reducer, extended with a new `.calendarExpanded` case and a new "which view is selected" input; and (4) `LocationProvider`'s lazy-first-use permission pattern, replicated for `EKReminderStore`.

The one genuinely new mechanical challenge is the switcher pill's "Tray" selection: today, the shelf row is *purely* additive (`shelfViewState.items.isEmpty` gates both `blobShape`'s height growth and `NotchWindowController`'s click-through zone) — there is no notion of "shelf forced visible with zero items." Adding a switcher-driven force-reveal requires touching the same three call sites (`NotchPillView.body`'s outer `.frame`, `blobShape`'s `hasShelf` computation, and `NotchWindowController.visibleContentZone()`) that already share the `shelfItems.isEmpty` check today, or introducing a second boolean threaded to all three. This is the sharpest edge in the phase and deserves its own task-level attention, not just "add a case to the enum."

**Primary recommendation:** Extend `CalendarService`/`EventKitService` (not a new service) with `fetchMonth`/reminder methods; add `.calendarExpanded` as a new `IslandPresentation` case fed by a new `SelectedView` (Home/Tray/Calendar) input threaded into `resolve(...)`; reuse `navCircleButton`/`chipButton` for the switcher and quick-add chrome; gate the Reminders permission lazily behind the first "Reminder" quick-add tap, mirroring `LocationProvider.requestOnce`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Month-range event fetch | API/Backend-equivalent (`EventKitService`) | — | Same tier as existing `fetchUpcoming`; EventKit is the local "backend" this app talks to |
| Reminder create/fetch | API/Backend-equivalent (`EventKitService`) | — | Must live in the SAME conformer as calendar fetch per CALVIEW-04 (no second service) |
| Day/month bucketing (pure logic: which day is "today", which events fall on a given day, prev/next month math) | Business logic (`CalendarGlance.swift`-style pure seam) | — | Foundation-only, explicit `now:`, unit-testable — mirrors existing `nextRelevantEvent` |
| View-switcher selection state (Home/Tray/Calendar) | Client/View state (`IslandResolver`/`IslandPresentationState`) | Browser-equivalent (`NotchPillView` render) | Must route through the single arbiter, not a parallel flag (established convention) |
| Month grid / day list / quick-add rendering | Client/View (`NotchPillView.swift`) | — | Pure SwiftUI render layer, no logic beyond calling into the pure seam + service |
| Reminders permission timing | Client/View-triggered, Business-logic-gated | — | Lazy request fires from the quick-add UI action, mirrors `LocationProvider`'s on-demand pattern |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| EventKit | Apple framework, macOS 15.0 (project deployment target) | Calendar events + Reminders read/write | Already the sole calendar integration point in this codebase (`CalendarService.swift`); Reminders is the same framework, no new dependency |
| SwiftUI `LazyVGrid` | Ships with macOS SDK | Month grid (7-column day layout) | First-party layout primitive; new to this codebase but not a third-party dependency — UI-SPEC already confirms this |
| SwiftUI `Picker(.segmented)` | Ships with macOS SDK | Quick-add Event/Reminder toggle | Already used in this exact codebase (`SettingsView.swift:238-242`, Theming material-style picker) — reuse the established convention, don't hand-roll a custom segmented control |

### Supporting
None — no new SPM packages this phase. `DynamicNotchKit` (listed as an optional accelerator in the project's Technology Stack doc) is confirmed **not present** in this codebase (`grep -rn "DynamicNotchKit"` returns zero hits) — the project already committed to its own custom `NSPanel`/`NotchWindowController` shell (Phase 23), so this phase must extend that shell, not introduce DynamicNotchKit at this late stage.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extending `CalendarService`/`EventKitService` protocol | A parallel `ReminderService` | Rejected — CALVIEW-04 explicitly mandates one shared EventKit layer; a second service duplicates the store/permission-gating logic this phase must NOT duplicate |
| Hand-built month grid | `EventKitUI`/`EKEventEditViewController` | Confirmed by REQUIREMENTS.md "Out of Scope" — no macOS/AppKit availability for this UI kit; must hand-build |
| Force-reveal via a second bool threaded through 3 call sites | A `TraySelection` enum owned by `ShelfViewState` itself (`.hidden`/`.itemsOnly`/`.forced`) | Either works; the enum keeps the "hasShelf" predicate in ONE place (`ShelfViewState`) rather than duplicating a raw bool at each of the 3 sites — recommended over a bare bool for maintainability, but genuinely Claude's/planner's discretion per CONTEXT.md D-02 |

**Installation:** None — zero new packages, zero new `project.yml` package entries. Only 2 new Info.plist keys (`project.yml` build settings, not a package).

**Version verification:** N/A — no versioned package added. EventKit's `requestFullAccessToReminders()`/`requestWriteOnlyAccessToReminders()` API surface is confirmed introduced in iOS 17/macOS 14 (TN3153) — [ASSUMED: could not load Apple's JS-rendered doc content this session; cross-referenced via WebSearch snippets and training knowledge only]. Project's deployment target is already macOS 15.0 (bumped Phase 26), so these APIs are unconditionally available — no `#available` guard needed.

## Package Legitimacy Audit

**Not applicable — this phase adds zero new external packages.** All new capability (Reminders) is exposed via the `EventKit` system framework, already linked (no new `import` target dependency, no new SPM/CocoaPods/npm entry). The Package Legitimacy Gate protocol is skipped per its own scope ("whenever this phase installs external packages").

## Architecture Patterns

### System Architecture Diagram

```
User taps switcher pill (Home/Tray/Calendar icon)
        │
        ▼
NotchPillView (onSwitcherSelect closure) ──reports intent only──▶ NotchWindowController
                                                                          │
                                                            mutates new SelectedView state
                                                            (e.g. interaction.selectedView)
                                                                          │
                                                                          ▼
                                                     currentPresentation() calls resolve(...)
                                                     with the new selectedView input
                                                                          │
                                                                          ▼
                                                     IslandResolver.resolve(...) [pure]
                                                     — picks .calendarExpanded when
                                                       isExpanded && selectedView == .calendar
                                                                          │
                                                                          ▼
                                              presentationState.presentation (published)
                                                                          │
                                                                          ▼
                                          NotchPillView.body switch renders calendarExpanded view
                                                     │                              │
                                                     ▼                              ▼
                                         Month grid (LEFT)              Day event list (RIGHT)
                                         reads: monthDays(...)          reads: events(on: selectedDay,
                                         [pure, Foundation-only,        events:) [pure, same file]
                                          CalendarGlance.swift-style]
                                                     │                              │
                                                     └──────────────┬───────────────┘
                                                                    ▼
                                                    both fed by EventKitService.fetchMonth(...)
                                                    (controller calls this ONCE per month-nav,
                                                     writes results into a new @Published model)
                                                                    │
                                                                    ▼
                                                    EKEventStore (system Calendar DB)

Quick-add "+ Add" tap ──▶ inline popover (Event/Reminder segmented Picker)
        │
        ├─ "Event" selected ──▶ EventKitService.createEvent(...) ──▶ EKEventStore.save(_:span:)
        │                       (no new permission — full access already granted, D-06)
        │
        └─ "Reminder" selected ──▶ first tap ever? ──▶ EKEventStore.requestFullAccessToReminders()
                                    (lazy, mirrors LocationProvider.requestOnce)
                                         │
                                         ▼
                                    EventKitService.createReminder(...) ──▶ EKReminderStore.save(_:commit:)
```

### Recommended Project Structure

No new top-level folders — extend the existing `Islet/Calendar/` and `Islet/Notch/` folders in place:

```
Islet/
├── Calendar/
│   ├── CalendarService.swift      # EXTEND: add fetchMonth(...), createEvent(...),
│   │                               #   fetchReminders(...)/createReminder(...) to the
│   │                               #   SAME protocol/conformer (CALVIEW-04)
│   ├── CalendarGlance.swift       # EXTEND: add pure month/day-bucketing functions
│   │                               #   (e.g. daysInMonth(for:), events(on:events:))
│   │                               #   following the EXISTING now:-explicit-parameter discipline
│   └── ReminderInput.swift        # NEW (small): plain struct mirroring EventInput's
│                                   #   untrusted-title-as-String convention (T-14-06)
├── Notch/
│   ├── IslandPresentationState.swift  # EXTEND: add .calendarExpanded case
│   ├── IslandResolver.swift           # EXTEND: resolve(...) gains a selectedView input
│   ├── NotchInteractionState.swift    # EXTEND: add SelectedView enum + published field
│   │                                   #   (or fold into a new small published model,
│   │                                   #   mirroring shelfViewState's own separate-model precedent)
│   ├── NotchPillView.swift            # EXTEND: switcher pill row, calendarExpanded view,
│   │                                   #   quick-add popover — reuse navCircleButton/chipButton
│   └── NotchWindowController.swift    # EXTEND: wire switcher taps, force-reveal shelf logic,
│                                       #   currentPresentation() passes new selectedView input
```

### Pattern 1: Protocol-isolation extension, not a new service (CALVIEW-04)
**What:** Add new methods to the existing `CalendarService` protocol / `EventKitService` conformer rather than creating a `ReminderService`.
**When to use:** Any time a phase requirement explicitly forbids duplicated integration logic (CALVIEW-04's literal wording).
**Example:**
```swift
// Source: direct read of Islet/Calendar/CalendarService.swift (existing file, this phase extends it)
protocol CalendarService: AnyObject {
    func fetchUpcoming(completion: @escaping (CalendarGlance?) -> Void)
    // NEW — month-range fetch for the grid, same store/completion-on-main-thread contract:
    func fetchMonth(containing date: Date, completion: @escaping ([EventInput]) -> Void)
    // NEW — Reminders share the store's authorization umbrella but are their OWN entity type:
    func createReminder(title: String, dueDate: Date?, completion: @escaping (Bool) -> Void)
}
```

### Pattern 2: Pure day/month-bucketing, Foundation-only, explicit `now:` (T-14 discipline)
**What:** All "which day is this event on", "is this today", "what are this month's day cells" logic lives in a pure function taking an explicit reference date — never `Date()` inline.
**When to use:** Any new calendar math this phase adds (month grid cell generation, day filtering for the event list, prev/next month navigation).
**Example:**
```swift
// Source: mirrors existing Islet/Calendar/CalendarGlance.swift discipline (direct code read)
// NEW function this phase adds, following the SAME contract as nextRelevantEvent(events:now:):
func events(on day: Date, events: [EventInput], calendar: Calendar = .current) -> [EventInput] {
    events
        .filter { calendar.isDate($0.start, inSameDayAs: day) }
        .sorted { $0.start < $1.start }
}
```

### Pattern 3: Single-arbiter presentation extension
**What:** New "which view is showing" state is a new INPUT to `resolve(...)`, never a parallel `if` in `NotchPillView`.
**When to use:** Adding the Calendar Full View and Tray-force-reveal.
**Example:**
```swift
// Source: mirrors existing Islet/Notch/IslandResolver.swift resolve(...) signature (direct code read)
enum SelectedView: Equatable { case home, tray, calendar }   // NEW

func resolve(activeTransient: ActiveTransient?,
             nowPlaying: NowPlayingPresentation,
             nowPlayingHealthy: Bool,
             hasPlayedSinceLaunch: Bool,
             isExpanded: Bool,
             selectedView: SelectedView = .home,             // NEW input, defaulted for source-compat
             onboardingStep: OnboardingStep? = nil) -> IslandPresentation {
    if let step = onboardingStep { return .onboarding(step) }
    switch activeTransient {
    case .charging(let a): return .charging(a)
    case .device(let d):   return .device(d)
    case nil: break
    }
    if isExpanded {
        if !nowPlayingHealthy { return .nowPlayingExpanded(nowPlaying, healthy: false) }
        if nowPlaying != .none { return .nowPlayingExpanded(nowPlaying, healthy: true) }
        // NEW: selectedView only matters once nothing higher-priority is showing
        if selectedView == .calendar { return .calendarExpanded }
        return .expandedIdle   // covers .home AND .tray today (tray's OWN forced-reveal is
                                // a NotchPillView/blobShape-level concern, not a resolve() case —
                                // see Anti-Pattern below)
    }
    let ambient = nowPlayingLaunchGate(hasPlayedSinceLaunch: hasPlayedSinceLaunch, nowPlaying: nowPlaying)
    if ambient != .none { return .nowPlayingWings(ambient) }
    return .idle
}
```
**Note on Tray:** unlike Calendar, "Tray selected" is NOT modeled as its own `IslandPresentation` case in this sketch — the shelf already renders additively on top of whichever presentation is active (D-02 in CONTEXT.md flags this reconciliation as open). Recommendation: keep `.expandedIdle` as the base case when `selectedView == .tray`, and have `blobShape`'s `hasShelf` computation take an OR of `(!shelfItems.isEmpty || selectedView == .tray)` instead of only checking emptiness — this is the smallest change that satisfies "Tray force-reveals an empty shelf" without adding a redundant presentation case that duplicates `.expandedIdle`'s content.

### Anti-Patterns to Avoid
- **A second `if selectedView == .calendar` check inside `NotchPillView`'s body, alongside the `switch presentation`:** defeats the single-arbiter pattern this codebase has enforced since Phase 6 (COORD-01/D-05) — the view must stay a pure `switch`, never re-deciding precedence.
- **A parallel `ReminderService`:** violates CALVIEW-04 explicitly; would also duplicate the `EKEventStore` instance (two stores watching the same DB is wasteful and makes the single-conformer isolation pattern meaningless).
- **Fetching the whole visible month synchronously on every render:** `EventKitService.fetchMonth` should be called once per month-navigation (prev/next tap) or once on `.calendarExpanded` becoming active, written into a `@Published` model the view reads — never called from inside the SwiftUI body (mirrors `refreshCalendar()`'s existing controller-owned call site, not a view-triggered fetch).
- **Threading `Date()`/`Date.now` into any new month-math function:** breaks the T-14 unit-testability discipline this codebase has maintained since Phase 14 and tests (`CalendarGlanceTests.swift`) rely on.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Month/day-of-week grid math | A custom calendar-math library | `Foundation.Calendar` (`.current`, `.date(byAdding:to:)`, `.range(of:in:for:)`, `.component(.weekday, from:)`) | Foundation already provides everything needed (leap years, month lengths, first-weekday-of-month) — this codebase's own `nextRelevantEvent` already leans on `Calendar.current.isDate(_:inSameDayAs:)`, extend that habit |
| Event/Reminder creation UI | A custom modal window or `EKEventEditViewController` | Hand-built SwiftUI popover calling `EKEventStore`/`EKReminder` directly | `EKEventEditViewController` confirmed unavailable on macOS (REQUIREMENTS.md Out of Scope, already researched) |
| Segmented Event/Reminder toggle | A custom two-button HStack | SwiftUI `Picker(_:selection:).pickerStyle(.segmented)` | Already used in this exact codebase for an analogous toggle (`SettingsView.swift` Theming material picker) |
| Permission-request sequencing/state tracking | A new permission-manager abstraction | Direct `store.requestFullAccessToReminders()` call from the quick-add action, mirroring `LocationProvider.requestOnce`'s inline pattern | This codebase deliberately keeps each permission's request call colocated with its trigger, not centralized in a manager |

**Key insight:** Every piece of new logic this phase needs already has a same-shaped precedent somewhere in this codebase (day-bucketing → `CalendarGlance.swift`; lazy permission → `LocationProvider`; segmented picker → `SettingsView`; additive chrome row → shelf row). The main planning risk is NOT "what pattern to invent" but "which exact call sites the Tray-force-reveal touches" (see System Architecture Diagram note above) and "how much new state to add to `NotchInteractionState` vs. a new small `@Published` model" (mirrors the existing `shelfViewState`/`outfit`/`onboardingState` precedent of one small model per feature — a `CalendarViewState` holding `selectedDay`/`visibleMonth`/`monthEvents` is the natural shape, separate from `NotchInteractionState`).

## Common Pitfalls

### Pitfall 1: Reminders fetch has no async/await variant
**What goes wrong:** Calling `store.requestFullAccessToReminders()` (async, confirmed) and then reaching for an equally-modern async `fetchReminders` will fail to compile — `fetchReminders(matching:completion:)` is completion-handler-only (returns an opaque `Any` cancel-token, no async overload exists in EventKit as of this research).
**Why it happens:** Apple modernized the *authorization* request APIs in iOS 17/macOS 14 but left the older completion-based fetch API for reminders unchanged.
**How to avoid:** Wrap the completion-based fetch in a `withCheckedContinuation` if async call sites are desired, OR keep it completion-based to match `EventKitService.fetchUpcoming`'s own existing completion-handler shape (recommended — consistency with the existing method beats a partial async conversion).
**Warning signs:** A compile error looking for `await store.fetchReminders(...)`.

### Pitfall 2: Two Reminders Info.plist keys, easy to add only one
**What goes wrong:** Adding only `NSRemindersFullAccessUsageDescription` (the new granular key) without the legacy `NSRemindersUsageDescription` can still crash/silently fail on the first `EKReminder`/`EKReminderStore` touch, mirroring this exact codebase's own prior finding (`a1-bluetooth-usage-key-required` — a missing usage key hard-crashes at first API touch, not just a soft prompt failure).
**Why it happens:** Apple's EventKit TCC gate historically checked the legacy key even after adding the granular one; omitting the legacy key is a known trap other apps have hit.
**How to avoid:** Add BOTH `INFOPLIST_KEY_NSRemindersUsageDescription` and `INFOPLIST_KEY_NSRemindersFullAccessUsageDescription` to `project.yml` (already locked as D-05 in CONTEXT.md) — do not economize to one key.
**Warning signs:** Crash log containing "attempted to access privacy-sensitive data without a usage description" the first time `EKReminderStore`/`EKReminder` is touched (same crash signature as the Phase 6 Bluetooth finding).

### Pitfall 3: Tray-force-reveal breaking the auto-expand-on-drop regression guard
**What goes wrong:** `blobShape`'s `hasShelf`, `NotchPillView.body`'s outer `.frame`, and `NotchWindowController.visibleContentZone()` all independently check `shelfViewState.items.isEmpty` today. Changing only ONE of these three call sites to also account for "Tray forced open" desyncs the visible shape from the click-through hit-test zone — the exact class of bug the project's own `cr01-clickthrough-or-defeat-gotcha` memory warns about (an OR'd zone silently reintroduces the empty-shelf click-swallowing regression).
**Why it happens:** The three checks were written when "shelf visible" and "shelf has items" were the same fact; the switcher pill breaks that assumption.
**How to avoid:** Introduce ONE new source of truth (e.g. `shelfViewState.isForceVisible` or a computed `var isVisible: Bool { !items.isEmpty || forcedByTray }` on `ShelfViewState` itself) and route ALL THREE call sites through it — never patch one site with an inline OR.
**Warning signs:** Clicking where the empty shelf strip visually appears does nothing (click-through swallows it) even though the strip is rendered — the exact regression class from Phase 24's `CR-01` finding.

### Pitfall 4: Empty-state day list mistaken for a loading state
**What goes wrong:** `EventKitService.fetchMonth` settles asynchronously; if the day-list view can't distinguish "still loading" from "confirmed zero events," the CALVIEW-02 empty state may flash briefly on every day-switch even when events exist, or (worse) permanently show "No events today" before the fetch resolves.
**Why it happens:** `@Published var monthEvents: [EventInput] = []` defaults to empty, which is indistinguishable from "fetched, and there really are none" without an explicit loaded/not-loaded flag.
**How to avoid:** Model the month-events field as `[EventInput]?` (nil = not yet loaded) rather than defaulting to `[]`, mirroring `outfit.calendar: CalendarGlance?`'s existing nil-means-not-ready convention in this codebase — only render the CALVIEW-02 empty state once the optional is non-nil AND the filtered day slice is empty.
**Warning signs:** Empty state flashes on every switcher/day-nav tap even when Calendar access is granted and events exist.

### Pitfall 5: `EKReminder.title` treated differently from `EKEvent.title`
**What goes wrong:** `EKReminder.title` is the same untrusted-external-text risk class as `EKEvent.title` (T-14-06) — subscribed/shared reminder lists could carry adversarial strings. Forgetting to apply the same plain-`String`-only, no-interpolation-into-format/log/shell-string discipline reopens a closed security gap for the new entity type.
**Why it happens:** Reminders is new surface area (CONTEXT.md explicitly notes: "no existing `EKReminder` code"), so the T-14-06 discipline isn't automatically inherited — it must be deliberately re-applied.
**How to avoid:** The new `ReminderInput`-style plain struct should copy `EventInput`'s exact pattern: plain `String` field, `.lineLimit(1)`/`.truncationMode(.tail)` at render time, never interpolated into a shell/format/log string.
**Warning signs:** Code review should explicitly check the new Reminder-mapping code against `EventKitService.fetchUpcoming`'s existing T-14-06 comment.

## Code Examples

### Lazy Reminders permission request (mirrors LocationProvider.requestOnce)
```swift
// Source: pattern mirrors Islet/Location/LocationProvider.swift (direct code read) — the
// established "lazy, silent-degrade, first-use" shape this codebase already uses for
// Location, extended here for Reminders. D-04 (CONTEXT.md): fires ONLY on first "Reminder"
// quick-add tap, never at launch/onboarding.
func createReminder(title: String, dueDate: Date?, completion: @escaping (Bool) -> Void) {
    Task {
        let granted = (try? await store.requestFullAccessToReminders()) ?? false
        guard granted else {
            await MainActor.run { completion(false) }   // silent degrade, no retry/nag (D-01 precedent)
            return
        }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title                            // T-14-06: plain String, never interpolated
        reminder.calendar = store.defaultCalendarForNewReminders()
        if let dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: dueDate)
        }
        do {
            try store.save(reminder, commit: true)
            await MainActor.run { completion(true) }
        } catch {
            await MainActor.run { completion(false) }     // silent degrade on save failure too
        }
    }
}
```

### Month-range fetch (mirrors fetchUpcoming's existing shape)
```swift
// Source: mirrors Islet/Calendar/CalendarService.swift's existing fetchUpcoming (direct code
// read) — same predicate-based EKEventStore.events(matching:) call, widened date range.
func fetchMonth(containing date: Date, completion: @escaping ([EventInput]) -> Void) {
    Task {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        guard granted else { await MainActor.run { completion([]) }; return }
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            await MainActor.run { completion([]) }; return
        }
        let calendars = store.calendars(for: .event)
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end,
                                                  calendars: calendars)
        let events = store.events(matching: predicate).map { ek -> EventInput in
            var red = 1.0, green = 1.0, blue = 1.0
            if let rgb = ek.calendar.color.usingColorSpace(.deviceRGB) {
                red = Double(rgb.redComponent); green = Double(rgb.greenComponent); blue = Double(rgb.blueComponent)
            }
            return EventInput(title: ek.title ?? "", start: ek.startDate, end: ek.endDate,
                              colorRed: red, colorGreen: green, colorBlue: blue)
        }
        await MainActor.run { completion(events) }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `EKEventStore.requestAccess(to:completion:)` (read/write undifferentiated, deprecated) | `requestFullAccessToEvents()`/`requestWriteOnlyAccessToEvents()` (granular async) | iOS 17/macOS 14 (TN3153) | Already adopted in this codebase's `EventKitService` (uses `requestFullAccessToEvents`, D-06 confirmed) — Reminders should follow the SAME modern pattern (`requestFullAccessToReminders`), not the deprecated undifferentiated call |
| `nowplaying-cli`/direct MediaRemote dlopen | `mediaremote-adapter` bridge | macOS 15.4 (unrelated to this phase, documented in project's Technology Stack) | Not directly relevant to Phase 28, noted only because it establishes this codebase's precedent of tracking Apple's private/evolving API breakage closely |

**Deprecated/outdated:**
- `EKEventStore.requestAccess(to: .event, completion:)` — superseded by `requestFullAccessToEvents()`; this codebase already avoids it. Do not introduce it for Reminders either.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `requestFullAccessToReminders()`/`fetchReminders(matching:completion:)` exact signatures, and that both `NSRemindersUsageDescription` + `NSRemindersFullAccessUsageDescription` keys are required together | Standard Stack, Pitfall 1/2 | If the legacy key turns out unnecessary on macOS 15.0+ specifically, it's a harmless extra string — low risk. If a signature is subtly wrong (e.g. fetch predicate parameter name), a compile error surfaces immediately during planning/execution, self-correcting |
| A2 | `EKReminder.calendar = store.defaultCalendarForNewReminders()` is non-nil once Reminders access is granted (no explicit nil-check shown in example) | Code Examples | If nil on some system configs (no Reminders list configured), `save()` would throw — the example already wraps `save` in `do/catch` so this degrades to `completion(false)`, not a crash |
| A3 | The "second bool through 3 call sites" vs. "ShelfViewState.isVisible computed property" recommendation for Tray force-reveal | Pattern 3, Pitfall 3 | Purely a code-organization judgment call, explicitly flagged in CONTEXT.md as Claude's/planner's discretion — no functional risk either way as long as ALL THREE sites read the SAME source of truth |

**If this table is empty:** N/A — see above; none of these assumptions carry a functional risk beyond "extra Info.plist string" or "self-correcting compile error."

## Open Questions

1. **Exact `SelectedView`/switcher-state ownership: new field on `NotchInteractionState`, or a new sibling `@Published` model?**
   - What we know: every prior feature (shelf, onboarding, outfit) got its OWN small `@Published` model rather than growing `NotchInteractionState`; `NotchInteractionState` itself only holds `phase`/`collapsedNotchSize` today.
   - What's unclear: whether "which view is selected" is interaction-state-shaped (like `phase`) or feature-state-shaped (like `shelfViewState`).
   - Recommendation: follow the established precedent — a new small model (e.g. `ViewSwitcherState`) — for consistency, but this is genuinely a planner-level call, not a blocking unknown.

2. **Does month-navigation refetch on every prev/next tap, or does the controller prefetch adjacent months?**
   - What we know: `fetchUpcoming`'s existing 2-day window is small and refetched fresh each call; a month view's data volume is larger but still trivially small for a local EventKit query.
   - What's unclear: whether prefetching the next/prev month improves perceived snappiness enough to matter for a notch-sized UI (no user-facing loading spinner space).
   - Recommendation: start with fetch-on-navigate (simplest, matches existing `fetchUpcoming` call pattern); revisit only if on-device UAT shows a visible fetch-lag on month-nav taps (consistent with this project's established "tune after first on-device pass" convention).

## Environment Availability

Skipped — this phase has no NEW external tool/service/runtime dependency. EventKit (Calendar + Reminders) is an Apple system framework already linked via the existing `CalendarService.swift` import; no new SPM package, no new CLI tool, no new background service. The existing Xcode 26.6 / `xcodebuild` toolchain (already verified working in Phase 27) is unchanged.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing `IsletTests` target) |
| Config file | `project.yml` (XcodeGen-managed `IsletTests` target — no separate test config file) |
| Quick run command | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` (build-only gate — see Wave 0 Gaps) |
| Full suite command | Manual Cmd-U in Xcode (`IsletTests` scheme) — this project's established constraint: `xcodebuild test` hangs because the test target hosts the full `NSPanel`/MediaRemote/IOBluetooth-booting app (see project memory `xcodebuild-test-headless-hang`) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CALVIEW-01 | Third view (`.calendarExpanded`) is reachable via the switcher and renders month grid + day list | unit (pure `resolve(...)` reducer transition) + manual Cmd-U/on-device UAT for rendering | `xcodebuild build ...` (compiles) + Cmd-U `IslandResolverTests` (new cases) | ❌ Wave 0 — extend existing `IslandResolverTests` (file exists per Phase 6/17/18/26 precedent — verify exact name during planning) |
| CALVIEW-02 | Empty-state day renders explicit copy, not blank | unit (pure day-bucketing `events(on:events:)` returns `[]` for an empty day) | Cmd-U `CalendarGlanceTests` (extended) | ❌ Wave 0 — extend `IsletTests/CalendarGlanceTests.swift` |
| CALVIEW-03 | Quick-add creates either an Event or a Reminder per user choice | unit (pure input-mapping) + manual on-device UAT (real `EKEventStore`/`EKReminderStore` save cannot be unit-tested without a live store — mirrors `EventKitService`'s existing untested-by-XCTest live-store shape) | Cmd-U for any new pure mapping logic; manual UAT for the actual save round-trip | ❌ Wave 0 — new `ReminderInput`-mapping test file if a pure mapping function is extracted |
| CALVIEW-04 | Full view and Home-glance glance both call through `CalendarService`, no duplicated fetch/mapping logic | code-review / grep-based (structural, not a runtime test) | `grep -c "EKEventStore()" Islet/Calendar/*.swift` should remain `1` (single store instance) | N/A — structural check, not a test file |

### Sampling Rate
- **Per task commit:** `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug`
- **Per wave merge:** Full Cmd-U pass in Xcode (`IsletTests` scheme) — confirm all new + existing test methods pass
- **Phase gate:** Full suite green (via manual Cmd-U) before `/gsd:verify-work`, plus the on-device UAT checkpoints CALVIEW-01/02/03 require (switcher visibility, empty-state copy, quick-add round-trip, Reminders permission prompt timing) — these cannot be automated given the live EventKit store / real permission dialog involved, matching this project's established human-verify convention for permission-gated features (Phase 26 precedent).

### Wave 0 Gaps
- [ ] Confirm exact filename of the existing resolver test file (likely `IsletTests/IslandResolverTests.swift`) before extending it with `.calendarExpanded`/`selectedView` test cases.
- [ ] `IsletTests/CalendarGlanceTests.swift` — extend with new pure month/day-bucketing function tests (no new file needed, extend existing).
- [ ] No framework install needed — XCTest is already wired via the existing `IsletTests` target.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No auth surface in this phase |
| V3 Session Management | No | N/A |
| V4 Access Control | Yes (OS-level) | macOS TCC permission gates (`requestFullAccessToEvents`/`requestFullAccessToReminders`) — already the established access-control mechanism for this app's data access, no app-level access control needed beyond OS permission grants |
| V5 Input Validation | Yes | Quick-add title `TextField` — no format-string/shell injection risk since titles are only ever assigned to `EKEvent.title`/`EKReminder.title` properties (never interpolated into a command/log/URL) |
| V6 Cryptography | No | No new crypto surface |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Untrusted `EKEvent.title`/`EKReminder.title` from subscribed/shared calendars or reminder lists rendered/logged unsafely | Information Disclosure / Tampering (if ever shell-interpolated) | Plain `String` pass-through only, `.lineLimit`/`.truncationMode` at render time, never interpolated into format/log/shell strings — established T-14-06 discipline, extend identically to the new `ReminderInput` type |
| Over-broad permission scope requested before it's needed | Elevation of Privilege (UX-trust erosion, not a technical vuln) | Lazy, first-use-only permission requests (D-04) — never request Reminders access at app launch or during onboarding |

## Sources

### Primary (HIGH confidence — direct codebase reads)
- `Islet/Calendar/CalendarService.swift` — existing `CalendarService`/`EventKitService`, full-access-events pattern, main-thread completion contract
- `Islet/Calendar/CalendarGlance.swift` — pure day-bucketing discipline, explicit `now:` convention
- `Islet/Notch/IslandPresentationState.swift` / `IslandResolver.swift` — single-arbiter `resolve(...)` reducer shape
- `Islet/Notch/NotchPillView.swift` — `blobShape`, `shelfRow`, `navCircleButton`, `chipButton`, `shelfRowHeight`, outer `.frame` height computation
- `Islet/Notch/NotchWindowController.swift` — `currentPresentation()`, `visibleContentZone()`, `syncClickThrough()`, shelf-height click-through math
- `Islet/Location/LocationProvider.swift` — lazy first-use permission pattern
- `IsletTests/CalendarGlanceTests.swift` — existing XCTest conventions for the pure seam
- `project.yml` — existing Calendar Info.plist keys, deployment target 15.0, no Reminders keys present (confirmed via grep)
- `.planning/phases/28-calendar-full-view/28-CONTEXT.md` — locked decisions D-01 through D-08
- `.planning/phases/28-calendar-full-view/28-UI-SPEC.md` — approved visual/interaction contract

### Secondary (MEDIUM confidence — WebSearch, cross-referenced)
- [requestFullAccessToReminders(completion:) | Apple Developer Documentation](https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoreminders(completion:)) — page title/existence confirmed, full content not fetchable this session (JS-rendered)
- [TN3153: Adopting API changes for EventKit in iOS 17, macOS 14, and watchOS 10](https://developer.apple.com/documentation/technotes/tn3153-adopting-api-changes-for-eventkit-in-ios-macos-and-watchos) — page existence confirmed as the authoritative source for the granular-access API changes; content not directly fetchable this session, cross-referenced via search snippets

### Tertiary (LOW confidence — WebSearch summaries only, flagged for validation)
- [fetchReminders(matching:completion:) | Apple Developer Documentation](https://developer.apple.com/documentation/eventkit/ekeventstore/fetchreminders(matching:completion:)) — signature confirmed as completion-based via community examples (Medium, createwithswift.com), not the primary source page itself
- [Using Swift: A Guide to Adding Reminders in the iOS Reminder App with the EventKit API](https://medium.com/@rohit.jankar/using-swift-a-guide-to-adding-reminders-in-the-ios-reminder-app-with-the-eventkit-api-020b2e6b38bb)
- [Creating reminder lists with EventKit from your app](https://www.createwithswift.com/creating-reminder-lists-with-eventkit-from-your-app/)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; existing codebase patterns directly read
- Architecture: HIGH for the extension patterns (direct code reads of the exact files this phase touches); MEDIUM for the Tray-force-reveal exact mechanism (multiple valid implementations, flagged as planner discretion in CONTEXT.md)
- Pitfalls: MEDIUM-HIGH — Pitfalls 2/3/5 are grounded in this project's OWN documented prior incidents (memory files `a1-bluetooth-usage-key-required`, `cr01-clickthrough-or-defeat-gotcha`); Pitfall 1 is MEDIUM (EventKit API surface, WebSearch-sourced)

**Research date:** 2026-07-13
**Valid until:** 30 days (stable Apple framework APIs + a codebase whose own conventions are the primary source; re-verify Reminders API signatures against Xcode's actual header/autocomplete during Wave 0 if any doubt arises)
