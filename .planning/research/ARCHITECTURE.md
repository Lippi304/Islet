# Architecture Research — v1.5 (Home Focus & Widget Redesign)

**Domain:** Integration architecture for 5 target features against Islet's existing Swift/SwiftUI/AppKit notch app
**Researched:** 2026-07-13
**Confidence:** HIGH (every claim below is grounded in a direct read of the current source, not PROJECT.md prose)

> Supersedes the prior `ARCHITECTURE.md` (2026-07-11, v1.4 shell-redesign research) for the purposes of the v1.5 milestone. That doc's findings about `NotchPanel`/`NotchWindowController`'s shell shape remain true and are the foundation this doc builds on; see `.planning/phases/23-shell-parity-rewrite/` through `28-calendar-full-view/` for the full prior detail if needed.

## System Overview (as it exists today, relevant slice)

```
NotchWindowController (AppKit glue, ~1832 lines)
 ├─ IslandResolver.resolve(...)         — PURE single arbiter → IslandPresentation enum
 │    inputs: activeTransient, nowPlaying, nowPlayingHealthy, hasPlayedSinceLaunch,
 │            isExpanded, selectedView (Home/Tray/Calendar/Weather), onboardingStep
 ├─ IslandPresentationState (@Published presentation)  ← written by controller inside withAnimation(spring)
 ├─ ViewSwitcherState (@Published selectedView: SelectedView)
 ├─ ShelfCoordinator → ShelfLogic (pure) + ShelfFileStore (disk IO)
 ├─ ShelfViewState (@Published items, isVisible = !items.isEmpty)
 ├─ DropInterceptTap (CGEventTap) — swallows the terminating .leftMouseUp so Finder's
 │    Desktop never completes its own move; NotchWindowController.handleDragApproachEnd()
 │    does the actual shelfCoordinator.append(...) synchronously in the swallow callback
 ├─ BasicOutfitState (@Published weather: WeatherGlance?, calendar: CalendarGlance?)
 ├─ NowPlayingState (@Published presentation, artwork, isHealthy, hasPlayedSinceLaunch, position)
 └─ syncClickThrough()/visibleContentZone() — hit-test scoped to the ACTUAL rendered
      content rect, independent of the panel's static (always max-reserved) frame

NotchPillView (SwiftUI, ~2017 lines) — pure render, one switch over IslandPresentation
 └─ blobShape(topCornerRadius:bottomCornerRadius:alignment:width:height:shelfItems:
              shelfVisible:showSwitcher:content:) — the ONE shape+fill+matchedGeometryEffect
      helper every expanded presentation (Home/Calendar/Weather/Tray/NowPlaying/Onboarding)
      calls; appends switcherRow then shelfRow BELOW content() inside the SAME NotchShape
```

