---
phase: 02-hover-expand-fullscreen-hardening
plan: 04
subsystem: ui
tags: [swift, appkit, swiftui, nspanel, nsworkspace, coregraphics, cgs, skylight, fullscreen, isl-05]

# Dependency graph
requires:
  - phase: 02-hover-expand-fullscreen-hardening
    provides: "Plan 02-01 pure shouldShow(hasTarget:hideInFullscreen:isFullscreen:) visibility AND; Plan 02-03 NotchWindowController interaction wiring (global mouse monitor, click-to-expand, grace collapse)"
  - phase: 01-the-empty-island
    provides: "ScreenDescriptor + selectTargetScreen + notchFrame + NSScreen.descriptor (display resolution seam); didChangeScreenParameters observer"
provides:
  - "ISL-05 runtime fullscreen-yield: the island hides on true (native) fullscreen of the built-in display and auto-restores on exit"
  - "FullscreenSpaceProbe.swift — a CGS managed-display-spaces runtime fullscreen signal (isBuiltinDisplayInFullscreenSpace(builtinUUID:)), fail-safe to false"
  - "A single unified updateVisibility() in NotchWindowController — the SOLE show/hide site (one orderOut, one orderFrontRegardless); clamshell/display-target AND fullscreen converge here"
  - "hideInFullscreen seam (default-true stored let) for the Phase-6 (APP-03) settings toggle"
affects: [06-priority-resolver-settings-ship]

# Tech tracking
tech-stack:
  added: ["Private CoreGraphics/SkyLight CGS API via @_silgen_name (CGSMainConnectionID, CGSCopyManagedDisplaySpaces)"]
  patterns:
    - "Pattern 6: NSWorkspace activeSpaceDidChange + didActivateApplication observers re-run the ONE visibility decision; torn down against NSWorkspace.shared.notificationCenter in deinit"
    - "Pattern 7: a single idempotent updateVisibility() is the only show/hide path — no second orderOut/orderFront anywhere"
    - "Runtime fullscreen detection via CGS managed display spaces (current-space type==4), not via the agent's own safe area — a background LSUIElement cannot observe another app's fullscreen from its own physical display geometry"

key-files:
  created:
    - "Islet/Notch/FullscreenSpaceProbe.swift"
  modified:
    - "Islet/Notch/NotchWindowController.swift"
    - "Islet/Notch/FullscreenDetector.swift"

key-decisions:
  - "Q3 pivot: the safe-area predicate isTrueFullscreen(builtin:) is superseded as the LIVE signal by a CGS managed-display-spaces probe; the safe-area predicate is kept only as a pure heuristic + its tests"
  - "Runtime fullscreen = built-in display's CURRENT-space type == 4 (kCGSSpaceFullscreen), confirmed on-device on Tahoe"
  - "Enter-transition 1-frame flash is product-deferred (root-caused as compositor-side, not our code) — no show-debounce (the attempt was reverted)"

patterns-established:
  - "Pattern 6: NSWorkspace fullscreen/space observers feed one visibility decision and are removed from the workspace center in deinit"
  - "Pattern 7: one updateVisibility() = the single show/hide site (orderOut==1, orderFrontRegardless==1)"
  - "Private CGS symbols bound via @_silgen_name (no dlopen); any nil/parse/ambiguity fails safe to false (prefer showing over wrongly hiding)"

requirements-completed: [ISL-05]

# Metrics
duration: ~3h (incl. on-device verification + Q3 CGS pivot)
completed: 2026-06-27
---

# Phase 2 Plan 4: ISL-05 Fullscreen-Yield Runtime Wiring Summary

**The island now hides on true (native) fullscreen of the built-in display and auto-restores on exit, driven at runtime by a CGS managed-display-spaces probe (current-space type==4) fed into a single unified updateVisibility() — replacing the safe-area heuristic that a background agent could never observe.**

## Performance

- **Duration:** ~3h (includes on-device verification and the Q3 detection-mechanism pivot)
- **Started:** 2026-06-27 (post 02-03 chain)
- **Completed:** 2026-06-27
- **Tasks:** 2 (1 autonomous code + 1 human-verify checkpoint)
- **Files modified:** 2 (+1 created)

## Accomplishments

