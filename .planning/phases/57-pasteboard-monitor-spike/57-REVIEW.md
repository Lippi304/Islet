---
phase: 57-pasteboard-monitor-spike
reviewed: 2026-07-22T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - Islet/Clipboard/ClipboardMonitor.swift
  - IsletTests/ClipboardMonitorTests.swift
  - IsletTests/ClipboardMonitorManualSpike.swift
  - Islet/AppDelegate.swift
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 57: Code Review Report

**Reviewed:** 2026-07-22T00:00:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the new `ClipboardMonitor` polling spike, its unit tests, its manual on-device spike, and the DEBUG-only integration hooks added to `AppDelegate`. The three pure top-level functions (`isConcealedOrTransient`, `isSelfCaptureMarker`, `classifyPasteboardContent`) are correctly implemented and covered by tests; the polling/gating logic in `poll()` is sound (cheap `changeCount` gate first, concealed/transient/self-capture filtering before any content read, text-over-image tie-break). No injection, unsafe deserialization, or crash-causing null-handling bugs were found.

The concerns found are all about lifecycle/robustness rather than the core polling logic: the class's own documented "owner calls `stop()` on teardown" contract is never actually honored by its only current caller (`AppDelegate`'s DEBUG spike hook), which combined with the `nonisolated(unsafe)` mutable state makes the eventual real wiring (Phase 58) a place future bugs are likely to land if the same gap is copy-pasted forward. Test hygiene has one minor resource-leak issue (named pasteboards never released).

## Warnings

### WR-01: `ClipboardMonitor.stop()` contract is documented but never fulfilled by its owner

**File:** `Islet/Clipboard/ClipboardMonitor.swift:80-89`, `Islet/AppDelegate.swift:313-323`
**Issue:** The class comments explicitly state the ownership contract: *"deinit can't be @MainActor in Swift 5 mode, so it does NOT call stop() here. The owner (AppDelegate) calls stop() explicitly on teardown."* No call site for `.stop()` exists anywhere in the reviewed files (confirmed via `grep -rn "ClipboardMonitor" .` and `grep -n "stop()" AppDelegate.swift`). `debugSpikeStartClipboardMonitor()` creates and starts `debugClipboardMonitor` but there is no corresponding "Stop Clipboard Monitor" debug menu action, and `AppDelegate` never implements `applicationWillTerminate(_:)` or any other teardown hook that calls `.stop()`. Once started via the debug menu, the 500ms repeating timer runs for the remainder of the process's life with no way to disable it short of quitting the app. This is only latent for now (DEBUG-only, process death cleans up GCD timers anyway), but if Phase 58 copies this same "spike then wire up later" pattern forward without adding the missing teardown call, the documented invariant will still be false.
**Fix:** Either add a paired "Stop Clipboard Monitor" debug action that calls `debugClipboardMonitor?.stop(); debugClipboardMonitor = nil`, or wire `stop()` into an actual teardown path (e.g. `applicationWillTerminate`) so the comment's claimed contract is actually true somewhere in the codebase before Phase 58 builds on top of it.

### WR-02: `nonisolated(unsafe) timer`/`running` allows a genuine cross-context data race once `stop()` is actually wired to teardown

**File:** `Islet/Clipboard/ClipboardMonitor.swift:20-23, 36-46, 80-84`
**Issue:** `timer` and `running` are marked `nonisolated(unsafe)` specifically so `stop()` (declared `nonisolated`) can mutate them from outside the `@MainActor` context — per the comment, so an owner's *nonisolated* `deinit` can call it. `start()` is `@MainActor`-isolated and mutates the same two properties. `nonisolated(unsafe)` opts out of the compiler's actor-isolation checking entirely, so if `stop()` is ever invoked from a background thread (which a nonisolated `deinit` can run on, depending on which thread drops the last reference) concurrently with `start()`/`poll()` running on the main thread, `timer`/`running` are read/written without synchronization — a real data race, not just a theoretical one. This mirrors an existing pattern (`FocusModeMonitor`), so it isn't a new anti-pattern introduced by this phase, but it is currently dormant only because `stop()` is never called at all (see WR-01). The moment real teardown wiring is added, this race becomes reachable.
**Fix:** No action strictly required for this spike phase, but when Phase 58 wires `stop()` into real teardown, ensure the call happens on the main thread/actor (e.g. `MainActor.assumeIsolated { monitor.stop() }` or dispatch to `.main`) rather than relying on an arbitrary deinit thread.

### WR-03: Manual spike test has no build-time guard against accidental inclusion in `xcodebuild test` runs

**File:** `IsletTests/ClipboardMonitorManualSpike.swift:1-8`
**Issue:** The file's own top comment states this test must never run via `xcodebuild test` ("the full Islet.app test host hangs headless") and must only be run manually via Xcode Cmd-U for this single method. The only enforcement mechanism is the comment itself — the test class lives in the default `IsletTests` target alongside `ClipboardMonitorTests.swift`, so any CI job or `xcodebuild test` invocation targeting the whole test bundle will execute `testManualPollingAndClassification()`, which blocks the run loop for 45 real seconds waiting for manual interaction that will never come in a headless CI context. This matches an existing codebase precedent (`AudioOutputMonitorManualSpike`), so it's not a new problem, but it remains a real fragility: nothing technical stops a future `xcodebuild test` CI run from stalling 45+ seconds per manual-spike file.
**Fix:** Out of scope to fix here since it mirrors established convention, but worth tracking: consider excluding manual-spike files from the default test scheme/plan, or guarding the body with an environment-variable check (e.g. skip via `XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil)`) so automated runs no-op instead of blocking.

## Info

### IN-01: `ClipboardMonitorTests.freshPasteboard()` leaks named pasteboards

**File:** `IsletTests/ClipboardMonitorTests.swift:13-15`
**Issue:** Each test calls `NSPasteboard(name: NSPasteboard.Name("ClipboardMonitorTests-\(UUID())"))` to get an isolated pasteboard, which is the right idea (never pollute `NSPasteboard.general`). However, named pasteboards registered this way persist in the system pasteboard server until `releaseGlobally()` is called (or logout) — none of the 8 tests that create one ever release it. Every test run permanently registers new named pasteboards with the OS pasteboard server that are never cleaned up.
**Fix:** Track the created pasteboard and release it, e.g. wrap in `defer { pasteboard.releaseGlobally() }` in each test, or add a shared `tearDown()` that releases the last-created instance.

### IN-02: DEBUG spike hooks destructively overwrite the real system clipboard with placeholder secrets, with no restore

**File:** `Islet/AppDelegate.swift:325-341`
**Issue:** `debugSpikeWriteConcealedTestItem()` and `debugSpikeSimulateSelfCaptureWrite()` call `NSPasteboard.general.clearContents()` / `writeObjects(...)` unconditionally, permanently destroying whatever the developer actually had copied, with no save/restore of prior pasteboard contents. This is acceptable for a `#if DEBUG`-gated manual dev tool but is worth a comment noting the destructive side effect, since a developer running the spike menu mid-session will silently lose their actual clipboard contents.
**Fix:** Non-blocking; consider a one-line comment noting the destructive overwrite, or optionally save/restore the previous pasteboard item before/after the spike write if this tooling is kept around past Phase 57.

---

_Reviewed: 2026-07-22T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
