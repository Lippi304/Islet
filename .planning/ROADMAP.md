# Roadmap: Notch — Dynamic Island for Mac

## Milestones

- ✅ **v1.0 MVP** — Phases 0-6 (shipped 2026-07-02)
- ✅ **v1.0.1 Pre-Release Polish** — Phases 7-9 (shipped 2026-07-04)
- ✅ **v1.1 Trial & Paid Release** — Phases 10-13 (shipped 2026-07-08)
- ✅ **v1.2 Now Playing Polish** — Phases 17-18 (shipped 2026-07-09)
- ✅ **v1.3 Notch Shelf** — Phases 19-21 (shipped 2026-07-11, known gap: SHELF-01/02 drag-in deferred to v1.4)
- 🚧 **v1.4 Architecture Redesign** — Phases 23-28 (in progress)

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

**v1.4:** 5/6 phases complete (83%) — Phases 23 (Shell Parity Rewrite), 24 (Drag-In), 25 (Visual/Material Theming Redesign), 26 (Onboarding Flow), and 27 (Settings Sidebar Redesign) are done; only Phase 28 (Calendar Full View) remains.

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
