# Roadmap: Notch — Dynamic Island for Mac

## Milestones

- ✅ **v1.0 MVP** — Phases 0-6 (shipped 2026-07-02)
- ✅ **v1.0.1 Pre-Release Polish** — Phases 7-9 (shipped 2026-07-04)
- ✅ **v1.1 Trial & Paid Release** — Phases 10-13 (shipped 2026-07-08)
- ✅ **v1.2 Now Playing Polish** — Phases 17-18 (shipped 2026-07-09)
- ✅ **v1.3 Notch Shelf** — Phases 19-21 (shipped 2026-07-11, known gap: SHELF-01/02 drag-in deferred to v1.4)
- 🚧 **v1.4 Architecture Redesign** — Phases 23-28 (in progress)
- 🚧 **v1.5 Home Focus & Widget Redesign** — Phases 29-34 (in progress, left open in parallel)
- ✅ **v1.6 Liquid Glass & System HUD Suite** — Phases 35-42 (shipped 2026-07-19)
- 🚧 **v1.7 Interaction & Calendar Polish** — Phases 43-50 (planned, left open in parallel)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 0-6) — SHIPPED 2026-07-02</summary>

- [x] Phase 0: Foundations & Notarization Dry Run (4/4 plans) — completed 2026-06-26
- [x] Phase 1: The Empty Island (Window + Geometry) (3/3 plans) — completed 2026-06-26
- [x] Phase 2: Hover, Expand & Fullscreen Hardening (4/4 plans) — completed 2026-06-27
- [x] Phase 3: Charging Activity (3/3 plans) — completed 2026-06-27
- [x] Phase 4: Now Playing (4/4 plans) — completed 2026-06-28
- [x] Phase 5: Device-Connected Activity (superseded by Phase 6 — scope folded into 06-02/06-04) — 2026-07-01
- [x] Phase 6: Priority Resolver, Settings & v1 Ship (13/13 plans) — completed 2026-07-01

Full phase details, goals, success criteria, and plan lists: `.planning/milestones/v1.0-ROADMAP.md`

</details>

<details>
<summary>✅ v1.0.1 Pre-Release Polish (Phases 7-9) — SHIPPED 2026-07-04</summary>

- [x] Phase 7: Now Playing Progress Bar (1/1 plans) — completed 2026-07-03
- [x] Phase 8: Fullscreen-Enter Flash Elimination (2/3 plans, 08-02 correctly skipped — escalated FS-01 to Phase 9) — completed 2026-07-04
- [x] Phase 9: Fullscreen-Enter Flash — Window/Space Architecture Retry (5/5 plans, FS-01 resolved on Wave 1) — completed 2026-07-04

Full phase details, goals, success criteria, and plan lists: `.planning/milestones/v1.0.1-ROADMAP.md`

</details>

<details>
<summary>✅ v1.1 Trial & Paid Release (Phases 10-13) — SHIPPED 2026-07-08</summary>

- [x] Phase 10: Trial & Lockout Gate (4/4 plans) — completed 2026-07-05
- [x] Phase 11: License Settings UI (Stubbed) (2/2 plans) — completed 2026-07-05
- [x] Phase 12: Real Polar.sh License Integration (4/4 plans) — completed 2026-07-07
- [x] Phase 13: Real Notarization & Release (1/1 plans) — completed 2026-07-08

Full phase details, goals, success criteria, and plan lists: `.planning/milestones/v1.1-ROADMAP.md`

</details>

<details>
<summary>✅ v1.2 Now Playing Polish (Phases 17-18) — SHIPPED 2026-07-09</summary>

- [x] Phase 17: Now Playing Launch Gating (1/1 plans) — completed 2026-07-09
- [x] Phase 18: Song-Change Toast (2/2 plans) — completed 2026-07-09

Full phase details, goals, success criteria, and plan lists: `.planning/milestones/v1.2-ROADMAP.md`

</details>

<details>
<summary>✅ v1.3 Notch Shelf (Phases 19-21) — SHIPPED 2026-07-11</summary>

- [x] Phase 19: Shelf Data Model (1/1 plans) — completed 2026-07-09
- [x] Phase 20: Shelf View (3/3 plans) — completed 2026-07-10
- [x] Phase 21: Drag-Out (1/1 plans) — completed 2026-07-10

**Known gap:** SHELF-01/02 (drag-in) not shipped — see Phase 22 below, carried forward as requirements into v1.4.

Full phase details, goals, success criteria, and plan lists: `.planning/milestones/v1.3-ROADMAP.md`

</details>

### 🚧 v1.4 Architecture Redesign (In Progress)

**Milestone Goal:** Redesign the `NotchPanel`/`NotchWindowController` architecture (resolving the Phase 22 drag-in blocker), then layer Droppy-inspired onboarding, a black-to-transparent gradient + fluid Dynamic-Island-style animation visual redesign, a sidebar Settings redesign (including a new Theming section), and a calendar full view on top of it. Gesture-based swipe navigation is explicitly deferred.

- [x] **Phase 23: Shell Parity Rewrite** - Rebuild NotchPanel/NotchWindowController with zero behavioral regression, dropping the residual NSDraggingDestination scaffold (completed 2026-07-11)
- [x] **Phase 24: Drag-In** - DragApproachDetector wiring against Phase 22's already-proven pure seams (completed 2026-07-11)
- [x] **Phase 25: Visual/Material Theming Redesign** - Black-to-transparent gradient material + fluid bouncy Dynamic-Island-style animation (completed 2026-07-11)
- [x] **Phase 26: Onboarding Flow** - First-launch carousel + permissions pre-explanation (completed 2026-07-12)
- [x] **Phase 27: Settings Sidebar Redesign** - NavigationSplitView with General/Workspace/System/About sections, incl. new Theming section (VISUAL-03) (completed 2026-07-12)
- [x] **Phase 28: Calendar Full View** - Month grid + day list + quick-add, sharing one EventKit service layer (completed 2026-07-13)

### 📋 v1.5 Home Focus & Widget Redesign (Planned)

**Milestone Goal:** Declutter Home to music-only, consolidate all file-drop behavior into Tray (with a Droppy-style Drop/AirDrop/Mail destination picker), redesign Weather as an iOS-widget-style card, widen/enlarge the Tray file layout, and give the expanded-state notch silhouette an outward-flaring top edge.

- [x] **Phase 29: NotchShape Flare** - Outward-flaring top edge for every expanded presentation; collapsed pill silhouette unchanged (completed 2026-07-14)
- [x] **Phase 30: Home Music-Only** - Home shows only live/last-played music or an explicit empty state; idle time/weather/calendar glance removed (completed 2026-07-14)
- [x] **Phase 31: Shelf Consolidation to Tray-Only** - Shelf-strip reveal removed from Home/Calendar/Weather, lives only on Tray (completed 2026-07-14)
- [x] **Phase 32: Tray Widening** - Wider Tray layout with larger file tiles, more files visible side-by-side (completed 2026-07-14)
- [x] **Phase 33: Weather Widget Redesign** - Medium (header + hourly row) always shown, Settings-gated Large adds a daily range-bar list — 1:1 iOS Weather widget clone (completed 2026-07-15)
- [x] **Phase 34: Quick Action Destination Picker** - Drop/AirDrop/Mail destination picker shown on every file drop (completed 2026-07-15)

<details>
<summary>✅ v1.6 Liquid Glass & System HUD Suite (Phases 35-42) — SHIPPED 2026-07-19</summary>

