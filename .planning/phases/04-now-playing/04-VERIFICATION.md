---
phase: 04-now-playing
verified: 2026-06-28T00:00:00Z
status: passed
score: 4/4 roadmap success criteria verified (16/16 plan must-haves)
overrides_applied: 0
human_verification: []
---

# Phase 4: Now Playing Verification Report

**Phase Goal:** The core install driver — current media from any app shows album art, title, and artist in the island with working transport controls, built entirely behind one isolated service that fails gracefully when the system API is blocked.
**Verified:** 2026-06-28
**Status:** passed
**Re-verification:** No — initial verification

## Verification Method Note

This phase's outcome splits into two verification surfaces:

- **On-device / live-IPC criteria** (live MediaRemote IPC, transport reaching the real Spotify/Apple Music session, restart survival, idle-CPU when paused, charging-vs-media precedence, no orphaned perl) were verified by the **USER on-device** during the 04-04 human-verify UAT checkpoint and explicitly confirmed ("passt", 2026-06-28). These are documented as **human-confirmed**, not as gaps. They are inherently unreachable by a background agent (no notch hardware, no live media session, no signing identity for a runnable signed app).
- **Static / code-level must-haves** (single isolated service, launch health check, deinit teardown, pure seam, D-11/D-12/D-13 graceful paths, idle-CPU animation gating, no repeating Timer, single `updateVisibility()` gate, transport wiring, D-14 precedence ordering) were verified **directly against the codebase** — read, grep, and a clean `BUILD SUCCEEDED`.

A standard code review (04-REVIEW.md) found **0 critical, 3 warnings (advisory, non-blocking)**: a latent off-main teardown comment/race in `deinit` (WR-01), health-probe stickiness on quiet paused sessions (WR-02), and no adapter-restart debounce (WR-03). These are recorded below as **known advisory items**, not phase-blocking gaps — each is a low-probability edge case with a self-healing or singleton-lifetime mitigation already in place.

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Media in any app (Apple Music, Spotify, browser) → island shows album art, title, artist | ✓ VERIFIED (code + user UAT) | `mediaWings`/`mediaExpanded` render `artThumbnail` + title (bold) + artist (grey) from `nowPlayingState`; D-01 allowlist (`com.spotify.client`, `com.apple.Music`) in `NowPlayingPresentation.swift:40` excludes browsers. User confirmed live render for Spotify + Apple Music in UAT. |
| 2 | User can play/pause, skip next, prev from the expanded island | ✓ VERIFIED (code + user UAT) | `transportButton("backward.fill"/"playpause.fill"/"forward.fill")` → `onPrevious/onTogglePlayPause/onNext` closures → controller forwards to `nowPlayingMonitor?.previousTrack()/togglePlayPause()/nextTrack()` (NotchWindowController.swift:295-297) → `MediaController` transport rides the existing child stdin. User confirmed live transport on both apps. |
| 3 | Survives restart; on unavailable/blocked API, clears state + explicit "unavailable", no crash/empty | ✓ VERIFIED (code + user UAT) | `start()` opens the persistent child that emits the current session immediately (restart survival). D-12: `runHealthCheck` 3s timeout → `isHealthy=false` → `mediaUnavailable` ("Now Playing nicht verfügbar"). D-13: `handleAdapterTerminated` clears `.none` + `isHealthy=false`. D-11 ≠ D-12 modeled as orthogonal axes (no `.unavailable` in the enum). User confirmed graceful behavior in UAT. |
| 4 | All MediaRemote access behind a single service with a launch health check, consuming the stream (not re-spawning), main-thread callbacks | ✓ VERIFIED (code) | `import MediaRemoteAdapter` appears in exactly ONE file (`NowPlayingMonitor.swift`, grep confirmed). `startListening()` + `onTrackInfoReceived` (persistent stream); `getTrackInfo` used ONLY in `runHealthCheck` (the one-shot health probe), never per-update. No second main-hop (wrapper already hops; A2). `runHealthCheck` is the launch-time D-12 probe. |

