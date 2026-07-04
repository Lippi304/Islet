---
phase: 08-fullscreen-enter-flash-elimination
requirement: FS-01
status: escalated
created: 2026-07-04
---

# FS-01 Escalation Report: Fullscreen-Enter Island Flash

## Root Cause

The ~1-frame island flash at the end of the fullscreen-enter transition is a
**window-server compositor timing gap**, not an application-layer bug. It has
now been diagnosed three separate times, in three separate investigations,
with the same underlying finding:

- **Phase 2 (`02-04-SUMMARY.md`):** on entering true (native) fullscreen, the
  window server composites the notch panel's `.canJoinAllSpaces` overlay onto
  the activating fullscreen Space for approximately one frame, before our
  code's only hide mechanism — `NotchWindowController.updateVisibility()` →
  `panel?.orderOut(nil)` — has a chance to run. The hide is wired to
  `NSWorkspace.activeSpaceDidChangeNotification` /
  `didActivateApplicationNotification`, both of which are **reactive**: they
  fire only *after* the Space transition (and its compositor pass) has
  already happened. On enter, our code never calls `orderFrontRegardless()`,
  and the CGS current-space-type probe (`isBuiltinDisplayInFullscreenSpace`)
  reads cleanly (`type == 4`, no transient blip) — there is nothing on our
  side to debounce. A 0.2s show-debounce was tried (`cc7f3c1`) and reverted
  (`f706f66`) for exactly this reason: it only added restore latency without
  touching the actual timing gap.
- **Phase 6 debug session (`.planning/debug/resolved/fullscreen-enter-flash.md`):**
  re-confirmed the flash after the Phase-6 priority-resolver/TransientQueue
  rewrite, and ruled out the new resolver code as a source (it is a pure,
  AppKit-free value type with no window-call surface; every Phase-6 call site
  still funnels through the same single `updateVisibility()` arbiter). Verdict:
  same pre-existing Phase-2 issue re-surfacing, not a Phase-6 regression.
- **Phase 8 (this phase, `08-01-SUMMARY.md`):** identified and on-device tested
  a genuinely new candidate signal — the private CGS notification pair
  `CGSClientEnterFullscreen`/`CGSClientExitFullscreen` (event codes 106/107),
  registered globally via `CGSRegisterNotifyProc`. This is a materially
  different *kind* of signal than what Phase 2/6 tried: a raw WindowServer
  client-lifecycle push notification (the same mechanism Dock.app uses to
  sync its own hide/reclaim animation), not a Cocoa-level Space/app-activation
  notification. Registration succeeded on-device (return code `0`, no error),
  refuting a blanket "this API is dead on modern macOS" concern. But the
  decisive on-device trigger-matrix run (see below) found it **never fires**
  for another process's real fullscreen transition — closing off this avenue
  too.

In short: every available application-layer signal — the two reactive
`NSWorkspace` notifications, the CGS current-space-type probe, and now the
raw CGS client-fullscreen event pair — either fires only after the compositor
has already drawn the flash frame, or (in the case of 106/107) does not fire
for a foreign process at all. No proactive (pre-compositor-pass) signal has
been found to exist at the application layer across three independent
investigations spanning Phase 2, Phase 6, and Phase 8.

## What Was Tried This Phase

Phase 8 did not restate the Phase-2/Phase-6 conclusion — it identified and
on-device tested one concrete new candidate, per D-07.

**Candidate: `CGSClientEnterFullscreen` (106) / `CGSClientExitFullscreen` (107)
via `CGSRegisterNotifyProc`.**

- **Wave 0 (08-01, Task 1):** added DEBUG-only instrumentation to
  `FullscreenSpaceProbe.swift` (the constants, `CGSNotifyProc` typealias, and
  `@_silgen_name` bindings for `CGSRegisterNotifyProc`/`CGSRemoveNotifyProc`)
  and `NotchWindowController.swift` (registration in `start()`, teardown in
  `deinit`, a main-thread-hopping callback, and `[FS-01 probe]` logging
  alongside the existing `spaceObserver`/`appActivateObserver` prints).
  Verified: build succeeded, 141/141 tests passing (no regression).
