# Feature Research — v1.5 (Home Focus & Widget Redesign)

**Domain:** macOS notch-utility app, subsequent milestone (5 target features added to a shipped app)
**Researched:** 2026-07-13
**Confidence:** MEDIUM-HIGH (existing-codebase claims HIGH via direct source read; AirDrop/Mail/WeatherKit-forecast API claims MEDIUM via WebSearch, not Context7-verified — no Context7 entry for AppKit `NSSharingService`)

This research supersedes the previous (v1.4) FEATURES.md. This is **not greenfield feature research** — all 5 target features touch code that already shipped and passed on-device UAT (Home's resolver precedence, the Shelf/drag-in `CGEventTap` pipeline, `WeatherService`/`WeatherGlance`, `NotchShape`'s animatable morph, the 4-icon switcher). Each section below calls out the exact existing type/file it touches and what must not silently regress.

## Feature Landscape

### Area 1 — Home tab becomes music-only

#### What Droppy / iOS-widget precedent establishes
Droppy's own default view IS Now Playing (image `5.png` in `.planning/research/inspiration/notes.md`) — this milestone finally aligns Islet with that reference after Phase 28 explicitly kept the idle glance as Home's fallback. "Last played, paused, controls hidden" is the standard Now-Playing-widget pattern iOS/macOS media widgets use (Control Center's Now Playing module and the iOS 16+ media widget both keep showing the last track's art/title after pause, but grey out or remove the transport row) — there is no live "nothing is playing" empty state in comparable products; they show the last-known state indefinitely (until a genuinely different app/source takes over) rather than reverting to a blank/idle card.

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Home shows live Now Playing (art/title/artist/transport) while something plays | Already shipped (Phase 4/28) — must not regress | — | `IslandResolver` already gives Home this when `.home` selected and a track is actively playing |
| Home shows last-played cover+title, no transport, when paused/stopped | Matches iOS/macOS Now-Playing-widget convention; user explicitly asked for it | LOW-MEDIUM | Needs a "last known track" cache that survives the pause transition — `NowPlayingMonitor`/`NowPlayingState` currently clears/goes idle on pause (Phase 17's NOW-04 gating is about *launch*, not steady-state pause) |
| Removing weather/calendar/date glance from Home does not remove it from the app | User is explicit: Weather/Calendar keep their own tabs | LOW | Pure deletion from Home's render branch only; `WeatherService`/EventKit fetch logic, `.weather`/`.calendar` `SelectedView` cases untouched |
| A true "nothing has ever played" empty state still exists | Fresh install / never launched a player — can't show a "last played" that doesn't exist | LOW | Needs an explicit empty-state view (icon + "Nothing playing" text), distinct from the paused-with-last-track state |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Smooth cross-fade/morph between "live controls" and "paused, no controls" sub-states (not a hard cut) | Matches the project's existing spring-morph design language (Phase 25) | LOW | Reuse existing `matchedGeometryEffect`/spring convention already in `NotchPillView` — no new animation primitive needed |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Reviving the idle weather/calendar/date glance as a Home fallback when nothing has ever played | Feels like "using the empty space productively" | Directly contradicts this milestone's explicit goal (Home = music-only); also re-creates the exact ambiguity Phase 28 already fought through 3 rounds of resolver-precedence UAT | Dedicated small "Nothing Playing" empty state; user reaches Weather/Calendar via the switcher, one tap away |
| Auto-switching Home's selection back to `.calendar`/`.weather` when music stops | Seems "smart" | Silently overrides the user's explicit switcher selection — same anti-pattern Phase 28 already reversed once (Now-Playing was originally an unreachable override) | Never auto-change `ViewSwitcherState.selectedView`; only the *content shown under* `.home` changes |

#### Dependencies on shipped features
- **`IslandResolver`** (Phase 6/28) — its `.home` branch currently reads "is something playing → NowPlaying, else → idle glance." This must be rewired to "is something playing → live NowPlaying, else → last-played (paused) view, else → empty state" — a 2-way branch becomes 3-way. This is the actual center of complexity for this feature, not the UI.
- **`NowPlayingMonitor`/`NowPlayingState`** — must retain the last track's metadata/artwork across a pause/stop transition instead of clearing it; check whether it already does (health-check clearing on source-drop, Phase 4 NOW-03) — that "MediaRemote unavailable" clear path must stay distinct from a normal pause.
- **Weather/Calendar tabs (Phase 28)** — zero code change required to them; only their reachability path (still via the switcher) is retained.

---

### Area 2 — Droppy-style Quick Action drop-destination picker (Drop / AirDrop / Mail)

#### How this class of feature typically works (verified against Apple APIs)
- **AirDrop, programmatic:** `NSSharingService(named: .sendViaAirDrop)?.perform(withItems: [fileURL])` opens the native macOS AirDrop panel pre-loaded with the file — no `NSSharingServicePicker` menu needed if the app already knows the destination (which this design does, since the user tapped a specific icon). HIGH confidence, standard AppKit API, unsandboxed app has no entitlement blocker.
- **Mail, programmatic:** `NSSharingService(named: .composeEmail)?.perform(withItems: [fileURL])` opens a new Mail.app compose window with the file attached — but **this attachment support is Mail.app-specific**; if the user's default mail client is something else (Outlook, Spark, etc.), `NSSharingService` degrades to a `mailto:` link with **no attachment**, silently dropping the file from the email. MEDIUM confidence (multiple independent sources agree, not officially documented as a hard limitation but consistently reported).
- **"Drop" (stage into Shelf):** already fully built (Phase 19-21) — `ShelfCoordinator.append` etc.

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Picker appears immediately on drop, before the file lands anywhere | This is the entire point of the feature — Droppy's reference screenshot shows a row of destination icons at the moment of drop | MEDIUM-HIGH | **Architecture change, not additive**: today `DropInterceptTap`'s `onIntercept()` calls straight into shelf-append (Pitfall A in `DropInterceptTap.swift` — landing must happen synchronously in the swallow branch, not via a deferred event). The picker needs a **pending-drop holding state** between "file captured off the CGEventTap" and "user picks a destination" — the file cannot be committed to any destination until chosen |
| Drop (stage in Tray) still works exactly as today once chosen | Zero regression on the one thing that's fully shipped and UAT'd | LOW once the pending-state plumbing exists | Same `ShelfCoordinator.append` call, just deferred behind the picker choice instead of automatic |
| AirDrop opens the real system AirDrop panel with the correct file | Users expect the OS-native AirDrop UI, not a custom reimplementation | LOW-MEDIUM | `NSSharingService(named: .sendViaAirDrop)?.perform(withItems:)` — but needs an anchoring `NSView`/window, which the click-through `NotchPanel` complicates (see Complexity below) |
| Mail opens a real compose window with the file attached (when default client is Mail.app) | Matches the "Mail" icon's implied behavior | LOW-MEDIUM | Same API, same anchoring caveat; **silent attachment loss on non-Mail.app default clients is a real gap to decide on explicitly**, not discover in UAT |
| Picker is dismissable / has a clear "nothing chosen" outcome | Users need to be able to cancel | LOW | e.g. auto-dismiss after N seconds reverting to "Drop" default, or an explicit dismiss tap — needs an explicit design decision, not implied by Droppy's screenshot alone |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| The 3-icon row is a custom-drawn SwiftUI row inside the island (not the generic system `NSSharingServicePicker` menu) | Matches Droppy's polished in-notch feel instead of a generic system dropdown | LOW-MEDIUM | Reuses the exact clickable-region-within-a-click-through-panel pattern already solved for shelf-item click-to-open (`visibleContentZone()`, CR-01 lesson) — not a new interaction class |
| Auto-navigate the switcher to Tray after choosing "Drop" | Droppy's Settings has an explicit "Open Tray After Drop" toggle (`.planning/research/inspiration/notes.md` line 38) — confirms this is a known, named pattern, not a guess | LOW | Optional; could default on/off, worth a Settings toggle rather than hardcoding |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Full `NSSharingServicePicker` (system's own extensible sharing menu with all installed share extensions — Messages, Notes, Twitter, etc.) | "More options is more useful" | Explicitly out of scope per the milestone's 3-fixed-icon design (Drop/AirDrop/Mail only), and a system picker anchored to a click-through borderless panel is a known-fragile combination (system picker windows expect a normal owning window) | Keep the 3 fixed custom icons; each directly invokes its own `NSSharingService`, never the generic picker |
| Building a custom AirDrop or Mail-compose UI in-app instead of using the system panels | Full visual consistency with the rest of the island | Reimplementing AirDrop device-discovery or SMTP/Mail.app compose is a massive, unnecessary undertaking — `NSSharingService` exists specifically so apps never have to | Always hand off to the real system panel/app once a destination is chosen — only the *picker row itself* is custom |
| Silently falling back to "Drop" when AirDrop/Mail can't complete (e.g., no default mail client attaches files) | Avoids a dead-end/confusing failure | Silent behavior swap violates the user's explicit choice and could stage a file in the Shelf when the user thought they'd emailed it away | Surface a visible failure/fallback notice, don't silently redirect |

