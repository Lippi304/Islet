---
gsd_state_version: 1.0
milestone: v1.5
milestone_name: Home Focus & Widget Redesign
status: executing
stopped_at: Phase 33 UI-SPEC approved
last_updated: "2026-07-14T23:41:20.462Z"
last_activity: 2026-07-14 -- Phase 33 planning complete
progress:
  total_phases: 19
  completed_phases: 13
  total_plans: 37
  completed_plans: 34
  percent: 68
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-13)

**Core value:** The notch becomes a beautiful, reliable island that shows now-playing media and reacts when you plug in the charger or connect a device — native, smooth, and as polished as the iPhone Dynamic Island.
**Current focus:** Phase 32 — tray-widening

## Current Position

Phase: 32 (tray-widening) — EXECUTING
Plan: 1 of 1
Status: Ready to execute
Last activity: 2026-07-14 -- Phase 33 planning complete
Next: Phase 31 — Shelf Consolidation to Tray-Only

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

Progress (v1.4): [██████████] 100% (6/6 phases — Phases 23-28 complete; pending final on-device UAT re-confirmation of 2 code-review fixes before formal close)

Progress (v1.5): [██░░░░░░░░] 17% (1/6 phases — Phase 29 complete, Phase 30 next)

## Performance Metrics

**Velocity:**

