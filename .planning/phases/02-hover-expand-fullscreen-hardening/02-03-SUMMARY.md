---
phase: 02-hover-expand-fullscreen-hardening
plan: 03
subsystem: ui
tags: [swift, appkit, nsevent, global-monitor, haptic, grace-delay, conditional-click-through, focus-safe, nspanel, dynamic-island]

# Dependency graph
requires:
  - phase: 02-hover-expand-fullscreen-hardening
    provides: "nextState(_:_:) + NotchInteractionState (Plan 02-01); expandedNotchFrame(collapsed:expandedSize:) (Plan 02-01); NotchPillView(interaction:) morph + NotchPillView.expandedSize seed (Plan 02-02)"
provides:
  - "Focus-safe ISL-03 runtime wiring: global NSEvent .mouseMoved monitor → hot-zone hit-test → nextState; haptic + bounce on hover-enter (D-01); click→expand spring morph (D-02); 0.4s grace-delay collapse with re-entry cancel (D-03); conditional ignoresMouseEvents restored deterministically (Pitfall 3)"
  - "NotchPanel.ignoresMouseEvents documented as CONDITIONAL (controller-driven); all focus-safe invariants retained (.nonactivatingPanel, canBecomeKey/Main=false, .statusBar, all-Spaces)"
  - "NotchPillView.onClick closure: the view reports a tap via a plain Swift closure so it stays AppKit-free; the controller owns the .clicked transition + spring"
  - "Panel sized to expandedNotchFrame up front (Pattern 4) so the SwiftUI morph never clips"
  - "A1 on-device probe seam: DEBUG-only hover-tick log to confirm the global monitor fires unprompted on Tahoe; NSTrackingArea (Pattern 1b) documented as the permission-free fallback"
