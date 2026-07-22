---
phase: 57-pasteboard-monitor-spike
fixed_at: 2026-07-23T00:00:00Z
review_path: .planning/phases/57-pasteboard-monitor-spike/57-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 1
skipped: 2
status: partial
---

# Phase 57: Code Review Fix Report

**Fixed at:** 2026-07-23T00:00:00Z
**Source review:** .planning/phases/57-pasteboard-monitor-spike/57-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3 (WR-01, WR-02, WR-03 — `fix_scope: critical_warning`; IN-01/IN-02 excluded, see below)
- Fixed: 1
- Skipped: 2

## Fixed Issues

### WR-01: `ClipboardMonitor.stop()` contract is documented but never fulfilled by its owner

**Files modified:** `Islet/AppDelegate.swift`
**Commit:** ee877a0
**Applied fix:** Added a paired `debugSpikeStopClipboardMonitor()` `@objc` action and a "Spike: Stop Clipboard Monitor" debug menu item next to the existing "Spike: Start Clipboard Monitor" entry. The new action calls `monitor.stop()` then sets `debugClipboardMonitor = nil`, giving the class's documented "owner calls `stop()` on teardown" contract an actual call site in `AppDelegate` (its only current owner) before Phase 58 builds real wiring on top of it.

## Skipped Issues

### WR-02: `nonisolated(unsafe) timer`/`running` allows a genuine cross-context data race once `stop()` is actually wired to teardown

**File:** `Islet/Clipboard/ClipboardMonitor.swift:20-23, 36-46, 80-84`
**Reason:** Reviewer's own Fix text states "No action strictly required for this spike phase" — the guidance is for Phase 58 (ensure `stop()` calls from teardown happen on the main thread/actor when real wiring is added), not a change to make in this spike's current code. Applying the suggested `MainActor.assumeIsolated`/dispatch wrapping now would require picking a specific future teardown call site that doesn't exist yet (WR-01's fix keeps `stop()` invoked from the `@MainActor`-isolated debug action, so this race remains dormant as the reviewer notes). Left for Phase 58 to address when it wires the real teardown path.
**Original issue:** `timer`/`running` are `nonisolated(unsafe)` so `stop()` can be called from a nonisolated `deinit`; if `stop()` is ever invoked from a background thread concurrently with `start()`/`poll()` on the main thread, both fields are read/written without synchronization. Currently dormant because `stop()` was never called at all — this fix's new call site (`debugSpikeStopClipboardMonitor`) is itself `@MainActor`-isolated, so the race is still not reachable through this codebase's current call sites.

### WR-03: Manual spike test has no build-time guard against accidental inclusion in `xcodebuild test` runs

**File:** `IsletTests/ClipboardMonitorManualSpike.swift:1-8`
**Reason:** Reviewer's own Fix text states "Out of scope to fix here since it mirrors established convention" (matches existing `AudioOutputMonitorManualSpike` precedent) — explicitly marked as tracking-only, not an in-scope fix for this phase.
**Original issue:** The manual-spike test's only protection against running in headless CI is a top-of-file comment; nothing technically stops `xcodebuild test` from executing `testManualPollingAndClassification()` and blocking 45 seconds waiting for manual interaction.

### IN-01, IN-02: excluded by fix scope

**Reason:** `fix_scope` for this run is `critical_warning`; Info-tier findings (`IN-01` named-pasteboard leak in tests, `IN-02` destructive clipboard overwrite in debug spike hooks) are out of scope and were not attempted. Re-run with `--all` to include them.

---

_Fixed: 2026-07-23T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
