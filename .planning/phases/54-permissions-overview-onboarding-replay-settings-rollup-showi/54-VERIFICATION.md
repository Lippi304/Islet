---
phase: 54-permissions-overview-onboarding-replay-settings-rollup-showi
verified: 2026-07-21T23:51:05Z
status: gaps_found
score: 8/11 must-haves verified
overrides_applied: 0
gaps:
  - truth: "User can re-request any denied/not-yet-granted permission individually and have the grant actually take effect"
    status: partial
    reason: "The tap-to-act UI exists and correctly triggers OS-level requests, but 3 of 5 rows wire into the wrong app-side code path (confirmed unfixed in 54-REVIEW.md, no follow-up commit exists after the review). Bluetooth's grant bypasses the user's own 'Devices' activity toggle and starts live monitoring even when the user explicitly disabled it. Location's grant never reaches the app's real one-shot fetch (startLocationOnce()), so a grant made through this row has no visible effect on weather/location data until the app is relaunched. Focus's grant result is discarded, so an already-enabled Focus toggle doesn't start polling until manually re-toggled."
    artifacts:
      - path: "Islet/SettingsView.swift"
        issue: "handlePermissionTap(kind: .bluetooth, ...) calls notchController.requestBluetoothPermission() which unconditionally starts the Bluetooth monitor with no activityEnabled(deviceKey) gate (CR-01); handlePermissionTap(kind: .location, ...) calls a disconnected CLLocationManager().requestWhenInUseAuthorization() that never reaches startLocationOnce() (CR-02); handlePermissionTap(kind: .focus, ...) calls FocusModeMonitor.requestAuthorization { _ in } and discards the granted result instead of calling focusPermissionGranted() (WR-01)"
    missing:
      - "Gate requestBluetoothPermission() on activityEnabled(ActivitySettings.deviceKey), mirroring every other Bluetooth-monitor start site in NotchWindowController.swift"
      - "Add a requestLocationPermission() bridge on NotchWindowController that calls startLocationOnce(), and call it from SettingsView's .location case instead of a throwaway CLLocationManager()"
      - "Wire the Focus grant callback to call notchController?.focusPermissionGranted() on granted == true, mirroring the existing focusPermissionExplanationView Continue-button pattern"
  - truth: "Replay Onboarding reliably shows the carousel regardless of the panel's current visibility state"
    status: failed
    reason: "replayOnboarding() (NotchWindowController.swift:1951-1965) never calls updateVisibility(), unlike its own exit counterpart finishOnboardingReplay() and the original finishOnboarding(). If the panel is currently off-screen when the user taps 'Replay Onboarding' in Settings (e.g. another app in fullscreen with hideInFullscreen on, or an expired-trial lockout with the pointer not over the now-invisible hot-zone), the onboarding state is fully set internally but the NSPanel itself never comes back on-screen — a silent no-op from the user's point of view. Confirmed still present and unfixed as of the latest commit (2dde28d, which only adds the review report, no code fix)."
    artifacts:
      - path: "Islet/Notch/NotchWindowController.swift"
        issue: "replayOnboarding() (lines 1951-1965) is missing the updateVisibility() call that both finishOnboarding() and finishOnboardingReplay() make"
    missing:
      - "Add updateVisibility() to replayOnboarding(), after the withAnimation block, before syncClickThrough() — matching the pattern already used in finishOnboarding()/finishOnboardingReplay()"
---

# Phase 54: Permissions Overview & Onboarding Replay Verification Report

