---
phase: 63-meeting-hud
verified: 2026-07-30T02:30:00Z
status: passed
score: 8/8 must-haves verified
overrides_applied: 0
user_override: "2026-07-30 — user explicitly accepted the 3 human_needed items (CR-01, CR-02/CR-03, WR-05) as code-verified/test-green without a live on-device re-test, during /gsd-complete-milestone v1.10 close-out. Phase counted as complete on that basis."
human_verification:
  - test: "Mute the mic from Control Center (or unplug/swap the input device) WHILE a call is standing and watch the HUD's icon."
    expected: "Within ~5s the mute icon flips to reflect the real state — the HUD must never keep showing 'muted' (or 'unmuted') for a live mic for the rest of the call (CR-01 fix)."
    why_human: "CR-01 (mid-call mute re-read + in-place refresh) landed in the code-review-fix pass AFTER the phase's own 2-round on-device UAT was already approved. The fix is code-verified (MeetingMonitor.evaluate() re-reads mute every poll, MeetingActivityTests pass) but the actual on-device convergence timing/render was never watched on hardware."
  - test: "Start a call, then plug in the charger (or connect/disconnect Bluetooth) WHILE the call stands, then let the call end."
    expected: "Nothing appears during the call (D-05a, already UAT-confirmed), AND no charging/device splash appears immediately after the call ends either — the displaced transient must be dropped, not resumed (CR-02/CR-03 fix)."
    why_human: "CR-02/CR-03 changed TransientQueue.preempt() to drop what a call displaces instead of parking it in `pending`. This is a queue-semantics change on top of the already-approved D-05a UAT; testMeetingOutranksLowerRankedPersistentTransients was updated and passes, but the user-visible 'no late splash' behavior was not re-run on hardware after this specific fix landed."
  - test: "During a call, click just past the mute icon's far edge, and separately confirm a menu-bar item sitting to the right of the notch stays clickable for the whole call."
    expected: "Clicks past the icon's real footprint pass through to whatever is underneath (already UAT-confirmed pre-fix); the ~84pt band between the pill and the icon stays click-through for the full call duration, not just briefly."
    why_human: "WR-05 replaced a single wide click-through rect with a 2-rect array plus a per-pointer-tick re-sync; UAT step 9 confirmed the pre-fix geometry but this specific fix (the re-sync mechanism, and the 'stays clickable for the whole call, not just the last click' claim) was flagged in 63-REVIEW-FIX.md as needing on-device confirmation and has not been checked off since."
---

# Phase 63: Meeting-HUD Verification Report

**Phase Goal:** While a native Zoom or Teams call is active with the microphone on, the notch
shows a call timer with a working system-mute toggle — the milestone's first feature with
genuine call-detection uncertainty (no public API), spiked on real hardware before the full HUD
is built, reusing the generalized persistent-transient path from Phase 62.
**Verified:** 2026-07-30
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | An on-device spike confirms/narrows a reliable "call active" heuristic, isolated in one `MeetingMonitor` file, with a documented go/no-go before the full HUD is built | ✓ VERIFIED | `Islet/Notch/MeetingMonitor.swift` is the sole file reading `NSWorkspace`/CoreAudio for this heuristic. `63-02-SUMMARY.md` records a **GO** verdict from a 3-run on-device spike (Discord stand-in, no Zoom/Teams on the validation machine): TCC-prompt-free, correct detect/clear, once-per-transition dedup, no false trigger with mic active but no target app running, Google Meet negative confirmed |
| 2 | Joining a real call with an active mic shows a call-timer HUD (mm:ss) in the notch | ✓ VERIFIED | `MeetingMonitor.evaluate()` → `NotchWindowController.handleMeetingActivityChange` → `transientQueue.preempt(.meeting(activity))` → `IslandResolver`'s rank-3 `.meeting` case → `NotchPillView.meetingWings(for:)` renders live `mm:ss` from `meetingElapsedLabel`, computed inside the `TimelineView` tick. On-device UAT (63-04, 2 rounds, "approved") confirmed the HUD appears with live mm:ss on a real voice call |
| 3 | Tapping the HUD's mute control toggles the system-wide mic mute (shared `MicMuteController`, not in-app) and the icon reflects current mute state | ✓ VERIFIED | `meetingWings`' nested `.onTapGesture` → `onMuteTap` → `NotchWindowController.handleMuteTap()` → `toggleSystemInputMute()` (CoreAudio `kAudioDevicePropertyMute`, Input scope) → `updateHead` + `renderPresentation()`; icon swaps `mic.fill`/white ↔ `mic.slash.fill`/red. On-device UAT round 1 steps 6-8 confirmed real system mute toggling and icon reflection (also settled the nested-tap hit-testing risk, A2) |
| 4 | Opening Google Meet in a browser does not show the Meeting-HUD — documented as a known limitation | ✓ VERIFIED | `MeetingMonitor`'s detection is an AND of bundle-ID match (`us.zoom.xos`/`com.microsoft.teams2`/`com.microsoft.teams`) and mic-active — a browser tab matches neither. On-device UAT steps 12-13 confirmed no HUD appears for a real Google Meet browser call. Settings card copy explicitly scopes to "Zoom/Teams calls" |

