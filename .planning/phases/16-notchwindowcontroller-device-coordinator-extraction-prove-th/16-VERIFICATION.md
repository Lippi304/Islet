---
phase: 16-notchwindowcontroller-device-coordinator-extraction-prove-th
verified: 2026-07-08T21:35:00Z
status: passed
score: 9/9 must-haves verified
overrides_applied: 0
---

# Phase 16: NotchWindowController Device Coordinator Extraction Verification Report

**Phase Goal:** Extract the 9-field device-splash bookkeeping (deviceLastShown, deviceSuppressedAtLaunch,
deviceDebounce, connectedDeviceAddresses, bluetoothStartedAt, deviceLaunchGrace, deviceBatteryWork,
pollingAddress, pendingDeviceBatteryPolls) plus handleDevice, scheduleDeviceBatteryRefresh, and
triggerDeviceBatteryRefreshIfPromoted out of NotchWindowController into an independently-testable
DeviceCoordinator behind a narrow ActivityCoordinator protocol (D-02), with zero product behavior
change proven both by unit tests and by a mandatory on-device Bluetooth verification checklist (D-03),
while BluetoothMonitor's own lifecycle stays untouched and directly owned by NotchWindowController (D-01).

**Verified:** 2026-07-08T21:35:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `ActivityCoordinator` protocol exists with exactly two requirements, no speculative methods | VERIFIED | `Islet/Notch/ActivityCoordinator.swift:18-28` — `@MainActor protocol ActivityCoordinator { associatedtype Reading; func handle(_ reading: Reading); func activityPromoted() }`. Grep confirms `grep -c "func handle\|func activityPromoted"` = 2, `grep -c "reset()\|cancelPendingWork()\|started(at"` = 0. |
| 2 | `DeviceCoordinator` reproduces handleDevice/scheduleDeviceBatteryRefresh/triggerDeviceBatteryRefreshIfPromoted verbatim, calling the existing pure seams (not reimplementing them) | VERIFIED | `Islet/Notch/DeviceCoordinator.swift:148-261` — `handle(_:now:)` calls `shouldShowDeviceSplash(...)` (line 182) and `deviceActivity(from:)` (line 191); `activityPromoted()` calls `matchPendingBatteryPoll(...)` (line 223); `scheduleDeviceBatteryRefresh` reproduces the retry/poll logic verbatim with closures replacing direct controller field access. |
| 3 | `DeviceCoordinator`'s `deviceBatteryWork`/`pollingAddress` are `nonisolated(unsafe)` with a `nonisolated cancelPendingWork()` the controller's nonisolated deinit calls synchronously | VERIFIED | `DeviceCoordinator.swift:51,61` (`private nonisolated(unsafe) var deviceBatteryWork`/`pollingAddress`), `:121` (`nonisolated func cancelPendingWork()`). `NotchWindowController.swift:1065` calls `deviceCoordinator?.cancelPendingWork()` from within `deinit` (line 1042), immediately after `bluetoothMonitor?.stop()` at line 1064. |
| 4 | `NotchWindowController` no longer declares any of the 9 device-splash fields or the 3 extracted methods | VERIFIED | `grep` for all 9 field names + `deviceDebounce` + the 3 method signatures against `NotchWindowController.swift` returns zero matches (only 2 unrelated comment-only mentions of old method names remain, in `ActivityCoordinator.swift`'s own header and `IslandResolver.swift`'s pre-existing gap-closure comment, neither a live call site). |
| 5 | `BluetoothMonitor`'s own lifecycle (construction, start/stop, deinit teardown) is UNCHANGED and still owned directly by `NotchWindowController` (D-01) | VERIFIED | `NotchWindowController.swift:105` (`private var bluetoothMonitor: BluetoothMonitor?`), `:388-396` (`startBluetoothMonitor()` constructs/starts it directly), `:860` (`bluetoothMonitor?.stop(); bluetoothMonitor = nil` in settings-toggle-off), `:1064` (`bluetoothMonitor?.stop()` in deinit) — none of these call sites were altered to route through `DeviceCoordinator`; only the `onReading` closure body changed from `self?.handleDevice(reading)` to `self?.deviceCoordinator.handle(reading)` (a one-line forward, not a lifecycle change). |
| 6 | Every one of the 6 rewired call sites preserves identical ordering/behavior, including flushTransients(.device)'s unconditional pending-poll clear (Pitfall 12) and handleSettingsChanged's deviceLastShown-only reset asymmetry | VERIFIED | All 6 call sites confirmed by direct read: construction (`start()`:247-254), `onReading` forward (:393), `scheduleActivityDismiss` (:804), `handleSettingsChanged` devices-off (:861, `deviceCoordinator.reset()` only, alongside unchanged charging/nowPlaying blocks), `flushTransients(.device)` (:916 `clearPendingBatteryPolls()` BEFORE the `oldHead` guard at :918 — ordering preserved), `deinit` (:1065). `DeviceCoordinator.reset()` (its own file, line 108-110) clears only `deviceLastShown`, matching the documented asymmetry. |
| 7 | A real Bluetooth device exercises all four D-03 scenarios on-device and all four pass, recorded in 16-HUMAN-UAT.md | VERIFIED | `16-HUMAN-UAT.md` frontmatter `status: complete`; all 4 `### N.` entries (reconnect-flap debounce, launch-grace suppression, genuine disconnect edge, battery-poll promotion) each show `result: pass`; Summary block shows `total: 4, passed: 4, issues: 0, pending: 0`. |
| 8 | The existing ~20-file IsletTests suite plus the new DeviceCoordinatorTests all stay green | VERIFIED (build) / recorded (Cmd-U) | `xcodebuild build-for-testing -scheme Islet -configuration Debug` succeeds in this session (re-run independently, not trusting SUMMARY). Actual Cmd-U pass result is recorded in 16-02-SUMMARY.md's Task 3 checkpoint (human-approved, `11cc84e` commit) — Xcode test execution itself cannot be run headlessly in this environment per documented project memory (`xcodebuild test` hangs booting the full app stack), so this is the accepted verification method for this codebase. |
| 9 | DeviceCoordinatorTests.swift provides 9+ tests covering Pitfalls 1-8 | VERIFIED | `grep -c "func test" IsletTests/DeviceCoordinatorTests.swift` = 9 (one per pitfall 1-5, 6 split into connect/disconnect halves, 7, 8). File is 273 lines (exceeds `min_lines: 90`). |

