# Roadmap: Notch — Dynamic Island for Mac

## Milestones

- ✅ **v1.0 MVP** — Phases 0-6 (shipped 2026-07-02)
- ✅ **v1.0.1 Pre-Release Polish** — Phases 7-9 (shipped 2026-07-04)
- 🚧 **v1.1 Trial & Paid Release** — Phases 10-13 (in progress)

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

### 🚧 v1.1 Trial & Paid Release (In Progress)

**Milestone Goal:** Islet becomes a real, sellable product — a 3-day free trial, then a one-time €7.99 purchase via Polar.sh, enforced by a local license check, shipped as a genuinely Developer-ID-notarized build.

- [x] **Phase 10: Trial & Lockout Gate** - Silent 3-day trial with tamper-resistant Keychain persistence and a hard functionality lockout, proven against a stubbed license state — completed 2026-07-05
- [x] **Phase 11: License Settings UI (Stubbed)** - Days-remaining, Buy Now, and license-entry UI in Settings, wired against a fake in-memory license service (completed 2026-07-05)
- [ ] **Phase 12: Real Polar.sh License Integration** - Swap the stub for a real `PolarLicenseService` — live checkout, online validation, offline-capable Keychain cache
- [ ] **Phase 13: Real Notarization & Release** - Real Developer-ID sign → notarize → staple pipeline, replacing the v1.0 dry-run placeholders

## Phase Details

### Phase 10: Trial & Lockout Gate

