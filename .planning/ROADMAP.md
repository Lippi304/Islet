# Roadmap: Notch — Dynamic Island for Mac

## Milestones

- ✅ **v1.0 MVP** — Phases 0-6 (shipped 2026-07-02)
- ✅ **v1.0.1 Pre-Release Polish** — Phases 7-9 (shipped 2026-07-04)
- ✅ **v1.1 Trial & Paid Release** — Phases 10-13 (shipped 2026-07-08)

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
**Plans:** 5 plans

Plans:
**Wave 1**

- [ ] 15-01-PLAN.md — NotchGeometry DRY (topPinnedFrame) + NotchPillView blobShape() extraction (items 1, 2)
- [ ] 15-02-PLAN.md — LocationProvider protocolization + BasicOutfitState @MainActor + weather/calendar visibility-arbiter gap fix (items 3, 5)
- [ ] 15-03-PLAN.md — LicenseState dependency-injection seam + LicenseStateTests.swift (item 4)
- [ ] 15-04-PLAN.md — Preserve the real Polar.sh validation payload end-to-end (item 7)

**Wave 2** *(blocked on 15-01)*

- [ ] 15-05-PLAN.md — EqualizerBars re-render reshuffle bug fix (item 6)

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
**Requirements**: TBD (source: this session's full-codebase architecture audit)
**Depends on:** Phase 15
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 16 to break down)
