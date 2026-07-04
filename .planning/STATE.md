---
gsd_state_version: 1.0
milestone: v1.0.1
milestone_name: Pre-Release Polish
status: milestone_complete
stopped_at: Milestone complete (Phase 09 was final phase)
last_updated: 2026-07-04T14:13:58.046Z
last_activity: 2026-07-04 -- Phase 09 execution started
progress:
  total_phases: 3
  completed_phases: 1
  total_plans: 9
  completed_plans: 39
  percent: 33
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-26)

**Core value:** The notch becomes a beautiful, reliable island that shows now-playing media and reacts when you plug in the charger or connect a device — native, smooth, and as polished as the iPhone Dynamic Island.
**Current focus:** Milestone complete

## Current Position

Phase: 09
Plan: Not started
Status: Milestone complete
  Phase 8 escalated per D-03/D-04: the on-device D-05 trigger matrix (08-01) found the CGS event
  106/107 candidate never fires cross-process (option-c), so 08-03's escalation path ran, reverting
  all exploratory code byte-for-byte and producing 08-ESCALATION.md. The user reviewed it and
  selected option-investigate-b (follow-up investigation). Researching comparable open-source
  projects (TheBoredTeam/boring.notch, Ebullioscopic/Atoll) surfaced a second, prioritized candidate
  (Candidate C: window/Space architecture change) beyond the originally-escalated
  SLSManagedDisplayIsAnimating poll (Candidate B). Phase 9 was added to ROADMAP.md to investigate
  both, Candidate C first.
Last activity: 2026-07-04
  Phase 9 added to ROADMAP.md/.planning/phases/09-fullscreen-flash-window-space-retry/ for FS-01's
  follow-up investigation; REQUIREMENTS.md traceability updated to point at Phase 9

### Phase 5 status note (resolved at v1.0 milestone close)

Phase 5 (device-connected-activity) was formally marked **superseded by Phase 6** in
ROADMAP.md at v1.0 milestone close (2026-07-02, user decision). Its scope — device
connect/disconnect activity, `DeviceActivityState`, `BluetoothMonitor`, device wings —
shipped inside Phase 6 (06-02/06-04); DEV-01/DEV-02 are code-complete and verified (see
`06-VERIFICATION.md`, `REQUIREMENTS.md`). Phase 5's own 3 plans were never executed. The
on-device Bluetooth permission spike from 05-01 Task 3 was superseded by the actual A1
finding in 06-04 (NSBluetoothAlwaysUsageDescription IS required on macOS 26 — see project
memory `a1-bluetooth-usage-key-required`), so no further action is needed there either.

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**

