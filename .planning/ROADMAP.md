# Roadmap: Notch — Dynamic Island for Mac

## Milestones

- ✅ **v1.0 MVP** — Phases 0-6 (shipped 2026-07-02)
- 🚧 **v1.0.1 Pre-Release Polish** — Phases 7-9 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 0-6) — SHIPPED 2026-07-02</summary>

- [x] Phase 0: Foundations & Notarization Dry Run (4/4 plans) — completed 2026-06-26
- [x] Phase 1: The Empty Island (Window + Geometry) (3/3 plans) — completed 2026-06-26
- [x] Phase 2: Hover, Expand & Fullscreen Hardening (4/4 plans) — completed 2026-06-27
- [x] Phase 3: Charging Activity (3/3 plans) — completed 2026-06-27
- [x] Phase 4: Now Playing (4/4 plans) — completed 2026-06-28
- [x] Phase 5: Device-Connected Activity (superseded by Phase 6 — scope folded into 06-02/06-04) — 2026-07-01
- [x] Phase 6: Priority Resolver, Settings & v1 Ship (13/13 plans) — completed 2026-07-01

Full phase details, goals, success criteria, and plan lists: `.planning/milestones/v1.0-ROADMAP.md`

</details>

### 🚧 v1.0.1 Pre-Release Polish (In Progress)

**Milestone Goal:** Close the two remaining polish gaps before Islet's first real release — a Now Playing progress bar and eliminating the fullscreen-enter flash.

- [x] **Phase 7: Now Playing Progress Bar** - Display-only elapsed/remaining playback progress bar in the expanded Now Playing view (completed 2026-07-03)
- [x] **Phase 8: Fullscreen-Enter Flash Elimination** - Root-cause investigation completed; new CGS event 106/107 candidate disproven on-device (option-c). Escalated per D-03/D-04; user selected a follow-up investigation of `SLSManagedDisplayIsAnimating` (see `08-ESCALATION.md`). FS-01 remains open, tracked for a new phase (completed 2026-07-04)
- [ ] **Phase 9: Fullscreen-Enter Flash — Window/Space Architecture Retry** - Retry FS-01 with a window/Space architecture change (Candidate C, max-level CGS Space) found via research of comparable open-source projects, `SLSManagedDisplayIsAnimating` polling (Candidate B) as fallback

### 📋 v1.1 (Planned)

Scope not yet defined — run `/gsd:new-milestone` to start requirements definition. Candidate carry-overs from v1.0's Active/Out-of-Scope backlog:

- [ ] File shelf: drag-and-drop tray at the notch to temporarily hold files, then drag them back out / share / AirDrop
- [ ] System HUDs: replace the default volume / brightness / battery overlays with notch-based HUDs
- [ ] Timer: start and watch a countdown timer as a live activity in the island
- [ ] Real Developer-ID notarization (pending Apple Developer account purchase, $99/yr)
- [ ] Phase 2's 8 remaining on-device UAT scenarios (`02-HUMAN-UAT.md`)
- [ ] Code-review polish items from `06-REVIEW.md` (WR-01..04: wing accent-tint consistency, accent-change view rehost, missing animation wrapper, BluetoothMonitor race)

## Phase Details

### Phase 7: Now Playing Progress Bar
**Goal**: Users can see exactly where playback is within the current track, at a glance, from the expanded island — display-only, no interaction.
**Depends on**: Phase 4 (Now Playing, v1.0)
**Requirements**: PBAR-01
**Success Criteria** (what must be TRUE):
  1. The expanded Now Playing view shows a horizontal progress bar reflecting the current track's playback position relative to its total duration.
  2. Elapsed and remaining/total time labels are visible next to the bar (e.g. "1:23 / 3:45").
  3. The bar and labels update smoothly while a track is playing, and hold perfectly still (no drift) while paused.
  4. The bar is strictly display-only — clicking or dragging it does not seek or change playback in any way.
**Plans**: 1 plan
Plans:
- [x] 07-01-PLAN.md — Extend pure seam + monitor + state to carry playback position; render ProgressBar in expanded Now Playing view; on-device UAT
**UI hint**: yes

### Phase 8: Fullscreen-Enter Flash Elimination
**Goal**: Entering true (native) fullscreen on the built-in display never produces a visible island flash, closing out the polish debt v1.0 shipped with.
**Depends on**: Phase 2 (Hover, Expand & Fullscreen Hardening, v1.0)
**Requirements**: FS-01
**Success Criteria** (what must be TRUE):
  1. On-device, entering native fullscreen (tested across multiple trigger methods — green-button, menu bar, video apps, at minimum) shows zero visible island flash during or after the transition, across repeated trials.
  2. The fix is a genuine root-cause elimination using a detection/timing signal distinct from v1.0's reactive `orderOut` approach (which was already confirmed insufficient) — not a best-effort reduction.
  3. Existing fullscreen behavior is not regressed: the island still hides for the duration of fullscreen and still restores correctly on exit.
**Plans**: 3 plans (Wave 0 on-device probe gates two mutually exclusive Wave 1 plans — fix path or escalation path)
Plans:
- [x] 08-01-PLAN.md — Wave 0: build DEBUG-only CGS event 106/107 timing probe, run on-device D-05 trigger matrix, record option-a/option-b/option-c decision
- [ ] 08-02-PLAN.md — Wave 1 (fix path, only if 08-01 = option-a/option-b): wire the permanent proactive fullscreen-transition signal into updateVisibility(), extend tests, on-device UAT
- [x] 08-03-PLAN.md — Wave 1 (escalation path, only if 08-01 = option-c): revert exploratory code, write root-cause escalation report, surface scope decision to user

**Investigation note:** FS-01 is scoped as a full elimination outcome (see REQUIREMENTS.md Out of Scope — partial mitigation is explicitly excluded). If on-device investigation during planning/execution finds the flash is genuinely not fixable at the application layer (window-server compositor timing, as v1.0's root-cause diagnosis suggested), the phase's terminal state is a documented escalation with root-cause evidence, surfaced to the user for an explicit scope decision — not a silent "good enough" ship.

### Phase 9: Fullscreen-Enter Flash — Window/Space Architecture Retry
**Goal**: Entering true (native) fullscreen on the built-in display never produces a visible island flash, closing out FS-01 (escalated, unresolved, from Phase 8).
**Depends on**: Phase 8 (Fullscreen-Enter Flash Elimination — see `08-ESCALATION.md` for prior findings)
**Requirements**: FS-01
**Success Criteria** (what must be TRUE):
  1. On-device, entering native fullscreen (green-button, menu bar, video app, at minimum) shows zero visible island flash during or after the transition, across repeated trials.
  2. The fix is a genuine root-cause elimination, not a best-effort/partial reduction.
  3. Existing fullscreen behavior is not regressed: the island still hides for the duration of fullscreen and still restores correctly on exit.
**Plans**: 0 plans (not yet planned)

**Candidates to investigate (found via research of comparable open-source Dynamic-Island clones, GitHub):**
- **Candidate C (prioritized)** — Window/Space architecture change: replace the panel's `.canJoinAllSpaces` NSWindow collection behavior with a dedicated private CGS Space created at the maximum absolute level (`CGSSpaceCreate` + `CGSSpaceSetAbsoluteLevel(level: Int32.max)`, membership managed via `CGSAddWindowsToSpaces`/`CGSRemoveWindowsFromSpaces`) — mirrors the technique found in `Ebullioscopic/Atoll`'s `NotchSpaceManager`/`CGSSpace.swift` (fork lineage of `TheBoredTeam/boring.notch`). Targets Phase 2's original root-cause diagnosis structurally: `.canJoinAllSpaces` auto-joins the panel onto every newly-created Space (including a just-activated fullscreen Space), compositing it there for ~1 frame before reactive hide code can run. A dedicated max-level Space has no per-Space auto-join event to race against. Needs on-device verification that it (a) actually eliminates the flash, (b) doesn't regress hide-during-fullscreen/restore-on-exit, (c) doesn't cause the panel to visibly show above fullscreen content when it should stay hidden.
- **Candidate B (fallback)** — `SLSManagedDisplayIsAnimating` poll + fullscreen-vs-ordinary-Space-switch disambiguator (full design in `08-ESCALATION.md`'s "Untried Fallback" section). Requires a new `project.yml` `SkyLight.framework` linker setting and a `CVDisplayLink`-driven poll.

Plans:
- [ ] TBD (run `/gsd-plan-phase 9` to break down)

## Progress

**v1.0:** 7/7 phases complete (100%) — see `.planning/milestones/v1.0-ROADMAP.md` for the full per-phase breakdown.

**v1.0.1:**

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 7. Now Playing Progress Bar | 1/1 | Complete   | 2026-07-03 |
| 8. Fullscreen-Enter Flash Elimination | 2/3 | Escalated (08-02 correctly skipped) | 2026-07-04 |
| 9. Fullscreen-Enter Flash — Window/Space Architecture Retry | 0/0 | Not planned | - |
