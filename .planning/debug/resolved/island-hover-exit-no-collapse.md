---
status: resolved
trigger: "Die Island (expanded notch) schließt sich nicht mehr automatisch, wenn der Mauszeiger sie verlässt (hover-out). Aktuell klappt sie nur noch zu, wenn man explizit klickt (genau wie beim Öffnen). Erwartet: automatisches Schließen beim Verlassen mit der Maus soll wieder funktionieren."
created: 2026-07-20
updated: 2026-07-20
---

# Debug Session: island-hover-exit-no-collapse

## Symptoms

- **Expected behavior:** The expanded island auto-collapses when the mouse cursor leaves its hover/hit area, without any click needed.
- **Actual behavior:** The island only collapses via an explicit mouse click (the same click gesture used to open/expand it). Hover-exit no longer triggers auto-collapse.
- **Error messages:** None reported.
- **Timeline:** User is unsure exactly when this regressed — not definitively tied to today's Phase 48 (Audio Output Switcher) work, but that's a plausible candidate given it's the most recent change touching interaction/click handling near the expanded island. Could also be older/pre-existing.
- **Reproduction:** Hover or click to expand the island, then move the mouse away from it. Expected auto-collapse does not happen; the island stays expanded until clicked again.

## Current Focus

- **hypothesis (REVISED per user correction 2026-07-20):** The bug is NOT conditional/intermittent — user confirms it happens EVERY time, including in the exact "basic repro" scenario logged previously. Critical reinterpretation: `[hover] grace collapse applied — phaseAfter=collapsed` in that log means the INTERNAL state machine (`interaction.phase`, `NotchInteractionState`) correctly flips to `.collapsed` — but the user visually watched the real island and it did NOT shrink back down; it stayed visually expanded on screen. So the state-machine layer is provably correct (confirmed twice now), but something between "phase becomes .collapsed" and "the actual rendered SwiftUI content re-renders to the collapsed visual" fails specifically on the grace-timer path, while the IDENTICAL final state produced by an explicit click DOES render correctly every time.
- **Static comparison completed (exhaustive, see Evidence):** Read and line-by-line compared `handleClick()` vs `handleHoverExit()`'s grace `DispatchWorkItem` in NotchWindowController.swift, the pure `nextState()` reducer in NotchInteractionState.swift, and the pure `resolve()` arbiter in IslandResolver.swift. Found NO logical/structural asymmetry:
  - Both wrap `interaction.phase = nextState(...)` + `renderPresentation()` + conditional `discardPendingDrop()` in the identical `withAnimation(.spring(response:dampingFraction:))` block.
  - Both then call `updateVisibility()` and `syncClickThrough()` immediately after (outside the animation block), in the same order.
  - `resolve()` (the pure function `renderPresentation()`/`currentPresentation()` calls) is a TOTAL, deterministic function of `interaction.isExpanded` + other published inputs — it cannot behave differently based on WHICH caller invoked it.
  - `nextState`: `.expanded + .clicked -> .collapsed` and `.expanded + .graceElapsed -> .collapsed` produce the identical target state.
  - Panel frame is proven STATIC across all presentation states (`positionAndShow()` sizes the panel ONCE to the union of every possible content frame — confirmed by explicit code comment "the window is never live-resized"), so visual collapse is driven ENTIRELY by SwiftUI content re-render inside a fixed-size transparent panel, not by window resize. This rules out a window-frame-resize race as the mechanism.
  - `NotchPillView.body` renders purely off `presentationState.presentation` (an enum), not directly off `interaction.phase`/`isExpanded` (confirmed via file header comment: "the view no longer READS interaction.isExpanded to decide which branch to render").
  - `self` in the grace `DispatchWorkItem` is a weak capture of the SAME singleton `NotchWindowController`; `interaction`/`presentationState` are `private let` properties constructed once, never reassigned — ruled out a stale/different controller or model instance via static reading (no re-construction site found anywhere in the file).
  - Conclusion: pure code-logic reading cannot find the divergence. The one thing NOT yet directly observed at runtime is what `presentationState.presentation` (the actual visual driver) and the panel's live AppKit state (`isVisible`, `frame`, `ignoresMouseEvents`) ACTUALLY are at the exact moment the grace collapse fires, compared to the same values at an explicit click-collapse, in the SAME run.
