# Roadmap: Notch — Dynamic Island for Mac

## Milestones

- ✅ **v1.0 MVP** — Phases 0-6 (shipped 2026-07-02)
- ✅ **v1.0.1 Pre-Release Polish** — Phases 7-9 (shipped 2026-07-04)
- ✅ **v1.1 Trial & Paid Release** — Phases 10-13 (shipped 2026-07-08)
- ✅ **v1.2 Now Playing Polish** — Phases 17-18 (shipped 2026-07-09)
- ✅ **v1.3 Notch Shelf** — Phases 19-21 (shipped 2026-07-11, known gap: SHELF-01/02 drag-in deferred to v1.4)
- 🚧 **v1.4 Architecture Redesign** — Phases 23-28 (in progress)
- 📋 **v1.5 Home Focus & Widget Redesign** — Phases 29-34 (planned)
- 📋 **v1.6 Liquid Glass & System HUD Suite** — Phases 35-42 (planned)

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

### 📋 v1.6 Liquid Glass & System HUD Suite (Planned)

**Milestone Goal:** Give Islet an edgier "Liquid Glass" material look and a suite of new Droppy-style collapsed-state system HUDs, plus a new dual-activity display concept for when two top-priority activities are live at once. Sequenced material-first (every other visual feature renders inside it), then risk-ascending through the new-transient-case pattern (cosmetic restyles → drop-session chip → Focus Mode spike → Volume/Brightness spike), with the fully-independent Sparkle integration floating after Phase 35, and the architecturally novel dual-activity display sequenced last, after Calendar Countdown exists as a proven single-winner case to combine with Now Playing. Numbered from Phase 35 to avoid colliding with v1.5's still-open Phase 34 (v1.5 remains open in parallel, not archived).

- [x] **Phase 35: Liquid Glass Material** - Shared background material (pill, expanded island, all wings) replaced by the Liquid Glass look from user-supplied reference code (completed 2026-07-16)
- [x] **Phase 36: Cosmetic Restyles & Signature Animation** - Bluetooth/Charging HUD restyles, equalizer bars redesign, onboarding signature animation — pure view-layer, zero resolver/monitor changes (completed 2026-07-16)
- [x] **Phase 37: Drop-Session Summary Chip** - ABANDONED after on-device UAT (completed 2026-07-17, reverted 2026-07-17) — see phase detail below
- [ ] **Phase 38: Focus Mode HUD** - Research spike + generic on/off Focus/DND HUD, first new ActiveTransient case
- [ ] **Phase 39: Volume & Brightness HUD** - Research spike + shared OSD-replacement subsystem for volume/brightness key presses
- [ ] **Phase 40: Update-Available HUD & Sparkle Integration** - Real Sparkle 2 auto-update + update-available HUD/badge
- [ ] **Phase 41: Calendar Countdown HUD** - Live minute-countdown starting 1 hour before a calendar event, own persistent timer
- [ ] **Phase 42: Dual-Activity Display** - Main pill + secondary bubble when two top-priority activities are live at once, additive resolver extension

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

**v1.6:** 1/8 phases complete (13%) — roadmap created 2026-07-15. Phases 35-42, 12/12 v1.6 requirements mapped. Left open in parallel with v1.5 (not archived); numbering starts at 35 to avoid colliding with v1.5's still-open Phase 34. Phase 35 (GLASS-01) completed 2026-07-16 — on-device UAT required 4 rounds (round 1 flat opaque grey, round 2 uniformly bright, round 3 screen-blend washout over the frost's dark center, round 4 rim-masked the fringe/wash layers to the same edge falloff and passed); see 35-12-SUMMARY.md. A round-5 post-completion regression (flat grey rim, D-20) pivoted the island to SwiftUI's native `.glassEffect()` on macOS 26+, keeping the custom shader as the `<26` fallback; see 35-12-ADDENDUM-SUMMARY.md.

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

**Goal**: Users get a full calendar view — month grid, day detail, and quick-add — as a third view alongside Home and Tray, sharing one EventKit service layer with the existing glance.
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

