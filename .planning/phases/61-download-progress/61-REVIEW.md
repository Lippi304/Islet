---
phase: 61-download-progress
reviewed: 2026-07-24T02:58:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - Islet/Notch/DownloadActivity.swift
  - Islet/Notch/DownloadCoordinator.swift
  - Islet/Notch/DownloadMonitor.swift
  - Islet/Notch/IslandResolver.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - IsletTests/DownloadActivityTests.swift
  - IsletTests/DownloadCoordinatorTests.swift
  - IsletTests/IslandResolverTests.swift
findings:
  critical: 1
  warning: 3
  info: 0
  total: 4
status: issues_found
---

# Phase 61: Code Review Report

**Reviewed:** 2026-07-24T02:58:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed the Download Progress feature: the pure `DownloadActivity`/`DownloadReading` seam, the
stateful `DownloadCoordinator`, the live `DownloadMonitor` FSEvents wrapper, the shared
`IslandResolver`/`TransientQueue` changes, the pill rendering in `NotchPillView`, and the
`NotchWindowController` wiring + toggle lifecycle, plus the three associated test files.

The pure/testable layers (`DownloadActivity.swift`, most of `DownloadCoordinator.swift`,
`IslandResolver.swift`'s resolve()/isPersistent additions) are well covered by unit tests and
individually correct. However, tracing the interaction between `DownloadCoordinator`'s
completion path and `TransientQueue`'s bounded pending list surfaces a real deadlock: a download
that finishes while a Charging/Device splash is currently showing (and the download's
`.inProgress` placeholder is still only *pending*, not head) gets permanently stuck once that
splash's dismiss timer promotes the stale `.inProgress` entry to head — because `.inProgress` is
`isPersistent` and never self-elapses, and nothing re-checks whether the download it represents
has actually already completed. No existing test (unit or otherwise) exercises this
cross-transient interaction, only single-category `TransientQueue` scenarios and single-category
`DownloadCoordinator` scenarios in isolation.

Two smaller correctness/quality gaps were also found: a defensive nil-check branch in
`DownloadCoordinator` that leaves internal state and UI out of sync if ever triggered, and the
`.done(filename:)` payload that is computed and threaded all the way through the coordinator and
queue but is never actually rendered or exposed anywhere in the UI layer.

## Critical Issues

### CR-01: Completed download's spinner gets stuck forever if a Charging/Device transient was showing at completion time

**File:** `Islet/Notch/DownloadCoordinator.swift:86-101` (interacting with `Islet/Notch/IslandResolver.swift:348-379` and `Islet/Notch/NotchWindowController.swift:2359-2378`)

**Issue:** When a download's `.renamed` (completion) reading arrives while `inFlightDownloads`
becomes empty, the coordinator decides how to present the `.done` transient by checking only the
*current head* of the queue:

```swift
if inFlightDownloads.isEmpty {
    if case .downloadProgress = queueHead() {
        replaceHead(doneActivity)
    } else if enqueue(doneActivity) {
        presentTransientChange()
    }
}
```

If a higher-priority transient (Charging or Device) is currently the head, `queueHead()` is not
`.downloadProgress`, so this falls into the `else` branch and simply appends `doneActivity` to
`TransientQueue.pending` via `enqueue(_:)`. Crucially, it never checks whether a **stale**
`.downloadProgress(.inProgress)` entry is *already sitting in `pending`* from when the download
started (this happens whenever a download starts while Charging/Device is head — see
`DownloadCoordinator.swift:69-77`, whose `enqueue` closure just appends to `pending` in that
case).

Trace of a concrete failure:
1. Charging plugged in → `transientQueue.head == .charging(...)`.
2. A download starts while Charging is showing → `.downloadProgress(.inProgress)` is appended to
   `pending` (not head), because `TransientQueue.enqueue(_:)` only replaces `head` when it is
   `nil` (`IslandResolver.swift:348-354`).
3. The download finishes (rename) before Charging's ~3s timer elapses. `inFlightDownloads`
   becomes empty; `queueHead()` is still `.charging`, so the code above just enqueues
   `doneActivity` behind the still-stale `.inProgress` entry:
   `pending == [.downloadProgress(.inProgress), .downloadProgress(.done(filename:))]`.
4. Charging's dismiss timer fires (`NotchWindowController.swift:2366-2378`), calls
   `transientQueue.advance()`, which does `head = pending.removeFirst()` — promoting the
   **stale** `.downloadProgress(.inProgress)` to head, even though the download it represents
   already completed.
5. `scheduleActivityDismiss()` is re-armed for the new head (`NotchWindowController.swift:2376`),
   but its very first guard is `guard let head = transientQueue.head, !head.isPersistent else {
   return }` (`NotchWindowController.swift:2365`). `ActiveTransient.isPersistent` returns `true`
   for `.downloadProgress(.inProgress)` (`IslandResolver.swift:142`), so **no dismiss timer is
   ever armed** for this stale head.
6. Nothing else will ever call `advance()` again for this queue state — the download has already
   completed, so no further `.created`/`.renamed`/`.removed` FSEvents will fire for it, and
   `removeInProgress()` (the only other code path that can clear a stray `.inProgress`) is wired
   solely to the `.removed` (cancel) case in `DownloadCoordinator.handle`
   (`DownloadCoordinator.swift:103-113`), not to this promotion path.

Result: the pill shows a spinner ("downloading…") **forever** for a download that already
finished, and the download's own `.done` filename toast — sitting right behind it in `pending` —
never shows at all. The user must relaunch the app (or trigger another transient category that
happens to flush/replace it) to clear the stuck state.

Note the codebase's own `removeInProgress` closure (wired for the cancel path,
`NotchWindowController.swift:538-555`) already solves the general version of this problem
correctly, by calling `transientQueue.removeAll(where:)`, which scans **both** `head` and
`pending`. The `.renamed` completion path in `DownloadCoordinator` does not reuse that pattern —
it only special-cases the head, not pending.

