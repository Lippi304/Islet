---
phase: 04-now-playing
reviewed: 2026-06-28T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - Islet/Notch/NowPlayingPresentation.swift
  - Islet/Notch/NowPlayingState.swift
  - Islet/Notch/NowPlayingMonitor.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - IsletTests/NowPlayingPresentationTests.swift
  - project.yml
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-06-28
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 4 wires the now-playing feature through a clean four-layer flow: `NowPlayingMonitor` (the sole MediaRemoteAdapter importer) → `NowPlayingState` (@Published model) → `NotchPillView` (SwiftUI surfaces) → `NotchWindowController` (NSPanel owner + lifecycle). The architecture is disciplined: the riskiest classification logic is quarantined in a pure, total function (`nowPlayingPresentation`) with thorough unit coverage, the MediaRemote dependency is isolated to one file as CLAUDE.md mandates, and the four key invariants the brief flagged are each addressed deliberately and, in most cases, correctly.

**Verified correct against the stated invariants:**

- **Idle-CPU (EqualizerBars):** The `.animation(...)` is conditional on `isPlaying` — only `.playing` attaches `.repeatForever`; `.paused`/`.none` pass a finite `.default`. This is the right fix for the display-link-stays-alive trap. Correct.
- **Focus-safe transport:** Transport buttons use `.buttonStyle(.plain)` and only fire plain closures; the panel stays `.nonactivatingPanel` and is shown via `orderFrontRegardless()`. Commands ride the existing child's stdin via the wrapper's `commandQueue` — no re-spawn, no activation. Correct.
- **Untrusted metadata bounding (display):** Title/artist `Text` use `.lineLimit(1)` + `.truncationMode(.tail)`; SwiftUI `Text` is inert to format strings. Correct.
- **D-11 vs D-12 separation:** Health is a genuinely orthogonal `@Published` axis, never derived from a snapshot. The `.none` enum deliberately has no `.unavailable` case. Correct and well-reasoned.

The findings below are about lifecycle/concurrency edge cases and a few dead/under-used surfaces, not about the core feature being broken.

## Warnings

### WR-01: `stopListening()` mutates main-only state from a nonisolated deinit

**File:** `Islet/Notch/NowPlayingMonitor.swift:74` (calling into `MediaController.stopListening`)
**Issue:** `NowPlayingMonitor.stop()` is `nonisolated` so it can run from `NotchWindowController`'s nonisolated `deinit` (line 560). It calls `controller.stopListening()`, which mutates state (`dataBuffer`, `dataBufferSearchStart`, `listeningProcess`, `listeningInputPipe`) that the wrapper otherwise only touches inside `DispatchQueue.main.async` blocks (the `readabilityHandler` and `terminationHandler` callbacks). If `deinit` runs off the main thread, `stopListening()` races those handlers — a classic AppKit-object-deallocated-off-main hazard. The accompanying comment asserts "no concurrent access" and "thread-safe child-process termination," but `stopListening()` is not in fact a pure thread-safe operation; it does unsynchronized mutation of buffers shared with the readability handler.

In practice this is low-probability because the controller is a long-lived singleton whose `deinit` typically coincides with app teardown, and this mirrors the already-accepted `PowerSourceMonitor` pattern (where `CFRunLoopRemoveSource` genuinely *is* thread-safe — the analogy does not fully hold here, since `stopListening` is not). Flagging because the "thread-safe" justification in the comment is inaccurate and could mask a real teardown race if the controller ever becomes non-singleton.

**Fix:** Make teardown deterministic on main rather than relying on `deinit` timing. Prefer an explicit `MainActor`-isolated shutdown called from `applicationWillTerminate`, e.g.:
```swift
// In NotchWindowController, called from the app delegate's applicationWillTerminate:
@MainActor func shutdown() {
    nowPlayingMonitor?.stop()
    powerMonitor?.stop()
    mediaDismissWorkItem?.cancel()
    dismissWorkItem?.cancel()
    graceWorkItem?.cancel()
}
```
Keep the `deinit` teardown only as a best-effort backstop. At minimum, soften the comment in `NowPlayingMonitor.swift:73` so it does not claim `stopListening()` is thread-safe.

### WR-02: `runHealthCheck` timeout fires even after a successful stream emission (possible spurious "nicht verfügbar")