#### Complexity flags (explicit, for roadmap)
1. **Pending-drop state is new architecture**, not a small addition — today's `DropInterceptTap` → `ShelfCoordinator` path is a direct, synchronous, single-destination pipeline (deliberately so, per Pitfall A's comment about not relying on deferred event delivery). Introducing a user-choice step in between means holding the dropped file (URL or `NSItemProvider`) in a short-lived pending state, rendering the picker, then routing to exactly one of three destinations on selection — or discarding on timeout/dismiss. This is the single highest-complexity item across all 5 features.
2. **Anchoring `NSSharingService.perform(withItems:)` from a borderless, non-activating, click-through `NSPanel`** is unverified in this codebase — every prior AppKit integration point (drag delivery, click-through hit-testing) has needed on-device iteration to get right (CR-01, Phase 22/23/24's drag saga). Flag for a spike/on-device check before committing to a specific plan, same caution the project already applied to drag-in.
3. **Mail attachment reliability is client-dependent** (LOW-MEDIUM confidence, not Apple-documented as a hard rule but consistently reported) — decide up front whether to detect the default mail client and warn, or accept the silent-`mailto:`-fallback risk.
4. **Removing the additive shelf-strip-reveal on Home/Calendar/Weather** (explicitly stated in `PROJECT.md`'s milestone goal) is itself a deletion inside `ShelfViewState`/`NotchWindowController`'s existing auto-reveal-on-drop logic — low complexity on its own, but must be sequenced/tested together with the picker replacing it, since it's the same drop-event code path.

#### Dependencies on shipped features
- **`DropInterceptTap`** (Phase 24) — the CGEventTap swallow/relocate mechanism is reused as-is for *detecting* a drop; only what happens in `onIntercept()` changes.
- **`ShelfCoordinator`/`ShelfViewState`** (Phase 19-21) — "Drop" destination is a direct pass-through to the existing, fully-verified append path. No change to `ShelfItem`, `ShelfFileStore`, drag-out.
- **Click-through hit-testing (`visibleContentZone()`, CR-01 lesson)** — the picker's 3 tappable icons need the exact same scoped-hit-test discipline already learned the hard way in Phase 20/23/28; reuse the pattern, don't rediscover it.
- **Removes**: the additive "shelf strip reveals under Home/Calendar/Weather on drop" behavior from Phase 20/21 — this is an explicit *behavior removal* of previously-shipped, UAT'd functionality, not just new code. Call this out plainly in planning so it isn't mistaken for an untouched legacy path.

---

### Area 3 — Tray widened with bigger file icons/tiles

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| More files visible at once without scrolling, in a grid/wider-row layout | This is the entire ask — Droppy's Tray page is "file-forward," per the milestone goal | LOW-MEDIUM | Primarily a layout/sizing change inside the existing dedicated `.trayExpanded` presentation (Phase 28) — `ShelfItemView` icon size, panel width, and the island's own width constraint all need coordinated tuning |
| Existing per-item/delete-all trash, click-to-open, drag-out all keep working at the new size | These are fully shipped, UAT'd behaviors (Phase 20/21) | LOW | Pure visual resize of `ShelfItemView`; no logic change if done as a rendering-only pass (same convention as Phase 25's material redesign — "individual activity content untouched") |
| Panel/window width increase doesn't break click-through hit-testing or multi-Space/fullscreen positioning | Every prior geometry change in this codebase (Phase 20's CR-01, Phase 28's phantom-band regression) has broken click-through when the visible rect changed without updating the hit-test rect in lockstep | MEDIUM | This is the real risk here, not the visual resize — `visibleContentZone()`/`syncClickThrough()` must be updated to match the new, wider blob shape |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| A genuine grid layout (multiple rows) rather than a single wider horizontal strip | Matches Droppy's actual Tray screenshot more closely than a same-strip-but-wider stopgap | MEDIUM | `LazyVGrid` is the natural SwiftUI fit; still needs the same click-through/geometry discipline above |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Growing the Tray panel wider than the display's usable width on smaller MacBook screens | "Bigger is better" taken literally | Off-screen clipping, breaks the notch-relative positioning this app depends on | Cap width to a tested max, verify on the smallest supported notch MacBook display |
| Making the whole expanded island (Home/Calendar/Weather too) wider to match Tray, for "consistency" | Seems simpler than per-tab sizing | Explicitly not asked for — Home/Calendar/Weather have their own established, UAT'd geometry (Phase 28); widening them is unscoped, unrequested surface area | Only `.trayExpanded`'s own width/grid changes; other tabs unaffected |

#### Dependencies on shipped features
- **`ShelfItemView`, `ShelfViewState`, `.trayExpanded` (`IslandPresentation`)** (Phase 20/21/28) — this is a pure resize/relayout of an already-dedicated, already-isolated view; low risk of touching unrelated code, since Phase 28 already split Tray into its own resolver case specifically to avoid coupling to other tabs.
- **`visibleContentZone()`/`syncClickThrough()` and `blobShape`** (Phase 20 CR-01, Phase 28 phantom-band fix) — MUST be updated in lockstep with any width/height change to Tray's blob, per the project's own documented memory (`cr01-clickthrough-or-defeat-gotcha`). This is the concrete regression risk to flag for planning/QA, not a hypothetical.

---

### Area 4 — Weather as an iOS-widget-style card (compact default + optional forecast-extended variant)

#### How this class of feature typically works
Apple's own Weather app iOS widgets (Small: location, icon, current temp, H/L; Medium: same plus a horizontal multi-day forecast row) are the explicit reference. This is a well-understood, standard layout pattern — no exotic UI technique needed, just two view compositions sharing the same data-driven building blocks (condition icon, temp string, H/L string, day-forecast chip).

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Compact card: location name, condition icon, current temp, high/low | This is the explicit default per the milestone goal and the Apple-widget reference | LOW-MEDIUM | Current temp + icon already exist (`WeatherGlance`/`WeatherCategory`, Phase 14/28) — **location name and high/low are new fields**, not currently fetched or modeled |
| A Settings toggle switches to the extended (forecast) variant | Explicitly requested, mirrors Droppy's per-feature Settings toggles pattern already used elsewhere in this app (Now Playing toast, activity toggles) | LOW | Same `@AppStorage` convention already used throughout Settings (Phase 6/27) |
| Extended variant adds a multi-day forecast row (day labels, icons, temps) | Matches the captured reference screenshot ("6-day forecast row") and Apple's Medium widget | MEDIUM-HIGH | **Requires a genuinely new WeatherKit call** — `WeatherService.shared.weather(for:including: .daily)` returning `Forecast<DayWeather>` — Phase 28 explicitly deferred this ("a real multi-day forecast would need a new WeatherKit call and data model, deliberately left as an open follow-up"). This is the correct, expected API (`dailyForecast`/`DayWeather`, HIGH confidence per Apple docs), not a guess |
| Both variants degrade silently on permission/fetch failure, matching the existing `WeatherService` contract | Established project convention (Phase 14 D-01 — "no retry, silent omission") | LOW | Just extend the same completion-nil-on-failure contract to the new forecast fetch; don't invent a different failure UX for forecast vs current |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Smooth compact↔extended morph reusing the existing spring/matchedGeometryEffect convention | Consistency with the rest of the app's Alcove-quality motion language | LOW-MEDIUM | Same technique as collapsed↔expanded island morph; extended card is taller, same as Tray growing wider — geometry-only change, same click-through caution as Area 3 |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Hourly forecast (not just daily) | "More data is more useful," and WeatherKit supports `.hourly` too | Reference screenshot and milestone goal both specify **daily** ("6-day forecast row"), not hourly; hourly is a much denser UI that doesn't fit a widget-card metaphor and would need its own scroll/layout design | Stick to daily forecast only, matching Apple's own Medium widget scope |
| Live/auto-refreshing forecast on a tight polling interval | Feels "more live" | WeatherKit has real API-call-volume implications and Phase 14 already established a **coarse refresh timer**, not continuous polling, as the pattern; forecast data changes slowly (once/few-hours cadence is plenty) | Reuse/extend the existing coarse refresh timer, don't add a second, tighter one just for forecast |
| Full weather-app feature set (radar, precipitation minute-by-minute, severe alerts) | "Since we're touching Weather anyway" | Massively out of scope for a notch-widget card; not what the reference screenshot or milestone goal ask for | Two fixed layouts only: compact and extended-with-daily-forecast |

#### Complexity flags (explicit, for roadmap)
1. **New WeatherKit data**: location name and high/low are not in the current `WeatherGlance` struct at all (it only carries `category` + `temperature`) — this needs its own small extension, separate from the forecast call. Location name likely needs reverse-geocoding (`CLGeocoder`) or a placemark lookup alongside the existing `CLLocation`-based fetch — verify whether WeatherKit's response or `CoreLocation` supplies a human-readable name; this wasn't confirmed in this research pass (flag as an open question for the phase's own research).
2. **The forecast call is additive, not a replacement** — keep `fetchCurrent` as-is (Phase 14's `WeatherService` protocol contract, mirrored across the codebase) and add a second method/protocol extension for `fetchDailyForecast`, consistent with this project's "isolate the fragile external behind one seam" convention (`NowPlayingMonitor`, `WeatherKitService` itself, `LicenseService`) — don't collapse both into one call unless the extended-card-only setting makes lazy-fetching (only calling forecast when the toggle is on) worth the split anyway, which it does: no reason to pay the extra WeatherKit call for users who never enable the extended card.
3. **Geometry/click-through impact of a taller extended card** is the same class of risk flagged in Area 3 — must update hit-testing in lockstep.

#### Dependencies on shipped features
- **`WeatherService`/`WeatherKitService`/`WeatherGlance`/`WeatherCategory`** (Phase 14) — current-conditions fetch, icon classification, and the "silent omission on failure" contract are all reused as-is; forecast is additive alongside, not a rewrite.
- **`.weather`/`.weatherExpanded` (`SelectedView`/`IslandPresentation`)** (Phase 28) — the dedicated Weather tab already exists; this feature redesigns its *content*, not its reachability via the switcher.
- **Settings (`@AppStorage`, sidebar sections)** (Phase 6/27) — the compact/extended toggle slots into the existing Settings architecture; no new Settings infrastructure needed.

---

### Area 5 — NotchShape outward-flaring top edge (expanded state only)

#### How this class of feature typically works
Apple's macOS Control Center panel (and Notification Center) visually "hangs" from the menu bar with a small rounded flare/handle where the panel meets the status-bar strip, rather than a flat top edge — this is a cosmetic silhouette detail achieved with a custom `Shape`/`Path`, not a system-provided modifier. Since `NotchShape` is already a hand-rolled `Shape` with `animatableData`-driven corner-radius interpolation (confirmed by direct source read), adding a flare is squarely in the same technique family already used for the collapsed↔expanded morph — not a new rendering approach.

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Flare appears ONLY in the expanded state; collapsed/idle pill is pixel-identical to today | Explicit, repeated constraint in `PROJECT.md`'s milestone goal ("idle/collapsed pill silhouette is explicitly unchanged") | MEDIUM | **Currently every expanded `blobShape` call uses `topCornerRadius: 6`, same as collapsed** (confirmed via source grep) — the flare needs a genuinely new geometry parameter, not a reuse of the existing top-corner-radius axis, or the collapsed pill will flare too the moment the two states share the same code path |
| Flare animates in/out smoothly as part of the existing collapsed↔expanded spring morph, not a hard cut | Matches every other transition in this app (Phase 2/25's spring-morph design language) | MEDIUM | Needs to become a 3rd `animatableData` component alongside `topCornerRadius`/`bottomCornerRadius` (or a computed `AnimatablePair`/triple), so it interpolates 0→flare exactly like the corner radii already do — SwiftUI's `Shape.animatableData` supports this via nested `AnimatablePair` |
| Flare doesn't clip/overflow visibly against the physical camera housing or screen's top bezel | The whole app's positioning discipline (Phase 1/2) exists to sit exactly over the real notch — any new geometry that extends the silhouette upward/outward risks visually colliding with the physical camera housing | MEDIUM-HIGH | This needs on-device verification against the real hardware notch, same caution this project applied to every prior `NotchShape`/positioning change (Phase 1-3's measured-notch-geometry discipline) |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Flare radius/depth tuned to genuinely mirror Control Center's own panel silhouette (not just "any outward curve") | This is explicitly the reference cited in the milestone goal — getting the curve shape right (a smooth compound curve, not a simple extra corner radius) is what makes it read as "Apple-quality" rather than an arbitrary bump | MEDIUM | Likely needs 1-2 on-device visual-tuning rounds, consistent with this project's established pattern for every prior shape/geometry feature (charging-wings sizing in Phase 3, corner-radius roundness in Phase 25) |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Applying the flare to the collapsed pill too, "for consistency" | Feels more unified | Directly contradicts the explicit milestone constraint; the collapsed pill's whole design goal (Phase 1) is to be a near-invisible, exact match to the physical notch — a flare would break that camouflage | Flare strictly gated to the expanded/blob states only |
| Making the flare amount user-configurable in Settings | "More customization" | Unrequested scope — this is a fixed design-language detail (like the Phase 25 corner-radius/spring retune), not a per-user preference; no reference app exposes this as a toggle | Ship as a fixed visual constant, tuned once on-device, like every other shape constant in this codebase |

#### Complexity flags (explicit, for roadmap)
1. **This is the one feature of the five with the most geometry-only risk and the least product-logic risk** — no new data model, no new external API, no new architecture layer. The entire complexity is in `NotchShape.swift`'s `path(in:)` math plus its `animatableData` interpolation, verified on real hardware.
2. **Every `blobShape(...)` call site currently passes `topCornerRadius: 6` uniformly** (11+ call sites found via grep) — introducing a flare that must NOT apply to the collapsed pill (which also uses a `NotchShape` instance, just not via `blobShape`) means the new flare parameter needs its own default (0) that only expanded-state call sites override, not a blanket change to `NotchShape`'s defaults.

#### Dependencies on shipped features
- **`NotchShape`** (Phase 1, animatable per Phase 2/25 confirmation) — this feature extends the existing shape struct; it's the same file every prior shape-morph feature has touched, so the project already has a working, on-device-proven pattern (`animatableData`, `matchedGeometryEffect`) to extend rather than invent.
- **`blobShape(...)` in `NotchPillView`** — the single shared shape-construction helper (11+ call sites: Home, Tray, Calendar, Weather, onboarding, toast) — the flare parameter should thread through here once, not be special-cased per call site, to avoid the kind of "one call site fixed, siblings still broken" bug class this project's own memory notes warn about (`cr01-clickthrough-or-defeat-gotcha`).
- **Fullscreen-hide / positioning (`CGSSpace`, Phase 9)** — no expected interaction (flare is a pure rendering/silhouette change, not a window-frame or positioning change), but worth a quick fullscreen-enter/exit re-check since every prior `NotchPillView`/`NotchShape` geometry change in this project has ended up needing at least one on-device regression pass against fullscreen/click-through.

## Feature Dependencies

```
[1. Home music-only]
    └──requires──> IslandResolver 3-way branch rewrite (live / paused-last-track / empty)
    └──requires──> NowPlayingMonitor retaining last-track state across pause (verify/extend)

[2. Quick Action picker]
    └──requires──> Pending-drop holding state (NEW — doesn't exist today)
    └──requires──> DropInterceptTap (existing, reused for detection only)
    └──requires──> ShelfCoordinator.append (existing, reused for "Drop" destination only)
    └──requires──> NSSharingService AirDrop/Mail anchoring from click-through NSPanel (spike/verify)
    └──removes───> Phase 20/21 additive shelf-strip-reveal on Home/Calendar/Weather

[3. Tray widened]
    └──requires──> .trayExpanded / ShelfItemView (existing, resize only)
    └──requires──> visibleContentZone()/syncClickThrough() updated in lockstep (CR-01 class risk)

[4. Weather widget redesign]
    └──requires──> WeatherService (existing fetchCurrent, reused as-is)
    └──requires──> NEW fetchDailyForecast method/protocol extension (additive, WeatherKit .daily)
    └──requires──> NEW location-name field (open question — geocoding source TBD)
    └──requires──> visibleContentZone()/syncClickThrough() updated for taller extended card (CR-01 class risk)

[5. NotchShape flare]
    └──requires──> NotchShape animatableData extended with a 3rd interpolated parameter
    └──requires──> blobShape(...) threading the new parameter to all 11+ expanded call sites
    └──must NOT affect──> collapsed pill's own NotchShape usage (explicit constraint)

[2] and [3] ──share a code path──> both touch the drop-landing pipeline and the Tray view; sequence 2 before 3 or vice versa deliberately, don't do both blind in the same pass
[3] and [4] ──share a risk class──> both grow the blob taller/wider and need the same CR-01-lesson click-through re-verification — worth one shared regression checklist across both, not two independent ones
```

### Dependency Notes

- **Feature 2 (Quick Action picker) is the highest-complexity item** — it's the only one requiring genuinely new architecture (a pending-drop state machine) rather than extending an existing one. Recommend sequencing it with room for an on-device spike, mirroring how Phase 22-24 (drag-in) was isolated from the rest of v1.3's shelf work when it turned out to be the risky piece.
- **Features 3 and 4 share the exact same regression class**: any growth in the expanded blob's width/height requires `visibleContentZone()`/`syncClickThrough()` to be updated in the same commit, per this project's own documented lesson (`cr01-clickthrough-or-defeat-gotcha` in memory, CR-01/phantom-band in Phase 20/28). Worth a single shared verification pass rather than discovering the same class of bug twice.
- **Feature 1 (Home music-only) is a prerequisite-in-spirit for Feature 2's "removed from Home/Calendar/Weather" scope** — both changes touch how drops/content interact with non-Tray tabs; sequencing Home's simplification before or alongside the drop-picker rework avoids re-touching the same resolver logic twice.
- **Feature 5 (NotchShape flare) is fully independent** of Features 1-4 — no shared data, no shared state, touches only `NotchShape.swift`/`blobShape(...)`. Can be built and shipped in isolation, same as Phase 25 (Visual/Material) was sequenced independently of Phase 24 (Drag-In) in the prior milestone.

## MVP Definition

### Launch With (v1.5)
- [ ] Home music-only (live + last-played-paused + empty states) — the milestone's named headline change
- [ ] Quick Action picker with all 3 destinations (Drop/AirDrop/Mail) — a 2-of-3 picker (e.g., Drop+AirDrop only, Mail deferred) would be an incomplete match to the explicit Droppy reference; if Mail's attachment-reliability risk (client-dependent) proves too rough on-device, that's a mid-phase call, not a pre-decided scope cut
- [ ] Tray widened/enlarged — directly requested, low-medium complexity, no external dependency
- [ ] Weather compact card (location, icon, temp, H/L) as the new default — table stakes per the milestone goal
- [ ] NotchShape expanded-only flare — independent, low product-risk, can ship any time in the sequence

### Add After Validation (v1.5.x or same milestone if time allows)
- [ ] Weather extended/forecast variant (Settings toggle) — explicitly gated behind its own new WeatherKit call; reasonable to sequence after the compact card ships and is confirmed working, since it's additive and lazy-fetched only when the toggle is on
- [ ] "Open Tray After Drop" setting (Droppy-precedented convenience toggle for the Quick Action picker's "Drop" outcome) — nice-to-have, not in the milestone's explicit ask

### Future Consideration (v2+)
- [ ] Hourly forecast, weather alerts, radar — explicitly out of scope per the anti-features above; the milestone's own reference screenshot only asks for a daily forecast row
- [ ] User-configurable flare depth/amount — explicitly an anti-feature per the milestone's fixed-design-language convention

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|----------------------|----------|
| Home music-only | HIGH | LOW-MEDIUM | P1 |
| Quick Action picker (Drop/AirDrop/Mail) | HIGH | HIGH | P1 |
| Tray widened | MEDIUM | LOW-MEDIUM | P1 |
| Weather compact card | MEDIUM | LOW-MEDIUM | P1 |
| Weather extended/forecast toggle | MEDIUM | MEDIUM-HIGH | P2 |
| NotchShape flare | LOW-MEDIUM (polish) | MEDIUM | P1 (independent, cheap to slot in anywhere) |

**Priority key:** P1: targeted for this milestone per `PROJECT.md`'s explicit goal. P2: reasonable to slip to a fast-follow if the WeatherKit forecast call or its data model needs more iteration than expected.

## Competitor Feature Analysis

| Feature | Droppy | Apple (iOS/macOS system) | Islet's plan |
|---------|--------|---------------------------|--------------|
| Home/default view content | Now Playing by default | Control Center Now-Playing module keeps last track visible, greys out controls when paused | Live controls when playing, last-track-no-controls when paused, explicit empty state when never played |
| Drop-destination choice | Custom "Quick Action Layout" row (Drop/AirDrop/Mail/others per Settings) | No direct system equivalent; closest is Finder's Share/Quick Actions menu (system `NSSharingServicePicker`) | Custom 3-icon row (Drop/AirDrop/Mail), backed by direct `NSSharingService` calls, not the generic system picker |
| Tray/file-shelf layout | Wide, file-forward grid | N/A (no direct system equivalent) | Widen existing `.trayExpanded`, larger `ShelfItemView` tiles, likely a grid |
| Weather widget | Not shown in captured Droppy reference material | iOS Weather app Small widget (compact) / Medium widget (+ forecast row) is the explicit cited reference | Compact card matches Small widget; extended card matches Medium widget's forecast row |
| Panel/shape silhouette | Not specifically referenced for this feature | Control Center panel's flared top-edge connection to the menu bar/notch is the explicit cited reference | New flare geometry in `NotchShape`, expanded-state only |

## Sources

- `.planning/PROJECT.md` — milestone goal, shipped-feature history, all Phase references cited above (HIGH — primary project source)
- `.planning/research/inspiration/notes.md` — Droppy reference screenshots/notes, incl. the "Open Tray After Drop" and Shelf-size Settings precedents (MEDIUM — single competitor app, screenshots not independently re-verified this pass)
- Direct source reads: `Islet/Notch/NotchShape.swift`, `Islet/Weather/WeatherService.swift`, `Islet/Weather/WeatherCategory.swift`, `Islet/Notch/ViewSwitcherState.swift`, `Islet/Notch/DropInterceptTap.swift`, `Islet/Shelf/ShelfViewState.swift`, `Islet/Notch/NotchPillView.swift` (grep) (HIGH — ground truth for all "existing behavior"/"dependency" claims)
- [Apple: NSSharingService](https://developer.apple.com/documentation/appkit/nssharingservice) — AirDrop/Mail invocation API (HIGH — official docs)
- [cutecoder.org — Programmatically Sending Rich Text e-mail with Attachments on the Mac](https://cutecoder.org/featured/programmatically-sending-rich-text-mail-attachment-mac/) — Mail.app-specific attachment support pattern (MEDIUM)
- [Mozilla Bugzilla 1491683 — Thunderbird doesn't attach files when called using NSSharingService](https://bugzilla.mozilla.org/show_bug.cgi?id=1491683) — corroborates the non-Mail.app fallback gap (MEDIUM, independent corroboration)
- [Apple: dailyForecast](https://developer.apple.com/documentation/weatherkit/weather/dailyforecast) and [Get Started with WeatherKit](https://developer.apple.com/weatherkit/) — `WeatherService.weather(for:including: .daily)` → `Forecast<DayWeather>` as the correct forecast API (HIGH — official docs referenced, exact call signature not hand-verified against a live Xcode SDK this pass, flag as a quick confirm at phase-research time)

---
*Feature research for: Islet v1.5 (Home Focus & Widget Redesign)*
*Researched: 2026-07-13*