- Total plans completed: 39
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

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 00 P03 | 3 | 3 tasks | 3 files |
| Phase 02 P01 | 4 | 3 tasks | 8 files |
| Phase 02 P02 | 4 | 2 tasks | 3 files |
| Phase 02 P03 | 4 | 2 tasks | 3 files |
| Phase 02 P04 | 180 | 2 tasks | 3 files |
| Phase 06 P06 | 20min | 3 tasks | 2 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap] Charging (Phase 3) is built before Now Playing (Phase 4): proves the activity→island loop on the safest public API (IOKit) before the fragile MediaRemote landmine. (Diverges from research SUMMARY's "Now Playing first"; activity-arbitration nuance deferred to Phase 6 resolver.)
- [Roadmap] Notarization toolchain proven in Phase 0 on a hello-world build, not deferred to release — the single biggest first-timer footgun.
- [Roadmap] Fullscreen-hide (ISL-05) and multi-display/clamshell correctness (ISL-06) are CORE success criteria in Phases 1–2, not polish.
- [Roadmap] All MediaRemote access isolated behind one NowPlayingService with a launch-time health check (Phase 4); a future Apple change is a one-file fix.
- [Roadmap v1.0.1] Two requirements (PBAR-01, FS-01) split into two phases (7, 8) rather than combined into one — different risk profiles: PBAR-01 is straightforward SwiftUI/timer work on top of the existing Now Playing view; FS-01 requires fresh on-device investigation of alternative fullscreen-transition detection signals (v1.0's reactive orderOut approach was already ruled out), with a documented-escalation path if genuinely unfixable at the app layer.
- [Phase 00]: [00-03] Release script uses hdiutil (UDZO) for the DMG; create-dmg noted as Phase-6 polish (not installed).
- [Phase 00]: [00-03] release.sh placeholder-gates Developer-ID/notary steps; ad-hoc fallback exits 0 with a loud SKIP banner — runs unchanged at Phase 6 (D-01/D-02/D-03).
- [Phase 02]: [02-01] isTrueFullscreen maps nil built-in to false: clamshell is NOT fullscreen; the no-target path is owned by shouldShow's hasTarget term, keeping the two concerns untangled.
- [Phase 02]: [02-01] shouldShow = hasTarget && !(hideInFullscreen && isFullscreen): single D-10 gating flag so a future Phase-6 fullscreen toggle is a one-flag change, no logic edit.
- [Phase 02]: [02-02] NotchPillView morph: collapsed+expanded share one matchedGeometryEffect(id: "island") on a single @Namespace; view holds no animation driver (D-08), Plan 03 wraps state mutation in withAnimation(.spring).
- [Phase 02]: [02-02] Expanded size seed 360×72 / collapsed 200×38 exposed as NotchPillView.expandedSize/.collapsedSize so Plan 03 passes the SAME expandedSize to expandedNotchFrame (no view/panel drift).
- [Phase 02]: [02-03] Focus-safe ISL-03: global NSEvent .mouseMoved monitor drives nextState; hover fires haptic+bounce (no expand), click expands with the spring, 0.4s grace-delay collapse; ignoresMouseEvents flipped false only in the hot-zone, restored true when collapsed (Pitfall 3); shown only via orderFrontRegardless (no focus-stealing call).
- [Phase 02]: [02-03] Tuning seeds single-sourced in NotchWindowController for Plan 05: graceDelay 0.4s, spring response 0.35/damping 0.65, hotZonePadding 6, expandedSize from NotchPillView.expandedSize (360×72). A1 DEBUG hover-tick probe ready; NSTrackingArea (Pattern 1b) documented as the permission-free fallback.
- [Phase 02]: [02-04] ISL-05 runtime fullscreen signal pivoted from the safe-area heuristic to a CGS managed-display-spaces probe (built-in current-space type==4): a background agent (LSUIElement) can never observe another app's fullscreen from its own physical display's safe area, so the safe-area predicate is superseded (kept only as a pure test-covered heuristic). No AX/TCC prompt; fails safe to false.
- [Phase 02]: [02-04] Native fullscreen ISL-05 on-device VERIFIED (Tahoe); a ~1-frame island flash at the END of the fullscreen-ENTER transition is product-deferred — root-caused as window-server compositing the all-Spaces panel onto the activating fullscreen Space (our orderOut is reactive, can't pre-empt it); a show-debounce was tried and reverted (f706f66, nothing to debounce). Q2 items (FS video, QuickLook, maximized-stays, clamshell, focus-safe restore) remain pending UAT.
- [Phase 06]: scheduleActivityDismiss() commits syncActivityModels() and renderPresentation() inside one withAnimation(.spring) transaction (was two back-to-back transactions) — an un-animated model clear immediately before an animated presentation switch broke matchedGeometryEffect's frame interpolation on the charging-yield-back, causing a width snap
- [Phase 06]: positionAndShow() guards panel.setFrame(_, display: true) with if panel.frame != panelFrame — an unconditional forced AppKit redisplay on every activity switch could compound the SwiftUI animation interpolation issue
- [Phase 06]: Charging wings BatteryIndicator forwards accent: accent; device wings BatteryIndicator stays untinted (user-confirmed scope exclusion) — 06-04 wired BatteryIndicator's accent parameter end-to-end but missed this one call site; the device battery's fixed green/amber/red is an intentional design decision, not a bug
- [Phase 06]: Charging-cue bolt icon color changed from Color.yellow to Color.green while charging (post-checkpoint deviation) — user reported the yellow was too washed out/hard to see during on-device human-verify; requested live during the checkpoint, not in original plan scope

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

None yet.

### Blockers/Concerns

[Issues that affect future work]

- [Phase 4] MediaRemote longevity is unknowable. Verify the mediaremote-adapter version against the *currently installed* macOS at Phase-4 planning; treat each macOS update as a Now-Playing regression event.
- [Phase 1] Open decision: DynamicNotchKit vs. a custom NSPanel for the overlay. Decide at Phase-1 planning (prototype-with-it then graduate, or roll the panel directly).
- [Phase 0] Confirm the macOS deployment floor (14.0 recommended for reach vs 15.0) before starting.
- [Phase 4] No Apple Developer account yet — only needed for notarization. Phase 0's dry run and Phase 6's release both require it ($99/yr).
- [Phase 6] Decision Coverage Gate override (2026-07-01): planning 06-07..06-12 flagged D-01–D-05, D-07–D-12 as uncovered by `must_haves`/`truths` YAML citations. These decisions are already implemented and shipped in the executed 06-01/06-03/06-04 plans (cited 17-27x in prose) — the gate only scans the structured YAML field, so this is a citation-format artifact in the original plans, not a missing feature. User chose to proceed without editing the already-executed plans. Re-surface if `/gsd:verify-work 6` also flags this.
- [Phase 8] FS-01 is scoped as a full elimination, not a best-effort reduction (REQUIREMENTS.md Out of Scope). v1.0's Phase 2 root-cause diagnosis found the flash likely a window-server compositor timing issue with no viable app-layer fix via the reactive orderOut approach — Phase 8 must find a genuinely different detection/timing signal or produce a documented escalation for an explicit user scope decision.
- [Phase 8] Plan 01's on-device D-05 trigger matrix recorded option-c: CGS event 106/107 never fired for another process's real fullscreen transition across all 3 trigger methods, 3 full enter/exit cycles. Candidate A is disproven; the escalation path (08-03) is the correct plan to execute, not the fix path (08-02).
- [Phase 8] RESOLVED: user selected option-investigate-b (see `.planning/phases/08-fullscreen-enter-flash-elimination/08-ESCALATION.md` and `08-03-SUMMARY.md`). FS-01 remains open.
- [Phase 9] Added to ROADMAP.md to retry FS-01, with two candidates: Candidate C (prioritized) — replace `.canJoinAllSpaces` with a dedicated max-level CGS Space (`CGSSpaceCreate` + `CGSSpaceSetAbsoluteLevel(level: Int32.max)`), found via researching `Ebullioscopic/Atoll`'s `NotchSpaceManager`/`CGSSpace.swift` (fork lineage of `TheBoredTeam/boring.notch`) — targets Phase 2's root-cause diagnosis structurally (no per-Space auto-join event to race against), unlike Phase 8's timing-detection approach. Candidate B (fallback) — `SLSManagedDisplayIsAnimating` poll + disambiguator, from `08-ESCALATION.md`. Not yet planned — run `/gsd-discuss-phase 9` then `/gsd-plan-phase 9`.

## Deferred Items

Items acknowledged and deferred at milestone close on 2026-07-02:

| Category | Item | Status |
|----------|------|--------|
| uat_gaps | Phase 02: 02-HUMAN-UAT.md | partial (8 pending on-device scenarios) |
| verification_gaps | Phase 02: 02-VERIFICATION.md | human_needed |

Pre-existing debt from Phase 2 (Hover, Expand & Fullscreen Hardening), unrelated to Phase 6 gap-closure work this session. Not blocking v1.0 close per user decision — revisit before v1.1 planning or run `/gsd:verify-work 2` to close out.

## Session Continuity

Last session: 2026-07-04T01:59:07.558Z
Stopped at: Phase 9 context gathered
Resume file: .planning/phases/09-fullscreen-flash-window-space-retry/09-CONTEXT.md

## Operator Next Steps

- Phase 9 (`.planning/phases/09-fullscreen-flash-window-space-retry/`) added for FS-01's follow-up
  investigation. Candidate C (window/Space architecture change — dedicated max-level CGS Space,
  found via researching `Ebullioscopic/Atoll`) is prioritized; Candidate B
  (`SLSManagedDisplayIsAnimating` poll, from `08-ESCALATION.md`) is the documented fallback.

- Run `/gsd-discuss-phase 9` then `/gsd-plan-phase 9` to break Phase 9 down before executing.
- v1.0.1 milestone now spans Phases 7-9 (was 7-8) — do not run `/gsd-complete-milestone` until
  Phase 9 resolves FS-01 or the user explicitly descopes it.
