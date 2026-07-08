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

### Phase 15: Architecture Refactor: NotchWindowController & NotchPillView Decomposition — targeted extraction (coordinators, DI seams, shared view helpers) per the full-codebase audit, zero product-behavior change

**Goal:** [To be planned]
**Requirements**: TBD
**Depends on:** Phase 14
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 15 to break down)
