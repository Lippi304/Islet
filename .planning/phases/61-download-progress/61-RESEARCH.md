# Phase 61: Download-Progress - Research

**Researched:** 2026-07-23
**Domain:** macOS FSEvents file-watching + collapsed-HUD transient integration (Swift/AppKit)
**Confidence:** MEDIUM-HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Queue Placement & Persistence
- **D-01:** Download-Progress ranks **5** in `TransientQueue` (`Islet/Notch/IslandResolver.swift`) — above Caps Lock and Update-Available (which shift to rank 6/7), below OSD (rank 4). Rationale: an active download reads as real ongoing work, more urgent than a lightweight caps-lock toggle or update ping.
- **D-02:** The collapsed HUD stays visible for the **full download duration, no display-time cap** — tied to the temp file's actual presence, not a fixed timer.
- **D-03:** **Collapsed-only** — falls through unmodified when `isExpanded`, matching the Focus/OSD/Caps-Lock/Update precedent (`IslandResolver.swift:166-168`).
- **D-04:** A user's manual expand gesture **cuts the "done" splash short immediately** — matches the existing Charging/Device precedence (D-11 in Phase 3/6: user gesture always wins over a transient splash).

### Concurrent Downloads
- **D-05:** If two genuinely different files download at once (not the same file's own temp-rename sequence), the HUD shows **only the most recently started one**; the older download's own "done" state still fires independently later when it actually finishes.
- **D-06:** Tracking is **per-file** — each temp file is its own logical download, matching DL-01/DL-02's "each detected as one logical download apiece" wording (SC3).
- **D-07:** Only **~/Downloads** is watched — no per-browser custom download-folder configuration.
- **D-08:** No filtering beyond the known temp-file suffixes (`.crdownload`/`.download`/`.part`) — matching suffix alone is enough; everything else is silently ignored.

### HUD Content & Visuals
- **D-09:** In-progress label is a **generic "Downloading…" string**, not the filename — avoids truncation/overflow edge cases with long or unusual filenames.
- **D-10:** Trailing indicator is a **simple spinner icon**, not a pulsing/indeterminate bar.
- **D-11:** **No tap action** — purely informational, matching every other collapsed HUD (Charging/Device/Focus/OSD/Caps-Lock/Update).
- **D-12:** The **"done" state shows the actual final filename + a checkmark/done icon** — deliberately asymmetric with D-09: the in-progress label stays generic (temp filenames can be long/ugly), but once renamed to its final name the filename is stable and short, so it's worth surfacing there.

### Done-State Timing
- **D-13:** Done confirmation shows for **~3s**, matching the Charging/Device shared auto-dismiss-timer convention (not OSD's shorter 1.5s).
- **D-14:** If the app wasn't running at the exact moment a temp file was renamed, that missed transition is **silently skipped** — no historical FSEvents replay for this feature's scope.
- **D-15:** A cancelled/failed download (temp file deleted without ever being renamed to its final name) **silently disappears with no done state** — matches DL-02's literal wording (done fires only on rename-to-final-name).

### Claude's Discretion
- Exact spinner styling/animation timing (SwiftUI system spinner vs. a small custom one) — low-stakes, pick whatever matches the wings pattern's existing trailing-element sizing.
- Internal `DownloadActivityState`/monitor class naming and file layout — no user-facing impact.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope. Three todo matches (`2026-07-19-calendar-month-grid-polish.md`, `2026-07-19-island-briefly-disappears-during-click-through.md`, `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md`) were reviewed as keyword-only false positives and left out of scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DL-01 | When a file starts downloading into ~/Downloads (browser temp-file convention), the notch shows a live "downloading" indicator | FSEvents `kFSEventStreamCreateFlagFileEvents` create-event detection matched against D-08's temp-suffix list; rank-5 `ActiveTransient.downloadProgress` wiring in IslandResolver/TransientQueue (Architecture Patterns, Code Examples) |
| DL-02 | When the temp file is renamed to its final filename (download complete), the indicator shows a brief "done" state then clears — no exact-percentage guarantee across all browsers (presence + completion signal only) | `kFSEventStreamCreateFlagUseExtendedData` FileID correlation for the rename-pair (Pattern 1, Pitfall 2); `DownloadCoordinator` per-file side table for D-05/D-06 concurrent-download correctness (Pattern 2); D-13/D-15 timing and cancel-drop logic (isPersistent extension, Code Examples) |
</phase_requirements>

## Summary

This phase adds the codebase's first filesystem-watching subsystem: an FSEvents-based monitor on `~/Downloads` that detects a browser's temp-file lifecycle (create → rename-to-final-name) and surfaces it as a new rank-5 `ActiveTransient` in the existing `TransientQueue`/`IslandResolver` architecture proven by Phase 60 (Caps Lock/Update). The UI side is pure reuse of the `wingsShape()` pattern — no research needed there, `61-UI-SPEC.md` already fully specifies it. The two genuinely new problems are (1) correctly using `FSEventStreamCreate` to detect per-file create/rename events on a single non-recursive directory with reliable correlation between a temp file's disappearance and its final-name reappearance, and (2) extending the single-head-per-category `TransientQueue`/`ActiveTransient` model to a **multi-instance, per-file** activity where only the most-recent download is displayed but every file's own completion still fires independently later (D-05/D-06) — this has a direct precedent already in the codebase (`DeviceCoordinator`'s address-keyed side table for battery-poll identity), not a new invention.

**Primary recommendation:** Use `FSEventStreamCreate` with `kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagUseExtendedData`, scheduled via `FSEventStreamSetDispatchQueue(.main)` (no CFRunLoop), watching only `NSHomeDirectory()/Downloads`. Build a `DownloadCoordinator` (conforming to the existing `ActivityCoordinator` protocol) that keeps a path-keyed side table of in-flight temp files, mirroring `DeviceCoordinator`'s `pendingDeviceBatteryPolls` pattern, and extend `ActiveTransient`/`IslandPresentation` with a `.downloadProgress(DownloadActivity)` case at rank 5 per D-01.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Filesystem watching (`~/Downloads`) | System monitor layer (new `DownloadMonitor`, mirrors `CapsLockMonitor`/`FocusModeMonitor`) | — | Isolates the fragile system API (FSEvents/CoreServices) behind one file, per this codebase's established "one file touches the system framework" convention |
| Temp-file → logical-download correlation & per-file state | Coordinator layer (new `DownloadCoordinator`, mirrors `DeviceCoordinator`) | — | Multi-instance identity tracking (per-file, not per-category) needs the same address-keyed side-table pattern `DeviceCoordinator` already established for per-device battery polls |
| Presentation mapping (temp path → `.inProgress`/`.done`) | Pure logic layer (new `DownloadActivity.swift`, Foundation-only) | — | Matches `DeviceActivity.swift`/`CapsLockActivity.swift`'s "Pattern 1" — plain value + total function, unit-testable in milliseconds |
| Queue ranking / collapsed-only fallthrough | `IslandResolver.swift` (`TransientQueue`, `resolve(...)`) | — | Single arbiter, already reserved a comment slot for this phase (line 84) |
| HUD rendering (spinner / checkmark + label) | `NotchPillView.swift` (new `downloadWings(for:)`) | — | Zero new visual primitives per `61-UI-SPEC.md`; pure content addition to `wingsShape()` |
| Settings toggle | `Islet/ActivitySettings.swift` / `SettingsView.swift` | — | Already fully wired by Phase 59 (`downloadProgressKey`, card registered, default OFF) — this phase only reads it |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| CoreServices (FSEvents) | macOS 15.0+ (project's `MACOSX_DEPLOYMENT_TARGET`) [VERIFIED: project.pbxproj] | Native filesystem change notification API | The only Apple-native push (non-polling) API for directory content changes; matches this codebase's stated preference for event-driven monitors over polling (see `FocusModeMonitor.swift`'s own comment explaining it polls only because no push API exists for its case) |
| Foundation | project SDK | `FileManager`, `URL`, path/suffix matching | Already the sole import for every "Pattern 1" pure-logic file in this codebase |

### Supporting
None — no third-party packages needed or recommended. This is a native-platform-feature phase (ladder rung 4): FSEvents is a stable, stdlib-adjacent system framework, not something to wrap in a dependency.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `FSEventStreamCreate` (file-level events) | `DispatchSource.makeFileSystemObjectSource(fileDescriptor:eventMask:.write)` on an open FD to `~/Downloads` itself | Simpler GCD-only API (no CF callback/dispatch-queue bridging), but only reports "something in this directory changed" — no path, no event kind. Would require re-listing the directory on every fire and diffkeying files by inode to detect create-vs-rename-vs-remove yourself. Since SC3 explicitly requires distinguishing create+rename correlation per logical file, `FSEventStreamCreate`'s per-path, per-kind events (`ItemCreated`/`ItemRenamed`/`ItemRemoved`) do most of this work for free — recommended over hand-rolling the diff loop. |
| `kFSEventStreamCreateFlagUseExtendedData` FileID correlation | Manual `stat()`/inode comparison via `FileManager.attributesOfItem` before/after each event | Both approaches need *some* identity key to pair a rename-away event with its rename-to event (FSEvents fires the two halves of a single `mv` as two separate, unordered events with no built-in linkage) [CITED: FSEvents `fsevents/fsevents` GitHub issue #361, alexwlchan.net FSEvents article]. The extended-data flag (10.13+, safe given this project's 15.0 deployment target) gets the file ID as part of the event payload with zero extra syscalls — simpler than a manual `stat()` before-and-after dance. |

**Installation:** None — no package manager changes. All APIs (`CoreServices`, `Foundation`) are already implicitly available via the existing `import AppKit`/`import Foundation` used elsewhere in `Islet/Notch/`.

**Version verification:** Not applicable — no versioned package dependency, only an OS-framework API gated by `MACOSX_DEPLOYMENT_TARGET = 15.0` [VERIFIED: `Islet.xcodeproj/project.pbxproj:850`], which is far above the 10.13 minimum for `kFSEventStreamCreateFlagUseExtendedData`.

## Package Legitimacy Audit

Not applicable — this phase installs zero external packages (no `npm`/`pip`/`cargo`/SPM additions). Every API used (`CoreServices.FSEvents`, `Foundation.FileManager`) ships with the macOS SDK already linked by this project. The Package Legitimacy Gate protocol is skipped entirely; there is nothing to slopcheck.

## Architecture Patterns

### System Architecture Diagram

```
~/Downloads (filesystem)
      │  (create / rename / remove events)
      ▼
FSEventStreamCreate (kFSEventStreamCreateFlagFileEvents | UseCFTypes | UseExtendedData)
      │  scheduled on FSEventStreamSetDispatchQueue(.main)
      ▼
DownloadMonitor.swift  ─── "system glue" file, isolates the C API
      │  onEvent: (path: String, flags: FSEventStreamEventFlags, fileID: UInt64?) -> Void
      ▼
DownloadCoordinator.swift  ─── mirrors DeviceCoordinator's per-identity side table
  • matches path suffix (.crdownload / .part / .download) — D-08
  • path-keyed dict of in-flight temp downloads (create time, fileID)
  • on rename-away of a tracked temp path (with matching fileID reappearing under a
    NEW non-temp path) → correlates to the SAME logical download (D-06 "one apiece")
  • on rename-away with NO reappearance before the temp file vanished → cancelled,
    silently dropped (D-15)
      │  DownloadActivity(.inProgress) / DownloadActivity.done(filename:) — Pattern 1 pure enum
      ▼
NotchWindowController.swift
  • handleDownloadChange(_:) — enqueue/preempt into TransientQueue at rank 5 (D-01)
  • only the MOST RECENTLY STARTED download's .inProgress ever occupies the head (D-05)
      │
      ▼
IslandResolver.swift  resolve(...)  — collapsed-only branch (D-03), falls through when isExpanded
      │
      ▼
NotchPillView.swift  downloadWings(for:)  — spinner (in-progress) / checkmark+filename (done)
```

### Recommended Project Structure
```
Islet/Notch/
├── DownloadActivity.swift      # NEW — Pattern 1: pure DownloadActivity enum + total mapping fn
├── DownloadMonitor.swift       # NEW — system glue: FSEventStreamCreate wrapper, mirrors CapsLockMonitor's start()/stop()/nonisolated-deinit skeleton
├── DownloadCoordinator.swift   # NEW — mirrors DeviceCoordinator: per-file side table + ActivityCoordinator conformance
├── IslandResolver.swift        # MODIFIED — add .downloadProgress case at rank 5, shift capsLock/updateAvailable to 6/7 (D-01)
├── NotchWindowController.swift # MODIFIED — wire monitor start/stop to downloadProgressKey toggle, handleDownloadChange(_:)
└── NotchPillView.swift         # MODIFIED — add downloadWings(for:), branch in the presentation switch
```

### Pattern 1: FSEvents wrapper with extended-data FileID correlation
**What:** Wrap `FSEventStreamCreate` in a small `@MainActor` class (mirrors `CapsLockMonitor`'s shape), scheduled on the main dispatch queue (no CFRunLoop ceremony), watching only `[NSHomeDirectory() + "/Downloads"]`.
**When to use:** The one and only monitor for this phase's file-watching need.
**Example:**
```swift
// Source: synthesized from Apple's FSEvents_ProgGuide conceptual docs + fsevents/fsevents
// issue #361 (FileID correlation) — CITED, no Context7 entry exists for this C API.
import CoreServices

final class DownloadMonitor {
    private var streamRef: FSEventStreamRef?
    private let onEvent: (_ path: String, _ flags: FSEventStreamEventFlags, _ fileID: UInt64?) -> Void

    init(onEvent: @escaping (String, FSEventStreamEventFlags, UInt64?) -> Void) {
        self.onEvent = onEvent
    }

    func start() {
        guard streamRef == nil else { return }
        let downloadsPath = (NSHomeDirectory() as NSString).appendingPathComponent("Downloads")
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        let flags: FSEventStreamCreateFlags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagUseExtendedData   // 10.13+ — gives per-event FileID, needed to pair the two halves of a rename
        )
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { (streamRef, clientInfo, numEvents, eventPaths, eventFlags, eventIDs) in
                // clientInfo -> Unmanaged<DownloadMonitor>.fromOpaque(clientInfo!).takeUnretainedValue()
                // parse eventPaths (CFArray of CFDictionary when UseExtendedData is set:
                // path = dict[kFSEventStreamEventExtendedDataPathKey],
                // fileID = dict[kFSEventStreamEventExtendedFileIDKey])
            },
            &context,
            [downloadsPath] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),  // D-14: never replay history
            0.3,  // latency (seconds) — coalesces rapid events, ~2s SC1 budget leaves ample room
            flags
        ) else { return }
        FSEventStreamSetDispatchQueue(stream, .main)   // modern GCD scheduling — no CFRunLoop needed
        FSEventStreamStart(stream)
        streamRef = stream
    }

    func stop() {
        guard let stream = streamRef else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        streamRef = nil
    }
}
```
**Note:** The C callback signature above is intentionally sketched, not compiled — the exact `@convention(c)` closure-capturing boilerplate (using `Unmanaged.fromOpaque`) is fiddly in Swift and should be verified against a working sample (e.g. the alexwlchan.net article or `jgvanwyk/SwiftFileSystemEvents` on GitHub) during planning/implementation, not re-derived from scratch.

### Pattern 2: Per-file side-table coordinator (mirrors `DeviceCoordinator`)
**What:** A path/fileID-keyed dictionary tracking in-flight temp downloads, entirely separate from `TransientQueue`'s single `head`/`pending` model.
**When to use:** Whenever an activity needs N independent concurrent instances but only one is ever displayed at a time (D-05/D-06) — this is NOT a new pattern class, it is the exact shape `DeviceCoordinator.pendingDeviceBatteryPolls`/`PendingBatteryPoll` already solved for per-device battery-poll identity (`IslandResolver.swift:297-321`, `DeviceCoordinator.swift:53-73`).
**Example:**
```swift
// Mirrors PendingBatteryPoll's identity-not-FIFO-position discipline (WR-1 gap-closure).
private struct InFlightDownload {
    let tempPath: String
    let fileID: UInt64?
    let startedAt: Date
}
private var inFlightDownloads: [String: InFlightDownload] = [:]  // keyed by tempPath

// On temp-file create matching a known suffix (D-08): insert into inFlightDownloads,
// then enqueue/preempt .downloadProgress(.inProgress) as the NEW head (D-05 — replaces
// whichever download was previously showing; that older download's OWN entry in
// inFlightDownloads is untouched and will still fire its own .done later).

// On a rename-away event for a tracked tempPath: look up by fileID among any newly
// observed non-suffix path in the same batch of events to get the final filename (D-12);
// remove the entry from inFlightDownloads; if the CURRENT head is a different download,
// do NOT touch the head — just render a .done splash for the one that actually finished
// (D-05's "fires independently later" — this may need its OWN small notification path
// outside the single-head TransientQueue if a different download currently owns the head;
// see Pitfall 1 below).
```

### Anti-Patterns to Avoid
- **Treating `TransientQueue.head` as the sole source of truth for "download is happening":** it can only represent ONE thing at a time; per D-05/D-06 there can be N concurrent logical downloads. The coordinator's side table (not the queue) is the source of truth for "is file X still downloading"; the queue only reflects which ONE is currently shown.
- **Recursing FSEvents into Safari's `.download` package bundle:** `kFSEventStreamCreateFlagFileEvents` reports events for files *inside* a watched directory tree, including inside a `.download` bundle (which is itself a directory, not a flat file — see Pitfall 1). Filter to top-level `~/Downloads` entries only (path depth check against the watched root) or every internal byte-write inside Safari's bundle will re-fire the handler.
- **Re-deriving the FileID-correlation problem from scratch:** it is a documented, known FSEvents limitation (unordered rename-pair events) with a documented fix (`kFSEventStreamCreateFlagUseExtendedData`) — don't invent a custom heuristic (e.g., "any new file appearing within 500ms of a temp file vanishing") when the FileID is available for free.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Filesystem change notification | A polling loop that lists `~/Downloads` on a timer | `FSEventStreamCreate` (event-driven) | Matches this codebase's explicit event-driven-over-polling preference (see `FocusModeMonitor.swift`'s comment justifying why IT alone must poll — the exception, not the rule); polling also risks missing rapid temp-file lifecycles inside the poll interval |
| Rename-pair correlation | Manual `stat()`-before/after inode diffing across every directory listing | `kFSEventStreamCreateFlagUseExtendedData`'s built-in FileID in the event payload | Zero extra syscalls, documented Apple mechanism, avoids a custom heuristic that can misfire on a coincidental same-second create+delete of unrelated files |
| Per-file concurrent-download identity tracking | A new generic priority/queueing engine | The existing `ActivityCoordinator` protocol + a `DownloadCoordinator` mirroring `DeviceCoordinator`'s side-table shape | Direct precedent already proven and unit-tested in this exact codebase (`DeviceCoordinatorTests.swift`) — no new architectural concept needed |

**Key insight:** Every piece of this phase that looks novel (multi-instance activity tracking, identity-based correlation across async system events) already has a solved, tested precedent in this codebase's `DeviceCoordinator`/`PendingBatteryPoll` machinery from Phase 16. The only genuinely new surface is the FSEvents C API itself.

## Common Pitfalls

### Pitfall 1: Safari's `.download` is a directory bundle, not a flat file
**What goes wrong:** Code that assumes every temp download is a single flat file (as Chrome's `.crdownload` and Firefox's `.part` are) will either miss Safari downloads entirely or double-fire on every internal write inside the bundle.
**Why it happens:** Safari's `.download` file is implemented as a macOS package/bundle directory containing the in-progress data internally [CITED: Apple Support Safari download docs, community reports]. With `kFSEventStreamCreateFlagFileEvents`, FSEvents reports events for paths *inside* that bundle too (it is a real directory on disk under the watched subtree).
**How to avoid:** When matching suffixes (D-08), check the event's *top-level* path component directly under `~/Downloads` (i.e. `path.hasPrefix(downloadsPath + "/")` with exactly one more path component, or `URL(fileURLWithPath:).deletingLastPathComponent() == downloadsRoot`), not the raw event path, and ignore any event whose path is nested more than one level deep.
**Warning signs:** The HUD flickers or re-triggers repeatedly during a single Safari download; a Safari download never shows the in-progress state despite Chrome/Firefox working.

### Pitfall 2: FSEvents rename events arrive unordered and unpaired
**What goes wrong:** A single `mv tempfile finalname` produces TWO separate FSEvents callbacks (one for the old path, one for the new path), each flagged `kFSEventStreamEventFlagItemRenamed`, with **no built-in way to tell they're the same operation** [CITED: `fsevents/fsevents` GitHub issue #361].
**Why it happens:** FSEvents is a coalesced, best-effort notification API by design — it reports "this path changed" events, not atomic filesystem transactions.
**How to avoid:** Use `kFSEventStreamCreateFlagUseExtendedData` (macOS 10.13+, safe given this project's 15.0 target) to get each event's file ID (inode) and correlate the vanishing temp path with the appearing final path by matching file IDs, not by timing/ordering assumptions.
**Warning signs:** Occasional wrong final-filename shown, or the "done" splash failing to appear when two downloads finish within the same latency window.

### Pitfall 3: Latency coalescing can merge create+rename into one callback
**What goes wrong:** A very small/fast download can create AND rename its temp file within the same FSEvents latency window (commonly 0.1–1s), delivering both events in a single callback batch — code that assumes "create always arrives before rename, in a separate callback" can drop the in-progress state entirely for fast downloads.
**Why it happens:** The `latency` parameter passed to `FSEventStreamCreate` intentionally batches rapid changes to reduce event volume; it is NOT a per-event guarantee.
**How to avoid:** Process ALL events in a callback batch as a single ordered array (FSEvents does preserve within-batch order via `eventIDs`), applying create-then-rename logic sequentially rather than assuming a create must have already been separately handled.
**Warning signs:** Small/instant downloads never show the "downloading" state, jumping straight to "done" (arguably acceptable per D-02/DL-01's "couple seconds" tolerance, but should be a deliberate decision, not an accident).

### Pitfall 4: `TransientQueue`'s `isPersistent` is category-level, but Download needs sub-state-level persistence
**What goes wrong:** The existing `isPersistent` extension pattern (`if case .focus = self { return true }`) checks only the outer `ActiveTransient` case. Per D-02, the in-progress download state must NEVER self-elapse (no display-time cap) while the done state MUST self-elapse after ~3s (D-13) — these are two different persistence behaviors on the SAME `.downloadProgress` category, distinguished only by the associated `DownloadActivity` value.
**Why it happens:** No prior activity in this codebase has needed two different `isPersistent` behaviors within one category — Focus is always persistent, OSD/CapsLock/Charging/Device/Update are never persistent.
**How to avoid:** Pattern-match on the associated value, not just the case: `if case .downloadProgress(.inProgress) = self { return true }; if case .downloadProgress(.done) = self { return false }` — Swift supports this directly; no architectural change to `ActiveTransient`/`isPersistent`'s shape is needed, just a more specific match arm.
**Warning signs:** The in-progress HUD auto-dismisses after 3s even though the download is still running (violates D-02), or the "done" splash never clears (violates D-13).

### Pitfall 5: `xcodebuild test` hangs in non-interactive/sandboxed sessions
**What goes wrong:** Running the full test suite headlessly (as an agent would) hangs indefinitely.
**Why it happens:** A pre-existing, documented issue — `BluetoothMonitor`/`IOBluetoothCoreBluetoothCoordinator` waits on a Bluetooth TCC-authorization prompt that never resolves outside an interactive session [VERIFIED: `.planning/PROJECT.md:425`, `.planning/v1.0.1-MILESTONE-AUDIT.md:21`]. Unrelated to this phase's own code, but it blocks any agent-run `xcodebuild test`.
**How to avoid:** Gate automated verification on `xcodebuild build` (compiles + catches type errors) for this phase's new pure-logic files' unit tests specifically, or run only the new test target/class via `xcodebuild test -only-testing:IsletTests/DownloadActivityTests` if that scoping avoids triggering the Bluetooth monitor's boot path — otherwise route full-suite runs to a manual Cmd-U session per the project's own documented workaround.
**Warning signs:** A `run_in_background` test invocation that never completes.

## Code Examples

### DownloadActivity — Pattern 1 pure enum (mirrors CapsLockActivity.swift)
```swift
// Source: synthesized to mirror CapsLockActivity.swift's exact "Pattern 1" shape —
// plain Foundation-only value + total mapping, no system frameworks.
import Foundation

enum DownloadActivity: Equatable {
    case inProgress                  // D-09: generic label only, never the temp filename
    case done(filename: String)      // D-12: real final filename + checkmark
}
```

### isPersistent extension — sub-state-aware match (extends IslandResolver.swift:133-138)
```swift
// Extends the existing extension — download needs BOTH: in-progress never self-elapses
// (D-02, like Focus), done DOES self-elapse after ~3s (D-13, like every other transient).
extension ActiveTransient {
    var isPersistent: Bool {
        if case .focus = self { return true }
        if case .downloadProgress(.inProgress) = self { return true }
        return false
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)` | `FSEventStreamSetDispatchQueue(stream, dispatchQueue)` | Available since macOS 10.9 (Mavericks) | Avoids CFRunLoop scheduling entirely — fits this codebase's GCD-only convention (`DispatchSource.makeTimerSource`, `DispatchQueue.main.asyncAfter` used everywhere else in `Islet/Notch/`) instead of introducing the one Core-Foundation-run-loop dependency in the whole file-watching path |
| Directory-only FSEvents (no file-level detail) | `kFSEventStreamCreateFlagFileEvents` | Available since macOS 10.7 (Lion) | Required for this phase — without it, FSEvents only reports "something changed in this directory," not which file or what kind of change |
| Manual inode `stat()` diffing to pair rename events | `kFSEventStreamCreateFlagUseExtendedData` | Available since macOS 10.13 (High Sierra) | Solves the historically undocumented "two unordered rename events, no linkage" problem with a built-in FileID — safe to use given this project's 15.0 deployment target |

**Deprecated/outdated:** None of the FSEvents C API itself is deprecated; it remains Apple's only native filesystem-change-notification mechanism as of this research date. No Swift-native replacement exists (the newer `NSFilePresenter`/`NSFileCoordinator` APIs solve a different problem — coordinated document access, not passive directory watching).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Chrome/Edge use `.crdownload`, Firefox uses `.part`, Safari uses `.download` (as a package bundle) on current macOS versions | Common Pitfalls, Pattern 1 | Already locked by D-08/roadmap wording as the three suffixes to match — if a browser's convention has changed, downloads from that browser silently produce no HUD (graceful degrade, not a crash, but misses SC1 for that browser) |
| A2 | Safari's `.download` is specifically a directory/package bundle (not a flat file with that extension) | Pitfall 1 | If wrong, the "filter nested paths" mitigation is unnecessary complexity (harmless if applied anyway, since a flat file has no nested paths to filter) |
| A3 | FSEvents rename-pair events are genuinely unordered/unlinked without extended data, and `kFSEventStreamCreateFlagUseExtendedData` reliably provides a matching FileID for both halves | Pattern 1, Pitfall 2 | If the FileID correlation doesn't work as expected in practice, final filenames could show the WRONG name in the done state (cosmetic, not crash-level) — worth an early on-device spike to confirm before full implementation |
| A4 | The exact `@convention(c)` FSEventStreamCreate Swift callback boilerplate sketched in Pattern 1's code example is illustrative, not copy-paste-ready | Code Examples | If planner/executor copies it verbatim without adapting the `Unmanaged` bridging, it will not compile — flagged explicitly in the pattern's own "Note" |

## Open Questions

1. **Does D-05's "older download still fires its own done state independently later" require a notification path OUTSIDE `TransientQueue.head`?**
   - What we know: `TransientQueue` only ever shows one `.downloadProgress` at a time (the head); `DeviceCoordinator`'s battery-poll pattern shows how a coordinator can defer/queue a side-effect (the poll) independent of what currently owns the head, then apply it later via `activityPromoted()`/direct `updateHead`/`enqueue` calls.
   - What's unclear: whether the older download's `.done` splash should ENQUEUE behind whatever is currently head (goes through `TransientQueue.pending`, so it may wait) or PREEMPT/replace whatever's showing the instant it happens (matching the urgency of a real "genuinely new file-watching subsystem" completion signal).
   - Recommendation: Plan should decide explicitly — the safest default matching D-05's literal wording ("fires independently later") is a plain `enqueue`, consistent with how every other transient (Device, Focus) already queues behind Charging without preempting; reserve `preempt` only for the Focus-displacement case that already exists.

2. **What is the practical upper bound on concurrent tracked downloads (`inFlightDownloads` dict size)?**
   - What we know: `TransientQueue.maxDepth = 2` bounds the VISIBLE queue; the coordinator's side table is separate and currently unbounded in the sketch above.
   - What's unclear: whether an unbounded dict is an acceptable practical risk (a user would need dozens of simultaneous downloads for this to matter) or whether it should mirror `pendingDeviceBatteryPolls`' explicit cap.
   - Recommendation: Given D-15 (cancelled downloads silently drop their entry) and realistic Downloads-folder usage, an unbounded-but-self-cleaning dict (entries removed on both success and cancellation) is likely fine — flag for the planner to size a defensive cap only if on-device testing shows entries leaking.

## Environment Availability

Skipped — this phase's only "external dependency" is the CoreServices/FSEvents framework, which ships with every macOS installation at the project's `MACOSX_DEPLOYMENT_TARGET = 15.0` and is not independently installable/version-checkable (no `npm view`/`pip index`/`cargo search` equivalent for an OS framework). No fallback needed; FSEvents has been present on every macOS release since 10.5.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest [VERIFIED: `IsletTests/*.swift`] |
| Config file | `Islet.xcodeproj` test target (no separate config file) |
| Quick run command | `xcodebuild build -project Islet.xcodeproj -scheme Islet` (compile-check only — see Pitfall 5) |
| Full suite command | `xcodebuild test -project Islet.xcodeproj -scheme Islet` — **known to hang in non-interactive/sandboxed agent sessions** (Pitfall 5); route to manual Cmd-U per `.planning/PROJECT.md:425` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DL-01 | Temp-file creation matching a known suffix maps to `.inProgress`, non-matching files produce no activity (D-08) | unit | `xcodebuild test -only-testing:IsletTests/DownloadActivityTests` | ❌ Wave 0 |
| DL-01 | `.downloadProgress` ranks 5 in `resolve(...)` (above capsLock/updateAvailable, below osd), collapsed-only (D-01/D-03) | unit | `xcodebuild test -only-testing:IsletTests/IslandResolverTests` | ✅ (extend existing file) |
| DL-02 | Rename-to-final-name maps to `.done(filename:)`; a deleted (never-renamed) temp file produces no activity (D-15) | unit | `xcodebuild test -only-testing:IsletTests/DownloadActivityTests` | ❌ Wave 0 |
| DL-02 | Two concurrent downloads: newest replaces the shown head, older's `.done` still fires later (D-05/D-06) — coordinator-level identity logic | unit | `xcodebuild test -only-testing:IsletTests/DownloadCoordinatorTests` | ❌ Wave 0 |
| DL-01/DL-02 | Live FSEvents behavior against a real `~/Downloads` (create/rename/cancel a real file) | manual | on-device checkpoint (drop a real file, observe HUD timing) — cannot be automated (requires real filesystem + real timing, mirrors `CapsLockMonitor`'s Accessibility-gate manual verification precedent) | n/a |

### Sampling Rate
- **Per task commit:** `xcodebuild build` (compile-check; the pure-logic files' unit tests via targeted `-only-testing:` runs if the Bluetooth hang can be avoided by scoping)
- **Per wave merge:** targeted `-only-testing:IsletTests/DownloadActivityTests,IsletTests/DownloadCoordinatorTests,IsletTests/IslandResolverTests` (avoids the full-suite Bluetooth hang while still covering this phase's own new/changed pure logic)
- **Phase gate:** on-device manual verification (drop a real file into `~/Downloads`, observe collapsed HUD) is REQUIRED before `/gsd:verify-work` — FSEvents timing/correlation behavior cannot be fully proven by unit tests alone (Open Question 1's coordinator behavior, in particular, benefits from a real multi-browser on-device pass)

### Wave 0 Gaps
- [ ] `IsletTests/DownloadActivityTests.swift` — covers DL-01/DL-02's pure mapping logic (temp-suffix detection, done-state filename extraction, D-15 cancel-silently-drops)
- [ ] `IsletTests/DownloadCoordinatorTests.swift` — covers D-05/D-06 per-file identity tracking, mirrors `DeviceCoordinatorTests.swift`'s structure
- [ ] Extend `IsletTests/IslandResolverTests.swift` — add rank-5 collapsed-only assertions for `.downloadProgress`, verify capsLock/updateAvailable's rank shift to 6/7 doesn't break existing tests
- [ ] No new framework/config install needed — XCTest target already exists and covers this phase's test shape

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth surface in this phase |
| V3 Session Management | no | Not applicable |
| V4 Access Control | no | Not applicable — no privilege boundary |
| V5 Input Validation | yes | The final filename (D-12) is UNTRUSTED external input — an attacker-controlled website can name a downloaded file anything, including long/malformed/RTL-override Unicode strings. Mirrors `DeviceActivity.swift`'s existing `name` handling: render via plain `Text` with `.lineLimit(1)` + `.truncationMode(.middle)` (already specified in `61-UI-SPEC.md`), NEVER interpolate into a format string, shell command, or file-path-construction call beyond the read-only FSEvents-supplied path itself. |
| V6 Cryptography | no | Not applicable |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious/oversized/control-character filename rendered in UI | Tampering (of displayed data, not the app itself) | `.lineLimit(1)` + `.truncationMode(.middle)` (already locked in `61-UI-SPEC.md`); never pass the raw filename to any `Process`/shell/format-string API — this phase only ever displays it as `Text`, matching every existing untrusted-string precedent in this codebase (`DeviceActivity.name`, `NowPlayingPresentation` track titles) |
| Symlink/path-traversal inside `~/Downloads` (e.g. a downloaded `.download` bundle containing a symlink pointing outside the sandbox) | Tampering / Information Disclosure | This phase only WATCHES and DISPLAYS — it never opens, reads the contents of, or follows any path found. No file I/O beyond `FileManager.fileExists`/directory-listing calls confined to the FSEvents-reported paths themselves; no risk surface is introduced as long as the implementation stays read-only-metadata (no `Data(contentsOf:)` of downloaded content) |

## Sources

### Primary (HIGH confidence)
- `Islet/Notch/IslandResolver.swift`, `Islet/Notch/DeviceCoordinator.swift`, `Islet/Notch/ActivityCoordinator.swift`, `Islet/Notch/CapsLockMonitor.swift`, `Islet/Notch/CapsLockActivity.swift`, `Islet/Notch/ChargingActivityState.swift`, `Islet/Notch/FocusModeMonitor.swift`, `Islet/Notch/DeviceActivity.swift`, `Islet/Notch/NotchPillView.swift` — direct codebase read, current state
- `.planning/phases/61-download-progress/61-CONTEXT.md`, `61-UI-SPEC.md` — locked user decisions
- `Islet.xcodeproj/project.pbxproj` — deployment target verification

### Secondary (MEDIUM confidence)
- [Watching for file changes on macOS – alexwlchan.net](https://alexwlchan.net/2026/watch-files-on-macos/) — FSEvents Swift wrapping approach, `kFSEventStreamCreateFlagFileEvents` rename-pair limitation
- [FSEvents API reports Renamed events out of order · Issue #361 · fsevents/fsevents](https://github.com/fsevents/fsevents/issues/361) — `kFSEventStreamCreateFlagUseExtendedData` FileID correlation fix, confirmed by a second independent source
- [Using the File System Events API — Apple Developer (archived conceptual guide)](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/UsingtheFSEventsFramework/UsingtheFSEventsFramework.html) — official (archived) conceptual documentation
- [Download items from the web using Safari on Mac — Apple Support](https://support.apple.com/en-mide/guide/safari/sfri40598/mac) — Safari `.download` bundle behavior, cross-referenced with community reports

### Tertiary (LOW confidence)
- General web results on Chrome `.crdownload`/Firefox `.part` conventions (multiple non-official sources agreeing) — consistent with the roadmap's own wording, not independently verified against current browser source

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no packages to verify; FSEvents API surface confirmed via multiple independent sources and matches training knowledge
- Architecture: HIGH — directly mirrors two proven, tested, already-shipped patterns in this exact codebase (`DeviceCoordinator`, `CapsLockMonitor`)
- Pitfalls: MEDIUM — FSEvents rename-correlation and Safari bundle behavior are well-documented externally but not verifiable against this specific codebase (no prior FSEvents code exists to cross-check against); recommend an early on-device spike before full implementation to confirm the FileID-correlation approach works as expected

**Research date:** 2026-07-23
**Valid until:** 30 days (stable OS API surface; browser temp-file conventions could shift on a browser update, but the D-08 suffix list is user-locked regardless)
