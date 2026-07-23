# Architecture Research — v1.10 Live Activities Suite

**Domain:** Integration of 9 new Live Activities/HUDs + a Settings grid redesign into Islet's existing notch-overlay architecture
**Researched:** 2026-07-23
**Confidence:** HIGH (based on direct reading of the current codebase — `IslandResolver.swift`, `NotchWindowController.swift`, `ActivityCoordinator.swift`, `ActivitySettings.swift`, `SettingsView.swift`, `AppDelegate.swift`, and 4 representative Monitors: `CalendarCountdownMonitor`, `FocusModeMonitor`, `OSDActivity`, `ClipboardMonitor`)

This is not greenfield research — it is a direct extension of a fixed, already-proven convention. Every recommendation below traces to an existing pattern already shipped in this codebase; nothing here proposes new architectural machinery beyond two small, load-bearing generalizations (see "Required Resolver Generalization" below).

## Standard Architecture (as it exists today)

```
┌──────────────────────────────────────────────────────────────────────┐
│  System-surface Monitors (one per signal, Foundation+minimal-AppKit) │
│  PowerSourceMonitor · BluetoothMonitor · NowPlayingMonitor ·         │
│  FocusModeMonitor · CalendarCountdownMonitor · OSDInterceptor ·      │
│  AudioOutputMonitor · ClipboardMonitor(owned by AppDelegate)         │
├──────────────────────────────────────────────────────────────────────┤
│  NotchWindowController (owns all Monitors except Clipboard)          │
│    - starts/stops Monitors per ActivitySettings toggle               │
│    - feeds raw readings into pure mapping fns (deviceActivity(),     │
│      osdVolumeActivity(), etc.) or a Coordinator (DeviceCoordinator) │
│    - owns `transientQueue: TransientQueue` (mutable state)           │
│    - calls `resolve(...)` / `resolveSecondary(...)` every re-render  │
├──────────────────────────────────────────────────────────────────────┤
│  IslandResolver.swift — PURE, Foundation-only, unit-tested            │
│    IslandPresentation (enum) ← resolve(activeTransient, nowPlaying,  │
│      isExpanded, selectedView, calendarCountdown, pendingDrop, ...)  │
│    ActiveTransient (enum: charging/device/focus/osd)                 │
│    TransientQueue (struct: enqueue/preempt/advance/updateHead)       │
│    resolveSecondary(primary:nowPlaying:) → dual-bubble               │
├──────────────────────────────────────────────────────────────────────┤
│  NotchPillView (SwiftUI) — switches on IslandPresentation, renders   │
├──────────────────────────────────────────────────────────────────────┤
│  Settings: NavigationSplitView sidebar, 7 sections, @AppStorage      │
│  Menu bar: AppDelegate → NSMenu (Settings/Updates/Quit + Clipboard   │
│    flyout submenu, rebuilt in menuNeedsUpdate)                       │
└──────────────────────────────────────────────────────────────────────┘
```

### The two resolver "tiers" that already exist — and when the codebase uses which

This distinction is the single most important thing to get right for the 9 new features, and it is not spelled out anywhere as a named rule — it has to be read out of the code:

**Tier A — `ActiveTransient` / `TransientQueue` (Charging, Device, Focus, OSD).**
Used when an activity (1) arrives via a discrete event/reading, (2) needs de-dup or in-place refresh (`updateHead`) so a noisy source (rapid volume key presses, reconnect flaps) can't spam the collapsed slot, and/or (3) must be able to forcibly evict whatever is *currently standing* in the collapsed slot even if that thing never self-elapses. Point 3 is why `TransientQueue.preempt()` exists: Focus never auto-dismisses (`isPersistent == true`), so a later Charging/Device event must forcibly displace it rather than politely queue behind it forever. Every Tier-A case gets an explicit `case .xxx(let a) where !isExpanded: return .xxx(a)` line in `resolve()`'s `switch activeTransient` block, at a hand-chosen rank position.

