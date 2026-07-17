---
phase: 38-focus-mode-hud
verified: 2026-07-17T02:50:00Z
status: gaps_found
score: 2/4 must-haves verified
overrides_applied: 0
gaps:
  - truth: "Toggling Focus/DND on shows the new HUD in a generic 'Focus On' state; toggling off dismisses it — no named-mode text anywhere (ROADMAP SC #2)"
    status: failed
    reason: "NotchWindowController.activityEnabled(_:) (lines 561-563) has a single hard-coded `?? true` fallback used for every activity key, including ActivitySettings.focusKey. The toggle's own @AppStorage default is correctly OFF (SettingsView.swift:37, `focusEnabled = false`), but the controller's independent read of the same UserDefaults key does NOT share that default — a fresh install with no UserDefaults key ever written reads focusKey as enabled=true. Both gate sites (start() line 474, handleSettingsChanged() line 1713) combine this with `FocusModeMonitor.isAuthorized`; if OS-level INFocusStatusCenter authorization is already granted (documented as the actual state of the project's own dev machine in FocusModeMonitor.swift's header), the monitor silently auto-starts and the HUD can appear despite the visible Settings toggle reading OFF. This violates D-01/D-02, which SC #2 depends on for 'no HUD without an explicit user opt-in step'."
    artifacts:
      - path: "Islet/Notch/NotchWindowController.swift"
        issue: "activityEnabled(_:) at lines 561-563 defaults every key (including focusKey) to true; no per-key override for focusKey's documented OFF default"
    missing:
      - "Give focusKey an explicit false fallback in activityEnabled(_:), separate from the shared true-default used by every other activity toggle"
  - truth: "The FocusActivity/FocusModeMonitor pipeline routes through IslandResolver/TransientQueue like every other transient — no resolver bypass, and functions reliably for the primary first-grant user flow (ROADMAP SC #4, cross-cutting with SC #1/#3's spike-to-shipped-feature promise)"
    status: failed
    reason: "The pure resolver/queue wiring itself is correct and well-tested (IslandResolver.swift .focus case wired into resolve() and TransientQueue, IslandResolverTests.swift covers D-06/D-07/D-08). However the system-glue path that is supposed to feed it never fires for the standard first-time-user flow: SettingsView.swift's 'Continue' button (lines 273-276) calls `FocusModeMonitor.requestAuthorization { _ in }` and discards the completion result. The only two call sites that can start FocusModeMonitor (NotchWindowController.swift start() line 474, handleSettingsChanged() line 1713) are both driven exclusively by UserDefaults.didChangeNotification. Flipping the Settings toggle ON fires handleSettingsChanged() while isAuthorized is still false (OS dialog unresolved) — guard fails, monitor does not start. When the async grant resolves moments later, nothing calls startFocusModeMonitor() or re-runs handleSettingsChanged(); focusEnabled stays true so no further UserDefaults write occurs to re-trigger it. The monitor never starts until the user manually toggles off/on again or restarts the app — neither discoverable nor documented. This is the primary path a first-time user takes to reach the HUD at all."
    artifacts:
      - path: "Islet/SettingsView.swift"
        issue: "requestAuthorization completion (lines 273-276) discarded; no callback threads the grant back to the controller"
      - path: "Islet/Notch/NotchWindowController.swift"
        issue: "No focusPermissionGranted()-style entry point exists; startFocusModeMonitor() is only reachable from launch and from UserDefaults change notifications"
    missing:
      - "Thread requestAuthorization's completion back into the controller (e.g. a callback/notification) that re-runs the same start-gate handleSettingsChanged() already uses, so a successful grant actually starts the monitor without a toggle-off/on or relaunch workaround"
deferred: []
---

# Phase 38: Focus Mode HUD Verification Report

**Phase Goal:** A generic on/off Focus Mode HUD appears when the user toggles Focus/Do Not Disturb — an on-device research spike confirms the detection mechanism first, then the feature is built as the first genuinely new ActiveTransient case in this milestone, proving the "new pure Activity type → Monitor → resolver case → wing view" pipeline once, cheaply, before Phase 39 attempts the same pipeline under real private-API risk.
**Verified:** 2026-07-17T02:50:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | An on-device spike confirms and records which detection path is used before full implementation proceeds | ✓ VERIFIED | `FocusModeMonitor.swift:11-17` header documents Path A (`INFocusStatusCenter`) won on-device, superseding 38-RESEARCH.md's prediction; `38-01-SUMMARY.md` and `38-07-SUMMARY.md` record the spike result; `FocusDetectionSpike.swift` was removed once locked in (38-07, commit `fbfab85`), confirmed zero references remain |
| 2 | Toggling Focus/DND on shows the new HUD in a generic "Focus On" state; toggling off dismisses it — no named-mode text anywhere | ✗ FAILED | UI rendering itself is correctly generic (`NotchPillView.swift:2151-2170` `focusWings` shows only "Focus" + moon icon + green dot, `FocusActivity` is a single `.on` case, no named-mode payload anywhere per `FocusActivity.swift:13-15`). BUT the toggle's true on/off state is not reliably respected at runtime: CR-01 (`activityEnabled(_:)` default-true bug, confirmed live in `NotchWindowController.swift:561-563`) can auto-start the monitor with the Settings toggle showing OFF, and CR-02/WR-02 (confirmed live in `SettingsView.swift:273-276`) means the normal first-grant flow never actually starts the monitor at all without an undocumented toggle-off/on or app restart. Both are BLOCKER-level and unfixed as of the latest commit (`15903b5`, the review commit itself, is the tip — no follow-up fix commits exist) |
| 3 | If the FDA-gated path is required, denying that permission degrades silently rather than blocking the rest of the app | ✓ VERIFIED (path not applicable, but silent-degrade convention correctly implemented for the path actually used) | Path A was used, not the FDA path, so this criterion's literal FDA scenario is N/A. The silent-degrade convention it protects is nonetheless correctly implemented for Path A: `FocusModeMonitor.poll()` (lines 56-63) guards on `.authorized` and a non-nil `isFocused` read, doing nothing (no crash, no onChange call, no spin) on any non-authorized or unreadable state — mirrors `LocationProvider.swift`'s documented D-01 shape |
| 4 | The new FocusActivity/FocusModeMonitor pipeline routes through IslandResolver/TransientQueue like every other transient — no resolver bypass | ✗ FAILED | The resolver/queue wiring itself is structurally correct and well-tested (`IslandResolver.swift:59,75,120-121` `.focus` case wired into `resolve()`; `TransientQueue.preempt/enqueue` handle it; `IslandResolverTests.swift` covers D-06/D-07/D-08 precedence). However CR-02/WR-02 means the upstream glue that is supposed to feed this pipeline (FocusModeMonitor actually running) never activates for the standard first-grant flow, so the pipeline is proven correct in isolation but not reliably reachable end-to-end. Separately (not blocking, but real): WR-01 documents a `TransientQueue.preempt(_:)` bound-violation / eviction-order bug that can cause a displaced Focus entry to be silently evicted from `pending` before its scheduled resume, though it self-heals within ~2.5s via the poll re-enqueue — kept as a warning, not a blocker, since it does not prevent the HUD from ever appearing, only causes a transient queue-ordering hiccup |

**Score:** 2/4 truths verified

### Independent Verification of Code-Review Findings (CR-01, CR-02/WR-02)

Both CRITICAL findings from `38-REVIEW.md` were independently re-confirmed by directly reading the live files (not trusting the review or the SUMMARY):

- **CR-01 — CONFIRMED LIVE.** `Islet/Notch/NotchWindowController.swift:561-563`:
  ```swift
  private func activityEnabled(_ key: String) -> Bool {
      UserDefaults.standard.object(forKey: key) as? Bool ?? true
  }
  ```
  This single helper is used at both `start()` (line 474) and `handleSettingsChanged()` (line 1713) to gate `startFocusModeMonitor()`. It has no per-key branch for `ActivitySettings.focusKey`, despite `ActivitySettings.swift:19-22` and `SettingsView.swift:37` (`@AppStorage(focusKey) private var focusEnabled = false`) both documenting focusKey as the one activity toggle that must default OFF. The mismatch is real: the controller's own default and the UI's default diverge for the same UserDefaults key.

- **CR-02/WR-02 — CONFIRMED LIVE.** `Islet/SettingsView.swift:273-276`:
  ```swift
  Button("Continue") {
      FocusModeMonitor.requestAuthorization { _ in }
      showFocusPermissionExplanation = false
  }
  ```
  The completion closure is discarded (`{ _ in }`). Grepping `NotchWindowController.swift` confirms `startFocusModeMonitor()` is called from exactly two places — `start()` (launch) and `handleSettingsChanged()` (UserDefaults change notification) — and no third path exists that the permission-grant completion could reach. No `focusPermissionGranted()`-style method or NotificationCenter post/observe pair for this event exists anywhere in the reviewed files.