- **test:** Added DEBUG-only instrumentation (Islet/Notch/NotchWindowController.swift, Debug build confirmed green via `xcodebuild`) that logs, at the moment of collapse:
  - Grace path: `presentationState.presentation`, `panel?.isVisible`, `panel?.frame`, `panel?.ignoresMouseEvents` — once right after the withAnimation block ("[hover] grace collapse applied"), and again after `syncClickThrough()` ("[hover] post-syncClickThrough").
  - Click path: the same 4 values, logged at the end of `handleClick()` ("[click] collapse applied").
  Ask user to reproduce the SAME basic scenario (hover-expand, hover-exit, wait, observe — do NOT click yet) and report the `[hover]` log lines AND what they see on screen at that instant. Then, while still watching the (per their report) still-expanded island, have them click it once (which they say always works) and report the `[click]` log line for direct A/B comparison in the same session.
- **expecting:**
  - If `presentation` in the `[hover]` logs is NOT a collapsed-looking case (i.e., not `.idle`/`.nowPlayingWings`/`.calendarCountdown`) while `phaseAfter=collapsed` — proves `resolve()`'s live inputs (not just `isExpanded`) disagree between the two paths at that instant; would fully contradict the static "pure function" analysis and demand re-examining what mutates those other inputs asynchronously in the 0.4s window.
  - If `presentation` in `[hover]` logs already shows the CORRECT collapsed-looking value, but the user still visually sees the expanded island on screen at that same instant — this points to a genuine AppKit/CoreAnimation render-flush gap specific to timer-driven (non-gesture) mutations on this `.nonactivatingPanel`/`ignoresMouseEvents`-toggling window, i.e. the SwiftUI state is correct but the frame is not being displayed/committed to screen without an accompanying real window-local event. Next step in that branch: force a display refresh at the end of the grace closure (e.g. `panel?.contentView?.needsDisplay = true` / `panel?.displayIfNeeded()`) as a targeted fix and re-verify.
  - If `panelVisible=false` unexpectedly in the `[hover]` logs — points to `updateVisibility()` hiding the panel via a fullscreen/licensing edge case coinciding with grace-fire, contradicting the "stays visually expanded" report (would need re-examination) — low probability given prior evidence but cheap to rule out with the same log line.
- **next_action (SUPERSEDED — see Evidence below, verification FAILED; new root cause confirmed and second fix applied 2026-07-20):** ~~Root cause found: hover-exit detection was fed ONLY by a global NSEvent `.mouseMoved` monitor...~~ Local-monitor fix did NOT resolve the bug (user re-verified, identical failure signature). Investigated why: confirmed `NotchPanel.acceptsMouseMovedEvents` was already `true` (ruling out that alternate explanation) and the local monitor registration itself was correct (single registration, correct entry point, torn down in deinit). The REAL root cause: `handlePointer`'s hover-exit tracking (`activeZone`, used to flip `pointerInZone`) keyed off `expandedZone` — the STATIC union of every possible presentation's max footprint (up to ~650x454pt, from Weather/Tray/Output-panel/Onboarding), all top-pinned to the same edge as the collapsed pill. Any single presentation's actual visible content (e.g. nowPlayingExpanded, ~420x240) sits in only the top portion of that union, leaving up to ~200pt+ of invisible dead space below/around it that still counted as "in zone." A user moving the mouse away from the visually-shrunk island remained geometrically inside `expandedZone` for as long as they stayed within that oversized reservation — exactly matching "5 seconds outside the island, still expanded, no `[hover] exit` line at all." This existed independently of the local-monitor gap (which was a real but secondary/insufficient fix) — confirmed by the fact that `syncClickThrough()` already deliberately uses the narrower `visibleContentZone()` (the current presentation's real rect) for click-through, per its own CR-01 fix-2 code comment, while hover-exit tracking did not. Fix applied: `handlePointer`'s `activeZone` for the expanded case now uses `visibleContentZone()` instead of `expandedZone`; `expandedZone` itself is untouched and still used by the drag-accept-region check (`isWithinDragAcceptRegion`), which legitimately needs the broader reservation. Debug build confirmed green via `xcodebuild`. Awaiting user to rebuild+run and confirm the island now auto-collapses on hover-exit shortly after the pointer visually leaves the rendered content (not just after leaving the much larger static panel reservation), for both hover-opened AND click-opened expand.

