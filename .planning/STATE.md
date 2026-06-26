# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-26)

**Core value:** The notch becomes a beautiful, reliable island that shows now-playing media and reacts when you plug in the charger or connect a device — native, smooth, and as polished as the iPhone Dynamic Island.
**Current focus:** Phase 0 — Foundations & Notarization Dry Run

## Current Position

Phase: 0 of 6 (Foundations & Notarization Dry Run)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-06-26 — Roadmap created (7 phases, 19/19 v1 requirements mapped)

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: — min
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap] Charging (Phase 3) is built before Now Playing (Phase 4): proves the activity→island loop on the safest public API (IOKit) before the fragile MediaRemote landmine. (Diverges from research SUMMARY's "Now Playing first"; activity-arbitration nuance deferred to Phase 6 resolver.)
- [Roadmap] Notarization toolchain proven in Phase 0 on a hello-world build, not deferred to release — the single biggest first-timer footgun.
- [Roadmap] Fullscreen-hide (ISL-05) and multi-display/clamshell correctness (ISL-06) are CORE success criteria in Phases 1–2, not polish.
- [Roadmap] All MediaRemote access isolated behind one NowPlayingService with a launch-time health check (Phase 4); a future Apple change is a one-file fix.

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

None yet.

### Blockers/Concerns

[Issues that affect future work]

- [Phase 4] MediaRemote longevity is unknowable. Verify the mediaremote-adapter version against the *currently installed* macOS at Phase-4 planning; treat each macOS update as a Now-Playing regression event.
- [Phase 1] Open decision: DynamicNotchKit vs. a custom NSPanel for the overlay. Decide at Phase-1 planning (prototype-with-it then graduate, or roll the panel directly).
- [Phase 0] Confirm the macOS deployment floor (14.0 recommended for reach vs 15.0) before starting.
- [Phase 4] No Apple Developer account yet — only needed for notarization. Phase 0's dry run and Phase 6's release both require it ($99/yr).

## Session Continuity

Last session: 2026-06-26
Stopped at: Roadmap and STATE created during project initialization
Resume file: None
