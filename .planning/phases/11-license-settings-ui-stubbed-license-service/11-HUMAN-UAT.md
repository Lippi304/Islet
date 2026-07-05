---
status: partial
phase: 11-license-settings-ui-stubbed-license-service
source: [11-VERIFICATION.md]
started: 2026-07-05T14:53:00Z
updated: 2026-07-05T14:53:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Run the test suite (Cmd-U)
expected: The 4 `IsletTests/LicenseServiceTests` pass — magic key `ISLET-DEMO-OK` → `.success` on the main thread, `"NOPE-1234"` → `.failure(.invalidKey)`, whitespace-padded magic key → `.success` (trimming), and the completion is asynchronous (a flag is still false immediately after `activate` returns).
result: [pending]
note: `xcodebuild test` hangs headlessly because the test bundle is hosted in the full Islet.app (boots the notch NSPanel/MediaRemote/IOBluetooth on launch). Run interactively in Xcode: open `Islet.xcodeproj`, select the `Islet` scheme, press Cmd-U (or run only `LicenseServiceTests`). Pre-existing repo constraint, not a Phase 11 defect.

### 2. Live unlock (magic-key activation)
expected: In an expired/trial state, open Settings → paste `ISLET-DEMO-OK` → click Activate → `⟳ Validating…` shows for ~1s → the section flips to `Licensed ✓` and the locked island re-appears WITHOUT an app restart (no abrupt yank).
result: [pending]

### 3. Buy Now browser handoff (D-07)
expected: Clicking "Buy Islet — €7.99" opens the default browser at `https://getislet.app`.
result: [pending]

### 4. Adaptive layout across the three states (D-01)
expected: `.trial` and `.trialExpired` show the days-line / expired heading + Buy Now + license field; `.licensed` shows `Licensed ✓` only (Buy Now + field hidden). Drive via the DEBUG `forceExpired` / `forceLicensed` flips + the magic key.
result: [pending]

### 5. No persistence across relaunch (T-11-02 / Pitfall 1)
expected: Activate with the magic key, quit + relaunch → the app is back in trial/expired (island locked); entitlement did not survive the relaunch.
result: [pending]

### 6. Menu-bar → Settings one-click (SC#4 — Phase 10 regression check)
expected: Clicking the menu-bar item's "Settings…" opens the Settings window in one action (no Phase 10 regression).
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps
