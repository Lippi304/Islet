---
gsd_state_version: 1.0
milestone: v1.4
milestone_name: Architecture Redesign
status: milestone_complete
stopped_at: Milestone complete (Phase 28 was final phase)
last_updated: 2026-07-13T14:14:11.786Z
last_activity: 2026-07-12 -- Phase 28 execution started
progress:
  total_phases: 13
  completed_phases: 8
  total_plans: 28
  completed_plans: 27
  percent: 62
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-09)

**Core value:** The notch becomes a beautiful, reliable island that shows now-playing media and reacts when you plug in the charger or connect a device — native, smooth, and as polished as the iPhone Dynamic Island.
**Current focus:** Milestone complete

## Current Position

Phase: 28
Plan: Not started
Status: Milestone complete
Last activity: 2026-07-13

### Phase 5 status note (resolved at v1.0 milestone close)

Phase 5 (device-connected-activity) was formally marked **superseded by Phase 6** in
ROADMAP.md at v1.0 milestone close (2026-07-02, user decision). Its scope — device
connect/disconnect activity, `DeviceActivityState`, `BluetoothMonitor`, device wings —
shipped inside Phase 6 (06-02/06-04); DEV-01/DEV-02 are code-complete and verified (see
`06-VERIFICATION.md`, `REQUIREMENTS.md`). Phase 5's own 3 plans were never executed. The
on-device Bluetooth permission spike from 05-01 Task 3 was superseded by the actual A1
finding in 06-04 (NSBluetoothAlwaysUsageDescription IS required on macOS 26 — see project
memory `a1-bluetooth-usage-key-required`), so no further action is needed there either.

Progress (v1.3): [██████████] 100% (Phases 19-21 shipped; Phase 22 blocked, superseded by v1.4 Phases 23-24)

Progress (v1.4): [██████░░░░] 67% (4/6 phases — Phases 23-26 complete; Phase 27 next)

## Performance Metrics

**Velocity:**

- Total plans completed: 71
- Average duration: — min
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 00 | 4 | - | - |
| 01 | 3 | - | - |
| 02 | 4 | - | - |
| 03 | 3 | - | - |
| 04 | 4 | - | - |
| 06 | 13 | - | - |
| 07 | 1 | - | - |
| 08 | 2 | - | - |
| 09 | 5 | - | - |
| 11 | 2 | - | - |
| 12 | 4 | - | - |
| 13 | 1 | - | - |
| 15 | 5 | - | - |
| 16 | 2 | - | - |
| 18 | 2 | - | - |
| 19 | 1 | - | - |
| 20 | 3 | - | - |
| 21 | 1 | - | - |
| 23 | 4 | - | - |
| 25 | 1 | - | - |
| 24 | 3 | - | - |
| 27 | 4 | - | - |
| 28 | 4 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 25 P01 | 9min | 3 tasks | 2 files |
| Phase 26 P04 | 25h (7 UAT rounds) | 2 tasks | 8 files |

## Accumulated Context

### Decisions

Full decision log is in PROJECT.md Key Decisions table (v1.1 decisions archived there and in `.planning/milestones/v1.1-ROADMAP.md`).

- [Phase 14] Verification (14-05) found and fixed two Hardened-Runtime entitlement gaps (Calendar, Location) plus a WeatherKit Portal App Services capability miss - all three needed before on-device permission prompts/weather fetch would work at all
- [v1.2 roadmap] Phase 18 (song-change toast) sequenced after Phase 17 (launch gating) — both track "is this the first real playback transition after launch" state, so gating ships and settles first before the toast is layered on top
- [v1.3 roadmap] Phase order 19→20→21→22 (model → view → drag-out → drag-in) follows research's codebase-grounded build order: pure-seam-first is this project's own established convention (`IslandResolver`, `DeviceCoordinator`), and the one genuinely uncertain integration point — drag delivery through the click-through `NSPanel` — is isolated in its own last phase (22) so a spike/iteration there doesn't block the rest of the feature
- [v1.4 roadmap] Phase 23 (Shell Parity Rewrite) must complete and be fully on-device UAT'd before Phase 24 (Drag-In) starts — hard dependency, per research's explicit warning that re-attempting drag-in before the shell is reproven repeats Phase 22's exact failure mode. Phases 25-28 (Theming, Onboarding, Settings Sidebar, Calendar) have no dependency on the shell work and may be resequenced for throughput.
- [Phase 25]: [Phase 25] Gradient stops (0/0.65/1.0) and 32pt corner radius, plus spring constants (response 0.6, damping 0.62), confirmed correct on first on-device UAT pass — no iteration or NotchShape.swift animatableData contingency needed
- [Phase 26]: Onboarding carousel visuals iterated across 5 on-device UAT rounds vs. a Droppy reference (centered text, 400->420 wide/300->320 tall panel, pill permission rows, circular nav, static glow); 26-UI-SPEC.md updated each round to stay truthful
- [Phase 26]: macOS deployment target bumped 14.0 -> 15.0 (user-approved) to fix a Settings-window auto-restore-at-launch bug via .defaultLaunchBehavior(.suppressed), which has no availability-guard path in SwiftUI's SceneBuilder

### Roadmap Evolution

- v1.1 (Trial & Paid Release) shipped 2026-07-08 — archived to `.planning/milestones/v1.1-ROADMAP.md`.
- Phase 14 (weather/calendar/date) executed ahead of formal milestone scope — stays on the live ROADMAP.md pending next-milestone requirement capture.
- Phase 15 rescoped to "Mechanical Fixes & DI Seams" (7 low-risk audit findings; context captured in `15-CONTEXT.md`, ready for `/gsd:plan-phase 15`) after discussion split the original scope in two.
- Phase 16 added: NotchWindowController DeviceCoordinator Extraction — the higher-risk coordinator-split work, isolated from Phase 15 per user decision. Completed 2026-07-08.
- v1.2 (Now Playing Polish) roadmap created 2026-07-09: Phase 17 (NOW-04, launch gating) and Phase 18 (NOW-05/NOW-06, song-change toast + its Settings toggle), 100% requirement coverage. Phase numbering continues from Phase 16.
- v1.3 (Notch Shelf) roadmap created 2026-07-09: Phase 19 (Shelf Data Model, SHELF-08), Phase 20 (Shelf View, SHELF-03/04/05/07/09), Phase 21 (Drag-Out, SHELF-06), Phase 22 (Drag-In, SHELF-01/02) — 100% coverage (9/9). Phase numbering continues from Phase 18. Sequenced per research's build-order recommendation with the click-through drag-in risk isolated in the final phase.
- v1.4 (Architecture Redesign) roadmap created 2026-07-11: Phase 23 (Shell Parity Rewrite, ARCH-01), Phase 24 (Drag-In, SHELF-01/02), Phase 25 (Visual/Material Theming Redesign, VISUAL-01/02), Phase 26 (Onboarding Flow, ONBOARD-01/02/03), Phase 27 (Settings Sidebar Redesign, SETTINGS-01), Phase 28 (Calendar Full View, CALVIEW-01/02/03/04) — 100% coverage (13/13). Phase numbering continues from Phase 22 (which is superseded, not resumed). Sequenced per research's recommendation: shell rewrite first (hard prerequisite for drag-in only), remaining four phases independent and free to reorder.
- Phase 25 edited: rescoped from generic frosted/glossy+slower-spring to a specific black-to-transparent vertical gradient material, fluid/bouncy Dynamic-Island-style animation, and a new Theming settings section (VISUAL-03 added); explicitly scoped to shared shell chrome only, not individual activity content views

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

None yet.

### Blockers/Concerns

[Issues that affect future work]

