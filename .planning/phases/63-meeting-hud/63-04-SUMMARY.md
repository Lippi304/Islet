---
phase: 63
plan: 04
subsystem: meeting-hud
tags: [meeting, controller-wiring, click-through, coreaudio, uat, priority-supersession]
requires:
  - 63-01 (MeetingActivity payload, readSystemInputMuted/toggleSystemInputMute)
  - 63-02 (MeetingMonitor + its once-per-transition onChange contract)
  - 63-03 (.meeting resolver case + meetingWings + onMuteTap seam)
provides:
  - Meeting HUD shippable end to end — detection -> resolver -> render -> tap -> real system mute
  - TransientQueue.dropsWhileCallStands(_:) — D-05a "nothing interrupts a live call" admission rule
  - collapsedInteractiveZone()'s .meeting branch — the mute icon is clickable at its real screen position
  - NotchPillView.meetingMuteIconTrailingEdgeOffset — shared render/click-through geometry constant
affects:
  - Any future ActiveTransient category — it inherits D-05a automatically (the rule lives in the queue)
  - Phase 62's Timer (the four un-stalled preempt call sites fix a latent bug it also had)
tech-stack:
  added: []
  patterns:
    - "startCapsLockMonitor/startDownloadMonitor's idempotent toggle-gated monitor lifecycle"
    - "secondaryBubbleCenterOffset's WR-03 single-source-of-truth geometry constant, shared by render + click-through"
    - "collapsedInteractiveZone()'s bounded, presentation-gated hot-zone widen (Phase 42 T-42-07 discipline)"
    - "Queue-level admission rule instead of per-call-site guards (NEW — the four stale .focus guards are exactly why)"
key-files:
  created:
    - .planning/phases/63-meeting-hud/63-04-SUMMARY.md
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/IslandResolver.swift
    - Islet/Notch/NotchPillView.swift
    - IsletTests/IslandResolverTests.swift
    - .planning/phases/63-meeting-hud/63-CONTEXT.md
decisions:
  - "D-05a SUPERSEDES D-05 (user decision, on-device UAT round 1): nothing interrupts a live call — every other transient is dropped outright, Charging/Device included. OSD suppression mid-call is an accepted, user-warned cost"
  - "The drop rule lives in TransientQueue.dropsWhileCallStands(_:), consulted by both enqueue() and preempt(), so a future transient category cannot forget it; updateHead/removeAll deliberately exempt"
  - "Four NotchWindowController call sites (charging/capsLock/updateAvailable/osd) still carried the pre-Phase-62 `if case .focus = head` guard — deleted, all now call preempt() unconditionally (Rule 3 root-cause fix for a latent Phase 62 bug that also affected a running .timer head)"
  - "handleMuteTap() calls renderPresentation() despite the plan saying no re-trigger is needed — updateHead alone never touches presentationState.presentation, the exact Phase 62-04 'Bug 2' failure class"
  - "UAT ran against Discord as a Zoom/Teams stand-in (63-02 precedent); substitution reverted, production target set unchanged"
metrics:
  duration: multi-session (checkpoint, 2 UAT rounds)
  completed: 2026-07-25
---

# Phase 63 Plan 04: Meeting HUD Controller Wiring + On-Device UAT Summary

Meeting HUD is shippable: `MeetingMonitor` is instantiated and toggle-gated like every other
monitor, the mute icon's tap reaches the real system-wide mic through `toggleSystemInputMute()`,
the collapsed click-through hot-zone was widened so that tap actually lands, and a two-round
on-device UAT closed both open Phase 63 risks — plus superseded D-05 outright on the user's own
call and root-caused a latent Phase 62 preemption bug found on the way.

## What Was Built

### Task 1 — controller lifecycle, mute-tap handler, Settings wiring (`e75f1c5`)

`meetingMonitor` property + `startMeetingMonitor()`, both cloned from
`downloadMonitor`/`startDownloadMonitor()` verbatim. No extra `isAuthorized`-style gate: 63-02's
spike proved the NSWorkspace + CoreAudio HAL reads need no Microphone TCC prompt.

`handleMeetingActivityChange(_:)` preempts **unconditionally** on call start (no
`if case .focus` conditional — `preempt()`'s generalized `currentHead.isPersistent` guard already
handles whichever persistent case holds the head) and clears on call end, both with no debounce
(D-07/D-08). The initial `isMuted` comes from `readSystemInputMuted()`, never an assumed `false`,
so a mic already muted by a hardware key renders correctly the instant the HUD appears.

