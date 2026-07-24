---
phase: 63
slug: meeting-hud
status: final
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-24
---

# Phase 63 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (`IsletTests` target) |
| **Config file** | Standard Xcode test target, no separate config file |
| **Quick run command** | `xcodebuild test -scheme Islet -only-testing:IsletTests/IslandResolverTests` |
| **Full suite command** | `xcodebuild test -scheme Islet` |
| **Estimated runtime** | ~30 seconds (quick) / ~2-3 minutes (full) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Islet -only-testing:IsletTests/IslandResolverTests`
- **After every plan wave:** Run `xcodebuild test -scheme Islet`
- **Before `/gsd:verify-work`:** Full suite green + on-device D-03 spike go/no-go documented + on-device UAT (MEET-01/02/03 checklist)
- **Max feedback latency:** 180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 63-03 T1 | 63-03 | 3 | MEET-01 | — | `.meeting` case resolves at correct rank (D-05), preempts Focus/OSD/Download/CapsLock/Update/Timer, preempted only by Charging/Device | unit | `xcodebuild test -only-testing:IsletTests/IslandResolverTests` | ❌ W0 | ⬜ pending |
| 63-03 T1 | 63-03 | 3 | MEET-01 | — | `ActiveTransient.meeting(...).isPersistent == true` while active | unit | `xcodebuild test -only-testing:IsletTests/IslandResolverTests` | ❌ W0 | ⬜ pending |
| 63-02 T2 | 63-02 | 2 | MEET-01 | — | Real Zoom/Teams call + mic on shows the HUD; app-open-only does not | manual-only | On-device spike checklist (D-03), checkpoint:human-verify | N/A | ⬜ pending |
| 63-01 T2 | 63-01 | 1 | MEET-02 | T-63-DoS | `MicMuteController` guarded Get/Set never crashes on unsupported device | unit | New `MicMuteControllerTests.swift` | ❌ W0 | ⬜ pending |
| 63-04 T3 | 63-04 | 4 | MEET-02 | T-63-11 | Tapping the mute icon toggles system input mute and icon reflects new state; widened hot-zone doesn't swallow clicks past the icon's edge | manual-only | On-device UAT checklist, checkpoint:human-verify | N/A | ⬜ pending |
| 63-02 T2 | 63-02 | 2 | MEET-03 | — | Google Meet in a browser never triggers the HUD | manual-only | On-device spike checklist (negative case) | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IslandResolverTests.swift` — add `.meeting` rank/preemption/isPersistent test cases (file exists, needs new cases)
- [ ] New `MicMuteControllerTests.swift` — guarded-call safety tests (never crash on missing property); verify whether an existing `VolumeReaderTests.swift`-equivalent exists to mirror first
- [ ] No new framework install needed — XCTest already wired

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| Real Zoom/Teams call + active mic shows call-timer HUD | MEET-01 | No way to simulate a real call/mic state in CI | Join a real Zoom or Teams call with mic on; confirm HUD appears with elapsed mm:ss |
| Tapping mute icon toggles system input mute | MEET-02 | CoreAudio HAL writes affect the real machine's audio state, not safely automatable in CI | Tap the Meeting-HUD mute icon during a call; confirm system mic mutes/unmutes and icon reflects state |
| Google Meet (browser) never triggers the HUD | MEET-03 | No process/filesystem signal identifies a browser tab | Join a Google Meet call in a browser with mic on; confirm no HUD appears |
| On-device detection-heuristic spike (D-03) go/no-go | MEET-01 | Detection reliability (Zoom/Teams process-running + mic-active) can only be validated against real hardware and real app behavior | Run the spike checklist against real Zoom/Teams sessions; document go/no-go before full HUD build |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 180s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** confirmed by gsd-plan-checker (iteration 2/3), 2026-07-24