No test in `DownloadCoordinatorTests.swift` or `IslandResolverTests.swift` exercises a download
completing (or being created) while a Charging/Device transient is the current head, so this
regression class has no coverage.

**Fix:** Before deciding how to present `doneActivity`, strip any stale
`.downloadProgress(.inProgress)` from the *entire* queue (head + pending), not just check whether
the head happens to be `.downloadProgress`. For example, expose (or reuse) a
`removeAll(where:)`-based path from `DownloadCoordinator` itself for this case too:

```swift
case .renamed:
    guard inFlightDownloads.removeValue(forKey: reading.path) != nil else { return }
    guard let finalPath = reading.renamedTo else { return }
    let doneActivity = ActiveTransient.downloadProgress(.done(filename: downloadFilename(fromPath: finalPath)))

    if inFlightDownloads.isEmpty {
        if case .downloadProgress = queueHead() {
            replaceHead(doneActivity)
        } else {
            // Drop any stale in-progress placeholder still queued behind another transient
            // before enqueueing the done splash, or it will get promoted ahead of `doneActivity`
            // once the current head elapses, and — being isPersistent — will never self-elapse.
            removeStaleInProgress()   // new reach-back closure mirroring removeInProgress's removeAll(where:) shape
            if enqueue(doneActivity) { presentTransientChange() }
        }
    } else {
        _ = enqueue(doneActivity)
    }
```

Add a regression test that: enqueues a Charging transient as head, starts a download (goes to
`pending`), completes the download before Charging elapses, then asserts that after Charging's
splash is dismissed the promoted head is `.downloadProgress(.done(...))`, not a stuck
`.downloadProgress(.inProgress)`.

## Warnings

### WR-01: Defensive nil-`renamedTo` branch mutates tracking state without reconciling the queue

**File:** `Islet/Notch/DownloadCoordinator.swift:82-83`