- Total plans completed: 72
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
| 31 | 1 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 25 P01 | 9min | 3 tasks | 2 files |
| Phase 26 P04 | 25h (7 UAT rounds) | 2 tasks | 8 files |
| Phase 31 P01 | 25min | 3 tasks | 5 files |

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
- [v1.5 roadmap] Phase order 29→30→31→32→33→34 (Flare → Home → Shelf Consolidation → Tray Widening → Weather → Quick Action Picker) follows research's dependency-grounded recommendation: independence first (Flare), then lowest-new-architecture-risk (Home), then a hard-dependency pair (Shelf Consolidation must land before Tray Widening to avoid touching `visibleContentZone()` twice), then fully-independent Weather, then the one feature requiring genuinely new AppKit territory (Quick Action picker) isolated last — mirrors the project's own Phase 22→24 drag-in risk-isolation precedent
- [Phase 29]: SHAPE-01 shipped as a plain topCornerRadius increase (24pt blob / 12pt wings) at 2 call sites, not the topFlareWidth geometry the plan specified — 3 alternate geometry designs (concave sweep, shoulder bulge, centered notch dip) were built and abandoned across ~17 on-device UAT rounds before the simple radius bump matched the user's reference
- [Phase 30]: Decision coverage gate override: D-01/D-02/D-03/D-06/D-07 not explicitly cited in plan must_haves/truths, but plan-checker semantic review confirmed all 5 are implemented (D-02/D-03 are Plan 01's core resolver branch logic; D-01/D-06 verified as pre-existing behavior; D-06/D-07 referenced in plan body text). User chose Proceed anyway.
- [Phase 31]: [Phase 31] shelfStripVisible access bumped private->internal (testability only) mirroring EqualizerBars.makeProfiles() precedent; regression-locked via NotchPillViewTests; on-device CR-01 click-through trace approved with zero regressions, no contingency fix needed

### Roadmap Evolution

- v1.1 (Trial & Paid Release) shipped 2026-07-08 — archived to `.planning/milestones/v1.1-ROADMAP.md`.
- Phase 14 (weather/calendar/date) executed ahead of formal milestone scope — stays on the live ROADMAP.md pending next-milestone requirement capture.
- Phase 15 rescoped to "Mechanical Fixes & DI Seams" (7 low-risk audit findings; context captured in `15-CONTEXT.md`, ready for `/gsd:plan-phase 15`) after discussion split the original scope in two.
- Phase 16 added: NotchWindowController DeviceCoordinator Extraction — the higher-risk coordinator-split work, isolated from Phase 15 per user decision. Completed 2026-07-08.
- v1.2 (Now Playing Polish) roadmap created 2026-07-09: Phase 17 (NOW-04, launch gating) and Phase 18 (NOW-05/NOW-06, song-change toast + its Settings toggle), 100% requirement coverage. Phase numbering continues from Phase 16.
- v1.3 (Notch Shelf) roadmap created 2026-07-09: Phase 19 (Shelf Data Model, SHELF-08), Phase 20 (Shelf View, SHELF-03/04/05/07/09), Phase 21 (Drag-Out, SHELF-06), Phase 22 (Drag-In, SHELF-01/02) — 100% coverage (9/9). Phase numbering continues from Phase 18. Sequenced per research's build-order recommendation with the click-through drag-in risk isolated in the final phase.
- v1.4 (Architecture Redesign) roadmap created 2026-07-11: Phase 23 (Shell Parity Rewrite, ARCH-01), Phase 24 (Drag-In, SHELF-01/02), Phase 25 (Visual/Material Theming Redesign, VISUAL-01/02), Phase 26 (Onboarding Flow, ONBOARD-01/02/03), Phase 27 (Settings Sidebar Redesign, SETTINGS-01), Phase 28 (Calendar Full View, CALVIEW-01/02/03/04) — 100% coverage (13/13). Phase numbering continues from Phase 22 (which is superseded, not resumed). Sequenced per research's recommendation: shell rewrite first (hard prerequisite for drag-in only), remaining four phases independent and free to reorder.
- Phase 25 edited: rescoped from generic frosted/glossy+slower-spring to a specific black-to-transparent vertical gradient material, fluid/bouncy Dynamic-Island-style animation, and a new Theming settings section (VISUAL-03 added); explicitly scoped to shared shell chrome only, not individual activity content views
- v1.5 (Home Focus & Widget Redesign) roadmap created 2026-07-13: Phase 29 (NotchShape Flare, SHAPE-01), Phase 30 (Home Music-Only, HOME-01/02/03), Phase 31 (Shelf Consolidation to Tray-Only, TRAY-01), Phase 32 (Tray Widening, TRAY-05), Phase 33 (Weather Widget Redesign, WEATHER-01/02), Phase 34 (Quick Action Destination Picker, TRAY-02/03/04) — 100% coverage (11/11). Phase numbering continues from Phase 28. REQUIREMENTS.md's initial "10 total" count corrected to 11 (the actual v1.5 requirement ID list has 11 entries).

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

- [ui] Tray panel oversized vertically, shrink to fit content — `.planning/todos/pending/2026-07-14-tray-panel-oversized-vertically-shrink-to-fit-content.md`

### Blockers/Concerns

[Issues that affect future work]

- [Carried, pre-existing] Phase 2's 8 on-device UAT scenarios (`02-HUMAN-UAT.md`) remain unexercised since v1.0 close — unrelated to v1.1/v1.2/v1.3/v1.4/v1.5 scope, still open. Revisit via `/gsd:verify-work 2` if desired.
- [v1.4, pending] 2 items in `28-HUMAN-UAT.md` remain pending final on-device re-confirmation of the two code-review fixes; run `/gsd:verify-work` for v1.4 once confirmed, then `/gsd:complete-milestone` for v1.4 whenever convenient — does not block starting v1.5 phase work.
- [v1.5, from research] Quick Action picker precedence tier (Phase 34) — whether a Charging/Device transient interrupts an open picker or queues behind it is an explicit open product decision, not yet resolved; flag for `/gsd-discuss-phase 34` before that phase's planning.
- [v1.5, from research] `NSSharingService`/`NSSharingServicePicker` behavior from Islet's permanently non-key `NotchPanel` is unverified in this codebase (WebSearch-corroborated only) — Phase 34 must spike this in isolation before committing to the full picker plan.
- [v1.5, from research] NotchShape flare (Phase 29) has an open geometry question — whether the flare stays inside the existing panel-frame reservation or needs the panel to grow upward past `screenFrame.maxY` — resolve via a quick on-device check during Phase 29 planning/execution.
- [v1.5, from research] Weather (Phase 33) has two open questions to resolve during its own planning: whether the compact card's H/L needs `fetchCurrent` itself to change, and whether the extended forecast card fits inside the existing 196pt `switcherContentHeight` shared constant (also used by Home/Calendar/Tray) or requires it to grow.

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
| 260714-3k6 | Widen expanded island to 420pt (anticipates ROADMAP Phase 32/TRAY-05 width portion) + gate file-shelf strip to Tray-only (anticipates Phase 31/TRAY-01); 2 on-device gap-closure rounds fixed media-player edge overflow, empty-state camera clearance, and internal player compactness | 2026-07-14 | db11d72 | Complete ✓ (on-device approved after 3 UAT rounds — "Passt") | [260714-3k6-notch-island-verbreitern-und-file-shelf-](./quick/260714-3k6-notch-island-verbreitern-und-file-shelf-/) |

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

**v1.4 close (pending):** All 6 phases (23-28) code-complete; 2 items in `28-HUMAN-UAT.md` await final on-device re-confirmation before `/gsd:complete-milestone` formally closes v1.4. Not blocking v1.5 phase work.

## Session Continuity

Last session: 2026-07-14T23:19:01.361Z
Stopped at: Phase 33 UI-SPEC approved
Resume file: .planning/phases/33-weather-widget-redesign/33-UI-SPEC.md

## Operator Next Steps

- Phase 29 (NotchShape Flare) is complete — its own on-device UAT checkpoint (Task 3) already covered all 3 ROADMAP success criteria, so a separate `/gsd:verify-work 29` pass is not needed. Start `/gsd-discuss-phase 30` next.
- v1.4 is code-complete but not formally closed: 2 items in `28-HUMAN-UAT.md` await final on-device re-confirmation — run `/gsd:verify-work` for v1.4 then `/gsd:complete-milestone` whenever convenient (does not block v1.5).