**Phase Goal:** Settings gains a "Permissions" rollup showing how many of the app's permissions are granted (X of Y), lets the user see the status of and re-request any denied/not-yet-granted permission individually, and offers a "Replay Onboarding" button in About.
**Verified:** 2026-07-21T23:51:05Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Settings shows a "Permissions" sidebar section with an "X of 5 granted" summary above 5 always-visible rows | ✓ VERIFIED | `Islet/SettingsView.swift:429-458` (`permissionsSection`, `grantedPermissionCount`); `.permissions` inserted between `.weather`/`.diagnostics`, not filtered by `visibleSections(hasNotch:)`; confirmed by 2 passing regression tests |
| 2 | Each of the 5 permission kinds resolves to a deterministic 3-state status via pure, unit-tested mapper functions | ✓ VERIFIED | `Islet/PermissionStatus.swift` — 16/16 `PermissionStatusTests` pass (ran live: `xcodebuild test -only-testing:IsletTests/PermissionStatusTests` → 0 failures) |
| 3 | Calendar+Reminders combined row shows the worst of the two underlying statuses (D-13) | ✓ VERIFIED | `combinedCalendarReminderStatus` + 3 dedicated tests, all pass |
| 4 | Tapping a granted-status row is inert | ✓ VERIFIED | `permissionRow(...)` has `.disabled(status == .granted)`; `handlePermissionTap`'s `.granted` case is a bare `return` |
| 5 | Tapping a denied-status row opens System Settings to the specific Privacy & Security pane | ✓ VERIFIED | `handlePermissionTap`'s `.denied` case builds the deep-link URL from `kind.deepLinkAnchor` and calls `NSWorkspace.shared.open` — reuses the proven-working `x-apple.systempreferences:` prefix |
| 6 | User can re-request any not-yet-granted permission individually and have the grant actually take effect in the app | ✗ FAILED | Dialog/prompt triggers fire for all 5 kinds, but 3 of 5 (Bluetooth, Location, Focus) wire into the wrong downstream code path — confirmed unfixed in code (see Gaps below); `54-REVIEW.md` CR-01/CR-02/WR-01 |
| 7 | "Replay Onboarding" button in About shows the full carousel without ever writing `ActivitySettings.onboardingCompletedKey` | ✓ VERIFIED | `aboutSection` has the button calling `notchController?.replayOnboarding()`; `finishOnboardingReplay()` body contains no `UserDefaults` call (confirmed by direct read of `NotchWindowController.swift:1973-1985`) |
| 8 | Replay reliably shows on-screen regardless of the panel's current visibility state | ✗ FAILED | `replayOnboarding()` never calls `updateVisibility()`, unlike its own exit path and the real `finishOnboarding()` — silent no-op risk when panel is hidden; `54-REVIEW.md` CR-03, confirmed unfixed |
| 9 | Exiting a replay (Done or the new X) restores `interaction.phase` to exactly what it was before the replay started | ✓ VERIFIED | `finishOnboardingReplay()` restores `replayPriorPhase ?? .collapsed`, never `nextState(_, .clicked)` |
| 10 | The replay-only close button renders only when `onboardingState.isReplay` is true | ✓ VERIFIED | `NotchPillView.swift:1757-1758` gates `replayCloseButton` on `onboardingState.isReplay`; `onOnboardingCancel` wired to `finishOnboardingReplay()` |
| 11 | `finishOnboarding()` (the real first-launch path) is completely untouched | ✓ VERIFIED | `NotchWindowController.swift:1932-1944` byte-matches the plan's own "do NOT modify" interface snippet, still writes `onboardingCompletedKey`, still calls `startBluetoothMonitor()`/`startOutfitRefresh()` |