**Issue:**
```swift
guard inFlightDownloads.removeValue(forKey: reading.path) != nil else { return }
guard let finalPath = reading.renamedTo else { return }
```
Line 82 unconditionally removes the tracked entry as a side effect. If `renamedTo` is ever `nil`
for a `.renamed` reading (the type does not statically forbid this — `DownloadReading` is a plain
struct with an optional `renamedTo` for every `kind`), line 83 returns immediately without ever
enqueuing/replacing a `.done` transient and without calling anything equivalent to
`removeInProgress()`. If this was the last tracked download, the standing `.inProgress` transient
is left with no owner to ever dismiss it — reproducing the exact "spinner never stops" bug class
this feature's own commit history says was fixed for the `.removed` case (see the `removeInProgress`
comment at `DownloadCoordinator.swift:37-44`).

Today this is unreachable because `DownloadMonitor.swift`'s only construction site for a `.renamed`
reading always supplies a non-optional `event.path` as `renamedTo`
(`DownloadMonitor.swift:108-109`). But the invariant is enforced by convention only, not by the
type system, and nothing tests this branch.

**Fix:** Either encode the invariant at the type level (e.g. a `renamedTo` that is non-optional
specifically for `.renamed` readings, via a dedicated associated-value case rather than a shared
optional field), or make the nil-safety branch reconcile state the same way `.removed` does:

```swift
guard let finalPath = reading.renamedTo else {
    if inFlightDownloads.isEmpty { removeInProgress() }
    return
}
```

### WR-02: `DownloadActivity.done(filename:)`'s filename is never displayed anywhere

**File:** `Islet/Notch/NotchPillView.swift:3017-3029` (also `Islet/Notch/DownloadActivity.swift:35-40`, `Islet/Notch/DownloadCoordinator.swift:84`)

**Issue:** `DownloadActivity.swift`'s header comment states "D-12: `.done` carries the real,
final filename" and `downloadFilename(fromPath:)` is dutifully threaded through
`DownloadCoordinator` and `TransientQueue` on every completion. But `downloadWings(for:)` in
`NotchPillView.swift` only branches on the `.done` *case*, rendering a fixed green checkmark
icon — the `filename` associated value is discarded entirely:

```swift
case .done:
    Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 14, weight: .bold))
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(.green)
```

No `Text`, tooltip, or `.accessibilityLabel` anywhere in `NotchPillView.swift` references the
filename either (confirmed via search — the string is not used outside the pure/coordinator
layer). Users get an identical generic checkmark regardless of which file finished, with no way
to tell which download completed if two were queued.

**Fix:** Either surface the filename (e.g. as an `.accessibilityLabel("Download complete: \(activity.filename)")` for VoiceOver users at minimum, or a short caption/tooltip matching the shelf row's filename-caption convention), or — if a checkmark-only design is the deliberate final call — drop the unused `filename` payload from `.done` and simplify `DownloadCoordinator`/`downloadFilename(fromPath:)` accordingly, removing the dead data flow and its associated security commentary about "never interpolate... beyond plain display" for a display path that doesn't exist.

### WR-03: `pendingRenamesByFileID` correlation table has no eviction — unresolved halves accumulate indefinitely

**File:** `Islet/Notch/DownloadMonitor.swift:34, 98-113`

**Issue:** `pendingRenamesByFileID[fileID] = event.path` is written whenever a "moved away" half
of a rename is observed (`DownloadMonitor.swift:101-102`), and only ever removed when a matching
"moved to" half with the same `fileID` arrives later (`DownloadMonitor.swift:108`). There is no
timeout, capacity bound, or cleanup path. If the "moved to" half never arrives with a matching
fileID — e.g. the rename is interrupted, the two halves are coalesced into a single event and
lost to Pitfall-style FSEvents coalescing, or (on APFS) a `fileID` is recycled for an unrelated,
later file — the stale entry sits in the dictionary for the app's entire lifetime, and in the
fileID-reuse case can incorrectly correlate a brand-new, unrelated file creation with a
long-stale temp path, firing a bogus `.renamed` reading for two unrelated files.

**Fix:** Bound the table (e.g. drop the oldest entry past some small cap, mirroring
`TransientQueue.maxDepth`'s bounded-drop discipline already used elsewhere in this feature), or
time-stamp entries and evict ones older than a few seconds (well beyond the 0.3s FSEvents latency
window) on each batch.

---

_Reviewed: 2026-07-24T02:58:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