- **Wave 0 (08-01, Task 2 — on-device D-05 trigger matrix):** the user ran
  the full three-method trigger matrix (green-button click, menu-bar "Enter
  Full Screen", a fullscreen video app), 3 full enter→exit cycles, on real
  notch hardware (Tahoe/macOS 27, Xcode 26.6). Captured raw Xcode console
  output (quoting `08-01-SUMMARY.md`'s "Task 2 — RESOLVED: option-c" section):

  ```
  [FS-01 probe] didActivateApplication fired at 2026-07-04 01:07:54 +0000
  [ISL-05] builtin current-space type = 0
  [FS-01 probe] activeSpaceDidChange fired at 2026-07-04 01:07:56 +0000
  [ISL-05] builtin current-space type = 4        <- fullscreen entered (cycle 1)
  [FS-01 probe] activeSpaceDidChange fired at 2026-07-04 01:08:00 +0000
  [ISL-05] builtin current-space type = 0        <- fullscreen exited (cycle 1)
  ... (cycles 2 and 3 follow the identical pattern)
  ```

  **Finding:** across all 3 full enter/exit cycles spanning all three D-05
  trigger methods, **not a single `[FS-01 probe] CGS event 106` or `CGS event
  107` line appears anywhere in the captured output.** Only the pre-existing
  reactive signals (`activeSpaceDidChange`, `didActivateApplication`) fired —
  exactly as they did before this phase — confirmed via the existing
  `isBuiltinDisplayInFullscreenSpace` CGS-Spaces read flipping `4↔0` in
  lockstep with each real transition. `CGSRegisterNotifyProc` registration
  itself did not error (no crash, no exception) — the callback path is simply
  never invoked by WindowServer for these transitions, in this un-sandboxed,
  non-Apple-bundle-id process. The user confirmed the visible ~1-frame island
  flash **still occurs** on fullscreen entry across these trials.

  This mirrors the exact risk RESEARCH.md flagged as "Pitfall 2": event
  106/107 may be scoped to only the *registering connection's own*
  transitions rather than global (all-connections) events, despite the
  registration API accepting the same global (`cid`-less) call shape used by
  `kCGSNotificationWorkspaceChanged` (1401). The Assumptions Log's A1
  ("106/107 actually fire for a DIFFERENT process's fullscreen transition")
  is now falsified by on-device evidence.

**Decision recorded (`08-01-SUMMARY.md`): option-c — Candidate A disproven.**
No timing advantage exists over the existing reactive signals; the candidate
provides no closable gap. Per D-07, this phase's own on-device attempt at the
one new candidate identified in research is exhausted.

## Untried Fallback

RESEARCH.md documented a secondary candidate that was **not** attempted
on-device this phase, and remains available for a future investigation
session if the user chooses `option-investigate-b`:

**`SLSManagedDisplayIsAnimating` (a poll, not a push notification).**

- Confirmed callable on-device during research (returns `false` at rest), but
  **only** after explicitly linking `SkyLight.framework` — it is not
  re-exported through `CoreGraphics` the way the existing
  `CGSCopyManagedDisplaySpaces` binding is. This requires a new `project.yml`
  linker setting:
  ```yaml
  FRAMEWORK_SEARCH_PATHS: "$(inherited) /System/Library/PrivateFrameworks"
  OTHER_LDFLAGS: "$(inherited) -framework SkyLight"
  ```
  followed by `xcodegen generate`.
- It is a **poll**, not a push signal, so it needs a driving clock (e.g. a
  `CVDisplayLink` callback firing every vsync, ~16.7ms) to catch the
  "animating" flag flip as early as possible.
- It returns `true` for **any** display animation, including ordinary
  (non-fullscreen) Space switches — using it unguarded would risk a
  regression (spuriously hiding the island during a normal Space switch). The
  research-time mitigation is to pair it with a "did a new fullscreen-type
  Space just appear" check against the existing `CGSCopyManagedDisplaySpaces`
  read, so "isAnimating" is only treated as fullscreen-relevant when a new
  `type == 4` Space is appearing.
- This combined design is **untested reasoning only** (RESEARCH.md
  Assumptions Log A4) — it was never verified on-device for correctness
  (over-triggering vs. correctly discriminating) or for whether it actually
  closes the timing gap (does the animating-flag flip early enough relative
  to the compositor pass that currently produces the flash?). It is a
  genuinely new investigation, not a quick follow-up: new linker setting, new
  driving-clock design, new disambiguator logic, all unverified.

## Requested Decision

Per D-04, this escalation must be resolved by an explicit user decision — not
by silently shipping a partial/best-effort mitigation (REQUIREMENTS.md's "Out
of Scope" explicitly excludes that outcome). Three options:

1. **`option-accept` — Accept as permanent technical debt.** Closes the phase
   now, no further investigation spend. The ~1-frame flash remains in shipped
   builds indefinitely. Matches the pre-existing `STATE.md` blocker note that
   this was already accepted as deferred once before (Phase 2/Phase 6).
2. **`option-descope` — Formally descope FS-01.** Makes the decision explicit
   and traceable by editing `REQUIREMENTS.md`/`ROADMAP.md` to reflect the
   descope, rather than leaving it as an implicit carry-over.
3. **`option-investigate-b` — Request a follow-up investigation of the
   untried `SLSManagedDisplayIsAnimating` fallback.** One documented avenue
   (Candidate B, above) remains unexplored on-device. Requires a new
   `project.yml` linker setting and a new Space-switch disambiguator design —
   a genuinely new investigation phase, not a quick fix.

No code change has shipped for FS-01 in this phase (Task 1 of this plan
reverted all Wave-0 exploratory probe code byte-for-byte to its pre-Phase-8
state). The v1.0 reactive `updateVisibility()`/`orderOut` behavior is
unchanged.