- **ISL-05 runtime path is live and on-device VERIFIED for native fullscreen:** entering native (green-button / Ctrl-Cmd-F) fullscreen on the built-in notched display HIDES the island completely, and exiting RESTORES it.
- **Q3 resolved with a detection pivot:** the original safe-area predicate `isTrueFullscreen(builtin:)` was wired first (`7e783dd`) but failed on-device — the built-in's safe area is a *physical-display* property that does NOT change when *another* app enters fullscreen, and Islet (an `LSUIElement` background agent) never goes fullscreen itself, so from its process the safe-area signal was always false and the island never hid. Replaced with a CGS managed-display-spaces probe (`FullscreenSpaceProbe.swift`, `87f375e`/`0cbdf3e`) that reads the built-in's CURRENT-space `type`.
- **CGS detection constant confirmed on-device (Tahoe/macOS 26):** the built-in's current-space `type == 4` in fullscreen, `0` otherwise — confirmed via the DEBUG `[ISL-05] builtin current-space type = …` trace. The probe fails safe to `false` on any nil/parse/ambiguity (prefers showing over wrongly hiding).
- **Single-path contract held (Pitfall 5):** there is exactly ONE `updateVisibility()`, one `orderOut`, one `orderFrontRegardless`; the old `resolveAndPosition()` function is gone (only a comment reference remains). All three observers (didChangeScreenParameters, activeSpaceDidChange, didActivateApplication) call only `updateVisibility()`.
- **Threat mitigations enforced (grep + on-device):** no AX prompt (`AXUIElement`/`kAXFullscreenAttribute`/`AXIsProcessTrustedWithOptions` absent → T-02-09); no focus-stealing call (`makeKeyAndOrderFront`/`NSApp.activate`/`makeKey(` absent, restore is `orderFrontRegardless` only → T-02-08); no UserDefaults/Settings UI (D-10 seam only).

## Task Commits

1. **Task 1: Unified updateVisibility + hideInFullscreen seam + NSWorkspace observers (initial safe-area wiring)** - `7e783dd` (feat)
2. **Task 1 (cont.): CGS managed-display-spaces fullscreen probe** - `87f375e` (feat) — adds `FullscreenSpaceProbe.swift`
3. **Task 1 (cont.): feed CGS signal into updateVisibility, supersede safe-area heuristic** - `0cbdf3e` (fix)
4. **Show-debounce attempt (later reverted)** - `cc7f3c1` (fix)
5. **Revert show-debounce — enter flash is compositor-side, nothing to debounce** - `f706f66` (revert)
6. **Task 2: On-device human-verify checkpoint** — resolved by the user (native fullscreen VERIFIED; constant type==4 confirmed; enter-flash deferred; items 2–6 pending UAT). No code commit (verification step).

**Plan metadata:** (this docs commit)

## Files Created/Modified

- `Islet/Notch/FullscreenSpaceProbe.swift` (created) — `isBuiltinDisplayInFullscreenSpace(builtinUUID:)`: the LIVE runtime fullscreen signal. Binds the private CGS symbols `CGSMainConnectionID` + `CGSCopyManagedDisplaySpaces` via `@_silgen_name` (no dlopen), reads the built-in display dict's `Current Space` → `type`, and returns `type == 4`. Fail-safe `false` on any nil/parse/ambiguity. DEBUG-only trace prints the observed type for on-device confirmation.
- `Islet/Notch/NotchWindowController.swift` (modified) — added the `hideInFullscreen = true` D-10 seam, two `NSWorkspace` observers (`activeSpaceDidChange` + `didActivateApplication`, Pattern 6), `currentBuiltin()`, and the single `updateVisibility()` (Pattern 7) that ANDs `selectTargetScreen` (target) with `isBuiltinDisplayInFullscreenSpace(...)` (fullscreen) via the pure `shouldShow(...)`. The bare `orderOut` is gone; `resolveAndPosition()` was split into `updateVisibility()` (the sole decision) + `positionAndShow(on:)` (frame+show body, no hide decision). All three observers removed from their respective centers in `deinit`.
- `Islet/Notch/FullscreenDetector.swift` (modified) — the safe-area `isTrueFullscreen(builtin:)` is now documented as a SUPERSEDED pure heuristic (no longer the runtime signal), retained only to keep `FullscreenDetectorTests` green and document the original idea. `shouldShow(...)` (the pure visibility AND) is unchanged and still the runtime gate.

