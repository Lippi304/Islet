---
phase: 03-charging-activity
verified: 2026-06-27T17:40:00Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 1
overrides:
  - must_have: "Unplugging shows a brief on battery indication (ROADMAP SC#2 / CHG-02)"
    reason: "Deliberate product decision during on-device UAT (2026-06-27): the charging activity is connect-only — plugging in animates, unplugging shows nothing. The .onBattery state is still classified in the model but never triggers a splash. Recorded in REQUIREMENTS.md as 'Descoped (connect-only, UAT 2026-06-27)'. The goal phrase 'or unplugging' is superseded; the core goal (proving the activity→island loop on the public IOKit API) is achieved via the connect splash."
    accepted_by: "niklas.lippert (on-device UAT)"
    accepted_at: "2026-06-27T00:00:00Z"
---

# Phase 3: Charging Activity Verification Report

**Phase Goal:** The first real live activity — plugging in or unplugging the power cable produces a transient charging/on-battery splash, proving the full activity→island rendering loop end-to-end on the safest, public API.
**Verified:** 2026-06-27T17:40:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

The phase goal — proving the full activity→island rendering loop end-to-end on the safest public API (IOKit power sources) — is achieved. A live plug-in event flows: `IOPSNotificationCreateRunLoopSource` → `readCurrentPower()` → pure `powerActivity(from:)` mapping → `shouldTriggerSplash` connect-edge gate → `ChargingActivityState.activity` (inside `withAnimation(.spring)`) → `NotchPillView.wings(for:)` rendered through the single `updateVisibility()`, then auto-cleared by a one-shot `dismissWorkItem` after ~3s. The "or unplugging" half of the goal phrase is a documented, user-approved descope (connect-only); see the override below.

### Observable Truths

These are the four ROADMAP Success Criteria (the roadmap contract) merged with the plan must_haves.

| #   | Truth (ROADMAP Success Criterion)                                                                                  | Status              | Evidence                                                                                                                                                                                                                  |
| --- | ------------------------------------------------------------------------------------------------------------------ | ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Plugging in shows a charging animation + battery % for a few seconds, then collapses                                | ✓ VERIFIED          | `handlePower` fires on the not-AC→AC edge, sets `chargingState.activity` in a spring, `wings(for:)` renders the bolt glyph + `\(percent)%`; `scheduleActivityDismiss()` clears it after `activityDuration = 3.0`s. On-device UAT PASSED (03-03-SUMMARY). |
| 2   | Unplugging shows a brief "on battery" indication                                                                   | ✓ PASSED (override) | Intentionally descoped to connect-only by user decision during on-device UAT (2026-06-27). `shouldTriggerSplash` fires only on connect; unplug shows nothing by design. Recorded in REQUIREMENTS.md (CHG-02 "Descoped"). See override. |
| 3   | Splash distinguishes actively-charging from plugged-in-but-full, and behaves sanely with no charging state to read | ✓ VERIFIED          | `powerActivity(from:)`: AC+charging→`.charging` (bolt), AC+not-charging→`.full` (green, no bolt), `isPresent:false`→`nil` (no splash, no crash). Covered by `testChargingMapsToCharging`, `testOnACNotChargingMapsToFull`, `testNoBatteryMapsToNil`. |
| 4   | Power state is driven by event/notification sources with no long-lived polling timer (idle CPU ~0%)                | ✓ VERIFIED          | Only wake-up source is `IOPSNotificationCreateRunLoopSource`; grep for `Timer(`/`DispatchSourceTimer`/`scheduledTimer` across all 6 phase-3 files returns 0. Dismiss is a one-shot `DispatchWorkItem`. On-device UAT confirmed ~0% idle CPU. |
| 5   | Splash routed through the single `updateVisibility()` (inherits fullscreen/clamshell hide; D-11 precedence)        | ✓ VERIFIED          | `handlePower` and `scheduleActivityDismiss` call only `updateVisibility()`; `orderFrontRegardless`/`orderOut` count in controller is exactly 2 (no new show/hide site, Pitfall 5). D-11 precedence is the one-line `if let activity` at the top of the body. |

**Score:** 5/5 truths verified (4 VERIFIED + 1 PASSED via override).

### Required Artifacts

