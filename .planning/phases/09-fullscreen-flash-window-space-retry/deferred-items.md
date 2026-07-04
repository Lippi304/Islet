# Phase 9 — Deferred Items (out of scope for 09-01)

## `xcodebuild test` hangs in this worktree-agent sandbox (pre-existing, unrelated to 09-01)

**Discovered during:** 09-01 Task 2 verification (`xcodebuild test -scheme Islet
-only-testing:IsletTests/NotchPanelTests -only-testing:IsletTests/VisibilityDecisionTests
-only-testing:IsletTests/FullscreenDetectorTests`).

**Symptom:** The test run hangs indefinitely (XCTest eventually reports "Testing failed: Islet
encountered an error (The test runner hung before establishing connection.)" after ~5-6
minutes). The host app process (`Islet.app`, launched as the `IsletTests` bundle loader) shows
0% CPU for the entire hang.

**Root cause (confirmed via `sample`):** The main thread is stuck in
`AppDelegate.applicationDidFinishLaunching` -> `NotchWindowController.start()` ->
`startBluetoothMonitor()` -> `BluetoothMonitor.start()` -> `+[IOBluetoothDevice
registerForConnectNotifications:selector:]` -> `+[IOBluetoothCoreBluetoothCoordinator
sharedInstance]` -> blocked forever on `semaphore_wait_trap`. This looks like a Bluetooth
TCC-authorization wait that never resolves in this non-interactive, sandboxed worktree-agent
session (no GUI session available to answer a permission prompt for this freshly-signed
ad-hoc build's derived-data bundle identity).

**Confirmed NOT caused by 09-01's changes:** Reproduced the identical hang (same stack trace,
same `startBluetoothMonitor()` -> `semaphore_wait_trap` call chain) after temporarily reverting
`NotchWindowController.swift` to its pre-Task-2 state (i.e. with the `CGSSpace`
membership/wiring completely absent). The hang is 100% pre-existing `BluetoothMonitor`/IOKit
code from Phase 6 (DEV-01), unrelated to Phase 9's CGSSpace work, and out of this plan's scope
per the Scope Boundary rule (only auto-fix issues directly caused by the current task's
changes).

**Impact on 09-01:** Task 2's acceptance criterion `xcodebuild test -scheme Islet
-only-testing:IsletTests/NotchPanelTests -only-testing:IsletTests/VisibilityDecisionTests
-only-testing:IsletTests/FullscreenDetectorTests passes with zero failures` could not be
automatically verified in this worktree-agent environment. `xcodebuild build -scheme Islet`
succeeds with zero errors (verified), and all static/grep-based acceptance criteria (symbol
counts, call-site placement, `NotchPanel.swift` untouched) are verified. The actual test suite
content is unchanged by 09-01 (no test files were modified), so there is no code-level reason
to expect a regression in these specific tests — the only way to prove it definitively is to
run the suite in an environment where the Bluetooth TCC prompt/permission is already granted
(e.g. the user's own interactive Mac session, as prior phases' "141/141 tests green" claims
were presumably run there, not from an isolated worktree agent).

**Recommended follow-up:** Not a 09-01 blocker — flag for `/gsd:verify-work 9` or a future
housekeeping task: consider gating `BluetoothMonitor.start()` behind a
`ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil` check (the standard
"are we running under XCTest" guard) so `xcodebuild test` never spins up the live IOBluetooth
monitor at all. This would make `xcodebuild test` runnable from any sandboxed/headless
environment, not just an interactive Mac session with Bluetooth permission already granted.