## updateVisibility() final shape (for the Phase-6 toggle / 02-03 merge)

```
updateVisibility():
  descriptors = NSScreen.screens.map(\.descriptor)
  target      = selectTargetScreen(from: descriptors)                     // Phase-1: built-in present + notched
  fullscreen  = isBuiltinDisplayInFullscreenSpace(builtinUUID: currentBuiltin()?.uuid)  // Phase-2: CGS runtime signal
  if shouldShow(hasTarget: target != nil, hideInFullscreen: hideInFullscreen, isFullscreen: fullscreen), let target:
      positionAndShow(on: target)   // the ONLY orderFrontRegardless
  else:
      panel?.orderOut(nil); hotZone = nil   // the ONLY orderOut
```

- The Phase-6 (APP-03) settings toggle wires to exactly one property: `hideInFullscreen` (flip `let`→`var`, no logic edit).
- The show body (`positionAndShow`) already folds in 02-03's expanded-frame sizing + `NotchPillView(interaction:onClick:)` injection — there is ONE show site, ONE hide site (merge_note honored).

## Decisions Made

- **Q3 (RESEARCH Open Question) — detection mechanism:** the safe-area heuristic is the wrong signal for a background agent; pivoted to the CGS managed-display-spaces probe. The safe-area predicate stays as a documented, test-covered pure heuristic but is explicitly NOT the runtime signal.
- **No AX corroboration:** the CGS probe needs no Accessibility/TCC prompt and caught native fullscreen cleanly on-device, so the AX path (which WOULD prompt) is not wired — confirming the T-02-09 mitigation in code and on-device.
- **Enter-transition flash deferred (product decision by the user):** no show-debounce — the attempt (`cc7f3c1`) was reverted (`f706f66`) because there is no blip on our side to debounce. See Known issues.

## Deviations from Plan