| Artifact                                   | Expected                                                              | Status     | Details                                                                                                                                            |
| ------------------------------------------ | -------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Islet/Notch/PowerActivity.swift`          | Pure power→presentation seam (PowerReading, ChargingActivity, mapping) | ✓ VERIFIED | Foundation-only; `powerActivity(from:)` total + clamped + nil-on-no-battery; `shouldTriggerSplash` connect-edge predicate. Wired by tests + monitor + controller + view. |
| `Islet/Notch/ChargingActivityState.swift`  | ObservableObject publishing `@Published var activity: ChargingActivity?` | ✓ VERIFIED | Separate model (Pattern 2), not an InteractionPhase. Owned by controller, observed by view.                                                       |
| `Islet/Notch/NotchGeometry.swift`          | `wingsFrame(collapsed:wingsSize:)` pure frame math                    | ✓ VERIFIED | center-on-midX + pin-to-top, mirrors `expandedNotchFrame`. Called in `positionAndShow` via `expandedFrame.union(wings)`.                          |
| `Islet/Notch/NotchPillView.swift`          | Wings sideways layout + D-11 precedence + ChargingActivityState observation | ✓ VERIFIED | `wings(for:)` branch, one filling `battery.100percent[.bolt]` glyph (variableValue), shared `matchedGeometryEffect(id:"island")`, D-11 if-ordering, no animation/timer/IOKit in view. |
| `Islet/Notch/PowerSourceMonitor.swift`     | Thin IOKit glue: readCurrentPower, notification source, @convention(c) callback, main hop | ✓ VERIFIED | Correct Unmanaged ownership (Copy/Create→retained, Get→unretained), context-pointer self recovery, `DispatchQueue.main.async` hop, no polling. Owned + started + stopped by controller. |
| `Islet/Notch/NotchWindowController.swift`  | Owns monitor + state + ~3s dismiss; transition-gated splash; deinit teardown | ✓ VERIFIED | `handlePower` (didSeedInitialPower gate, shouldTriggerSplash, withAnimation), `scheduleActivityDismiss`, hover pause/resume, union panel sizing, `powerMonitor.stop()` in deinit. |
| `IsletTests/PowerActivityTests.swift`      | Classification matrix + clamp + no-battery nil + connect-only debounce | ✓ VERIFIED | 16 tests; suite passes (verified by xcodebuild run, not SUMMARY claim).                                                                           |
| `IsletTests/NotchGeometryTests.swift`      | wingsFrame cases (center+pin, non-zero origin, degenerate)            | ✓ VERIFIED | 3 wingsFrame tests; 16-test suite passes.                                                                                                          |

### Key Link Verification

| From                              | To                          | Via                                                       | Status   | Details                                                                                          |
| --------------------------------- | --------------------------- | --------------------------------------------------------- | -------- | ----------------------------------------------------------------------------------------------- |
| PowerActivityTests.swift          | PowerActivity.swift         | `@testable import Islet`, `powerActivity(from`            | ✓ WIRED  | 9 matches for `powerActivity(from`. (gsd-tools reported false due to a double-escaped regex; manually confirmed.) |
| ChargingActivityState.swift       | PowerActivity.swift         | `ChargingActivity` enum reference                         | ✓ WIRED  | Pattern found.                                                                                   |
| NotchPillView.swift               | ChargingActivityState.swift | `@ObservedObject var charging: ChargingActivityState`     | ✓ WIRED  | Pattern found.                                                                                   |
| NotchPillView.swift               | PowerActivity.swift         | switch over `ChargingActivity` cases (`case .charging`)   | ✓ WIRED  | Pattern found.                                                                                   |
| PowerSourceMonitor.swift          | PowerActivity.swift         | returns `PowerReading(`                                   | ✓ WIRED  | 3 matches for `PowerReading(`. (gsd-tools reported false due to a double-escaped regex; manually confirmed.) |
| NotchWindowController.swift       | ChargingActivityState.swift | owns + mutates `@Published activity`, passes into view    | ✓ WIRED  | `chargingState.activity` set in handlePower (4 sites); injected into `NotchPillView(...)`.       |
| NotchWindowController.swift       | PowerSourceMonitor.swift    | owns the monitor, starts in start(), stops in deinit      | ✓ WIRED  | Constructed L169, `monitor.start()` L171, `powerMonitor.stop()` in deinit L428.                 |

All 7 key links WIRED. (Two were false-negatives from a tool-side regex double-escape only; the underlying links exist — confirmed by direct grep.)

### Data-Flow Trace (Level 4)

| Artifact                  | Data Variable             | Source                                                                 | Produces Real Data | Status     |
| ------------------------- | ------------------------- | --------------------------------------------------------------------- | ------------------ | ---------- |
| NotchPillView.wings(for:) | `charging.activity`       | `chargingState.activity` set in `handlePower` from a live IOPS reading via `powerActivity(from:)` | Yes (live IOKit power event → real percent/state) | ✓ FLOWING  |
| NotchPillView wings glyph | `percent` / `isCharging`  | destructured from the live `ChargingActivity` (clamped 0...100 in Plan 01) | Yes                | ✓ FLOWING  |

The view is not hollow: its data originates from a real `IOPSCopyPowerSourcesInfo` read, not a hardcoded value. The `chargingState` injected at the call site is the controller-owned instance whose `.activity` the live power path mutates (not a fresh empty `ChargingActivityState()` — those appear only in DEBUG previews).

### Behavioral Spot-Checks

| Behavior                                        | Command                                                                 | Result                              | Status |
| ----------------------------------------------- | ----------------------------------------------------------------------- | ----------------------------------- | ------ |
| Full automated suite green                      | `xcodegen generate && xcodebuild test -scheme Islet -destination 'platform=macOS,arch=arm64'` | `Executed 72 tests, 0 failures` / `** TEST SUCCEEDED **` | ✓ PASS |
| Phase-3 pure classification suite present+green | (within run) `PowerActivityTests`                                       | `Executed 16 tests, with 0 failures`| ✓ PASS |
| Wings geometry suite present+green              | (within run) `NotchGeometryTests`                                       | `Executed 16 tests, with 0 failures`| ✓ PASS |
| No polling timer in phase-3 files               | grep `Timer(`/`DispatchSourceTimer`/`scheduledTimer` × 6 files          | 0 matches                           | ✓ PASS |
| Single show/hide site preserved                 | grep `orderFrontRegardless`/`orderOut` in controller                    | exactly 2                           | ✓ PASS |
| Phase-3 commits exist in history                | gsd verify commits (8 hashes)                                           | all_valid: true                     | ✓ PASS |
| Real hardware power events + window compositing  | on-device UAT (human, can't re-run programmatically)                    | PASSED (recorded in 03-03-SUMMARY)  | ? SKIP (human-performed, accepted) |

The test suite was run fresh and independently — the 72/0 result was observed directly, not trusted from the SUMMARY.

### Requirements Coverage

| Requirement | Source Plan(s)      | Description                                                                 | Status               | Evidence                                                                                                              |
| ----------- | ------------------- | --------------------------------------------------------------------------- | -------------------- | -------------------------------------------------------------------------------------------------------------------- |
| CHG-01      | 03-01, 03-02, 03-03 | Plugging in shows a charging animation + battery % for a few seconds, then collapses | ✓ SATISFIED          | End-to-end loop wired and tested; on-device UAT PASSED. REQUIREMENTS.md status: Complete.                            |
| CHG-02      | 03-01, 03-02, 03-03 | Unplugging shows a brief "on battery" indication                            | ✓ DESCOPED (accepted) | Connect-only product decision (UAT 2026-06-27). `.onBattery` still classified; never triggers a splash. REQUIREMENTS.md status: "Descoped (connect-only, UAT 2026-06-27)". See override. |

Both declared requirement IDs are accounted for. No orphaned requirements: REQUIREMENTS.md maps only CHG-01 and CHG-02 to Phase 3, both claimed by the plans.

### Anti-Patterns Found

| File              | Line | Pattern                  | Severity | Impact                                                                                                                              |
| ----------------- | ---- | ------------------------ | -------- | --------------------------------------------------------------------------------------------------------------------------------- |
| NotchPillView.swift | 111  | "Phase-2 placeholder" comment | ℹ️ Info  | Descriptive comment on the **Phase-2** expanded-island time readout (not Phase-3 charging code). The wings branch is fully implemented. No action. |

No blockers, no warnings. No `TODO`/`FIXME`/`return null`/empty-handler stubs in any phase-3 file. No `import IOKit` outside `PowerSourceMonitor.swift`. No `InteractionPhase` case added (Phase-2 machine untouched — its 15 tests still pass).

### Human Verification Required

None outstanding. The IOKit + AppKit + SwiftUI wiring that cannot be unit-tested (real hardware plug/unplug power events, fullscreen window compositing, idle-CPU measurement, on-device wings sizing) was already verified by the human via the Task-3 on-device UAT checkpoint and recorded as PASSED in `03-03-SUMMARY.md`:

- plug-in splash (bolt glyph + %, ~3s collapse) ✓
- fullscreen no-show ✓
- connect-only (no unplug splash) ✓ (per user decision)
- wings sized to the measured notch (305×32) ✓
- idle CPU ~0% after collapse ✓

This report does not re-open those items; they are accepted as human-verified.

### Gaps Summary

No gaps. All four ROADMAP success criteria are met (SC#2 via an accepted, documented connect-only override), all required artifacts exist, are substantive, are wired, and carry live data; all seven key links are connected; the full 72-test suite is green (independently re-run); the power path is event-driven with zero polling timers; and the on-device UAT for the untestable system wiring was performed by the human and passed.

The phase goal — proving the activity→island rendering loop end-to-end on the safest public API — is achieved. The "or unplugging" clause of the goal is superseded by the user's deliberate connect-only product decision (recorded in REQUIREMENTS.md), which is an accepted scope change, not missing work.

---

_Verified: 2026-06-27T17:40:00Z_
_Verifier: Claude (gsd-verifier)_
