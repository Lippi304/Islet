# Architecture Research

**Domain:** Islet v1.6 (Liquid Glass & System HUD Suite) — integrating 6 new feature groups into an existing native macOS notch-overlay app
**Researched:** 2026-07-15
**Confidence:** HIGH (all findings grounded in direct reads of the current codebase — `IslandResolver.swift`, `NotchWindowController.swift`, `NotchPillView.swift`, `ActivitySettings.swift`, `DeviceCoordinator.swift`, `PowerSourceMonitor.swift`, `AppDelegate.swift`, `NowPlayingState.swift`/`NowPlayingPresentation.swift`, `ViewSwitcherState.swift`, `CalendarService.swift`); MEDIUM on the two genuinely novel technical unknowns (Volume/Brightness OSD suppression, Focus Mode detection) since their private-API feasibility is out of this doc's scope — flagged, not solved, below.

## Existing System Overview (ground truth, v1.5 close)

```
┌──────────────────────────────────────────────────────────────────────────┐
│ AppDelegate (app lifecycle: status item, menu, Settings window, license) │
│   owns → NotchWindowController (the ONE @MainActor controller)           │
└───────────────────────────────┬──────────────────────────────────────────┘
                                 │ start()
┌────────────────────────────────▼───────────────────────────────────────┐
│                        NotchWindowController                            │
│  • owns EVERY live system monitor (PowerSourceMonitor, BluetoothMonitor,│
│    NowPlayingMonitor/NowPlayingService, WeatherKitService,              │
│    EventKitService, LocationProvider)                                   │
│  • owns EVERY *Coordinator (DeviceCoordinator today; the extraction     │
│    pattern behind the narrow `ActivityCoordinator` protocol)            │
│  • owns the bounded, de-duped TransientQueue (rank-1/2 splash sequencer)│
│  • is the ONLY caller of the pure `resolve(...)` reducer                │
│  • writes the verdict into IslandPresentationState.presentation (the    │
│    ONE @Published carrier NotchPillView observes)                       │
│  • is the SOLE show/hide site (updateVisibility) and the SOLE           │
│    click-through arbiter (syncClickThrough / visibleContentZone)        │
└───────────────┬───────────────────────────────────┬─────────────────────┘
                │ writes                              │ reads
┌────────────────▼───────────────┐   ┌────────────────▼───────────────────┐
│   PURE Foundation-only seams     │   │        @Published view models      │
│  IslandResolver.swift:           │   │  IslandPresentationState           │
│    resolve() — SINGLE arbiter,   │   │  NotchInteractionState             │
│    ranked reduce (Charging >     │   │  NowPlayingState / ChargingState   │
│    Device > NowPlaying) feeding  │   │  ShelfViewState / ViewSwitcherState│
│    TransientQueue                │   │  CalendarViewState / OnboardingVS  │
│  PowerActivity / DeviceActivity /│   └────────────────┬────────────────────┘
│  NowPlayingPresentation /        │                    │ observes
│  ShelfLogic — all unit-tested,   │   ┌────────────────▼────────────────────┐
│  zero AppKit/SwiftUI/IOKit       │   │            NotchPillView            │
└───────────────────────────────────┘   │  ONE switch over IslandPresentation │
                                          │  blobShape()/wingsShape() — shared  │
                                          │  islandFill material, shared        │
                                          │  matchedGeometryEffect "island"     │
                                          └──────────────────────────────────────┘
```

**The two invariants every one of the 6 integration points below must respect:**

1. **Single arbiter (COORD-01 / D-05).** `resolve(...)` in `IslandResolver.swift` is the ONE place priority is decided. Every new "does this show, and does it beat what's already showing" question must be answered inside this pure function (or a new pure function next to it), never as a scattered `if` in the controller or view.
2. **Pure-seam-first.** Every existing activity type (`PowerActivity`, `DeviceActivity`, `NowPlayingPresentation`) is a plain Foundation-only value + a total pure mapping function, unit-tested before any AppKit/SwiftUI/IOKit glue exists. New HUD types must follow the identical shape: `struct XReading` (raw, untrusted) → pure `xActivity(from:) -> XActivity?` → `XActivity` case inside `ActiveTransient`.

## Component Responsibilities (existing, for reference)