- [x] Phase 35: Liquid Glass Material (12/12 plans) — completed 2026-07-16
- [x] Phase 36: Cosmetic Restyles & Signature Animation (4/4 plans) — completed 2026-07-16
- [x] Phase 37: Drop-Session Summary Chip (ABANDONED — reverted after on-device UAT rejection) — 2026-07-17
- [x] Phase 38: Focus Mode HUD (9/9 plans incl. gap-closure) — completed 2026-07-17
- [x] Phase 39: Volume & Brightness HUD (8/8 plans incl. gap-closure) — completed 2026-07-17
- [x] Phase 40: Update-Available HUD & Sparkle Integration (3/3 plans) — completed 2026-07-18
- [x] Phase 41: Calendar Countdown HUD (4/4 plans) — completed 2026-07-18
- [x] Phase 42: Dual-Activity Display (4/4 plans) — completed 2026-07-19

Full phase details, goals, success criteria, and plan lists: `.planning/milestones/v1.6-ROADMAP.md`

</details>

### 🚧 v1.7 Interaction & Calendar Polish (Planned)

**Milestone Goal:** Fix a set of real-usage interaction and layout bugs surfaced since v1.4-v1.6 shipped (drag-detection false-triggers, Tray/picker width squeeze, view-switcher disappear/rebuild flicker, calendar quick-add friction) — no new features in that half. Also adds two new Now Playing capabilities: an audio-output switcher (low-risk, public CoreAudio API, sequenced first) and a favorite/like write-back to Spotify/Apple Music (this milestone's highest-risk item, gated behind a dedicated spike before implementation — mirroring this project's own Phase 22/38/39 spike-first precedent). Started 2026-07-19 while v1.4 and v1.5 both remain open in parallel. Phase numbering continues from Phase 42 (v1.6's last phase).

- [x] **Phase 43: Drag Detection Hardening** - Quick Action picker auto-expand only fires on a genuine inbound file drag, never a plain click/hover (completed 2026-07-19)
- [x] **Phase 44: Tray & Quick Action Width Alignment** - Tray widens to fit every file icon; the drag-preview picker matches that width exactly (completed 2026-07-19)
- [x] **Phase 45: View Switcher Morph Fix** - Tab switches morph continuously with no disappear/rebuild flicker or behind-buttons glitch (completed 2026-07-19)
- [ ] **Phase 46: Calendar Quick-Add Improvements** - Date+time picker with smart defaults, unclipped add button, roomier event rows
- [ ] **Phase 47: Audio Output Switcher — Pure Seam + Monitor** - Device value type + event-driven CoreAudio monitor, proven in isolation before any UI is built
- [ ] **Phase 48: Audio Output Switcher — UI Wiring** - Speaker-icon panel: live device list, tap-to-select, real volume slider
- [ ] **Phase 49: Favorite/Like — Spike** - Resolve Spotify quota, Apple Music reliability, and Automation-TCC unknowns; documented go/no-go scope decision
- [ ] **Phase 50: Favorite/Like — Implementation** - Star button write-back to Apple Music/Spotify, scoped per Phase 49's findings

## Phase Details

### Phase 14: Basic outfit: weather + calendar + date display with weather-driven animated background

**Goal:** The `expandedIdle` glance shows live weather (icon + temperature), date, and the next
relevant calendar event alongside the existing time readout, in a 3-column layout — with only
the weather icon animating per condition category, degrading silently to an absent column on
permission denial.
**Requirements**: WEATHER-01, CAL-01, OUTFIT-01 (new — executed ahead of the v1.1 milestone scope;
not yet in a REQUIREMENTS.md — add these 3 IDs when the next milestone's requirements are defined)
**Depends on:** Phase 13
**Plans:** 5/5 plans complete

Plans:
**Wave 1**

- [x] 14-01-PLAN.md — Pure seams: WeatherCategory.from(_:) (D-06) + nextRelevantEvent(events:now:) (D-04), TDD
- [x] 14-02-PLAN.md — WeatherKit signing/entitlement setup: real Developer Team for Debug, WeatherKit App ID capability, Location/Calendar usage-description keys (Pitfall 1)

**Wave 2** *(blocked on 14-01)*

- [x] 14-03-PLAN.md — Services: LocationProvider, WeatherService/WeatherKitService, CalendarService/EventKitService, BasicOutfitState

**Wave 3** *(blocked on 14-02, 14-03)*

- [x] 14-04-PLAN.md — Wire outfitState into NotchWindowController + 3-column expandedIsland layout in NotchPillView (D-07)

**Wave 4** *(blocked on 14-04)*

- [x] 14-05-PLAN.md — On-device verification: WeatherKit end-to-end, permission-denial silent omission (D-01/D-03), next-event live advancement (D-04), idle-CPU check (Pitfall 5)

## Progress

**v1.0:** 7/7 phases complete (100%) — see `.planning/milestones/v1.0-ROADMAP.md` for the full per-phase breakdown.

**v1.0.1:** 3/3 phases complete (100%) — see `.planning/milestones/v1.0.1-ROADMAP.md` for the full per-phase breakdown.

**v1.1:** 4/4 phases complete (100%) — see `.planning/milestones/v1.1-ROADMAP.md` for the full per-phase breakdown.

**Phase 14 (post-v1.1, pre-next-milestone):** 5/5 plans complete — completed 2026-07-08.

**v1.2:** 2/2 phases complete (100%) — see `.planning/milestones/v1.2-ROADMAP.md` for the full per-phase breakdown.

**v1.3:** 3/3 shipped phases complete (100%) — see `.planning/milestones/v1.3-ROADMAP.md`. Phase 22 (drag-in, SHELF-01/02) blocked and not shipped; carried forward into v1.4.

**v1.4:** 6/6 phases complete (100%) — Phases 23-28 all done. Pending final on-device UAT re-confirmation of 2 code-review fixes before formal `/gsd:complete-milestone`.

**v1.5:** 5/6 phases complete (83%) — roadmap created 2026-07-13. Phases 29-34, 11/11 v1.5 requirements mapped. Phase 29 (SHAPE-01) completed 2026-07-14. Phase 30 (HOME-01/02/03) completed 2026-07-14. Phase 31 (TRAY-01) completed 2026-07-14 — implementation shipped ahead of formal planning via quick task 260714-3k6, verified and closed by this phase's own plan. Phase 32 (TRAY-05) completed 2026-07-15 — on-device UAT required 11 gap-closure rounds (width narrowed 840→750→650pt, ScrollView top-clearance centering bug, filename horizontal-overhang fix); see 32-01-SUMMARY.md. Phase 33 (WEATHER-01/02) completed 2026-07-15 — on-device UAT required 6 gap-closure rounds (stale hourly data, text-wrap doubling row height, blobShape missing content-clipping onto the panel background, NotchShape's real taper clipping the daily row, final height/gap tuning); see 33-02-SUMMARY.md. Only Phase 34 (Quick Action Destination Picker) remains.

**v1.6:** 8/8 phases complete (100%) — see `.planning/milestones/v1.6-ROADMAP.md` for the full per-phase breakdown. Shipped 2026-07-19; 11/12 requirements delivered (HUD-07 dropped, Phase 37 abandoned).

**v1.7:** 3/8 phases complete (38%) — roadmap created 2026-07-19. Phases 43-50, 15/15 v1.7 requirements mapped. Phase 43 (Drag Detection Hardening) completed 2026-07-19. Phase 44 (Tray & Quick Action Width Alignment) completed 2026-07-19. Phase 45 (View Switcher Morph Fix, SWITCH-01/02) completed 2026-07-19 — 45-02's on-device 12-pairwise-transition sweep confirmed both requirements shipped. Phase order: the 4 independent, no-research-dependency bugfixes first (Drag Detection → Tray/Picker Width Alignment → View Switcher Morph → Calendar Quick-Add), then the Now Playing work split per research's risk-isolation recommendation — Audio Output Switcher (public CoreAudio API, pure-seam-then-UI-wiring, no external unknowns) before Favorite/Like (spike-then-implementation, this milestone's highest-risk item: Spotify OAuth+quota reality, Apple Music AppleScript reliability, Automation/TCC permission bug), mirroring this project's own Phase 22/24 and Phase 38/39 spike-first precedent.

### Phase 15: Architecture Refactor — Mechanical Fixes & DI Seams

**Goal:** Fix the audit's small, well-understood issues with no architectural risk: DRY the
duplicate frame-geometry formula (`NotchGeometry.swift`), extract a shared `blobShape()` helper
in `NotchPillView.swift`, protocolize `LocationProvider` and add its missing main-thread
contract, give `LicenseState` a dependency-injection seam, close the weather/calendar
visibility-arbiter gap, fix the `EqualizerBars` re-render bug, and preserve the real Polar.sh
validation payload instead of discarding it. Two items (EqualizerBars, Polar payload) are
explicit, called-out exceptions to an otherwise zero-product-behavior-change phase — both are
small, well-understood bug fixes with an already-worked fix.
**Requirements**: P15-ITEM1..P15-ITEM7 (source: this session's full-codebase architecture audit — no formal REQUIREMENTS.md IDs exist for this phase; the 7 CONTEXT.md scope items are the coverage unit)
**Depends on:** Phase 14
**Plans:** 5/5 plans complete

Plans:
**Wave 1**

- [x] 15-01-PLAN.md — NotchGeometry DRY (topPinnedFrame) + NotchPillView blobShape() extraction (items 1, 2)
- [x] 15-02-PLAN.md — LocationProvider protocolization + BasicOutfitState @MainActor + weather/calendar visibility-arbiter gap fix (items 3, 5)
- [x] 15-03-PLAN.md — LicenseState dependency-injection seam + LicenseStateTests.swift (item 4)
- [x] 15-04-PLAN.md — Preserve the real Polar.sh validation payload end-to-end (item 7)

**Wave 2** *(blocked on 15-01)*

- [x] 15-05-PLAN.md — EqualizerBars re-render reshuffle bug fix (item 6)

### Phase 16: NotchWindowController Device Coordinator Extraction

**Goal:** Extract the 9-field device-splash bookkeeping (`deviceLastShown`, `deviceSuppressedAtLaunch`,
`deviceDebounce`, `connectedDeviceAddresses`, `bluetoothStartedAt`, `deviceLaunchGrace`,
`deviceBatteryWork`, `pollingAddress`, `pendingDeviceBatteryPolls`) plus `handleDevice`,
`scheduleDeviceBatteryRefresh`, and `triggerDeviceBatteryRefreshIfPromoted` out of
`NotchWindowController` into a dedicated `DeviceCoordinator` behind an `ActivityCoordinator`
protocol, with its own test surface. This is a deliberate first slice, not the full controller
split — Device is the highest-risk, most-documented case (11+ inline "gap-closure"/"Finding N"
comments recording races found after the fact), chosen to prove the coordinator shape before
repeating it for Charging/NowPlaying/Outfit in a later phase. Identical `TransientQueue`/dismiss
timing behavior; zero product-behavior change.
**Requirements**: D-01, D-02, D-03 (source: 16-CONTEXT.md locked decisions — no formal REQUIREMENTS.md IDs exist for this phase)
**Depends on:** Phase 15
**Plans:** 2/2 plans complete

Plans:
**Wave 1**

- [x] 16-01-PLAN.md — ActivityCoordinator protocol (D-02) + DeviceCoordinator extraction with DeviceCoordinatorTests.swift covering Pitfalls 1-8
**Wave 2** *(blocked on 16-01)*

- [x] 16-02-PLAN.md — Wire NotchWindowController to DeviceCoordinator (D-01), delete extracted fields/methods, create + execute 16-HUMAN-UAT.md's D-03 on-device Bluetooth checklist

### Phase 19: Shelf Data Model

**Goal**: The shelf's core data and lifecycle contracts exist as pure, Foundation-only, unit-tested logic — no AppKit, no drag APIs — establishing the session-only guarantee before any fragile drag/panel code is touched. Mirrors this project's own established convention (`IslandResolver` before controller wiring, `DeviceCoordinator` proven in isolation before Phase 16 wiring).
**Depends on**: Nothing (first phase of this milestone)
**Requirements**: SHELF-08
**Success Criteria** (what must be TRUE):
  1. `ShelfItem` (id, originalURL, localURL, filename, addedAt) and `ShelfLogic` (append/remove/clear/dedupe) exist as pure value types/functions, fully covered by unit tests, with no dependency on AppKit or `NSItemProvider`.
  2. The model has no persistence path whatsoever — no Codable-to-disk, no UserDefaults, no Keychain — so a cleared or relaunched shelf is provably empty by construction (SHELF-08's core contract).
  3. The shelf is designed as its own independent `@Published` axis, never a case inside `IslandResolver`/`TransientQueue` — confirmed by the model's shape alone, before any view exists.
**Plans**: 1 plan

Plans:
**Wave 1**

- [x] 19-01-PLAN.md — ShelfItem + ShelfLogic pure model (append/remove/clear/dedupe) + ShelfFileStore session-temp copy-in/delete-on-removal I/O

### Phase 20: Shelf View

**Goal**: With hand-seeded shelf state, the expanded island renders a full shelf strip — icons, per-item and delete-all removal, click-to-open, and correct gating alongside Charging/Device splashes — proving the view and panel-sizing math before any live drag risk is introduced.
**Depends on**: Phase 19
**Requirements**: SHELF-03, SHELF-04, SHELF-05, SHELF-07, SHELF-09
**Success Criteria** (what must be TRUE):
  1. When the shelf has items and the island is expanded, a horizontally-scrolling strip appears below whatever else is showing (Now Playing, idle glance, etc.), showing each item's file-type icon, with unbounded capacity.
  2. Each shelf item has its own small trash icon; clicking it removes just that one item from the strip.
  3. A single "delete all" trash icon at the strip's far right clears every item at once.
  4. Clicking a shelf item (not its trash icon) opens the file in its default application.
  5. The shelf strip is hidden while a Charging or Device wings splash is actively showing, and reappears once the splash dismisses.
**Plans**: 3 plans

Plans:
**Wave 1**

- [x] 20-01-PLAN.md — ShelfViewState + ShelfItemView + NotchPillView shelf-aware blobShape/shelfRow, 8 previews updated, SHELF-09 resolver regression test

**Wave 2** *(blocked on 20-01)*

- [x] 20-02-PLAN.md — NotchWindowController wiring (ShelfCoordinator/ShelfViewState ownership, tap/delete/clear-all handlers, panel-height reservation, DEBUG hand-seed), ShelfViewStateTests.swift

**Wave 3** *(blocked on 20-02, gap closure)*

- [x] 20-03-PLAN.md — Closed CR-01 click-through regression: scoped syncClickThrough() hit-test to visible blob height (static panel, no resize), extracted resyncShelfViewState(animated:) helper (WR-01/WR-02)
**UI hint**: yes

### Phase 21: Drag-Out

**Goal**: Users can drag a file already staged in the shelf back out to Finder or any other app, using the item's own local copy — validated before the higher-risk drag-in work.
**Depends on**: Phase 20
**Requirements**: SHELF-06
**Success Criteria** (what must be TRUE):
  1. User can drag a shelf item out of the strip onto the Finder desktop (or another app) and the real file lands there.
  2. Dragging out a shelf item whose backing file has since vanished fails gracefully (pruned or a no-op drag) rather than crashing.
  3. The expanded island's hover/grace-collapse behavior does not get stuck open after a drag-out gesture completes.
**Plans**: 1 plan

Plans:
**Wave 1**

- [x] 21-01-PLAN.md — Pure drag-gate seam (shouldBeginShelfItemDrag) + ShelfItemView .onDrag drag source + NotchWindowController drag-pin lifecycle (D-01/D-02/D-03/D-04)

### Phase 22: Drag-In

**STATUS: BLOCKED, execution aborted 2026-07-10.** Wave 3 (22-03) failed on-device twice — `NotchPanel.draggingEntered` never fired despite clean compilation and a confirmed-working 22-01 spike using the same technique. Root cause not identified. Rather than continue debugging incrementally, the user chose to redesign the underlying `NotchPanel`/`NotchWindowController` architecture in v1.4. **SHELF-01/02 carry forward as requirements into v1.4** rather than resuming this phase as planned; Wave 1-2 (22-01 spike, 22-02 pure seams) remain merged to main and reusable. See STATE.md Blockers/Concerns and `.planning/milestones/v1.3-ROADMAP.md` for full details. **Superseded by:** Phase 23 (shell parity rewrite) and Phase 24 (drag-in retry via a `DragApproachDetector` global-monitor pattern, replacing `NSDraggingDestination` entirely) — this phase's Wave 3 (22-03) will not be resumed as planned.

**Goal**: Users can drag a file, multiple files, or a folder onto the collapsed island and have it land in the shelf — the single highest-uncertainty integration point (click-through panel vs. drag delivery, `.mouseMoved` freezing mid-drag), spiked and sequenced last so every other piece is already proven.
**Depends on**: Phase 21
**Requirements**: SHELF-01, SHELF-02
**Success Criteria** (what must be TRUE):
  1. Dragging one or more files, or a folder, onto the collapsed island pill auto-expands it and each item lands in the shelf strip.
  2. While a file is being dragged over the pill before release, the drop target shows visible "hot"/targeted feedback.
  3. Dragging a file (in or out) no longer freezes the hover/collapse state machine — the island still collapses normally afterward.
  4. The click-through panel correctly receives drag events without breaking normal click-through behavior for ordinary (non-drag) pointer movement.
**Plans**: 3 plans

Plans:
**Wave 1**

- [x] 22-01-PLAN.md — On-device spike: confirm AppKit drag-destination delivery survives ignoresMouseEvents (Assumption A1), scaffold + checkpoint — PARTIAL: A1 core question confirmed (draggingEntered fires), but new blocker found (hot-zone too small/near screen-edge Mission Control trigger, drop never completes). See 22-01-SUMMARY.md and 22-RESEARCH.md Open Question 4.

**UNBLOCKED** — `/gsd:discuss-phase 22` resolved the hot-zone/Mission-Control blocker: D-02 ("reuse the existing hot-zone as-is") is superseded by D-02b (drag-accept reuses the existing expandedZone rect) + D-02c (require landing below the physical top edge, past a margin) + D-05/D-06 (auto-expand and drag-hot feedback trigger off the same wider region) + D-07 (ordinary hover/click hot-zone stays unchanged). 22-02/22-03 replanned against this (2026-07-10).

**Wave 2** *(blocked on 22-01)*

- [x] 22-02-PLAN.md — Pure seams: nextState .dragEntered event (D-01) + DragDropSupport.swift (URL extraction + D-04/non-file gate) + folder round-trip test

**Wave 3** *(blocked on 22-02)*

- [ ] 22-03-PLAN.md — NotchPanel permanent registration/forwarding + NotchWindowController drag-in handlers (D-01/D-02b/D-02c/D-03/D-04/D-05/D-06) + on-device UAT checkpoint, including the D-02b/D-02c expandedZone + landing-margin boundary check

### Phase 23: Shell Parity Rewrite

**Goal**: The notch window shell (`NotchPanel`/`NotchWindowController`) is rebuilt with behavior identical to today, clearing the one architectural prerequisite standing between the project and a working drag-in feature.
**Depends on**: Phase 21 (last shipped v1.3 phase) — Phase 22 is superseded, not resumed. Hard prerequisite for Phase 24.
**Requirements**: ARCH-01
**Success Criteria** (what must be TRUE):
  1. The island still positions on the built-in notch, morphs collapsed↔expanded on hover/click, and grace-collapses after ~0.4s — identical to today, verified on-device.
  2. The island still hides in true fullscreen across all 3 trigger methods (green-button, menu bar, fullscreen video) and click-through still works with no dead-zone regressions.
  3. The island still stays visible above all windows across all Spaces and correctly repositions through external-display/clamshell changes.
  4. No `NSDraggingDestination` conformance or drag-stub overrides remain in `NotchPanel.swift`.
  5. `IslandResolver.swift`, `DeviceCoordinator.swift`, and `Islet/Shelf/` show zero diff — the rewrite touched only window-shell code.
**Plans**: 4 plans

Plans:
**Wave 1**

- [x] 23-01-PLAN.md — NotchPanel.swift D-01 drag-scaffold removal + NotchPanelTests.swift regression assertion
- [x] 23-02-PLAN.md — NotchWindowController.swift reconstruction: properties/start()/monitor lifecycle + hosting-view/settings-apply/Now-Playing/shelf handlers/deinit

**Wave 2** *(blocked on 23-02, same-file sequencing)*

- [x] 23-03-PLAN.md — NotchWindowController.swift reconstruction: the safety-critical single-arbiter core (updateVisibility/positionAndShow/syncClickThrough/hover-click state machine)

**Wave 3** *(blocked on 23-01, 23-03)*

- [x] 23-04-PLAN.md — Zero-diff + build gate verification, Cmd-U test suite, and the consolidated ~20-item on-device UAT checkpoint

### Phase 24: Drag-In

**STATUS: COMPLETE 2026-07-11.** Plan 24-01's spike confirmed the `DragApproachDetector` global-monitor mechanism reliably detects inbound Finder drags (PASSED). Plan 24-02's Tasks 1-2 shipped the shelf-landing logic (after fixing a geometry margin and a `recheckDragAcceptRegion` self-disarm bug), but on-device UAT surfaced an architecture gap: because the panel is deliberately click-through/non-`NSDraggingDestination`, a real drop was never intercepted at the OS level — it fell through to the Finder Desktop underneath and, on a same-volume drag, got MOVED there as an unwanted side effect. `/gsd:discuss-phase 24` scoped the fix (D-10 through D-15: a `CGEventTap`-based `DropInterceptTap`), and Plan 24-03 closed it — spike-first validation confirmed swallowing the terminating `.leftMouseUp` prevents the relocation, and a round-1 on-device finding (the drag ghost image got stranded on the cursor when the event was fully swallowed) was fixed by redirecting the event to an off-screen coordinate instead of discarding it outright, letting the WindowServer end the drag cleanly while still denying Finder a valid drop target. Plan 24-03's Task 4 on-device UAT (including a Release-configuration pass) is approved, resolving/superseding Plan 24-02's Task 3 checkpoint. SHELF-01/SHELF-02 are both complete.

**Goal**: Users can drag a file, multiple files, or a folder onto the collapsed island and have it land in the shelf — retried on the reproven shell via a global-monitor detection pattern (`DragApproachDetector`) instead of `NSDraggingDestination`.
**Depends on**: Phase 23 — hard dependency; retrying drag-in before shell parity closes would repeat Phase 22's exact failure mode.
**Requirements**: SHELF-01, SHELF-02
**Success Criteria** (what must be TRUE):
  1. Dragging one or more files, or a folder, onto the collapsed island pill auto-expands it and each item lands in the shelf strip.
  2. While a file is being dragged over the pill before release, the drop target shows visible "hot"/targeted feedback.
  3. Drag-in works reliably across repeated on-device trials — closing the Phase 22 regression rather than repeating it.
  4. Ordinary (non-drag) hover/click/click-through behavior is unaffected by the new `DragApproachDetector`.
**Plans**: 3 plans

Plans:
**Wave 1**

- [x] 24-01-PLAN.md — Isolated on-device spike (D-05/D-06): confirm DragApproachDetector global-monitor mechanism fires reliably for an inbound Finder drag, checkpoint-gated

**Wave 2** *(blocked on 24-01)*

- [x] 24-02-PLAN.md — Full DragApproachDetector accept/shelf-landing logic (SHELF-01/SHELF-02) + on-device UAT checkpoint — Tasks 1-2 merged, Task 3 paused (drop-interception architecture gap, resolved by 24-03)

**Wave 3** *(blocked on 24-02)*

- [x] 24-03-PLAN.md — Drop-interception fix (D-10 through D-15): spike-first CGEventTap validation, then production `DropInterceptTap` + on-device UAT superseding 24-02's Task 3

### Phase 25: Visual/Material Theming Redesign

**Goal**: The collapsed pill, expanded island, and activity wings share one black-to-transparent vertical-gradient material (opaque/solid black nearest the physical notch, increasingly transparent toward the bottom edge) instead of a flat or uniform frosted/glossy fill, animated with the fluid, deliberately-paced, gently-bouncy open/collapse feel of the iPhone Dynamic Island. Touches only the shared shell chrome (pill/expanded frame/wings material + animation curve); does NOT touch any individual activity's content rendering (Now Playing, Charging/Battery, Clock/Calendar idle glance) — those keep their current views unchanged inside the new chrome, since they'll be revisited in their own future system overhauls. Theming customization (VISUAL-03) is descoped to Phase 27, which already needs a "System (Theming)" Settings section.
**Depends on**: None — independent of the shell work (Phases 23-24); touches `NotchPillView` rendering only, not the window shell.
**Requirements**: VISUAL-01, VISUAL-02
**Success Criteria** (what must be TRUE):
  1. The collapsed pill, expanded island, and activity wings all render one shared vertical alpha-gradient material — opaque/solid black nearest the physical notch, increasingly transparent toward the bottom edge — replacing the current flat fill.
  2. The expand/collapse animation uses a fluid, deliberately-paced spring with a subtle bounce-in on open (matching the iPhone Dynamic Island's characteristic feel), with no dropped frames and no jarring overshoot beyond the intended subtle in-bounce.
  3. The material and animation changes apply only to the shared shell chrome — existing activity content views (Now Playing, Charging, idle glance) render unchanged inside the new chrome.
  4. The material composites without visual artifacts mid-morph (collapse↔expand), verified on-device in the real never-focused panel.
**Plans**: 1 plan

Plans:
**Wave 1**

- [x] 25-01-PLAN.md — Shared gradient material (VISUAL-01, D-01/D-02/D-08) + spring retune (VISUAL-02, D-05/D-06/D-07) + on-device UAT checkpoint
**UI hint**: yes

### Phase 26: Onboarding Flow

**Goal**: First-time users see a proper first-launch carousel — identity (trial/license/buy) and trust (permissions) — instead of today's passive Settings-only license flow.
**Depends on**: None — independent of the shell work; touches `AppDelegate`'s first-launch sequencing and Settings.
**Requirements**: ONBOARD-01, ONBOARD-02, ONBOARD-03
**Success Criteria** (what must be TRUE):
  1. First launch shows a carousel — hero screen → trial/license-key/buy choice → permissions pre-explanation → done — replacing the existing `isFirstLaunch` → `openSettings()` branch.
  2. The permissions screen shows a one-line reason per permission (Bluetooth, Calendar, Location/WeatherKit), and its Continue/Grant action triggers the real system permission prompt for each, in sequence.
  3. The onboarding flow shows exactly once (persisted flag) and is skippable per-step (each permission row, individually) — no whole-flow exit before the Done screen (D-09, locked).
  4. No gesture/feature tutorial screen appears anywhere in the flow.
**Plans**: 4 plans

Plans:
**Wave 1**

- [x] 26-01-PLAN.md — Pure onboarding seams (TDD): OnboardingFlow.swift step reducer + launch gate functions, IslandResolver onboarding precedence, ActivitySettings key

**Wave 2** *(blocked on 26-01)*

- [x] 26-02-PLAN.md — NotchPillView onboarding carousel view (4 steps per UI-SPEC) + OnboardingViewState
- [x] 26-03-PLAN.md — NotchWindowController launch-time gating (D-01) + AppDelegate hand-off

**Wave 3** *(blocked on 26-02, 26-03)*

- [x] 26-04-PLAN.md — Step/permission/settings/finish handlers + on-device UAT checkpoint
**UI hint**: yes

### Phase 27: Settings Sidebar Redesign

**Goal**: Settings is restructured from a single tabbed form into a sidebar-categorized layout, with every existing control preserved, and gains a new Theming section (VISUAL-03, descoped from Phase 25) to customize the Phase 25 gradient shell's appearance.
**Depends on**: None — independent of the shell work; naturally sequenced after Phase 25 (theming controls need the gradient material to exist) and Phase 26's permission/license state, though not a hard blocker.
**Requirements**: SETTINGS-01, VISUAL-03
**Success Criteria** (what must be TRUE):
  1. Settings opens as a `NavigationSplitView` with sidebar sections General, Workspace (Shelf), System (Theming), and About/License.
  2. Every existing toggle (activity toggles, launch-at-login, song-change toast, fullscreen-hide, etc.) and the accent-color picker are present and functional in their new section.
  3. License and login-item state stays correctly synced when switching between sidebar sections — no stale state on section switch.
  4. The System (Theming) section lets the user customize the shell's material/surface style and per-element accent colors.
**Plans**: 4 plans
**UI hint**: yes

Plans:
**Wave 1**

- [x] 27-01-PLAN.md — ActivitySettings.swift Theming data model (MaterialStyle, 4 new keys/EnvironmentKeys) + migration seeding + ActivitySettingsTests.swift

**Wave 2** *(blocked on 27-01)*

- [x] 27-02-PLAN.md — NotchPillView.swift AnyShapeStyle material branch + per-element accent call sites, NotchWindowController.swift single-read-site theme pipeline
- [x] 27-03-PLAN.md — SettingsView.swift NavigationSplitView restructure (General/Workspace/System/About) + Theming section UI + Diagnostics.swift 3-accent report

**Wave 3** *(blocked on 27-02, 27-03)*

- [x] 27-04-PLAN.md — Build gate + dead-reference sweep + consolidated on-device UAT checkpoint

### Phase 28: Calendar Full View

**Goal:** Users get a full calendar view — month grid, day detail, and quick-add — as a third view alongside Home and Tray, sharing one EventKit service layer with the existing glance.
**Depends on**: None — independent of the shell work; soft-pairs with Phase 27's view-switcher slot but not a hard blocker.
**Requirements**: CALVIEW-01, CALVIEW-02, CALVIEW-03, CALVIEW-04
**Success Criteria** (what must be TRUE):
  1. A third view (alongside Home and Tray) shows a month grid and the selected day's event list.
  2. Selecting a day with no events shows an explicit empty state, not a blank area.
  3. The user can quick-add either a calendar event or a reminder (their choice per entry) without leaving the island.
  4. The full calendar view and the existing Home-glance "next event" feature both read through one shared EventKit service layer — no duplicated date/event logic.
**Plans**: 4 plans
**UI hint**: yes

Plans:
**Wave 1**

- [x] 28-01-PLAN.md — Pure seams: CalendarGlance.swift day/month-bucketing (daysInMonth, events(on:)) + ViewSwitcherState/SelectedView + CalendarViewState/QuickAddKind data contracts, TDD
- [x] 28-02-PLAN.md — CalendarService.swift extension: fetchMonth, createEvent, createReminder (lazy Reminders permission, D-04) + project.yml Reminders keys (D-05)

**Wave 2** *(blocked on 28-01)*

- [x] 28-03-PLAN.md — ShelfViewState.isVisible/forcedByTray + IslandResolver .calendarExpanded/SelectedView + NotchPillView switcher pill + calendarFullView (month grid + day list + empty state + quick-add popover)

**Wave 3** *(blocked on 28-02, 28-03)*

- [x] 28-04-PLAN.md — NotchWindowController wiring (resolver/click-through/panel-geometry + switcher/month-nav/day-select/quick-add handlers) + on-device UAT checkpoint

### Phase 29: NotchShape Flare

**Goal**: The expanded island's top edge gains an outward-flaring transition into the screen bezel, threaded through the one shared `blobShape()` helper so every expanded presentation picks it up automatically; the collapsed/idle pill stays pixel-identical to today.
**Depends on**: Nothing — fully independent of the other v1.5 phases (touches only `NotchShape`/`blobShape()` rendering, same "pure rendering-value change" shape as Phase 25).
**Requirements**: SHAPE-01
**Success Criteria** (what must be TRUE):
  1. Every expanded presentation (Home, Tray, Calendar, Weather, Charging/Device wings) shows the new outward-flaring top edge instead of today's flush vertical edge.
  2. The collapsed/idle pill renders pixel-identical to today — no shape, size, or position regression.
  3. The flare animates smoothly as part of the existing collapse↔expand spring morph, with no visual glitches, artifacts, or dropped frames.
**Plans**: 1 plan

Plans:
**Wave 1**

- [x] 29-01-PLAN.md — NotchShape topFlareWidth property + blobShape()/wingsShape() wiring + on-device UAT (panel-frame clipping check, contingency fix)
**UI hint**: yes

### Phase 30: Home Music-Only

**Goal**: The Home view shows only music-related content — live playback, the last-played track, or an explicit empty state — with the idle time/weather/calendar glance removed entirely (Weather and Calendar keep their own switcher tabs).
**Depends on**: Nothing — independent of the other v1.5 phases (touches `IslandResolver`'s Home fallback, a new `NowPlayingState.lastKnownTrack` sticky field, and `NotchPillView`'s Home branch only).
**Requirements**: HOME-01, HOME-02, HOME-03
**Success Criteria** (what must be TRUE):
  1. While something is playing, the Home view shows live Now-Playing transport controls (play/pause/next/prev), unchanged from today.
  2. When paused/stopped, the Home view shows the last-played track's cover art and title, with the same transport controls as the live state (REVISED 2026-07-14: controls stay visible, not hidden — see 30-CONTEXT.md).
  3. When nothing has been played this session, the Home view shows an explicit empty state instead of any glance content.
  4. The time/weather/calendar idle glance no longer appears anywhere on Home, in any of the three sub-states.
**Plans**: 4 plans (3 planned + 1 gap-closure)
**UI hint**: yes

Plans:
**Wave 1**

- [x] 30-01-PLAN.md — NowPlayingState.lastKnownTrack contract + IslandResolver .homeLastPlayed/.homeEmpty cases + NotchPillView routing/homeEmptyState + test rewrite

**Wave 2** *(blocked on 30-01)*

- [x] 30-02-PLAN.md — NotchWindowController lastKnownTrack capture (D-07/D-08) + transport-button hover background (D-05)

**Wave 3** *(blocked on 30-02)*

- [x] 30-03-PLAN.md — On-device UAT: all 3 Home sub-states, hover background, Weather/Calendar regression check

**Wave 4** *(blocked on 30-03, gap closure)*

- [x] 30-04-PLAN.md — Fix D-05 hover never firing (NotchPanel.acceptsMouseMovedEvents) + camera clearance (32→42pt) + hover opacity settled at 0.40 after on-device A/B comparison

### Phase 31: Shelf Consolidation to Tray-Only

**Goal**: File-shelf content and the drop-triggered strip reveal exist only on the Tray tab; the additive shelf-strip-under-other-tabs behavior is removed via one shared gating function, clearing the path for Phase 32's width work to touch `visibleContentZone()` only once.
**Depends on**: Nothing directly, but must land before Phase 32 (Tray Widening) — widening against the still-additive shelf logic would mean touching `visibleContentZone()` twice.
**Requirements**: TRAY-01
**Success Criteria** (what must be TRUE):
  1. Adding a file to the shelf no longer reveals any shelf-strip UI while viewing Home, Calendar, or Weather.
  2. Switching to the Tray tab still shows the full shelf content exactly as before (icons, per-item/delete-all trash, click-to-open).
  3. Click-through hit-testing correctly excludes any residual shelf-strip band on non-Tray views — no CR-01-style phantom click-swallowing regression, verified via the on-device hover→expand→move-down trace.
**Plans**: 1/1 plans complete
**UI hint**: yes

Plans:
**Wave 1**

- [x] 31-01-PLAN.md — Verify-and-close: shelfStripVisible regression test (access-level bump), on-device CR-01 click-through trace, formal TRAY-01 closeout (implementation shipped by quick task 260714-3k6)

### Phase 32: Tray Widening

**Goal**: The Tray view renders wider with larger file tiles, reusing `blobShape()`'s existing `width:` override, so more files are visible side-by-side without scrolling.
**Depends on**: Phase 31 — widening must land after shelf-strip visibility is consolidated to Tray-only, so `visibleContentZone()` is touched once, not twice.
**Requirements**: TRAY-05
**Success Criteria** (what must be TRUE):
  1. The Tray view renders visibly wider with larger per-file icons/tiles than today's layout.
  2. More files are visible side-by-side without scrolling compared to the previous layout.
  3. Existing Tray interactions (trash, delete-all, click-to-open, drag-out) continue to work unchanged in the new layout.
  4. Click-through hit-testing matches the new wider geometry exactly — re-verified via the on-device hover→expand→move-down trace, closing off the CR-01/CR-02 failure class.
**Plans**: 1 plan
**UI hint**: yes

Plans:
**Wave 1**

- [x] 32-01-PLAN.md — traySize/trayContentHeight constants + blobShape height-ternary fix + panel-frame union + visibleContentZone Tray branch + ShelfItemView/shelfRow tile sizing + on-device CR-01 checkpoint

### Phase 33: Weather Widget Redesign

**Goal**: The Weather view is a 1:1 clone of Apple's iOS Weather widget: Medium (location/icon/current temp/H-L header + hourly forecast row) is the permanent baseline, with a Settings-gated Large style adding a daily forecast list with min/max range bars, sourced from one combined `weather(for:including: .current, .hourly, .daily)` call.
**Depends on**: Nothing — fully independent of the other v1.5 phases (Weather has its own resolver case and switcher tab).
**Requirements**: WEATHER-01, WEATHER-02
**Success Criteria** (what must be TRUE):
  1. The Weather view always shows at least the Medium layout: location, condition icon, current temperature, high/low, and an hourly forecast row.
  2. A Settings control (Medium/Large) switches Weather to the Large style, adding a daily forecast list with range bars, below the Medium content.
  3. Switching styles live-updates the Weather view without requiring a relaunch.
  4. Weather still degrades silently (no crash, sensible fallback) on permission denial, matching the existing pattern.
**Plans**: 2 plans (33-02 revised — supersedes the original daily-chip-row scope after on-device checkpoint rejection)
**UI hint**: yes

Plans:
**Wave 1**

- [x] 33-01-PLAN.md — Combined WeatherKit fetch (DailyForecast, extended WeatherGlance, fetchCurrentAndForecast + resolvePlaceName) + BasicOutfitState/ActivitySettings wiring, TDD

**Wave 2** *(blocked on 33-01)*

- [x] 33-02-PLAN.md — Medium/Large iOS Weather widget clone: hourly forecast row, daily range-bar list, Medium/Large Settings control, controller fetch/geometry three-site rule (two size tiers) + on-device UAT

### Phase 34: Quick Action Destination Picker

**Goal**: Dropping a file from any view presents a Droppy-style destination picker (Drop/AirDrop/Mail) instead of immediately staging into the shelf — the milestone's highest integration-risk item, isolated last and preceded by its own spike, mirroring this project's own Phase 22→24 drag-in risk-isolation precedent.
**Depends on**: Phase 31 — the picker's "Drop" destination routes into the now Tray-only shelf and switches the active view to Tray.
**Requirements**: TRAY-02, TRAY-03, TRAY-04
**Success Criteria** (what must be TRUE):
  1. Dropping a file on the island from any view shows a 3-option Quick Action picker: Drop, AirDrop, Mail.
  2. Choosing "Drop" stages the file into Tray exactly as before and switches the active view to Tray.
  3. Choosing "AirDrop" opens the system AirDrop share sheet for the dropped file.
  4. Choosing "Mail" composes a new email in Mail.app with the file attached (documented limitation: non-Mail.app default clients don't receive the attachment).
  5. Invoking AirDrop/Mail does not break the panel's non-activating/click-through guarantees — re-verified via the on-device hover→expand→move-down trace.
**Plans**: 2 plans

Plans:
**Wave 1**

- [x] 34-01-PLAN.md — REVISED (UAT drag-target redesign, D-10..D-15): computeQuickActionButtonFrames(card:) pure geometry seam (TDD) + buttons-only, controller-hover-driven NotchPillView.quickActionPickerView at 117pt — supersedes the original click-based pure-seam scope, which shipped but was superseded (original PendingDrop/.quickActionPicker/QuickActionSharingService seams reused verbatim, not re-planned)

**Wave 2** *(blocked on 34-01)*

- [x] 34-02-PLAN.md — REVISED (UAT drag-target redesign): moves pendingDrop population to the dragEntered edge (D-10), fixes the drag-out-before-release session-copy leak (D-13b/Pitfall 6), live per-button drag-hover highlight (D-11) + release-on-target routing (D-12/D-13) replacing the click-based Button(action:) wiring, geometry three-site rule at the new 117pt height + consolidated on-device UAT checkpoint (D-08 spike re-run, CR-01 trace, drag-in/out/re-entry trace, D-04/D-05 transient-interrupt-resume, Drop/AirDrop/Mail real hand-off) — supersedes the original click-based controller wiring, which shipped but was rejected on-device
**UI hint**: yes


## v1.6 Liquid Glass & System HUD Suite — SHIPPED 2026-07-19

Phases 35-42 full detail (goals, success criteria, plans, on-device UAT history) archived to `.planning/milestones/v1.6-ROADMAP.md`. Requirements archived to `.planning/milestones/v1.6-REQUIREMENTS.md`. 11/12 requirements shipped; HUD-07 (Drop-Session Summary Chip, Phase 37) dropped after on-device UAT found its trigger essentially never fires in real usage.

## v1.7 Interaction & Calendar Polish — PLANNED

### Phase 43: Drag Detection Hardening

**Goal**: The island's auto-expand / Quick Action destination picker only fires on a genuine external file drag approaching it — a plain click or hover on the collapsed or expanded island never triggers it, closing the false-trigger regression reported since Phase 24/34 shipped.
**Depends on**: Nothing (independent bugfix, no research dependency)
**Requirements**: DRAG-01
**Success Criteria** (what must be TRUE):
  1. Clicking the collapsed island (an ordinary click, no external drag in progress) never opens the Quick Action picker.
  2. Hovering the collapsed or expanded island with no active external file drag never opens the Quick Action picker.
  3. Dragging a real file from Finder toward the island still reliably auto-expands it and shows the picker, exactly as before — the correct-trigger path is unaffected by the false-trigger fix.
**Plans**: 2 plans
- [x] 43-01-PLAN.md — Add genuine-file-drag gate (isGenuineFileDrag) + wire into recheckDragAcceptRegion/handleDragApproachEnd
- [x] 43-02-PLAN.md — On-device verification of the 3 D-04 scenarios

### Phase 44: Tray & Quick Action Width Alignment

**Goal**: The Tray view (and island) widens so every file icon fits without visual squeeze, and the drag-preview Quick Action picker always renders at that same width — bundled into one phase so the shared width constant is established once and both consumers stay in sync by construction, avoiding a repeat-touch-the-geometry regression (this project's own Phase 31→32 sequencing precedent).
**Depends on**: Nothing (independent bugfix, no research dependency)
**Requirements**: TRAY-06, DRAG-02
**Success Criteria** (what must be TRUE):
  1. At typical file counts, every file icon in the Tray view fits without visual squeezing or overlap; individual file icon/button sizes are unchanged from today.
  2. The Quick Action picker shown during an in-progress drag renders at the exact same width as the real (widened) Tray view — no visible size mismatch between the drag-preview and landed states.
  3. Click-through hit-testing remains correct at the new width — re-verified via the on-device hover→expand→move-down trace, closing off the CR-01/CR-02 failure class.
**Plans**: 2 plans

Plans:
**Wave 1**

- [x] 44-01-PLAN.md — Align the 3-site picker geometry to Tray's real width/height (traySize.width, trayContentHeight + switcherRowHeight) + lock-in button-frame test

**Wave 2** *(blocked on 44-01)*

- [x] 44-02-PLAN.md — On-device verification: picker-vs-Tray size match, click-through hover→expand→move-down trace, button tap-zone re-check, TRAY-06 re-verification

### Phase 45: View Switcher Morph Fix

**STATUS: COMPLETE 2026-07-19.** Plan 45-01 consolidated the 6 per-case switcher-row `blobShape` calls into one shared `tabContentView` call site (`tabWidth`/`tabHeight` computed properties), giving every tab case one continuous view identity for `matchedGeometryEffect` to morph across. Plan 45-02's on-device 12-pairwise-transition sweep confirmed the fix on real hardware: all 12 pairwise tab transitions (both directions) morph continuously with no flicker, no large→small z-order glitch behind the switcher buttons, an interrupted mid-morph tap retargets smoothly (D-01), and the populated/actively-playing Home sub-state is equally glitch-free. SWITCH-01/SWITCH-02 both shipped.

**Goal**: Switching between the Home/Tray/Calendar/Weather views morphs the island continuously to the new view's size via the existing `matchedGeometryEffect` spring, eliminating both the disappear/rebuild flicker and the large→small render-behind-buttons glitch.
**Depends on**: Nothing (independent bugfix, no research dependency)
**Requirements**: SWITCH-01, SWITCH-02
**Success Criteria** (what must be TRUE):
  1. Switching views (Home/Tray/Calendar/Weather, any direction) shows one continuous spring morph directly to the new view's size — the island never visibly disappears or "rebuilds" mid-transition. ✅ Confirmed on-device 45-02.
  2. A large→small transition (e.g., Calendar → Tray) no longer shows the island rendering behind/underneath the switcher pill buttons during the morph. ✅ Confirmed on-device 45-02.
  3. All 12 pairwise view-to-view transitions are verified glitch-free on-device (or a representative sample covering every size-direction combination). ✅ All 12, both directions, walked per D-03 (locked, stricter than sampling) — 45-02.
**Plans**: 2 plans

Plans:
**Wave 1**

- [x] 45-01-PLAN.md — Consolidate presentationSwitch's 6 per-case blobShape calls into one shared tabContentView call site (tabWidth/tabHeight computed props + regression test)

**Wave 2** *(blocked on 45-01)*

- [x] 45-02-PLAN.md — On-device 12-pairwise-transition sweep + interrupted-tap retarget checkpoint
**UI hint**: yes

### Phase 46: Calendar Quick-Add Improvements

**Goal**: Calendar quick-add gains a proper date+time picker with sensible day-aware defaults, the add-event button moves off the currently-clipped right edge, and event rows get more breathing room.
**Depends on**: Nothing (independent bugfix, no research dependency)
**Requirements**: CALVIEW-05, CALVIEW-06, CALVIEW-07
**Success Criteria** (what must be TRUE):
  1. Quick-add shows a date+time picker — Events get a start/end time range, Reminders get a single time — defaulting to the tapped calendar day and the next full hour (if that day is today) or 00:00 (otherwise).
  2. The add-event button sits on the left, next to the day-list divider, fully visible with no clipping — replacing its previous clipped right-edge position.
  3. Calendar event rows in the day list show visibly more padding/margin than today, and the island grows a few pt wider and gains extra height to accommodate the roomier rows without cramping.
**Plans**: 3 plans
**UI hint**: yes

Plans:
**Wave 1**

- [x] 46-01-PLAN.md — Pure seam (defaultQuickAddTime) + QuickAddPopover date+time picker rows, widened onSubmit/onQuickAdd signature (D-01..D-05, D-07)

**Wave 2** *(blocked on 46-01)*

- [ ] 46-02-PLAN.md — NotchWindowController wiring (real dates to CalendarService) + "+ Add" left-edge placement (D-06) + row padding + calendarWidth/calendarContentHeight (D-08/D-09/D-10)

**Wave 3** *(blocked on 46-02)*

- [ ] 46-03-PLAN.md — On-device UAT: date-picker create-flow, button/popover placement, row/island sizing tune (D-11)

### Phase 47: Audio Output Switcher — Pure Seam + Monitor

**Goal**: The pure device-list/sort logic and the event-driven CoreAudio monitor exist and are proven correct in isolation — public, documented API, same risk tier as the already-shipped `VolumeReader`/`BrightnessReader` and `BluetoothMonitor` — safe to build and fully de-risk before any UI is wired to it (research's explicit build-order recommendation).
**Depends on**: Nothing (independent of the bugfix phases and of Favorite/Like; no external API unknowns)
**Requirements**: None formally scoped to this phase — infrastructure phase preceding Phase 48's OUTPUT-01..04, mirroring this project's own pure-seam-first precedent (Phase 15/16/19, Phase 22-01/24-01/38-01/39-01 spikes)
**Success Criteria** (what must be TRUE):
  1. `AudioOutputPresentation`'s device value type and sort/reorder logic are pure, unit-tested Foundation-only code with zero AppKit/SwiftUI dependency.
  2. `AudioOutputMonitor` enumerates real system audio-output devices, keyed by the stable `kAudioDevicePropertyDeviceUID` (never the session-ephemeral `AudioDeviceID`), and reflects live connect/disconnect/default-output changes via `AudioObjectAddPropertyListener`.
  3. Every CoreAudio callback-driven state update is confirmed to hop to the main thread before touching `@Published` state (mirrors `BluetoothMonitor`'s already-solved pattern).
  4. Per-device volume-property support (`kAudioDevicePropertyVolumeScalar`) is verified against the dev machine's actual Bluetooth headset, not just built-in speakers, so Phase 48 can wire a slider to it with confidence.
**Plans**: TBD

### Phase 48: Audio Output Switcher — UI Wiring

**Goal**: The reserved speaker-icon slot (right of the transport controls, held open since Phase 27's D-09) in the expanded Now Playing view becomes a real, working audio-output switcher — zero remaining external-API risk once Phase 47 lands, per research.
**Depends on**: Phase 47 — hard dependency; the panel wires against the pure seam and monitor built there.
**Requirements**: OUTPUT-01, OUTPUT-02, OUTPUT-03, OUTPUT-04
**Success Criteria** (what must be TRUE):
  1. Tapping the speaker icon reveals a panel with a thick draggable volume slider that controls the current audio output's real system volume in real time.
  2. The panel shows a vertical list of all available system audio outputs, with the current output visually highlighted and shown on top, others listed below.
  3. Tapping a non-current output in the list makes it the active system audio output and it animates to the top of the list (tap-to-select, not drag-to-reorder).
  4. The output list stays correct — no duplicate or stale entries — when a device connects or disconnects while the panel is open (e.g. AirPods reconnect), keyed by device UID not `AudioDeviceID`.
**Plans**: TBD
**UI hint**: yes

### Phase 49: Favorite/Like — Spike

**Goal**: Resolve this milestone's three genuine, undocumented/policy-gated unknowns — Apple Music `current track`/`loved` reliability, Spotify OAuth/quota-mode reality, and the Automation (TCC) permission-prompt bug — on real hardware, producing a documented go/no-go scope decision before any Favorite/Like UI is planned in detail. Mirrors this project's own Phase 22/24 (drag-in) and Phase 38/39 (undocumented-API) spike-first precedent.
**Depends on**: Nothing — shares no code path with the Audio Output Switcher work (Phases 47-48), so this spike can proceed independently and in parallel-safe order.
**Requirements**: None formally scoped to this phase — spike phase preceding Phase 50's FAV-01..03, mirroring Phase 22-01/24-01/38-01/39-01 precedent
**Success Criteria** (what must be TRUE):
  1. A real round-trip test confirms (or disproves) whether the vendored `mediaremote-adapter` wrapper can send a like/love command, and whether the streamed payload ever reports a favorite read-state.
  2. Apple Music's `current track`/`loved` AppleScript behavior is confirmed on this project's own dev hardware across library, streaming-only, and play/pause states — not assumed transferable from forum reports.
  3. A real Spotify OAuth PKCE round-trip plus a real `PUT` save-track call is exercised, and current quota-mode/Extended-Access criteria are confirmed directly on the Spotify Developer Dashboard.
  4. The Automation (Apple Events/TCC) permission-prompt reliability bug is reproduced or ruled out on this hardware, and a documented go/no-go scope decision (ship Spotify OAuth / bring-your-own-Client-ID / Apple-Music-only for this milestone) is recorded.
**Plans**: TBD

### Phase 50: Favorite/Like — Implementation

**Goal**: A star button in the expanded Now Playing view lets the user favorite/like the current track, writing back to the source app's own library, scoped precisely to what Phase 49's spike confirmed is real (read/write, write-only, or Apple-Music-only).
**Depends on**: Phase 49 — hard dependency; the concrete write path (and whether Spotify ships at all) is only known once the spike concludes.
**Requirements**: FAV-01, FAV-02, FAV-03
**Success Criteria** (what must be TRUE):
  1. A star button, positioned left of the transport controls in the expanded Now Playing view, toggles the current track's favorite/liked status and writes back to Apple Music (AppleScript `loved`) and/or Spotify (OAuth Web API), per Phase 49's confirmed scope.
  2. Spotify write-back (if shipped) works only for accounts explicitly authorized through Islet's own OAuth flow, with the small-quota limitation documented (Settings/About), not silently discovered by the user.
  3. If a like/favorite write fails (e.g. a streaming-only track Apple Music can't yet love, or an expired/unauthenticated Spotify session), the star button visibly reflects the failure rather than silently appearing to succeed.
**Plans**: TBD
