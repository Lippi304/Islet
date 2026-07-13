---
phase: 30
slug: home-music-only
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-14
---

# Phase 30 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing `IsletTests` target) |
| **Config file** | `project.yml` (XcodeGen) — `IsletTests` target, shared `Islet` scheme |
| **Quick run command** | `xcodebuild build -scheme Islet` (build-only gate — `xcodebuild test` hangs headless, see Pitfall/project memory) |
| **Full suite command** | Manual Cmd-U in Xcode |
| **Estimated runtime** | ~30s build / manual for full suite |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme Islet`
- **After every plan wave:** Manual Cmd-U full `IsletTests` run
- **Before `/gsd:verify-work`:** Full suite green (Cmd-U) + on-device UAT of all 3 Home states
- **Max feedback latency:** ~30 seconds (build gate); manual full-suite/on-device checks gate the wave/phase boundary, not each task

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 30-01-xx | 01 | 0 | HOME-02/HOME-03 | — | N/A | unit (resolver) | `xcodebuild build -scheme Islet` + manual Cmd-U | ❌ W0 | ⬜ pending |
| 30-0x-xx | TBD | 1 | HOME-01 | — | N/A | unit (resolver, existing coverage) | `xcodebuild build -scheme Islet` | ✅ `IsletTests/IslandResolverTests.swift` | ⬜ pending |
| 30-0x-xx | TBD | 1+ | HOME-02 (artwork stickiness) | — | N/A | manual on-device (NSImage/AppKit) | manual | n/a | ⬜ pending |
| 30-0x-xx | TBD | 1+ | D-05 (transport hover bg) | — | N/A | manual-only (visual polish) | manual | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/IslandResolverTests.swift` — split `testExpandedHealthyNoMediaIsExpandedIdle` and `testHomeSelectedNoMediaReturnsExpandedIdle` into `hasPlayedSinceLaunch`-parametrized pairs asserting the new last-played/empty-state resolver cases

*No new test framework/config needed — `IsletTests` target and shared scheme already fully wired.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Last-played cover art survives transition to `.none` | HOME-02 | Artwork is an `NSImage` from a real MediaRemote callback — not practically unit-testable | Play a track, pause/stop it in the source app, confirm cover art + title persist in Home with transport controls visible |
| Transport button hover rounded-rectangle background | D-05 | Visual-only polish, tuned on-device (matches project convention across Phases 7/18/20/21/23/25/26/28/29) | Hover each transport button in expanded Home view, confirm 8pt-corner-radius rounded-rect background appears |
| Empty state appearance (icon/heading/body, no idle glance) | HOME-03 | Requires fresh session with nothing played, visual confirmation no time/weather/calendar content leaks in | Launch app fresh (no playback this session), open Home, confirm empty state per 30-UI-SPEC.md and absence of any glance content |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (build gate)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