**Score:** 9/9 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/ActivityCoordinator.swift` | narrow @MainActor protocol, 2 requirements | VERIFIED | Exists, exactly 2 methods, compiles clean. |
| `Islet/Notch/DeviceCoordinator.swift` | extracted 9-field bookkeeping + 3 methods, conforms to ActivityCoordinator, min 130 lines | VERIFIED | 262 lines, `DeviceCoordinator: ActivityCoordinator` confirmed, calls pure seams verbatim. |
| `IsletTests/DeviceCoordinatorTests.swift` | unit coverage for Pitfalls 1-8, min 90 lines | VERIFIED | 273 lines, 9 test methods, no fakes/mocking framework (recording closures + real `TransientQueue` where appropriate). |
| `Islet/Notch/NotchWindowController.swift` | controller wired to `deviceCoordinator: DeviceCoordinator` | VERIFIED | `private var deviceCoordinator: DeviceCoordinator!` (IUO, deviated from plan's `lazy var` for a documented, correct reason — see Deviations below), all 9 old fields/3 methods deleted, 6 call sites rewired. |
| `.../16-HUMAN-UAT.md` | D-03 checklist + recorded pass/fail results | VERIFIED | `status: complete`, 4/4 scenarios `result: pass`. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `DeviceCoordinator.swift` | `DeviceActivity.swift` | calls `shouldShowDeviceSplash(...)`/`deviceActivity(from:)` verbatim | WIRED | Lines 182, 191 — confirmed calls, no reimplementation. |
| `DeviceCoordinator.swift` | `IslandResolver.swift` | `activityPromoted()` calls `matchPendingBatteryPoll(_:promoted:)` by identity | WIRED | Line 223, matches `IslandResolverTests`'s identity-not-FIFO precedent (test 8 in `DeviceCoordinatorTests.swift` mirrors this exactly). |
| `DeviceCoordinator.swift` | `ActivityCoordinator.swift` | `DeviceCoordinator: ActivityCoordinator` with `typealias Reading = DeviceReading` | WIRED | Line 19-20. |
| `NotchWindowController.swift` | `DeviceCoordinator.swift` | `BluetoothMonitor`'s onReading closure forwards to `deviceCoordinator.handle(reading)` | WIRED | Line 393 — one-line forward, no private `handleDevice` remains. |
| `NotchWindowController.swift` | `DeviceCoordinator.swift` | `deinit` calls `deviceCoordinator.cancelPendingWork()` alongside unchanged `bluetoothMonitor?.stop()` | WIRED | Lines 1064-1065, adjacent as required. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full project compiles with the extraction wired in | `xcodebuild build -scheme Islet -configuration Debug` | `** BUILD SUCCEEDED **` | PASS |
| Test target (incl. DeviceCoordinatorTests) compiles | `xcodebuild build-for-testing -scheme Islet -configuration Debug` | `** TEST BUILD SUCCEEDED **` | PASS |
| No stray old-API call sites remain anywhere in the Swift sources | `grep -rn "handleDevice(\|triggerDeviceBatteryRefreshIfPromoted(\|scheduleDeviceBatteryRefresh(" --include="*.swift" .` (excluding DeviceCoordinator.swift's own definitions) | Only 2 comment-only historical mentions (ActivityCoordinator.swift header, IslandResolver.swift pre-existing gap-closure note) — zero live call sites | PASS |

Note: `xcodebuild test` was not run in this verification session (project memory: it hangs headlessly, booting the full NSPanel/MediaRemote/IOBluetooth stack). The actual Cmd-U pass and the 4 on-device Bluetooth scenarios were performed by the human during the Plan 16-02 Task 3 checkpoint — these are treated as verified via the recorded `16-HUMAN-UAT.md` results (status: complete, 4/4 pass), which is the accepted evidence path for on-device/GUI-dependent checks in this codebase (not a SUMMARY.md claim — it's a separate, dated, per-scenario artifact the human filled in during the checkpoint gate itself).

### Requirements Coverage

| Requirement | Source | Description | Status | Evidence |
|-------------|--------|-------------|--------|----------|
| D-01 | 16-CONTEXT.md | BluetoothMonitor lifecycle stays on NotchWindowController, untouched | SATISFIED | Truth #5 above. |
| D-02 | 16-CONTEXT.md | Narrow ActivityCoordinator protocol, no speculative methods for future coordinators | SATISFIED | Truth #1, #2 above. |
| D-03 | 16-CONTEXT.md | Mandatory on-device Bluetooth verification, not just unit tests | SATISFIED | Truth #7 above. |

**Note on requirement ID sourcing:** This project has no `.planning/REQUIREMENTS.md` file at all (confirmed absent project-wide, not just for this phase) — the project does not use a formal requirements registry. D-01/D-02/D-03 are locked decisions recorded in `16-CONTEXT.md`, which is this project's established convention for phase-scoped decisions without a product requirement doc (16-CONTEXT.md itself states: "No external specs/ADRs apply — this is an internal refactor with no product requirement doc"). This is consistent with the project's pattern, not a gap — no orphaned requirements exist because no requirements registry exists to orphan against.

### Anti-Patterns Found

None. Scanned all 4 modified/created files (`ActivityCoordinator.swift`, `DeviceCoordinator.swift`, `DeviceCoordinatorTests.swift`, `NotchWindowController.swift`) for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER|coming soon|not yet implemented`: zero matches in the phase's new/touched code. One incidental match of the word "placeholder" exists in `NotchWindowController.swift:970`, but it is pre-existing Now Playing artwork-fallback prose unrelated to this phase's scope (not touched by this phase's diff, not a debt marker).

Two WARNING-level findings exist in `16-REVIEW.md` (advisory, not blocking per the review's own `status: issues_found` with 0 critical):
- **WR-1** (`16-REVIEW.md`): `activityPromoted()`'s stale-poll guard checks shape (`.device(.connected)`) not identity — currently benign given `TransientQueue.maxDepth == 2` matching `DeviceCoordinator`'s own `> 2` cap, but undefended against future independent cap changes.
- **WR-2** (`16-REVIEW.md`): `deviceSuppressedAtLaunch` is a dead parameter (always empty `Set`, documented as a deferred A2 carry-over) — inert code path, not a functional gap for this phase's zero-behavior-change contract (behavior identical to pre-extraction, which also never populated it).

Both are pre-existing conditions carried through the extraction verbatim (not introduced by it), correctly scoped as advisory by the phase's own code review, and do not block the phase's goal (zero-behavior-change extraction + on-device proof) — no override needed since they are not must-have failures, just quality notes.

### Human Verification Required

None outstanding. D-03's on-device checklist (the phase's designated human-verification gate) was already executed and recorded complete in `16-HUMAN-UAT.md` with all 4 scenarios `pass`, and the Cmd-U regression pass was recorded as part of the same approved checkpoint (16-02-SUMMARY.md Task 3, commit `11cc84e`).

### Gaps Summary

None. All observable truths verified against the actual codebase (not SUMMARY.md claims): both new files exist and are substantive, the controller is fully rewired with all 6 call sites in the exact preserved order, BluetoothMonitor's lifecycle is untouched, the build and test-build both succeed independently of any prior claim, and the D-03 on-device checklist is recorded complete with 4/4 pass. No REQUIREMENTS.md exists project-wide, so the informal D-01/D-02/D-03 sourcing from 16-CONTEXT.md is consistent with this project's convention, not a coverage gap.

---

_Verified: 2026-07-08T21:35:00Z_
_Verifier: Claude (gsd-verifier)_
