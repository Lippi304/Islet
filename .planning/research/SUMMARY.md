# Project Research Summary

**Project:** Islet v1.5 — Home Focus & Widget Redesign
**Domain:** Native macOS notch-overlay app, incremental milestone on a shipped SwiftUI/AppKit codebase
**Researched:** 2026-07-13
**Confidence:** MEDIUM-HIGH

## Executive Summary

This is not greenfield work — all 5 target features (Home music-only, Quick Action drop picker, wider Tray, widget-style Weather, NotchShape flare) extend a shipped, UAT'd app whose core architecture (`IslandResolver` as single arbiter, `blobShape()` as the one shared shape helper, `visibleContentZone()`/`syncClickThrough()` as the click-through discipline) is already proven across 28 prior phases. Every recommended technology is already linked in the project (AppKit, WeatherKit, SwiftUI) — no new dependency is justified for v1.5. The work is dominated by *integration risk against this codebase's own history*, not by unfamiliar APIs.

The recommended approach: extend existing seams rather than build parallel ones. Home's music-only view is a resolver-fallback change plus a new "sticky last track" field, not a new architecture. Weather forecast is one combined `weather(for:including: .current, .daily)` call threaded through the existing `WeatherService` protocol, not a second fetch. The Tray widening reuses `blobShape()`'s already-existing `width:` override (added Phase 26). The NotchShape flare is a third additive `CGFloat` parameter following the exact pattern `topCornerRadius`/`bottomCornerRadius` already establish. Only the Quick Action picker (AirDrop/Mail from a permanently non-key `NSPanel`) requires genuinely new architecture and untested AppKit territory.

The dominant risk, repeated across three of the five features, is this codebase's own documented failure class: **render geometry and click-through geometry silently drifting apart** (CR-01/CR-02, hit twice already in Phases 20/28). Tray widening, the Weather extended card, and de-scoping the shelf-strip from non-Tray tabs all touch `visibleContentZone()` and must be paired with matching view changes in the same commit. The second major risk is the Quick Action picker's `NSSharingService`/`NSSharingServicePicker` interaction with Islet's deliberately non-activating panel — multiple community sources agree the system share picker requires a key window, which Islet's panel is architected to never be. Mitigation: skip `NSSharingServicePicker` entirely, build a custom SwiftUI 3-button row, and call `NSSharingService(named:).perform(withItems:)` directly — isolated as its own spike phase, mirroring how Phase 22→24 isolated the drag-in risk.

## Key Findings

### Recommended Stack

No new dependencies. `NSSharingService` (direct calls, not the picker class) handles AirDrop/Mail; `WeatherKit.WeatherService.weather(for:including:)` adds forecast to the existing single-call current-conditions fetch; SwiftUI `Shape`/`animatableData` extends `NotchShape`; `LazyVGrid`/`GridItem(.adaptive(minimum:))` is available if Tray needs a true multi-row grid (verify against the Droppy reference first — a wider single row may suffice with the existing `blobShape(width:)` override).

**Core technologies:**
- `NSSharingService` (direct, not `NSSharingServicePicker`): AirDrop/Mail — the picker class is architecturally incompatible with Islet's `canBecomeKey == false` panel
- `WeatherKit weather(for:including: .current, .daily)`: one call for current + forecast — avoids doubling quota/network cost
- SwiftUI `Shape` + explicit `animatableData` (or the existing re-construct-per-frame pattern already proven for `NotchShape`): the flare parameter
- `LazyVGrid`/`GridItem(.adaptive(minimum:))`: only if Tray truly needs multi-row; `blobShape(width:)` override already covers a wider single row

### Expected Features

Five features, each touching already-shipped code. Full detail in FEATURES.md and ARCHITECTURE.md.

**Must have (table stakes):**
- Home: live Now Playing while playing, last-played cover+title (no controls) while paused/stopped, explicit "nothing ever played" empty state
- Quick Action picker: appears on drop with 3 destinations (Drop/AirDrop/Mail), Drop still stages to Tray exactly as today
- Tray: more files visible without scrolling; existing trash/click-to-open/drag-out unaffected
- Weather: compact widget card (location, icon, temp, H/L) as new default
- NotchShape flare: expanded-only, collapsed pill pixel-identical to today

**Should have (differentiators):**
- Smooth spring-morph transitions reusing existing `matchedGeometryEffect` convention for all of the above (no new animation primitive needed)
- "Open Tray After Drop" settings toggle (Droppy-precedented)
- Weather extended/forecast variant behind a settings toggle

**Defer (v2+):**
- Full `NSSharingServicePicker` (all system share extensions) — explicitly out of scope, 3 fixed icons only
- Hourly forecast, weather alerts, radar
- User-configurable flare depth — fixed design-language constant, not a preference
- WidgetKit — "widget-style" is purely visual, not an actual extension target

