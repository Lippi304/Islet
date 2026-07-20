---
phase: 49
slug: favorite-like-spike
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-20
---

# Phase 49 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (`IsletTests/` target, already present) |
| **Config file** | Existing `Islet.xcodeproj` scheme; no new config needed |
| **Quick run command** | `xcodebuild build -scheme Islet -configuration Debug` |
| **Full suite command** | `xcodebuild test -scheme Islet` |
| **Estimated runtime** | ~60s build / ~3min full suite |

This phase does not add automated tests. All four success criteria require real MediaRemote IPC, real AppleScript/TCC state, or a real network OAuth round-trip — none of which are unit-testable, mirroring this project's documented precedent for `NowPlayingMonitor` itself. The existing `IsletTests` suite is unaffected and should stay green (no production code changes expected beyond two entitlement/Info.plist additions).

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme Islet -configuration Debug` (confirms entitlement/Info.plist additions and any throwaway hook still compile)
- **After every plan wave:** N/A — single-wave spike phase
- **Before `/gsd:verify-work`:** All four success criteria have a recorded, honest verdict (PASS/FAIL/PARTIAL/NOT-REPRODUCED)
- **Max feedback latency:** ~60 seconds (build only; manual on-device verification has no fixed latency)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 49-01-* | 01 | 1 | Success Criterion #1 (likeTrack round-trip) | — | N/A | manual-only, on-device | `checkpoint:human-verify` | N/A | ⬜ pending |
| 49-01-* | 01 | 1 | Success Criterion #2 (loved/current track matrix) | — | N/A | manual-only, on-device (osascript acceptable) | `checkpoint:human-verify` per state | N/A | ⬜ pending |
| 49-01-* | 01 | 1 | Success Criterion #3 (Spotify PKCE + PUT save-track) | T-49-01 | S256 PKCE only, loopback redirect URI, no token persisted to disk | manual-only, on-device (shell script + real account) | `checkpoint:human-verify` | N/A | ⬜ pending |
| 49-01-* | 01 | 1 | Success Criterion #4 (TCC prompt-bug repro/rule-out) | — | N/A | manual-only, on-device, from Islet.app's own binary | `checkpoint:human-verify` (non-repro is a valid outcome) | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — no test framework or fixture gap. This phase's verification is entirely on-device/manual by design, consistent with this project's existing spike-phase convention (Phase 22).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `likeTrack()` send + effect on Music.app/Spotify.app | Success Criterion #1 | Requires real MediaRemote IPC to a running player app | Trigger `likeTrack()` via a throwaway hook while Music.app/Spotify.app plays a track; observe whether the app's own liked-state UI updates |
| `current track`/`loved` AppleScript matrix (library / streaming-only / play-pause) | Success Criterion #2 | Requires real Music.app library state and real AppleScript dictionary behavior on this hardware | Run `osascript` snippets against Music.app across each state combination; record `-1728` occurrences |
| Spotify OAuth PKCE + `PUT /me/library` round-trip | Success Criterion #3 | Requires a real registered Spotify Developer app, real user consent, and a real network call | Register app on Spotify Developer Dashboard, run PKCE shell script end-to-end, confirm `PUT` call succeeds and dashboard quota-mode is read directly |
| Automation (TCC) permission-prompt bug repro/rule-out | Success Criterion #4 | TCC state is OS/session-specific and cannot be simulated | Run AppleScript calls from Islet.app's own compiled binary (not Terminal), across fresh-grant and idle-elapsed states; record `-1743` occurrences |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (build-only automated verify; behavior is manual-only by design)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (build gate runs after every task commit)
- [x] Wave 0 covers all MISSING references (none — no gap)
- [x] No watch-mode flags
- [x] Feedback latency < 60s (build gate)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
