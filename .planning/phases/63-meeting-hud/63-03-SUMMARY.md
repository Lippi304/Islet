---
phase: 63
plan: 03
subsystem: meeting-hud
tags: [meeting, resolver, swiftui, collapsed-wing, nested-tap]
requires:
  - 63-01 (MeetingActivity payload, meetingElapsedLabel)
  - 63-02 (MeetingMonitor onChange contract + on-device GO verdict)
provides:
  - IslandPresentation.meeting / ActiveTransient.meeting at D-05 rank 3
  - ActiveTransient.meeting(_).isPersistent == true (D-06)
  - NotchPillView.meetingWings(for:) — the first collapsed wing with an interactive sub-region
  - NotchPillView.onMuteTap closure seam for Plan 63-04's controller
affects:
  - Plan 63-04 (controller enqueues .meeting from MeetingMonitor.onChange and wires onMuteTap
    to MicMuteController.toggleSystemInputMute)
tech-stack:
  added: []
  patterns:
    - "Collapsed-only transient = resolver `where !isExpanded` arm + plain `break` arm (Focus/OSD/CapsLock shape)"
    - "downloadWings' margin/leftWidth/rightWidth/assert geometry template"
    - "Nested .onTapGesture on a wing sub-region + explicit no-op wingsShape onTap (NEW — no prior precedent)"
    - "Live label computed INSIDE the TimelineView tick closure (countdownWings/timerWings desync discipline)"
key-files:
  created:
    - .planning/phases/63-meeting-hud/deferred-items.md
  modified:
    - Islet/Notch/IslandResolver.swift
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift
    - IsletTests/IslandResolverTests.swift
decisions:
  - "preempt() untouched — Phase 62's generalization already covers a persistent .meeting head; proven by a regression test rather than by new code"
  - "Rank-3 'outranking' is asserted as TransientQueue.preempt() tests, not resolve() tests — resolve() takes ONE transient, so switch order is unobservable from the outside"
  - "meetingWings canNOT use downloadWings' blanket .accessibilityElement(children: .ignore) — it would swallow the mute icon's own interactive element"
  - "MEET-01/MEET-02 stay Pending in REQUIREMENTS.md — the HUD is not reachable at runtime until Plan 63-04 wires the controller (63-02 precedent)"
metrics:
  duration: 20min
  completed: 2026-07-25
---

# Phase 63 Plan 03: Meeting Resolver Wiring + Collapsed Wing Summary

`.meeting(MeetingActivity)` now occupies D-05 rank 3 in the single-arbiter priority system —
persistent (D-06), collapsed-only always (D-10), riding Phase 62's already-generalized
`preempt()` with **zero changes to `preempt()` itself** — and `meetingWings(for:)` renders it as
this codebase's first collapsed wing with a genuinely tappable sub-region inside it.

## What Was Built

### Task 1 — `IslandResolver.swift` + `IslandResolverTests.swift` (TDD)

- `case meeting(MeetingActivity)` added to **both** `IslandPresentation` and `ActiveTransient`,
  slotted immediately after `.device` and before `.focus`. Every trailing rank comment below it
  renumbered +1 (focus 3→4, osd 4→5, downloadProgress 5→6, capsLock 6→7, updateAvailable 7→8,
  timer 8→9), matching the existing inline convention.
- `if case .meeting = self { return true }` in `ActiveTransient.isPersistent` — unconditional,
  the `.focus` shape, **not** a sub-state split like DownloadProgress/Timer. `isMuted` never
  affects persistence: a muted call is still a call.
- `resolve()` gained `case .meeting(let m) where !isExpanded: return .meeting(m)` plus a plain
  `case .meeting: break`. D-10 means there is deliberately no expanded counterpart the way Timer
  has `.timerExpanded` — Meeting falls through exactly like Focus/OSD/CapsLock.
- **`preempt()` was not touched.** Phase 62 already generalized it past the hardcoded `.focus`
  check to `guard let currentHead = head, currentHead.isPersistent`, so a persistent `.meeting`
  head flows through correctly for free. This is asserted, not assumed — see
  `testChargingAndDevicePreemptStandingMeetingHead`.