**Score:** 4/4 ROADMAP success criteria verified.

### Additional Plan-Level Must-Haves

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 5 | Meeting-HUD is a persistent transient that only Charging/Device style hardware events could interrupt at planning time, but on-device UAT led to D-05a superseding this — nothing interrupts a live call | ✓ VERIFIED | `TransientQueue.dropsWhileCallStands(_:)` in `IslandResolver.swift`, consulted by both `enqueue()` and `preempt()`; `testNothingInterruptsAStandingMeetingHead` covers 8 incoming categories via both paths. D-05a is recorded in `63-CONTEXT.md` with its on-device provenance (round-1 UAT failure → user decision) |
| 6 | Settings toggle for Meeting HUD defaults OFF and gates the monitor's lifecycle | ✓ VERIFIED | `ActivitySettings.meetingHUDKey`, `@AppStorage(...) = false` in `SettingsView.swift`; `NotchWindowController.start()`/toggle-observer both gate `startMeetingMonitor()`/`meetingMonitor?.stop()` on `activityEnabled(ActivitySettings.meetingHUDKey)`; card registered in the Live-Activity grid (`isNew: true`) |
| 7 | `MicMuteController`'s mute read/write never crashes on a device that doesn't implement the Mute property (T-63-01) | ✓ VERIFIED | `AudioObjectHasProperty` guard precedes every Get/Set in `MicMuteController.swift` (3 occurrences); `MicMuteControllerTests` (3/3) pass in my independent re-run |
| 8 | Monitor lifecycle has no leaked listeners/timers/observers across repeated Settings toggle on/off (T-63-04) | ✓ VERIFIED | `MeetingMonitor.stop()` removes the identical listener block from both the system object and the stored `listenedDeviceID`, invalidates the poll timer, drops NSWorkspace observers, and resets `lastReading`/`lastCallStart`/`lastEndedAt` (WR-04 fix); `NotchWindowController` calls `meetingMonitor?.stop()` on toggle-off and in `deinit` |

