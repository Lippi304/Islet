---
phase: 4
slug: now-playing
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-27
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `04-RESEARCH.md` § Validation Architecture. Mirrors the Phase-3 split:
> the pure classification seam is unit-tested in ms; system IPC + process lifecycle +
> render-loop behavior are on-device UAT.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode 26.6 / Swift 5 language mode) |
| **Config file** | none — `IsletTests` bundle wired in `project.yml` (host = Islet.app, `@testable import Islet`) |
| **Quick run command** | `xcodebuild test -scheme Islet -only-testing:IsletTests/NowPlayingPresentationTests -destination 'platform=macOS'` |
| **Full suite command** | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |
| **Estimated runtime** | ~5 s (pure-seam unit tests); full build+test longer |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Islet -only-testing:IsletTests/NowPlayingPresentationTests -destination 'platform=macOS'`
- **After every plan wave:** Run full `IsletTests` suite (existing PowerActivity/Geometry/etc. must stay green)
- **Before `/gsd-verify-work`:** Full suite green + on-device UAT of NOW-02 transport, NOW-03 graceful-unavailable, and D-04 idle-CPU
- **Max feedback latency:** ~5 s (unit seam)

---

## Per-Task Verification Map

> Task IDs are assigned by the planner. This map is requirement-level; the planner's
> per-task `<automated>`/`<manual>` verify fields must align with these rows.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | 0 | NOW-01 | — | Allowlist: only `com.spotify.client` / `com.apple.Music` map to a presentation; other bundle id → `.none` | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/NowPlayingPresentationTests/testAllowlistFiltersBundleID -destination 'platform=macOS'` | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | NOW-01 | — | Title/artist mapping; empty/nil title → `.none` | unit | `…/testNoTitleMapsToNone` | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | NOW-03 | — | `isPlaying` true→`.playing`, false/nil→`.paused` classification | unit | `…/testPlayingVsPausedClassification` | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | NOW-03 | — | snapshot nil (healthy API, no media) → `.none` (D-11, NOT D-12 unavailable) | unit | `…/testNilSnapshotMapsToNone` | ❌ W0 | ⬜ pending |
| TBD | TBD | — | NOW-02 | T-04-xx (process teardown) | Transport play/pause/next/prev reach the live Spotify + Apple Music session | manual | UAT: operate transport in both apps from expanded island | n/a (system IPC) | ⬜ pending |
| TBD | TBD | — | NOW-03 | T-04-xx (no leaked child / no crash on death) | Launch failure → "nicht verfügbar" (D-12); mid-drop → clear to idle, unavailable on next expand (D-13) | manual | UAT: launch with music, kill source/adapter, observe clear→idle then "nicht verfügbar" on next expand | n/a (process lifecycle) | ⬜ pending |
| TBD | TBD | — | NOW-01 (D-04) | — | Bars animate only while playing; removed (not just frozen) when paused/no-media → idle CPU ~0% | manual | UAT: pause, check `sample Islet` / Activity Monitor Energy = no active render loop | n/a (render-loop) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/NowPlayingPresentationTests.swift` — pure-seam fixtures for NOW-01 (allowlist, title/artist) + NOW-03 (playing/paused/none classification). No system calls; `TrackSnapshot` hand-constructed like `PowerReading`.

*No new shared fixtures/conftest needed. No framework install needed — the `IsletTests` XCTest bundle already exists from Phases 1–3.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Transport commands act on the live session | NOW-02 | Real MediaRemote IPC to Spotify/Apple Music — not reachable in a unit test | Play media in Spotify, then Apple Music; from the expanded island press play/pause, next, previous; confirm each affects the real player |
| Launch-time health check → "nicht verfügbar" | NOW-03 (D-12) | Depends on whether the OS blocks MediaRemote at launch — process/OS state, not pure logic | Force/observe a blocked-adapter launch; expand island; confirm "Now Playing nicht verfügbar" shows in place of controls |
| Mid-session adapter death → clear state | NOW-03 (D-13) | Child-process lifecycle — `onListenerTerminated` is real-process behavior | Launch with music showing, kill the source app / adapter child; confirm island clears to idle pill (no crash), and "nicht verfügbar" appears on the *next* expand |
| Survives app restart | NOW-03 | Requires real relaunch reading the live session | Play media, quit & relaunch Islet; confirm the glance repopulates from the current session |
| Equalizer idle CPU ~0% when paused/no-media | NOW-01 (D-04) | Render-loop / energy behavior — not observable in a unit test | Pause playback; with `sample Islet` or Activity Monitor Energy tab, confirm no continuous animation clock is running |
| Charging-vs-media precedence (D-14) | — | Two live system sources interacting (power + media) | While music plays, plug in charger; confirm ~3 s charging splash wins, then returns to now-playing wings (not empty) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies (manual-only rows justified above)
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (`NowPlayingPresentationTests.swift`)
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s (unit seam)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