| Component | Responsibility | Pattern to reuse for new features |
|-----------|----------------|-------------------------------------|
| `IslandResolver.swift` (`resolve`, `ActiveTransient`, `TransientQueue`) | Pure ranking + bounded sequential queue for rank-1/2 transients | Add new `ActiveTransient` cases here for new HUD types that need to interrupt/queue |
| `NotchWindowController` | Owns every live monitor + coordinator, calls `renderPresentation()`/`updateVisibility()` after every mutation | New monitors constructed/started in `start()` exactly like `startPowerMonitor()`/`startBluetoothMonitor()`, toggle-gated via `ActivitySettings` |
| `*Coordinator` behind `ActivityCoordinator` (`DeviceCoordinator`) | Extracted, independently-testable bookkeeping for one activity's debounce/dedup/enqueue logic, wired via reach-back closures (TransientQueue is a value type) | New HUD types with non-trivial debounce logic (Volume scrub, Focus flap) get their own Coordinator; simple ones (Update-available) don't need one |
| `*Monitor` (`PowerSourceMonitor`, `BluetoothMonitor`, `NowPlayingMonitor`) | Thin, event-driven (never polling) system-framework glue; C callbacks hop to main before touching `@Published` | Template for `VolumeBrightnessMonitor`/`FocusModeMonitor` |
| `*State: ObservableObject` (`NowPlayingState`, `ChargingActivityState`) | Plain `@Published` holder, no methods/timers, one per activity axis, written ONLY by the controller | Template for any new orthogonal display state that shouldn't live inside `IslandPresentation` itself (song-toast precedent) |
| `NotchPillView` | Render-only — ONE switch over `IslandPresentation`, never decides precedence | New HUD wing views + Liquid Glass material plug in here, at existing shared call sites |

---

## Integration Point 1 — Liquid Glass Material