- **38-07-SUMMARY.md's UAT evidence does not falsify either finding.** The plan's own Task 2 step 3 explicitly anticipated this exact ambiguity ("...confirm the status hint flips... may require re-toggling off/on or relaunching if the app does not live-poll permission grants — note which behavior you observe"), but the SUMMARY collapsed all 10 steps into a blanket "approved... no issues, no deviations" with no verbatim capture of whether a re-toggle/relaunch was actually needed. Tracing the UAT script itself: step 2 flips the Settings toggle ON (which is the point CR-01's bug is invisible — `focusPermissionStatusHint` returns nil while toggle-off regardless of the monitor's actual running state, and the hint is computed from `focusEnabled`, which is already true by step 4). This means the scripted UAT sequence structurally could not have exercised the CR-01 fresh-install/toggle-still-OFF scenario at all (the toggle is flipped ON in step 2, before Focus/DND is ever toggled in step 4) — it is not evidence against CR-01. For CR-02/WR-02, the UAT's step 4 success ("Focus wing appears") is only possible if the monitor was in fact running at that point, which per code should require either an undocumented re-toggle the tester wasn't asked to report precisely, or some other incidental re-render/UserDefaults write not visible in the reviewed code paths. Given the code has no reachable path from grant → monitor start, and no fix commit exists after the review, this is treated as a real, unresolved gap rather than proof the bug doesn't exist.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/FocusModeMonitor.swift` | Thin Path-A detection glue, silent-degrade, polling | ✓ VERIFIED | Substantive, isolated to Intents/INFocusStatusCenter, matches PowerSourceMonitor/BluetoothMonitor isolation discipline |
| `Islet/Notch/FocusActivity.swift` | Pure single-case Activity + total mapping fn | ✓ VERIFIED | `enum FocusActivity { case on }`, `focusActivity(from:)` total mapping, Foundation-only |
| `Islet/Notch/IslandResolver.swift` | `.focus` ActiveTransient case, resolver precedence, TransientQueue preempt | ✓ VERIFIED (wiring) / ⚠️ WR-01 queue-bound bug (non-blocking) | `.focus` correctly wired into `resolve()` (collapsed-only, D-07); `preempt(_:)` has an unbounded insert not trimmed on overflow (self-heals in ~2.5s, not a HUD-blocking defect) |
| `Islet/Notch/NotchPillView.swift` | Generic Focus wing, fixed white, no accent | ✓ VERIFIED | `focusWings(for:)` renders "Focus" text + moon icon fixed `.white`, green dot, no theme accent reference |
| `Islet/SettingsView.swift` | Toggle defaults OFF, permission popover, status hint | ⚠️ ORPHANED (functionally) | UI elements all exist and render correctly in isolation, but the permission-grant → monitor-start wiring is broken (CR-02/WR-02) |
| `Islet/Notch/NotchWindowController.swift` | Toggle-gated monitor lifecycle mirroring Charging/Devices | ✗ STUB-LIKE DEFECT | `activityEnabled(_:)` shared-default bug (CR-01) makes the focusKey gate unreliable |
| `Islet/FocusDetectionSpike.swift` | Removed once path locked (38-07) | ✓ VERIFIED | File deleted, `AppDelegate.swift` DEBUG hook removed, confirmed via git log (`fbfab85`) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `SettingsView.swift` Toggle("Focus Mode HUD") | `FocusModeMonitor.requestAuthorization` | `.onChange(of: focusEnabled)` | ✓ WIRED | Fires the request correctly on off→on flip only, matching D-02 |
| `FocusModeMonitor.requestAuthorization` completion | `NotchWindowController.startFocusModeMonitor()` | (none — missing) | ✗ NOT_WIRED | CR-02/WR-02: completion discarded, no callback path exists |
| `NotchWindowController.handleFocusChange` | `TransientQueue.enqueue`/`IslandResolver.resolve` | direct call | ✓ WIRED | `handleFocusChange(_:)` correctly enqueues/flushes and calls `presentTransientChange()` |
| `UserDefaults` focusKey write | `NotchWindowController.activityEnabled(focusKey)` | `activityEnabled(_:)` helper | ⚠️ PARTIAL/BUGGY | Reads the key but with the wrong (shared `true`) default (CR-01) |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|----------------|--------------|--------|----------|
| HUD-05 | 38-01 through 38-07 (all) | A Focus Mode HUD appears when the user toggles Focus/DND, generic on/off state only | ✗ BLOCKED | Structurally implemented and unit-tested at the pure-function/resolver level, but the two system-glue defects (CR-01, CR-02/WR-02) mean the feature does not reliably work end-to-end for the primary first-time-user flow at runtime. `.planning/REQUIREMENTS.md:120` still lists HUD-05 as "Pending" (tracker not updated to Complete post-phase — consistent with the functional gaps found, not just a stale-doc issue) |

No orphaned requirements: HUD-05 is the only ID mapped to Phase 38 in REQUIREMENTS.md, and it appears in every plan's `requirements:` frontmatter.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `Islet/Notch/NotchWindowController.swift` | 561-563 | Incorrect shared default in `activityEnabled(_:)` for a key documented to need a different default | 🛑 Blocker | Directly causes SC #2 failure (CR-01) |
| `Islet/SettingsView.swift` | 273-276 | Discarded async completion result (`{ _ in }`) on a security/permission-relevant call | 🛑 Blocker | Directly causes SC #4 / primary-flow failure (CR-02/WR-02) |
| `Islet/Notch/IslandResolver.swift` | 241-263 | `preempt(_:)` bypasses the `maxDepth` bound `enqueue(_:)` enforces | ⚠️ Warning | Queue-ordering hiccup, self-heals within ~2.5s, not HUD-blocking |