**The critical fact for all 5 features:** `IslandResolver.resolve(...)` is the *only* place precedence is decided; `NotchPillView` never re-derives it (`showsSwitcherRow(for:)` is the one shared helper both the view and the controller's click-through math call, closing the exact class of bug — CR-01/WR-01 — this project has been bitten by twice already). Any new feature that changes *what shows* must add/modify a branch in `resolve(...)`, not special-case the view.

## Feature 1 — Home music-only

### Current precedence (IslandResolver.swift, `resolve(...)`)

```swift
if selectedView == .calendar { return .calendarExpanded }
if selectedView == .weather  { return .weatherExpanded }
if selectedView == .tray     { return .trayExpanded }
// Home (default):
if !nowPlayingHealthy { return .nowPlayingExpanded(nowPlaying, healthy: false) }
if nowPlaying != .none { return .nowPlayingExpanded(nowPlaying, healthy: true) }
return .expandedIdle    // ← the weather/calendar/date glance (NotchPillView.expandedIsland)
```

Important nuance already true today: `NowPlayingPresentation` has 3 cases — `.playing`, `.paused`, `.none` — and the Home branch's `nowPlaying != .none` check already matches `.paused`, so **a paused track already reaches `nowPlayingExpanded`, not `expandedIdle`**. `expandedIdle` (the glance to remove) is reached *only* when `nowPlaying.presentation == .none` — i.e. nothing has ever loaded a track this session, or the last track fully stopped (not just paused).

`mediaExpanded(_:art:)` (NotchPillView.swift ~1485-1540) currently renders the SAME full transport-control row (prev/playpause/next + progress bar) for both `.playing` and `.paused` — there is no existing "read-only, no controls" layout.

### What "last-played track while paused/stopped" requires (a real gap, not a render tweak)

`NowPlayingState.presentation` goes to `.none` when the source truly stops or the player quits — there is currently **no cache of the last known title/artist/art surviving a transition to `.none`**. To satisfy "cover+title for the last-played track while paused/**stopped**", the state layer needs a new field, e.g. `NowPlayingState.lastKnownTrack: (title: String, artist: String)?` (or reuse the existing `TrackToast`-shaped struct), set whenever `presentation` is `.playing`/`.paused` and **deliberately not cleared** when it drops to `.none` (only cleared on a genuine track change to a *different* track, mirroring `isSameTrack(...)`'s existing comparison). This is new pure-seam logic in the same file as `nowPlayingPresentation(from:)` / `isSameTrack(...)` — follows the project's established pure-function-first convention.

### Concrete change shape

- **IslandResolver.swift (modify):** Home's fallback changes from `return .expandedIdle` to a new terminal case, e.g. `.nowPlayingExpanded(.none, healthy: true)` is not quite right (it's a valid presentation already meaning "nothing"), so cleanest is a **new `IslandPresentation` case**, e.g. `.homeEmpty` (or repurpose `.expandedIdle` to mean "no track ever / cache empty" and change what it *renders*, not what it *is* — see below), OR pass the cached last-track through as a `NowPlayingPresentation.paused(...)` synthetic value so `nowPlayingExpanded` handles it uniformly. The lower-risk option given this project's "single arbiter" discipline: keep `.expandedIdle` as the enum case name but change `NotchPillView`'s `expandedIdle` render to show the music-only empty/last-track state instead of weather/calendar/date — the resolver's job (deciding *when* Home falls through) barely changes; only the render target of that fallback branch changes. `.calendarExpanded`/`.weatherExpanded` are unaffected (they already have their own dedicated switcher tabs, matching the milestone's own note that Weather/Calendar "already have their own switcher tabs").
- **NotchPillView.swift (modify):** `expandedIsland` (the 3-column weather/time/calendar glance, lines ~433-456) is replaced with a music-only empty/last-track view. `mediaExpanded(_:art:)` needs an `isPlaying`-gated control-row visibility (hide the transport `HStack` when `.paused`/cached-stopped, matching the requirement "no live controls" while paused/stopped) — this is a straightforward conditional inside the existing view, no new blobShape parameter needed.
- **`outfit: BasicOutfitState` (unchanged as a type)** — still needed because Weather/Calendar tabs (their own resolver cases) still consume it; only Home's *consumption* of it is removed.
- **NowPlayingState.swift / NowPlayingPresentation.swift (modify, new field + pure helper):** the last-played cache described above.
- **NotchWindowController.swift `handleNowPlaying(...)` (modify):** the write site that must populate/preserve the new cache field.

### Data flow change

```
MediaRemote adapter → NowPlayingMonitor → handleNowPlaying() → NowPlayingState.presentation
                                                              → NEW: NowPlayingState.lastKnownTrack (sticky)
IslandResolver.resolve(selectedView: .home, nowPlaying, ...) → .nowPlayingExpanded / Home-empty
NotchPillView switch → mediaExpanded (controls gated on isPlaying) / new Home-empty view
```

No change to Tray/Calendar/Weather's own resolver branches or `showsSwitcherRow(for:)` — Feature 1 is additive-safe there.

## Feature 2 — Tray-only file drops + Quick Action destination picker

### Current drop path (traced end-to-end)

```
NSEvent.leftMouseDragged (global monitor) → handleDragApproachTick() → recheckDragAcceptRegion()
  → geometry check (expandedZone + dragLandingMaxY) → auto-expand island (.dragEntered)
  → dropInterceptTap = DropInterceptTap(shouldSwallow:, onIntercept:) constructed lazily, .start()

CGEventTap (session-level) intercepts the terminating .leftMouseUp:
  - if shouldSwallow() (== isDragApproaching) is true:
      onIntercept() called SYNCHRONOUSLY *before* relocating the event  → handleDragApproachEnd()
      event.location relocated off-screen, event still passed through (keeps WindowServer's
      own drag-session bookkeeping happy — a fully-`nil`-consumed event left the cursor's
      drag ghost stuck, this project already hit that bug once)

handleDragApproachEnd() (NotchWindowController.swift ~886-913):
  - reads NSPasteboard(name: .drag) → fileURLs(from:)
  - shouldAcceptDrop(isExpanded: false, urls:) gate + isWithinDragAcceptRegion(...) gate
  - for each url: ShelfFileStore.makeSessionCopy(...) → ShelfItem → shelfCoordinator.append(item)
  - resyncShelfViewState() → ShelfViewState.items updated
  - handlePointer(at:) re-sync (pointerInZone/click-through went stale during the OS drag)
```