**Score:** 8/8 must-haves verified (4 ROADMAP SCs + 4 plan-level truths).

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/MeetingActivity.swift` | Pure `MeetingActivity`/`MeetingReading` + `meetingElapsedLabel` (D-13, no h:mm:ss branch) | ✓ VERIFIED | 44 lines, Foundation-only, no `Date()` inside functions, clamps negative elapsed to 00:00 |
| `Islet/Notch/MicMuteController.swift` | `defaultInputDeviceID`/`readSystemInputMuted`/`toggleSystemInputMute`, Input-scope only | ✓ VERIFIED | 81 lines, `kAudioDevicePropertyScopeInput` only, guarded by `AudioObjectHasProperty` before every Get/Set |
| `Islet/Notch/MeetingMonitor.swift` | Isolated detection risk, once-per-transition dedup, GO verdict | ✓ VERIFIED | 272 lines, event-driven (NSWorkspace + CoreAudio listeners) + 5s poll fallback, dedup in `evaluate()`, CR-01/WR-02/WR-03/WR-04 fixes all present |
| `Islet/Notch/IslandResolver.swift` | `.meeting` case at rank 3, `isPersistent`, `dropsWhileCallStands` | ✓ VERIFIED | All present; `preempt()` unmodified except for the drop-rule guard, per design |
| `Islet/Notch/NotchPillView.swift` | `meetingWings(for:)`, `onMuteTap` seam, mute-icon geometry statics | ✓ VERIFIED | Wing renders icon/mm:ss/mute icon with `onTap: {}` no-op background + nested tappable mute icon |
| `Islet/Notch/NotchWindowController.swift` | Monitor lifecycle, `handleMeetingActivityChange`, `handleMuteTap`, click-through zones, Settings wiring | ✓ VERIFIED | All present; WR-01 (validate-before-write) guard order confirmed in current code |

### Key Link Verification

| From | To | Via | Status |
|------|----|----|--------|
| `MeetingMonitor.evaluate()` | `NotchWindowController.handleMeetingActivityChange` | `onChange` closure | ✓ WIRED |
| `handleMeetingActivityChange` | `TransientQueue.preempt`/`updateHead`/`removeAll` | direct calls, CR-01-routed mid-call refresh | ✓ WIRED |
| `IslandResolver.resolve()` | `NotchPillView.meetingWings` | `presentationSwitch`'s `.meeting(let activity)` arm | ✓ WIRED |
| Mute icon tap | `MicMuteController.toggleSystemInputMute` | `onMuteTap` → `handleMuteTap()` | ✓ WIRED |
| `collapsedInteractiveZone()`/`syncClickThrough()` | mute icon's real screen position | `meetingClickThroughZones()`, `meetingMuteIconTrailingEdgeOffset` | ✓ WIRED |
| `SettingsView` toggle | `MeetingMonitor` lifecycle | `activityEnabled(ActivitySettings.meetingHUDKey)` | ✓ WIRED |

### Behavioral Spot-Checks / Test Execution

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full suite, independently re-run (not trusting SUMMARY claims) | `xcodebuild test -scheme Islet -destination 'platform=macOS'` | 582 tests, 7 failures — 4x `LicenseStateTests`, 3x `SettingsViewTests`, all pre-existing per `deferred-items.md`/Phase-70's own independently-confirmed baseline; **zero failures in any Meeting-HUD file** | ✓ PASS |
| Meeting-HUD-specific suites | subset of the run above | `MeetingActivityTests` 6/6, `MicMuteControllerTests` 3/3, `IslandResolverTests` 96/96, `MeetingMonitorManualSpike` (manual harness, passes trivially — real detection is the on-device spike, not this CI run) | ✓ PASS |
| Debt-marker scan | `grep -n "TBD\|FIXME\|XXX\|TODO\|HACK\|PLACEHOLDER"` on all 6 Phase-63 files | 0 matches (one unrelated comment using the word "placeholder" describing an unused enum branch, not a stub) | ✓ PASS |
| Debug build | `xcodebuild build -scheme Islet -configuration Debug` (via the test run above) | BUILD SUCCEEDED | ✓ PASS |

Note: the pre-existing-failure baseline this task description quoted ("SettingsViewTests x2") is
slightly stale — the actual, currently-confirmed baseline is **3x** `SettingsViewTests`
(`testProductivityCardsAllNew`, `testSystemHUDCardsCount`, `testSystemHUDCardsExistingBeforeNew`),
matching exactly what Phase 70's independent verification run also recorded 
(`.planning/phases/70-file-tray-convert-button/70-VERIFICATION.md`). Not a Phase-63 regression.

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| MEET-01 | Call-timer HUD while Zoom/Teams running AND mic active | ✓ SATISFIED | Truths #1, #2; REQUIREMENTS.md marked Complete |
| MEET-02 | Mute control toggles system-wide mic mute via shared `MicMuteController` | ✓ SATISFIED | Truth #3; REQUIREMENTS.md marked Complete |
| MEET-03 | Google Meet (browser) not detected, documented limitation | ✓ SATISFIED | Truth #4; REQUIREMENTS.md marked Complete, Settings copy scoped correctly |

No orphaned requirements — MEET-01/02/03 are the only IDs mapped to Phase 63 in
REQUIREMENTS.md, and all three are declared across the 4 plans' frontmatter.

### Anti-Patterns Found

None. No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` debt markers, no empty stub returns, no
hardcoded-empty rendering paths in any of the 6 Meeting-HUD files. `WR-06` was explicitly
**skipped** in `63-REVIEW-FIX.md` with a documented, sound reason (matches this codebase's
established `nonisolated func stop()` convention used by every other `*Monitor`; the suggested
fixes would not compile or would introduce a real deadlock risk) — reviewed and this reasoning
holds. `IN-01..IN-05` (Info-severity, incl. IN-04's VoiceOver accessibility trait) were correctly
left out of scope for this review cycle; IN-04 remains a worthwhile small follow-up, not a phase
blocker.

### Human Verification Required

Three items, all originating from `63-REVIEW-FIX.md`'s own "Requires human verification" notes
on the code-review fixes (CR-01, CR-02/CR-03, WR-05) that landed **after** the phase's 2-round
on-device UAT was already approved. These fixes are code-verified (present in the current tree,
compile, and pass the full regression suite I independently re-ran) but their specific on-device
runtime behavior has not been re-observed since landing:

### 1. CR-01 — mid-call mute state stays live (5s convergence)
**Test:** Mute the mic from Control Center (or swap input device) while a call stands; watch the HUD icon.
**Expected:** Icon reflects the real mute state within ~5s, never stuck stale for the rest of the call.
**Why human:** Runtime timing/render behavior, not statically verifiable; postdates the approved UAT script.

### 2. CR-02/CR-03 — displaced transient is dropped, not resumed after the call
**Test:** Start a call, plug in the charger mid-call, let the call end; watch for a delayed splash.
**Expected:** No charging/device splash appears after the call ends (the original UAT-round-1 symptom must stay fixed under the new drop-not-park queue semantics).
**Why human:** Queue-semantics change verified by updated unit tests, but the user-visible "no late pop-up" behavior needs on-device confirmation with this exact fix in place.

### 3. WR-05 — click-through geometry stays correct for the whole call, not just briefly
**Test:** During a call, click just past the mute icon's far edge; separately confirm a menu-bar item right of the notch stays clickable throughout the call.
**Expected:** Clicks past the icon pass through; the ~84pt gap band stays click-through for the full call duration.
**Why human:** The fix replaced a single rect with a per-pointer-tick re-synced 2-rect array — the original UAT step 9 tested the pre-fix geometry, not this mechanism.

### Gaps Summary

No gaps against the phase goal. All 4 ROADMAP Success Criteria and all 4 additional plan-level
must-haves are verified in the current codebase — confirmed by reading the actual implementation
(not just SUMMARY.md claims) and by independently re-running the full test suite (582 tests, 7
pre-existing failures, zero new, zero in any Meeting-HUD file). The phase's core deliverable —
detection, timer HUD, real system mute toggle, Google Meet negative — was proven end-to-end on
real hardware via a 2-round on-device UAT that ended "approved."

The three items above are not gaps in the phase's delivered capability; they are un-reconfirmed
edge-case fixes that landed in the post-UAT code-review pass, exactly mirroring the precedent
already established by `70-VERIFICATION.md`'s CR-01 handling on this same project. Routed to
human verification rather than blocking, since none of them touch the 4 ROADMAP success criteria
that define this phase's goal.

---

_Verified: 2026-07-30_
_Verifier: Claude (gsd-verifier)_
