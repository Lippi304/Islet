---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: Trial & Paid Release
status: executing
stopped_at: Phase 14 UI-SPEC approved
last_updated: "2026-07-08T12:21:05.360Z"
last_activity: 2026-07-08 -- Phase 14 execution started
progress:
  total_phases: 5
  completed_phases: 4
  total_plans: 16
  completed_plans: 11
  percent: 69
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-05)

**Core value:** The notch becomes a beautiful, reliable island that shows now-playing media and reacts when you plug in the charger or connect a device — native, smooth, and as polished as the iPhone Dynamic Island.
**Current focus:** Phase 14 — basic-outfit-weather-calendar-date-display-with-weather-driv

## Current Position

Phase: 14 (basic-outfit-weather-calendar-date-display-with-weather-driv) — EXECUTING
Plan: 1 of 5
Next: `/gsd-plan-phase 14` (Basic Outfit) to plan the new post-v1.1 feature, or `/gsd-complete-milestone` to close out v1.1 (all 4 phases — 10, 11, 12, 13 — complete)
Last activity: 2026-07-08 -- Phase 14 execution started

### Phase 5 status note (resolved at v1.0 milestone close)

Phase 5 (device-connected-activity) was formally marked **superseded by Phase 6** in
ROADMAP.md at v1.0 milestone close (2026-07-02, user decision). Its scope — device
connect/disconnect activity, `DeviceActivityState`, `BluetoothMonitor`, device wings —
shipped inside Phase 6 (06-02/06-04); DEV-01/DEV-02 are code-complete and verified (see
`06-VERIFICATION.md`, `REQUIREMENTS.md`). Phase 5's own 3 plans were never executed. The
on-device Bluetooth permission spike from 05-01 Task 3 was superseded by the actual A1
finding in 06-04 (NSBluetoothAlwaysUsageDescription IS required on macOS 26 — see project
memory `a1-bluetooth-usage-key-required`), so no further action is needed there either.