This path is **agnostic to which tab is selected** — dropping while Home/Calendar/Weather is showing already stages the file into the shelf today (that's the "additive shelf-strip-reveal on other tabs" the milestone wants removed) because `ShelfViewState.isVisible` (`!items.isEmpty`) independently drives `shelfVisible:` at every non-Tray `blobShape` call site except `trayFullView` (which already hardcodes `shelfVisible: false` — Tray is the one presentation that deliberately does NOT also show the additive strip, per the Phase 28 round-5 decision recorded in IslandResolver.swift's header comment).

### (a) Stop the additive shelf-strip-reveal on non-Tray tabs

Mechanical, low-risk, and the codebase already demonstrates the exact pattern to copy (`trayFullView`'s own `shelfVisible: false`):

- **NotchPillView.swift (modify, ~5 call sites):** `expandedIsland`, `mediaExpanded`, `mediaUnavailable`, `calendarFullView`, `weatherFullView` all currently pass `shelfVisible: shelfViewState.isVisible`. Change each to `shelfVisible: false` (or delete the parameter/let it default false) so the shelf row never appends outside Tray.
- **NotchWindowController.swift `visibleContentZone()` (modify):** currently computes `shelfHeight = (shelfViewState.isVisible && !isTrayPresentation) ? shelfRowHeight : 0`. Once the additive reveal is gone everywhere but Tray, this collapses to `shelfHeight = isTrayPresentation ? ... : 0` — **must change in lockstep with the view**, exactly the CR-01/WR-01 failure class this project has hit twice (render and click-through geometry drifting independently). This is the single highest-attention edit in Feature 2a.
- **`positionAndShow`'s panel-frame union** reserving `shelfRowHeight` unconditionally can stay untouched (it's transparent reserved space, per the existing Phase 20 "PERMANENT, not conditional" comment) — no need to touch panel sizing for 2a.

### (b) Quick Action destination picker (Drop / AirDrop / Mail) before staging

This is a **new UI surface with no existing analog in this codebase** — the closest precedent is `QuickAddPopover` (NotchPillView.swift ~1733, a `.popover` triggered from a Button, used for Calendar quick-add), which proves the pattern "a small SwiftUI popover anchored to the panel's hosting view" already works inside this click-through NSPanel. The onboarding carousel (`.onboarding` resolver case, forced-flow, highest resolver priority) is the closest precedent for "a modal-like state that temporarily owns the whole island."