### Architecture Approach

`IslandResolver.resolve(...)` remains the single arbiter for what's shown; `NotchPillView` never re-derives precedence — this is the load-bearing rule the whole milestone must respect (violating it recreated CR-01/WR-01 twice already). `blobShape(...)` is the one shared shape/fill/matchedGeometryEffect helper every expanded presentation calls — new parameters (flare, width override) thread through this single helper, not through each call site individually.

**Major components:**
1. `IslandResolver` — pure precedence arbiter; gets a new fallback target for Home and a new precedence tier for the Quick Action picker
2. `NotchWindowController` — AppKit glue; owns `visibleContentZone()`/`syncClickThrough()` (must move in lockstep with any geometry change) and `handleDragApproachEnd()` (the most regression-prone function in the codebase — 3 prior phases/1 rewrite to get right)
3. `NotchPillView` — pure SwiftUI render, one switch over `IslandPresentation`; `blobShape()` is the shared shape helper all 5 features route new parameters through
4. `WeatherService`/`WeatherKitService` — single-method protocol seam, extends to a combined current+forecast call
5. `ShelfCoordinator`/`ShelfViewState` — unchanged; Quick Action picker's "Drop" destination is a pass-through to this existing, hardened path

### Critical Pitfalls

1. **`NSSharingServicePicker` likely won't work from Islet's non-activating panel** — the Services/Sharing menu machinery requires a key window; Islet's panel is deliberately never key. Avoid: build a custom SwiftUI picker, call `NSSharingService(named:).perform(withItems:)` directly, never the picker class. Spike this in isolation before wiring into the drop flow.
2. **AirDrop/Mail invocation may require real app activation**, risking the "never steals focus" guarantee — scope any `NSApp.activate` call tightly, immediately before `.perform`, and never touch the panel's own never-key state; re-run the CR-01 hover→expand→move-down trace after.
3. **Half-migrating the shelf-strip to Tray-only** — the `shelfVisible:` boolean is scattered across 5+ call sites plus one independent mirror in `visibleContentZone()`; a missed site recreates CR-01's phantom click-swallowing band. Avoid: introduce one shared gating function (mirroring `showsSwitcherRow(for:)`'s precedent) before touching any call site.
4. **Rewiring `handleDragApproachEnd()` for the picker touches the most regression-prone code in the project** (3 phases, 1 full rewrite to reach working state). Avoid: keep the existing accept/stage logic unchanged; model the picker as a follow-up step, not an inline await inside the drop handler.
5. **Forecast as a second independent WeatherKit call** doubles quota/network cost and duplicates the silent-fail contract. Avoid: single combined `weather(for:including: .current, .daily)` call.
6. **Render/click-through geometry divergence** (the CR-01/CR-02 failure class) — any width/height change to a `blobShape(...)` call site (Tray widening, Weather extended card) must be paired with the matching branch in `visibleContentZone()` in the same commit.

## Implications for Roadmap

Architecture research provides an explicit, dependency-grounded suggested order: **Flare → Home → Shelf-consolidation → Tray-widening → Weather → Quick-Action-picker**. Rationale below.

### Phase 1: NotchShape Flare
**Rationale:** Fully independent of the other 4 features — zero shared state, zero shared data. Lowest risk, same "pure rendering-value change" shape as the already-proven Phase 25. Good first phase to build momentum and validate the additive-parameter-through-`blobShape()` pattern other phases will reuse.
**Delivers:** Expanded-only outward flare on `NotchShape`, threaded through `blobShape()` to every expanded call site; collapsed pill/wings/toast explicitly unchanged.
**Addresses:** Feature 5 (NotchShape flare) from FEATURES.md.
**Avoids:** Pitfall 7 (flare inconsistently applied across call sites) — centralize in `blobShape()`, verify via grep + Phase 25's 7-point morph checklist.

