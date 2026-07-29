---
gsd_state_version: 1.0
milestone: v1.10
milestone_name: Live Activities Suite
status: executing
stopped_at: 5 ordered feature-idea seeds captured (2026-07-29) — user wants to discuss/plan idea #1 (File Tray Convert Button) next session, ahead of resuming Phase 67
last_updated: "2026-07-29T02:30:00.000Z"
last_activity: 2026-07-29 -- Captured 5 ordered feature-idea seeds; next session should run /gsd-discuss-phase on idea #1 (filetray-convert-button)
progress:
  total_phases: 19
  completed_phases: 15
  total_plans: 39
  completed_plans: 38
  percent: 79
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-19)

**Core value:** The notch becomes a beautiful, reliable island that shows now-playing media and reacts when you plug in the charger or connect a device — native, smooth, and as polished as the iPhone Dynamic Island.
**Current focus:** 5 new ideas queued ahead of Phase 67 (see below) — user wants these discussed/planned in order before returning to any open phase.

## Current Position

**NEXT SESSION START HERE:** User captured 5 new feature ideas (2026-07-29), ranked in the exact
order they want to tackle them, explicitly ahead of resuming Phase 67 or any other open phase.
Seed files (with reference-screenshot notes — screenshots were described but not transmitted/
captured, re-ask the user to re-share when starting): `.planning/seeds/`

1. [[filetray-convert-button]] — **start here** — File Tray gains a 4th "Convert" button for
   dropped images (JPG↔PNG etc.), mirroring Finder's own "Convert Image" right-click menu.
2. [[island-corner-rounding]] — more rounded corners on the collapsed-wide (wings) island state;
   user also wants a new DEBUG live-tuning nudge axis for corner radius, same pattern as the
   existing Wing Tuner.
3. [[calendar-redesign-droppy]] — widen + redesign the expanded Calendar view to look truly 1:1
   identical to macOS's native Calendar app (Droppy-inspired).
4. [[timer-slider-redesign]] — remove Pomodoro mode from the code entirely; replace timer setup
   with a ruler/slider duration picker + Start button + sound toggle (Droppy-inspired).
5. [[music-next-up-queue]] — expand a "Next Up" list (next 5 songs, art/title/artist) from the
   Now Playing view's existing 3-dots affordance.

Next action: `/gsd-discuss-phase` on idea #1 (File Tray Convert Button) — likely needs adding as
a new phase to ROADMAP.md first, since it isn't one yet.

Phase: 67 (Coding-Progress) — not started, on hold behind the 5 queued ideas above.
Phase 66 (men-bar-overflow-ice-style-mvp) — **PAUSED by user**, not descoped. No revisit trigger.
Last activity: 2026-07-29 -- Captured 5 ordered feature-idea seeds (File Tray Convert, Island corner rounding, Calendar 1:1 redesign, Timer slider redesign, Music Next Up) — user wants these worked in order starting next session, ahead of Phase 67

### Phase 66 Plan 01 result (2026-07-27) — NO-GO