**File:** `Islet/Notch/NowPlayingMonitor.swift:83-95`
**Issue:** `runHealthCheck` is a self-contained probe using a `getTrackInfo` one-shot plus a 3s `asyncAfter` timeout, both resolving the local `settled` flag on main (no data race — `getTrackInfo`'s callbacks all hop to main, so `settled` is safe). The subtle bug is *semantic*: the probe is fully independent of the live `startListening` stream. If the one-shot `getTrackInfo` perl process is slow to return (cold perl spawn, system under load) but the persistent `loop` child has *already* delivered real track updates via `onTrackInfoReceived`, the 3s timeout can still fire and set `isHealthy = false`. The next live callback (`handleNowPlaying`, line 480) does restore `isHealthy = true`, so the window is self-healing — but only when something is actively streaming. With a paused/idle session that emitted once at launch and then goes quiet, a slow probe can leave the expanded view showing "Now Playing nicht verfügbar" until the next emission, despite a healthy bridge.

**Fix:** Treat any successful live stream emission as proof of health and let it cancel the probe. Simplest: have the controller mark the probe satisfied on the first `onSnapshot`, or pass the stream's liveness into the probe. For example, gate the timeout's `setHealthy(false)` so it is a no-op once a stream callback has been seen:
```swift
// Controller already sets isHealthy = true in handleNowPlaying on every emission.
// Make runHealthCheck's negative verdict conditional on "no stream callback yet":
np.runHealthCheck { [weak self] healthy in
    guard let self else { return }
    if healthy {
        self.nowPlayingState.isHealthy = true
    } else if !self.sawAnyStreamEmission {   // new flag set true in handleNowPlaying
        self.nowPlayingState.isHealthy = false
    }
}
```

### WR-03: Auto-restart at the wrapper's 100-event threshold can transiently surface as a `D-13` termination

**File:** `Islet/Notch/NowPlayingMonitor.swift:67` (the `onListenerTerminated` wiring) — root cause in the vendored `MediaController.swift:240-263, 395-407`
**Issue:** The wrapper proactively recycles the `loop` child every 100 emissions (`restartThreshold`). `restartListeningProcess()` sets `eventCount = 0` (MediaController.swift:402) synchronously, then `terminate()`s the process, which schedules the `terminationHandler` on main; that handler fires `onListenerTerminated` only when `eventCount != 0` (MediaController.swift:259). Because the reset to 0 happens before the handler runs, the guard *normally* suppresses the spurious termination — so this is not a guaranteed bug. However, `restartListeningProcess` runs inside a `DispatchQueue.main.async` block (line 235-243) and the recycle is timing-sensitive; the codebase's own D-13 handler (`handleAdapterTerminated`, NotchWindowController.swift:530) tears the glance down to idle *and* sets `isHealthy = false`. If the suppression ever loses the race (e.g. a future wrapper bump reorders this), an ordinary 100-event recycle during continuous playback would flash "no media" and then "nicht verfügbar" on the next expand. The phase code has no defense of its own against a benign restart being treated as a death.

**Fix:** Do not rely solely on the vendored wrapper's internal guard. In `handleAdapterTerminated`, debounce: defer the "unhealthy" verdict briefly and cancel it if a fresh `onSnapshot` arrives (the restarted child emits the current session within ~0.2s + spawn time). This makes a benign recycle invisible while still surfacing a true mid-session death:
```swift
private func handleAdapterTerminated() {
    // Don't immediately declare unavailable — a 100-event auto-restart looks identical.
    pendingTerminationVerdict?.cancel()
    let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        withAnimation(...) { self.nowPlayingState.presentation = .none; self.nowPlayingState.artwork = nil }
        self.nowPlayingState.isHealthy = false
    }
    pendingTerminationVerdict = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
}
// In handleNowPlaying, cancel a pending termination verdict on any live emission.
```

## Info

### IN-01: `TrackSnapshot.hasArtwork` is set and tested but never read by any consumer

**File:** `Islet/Notch/NowPlayingPresentation.swift:27`; populated at `Islet/Notch/NowPlayingMonitor.swift:64`
**Issue:** `hasArtwork` is computed (`p.artwork != nil`) and carried through the pure seam, but `nowPlayingPresentation(from:)` never references it, and the view renders the real `NSImage` directly (with its own nil → placeholder path in `artThumbnail`). The field is effectively dead state on the value type — it adds a parameter to every `TrackSnapshot` construction and test fixture for no behavioral effect.
**Fix:** Remove `hasArtwork` from `TrackSnapshot` and from the monitor/test construction sites, or document the intended future use. If kept for symmetry with a planned NOW-04 feature, add a one-line note so it does not read as an oversight.

### IN-02: `onDecodingError` from the wrapper is never wired — malformed/oversized metadata is silently dropped

**File:** `Islet/Notch/NowPlayingMonitor.swift:55-69` (only `onTrackInfoReceived` and `onListenerTerminated` are set)
**Issue:** `MediaController` exposes `onDecodingError` (MediaController.swift:27, fired on JSON decode failure). The monitor leaves it unset, so a malformed or pathologically large JSON line from the (untrusted) media source is dropped with no signal. This is not a security hole — `Text` truncation already bounds display, and JSONDecoder won't execute anything — but a repeatedly-failing decode would leave the glance frozen on stale data with no health signal, indistinguishable from "nothing changed."
**Fix:** Wire `onDecodingError` to at least a DEBUG log, and consider treating a sustained decode-failure streak as a health drop. Even a no-op-with-comment makes the deliberate choice explicit.

### IN-03: `runHealthCheck`'s 3.0s timeout is a bare magic number

**File:** `Islet/Notch/NowPlayingMonitor.swift:90`
**Issue:** The 3-second probe deadline is inlined, unlike the controller's tunables (`pausedTimeout`, `activityDuration`, `graceDelay`, spring seeds) which are all named stored properties for single-point tuning. The plan's own convention is "one place for Plan 05 to tune."
**Fix:** Promote to a named constant, e.g. `private let healthProbeTimeout: TimeInterval = 3.0`, consistent with the rest of the codebase's tuning-seed discipline.

### IN-04: `titleArtist(_:)`'s `.none` branch is unreachable dead code (acknowledged)

**File:** `Islet/Notch/NotchPillView.swift:267-272`
**Issue:** `titleArtist` is only ever called from `mediaExpanded`, which the body invokes solely for non-`.none` presentations (NotchPillView.swift:115). The `case .none: return ("", "")` branch is therefore unreachable. The comment already acknowledges this ("never rendered"), so it is defensible defensive coding for switch exhaustiveness, not a bug.
**Fix:** Acceptable as-is. If preferred, the function could take the unpacked tuple from the caller instead, but the current form is safe and self-documenting. No action required.

---

_Reviewed: 2026-06-28_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