### Phase 35: Liquid Glass Material

**Goal**: The shared background material — pill, expanded island, and all activity wings — is replaced by a "Liquid Glass" look (glossier, blurred/frosted, not glass-clear), built from user-supplied reference code and plugging into the existing `MaterialStyle`/`islandMaterial` seam. Every later HUD phase in this milestone inherits the finished material for free instead of retrofitting each new view individually.
**Depends on**: Nothing — first phase of the v1.6 milestone.
**Requirements**: GLASS-01
**Success Criteria** (what must be TRUE):
  1. The collapsed pill, expanded island, and every activity wing (Charging, Device, Now Playing) render the new Liquid Glass material, replacing today's gradient material.
  2. The new material is applied as a modifier on the existing shape node that already carries the `matchedGeometryEffect` id — not a new sibling/wrapper view — so morph continuity is preserved.
  3. A Phase-25-style on-device UAT checklist (material renders correctly through collapse↔expand, no artifacts, no dropped frames) passes as a hard merge gate.
  4. The visual result is user-approved on-device against the supplied reference code.
**Plans**: 12 plans (35-05 rejected on-device round 1 — flat opaque grey, no transparency; 35-08 rejected on-device round 2 — uniformly bright/light, no dark glass; 35-10 rejected on-device round 3 — uniform silvery/washed-out, unmasked fringe+wash screen-blending over the frost's dark center; superseded by round-4 remediation plans 35-11/35-12 per 35-CONTEXT.md D-16/D-17/D-18/D-19)
**UI hint**: yes

Plans:
**Wave 1**

- [x] 35-01-PLAN.md — MaterialStyle.liquidGlass case (D-05) + EnvironmentKey default flip (D-06) + islandFill exhaustive-switch branch
- [x] 35-02-PLAN.md — LiquidGlassShader.metal distortion function (D-01) + LiquidGlassParameters/channelShaders contract (D-04)

**Wave 2** *(blocked on 35-01, 35-02)*

- [x] 35-03-PLAN.md — liquidGlassEffectLayer helper wired into all 4 island-shell fill sites (D-01/D-02/D-03/D-04)
- [x] 35-04-PLAN.md — Settings Theming picker 3rd segment + default flip (D-05/D-06) + calmer Settings-window background (D-08/D-09) *(blocked on 35-01 only, parallel to 35-03)*

**Wave 3** *(blocked on 35-03, 35-04)*

- [x] 35-05-PLAN.md — On-device UAT hard merge gate, round 1 (Success Criteria #3/#4) — **REJECTED** (flat opaque grey, no visible warp/transparency; see 35-UAT.md Test 1) — root cause D-02 superseded by D-10/D-11, remediated by 35-06/35-07/35-08 below

**Wave 4 (remediation)** *(blocked on 35-02)*

- [x] 35-06-PLAN.md — liquidGlassEdgeFalloff shared helper + liquidGlassEdgeOpacity colorEffect shader (D-11) + retuned LiquidGlassParameters (D-10/D-11)

**Wave 5 (remediation)** *(blocked on 35-06, 35-03)*

- [x] 35-07-PLAN.md — islandFill + liquidGlassEffectLayer translucent-material wiring (D-10/D-11)

**Wave 6 (remediation)** *(blocked on 35-06, 35-07)*

- [x] 35-08-PLAN.md — On-device UAT hard merge gate, round 2 (Success Criteria #3/#4) — supersedes rejected 35-05 — **REJECTED (round 2)** (island now translucent but reads as uniformly bright/light, not dark glass with edge-only bleed; see 35-UAT.md Test 1 Round 2) — root cause hypothesis: raw `.ultraThinMaterial` has no inherent dark tint, needs remediation round 3

**Wave 7 (remediation round 3)** *(blocked on nothing new — restructures 35-06/35-07's already-merged code)*

- [x] 35-09-PLAN.md — islandFill D-12 frost base + liquidGlassEffectLayer frost-over-material compositing (D-12/D-13/D-14/D-15) + retuned LiquidGlassParameters — no `.metal` file changes, reuses liquidGlassEdgeOpacity as-is

**Wave 8 (remediation round 3)** *(blocked on 35-09)*

- [x] 35-10-PLAN.md — On-device UAT hard merge gate, round 3 (Success Criteria #3/#4) — supersedes rejected 35-05/35-08 — **REJECTED (round 3)** (uniform, medium-grey/silvery panel across the whole surface, no dark near-opaque center, no clear rim contrast; see 35-UAT.md Test 1 Round 3) — root cause: unmasked chromatic-fringe passes (.blendMode(.screen)) + trailing white-wash overlay lighten the WHOLE surface including the frost's dark center, remediated by 35-11/35-12 below

**Wave 9 (remediation round 4)** *(blocked on nothing new — restructures 35-09's already-merged code)*

- [x] 35-11-PLAN.md — Mask the 3 chromatic-fringe passes + white-wash overlay to the shared liquidGlassEdgeOpacity falloff via a new liquidGlassRimMask helper (D-16/D-17/D-18) — no `.metal`/parameter-file changes, reuses liquidGlassEdgeOpacity as-is with mask-only arguments

**Wave 10 (remediation round 4)** *(blocked on 35-11)*

- [x] 35-12-PLAN.md — On-device UAT hard merge gate, round 4 (Success Criteria #3/#4) — supersedes rejected 35-05/35-08/35-10 (D-19: single UAT round, no intermediate checkpoint)

**Post-completion regression (round 5, outside formal plan artifacts)** — 2026-07-16, resolved via `.planning/debug/resolved/liquid-glass-grey-rim-regression.md`: round 4 was approved but a fresh on-device look showed a flat grey rim, no color. Root cause: 2 latent bugs the UAT screenshots never exercised (collapsed-pill DEBUG red-tint override; under-separated RGB fringe offsets) plus D-20's architectural pivot — the custom Metal shader (D-01–D-19) is now the `<macOS 26` fallback; `macOS 26.0+` uses SwiftUI's native `.glassEffect(_:in:)` for real system-rendered glass. Re-verified on-device, user-approved.

### Phase 36: Cosmetic Restyles & Signature Animation

**Goal**: Bluetooth/AirPods and Charging activities are restyled to the Droppy-pill look, the Now Playing equalizer bars get a new visual design, and the onboarding flow's first page gains a static rainbow-gradient signature-style heading — all pure view-layer changes with zero resolver, monitor, or data changes, proving the new visual language renders correctly inside Phase 35's material.
**Depends on**: Phase 35 — these restyles render inside the new Liquid Glass material rather than the old one.
**Requirements**: HUD-01, HUD-02, EQ-01, ONBOARD-04
**Success Criteria** (what must be TRUE):
  1. The Bluetooth/AirPods device-connected activity visually matches the Droppy-pill restyle; `DeviceCoordinator`/`BluetoothMonitor` are unchanged.
  2. The Charging activity visually matches the Droppy-pill restyle; the existing IOKit power monitor is unchanged.
  3. The Now Playing equalizer bars render the user-supplied reference visual design with no change to the underlying playback data or monitor.
  4. (D-14 scope pivot) The onboarding flow's first page shows a static rainbow-gradient signature-style script heading ("Meet" in blue→purple→pink, "Islet" in orange→yellow→green, Dancing Script Bold) replacing the "Welcome to Islet" text — scoped to that one page only, the rest of the app's typography is unaffected. Originally specified as a live stroke-reveal animation; descoped to a static heading after repeated font-licensing/implementation friction, per direct user decision.
**Plans**: 4 plans (waves: 1={36-01,36-03}, 2={36-02}, 3={36-04})

Plans:
- [x] 36-01-PLAN.md — Charging + Bluetooth Droppy-pill wing restyle (HUD-01, HUD-02)
- [x] 36-02-PLAN.md — Equalizer bars motion/geometry redesign + Skiper UI attribution (EQ-01)
- [x] 36-03-PLAN.md — Signature font (OFL) + Core Text glyph-extraction contract (ONBOARD-04)
- [x] 36-04-PLAN.md — Signature heading: static rainbow-gradient design (scope-pivoted from stroke-reveal animation, ONBOARD-04)
**UI hint**: yes

### Phase 37: Drop-Session Summary Chip — ABANDONED

**Status**: All 4 plans (37-01/02/03/04) were executed and merged 2026-07-17, then fully reverted the same day after failing on-device UAT (37-04). Reason: the chip's trigger requires the user to explicitly close the Tray after a drop, but in real usage the Island stays open showing the dropped files and isn't closed right away — the trigger condition essentially never fires under normal use. Per user decision, the feature isn't worth keeping; all code was reverted via `git revert` (5 commits, working tree confirmed clean of all `sessionFilesSaved`/`dropSessionChipGate`/`SessionSummaryChip`/`chipDismissWorkItem` traces, build re-verified green). HUD-07 is dropped from the milestone's requirement set.

**Goal** *(as originally planned, not achieved)*: After the Tray is closed following a drop session, a brief "N files saved" chip appears — first adding the missing "shelf session" boundary concept to `ShelfViewState`/`ShelfCoordinator`, then building the chip itself as a one-shot orthogonal toast reusing the already-shipped Phase-18 song-change-toast pattern.
**Depends on**: Nothing hard — independent of Phases 35-36, though it renders inside whatever material is current.
**Requirements**: ~~HUD-07~~ (dropped)
**Success Criteria** (what must be TRUE) — never reached, superseded by abandonment:
  1. `ShelfViewState`/`ShelfCoordinator` track an explicit session boundary (files dropped since Tray was last closed), distinct from today's `isVisible = !items.isEmpty` check.
  2. Closing the Tray after at least one file was dropped during that session briefly shows a chip reading "N files saved," then auto-dismisses.
  3. Closing the Tray with zero files dropped during that session shows no chip.
  4. The chip is implemented as a one-shot `@Published` orthogonal toast (mirroring Phase 18's song-change toast), not a new `IslandResolver`/`TransientQueue` case.
**Plans**: 4 plans (waves: 1={37-01}, 2={37-02,37-03}, 3={37-04}) — all executed, then reverted

Plans:
**Wave 1**

- [x] 37-01-PLAN.md — Session-boundary pure seams: ShelfCoordinator gross counter/resetSession() + IslandResolver dropSessionChipGate + ShelfViewState SessionSummaryChip/dropSessionChipContent/sessionSummaryChip *(reverted)*

**Wave 2** *(blocked on 37-01)*

- [x] 37-02-PLAN.md — NotchPillView chip rendering: chipTextRow(_:) wired into collapsedIsland and mediaWingsOrToast *(reverted)*
- [x] 37-03-PLAN.md — NotchWindowController wiring: collapse-trigger (D-01/D-02/D-03/D-06) + interrupt-clear (D-07) *(reverted)*

**Wave 3** *(blocked on 37-02, 37-03)*

- [x] 37-04-PLAN.md — On-device UAT checkpoint — FAILED (chip's Tray-close trigger doesn't fire in real usage), phase abandoned and reverted

### Phase 38: Focus Mode HUD

**Goal**: A generic on/off Focus Mode HUD appears when the user toggles Focus/Do Not Disturb — an on-device research spike confirms the detection mechanism first, then the feature is built as the first genuinely new `ActiveTransient` case in this milestone, proving the "new pure Activity type → Monitor → resolver case → wing view" pipeline once, cheaply, before Phase 39 attempts the same pipeline under real private-API risk.
**Depends on**: Nothing hard — independent of Phases 35-37, sequenced here per research to prove the new-transient pipeline before the higher-risk Volume/Brightness phase.
**Requirements**: HUD-05
**Success Criteria** (what must be TRUE):
  1. An on-device spike confirms and records which detection path is used (`INFocusStatusCenter`'s public boolean signal, preferred, vs. Assertions.json polling behind a manual Full Disk Access grant) before full implementation proceeds.
  2. Toggling Focus/DND on shows the new HUD in a generic "Focus On" state; toggling off dismisses it or shows "Focus Off" — no named-mode text (e.g. "Work Focus") anywhere.
  3. If the Full-Disk-Access-gated path is required, denying that permission degrades silently (no crash, no stuck state) rather than blocking the rest of the app.
  4. The new `FocusActivity`/`FocusModeMonitor` pipeline routes through `IslandResolver`/`TransientQueue` like every other transient — no resolver bypass.
**Plans**: 7 plans (waves: 1={38-01,38-02}, 2={38-03,38-04}, 3={38-05,38-06}, 4={38-07}) — D-12 descope gate: if the Wave 1 spike (38-01) finds neither detection path viable, Plans 38-04 through 38-07 do not execute and the phase is closed out per Phase 37's abandonment precedent.
**UI hint**: yes

Plans:
**Wave 1**

- [x] 38-01-PLAN.md — On-device detection-path spike (checkpoint): confirms INFocusStatusCenter vs. Assertions.json+FDA, or records a D-12 descope decision
- [x] 38-02-PLAN.md — Pure seams (TDD): FocusActivity.swift + IslandResolver.swift extension (ActiveTransient.focus, IslandPresentation.focus, D-07 where-guard, ActiveTransient.isPersistent for D-06, TransientQueue.preempt(_:) for D-08)

**Wave 2** *(blocked on Wave 1)*

- [ ] 38-03-PLAN.md — FocusModeMonitor.swift (spike-confirmed detection path) + ActivitySettings.swift (focusKey, D-05 status-hint mapping) — halts here if 38-01 recorded a descope
- [ ] 38-04-PLAN.md — NotchPillView.swift focusWings(for:) (D-10/D-11 Droppy-pill wing) + presentationSwitch dispatch + preview

**Wave 3** *(blocked on Wave 2)*

- [ ] 38-05-PLAN.md — NotchWindowController.swift wiring: monitor lifecycle, D-06 non-self-dismiss guard, D-08 Charging/Device preemption at both enqueue sites, D-09 silent off-flush
- [ ] 38-06-PLAN.md — SettingsView.swift: opt-in toggle (D-01), permission-status hint (D-05), explanation popover + deep-link/authorization trigger (D-02/D-03/D-04)

**Wave 4** *(blocked on Wave 3)*

- [ ] 38-07-PLAN.md — Remove the Wave 1 spike scaffolding + consolidated on-device UAT checkpoint (persistence, preemption, collapsed-only scope, silent off, fresh-install-no-permission)

### Phase 39: Volume & Brightness HUD

**Goal**: Volume and Brightness HUDs appear on key press in the Droppy-pill style and suppress the native macOS OSD when an on-device spike confirms it's safe — the milestone's single highest-risk item, isolated as its own spike-then-implement phase per this project's own Phase 22/Phase 8→9 precedent, sharing one OSD-replacement subsystem across both HUDs rather than duplicating the risky suppression work.
**Depends on**: Nothing hard — independent of Phases 35-38, but reuses the `ActiveTransient` pipeline shape Phase 38 proves first.
**Requirements**: HUD-03, HUD-04
**Success Criteria** (what must be TRUE):
  1. An on-device spike confirms `.cgSessionEventTap` (never the annotated variant) intercepts volume/brightness `NX_SYSDEFINED` events without breaking any of the 4 media transport keys, with the go/no-go decision and fallback behavior (show the HUD alongside the native OSD if suppression proves unreliable) explicitly recorded before full implementation.
  2. Pressing a volume key shows the new Volume HUD reflecting the live system volume level; pressing a brightness key shows the new Brightness HUD reflecting the live brightness level.
  3. Rapid repeated key presses (scrubbing) update the same HUD instance in place via `TransientQueue.updateHead()` rather than stacking multiple transients.
  4. The undocumented `EnableSystemBanners` Control-Center-wide defaults toggle is not used anywhere in the implementation.
**Plans**: TBD
**UI hint**: yes

### Phase 40: Update-Available HUD & Sparkle Integration

**Goal**: A real Sparkle 2 auto-update integration ships alongside an update-available HUD/badge — independent of every other phase in this milestone, floats anywhere after Phase 35.
**Depends on**: Nothing hard — independent, can be sequenced anywhere after Phase 35.
**Requirements**: HUD-06
**Success Criteria** (what must be TRUE):
  1. Islet checks for updates via a real `SPUStandardUpdaterController`/`SPUUpdater`, with a "Check for Updates…" menu item available from the status-item menu.
  2. When a new version is published, the collapsed island shows an update-available HUD/badge, implemented as an orthogonal `@Published` flag (not a `TransientQueue` participant, since it has no expiry).
  3. Tapping the HUD triggers Sparkle's own standard install/progress dialog — confirmed on-device not to steal focus or otherwise break the panel's non-activating/click-through guarantees in this LSUIElement app.
  4. The embedded Sparkle framework is signed/entitled correctly (mirroring the existing `MediaRemoteAdapter` disable-library-validation treatment) so Release builds launch without a Gatekeeper/library-validation crash.
**Plans**: TBD
**UI hint**: yes

### Phase 41: Calendar Countdown HUD

**Goal**: Starting 1 hour before a calendar event, the collapsed pill shows a live minute-countdown (calendar icon left, event time right), driven by its own persistent per-minute timer rather than the shared 3s `activityDuration` auto-dismiss pattern. Calendar data already exists via EventKit (Phase 28) — this phase de-risks the timer/data pipeline as a single-winner ambient feature before Phase 42 needs it as a proven input.
**Depends on**: Nothing hard — EventKit data already shipped in Phase 28; sequenced before Phase 42 so dual-activity has a proven single-winner case to combine with Now Playing.
**Requirements**: HUD-08
**Success Criteria** (what must be TRUE):
  1. Within 1 hour of a real calendar event's start time, the collapsed pill shows a calendar icon (left) and a live minutes-remaining countdown (right) that updates continuously without user interaction.
  2. The countdown HUD dismisses at (or shortly after) the event's start time, using its own scheduling — never the shared 3s `activityDuration` auto-dismiss.
  3. The countdown timer is scheduled to actual minute boundaries rather than a tight poll loop, verified via Activity Monitor's Idle Wake Ups column showing no regression.
  4. The countdown participates in `IslandResolver` as an ambient single-winner activity, correctly yielding to any higher-priority Charging/Device transient.
**Plans**: TBD
**UI hint**: yes

### Phase 42: Dual-Activity Display

**Goal**: When two top-priority activities are live simultaneously (e.g. the Calendar countdown and Now Playing), the collapsed state shows a main pill plus a small secondary bubble instead of one activity strictly winning — the milestone's single most architecturally novel change, extending the single-winner `IslandResolver` via an additive `secondary: SecondaryActivity?` field rather than reshaping `IslandPresentation`. Sequenced last, after Phase 41 gives it a real, independently-stable single-winner case to combine with Now Playing.
**Depends on**: Phase 41 — needs Calendar Countdown proven and independently correct before this phase has to solve only "how do two correct signals combine," not "is this new signal even correct."
**Requirements**: DUAL-01
**Success Criteria** (what must be TRUE):
  1. With Calendar Countdown and Now Playing both live at once, the collapsed island shows a main pill (one activity) plus a small secondary bubble (the other) rather than one activity hiding the other.
  2. The primary/secondary promotion-demotion rule is implemented as an explicit ordered table (not scattered conditionals) and correctly generalizes to any two competing top-priority activities, not just Calendar+Music.
  3. Primary and secondary slots use distinct `matchedGeometryEffect` namespaces — no visual glitches, geometry collisions, or dropped frames when either slot's content changes.
  4. The extension is additive — the existing `IslandResolver.resolve()` single-winner pass and every existing `IslandPresentation` switch site are otherwise unchanged, confirmed via a diff review.
**Plans**: TBD
**UI hint**: yes