### Phase 2: Home Music-Only
**Rationale:** Next-lowest risk once a pure "sticky last track" seam is written (mirrors the project's established pure-function-first convention). No dependency on Features 3-5. Should land before the picker so the picker's resolver precedence is reasoned about against a settled Home branch, not two new resolver branches at once.
**Delivers:** 3-way Home branch (live / paused-last-track / empty), `NowPlayingState.lastKnownTrack` sticky field, transport controls gated on `isPlaying`, weather/calendar/date glance removed from Home only.
**Addresses:** Feature 1 (Home music-only) from FEATURES.md.
**Avoids:** The anti-pattern of reviving the idle glance as a fallback, and of re-deciding precedence inside `NotchPillView` instead of `IslandResolver`.

### Phase 3: Shelf Consolidation to Tray-Only
**Rationale:** Hard dependency for Phase 4 (Tray widening) — doing Tray's width work against the current logic (which still ORs in `shelfViewState.isVisible` for non-Tray tabs) means touching `visibleContentZone()` twice. Land this simplification first.
**Delivers:** One shared `shelfStripVisible(for:hasItems:)` gating function used by both `NotchPillView` and `visibleContentZone()`; zero remaining scattered `shelfVisible: shelfViewState.isVisible` booleans.
**Uses:** The `showsSwitcherRow(for:)` centralization pattern as direct precedent.
**Implements:** `IslandResolver`/click-through discipline (Pitfall 3, 6 from PITFALLS.md).

### Phase 4: Tray Widening
**Rationale:** Depends on Phase 3. Independent of the Quick Action picker — widening Tray's display doesn't require the picker to exist, since Tray already receives files via the existing direct-append path.
**Delivers:** Wider `.trayExpanded` (reusing `blobShape()`'s existing `width:` override), larger `ShelfItemView` icons, new panel-frame union member in `positionAndShow`, new width branch in `visibleContentZone()`.
**Addresses:** Feature 3 (Tray widened) from FEATURES.md.
**Avoids:** Pitfall (render/click-through width divergence) — the central risk of this phase; pair every width change with the matching `visibleContentZone()` branch in the same commit.

### Phase 5: Weather Widget Redesign
**Rationale:** Fully independent of Phases 1-4 (Weather has its own resolver case and switcher tab). One soft dependency: if the extended card needs `switcherContentHeight` (the shared 196pt box every switcher-row presentation uses) to grow, decide that before/after Phase 4's width work, not interleaved, since both touch shared sizing constants.
**Delivers:** Compact widget card (location, icon, temp, H/L — new fields), settings-gated extended forecast variant via one combined `weather(for:including: .current, .daily)` call.
**Uses:** `WeatherKit.WeatherService.weather(for:including:)` from STACK.md.
**Implements:** `WeatherService`/`WeatherKitService` protocol extension (ARCHITECTURE.md Feature 4).

### Phase 6: Quick Action Destination Picker (Drop / AirDrop / Mail)
**Rationale:** Highest integration risk in the milestone — new resolver case, new `NSSharingService` interaction with a non-activating click-through panel, untested territory. Land last, preceded by its own isolated spike (throwaway button, no picker UI, no drop-flow integration) before committing to the full picker design — mirrors the project's own Phase 22→24 precedent for isolating its one genuinely uncertain integration point.
**Delivers:** `QuickActionPickerState`, new `IslandPresentation` precedence tier, custom SwiftUI 3-button picker, direct `NSSharingService(named:).perform(withItems:)` calls for AirDrop/Mail, Drop still routes through the existing `ShelfCoordinator.append` path unchanged.
**Addresses:** Feature 2 (Quick Action picker) from FEATURES.md — the highest-complexity item across all 5.
**Avoids:** Pitfalls 1, 2, 4 (picker-from-non-key-panel, activation-breaking-focus-guarantee, touching the most regression-prone drop-completion code) — isolate as its own phase, spike the `NSSharingService` call first, keep `handleDragApproachEnd()`'s existing logic untouched.

### Phase Ordering Rationale

- Independence first (Flare), then lowest-new-architecture-risk (Home), then a hard-dependency pair (Shelf consolidation → Tray widening) sequenced to avoid touching `visibleContentZone()` twice, then the fully-independent Weather work, then the one feature requiring genuinely new architecture and untested AppKit territory (Quick Action picker) last, isolated with its own spike.
- This mirrors the project's own established pattern: pure-seam-first work before AppKit-integration-risk work, and isolating the one genuinely uncertain integration point into its own phase (as Phase 22→24 did for drag-in).
- Every phase touching `blobShape()`/`visibleContentZone()` geometry (Flare, Tray widening, Weather extended) must re-run the CR-01 hover→expand→move-down on-device trace, not just a build/visual check.

### Research Flags

Phases likely needing deeper research/spike during planning:
- **Phase 6 (Quick Action picker):** `NSSharingService`/`NSSharingServicePicker` behavior from a non-activating `NSPanel` is unverified in this codebase — no single authoritative Apple doc confirms it; needs an isolated on-device spike before the full picker plan is committed.
- **Phase 1 (NotchShape flare):** open geometry question — does the flare stay inside the existing panel-frame reservation, or does it need the panel to grow upward past `screenFrame.maxY`? Resolve via quick on-device check before finalizing path math.
- **Phase 5 (Weather):** open question — does the compact card need H/L (meaning `fetchCurrent` itself changes) or is H/L extended-only? Also: does the extended card fit inside the existing 196pt `switcherContentHeight`, or does that shared constant need to grow (affecting Home/Calendar/Tray too)?

Phases with standard, well-documented patterns (skip research-phase):
- **Phase 2 (Home music-only):** extends existing `IslandResolver`/`NowPlayingState` seams with a well-understood "sticky last track" pattern; no new API.
- **Phase 3 (Shelf consolidation):** mechanical centralization following the exact `showsSwitcherRow(for:)` precedent already in the codebase.
- **Phase 4 (Tray widening):** reuses `blobShape()`'s already-existing `width:` override mechanism (Phase 26 precedent); the risk is disciplined execution (geometry lockstep), not unfamiliar technique.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | All Apple frameworks already linked; the one open risk (NSSharingService from a permanently-non-key panel) has no single authoritative Apple doc, flagged for spike |
| Features | MEDIUM-HIGH | Existing-codebase claims HIGH (direct source read); AirDrop/Mail/WeatherKit-forecast API claims MEDIUM (WebSearch, not Context7-verified) |
| Architecture | HIGH | Every claim grounded in direct read of current source, not PROJECT.md prose |
| Pitfalls | MEDIUM | Architectural analysis HIGH (grounded in codebase); NSSharingServicePicker-vs-nonactivating-panel behavior MEDIUM (WebSearch-corroborated, not on-device verified); WeatherKit combined-call API HIGH (official, WWDC22-documented) |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **NSSharingService/NSSharingServicePicker behavior from a non-activating NSPanel** — not independently verified on this project's exact panel configuration; resolve via an isolated on-device spike in Phase 6 before committing to the full picker UI design.
- **Weather location-name field** — likely needs reverse-geocoding (`CLGeocoder`) or a placemark lookup; not confirmed this research pass whether WeatherKit's response or CoreLocation directly supplies a human-readable name. Flag as an open question for Phase 5's own research.
- **NotchShape flare vertical extent** — whether the flare stays within the existing notch-height reservation or requires the panel frame to grow upward past the current `screenFrame.maxY`-pinned top edge is unresolved; needs a quick on-device geometry check.
- **Quick Action picker precedence tier** — whether a Charging/Device transient interrupts an open picker or queues behind it is an explicit open product decision, not yet resolved; flag for `/gsd-discuss-phase` before Phase 6 planning.
- **Mail attachment reliability on non-Mail.app default clients** — `NSSharingService(.composeEmail)` silently drops attachments when the default mail client isn't Mail.app (MEDIUM confidence, multiple community sources, not Apple-documented as a hard rule). Decide up front: detect-and-warn vs. accept the risk.

## Sources

### Primary (HIGH confidence)
- Direct source reads (2026-07-13): `Islet/Notch/IslandResolver.swift`, `NotchWindowController.swift` (full, 1832 lines), `NotchShape.swift`, `NotchPillView.swift`, `NowPlayingState.swift`/`NowPlayingPresentation.swift`, `Weather/WeatherService.swift`/`WeatherCategory.swift`, `Shelf/ShelfCoordinator.swift`/`ShelfViewState.swift`, `Notch/ShelfItemView.swift`, `Notch/DropInterceptTap.swift`, `Notch/BasicOutfitState.swift`, `ActivitySettings.swift`, `ViewSwitcherState.swift`
- `.planning/PROJECT.md` — milestone goal, Phase 14/19-28 history, CR-01/WR-01 documented failure class, Phase 22→24 drag-in isolation precedent
- Apple Developer Documentation — `NSSharingService`, `WeatherQuery`/`dailyForecast`
- Apple WWDC22 "Meet WeatherKit" — confirms `weather(for:including:)` single-call, single-quota-unit semantics

### Secondary (MEDIUM confidence)
- `philz.blog/nspanel-nonactivating-style-mask-flag` — documents an AppKit bug where `nonactivatingPanel`'s WindowServer activation tag can desync from AppKit's own state
- `gist.github.com/Wevah/2588578` — confirms popovers in LSUIElement/agent apps are a known activation-event source
- Apple Developer Forums thread 722288 — NSSharingServicePicker reliability issues, even in normal apps
- WebSearch aggregate — "NSSharingServicePicker requires key window" (multiple independent community sources converge, not independently verified on this project's exact panel config)
- `cutecoder.org` / Mozilla Bugzilla 1491683 — Mail.app-specific attachment support, non-Mail.app fallback drops attachments

### Tertiary (LOW confidence)
- `.planning/research/inspiration/notes.md` — Droppy reference screenshots (single competitor app, not independently re-verified this pass) — re-check before finalizing Tray grid-vs-wider-row and picker layout decisions

---
*Research completed: 2026-07-13*
*Ready for roadmap: yes*
