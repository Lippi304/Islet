---
phase: 48-audio-output-switcher-ui-wiring
plan: 03
subsystem: audio-ui
tags: [swiftui, coreaudio, output-switcher, notchwindowcontroller, geometry, on-device-uat]

# Dependency graph
requires:
  - phase: 48-01
    provides: "setSystemVolume(_:), IslandPresentationState.output* @Published fields, live AudioOutputMonitor wiring"
  - phase: 48-02
    provides: "row-as-volume-bar outputPanel(devices:) UI (D-10..D-13), onToggleOutputPanel/onSelectOutputDevice/onVolumeChange closures"
provides:
  - "handleToggleOutputPanel()/handleSelectOutputDevice(_:)/handleVolumeChange(_:) controller handlers, forwarded from makeRootView(theme:)"
  - "CR-01 geometry three-site rule closed for the output panel (Site 1 tabHeight from 48-02, Sites 2/3 positionAndShow/visibleContentZone from this plan)"
  - "On-device UAT confirmation of all 4 Phase 48 ROADMAP Success Criteria against the row-as-volume-bar design"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Drag-originated @Published mutations (handleVolumeChange -> outputCurrentVolumeFraction) must gate their consuming view's .animation(value:) off during the drag, or every DragGesture.onChanged tick retriggers a fresh spring chasing a moving target — same class of bug as isSecondaryBubbleHovering's 'one row active at a time' precedent, now also covering an active-drag boolean (isDraggingOutputVolume)."

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "Tasks 1-2 (handlers + closure forwarding, geometry three-site rule Sites 2/3) were already shipped in commits 5d14526/b584860 before this plan's row-as-volume-bar revision (48-CONTEXT.md D-10..D-13) and were re-verified as safe no-ops against the current codebase — no new commits needed for either task, per the plan's own REVISION NOTE."
  - "Task 3 UAT round 1 found 1 of 7 steps failing: the active row's volume-drag fill was visibly choppy/stepped rather than tracking the finger. Root cause: outputVolumeSlider's fill .animation(value: fraction) spring was copied from OSDLevelBar, correct there for rare discrete key-press updates, but wrong here since fraction updates on every DragGesture.onChanged tick, so each tick retriggered a fresh 150ms spring chasing a moving target."
  - "Fix: gate the fill animation off via an instance-level isDraggingOutputVolume bool while a drag is in progress, restoring the spring once the drag ends (commit e657356) - mirrors isSecondaryBubbleHovering's 'only one row/bubble active at a time' precedent. OSDLevelBar itself was untouched. CoreAudio's synchronous per-tick AudioObjectSetPropertyData write was assessed as a plausible secondary contributor but not throttled - the animation-retrigger mechanism alone fully explained the reported symptom, and throttling was deferred to avoid over-fixing pending on-device re-confirmation."
  - "Task 3 UAT round 2 (post-fix): user replied 'approved' - drag is now smooth and all 7 steps pass, including the D-13 hasVolumeControl-gated text-stays-white/bar-dims/drag-no-op row behavior."

requirements-completed: [OUTPUT-01, OUTPUT-03, OUTPUT-04]

# Metrics
duration: multi-session (2 on-device UAT rounds)
completed: 2026-07-20
---

# Phase 48 Plan 03: Audio Output Switcher — Controller Handlers, Geometry & On-Device Verification Summary

**Closed the audio-output-switcher loop end to end: real CoreAudio-backed toggle/select/drag handlers, the CR-01 geometry three-site rule finished for the output panel, and all 4 ROADMAP Phase 48 Success Criteria confirmed on real hardware against the row-as-volume-bar UI (D-10..D-13), after a two-round on-device UAT that found and fixed a choppy volume-drag animation bug.**

## Performance

- **Duration:** multi-session (Task 1/2 shipped pre-revision; Task 3 spanned 2 on-device UAT rounds with a gap-closure fix in between)
- **Completed:** 2026-07-20
- **Tasks:** 3 (2 auto tasks re-verified as no-ops, 1 checkpoint task with a round-1 finding/fix/round-2 re-approval)
- **Files modified:** 2 across the plan's full history (`NotchWindowController.swift` for Tasks 1-2's original ship, `NotchPillView.swift` for the Task 3 round-1 gap-closure fix)