`handleMuteTap()` writes the real system mute, then refreshes the standing head in place via
`updateHead`. A failed CoreAudio write (`nil`) returns early, leaving the icon in its pre-tap
state rather than lying about it (63-UI-SPEC.md's error-state rule).

Also landed: `onMuteTap` forwarded at `makeRootView`'s call site, `.meeting` added to
`TransientCategory` + `flushTransients`' inner `matches` and outer exhaustive switch, the launch
gate in `start()`, `meetingMonitor?.stop()` in `deinit` (T-63-04), and the
`case (.meeting, .meeting): head = t` arm in `TransientQueue.updateHead`.

### Task 2 — collapsed click-through hot-zone widen (`b0c724d`)

`meetingWingMargin` (20) / `meetingWingRightContentWidth` (84) hoisted to statics with
`meetingMuteIconTrailingEdgeOffset` (104) derived from them — `secondaryBubbleCenterOffset`'s exact
WR-03 shape. `collapsedInteractiveZone()` gained a `.meeting`-gated branch widening the trailing
edge by that offset; without it the mute icon rendered correctly but `syncClickThrough()` never
enabled mouse events out at its real screen position, so the tap could never arrive at all.

`meetingWings(for:)` now reads both statics, and `muteIconWidth` is **derived**
(`rightContentWidth - elapsedWidth - iconGap`) rather than restated as a third literal — the 84pt
right block is exact by construction, so render and click-through cannot desync.

### UAT round 1 fix — D-05a + four un-stalled call sites (`808996a`)

See "On-Device UAT" and "Deviations" below.

## On-Device UAT — Two Rounds, APPROVED

The plan's 13-step checklist ran across two rounds.

**Substitution:** the validation machine has neither Zoom nor Teams installed, so with
`MeetingMonitor`'s production `targetBundleIDs` the HUD could never appear and the UAT would have
been impossible to perform. Discord (`com.hnc.Discord`) was added to the target set in a separate,
clearly-marked temporary commit (`f716489`) — the identical stand-in 63-02's detection spike used
and approved (`63e6db1`), producing the same signal shape (target app running AND default-input
device active). **Reverted after approval in `e455ea7`; `MeetingMonitor`'s production default is
back to exactly `["us.zoom.xos", "com.microsoft.teams2", "com.microsoft.teams"]`,** verified by
grep, with the only remaining Discord reference being the manual spike file's own documented
`SPIKE SUBSTITUTION` comment.

### Round 1 — 12 of 13 steps passed, step 10 FAILED

| Step | Result |
|---|---|
| 1–2 Settings toggle defaults OFF, turns ON | PASS |
| 3–4 HUD appears on a real voice call with live mm:ss | PASS |
| 5 Tapping the wing anywhere except the mute icon does nothing (D-10) | PASS |
| 6–8 Mute icon tap at its real screen position mutes the SYSTEM mic; icon swaps to red `mic.slash.fill`; tap again reverts | PASS — **settles Research Assumption A2**: the nested `.onTapGesture` beats `wingsShape`'s outer gesture on real hardware; the `.highPriorityGesture` fallback was never needed |
| 9 Click just past the icon's far edge passes through | PASS — the widen is bounded to the icon's real footprint (T-63-11) |
| **10 Charging/Device preempts the Meeting HUD (D-05)** | **FAIL — see below** |
| 11 HUD disappears immediately on call end (D-08) | PASS |
| 12–13 Google Meet in a browser shows no HUD (MEET-03) | PASS |

Wing geometry needed **zero** retuning — no clipped digits, no over-spacing. 63-UI-SPEC.md's
locked `margin: 20` / 84pt right block were correct on the first try, unlike `timerWings`' 6-round
history. The Settings card copy was confirmed already correctly scoped to "Zoom/Teams calls"
(no change needed, satisfying MEET-03's documentation requirement).

**Step 10's observed failure:** plugging in the charger mid-call did not preempt the HUD at all.
The charging splash queued in `pending` and fired **after the call ended** — the user identified
that delayed pop-up as the specifically unacceptable part.

### The user decision that superseded D-05

Offered four options, the user chose: **nothing interrupts a live call.** While a `.meeting` head
stands, every other transient is dropped entirely — not preempted, not queued. Recorded as **D-05a**
in `63-CONTEXT.md` with its on-device provenance (this came from real hardware, not planning).

The user was explicitly warned that this also suppresses the volume/brightness OSD during a call,
and accepted it. The single-line knob to loosen it later (e.g. `if case .osd = t { return false }`)
is commented at the implementation site.

### Round 2 — focused re-test, APPROVED

Steps 1–9 and 11–13 were not repeated; their round-1 results stand.

| Re-test step | Result |
|---|---|
| 1 HUD still appears normally | PASS |
| 2 Charger, Bluetooth headphones AND volume keys all show nothing mid-call | PASS |
| 3 No delayed charging splash after the call ends | PASS — the round-1 symptom is gone |
| 4 Unplugging outside a call still animates normally | PASS — the drop rule did not break charging in general |

User reply: **"approved."**

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking, root cause] Four stale `if case .focus = transientQueue.head` preempt guards**
- **Found during:** UAT round 1, step 10
- **Issue:** `TransientQueue.preempt()` was correctly generalized in Phase 62-01 to
  `guard let currentHead = head, currentHead.isPersistent`, and the two `deviceCoordinator` call
  sites were updated — but **four** call sites in `NotchWindowController.swift` still carried the
  pre-Phase-62 hardcoded Focus check and fell through to plain `enqueue()` for any *other*
  persistent head: charging (~2360), capsLock (~2411), updateAvailable (~2431), osd (~2588). That
  is why an AirPods connect behaved correctly mid-call while the charger did not. **This is a
  pre-existing Phase 62 bug, not one Phase 63 introduced** — a running `.timer` head had the
  identical failure in shipped code.
- **Fix:** deleted all four conditionals; every site now calls `preempt()` directly. Since
  `preempt()` already falls back to `enqueue()` for a nil or non-persistent head, the `if/else`
  blocks were pure redundancy. Fixed at the shared function's callers rather than patching only
  the charging path the UAT happened to name.
- **Files modified:** `Islet/Notch/NotchWindowController.swift`
- **Commit:** `808996a`
- **Regression test:** `testChargingPreemptsAStandingTimerHead`

**2. [Rule 1 - Design change per user decision] D-05a drop rule**
- **Found during:** UAT round 1, step 10 (see above)
- **Issue:** with fix 1 alone, charging would have *preempted* the call HUD — correct per D-05, but
  the user rejected any interruption of a live call.
- **Fix:** `TransientQueue.dropsWhileCallStands(_:)` in `IslandResolver.swift`, consulted at the top
  of **both** `enqueue(_:)` and `preempt(_:)`. Implemented once inside the queue rather than at each
  controller call site — precisely because fix 1 demonstrates what happens when a priority rule is
  duplicated across call sites and one is forgotten. A future transient category inherits the rule
  automatically. `updateHead(_:)` and `removeAll(where:)` are deliberately exempt so the mute-tap
  `isMuted` refresh and the Settings toggle-off flush keep working.
  Model-sync side effects are untouched: `chargingState.activity = activity` still runs *before* the
  drop, so battery state stays correct — only the splash is suppressed.
- **Files modified:** `Islet/Notch/IslandResolver.swift`, `.planning/phases/63-meeting-hud/63-CONTEXT.md`
- **Commit:** `808996a`

**3. [Rule 1 - Bug] `handleMuteTap()` needed `renderPresentation()`**
- **Found during:** Task 1
- **Issue:** the plan states "no `presentTransientChange()` re-trigger needed (payload-only
  change)". Literally true for the dismiss timer — but `updateHead(_:)` mutates only the queue, and
  `presentationState.presentation` is the sole value the view observes. With no render at all the
  mute icon would never visibly change state, which is exactly the Phase 62-04 "Bug 2" failure class
  (`flushTransients(.timer)` called standalone with no follow-up render).