Progress (v1.1): [██████████] 100% (Phases 10-13 all complete; Phase 14 is new scope added after this milestone's original 4 phases)

## Performance Metrics

**Velocity:**

- Total plans completed: 41
- Average duration: — min
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 00 | 4 | - | - |
| 01 | 3 | - | - |
| 02 | 4 | - | - |
| 03 | 3 | - | - |
| 04 | 4 | - | - |
| 06 | 13 | - | - |
| 07 | 1 | - | - |
| 08 | 2 | - | - |
| 09 | 5 | - | - |
| 11 | 2 | - | - |
| 12 | 4 | - | - |
| 13 | 1 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap v1.1] Phase order follows research SUMMARY.md verbatim: Phase 10 (Trial + Lockout Gate on a stubbed license state) before Phase 11 (Settings UI against a stubbed LicenseService) before Phase 12 (real Polar.sh integration) — de-risks the most sensitive existing file (`NotchWindowController`'s single-arbiter `shouldShow(...)`) and the UI state machine before live network flakiness is introduced. Phase 13 (real notarization) is functionally independent and sequenced last for release-readiness ordering only.
- [Roadmap v1.1] LIC-01/LIC-02 mapped to Phase 12, not Phase 11, even though Phase 11 builds their UI shell — the requirements' actual observable behavior (real Polar.sh checkout page, real online validation) isn't true until the real `PolarLicenseService` swap; Phase 11's stub only proves the state machine.
- [Roadmap v1.1] LIC-03 (hard lockout) mapped to Phase 10, not Phase 12 — the lockout mechanism itself (the `isLicensed` AND-term in `shouldShow(...)`) is fully built and testable against a manually-settable stub license state in Phase 10, per research: the gate must exist and be proven before real license validation touches it.
- [Roadmap] Charging (Phase 3) is built before Now Playing (Phase 4): proves the activity→island loop on the safest public API (IOKit) before the fragile MediaRemote landmine. (Diverges from research SUMMARY's "Now Playing first"; activity-arbitration nuance deferred to Phase 6 resolver.)
- [Roadmap] Notarization toolchain proven in Phase 0 on a hello-world build, not deferred to release — the single biggest first-timer footgun.
- [Roadmap] All MediaRemote access isolated behind one NowPlayingService with a launch-time health check (Phase 4); a future Apple change is a one-file fix.
- [Roadmap v1.0.1] Two requirements (PBAR-01, FS-01) split into two phases (7, 8) rather than combined into one — different risk profiles.

### Roadmap Evolution

- Phase 14 added: Basic outfit: weather + calendar + date display with weather-driven animated background

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

None yet.

### Blockers/Concerns

[Issues that affect future work]

- [Phase 10] Trial-start and license-key/activation state must live in the Keychain (not UserDefaults/plist) per research PITFALLS.md — UserDefaults-only trial storage is trivially reset via `defaults delete`.
- [Phase 10] Lockout enforcement must defer to the next natural UI transition point, not an instant synchronous yank, per research pitfall on mid-session abrupt lockout.
- [Phase 12] License validation must distinguish "invalid key" (4xx) from "couldn't reach the server" (network/5xx) and never hard-lock a key the user just paid for — highest-consequence pitfall per research (hits paying customers at peak purchase-regret risk).
- [Phase 12] Polar API error taxonomy beyond `granted/revoked/disabled` is thin in official docs (research flag) — verify actual error shapes against the real (production) API during Phase 12 planning/implementation.
- **[RESOLVED 2026-07-08] [Phase 13] Individual-vs-Team notarytool API key `--issuer` flag behavior** — moot: app-specific-password auth (D-03) was used, not an API key, so this path was never hit.
- **[RESOLVED 2026-07-08] [Phase 13] Nested `MediaRemoteAdapter.framework` signing/entitlement mismatch** — hit exactly as predicted (2 pipeline iterations). Fixed in `scripts/release.sh`: embedded frameworks are now explicitly re-signed with the real Developer ID before the outer `.app` (codesign does not recurse; `--deep` is deprecated). Also fixed a related real bug: `notarytool submit` requires a `.zip`/`.pkg`/`.dmg`, not a raw `.app` — the script now zips via `ditto -c -k --keepParent` before submission. Verified end-to-end: notarized + stapled, `spctl --assess` accepted, manual double-click open confirmed no Gatekeeper warning.
- [Carried, pre-existing] Phase 2's 8 on-device UAT scenarios (`02-HUMAN-UAT.md`) remain unexercised since v1.0 close — unrelated to v1.1 scope, still open. Revisit via `/gsd:verify-work 2` if desired.
- [Carried, pre-existing] CR-01 (Phase 9): the dedicated CGS Space leaks in WindowServer on normal app quit (`AppDelegate.quit()` doesn't tear down `NotchWindowController`). Non-blocking, recommended fix via `/gsd-quick` before shipping v1.1.
- **[RESOLVED 2026-07-05 — quick 260705-mzj] Release build crashed at launch.** First-ever Release build failed in `dyld`: embedded `MediaRemoteAdapter.framework` failed Library Validation under Hardened Runtime on macOS 26/27 (`different Team IDs`; app + framework both ad-hoc signed, no entitlements file). **Fixed** by adding `Islet/Islet.entitlements` with `com.apple.security.cs.disable-library-validation`, wired into the Islet target via `CODE_SIGN_ENTITLEMENTS` in `project.yml` (commit `8e06a1b`). Release build now BUILD SUCCEEDED and the app launches without the dyld crash (objectively verified via standalone launch). This also pre-clears the Phase-13 blocker below (`MediaRemoteAdapter.framework` signing/entitlement mismatch) — the entitlement is notarization-compatible.

### Quick Tasks Completed

| # | Description | Date | Commit | Status | Directory |
|---|-------------|------|--------|--------|-----------|
| 260705-l4i | Idle-notch merge: data-drive collapsed pill size from measured notch (D-01) | 2026-07-05 | 52ee074 | Complete ✓ (on-device verified in Release) | [260705-l4i-idle-notch-soll-unsichtbar-mit-der-hardw](./quick/260705-l4i-idle-notch-soll-unsichtbar-mit-der-hardw/) |
| 260705-mzj | Release-build launch crash fix: disable-library-validation entitlement for embedded MediaRemoteAdapter framework | 2026-07-05 | 8e06a1b | Complete ✓ (Release launches, on-device verified) | [260705-mzj-release-build-crash-fix-disable-library-](./quick/260705-mzj-release-build-crash-fix-disable-library-/) |
| 260706-app-icon | App-Icon aus `brand/islet/` in den Xcode Asset-Catalog eingebaut (10 PNGs + Contents.json); Debug-Build packt AppIcon (Assets.car + AppIcon.icns, CFBundleIconName=AppIcon) | 2026-07-06 | d556f11 | Complete ✓ (Debug build verified icon embedded) | [260706-app-icon](./quick/260706-app-icon/) |

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| uat_gaps | Phase 02: 02-HUMAN-UAT.md | partial (8 pending on-device scenarios) | v1.0 close |
| verification_gaps | Phase 02: 02-VERIFICATION.md | human_needed | v1.0 close |
| code_review | CR-01: CGS Space leak on app quit (Phase 9) | non-blocking, recommended fix via `/gsd-quick` | v1.0.1 close |
| code_review | WR-01..04: wing accent-tint, view rehost, animation wrapper, BluetoothMonitor race (Phase 6) | non-blocking | v1.0 close |

Pre-existing debt from Phase 2 (Hover, Expand & Fullscreen Hardening) and Phase 6/9 code review, unrelated to v1.1 scope. Not blocking v1.1 roadmap creation per user decision — revisit via `/gsd-quick` or `/gsd:verify-work` as desired.

## Session Continuity

Last session: 2026-07-08T01:02:10.331Z
Stopped at: Phase 14 UI-SPEC approved
Resume file: .planning/phases/14-basic-outfit-weather-calendar-date-display-with-weather-driv/14-UI-SPEC.md

## Operator Next Steps

- v1.1 (Trial & Paid Release) is functionally complete — all 4 phases (10, 11, 12, 13) done, all v1.1 requirements (TRIAL-01/02/03, LIC-01/02/03, DIST-01) satisfied. Consider `/gsd-complete-milestone` to formally close it out.
- Phase 14 (Basic Outfit: weather + calendar + date display) is new post-milestone scope, discussed but not yet planned — run `/gsd-plan-phase 14` when ready to continue.
