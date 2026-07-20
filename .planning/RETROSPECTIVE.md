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

## Milestone: v1.3 — Notch Shelf

**Shipped:** 2026-07-11 (with a known gap)
**Phases:** 3 shipped (19-21) of 4 planned | **Plans:** 5 executed (+ 3 more on the abandoned Phase 22) | **Sessions:** 2 (2026-07-09 → 2026-07-11)

### What Was Built
- A pure, Foundation-only shelf stack (`ShelfItem`/`ShelfLogic`/`ShelfFileStore`/`ShelfCoordinator`) with zero persistence path and zero coupling to `IslandResolver`/`TransientQueue` (Phase 19, SHELF-08)
- The full shelf view — horizontally-scrolling strip, per-item + delete-all trash, click-to-open, correct gating alongside Charging/Device splashes (Phase 20, SHELF-03/04/05/07/09)
- Drag-out to Finder/other apps via `.onDrag` + `NSItemProvider(contentsOf:)`, with a drag-pin keeping the island open for the gesture's duration (Phase 21, SHELF-06)
- **Not built:** drag-in (SHELF-01/02) — Phase 22 spiked the core technical question successfully (AppKit drag delivery does reach a click-through `NSPanel`) but then failed on-device twice for an unidentified reason, `draggingEntered` never firing even after restoring the exact working technique from the spike.