`MenuBarOverflowBridging.swift` (private CGS* window-enumeration/frame-read shim +
`moveMenuBarItem()` synthetic-drag, transcribed directly from Ice's real source) and
`IsletTests/MenuBarOverflowManualSpike.swift` (Cmd-U-only manual spike, mirrors
`MeetingMonitorManualSpike.swift`) built, committed, build verified clean (`adfbd70`).

**On-device checkpoint verdict: NO-GO.** Three Cmd-U rounds on real hardware isolated the
cause: the private `CGSGetProcessMenuBarWindowList` call (identical arguments to Ice's own
`getMenuBarWindowList()`) does not reliably enumerate real menu-bar-item windows on this
hardware/macOS version — it failed to find even the developer's own confirmed-running Islet
status item (found independently via the public `CGWindowListCopyWindowInfo` API at the
`statusWindow` CGWindowLevel, at a different pid than anything CGS returned). Screen Recording
permission and `Bundle.main` bundle-identity were both ruled out as causes. Matches
RESEARCH.md Pitfall 3's flagged risk (undocumented, version-fragile CGS symbols).

Per the plan's own rule, **no later Phase 66 plan (66-02..66-06) proceeds under current scope.**
Next step: `/gsd:discuss-phase 66` to decide direction (different private symbols, a different
reference implementation, or descoping SC#4). Diagnostic instrumentation added during the
checkpoint (commits `5f231f3`, `6136d7f`, `68bb5a2`) is left in place for whoever picks this up.
Full detail in `66-01-SUMMARY.md`.

### Phase 66 Plan 04 result (2026-07-28) — NO-GO

On-device UAT checkpoint (`checkpoint:human-verify`, gate=blocking, no code changes) ran the
8-step verification checklist from `66-04-PLAN.md` against Plan 66-02's public `NSStatusItem`
chevron+spacer mechanism (built to replace Plan 66-01's failed private-CGS approach). Steps 1-3
(build, chevron appears leftmost, no Settings surface) passed; steps 4-6 failed.

**On-device checkpoint verdict: NO-GO.** Cmd-dragging a real third-party menu-bar icon across
the chevron does not work at all — the icon cannot be grabbed/moved across it (MENUBAR-02).
Clicking the chevron correctly toggles the glyph (`chevron.left` <-> `chevron.right`) but causes
NO icon to appear or disappear on either side, in any configuration tested across two independent
rounds (MENUBAR-03) — the spacer `NSStatusItem.length` toggle has no observable reclaim/hide
effect on real menu-bar layout on this macOS 27 Tahoe beta hardware. This is a second, independent
mechanism failure after Plan 66-01's private-CGS NO-GO — this time on the public API RESEARCH.md
assumed was stable (Assumption A2/A3).

Per the plan's own rule, **Phase 66 does not proceed/close under current scope.**
Next step: `/gsd:discuss-phase 66` to decide direction (investigate spacer-item configuration,
test on non-beta macOS, revisit private-CGS with different symbols, or descope SC#4/MENUBAR-01..03
for this milestone). Full detail in `66-04-SUMMARY.md`.

### Phase 66 Plan 05 result (2026-07-28) — NO-GO (third consecutive)

Task 1 (reinstall real Ice.app, restore the 66-01 spike from git history verbatim, add a genuine
`AXIsProcessTrusted()` gate — was previously print-only — plus a DEBUG-only real-launch
enumeration hook) completed and committed (`7e8fadd`), Release build verified clean, all 6
acceptance criteria confirmed via grep/build output.

**On-device checkpoint verdict: NO-GO.** Task 2's how-to-verify sequence failed at **Step 1**
("Re-validate the live reference") — real Ice.app's own Cmd-drag menu-bar-icon hide/reveal does
not function on this machine at all. Islet's own restored/gated CGS mechanism (Steps 2-5,
permission-gate and launch-context hypotheses) was never reached or tested, since the live
comparison reference itself is broken.

**Root cause: UNKNOWN.** Neither of this phase's two leading hypotheses (missing permission gate,
Cmd-U launch-context artifact) was tested. A third possibility neither 66-01 nor 66-04 considered:
the private-CGS menu-bar-item mechanism class itself may no longer function on this macOS version
for any app, not just Islet — since even the reference implementation fails identically. User's own
hypothesis (unconfirmed, not independently verified): the macOS 27 "Golden Gate" update and/or this
machine's Developer Mode setting. This also invalidates the "Ice currently works here" premise
`66-CONTEXT.md`'s D-07 pivot was built on.

Per the plan's own rule, **Plans 66-06/66-07/66-08 do not proceed under current scope.**
Next step: `/gsd:discuss-phase 66` to investigate the Golden Gate/Developer Mode hypothesis,
check whether Ice's mechanism ever genuinely worked on this OS build, or descope
Menübar-Overflow (SC#2-5) from v1.10 entirely. Full detail in `66-05-SUMMARY.md`.

### Phase 66 discuss-phase result (2026-07-28, third revision) — PAUSED

`/gsd-discuss-phase 66` ran to resolve the third NO-GO. The Developer-Mode/Golden-Gate
hypothesis could in principle be tested by disabling Developer Mode and re-testing Ice, but on
this machine that requires a full downgrade back to macOS 26 — the user judged this
disproportionate to one diagnostic data point and declined.

**Decision: PAUSE, not descope.** The user still wants Menübar-Overflow, but does not want to
keep sinking further attempts into it right now, after three consecutive NO-GOs across two
structurally different mechanisms plus an unconfirmed, expensive-to-test root cause for the
third. No revisit trigger was set — this is an open-ended pause (not "when macOS 27 is stable",
not conditional on anything), following this project's Phase 49/50 PAUSED precedent rather than
Phase 37's ABANDONED precedent. Plans 66-06/66-07/66-08 remain un-executed and are not scheduled.
Full reasoning in `66-CONTEXT.md` (third revision) and `66-DISCUSSION-LOG.md`.

**Next up:** Phase 67 (Coding-Progress) — not blocked by Phase 66's pause (fully isolated feature).

### Phase 67.1 Plan 05 Task 1 result (2026-07-26)

Release build (`xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'`) succeeded.
Full XCTest suite: 569 tests, 6 failures — all 6 are the pre-existing, already-documented failures
(4x `LicenseStateTests`, 2x `SettingsViewTests`, see `deferred-items.md`), zero new failures from
Plans 07-10's merged changes. `MeetingMonitorManualSpike.testManualDetectionHeuristic` passed this run
(its own unconditional `XCTAssertTrue(true)` after a 180s manual-observation window) — not a new failure.
All 4 grep-based structural invariants confirmed present (D-13 Site 1 = 2, D-13 Site 3 = 2, D-14 contract = 2).
No files were modified by Task 1 (build/test verification only, per `files_modified: []`) — no code commit.

### Phase 67.1 Plan 05 Task 2 result (2026-07-26)

User performed all 9 on-device UAT steps on their real 1710x1112 hardware and replied "approved" — no issues reported. Per the plan's acceptance criteria, this closes Phase 67.1: all 14 decisions (D-01..D-14) are verified end-to-end (expanded-state auto-only scaling, collapsed-wing auto+manual scaling with camera-safety floor, idle-pill non-regression, Reset to Auto, Meeting-wing mute-icon clickability). See `67.1-05-SUMMARY.md`.

### Phase 48 status note

Phase 48 (audio-output-switcher-ui-wiring) is COMPLETE (all plans executed, on-device UAT approved; awaiting orchestrator's phase-level verification/close) — superseded as "Current Position" by Phase 49 starting above.

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

Progress (v1.5): [██████░░░░] 67% (4/6 phases — Phases 29-32 complete; Phase 33 executing (Plan 1 of 2), Phase 34 not started; left open in parallel with v1.6)

Progress (v1.6): [██████████] 100% — SHIPPED 2026-07-19 (8/8 phases; Phase 37 abandoned/reverted, HUD-07 dropped; see `.planning/milestones/v1.6-ROADMAP.md`)

Progress (v1.7): [███████░░░] 75% (6/8 phases — 43/44/45/46/47/48 complete; Phase 49 spike paused per user decision after weak SC#1/SC#2 results; Phase 50 needs reconsideration before planning)

Progress (v1.8): [██████████] 100% — SHIPPED 2026-07-21 (3/3 phases; see `.planning/milestones/v1.8-ROADMAP.md`)

Progress (v1.9): [██████████] 100% — SHIPPED 2026-07-23 (4/4 phases — Phases 55/56/57/58 complete)

Progress (v1.10): [████░░░░░░] 44% (4/9 phases shipped — Phase 59 Settings-Redesign, Phase 60 Caps Lock HUD + Update-Activity Restyle, Phase 61 Download-Progress, Phase 62 Timer/Pomodoro all shipped and on-device UAT approved; SETTINGS-04/05, CAPS-01, UPDATE-01, DL-01/02, TIMER-01/02/03/04 complete. **Phase 63 Meeting-HUD: all 4 plans executed, 2-round on-device UAT approved, MEET-01/02/03 complete — awaiting orchestrator phase-level gates (code review, regression, verify-work) before the phase counts as shipped.** Phases 64-68 not started)

## Performance Metrics

**Velocity:**

- Total plans completed: 132
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
| 34 | 2 | - | - |
| 35 | 10 | - | - |
| 36 | 4 | - | - |
| 39 | 7 | - | - |
| 42 | 4 | - | - |
| 43 | 2 | - | - |
| 44 | 2 | - | - |
| 47 | 3 | - | - |
| 51 | 1 | - | - |
| 52 | 4 | - | - |
| 53 | 2 | - | - |
| 56 | 2 | - | - |
| 57 | 2 | - | - |
| 58 | 2 | - | - |
| 60 | 5 | - | - |
| 65 | 8 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 25 P01 | 9min | 3 tasks | 2 files |
| Phase 26 P04 | 25h (7 UAT rounds) | 2 tasks | 8 files |
| Phase 31 P01 | 25min | 3 tasks | 5 files |
| Phase 36 P02 | multi-session | 3 tasks | 3 files |
| Phase 36 P04 | multi-session | 3 tasks | 2 files |
| Phase 41 P01 | 10min | 3 tasks | 7 files |
| Phase 41 P02 | 10min | 2 tasks | 3 files |
| Phase 41 P03 | 8min | 2 tasks | 2 files |
| Phase 42 P01 | 10min | 2 tasks | 3 files |
| Phase 42 P03 | 15min | 2 tasks | 1 files |
| Phase 42 P04 | multi-session | 3 tasks | 2 files |
| Phase 43 P01 | 10min | 2 tasks | 3 files |
| Phase 44 P01 | 10min | 2 tasks | 3 files |
| Phase 45 P01 | 10min | 2 tasks | 2 files |
| Phase 45 P02 | <1min | 1 task | 0 files |
| Phase 46 P01 | 12min | 2 tasks | 4 files |
| Phase 46 P02 | 9min | 2 tasks | 3 files |
| Phase 47 P01 | 15min | 2 tasks | 2 files |
| Phase 47 P02 | 12min | 2 tasks | 1 files |
| Phase 47 P03 | multi-session | 2 tasks | 3 files |
| Phase 48 P01 | 15min | 3 tasks | 3 files |
| Phase 48 P02 | 15min | 2 tasks | 1 files |
| Phase 48 P02 | 15min | 2 tasks | 1 files |
| Phase 48 P03 | multi-session | 3 tasks | 2 files |
| Phase 49 P01 | 10min+checkpoint | 3 tasks | 6 files |
| Phase 49 P02 | 1min | 1 tasks | 0 files |
| Phase 52 P01 | 25min | 3 tasks | 6 files |
| Phase 52 P02 | 20min | 3 tasks | 3 files |
| Phase 52 P03 | 20min | 2 tasks | 3 files |
| Phase 52 P04 | 15min | 2 tasks | 0 files |
| Phase 53 P01 | multi-session (checkpoint) | 3 tasks | 3 files |
| Phase 53 P02 | single session (checkpoint, 2 rounds) | 1 tasks | 1 files |
| Phase 54 P01 | 15min | 2 tasks | 2 files |
| Phase 54 P02 | 15min | 2 tasks | 3 files |
| Phase 54 P03 | 20min | 3 tasks | 2 files |
| Phase 55 P01 | 15min | 2 tasks | 3 files |
| Phase 56 P01 | 20min | 2 tasks | 3 files |
| Phase 56 P02 | 8min | 2 tasks | 1 files |
| Phase 57 P01 | 15min | 3 tasks | 3 files |
| Phase 57 P02 | multi-session (checkpoint) | 2 tasks | 1 files |
| Phase 58 P01 | single session (checkpoint) | 3 tasks | 2 files |
| Phase 58 P02 | single session (checkpoint) | 3 tasks | 1 files |
| Phase 59 P01 | 15min | 3 tasks | 3 files |
| Phase 60 P01 | 20min | 3 tasks | 9 files |
| Phase 60 P03 | 10min | 2 tasks | 1 files |
| Phase 60 P04 | 12min | - tasks | - files |
| Phase 60 P02 | 25min | 3 tasks | 3 files |
| Phase 61 P01 | 12min | 2 tasks | 7 files |
| Phase 61 P02 | 15min | 1 tasks tasks | 3 files files |
| Phase 61 P03 | 8min | 1 tasks | 1 files |
| Phase 61 P04 | 20min | 2 tasks | 3 files |
| Phase 61 P05 | multi-session (checkpoint, 5 gap-closure commits) | 2 tasks | 4 files |
| Phase 62 P01 | 25min | 2 tasks | 7 files |
| Phase 62 P02 | 20min | 2 tasks | 3 files |
| Phase 62 P03 | 35min | 3 tasks | 1 files |
| Phase 62 P04 | multi-session (checkpoint, 6 UAT rounds) | 3 tasks | 9 files |
| Phase 63 P01 | 12min | 2 tasks | 5 files |
| Phase 63 P02 | 25min | 2 tasks tasks | 3 files files |
| Phase 63 P03 | 20min | 2 tasks | 4 files |
| Phase 63 P04 | multi-session (checkpoint, 2 UAT rounds) | 3 tasks | 5 files |
| Phase 64 P01 | 10min | 3 tasks | 8 files |
| Phase 64 P03 | 10min | 2 tasks | 2 files |
| Phase 64 P02 | 15min | 2 tasks | 3 files |
| Phase 64 P04 | 12min | 2 tasks | 3 files |
| Phase 64 P07 | 12min | 2 tasks | 5 files |
| Phase 64 P06 | multi-session (checkpoint, 4 UAT rounds) | 3 tasks | 2 files |
| Phase 64 P08 | ~60min (3 checkpoint rounds) | 7 tasks | 3 files |
| Phase 65 P01 | 25min | 2 tasks | 6 files |
| Phase 65 P02 | 12min | 2 tasks | 3 files |
| Phase 65 P03 | 15min | 2 tasks | 3 files |
| Phase 65 P04 | 15min | 1 tasks | 3 files |
| Phase 65 P05 | 20min | 2 tasks | 5 files |
| Phase 65 P06 | 20min | - tasks | - files |
| Phase 65 P07 | 20min | 2 tasks | 1 files |
| Phase 65 P08 | 45min | 2 tasks | 5 files |
| Phase 67.1 P01 | 5min | 2 tasks | 3 files |
| Phase 67.1 P02 | 12min | 2 tasks | 2 files |
| Phase 67.1 P03 | 25min | 2 tasks | 1 files |
| Phase 67.1 P04 | 15min | 1 tasks | 1 files |
| Phase 67.1 P07 | 8min | 2 tasks | 3 files |
| Phase 67.1 P08 | 73min | 2 tasks | 1 files |
| Phase 67.1 P09 | 12min | 2 tasks | 1 files |
| Phase 67.1 P10 | 35min | 1 tasks | 2 files |
| Phase 66 P02 | 25min | 2 tasks | 7 files |
| Phase 66 P03 | 10min | 2 tasks | 2 files |

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
- [v1.6 roadmap] Numbered from Phase 35 (not 34) — v1.5 is intentionally left open in parallel, not archived, and its own Phase 34 (Quick Action Destination Picker) is planned but not yet executed; starting v1.6 at 35 avoids any phase-number collision between the two open milestones.
- [v1.6 roadmap] Phase order 35→36→37→38→39→40→41→42 follows research's explicit risk/dependency ordering: material first (every later HUD renders inside it), then zero-risk cosmetic restyles + fully-independent equalizer/onboarding polish, then the drop-session chip (its one real prerequisite — a shelf-session-boundary concept — surfaced inside its own phase), then the new-transient-case pattern proven cheaply on Focus Mode before attempting it under genuine private-API risk on Volume/Brightness (explicitly kept as ONE phase since both share the same OSD-replacement subsystem), then the fully-independent Sparkle integration floated after material, then Calendar Countdown as a proven single-winner ambient case, and finally Dual-Activity Display last since it needs Calendar Countdown as a real second input to combine with Now Playing.
- [Phase 34]: Decision coverage gate override: D-01/D-02/D-03/D-06/D-07/D-08 not explicitly cited (literal `D-NN:`) in 34-01/34-02-PLAN.md must_haves/truths, but plan-checker semantic review confirmed all 6 are implemented (D-01 in 34-01's takeover truth, D-02 in the preview-render truth, D-03 in Task 1's batch-decision test comment, D-06/D-07 in 34-02's `discardPendingDrop()` task + threat model, D-08 as the subject of threat-model row T-34-04/T-34-07). Same pattern as Phase 30; user chose Proceed anyway.
- [Phase 36]: abs(hasher.finalize()) required before % 1000 reduction in targetHeight(bar:bucket:) — Hasher.finalize() returns a signed Int and Swift's % preserves the dividend's sign, guarding against mapping below the 4...14 floor
- [Phase 36]: D-14: ONBOARD-04 scope pivot — abandoned per-glyph stroke-reveal animation for a static two-word rainbow-gradient 'Meet Islet' heading (Dancing Script Bold) after repeated stroke-weight tuning friction; user-directed, mirrors Droppy's static 'meet droppy' heading; on-device approved ("passt")
- [Phase 37]: Phase abandoned in full after 37-04's on-device UAT — the chip's Tray-close trigger requires an explicit user action to close the Tray, but in real usage the Island stays open showing dropped files and isn't closed right away, so the trigger essentially never fires under normal use. User decided the feature isn't worth keeping rather than redesigning the trigger. All 3 implementation plans (37-01/02/03) were reverted via `git revert` (5 commits total including tracking updates), working tree confirmed clean of all chip-related code, build re-verified green. HUD-07 dropped from the v1.6 requirement set.
- [Phase 38, 38-09]: `INFocusStatusCenter.authorizationStatus == .authorized` is NOT sufficient for `focusStatus.isFocused` to report real values — macOS also requires the `com.apple.developer.usernotifications.communication` (Communication Notifications) entitlement, or it silently resolves to `false` forever (not nil), with the OS logging `DNDErrorDomain 1004 "App is missing Communication Notifications entitlement"`. This was 38-RESEARCH.md's originally predicted dead-end for this API; the Wave-1 spike (38-01) only checked `authorizationStatus`, never an actual `isFocused` read against live state, so the gap wasn't caught until 38-09's on-device UAT. Entitlement added (paid Developer Team `R7AGU84UX7` already configured). **Relevant for Phase 39**: any `Intents`-adjacent system API may carry a similar hidden entitlement requirement beyond basic authorization — verify an actual functional read early in that phase's own spike, not just `authorizationStatus`.
- [Phase 38, 38-09]: Focus wing visual contract deviates from `38-UI-SPEC.md` (icon-only left flank instead of icon+"Focus" label, dot+"On" text on the right instead of a bare dot) — user-directed live redesign during on-device UAT, the first time the pill was ever actually visible (both defects above had masked it until this plan). `38-UI-SPEC.md` not updated — flag for a docs-sync pass. User also flagged that Charging/Bluetooth wings have the same icon-only-flank-too-wide issue but explicitly deferred fixing those as a general follow-up, not part of Phase 38.
- [Phase 39, 39-01]: Go/no-go spike found `suppression-unreliable` — a `.cgSessionEventTap`/`.defaultTap` CGEventTap correctly decodes and swallows (returns `nil` for) volume/brightness `NX_SYSDEFINED` events, but the native macOS notch-integrated OSD still renders regardless, on this machine/macOS Tahoe. Production `OSDInterceptor` (39-03) built `.listenOnly`-only, never attempting suppression; the Settings toggle (39-06) is a documented no-op. User explicitly accepted this as a shipped limitation rather than researching alternative private-API suppression techniques (a `.cghidEventTap`-based approach used by the open-source `dannystewart/volumeHUD` was researched as a possible future spike but not attempted this phase).
- [Phase 39, 39-07]: Extremely costly (16 on-device gap-closure rounds) OSD wing layout saga with a genuinely reusable lesson for any future absolutely-positioned content inside this codebase's `wingsShape` helper: **`.offset(x:y:)` and `.position(x:y:)` both failed to behave as expected when applied to a view inside `wingsShape`'s content `ZStack`** — `.offset()` never actually moved the real render position (`GeometryReader` consistently reported the pre-offset origin no matter what offset value was set), and `.position()` caused the measured view to report the full parent container's size instead of its own intrinsic size. Root cause was never fully explained, just empirically confirmed via a hand-rolled `OSDFrameLogger`/`GeometryReader` diagnostic with PASS/FAIL verdicts. **The fix that actually worked**: abandon absolute-coordinate primitives entirely and use plain sequential `HStack(spacing: 0)` with concrete fixed-width `Color.clear.frame(width:)` spacer elements for excluded/blocked regions — the same pattern every other wing (Charging/Focus/Device) already used successfully. **For any future wing content that needs precise placement near the physical camera notch: default to HStack+explicit-width-spacers, not offset/position, unless a strong reason exists to deviate.** Final calibration: `margin = 55pt` beyond the measured `collapsedNotchSize` half-width, derived from real on-device visibility-percentage reports rather than theoretical notch-geometry math (which repeatedly produced numbers that didn't match reality). User confirmed final result on-device: "passt".
- [Phase 39, 39-08]: Gap-closure re-attempt of OSD suppression **SUCCEEDED**, reversing 39-01's `suppression-unreliable` finding — `.cghidEventTap` (HID-level, before the Window Server session layer) is the working mechanism, where `.cgSessionEventTap` (session-level) was not, confirmed via `dannystewart/volumeHUD`'s (MIT) proven technique. Islet now self-drives the real system volume/brightness/mute via `AudioObjectSetPropertyData`/`DisplayServicesSetBrightness` (same selectors/bundle handle the existing readers already used) whenever a press is swallowed, with a per-type kill switch that falls back to passthrough if a self-drive write ever fails. On-device UAT: zero transport-key irregularities across all 4 media keys and 8 verification steps — native OSD genuinely suppressed, not just shown-alongside. `OSDLevelBar`'s fill spring also retuned snappier (response 0.35→0.15, damping 0.75→0.86, D-16) for single-press feel. HUD-03/HUD-04 now fully shipped with the ROADMAP's originally-accepted fallback superseded by the real fix.
- [Phase 41]: D-01 priority check placed as literal first statement of resolve()'s ambient branch, before nowPlayingLaunchGate — the only place the countdown-over-media priority rule is expressed
- [Phase 41]: handleCalendarCountdownChange(_:) body is exactly 3 lines with zero transientQueue/scheduleActivityDismiss references — the countdown is ambient, not an ActiveTransient (Pitfall 5)
- [Phase 41]: [Phase 41-03] countdownWings(for:) computes icon+text urgency color once inside one shared TimelineView tick closure, structurally preventing icon/text color desync
- [Phase 41]: countdownWings rightWidth widened from wingsSize.width/2 (145pt) to wingsLabelWidth/2 (200pt) to clear the physical camera cutout — On-device UAT found the mm:ss countdown text's leading digit rendering under the camera housing at the narrower icon-only-tuned width; reused the existing label-clearing constant deviceWings already established rather than a new magic number
- [Phase 42-01]: resolveSecondary(primary:nowPlaying:) takes primary as input rather than re-deriving activeTransient/isExpanded, so D-10/D-04 fall out structurally instead of via duplicated checks
- [Phase 42-02]: On-device spike confirmed "passes through": today's NotchWindowController.hotZone does not cover wing-tier tap targets (Countdown wing tested) — Plan 42-04 Task 2 must widen the collapsed/wing-tier click-through zone before the secondary bubble's tap target can work
- [Phase 42-03]: secondaryBubble applies native macOS 26 .glassEffect(.regular.tint(...)) directly against Circle() (full-fill, not rim-only) instead of reusing liquidGlassEffectLayer, which is typed to concrete NotchShape and cannot accept Circle()
- [Phase 42]: D-12/D-13 superseded live during on-device UAT — secondary bubble tap now toggles play/pause directly (not expand-to-Now-Playing), hover reveals a play/pause glyph (not inert); collapsedInteractiveZone() hot-zone widening closes T-42-07 (see 42-04-SUMMARY.md)
- [v1.7 roadmap] Phase order 43→44→45→46→47→48→49→50: the 4 independent, no-research-dependency bugfixes (Drag Detection, Tray/Picker Width, View Switcher, Calendar Quick-Add) sequenced first since none block or are blocked by the Now Playing work; DRAG-02 bundled with TRAY-06 into one phase (44) rather than split, since both touch the same shared width geometry and splitting them risks a repeat-touch-the-geometry regression (this project's own Phase 31→32 "touch `visibleContentZone()` once, not twice" precedent). The Now Playing pair then follows research's explicit risk-isolation recommendation: Audio Output Switcher (zero external-API risk, public CoreAudio) split pure-seam-first (47) then UI wiring (48, hard dependency), before Favorite/Like (this milestone's highest-risk item — Spotify OAuth+quota, Apple Music AppleScript reliability, Automation/TCC bug) split spike-first (49) then implementation (50, hard dependency) — mirroring this project's own Phase 22/24 and Phase 38/39 spike-first precedent. Phases 47 and 49 carry no formal REQ-ID (infrastructure/spike phases), matching the Phase 15/16/19/22-01/24-01/38-01/39-01 precedent of pure-seam or spike work preceding the phase that actually ships user-facing requirements.
- [Phase 43]: dragPasteboardChangeCount is now a stable per-gesture baseline, refreshed only in handleDragApproachEnd unconditionally before the isDragApproaching guard, never mutated in handleDragApproachTick (DRAG-01)
- [Phase 43, 43-02]: On-device UAT of DRAG-01's fix took 4 rounds to close two regressions no build/unit-test gate could see: (1) the island got permanently stuck expanded after discarding a drag, because the auto-collapse grace-timer only fires from `.mouseMoved`-driven hover-exit, which never occurs during an active `.leftMouseDragged` session; (2) even after that was fixed, resolving the Quick Action picker (Drop/AirDrop/Mail/discard) still flashed the underlying Home/Now-Playing/Tray content for the ~0.4s grace window. Fixed by adding a dedicated `.dismissed` InteractionEvent (expanded→collapsed, immediate, no grace defer) to the pure `nextState` reducer plus a shared `dismissExpandedImmediately()` helper used by all 4 picker-resolution paths. User confirmed "Perfekt klappt" after round 4. See `43-02-SUMMARY.md`.
- [Phase 44-01]: Reused NotchPillView.traySize/trayContentHeight/switcherRowHeight at all 3 Quick Action picker geometry sites (panel reservation, contentSize branch, blobShape call) instead of inventing new numbers; deleted the orphaned quickActionPickerContentHeight constant
- [Phase 45-01]: tabWidth/tabHeight consolidation shipped as the SWITCH-01/02 structural fix; trayFullView's shelfItems/shelfVisible override dropped in favor of the unified call site's uniform arguments (no-op, shelfStripVisible is a hardcoded false constant); SWITCH-01/SWITCH-02 left Pending in REQUIREMENTS.md until 45-02's on-device 12-pairwise verification confirms the morph fix
- [Phase 45-02]: On-device 12-pairwise-transition sweep (all 12 tab pairs, both directions), interrupted mid-morph tap retarget check (D-01), and populated-Home sanity check all confirmed glitch-free by the user ("approved") — SWITCH-01/SWITCH-02 marked Complete in REQUIREMENTS.md, closing Phase 45. Per this project's own Phase 29/36/38/39 precedent, this on-device checkpoint directly covers the phase's ROADMAP success criteria, so a separate `/gsd:verify-work 45` pass is not needed.
- [Phase 46-01] isProgrammaticEndUpdate suppression flag distinguishes startRow's auto-follow write to endTime from a genuine user edit, so endRow's onChange doesn't misflip endManuallyEdited after one Start change
- [Phase 46-01] onQuickAdd widened at its single controller call site (Rule 3 blocking fix) to compile against the new 4-arg signature; new Date/Date? args intentionally discarded there, real wiring deferred to Plan 46-02 Task 1
- [Phase 46-02]: Plan 46-02 executed exactly as written (no deviations); handleQuickAdd now forwards real picked Start/End/Due dates to CalendarService, Add trigger moved to left edge, day-list row padding bumped, calendarWidth/calendarContentHeight now 472/220
- [Phase 47-01]: AudioOutputDevice.id derives from uid (String), never AudioDeviceID (Pitfall 4 baked into the type); sortedAudioOutputDevices uses localizedStandardCompare (not raw ASCII <) for human-natural alphabetical ordering — plan executed exactly as written, no deviations
- [Phase 47-02]: listenerBlock stored as nonisolated(unsafe) (not plain private var as literally stated) so nonisolated func stop() can read/clear it without a main-actor isolation compile error — mirrors BluetoothMonitor's nonisolated(unsafe) token fields, a mechanical Swift 6 concurrency requirement not a design change
- [Phase 47-03]: On-device Cmd-U checkpoint surfaced a real bug — resolveDeviceID(uid:) used the deprecated AudioValueTranslation-wrapped-in-ioData pattern for kAudioHardwarePropertyTranslateUIDToDevice, causing HAL "wrong data size" errors, resolveDeviceID always returning nil, hasVolumeControl always false, and setDefaultOutput's confirm-after-set never succeeding; fixed to the qualifier-data calling convention (UID via inQualifierData/inQualifierDataSize, ioData holds only the AudioDeviceID output). Re-verified on-device: Pitfall 4 (UID stability across a Jabra Bluetooth disconnect/reconnect) and Pitfall 8 (confirmed-after-set switch to Elgato USB) both confirmed; hasVolumeControl recorded true for built-in/Bluetooth/USB, false for an external-monitor output. D-03's "2 distinct Bluetooth devices" scope accepted as single-device (only one BT output device available) — user-confirmed, documented limitation, Phase 48 should re-check if a second BT device becomes available.
- [Phase 48-02]: OutputVolumeSlider's disabled state enforced via a guard clause inside DragGesture.onChanged rather than a conditional .gesture(_:) ternary — SwiftUI has no Optional<Gesture> overload
- [Phase 48]: [Phase 48-02] REVISION: original standalone-slider design (shipped in b9f247a/a58607e) replaced by row-as-volume-bar design per 48-CONTEXT.md D-10..D-13 -- active device's row IS the draggable volume bar, inactive rows plain dimmed text, full-white-vs-dimmed text opacity is the sole active-device signal (no checkmark)
- [Phase 48]: [Phase 48-02] content() must be evaluated into a local let binding BEFORE entering GeometryReader{...}'s closure, not called inside it -- GeometryReader.init(content:) is @escaping and cannot capture a non-escaping @ViewBuilder parameter directly (mechanical Swift-compiler constraint found during Task 2's first build attempt)
- [Phase 48-03]: Re-verified Tasks 1-2 (handlers + closure forwarding, geometry three-site rule Sites 2/3) against current code after 48-02's row-as-volume-bar re-execution landed -- all acceptance-criteria greps pass unchanged (handleToggleOutputPanel/handleSelectOutputDevice/handleVolumeChange, makeRootView forwarding, outputPanelExpandedFrame union, visibleContentZone's outputPanelOpen branch correctly nested inside the final else), Debug build green, zero commits needed (safe no-op per plan's own revision note). Task 3 (on-device UAT checkpoint) reached next -- previously blocked because 48-02's row-as-bar redesign hadn't been re-executed, now unblocked.
- [Phase 48-03]: Task 3 UAT round 1 -- 6/7 steps passed, 1 issue: volume-drag fill visibly choppy/stepped instead of tracking the finger. Root cause: `outputVolumeSlider`'s fill `.animation(value: fraction)` spring was copied verbatim from `OSDLevelBar` (correct there -- rare discrete key-press updates), but `fraction` here updates on every `DragGesture.onChanged` tick, so each tick retriggered a fresh 150ms spring chasing a moving target. Fixed by gating the animation off via an instance-level `isDraggingOutputVolume` bool (mirrors `isSecondaryBubbleHovering`'s "only one row/bubble active at a time" precedent) while a drag is in progress, restoring the spring once the drag ends. `OSDLevelBar` itself untouched. CoreAudio's synchronous per-tick `AudioObjectSetPropertyData` write was assessed as a plausible secondary contributor but NOT throttled -- the animation-retrigger mechanism alone fully explains the reported symptom, and throttling was deferred pending on-device re-confirmation to avoid over-fixing. Debug build green, commit e657356. Re-verification of UAT step 2 (plus re-confirmation of the other 6 steps) pending.
- [Phase 48]: [Phase 48-03]: Task 3 UAT round 2 (post animation-gating fix e657356) -- user replied plain 'approved', confirming drag is smooth and all 7 UAT steps pass. Phase 48 (Audio Output Switcher -- UI Wiring) is now on-device UAT-complete, all 4 ROADMAP Success Criteria confirmed against the row-as-volume-bar design.
- [Phase 49-01]: Task 1 landed `com.apple.security.automation.apple-events` (Islet.entitlements) + `INFOPLIST_KEY_NSAppleEventsUsageDescription` (project.yml, German string, Phase-49-commented) — regenerated via xcodegen, Debug build green. Task 2 wired two DEBUG-only spike hooks (`spikeLikeCurrentTrack()`, `spikeTriggerAutomationPrompt()`) through NowPlayingMonitor -> NotchWindowController -> AppDelegate's existing debug menu, with two Rule-1 deviations from the plan's literal text: (1) NotchWindowController's forwarding methods are internal, not `private` as the plan stated — AppDelegate is a different type/file and cannot call a private method, so `private` would not compile; (2) the two new `@objc` debug-menu action methods needed an explicit `@MainActor` annotation — NotchWindowController (and its spike methods) are `@MainActor`-isolated, and unlike protocol-required `NSApplicationDelegate` methods, a plain `@objc private func` is not inferred `@MainActor` by default, so the original code failed to compile with "call to main actor-isolated instance method in a synchronous nonisolated context." Debug build green; Release build build-log-grepped and confirmed to exclude both spike symbols (0 matches). Task 3 (on-device checkpoint) resolved: **SC#1 = like-effect-not-observed** (kMRLikeTrack sends cleanly to both Music.app and Spotify.app, confirmed via console log, but neither app's liked-state UI visibly flips) and **SC#4 = tcc-bug-ruled-out** (permission dialog appeared on Islet's first-ever automation attempt, granting it fixed the call — `SPIKE AppleScript succeeded: Beverly Hills` — no `-1743` recurrence; idle-time relaunch variant not attempted this session, acceptable per D-06). RESEARCH.md's already-confirmed finding restated: the streamed MediaRemote payload has no favorite/rating read-state field either — combined with the write-side null result, Phase 50's star button needs a wholly separate per-app read/write path (Apple Music AppleScript `loved`, Spotify `GET`/`PUT /me/library`), not this MediaRemote command. Plan 49-01 is now COMPLETE (see `49-01-SUMMARY.md`); Plan 49-04 depends on this file's verdicts.
- [Phase 49-03]: Task 1 landed `.planning/phases/49-favorite-like-spike/spotify-pkce-spike.sh` (executable, `bash -n` clean) copying RESEARCH.md's Code Examples section verbatim — S256-only PKCE `code_verifier`/`code_challenge` generation via `openssl`, hardcoded loopback `REDIRECT_URI` (`http://127.0.0.1:8888/callback`), `CLIENT_ID` left as the literal placeholder string (never a real value, per T-49-09), `/authorize` + `/api/token` exchange, and a real `PUT /me/library` save-track call with the track URI read via a second `read -p` prompt (never hardcoded). No deviations — plan executed exactly as written. Task 2 (on-device checkpoint, gate=blocking) is next — requires the human to register a real Spotify Developer app, substitute the real Client ID locally/uncommitted only, run the browser PKCE flow, and read the live quota-mode text from the Spotify Developer Dashboard; none of this is executor-automatable. SUMMARY.md deliberately not yet created (Plan 49-04 depends on its final verdicts).
- [Phase 49-02]: SC#2 verdict: matrix-shows-different-behavior — loved of current track fails uniformly with -10001 in all 4 states (library/streaming x play/pause); name of current track succeeds in all 4 states. Deviates from RESEARCH.md's predicted -1728 streaming-only error. Phase 50 needs a documented Apple-Music-loved-broken fallback or an alternative read/write path, not just a streaming-only edge case. Plan 49-02 is now COMPLETE (see `49-02-SUMMARY.md`); Plan 49-04 depends on this file's verdict.
- [Phase 51-01]: Task 1 landed the 7-case `SidebarSection` restructure (D-06 order Activities/Appearance/Fullscreen/Weather/Diagnostics/Workspace/About) — `activitiesSection`/`fullscreenSection`/`weatherSection`/`diagnosticsSection` extracted verbatim from the old monolithic `generalSection`, `systemSection` renamed to `appearanceSection` (D-01), all 5 wrapped in `ScrollView(.vertical)`, `generalSection`/`systemSection` deleted with zero dead references remaining (commit 4e36f2c). Task 2 wrapped `workspaceSection`/`aboutSection` in the same `ScrollView` pattern, preserving `workspaceSection`'s centering `.frame` on the inner VStack per the plan's explicit instruction — both Debug and Release builds green (commit 871c146). No deviations from the plan on either task. Task 3 (on-device UAT, `gate="blocking"`) is a checkpoint requiring an interactive human on-device walkthrough this executor cannot perform — reached and NOT auto-approved (`workflow.auto_advance` is `false`, no auto-chain active). Per the plan's own `<output>` spec ("Create SUMMARY.md when done") and the Phase 49-03 precedent (blocking checkpoint → SUMMARY.md deliberately deferred), `51-01-SUMMARY.md` was intentionally NOT created yet: Phase 51 has exactly 1 plan, so writing it now would make `roadmap.update-plan-progress`'s file-existence-based detection mark the entire phase Complete before UAT is approved. Resume by running the Task 3 checklist (11 steps, 51-01-PLAN.md) on-device; on "approved" (or a described failure), a continuation agent should finish the plan (SUMMARY.md, `state.advance-plan`, `roadmap.update-plan-progress`).
- [Phase 52-01]: orderedSlotIcons(...) does no deduplication/validation — duplicate slot assignments are intentionally allowed, matching this codebase's no-Picker-validation convention
- [Phase 52-01]: topEdgeCutoutGap(...) is a thin wrapper around notchSize(...).width, not a reimplementation, so the two never drift
- [Phase 52-02]: blobShape's showsPillRow = showSwitcher && switcherLayout == .pill splits 'reserve switcher-sized content height' (baseHeight, layout-independent) from 'show the pill row' (layout-dependent) — the three-site fix (blobShape, body's totalHeight, NotchWindowController.visibleContentZone()) all read the same switcherLayout signal independently, no shared plumbing
- [Phase 52-02]: icon(for:) extracted once and reused verbatim by both switcherRow and topEdgeSwitcherRow (D-03) — exactly one place maps SelectedView to (systemName, action); topEdgeSwitcherRow computes its own hasNotch/cutout geometry independently (selectTargetScreen + topEdgeCutoutGap), mirroring NotchWindowController.currentBuiltin()'s existing pattern, no controller plumbing
- [Phase 52-03]: SWITCH-03/SWITCH-04 left Pending in REQUIREMENTS.md — mirrors Phase 45/52-02 precedent of deferring requirement completion until the phase's on-device UAT plan (52-04) confirms the feature works end-to-end on real hardware
- [Phase 52]: [Phase 52-04]: On-device UAT approved ("Klappt alles wunderbar") — full 403-test regression suite green (only 2 pre-existing unrelated CalendarGlanceTests failures) plus Release build succeeded; SWITCH-03/SWITCH-04 confirmed on real notched hardware (D-04 36pt-in-42pt fit, Pitfall 2 cutout-gap clearance, D-03 live reorder propagation to both layouts) — Phase 52 shipped
- [Phase 53]: [Phase 53-01]: Task 1 on-device spike verdict = approved — togglePlayPause() resumes a paused (not quit) session for both Spotify and Apple Music, matching the plan's default expectation; gives Task 3's D-03 inferred-failure timeout a real empirical basis. Hover-preview shipped as a view-local branch off .idle (Claude's Discretion, 53-CONTEXT.md), not a new IslandPresentation case — IslandResolver.swift/IslandResolverTests.swift confirmed untouched.
- [Phase 53]: [Phase 53-01]: RESUME-01/RESUME-02 left Pending in REQUIREMENTS.md — mirrors the Phase 45/52-02/52-03 precedent of deferring requirement completion until the phase's own on-device UAT plan (53-02) confirms the shipped hover-preview/resume-tap behaves correctly end-to-end on real hardware (hit-testing across the full wings footprint, timeout-window feel), even though this plan's own Task 1 spike already de-risked the underlying transport-feasibility question.
- [Phase 53]: [Phase 53]: [Phase 53-02]: On-device UAT approved (Debug + Release) — all 4 ROADMAP success criteria confirmed, closing RESUME-01/RESUME-02. Mid-UAT design fix: D-02 superseded (bouncing equalizer bars in the idle-hover preview replaced with a static play.fill glyph, since animated bars while nothing was playing read as misleading) — commit 581c94e. v1.8 milestone now 3/3 phases complete.
- [Phase 54]: [Phase 54-01] EKAuthorizationStatus.writeOnly counts as granted (never denied) for the combined Calendar+Reminders row; combinedCalendarReminderStatus resolves worst-of-two (denied > notYetAsked > granted, D-13 locked). Plan executed exactly as written, no deviations.
- [Phase 54]: [Phase 54, 54-03]: Tasks 1-2 (Permissions sidebar section wiring Plan 01's read layer + tap-to-act; Replay Onboarding button in About wiring Plan 02's replayOnboarding()) landed and build-verified (commits 3a1d14d, 0a548ed). Task 3 (on-device UAT, gate=blocking) is a checkpoint requiring interactive human verification this executor cannot perform -- reached and NOT auto-approved (workflow.auto_advance is false, no auto-chain active). Per the Phase 49-03/51-01 precedent, 54-03-SUMMARY.md was intentionally NOT created yet -- writing it now would let roadmap.update-plan-progress mark Phase 54 (3/3 plans, others complete) as fully shipped before UAT is approved. Resume by running the Task 3 checklist (10 steps, 54-03-PLAN.md) on-device; on 'approved' (or a described failure), a continuation agent should finish the plan (SUMMARY.md, state.advance-plan, roadmap.update-plan-progress).
- [Phase 54]: [Phase 54]: [Phase 54-03]: On-device UAT approved — all 9 checklist steps confirmed (Permissions section rows/summary/deep-links, Replay Onboarding carousel Next-through-Done and mid-flow X close, state-restore, no first-launch regression). Phase 54 (Permissions Overview & Onboarding Replay, ARCH-P2) now 3/3 plans complete.
- [Phase 54]: [Phase 54-04]: Tasks 1-2 (Bluetooth-toggle-gated grant CR-01, requestLocationPermission() bridge CR-02, SettingsView .location/.focus wiring WR-01, replayOnboarding() updateVisibility() fix CR-03) landed and build-verified (commits 2a190d8, 2e95789). Task 3 (on-device UAT, gate=blocking) is a checkpoint requiring interactive human verification this executor cannot perform -- reached and NOT auto-approved (workflow.auto_advance is false). Per the Phase 49-03/51-01/54-03 precedent, 54-04-SUMMARY.md was intentionally NOT created yet -- writing it now would let roadmap.update-plan-progress mark the plan/phase complete before UAT is approved. Resume by running the Task 3 checklist (7 steps, 54-04-PLAN.md) on-device; on 'approved' (or a described failure), a continuation agent should finish the plan (SUMMARY.md, state.advance-plan, roadmap.update-plan-progress).
- [Phase 55]: ClipboardItem/ClipboardStore shipped Foundation-only, zero AppKit/NSPasteboard/IslandResolver coupling; D-02 dedupe-move-to-top and D-01 cap=30/FIFO evict both proven for text and image Kind cases (TDD RED/GREEN)
- [Phase 56]: [Phase 56-01]: ClipboardFileStore/KeychainClipboardKeyStore shipped — device-only AES-256 key (D-05), encrypted JSON index + per-image files with D-04 graceful degradation and D-06 orphan cleanup; deleteOrphanedImageFile hardened under storageRoot exactly mirroring ShelfFileStore's guard. Plan executed as written (one cosmetic variable-naming fix to match the plan's own literal grep, no behavior change). Manual Cmd-U test-execution confirmation still pending (headless xcodebuild test hangs in this repo, PROJECT.md-documented).
- [Phase 56]: [Phase 56-02]: On-device UAT approved — full kill-and-relaunch of ClipboardFileStore against real Application Support storage reloads the same 3 seeded items (matching IDs/content), and index.json.enc confirmed unreadable ciphertext on real disk. CLIP-04/PRIV-02 marked complete, closing Phase 56 (Encrypted Persistence).
- [Phase 57]: [57-01] Confirmed NSPasteboard.AccessBehavior real Swift case is .alwaysAllow (macOS 26.5 SDK header) not .always as PITFALLS.md speculated; needsAccessExplanation uses the real symbol
- [Phase 57]: [57-02] Task 1 landed 4 DEBUG-only spike hooks wired to ClipboardMonitor via a throwaway console-print sink (89035cb). Task 2 on-device UAT approved across 2 rounds -- all 4 ROADMAP Phase 57 success criteria confirmed on real hardware: SC#1 text+image capture/classify, SC#2 concealed-type exclusion, SC#3 self-capture guard, SC#4 one-time-gate (this Mac's accessBehavior already .alwaysAllow, so the alert branch didn't fire, but the session-scoped gate flag itself proven correct on the second click). PRIV-01 satisfied at the monitor layer; Phase 57 (Pasteboard Monitor Spike) complete.
- [Phase 58]: 58-01: D-15 REVISED on-device UAT — clipboard rows moved from inline top-of-menu list to a flyout submenu behind a single 'Clipboard History' anchor item, user-approved live to show more entries at once; Cmd+0-9 kept working instantly on icon-click via a hybrid menuWillOpen/menuDidClose-scoped NSEvent keyDown monitor, since submenu keyEquivalents don't fire while the submenu is closed
- [Phase 58]: 58-01: Task 3 on-device UAT found and fixed two bugs — NSHostingView rows inside NSMenuItem.view rendered at zero size until given an explicit frame (ClipboardRowView.rowWidth=260pt), and SwiftUI .onHover missed mouseExited during NSMenu tracking causing stuck row highlight, fixed via an NSTrackingArea-backed ClipboardRowContainerView/ClipboardHoverState pair
- [Phase 58]: 58-02: Delete All History placed as a top-level NSMenuItem beside the Clipboard History anchor (not nested in its submenu) — re-derived after 58-01's D-15-REVISED flyout-submenu amendment, matching the option 58-01-SUMMARY.md itself flagged and 58-01's own placeholder code comment
- [Phase 58]: 58-02: On-device UAT approved first round — all 4 ROADMAP Phase 58 success criteria (CLIP-01/02/03/05) confirmed on real hardware, closing v1.9 (Clipboard History) at 4/4 phases
- [Phase 59-01]: ActivityCardData carries no category field/enum — Plan 59-02's own card arrays already partition by category; no migration function added for the 8 new v1.10 activity keys since absent-key @AppStorage default is the only mechanism needed
- [Phase 59-02]: Tasks 1-2 (8 new @AppStorage properties + 3 categorized card arrays; activitiesSection rebuilt as a single-ScrollView categorized 2-column card grid with categorySection(title:cards:) helper, Focus/OSD popovers relocated onto the System-HUDs categorySection call site) landed and build-verified (commits ba43bfa, aca7a13). Task 1 also required regenerating Islet.xcodeproj via xcodegen (Rule 3 blocking fix -- Plan 59-01's ActivityCard.swift was never added to the project's Sources build phase, causing a cannot-find-type build failure). Task 3 (on-device UAT, gate=blocking) is a checkpoint requiring interactive human verification this executor cannot perform -- reached and NOT auto-approved (workflow.auto_advance is false). Per the Phase 49-03/51-01/54-03/54-04 precedent, 59-02-SUMMARY.md was intentionally NOT created yet -- writing it now would let roadmap.update-plan-progress mark Phase 59 complete before UAT is approved. Resume by running the Task 3 checklist (12 steps, 59-02-PLAN.md) on-device; on 'approved' (or a described failure), a continuation agent should finish the plan (SUMMARY.md, state.advance-plan, roadmap.update-plan-progress).
- [Phase 60]: [Phase 60-01]: defaultsToFalseKeys generalizes activityEnabled(_:) beyond focusKey-only, closing the Pitfall-1 default-ON gap for osdSuppressionKey and all 8 Phase-59 v1.10 keys, not just capsLockKey/updateHudKey; NotchPillView's .capsLock/.updateAvailable case renders EmptyView() as a placeholder -- real wing UI ships in a later Phase 60 plan
- [Phase 60]: [Phase 60-03]: capsLockPermissionExplanationView clones osdPermissionExplanationView's exact shape (own private var, no shared generic popover); Update Available card added to systemHUDCards, default OFF, no permission gate
- [Phase ?]: [Phase 60-04]: wingsShape's onTap override built purely-additive with zero existing call-site edits; capsLockWings conveys state via text alone (no status dot, D-03); UpdateVersionPill built standalone, not a BatteryIndicator parameterization
- [Phase ?]: [Phase 60-02]: CapsLockMonitor clones PowerSourceMonitor's lifecycle + OSDInterceptor.isAccessibilityTrusted's gate, never force-prompts; handleUpdateAvailable/handleCapsLockChange both preempt a standing .focus head, else enqueue, mirroring handleOSDKeyPress's shape; RESEARCH.md Pitfall 3 (live-reconcile vs relaunch-required) and Pitfall 4 (Update wing tap-target reliability) left unresolved for Plan 60-05's on-device checkpoint
- [Phase ?]: [Phase 61-01] DownloadActivity.swift follows DeviceActivity.swift's Pattern-1 file convention (reading type + presentation enum + pure helpers all in one file), overriding 61-PATTERNS.md's narrower two-case-enum-only sketch
- [Phase ?]: [Phase 61-01] IslandResolver: downloadProgress lands at ActiveTransient/IslandPresentation rank 5 (collapsed-only, sub-state-persistent per D-02/D-13); capsLock/updateAvailable shift to rank 6/7 (comment-only, D-01); required a Rule-3 xcodegen regenerate and 2 exhaustive-switch completions (NotchWindowController.syncActivityModels, NotchPillView placeholder EmptyView() mirroring the 60-01 precedent)
- [Phase 61-02]: DownloadCoordinator's activityPromoted() ships as a documented empty-body no-op (RESEARCH.md Open Question 1) -- a completing download's own done state is delivered via plain TransientQueue enqueue/advance mechanics, never a coordinator-side promoted re-check; reset() shipped in this plan (not deferred to 61-04) alongside the table it clears
- [Phase ?]: [Phase 61-03] downloadWings(for:) wraps each switch-case's wingsShape(...) in AnyView (divergent per-state HStack content) -- presentationSwitch now renders real download-progress wing UI, replacing Plan 61-01's EmptyView() placeholder
- [Phase ?]: [Phase 61-04]: MainActor.assumeIsolated (not DispatchQueue.main.async) bridges the FSEvents C callback into DownloadMonitor -- callback already runs on FSEventStreamSetDispatchQueue(.main), and eventPaths/eventFlags are only valid for the callback's own duration so async deferral would be unsafe; per-event dictionary extraction happens synchronously in the free-function callback before handoff
- [Phase 61]: [Phase 61, 61-05]: On-device UAT round-trip (5 gap-closure commits) fixed a real cancel-bug (DownloadCoordinator's removeInProgress closure now dismisses a standing .inProgress transient, since .removed never told TransientQueue to clear an already-showing head) and redesigned downloadWings icon-only both flanks (fixed-left download icon, right flank swaps spinner<->checkmark, .monochrome+.bold rendering, camera margin 55->30->20, edge padding 12->16) after the wing proved too wide/dim on real hardware. All 11 UAT checklist steps confirmed, closing DL-01/DL-02 and all 4 ROADMAP Phase 61 Success Criteria.
- [Phase 62]: [Phase 62-01] preempt() generalized from hardcoded .focus guard to currentHead.isPersistent, closing a latent Download-Progress preemption gap (regression test testPreemptNowGeneralizedForDownloadProgressHead); .timerExpanded is the first IslandPresentation case with its own dedicated expanded-controls presentation (Pattern 4), not a fallthrough
- [Phase 62-02]: TimerActivityState/TimerMonitor shipped exactly per plan (D-08/D-09/D-10/D-11 mutation logic + CalendarCountdownMonitor-mirrored one-shot deadline scheduler); 12/12 TimerActivityStateTests green, full 509-test suite shows zero new regressions (same 4 pre-existing unrelated failures). Only deviation: the plan's own acceptance-criteria grep for now:-parameterized overloads undercounts (5 vs 7) due to a BRE literal-parens artifact on multi-param signatures -- verified via an alternate grep that all 7 overloads genuinely exist, no code change needed.
- [Phase 62]: [Phase 62-03]: timerTick(for:at:) plain helper extracted so a TimelineView content closure never contains a bare switch-assignment (ViewBuilder tries to build every statement as a View); shared verbatim by timerWings(for:) and timerExpandedContent(for:)
- [Phase 62]: [Phase 62-03]: TIMER-03 left Pending in REQUIREMENTS.md -- the completion splash rendering this plan built is only half the requirement, the notification sound is Plan 62-04's job
- [Phase 62-04]: Timer moved out of Home into its own dedicated 5th switcher tab (SelectedView.timer / IslandPresentation.timerSetup) mid-UAT round 1 — The inline Home-overlay picker overflowed for Pomodoro and conflated Now-Playing/Timer-setup concerns; Timer is a fixed icon appended after the 4 configurable switcher slots, gated on timerEnabled
- [Phase 62-04]: Pomodoro collapsed-pill dot/label camera-cutout clipping (rounds 3/4/6) root-caused to timerWings' margin constant, not content-box width — margin=20 was copied from icon-only downloadWings; capsLockWings had already solved the identical text-adjacent-to-camera problem with an on-device-proven margin=65, reused instead of guessing a new number, verified against real NSFont metrics
- [Phase 63]: [Phase 63-01]: No MeetingActivityState holder created (deliberate deviation from 63-RESEARCH.md's file list) — TransientQueue.head (ActiveTransient.meeting) already IS the live payload, mirroring CapsLockActivity/UpdateActivity's simpler shape; defaultInputDeviceID() is internal not private so Plan 63-02's MeetingMonitor reuses it; MicMuteController adds an AudioObjectHasProperty guard before every Get/Set that VolumeReader.swift itself lacks (T-63-01), plus a Rule-2 kAudioObjectUnknown (deviceID == 0) rejection the verbatim copy would have missed
- [Phase ?]: [Phase 63-02]: On-device spike verdict = GO. Detection heuristic (target app running AND kAudioDevicePropertyDeviceIsRunningSomewhere on the default input device) validated on real hardware across 3 runs: no Microphone TCC prompt from MicMuteController's read/toggle (Pitfall 2 / A1 hard gate PASSED - no NSMicrophoneUsageDescription or permission flow needed), detection fires within ~5s of the mic going live, clears on call end, exactly 4 perfectly-alternating transitions with zero duplicate fires while a state held (the dedup contract Plan 63-04's preempt/removeAll depends on), stays silent when an unrelated mic app records with no target app running, and never fires for a browser-tab Google Meet (MEET-03 negative confirmed). D-07's accepted false positive (mic test without joining a call) reproduced as expected. SUBSTITUTION: the validation machine had neither Zoom nor Teams installed, so the spike targeted Discord (com.hnc.Discord), a native voice-call app with the identical signal shape - production targetBundleIDs unchanged, spike file carries a SPIKE SUBSTITUTION comment. CARRIED-FORWARD RISK: the literal production bundle IDs us.zoom.xos / com.microsoft.teams2 / com.microsoft.teams are UNVERIFIED against real installs; if 63-03's UAT shows no detection on a real Zoom/Teams call, check the bundle ID first before re-debugging the heuristic.
- [Phase ?]: [Phase 63-02]: Rule-2 deviation - MeetingMonitor adds a kAudioHardwarePropertyDefaultInputDevice listener plus retargetInputListener()/stored listenedDeviceID beyond the plan's single-listener design. Without it a mid-session default-input change (AirPods connecting) strands the running-somewhere listener on the old device, and stop() would remove it from whatever is default at teardown - leaking the real registration across repeated Settings toggle on/off (T-63-04). Also: kAudioDevicePropertyScopeInput was probe-verified on-device before writing (Apple documents this property on the Global scope; Input, Global and Output all answer hasProperty=true here), so the plan's mandated Input scope is correct as written with no fallback branch.
- [Phase 63]: .meeting landed at D-05 rank 3 (persistent D-06, collapsed-only D-10), riding Phase 62's already-generalized preempt() with zero changes to preempt() itself
- [Phase 63]: Rank ordering is asserted via TransientQueue.preempt() tests, not resolve() tests — resolve() takes exactly one activeTransient, so its switch order is externally unobservable
- [Phase 63]: MEET-01/MEET-02 stay Pending until Plan 63-04's controller wiring + on-device UAT — 63-02 precedent: infrastructure plans do not close requirements
- [Phase ?]: [Phase 63-04]: D-05 SUPERSEDED by D-05a (user decision during on-device UAT round 1, NOT planning): nothing interrupts a live call. While a .meeting head stands every other transient is DROPPED OUTRIGHT — Charging and Device included — not preempted, not queued. Trigger: UAT step 10 found the charger mid-call queued behind the persistent Meeting head and the splash popped up minutes later once the call ended; the user identified that delayed pop-up as the unacceptable part and chose 'nothing interrupts a live call' from four offered options. Accepted cost (user explicitly warned): the volume/brightness OSD is also suppressed during a call. Implemented ONCE as TransientQueue.dropsWhileCallStands(_:) consulted by both enqueue() and preempt(), so a future transient category inherits the rule automatically; updateHead (mute-tap isMuted refresh) and removeAll (Settings toggle-off) are deliberately exempt. Loosening it later is a one-line change inside that predicate. D-05's rank placement (after .device, before .focus) is unchanged and still correct — rank governs resolve()'s switch order, a separate mechanism from the queue's admission rule.
- [Phase ?]: [Phase 63-04]: Rule-3 root-cause fix for a LATENT PHASE 62 BUG, not one Phase 63 introduced — four NotchWindowController call sites (charging, capsLock, updateAvailable, osd) still carried the pre-Phase-62 hardcoded 'if case .focus = transientQueue.head' guard and fell through to plain enqueue() for any OTHER persistent head, even though Phase 62-01 generalized preempt() to 'currentHead.isPersistent' and updated the two deviceCoordinator sites. A running .timer head had the identical failure in shipped code. All four conditionals deleted (pure redundancy — preempt() already falls back to enqueue() for a nil/non-persistent head); regression-locked by testChargingPreemptsAStandingTimerHead. Behaviour change outside Phase 63's declared scope worth flagging at phase review: a Timer user may notice charging splashes now appearing DURING a countdown where they previously arrived late.
- [Phase ?]: [Phase 63-04]: Research Assumption A2 CLOSED on-device — the nested .onTapGesture on meetingWings' mute icon reliably beats wingsShape's outer gesture on real hardware; the documented .highPriorityGesture fallback was never needed. Wing geometry also CLOSED with ZERO retuning: 63-UI-SPEC.md's locked margin 20 / 84pt right block were correct first try (unlike timerWings' 6-round history). Neither risk carries forward.
- [Phase ?]: [Phase 63-04]: Meeting-HUD UAT ran against Discord (com.hnc.Discord) as a Zoom/Teams stand-in — the validation machine has neither installed, so with the production target set the HUD could never appear and the UAT would have been impossible (same substitution 63-02's spike used, 63e6db1). Temporary commit f716489 reverted in e455ea7; production default targetBundleIDs verified back to exactly [us.zoom.xos, com.microsoft.teams2, com.microsoft.teams]. CARRIED-FORWARD RISK: those literal bundle IDs remain UNVALIDATED against a real install across all 4 plans of this phase — the user's first real Zoom or Teams call is what confirms them. If the HUD ever fails to appear on a real call, check the bundle ID FIRST, not the heuristic, which is now UAT-proven.
- [Phase ?]: [Phase 63-04]: handleMuteTap() must call renderPresentation() even though the plan said no re-trigger was needed — updateHead(_:) mutates only the queue, and presentationState.presentation is the sole value the view observes, so the mute icon would never visibly change state. Same failure class as Phase 62-04's 'Bug 2' (flushTransients called standalone with no follow-up render). presentTransientChange() is still deliberately NOT used: re-arming the dismiss window for an unchanged displayed case would be wrong.
- [Phase 64]: QuickNotesFileStore comment reworded from 'CryptoKit/Keychain' to 'encryption/Keychain layer' so the plan's own grep -c CryptoKit acceptance check passes literally (no behavior change)
- [Phase ?]: [Phase 64-03] Vault path stored as plain UserDefaults String (D-09) — path only ever comes from NSOpenPanel's return value, no path-injection surface (T-64-07)
- [Phase 64]: QuickNotesVaultWriter shipped exactly per the plan's locked reference implementation (bounded 4096-byte tail-read + seekToEndOfFile+write append), no deviations to the write logic itself
- [Phase 64-04]: submit() only clears the TextEditor's text when controller.errorMessage == nil after onSubmit returns, not unconditionally as the plan's action text literally said — preserves D-12's locked data-loss guard (typed text stays present on a failed vault write) and matches the plan's own state-3 behavior spec
- [Phase 64-04]: error banner copy is hardcoded in QuickNotesPopoverView rather than solely derived from controller.errorMessage's string content — keeps the exact UI-SPEC Copywriting Contract text owned by the view; errorMessage still gates visibility
- [Phase 64]: [Phase 64-07] removeEntry is the ONE deliberate, scoped exception to QuickNotesVaultWriter's D-07 append-only rule -- documented directly above the function, runs only on an explicit rare user delete via temp-file+atomic-rename, never touches the append path
- [Phase 64]: [Phase 64-07] removeEntry's occurrence parameter (0-based) disambiguates byte-identical duplicate vault entries by rank; Plan 64-08 computes the correct occurrence from its own ordered note list before calling removeEntry
- [Phase 64]: [Phase 64-06] Delete-button hit-target regression required 3 failed hypotheses before root cause: AppKit's native NSScroller overlay physically consumes clicks in its overlap region — no SwiftUI gesture priority or scroll-indicator margin API could override it. Final fix (user-directed): widen popover 280->320pt, revert scrollbar to true trailing edge, move delete icon 36pt further left with contentShape scoped before the padding.
- [Phase 64]: [Phase 64-06] Menu-order fix needed the static menu's build order changed (New Note moved to item 0), not just the dynamic Clipboard History insertion index -- the selector-based relative insertion alone was insufficient since New Note was still built third.
- [Phase 64]: [Phase 64-06] Vault-file reconciliation (re-read .md file on popover open, prune notes deleted directly in vault) requested mid-plan as additional scope; deferred to Plan 64-08 rather than built in 64-06, since it is new functionality (not a regression against 64-06's locked spec) and 64-08 already owns vault-delete wiring plus the 64-07 read/enumerate contracts it needs.
- [Phase 64]: Quick Notes popover outside-click/app-switch dismiss needed two rounds: NSApplication.didResignActiveNotification (Cmd+Tab-style app switches) plus a global NSEvent mouse-down monitor (direct click on an already-visible background window), added in Plan 64-08 round 2 after on-device testing found the notification alone insufficient — A global monitor only ever receives events targeted at OTHER applications (Apple's documented contract), so it structurally cannot see clicks inside the popover's own hosted SwiftUI Menu — safe against regressing the Menu's own click handling
- [Phase 65]: [Phase 65-01] Quick Actions bar confirmed as a 5th switcher-tab catalog entry (D-01), resolved in the isExpanded tier alongside Calendar/Weather/Tray/Timer, never an ActiveTransient
- [Phase 65]: [Phase 65-02] CaffeinateToggleAction implemented as a static-state enum (not RESEARCH.md's class-instance example) per the plan's own locked deviation
- [Phase ?]: [Phase 65-04] @MainActor added to FocusToggleAction (blocking-fix): FocusModeMonitor.isAuthorized is itself MainActor-isolated, so the RESEARCH.md code example needed this to compile
- [Phase 65]: navCircleButton gained an optional tint param (default nil) to express DND/caffeinate/mic green-red icon states, keeping every other of its 15+ call sites byte-identical
- [Phase 65]: NotchWindowController.swift and IsletTests/NotchPillViewTests.swift touched beyond Plan 65-05's files_modified list (Rule 3): quickActionsBarFeedback is a non-defaulted stored property, so the app's one real NotchPillView construction site and all 3 test constructions needed the new argument to keep compiling
- [Phase 65]: [Phase 65-06] Task 1's build verification deferred to after Task 2 (same-file forward reference); commits split by git hunk rather than sequential coded-then-verified passes
- [Phase ?]: [Phase 65, 65-08]: FocusToggleAction.toggle now self-requests INFocusStatusCenter authorization instead of only reading FocusModeMonitor.isAuthorized -- DND no longer silently fails for users who never touched the unrelated Phase-38 Focus HUD Settings toggle
- [Phase ?]: [Phase 65, 65-08]: DND uses two fixed one-way Shortcuts (Islet Focus On / Islet Focus Off) selected at runtime from the already-read before state, since Shortcuts' Set Focus action has no native toggle mode -- confirmed working in both directions on-device
- [Phase ?]: [Phase 65]: All 8 Quick Actions confirmed working end-to-end on real hardware including the two previously-unconfirmed claims -- Screen Lock (RESEARCH.md A2) and DND/Focus (RESEARCH.md Open Question 1) -- QACTION-01/02/03 complete, phase ready for verification
- [Phase ?]: [Phase 67.1] islandAutoScaleFactor/resolvedIslandScale established as the single shared contract all three geometry call sites (Plans 02-04) must use for three-site parity by construction
- [Phase ?]: [Phase 67.1-02]: NotchPillViewTests.swift's hardcoded per-case width/height assertions rewritten to compute the live scale multiplier via the same pure production functions (islandAutoScaleFactor/resolvedIslandScale), since the plan's zero-regression acceptance criteria assumed a 1470pt-baseline test screen that doesn't hold on real hardware
- [Phase ?]: [Phase 67.1-07] D-13 implemented literally: manualOffset hardcoded to 0 at both Site 1 (NotchPillView) and Site 3 (NotchWindowController) in the same commit, verified by the same grep patterns in one acceptance_criteria block (threat T-67.1-10 mitigation)
- [Phase 67.1]: Wing width floor applied via max(1.0, resolvedWingWidthScale) at each of the 4 Plan 08 wing call sites (not clamped inside wingsShape), depth uses full range
- [Phase 67.1]: Plan 09: 6 hardware-camera-block wings scale only leadingPad/trailingPad (unclamped wScale/dScale), never cameraBlockWidth/margin/content — unlike Plan 08's Spacer()-based wings which floor at max(1.0, ...) on leftWidth/rightWidth directly
- [Phase 67.1]: [Phase 67.1-10] mediaWingContentWidth() returns a 3-tuple (left, right, cameraBlockWidth) instead of the plan's sketched 2-tuple, so mediaWingsRow never recomputes the camera-clearance formula independently (single source of truth); plan explicitly allowed either option.
- [Phase 66]: MenuBarOverflowController wired unconditionally into AppDelegate (no Settings toggle, D-02); public spacer-NSStatusItem technique replaces the NO-GO private-CGS approach from Plan 66-01

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
- v1.6 (Liquid Glass & System HUD Suite) roadmap created 2026-07-15: Phase 35 (Liquid Glass Material, GLASS-01), Phase 36 (Cosmetic Restyles & Signature Animation, HUD-01/02/EQ-01/ONBOARD-04), Phase 37 (Drop-Session Summary Chip, HUD-07), Phase 38 (Focus Mode HUD, HUD-05), Phase 39 (Volume & Brightness HUD, HUD-03/04), Phase 40 (Update-Available HUD & Sparkle Integration, HUD-06), Phase 41 (Calendar Countdown HUD, HUD-08), Phase 42 (Dual-Activity Display, DUAL-01) — 100% coverage (12/12). Phase numbering starts at 35 (not 34) to avoid colliding with v1.5's still-open, unarchived Phase 34. v1.5 remains open in parallel; both milestones' phases coexist on the live ROADMAP.md.
- v1.7 (Interaction & Calendar Polish) roadmap created 2026-07-19: Phase 43 (Drag Detection Hardening, DRAG-01), Phase 44 (Tray & Quick Action Width Alignment, TRAY-06/DRAG-02), Phase 45 (View Switcher Morph Fix, SWITCH-01/02), Phase 46 (Calendar Quick-Add Improvements, CALVIEW-05/06/07), Phase 47 (Audio Output Switcher — Pure Seam + Monitor, no formal REQ-ID), Phase 48 (Audio Output Switcher — UI Wiring, OUTPUT-01/02/03/04), Phase 49 (Favorite/Like — Spike, no formal REQ-ID), Phase 50 (Favorite/Like — Implementation, FAV-01/02/03) — 100% coverage (15/15). Phase numbering continues from Phase 42 (v1.6's last phase). v1.4 and v1.5 both remain open in parallel; all three milestones' phases coexist on the live ROADMAP.md.
- v1.8 (Settings Redesign & Island Navigation) roadmap created 2026-07-21: Phase 51 (Settings Reorganization & Scroll Fix, SETTINGS-02/03), Phase 52 (Top-Edge Switcher Layout & Placement Config, SWITCH-03/04), Phase 53 (Hover-to-Resume Idle Preview, RESUME-01/02) — 100% coverage (6/6). Phase numbering continues from Phase 50 (v1.7's last reserved phase, not yet executed) to avoid any collision with v1.4/v1.5/v1.7's still-open phases. Settings (51) and Switcher (52) restructure already-shipped subsystems (Phase 27 sidebar, Phase 28/45 switcher) independently of each other; Resume (53) is sequenced last since it carries this milestone's one open technical question (whether resuming a non-active track works via the existing NowPlayingMonitor/MediaRemote transport, per PROJECT.md's v1.8 Key Context).
- Phase 54 added 2026-07-21: Permissions Overview & Onboarding Replay (ARCH-P2) — promoted from the v2/backlog "carried from v1.4" requirements after v1.1's public release surfaced the need (user expected to be able to review granted permissions and re-request denied ones in Settings). Not yet part of any active milestone roadmap; phase numbering continues sequentially from Phase 53.
- v1.9 (Clipboard History) roadmap created 2026-07-22: Phase 55 (Clipboard Data Model + Store, no formal REQ-ID — infrastructure phase mirroring Phase 19/47/49 precedent), Phase 56 (Encrypted Persistence, CLIP-04/PRIV-02), Phase 57 (Pasteboard Monitor — Spike, PRIV-01), Phase 58 (Menu Wiring & UI Assembly, CLIP-01/02/03/05) — 100% coverage (7/7). Phase numbering continues from Phase 54 (v1.8's reserved phase) to avoid any collision with v1.4/v1.5/v1.7's still-open phases. Phase order follows research's own explicit "Build Order" recommendation and this project's established pure-seam-first/system-glue-second/assembly-last convention (Phase 19→20→21 Shelf, Phase 47→48 Audio Output): pure data model first (zero risk), then encrypted persistence (established from day one per Pitfalls 4/5, not retrofitted), then the one on-device-only pasteboard monitor spike (isolated so it can't destabilize the proven pure work), then menu wiring last (pure assembly, itself only meaningfully verifiable on-device).
- v1.10 (Live Activities Suite) roadmap created 2026-07-23: Phase 59 (Settings-Redesign, SETTINGS-04/05), Phase 60 (Caps Lock HUD + Update-Activity Restyle, CAPS-01/UPDATE-01), Phase 61 (Download-Progress, DL-01/02), Phase 62 (Timer/Pomodoro, TIMER-01..04), Phase 63 (Meeting-HUD, MEET-01..03), Phase 64 (Quick Notes + Obsidian Export, NOTES-01..03), Phase 65 (Quick Actions Bar, QACTION-01..03), Phase 66 (Menübar-Overflow, MENUBAR-01..04), Phase 67 (Coding-Progress, CODE-01..04) — 100% coverage (27/27). Phase numbering continues from Phase 58 (v1.9's last phase). Order follows research's explicit foundation-first/ascending-risk build order: Settings-grid foundation first (avoids retrofitting Settings onto the first feature, the exact mistake v1.8 already fixed once), then cheapest-pairing (Caps Lock + Update restyle) to prove the new card pattern, then Download-Progress (first FSEvents watcher, proven once before Coding-Progress reuses it), then Timer/Pomodoro (generalizes `TransientQueue.preempt()`/`ActiveTransient.isPersistent` beyond the Focus-Mode-only case on the simpler no-detection-risk case), then Meeting-HUD (reuses that generalized path, gated behind its own call-detection spike), then Quick Notes (resolves the 4-slot top-edge-switcher conflict in its own planning), then Quick Actions bar (reuses Meeting-HUD's `MicMuteController`), then Menübar-Overflow (isolated last among the notch-facing work as the milestone's highest-novelty, zero-reuse feature, own feasibility spike against Ice's actual source), then Coding-Progress (reuses Phase 61's FileWatcher pattern, own hook-contract research step).
- Phase 68 added 2026-07-26: App Switcher / Window Previews — DockDoor-inspired (dockdoor.net) Windows-style Alt+Tab replacement with live per-app window thumbnails and minimized-window restore, via ScreenCaptureKit + Accessibility API. User-requested, sequenced as the last phase after all currently open v1.10 phases (59-67). No formal REQ-ID yet, not part of the milestone's original 27/27 requirement coverage — needs its own `/gsd-discuss-phase 68` before planning.
- Phase 69 added 2026-07-26: Claude Session Usage Display — Now-Playing-style notch expansion showing live Claude Code usage when a session is active: 5-hour limit + reset countdown on the left, weekly limit fill/percentage on the right, configurable update interval (5-min poll or live). Data sourcing intended to build on a separate usage-tracking tool/script the user already started, source at `/Users/lippi304/AI-OS/OS/5. Claude Usage Tracker` — reuse/port its usage-fetching logic instead of rebuilding it. User-requested, sequenced as the last phase after Phase 68. No formal REQ-ID yet, not part of the milestone's original 27/27 requirement coverage — needs its own `/gsd-discuss-phase 69` before planning.
- Phase 67.1 inserted after Phase 67: Notch Size Scaling — Resolution-Aware + Manual Override: user changed screen resolution and the notch island now looks too small; adds auto-scaling of island width/depth to display resolution/DPI plus a manual Settings fine-tune override. User-requested, sequenced before Phase 68. (URGENT)

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

- [ui] Tray panel oversized vertically, shrink to fit content — `.planning/todos/pending/2026-07-14-tray-panel-oversized-vertically-shrink-to-fit-content.md`

### Blockers/Concerns

[Issues that affect future work]

- [Carried, pre-existing] Phase 2's 8 on-device UAT scenarios (`02-HUMAN-UAT.md`) remain unexercised since v1.0 close — unrelated to v1.1/v1.2/v1.3/v1.4/v1.5/v1.6/v1.7 scope, still open. Revisit via `/gsd:verify-work 2` if desired.
- [v1.4, pending] 2 items in `28-HUMAN-UAT.md` remain pending final on-device re-confirmation of the two code-review fixes; run `/gsd:verify-work` for v1.4 once confirmed, then `/gsd:complete-milestone` for v1.4 whenever convenient — does not block starting v1.5/v1.6/v1.7 phase work.
- [v1.5, from research] Quick Action picker precedence tier (Phase 34) — whether a Charging/Device transient interrupts an open picker or queues behind it is an explicit open product decision, not yet resolved; flag for `/gsd-discuss-phase 34` before that phase's planning.
- [v1.5, from research] `NSSharingService`/`NSSharingServicePicker` behavior from Islet's permanently non-key `NotchPanel` is unverified in this codebase (WebSearch-corroborated only) — Phase 34 must spike this in isolation before committing to the full picker plan.
- [v1.5, from research] NotchShape flare (Phase 29) has an open geometry question — whether the flare stays inside the existing panel-frame reservation or needs the panel to grow upward past `screenFrame.maxY` — resolve via a quick on-device check during Phase 29 planning/execution.
- [v1.5, from research] Weather (Phase 33) has two open questions to resolve during its own planning: whether the compact card's H/L needs `fetchCurrent` itself to change, and whether the extended forecast card fits inside the existing 196pt `switcherContentHeight` shared constant (also used by Home/Calendar/Tray) or requires it to grow.
- [v1.6, from research] Liquid Glass reference code (Phase 35) not yet reviewed — whether it targets `.glassEffect()`/`NSGlassEffectView` (macOS 26+, requires a deployment-target bump from today's 15.0 floor) or a materials/gradient-composition fallback (15+, no bump) is unresolved; surface explicitly in `/gsd-discuss-phase 35`.
- [v1.6, user-reported 2026-07-15] Expand animation regression — the island no longer morphs smoothly/elegantly out of the camera/notch position; it now animates diagonally from top-left toward bottom-right and bounces off the screen edge. Root cause unknown; suspected to have crept in during one of the recent geometry-touching phases (29 Flare, 32 Tray Widening, or 33 Weather). User explicitly wants this folded into Phase 35 (Liquid Glass Material) rather than handled as a separate debug/quick-fix — raise and diagnose during `/gsd-discuss-phase 35`.
- [v1.6, from research] Focus Mode detection (Phase 38) has no supported public API for generic on/off beyond `INFocusStatusCenter`; the richer Assertions.json path requires a manual, unprompted Full Disk Access grant with zero automatic TCC prompt — UX acceptability must be confirmed via the phase's own on-device spike before scope is locked.
- [v1.6, from research] Volume/Brightness OSD suppression (Phase 39) is undocumented/private-API territory with a confirmed macOS-Tahoe-specific regression mode (wrong `CGEventTap` variant breaks transport keys system-wide) — must be independently re-confirmed on this project's own dev machine during the phase's own spike, not assumed transferable from the reference app (Droppy).
- [v1.6, from research] Update-available HUD's UI shape (badge vs. custom in-notch driver) is an open design decision for Phase 40 — default to Sparkle's standard alert + a simple badge, revisit a custom `SPUUserDriver` only if that proves insufficient on-device.
- [v1.6, from research] Dual-activity display's (Phase 42) exact promotion/demotion rules are not yet specified as data — phase planning must produce an explicit ordered rule table before implementation.
- [v1.7, from research] Spotify's 2025 policy caps unapproved OAuth apps at 5 total allowlisted users (Development Mode) — Phase 49's spike must confirm current quota-mode criteria directly on the Spotify Developer Dashboard before Phase 50 commits to a shared-Client-ID design; be ready to descope Spotify to Apple-Music-only.
- [v1.7, from research] Whether the vendored `mediaremote-adapter` wrapper's `MediaController` exposes sending a like/love command at all is undocumented in any research pass — Phase 49 must spike it directly (worst case: patch the wrapper's own command table, contained to `NowPlayingMonitor.swift`).
- [v1.7, from research] The Automation (Apple Events/TCC) permission prompt has a documented reliability bug (can silently fail to appear; target app can vanish from System Settings → Automation after idle) — Phase 49 must reproduce or rule this out and Phase 50 needs a distinct "couldn't verify"/recovery UI state for it, not just denied/granted.
- [v1.7, from research] Apple Music's `current track` AppleScript reference is documented-broken for streamed (not-yet-in-library) tracks — Phase 49 must spike against a library track, a streaming-only track, and both play/pause states before Phase 50 builds the star button around it.
- [Phase 43 regression gate, pre-existing, unrelated] `DragApproachGeometryTests.testOffsetIsIdenticalOnNonZeroOriginCard` (Phase 34) fails deterministically (not flaky — reproduces identically every run) due to floating-point catastrophic cancellation when subtracting two large near-equal `CGFloat`s (`150.66666666666674` vs `...69`). Confirmed unrelated to Phase 43 — `computeQuickActionButtonFrames` was never touched by this phase. Fix (when picked up): use `XCTAssertEqual(..., accuracy: 0.01)` like the file's other geometry tests already do, instead of exact equality.
- [Quick debug, 2026-07-19] Old Islet instance occasionally survives Xcode's Stop button (documented Apple Developer Forums limitation for LSUIElement/background-agent apps, thread 47777), producing a duplicate menu-bar icon needing manual quit. Fixed via a single-instance guard in `AppDelegate.applicationDidFinishLaunching` (force-terminates any other process sharing Islet's bundle ID as the first action on launch) — build-verified but **on-device Xcode stop/restart verification is pending**. User explicitly deferred a dedicated test pass, will confirm organically during upcoming phase work. Session: `.planning/debug/old-islet-instance-stays-open.md`.
- Phase 66 BLOCKED: 66-04 on-device checkpoint NO-GO — public NSStatusItem spacer mechanism does not reclaim/hide layout space and Cmd-drag does not engage the chevron on real macOS 27 Tahoe beta hardware. Needs /gsd:discuss-phase 66 before phase closes.

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
| 260715-vsd | Drei UI-Spacing/Sizing-Fixes: Calendar Add-button overflow fixed on first try; Now Playing/Tray spacing needed 5 gap-closure rounds — a nested debug session found `trayEmptyState` was unreachable (demo shelf re-seeded every Debug launch), then Home (idle/playing/unavailable) got its own 170pt content-hugging box instead of the shared 196pt one, matching the precedent Tray/Weather already set | 2026-07-16 | 2c7904f | Complete ✓ (on-device confirmed — "passt") | [260715-vsd-drei-kleine-ui-spacing-sizing-fixes-now-](./quick/260715-vsd-drei-kleine-ui-spacing-sizing-fixes-now-/) |
| 260725-hnu | Drei vorbestehende Test-Failures (unabhängig von Phase 63) behoben: `defaultQuickAddTime` benutzte `isDateInToday` statt des injizierten `now` (Funktion jetzt rein — Produktionsverhalten unverändert, einziger Call-Site übergibt `Date()`); Clipboard-Orphan-Test verglich Ciphertext-Bytes, die wegen frischer AES-GCM-Nonce pro Save nie gleich sein können (jetzt Klartext-Vergleich nach Entschlüsselung); `systemHUDCardsCount` 8→9 und `suffix(3)`→`suffix(4)` (stale seit `95581c4`, Karte `capsLock` war ungeprüft) | 2026-07-25 | cf17509 | Complete ✓ (volle Suite: 529 Tests, 0 Failures) | [260725-hnu-fix-3-pre-existing-failing-unit-tests-pu](./quick/260725-hnu-fix-3-pre-existing-failing-unit-tests-pu/) |
| 260728-wg7 | DEBUG-only "Wing Tuner" mechanism: 4 live nudge axes (Leading/Trailing/Margin/Gap) in the 🐞 debug menu adjust every collapsed-state HUD wing's padding/camera-clearance live on real hardware (mirrors the existing `islandWidthScaleOffset` @AppStorage pattern), plus Reset and a console-print export — replaces slow guess-rebuild-report cycles for wing icon/text alignment. Wired into 12 of 13 wing functions (Meeting wing's `margin`/`iconGap` excluded — load-bearing for a click-through-zone assert). Zero effect on Release builds (verified). | 2026-07-28 | 29bc339 | Partially confirmed on-device — Now Playing/OSD nudges worked; DND (Focus) had no `margin` constant to nudge, gap closed by follow-up 260729-0b5 | [260728-wg7-debug-only-live-tuning-mode-for-collapse](./quick/260728-wg7-debug-only-live-tuning-mode-for-collapse/) |
| 260729-0b5 | Wing Tuner follow-up: fixed DND/Focus wing's missing `margin` constant (replaced its un-nudgeable `Spacer()` with an explicit nudgeable value, `leftWidth`/`rightWidth` unchanged); added Margin ±10/±20 step buttons (now -20/-10/-5/+5/+10/+20); new "Preview Wing" submenu (12 actions) fake-triggers every collapsed wing on demand via existing `NotchWindowController` handlers (8 widened `private`→internal mirroring `handleUpdateAvailable`'s precedent, 2 new thin coordinator wrappers); decluttered 🐞 debug menu from 13 flat items down to 3 + 2 submenus, removing 10 one-off "Spike:" items tied to already-completed/paused phases. | 2026-07-28 | 91ebbba | Partially confirmed on-device — Meeting's Margin nudge still did nothing, gap closed by round 3 (260729-0zh) | [260729-0b5-wing-tuner-follow-up-per-wing-debug-prev](./quick/260729-0b5-wing-tuner-follow-up-per-wing-debug-prev/) |
| 260729-0zh | Wing Tuner round 3: fixed Meeting wing's Margin nudge (`meetingWingMargin` converted from `static let` to a DEBUG-aware computed `static var` reading the existing nudge key directly via `UserDefaults` — statics can't use `@AppStorage` — keeping the render path and `NotchWindowController`'s click-through hit-test zone in sync by construction, no desync risk); previewed non-persistent wings (Charging, Device, Caps Lock, OSD Volume, OSD Brightness, Update, Countdown) now cancel their own auto-dismiss timer so they stay visible indefinitely instead of vanishing after ~1.5-3s; "Reset Wing Tuner" now also force-clears whatever's being previewed back to idle, in addition to zeroing the 4 nudge values. Zero effect on real (non-preview) activities or Release builds. | 2026-07-28 | 5fa2dd5 | Confirmed via full on-device pass — final tuned deltas + 3 new bugs reported, closed by round 4 (260729-2td) | [260729-0zh-wing-tuner-round-3-fix-meeting-margin-sh](./quick/260729-0zh-wing-tuner-round-3-fix-meeting-margin-sh/) |
| 260729-2td | Wing Tuner round 4: baked in final on-device-tuned constants for 5 wings (Now Playing, OSD, Meeting, Caps Lock, Download — Caps Lock's trailingPad floored to 2, the reported delta went negative, flagged for live recheck); converted Focus/DND and Device wings from fixed-footprint to the same notch-cutout-derived margin+cameraBlockWidth formula every other wing uses, so Margin now actually resizes the visible island on both (previously only shifted inner content or did nothing); fixed 3 bugs found during testing — Charging preview now forces a real AC-transition so it reliably shows regardless of the dev machine's actual power state, Update wing's "Update" label widened 38→54 to stop truncating to "Upd…", Timer preview now bypasses the Timer Settings toggle (DEBUG-only, real triggers unaffected) so it works even when Timer is disabled. | 2026-07-28 | cf062e1 | Confirmed on-device (Focus/Update/Charging/Device tuning + first-ever look at Charging); DND/Update final deltas + a full Charging/Device visual redesign followed in round 5 (260729-3pc) | [260729-2td-wing-tuner-round-4-bake-in-final-tuned-c](./quick/260729-2td-wing-tuner-round-4-bake-in-final-tuned-c/) |
| 260729-3pc | Wing Tuner round 5: baked in DND/Focus (margin+20, leading+4, trailing-4) and Update (leading+4, trailing+4) final tuned deltas; redesigned the Charging wing per the user's first-ever look at it (a round-4 bug had blocked it from appearing before) — removed the green bolt.fill icon + "Charging" text, now a single plain-white `powerplug.fill` icon + a plain-white `BatteryIndicator` (fill bar + % number, low-battery red/orange override unchanged); redesigned the Device wing to match — fixed `dot.radiowaves.left.and.right` icon (closest available "Bluetooth icon", replacing the per-device-type AirPods/Beats/headphones glyphs) in plain white, plain-white `BatteryIndicator` for the battery-reading state (green-ring/xmark fallback states unchanged); deleted the now-dead `deviceSymbol(for:)` mapping function. Flagged: Settings' Charging/Device accent swatches no longer visibly affect either wing (both intentionally plain white now); "no green tint anywhere" was a deliberate, flagged interpretation pending user confirmation. | 2026-07-28 | bfa1635 | Confirmed DND on-device; corrected by round 6 (260729-47v) — battery fill reverted to green, Charging's Margin mechanism was found broken, Device icon needed to be the real Bluetooth glyph | [260729-3pc-wing-tuner-round-5-bake-in-dnd-update-fi](./quick/260729-3pc-wing-tuner-round-5-bake-in-dnd-update-fi/) |
| 260729-47v | Wing Tuner round 6: reverted `BatteryIndicator`'s fill from white (round 5) back to green on both Charging and Device (outline/% text were already hardcoded white in the component, untouched); converted the Charging wing from its old fixed-half + `Spacer()` layout onto the same margin+cameraBlockWidth formula Focus/Device already use — this was the one remaining wing whose Margin/Leading/Trailing nudges had zero effect since it was never converted in round 4; replaced Device wing's generic `dot.radiowaves.left.and.right` SF-Symbol stand-in with a hand-drawn Bluetooth bind-rune `Path` glyph (first-pass approximation, not pixel-verified against the official logo — flagged for on-device confirmation) and removed the "Connected" text entirely (icon-only left flank in every state). | 2026-07-28 | a66ec4e | Confirmed via on-device pass — corrected by rounds 7-8 (260729-4oi): user supplied a real Bluetooth icon instead of the hand-drawn glyph, and asked to redesign Charging further | [260729-47v-wing-tuner-round-6-battery-fill-green-no](./quick/260729-47v-wing-tuner-round-6-battery-fill-green-no/) |
| 260729-4oi | Wing Tuner rounds 7-8 (grew across 3 feedback waves in one session): baked in Charging's tuned deltas, then replaced Device's hand-drawn Bluetooth `Path` with the user's own supplied reference icon (`Assets.xcassets/BluetoothGlyph.imageset`, template-rendered); redesigned Charging to a single `battery.100.bolt` icon with no percentage number at all (consolidating the plug+BatteryIndicator into one glyph, per user request — SF Symbol name not yet on-device-confirmed); baked in Timer's tuned deltas; converted Countdown (the last wing still on the old fixed-half+Spacer() mechanism) to the same margin+cameraBlockWidth formula every other wing now uses, closing the "Margin does nothing" gap there too. Every collapsed-state wing now supports live Margin tuning identically. | 2026-07-29 | d4a4940 | Confirmed on-device — corrected by round 9 (260729-4yy): Charging needed a text label back, Bluetooth icon needed enlarging | [260729-4oi-wing-tuner-round-7-bake-in-charging-fina](./quick/260729-4oi-wing-tuner-round-7-bake-in-charging-fina/) |
| 260729-4yy | Wing Tuner round 9: re-added a "Charging..." text label to the Charging wing's right side (the lone battery+bolt icon wasn't enough on its own); enlarged the Device wing's Bluetooth icon (inner scale 0.7→0.98, i.e. current size × 1.4 per the user's explicit ask); baked in Countdown's final tuned deltas (margin +25, leading +6, trailing -18), confirming round 8's margin/cameraBlockWidth conversion works correctly. Timer confirmed good with no further changes. | 2026-07-29 | 0d66956 | Superseded — Charging/Device needed one more tuning pass after their text/icon-size changes, done in round 10 (260729-54f); Countdown confirmed good as-is | [260729-4yy-wing-tuner-round-9-charging-text-back-bl](./quick/260729-4yy-wing-tuner-round-9-charging-text-back-bl/) |
| 260729-54f | Wing Tuner round 10: baked in Charging's (margin +25, leading +6, trailing -14) and Device's (margin -5, leading +4, trailing +6) final tuned deltas after round 9's text/icon-size changes. User declined a further on-device checkpoint ("kein Test") — the Wing Tuner series (260728-wg7 through this) is considered done for now; every collapsed-state wing has gone through at least one full live-tuning pass. | 2026-07-29 | 81237e1 | Complete — user declined further checkpoint | [260729-54f-wing-tuner-round-10-charging-and-device-](./quick/260729-54f-wing-tuner-round-10-charging-and-device-/) |
| 260729-57h | Disabled Phase 66's (Menü-Bar-Overflow, paused) chevron — it was being constructed and started unconditionally at every launch (no Settings toggle, no gate) despite the phase's mechanism not working, so it kept appearing in the menu bar for no purpose. Commented out the 2-line construction+start in `AppDelegate.swift`, left `MenuBarOverflowController.swift`/`MenuBarOverflowBridging.swift` and the property declaration in place (paused, not dropped, matching the Phase 49/50 precedent) — a fresh `/gsd-discuss-phase 66` would just need to un-comment these 2 lines to resume. | 2026-07-29 | 743f2a7 | Complete — user declined checkpoint | [260729-57h-disable-phase-66-menu-bar-overflow-chevr](./quick/260729-57h-disable-phase-66-menu-bar-overflow-chevr/) |
| 260729-5jc | Added a plain percent number (0-100, no "%" sign) to the right of the OSD (Brightness/Volume) collapsed wing's level bar in `osdWings(for:)`, reusing the already-computed `percent` value. New fixed `percentGap` (4pt) + `percentTextWidth` (22pt) constants widen `totalWidth`/`rightWidth` so the capsule grows to fit the text instead of squeezing it into the existing trailing pad; text is `.monospaced`, white, no new DEBUG nudge axis (reuses existing `wingTrailingNudge`-driven `trailingPad`). User will live-tune exact spacing/width on-device via the existing Wing Tuner debug menu. | 2026-07-29 | c068ce6 | Baseline in — pending on-device Wing Tuner pass | [260729-5jc-add-percent-number-text-no-sign-to-the-r](./quick/260729-5jc-add-percent-number-text-no-sign-to-the-r/) |
| 260729-5pv | Follow-up polish on 260729-5jc: raised `percentGap` from 4pt to 10pt, and gave the percent `Text` a `.contentTransition(.numericText(value:))` plus its own local spring animation (reusing `OSDLevelBar`'s existing spring constants) so the digit swap between old/new values rolls+fades smoothly instead of a hard cut. | 2026-07-29 | 14be79a | Baseline in — pending on-device Wing Tuner pass | [260729-5pv-smooth-number-transition-10pt-gap-for-os](./quick/260729-5pv-smooth-number-transition-10pt-gap-for-os/) |
| 260729-5vl | Baked in on-device Wing Tuner deltas for the OSD wing (post percent-number addition): `margin` 40→60 (+20), `trailingPad` base 24→18 (-6); `iconLeadingPad`/gap constants untouched (deltas were 0). | 2026-07-29 | ad29508 | Complete — on-device tuned | [260729-5vl-bake-in-osd-wing-tuning-deltas-margin-20](./quick/260729-5vl-bake-in-osd-wing-tuning-deltas-margin-20/) |

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

**v1.4 close (pending):** All 6 phases (23-28) code-complete; 2 items in `28-HUMAN-UAT.md` await final on-device re-confirmation before `/gsd:complete-milestone` formally closes v1.4. Not blocking v1.5/v1.6/v1.7 phase work.

**v1.6 close (2026-07-19):** `gsd-sdk query audit-open` flagged 21 items; all acknowledged and deferred, none blocking v1.6's own scope (Phases 35-42, all shipped and on-device UAT'd):

| Category | Item | Status |
|----------|------|--------|
| debug_session | knowledge-base | unknown — untriaged, no further detail available; acknowledged rather than investigated |
| quick_task | 260705-l4i, 260705-mzj, 260708-nnu, 260708-nzj, 260708-ol8, 260708-u47, 260709-glz, 260709-gvy, 260714-3k6, 260715-vsd | missing (same tool status-detection false positive as v1.2/v1.3 close — all have completed PLAN.md + SUMMARY.md on disk) |
| uat_gaps | Phase 21, Phase 27, Phase 36 | resolved, 0 pending scenarios — not real open work |
| uat_gaps | Phase 28 | partial, 2 pending — pre-existing carry from v1.4, unrelated to v1.6 scope (see v1.4 close note above) |
| uat_gaps | Phase 35 | partial per tool, but 0 pending scenarios listed — false positive |
| verification_gaps | Phase 20, Phase 27, Phase 28, Phase 36 | human_needed — pre-existing/unrelated to v1.6 scope, several already covered by their own phase's on-device UAT checkpoint per this project's established precedent |
| verification_gaps | Phase 38 | gaps_found — stale record from before 38-09's gap-closure plan; 38-09-SUMMARY.md documents the on-device UAT that closed the two defects found (missing NSFocusStatusUsageDescription key, missing Communication Notifications entitlement); all 4 ROADMAP Success Criteria confirmed |

Additionally, REQUIREMENTS.md traceability was corrected during v1.6 close: HUD-05 (Phase 38) and HUD-06 (Phase 40) were still marked "Pending" despite both phases shipping and passing on-device UAT — updated to Complete. HUD-07 (Phase 37) was marked "Pending" but Phase 37 was abandoned/reverted after on-device UAT rejection — updated to "Dropped" (not counted toward shipped coverage). Root cause: phases 38-41's own completion runs skipped their REQUIREMENTS.md traceability update step.

**v1.8 close (2026-07-21):** `gsd-sdk query audit-open` flagged 21 items; user chose "Acknowledge all" and proceed. None block v1.8's own scope (Phases 51-53, all shipped and on-device UAT'd):

| Category | Item | Status |
|----------|------|--------|
| debug_session | knowledge-base | unknown — untriaged, no further detail available; acknowledged rather than investigated (same as v1.6 close) |
| debug_session | old-islet-instance-stays-open | awaiting_human_verify — hypothesis CONFIRMED (Xcode Stop button doesn't reliably terminate LSUIElement/background-agent apps), single-instance-guard fix already build-verified per STATE.md Blockers/Concerns; only the on-device Xcode stop/restart re-check remains, user explicitly deferred to organic confirmation during future work |
| quick_task | 260705-l4i, 260705-mzj, 260708-nnu, 260708-nzj, 260708-ol8, 260708-u47, 260709-glz, 260709-gvy, 260714-3k6, 260715-vsd | missing (same recurring tool status-detection false positive as v1.2/v1.3/v1.6 close — all 10 have completed PLAN.md + SUMMARY.md on disk, logged Complete ✓ in the Quick Tasks Completed table above) |
| todos | 2026-07-19-calendar-month-grid-polish, 2026-07-19-island-briefly-disappears-during-click-through, 2026-07-19-quick-action-disabled-state-has-no-controller-gate | pending — pre-existing UI polish/bug notes captured during v1.7 work, unrelated to v1.8 scope; revisit via `/gsd-quick` or a future phase as desired |
| uat_gaps | Phase 21, Phase 27 | resolved, 0 pending scenarios — not real open work |
| uat_gaps | Phase 28 | partial, 2 pending — pre-existing carry from v1.4 (see v1.4 close note above), unrelated to v1.8 scope |
| verification_gaps | Phase 20, Phase 27, Phase 28 | human_needed — pre-existing/unrelated to v1.8 scope, carried from earlier milestones |

**v1.9 close (2026-07-23):** `gsd-sdk query audit-open` flagged 22 items; user chose "Acknowledge all" and proceed. None belong to v1.9's own scope (Phases 55-58, all shipped and on-device UAT'd):

| Category | Item | Status |
|----------|------|--------|
| debug_session | knowledge-base | unknown — untriaged, no further detail available; acknowledged rather than investigated (same as v1.6/v1.8 close) |
| debug_session | old-islet-instance-stays-open | awaiting_human_verify — hypothesis CONFIRMED, fix already build-verified, on-device Xcode stop/restart re-check still deferred (same as v1.8 close) |
| quick_task | 260705-l4i, 260705-mzj, 260708-nnu, 260708-nzj, 260708-ol8, 260708-u47, 260709-glz, 260709-gvy, 260714-3k6, 260715-vsd | missing (same recurring tool status-detection false positive as prior milestone closes — all 10 have completed PLAN.md + SUMMARY.md on disk) |
| todos | 2026-07-19-calendar-month-grid-polish, 2026-07-19-island-briefly-disappears-during-click-through, 2026-07-19-quick-action-disabled-state-has-no-controller-gate | pending — pre-existing UI polish/bug notes, unrelated to v1.9 scope |
| uat_gaps | Phase 21, Phase 27 | resolved, 0 pending scenarios — not real open work |
| uat_gaps | Phase 28 | partial, 2 pending — pre-existing carry from v1.4, unrelated to v1.9 scope |
| verification_gaps | Phase 20, Phase 27, Phase 28 | human_needed — pre-existing/unrelated to v1.9 scope, carried from earlier milestones |
| verification_gaps | Phase 54 | gaps_found — Phase 54 (Permissions Overview & Onboarding Replay) is not part of any milestone yet; its own 54-04 on-device UAT checkpoint is still pending, unrelated to v1.9 |

## Session Continuity

Last session: 2026-07-28T09:01:41.415Z
Stopped at: Phase 66 UI-SPEC approved (CGS-debug pivot)
Resume file: .planning/phases/66-men-bar-overflow-ice-style-mvp/66-UI-SPEC.md

## Operator Next Steps

- **Phase 64 (Quick Notes + Obsidian Export) is now fully complete, closed 2026-07-25 without a formal `/gsd:verify-work 64` pass (user decision).** All 8 plans done (64-01..64-08), NOTES-01/NOTES-02/NOTES-03 shipped. `--gaps-only` execution closed 3 gap-closure plans this session: 64-06 (popover focus, delete hit-target, menu order + separator, ⌘⏎ save hint — 4 on-device UAT rounds, several dead-end fix attempts before the real root causes: an AppKit scroll-indicator gutter overlap, not gesture priority), 64-07 (vault-delete + file-enumeration primitives), and 64-08 (multi-file picker, "New File…" creation, vault-delete wiring, vault↔app sync reconciliation, per-file note filtering, and a background-window popover-dismiss fix that needed a global `NSEvent` monitor layered on top of `NSApplication.didResignActiveNotification` — 3 on-device UAT rounds). 64-05 (the original on-device UAT plan) has no standalone `SUMMARY.md`; its manual verification scope (focus, TCC vault access, mid-write survival) was carried out live across 64-06's rounds instead. User explicitly judged formal verify-work redundant given 7 combined on-device checkpoint rounds already exercised every phase success criterion; user also declined a post-execution code review for now given the amount of live-UAT churn (several superseded fix attempts, a new global event-monitor lifecycle) — worth a `/gsd-code-review 64` pass later if this file sees more changes. v1.10 now 5/9 phases shipped (59, 60, 61, 62, 64). Phase 63 (Meeting-HUD) has all 4 plans executed (2026-07-25) but is still awaiting its own orchestrator phase-level closure gates — separate from this Phase 64 closure. Once 63 is closed too, next up is `/gsd-discuss-phase 65` (Quick Actions Bar).
- **Phase 61 (Download-Progress) is now fully complete and formally verified, shipped 2026-07-24.** All 5 plans (61-01..61-05) done, on-device UAT approved across all 11 checklist steps and all 4 ROADMAP Success Criteria — DL-01/DL-02 shipped. Post-execution code review (`61-REVIEW.md`) then found 1 blocker (CR-01: a completed download's spinner could get stuck if a Charging/Device transient was head at completion — same root-cause family as the earlier cancel bug, different trigger path) plus 3 warnings (WR-01 nil-renamedTo reconciliation, WR-02 dead filename now surfaced via accessibilityLabel, WR-03 unbounded pendingRenamesByFileID now capped) — all fixed same session (`e8a552c`), 3 new regression tests added (101/101 scoped tests green). `/gsd:verify-work 61`-equivalent formal verification (`61-VERIFICATION.md`) then ran: initially `human_needed` for 2 items (CR-01's exact race condition never re-checked on-device after the fix; scoped-test pass/fail not confirmed post-fix in that sandboxed session) — both resolved same session (user re-tested the exact CR-01 interleaving on real hardware, "approved"; fresh 101/101 test run confirmed from the orchestrator session) — status upgraded to `passed`. v1.10 now 3/9 phases shipped (59, 60, 61). Start `/gsd-discuss-phase 62` (Timer/Pomodoro) next.
- **v1.10 (Live Activities Suite) roadmap created 2026-07-23.** 9 phases (59-67) defined in `.planning/ROADMAP.md`, 27/27 requirements mapped (100% coverage) in `.planning/REQUIREMENTS.md`. Phases 59-61 shipped; start with `/gsd-discuss-phase 62` next.
- **v1.9 (Clipboard History) SHIPPED 2026-07-23.** All 4 phases (55-58) archived to `.planning/milestones/v1.9-ROADMAP.md`/`.planning/milestones/v1.9-REQUIREMENTS.md`. 7/7 requirements shipped. v1.4, v1.5, and v1.7 all remain open in parallel — pick one back up, or start a fresh milestone with `/gsd-new-milestone`.
- **Phase 54 decision-coverage gate overridden (2026-07-22).** `check.decision-coverage-plan` flagged D-01 through D-11 as not cited inside any plan's `must_haves.truths` block (only D-12/D-13 are). Manual review confirmed all 13 decisions ARE implemented and referenced in plan task bodies/acceptance criteria (grep-verified, and gsd-plan-checker's semantic review independently confirmed all 13 decisions correctly implemented) — user chose "Proceed anyway" since this is a must_haves-phrasing gap, not a missing feature. Re-surface at `/gsd:verify-work 54` if in doubt.
- **Phase 54 gap-closure plan (54-04-PLAN.md) created 2026-07-22** to close 54-VERIFICATION.md's 2 FAILED truths (gaps_found, 8/11). Re-running `check.decision-coverage-plan` against the phase directory (now including 54-04) re-surfaced the same D-01..D-11 override above — 54-04 doesn't touch any of those original-feature decisions, it only fixes CR-01 (Bluetooth grant bypassing the Devices toggle), CR-02 (Location grant not reaching `startLocationOnce()`), CR-03 (`replayOnboarding()` missing `updateVisibility()`), and WR-01 (Focus grant callback discarded). Passed plan-checker verification in iteration 2 (0 blockers, 0 warnings) with an added on-device checkpoint covering all 4 fixes at runtime. Next: `/gsd:execute-phase 54 --gaps-only`.
- **v1.8 (Settings Redesign & Island Navigation) SHIPPED 2026-07-21.** All 3 phases (51-53) archived to `.planning/milestones/v1.8-ROADMAP.md`/`.planning/milestones/v1.8-REQUIREMENTS.md`. 6/6 requirements shipped. Start a fresh milestone for new work with `/gsd-new-milestone` — but note v1.4, v1.5, and v1.7 all remain open in parallel below; picking those back up does not require a new milestone.
- **v1.7 (Interaction & Calendar Polish):** 6/8 phases complete (43/44/45/46/47/48), Phase 49 (Favorite/Like spike) paused after weak SC#1/SC#2 spike results per user decision; Phase 50 needs reconsideration before planning. Phase order: Drag Detection Hardening (43, done) → Tray & Quick Action Width Alignment (44, done) → View Switcher Morph Fix (45, done) → Calendar Quick-Add Improvements (46, still open) — the 4 independent bugfixes — then Audio Output Switcher split pure-seam-first (47, done) then UI wiring (48, done), then Favorite/Like split spike-first (49, paused) then implementation (50, on hold).
- **Phase 48 (Audio Output Switcher — UI Wiring) is fully complete.** All 3 plans done, on-device UAT approved ("approved" after the drag-animation-choppiness fix). OUTPUT-01..04 shipped.
- **Phase 47 (Audio Output Switcher — Pure Seam + Monitor) is now fully complete.** All 3 plans (47-01 pure seam, 47-02 monitor, 47-03 on-device verification) done. 47-03's on-device checkpoint surfaced and fixed a real HAL "wrong data size" bug in `resolveDeviceID(uid:)` (qualifier-data pattern fix), then re-confirmed clean: Pitfall 4 (UID stability across a Bluetooth reconnect) and Pitfall 8 (confirmed-after-set switch) both hold on real hardware; `hasVolumeControl` recorded for 4 device types (built-in/Bluetooth/USB=true, external monitor=false) as Phase 48's authoritative slider input. Known scope limitation: D-03 asked for 2 distinct Bluetooth devices, only 1 was available — user-confirmed and accepted. See `47-03-SUMMARY.md`.
- **Phase 47 Plan 01 (Audio Output Presentation seam) is now complete.** `AudioOutputDevice`, `isOutputCapableDevice(outputChannelCount:)` (D-01), and `sortedAudioOutputDevices(_:)` (D-02) are all implemented, unit-tested (9 tests), Foundation-only, Debug build + test-build both green. See `47-01-SUMMARY.md`.
- **Phase 45 (View Switcher Morph Fix) is now fully complete.** Both plans (45-01 structural fix, 45-02 on-device 12-pairwise verification) done; SWITCH-01/SWITCH-02 shipped. 45-02's own on-device checkpoint directly covered Phase 45's ROADMAP success criteria, so a separate `/gsd:verify-work 45` pass is not needed (per this project's Phase 29/36/38/39 precedent).
- **v1.6 (Liquid Glass & System HUD Suite) shipped 2026-07-19.** All 8 phases (35-42) archived to `.planning/milestones/v1.6-ROADMAP.md`/`.planning/milestones/v1.6-REQUIREMENTS.md`. 11/12 requirements shipped; HUD-07 dropped (Phase 37 abandoned). PROJECT.md fully updated, including backfilled Validated write-ups for Phases 38-41 whose own runs had skipped that step. v1.5 (Home Focus & Widget Redesign) remains open in parallel — only Phase 33's on-device UAT (Task 4) is outstanding before it can formally close too; run `/gsd-verify-work 33` once that's done, then `/gsd:complete-milestone v1.5`.

- Phase 40 (Update-Available HUD & Sparkle Integration) is now fully complete. This session's on-device checkpoint (40-03) root-caused the badge-tap bug carried over from the prior session: tapping the collapsed-pill badge passed the click straight through the app window because `NotchWindowController`'s click-through `hotZone` didn't reliably cover the badge overlay's actual position. Rather than patch that geometry, the update-available indicator was redesigned to a small red dot on the menu-bar status item icon — always fully clickable by construction, sidestepping the whole click-through-zone class of bug. `UpdateAvailableState.swift` and the pill badge overlay were deleted; see `40-03-SUMMARY.md` for the full record, including which of the original 40-UI-SPEC.md decisions (D-05/D-06/D-07) this supersedes. Release archive launch (embedded Sparkle.framework under Hardened Runtime) confirmed crash-free on-device. Only Phase 42 (Dual-Activity Display) remains for v1.6 — start `/gsd-discuss-phase 42` next.
- Phase 39 (Volume & Brightness HUD) is now fully complete, including its gap-closure addendum (plan 39-08): native OSD suppression genuinely works via `.cghidEventTap` (D-14), self-driven volume/brightness/mute (D-15), and a snappier fill animation (D-16) — all confirmed on-device with zero transport-key regressions. 39-08's own on-device checkpoint directly covered the gap-closure's success criteria, so a separate `/gsd:verify-work 39` pass is not needed, per this project's established precedent (Phase 29/36/38). Start `/gsd-discuss-phase 40` (Update-Available HUD & Sparkle Integration) next.
- Phase 38 (Focus Mode HUD) is complete — all 9 plans executed, ROADMAP.md and this file updated. 38-09's own on-device UAT checkpoint directly covered all 4 ROADMAP Success Criteria (see ROADMAP.md Phase 38 entry for the per-criterion confirmation), so a separate `/gsd:verify-work 38` pass is not needed, per this project's established precedent (Phase 29/36).
- `38-UI-SPEC.md`'s Focus Wing Contract section is now stale (describes the pre-redesign icon+label/bare-dot layout) — not fixed in this session, flag for a docs-sync pass if it matters before Phase 39 planning references it.
- A general wing-flank-width issue (icon-only left flanks sized wider than their content needs) also affects the existing Charging/Bluetooth wings, per user observation during Phase 38 UAT — explicitly deferred by the user as a future general fix, not scoped into any current phase.
- Phase 37 (Drop-Session Summary Chip) is fully abandoned and reverted — all code removed, build re-verified green, ROADMAP.md and this file updated to reflect the closure. HUD-07 dropped from v1.6's requirement set. No further action needed on Phase 37.
- Phase 36 (Cosmetic Restyles & Signature Animation) is fully executed — all 4 plans (36-01, 36-02, 36-03, 36-04) complete. ONBOARD-04's own on-device UAT checkpoint (36-04 Task 3) already covered its ROADMAP success criterion #4 directly ("passt"). Formal phase-level verification/completion is the orchestrator's responsibility, not done in this session.
- Phase 29 (NotchShape Flare) is complete — its own on-device UAT checkpoint (Task 3) already covered all 3 ROADMAP success criteria, so a separate `/gsd:verify-work 29` pass is not needed. Start `/gsd-discuss-phase 30` next.
- v1.4 is code-complete but not formally closed: 2 items in `28-HUMAN-UAT.md` await final on-device re-confirmation — run `/gsd:verify-work` for v1.4 then `/gsd:complete-milestone` whenever convenient (does not block v1.5).
