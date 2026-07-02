# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — MVP

**Shipped:** 2026-07-02
**Phases:** 7 (0-6, Phase 5 superseded by Phase 6) | **Plans:** 31 executed (+3 superseded) | **Sessions:** multiple across 2026-06-26 → 2026-07-02

### What Was Built
- A menu-bar background agent with a proven sign→notarize→staple release pipeline (Phase 0)
- A borderless, always-on-top notch overlay positioned exactly on the physical notch, surviving display/clamshell changes (Phase 1)
- Dynamic-Island-quality spring-morph expand/collapse with focus-safe hover/click and reliable true-fullscreen hiding (Phase 2)
- Live activities: charging splash (Phase 3), Now Playing with album art/transport controls behind an isolated, swappable MediaRemote service (Phase 4), and Bluetooth/AirPods device connect/disconnect with battery % (Phase 6, absorbed from Phase 5)
- A single pure `IslandResolver` priority arbiter (Charging > Device > Now Playing) plus a bounded `TransientQueue`, and a settings window with activity toggles + accent theming (Phase 6)
- A fully closed security threat register (25 threats, 0 open) and a clean final code review

### What Worked
- **Pure-seam-first discipline** (RED→GREEN unit tests on pure logic before any AppKit/SwiftUI wiring) caught real bugs early and made later gap-closure plans (06-07 through 06-13) fast to verify — each fix had an existing test harness to extend.
- **Isolating the risky private API** (MediaRemote) behind one `NowPlayingMonitor`/`NowPlayingService` protocol meant repeated fresh code reviews never flagged it as a growing risk surface — it stayed a one-file swap point throughout.
- **Iterative gap-closure phases** (06-06 through 06-13, driven by UAT + fresh multi-agent code reviews) converged the codebase to zero open findings without ever re-planning from scratch — each fix built on the prior wave's tests.
- **Threat modeling at plan time** (every one of Phase 6's 13 plans carried a `<threat_model>` block) meant the final `/gsd:secure-phase` run could short-circuit straight to a verified SECURITY.md with no additional auditor pass needed.

### What Was Inefficient
- **Phase bookkeeping drifted from actual completion state repeatedly.** Phase 0 and Phase 1's ROADMAP.md checkboxes and Progress-table rows stayed "Not started" long after both phases were 100% done (all plans executed, summaries present) — only caught during milestone-close readiness checks. Same pattern hit `REQUIREMENTS.md`: DEV-01/DEV-02 and APP-01/APP-02 were functionally complete but never checked off, because `phase.complete` only updates STATE.md frontmatter + plan checkboxes, not the ROADMAP top checklist/Progress table or REQUIREMENTS.md checkboxes (see `[[gsd-phase-complete-roadmap-gaps]]` project memory).
- **Phase 5 was left in a permanently ambiguous state for days** ("device wiring finished INSIDE Phase 6" documented in STATE.md, but never formally resolved in ROADMAP.md) until milestone close forced the decision. Absorbing a phase's scope into a later phase should trigger an immediate ROADMAP.md status update, not wait for milestone-close audit to surface it.
- **Debug session files and UAT files accumulated stale status fields.** Three debug sessions (`battery-indicator-accent-not-tinted`, `charging-yield-width-jump`, `fullscreen-enter-flash`) were diagnosed and two of them fixed by gap-closure plan 06-06, but their frontmatter/location never advanced to `resolved`/`.planning/debug/resolved/` because that step only fires automatically for decimal (X.Y) gap-closure phases, not integer phases with internal gap-closure plans.

### Patterns Established
- **Three UAT artifact types per phase are normal, not a bug:** `{phase}-UAT.md` (original UAT session, becomes `diagnosed`→`resolved` after gap closure), `{phase}-HUMAN-UAT.md` (created by execute-phase when verify_phase_goal returns `human_needed`, tracks post-verification on-device checks), and `{phase}-VERIFICATION.md` (the automated goal-backward check). All three need their status fields kept in sync manually when the underlying work resolves — none of this syncing happens automatically today.
- **Milestone close is the actual integration test for planning-artifact hygiene.** The pre-close `audit-open` check is what actually catches drifted checkboxes/statuses across phases — treat it as a required gate, not a formality, even when a phase "feels" done.

### Key Lessons
1. When a phase's scope is deliberately folded into a later phase, update ROADMAP.md's phase entry (checkbox + Progress table row) to "Superseded by Phase N" immediately, not at milestone close — leaving it ambiguous for days invites drift and confuses future `roadmap.analyze` reads.
2. After closing a UAT gap or debug session outside the decimal-phase gap-closure flow, manually advance the source UAT/debug-session status fields (`diagnosed`→`resolved`, move debug files to `.planning/debug/resolved/`) in the same commit as the fix — don't rely on `close_parent_artifacts` catching it later, since that step is decimal-phase-only.
3. Run `gsd-sdk query audit-open` early and often in a milestone's final phase, not just at `/gsd:complete-milestone` — it would have caught the Phase 0/1 checkbox drift and the REQUIREMENTS.md staleness weeks earlier.
4. A `human_needed` verification status is not the end of the workflow — `06-HUMAN-UAT.md` needs an explicit `/gsd:verify-work {phase}` pass to actually close the loop, and the source `VERIFICATION.md` status field needs a manual update afterward since `verify-work.md` doesn't write back to it.

### Cost Observations
- Sessions: several across ~6 days of wall-clock development
- Notable: gap-closure waves (06-06 through 06-13) were driven almost entirely by fresh multi-agent code reviews rather than new feature work — a sign the core build was solid early and later effort went into hardening, not architecture rework

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | several | 7 (0-6) | First milestone — established pure-seam-first TDD discipline and isolated-service pattern for risky private APIs |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|---------------------|
| v1.0 | 131 (XCTest) | Not measured (no coverage tool configured) | mediaremote-adapter (SPM) |

### Top Lessons (Verified Across Milestones)

1. Planning-artifact bookkeeping (ROADMAP.md checkboxes, REQUIREMENTS.md checkboxes, debug-session/UAT status fields) drifts silently unless actively audited — `gsd-sdk query audit-open` is the tool that catches it, run it proactively, not just at milestone close.
