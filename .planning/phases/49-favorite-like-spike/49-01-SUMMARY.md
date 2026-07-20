---
phase: 49-favorite-like-spike
plan: 01
subsystem: infra
tags: [mediaremote-adapter, appleevents, tcc, applescript, entitlements]

# Dependency graph
requires: []
provides:
  - "com.apple.security.automation.apple-events entitlement + NSAppleEventsUsageDescription Info.plist key landed"
  - "Honest, on-device-verified verdict for ROADMAP Phase 49 Success Criterion #1 (likeTrack effect): like-effect-not-observed"
  - "Honest, on-device-verified verdict for ROADMAP Phase 49 Success Criterion #4 (TCC/Automation prompt bug): tcc-bug-ruled-out"
  - "Confirmation (restated from RESEARCH.md, not re-tested) that the streamed MediaRemote payload has no favorite/rating/wishlist read-state field"
affects: [49-04-favorite-like-spike, 50-favorite-like-implementation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "DEBUG-only spike hooks mirroring this project's Phase 22/38/39 throwaway-scaffold convention, NSLog-marked, reachable from the existing debug status-bar menu"

key-files:
  created: []
  modified:
    - Islet/Islet.entitlements
    - project.yml
    - Islet.xcodeproj/project.pbxproj
    - Islet/Notch/NowPlayingMonitor.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/AppDelegate.swift

key-decisions:
  - "SC#1 verdict: like-effect-not-observed — MRMediaRemoteSendCommand(kMRLikeTrack) sends cleanly but neither Music.app's heart icon nor Spotify's Liked Songs state visibly flip"
  - "SC#4 verdict: tcc-bug-ruled-out — permission dialog appeared on first automation attempt from Islet's own binary, granting it fixed the call, no -1743 recurrence observed (idle-time relaunch variant not attempted this session, acceptable per D-06)"
  - "Phase 50's star button cannot source its initial 'already liked' read-state or its write effect from this MediaRemote path — needs Apple Music AppleScript loved / Spotify GET+PUT /me/library instead (RESEARCH.md, restated here per plan's <output> spec)"

patterns-established: []

requirements-completed: []  # D-06 is a CONTEXT.md decision ID, not a formal REQUIREMENTS.md entry — no REQUIREMENTS.md checkbox to mark for this phase (FAV-01..03 belong to Phase 50)

# Metrics
duration: 10min active (Tasks 1-2) + on-device human checkpoint session
completed: 2026-07-20
---

# Phase 49 Plan 01: Apple Events Prerequisite + likeTrack/TCC Spike Hooks Summary

**Entitlement/Info.plist landed and two DEBUG-only spike hooks confirm on real hardware that the private MediaRemote like command sends cleanly but has no observable effect on Music.app/Spotify.app, while the Automation/TCC permission-prompt bug is ruled out on this machine.**

## Performance

- **Duration:** ~10 min active work (Tasks 1-2) + a separate on-device human-verify checkpoint session
- **Started:** 2026-07-20T14:04:22Z
- **Completed:** 2026-07-20T14:53:00Z (approx, includes checkpoint wait)
- **Tasks:** 3 (2 auto + 1 checkpoint:human-verify)
- **Files modified:** 6

## Accomplishments
- `com.apple.security.automation.apple-events` entitlement + `INFOPLIST_KEY_NSAppleEventsUsageDescription` landed via `project.yml` (xcodegen source of truth), regenerated into `project.pbxproj`, Debug build green — unblocks any AppleScript call from Islet's own binary under Hardened Runtime.
- Two DEBUG-only spike hooks (`spikeLikeCurrentTrack()`, `spikeTriggerAutomationPrompt()`) wired end-to-end: `NowPlayingMonitor` → `NotchWindowController` → `AppDelegate`'s existing 🐞 debug menu. Release build confirmed (via build-log grep) to exclude both symbols entirely.
- On-device checkpoint recorded an honest, separately-verdicted answer for ROADMAP Success Criteria #1 and #4 (see below) — both are now resolved, not open questions.

## Task Commits

Each task was committed atomically:

1. **Task 1: Land Apple Events entitlement + Info.plist key, regenerate, build-verify** - `3d7ad64` (feat)
2. **Task 2: Wire the two DEBUG-only spike hooks through the existing debug menu** - `38ecd8c` (feat)
3. **Task 3: On-device verification checkpoint** - no code commit (verification-only); verdicts recorded in this file

**Interim progress commit:** `d2f5d1d` (docs: record Task 1-2 progress, deviations, checkpoint pending)

**Plan metadata:** (this commit, follows) `docs: complete plan`

## Files Created/Modified
- `Islet/Islet.entitlements` - added `com.apple.security.automation.apple-events`
- `project.yml` - added `INFOPLIST_KEY_NSAppleEventsUsageDescription` (German string, Phase-49-commented)
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` (never hand-edited)
- `Islet/Notch/NowPlayingMonitor.swift` - added `#if DEBUG` protocol requirements + implementations for `spikeLikeCurrentTrack()` (calls `controller.likeTrack()`) and `spikeTriggerAutomationPrompt()` (NSAppleScript `current track` call, branches -1728 vs -1743)
- `Islet/Notch/NotchWindowController.swift` - added `#if DEBUG` forwarding methods to `nowPlayingMonitor`
- `Islet/AppDelegate.swift` - added two debug-menu items + `@MainActor @objc` action methods

## Decisions Made

- **SC#1 verdict — `like-effect-not-observed`:** Console confirmed `SPIKE likeTrack() sending kMRLikeTrack` logged cleanly (multiple times, no send error) — `MRMediaRemoteSendCommand(kMRLikeTrack, nil)` genuinely reaches both apps. User tested with **both** Music.app and Spotify.app while a track was playing; in **neither** app did the liked-state UI (heart icon in Music.app / "Liked Songs" in Spotify) visibly flip after the command was sent. The command sends successfully (confirms RESEARCH.md's code-level HIGH-confidence finding) but Music.app's/Spotify.app's current builds do not honor it as an actual "like" action.
- **SC#4 verdict — `tcc-bug-ruled-out`:** User clicked "Spike: Trigger Automation Prompt" with Music.app running a track loaded (post-entitlement/Info.plist). A macOS Automation permission dialog appeared on this first-ever attempt from Islet's own compiled binary; user granted it. Console then logged `SPIKE AppleScript succeeded: Beverly Hills` — the AppleScript `current track` call succeeded (returned the real track name), no error number logged (neither `-1728` nor `-1743`) after granting. The permission flow behaved normally: prompt appeared once, granting fixed it, no `-1743` recurrence. **Caveat:** the optional idle-time relaunch retest (quit Islet, wait, relaunch, repeat) was **not** attempted this session — per D-06 and RESEARCH.md's own framing, this is an acceptable, honestly-documented scope limitation; the `ruled-out` verdict rests on the normal single-grant flow observed, not on a forced idle-time reproduction attempt.
- **RESEARCH.md restated finding (Success Criterion #1's second half, not re-tested on-device — already HIGH-confidence, code-verified):** the streamed MediaRemote payload (`TrackInfo.Payload`/`MediaRemoteAdapterKeys.h`) contains **no** favorite/rating/wishlist read-state field. Combined with this plan's `like-effect-not-observed` write-side finding, **Phase 50's star button cannot use this MediaRemote path for either reading the initial "already liked" state or for a working write action** — it needs a separate read/write path per source app (Apple Music: AppleScript `loved of current track`; Spotify: `GET`/`PUT /me/library`, per STACK.md's original recommendation, now confirmed necessary rather than optional).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] NotchWindowController's spike-forwarding methods made internal, not `private` as the plan literally stated**
- **Found during:** Task 2
- **Issue:** The plan's action text said "add two private forwarding methods," but `AppDelegate` (a different type, in a different file) must call `notchController?.spikeLikeCurrentTrack()` — a `private` method is inaccessible across that boundary and would not compile.
- **Fix:** Declared the two forwarding methods with default (internal) access instead of `private`.
- **Files modified:** `Islet/Notch/NotchWindowController.swift`
- **Verification:** Debug build succeeded; `grep -c "nowPlayingMonitor?.spike"` returns 2 as the plan's acceptance criteria require.
- **Committed in:** `38ecd8c` (Task 2 commit)

**2. [Rule 1 - Bug] Added explicit `@MainActor` to the two new AppDelegate debug-menu action methods**
- **Found during:** Task 2 (first Debug build attempt)
- **Issue:** `NotchWindowController` (and its spike methods) are `@MainActor`-isolated. A plain `@objc private func` action method is not inferred `@MainActor` by default (unlike protocol-required `NSApplicationDelegate` methods such as `applicationDidFinishLaunching`), so the initial code failed with: "call to main actor-isolated instance method 'spikeLikeCurrentTrack()' in a synchronous nonisolated context."
- **Fix:** Added `@MainActor` to `debugSpikeLikeCurrentTrack()` and `debugSpikeTriggerAutomationPrompt()`.
- **Files modified:** `Islet/AppDelegate.swift`
- **Verification:** Debug build succeeded after the fix (`xcodebuild build -configuration Debug` exit 0).
- **Committed in:** `38ecd8c` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - blocking compile bugs, mechanical Swift-concurrency/access-control fixes, not design changes)
**Impact on plan:** Both fixes were required for the code to compile at all; no scope creep, no behavior beyond what the plan specified.

## Issues Encountered
None beyond the two deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan 49-04 (consolidated go/no-go) can now read this file for Success Criteria #1 and #4's final verdicts: **SC#1 = like-effect-not-observed** (command sends, no observable UI effect in either app), **SC#4 = tcc-bug-ruled-out** (normal single-grant flow, idle-time variant not attempted this session).
- Phase 50's planner must budget for a **separate read/write path** for the star button's favorite state (Apple Music AppleScript `loved`, Spotify `GET`/`PUT /me/library`) — the MediaRemote `likeTrack()`/streamed-payload path this plan spiked is confirmed **not viable** for either reading or writing favorite state, informing FAV-01's concrete implementation design.
- No blockers for Plans 49-02 (Apple Music matrix) / 49-03 (Spotify OAuth) — both proceed independently, per ROADMAP's stated Wave 1 parallelism.

---
*Phase: 49-favorite-like-spike*
*Completed: 2026-07-20*