**What exists today:** `NotchPillView.swift` already has a SINGLE material seam. `private var islandFill: AnyShapeStyle` (line ~250) branches on `ActivitySettings.MaterialStyle` (`.gradient` / `.solidBlack`) and is the ONE property all 4 fill call sites read (`blobShape()`, `wingsShape()`, the standalone collapsed-pill fill, `mediaWingsOrToast`'s own custom-shape branch). This is exactly the Phase-25/27 "single source of truth" pattern the project already proved twice.

**Integration point:** Extend, don't replace.
- Add `case liquidGlass` to `ActivitySettings.MaterialStyle` (mirrors how `.solidBlack` was added alongside `.gradient` in Phase 27) — keeps the existing Settings picker pattern (`SettingsView`'s Theming section) working unchanged, just with a third option.
- Extend `islandFill`'s switch with the new branch using the user-supplied reference implementation.
- **Risk to flag:** if the reference "Liquid Glass" look needs more than a flat `ShapeStyle` value (e.g. a blur/specular-highlight overlay via `.background(.ultraThinMaterial)` + a gradient overlay + an edge highlight stroke — typical for a "glossy/frosted" look per the milestone's own description), `islandFill: AnyShapeStyle` is the wrong shape. In that case, convert the single-site pattern from a **value** (`ShapeStyle`) to a **view modifier**: `private func islandMaterialBackground<S: Shape>(_ shape: S) -> some View`, still called from the same 4 sites, still ONE definition. Do this conversion FIRST, before wiring the real Liquid Glass code in, so the plumbing change and the visual change are separate, verifiable diffs.

**New components:** None. **Modified:** `ActivitySettings.swift` (enum case), `NotchPillView.swift` (single `islandFill`/material seam).

**Why build this first:** every other v1.6 feature that renders a NEW wing/HUD (Volume, Brightness, Focus, Update, restyled Charging/Bluetooth) will call the SAME `wingsShape()`/`blobShape()` helpers and inherit whatever material is wired here for free. Building Liquid Glass after the new HUDs exist means retrofitting N+1 call sites instead of 1.

---

## Integration Point 2 — 7 New HUD Types: NOT one bucket, three different shapes

The milestone brief's own framing ("new resolver entries vs. a parallel HUD system") is a false binary once you separate the 7 by their actual *display semantics* — they are not architecturally uniform:

| HUD | Actual shape | Resolver treatment |
|-----|--------------|---------------------|
| **Bluetooth/AirPods restyle** | Same `.device(DeviceActivity)` case, same `DeviceCoordinator`, same `TransientQueue` slot — **zero resolver change** | Pure view-layer restyle of `wingsShape`'s device content |
| **Charging restyle** | Same `.charging(ChargingActivity)` case — **zero resolver change** | Pure view-layer restyle |
| **Focus Mode HUD** | New discrete, rare, binary event (on/off) — matches Device's shape exactly | NEW `ActiveTransient.focus(FocusActivity)` case, own pure `FocusActivity`/`focusActivity(from:)` seam (mirrors `PowerActivity.swift`), enqueued like a device connect |
| **Volume HUD** / **Brightness HUD** | High-frequency, continuous *scrub* events (holding the key repeats several times/sec) — **does NOT match Device/Charging's "rare + debounce" shape** | NEW `ActiveTransient.volume(...)`/`.brightness(...)` cases, but the monitor MUST call `TransientQueue.updateHead(_:)` (the existing in-place-refresh path the charging-% tick already uses) on every scrub tick, never `enqueue(_:)` fresh — `enqueue`'s dedup/bound logic was designed for rare events and would either spam re-renders or blow the `maxDepth` bound under rapid key-repeat |
| **Update-available HUD** | Rare, low-urgency, no natural "expiry" (an update sits available for days) — does NOT fit the ~3s transient-splash shape at all | **NOT a `TransientQueue` transient.** A simple orthogonal `@Published` badge flag (see Integration Point 5) |
| **Drop-session summary chip** | One-shot, ~2-3s, triggered by a UI action (closing Tray) not a system event — structurally identical to the already-shipped **song-change toast** (Phase 18) | **NOT threaded through `resolve()`/`IslandPresentation`** — reuses the Phase-18 pattern exactly: a separate `@Published` one-shot field + its own dismiss `DispatchWorkItem`, set by the controller, read directly by the view |

**Why NOT bolt all 7 onto `resolve()`'s switch uniformly:** the resolver's `switch activeTransient` + `TransientQueue` combo is correct and low-risk for 3 of the 7 (Focus, Volume, Brightness) because they genuinely ARE transients that must interrupt/queue like Charging/Device. It is actively wrong for Update-available (no queue semantics apply — it should never occupy or evict a splash slot) and redundant for the drop-session chip and both restyles (no new resolver state needed at all). Treating "new HUD" as synonymous with "new `IslandPresentation`/`ActiveTransient` case" would add resolver-switch bloat and 4 sets of unit tests for cases that don't need to participate in ranking at all.

**New pure files (mirror `PowerActivity`'s shape — struct + total mapping function, Foundation-only):**
- `Islet/Notch/FocusActivity.swift`
- `Islet/Notch/VolumeActivity.swift`, `Islet/Notch/BrightnessActivity.swift`

**Modified:** `IslandResolver.swift` (`ActiveTransient` gains 3 new cases — `.focus`, `.volume`, `.brightness` — plus their ranking position in `resolve()`'s existing `switch activeTransient` block, same shape as today's `.charging`/`.device`).

**New monitors (mirror `PowerSourceMonitor`'s event-driven glue shape):**
- `Islet/Notch/FocusModeMonitor.swift` — likely `NSDistributedNotificationCenter` observation or the (undocumented) Focus Status API; isolate behind its own thin protocol from day one (same containment reasoning as `NowPlayingService`).
- `Islet/Notch/SystemHUDMonitor.swift` (Volume + Brightness together, or split) — this is the genuinely novel, adversarial-with-Apple's-own-OSD piece; see Integration Point 4.

**Ranking decision needed (product, not architecture) before implementation:** where do Focus/Volume/Brightness sit relative to existing Charging(1)/Device(2)? Recommendation: Volume/Brightness rank ABOVE Charging/Device (they are direct replacements for an OS-level control the user expects to respond instantly, same reasoning Apple's own OSD always wins over any other system chrome); Focus ranks below Device (informational, not urgent). This is a one-line reordering of `resolve()`'s existing `switch` — cheap to change later, but pick an initial order before Phase planning locks UI-SPEC copy.

---

## Integration Point 3 — Dual-Activity Display (highest-risk, most novel — sequence LAST)

**The core invariant at risk:** `IslandPresentation` is today a single `enum` — every call site (`NotchPillView.body`'s switch, `showsSwitcherRow(for:)`, `visibleContentZone()`'s pattern-match, 9+ `NotchShape(...)` construction sites) assumes exactly one winner renders. Reshaping `IslandPresentation` itself into a "two-slot" carrier (e.g. a tuple, or wrapping every case in `Dual<Primary, Secondary>`) would touch every one of those call sites simultaneously — exactly the failure class the project's own CR-01/CR-02 history already demonstrates as its highest-risk change shape ("a case added to one switch and forgotten in the other silently desyncs render vs. click-through geometry" — `IslandResolver.swift`'s own header comment).

**Recommended shape: additive, not a reshape.**
- Leave `IslandPresentation` and `resolve(...)` **completely untouched**. Zero risk to the 14+ existing resolver unit tests and every existing single-winner case.
- Add a NEW, small, separate enum `SecondaryActivity` (starts with exactly the 2 members the milestone's own example names: `.calendarCountdown(CountdownActivity)`, `.nowPlaying(NowPlayingPresentation)`) and a NEW pure function `resolveSecondary(primary: IslandPresentation, calendarCountdown: CountdownActivity?, nowPlaying: NowPlayingPresentation) -> SecondaryActivity?`, living beside `resolve(...)` in `IslandResolver.swift`.
- **Scope `resolveSecondary` to return non-nil ONLY when `primary` is in the ambient/collapsed tier** (`.idle` or `.nowPlayingWings`) — never during a transient (Charging/Device/Volume/Brightness/Focus splash), never while expanded, never during onboarding. This single scoping rule is what makes the feature genuinely additive: the secondary bubble literally cannot exist in any of the states the existing single-winner logic already owns and has proven correct — it only ever appears in the two ambient fallback branches at the very bottom of `resolve()`, which is the LEAST contested part of the function.
- `IslandPresentationState` gains one new field: `@Published var secondary: SecondaryActivity?` (mirrors adding `songChangeToast` to `NowPlayingState` in Phase 18 — an orthogonal field, not a reshape of the primary enum).
- `NotchPillView` renders `secondary` as a small additive bubble overlay alongside whatever `presentation` already renders — a NEW, small view (`SecondaryBubbleView`), not a modification of `blobShape()`/`wingsShape()`.

**New files:** none beyond what Integration Points 2/6 already add (`SecondaryActivity` + `resolveSecondary` can live directly in `IslandResolver.swift`, following that file's existing convention of colocating every pure resolver-adjacent function).
**Modified:** `IslandResolver.swift` (additive function + enum), `IslandPresentationState.swift` (one new `@Published` field), `NotchPillView.swift` (new small bubble view, rendered additively).

**Why this must be sequenced LAST:** it depends on BOTH of its flagship inputs already existing and being independently stable — Now Playing (already shipped) and Calendar Countdown (Integration Point 6, new in this milestone). Building the dual-slot mechanism at the same time as inventing the calendar-countdown data/timer pipeline means debugging two new things at once through one new rendering path. Sequencing it after Calendar Countdown already works correctly as a *single*-winner ambient case means the dual-activity phase only has to solve "how do two already-correct signals combine," not "is this new signal even correct."

---

## Integration Point 4 — Volume/Brightness System-OSD Suppression

**What this needs, architecturally, if/once feasible** (feasibility itself — suppressing Apple's native OSD — is private/undocumented-API territory per PROJECT.md's own "Key context" flag; treat as a spike, not a committed design):

- A NEW `SystemHUDMonitor` (or two: `VolumeMonitor`/`BrightnessMonitor`), same shape as `PowerSourceMonitor`: `@MainActor`, event-driven (no polling), owns a low-level tap (most likely a `CGEventTap` at `.headInsertEventTap` intercepting the volume/brightness media-key `NSSystemDefined`/`kCGEventKeyDown` events before the system OSD renders), applies the actual volume/brightness change itself (`AudioObjectSetPropertyData` / a private `DisplayServices`-family call), then feeds a `VolumeReading`/`BrightnessReading` into the same `handlePower`-shaped pure-seam pipeline as every other monitor.
- Because a `CGEventTap` is itself an adversarial, easily-broken-by-a-future-macOS-update integration (the exact same risk class as MediaRemote), isolate it behind its own protocol from day one — e.g. `SystemHUDSuppressing` — mirroring the project's own explicit, already-proven `NowPlayingService` containment convention ("Apple might break this again... isolation makes the fix a one-file swap").
- Scrub-tick handling (see Integration Point 2's table): the monitor's callback must distinguish "new scrub session starts" (→ `TransientQueue.enqueue`) from "same scrub session continues" (→ `TransientQueue.updateHead`, no re-arm of the dismiss timer) — same shape as the existing charging-%-tick discipline in `handlePower`.

**New files:** `Islet/Notch/SystemHUDMonitor.swift` (or split), `Islet/Notch/SystemHUDSuppressing.swift` (protocol).
**Modified:** `NotchWindowController.swift` (construct/own the monitor in `start()`, toggle-gated exactly like `startPowerMonitor()`), `IslandResolver.swift` (per Integration Point 2).

**Sequencing:** treat as its own isolated spike/research phase BEFORE committing the `ActiveTransient` wiring — directly mirroring this project's own established precedent (Phase 22's drag-in spike, the Phase 8→9 fullscreen-flash escalation chain). Do NOT plan Volume/Brightness in the same phase as Focus Mode; ship Focus Mode first to prove the "new `ActiveTransient` case, low technical risk" pattern once, cheaply, before attempting the harder scrub-tick + OSD-suppression problem.

---

## Integration Point 5 — Sparkle Integration

**Where it lives:** `AppDelegate.swift`, not `NotchWindowController`. Sparkle's `SPUStandardUpdaterController` is an app-lifecycle concern — parallel to the existing `statusItem`/`menu` construction in `applicationDidFinishLaunching`, not a notch-rendering concern. Add:
- `private var updaterController: SPUStandardUpdaterController!` constructed alongside `statusItem` in `applicationDidFinishLaunching`.
- A "Check for Updates…" `NSMenuItem` added to the existing `menu` (mirrors the existing "Settings…"/"Quit Islet" items verbatim — same `target = self` wiring).

**Does "update available" need to flow through `IslandResolver`?** No, and it should NOT for the full transient-ranking treatment — recommend the simpler split:
1. **Required, low-risk:** the standard Sparkle-driven menu-bar "Check for Updates…" flow, using Sparkle's own built-in alert UI (proven, standard, near-zero custom code — appropriate for this project's "avoid unnecessary complexity" constraint). This alone satisfies "a real Sparkle auto-update integration."
2. **Additive, optional, low-risk:** observe `SPUUpdaterDelegate.updater(_:didFindValidUpdate:)` to flip a small `@Published var updateAvailable: Bool` on a new lightweight `UpdateAvailableState: ObservableObject` (mirrors `NowPlayingState`'s shape but with one field). Render this as an orthogonal badge/dot on the collapsed pill — NOT a resolver case, NOT a `TransientQueue` participant — reusing the exact "orthogonal `@Published` flag the view reads directly" pattern the song-change toast and (per Integration Point 2) the drop-session chip already establish. Clicking the badge calls `updaterController.checkForUpdates(nil)`, which surfaces Sparkle's own standard alert (a real, activatable window — acceptable here since it's an explicit user-initiated action, same category as `openOnboardingSettings()`'s existing `NSApp.activate` precedent, not an ambient hover-triggered activation).

**New files:** none required beyond the optional `UpdateAvailableState.swift` if the badge is built.
**Modified:** `AppDelegate.swift` (updater controller + menu item), optionally `NotchPillView.swift` (badge overlay).

**Why NOT build the full custom Sparkle UI (`SPUUserDriver`) to make Update-available a "real" HUD splash:** replacing Sparkle's entire user-facing UI layer is a significantly larger, riskier lift than every other item in this milestone for a feature the milestone itself describes as one of the least-differentiating additions. Ship the standard-UI + badge version; only revisit `SPUUserDriver` if the badge genuinely feels insufficient on-device.

---

## Integration Point 6 — Calendar Countdown HUD

**New pure seam** (mirrors `PowerActivity.swift`'s and `NowPlayingPresentation.swift`'s shape exactly — Foundation-only, `now:` threaded explicitly for testability, no Timer inside):
- `Islet/Calendar/CalendarCountdown.swift` — `struct CountdownActivity: Equatable { let title: String; let minutesUntilStart: Int }` + `func calendarCountdown(from glance: CalendarGlance?, now: Date) -> CountdownActivity?`, returning non-nil only when the next event starts within 60 minutes (and hasn't already started).

**Where it lives relative to `CalendarService`/`EventKitService`:** it does NOT need a new EventKit fetch or a new permission. `NotchWindowController` already fetches `CalendarGlance` via `refreshCalendar()` on a 15-minute cadence into `outfitState.calendar`. The countdown value itself needs finer-grained recomputation (proximity crosses the 60-minute boundary and the minute readout ticks down), so add a lightweight, SEPARATE `Timer.scheduledTimer` (e.g. every 30s) that re-derives `calendarCountdown(from: outfitState.calendar, now: Date())` from the ALREADY-FETCHED glance — no new network/EventKit call, no new quota concern, same "coarse fetch, cheap local re-derive" split the existing `PlaybackPosition`/progress-bar pattern already uses for Now Playing.

**Resolver treatment:** ambient, like Now Playing — NOT a `TransientQueue` transient (it doesn't need to interrupt anything, and per Integration Point 3 it's explicitly one of the two flagship members of the NEW secondary-bubble slot). Ship it FIRST as a plain single-winner ambient addition to `resolve()`'s existing ambient fallback tier (alongside `.nowPlayingWings`/`.idle`) so its own data/timer plumbing is proven correct in isolation, using the existing, well-understood single-winner path, before Integration Point 3's dual-slot mechanism is built on top of it.

**New files:** `Islet/Calendar/CalendarCountdown.swift`.
**Modified:** `IslandResolver.swift` (one new ambient `IslandPresentation` case or reuse of the existing ambient branch — decide during phase planning), `NotchWindowController.swift` (new 30s timer, reads `outfitState.calendar`, writes a new countdown field), `NotchPillView.swift` (new collapsed-state HUD view: calendar icon left, minutes-countdown right, per the milestone's copy spec).

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Treating "new HUD" as "new resolver case" uniformly
**What people do:** add all 7 HUDs as new `ActiveTransient`/`IslandPresentation` cases because that's the pattern Charging/Device already use.
**Why it's wrong:** Update-available has no queue/expiry semantics: shoving it into `TransientQueue` means writing dead debounce/bound code for a state that should just persist as a badge until dismissed. The drop-session chip and both restyles need ZERO new resolver state at all — adding cases for them is pure switch-statement bloat with matching dead unit tests.
**Do this instead:** classify each HUD by its actual display semantics (transient/queued vs. one-shot toast vs. orthogonal badge vs. pure restyle) using the table in Integration Point 2, and use the SIMPLEST existing pattern that already fits (Phase 18's toast pattern already exists for a reason).

### Anti-Pattern 2: Reshaping `IslandPresentation` into a two-slot type for dual-activity
**What people do:** wrap every existing case in a `Dual<Primary, Secondary>` container, or turn `IslandPresentation` into a tuple, to "properly model" two simultaneous activities.
**Why it's wrong:** every existing exhaustive `switch` over `IslandPresentation` (rendering, `showsSwitcherRow`, `visibleContentZone`'s click-through geometry) would need to change simultaneously — exactly the failure class (CR-01/CR-02) this project's own resolver header comment already names as its worst historical bug pattern, now applied to the SINGLE most load-bearing type in the codebase.
**Do this instead:** the additive `secondary: SecondaryActivity?` field described in Integration Point 3 — zero risk to the 14+ existing single-winner tests, because nothing about the primary type or its exhaustive switches changes.

### Anti-Pattern 3: Polling for Volume/Brightness/Focus state
**What people do:** since these lack an obvious event-driven API (unlike `IOPSNotificationCreateRunLoopSource` for power), reach for a repeating `Timer` that reads the current volume/brightness/focus state every N ms.
**Why it's wrong:** violates this project's own consistently-enforced "no polling clock, idle CPU ~0%" discipline (explicitly called out in `PowerSourceMonitor.swift`'s and `TransientQueue`'s own doc comments as a locked criterion) and would miss/lag genuine scrub-speed volume changes anyway.
**Do this instead:** a `CGEventTap` (event-driven interception, required anyway for OSD suppression) for Volume/Brightness; `NSDistributedNotificationCenter` observation for Focus Mode changes if such a notification exists (verify during the Volume/Brightness/Focus spike — this is exactly the kind of claim that needs an official-docs/community-precedent check before committing).

---

## Build Order & Risk Sequencing

**Wave 1 — Independent, low-risk, foundational (any order, no dependencies):**
1. Liquid Glass material (Integration Point 1) — touches every existing render call site; do this before any NEW call site (new HUD wings) exists, so new HUDs inherit it for free.
2. Equalizer bars redesign, onboarding signature animation — purely cosmetic, zero resolver coupling.
3. Charging/Bluetooth restyle — reuses existing `.charging`/`.device` cases verbatim, zero resolver risk; do after Liquid Glass so the restyle designs against the final material.

**Wave 2 — Prove the "new transient case" and "new orthogonal toast" patterns at lowest risk:**
4. Drop-session summary chip — reuses the already-shipped Phase-18 toast pattern exactly; zero resolver risk, good low-stakes proof this pattern generalizes.
5. Focus Mode HUD — the FIRST genuinely new `ActiveTransient` case; lower technical risk than Volume/Brightness (read-only detection, no OSD suppression, no scrub-tick handling) — proves the full "new pure Activity type → new Monitor → new Coordinator (if needed) → new resolver case → new wing view" pipeline end-to-end once, cheaply, before Wave 3's harder problem.

**Wave 3 — Isolated spike before commit (highest technical risk, private-API territory):**
6. Volume/Brightness OSD suppression — dedicated feasibility spike FIRST (mirrors the project's own Phase-22/Phase-8→9 precedent for isolating a genuinely uncertain integration point). Only after feasibility is confirmed, wire the full `ActiveTransient` cases + scrub-tick `updateHead` handling, reusing Wave 2's now-proven pipeline shape.

**Wave 4 — Sparkle (independent of everything else, can interleave anywhere after Wave 1):**
7. Sparkle menu-bar integration (required) + optional orthogonal update-available badge (reuses the Wave-2 toast/badge pattern, not a resolver case).

**Wave 5 — Calendar countdown, proven as single-winner first:**
8. Calendar countdown pure seam + 30s local re-derive timer + ambient single-winner resolver wiring — ships as a real, useful, single-winner feature on its own; de-risks the data/timer pipeline in isolation using the well-understood existing ambient-tier pattern.

**Wave 6 — Dual-activity display (LAST — the highest-risk, most novel change in this milestone):**
9. Only after Wave 5's calendar countdown and the existing Now Playing ambient case are BOTH independently stable: add the additive `SecondaryActivity`/`resolveSecondary(...)` seam (Integration Point 3) and the secondary-bubble view. Sequencing it last means this phase only has to solve "how do two already-correct signals combine," never "is this new signal even correct" at the same time.

**Explicit dependency the roadmap must encode:** Wave 6 (dual-activity) depends on Wave 5 (calendar countdown) shipping first. Waves 1-5 have no cross-dependencies on each other and can be reordered/parallelized freely within their own wave.

## Sources

- Direct source reads (this repository, 2026-07-15): `Islet/Notch/IslandResolver.swift`, `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/NotchPillView.swift`, `Islet/ActivitySettings.swift`, `Islet/Notch/DeviceCoordinator.swift`, `Islet/Notch/ActivityCoordinator.swift`, `Islet/Notch/PowerSourceMonitor.swift`, `Islet/Notch/BluetoothMonitor.swift`, `Islet/Notch/NowPlayingMonitor.swift`, `Islet/Notch/NowPlayingState.swift`, `Islet/Notch/NowPlayingPresentation.swift`, `Islet/Notch/IslandPresentationState.swift`, `Islet/Notch/ViewSwitcherState.swift`, `Islet/Notch/NotchInteractionState.swift`, `Islet/AppDelegate.swift`, `Islet/Calendar/CalendarService.swift`, `Islet/Shelf/ShelfCoordinator.swift` — HIGH confidence, all findings traceable to specific line ranges cited inline above.
- `.planning/PROJECT.md` — v1.6 milestone scope, "Key context" flag on Volume/Brightness/Focus as private-API unknowns.
- Volume/Brightness OSD suppression and Focus Mode detection feasibility (CGEventTap approach, private AudioObject/DisplayServices APIs) — NOT independently verified in this research pass (out of scope for an architecture-integration doc); MEDIUM confidence, based on general macOS system-programming precedent rather than a fetched, dated source. Flag for a dedicated feasibility spike (Wave 3 above) before committing to the wiring described in Integration Point 4.

---
*Architecture research for: Islet v1.6 (Liquid Glass & System HUD Suite)*
*Researched: 2026-07-15*