- [Carried, pre-existing] Phase 2's 8 on-device UAT scenarios (`02-HUMAN-UAT.md`) remain unexercised since v1.0 close — unrelated to v1.1/v1.2/v1.3/v1.4 scope, still open. Revisit via `/gsd:verify-work 2` if desired.
- [v1.3→v1.4, Phase 22, ABORTED 2026-07-10, superseded] `NotchPanel.draggingEntered` never fired on-device twice despite a confirmed-working spike using the same technique; root cause never identified. Resolution is architectural, not incremental: Phase 23 rebuilds the shell (dropping `NSDraggingDestination` entirely), Phase 24 retries drag-in via a global-monitor `DragApproachDetector` pattern instead. Research flags this pattern as itself unproven in this codebase and recommends its own isolated on-device validation rounds during Phase 24 planning/execution, not an assumption it "just works." Work preserved, not merged: worktree `/Users/lippi304/conductor/repos/notch/.claude/worktrees/agent-a9e6341bfc04601a5` (branch `worktree-agent-a9e6341bfc04601a5`) still holds the 22-03 debugging commits, kept as reference per explicit user request. 22-02's pure seams (`DragDropSupport.swift`, `.dragEntered` state) ARE merged and reusable by Phase 24.
- [v1.4, from research] Open product decisions flagged for discuss-phase, not yet locked: (1) Phase 26 onboarding — permissions pre-explanation screen must stay educational-only with real permission requests kept lazy-at-first-use, to avoid racing/duplicating the existing `AppDelegate.isFirstLaunch` hook; (2) Phase 28 calendar — whether the existing Calendar authorization is already full (not read-only) access, and whether quick-add targets Calendar events vs. Reminders (determines if a new `NSRemindersFullAccessUsageDescription` Info.plist key is needed), must be verified against actual Phase 14 code before implementation.
- [v1.3, from research] Open product decision, flagged for `/gsd:discuss-phase 20`: should the shelf render/suppress during collapsed "wings" transients (Charging/Device/Now-Playing-wings) mid-display, beyond the already-locked SHELF-09 (suppressed only during Charging/Device splashes)?
- [Phase 24, RESOLVED 2026-07-11] Plan 24-02's Task 3 on-device UAT found that because the panel is deliberately click-through/non-`NSDraggingDestination` (D-05's pivot away from Phase 22's twice-unexplained `draggingEntered` failure), a real drop's OS-level drag session was never intercepted — it fell through to the Finder Desktop underneath, which on a same-volume drag performed its own default MOVE, relocating the original file even though the shelf also correctly received its own session copy. `/gsd:discuss-phase 24` scoped a `CGEventTap`-based fix (D-10 through D-15), and Plan 24-03 implemented and on-device-validated it: swallowing/redirecting the terminating `.leftMouseUp` via a new `DropInterceptTap` (`Islet/Notch/DropInterceptTap.swift`) prevents the relocation. One round-1 finding during Task 4 UAT — fully swallowing the event stranded the drag ghost image on the cursor (the WindowServer's own drag-session bookkeeping never saw a release signal) — was fixed by redirecting the event to an off-screen coordinate (`CGEventSetLocation`) instead of discarding it outright, letting the WindowServer end the drag cleanly while still denying Finder a valid drop target. Plan 24-03's Task 4 checkpoint (including a Release-configuration pass) is approved; this resolves/supersedes Plan 24-02's Task 3. SHELF-01/SHELF-02 are both complete.

### Quick Tasks Completed

| # | Description | Date | Commit | Status | Directory |
|---|-------------|------|--------|--------|-----------|
| 260705-l4i | Idle-notch merge: data-drive collapsed pill size from measured notch (D-01) | 2026-07-05 | 52ee074 | Complete ✓ (on-device verified in Release) | [260705-l4i-idle-notch-soll-unsichtbar-mit-der-hardw](./quick/260705-l4i-idle-notch-soll-unsichtbar-mit-der-hardw/) |
| 260705-mzj | Release-build launch crash fix: disable-library-validation entitlement for embedded MediaRemoteAdapter framework | 2026-07-05 | 8e06a1b | Complete ✓ (Release launches, on-device verified) | [260705-mzj-release-build-crash-fix-disable-library-](./quick/260705-mzj-release-build-crash-fix-disable-library-/) |
| 260706-app-icon | App-Icon aus `brand/islet/` in den Xcode Asset-Catalog eingebaut (10 PNGs + Contents.json); Debug-Build packt AppIcon (Assets.car + AppIcon.icns, CFBundleIconName=AppIcon) | 2026-07-06 | d556f11 | Complete ✓ (Debug build verified icon embedded) | [260706-app-icon](./quick/260706-app-icon/) |
| 260708-nnu | Wetter-Icon symbolEffect-Animation verlangsamt (0.4x Speed) nach User-Feedback, dass Puls/Farbwechsel zu schnell/stark war | 2026-07-08 | e8f195c | Complete ✓ (Debug build verified) | [260708-nnu-das-wetter-icon-wolken-symbol-im-notch-b](./quick/260708-nnu-das-wetter-icon-wolken-symbol-im-notch-b/) |
| 260708-nzj | Wetter-Icon symbolEffect-Animation komplett entfernt (statisch) — supersedes 260708-nnu | 2026-07-08 | fd12326 | Complete ✓ (Debug build verified) | [260708-nzj-wetter-icon-animation-symboleffect-pulse](./quick/260708-nzj-wetter-icon-animation-symboleffect-pulse/) |
| 260708-ol8 | Bump MARKETING_VERSION 0.1 → 1.0 for public launch (D-14) | 2026-07-08 | 57f601a | Complete ✓ | [260708-ol8-bump-marketing-version-in-project-yml-fr](./quick/260708-ol8-bump-marketing-version-in-project-yml-fr/) |
| 260708-u47 | Settings: "Save Diagnostic Report…" button — snapshots version/OS/hardware/license summary/toggles/Now-Playing health to a user-saved .txt (no raw license key) | 2026-07-08 | a7a4243 | Complete ✓ (on-device save + Cmd-U `DiagnosticReportTests` both verified by user) | [260708-u47-settings-button-hinzuf-gen-um-einen-fehl](./quick/260708-u47-settings-button-hinzuf-gen-um-einen-fehl/) |
| 260709-glz | Fullscreen-hide gating (`hideInFullscreen`) turned from a hardcoded constant into a persisted, live-editable Settings toggle ("Hide notch in fullscreen"); default true preserves existing behavior | 2026-07-09 | d1f6b5e | Complete ✓ (Debug build verified — manual on-device toggle check recommended) | [260709-glz-fullscreen-sichtbarkeit-der-notch-als-ei](./quick/260709-glz-fullscreen-sichtbarkeit-der-notch-als-ei/) |
| 260709-gvy | SettingsView restructured from a single Form into a 3-tab TabView (General/Appearance/Activities) — pure view-hierarchy reorg, no `@AppStorage` keys or behavior changed; Accent picker moved from Activities into Appearance | 2026-07-09 | 9972811 | Complete ✓ (Debug build verified — manual on-device tab check recommended) | [260709-gvy-settingsview-tabview-umbau-general-appea](./quick/260709-gvy-settingsview-tabview-umbau-general-appea/) |

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| uat_gaps | Phase 02: 02-HUMAN-UAT.md | partial (8 pending on-device scenarios) | v1.0 close |
| verification_gaps | Phase 02: 02-VERIFICATION.md | human_needed | v1.0 close |
| code_review | WR-01..04: wing accent-tint, view rehost, animation wrapper, BluetoothMonitor race (Phase 6) | non-blocking | v1.0 close |

Pre-existing debt from Phase 2 (Hover, Expand & Fullscreen Hardening) and Phase 6/9 code review, carried forward again at v1.1 close. Not blocking — revisit via `/gsd-quick` or `/gsd:verify-work` as desired.

**v1.2 close (2026-07-09):** `gsd-sdk query audit-open` flagged 8 quick-tasks (260705-l4i, 260705-mzj, 260708-nnu, 260708-nzj, 260708-ol8, 260708-u47, 260709-glz, 260709-gvy) as status `missing`. All 8 have completed PLAN.md + SUMMARY.md on disk and are already logged "Complete ✓" in the Quick Tasks Completed table above — acknowledged as a tool status-detection false positive, not real open work, and unrelated to v1.2's phases (17-18). No action needed.

**v1.3 close (2026-07-11):** `gsd-sdk query audit-open` flagged 10 items, all acknowledged and deferred:

| Category | Item | Status |
|----------|------|--------|
| quick_task | 260705-l4i-idle-notch-soll-unsichtbar-mit-der-hardw | missing (same false positive as v1.2 close) |
| quick_task | 260705-mzj-release-build-crash-fix-disable-library- | missing (same false positive as v1.2 close) |
| quick_task | 260708-nnu-das-wetter-icon-wolken-symbol-im-notch-b | missing (same false positive as v1.2 close) |
| quick_task | 260708-nzj-wetter-icon-animation-symboleffect-pulse | missing (same false positive as v1.2 close) |
| quick_task | 260708-ol8-bump-marketing-version-in-project-yml-fr | missing (same false positive as v1.2 close) |
| quick_task | 260708-u47-settings-button-hinzuf-gen-um-einen-fehl | missing (same false positive as v1.2 close) |
| quick_task | 260709-glz-fullscreen-sichtbarkeit-der-notch-als-ei | missing (same false positive as v1.2 close) |
| quick_task | 260709-gvy-settingsview-tabview-umbau-general-appea | missing (same false positive as v1.2 close) |
| uat_gaps | Phase 21: 21-HUMAN-UAT.md | resolved, 0 pending scenarios — not real open work |
| verification_gaps | Phase 20: 20-VERIFICATION.md | human_needed — pre-existing, unrelated to v1.3 scope; the 4 on-device/Cmd-U checks remain in Operator Next Steps below |

Additionally, v1.3's own scope closed with a known gap: **SHELF-01/02 (drag-in, Phase 22) remained unshipped** — Phase 22 was blocked twice on-device (AppKit drag delivery never reached `NotchPanel`, root cause unidentified) and the user chose to abandon the incremental fix in favor of a broader NotchPanel/NotchWindowController architecture redesign. SHELF-01/02 now formally re-scoped into v1.4 Phase 24, gated behind Phase 23's shell rewrite.

## Session Continuity

Last session: 2026-07-12T22:51:19.126Z
Stopped at: Phase 28 UI-SPEC approved
Resume file: .planning/phases/28-calendar-full-view/28-UI-SPEC.md

## Operator Next Steps

- Run `/gsd-verify-work 25` to confirm Phase 25's goals (VISUAL-01/02) were really achieved, not just tasks checked off.
- Phase 24 is complete (SHELF-01/SHELF-02 done, drop-interception gap resolved via `DropInterceptTap`). Next up: `/gsd:discuss-phase 26` (Onboarding Flow).