No TBD/FIXME/XXX debt markers found in the phase's files.

### Behavioral Spot-Checks

Skipped — this is a native macOS app requiring a GUI build/run and physical Focus/DND toggling; not runnable via headless command in this environment. Covered instead by direct code-path tracing (see "Independent Verification" section above) and by the human on-device UAT in `38-07-SUMMARY.md` (whose evidentiary weight is discussed and discounted for the two specific defects above).

### Probe Execution

No `scripts/*/tests/probe-*.sh` files or probe references found for this phase — SKIPPED (no runnable entry points; this is an Xcode/Swift GUI app phase, verified via `xcodebuild`-class gates in earlier plans, not shell probes).

### Human Verification Required

None new — a full 10-step on-device UAT was already run for this phase (`38-07-SUMMARY.md`). However, given the two confirmed code-level defects above, the following RE-VERIFICATION is recommended before this phase can be considered done, structured so the ambiguity the original UAT script anticipated is actually captured this time:

#### 1. Fresh-install / toggle-still-OFF auto-start check (CR-01)

**Test:** With the Settings "Focus Mode HUD" toggle showing OFF (never touched, or explicitly reset via `defaults delete` on `activity.focus`) AND `INFocusStatusCenter` authorization already granted from a prior session/spike run, quit and relaunch Islet. Toggle macOS Focus/DND ON via Control Center.
**Expected:** The Focus HUD should NOT appear — the toggle is OFF.
**Why human:** Requires a real prior-authorization state and a real app relaunch; cannot be simulated via grep/static analysis, and the code path depends on actual `INFocusStatusCenter.default.authorizationStatus` on the test machine.

#### 2. First-grant flow without any toggle-off/on workaround (CR-02/WR-02)

**Test:** With Focus/DND authorization never previously granted, flip the Settings "Focus Mode HUD" toggle ON, click "Continue" in the popover, grant the OS permission dialog — do nothing else (no re-toggle, no relaunch). Then toggle macOS Focus/DND ON.
**Expected (per the current code):** The Focus HUD will NOT appear, because `startFocusModeMonitor()` is never called after the grant resolves.
**Why human:** Requires the real async OS authorization dialog and a from-scratch permission state; the previous UAT run may have inadvertently exercised a re-toggle without recording it precisely.

### Gaps Summary

Two CRITICAL system-glue defects, both independently re-confirmed against the current live code (not just trusted from `38-REVIEW.md`), remain unfixed as of the latest commit:

1. **CR-01** — `NotchWindowController.activityEnabled(_:)`'s single shared `?? true` default is wrong for `focusKey`, which is documented (D-01) to default OFF. This can cause the Focus monitor to silently auto-start on a fresh install whenever OS-level authorization already happens to be granted, contradicting the visible Settings toggle state.
2. **CR-02/WR-02** — The permission-grant completion in `SettingsView.swift`'s "Continue" button is discarded; nothing re-triggers `startFocusModeMonitor()` after the async OS grant resolves, so the primary first-time-user flow (toggle on → popover → grant) never actually starts the monitor without an undocumented workaround.

Both bugs sit in the same root cause the code review identified: `NotchWindowController` reads/reacts to Focus's enabled/authorized state independently in multiple places with no single reactive source of truth tied to the actual moment of permission grant. The pure seams (FocusActivity, IslandResolver's `.focus` case, the wing view) are correct and well-tested — the failure is entirely in the system-glue layer connecting Settings → Monitor → Controller.

The existing `38-07-SUMMARY.md` UAT sign-off does not override these findings: tracing the UAT script shows it structurally could not have exercised CR-01's scenario (the toggle is flipped ON in step 2, before Focus/DND is toggled in step 4), and its step 3 explicitly anticipated the CR-02/WR-02 ambiguity but the recorded "approved" blanket answer did not capture whether a re-toggle/relaunch was actually needed to make step 4 succeed.

Because these are BLOCKER-level defects directly contradicting ROADMAP Success Criteria #2 and #4, this phase cannot be marked passed. A closure plan should target exactly these two defects (`Islet/Notch/NotchWindowController.swift` activityEnabled + a grant-completion callback path) — the fixes suggested in `38-REVIEW.md`'s CR-01/WR-02 sections are directly actionable.

---

_Verified: 2026-07-17T02:50:00Z_
_Verifier: Claude (gsd-verifier)_