## Evidence

- timestamp: 2026-07-20
  checked: NotchInteractionState.swift (nextState reducer) — unit-test-covered, unmodified since Phase 02/22/43. All `.expanded` transitions for `.pointerExited`/`.graceElapsed`/`.clicked` are correct and match InteractionStateTests.swift (all pass statically).
  found: State machine itself is provably correct; the bug (if real) must be in the AppKit/timer integration layer (NotchWindowController.swift), not the pure reducer.
  implication: Ruled OUT (weak->none, but very high confidence): `nextState` logic.

- timestamp: 2026-07-20
  checked: `git log` for NotchWindowController.swift + NotchInteractionState.swift — last 4 commits touching the controller are Phase 48 (audio output panel: 0e16fcc, 5d14526, b584860) and Phase 49 (38ecd8c, DEBUG-only spike hooks). Read full diffs of all 3 Phase 48 commits.
  found: None of the 3 Phase 48 diffs touch `handlePointer`, `handleHoverExit`, `pointerInZone`, `graceWorkItem`, or `nextState`. They only add `outputPanelExpandedFrame` to the panel-frame union (positionAndShow, Site 2) and a nested `if presentationState.outputPanelOpen` branch inside `visibleContentZone()`'s pre-existing final `else` (Site 3) — both purely additive geometry reservations, not touching the exit/grace-timer edge-detection code path.
  implication: Phase 48 is an unlikely direct cause. The bug (if triggered by recent work at all) is more likely from Phase 43 (picker dismiss-immediately paths) or is pre-existing, consistent with the user's own uncertainty in Symptoms.timeline.

- timestamp: 2026-07-20
  checked: `handleHoverExit()`'s DispatchWorkItem guards (`isDraggingShelfItem`, `isOnboardingActive`) and their set/reset sites.
  found: `isOnboardingActive` also gates `handleClick()` at its very first line (`guard !isOnboardingActive else { return }`) — if this were stuck true, clicking would ALSO stop working, contradicting the user's report that click-to-close still works. `isDraggingShelfItem` has a 20s hard safety-net timer (`dragPinSafetyNetWorkItem`) that unconditionally calls `endShelfItemDrag()` even if the mouse-up monitor never fires, so it cannot stay stuck true indefinitely (max 20s stall, not the reported "never" behavior).
  implication: Both flags are unlikely standing culprits, though not 100% excluded (the instrumentation will show their live value at grace-fire time either way).

- timestamp: 2026-07-20
  checked: `NotchPanel.swift` init comment + `handlePointer`'s design (Pattern 1: a GLOBAL `NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved])` is the ONLY mechanism feeding hover tracking — confirmed via NotchPanel.swift's own comment: "every hover interaction ... was driven by a manual global NSEvent monitor, never native window events").
  found: A macOS global monitor only delivers events NOT destined for the monitoring app's own windows. While the panel is interactive (`ignoresMouseEvents = false`, i.e. pointer over the actual visible expanded content), mouse-moved events are delivered LOCALLY and do NOT reach `handlePointer` at all — this is expected/by-design and does not itself explain a total loss of exit-collapse, since crossing the real window boundary always re-classifies the event as "other app" and should still reach the global monitor. Flagged as the most plausible surviving hypothesis category (window bounds vs. tracked-zone mismatch) but NOT independently confirmed.
  implication: Needs the runtime `[hover]` log evidence to confirm or refute — cannot be resolved by further static reading.