**Score:** 8/11 truths verified (2 FAILED — both structural/functional, not cosmetic; 1 counted-as-failed umbrella truth carries 3 sub-bugs)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/PermissionStatus.swift` | 3-state enum, 5-kind enum w/ deep-link anchors, 4 pure mappers, D-13 combine, 6 live reads | ✓ VERIFIED | Exists, 135 lines, all functions present, 16/16 unit tests pass |
| `IsletTests/PermissionStatusTests.swift` | Full mapper + combine coverage | ✓ VERIFIED | 16 tests, all pass (ran live) |
| `Islet/Notch/OnboardingViewState.swift` | `isReplay` published flag | ✓ VERIFIED | `@Published var isReplay: Bool = false` present |
| `Islet/Notch/NotchWindowController.swift` | `replayOnboarding()`/`finishOnboardingReplay()`/`requestBluetoothPermission()` | ⚠️ VERIFIED w/ bugs | All 3 functions exist and compile; `replayOnboarding()` missing `updateVisibility()` (CR-03); `requestBluetoothPermission()` missing the activity-toggle gate every sibling start-site has (CR-01) |
| `Islet/Notch/NotchPillView.swift` | `onOnboardingCancel` closure + replay-only close button | ✓ VERIFIED | Present, gated correctly on `onboardingState.isReplay` |
| `Islet/SettingsView.swift` | `.permissions` sidebar case + `permissionsSection` + About's Replay button | ⚠️ VERIFIED w/ bugs | UI/wiring all present and builds; `handlePermissionTap` for `.location`/`.focus` doesn't reach the app's real permission-consuming code paths (CR-02/WR-01) |
| `IsletTests/SettingsViewTests.swift` | Regression coverage for `.permissions` surviving `visibleSections` | ✓ VERIFIED | 2 new tests, both pass (ran live) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `PermissionStatus.swift` live-read functions | pure mapper functions | direct call | ✓ WIRED | e.g. `locationPermissionStatus()` calls `mapCLAuthorization(...)` |
| `SettingsView.swift` `permissionsSection` | `PermissionStatus.swift` live-read functions | `refreshPermissionStatuses()` | ✓ WIRED | Called from `.onAppear` and `.onChange(of: appearsActive)` |
| `SettingsView.swift` Replay button | `NotchWindowController.replayOnboarding()` | cross-window call via `AppDelegate.notchController` | ✓ WIRED | `notchController?.replayOnboarding()` present |
| `NotchWindowController.onOnboardingFinish` | `finishOnboarding()` / `finishOnboardingReplay()` | branch on `replayPriorPhase != nil` | ✓ WIRED | Confirmed at construction site |
| `SettingsView.swift` Bluetooth "not yet asked" tap | `NotchWindowController.requestBluetoothPermission()` → `startBluetoothMonitor()` | direct call | ⚠️ WIRED but ungated | Reaches the real monitor, but bypasses the user's Devices toggle (CR-01) |
| `SettingsView.swift` Location "not yet asked" tap | `NotchWindowController.startLocationOnce()` (the app's real fetch) | — | ✗ NOT WIRED | Tap only calls a disconnected `CLLocationManager()`; no bridge method exists to reach `startLocationOnce()` (CR-02) |
| `SettingsView.swift` Focus "not yet asked" tap | `NotchWindowController.focusPermissionGranted()` | — | ✗ NOT WIRED | Grant result is discarded (`{ _ in }`); the existing bridge method is never called (WR-01) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Debug build compiles with all Phase 54 code | `xcodebuild build -scheme Islet -destination 'platform=macOS'` | `** BUILD SUCCEEDED **` | ✓ PASS |
| PermissionStatus unit tests pass | `xcodebuild test -only-testing:IsletTests/PermissionStatusTests` | 16/16 passed | ✓ PASS |
| SettingsView regression tests pass | `xcodebuild test -only-testing:IsletTests/SettingsViewTests` | 4/4 passed (2 new + 2 pre-existing) | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| ARCH-P2 | 54-01, 54-02, 54-03 | "Permissions Overview — X of Y granted" rollup row in Settings + a "Replay onboarding" button in About | ⚠️ PARTIALLY SATISFIED | The rollup UI, summary count, and Replay button all exist and are wired; the "re-request individually" half of the requirement is functionally broken for 3/5 permission kinds (CR-01/CR-02/WR-01), and the replay button itself can silently no-op when the panel is hidden (CR-03) |

**Note (informational, not a gap):** `.planning/REQUIREMENTS.md`'s "v2 Requirements" section still describes ARCH-P2 as "Deferred to a future milestone, not in this roadmap" and the Traceability table has no ARCH-P2 row. This phase clearly pulled ARCH-P2 forward and implemented it now — REQUIREMENTS.md's v2 section text/traceability table appears stale relative to actual roadmap execution. This is a documentation bookkeeping gap, not a code gap, and does not block phase completion, but should be cleaned up (move ARCH-P2 out of the "deferred" v2 list and add its traceability row).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `Islet/Notch/NotchWindowController.swift` | 748-750 | `requestBluetoothPermission()` unconditionally calls `startBluetoothMonitor()`, no toggle gate | 🛑 Blocker | User's explicit "Devices" toggle-off is silently overridden; live Bluetooth monitoring starts and stays running for the rest of the session (CR-01) |
| `Islet/SettingsView.swift` | 519-522 | Location "not yet asked" tap uses a disconnected `CLLocationManager()` instead of the app's real one-shot fetch | 🛑 Blocker | Granting Location via this row has no effect on weather data until the app is relaunched (CR-02) |
| `Islet/Notch/NotchWindowController.swift` | 1951-1965 | `replayOnboarding()` missing `updateVisibility()` present in every sibling onboarding-lifecycle method | 🛑 Blocker | Replay can be a silent no-op when the panel is currently off-screen (CR-03) |
| `Islet/SettingsView.swift` | 528-529 | Focus "not yet asked" tap discards the grant callback result (`{ _ in }`) | ⚠️ Warning | An already-toggled-on Focus activity doesn't start polling until manually re-toggled (WR-01) |
| `Islet/SettingsView.swift` | 512-535 | `refreshPermissionStatuses()` called synchronously right after async grant requests, before any of them can have resolved | ⚠️ Warning | Misleading code shape, not a functional bug — real refresh happens later via `.onChange(of: appearsActive)` (WR-02) |
| `Islet/SettingsView.swift` | 523-525 | Calendar/Reminders "not yet asked" tap uses disconnected `EKEventStore()` instances instead of the app's real `refreshCalendar()` | ⚠️ Warning | Self-heals via the 15-minute outfit-refresh timer while the panel is visible, but inconsistent with the onboarding grant path (WR-03) |

All 6 findings above were identified in `.planning/phases/54-permissions-overview-onboarding-replay-settings-rollup-showi/54-REVIEW.md` (reviewed 2026-07-22T00:00:00Z) and independently re-confirmed present in the current codebase by this verification (git log shows the latest commit, `2dde28d`, only adds the review report itself — no follow-up fix commit exists).

### Human Verification Required

None new. The phase's own on-device UAT checkpoint (54-03 Task 3) was already run and approved by the user (all 9 checklist steps). However, that UAT did not specifically exercise the two edge cases these bugs live in (tapping Bluetooth's permission row with the Devices toggle explicitly off; tapping Replay Onboarding while the panel is off-screen), so the approval does not constitute evidence these bugs are absent — it explains why they weren't caught live.

### Gaps Summary

The Permissions rollup UI (summary count, 5-row list, granted/denied/not-yet-asked tap behavior for opening System Settings and showing native prompts) and the Replay Onboarding button/carousel/state-restore mechanism all exist, compile, and are wired end-to-end — the scaffolding the roadmap goal describes is fully built and its own unit tests (20/20) pass.

However, the phase goal's specific promise — "re-request any denied/not-yet-granted permission individually" — is not fully true for 3 of the 5 rows once you trace past the tap into what actually happens in the app:

- **Bluetooth** grants bypass the user's own "Devices" toggle and leave a monitor running they explicitly turned off (CR-01).
- **Location** grants never reach the app's real one-shot fetch, so nothing changes in the running app until relaunch (CR-02).
- **Focus** grants are silently discarded, so an already-enabled Focus toggle doesn't start working until manually re-toggled (WR-01).

Separately, **Replay Onboarding** itself can be a silent no-op if the panel happens to be off-screen when tapped, because `replayOnboarding()` is missing the `updateVisibility()` call every sibling lifecycle method makes (CR-03).

These are all narrow, single-line-scale fixes (a guard clause, a bridge-method call, an unused closure parameter) — not architectural problems — and this codebase already has the exact right precedent to copy in each case (`focusPermissionGranted()`, the other `startBluetoothMonitor()` call sites, `updateVisibility()`'s own sibling calls). None of them were applied after `54-REVIEW.md` was written; the phase's last commit is the review report itself, with no fix commit following it.

---

_Verified: 2026-07-21T23:51:05Z_
_Verifier: Claude (gsd-verifier)_
