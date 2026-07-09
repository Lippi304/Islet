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

## Milestone: v1.2 — Now Playing Polish

**Shipped:** 2026-07-09
**Phases:** 2 (17-18) | **Plans:** 3 | **Tasks:** 9 | **Sessions:** 1 (single day, 2026-07-09)

### What Was Built
- `hasPlayedSinceLaunch` flag + `nowPlayingLaunchGate` pure helper (mirroring the existing `nowPlayingHealthGate` shape) gates the ambient Now Playing glance until a real Play is observed — a paused/loaded track at launch no longer triggers it (Phase 17, NOW-04)
- A pure `songChangeToastGate`/`songChangeToastContent` seam plus controller wiring detects a genuine track change and shows a brief title+artist toast with an independent ~2s dismiss, suppressed during Charging/Device activity and while manually expanded, with a Settings toggle (Phase 18, NOW-05/NOW-06)

### What Worked
- **Reusing existing gate/seam shapes** (`nowPlayingLaunchGate` mirrors `nowPlayingHealthGate`; the toast reused `isSameTrack(_:_:)`) kept both phases small, fast, and consistent with the codebase's established pure-seam-first pattern from v1.0.
- **On-device iteration as the actual design process for Phase 18** — the toast went through 5 rounds (full blob → shrink → structural redesign to a fading text row → centering → independent duration) converging faster than trying to nail the design upfront in UI-SPEC.md would have.

### What Was Inefficient
- **REQUIREMENTS.md traceability wasn't updated when Phase 17 closed** — NOW-04 sat unchecked and "Pending" despite being on-device verified and approved, only caught during this milestone-close review. This is the same root-cause class the v1.0 retrospective already flagged (Top Lesson 1: phase-close doesn't sync REQUIREMENTS.md checkboxes) — it recurred here too.
- **`gsd-sdk query audit-open` flagged 8 already-complete quick-tasks as status `missing`** at milestone-close time, even though all 8 have PLAN.md + SUMMARY.md on disk and are logged "Complete ✓" in STATE.md's own tracking table. Acknowledged as a tool false positive rather than blocking, but worth a look at the audit tool's completion-detection logic before it erodes trust in the gate.
- **This RETROSPECTIVE.md had no v1.0.1 or v1.1 sections** — the "after each milestone" append step was skipped twice before this close. Not a v1.2 defect, but a process gap worth naming so it doesn't recur a third time.

### Patterns Established
- **UI-SPEC.md is a pre-execution draft, not a contract** — on-device feedback is expected to override it, and the spec gets updated to match reality *after* approval, not treated as locked scope during execution.
- **Per-activity dismiss durations don't need to share one constant** — the toast's independent 2.0s timer coexists fine with the shared 3.0s `activityDuration` used elsewhere.

### Key Lessons
1. Sync REQUIREMENTS.md's checkbox + traceability status in the same commit that closes a phase's plan, not just at milestone close — this is a repeat of v1.0's lesson, so it may need an actual workflow-step fix (not just a retrospective note) to stop recurring.
2. Treat `audit-open` "missing" statuses as a prompt to hand-verify against STATE.md's own completed-tasks table before accepting them at face value — in this milestone all 8 were false positives.
3. Actually run the retrospective-append step at every milestone close, not just the first — two milestones' worth of lessons (v1.0.1, v1.1) were never captured here.

### Cost Observations
- Sessions: 1 (entire milestone shipped same-day)
- Notable: smallest milestone to date (2 phases, 3 plans) — tight requirement scope (3 requirements) meant same-day turnaround from discuss→plan→execute→verify for both phases

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | several | 7 (0-6) | First milestone — established pure-seam-first TDD discipline and isolated-service pattern for risky private APIs |
| v1.0.1 | — (retrospective not captured at close) | 3 (7-9) | Progress bar + fullscreen-flash root-cause fix via dedicated CGS Space |
| v1.1 | — (retrospective not captured at close) | 4 (10-13) | Trial/lockout, Polar.sh licensing, real notarization |
| v1.2 | 1 | 2 (17-18) | Smallest milestone to date; on-device iteration used as the actual design process for Phase 18 |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|---------------------|
| v1.0 | 131 (XCTest) | Not measured (no coverage tool configured) | mediaremote-adapter (SPM) |
| v1.0.1 | 141 (XCTest) | Not measured | none |
| v1.1 | 185 (XCTest) | Not measured | none |
| v1.2 | 185+ (4 new `IslandResolverTests` + toast seam tests; exact count not re-tallied) | Not measured | none |

### Top Lessons (Verified Across Milestones)

1. Planning-artifact bookkeeping (ROADMAP.md checkboxes, REQUIREMENTS.md checkboxes, debug-session/UAT status fields) drifts silently unless actively audited — `gsd-sdk query audit-open` is the tool that catches it, run it proactively, not just at milestone close. **Recurred at v1.2 close** (NOW-04 sat unchecked after Phase 17) — this is now a confirmed repeat pattern, not a one-off.
2. The retrospective-append step itself gets skipped under time pressure (v1.0.1 and v1.1 both shipped without a retrospective section, only backfilled retroactively at v1.2 close) — treat it as a required milestone-close step, not optional polish.