- timestamp: 2026-07-20
  checked: Live `[hover]` console log from user's DEBUG build, basic/generic repro (plain hover-to-expand, move mouse away, nothing else active — Now Playing not confirmed expanded, output panel not confirmed open).
  found: |
    [hover] enter — phase=collapsed expanded=false
    [hover] exit — phase=expanded expanded=true
    [hover] scheduling grace collapse in 0.4s
    [hover] grace timer fired — isDraggingShelfItem=false isOnboardingActive=false phaseBefore=expanded
    [hover] grace collapse applied — phaseAfter=collapsed
    Full pipeline (enter -> exit edge detection -> grace scheduling -> timer fire -> guards both false -> phaseAfter=.collapsed) completed correctly end-to-end in this run.
  implication: |
    RULES OUT as a static/always-broken defect: pointerInZone enter/exit edge detection (Evidence #4 concern — global monitor DOES receive exit events correctly, at least in this basic case), DispatchWorkItem cancellation/starvation, isDraggingShelfItem stuck-true, isOnboardingActive stuck-true, and nextState/.graceElapsed reducer logic. All four Current-Focus branch predictions were addressed by this single log and none matched a broken state — the bug did NOT reproduce here.
    CONCLUSION: the core hover-exit -> grace-collapse pipeline is mechanically sound. The reported bug is conditional/intermittent, not a standing defect in this path. Something ADDITIONAL — not present in this basic repro — must be required to trigger the failure. Candidates not yet tested: Now Playing expanded state, Phase 48 Audio Output panel open (adds `outputPanelExpandedFrame`/`outputPanelOpen` geometry per Evidence #2 — untested at runtime even though the diff looked additive-only), some other glance/activity visible, a specific prior interaction sequence (e.g., drag-then-hover, click-then-hover), or Phase 49 DEBUG spike-hook interference.
    **SUPERSEDED 2026-07-20 by user correction below — the "did not reproduce" conclusion above was wrong; see next entry.**

- timestamp: 2026-07-20
  checked: User correction (verbatim, DE): "Doch immer. Sie hat sich ja nicht geschlossen in dem Szenario, das passiert wirklich immer das sie sich nicht mehr schließt." (Translation: "No, it happens every time. It did NOT close in that scenario — this really always happens, that it no longer closes.")
  found: The prior evidence entry's log capture (`phaseAfter=collapsed`) was misread as "the bug did not reproduce." The user was watching the REAL on-screen island during that exact same run and it visually stayed expanded — it never visually shrank back down — even though the internal `interaction.phase` state variable correctly flipped to `.collapsed`. So the log proves the state-machine mutation succeeded; it does NOT prove the bug didn't reproduce. The bug is NOT conditional/intermittent — it is a standing defect that fires on literally every hover-exit, and the previously captured log is itself an instance of the bug (correct state, wrong visual), not a counterexample to it.
  implication: Reframes the entire investigation. The hover-exit -> grace-timer -> nextState(.graceElapsed) state-machine pipeline is NOT the defect (confirmed correct, twice over). The defect is downstream: between "phase becomes .collapsed" and "the window/view actually re-renders to the collapsed visual," specifically on the grace-timer path only (click-driven collapse visually works every time, per user). Exhaustive static line-by-line comparison of handleClick() vs handleHoverExit()'s grace closure, nextState(), and resolve() (see Current Focus) found NO code-level asymmetry between the two paths — added targeted DEBUG instrumentation logging presentationState.presentation + panel AppKit state at the moment of both collapse paths to observe the actual divergence at runtime, since static reading is exhausted.

- timestamp: 2026-07-20
  checked: User re-verification of the local-monitor fix (fresh Debug rebuild). New `[click]`/`[hover]` log capture, same repro (click-open, wait ~9s with mouse genuinely moved away).
  found: |
    [hover] enter — phase=collapsed expanded=false
    [click] collapse applied — phaseAfter=expanded presentation=nowPlayingExpanded(...)
    ... ~9s pass, mouse held away, NOT ONE [hover] exit line ...
    [click] collapse applied — phaseAfter=collapsed presentation=idle   (user's manual click)
    [hover] exit — phase=collapsed expanded=false                       (only fires AFTER manual collapse, as before)
    [hover] grace timer fired — ... phaseBefore=collapsed                (never phaseBefore=expanded)
  implication: |
    Identical failure signature to before the local-monitor fix — the fix had NO observable effect.
    Read NotchPanel.swift: `acceptsMouseMovedEvents = true` was ALREADY set at init (line 36) — ruled out
    that alternate explanation for the local monitor "having nothing to receive." Read the local monitor
    registration (NotchWindowController.swift ~line 505): single correct registration, correct
    `handlePointer(at: NSEvent.mouseLocation)` call, returns `event` unmodified, torn down in deinit —
    ruled out a registration/scoping bug.
  timestamp: 2026-07-20

- timestamp: 2026-07-20
  checked: |
    positionAndShow()'s `expandedZone` construction (line ~1104) and `handlePointer`'s `activeZone`
    (line ~1361) which consumes it for hover-exit tracking while expanded. Also `expandedNotchFrame`/
    `topPinnedFrame` (NotchGeometry.swift) confirming every presentation frame — including the
    `panelFrame` union itself — is centered on the collapsed pill's midX and pinned to the SAME top
    edge (`collapsed.maxY`), differing only in how far DOWN/WIDE each grows. Computed concrete sizes:
    expandedFrame (default/nowPlaying, switcher-row case) ≈ 420x296 (196+56+44); weatherExpandedFrame
    (tallest) = 420x454; trayFrame/quickActionPickerFrame (widest) = 650 wide. `panelFrame` = union of
    all seven ⇒ ≈650x454. `visibleContentZone()` (used by `syncClickThrough()` for click-through, per
    its own CR-01 fix-2 comment) already computes the CURRENT presentation's real content rect (e.g.
    nowPlayingExpanded's default-branch case ≈ 420x240), independently confirming a ~200pt+ height /
    ~115pt-per-side width gap between what's visually rendered and what `expandedZone` (used for
    hover-exit tracking) considers "still inside."
  found: |
    `handlePointer`'s hover-exit tracking used `expandedZone` (the full ~650x454 static multi-presentation
    union) instead of `visibleContentZone()` (the current presentation's real, much smaller rect already
    used correctly for click-through). Because every frame is top-pinned to the same edge, the "extra"
    reserved space sits BELOW and to the SIDES of whatever is actually visible — completely invisible to
    the user, but still geometrically "in zone." Moving the mouse straight down/away from a small
    presentation (nowPlaying, ~420x240) leaves it inside a zone that extends to ~454pt tall / 650pt wide,
    i.e. up to ~200pt+ of dead space the pointer can sit in indefinitely without ever registering as
    "exited" — independent of whether handlePointer is invoked via the global or local monitor.
  implication: |
    This explains why the local-monitor fix had zero effect: even with handlePointer now correctly
    invoked for events over the panel, `zone.contains(point)` still evaluates true because the zone
    itself is far larger than the visible content. This is the actual root cause, and it predates/
    is independent of the global-vs-local monitor gap (which remains a real, valid, secondary fix —
    both are needed together: local monitor ensures handlePointer is called for on-panel events at all;
    visibleContentZone() ensures the containment check reflects what the user can actually see).

## Eliminated

- hypothesis: pointerInZone enter/exit edge detection never fires / global monitor doesn't see exit events (static concern from Evidence #4)
  evidence: Live log shows `[hover] exit` fired correctly with correct phase/expanded values in the basic repro.
  timestamp: 2026-07-20

- hypothesis: DispatchWorkItem grace timer is being cancelled/starved before it can fire
  evidence: Live log shows `[hover] grace timer fired` within the scheduled 0.4s window.
  timestamp: 2026-07-20

- hypothesis: isDraggingShelfItem or isOnboardingActive stuck true, blocking grace-collapse
  evidence: Live log shows both flags false at grace-fire time, and collapse was applied successfully.
  timestamp: 2026-07-20

- hypothesis: nextState(.graceElapsed) reducer fails to produce .collapsed
  evidence: Live log shows phaseAfter=collapsed — reducer produced correct output when guards passed.
  timestamp: 2026-07-20

- hypothesis: the bug is conditional/intermittent, requiring an additional condition (Now Playing expanded, output panel open, a specific prior interaction sequence, or Phase 49 DEBUG hooks) beyond the basic hover-expand/hover-exit repro
  evidence: User correction (2026-07-20) — the basic repro run that produced the "phaseAfter=collapsed" log was ITSELF an instance of the bug (state flipped correctly, visual did not). The bug reproduces on literally every hover-exit, not conditionally. This whole "conditional/intermittent" line of reasoning is superseded.
  timestamp: 2026-07-20

- hypothesis: handleClick()'s and handleHoverExit()'s grace-timer code paths differ in what they call after nextState (missing renderPresentation/updateVisibility/syncClickThrough call, different withAnimation scoping, or thread-dispatch difference)
  evidence: Exhaustive line-by-line static comparison of both functions (NotchWindowController.swift) — both call the identical sequence (nextState -> renderPresentation -> conditional discardPendingDrop, all inside the same withAnimation spring; then updateVisibility + syncClickThrough outside it). resolve() is a pure/deterministic function of published state, not the caller. nextState's two `.expanded ->` transitions for `.clicked` and `.graceElapsed` both target `.collapsed`. No asymmetry found in source.
  timestamp: 2026-07-20

## Resolution

reasoning_checkpoint:
  hypothesis: "handlePointer's hover-exit containment check (`activeZone` in handlePointer, NotchWindowController.swift ~line 1361) uses `expandedZone` while the island is expanded — a STATIC union of every possible presentation's maximum footprint (expandedFrame/wings/onboardingFrame/trayFrame/weatherExpandedFrame/outputPanelExpandedFrame/quickActionPickerFrame, ~650x454pt at its largest), all top-pinned to the SAME edge as the collapsed pill (topPinnedFrame in NotchGeometry.swift centers every frame on collapsed.midX and pins to collapsed.maxY). Any single active presentation's real visible content (e.g. nowPlayingExpanded's default-branch case, ~420x240) occupies only the top portion of that union, leaving up to ~200pt of height and ~115pt per side of INVISIBLE dead space that still counts as 'inside the zone.' A user moving the pointer away from the visually-shrunk island in any direction other than straight up remains geometrically inside expandedZone for as long as they stay within that oversized reservation, so pointerInZone never flips false, handleHoverExit/the grace-collapse timer is never scheduled, and the island appears to 'never' auto-collapse — matching the user's '5 seconds outside, still expanded, no [hover] exit line at all' report exactly, and explaining why the previously-applied local-monitor fix made no observable difference: handlePointer being correctly invoked doesn't matter if the containment check it feeds still evaluates to 'inside.'"
  confirming_evidence:
    - "User's re-verification log (this round) is BYTE-IDENTICAL in failure shape to the pre-local-monitor-fix logs: click-open, ~9s of genuine mouse-away time, zero [hover] exit lines, exit only appears after a manual click re-collapses. If the local monitor were the sole remaining gap, adding it should have changed this signature (at minimum, SOME new behavior); it did not, which is only consistent with the containment check itself never flipping regardless of which monitor calls it."
    - "Read NotchPanel.swift: acceptsMouseMovedEvents = true already set at init (line 36) — the 'events aren't generated at all' alternate explanation is ruled out directly."
    - "Read the local monitor registration (NotchWindowController.swift ~line 505): single correct registration calling handlePointer(at: NSEvent.mouseLocation), returns event unmodified, torn down in deinit — ruled out a registration/scoping bug in the prior fix itself."
    - "syncClickThrough() (NotchWindowController.swift ~line 1550) already deliberately uses the NARROWER visibleContentZone() instead of expandedZone for click-through interactivity, per its own explicit CR-01 fix-2 code comment explaining that expandedZone 'stays true for the whole time the pointer sits anywhere in that zone, including over the invisible reserved shelf band' — i.e. the codebase already independently identifies and documents that expandedZone is much broader than the visible content; hover-exit tracking simply never received the same narrowing that click-through did."
    - "Computed concrete geometry from NotchPillView.swift's own named constants (switcherContentHeight=196, shelfRowHeight=56, switcherRowHeight=44, weatherLargeContentHeight=410, traySize.width=650) confirms panelFrame's union is ~650x454 at its largest members (Weather/Tray), while nowPlayingExpanded's own real content is ~420x240 — a concrete, non-trivial (~200pt) gap, not a rounding-error-sized discrepancy."
  falsification_test: "If, after switching handlePointer's expanded-state activeZone from expandedZone to visibleContentZone(), the user still cannot get the island to auto-collapse shortly after visually leaving the rendered content (with a fresh [hover] exit line appearing during the expanded window, not only after a manual click) — this hypothesis is wrong and the remaining gap is elsewhere (e.g. visibleContentZone()'s own per-presentation branch is itself computing a rect larger than what's rendered for the specific presentation in use, or lastPointerLocation/point coordinate space mismatch)."
  fix_rationale: "Both monitors (global for events over other apps, local for events over Islet's own interactive panel — kept from the prior round, since it is a real and still-necessary fix for handlePointer to be invoked AT ALL while the panel is interactive) now feed handlePointer correctly. The remaining, actual defect was that the containment check itself (activeZone) was scoped to the wrong rect. Repointing it at visibleContentZone() — the SAME rect already computed correctly for click-through, requiring no new geometry code — makes hover-exit detection match what the user can see, without touching the state machine, grace-timer, rendering, or the drag-accept-region logic (which still legitimately uses the broad expandedZone, untouched, at its own call site)."
  blind_spots: "Have not yet confirmed at runtime that visibleContentZone()'s per-presentation branches (Tray/Weather/Onboarding/QuickActionPicker/Calendar/default) each match their OWN rendered content as tightly as computed here for nowPlaying's default branch — if any one branch is itself oversized relative to what actually renders, that specific presentation would still exhibit some version of this bug even after the fix. Also have not verified whether moving the pointer to genuinely reach the transport-control buttons within nowPlayingExpanded (the original reason expandedZone was used for keep-open, per the old code comment) still works correctly under visibleContentZone() — expected to, since visibleContentZone() covers the entire current presentation's real content including its buttons, but not yet confirmed on-device."
root_cause: |
  handlePointer's hover-exit containment check (`activeZone`, NotchWindowController.swift) used `expandedZone` — the static union of every possible presentation's maximum footprint (~650x454pt at its largest, from Weather/Tray) — instead of `visibleContentZone()`, the current presentation's actual rendered rect (e.g. ~420x240 for nowPlayingExpanded). Every presentation frame is top-pinned to the same edge (topPinnedFrame in NotchGeometry.swift), so the "extra" reserved space in the union sits invisibly below/around whatever is actually shown. A user moving the pointer away from the visually-shrunk island remained geometrically inside this oversized zone for as long as they stayed within it (up to ~200pt+ of dead space), so pointerInZone never flipped false and the grace-collapse timer was never scheduled — matching "stays expanded for 5+ seconds outside the visible island, only closes on click" exactly. This existed independently of, and was not fixed by, the earlier local-monitor fix (which addressed a real but separate gap: handlePointer not being invoked at all for on-panel events via the global-only monitor). Both fixes are needed together.
fix: |
  Round 1 (kept, still necessary): added a LOCAL NSEvent monitor for .mouseMoved (NSEvent.addLocalMonitorForEvents) alongside the existing global monitor, calling the same handlePointer(at: NSEvent.mouseLocation) entry point, so handlePointer is invoked regardless of whether a given mouseMoved event is routed globally or locally.
  Round 2 (this round, the actual fix for the reported symptom): changed handlePointer's expanded-state `activeZone` from `expandedZone` (static ~650x454 multi-presentation union) to `visibleContentZone()` (the current presentation's real rendered rect, already used correctly by syncClickThrough() for click-through) — one-line change plus updated comments at both the old `expandedZone` construction site (positionAndShow) and the `activeZone` computation site (handlePointer) explaining why. `expandedZone` itself is untouched and still used, unchanged, by the drag-accept-region check (isWithinDragAcceptRegion), which legitimately needs the broader static reservation.
verification: |
  User rebuilt and re-tested on-device with both fixes in place (local NSEvent monitor + visibleContentZone()-based activeZone). User confirmed (German, verbatim): "Ok klappt" ("OK, it works.") — auto-collapse on hover-exit now works correctly for the reproduction scenario. No new/regression issue reported.
files_changed:
  - Islet/Notch/NotchWindowController.swift (round 1: added `localMouseMonitor` property + registration in start() + teardown in deinit; round 2: `activeZone` in handlePointer now uses `visibleContentZone()` instead of `expandedZone`; updated comments at both call sites; DEBUG-only print instrumentation from prior rounds retained unchanged)