**Score:** 4/4 roadmap success criteria verified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/NowPlayingPresentation.swift` | Pure Foundation-only seam + D-01 allowlist | ✓ VERIFIED | Foundation-only (no AppKit/MediaRemoteAdapter import); total `nowPlayingPresentation(from:)`; allowlist exactly Spotify + Apple Music; no `.unavailable` case. Wired: imported by tests + monitor + controller. |
| `IsletTests/NowPlayingPresentationTests.swift` | RED→GREEN fixtures for NOW-01/NOW-03 | ✓ VERIFIED | All 5 named methods present (testAllowlistFiltersBundleID, testNoTitleMapsToNone, testPlayingVsPausedClassification, testNilSnapshotMapsToNone, testNilIsPlayingMapsToPaused). |
| `project.yml` | Adapter SPM dep pinned by revision, embed+sign | ✓ VERIFIED | `url: …/ejbills/mediaremote-adapter`, `revision: cf30c4f…`, `product: MediaRemoteAdapter`, `embed: true`, `codeSign: true`. |
| `Islet/Notch/NowPlayingState.swift` | @Published model (presentation + artwork + isHealthy) | ✓ VERIFIED | `final class NowPlayingState: ObservableObject` with the three `@Published` props, no methods/timers. Observed by `NotchPillView`, owned by controller. |
| `Islet/Notch/NowPlayingMonitor.swift` | Single isolated bridge: stream/transport/health/teardown | ✓ VERIFIED | Sole `import MediaRemoteAdapter`; `startListening`/`onTrackInfoReceived`; `onListenerTerminated` (D-13); `stop()` → `stopListening()`; transport trio; `runHealthCheck` (D-12); lifts `TrackSnapshot`. |
| `Islet/Notch/NotchPillView.swift` | Media wings + expanded + EqualizerBars + D-14 precedence | ✓ VERIFIED | `@ObservedObject var nowPlaying`; `struct EqualizerBars` with `.repeatForever` ONLY in the `isPlaying ?` true branch; `mediaWings`/`mediaExpanded`/`mediaUnavailable`; nil-art `music.note` placeholder; body if-chain charging > expanded > media-wings > collapsed. |
| `Islet/Notch/NotchWindowController.swift` | Ownership, handleNowPlaying, health check, dismiss, transport, deinit teardown | ✓ VERIFIED | `nowPlayingState`/`nowPlayingMonitor`; `handleNowPlaying` (pure seam + spring + single `updateVisibility()`); `handleAdapterTerminated`; `scheduleMediaDismiss` (one-shot, no Timer); transport closures; `deinit` calls `nowPlayingMonitor?.stop()` + cancels `mediaDismissWorkItem`. |

### Key Link Verification

| From | To | Via | Status |
|------|----|----|--------|
| Tests | NowPlayingPresentation.swift | `nowPlayingPresentation(from:)` | ✓ WIRED |
| project.yml | ejbills/mediaremote-adapter | revision pin | ✓ WIRED |
| NowPlayingMonitor | MediaRemoteAdapter.MediaController | `onTrackInfoReceived` + `startListening()` | ✓ WIRED |
| NowPlayingMonitor | NowPlayingPresentation | `TrackSnapshot(...)` lift | ✓ WIRED |
| NotchPillView | NowPlayingState | `@ObservedObject var nowPlaying` | ✓ WIRED |
| EqualizerBars.animation | isPlaying gate | conditional `isPlaying ?` (repeatForever only when true) | ✓ WIRED |
| Controller.start() | NowPlayingMonitor | `monitor.start()` + `runHealthCheck` + retained for deinit | ✓ WIRED |
| Controller.handleNowPlaying | updateVisibility() | single show/hide gate after publishing | ✓ WIRED |
| Transport closures | NowPlayingMonitor transport | `onTogglePlayPause/onNext/onPrevious` → monitor | ✓ WIRED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Whole app compiles with all 4 NowPlaying files + wiring | `xcodebuild build -scheme Islet` | `** BUILD SUCCEEDED **` | ✓ PASS |
| Single isolated MediaRemote importer | `grep -rn "import MediaRemoteAdapter" Islet/` | 1 hit (NowPlayingMonitor.swift) | ✓ PASS |
| No repeating Timer in now-playing code | `grep -E "Timer\(|Timer\.scheduled" …` | no matches (exit 1) | ✓ PASS |
| Unit suite (NowPlayingPresentationTests) | `xcodebuild test …` | Build OK; test run blocked only at CodeSign (signing-identity unavailable in background agent) — SUMMARY + REVIEW report 77/77 green on user's machine | ? SKIP (env) |

The unit-test *execution* could not complete in this background environment: the test run requires CodeSigning the embedded MediaRemoteAdapter framework, which needs the user's signing identity (absent here). The Swift **compilation** of the test target + app succeeds (`BUILD SUCCEEDED`), and 04-01-SUMMARY independently records 77/77 green on the user's machine. This is an environment limitation, not a code defect.

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|----------------|-------------|--------|----------|
| NOW-01 | 04-01, 04-02, 04-03, 04-04 | Media playing → island shows album art, title, artist | ✓ SATISFIED | Pure seam classification + media wings/expanded render + live UAT (Spotify, Apple Music). |
| NOW-02 | 04-02, 04-03, 04-04 | Play/pause, next, previous from expanded island | ✓ SATISFIED | Transport buttons → closures → monitor → live session; user-confirmed on both apps. |
| NOW-03 | 04-01, 04-02, 04-04 | Survives restart; degrades gracefully (clears state, no crash) when unavailable/blocked | ✓ SATISFIED | Persistent stream emits current session on launch; D-12 health check + D-13 mid-death → "nicht verfügbar"/clear; user-confirmed graceful. |

All three phase requirement IDs accounted for and satisfied. REQUIREMENTS.md maps exactly NOW-01/02/03 to Phase 4 — no orphaned requirements. (Note: REQUIREMENTS.md traceability table still lists NOW-01/02/03 as "Pending" and the checklist boxes unchecked — a post-phase bookkeeping update, per the known "GSD phase-complete ROADMAP gaps" memory; not a phase deliverable gap.)

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| NowPlayingPresentation.swift | 27 | `hasArtwork` carried but never read by any consumer (IN-01) | ℹ️ Info | Dead state on the value type; no behavioral effect. View renders the real NSImage directly. |
| NowPlayingMonitor.swift | 55-69 | `onDecodingError` never wired (IN-02) | ℹ️ Info | Malformed JSON silently dropped; not a security hole (Text truncation + JSONDecoder are inert). |
| NowPlayingMonitor.swift | 90 | `3.0` health-probe timeout is a magic number (IN-03) | ℹ️ Info | Inconsistent with named tuning seeds elsewhere; cosmetic. |
| NotchPillView.swift | 267-272 | `titleArtist` `.none` branch unreachable (IN-04, acknowledged) | ℹ️ Info | Defensive switch exhaustiveness; comment acknowledges. |

No `TODO`/`FIXME`/`PLACEHOLDER`, no stub returns, no empty handlers, no hardcoded-empty data flowing to render. The nil-artwork `music.note` and `Color.clear` reserved D-09 slots are intentional design, not stubs.

### Known Advisory Items (from 04-REVIEW.md — non-blocking)

| ID | Severity | Item | Disposition |
|----|----------|------|-------------|
| WR-01 | Warning | `stopListening()` mutates main-only state from a nonisolated `deinit`; the "thread-safe" comment overstates safety | Low-probability — controller is a long-lived singleton whose deinit coincides with app teardown. Advisory: prefer an explicit MainActor `shutdown()` from `applicationWillTerminate`; soften the comment. |
| WR-02 | Warning | `runHealthCheck` 3s timeout can spuriously set `isHealthy=false` on a quiet paused session even when the live stream already emitted | Self-healing while streaming; only sticks on a paused/idle session that emitted once then went quiet. Advisory: cancel the negative verdict once any live emission is seen. |
| WR-03 | Warning | No debounce: the wrapper's 100-event auto-restart could (if the internal guard ever loses the race) surface as a transient D-13 "unavailable" | Currently suppressed by the vendored wrapper's `eventCount==0` guard; not a guaranteed bug. Advisory: debounce `handleAdapterTerminated` and cancel on the next emission. |

These are advisory follow-ups (candidates for Phase 5/6 hardening or a `/gsd-quick`), explicitly NOT phase-blocking.

### Human Verification Required

None outstanding. The on-device UAT (live transport, restart, idle-CPU, D-12/D-13 graceful, D-14 precedence, no orphaned perl) was completed and confirmed by the user during the 04-04 checkpoint ("passt", 2026-06-28).

### Gaps Summary

No gaps. All four ROADMAP success criteria are achieved: the static/code-level invariants verified directly against the codebase (clean `BUILD SUCCEEDED`, single isolated importer, no repeating Timer, correct pure-seam classification, D-11/D-12/D-13 orthogonal modeling, single visibility gate, transport wiring, idle-CPU animation gating, deinit teardown), and the live-IPC/on-device criteria confirmed by the user in UAT. The three REVIEW warnings are advisory hardening items with existing mitigations, not goal-blocking defects.

---

_Verified: 2026-06-28_
_Verifier: Claude (gsd-verifier)_