- **Fix:** `withAnimation(spring) { renderPresentation() }`, mirroring `refreshTimerHeadInPlace()`.
  `presentTransientChange()` is still deliberately NOT used — re-arming the dismiss window for an
  unchanged displayed case would be wrong.
- **Files modified:** `Islet/Notch/NotchWindowController.swift`
- **Commit:** `e75f1c5`

**4. [Rule 2 - Missing critical functionality] `meetingMonitor?.stop()` in `deinit`**
- **Found during:** Task 1
- **Issue:** not in the plan's action text. `MeetingMonitor`'s `deinit` is empty by design and its
  own doc comment expects the owner to call `stop()`; without it, two CoreAudio listeners, a 5s
  poll timer and two NSWorkspace observers outlive the controller (T-63-04, the exact leak class
  63-02's Rule-2 fix already closed once inside the monitor).
- **Fix:** added alongside `downloadMonitor?.stop()`.
- **Files modified:** `Islet/Notch/NotchWindowController.swift`
- **Commit:** `e75f1c5`

### Design notes (not deviations)

- **`changed` on the call-end path is a head-transition test**, not "did `removeAll` touch
  anything". Dropping a *queued* `.meeting` that was never on screen changes nothing visible, so it
  must not re-run the spring or re-arm the standing head's dismiss window — reuses
  `flushTransients`' own `head != oldHead` discipline.
- **`muteIconWidth` is derived, not a third literal.** The plan asked for `margin`/
  `rightContentWidth` to read from the new statics; keeping a bare `= 20` mute-icon literal
  alongside an `= 84` total would have reintroduced the desync class the statics exist to prevent.
  An `assert` guards a future retune below `elapsedWidth + iconGap`.
- **D-05's rank placement is unchanged and still correct.** D-05a supersedes only the *admission*
  rule; the rank governs `resolve()`'s switch order, a separate mechanism.

## Verification

| Check | Result |
|-------|--------|
| `xcodebuild build -scheme Islet -configuration Debug` | **BUILD SUCCEEDED** (after each task and after the revert) |
| `xcodebuild test -only-testing:IsletTests/IslandResolverTests` | **91/91 passed** (89 + 2 net new) |
| `xcodebuild test` (full suite) | 528 tests, 4 failures — **exactly the 4 pre-existing ones, Phase 63 added none** |
| On-device UAT (13 steps, 2 rounds) | **APPROVED** |
| Production `targetBundleIDs` after revert | exactly `["us.zoom.xos", "com.microsoft.teams2", "com.microsoft.teams"]` |
| Discord references outside the spike file | 0 |
| `grep -c "private var meetingMonitor: MeetingMonitor?"` == 1 | 1 |
| `grep -c "func startMeetingMonitor"` == 1 | 1 |
| `grep -c "func handleMeetingActivityChange"` == 1 | 1 |
| `grep -c "func handleMuteTap"` == 1 | 1 |
| `grep -c "transientQueue.preempt(.meeting(activity))"` == 1 | 1 |
| `grep -c "ActivitySettings.meetingHUDKey"` >= 2 | 2 |
| `grep -c "onMuteTap:"` >= 1 | 1 |
| `grep -c "case (.meeting, .meeting): head = t"` IslandResolver == 1 | 1 |
| `grep -c "static let meetingWingMargin: CGFloat = 20"` == 1 | 1 |
| `grep -c "static let meetingWingRightContentWidth: CGFloat = 84"` == 1 | 1 |
| `grep -c "static var meetingMuteIconTrailingEdgeOffset"` == 1 | 1 |
| `grep -c "NotchPillView.meetingMuteIconTrailingEdgeOffset"` controller == 1 | 1 |
| `grep -c "if case .meeting = presentationState.presentation"` == 1 | 1 |
| `grep -c "if case .focus = transientQueue.head"` == 0 (all four un-stalled) | 0 |
| Post-commit deletion check on all 4 commits | no unintended deletions |

### Pre-existing failures (NOT caused by this plan)

Identical to 63-03's list, confirmed unchanged by name: 2 wall-clock-dependent
`CalendarGlanceTests` date assertions, 1 `ClipboardFileStoreTests` assertion comparing objects with
identical descriptions, and `SettingsViewTests.testSystemHUDCardsCount` (from Phase 60-03, commit
`9bf1417`). Logged in `.planning/phases/63-meeting-hud/deferred-items.md` and deliberately left
unfixed per the executor's scope boundary.

## Tests Added

| Test | Covers |
|---|---|
| `testNothingInterruptsAStandingMeetingHead` | D-05a across 8 incoming categories, via **both** `enqueue()` and `preempt()`; asserts `pendingCount == 0` and that `advance()` yields nil — nothing surfaces after the call, the exact round-1 symptom |
| `testMeetingHeadStillRefreshesAndClearsWhileTheDropRuleStands` | the drop rule does not cost `updateHead` (mute-tap) or `removeAll` (toggle-off) |
| `testChargingPreemptsAStandingTimerHead` | the four un-stalled call sites' underlying behaviour, incl. the latent Phase 62 `.timer` bug |

`testChargingAndDevicePreemptStandingMeetingHead` (from 63-03) was **replaced** — it asserted D-05,
which no longer holds. The replacement documents the supersession inline so a future reader does not
"restore" it.

## Known Stubs

None. Meeting HUD is complete end to end: detection, resolver priority, rendering, a genuinely
clickable mute control, real system-mute writes, and a live Settings toggle — all on-device
confirmed.

## Requirements Status

**MEET-01, MEET-02 and MEET-03 marked Complete** in REQUIREMENTS.md. The on-device UAT confirmed
each one against real hardware, which is the gate 63-02 and 63-03 deliberately deferred to this
plan (matching the Phase 45 / 52-03 / 53-01 precedent of not closing requirements on an
infrastructure plan).

## Carried-Forward Risk

- **The real Zoom/Teams bundle IDs remain UNVALIDATED.** Neither app has ever been available on the
  validation machine, across all four plans of this phase. The full chain — detection heuristic,
  dedup, resolver, rendering, tap-to-mute, hot-zone, Settings toggle — is proven on real hardware
  via Discord, but the literal strings `us.zoom.xos`, `com.microsoft.teams2` and
  `com.microsoft.teams` have never been matched against a real install. These are publicly
  documented, stable identifiers and the risk is accepted; **the user's first real Zoom or Teams
  call is what confirms them.** If the HUD ever fails to appear on a real call, check the bundle ID
  FIRST — run `osascript -e 'id of app "zoom.us"'` (or read the app's `Info.plist`
  `CFBundleIdentifier`) — rather than re-debugging the heuristic, which is now UAT-proven.
- **The OSD is suppressed during a call** by design (D-05a), user-warned and accepted. If that ever
  feels wrong in daily use, it is a one-line change inside `dropsWhileCallStands(_:)`.
- **Research Assumption A2 is CLOSED** (nested-tap hit-testing works on-device) and **wing geometry
  is CLOSED** (no retune needed). Neither carries forward.

## Threat Flags

None. No new network endpoint, auth path, file access, or trust boundary beyond the one the plan's
threat model already declared (user tap → system audio state write).

- **T-63-08** (mute write without confirmation) stays `accept` — instantly reversible, on-device
  confirmed working in both directions.
- **T-63-09** (duplicate `preempt` entries) mitigated as planned by `MeetingMonitor`'s dedup, and
  now additionally by D-05a: a `.meeting` head cannot be displaced at all.
- **T-63-10** (UserDefaults flag) stays `accept`.
- **T-63-11** (over-widened hot-zone swallowing clicks) mitigated as planned and **verified
  on-device** — UAT step 9 confirmed a click past the icon's far edge still passes through to what
  is underneath.

## TDD Gate Compliance

Both auto tasks are `type="auto"`, not `tdd="true"`, so no RED gate applies. Task 1's verification is
the `IslandResolverTests` regression suite; Task 2's is `xcodebuild build` plus the on-device UAT, per
the plan's own `<verify>` blocks. The UAT-round-1 fix landed as a `fix(...)` commit carrying its 3
tests in the same commit as the code — a post-hoc regression suite for a bug found on hardware, which
has no meaningful RED phase (the failing "test" was the physical charger).

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| `e75f1c5` | feat | MeetingMonitor lifecycle, mute tap and Settings toggle wiring |
| `b0c724d` | feat | widen the collapsed hot-zone to reach the mute icon (D-09) |
| `f716489` | test | add Discord to the target set for the on-device UAT (temporary) |
| `808996a` | fix | nothing interrupts a live call; unstall 4 stale preempt call sites |
| `e455ea7` | revert | revert the Discord substitution — production target set restored |

## Next

Phase 63's plans are all executed. The orchestrator owns the phase-level gates that follow (code
review, regression sweep, `/gsd:verify-work 63`) — this plan does not mark the phase itself complete
in ROADMAP.md.

One follow-up worth surfacing to whoever runs the phase-level review: the four un-stalled call sites
were a **Phase 62** defect, so a running Timer preempting correctly is a behaviour change outside
Phase 63's declared scope. It is covered by `testChargingPreemptsAStandingTimerHead`, but a Timer
user might notice charging splashes now appearing during a countdown where they previously arrived
late.

## Self-Check: PASSED

All 5 claimed files exist on disk; all 5 claimed commit hashes exist in git history;
`grep -c "if case .focus = transientQueue.head"` is 0, confirming all four stale guards are gone.
