# Roadmap: Notch — Dynamic Island for Mac

## Milestones

- ✅ **v1.0 MVP** — Phases 0-6 (shipped 2026-07-02)
- ✅ **v1.0.1 Pre-Release Polish** — Phases 7-9 (shipped 2026-07-04)
- ✅ **v1.1 Trial & Paid Release** — Phases 10-13 (shipped 2026-07-08)
- ✅ **v1.2 Now Playing Polish** — Phases 17-18 (shipped 2026-07-09)
- 🚧 **v1.3 Notch Shelf** — Phases 19-22 (in progress)

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

### 🚧 v1.3 Notch Shelf (Phases 19-22) — In Progress

**Milestone Goal:** Add a drag-and-drop file shelf to the island — a temporary, session-only staging area for files, matching the polish of the existing activities.

- [x] **Phase 19: Shelf Data Model** - Pure, unit-tested shelf lifecycle (append/remove/clear, never persisted) with zero AppKit/drag risk (completed 2026-07-09)
- [x] **Phase 20: Shelf View** - Users can see and manage a populated shelf strip in the expanded island (icons, per-item/delete-all trash, click-to-open, gated correctly against other activities) — CR-01 click-through gap closed in 20-03 (completed 2026-07-10)
- [x] **Phase 21: Drag-Out** - Users can drag shelf items back out to Finder or other apps (completed 2026-07-10)
- [ ] **Phase 22: Drag-In** - Users can drag files/folders onto the collapsed island to add them to the shelf

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

**v1.3:** 2/4 phases complete (50%) — Phase 21 (Drag-Out) ready to plan.

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

- [ ] 22-02-PLAN.md — Pure seams: nextState .dragEntered event (D-01) + DragDropSupport.swift (URL extraction + D-04/non-file gate) + folder round-trip test

**Wave 3** *(blocked on 22-02)*

- [ ] 22-03-PLAN.md — NotchPanel permanent registration/forwarding + NotchWindowController drag-in handlers (D-01/D-02b/D-02c/D-03/D-04/D-05/D-06) + on-device UAT checkpoint, including the D-02b/D-02c expandedZone + landing-margin boundary check
