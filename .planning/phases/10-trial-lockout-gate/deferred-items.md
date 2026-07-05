# Phase 10 — Deferred Items (out of scope for 10-01)

## `xcodebuild test -scheme Islet` (full suite) hangs in this worktree-agent sandbox (pre-existing, unrelated to 10-01)

**Discovered during:** 10-01 final verification step (plan-level `<verification>`: "Full suite:
`xcodebuild test -scheme Islet`").

**Symptom / root cause:** Identical to the pre-existing issue already documented in
`.planning/phases/09-fullscreen-flash-window-space-retry/deferred-items.md` — the full test
target launches the host app (`AppDelegate.applicationDidFinishLaunching` ->
`NotchWindowController.start()` -> `BluetoothMonitor.start()` ->
`IOBluetoothDevice.registerForConnectNotifications` -> `IOBluetoothCoreBluetoothCoordinator
sharedInstance`), which blocks forever on a Bluetooth TCC-authorization wait in this
non-interactive, sandboxed worktree-agent session. Confirmed pre-existing (Phase 6 DEV-01
code), unrelated to any Phase 10 change — 10-01 adds only new files under `Islet/Licensing/`
that are never referenced from `BluetoothMonitor`.

**Impact on 10-01:** Could not run the plan-level full-suite verification in this environment.
All per-task automated verifications DID run successfully and are the actual gating checks per
each task's own `<verify>` block:
- `xcodebuild test -scheme Islet -only-testing:IsletTests/TrialLogicTests` — 5/5 passed
- `xcodebuild test -scheme Islet -only-testing:IsletTests/TrialManagerTests` — 6/6 passed
- `xcodebuild build -scheme Islet` (Debug) — succeeded
- `xcodebuild build -scheme Islet -configuration Release` — succeeded

No test files were modified or added outside `TrialLogicTests.swift`/`TrialManagerTests.swift`
(both new, both green), so there is no code-level reason to expect a regression in the
pre-existing 141 tests. Recommended follow-up remains the same as Phase 9's: gate
`BluetoothMonitor.start()` behind an `XCTestConfigurationFilePath == nil` guard so
`xcodebuild test` is runnable headlessly.
