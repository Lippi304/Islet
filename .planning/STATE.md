---
gsd_state_version: 1.0
milestone: v1.8
milestone_name: Settings Redesign & Island Navigation
status: executing
stopped_at: Phase 54 UI-SPEC approved
last_updated: "2026-07-21T22:43:54.996Z"
last_activity: 2026-07-21 -- Phase 54 planning complete
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 10
  completed_plans: 7
  percent: 70
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-19)

**Core value:** The notch becomes a beautiful, reliable island that shows now-playing media and reacts when you plug in the charger or connect a device — native, smooth, and as polished as the iPhone Dynamic Island.
**Current focus:** v1.8 shipped; v1.4, v1.5, and v1.7 remain open in parallel (see their own Operator Next Steps entries below)

## Current Position

Phase: v1.8 archived (Phases 51-53) — no active phase selected
Plan: —
Status: Ready to execute
Last activity: 2026-07-21 -- Phase 54 planning complete

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

## Performance Metrics

**Velocity:**

- Total plans completed: 113
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

## Session Continuity

Last session: 2026-07-21T22:09:02.033Z
Stopped at: Phase 54 UI-SPEC approved
Resume file: .planning/phases/54-permissions-overview-onboarding-replay-settings-rollup-showi/54-UI-SPEC.md

## Operator Next Steps

- **Phase 54 decision-coverage gate overridden (2026-07-22).** `check.decision-coverage-plan` flagged D-01 through D-11 as not cited inside any plan's `must_haves.truths` block (only D-12/D-13 are). Manual review confirmed all 13 decisions ARE implemented and referenced in plan task bodies/acceptance criteria (grep-verified, and gsd-plan-checker's semantic review independently confirmed all 13 decisions correctly implemented) — user chose "Proceed anyway" since this is a must_haves-phrasing gap, not a missing feature. Re-surface at `/gsd:verify-work 54` if in doubt.
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