## Accomplishments
- **Task 1 (Handlers + closure forwarding):** `handleToggleOutputPanel()`, `handleSelectOutputDevice(_:)`, `handleVolumeChange(_:)` added to `NotchWindowController` and forwarded from `makeRootView(theme:)` as `onToggleOutputPanel`/`onSelectOutputDevice`/`onVolumeChange`. Toggling flips `presentationState.outputPanelOpen` inside the existing spring `withAnimation` wrapper then calls `syncClickThrough()` (D-08); selecting a device calls `audioOutputMonitor?.setDefaultOutput(device:completion:)` with an empty completion body and never force-closes the panel (D-07/D-09); dragging calls `setSystemVolume(_:)` and writes the result back into `outputCurrentVolumeFraction` as an optimistic UI update. Already shipped in commit `5d14526` before this plan's row-as-volume-bar revision; re-verified against the current, redesigned `NotchPillView.swift` and confirmed unaffected — the handlers only forward opaque `AudioOutputDevice`/`Float` values regardless of how the panel renders internally, so no new commit was needed (all acceptance-criteria greps pass unchanged).
- **Task 2 (Geometry three-site rule — Sites 2+3):** `positionAndShow()`'s panel-frame union unconditionally reserves `outputPanelExpandedFrame` (mirroring `onboardingFrame`/`trayFrame`/`weatherExpandedFrame`'s own precedent); `visibleContentZone()`'s new branch reads `presentationState.outputPanelOpen`, nested inside the final `else` (not a sibling `else if`) so it only applies during genuinely-active media presentations, closing the transient-presentation edge case (`.charging`/`.device` overriding `presentationState.presentation` while `outputPanelOpen` is still true from before). Already shipped in commit `b584860`; re-verified against the current codebase as an unchanged no-op — `NotchPillView.homeContentHeight + NotchPillView.outputPanelExtraHeight`'s value (140) was unaffected by 48-02's row-as-bar restructuring (only its doc comment changed there).
- **Task 3 (On-device UAT, 2 rounds):**
  - **Round 1** — 6 of 7 verification steps passed cleanly (panel reveal animation, device-list correctness, tap-to-select with panel staying open, live connect/disconnect list updates, symmetric toggle-close, `hasVolumeControl`-gated row behavior). 1 issue found: the active device's Capsule volume-bar fill was visibly choppy/stepped while dragging instead of smoothly tracking the finger.
  - **Root cause:** `outputVolumeSlider`'s fill `.animation(response: 0.15, dampingFraction: 0.86, value: fraction)` was copied verbatim from `OSDLevelBar`, where it is correct (rare discrete key-press updates). In the output panel, `fraction` updates on every `DragGesture.onChanged` tick during an active drag — each tick retriggered a fresh 150ms spring chasing a moving target, producing the observed choppiness.
  - **Fix (commit `e657356`):** gated the fill's animation off via a new instance-level `isDraggingOutputVolume` bool set `true` in `onChanged` and `false` in `onEnded`, restoring the spring only once the drag completes — mirrors `isSecondaryBubbleHovering`'s established "only one row/bubble is actively interactive at a time" precedent. `OSDLevelBar` itself was left untouched (still correct for its own discrete-update use case). CoreAudio's synchronous per-tick `AudioObjectSetPropertyData` write was assessed as a plausible secondary contributor but deliberately not throttled, since the animation-retrigger mechanism alone fully explained the symptom and throttling risked over-fixing without on-device confirmation it was needed.
  - **Round 2 (this session)** — user re-verified the fix on-device and replied a plain **"approved"**, confirming the drag is now smooth and all 7 UAT steps pass, closing out Phase 48's on-device verification.

## Task Commits