The plan specified the runtime fullscreen signal as the Plan 02-01 safe-area predicate `isTrueFullscreen(builtin:)`. On-device that predicate could not work for a background agent (it only sees its own physical display's constant safe area). This was an in-scope correctness fix discovered at the Task-2 checkpoint:

### Auto-fixed Issues

**1. [Rule 1 - Bug] Runtime fullscreen signal could never fire for a background agent**
- **Found during:** Task 2 (on-device human-verify checkpoint)
- **Issue:** `isTrueFullscreen(builtin:)` infers fullscreen from the built-in's safe-area/notch band, but the safe area is a physical-display property that does not change when ANOTHER app enters fullscreen; Islet (`LSUIElement`) never goes fullscreen itself, so the signal was always `false` and the island never hid.
- **Fix:** Added `FullscreenSpaceProbe.swift` (`isBuiltinDisplayInFullscreenSpace(builtinUUID:)`) using the private CGS "Managed Display Spaces" API (current-space `type == 4`), bound via `@_silgen_name`, fail-safe to `false`. Fed it into `updateVisibility()` in place of the safe-area call; documented the safe-area predicate as superseded. This is the documented approach used by the reference app boring.notch and needs no AX/TCC prompt.
- **Files modified:** `Islet/Notch/FullscreenSpaceProbe.swift` (created), `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/FullscreenDetector.swift`
- **Verification:** On-device — native fullscreen now hides the island and exiting restores it; DEBUG trace confirms `type == 4` in fullscreen, `0` otherwise. Full test suite green (51 tests, 0 failures — the pure `shouldShow` AND is unchanged).
- **Committed in:** `87f375e`, `0cbdf3e`

**2. [Rule 1 - reverted] Show-debounce to mask an enter-transition flash**
- **Found during:** Task 2 (on-device)
- **Issue:** A ~1-frame flash of the island appears at the END of the fullscreen-ENTER transition.
- **Fix attempt:** A 0.2s show-debounce (`cc7f3c1`) — then REVERTED (`f706f66`): console tracing showed the flash is NOT from our code (on enter we only ever call `orderOut`, never `orderFrontRegardless`; CGS reads `type 4` cleanly with no transient blip). There is nothing on our side to debounce, so the debounce was removed. See Known issues.
- **Committed in:** `cc7f3c1` (revert: `f706f66`)

---

**Total deviations:** 1 auto-fixed (Rule 1 — wrong runtime signal for a background agent) + 1 attempted-and-reverted.
**Impact on plan:** The fix was necessary for ISL-05 to function at all; the seam, single-path contract, threat greps, and the pure `shouldShow` AND are all unchanged. No scope creep — the safe-area predicate and its tests are retained.

## Known issues / deferred

### Fullscreen-ENTER 1-frame flash (product-deferred to a later polish phase)

- **Symptom:** A ~1-frame flash of the island appears at the END of the fullscreen-ENTER transition, then it hides correctly. (Exit/restore has no flash.)
- **Root cause (console-traced):** NOT our code. On enter we only ever call `orderOut`, never `orderFrontRegardless`; CGS reads `type 4` cleanly with no transient blip. It is the window server compositing the `.canJoinAllSpaces` panel onto the activating fullscreen Space; our `orderOut` is REACTIVE (fired only after `activeSpaceDidChange`) and cannot pre-empt the compositor.
- **Things tried (did not fix):** removing `.fullScreenAuxiliary` did not help; a 0.2s show-debounce was tried (`cc7f3c1`) and reverted (`f706f66`) — there is no blip on our side to debounce.
- **Why deferred:** a real fix must hide the panel BEFORE the transition completes, but no reliable background-agent signal exists to fire that early. Negligible in the release pill (pure black / flush to the notch). Deferred to a later polish phase (Plan 05 on-device tuning / Phase 6).

## Pending human verification (RESEARCH Q2 — per-kind fullscreen behavior on Tahoe)

Only **native fullscreen** was on-device verified. The following are NOT yet tested on-device and remain open UAT items (they resolve RESEARCH Q2 — whether the CGS probe covers every fullscreen kind):

1. **Fullscreen video** (YouTube fullscreen in Safari, QuickTime Player fullscreen) — EXPECT: island hides; exiting restores.
2. **QuickLook** (Finder → Space → QuickLook fullscreen toggle) — EXPECT: island hides; closing restores.
3. **Maximized window must STAY visible** (double-click title bar / option-click green button without entering fullscreen) — EXPECT: island stays visible (not a fullscreen Space).
4. **Clamshell + external-display coexistence** (lid close/open, fullscreen on the external while the built-in is present) — EXPECT: no flicker / no stuck-hidden / no stuck-shown.
5. **Focus-safety of the auto-restore** (restoring after fullscreen exit must not steal focus from the foreground app) — `orderFrontRegardless` only.

If any kind fails to hide via the CGS probe, the AX-corroboration path (Q3, would prompt) would be reconsidered then — but the on-device native-fullscreen result plus the probe's display-space semantics make that unlikely.

## Q3 resolution note (detection mechanism)

- **Resolved:** runtime fullscreen detection uses the CGS managed-display-spaces probe (current-space `type==4`), NOT the safe-area heuristic and NOT an AX read.
- The safe-area predicate `isTrueFullscreen(builtin:)` is **superseded** as the live signal and kept only as a pure, test-covered heuristic (documenting the original idea + keeping `FullscreenDetectorTests` green).
- No Accessibility/TCC prompt is introduced (T-02-09 mitigation confirmed in code and on-device).

## Issues Encountered

- The first wiring used the safe-area predicate (per plan) and did not hide on-device — root-caused at the checkpoint as the background-agent / physical-display-property mismatch, fixed by the CGS pivot (see Deviations #1).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- **ISL-05 native fullscreen is live and verified;** Phase 2's success criterion 3 (hide on true fullscreen, restore on exit) is met for native fullscreen.
- **Phase 6 (APP-03):** the settings toggle wires to exactly one property — `hideInFullscreen` (flip `let`→`var`).
- **Carry-forward UAT:** the five Q2 items above (fullscreen video, QuickLook, maximized-stays-visible, clamshell coexistence, focus-safe restore) and the deferred enter-flash polish should be picked up in Plan 05 on-device tuning / Phase 6.

## Self-Check: PASSED

---
*Phase: 02-hover-expand-fullscreen-hardening*
*Completed: 2026-06-27*
