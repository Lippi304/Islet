# Roadmap: Notch — Dynamic Island for Mac

## Milestones

- ✅ **v1.0 MVP** — Phases 0-6 (shipped 2026-07-02)
- ✅ **v1.0.1 Pre-Release Polish** — Phases 7-9 (shipped 2026-07-04)
- ✅ **v1.1 Trial & Paid Release** — Phases 10-13 (shipped 2026-07-08)
- 🚧 **v1.2 Now Playing Polish** — Phases 17-18 (in progress)

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

### 🚧 v1.2 Now Playing Polish (Phases 17-18, in progress)

**Milestone Goal:** Fix the Now-Playing launch behavior (an already-paused track must not trigger
the glance until the user actually presses Play) and add a brief song-change toast that shows the
new track's title as text when playback switches to a genuinely new song.

- [x] **Phase 17: Now Playing Launch Gating** - Islet stays idle at launch for a paused/loaded track; only a transition into actively-playing triggers the glance (completed 2026-07-09)
- [ ] **Phase 18: Song-Change Toast** - a brief title toast on genuine track changes, with its own Settings toggle

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

**v1.2:** 1/2 phases complete (50%) — Phase 17 complete, Phase 18 ready to plan.

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

### Phase 17: Now Playing Launch Gating

**Goal:** Islet no longer shows the Now Playing glance at launch just because an allowlisted
player has a paused/loaded track sitting in its session — the glance appears only once the user
actually starts playback. A restart with music already actively playing is unaffected.
**Requirements**: NOW-04
**Depends on:** Phase 16
**Success Criteria** (what must be TRUE):
  1. Launching Islet while Spotify/Apple Music has a track loaded but paused shows no Now Playing glance.
  2. Pressing Play after such a launch makes the glance appear immediately, with correct track info.
  3. Launching Islet while a track is already actively playing still shows the glance immediately (no regression from today's behavior).
**Plans:** 1/1 plans complete

Plans:
**Wave 1**

- [x] 17-01-PLAN.md — hasPlayedSinceLaunch gate: pure resolve() signature change + IslandResolverTests coverage, controller wiring (flip on Play + thread into resolve), on-device verification checkpoint

### Phase 18: Song-Change Toast

**Goal:** Users get a brief, glanceable cue whenever playback switches to a genuinely different
song, and can turn that cue off if they don't want it — without affecting the underlying Now
Playing glance itself.
**Requirements**: NOW-05, NOW-06
**Depends on:** Phase 17
**Success Criteria** (what must be TRUE):
  1. When playback switches to a new song (not the very first track detected after launch), the island briefly expands downward showing the new title as text, then collapses back to the compact glance after ~3s.
  2. The toast does not fire for the first track detected after launch, or for pause/resume/scrub of the same track.
  3. Settings' Activities tab has a toggle for the song-change toast, positioned next to the existing Now Playing toggle.
  4. Turning the toggle off suppresses the toast on subsequent track changes while the Now Playing glance itself keeps working normally.
**Plans:** 2 plans

Plans:
**Wave 1**

- [ ] 18-01-PLAN.md — Pure seam (TrackToast/songChangeToastContent/songChangeToastGate) + NOW-06 Settings toggle
**Wave 2** *(blocked on 18-01)*

- [ ] 18-02-PLAN.md — Controller wiring (detection, ~3s dismiss timer, toggle-off live-clear) + toast render + on-device verification
**UI hint**: yes
