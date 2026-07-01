# Debug: fullscreen-enter-flash

## Symptom
Enter true fullscreen (e.g. a fullscreen video) via the slide transition while
an activity would normally splash. Expected: the island stays hidden
throughout, never popping over the fullscreen app. Actual (UAT Test 5,
`06-UAT.md`): "immernoch der kleine mini flash wenn man mit der Slide
animation zum Fullscreen kommt das dann der kurze nochmal flash kommt" — a
brief island flash still appears at the END of the fullscreen-enter
transition.

## Status: ROOT CAUSE CONFIRMED — pre-existing Phase-2 issue, NOT a Phase-6 regression (diagnosis only — no fix applied)

## Root cause (unchanged since Phase 2 / 02-04)

The flash is the window server compositing the panel's `.canJoinAllSpaces`
overlay onto the activating fullscreen Space during the Space-switch
animation itself. `NotchWindowController.updateVisibility()` (the single
show/hide arbiter) only ever calls `panel?.orderOut(nil)`; it never calls
`orderFrontRegardless()` reactively during a hide. The hide fires correctly,
but only in response to `NSWorkspace.activeSpaceDidChangeNotification` /
`didActivateApplicationNotification` — both of which land AFTER the Space
transition (and its compositor pass) has already happened. A reactive
`orderOut` cannot pre-empt a compositor frame that already rendered before
the notification arrived. This was console-traced and documented in Phase 2
(`.planning/phases/02-hover-expand-fullscreen-hardening/02-04-SUMMARY.md`,
"Known issues / deferred → Fullscreen-ENTER 1-frame flash"): on enter, the
CGS signal reads `type == 4` cleanly with no transient non-fullscreen blip on
our side, and our code never calls `orderFrontRegardless()` during enter — so
there is nothing in application logic to debounce or delay. A 0.2s
show-debounce was tried (`cc7f3c1`) and reverted (`f706f66`) for exactly this
reason: it added restore latency while fixing nothing, because the blip was
never on our side.

## Confirmation this is the SAME issue, not a new Phase-6 path

Checked whether Phase 6's single-arbiter resolver / `TransientQueue` wiring
introduced a NEW code path that could flip `updateVisibility()` mid-transition
(e.g. a queued transient's dismiss timer firing right as `isTrueFullscreen`
changes) — it does not:

1. **The fullscreen-gating files are untouched by Phase 6.**
   - `git log --oneline -- Islet/Notch/FullscreenSpaceProbe.swift` → only
     `87f375e` (Phase 2, 02-04).
   - `git log --oneline -- Islet/Notch/FullscreenDetector.swift` → only
     `0cbdf3e` and `324a0fe` (both Phase 2, 02-01/02-04).
   - `git log --oneline -- Islet/Notch/NotchPanel.swift` → only `a78b1c4`
     (Phase 1) and `a69403e` (Phase 2, comment-only); `collectionBehavior =
     [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`
     (`NotchPanel.swift:32`) is exactly what was already in place when the
     Phase-2 root cause was diagnosed.
   - `git log -L 372,399:Islet/Notch/NotchWindowController.swift` (the
     `updateVisibility()` body) → the fullscreen-gate logic itself (the
     `isBuiltinDisplayInFullscreenSpace` call, the `shouldShow(...)` check,
     the single `panel?.orderOut(nil)` hide site) has not changed since
     `0cbdf3e`/`f706f66` landed in Phase 2. The only post-Phase-2 edit to this
     function is `eb1a929` (Phase 4) adding `expandedZone = nil` to the hide
     branch — unrelated to fullscreen gating.
   - `hideInFullscreen` (`NotchWindowController.swift:44`) is still a
     hardcoded `private let hideInFullscreen = true`. The Phase-2 comment
     above it says "Phase 6 (APP-03) will flip `let`→`var` and wire a
     preferences toggle" — that flip never happened; `grep -rn
     hideInFullscreen` shows no settings/`UserDefaults` read feeding it
     anywhere. So Phase 6 also did not add a live-toggle race on this flag.

2. **Every Phase-6 call site funnels through the SAME single arbiter, not a
   second show/hide path.** `handlePower`, `handleDevice`,
   `scheduleActivityDismiss`, `scheduleDeviceBatteryRefresh`,
   `handleSettingsChanged`, `handleNowPlaying`, `scheduleMediaDismiss`, and
   `handleAdapterTerminated` all end by calling `updateVisibility()` — never
   `panel.orderFrontRegardless()` or `panel?.orderOut(nil)` directly. Pattern
   7 (documented at `NotchWindowController.swift:365-371`) is intact:
   "one updateVisibility() = the single show/hide site." Even if one of these
   new one-shot timers (e.g. the ~3s transient-queue dismiss) happened to
   fire in the same instant as a fullscreen-enter transition, it would call
   the SAME `updateVisibility()`, which re-reads the live CGS signal
   (`isBuiltinDisplayInFullscreenSpace`, a synchronous system call, not a
   cached/stale value) at call time and behaves idempotently — it does not
   introduce an additional hide→show→hide flip beyond what the compositor
   itself already causes.

3. **The UAT report scenario matches the Phase-2 description precisely**:
   "while an activity would normally splash" implies the island panel is
   already visible when fullscreen engages (matching the original repro), and
   the flash is reported "at the end of the transition" — the same timing
   signature as the console-traced Phase-2 finding, not an early/mid-transition
   pop that would suggest a race in the new resolver logic.

## Ruled out
- **Phase-6 resolver (`IslandResolver.swift`) as a source**: `resolve()` and
  `TransientQueue` are pure Foundation-only value types (no AppKit, no window
  calls, no clock) — they cannot themselves call `orderFrontRegardless`/
  `orderOut`. They only ever change what `currentPresentation()` returns; the
  controller still gates every render through `updateVisibility()`
  afterward, unchanged from Phase 2.
- **A new toggle-driven show/hide race**: `hideInFullscreen` was never wired
  to a live settings toggle in Phase 6 (still a hardcoded `let`), so there is
  no live-flip path through Settings that could race the fullscreen gate.
- **Panel `collectionBehavior` regression**: `.canJoinAllSpaces` /
  `.fullScreenAuxiliary` are unchanged since Phase 1/2 — Phase 2's own
  research already tried removing `.fullScreenAuxiliary` and it did not help,
  consistent with the compositor-side (not collection-behavior-side) root
  cause.

## Why this is deferred, not fixable at the application layer
Per the Phase-2 finding (still accurate): a real fix would require hiding the
panel BEFORE the Space transition's compositor pass runs, but there is no
reliable background-agent (LSUIElement) signal that fires that early — every
available signal (`activeSpaceDidChangeNotification`,
`didActivateApplicationNotification`, the CGS space-type probe) is reactive,
firing only after the transition has already been composited. This is a
window-server timing constraint, not an application bug.

## Verdict
This is the exact same pre-existing, product-deferred Phase-2 (02-04)
window-server compositing flash re-surfacing during Phase-6 UAT — it is a
re-confirmation, not a new Phase-6 regression. No code changes recommended
from this investigation; the existing product decision to defer remains
valid. If prioritization changes, note that a proactive (non-reactive) hide
signal would be required (e.g. hooking a lower-level Space-transition-start
callback, if one becomes available), not another debounce — Phase 2 already
proved debouncing the show doesn't help since there is no on-side blip to
debounce.

## Files involved
- `Islet/Notch/NotchWindowController.swift:365-399` — `updateVisibility()`,
  the single show/hide arbiter (unchanged fullscreen-gate logic since Phase 2
  except an unrelated Phase-4 line); `:44` `hideInFullscreen` still hardcoded
  `let`
- `Islet/Notch/FullscreenSpaceProbe.swift` — `isBuiltinDisplayInFullscreenSpace`,
  the synchronous CGS managed-display-spaces probe (untouched since Phase 2)
- `Islet/Notch/FullscreenDetector.swift` — `shouldShow(...)` pure gate
  (untouched since Phase 2)
- `Islet/Notch/NotchPanel.swift:32` — `collectionBehavior` incl.
  `.canJoinAllSpaces` (the panel kind the compositor draws onto the
  activating Space)
- `Islet/Notch/IslandResolver.swift` — Phase-6 pure resolver/`TransientQueue`;
  confirmed to have no AppKit/window-call surface, ruled out as a source
- `.planning/phases/02-hover-expand-fullscreen-hardening/02-04-SUMMARY.md` —
  original root-cause analysis, the show-debounce attempt, and its revert
- commit `f706f66` — the show-debounce revert ("fullscreen-enter flash is
  compositor-side")
- `.planning/phases/06-priority-resolver-settings-v1-ship/06-UAT.md` (Test 5)
  — the re-confirmation report this investigation validates
