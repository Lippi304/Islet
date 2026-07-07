---
phase: 14
slug: basic-outfit-weather-calendar-date-display-with-weather-driv
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-08
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest, hosted inside the `Islet.app` target (`IsletTests` in `project.yml`) |
| **Config file** | `project.yml` (XcodeGen-generated `.xcodeproj`) |
| **Quick run command** | `xcodebuild build -scheme Islet` (build-only gate) |
| **Full suite command** | Manual `Cmd-U` in Xcode — `xcodebuild test` hangs headlessly (tests host inside the full app, which boots NSPanel/MediaRemote/IOBluetooth, and this phase adds WeatherKit/EventKit/CoreLocation permission prompts that block headlessly) |
| **Estimated runtime** | Build: ~30-60s. Manual Cmd-U: a few minutes including on-device permission dialogs |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme Islet`
- **After every plan wave:** Manual `Cmd-U` in Xcode for the pure-seam unit tests
- **Before `/gsd:verify-work`:** Full suite must be green + on-device UAT for permission-denial silent-omission and idle-CPU checks
- **Max feedback latency:** ~60 seconds (build gate)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 0 | TBD (planner-assigned) | — | `WeatherCategory.from(_:)` maps every condition exhaustively, default → `.cloudy` | unit | `xcodebuild build -scheme Islet` (build gate) + manual Cmd-U for assertions | ❌ Wave 0 | ⬜ pending |
| 14-01-02 | 01 | 0 | TBD | — | `nextRelevantEvent(events:now:)` picks today's next/in-progress, falls to tomorrow's first, else nil (D-04) | unit | same as above | ❌ Wave 0 | ⬜ pending |
| 14-0X-XX | TBD | TBD | TBD | T-14-01 | Calendar event title bounded via `.lineLimit(1)`/`.truncationMode(.tail)` (untrusted external input, V5) | manual on-device | manual Cmd-U + visual check | N/A | ⬜ pending |
| 14-0X-XX | TBD | TBD | TBD | — | Weather/calendar column hidden (not error-shown) on permission denial (D-01/D-03) | manual on-device | manual Cmd-U + System Settings permission toggle | N/A | ⬜ pending |
| 14-0X-XX | TBD | TBD | TBD | — | No animation clock survives island collapse (D-04/Pitfall 5 precedent) | manual on-device | manual `sample`/Energy check | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Exact Task IDs/Requirement IDs to be filled by the planner once PLAN.md files are generated — this phase has no REQUIREMENTS.md entries yet (phase_req_ids: TBD).*

---

## Wave 0 Requirements

- [ ] `IsletTests/WeatherCategoryTests.swift` — stubs for the pure `WeatherCategory.from(_:)` mapping
- [ ] `IsletTests/CalendarGlanceTests.swift` — stubs for the pure `nextRelevantEvent(events:now:)` selection logic
- [ ] `project.yml` signing fix — Debug builds must sign with the real Developer Team (not ad-hoc `CODE_SIGN_IDENTITY: "-"`) or WeatherKit will fail silently on-device (Pitfall 1) — this is a setup prerequisite, not a test file, but blocks all weather testing until done

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| Weather column hidden on location-permission denial (D-01) | TBD | Permission prompts can't be automated headlessly; requires toggling System Settings | Deny Location permission for Islet in System Settings → Privacy & Security → Location Services; relaunch; confirm weather column is absent, no error/retry UI |
| Calendar column hidden on Calendar-permission denial (D-03) | TBD | Same — OS permission prompt | Deny Calendar access for Islet in System Settings → Privacy & Security → Calendars; relaunch; confirm calendar column is absent, no error/retry UI |
| Next-event live advancement through the day (D-04) | TBD | Requires real wall-clock time passing / manipulating test calendar events | Create test events spanning now; confirm the shown event advances as each passes, falls to tomorrow's first event when today's are exhausted |
| Idle-CPU: no lingering animation after collapse (D-04/Pitfall 5) | TBD | Requires on-device `sample`/Energy profiling, matches existing `EqualizerBars`/`ProgressBar` precedent | Expand island to show weather icon animating, collapse back to idle pill, run `sample Islet` or Energy in Activity Monitor, confirm no symbol-effect-driven CPU activity remains |
| WeatherKit entitlement/signing works end-to-end | TBD | Requires real Developer Team signing + Apple Developer portal capability, not verifiable by build alone | After enabling WeatherKit capability on App ID and updating `project.yml` signing, run on-device and confirm a real weather fetch succeeds (no silent entitlement failure) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