**Tier B — Ambient, resolved directly in `resolve()`'s ambient branch (Calendar Countdown).**
Used when an activity is a live, continuously-recomputed derived fact fed into `resolve()` on every render (not something that "arrives" and needs FIFO handling). Because `resolve()` checks `switch activeTransient` *before* the ambient branch, Tier B activities get Charging/Device preemption **for free** — no `preempt()`, no `isPersistent` flag, no dismiss timer. When a Charging/Device splash clears, the ambient value simply gets re-read on the next render and reappears on its own. This is structurally simpler than Tier A and should be preferred whenever an activity doesn't need de-dup/rate-limiting.

Two of the milestone's collapsed-tier features (Meeting-HUD, Timer/Pomodoro) are session-length activities like Focus, not discrete self-elapsing announcements like Charging/Caps-Lock — they belong in Tier A. This has one real consequence flagged below.

## Required Resolver Generalization (small, load-bearing, not optional)

Today `TransientQueue.preempt()` and `ActiveTransient.isPersistent` are hardcoded to a single case:

```swift
mutating func preempt(_ t: ActiveTransient) -> Bool {
    guard case .focus = head else { return enqueue(t) }
    ...
}
extension ActiveTransient {
    var isPersistent: Bool {
        if case .focus = self { return true }
        return false
    }
}
```

Meeting-HUD and Timer/Pomodoro are both session-length (Focus-shaped, not Charging-shaped) — Focus's `preempt()`/`isPersistent` special-case must generalize from "is this `.focus`?" to "is `head.isPersistent`?" the moment the **second** persistent case is added. This is a small, mechanical, low-risk change (the `guard case .focus = head` line becomes `guard head?.isPersistent == true` and `isPersistent` gains one line per new case) — but it is real, load-bearing architecture work, not styling, and it should be attributed to whichever of Pomodoro/Meeting-HUD ships first (recommend Pomodoro, since it ships first in the proposed order and is simpler to validate the generalized path against before Meeting-HUD's call-detection uncertainty is layered on top). Flag this explicitly in that phase's plan — it is easy to miss because the current code "happens to work" with only one persistent case and gives no compiler signal that a second one needs the guard changed.

`TransientQueue.updateHead()`'s same-category switch also needs one new arm per self-updating new transient (Download-Progress's percent ticks, mirroring the existing `(.charging, .charging)` / `(.osd, .osd)` arms) — same shape, no design question.

## Per-Feature Integration Points