Recommended integration:
- **New pure state:** `QuickActionPickerState` (mirrors `ShelfViewState`'s "plain @Published holder, no methods" convention) holding the pending dropped `[URL]` (or a single URL — verify with UX which the picker targets) once a drop lands, instead of immediately calling `shelfCoordinator.append(...)`.
- **`handleDragApproachEnd()` (modify):** instead of appending directly, it stashes the accepted URLs into `QuickActionPickerState` and triggers the picker to show. "Drop" (existing behavior) becomes one of 3 choices the user then picks explicitly; only *that* choice calls the existing `ShelfFileStore.makeSessionCopy` → `shelfCoordinator.append` path.
- **IslandResolver.swift (modify):** the picker needs its own precedence slot. Given a drop is an interrupting, short-lived user decision (not a passive ambient state), it fits best as a **new transient-like `IslandPresentation` case** (e.g. `.quickActionPicker`) checked near the top of `resolve(...)` — analogous to, but a notch below, `.onboarding`'s forced-flow (onboarding must never be interrupted; a drop-picker should probably itself be interruptible by a genuine Charging/Device transient, so it likely sits *below* `activeTransient` but *above* the switcher-selected branches). This needs an explicit product decision (does plugging in the charger mid-picker dismiss it or queue behind it?) before implementation — flag this as an open question for `/gsd-discuss-phase`.
- **AirDrop/Mail via `NSSharingService`:** real integration risk, not just a render change. `NSSharingService(named: .sendViaAirDrop)` / `.composeEmailWithAttachment` need `perform(withItems:)`, and AirDrop in particular typically wants an anchoring view/rect for its picker UI (`NSSharingServicePicker.show(relativeTo:of:preferredEdge:)`) or at minimum a non-nil `delegate`. The notch panel is a deliberately **non-activating, click-through `NSPanel`** (`canBecomeKey/Main == false`, per `NotchWindowController`'s own header doc) — invoking a system sharing UI from it is untested territory in this codebase and may force a brief, deliberate exception to the focus-safe design (a sharing picker is inherently a modal system UI that *should* take focus while open). This is the one place in the whole v1.5 milestone most likely to need its own research/spike phase, similar to how Phase 22/24 isolated the drag-in risk.

### Data flow change

```
Drop lands (any tab) → handleDragApproachEnd() → QuickActionPickerState.pendingURLs = urls
IslandResolver.resolve(...) → .quickActionPicker (new case, own precedence tier)
NotchPillView → new quickActionPicker view (3 buttons: Drop / AirDrop / Mail)
  - Drop  → existing ShelfFileStore.makeSessionCopy → shelfCoordinator.append → dismiss picker
  - AirDrop/Mail → NSSharingService(...).perform(withItems: urls) → dismiss picker (file NOT staged into Tray)
```

## Feature 3 — Tray widening / larger icons

Traced against the exact geometry chain (`NotchGeometry.swift`, `NotchWindowController.positionAndShow`, `NotchPillView.blobShape`):

- `blobShape(...)` **already accepts an optional `width:` override** (added in Phase 26 for `onboardingSize.width = 420`, wider than the standard `expandedSize.width = 360`). This is the exact mechanism to reuse for a wider Tray — `trayFullView` would call `blobShape(..., width: <newTrayWidth>, ...)` instead of relying on the `expandedSize.width` default. **No new plumbing needed at the shape level.**
- `ShelfItemView.swift`'s icon is hardcoded `28x28` (matching `transportButton`'s touch-target convention) and the caption `.frame(maxWidth: 44)` — enlarging icons is a pure constant change in this one file (or introduce a `size:` parameter if Home/Tray end up wanting different sizes, but since Feature 1+2 remove the shelf strip from every non-Tray surface, `ShelfItemView` will after this milestone be used *only* inside `trayFullView`'s `shelfRow(_:)`, so a hardcoded resize is safe and simplest).
- **`shelfRow(_:)` and `shelfRowHeight` (56pt, NotchPillView.swift)** are shared constants also used to reserve space in the (now Tray-only, per Feature 2a) additive strip math — but once Feature 2a lands, `shelfRow`/`shelfRowHeight` effectively becomes Tray-exclusive too, so bumping `shelfRowHeight` for bigger icons only affects Tray, which is exactly the target.
- **Panel-geometry / click-through implications (the CR-01 history this project explicitly flags):**
  - `NotchWindowController.positionAndShow`'s `panelFrame` union is built from `expandedFrame` (using the *fixed* `expandedSize.width`), `wings`, and `onboardingFrame`. **A wider Tray view is not yet a member of this union.** If `trayFullView` renders wider than `expandedSize.width` without a matching panel-frame reservation, the panel window itself will clip the wider content (SwiftUI can't paint outside its hosting `NSPanel`'s frame) — this needs a **new union member**, e.g. `let trayFrame = expandedNotchFrame(collapsed: collapsedFrame, expandedSize: CGSize(width: newTrayWidth, height: ...))`, added to `panelFrame` exactly mirroring how `onboardingFrame` was added in Phase 26.
  - `visibleContentZone()` (the CR-01 fix's hit-test scope) computes `contentSize` using a **single hardcoded `width: expandedSize.width`** for every non-onboarding case today. A wider Tray means this function needs a **presentation-aware width branch** (mirroring the `isOnboardingActive` branch already there, and the `isTrayPresentation` exclusion already there for height) — **this is the single most important correctness risk in Feature 3**, structurally identical to the CR-01/WR-01 bug class (render width and click-through width silently diverging). Missing this produces exactly the class of "phantom band swallows clicks" or "wider content unclickable past 360pt" regression this project's own memory (`cr01-clickthrough-or-defeat-gotcha`) warns about.
  - `hotZone`/`expandedZone` (used for hover/grace-collapse decisions, not click-through) are derived from the panel union and don't need independent changes beyond the union growing correctly.

### Data flow change

None — Feature 3 is pure layout/geometry, no new state. It is, however, **not a "purely a view change"** as the question's framing suggested: it has two concrete non-optional companion edits in `NotchWindowController.swift` (`positionAndShow`'s union, `visibleContentZone()`'s width branch) that must land in the same change or the app ships a real click-through regression.

## Feature 4 — Weather widget card + optional extended forecast

### Current shape

`WeatherService` protocol has exactly one method, `fetchCurrent(latitude:longitude:completion:)`, returning a single `WeatherGlance { category: WeatherCategory, temperature: Measurement<UnitTemperature> }` — no high/low, no multi-day, no forecast type at all. `WeatherKitService.fetchCurrent` calls `WeatherKit.WeatherService.shared.weather(for:)` and only reads `.currentWeather`. `weatherFullView`/`weatherFullContent` (NotchPillView.swift ~657-699) already render category+temp large/centered — this is close to the "compact widget" target visually but is missing location and H/L, and the milestone's reference layout ("Local / 16° Cloudy H:24 L:15 / 6-day forecast row") needs new fields WeatherKit already exposes (`currentWeather` has no H/L directly — daily forecast's `DayWeather.highTemperature`/`.lowTemperature` for *today* is the correct source) plus a location label (already available via existing `LocationProvider`/`CLLocation`, possibly reverse-geocoded, or WeatherKit's own locality if fetched via a `CLPlacemark`).

### Concrete change shape

- **WeatherService.swift (modify protocol + model):**
  - New model, e.g. `struct DailyForecast: Equatable { let date: Date; let category: WeatherCategory; let high: Measurement<UnitTemperature>; let low: Measurement<UnitTemperature> }`
  - Extend `WeatherGlance` (or add a sibling struct returned by a new call) to carry `high`/`low` for *today* (needed even for the compact card per the reference screenshot) and optionally `[DailyForecast]` for the extended card.
  - New method on the protocol, e.g. `fetchForecast(latitude:longitude:days:completion:)`, calling `service.weather(for:, including: .daily)` (WeatherKit's typed multi-fetch API) — a **second, separate WeatherKit call**, gated so it only fires when the extended widget is enabled (avoid burning quota on the compact-only default, per this file's own existing D-01 "no retry, no eager fetch" discipline and the project's WeatherKit-quota awareness noted in PROJECT.md Phase 14).
- **`WeatherKitService` (modify):** add the forecast fetch, same `completion` always-main-thread contract, same silent-nil-on-failure discipline as `fetchCurrent`.
- **`BasicOutfitState` (modify):** add `@Published var forecast: [DailyForecast]?` alongside the existing `weather`/`calendar` fields — same ownership contract (controller-only writer).
- **`NotchWindowController.refreshWeather()` (modify):** becomes conditional — always fetch current (for the compact card, now needing H/L too, so `fetchCurrent` itself likely needs the H/L fields, or `refreshWeather()` calls both endpoints when H/L is compact-required). Only call the new forecast fetch when the Settings toggle (below) is on.
- **Settings toggle — integrates with the existing `ActivitySettings`/`@AppStorage` pattern exactly:** add a new key, e.g. `static let weatherExtendedKey = "weather.extended"`, following the exact precedent of `ActivitySettings.MaterialStyle`/`materialStyleKey` (a persisted enum-or-bool read fresh via `UserDefaults.standard.object(forKey:) as? Bool ?? false`, observed through the *existing* `UserDefaults.didChangeNotification` observer already wired in `NotchWindowController.start()` — no new observer needed, the same `handleSettingsChanged()` dispatch that already re-applies theme/toggle changes live can gate `startOutfitRefresh()`'s cadence or trigger one immediate forecast fetch on flip-to-on).
- **NotchPillView.swift (modify `weatherFullView`/`weatherFullContent`, or new `weatherExtendedContent`):** branch on the toggle (read via `@AppStorage` or an injected bool, matching how `materialStyle` is read via `@Environment` today — either convention is consistent with this codebase; `@AppStorage` is simpler and is *already* how `SettingsView` reads these same keys) to render the compact card vs. compact+forecast-strip. The extended variant likely needs more vertical space than `switcherContentHeight` (196pt) currently reserves for Weather — **same class of concern as Feature 3's width**: if the extended card is taller, `blobShape`'s `showSwitcher: true` path forces `baseHeight = switcherContentHeight` uniformly for *every* switcher-row presentation (a deliberate Phase 28 round-5 fix to stop the switcher pill's Y-position jumping between tabs) — a taller Weather-extended card either needs to fit inside 196pt or `switcherContentHeight` needs to grow globally (affecting Home/Calendar/Tray too) or Weather needs to become the one exception with its own scroll region inside the fixed box. This directly touches the exact bug class Phase 28 round 5 fixed and needs deliberate handling, not an incidental height bump.

### Data flow change

```
Settings toggle (weather.extended) → @AppStorage / handleSettingsChanged()
  → NotchWindowController gates fetchForecast(...) call
WeatherKitService.fetchForecast(...) → BasicOutfitState.forecast
NotchPillView.weatherFullView reads outfit.weather (current+H/L) + outfit.forecast (if extended)
```

## Feature 5 — NotchShape outward flare, expanded-only

### Current structure (confirmed by direct read of NotchShape.swift)

`NotchShape` is **already a single `Shape` with exactly two animatable stored `CGFloat` properties**, `topCornerRadius` (default 6) and `bottomCornerRadius` (default 14). The file itself has **no explicit `animatableData` override** — only two plain `var` properties (confirmed by direct read: 33 lines total). Every existing collapsed↔expanded morph works because `blobShape(...)`/`collapsedIsland`/`wingsShape(...)` construct a fresh `NotchShape(topCornerRadius:bottomCornerRadius:)` with different constant arguments at each SwiftUI `body` re-evaluation inside the controller's `withAnimation(.spring(...))` wrapper — the interpolation is effectively driven by re-running `body` at each animation frame with different constructor args plus `matchedGeometryEffect(id: "island", in: ns)` tying the two shapes' identity together, not by a custom `Shape.animatableData`. Confirmed by this project's own Phase 25 comment: "the documented `NotchShape.swift` `animatableData` contingency was not needed."

**It already varies between idle/expanded**: every `blobShape(...)` call site expanding the island passes `bottomCornerRadius: 32` (vs. the collapsed pill's default `bottomCornerRadius: 14`, and wings pass `bottomCornerRadius: 6`) — the corner-radius morph *is* the established mechanism for state-conditional shape variation in this codebase.

The path itself (`NotchShape.path(in:)`) is a fixed 8-point path: flat top edge → top-left quad curve → straight left edge → bottom-left quad curve → flat bottom edge → bottom-right quad curve → straight right edge → top-right quad curve → close. There is **no existing parameter for an outward flare at the top edge** — the top edge is always a flat `addLine` between the two top corners.

### Cleanest integration point

- **NotchShape.swift (modify, additive parameter):** add a new stored `CGFloat` property, e.g. `topFlare: CGFloat = 0`, defaulting to `0` so **every existing call site that doesn't pass it renders byte-identical to today** (the exact same additive-parameter discipline `topCornerRadius`/`bottomCornerRadius` already establish, and the same discipline `blobShape`'s own `width:`/`height:` optional overrides use). Since interpolation here is driven by re-constructing the shape with different constants at each animated frame (not a real `animatableData` override, per the finding above), adding a 3rd plain `CGFloat` constructor parameter animates correctly with **zero additional `animatableData` work** — it follows the exact same mechanism the existing two parameters already use.
- **Path math (modify `path(in:)`):** the flare needs to bulge the flat top edge outward. This needs a UI-SPEC decision (does "outward flare" mean the top-left/top-right corners extend sideways past the notch width, or does the top edge itself bow upward past `rect.minY`?). Either way, it's an additive change to the two `addQuadCurve`/`addLine` calls touching the top edge, gated by the new flare parameter (0 = today's flat top, exactly reproducing current geometry).
- **NotchPillView.swift `blobShape(...)` (modify):** thread a new `topFlare: CGFloat = 0` parameter through to `NotchShape(...)`, mirroring exactly how `topCornerRadius`/`bottomCornerRadius` are already threaded per-call-site. Every expanded call site (`expandedIsland`, `mediaExpanded`, `calendarFullView`, `weatherFullView`, `trayFullView`, and the new Feature-1 Home view / Feature-2 picker view) passes the flare value; `collapsedIsland` (which constructs `NotchShape()` directly, not through `blobShape`) and `wingsShape(...)` (charging/device/media wings) are **explicitly excluded** per the milestone's own constraint ("applied ONLY to the expanded state... idle/collapsed pill silhouette is explicitly unchanged").

### Panel-geometry / hit-test interaction with `NotchWindowController` (the question's specific concern)

- **No interaction with click-through hit-testing** as long as the flare stays *inside* the already-reserved panel frame (`expandedNotchFrame`/`panelFrame` union) — the flare only changes where the *fill* is painted within the existing transparent window, not the window's own frame or `visibleContentZone()`'s rect math (which is a plain `CGRect`, not shape-aware). **However**, if the flare needs to extend *above* `rect.minY` (bulge upward past the collapsed pill's top edge, toward the literal screen edge) — which is plausible for a "flare into the top screen edge" effect — this **does** require the panel window itself to reserve a few extra points of headroom above where `expandedNotchFrame` currently starts, since `NSHostingView`/`NSPanel` will clip any `Path` content painted outside the window's own frame. This is the exact same class of concern as Feature 3's width union member: if the flare's vertical extent isn't included in `positionAndShow`'s frame math, the top of the flare will be silently clipped by the window edge. Given the panel is already pinned flush to `screenFrame.maxY` (`notchFrame`'s `y = screenFrame.maxY - size.height`), flaring *above* the current top edge would require either (a) confirming the flare stays within the already-fudged notch height, or (b) extending the panel's frame upward past the literal screen top — worth flagging as a geometry question for the discuss-phase step, since `screenFrame.maxY` is already the literal top of the display.
- **No interaction with `DropInterceptTap`'s drop-acceptance geometry** (`dragLandingMaxY`, `isWithinDragAcceptRegion`) — those are independent `CGRect`/`CGFloat` gates unrelated to the painted shape.

### Data flow change

None — Feature 5 is pure rendering-value change, following the exact precedent Phase 25 (VISUAL-01/02) already established for this codebase ("Pure rendering-value change confined to NotchPillView.swift/NotchWindowController.swift — no new files/types"), *unless* the vertical-headroom question above resolves to "yes, the panel frame needs to grow," which would then also touch `NotchWindowController.positionAndShow`.

## Integration Points Summary

| Feature | New components | Modified components | Panel-geometry/hit-test touch? |
|---|---|---|---|
| 1. Home music-only | `NowPlayingState.lastKnownTrack` (new field) + pure "sticky last track" helper | `IslandResolver.resolve` (Home fallback target), `NotchPillView.expandedIsland`→music-only view, `mediaExpanded` (gate controls on isPlaying), `NotchWindowController.handleNowPlaying` | No |
| 2a. Remove additive shelf-strip on other tabs | — | `NotchPillView` (5 `shelfVisible:` call sites → false), `NotchWindowController.visibleContentZone()` (shelfHeight branch) | **Yes — CR-01-class risk, must move in lockstep** |
| 2b. Quick Action picker | `QuickActionPickerState`, new `IslandPresentation` case, `NSSharingService` wiring | `IslandResolver.resolve` (new precedence tier), `NotchWindowController.handleDragApproachEnd` (defer append), `NotchPillView` (new picker view) | Possibly — sharing picker anchor/focus is untested against the non-activating panel |
| 3. Tray widening | — | `NotchPillView.trayFullView` (`width:` override — mechanism already exists), `ShelfItemView` (icon size), `NotchWindowController.positionAndShow` (new panel-frame union member), `NotchWindowController.visibleContentZone()` (width branch) | **Yes — the central risk of this feature** |
| 4. Weather widget/forecast | `DailyForecast` model, `fetchForecast(...)` protocol method, `ActivitySettings.weatherExtendedKey` | `WeatherService`/`WeatherKitService`, `BasicOutfitState.forecast`, `NotchWindowController.refreshWeather`, `NotchPillView.weatherFullView` | Possibly — if extended card exceeds `switcherContentHeight` (196pt shared box) |
| 5. NotchShape flare | New `topFlare` parameter on `NotchShape` | `NotchShape.path(in:)`, `NotchPillView.blobShape` (thread param through expanded-only call sites) | Possibly — only if flare extends above the panel's current top edge |

## Anti-Patterns to Avoid (specific to this codebase's own history)

### Anti-Pattern 1: Letting render geometry and click-through geometry diverge

**What people do:** change `NotchPillView`'s visible content width/height for one presentation (Tray widening, Weather extended card) without updating `NotchWindowController.visibleContentZone()`'s matching `contentSize` computation in the same change.
**Why it's wrong:** this is the exact CR-01 (Phase 20) / WR-01 (Phase 28 review) failure class already hit twice in this codebase — a silent gap between what's drawn and what's hit-tested either swallows clicks meant for the app underneath, or makes real content unclickable.
**Do this instead:** every width/height change to a `blobShape(...)` call site must be paired with the matching branch in `visibleContentZone()`, ideally by extracting a single shared size function both sites call (the same fix direction `showsSwitcherRow(for:)` already took for the switcher-row-visibility class of bug).

### Anti-Pattern 2: Re-deciding precedence inside NotchPillView

**What people do:** add an `if shelfViewState.isVisible` / `if selectedView == .tray` branch directly in the view instead of in `IslandResolver.resolve(...)`.
**Why it's wrong:** this project's whole architecture rests on `resolve(...)` being the ONE arbiter; every prior precedence bug (28-04 rounds 4-5) came from a second decision point drifting from the resolver.
**Do this instead:** new presentation states (Quick Action picker, Home music-only fallback) get a resolver branch/case; the view only renders whatever the resolver handed it.

## Suggested Build Order

Grounded in this project's own established convention ("Pure-seam-first is this project's own established convention," per PROJECT.md Key Decisions for Phase 19-22) and the actual dependency graph found above — **not** a numeric guess:

1. **Feature 5 (NotchShape flare)** — fully independent, zero dependency on anything else, same low-risk "pure rendering-value change" shape Phase 25 already proved works well standalone. Do this first or in parallel with anything; it can't block or be blocked by the other four. Verify the vertical-headroom question (does the flare stay inside the existing panel frame?) early via a quick on-device geometry check before finalizing the shape math.

2. **Feature 1 (Home music-only)** — next-lowest risk once the new `lastKnownTrack` pure seam is written and unit-tested (mirrors this project's existing pure-function-first pattern for `nowPlayingPresentation`/`isSameTrack`). No dependency on Features 2-4. Should land before Feature 2, because Feature 2's Quick Action picker's resolver precedence needs to be reasoned about against a settled Home-branch shape (adding two new resolver branches in the same phase multiplies the precedence-interaction surface unnecessarily).

3. **Feature 2a (remove additive shelf strip) BEFORE Feature 3 (Tray widening)** — hard dependency, not just sequencing convenience: Feature 3 changes `visibleContentZone()`'s width math for Tray specifically; doing that against the *current* logic (which still ORs in `shelfViewState.isVisible` for non-Tray tabs) means touching the same function twice and re-verifying the CR-01 hit-test trace twice. Land 2a's `shelfVisible:`/`visibleContentZone()` simplification first, then 3's width-union/width-branch changes land on the simpler post-2a code.

4. **Feature 3 (Tray widening)** — depends on 2a (above). Independent of Feature 2b (the picker) — widening Tray's *display* doesn't require the picker to exist yet, since Tray already receives files via the existing direct-append path until 2b changes that. **However**, if 2b's picker changes what lands in the shelf (e.g., adds a destination step before append), and 3 also touches `ShelfItemView`'s icon size, doing 3 before 2b avoids re-touching `ShelfItemView`/`shelfRow` twice.

5. **Feature 2b (Quick Action picker + AirDrop/Mail)** — highest integration risk in the milestone (new resolver case, new `NSSharingService` interaction with a non-activating click-through panel — untested territory, closest analog to this project's own Phase 22/24 drag-in risk isolation). Land last, and per this project's own established pattern for isolating its one genuinely uncertain integration point (see PROJECT.md: "isolating the one genuinely uncertain integration point... meant a spike/iteration there wouldn't block the rest of the feature" — the exact reasoning behind the v1.3 phase order), give 2b its **own phase**, ideally preceded by a small spike specifically on `NSSharingServicePicker`/`NSSharingService` from a non-activating `NSPanel` before committing to the full picker UI design.

6. **Feature 4 (Weather widget/forecast)** — fully independent of Features 1/2/3/5 (Weather already has its own resolver case and switcher tab, untouched by any of the above). Can run in parallel with any of them. The one soft dependency: if the extended card needs `switcherContentHeight` (the shared 196pt box every switcher-row presentation uses) to grow, that change ripples into Home/Calendar/Tray's box too — worth deciding "does Weather-extended fit in 196pt, or does the shared constant need to grow" **before** finalizing Feature 3's width work, since both features touch shared sizing constants in the same file and a two-phase collision (one shrinking, one growing the same shared box) would be wasted rework. Sequence 4 either well before or well after 3, not interleaved.

**Recommended overall order: 5 → 1 → 2a → 3 → 4 → 2b** (5/1 could also run in parallel; 4 could also run in parallel with 2a/3 if the `switcherContentHeight` question above is resolved by explicit design decision rather than trial-and-error).

## Open Questions for `/gsd-discuss-phase`

- Feature 1: what does "cover+title for the last-played track" render as when *nothing has ever played this session* (cache empty) — a blank/neutral Home state, or a "Nothing Playing" placeholder string?
- Feature 2b: does a Charging/Device transient interrupt an open Quick Action picker, or queue behind it? What is `NSSharingService`'s actual behavior invoked from a non-activating `NSPanel` — does it need to briefly activate the app (breaking the project's focus-safe invariant) to show the AirDrop/Mail system UI?
- Feature 3: is "wider Tray" a fixed new constant (like `onboardingSize.width = 420`) or should it flex with item count?
- Feature 4: does the compact widget also need H/L (per the reference screenshot), meaning `fetchCurrent` itself needs to change, or is H/L extended-only?
- Feature 5: does "outward flare into the top screen edge" mean the flare stays within the existing notch-height reservation, or does it need the panel frame to grow upward past the current `screenFrame.maxY`-pinned top edge?

## Sources

- Direct reads of current source (2026-07-13): `Islet/Notch/IslandResolver.swift`, `IslandPresentationState.swift`, `ViewSwitcherState.swift`, `DropInterceptTap.swift`, `NotchWindowController.swift` (full, both halves), `NotchShape.swift`, `NotchPillView.swift` (header/body/blobShape/mediaExpanded/weatherFullView/trayFullView/switcherRow/shelfRow sections), `NowPlayingPresentation.swift`, `NowPlayingState.swift`, `NotchGeometry.swift`, `DragDropSupport.swift`, `Shelf/ShelfCoordinator.swift`, `Shelf/ShelfLogic.swift`, `Shelf/ShelfViewState.swift`, `Notch/ShelfItemView.swift`, `Weather/WeatherService.swift`, `Weather/WeatherCategory.swift`, `Notch/BasicOutfitState.swift`, `ActivitySettings.swift`.
- `.planning/PROJECT.md` — Phase 20/21/23/25/27/28 Validated entries and Key Decisions table (CR-01/WR-01 history, pure-seam-first convention, Phase 22/24 drag-in isolation precedent).

---
*Architecture research for: Islet v1.5 (Home Focus & Widget Redesign)*
*Researched: 2026-07-13*
