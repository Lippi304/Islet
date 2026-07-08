---
phase: 14-basic-outfit-weather-calendar-date-display-with-weather-driv
plan: 05
subsystem: verification
tags: [weatherkit, eventkit, corelocation, entitlements, hardened-runtime, on-device-uat]

# Dependency graph
requires:
  - phase: 14-01..14-04
    provides: WeatherCategory/nextRelevantEvent pure seams, WeatherKit signing/entitlement setup, WeatherKitService/EventKitService, NotchWindowController wiring + 3-column expandedIsland layout
provides:
  - On-device proof that the real WeatherKit fetch succeeds end-to-end (signing + App ID capability + entitlements all correct together)
  - On-device proof of D-01/D-03 silent permission-denial degradation (no error UI, no retry nagging)
  - On-device proof of D-04 live next-event advancement (in-progress -> next-today -> tomorrow's-first -> nothing)
  - On-device proof of idle-CPU/energy discipline (weather icon animation stops costing CPU/energy after island collapse)
affects: [phase-14-completion, verify-work-14, future-weatherkit-or-eventkit-changes]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - Islet/Islet.entitlements

key-decisions:
  - "Task 1 checkpoint approved on-device after two real bugs found via separate debug sessions (not part of this plan's own tasks, but blocking its verification): missing Calendar entitlement (f822d1b) and missing Location entitlement + un-checked WeatherKit App Services Portal capability (3ae2c53)"
  - "Task 2 idle-CPU check performed via Activity Monitor's Energy tab (View > All Processes) instead of the sample CLI, because /opt/homebrew/bin/sample was shadowed by an unrelated Homebrew Python package on the user's machine — Energy tab gave an equally valid on-device measurement (baseline ~3, ~9 while animating, back to ~3 after collapse)"

patterns-established: []

requirements-completed: [WEATHER-01, CAL-01, OUTFIT-01]

# Metrics
duration: —
completed: 2026-07-08
---

# Phase 14 Plan 05: On-Device Verification Summary

**Real WeatherKit fetch, D-01/D-03 silent permission-denial degradation, D-04 live next-event advancement, and idle-CPU discipline all confirmed working on-device after fixing two Hardened-Runtime entitlement gaps found during verification.**

## Performance

- **Tasks:** 2/2 checkpoint tasks approved
- **Files modified:** 1 (`Islet/Islet.entitlements`, via the two linked debug sessions, not this plan directly)

## Accomplishments
- Confirmed a real, entitled WeatherKit fetch renders (icon + temperature) on-device — the full chain (project.yml Developer Team signing, WeatherKit App ID capability + App Services checkbox, entitlements, Info.plist usage-description keys) works end-to-end.
- Confirmed D-01 (Location denial silently omits the weather column) and D-03 (Calendar denial silently omits the calendar column) — no error text, no retry UI, no crash — and that re-granting both permissions restores both columns.
- Confirmed D-04's live next-event selection: in-progress/next-today event shown and labeled "Today", falls to tomorrow's first event labeled "Tomorrow" once today's are exhausted, and goes fully absent once no events remain in either window.
- Confirmed no animation-driven CPU/energy cost survives island collapse — Activity Monitor Energy Impact returns from ~9 (expanded, weather icon animating) back to baseline ~3 after collapsing to the idle pill, matching the `EqualizerBars`/`ProgressBar` idle-CPU-gating precedent (D-04/Pitfall 5).

## Task Commits

This plan makes no code changes of its own (`files_modified: []` in frontmatter) — it is a pure on-device verification gate. Verification depended on two bugs found and fixed via separate linked debug sessions during the checkpoint process:

1. **Task 1 blocker fix** — `fix(calendar-perm-no-dialog): declare Calendar entitlement for Hardened Runtime TCC prompt` - `f822d1b`
2. **Task 1 blocker fix** — `fix(weatherkit-column-empty): declare Location entitlement for Hardened Runtime TCC prompt` - `3ae2c53`

Both are documented in full in `.planning/debug/resolved/calendar-perm-no-dialog.md` and `.planning/debug/resolved/weatherkit-column-empty.md`.

**Plan metadata:** (this commit) — `docs(14-05): complete on-device verification plan`

## Files Created/Modified
- `Islet/Islet.entitlements` - Added `com.apple.security.personal-information.calendars` and `com.apple.security.personal-information.location`, required under Hardened Runtime for tccd to process Calendar/Location TCC prompts at all (fixed via the two linked debug sessions, not a task in this plan).

## Decisions Made
- Both entitlement gaps were genuine root-cause blockers discovered only by attempting real on-device verification — exactly the scenario this plan's threat register (T-14-11) anticipated: a broken entitlement and a correctly-denied permission produce the identical "column absent" UI, so only a human watching the real permission dialogs could tell the WeatherKit/Calendar pipeline was silently failing to even prompt, versus intentionally omitting the column.
- The WeatherKit App ID "App Services" capability checkbox (separate from "Capabilities" in the Apple Developer Portal) was the second gap — an external Portal configuration step, no code change, but caused a hard 401 on the JWT token handshake until checked.

## Deviations from Plan

None — plan executed exactly as written. The two entitlement bugs surfaced during this plan's own verification process were resolved via separate `/gsd-debug` sessions (not deviation-rule auto-fixes within this plan's task list, since this plan has zero code tasks), and are fully documented in their own resolved debug files.

## Issues Encountered
- Task 1 checkpoint initially blocked twice by Hardened Runtime silently refusing to process Calendar and then Location TCC requests without their respective entitlements declared — both root-caused and fixed via linked debug sessions (`f822d1b`, `3ae2c53`) before Task 1 could be re-verified and approved.
- Task 2's idle-CPU check couldn't use the `sample` CLI as originally instructed because `/opt/homebrew/bin/sample` was shadowed by an unrelated Homebrew Python package on the user's machine (a PATH collision, not an app bug) — Activity Monitor's Energy tab was used instead and gave an equally conclusive result.

## User Setup Required

None - no external service configuration required beyond the WeatherKit App Services Portal checkbox already completed during this plan's Task 1 verification (documented in `weatherkit-column-empty.md`).

## Next Phase Readiness
- Phase 14 (Basic Outfit: weather + calendar + date display) is now fully on-device verified — all 5 plans complete, all `must_haves.truths` from this plan's frontmatter confirmed working.
- Ready for `/gsd:verify-work 14` and/or phase completion/transition.

## Self-Check: PASSED

- FOUND: Islet/Islet.entitlements
- FOUND: f822d1b (git log)
- FOUND: 3ae2c53 (git log)
- FOUND: .planning/debug/resolved/calendar-perm-no-dialog.md
- FOUND: .planning/debug/resolved/weatherkit-column-empty.md

---
*Phase: 14-basic-outfit-weather-calendar-date-display-with-weather-driv*
*Completed: 2026-07-08*