| # | Feature | Resolver tier | New Monitor? | New IslandPresentation / ActiveTransient case | Notes |
|---|---------|---------------|---------------|------------------------------------------------|-------|
| 1 | Meeting-HUD | **Tier A**, `isPersistent = true` | Yes — call/mic-mute detection is unknown territory, needs its own spike (mirrors the Volume/Brightness OSD-suppression precedent from v1.6) | `ActiveTransient.meeting(MeetingActivity)` | First collapsed-only HUD with an **interactive control** (mute toggle) — every existing Tier-A HUD is display-only. This is genuinely new interaction-pattern territory in `NotchPillView`, not just a new case; flag as its own risk, separate from the detection-mechanism risk. |
| 2 | Download-Progress | **Tier A**, self-elapsing (like Charging, not Focus) | Yes — `DispatchSource.makeFileSystemObjectSource` watching `~/Downloads` (grep confirms **zero** existing FSEvents/kqueue usage anywhere in the codebase — this is a genuinely new system-integration seam, not a variant of an existing one) | `ActiveTransient.download(DownloadActivity)` | Percent-refresh reuses the exact `updateHead` same-category-replace pattern Charging's % ticks already use. Needs research on distinguishing in-progress (`.download`/`.crdownload`) vs. completed files and computing % from size deltas. Rank position (where it sits relative to Charging/Device/Focus/OSD) is a product decision, not an architecture one — resolve() just needs one more explicit line. |
| 3 | Timer/Pomodoro | **Tier A**, `isPersistent = true` | **No** — there is no external system signal to isolate; this is pure app-owned state (mirrors `ShelfLogic`/`TrialLogic`'s "pure Foundation-only logic type" convention, not the Monitor convention). A lightweight ticking source for UI refresh only, owned directly by the controller like the existing dismiss-timer, is enough. | `ActiveTransient.pomodoro(PomodoroActivity)` | This is the phase that should carry the `preempt()`/`isPersistent` generalization (see above). Needs a start/stop UI trigger point — natural options are the new Quick Actions bar or a small popover; not itself an architecture decision, just needs a concrete home picked at phase-planning time. |
| 4 | Quick Notes + Obsidian export | **Expanded-view only** — new `SelectedView` case + dedicated `IslandPresentation` case, exactly mirroring the Tray precedent (28-04 round 5: Tray got its own resolver case rather than an additive strip) | **No** — text capture is user-typed, not a system signal | `IslandPresentation.quickNotesExpanded` | Data model parallels `ClipboardItem`/`ClipboardStore`/`ClipboardFileStore` (a `QuickNote` value + MRU store + simple file persistence) — but note PROJECT.md places this **in the notch** ("quick text capture in the notch"), unlike Clipboard History which was deliberately kept menu-bar-only in v1.9. **Concrete wrinkle:** `SelectedView` today has exactly 4 cases, and Phase 52's top-edge switcher layout hardcodes exactly 4 independently-configurable slot keys (`switcherSlotLeftOuterKey`/`LeftInner`/`RightInner`/`RightOuter`). Adding a 5th tab means either the top-edge switcher's 4-slot model needs to grow (real design/config work, not just a resolver change) or Quick Notes is deliberately reached some other way (e.g. from the pill switcher only, not the top-edge variant, or folded into an existing tab). Flag as a genuine integration point to resolve at phase-planning time, not purely mechanical. Obsidian export is a pure side effect (timestamped append to a fixed `.md` file at a user-chosen folder) — needs a security-scoped-bookmark pattern for folder access that doesn't exist anywhere in the codebase yet (`ShelfFileStore` writes to app-owned paths, not an arbitrary user-chosen folder); confirm the app's non-sandboxed status before assuming a plain `FileManager` append suffices. |
| 5 | Quick Actions bar | **Outside the resolver entirely** | No | None | A plain SwiftUI row rendered unconditionally in relevant expanded/collapsed states (or a `showsQuickActionsBar(for:)` boolean helper, mirroring the existing `showsSwitcherRow(for:)` shared-predicate pattern, if it needs to vary by presentation). Each button is a fire-and-forget system call (mic mute, display sleep, dark mode, screen lock) — no state machine, no Monitor. Configurable button selection is a small `CaseIterable` enum + a handful of independent `@AppStorage` keys, mirroring the switcher's per-slot key convention exactly. |
| 6 | Menübar-Overflow | **Outside the resolver entirely — not even in `NotchWindowController`'s domain** | Possibly a small new controller, but no `*Monitor` in the system-signal sense | None | Confirmed non-notch by the milestone brief. Lives in `AppDelegate`, the one place the codebase already has ownership-exception precedent (`ClipboardMonitor` is deliberately owned by `AppDelegate`, not the window controller — the doc comment on `ClipboardMonitor` calls this out explicitly as "the one deliberate ownership deviation"). Ice's actual "hide behind a chevron" mechanism (reordering/repositioning `NSStatusItem`s via a drag-in spacer item) is worth a short feasibility check before committing to an approach — it is the kind of private/undocumented-API-adjacent territory the project has flagged before (MediaRemote, Volume/Brightness OSD suppression). This is architecturally the most isolated of the 9 features and could be built without touching `NotchWindowController`/`IslandResolver` at all. |
| 7 | Caps Lock HUD | **Tier A**, self-elapsing (OSD-shaped) | Yes — but the simplest of the new Monitors: caps lock toggles are observable via `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)`, which is **event-driven**, not polling, and the codebase already uses the sibling `NSEvent.addGlobalMonitorForEvents` API elsewhere (drag-approach detection in `NotchWindowController`) — no new permission/entitlement territory expected | `ActiveTransient.capsLock(CapsLockActivity)` | Structurally the closest of the 9 to an existing precedent (milestone brief: "same shape as Focus Mode" — though the self-elapsing-vs-persistent choice should mirror OSD, not Focus, since a caps-lock press is a discrete announcement, not an ongoing session). |
| 8 | Update-Activity restyle | **No change** | No | None (existing case) | Confirmed zero new architecture — pure `NotchPillView` styling on an already-shipped case from Phase 40. |
| 9 | Coding-Progress | **Tier B (ambient)**, recommended over Tier A | Yes — file-watching, same `DispatchSource.makeFileSystemObjectSource` technique as Download-Progress, reading a Claude-Code-hook-written status file | New param on `resolve(...)`, mirroring `calendarCountdown:` exactly (e.g. `codingProgress: CodingProgressActivity? = nil`), checked in the ambient branch | The milestone brief leaves the tier choice open ("collapsed-HUD-tier or ambient entry"). Recommend ambient: it is a continuously-updating status readout (todo X of Y) with no discrete "arrival" to de-dup and no urgency to preempt anything beyond what the ambient tier already gives for free — adding it as a 3rd Tier-A persistent participant (after Focus and Pomodoro/Meeting) would be unjustified complexity for no behavioral gain. Needs its own short research step per the milestone brief (hook-event choice, file format). |

### Summary of the tier split

- **New Tier-A (TransientQueue) entries:** Caps Lock, Download-Progress, Meeting-HUD, Timer/Pomodoro — 4 new `ActiveTransient` cases, each one `resolve()` line + one `updateHead`/`isPersistent` consideration.
- **New Tier-B (ambient) entry:** Coding-Progress — 1 new `resolve(...)` parameter, no queue involvement.
- **New expanded-view-only entry:** Quick Notes — 1 new `SelectedView` case + 1 new `IslandPresentation` case, no collapsed-tier participation at all.
- **Entirely outside the resolver:** Quick Actions bar, Menübar-Overflow, Update-Activity restyle.

This is exactly proportional to the actual heterogeneity described in the milestone brief — nothing here invents a category the codebase doesn't already have a precedent for.

## Settings Grid Data Model

### The question

Map ~15-20 heterogeneous activities (existing: Charging, Device, Now Playing, Song-Change Toast, Calendar Countdown, Focus, OSD Volume, OSD Brightness, Auto-Update-Check; new: Caps Lock, Download-Progress, Timer/Pomodoro, Meeting-HUD, Quick Notes, Quick Actions bar, Menübar-Overflow, Coding-Progress, Update-restyle) to one uniform "toggle-able card with a mini live preview" — without building a plugin system this project will never need (no third-party extensibility is planned or implied anywhere in the milestone).

### Recommendation: a static array of a small value struct, not a protocol hierarchy

```swift
struct ActivityCardSpec: Identifiable {
    let id: String                    // == the existing ActivitySettings @AppStorage key, e.g. ActivitySettings.chargingKey
    let title: String
    let description: String
    let defaultOn: Bool
    let preview: ActivityCardPreview
}

enum ActivityCardPreview {
    case presentation(IslandPresentation)   // feed a canned/fake value into the SAME NotchPillView render code, scaled down
    case custom(() -> AnyView)              // escape hatch for features with no IslandPresentation case at all
}

let activityCards: [ActivityCardSpec] = [
    ActivityCardSpec(id: ActivitySettings.chargingKey, title: "Charging", description: "...",
                      defaultOn: true, preview: .presentation(.charging(.sample))),
    // ... one line per existing activity, unchanged behavior ...
]
```

Why this fits and a protocol/registry would not:

- **The list is fixed and small.** Every card that will ever exist is enumerable today by reading the milestone brief; nothing in this project loads activities dynamically, from a plugin folder, or from user-authored code. A `protocol ActivityDescriptor` with per-feature conforming types (`ChargingDescriptor`, `MeetingDescriptor`, ...) would add one file and one indirection layer per feature for zero behavioral gain over a literal array entry — this is exactly the "no new file for a value that could be one array literal" case the project's own YAGNI convention (visible throughout `ActivitySettings.swift`'s flat key-namespace style) already avoids elsewhere.
- **The toggle half is already solved.** `ActivitySettings` already centralizes every `@AppStorage` key as a `static let` string constant; `ActivityCardSpec.id` just reuses that existing constant directly — no new toggle abstraction needed, no risk of a card's toggle drifting out of sync with the controller's own `activityEnabled(...)` reads (which already key off these same constants).
- **The preview half reuses rendering code that already exists, rather than duplicating it.** Because `IslandPresentation` is already a single `Equatable` enum with one canonical SwiftUI render path (`NotchPillView`'s `switch presentation`), most cards' "live preview" is not a new view at all — it's the *same* view, fed a canned static case value, scaled down. Only the minority of genuinely non-resolver features (Quick Actions bar, Menübar-Overflow) need the `.custom(AnyView)` escape hatch, which is proportional to their genuine architectural difference, not an inconsistency to paper over.
- **Heterogeneity (Tier A / Tier B / expanded-only / non-resolver) collapses to the same two facts a card needs:** an on/off key and a small view. The tier distinction matters for *how the activity itself is wired into the resolver*, not for *what the Settings card needs to render it* — so the card model does not need to know or care which tier a given activity belongs to. This is the right level of abstraction: don't let resolver-internal complexity leak into the Settings layer.

**What NOT to build:** no `ActivityPlugin` protocol, no dynamic registration/discovery, no reflection over `IslandPresentation`'s cases, no generic "renderer registry." A flat array + a 2-case enum is the complete solution for a fixed, known, ~20-item list.

## Suggested Build Order

The milestone brief's own proposed order (Settings-Redesign → Caps Lock + Update restyle → Download-Progress → Timer/Pomodoro → Meeting-HUD → Quick Notes/Obsidian → Quick Actions bar → Menübar-Overflow → Coding-Progress) holds up against the architecture, with one addition (which phase pays down the `preempt()` generalization) and one dependency flag (Quick Notes vs. the 4-slot switcher).

**Does Settings-Redesign genuinely need to go first?**

Yes — not because of a hard technical blocking dependency (the `ActivityCardSpec` shape above is fully derivable from the *existing* ~9 activities alone, without needing any of the 9 new features built first to "discover" the abstraction), but because:

1. The abstraction is already fully specified by what's in the codebase today — deferring it to "build alongside the first 1-2 features, then generalize" buys no real design insight, since the shape doesn't change once Quick Actions bar/Menübar-Overflow's `.custom` case is accounted for (which was obvious from reading the milestone brief, not from having built either feature).
2. Building it alongside the first 1-2 features first, then generalizing, means retrofitting whatever ad-hoc Settings UI those first phases ship with — this project has already paid that exact cost once (v1.8's Settings redesign existed specifically to fix a Settings section that grew ad-hoc, one feature at a time, without a shared abstraction). Doing it "foundation-first" this time avoids repeating that.
3. Practically, "foundation-first" does **not** mean pre-building cards for features that don't exist yet — each new feature's phase still adds its own one-line `ActivityCardSpec` entry (+ its own `@AppStorage` key, exactly like every past phase already added its own key to `ActivitySettings.swift`: `calendarCountdownKey` in Phase 41, `focusKey` in Phase 38, etc.). The grid ships in its own phase showing only the ~9 existing activities; every subsequent phase's "wire it into Settings" step becomes a trivial, low-risk addition to an already-proven array, rather than a new one-off section.

**Recommended order, with the two architecture-driven refinements:**

1. **Settings-Redesign (foundation)** — `ActivityCardSpec` array + `ActivityCardPreview` enum, ported against the ~9 existing activities only. No new Monitor, no resolver change.
2. **Caps Lock HUD + Update-Activity restyle** — cheapest pairing: Caps Lock is the simplest new Monitor (event-driven `NSEvent` global monitor, direct precedent already in the codebase), Update-restyle is pure styling. Good low-risk phase to validate the new Settings-card-per-phase habit before harder features land.
3. **Download-Progress** — first genuinely new system-integration seam (FSEvents-style watching), self-elapsing Tier-A, no persistence-generalization concern.
4. **Timer/Pomodoro** — no Monitor at all (pure app state), but **this is the phase that should carry the `TransientQueue.preempt()`/`ActiveTransient.isPersistent` generalization** from a Focus-only special case to a general "any persistent transient" check, since Pomodoro is the second persistent-transient case and the simpler of the two remaining ones to validate the generalized path against (no unreliable-detection risk layered on top, unlike Meeting-HUD).
5. **Meeting-HUD** — needs its own spike (call + mic-status detection, per the milestone brief) and reuses the now-generalized preempt path from step 4. Also introduces the first **interactive** control inside a collapsed-only HUD (the mute toggle) — flag this as a second, independent risk axis from the detection-mechanism risk, since no existing Tier-A HUD has ever needed a tappable control while collapsed.
6. **Quick Notes + Obsidian export** — new expanded-view `SelectedView`/`IslandPresentation` case (Tray precedent) + a Clipboard-shaped data/file-store pair. **Resolve the 4-slot top-edge-switcher conflict at this phase's planning step**, before writing code — either the switcher's slot model grows past 4, or Quick Notes is deliberately reached a different way (pill switcher only, or folded into an existing tab). This is a real design decision, not something the architecture can silently absorb.
7. **Quick Actions bar** — static row, zero resolver coupling, lowest remaining technical risk; sequenced after Quick Notes per the brief mainly because button selection needs a product decision, not because of any dependency.
8. **Menübar-Overflow** — fully isolated from `NotchWindowController`/`IslandResolver`; could in principle be built in parallel with any of the above without conflict, but the `NSStatusItem` reordering mechanism (Ice's actual technique) deserves its own short feasibility check before committing to an approach, similar in kind to the Volume/Brightness OSD-suppression spike from v1.6.
9. **Coding-Progress** — new file-watching Monitor (same technique as step 3's Download-Progress, so building it after Download-Progress means the FSEvents pattern is already proven once), ambient-tier resolver integration (no queue changes), plus its own short research step for the hook-event/file-format contract.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Giving every new HUD its own bespoke resolver branch shape
**What people might do:** invent a slightly different resolve() integration style per feature (e.g. a special-cased `if capsLockActive { ... }` block outside the `switch activeTransient`/ambient-branch structure) because each feature "feels" a little different.
**Why it's wrong:** the codebase already has exactly two well-understood, precedented tiers (Tier A transient, Tier B ambient) that cover every one of the 9 features cleanly (see table above). A third ad-hoc shape adds a maintenance burden and breaks the "one arbiter" property (`COORD-01`) the resolver was built to guarantee.
**Do this instead:** classify each feature into Tier A or Tier B using the "does it need de-dup/rate-limiting or forced eviction of a non-self-elapsing occupant?" test, and follow that tier's existing code shape exactly.

### Anti-Pattern 2: A Settings "plugin" abstraction
**What people might do:** build a `protocol ActivityDescriptor`/registry so "any future activity" can self-register into the grid.
**Why it's wrong:** there is no future extensibility requirement anywhere in this project (no third-party activities, no dynamic loading) — this is speculative generality for a fixed, small, enumerable list, and it would duplicate the toggle-key and rendering machinery that `ActivitySettings` and `NotchPillView` already own.
**Do this instead:** the flat `[ActivityCardSpec]` array described above.

### Anti-Pattern 3: Treating every session-length HUD as Tier A by default
**What people might do:** since Meeting-HUD and Timer/Pomodoro clearly need Tier A (isPersistent), reflexively also put Coding-Progress there "for consistency."
**Why it's wrong:** Coding-Progress has no de-dup/rate-limiting need and no eviction concern the ambient tier doesn't already solve for free — adding a 3rd persistent-transient participant would be unjustified TransientQueue complexity (a 3-way `isPersistent` switch, more `preempt()` edge cases) for a feature that fits Tier B cleanly.
**Do this instead:** apply the same tier test per-feature; don't let "these two ended up in Tier A" bias the third.

## Integration Points Summary

| Boundary | Change required | Risk |
|----------|------------------|------|
| `IslandResolver.swift` (`resolve`, `ActiveTransient`, `TransientQueue`) | 4 new Tier-A cases + `preempt()`/`isPersistent` generalization + 1 new Tier-B parameter | Low-medium — mechanical per-case additions, one genuine generalization (flagged above) |
| `NotchWindowController.swift` | 4 new `start*Monitor()` functions following the exact existing idempotent-guard shape; 1 new pure app-state ticker (Pomodoro, no Monitor); wiring for the interactive Meeting-HUD mute control (new territory) | Medium — mostly boilerplate-shaped, Meeting-HUD's interactive control is the one genuinely new UI-wiring pattern |
| `ActivitySettings.swift` | ~9 new `@AppStorage` key constants, one per feature, following the exact existing convention | Low |
| `SettingsView.swift` | Replaced by the new grid (`ActivityCardSpec` array + card view), built against existing activities first, then one array entry added per new-feature phase | Low once the foundation phase lands |
| `AppDelegate.swift` | Menübar-Overflow logic added here (or a small sibling controller it owns), following the `ClipboardMonitor`-owned-by-AppDelegate ownership-exception precedent | Low architecturally, but the underlying `NSStatusItem` reordering mechanism needs its own feasibility spike |
| `ViewSwitcherState.swift` (`SelectedView`, 4-slot top-edge switcher) | Potential 5th case for Quick Notes — conflicts with Phase 52's hardcoded 4-slot config keys | Needs a design decision before Quick Notes' phase starts coding |
| New: Downloads-folder / Coding-Progress file watchers | First FSEvents-style (`DispatchSource.makeFileSystemObjectSource`) monitors in the codebase — confirmed zero prior usage | Medium — new system-integration seam, but a well-documented macOS API, not private/undocumented territory like MediaRemote or OSD suppression |
| New: Meeting-HUD call/mic detection | Genuinely unknown mechanism | High — explicitly flagged by the milestone brief as needing its own spike, same class of risk as v1.6's Volume/Brightness OSD suppression research |

## Sources

- Direct reading of the current Islet codebase (`/Users/lippi304/conductor/workspaces/notch/algiers/Islet/`): `Notch/IslandResolver.swift`, `Notch/ActivityCoordinator.swift`, `Notch/DeviceCoordinator.swift`, `Notch/NotchWindowController.swift`, `Notch/CalendarCountdownMonitor.swift`, `Notch/FocusModeMonitor.swift`, `Notch/OSDActivity.swift`, `Notch/ViewSwitcherState.swift`, `Clipboard/ClipboardMonitor.swift`, `ActivitySettings.swift`, `SettingsView.swift`, `AppDelegate.swift`.
- `.planning/PROJECT.md` — milestone goal statement, requirement history, per-phase shipped-scope notes (v1.0 through v1.9), including the v1.10 target-feature list and proposed phase order.
- Codebase-wide grep confirming no existing FSEvents/`makeFileSystemObjectSource` usage prior to this milestone (Download-Progress and Coding-Progress are both first-of-kind).

---
*Architecture research for: Islet v1.10 Live Activities Suite*
*Researched: 2026-07-23*
