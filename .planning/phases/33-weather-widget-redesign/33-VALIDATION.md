---
phase: 33
slug: weather-widget-redesign
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-15
---

# Phase 33 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing `IsletTests` target) |
| **Config file** | `project.yml` (XcodeGen) — `IsletTests` target, shared `Islet` scheme |
| **Quick run command** | `xcodebuild build -scheme Islet -destination 'platform=macOS'` (build-only gate — `xcodebuild test` hangs headless, see project memory `xcodebuild-test-headless-hang`) |
| **Full suite command** | Manual Cmd-U in Xcode |
| **Estimated runtime** | ~30s build / manual for full suite |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme Islet -destination 'platform=macOS'`
- **After every plan wave:** Manual Cmd-U full `IsletTests` run, PLUS on-device Settings-toggle live-update trace (WEATHER-02) — cannot be automated
- **Before `/gsd:verify-work`:** Full suite green (Cmd-U) + on-device UAT checkpoints passed
- **Max feedback latency:** ~30 seconds (build gate); manual full-suite/on-device checks gate the wave/phase boundary, not each task

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 33-0x-xx | TBD | 0 | WEATHER-01 (compact card data mapping / "Local" fallback) | — | N/A | unit | `xcodebuild build -scheme Islet -destination 'platform=macOS'` | ❌ W0 — new `DailyForecastTests.swift` or extend `WeatherCategoryTests.swift` | ⬜ pending |
| 33-0x-xx | TBD | 0 | WEATHER-02 (single combined WeatherKit call, not two) | — | N/A | unit (mock `WeatherService` conformer, assert call count) | `xcodebuild build -scheme Islet -destination 'platform=macOS'` | ❌ W0 — new test double, following `LocationServiceTests.swift` protocol-mock pattern | ⬜ pending |
| 33-0x-xx | TBD | 1 | WEATHER-01 (compact card renders location/icon/temp/H-L) | — | N/A | manual-only (SwiftUI view internals not assertable without ViewInspector) | manual | n/a | ⬜ pending |
| 33-0x-xx | TBD | 1 | WEATHER-02 (Settings toggle switches compact ↔ extended, live, no relaunch) | — | N/A | manual-only (no precedent for unit-testing live-render toggle behavior in this codebase) | manual | n/a | ⬜ pending |
| 33-0x-xx | TBD | 1 | WEATHER-01/02 (silent degradation on permission denial) | — | N/A | manual-only (requires revoking location permission on-device) | manual | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/DailyForecastTests.swift` (or equivalent) — pure mapping/fallback logic for the forecast row and "Local" geocode fallback (D-02)
- [ ] Mock `WeatherService` conformer that records call count — asserts the combined-call-not-two-calls contract (Pitfall 1), following `LocationServiceTests.swift`'s existing protocol-mock pattern

*No new test framework/config needed — `IsletTests` target and shared scheme already fully wired.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Compact widget card shows location, condition icon, current temp, and high/low | WEATHER-01 | SwiftUI view internals not directly assertable without ViewInspector (not a project dependency) | Open Weather tab on-device, confirm all four data points render correctly for the current location |
| Settings toggle switches compact ↔ extended live, no relaunch required | WEATHER-02 | `@AppStorage`-driven SwiftUI render branch + AppKit panel-frame change — no existing precedent for unit-testing this class of behavior in this codebase | Flip the Weather extended-widget setting on-device while the Weather tab is visible; confirm the forecast row appears/disappears immediately without app restart |
| Extended card's forecast row fits the panel width without scrolling | WEATHER-02 | Visual layout confirmation, dependent on real rendered chip size (Open Question 1 in RESEARCH.md) | Open extended Weather view on-device, confirm all forecast days are visible and legible without overflow or clipping |
| Weather height-override geometry (D-03) doesn't break click-through hit-testing | WEATHER-01/02 | `visibleContentZone()`'s consumer is a live global mouse-event monitor — CR-01/CR-02 regression class empirically not caught by unit tests alone in this codebase's history | Full on-device hover→expand→move-down trace per CR-01 precedent (project memory `cr01-clickthrough-or-defeat-gotcha`) — confirm expanded branch stays pure `visibleContentZone()` after the Weather height override lands |
| Weather degrades silently on permission denial (no crash, sensible fallback) | WEATHER-01/02 | Requires revoking location permission on-device, matching existing pattern | Deny location permission in System Settings, relaunch app, confirm Weather view shows a sensible fallback state with no crash |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (build gate)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
