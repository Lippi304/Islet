---
phase: 42
slug: dual-activity-display
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-18
---

# Phase 42 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest, `IsletTests` target (defined in `project.yml`) |
| **Config file** | `project.yml` (XcodeGen), `IsletTests` scheme |
| **Quick run command** | `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` — **use `build`, NOT `test`** (project memory: `xcodebuild test` hangs headless because `IsletTests` is hosted inside the full `Islet.app`, which boots the `NSPanel`/`MediaRemote`/`IOBluetooth` stack) |
| **Full suite command** | Manual `Cmd-U` in Xcode (routes around the headless-hang gap above) |
| **Estimated runtime** | ~30-60s build |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build`
- **After every plan wave:** Manual `Cmd-U` full suite in Xcode
- **Before `/gsd:verify-work`:** Full manual `Cmd-U` pass + all on-device checkpoints below must be green
- **Max feedback latency:** ~60 seconds (build-only gate)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 42-01-xx | TBD | TBD | DUAL-01 | — | Both Countdown + NowPlaying live → `resolve(...)` returns primary=`.calendarCountdown`, secondary=`.nowPlaying` (ranking table) | unit | new test method in `IsletTests/IslandResolverTests.swift`, run via Cmd-U | ✅ file exists, add test method | ⬜ pending |
| 42-01-xx | TBD | TBD | DUAL-01 | — | Only one activity live → `secondary` is nil, byte-identical to today's single-winner output (regression) | unit | extend existing `IslandResolverTests.swift` style tests | ✅ | ⬜ pending |
| 42-01-xx | TBD | TBD | DUAL-01 (D-10) | — | Any transient (Charging/Device/Focus/OSD) active → both `presentation` AND `secondary` suppressed together | unit | new test mirroring `testChargingOutranksDeviceAndMedia`, asserting `secondary == nil` | ✅ | ⬜ pending |
| 42-0x-xx | TBD | TBD | DUAL-01 (D-12) | — | Tap on secondary bubble expands to that activity — independent tap target, not swallowed by the primary pill's hot zone | manual-only | on-device tap test — AppKit click-through geometry (hotZone/handlePointer) is not unit-testable | N/A — human-verify checkpoint required |
| 42-0x-xx | TBD | TBD | DUAL-01 (criterion 3) | — | No visual glitches, geometry collisions, or dropped frames when either slot's content changes (distinct `matchedGeometryEffect` ids under the shared namespace) | manual-only | on-device visual UAT | N/A — human-verify checkpoint required |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `IsletTests/IslandResolverTests.swift` already exists with the exact pattern this phase's new tests extend (hand-built `CalendarCountdownActivity`/`NowPlayingPresentation` values, assert `resolve(...)` output) — no new test infrastructure needed.

*No framework install needed — `IsletTests` target and XCTest are already fully configured.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| Tap on secondary bubble expands to that activity | DUAL-01 (D-12) | AppKit click-through/hot-zone geometry (`NotchWindowController.hotZone`/`handlePointer(at:)`) is not unit-testable, and Phase 40-03 already found this exact mechanism caused a real click-swallowing bug | With Countdown + NowPlaying both live, click directly on the secondary bubble; confirm it expands to that activity's view, not the primary's |
| No visual glitches / geometry collisions / dropped frames between primary and secondary slots | DUAL-01 (criterion 3) | Frame-drop and geometry-collision behavior of `matchedGeometryEffect` can only be observed by eye on real hardware | With both activities live, trigger content changes in each slot (e.g. track change, countdown tick) and watch for jank, snapping, or shape collisions between the pill and bubble |
| Additive-only change — no regression to existing single-winner behavior or presentation switch sites | DUAL-01 (criterion 4) | Confirmed via diff review, not a runtime test | Diff `IslandResolver.swift` and every `IslandPresentation` switch site against pre-Phase-42 state; confirm only additive changes (new `secondary` field/branches), no existing case bodies altered |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references — `IslandResolverTests.swift` already exists, no scaffold gap
- [x] No watch-mode flags
- [x] Feedback latency < 60s per task (build-only gate; project-wide `xcodebuild build` latency of ~30-60s is an accepted inherent constraint, not a plan defect)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