affects: [02-04, 05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Conditional click-through: ignoresMouseEvents flipped false ONLY inside the pill hot-zone, restored true whenever !isHovering && !isExpanded — the style mask is never toggled at runtime"
    - "Global NSEvent .mouseMoved monitor (observes copies of other apps' events, never consumes, fires on main) as the focus-safe hover mechanism — no local monitor, no CGEvent tap, no keyboard mask"
    - "OS events → pure events: the AppKit glue translates pointer/timer/tap into nextState(_, .pointerEntered/.pointerExited/.graceElapsed/.clicked); all choreography stays in the unit-tested pure machine"
    - "Spring applied AT the state mutation (withAnimation(.spring(response:dampingFraction:))) — the view drives no animation (D-08); tuning seeds (response/damping, graceDelay, expandedSize) centralized for Plan 05"

key-files:
  created: []
  modified:
    - "Islet/Notch/NotchPanel.swift"
    - "Islet/Notch/NotchWindowController.swift"
    - "Islet/Notch/NotchPillView.swift"

key-decisions:
  - "Hot-zone = the COLLAPSED notchFrame inset by -6px (collapsedFrame.insetBy(dx:-6,dy:-6)) in global bottom-left coords — comfortable to target without overgrowing the click-swallowing band; recomputed every resolve so it tracks display/clamshell changes"
  - "graceDelay = 0.4s (within D-03's 0.3–0.5s); spring seeds response=0.35 / dampingFraction=0.65; expandedSize read from NotchPillView.expandedSize (360×72) — all single-source so Plan 05 tunes feel in one place"
  - "Click wired via an onClick: () -> Void closure on NotchPillView (default {}) so the DEBUG previews still build and the view imports no AppKit; the controller's handleClick() runs nextState(_, .clicked) inside the spring, keeping .clicked + the spring co-located with the rest of the focus-safe glue"
  - "Spring spelled inline at all four mutation sites (not factored into a stored Animation) so the animation is provably attached AT the state change and the spring is discoverable; response/damping kept as named seeds for Plan-05 tuning"

requirements-completed: [ISL-03]

# Metrics
duration: 4min
completed: 2026-06-27
---

# Phase 2 Plan 03: Focus-Safe Hover/Click Interaction Wiring Summary

**The static morph view becomes the live Alcove interaction: a global NSEvent `.mouseMoved` monitor hit-tests the pointer against the pill hot-zone and drives the pure `nextState` machine — hover fires a trackpad haptic + bounce without expanding (D-01), a click expands with the spring morph (D-02), pointer-leave collapses after a 0.4s grace delay that a re-entry cancels (D-03) — while `ignoresMouseEvents` is flipped false only inside the hot-zone and the panel is shown only via `orderFrontRegardless()`, so clicking the island never activates Islet or steals focus and clicks outside pass through (D-04).**

## Performance

- **Duration:** 4 min
- **Started:** 2026-06-27T01:11:44Z
- **Completed:** 2026-06-27T01:16:37Z
- **Tasks:** 2
- **Files modified:** 3 (0 created, 3 modified)

## Accomplishments

- **Task 1 — conditional click-through documented (NotchPanel):** `ignoresMouseEvents = true` stays the INIT value (idle = click-through, D-07; `testPanelStartsClickThrough` stays green), and the comment now marks it CONDITIONAL: the controller flips it false only in the hot-zone. Every focus-safe invariant is untouched (`.borderless, .nonactivatingPanel`, `canBecomeKey/Main == false`, `level = .statusBar`, `.canJoinAllSpaces, .fullScreenAuxiliary`). The style mask is never reassigned (`grep "styleMask =" → 0`). NotchPanelTests: 6/6 green.
- **Task 2 — the full focus-safe interaction (NotchWindowController):** the controller now DRIVES `NotchInteractionState`:
  - **Global monitor (T-02-05 mitigation):** `NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved])` only — observes copies of other apps' events, never consumes them, fires on main. No `addLocalMonitorForEvents`/`CGEvent` (grep → 0).
  - **Hit-test (Pitfall 6):** `handlePointer(at: NSEvent.mouseLocation)` tests the GLOBAL bottom-left point directly against the hot-zone — no coordinate conversion.
  - **Hover-enter (D-01):** on the false→true transition only — `NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, …)` haptic, `ignoresMouseEvents = false`, cancel any pending grace, feed `.pointerEntered` inside the spring (hover NEVER expands). DEBUG-only "hover tick" A1 probe logs once.
  - **Hover-exit (D-03):** feed `.pointerExited` (pure machine defers), schedule a 0.4s `DispatchWorkItem`; on fire it feeds `.graceElapsed` and, if `!isHovering && !isExpanded`, restores `ignoresMouseEvents = true` (Pitfall 3). A re-entry cancels the work item.
  - **Click-to-expand (D-02):** `NotchPillView.onClick` → `handleClick()` runs `nextState(_, .clicked)` inside the spring — the ONLY path to `.expanded`.
  - **Panel sized to expanded up front (Pattern 4):** `expandedNotchFrame(collapsed: collapsedFrame, expandedSize: NotchPillView.expandedSize)` is the panel frame; the transparent extra area is invisible so the morph never clips.
  - **Focus-safe (D-04):** shown only via `orderFrontRegardless()`; zero focus-stealing calls (grep → 0).
  - **Teardown:** `deinit` removes the screen observer (already) + `NSEvent.removeMonitor(m)` + cancels the grace work item.
- **NotchPillView gained `onClick: () -> Void = {}`** wired to `.onTapGesture`, so the view reports a tap via a plain closure and stays AppKit-free; the default no-op keeps the DEBUG `#Preview`s building.
- **Full suite green:** `xcodegen generate && xcodebuild build` → BUILD SUCCEEDED; `xcodebuild test` → 51 tests, 0 failures (this plan is AppKit glue — the pure seams from 02-01 remain authoritative).

## Task Commits

Each task committed atomically:

1. **Task 1: document conditional ignoresMouseEvents in NotchPanel** — `a69403e` (refactor)
2. **Task 2: global mouse monitor + click-to-expand + grace collapse + conditional click-through** — `701a40f` (feat)

## Final Wiring (consume in Plan 02-04 / Plan 05)

```swift
// NotchWindowController (AppKit glue; @MainActor)
private let interaction = NotchInteractionState()        // DRIVEN here now
private var mouseMonitor: Any?                            // global .mouseMoved monitor
private var graceWorkItem: DispatchWorkItem?             // pending grace-delay collapse
private var hotZone: CGRect?                              // collapsedFrame inset by -6px, global bottom-left
private let expandedSize = NotchPillView.expandedSize    // 360×72 — single source
private let hotZonePadding: CGFloat = 6
private let graceDelay: TimeInterval = 0.4               // D-03; Plan-05 tunable
private let springResponse = 0.35, springDamping = 0.65  // D-07; Plan-05 tunable

// resolveAndPosition(): panel frame = expandedNotchFrame(collapsed: collapsedFrame, expandedSize:)
//   contentView = NSHostingView(rootView: NotchPillView(interaction: interaction,
//                                                        onClick: { [weak self] in self?.handleClick() }))
//   shown via panel.orderFrontRegardless()  // only show call

// start(): mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { … handlePointer(at: NSEvent.mouseLocation) }
// handlePointer → handleHoverEnter (haptic + .pointerEntered + ignoresMouseEvents=false + cancel grace)
//               → handleHoverExit  (.pointerExited + schedule grace → .graceElapsed + restore ignoresMouseEvents=true)
// handleClick  → withAnimation(.spring(response:0.35,dampingFraction:0.65)) { interaction.phase = nextState(_, .clicked) }
// deinit: removeObserver + NSEvent.removeMonitor + graceWorkItem?.cancel()
```

```swift
// NotchPillView — view stays AppKit-free
var onClick: () -> Void = {}    // default no-op (DEBUG previews build); .onTapGesture { onClick() }
```

## Hot-Zone Definition (for Plan 05 on-device tuning)

- **Hot-zone:** `collapsedFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)` with `hotZonePadding = 6` — the collapsed pill frame grown 6px on each edge, in global bottom-left coords. Recomputed on every `resolveAndPosition()` so it follows resolution/display/clamshell changes.
- **Tuning seeds, all single-source in NotchWindowController:** `graceDelay = 0.4s` (D-03 0.3–0.5), `springResponse = 0.35` / `springDamping = 0.65` (D-07), `hotZonePadding = 6`, `expandedSize = NotchPillView.expandedSize` (360×72). Plan 05 adjusts feel here without touching logic.

## Focus-Safety Confirmation (T-02-06 / D-04)

- **No focus-stealing call present:** `grep -c "makeKeyAndOrderFront\|NSApp.activate\|makeKey(" NotchWindowController.swift → 0`. The only show call is `orderFrontRegardless()`.
- Panel remains `.nonactivatingPanel` + `canBecomeKey/Main == false` (NotchPanel.init, never toggled).
- `ignoresMouseEvents` toggles in BOTH directions (`= false` on hover-enter, `= true` on grace-collapse) and is restored deterministically whenever `!isHovering && !isExpanded` (Pitfall 3 / T-02-05).
- Global monitor only; no local monitor / CGEvent tap; `.mouseMoved` mask only (no keyboard); pointer location never logged in release (A1 probe is `#if DEBUG`). Monitor removed in `deinit`.

## A1 Probe + Fallback Readiness (for Plan 05 on-device check)

- **Probe:** `#if DEBUG` one-shot `print("hover tick — global mouse monitor fired (A1 probe)")` on the first hover-enter. `addGlobalMonitorForEvents` returns a non-nil token even when the OS gated it behind Accessibility and never fires — so the log (not the token) is the evidence the monitor actually fires unprompted on Tahoe.
- **Ready fallback (Pattern 1b, permission-free):** if Plan 05 finds the global monitor IS gated, swap to an `NSTrackingArea` (`.activeAlways, .mouseEnteredAndExited, .inVisibleRect`) on a thin hit view inside the hosting view, keeping `ignoresMouseEvents = false` on just the pill region. Tradeoff documented: the pill region loses click-through even when collapsed (acceptable for a notch-hugging pill). No Accessibility is requested in this plan.

## Decisions Made

- **Click via an `onClick` closure, not a `handleClick()` on the state:** keeps `.clicked` + the spring co-located with the rest of the focus-safe glue in the controller (where the acceptance criteria expect them) AND keeps `NotchPillView` AppKit-free. The default `{}` means the DEBUG `#Preview`s and any unit construction build without a controller.
- **Spring inline at the four mutation sites** (not a stored `Animation`): the animation is provably attached AT the state change (D-08 — the view drives none), and the `withAnimation(.spring(...))` is discoverable. `response`/`dampingFraction` kept as named seeds so Plan 05 tunes one place.
- **Hot-zone = collapsed pill + 6px:** comfortable to enter without growing the always-interactive band; well within "pill bounds, possibly slightly padded" (Claude's discretion). Recomputed each resolve so it never drifts from the live notch.
- **Panel sized to expanded up front (Pattern 4 over animating setFrame):** flicker-free; the transparent extra area is invisible, and the SwiftUI morph animates content inside a fixed expanded-sized window.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Reworded the focus-safety comment so the grep-enforced contract is checked against CODE, not a comment**
- **Found during:** Task 2 verification.
- **Issue:** The focus-safety doc comment originally spelled `makeKeyAndOrderFront / NSApp.activate / makeKey()` verbatim to document what the file must NEVER do. The acceptance criterion `grep -c "makeKeyAndOrderFront\|NSApp.activate\|makeKey(" → 0` then matched those COMMENT tokens (returned 2), so the grep could no longer prove the absence of the actual calls — the same comment-vs-grep fragility flagged in 02-02-SUMMARY.
- **Fix:** Reworded the comment to "no key-and-order-front, no app activation, no make-key" (no verbatim API tokens). The contract is still documented; the grep now reflects real code only. `grep → 0`.
- **Files modified:** Islet/Notch/NotchWindowController.swift
- **Verification:** `grep -c "makeKeyAndOrderFront\|NSApp.activate\|makeKey(" → 0`; BUILD SUCCEEDED; 51 tests green.
- **Committed in:** `701a40f` (Task 2 commit)

**2. [Rule 1 — Bug] Inlined the spring at the mutation sites so the spring is provably at the state change**
- **Found during:** Task 2 verification.
- **Issue:** The spring was first factored into a stored `private let morphSpring = Animation.spring(...)` and call sites read `withAnimation(morphSpring)`. The acceptance criterion `grep "withAnimation(.spring"` would then have matched only a doc comment, not the actual mutations — the spring would not be provably AT the state change.
- **Fix:** Replaced the stored `Animation` with named `springResponse`/`springDamping` seeds and inlined `withAnimation(.spring(response: springResponse, dampingFraction: springDamping))` at all four mutation sites (hover-enter `.pointerEntered`, hover-exit `.pointerExited`, grace `.graceElapsed`, click `.clicked`). The spring is now genuinely at every state mutation and the seeds remain a single tuning point.
- **Files modified:** Islet/Notch/NotchWindowController.swift
- **Verification:** `grep -c "withAnimation(.spring" → 6` (4 real mutation sites + 2 doc refs); BUILD SUCCEEDED; 51 tests green.
- **Committed in:** `701a40f` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 bugs, both verification-hardening). No scope change — both keep the implementation honest against the grep-enforced focus-safety/animation criteria.

## Known Stubs

None introduced by this plan. The expanded date/time placeholder in `NotchPillView` (`Text(Date.now, …)`) is the pre-existing, intentional D-05 placeholder from Plan 02-02 (already tracked in 02-02-SUMMARY) and is untouched here.

## Issues Encountered

None affecting correctness. `xcodebuild` emits the documented benign macOS 26 / Xcode 26 environment noise (`CoreSimulator out of date`, `linkd.autoShortcut`) — unrelated to the macOS test destination; all 51 tests pass and the build succeeds.

## Next Phase Readiness

- **Plan 02-04** (fullscreen runtime wiring) extends the SAME `resolveAndPosition()` / single-show-call discipline: it adds the fullscreen input to one unified `updateVisibility()`-style decision (Pattern 7), reusing `isTrueFullscreen` + `shouldShow` (02-01) and the focus-safe `orderFrontRegardless()` shown here. The global monitor + grace timer + conditional click-through established here do not conflict — they are pointer-side; 02-04 is visibility-side.
- **Plan 05** (on-device verify) runs the three manual checks the greps cannot: (1) the A1 hover-tick probe confirms the global `.mouseMoved` monitor fires unprompted on Tahoe (else flip to the documented `NSTrackingArea` fallback); (2) clicking the island never activates Islet / steals focus and clicks outside pass through (T-02-05/T-02-06); (3) the morph reads as one smooth spring. All tuning seeds are single-sourced in NotchWindowController for that pass.
- **Carry-forward:** the two HIGH focus/event-hijacking threats (T-02-05, T-02-06) are mitigated in code and grep-enforced here; their on-device re-verification is Plan 05. No blockers.

## Self-Check: PASSED

All 3 modified source files and the SUMMARY exist on disk; both task commits (`a69403e`, `701a40f`) are present in git history. `xcodegen generate && xcodebuild build` → BUILD SUCCEEDED; full suite → 51 tests, 0 failures. All Task 1 + Task 2 acceptance-criteria greps verified (global `.mouseMoved` monitor present; 0 local/CGEvent; 0 focus-stealing calls; both `ignoresMouseEvents` toggle directions; haptic; `expandedNotchFrame`; `.clicked` + `.pointerEntered`; `withAnimation(.spring`; `orderFrontRegardless`; `removeMonitor` in deinit; `graceDelay = 0.4`; DEBUG hover-tick probe).

---
*Phase: 02-hover-expand-fullscreen-hardening*
*Completed: 2026-06-27*