**Goal**: The app enforces a real, tamper-resistant 3-day trial with a hard functionality lockout — proven end-to-end using a manually-settable stub license state, with no live network dependency.
**Depends on**: Nothing new (builds on the existing v1.0.1 codebase, specifically `NotchWindowController`'s single-arbiter `shouldShow(...)`)
**Requirements**: TRIAL-01, TRIAL-02, LIC-03
**Success Criteria** (what must be TRUE):

  1. On first launch, the trial start timestamp is persisted to the Keychain — running `defaults delete` on the app or deleting/reinstalling it does not reset the trial clock.
  2. On first launch (and only on first launch), the user sees an explicit one-time notice stating the 3-day trial has started — never a silent start.
  3. With the trial active or a stub license flagged valid, the island behaves exactly as before (no regression to existing v1.0/v1.0.1 behavior).
  4. With the trial expired and the stub license flagged invalid/absent, the island is fully locked — no pill, no activities, no expansion — until the stub flips to valid.
  5. Flipping the stub license from invalid to valid un-locks the island at the next natural UI transition, not as an abrupt mid-interaction yank.

**Plans:** 4/4 plans executed — Phase complete 2026-07-05
Plans:
**Wave 1**

- [x] 10-01-PLAN.md — Keychain-backed trial persistence + LicenseState stub (TrialLogic, TrialManager, LicenseState)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 10-02-PLAN.md — isLicensed AND-term wired into the single visibility arbiter + one-shot expiry timer
- [x] 10-03-PLAN.md — First-launch Settings notice, D-05 locked-click routing, DEBUG stub menu

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 10-04-PLAN.md — On-device manual verification (Keychain survival, DEBUG-inertness, non-abrupt lockout)

### Phase 11: License Settings UI (Stubbed License Service)

**Goal**: Users can see their trial/license status and initiate purchase or key entry entirely from Settings, exercising the full UI state machine against a fake in-memory service before any live network call exists.
**Depends on**: Phase 10 (Settings displays the trial/lockout state Phase 10 computes)
**Requirements**: TRIAL-03
**Success Criteria** (what must be TRUE):

  1. User can open Settings and see the number of trial days remaining at any time.
  2. User can click a "Buy Now" button in Settings (opens a placeholder URL for now — the real Polar.sh link lands in Phase 12).
  3. User can paste a key into a license field and click Activate, observing idle → validating → success/failure state transitions driven by a fake stub `LicenseService`.
  4. The Settings window (and its License section) stays one click away from the menu-bar icon at all times, even though Islet has no Dock icon or main window.

**Plans:** 2/2 plans complete
Plans:

**Wave 1**

- [x] 11-01-PLAN.md — LicenseService stub seam + in-memory session entitlement + Wave 0 async tests (LicenseService, LicenseState.sessionActivated, LicenseServiceTests)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 11-02-PLAN.md — Adaptive License section in Settings (days-remaining, Buy Now, activation state machine, live-unlock wiring)

**UI hint**: yes

### Phase 12: Real Polar.sh License Integration

**Goal**: License purchase and validation work for real against Polar.sh, and stay fully functional offline after the first successful validation.
**Depends on**: Phase 11 (swaps the stub `LicenseService` for `PolarLicenseService` behind the same protocol — no UI or `TrialManager` changes)
**Requirements**: LIC-01, LIC-02
**Success Criteria** (what must be TRUE):

  1. User can click "Buy Now" in Settings and land on the real Polar.sh checkout page in their default browser, able to complete a live €7.99 one-time purchase.
  2. User can paste the license key they received by email into Settings; the app validates it online against Polar.sh and shows success or a specific failure reason.
  3. After one successful validation, the app keeps working fully offline (e.g., in airplane mode) without re-prompting for the key.
  4. A transient network error during validation (no internet, server hiccup) is distinguishable from an actually-invalid key — it does not lock out a key the user just paid for, and can be retried.

**Plans:** 4/4 plans executed — Phase complete 2026-07-07

Plans:

**Wave 1**

- [x] 12-01-PLAN.md — Keychain license persistence: LicenseStore seam + LicenseRecord + KeychainLicenseStore + read-once-cached LicenseManager
- [x] 12-02-PLAN.md — PolarLicenseService: URLSession customer-portal validate + strict HTTP→verdict mapping + HTTPSession seam

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 12-03-PLAN.md — Integration: LicenseState persisted branch + SettingsView PolarLicenseService swap, record persistence, D-04 unreachable/invalid split + Retry

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 12-04-PLAN.md — On-device verification (Buy Now, real-key validate, offline relaunch, error states) + Debug/Release build gate

### Phase 13: Real Notarization & Release

**Goal**: The distributed `.dmg` is genuinely Developer-ID signed, notarized, and stapled — purchasers see no Gatekeeper warning on first launch.
**Depends on**: Nothing new — functionally independent of Phases 10-12, sequenced last for release-readiness ordering only
**Requirements**: DIST-01
**Success Criteria** (what must be TRUE):

  1. Running `scripts/release.sh` produces a `.dmg` signed with the real Developer ID Application certificate — no ad-hoc/placeholder signing remains.
  2. The `.dmg` is successfully notarized via `xcrun notarytool submit --wait` and stapled via `stapler staple`, with no errors.
  3. `spctl --assess` on the stapled app reports "accepted" — opening it on a clean Mac shows no "unidentified developer" Gatekeeper warning.

**Plans:** 1/1 plans executed — Phase complete 2026-07-08

Plans:

**Wave 1**

- [x] 13-01-PLAN.md — Fill real DEVELOPER_ID/NOTARY_PROFILE credentials, run release.sh, verify signing/notarization + Gatekeeper (D-01 same-Mac simulation)

## Progress

**v1.0:** 7/7 phases complete (100%) — see `.planning/milestones/v1.0-ROADMAP.md` for the full per-phase breakdown.

**v1.0.1:** 3/3 phases complete (100%) — see `.planning/milestones/v1.0.1-ROADMAP.md` for the full per-phase breakdown.

**v1.1:**

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 10. Trial & Lockout Gate | 4/4 | Complete | 2026-07-05 |
| 11. License Settings UI (Stubbed) | 2/2 | Complete    | 2026-07-05 |
| 12. Real Polar.sh License Integration | 4/4 | Complete | 2026-07-07 |
| 13. Real Notarization & Release | 1/1 | Complete | 2026-07-08 |

### Phase 14: Basic outfit: weather + calendar + date display with weather-driven animated background

**Goal:** The `expandedIdle` glance shows live weather (icon + temperature), date, and the next
relevant calendar event alongside the existing time readout, in a 3-column layout — with only
the weather icon animating per condition category, degrading silently to an absent column on
permission denial.
**Requirements**: WEATHER-01, CAL-01, OUTFIT-01 (new — not yet in REQUIREMENTS.md; add these 3
IDs to REQUIREMENTS.md's Requirements section and Traceability table)
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
