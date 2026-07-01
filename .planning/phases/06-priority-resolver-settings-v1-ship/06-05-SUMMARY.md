---
phase: 06-priority-resolver-settings-v1-ship
plan: 05
subsystem: release
tags: [xcodegen, hdiutil, notarization-dry-run, nowplaying, swiftui, on-device]

# Dependency graph
requires:
  - phase: 06-priority-resolver-settings-v1-ship
    provides: "Single-arbiter integration + live device battery (06-04) — the v1 feature set this ship gate packages"
provides:
  - "project.yml at MARKETING_VERSION 0.1 (D-14 private first release), PRODUCT_NAME/bundle id unchanged (D-13)"
  - "dist/Islet.dmg — ad-hoc signed dry-run distributable via the unchanged scripts/release.sh (D-15)"
  - "D-16 verdict: Now Playing launch-time health check confirmed healthy on-device on the current macOS build"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "TimelineView(.animation, paused:)-driven equalizer bars instead of implicit repeatForever animations — immune to ambient withAnimation transactions from unrelated view updates, and idle-CPU-safe when paused"

key-files:
  created: []
  modified:
    - project.yml
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "D-14 executed: MARKETING_VERSION 1.0 -> 0.1 (private release); 1.0 stays reserved for the public/sellable launch"
  - "D-15 executed as a pure dry-run: scripts/release.sh left unchanged, Developer-ID/notary placeholders untouched, ad-hoc sign + hdiutil UDZO DMG + SKIP banner + exit 0 — real notarize/staple remains a deferred carry-over pending a paid Developer-ID account"
  - "D-16 confirmed healthy: NowPlayingMonitor's launch-time health check received a callback within the 3s window on the current macOS build (27.0 / 26A5368g) — no regression"
  - "On-device UAT during the Task 3 checkpoint surfaced independent UI bugs (equalizer freeze-on-hover, media content spacing) — fixed inline rather than deferred, following the same post-checkpoint-fix pattern as 06-04"

requirements-completed: [APP-04]

# Metrics
duration: multi-session (checkpoint + post-checkpoint iteration)
completed: 2026-06-29
---

# Phase 6 Plan 05: Ship Gate (Dry-Run) + D-16 Health Re-Check Summary

**v1 ships as a dry-run notarizable build: project.yml bumped to 0.1, `scripts/release.sh` produced `dist/Islet.dmg` unchanged and exited clean with the SKIP banner, and the Now Playing launch health check was re-confirmed healthy on-device — closing out APP-04.**

## Accomplishments
- **D-13/D-14:** `project.yml` ships `MARKETING_VERSION: "0.1"` (private first release); `PRODUCT_NAME: Islet` and the bundle id are unchanged. `xcodebuild build -scheme Islet` succeeded with the new version baked into Info.plist.
- **D-15:** `scripts/release.sh` ran completely unmodified. Log confirms: `** ARCHIVE SUCCEEDED **` → ad-hoc sign (`-> No Developer ID set: AD-HOC signing for local dry-run (D-03).`) → `dist/Islet.dmg` created via `hdiutil create ... -format UDZO` → `SKIPPING notarize + staple — placeholders not filled (Phase 6 step).` → `Phase-0 dry run complete: dist/Islet.dmg (ad-hoc signed, NOT notarized).` `dist/Islet.dmg` (620KB) is present on disk.
- **D-16:** On-device re-verification of the Now Playing health check — **healthy**. Now Playing info displayed and transport commands (play/pause/skip) worked correctly on the currently installed macOS build (ProductVersion 27.0, BuildVersion 26A5368g). No regression from the Phase-4 standing blocker.
- v1.0 milestone requirements (COORD-01, DEV-01, DEV-02, APP-03, APP-04) are now all code-complete; Phase 6 is the last phase in the milestone.

## Task Commits
1. **Task 1: Bump project.yml to version 0.1** — `2c61ee0`
2. **Task 2: Run the release pipeline as the D-15 dry-run** — no commit (build artifacts `dist/`/`build/` are gitignored per Phase 0); verified via `/tmp/islet_release.log` and `dist/Islet.dmg` on disk
3. **Task 3: On-device human-verify (D-16)** — approved, healthy (see post-checkpoint fixes below)

### Post-checkpoint fixes (from on-device UAT)
- `f2e3704` reliable equalizer loop + inset media art/bars from notch edge — the implicit `.animation(.repeatForever, value:)` form often never engaged; each bar now drives its own explicit `withAnimation(.repeatForever)` via `onAppear`/`onChange`, gated by `isPlaying`
- `bde3f61` inset expanded media content +5pt from the notch edge
- `78914dd` equalizer bars no longer freeze on hover (TimelineView-driven) — hovering ran a `withAnimation(.spring)` transaction in the controller that overrode the bars' state-based loop; bars now derive their height from `TimelineView(.animation, paused: !isPlaying)` (a sine of frame time), immune to ambient transactions, idle CPU ~0 when paused

## Files Created/Modified
- `project.yml` — `MARKETING_VERSION` 1.0 → 0.1
- `Islet/Notch/NotchPillView.swift` — equalizer bar animation reliability + hover-freeze fix + media content inset

## Decisions Made
See key-decisions (D-14/D-15/D-16 execution outcomes; TimelineView-driven equalizer pattern).

## Deviations from Plan
Tasks 1–2 landed as written. As with 06-04, the bulk of the checkpoint outcome was **post-checkpoint iteration** driven by on-device UAT: the user found two independent, pre-existing UI polish bugs in the Now Playing equalizer/media wing (unrelated to the D-16 health check itself) and fixed them inline rather than filing them as a gap. No architectural changes; scope stayed within Phase 6.

## Issues Encountered
- SwiftUI's implicit `repeatForever` animation modifier is unreliable under ambient `withAnimation` transactions from sibling view updates (hover state) — resolved by switching the equalizer to a `TimelineView`-driven, transaction-immune render.

## Known Stubs
Deferred carry-overs (not blockers, per D-13/D-14/D-15): the public product name + version 1.0, and the real Developer-ID sign → notarize → staple + clean-second-Mac open (needs a paid Developer-ID account). Both were explicitly out of scope for this dry-run ship gate.

## User Setup Required
None for this dry-run. The deferred carry-over (real notarization) will require an Apple Developer ID + notary credentials when pursued.

## Next Phase Readiness
- Phase 6 is now complete — all 5 plans have summaries. This was the last phase in the v1.0 milestone roadmap.
- v1.0 core value (island reacts to charging, device connection, and now-playing media, under one resolver, with settings/accent, shipping as a dry-run build) is fully realized.
- Ready for `/gsd-verify-work 6` (or milestone-level UAT) and `/gsd-complete-milestone` once the user is satisfied.

---
*Phase: 06-priority-resolver-settings-v1-ship*
*Completed: 2026-06-29*