### What Worked
- **Isolating the highest-uncertainty integration point in its own final phase** (research's own recommendation, followed in the v1.3 roadmap) worked exactly as designed — when Phase 22 failed, the damage stayed contained to Phase 22. Phases 19-21 shipped clean, tested, and independently valuable regardless of how drag-in resolves.
- **Pure-seam-first discipline held again** — the shelf's data model, view-state mirror, and drag-out gate were all unit-tested before any AppKit wiring, consistent with `IslandResolver`/`DeviceCoordinator` precedent.
- **On-device UAT kept finding real integration gaps pure-seam testing can't catch** — Phase 20's CR-01 (invisible click-swallowing band under an empty shelf) and Phase 21's outer-container-height bug were both real product bugs invisible to unit tests, caught only by actually running the app.

### What Was Inefficient
- **A confirmed-working technique (22-01's `draggingUpdated(_:)`) was dropped in 22-03's plan on a disproven assumption** ("AppKit reuses `draggingEntered`'s return value without it") and restoring it later did not fix the regression — meaning the actual root cause was never isolated before the user chose to abandon the phase. Two full on-device UAT cycles were spent without a clear diagnostic signal.
- **No systematic bisection was run against the working 22-01 spike** — the debugging session compared plan assumptions to the spike's code, but never diffed the actual runtime registration/forwarding path step-by-step against the spike to find exactly where delivery broke. A future drag/AppKit-integration debugging session should keep a known-working reference build side-by-side sooner.
- **PROJECT.md's Validated Requirements section silently missed Phase 20** (Shelf View) — Phase 19 and Phase 21 both got entries at their respective phase closes, but Phase 20 never did, only caught during this milestone-close review. Same root-cause class as v1.0/v1.2's REQUIREMENTS.md-sync lesson, just hitting PROJECT.md this time instead.

### Patterns Established
- **A milestone can close "shipped with a known gap"** rather than staying open indefinitely — when a subset of a milestone's requirements ship real, tested, independently-valuable work and the remainder is blocked on a decision needing broader scope (here: an architecture redesign), closing the milestone and carrying the blocked requirement(s) forward as a fresh-milestone requirement is more honest than leaving MILESTONES.md permanently "in progress."
- **A failed phase's historical record is worth preserving, not deleting** — Phase 22's plans, spike findings, and even the debugging worktree (kept off the merge path but on disk) stay valuable input for whatever replaces it.

### Key Lessons
1. When an on-device integration bug resists a plan's stated assumption fix, treat the *previous* known-working state as ground truth and diff against it directly (build config, registration order, exact API surface) rather than reasoning from the plan's assumptions about *why* it should work — 22-03's fix attempt reasoned from a disproven assumption instead of comparing against 22-01's actual working code.
2. Add "update PROJECT.md Validated Requirements" as an explicit phase-close checklist item, not just REQUIREMENTS.md — this is the second milestone in a row (v1.2 had the REQUIREMENTS.md variant) where a phase-close bookkeeping step silently didn't happen and was only caught at the next milestone-close audit.
3. Isolating a genuinely uncertain integration point in its own final phase (this project's second time doing this, after Phase 6/Phase 9's fullscreen work) is a pattern worth keeping — it correctly contained this milestone's one real failure to a single phase instead of destabilizing the whole shelf feature.

### Cost Observations
- Sessions: 2 (2026-07-09 initial build, 2026-07-10→11 Phase 22 debugging + abort + milestone close)
- Notable: 3 of 4 planned phases shipped in roughly one day; the 4th consumed a comparable amount of session time on its own without resolving, which is what triggered the broader architecture-redesign decision rather than a 4th debugging attempt

---

## Milestone: v1.6 — Liquid Glass & System HUD Suite

**Shipped:** 2026-07-19
**Phases:** 8 (35-42; Phase 37 abandoned/reverted) | **Plans:** 43 | **Sessions:** several across 2026-07-15 → 2026-07-19

### What Was Built
- A shader-based "Liquid Glass" background material across the collapsed pill, expanded island, and every activity wing, with a native SwiftUI `.glassEffect()` fast path on macOS 26+ and the custom Metal shader stack as the `<26` fallback (Phase 35, GLASS-01)
- Bluetooth/Charging Droppy-pill restyles, a redesigned equalizer, and a static rainbow-gradient onboarding heading (Phase 36, HUD-01/02/EQ-01/ONBOARD-04)
- Focus Mode HUD via `INFocusStatusCenter` (Phase 38, HUD-05), Volume/Brightness HUD with genuine native-OSD suppression via `.cghidEventTap` (Phase 39, HUD-03/04), a real Sparkle 2 auto-update integration (Phase 40, HUD-06), and a live Calendar Countdown HUD (Phase 41, HUD-08)
- A new dual-activity display concept — `IslandResolver.resolveSecondary()` shows a secondary bubble alongside the main pill when two top-priority activities are live at once (Phase 42, DUAL-01)
- **Not built:** Drop-Session Summary Chip (HUD-07) — Phase 37 was fully implemented, then abandoned and reverted after on-device UAT found its Tray-close trigger essentially never fires in real usage.

### What Worked
- **Isolating the milestone's highest-risk item as its own spike-then-implement phase (Phase 39) worked again** — same pattern as v1.3's Phase 22 isolation, but this time the spike's initial "unreliable" finding was later *reversed* in a gap-closure plan (39-08) rather than the phase being abandoned, showing the pattern also supports iterating past an initial negative spike result when a different technique (`.cghidEventTap` vs `.cgSessionEventTap`) is found.
- **Proving the new-`ActiveTransient`-case pipeline cheaply on Focus Mode (Phase 38) before attempting it under real private-API risk on Volume/Brightness (Phase 39)** paid off — Phase 38 surfaced real pipeline gaps (missing render-tail re-render, wrong shared-default fallback) that Phase 39 then didn't repeat.
- **Abandoning Phase 37 outright rather than redesigning its trigger** was the right call in hindsight — the milestone shipped a cleaner scope (11/12 requirements) instead of carrying a half-working feature or burning another phase's worth of time forcing a fix onto a fundamentally mismatched trigger condition.

### What Was Inefficient
- **The REQUIREMENTS.md/PROJECT.md sync-drift lesson (flagged at v1.0, v1.2, v1.3 close) recurred at v1.6 close, worse than before.** Phases 38, 39, 40, and 41 all skipped their own `update_project_md`/REQUIREMENTS.md-traceability step — HUD-05/HUD-06 sat marked "Pending" despite shipping and passing on-device UAT, and PROJECT.md's Validated section had no entries at all for 4 of the milestone's 8 phases until backfilled during this milestone-close review. This is now a confirmed repeat pattern across 4 milestones, not 3 — the retrospective's own top lesson about this has not stopped it from recurring, meaning a retrospective note alone is not a sufficient fix.
- **The same click-through hot-zone fragility class caused two separate bugs in two different phases** (Phase 40's badge-tap bug, Phase 42's wing-tier-content pass-through) — both traced to `NotchWindowController`'s hot-zone not covering some tier of rendered content. The Phase 40 fix (redesigning to a menu-bar dot) sidestepped the class entirely for that feature, but didn't prevent Phase 42 from independently rediscovering the same underlying gap two phases later.
- **A 16-round on-device layout debugging saga (Phase 39-07)** for the OSD wings traced to `.offset()`/`.position()` unreliably positioning content inside `wingsShape`'s shared `ZStack` — a genuinely reusable lesson (use `HStack`+fixed-width-spacers instead) that had to be rediscovered empirically rather than being already documented as a codebase convention before this phase started.
- **Liquid Glass (Phase 35) needed 4 full on-device UAT rejection/remediation rounds plus a 5th post-completion regression** before landing — each round's root cause (opaque base, wrong-material brightness, unmasked chromatic-fringe washout, then a shader/DEBUG-tint bug) was only found via looking at the actual rendered result on hardware, not via reasoning about the shader math in advance.

### Patterns Established
- **A negative spike finding is not always final** — Phase 39's own gap-closure plan reversed its own initial "OSD suppression unreliable" conclusion by trying a different, more specific technique (`.cghidEventTap` vs `.cgSessionEventTap`), sourced from a proven open-source reference (`dannystewart/volumeHUD`). Worth checking for a more targeted technique before accepting a spike's negative result as permanent.
- **`wingsShape`'s shared content `ZStack` does not support `.offset()`/`.position()` reliably** — any future wing content needing precise placement should default to `HStack(spacing: 0)` with explicit fixed-width `Color.clear` spacers, matching every wing that already works this way (see STATE.md decision log, Phase 39-07).
- **On-device UAT is where interaction design actually gets decided for this project**, not the pre-execution UI-SPEC — both Phase 37's abandonment and Phase 42's D-12/D-13 supersession (tap-to-expand → hover-reveal play/pause) were live on-device redesigns, continuing the pattern v1.2's retrospective already named for Phase 18's toast.

### Key Lessons
1. The REQUIREMENTS.md/PROJECT.md sync-drift issue needs an actual workflow-level fix (e.g., a hard gate in `phase.complete` or `/gsd:verify-work`), not another retrospective note — this is the 4th milestone in a row it has recurred, and it got worse (4 consecutive phases skipped it) rather than better.
2. When a new bug traces to a previously-fixed fragility class (here: click-through hot-zone gaps), treat that as a signal to sweep the whole codebase for other instances of the same class, not just patch the one instance found — Phase 42 rediscovering Phase 40's bug class independently suggests other undiscovered instances may still exist.
3. Document empirically-discovered SwiftUI layout gotchas (like the `wingsShape`/`.offset()` failure) as an explicit codebase convention note immediately after the debugging session that found them, not just in a phase's own STATE.md decision-log entry — the next phase needing similar placement shouldn't have to rediscover it.
4. A spike's negative finding is worth one targeted re-attempt with a more specific technique (not just abandoning the feature) before accepting it as final — Phase 39's OSD suppression reversal shipped a materially better feature than the originally-accepted fallback.

### Cost Observations
- Sessions: several across 2026-07-15 → 2026-07-19 (5 days wall-clock)
- Notable: Phase 35 (Liquid Glass) and Phase 39 (Volume/Brightness) together absorbed the large majority of on-device iteration rounds in this milestone (4+1 UAT rounds and 16 layout-debugging rounds respectively) — both were the milestone's two explicitly-flagged highest-risk items, so the iteration cost landed where research predicted it would

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | several | 7 (0-6) | First milestone — established pure-seam-first TDD discipline and isolated-service pattern for risky private APIs |
| v1.0.1 | — (retrospective not captured at close) | 3 (7-9) | Progress bar + fullscreen-flash root-cause fix via dedicated CGS Space |
| v1.1 | — (retrospective not captured at close) | 4 (10-13) | Trial/lockout, Polar.sh licensing, real notarization |
| v1.2 | 1 | 2 (17-18) | Smallest milestone to date; on-device iteration used as the actual design process for Phase 18 |
| v1.3 | 2 | 3 shipped of 4 planned (19-21; Phase 22 blocked/aborted) | First milestone to close "shipped with a known gap" — blocked drag-in requirement carried forward instead of the milestone staying open indefinitely |
| v1.6 | several | 8 shipped of 8 planned (35-42; Phase 37 abandoned/reverted) | First milestone where a spike's own negative finding was later reversed by a gap-closure plan (Phase 39 OSD suppression); REQUIREMENTS.md/PROJECT.md sync-drift recurred across 4 consecutive phases (38-41), worst instance of that pattern yet |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|---------------------|
| v1.0 | 131 (XCTest) | Not measured (no coverage tool configured) | mediaremote-adapter (SPM) |
| v1.0.1 | 141 (XCTest) | Not measured | none |
| v1.1 | 185 (XCTest) | Not measured | none |
| v1.2 | 185+ (4 new `IslandResolverTests` + toast seam tests; exact count not re-tallied) | Not measured | none |
| v1.3 | 261 (XCTest) | Not measured | none |
| v1.6 | Not re-tallied this close (16,212 total Swift LOC at close) | Not measured | Sparkle 2 (SPM) |

### Top Lessons (Verified Across Milestones)

1. Planning-artifact bookkeeping (ROADMAP.md checkboxes, REQUIREMENTS.md checkboxes, PROJECT.md Validated Requirements, debug-session/UAT status fields) drifts silently unless actively audited — `gsd-sdk query audit-open` catches some of this, but not PROJECT.md drift, so a milestone-close read-through is still needed. **Recurred at v1.2 close** (NOW-04 sat unchecked after Phase 17), **again at v1.3 close** (Phase 20's Validated Requirements entry was never added), **and again, worse, at v1.6 close** (4 consecutive phases — 38, 39, 40, 41 — all skipped it). A confirmed repeat pattern across 4 milestones now, trending worse, not better — a workflow-level gate is needed, not another retrospective note (see v1.6 Key Lesson 1).
2. The retrospective-append step itself gets skipped under time pressure (v1.0.1 and v1.1 both shipped without a retrospective section, only backfilled retroactively at v1.2 close) — treat it as a required milestone-close step, not optional polish.
3. When an on-device integration bug resists a plan's stated-assumption fix, diff against the last known-working reference implementation directly rather than reasoning further from the (possibly wrong) assumption — v1.3's Phase 22 spent two full UAT cycles reasoning from a disproven assumption before the user chose to abandon it for a broader architecture redesign.
4. A negative spike finding deserves one targeted re-attempt with a more specific technique before being accepted as permanent — v1.3's Phase 22 (drag-in) never got this re-attempt and was abandoned, but v1.6's Phase 39 (OSD suppression) did and shipped a materially better feature as a result. The difference: Phase 39 had a concrete alternative technique to try (`.cghidEventTap`, sourced from a proven reference); Phase 22 didn't have an equivalent lead. Worth actively looking for one before abandoning a blocked integration point.
5. The same fragility class can cause independent bugs in separate phases if the underlying gap isn't swept codebase-wide after the first fix — v1.6's click-through hot-zone bug hit Phase 40 (badge) and Phase 42 (wing-tier bubble) separately, months apart in phase-numbering terms but both within the same milestone.