- Tier-1 priority-table doc comment updated (summary line + the reserved-slot entry now reads
  `LANDED (63-03): ActiveTransient tier, rank 3, collapsed-only (D-10), persistent (D-06)`,
  matching Phase 60/61/62's own annotation style).

5 new tests (84 → 89 in `IslandResolverTests`): collapsed-only resolution, expanded fallthrough,
`isPersistent` for both mute states, Meeting preempting each persistent lower-ranked head
(Focus/DownloadProgress/Timer), and Charging/Device still preempting a standing Meeting head.

RED: `test(63-03)` `7dcc1f6` (10 compile errors, all "type has no member 'meeting'").
GREEN: `feat(63-03)` `3afacb5` (89/89 passing).

### Task 2 — `NotchPillView.meetingWings(for:)`

`video.fill` (13pt semibold, `.hierarchical`, white, non-interactive) on the left; the fixed
`cameraBlockWidth` spacer; then live `mm:ss` (13pt semibold rounded, `.monospacedDigit()`, 60pt
box, `.trailing`) + a 4pt gap + the mute icon. Geometry is `downloadWings`' template verbatim at
`margin: 20` per 63-UI-SPEC.md's Spacing Scale — the "short, icon-adjacent" content class, not
`capsLockWings`' 65.

The two things that make this wing unlike every other one:

1. **`onTap: {}` — an explicit no-op, never `nil`.** `wingsShape`'s `(onTap ?? onClick)()` means
   a `nil` override falls through to the universal expand-to-Home, which D-10 forbids here (there
   is nothing to expand *to*). Tapping the wing background does nothing at all.
2. **The mute icon owns a nested `.onTapGesture`** (D-09), preceded by
   `.contentShape(Rectangle())` so the full 20pt frame is tappable rather than just the glyph's
   opaque pixels. SwiftUI's deepest-view-first hit-testing consumes it before the outer wing
   gesture sees it.

D-12 is implemented as icon swap **and** red tint together (`mic.fill`/white ↔
`mic.slash.fill`/`Color.red`, `.monochrome`), not either alone — red by itself would be a
colour-only state signal.

The elapsed label is computed **inside** the `TimelineView(.periodic(from: .now, by: 1))` tick
closure, never outside it, per `countdownWings`'/`timerWings`' explicit desync warning.

`feat(63-03)` `e30199f`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `NotchWindowController.syncActivityModels()` needed a `.meeting` arm**
- **Found during:** Task 1
- **Issue:** `syncActivityModels()` switches over `transientQueue.head` exhaustively with no
  `default:`. Adding a case to `ActiveTransient` broke the build — the app module must compile
  before `@testable import Islet` can run a single resolver test, so this blocked Task 1's own
  GREEN verification. The file is not in the plan's `files_modified`.
- **Fix:** added `case .meeting: chargingState.activity = nil`, mirroring the `.timer`/`.capsLock`
  arms verbatim ("not charging — no standing charging splash").
- **Files modified:** `Islet/Notch/NotchWindowController.swift`
- **Commit:** `3afacb5`
- **Checked and NOT affected:** `flushTransients` switches over its own private
  `TransientCategory` enum (not `ActiveTransient`) and its `matches` closure has a `default:` —
  Plan 63-04 adds the `.meeting` category there when it wires the Settings toggle. `tabWidth`/
  `tabHeight`/`showsSwitcherRow` all carry `default:` arms.

**2. [Rule 3 - Blocking] One-commit-lived `EmptyView()` placeholder in `presentationSwitch`**
- **Found during:** Task 1
- **Issue:** T-63-06 assumes both exhaustive switches land in the same commit, but the plan splits
  them across two tasks — and `presentationSwitch`'s arm calls `meetingWings(for:)`, which does
  not exist until Task 2. Task 1's `<verify>` is `xcodebuild test`, which cannot run against a
  non-compiling app module.
- **Fix:** Task 1's commit carried `case .meeting: EmptyView()` behind an explicit "TEMPORARY —
  63-03 Task 2 replaces this" comment; Task 2's commit replaced it with the real wing. Both
  commits build and test green, and no placeholder survives the plan.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Commits:** `3afacb5` (added), `e30199f` (removed)

### Design notes (not deviations)

- **Rank-3 "outranking" is tested via `preempt()`, not `resolve()`.** The plan asks for a test
  that `.meeting` outranks Focus/OSD/DownloadProgress/CapsLock/UpdateAvailable/Timer "mirroring
  `testChargingOutranksDeviceAndMedia`'s shape". `resolve()` takes exactly **one**
  `activeTransient`, so its switch order can never be observed by feeding it two transients — for
  a single value, rank is documentation. The observable mechanism is
  `TransientQueue.preempt()`, so the outranking tests are queue tests (mirroring
  `testDownloadProgressPreemptsStandingFocusHead` /
  `testPreemptNowGeneralizedForDownloadProgressHead` instead).
  The three lower-ranked **non-persistent** transients (`.osd` 5, `.capsLock` 7,
  `.updateAvailable` 8) are deliberately excluded: they self-elapse on the shared ~3s timer, so a
  standing one is never *displaced* by anything — it expires and `advance()` promotes the queued
  Meeting, a path already covered by the generic enqueue/advance tests and not Meeting-specific.
  This reasoning is written into the test file's own MARK comment so a future reader does not
  "fix" the perceived gap.
- **Accessibility could not copy `downloadWings` verbatim.** 63-UI-SPEC.md points at
  `downloadWings`' `.accessibilityElement(children: .ignore)` + single label for the
  non-interactive portion, but applying that to this wing's HStack would swallow the mute icon's
  own interactive element and destroy the state-dependent Mute/Unmute label the same spec
  mandates. Resolved by scoping instead of grouping: the decorative call icon is
  `.accessibilityHidden(true)` (its meaning is already carried by the duration), the elapsed text
  carries `"Call duration MM:SS"`, and the mute icon keeps its own separate element and label.
  The rationale is written inline at the call site.
- **One comment reworded to keep a grep criterion literal.** The `case .meeting: break` arm's
  comment originally read "no `.meetingExpanded` counterpart", which made
  `grep -c meetingExpanded == 1` despite no such case existing. Reworded to "no dedicated
  expanded counterpart the way Timer has `.timerExpanded`" — same meaning, `grep -c` now 0. Same
  precedent as Plan 63-01's own header rewordings.

## Verification

| Check | Result |
|-------|--------|
| `xcodebuild test -only-testing:IsletTests/IslandResolverTests` | **89/89 passed** (84 existing + 5 new) |
| `xcodebuild build -scheme Islet -configuration Debug` | **BUILD SUCCEEDED** |
| `xcodebuild test` (full suite, regression sweep) | 526 tests, 4 failures — **all 4 pre-existing and out of scope**, see below |
| `grep -c "case meeting(MeetingActivity)"` IslandResolver == 2 | 2 |
| `grep -c "if case .meeting = self { return true }"` == 1 | 1 |
| `grep -c "case .meeting(let m) where !isExpanded: return .meeting(m)"` == 1 | 1 |
| `grep -c "mutating func preempt"` == 1 (unchanged) | 1 |
| `grep -c "meetingExpanded"` == 0 (no dedicated expanded case) | 0 |
| `grep -c "var onMuteTap: () -> Void = {}"` == 1 | 1 |
| `grep -c "private func meetingWings"` == 1 | 1 |
| `grep -c "onTap: {}"` >= 1 | 2 (1 call site + 1 doc-comment mention) |
| `grep -c "case .meeting(let activity): meetingWings"` == 1 | 1 |
| `grep -c "mic.slash.fill"` == 1 | 1 |
| `grep -c "\"video.fill\""` == 1 | 1 |
| Post-commit deletion check on both feat commits | no files deleted |

### Pre-existing failures (NOT caused by this plan)

4 of 526 tests fail, all in suites that never reference `IslandPresentation`, `ActiveTransient`,
or `meetingWings` (verified by grep): 2 wall-clock-dependent `CalendarGlanceTests` date
assertions, 1 `ClipboardFileStoreTests` assertion comparing objects with identical descriptions,
and `SettingsViewTests.testSystemHUDCardsCount` (9 actual vs 8 expected — `Islet/SettingsView.swift`
was last modified in **Phase 60-03**, commit `9bf1417`, long before Phase 63). Logged to
`.planning/phases/63-meeting-hud/deferred-items.md` and deliberately left unfixed per the
executor's scope boundary.

## Known Stubs

None. The one-commit `EmptyView()` placeholder from Task 1 was replaced by the real wing in Task
2 and does not survive in the tree.

`meetingWings` is not yet reachable at runtime — nothing enqueues `.meeting` and `onMuteTap`
defaults to a no-op — but that is Plan 63-04's declared scope (controller wiring), not a stub:
both seams are complete and typed, exactly as 63-01 and 63-02 left their own.

## Requirements Status

**MEET-01 and MEET-02 stay `Pending`.** This plan lands the resolver + rendering half; the HUD
cannot appear or respond to a tap until Plan 63-04 connects `MeetingMonitor.onChange` to the
queue and `onMuteTap` to `MicMuteController`. Marking them complete here would claim a
user-visible capability that does not yet exist. This matches 63-02-SUMMARY's own stated
precedent (Phase 45 / 52-03 / 53-01: infrastructure plans do not close requirements).

## Carried-Forward Risk

- **Nested-tap hit-testing is unproven on-device (Research Assumption A2).** No existing wing has
  an interactive sub-region, so nothing in this codebase demonstrates that a nested
  `.onTapGesture` reliably wins over `wingsShape`'s outer gesture. If Plan 63-04's UAT shows the
  background swallowing mute taps, the fallback is `.highPriorityGesture(TapGesture().onEnded
  { onMuteTap() })` in place of the plain `.onTapGesture` — documented inline at the call site,
  not just here.
- **Wing geometry is a starting point, not a measurement.** `margin: 20` and the 84pt right block
  come from 63-UI-SPEC.md's locked starting values, never from on-device measurement. `timerWings`
  needed 6 UAT rounds before its right-side text stopped clipping against the camera — if 63-04's
  UAT reports clipped digits, the first knob is `margin` (the root cause in `timerWings`' own
  documented history), not `elapsedWidth`.
- **63-02's Zoom/Teams bundle-ID risk is unchanged** and still applies to 63-04's UAT.

## Threat Flags

None. No new network endpoint, auth path, file access, or trust boundary — this plan is pure
Foundation resolver logic plus SwiftUI rendering of an already-validated `MeetingActivity`.

T-63-06 (exhaustive-switch coverage) is mitigated as planned, and the audit widened it: three
switch sites were checked, not the two the threat register names — `resolve()`,
`presentationSwitch`, and `NotchWindowController.syncActivityModels()` (the third was missing
from the plan and would have failed the build).

T-63-07 (mute tap bubbling to expand-to-Home) is mitigated as planned: explicit `onTap: {}` plus
`.contentShape(Rectangle())` + nested `.onTapGesture`, with the `.highPriorityGesture` fallback
documented at the call site for 63-04's UAT.

## TDD Gate Compliance

**Task 1: full RED → GREEN cycle.** `7dcc1f6` (test, compile-failed as expected with 10 "type has
no member 'meeting'" errors) → `3afacb5` (feat, 89/89 green). No REFACTOR commit needed.

**Task 2: no RED gate — deliberate, and a gap worth naming.** The task is marked `tdd="true"`,
but its `<behavior>` block is entirely SwiftUI rendering and gesture routing (tap goes to
`onMuteTap` not `onClick`; icon swaps on `isMuted`), and this codebase has **no** view-rendering
or gesture test harness — `NotchPillViewTests.swift` only asserts pure computed properties like
`tabWidth`/`tabHeight`. The plan's own `<verify>` for Task 2 is `xcodebuild build`, not a test
run, which reflects that. Extracting a helper purely to unit-test a ternary would add an
abstraction the plan explicitly does not ask for. Task 2's real verification is Plan 63-04's
on-device UAT, where the A2 hit-testing assumption is also settled.

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| `7dcc1f6` | test | failing tests for the .meeting resolver case |
| `3afacb5` | feat | wire .meeting into the resolver at D-05 rank 3 |
| `e30199f` | feat | meetingWings collapsed pill with inline mute tap |

## Next

Plan 63-04: instantiate `MeetingMonitor` in `NotchWindowController`, enqueue/remove `.meeting`
from its once-per-transition `onChange`, wire `onMuteTap` to
`MicMuteController.toggleSystemInputMute()`, read mute state back via `readSystemInputMuted()`
(63-UI-SPEC.md: read-after-write, never an optimistic local toggle, so a hardware mute key stays
in sync), add the `.meeting` case to `flushTransients`' `TransientCategory` for the Settings
toggle, and run the on-device UAT that settles both A2 and the wing geometry.

## Self-Check: PASSED

All 6 claimed files exist on disk; all 4 claimed commit hashes (3 new + the cited Phase 60-03
`9bf1417`) exist in git history.