Each task was committed atomically (commits below span both the pre-revision original ship and this session's gap-closure/checkpoint history):

1. **Task 1: Handlers + closure forwarding** — `5d14526` (feat, pre-revision original ship); re-verified against post-48-02-revision code this session, confirmed no-op, no new commit needed.
2. **Task 2: Geometry three-site rule Sites 2+3** — `b584860` (feat, pre-revision original ship); re-verified against post-48-02-revision code this session, confirmed no-op, no new commit needed.
3. **Task 3: On-device UAT round 1** — `bceccf8` (docs: record finding, pre-fix)
4. **Task 3 gap-closure fix: volume-drag animation gating** — `e657356` (fix)
5. **Task 3: On-device UAT round 2 (re-verify)** — `d2fae7e` (docs: reach checkpoint, pre-round-2); this session's approval documented in this SUMMARY + STATE.md/ROADMAP.md tracking commit below

**Plan metadata:** (this SUMMARY's own commit, tracking commit follows)

_No TDD tasks in this plan._

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` — `handleToggleOutputPanel()`/`handleSelectOutputDevice(_:)`/`handleVolumeChange(_:)` handlers, `makeRootView(theme:)` closure forwarding, `outputPanelExpandedFrame` panel-frame union member, `visibleContentZone()`'s `outputPanelOpen`-gated branch nested in the final `else` (shipped pre-revision, unaffected by 48-02's redesign)
- `Islet/Notch/NotchPillView.swift` — `isDraggingOutputVolume` instance state added to gate `outputVolumeSlider`'s fill animation off during an active drag, fixing the choppy-fill regression found in Task 3 round 1

## Decisions Made
- Re-running Tasks 1-2 against the current (post-48-02-revision) codebase was correctly treated as a safe no-op per the plan's own REVISION NOTE — both tasks forward/read opaque values (`AudioOutputDevice`, `Float`, `presentationState.outputPanelOpen`) that are presentation-agnostic, so 48-02's internal row-as-volume-bar restructuring required zero controller-level changes.
- The Task 3 round-1 drag-choppiness fix was scoped to a single boolean gate on the consuming view's animation modifier rather than throttling the underlying CoreAudio write — smaller, more targeted diff that fully explained and resolved the reported symptom without risking a second, unconfirmed change.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Volume-drag fill animation re-triggering per drag tick, causing visible choppiness**
- **Found during:** Task 3, on-device UAT round 1 (step 2: drag the active device's row)
- **Issue:** `outputVolumeSlider`'s Capsule fill used `.animation(response: 0.15, dampingFraction: 0.86, value: fraction)`, copied from `OSDLevelBar`'s discrete-update use case. Since `fraction` updates on every `DragGesture.onChanged` tick during a live drag, each tick retriggered a fresh 150ms spring chasing a moving target, producing a stepped/choppy visual instead of the fill tracking the finger smoothly.
- **Fix:** Added an instance-level `isDraggingOutputVolume` bool, set `true` in the drag gesture's `onChanged` and `false` in `onEnded`, and gated the fill's `.animation(value:)` off while `true` — the fill updates immediately (no spring lag) during the drag, then the spring resumes for any subsequent non-drag-driven change (e.g. a device switch elsewhere setting a new default volume).
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Commit:** `e657356`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary correctness fix for the plan's own Success Criterion 1 (real-time draggable volume control) — required to pass on-device UAT. No scope creep; `OSDLevelBar` and CoreAudio write path left untouched.

## Issues Encountered

None beyond the deviation above, which required a second on-device UAT round to confirm the fix — resolved cleanly, no further issues found in round 2.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **Phase 48 (Audio Output Switcher — UI Wiring) is now code-complete and on-device UAT'd.** All 4 ROADMAP Phase 48 Success Criteria confirmed against the row-as-volume-bar design: (1) the active device's row itself is the draggable real-time volume control with a smooth, non-choppy fill; (2) full-white-vs-dimmed text is the sole active-device signal with no checkmark anywhere; (3) tapping an inactive row selects it and the bar follows to the newly-active row without closing the panel; (4) the live list stays correct across connect/disconnect (OUTPUT-04); and D-13's per-row `hasVolumeControl`-gated text-stays-white/bar-dims/drag-no-op behavior is confirmed.
- Per this project's established Phase 29/36/38/39/45/47 precedent, this plan's own on-device checkpoint directly covers Phase 48's ROADMAP success criteria — a separate `/gsd:verify-work 48` pass is not required before formally closing the phase, though the orchestrator (not this plan) owns that decision.
- OUTPUT-04 ("The output list stays correct when a device connects or disconnects while the panel is open... keyed by device UID") is now confirmed on-device via Task 3 step 5 and marked complete alongside OUTPUT-01/OUTPUT-03 in this plan's requirements-completed list.

---
*Phase: 48-audio-output-switcher-ui-wiring*
*Completed: 2026-07-20*

## Self-Check: PASSED

SUMMARY.md and all 5 referenced commit hashes (5d14526, b584860, bceccf8, e657356, d2fae7e) found on disk/in git log.
