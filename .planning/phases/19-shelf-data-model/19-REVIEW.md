---
phase: 19-shelf-data-model
reviewed: 2026-07-09T18:54:53Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - Islet/Shelf/ShelfItem.swift
  - Islet/Shelf/ShelfLogic.swift
  - Islet/Shelf/ShelfFileStore.swift
  - Islet/Shelf/ShelfCoordinator.swift
  - IsletTests/ShelfLogicTests.swift
  - IsletTests/ShelfFileStoreTests.swift
  - IsletTests/ShelfCoordinatorTests.swift
findings:
  critical: 1
  warning: 2
  info: 3
  total: 6
status: issues-found
---

**Post-review update (2026-07-09):** CR-01 and WR-01 fixed in commit `a5cff71` (path-validation guard on `deleteSessionCopy`; orphan cleanup on rejected duplicate append), both with new passing tests. WR-02 and the Info items are deferred — no live caller exists yet in this phase; tracked for Phase 20-22.

# Phase 19: Code Review Report

**Reviewed:** 2026-07-09T18:54:53Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues-found

## Summary

Reviewed the pure `ShelfItem`/`ShelfLogic` model, the real-disk `ShelfFileStore` copy/delete
helper, the `@MainActor` `ShelfCoordinator` wiring, and all three test files. The append/
dedupe/remove/clear reducer logic (`ShelfLogic`) is correct and matches D-01/D-02/D-06 exactly,
and is well covered by tests. The Foundation-only constraint (SHELF-08) holds — no AppKit/
SwiftUI/Cocoa/NSItemProvider imports anywhere, confirmed by direct inspection of all four
source files. The `Equatable` addition to `ShelfFileStoreError` (the SUMMARY's noted deviation)
is sound: the enum has a single case, so `Equatable` conformance is inert and does not mask any
behavior — no concern there.

However, `ShelfFileStore.deleteSessionCopy` performs an **unvalidated recursive delete of an
entire parent directory** derived from a caller-supplied URL, with no check that the URL
actually lives under the shelf's own temp-directory prefix. Given this primitive is the thing
`ShelfCoordinator.remove`/`clear` call on every item leaving the shelf, and its only safety
comes from callers *always* constructing `ShelfItem.localURL` via `ShelfFileStore.makeSessionCopy`
first — a convention enforced nowhere in code — this is a real data-loss risk once Phase 20-22
wire live callers around it. There is also a genuine gap in the phase's own T-19-03 mitigation:
a rejected duplicate append leaves its just-created session-temp copy permanently orphaned,
uncovered by any test. Both are flagged below along with lower-severity design notes.

## Critical Issues

### CR-01: `ShelfFileStore.deleteSessionCopy` deletes an unvalidated parent directory — real data-loss risk if ever called with a non-session URL

**File:** `Islet/Shelf/ShelfFileStore.swift:41-43`

**Issue:** `deleteSessionCopy(at:)` unconditionally does:

```swift
static func deleteSessionCopy(at localURL: URL) {
    try? FileManager.default.removeItem(at: localURL.deletingLastPathComponent())
}
```

This recursively deletes the **entire parent directory** of whatever `localURL` it is given —
not just the single file. The only thing keeping this safe today is the *convention*, documented
only in comments, that every `ShelfItem.localURL` passed through `ShelfCoordinator` was produced
by `ShelfFileStore.makeSessionCopy` and therefore lives under
`NSTemporaryDirectory()/IsletShelf/<uuid>/`. Nothing in `ShelfItem`, `ShelfLogic.append`, or
`ShelfCoordinator.append` validates that invariant — `ShelfItem.localURL` is a plain, freely
constructible `var URL` field.

If a future caller (Phase 20's view/controller wiring, Phase 22's drag-in) ever constructs a
`ShelfItem` with `localURL` accidentally equal to (or derived from) `originalURL` — e.g. a
copy-paste bug that swaps the two arguments, or a code path that skips `makeSessionCopy` — the
very next `remove(id:)` or `clear()` call will silently `removeItem` on the **parent folder of
the user's real file** (e.g. their entire `~/Downloads` if `originalURL` was
`~/Downloads/resume.pdf`), because the function has no way to tell a legitimate session-temp
path from an arbitrary one. This is exactly the class of bug that a single future misuse turns
into permanent, silent user data loss — worse than a crash, because `try?` swallows any error
and nothing surfaces the mistake.

**Fix:** Validate that the resolved directory is actually inside the shelf's own temp root
before deleting anything; no-op (or assert in debug) otherwise:

```swift
static func deleteSessionCopy(at localURL: URL) {
    let itemDir = localURL.deletingLastPathComponent().standardizedFileURL
    let shelfRoot = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("IsletShelf", isDirectory: true)
        .standardizedFileURL
    guard itemDir.path.hasPrefix(shelfRoot.path + "/") else {
        assertionFailure("deleteSessionCopy called with a URL outside IsletShelf temp root: \(localURL)")
        return
    }
    try? FileManager.default.removeItem(at: itemDir)
}
```

## Warnings

### WR-01: T-19-03 mitigation is incomplete — duplicate-drop rejection orphans its just-created session-temp copy

**File:** `Islet/Shelf/ShelfCoordinator.swift:25-28`, `Islet/Shelf/ShelfLogic.swift:16-21`

**Issue:** The documented workflow (per this file's own header comment and the plan) is: the
caller calls `ShelfFileStore.makeSessionCopy` to get a real `localURL` *first*, then calls
`ShelfCoordinator.append(_:)`. But `ShelfLogic.append` silently rejects (returns `false`) any
item whose `originalURL` already exists in the shelf (D-01/D-02). When that happens, the
session-temp copy that was just created on disk for the rejected duplicate is never deleted —
`ShelfCoordinator.append` is a bare pass-through to `logic.append` with "no FileManager side
effect here" by design, and there is no branch anywhere that calls `ShelfFileStore
.deleteSessionCopy` for a rejected append.

This directly undermines the phase's own threat-model claim: `19-01-PLAN.md`'s STRIDE register
marks T-19-03 ("Denial of Service via orphaned copies") as `mitigate`, citing
`ShelfCoordinator.remove`/`clear` as the enforcement — but that only covers items that
successfully entered the shelf and were later removed. An item that never *successfully* enters
the shelf (rejected duplicate) has no coordinator method that ever touches its already-created
`localURL`. None of the 5 `ShelfFileStoreTests` or 4 `ShelfCoordinatorTests` exercise this path
(create-copy → append → rejected → assert copy is gone).

**Fix:** Either (a) have `ShelfCoordinator.append` delete the just-made copy when `logic.append`
returns `false`:

```swift
@discardableResult
func append(_ item: ShelfItem) -> Bool {
    let added = logic.append(item)
    if !added {
        ShelfFileStore.deleteSessionCopy(at: item.localURL)
    }
    return added
}
```

or (b) explicitly document this as Phase 22's responsibility (check the return value and clean
up on `false`) and add a test asserting the current contract, so the gap is a documented decision
rather than a silent one. Given `ShelfCoordinator` already owns the D-05 delete side effect for
`remove`/`clear`, option (a) keeps all delete-on-rejection logic in one place rather than
depending on every future caller remembering to check a boolean.

### WR-02: Dedupe key relies on raw `URL` equality with no path standardization

**File:** `Islet/Shelf/ShelfLogic.swift:18`

**Issue:** `append`'s dedupe guard is `$0.originalURL == item.originalURL`. `URL` equality is a
component-wise string comparison; it does not resolve symlinks or standardize paths. On macOS,
`/tmp` is a symlink to `/private/tmp`, and Finder/`NSItemProvider`-supplied URLs for the *same*
file are not guaranteed to be textually identical across two separate drop events (e.g. a
security-scoped bookmark resolving to `/private/var/...` on one drop vs `/var/...` on another,
or a trailing-slash / percent-encoding difference). If that happens, a genuine re-drop of the
same file would bypass D-01/D-02's dedupe and create a second `ShelfItem` for what the user
perceives as "the same file already on the shelf."

This is a real risk for Phase 22 (live drag-in), not for this phase's own tests, which construct
URLs consistently. It's worth flagging now since the dedupe contract is locked in this phase.

**Fix:** Consider standardizing/resolving `originalURL` (`.standardizedFileURL` and/or
`.resolvingSymlinksInPath()`) either when constructing `ShelfItem` or inside the dedupe
comparison, so equality is based on the canonical filesystem path rather than the literal URL
string. Not urgent for this phase (no caller exists yet), but should be decided explicitly
before Phase 22 wires real Finder drops rather than discovered as a field bug later.

## Info

### IN-01: `ShelfItem.localURL` is declared `var` but is never mutated anywhere in the codebase

**File:** `Islet/Shelf/ShelfItem.swift:12`

**Issue:** `ShelfItem` is documented and treated everywhere as an immutable "PURE shelf item
value," and every other field is `let`. `localURL` is `var`, per the plan's literal spec, but no
code (source or tests) ever reassigns it after construction — items are always fully constructed
with a real `localURL` up front (`ShelfFileStore.makeSessionCopy` result). The mutability adds a
foot-gun: nothing stops a later caller from mutating `shelfItem.localURL` on a `var` copy after
the fact, silently invalidating the CR-01/WR-01 invariant that `localURL` always points at a
real session-temp path this store created.

**Fix:** If no future phase genuinely needs in-place mutation of `localURL` (skimmed
`19-01-PLAN.md`/`ROADMAP.md` — none indicated), change to `let localURL: URL` for a true value
type. Low priority; flag only because it slightly weakens the safety argument used in CR-01/WR-01.

### IN-02: `makeSessionCopy` leaves an orphaned empty directory if `copyItem` fails after `createDirectory` succeeds

**File:** `Islet/Shelf/ShelfFileStore.swift:29-33`

**Issue:** `createDirectory` and `copyItem` are two separate throwing calls with no cleanup on
partial failure. If `createDirectory` succeeds but `copyItem` subsequently throws (disk full,
permission denied, source vanished mid-call), the freshly created empty
`IsletShelf/<uuid>/` directory is left behind — nothing ever removes it, since the calling
`ShelfItem` was never successfully constructed (the `throws` propagates before any `ShelfItem`
exists for `ShelfCoordinator` to `remove`/`clear` later).

**Fix:** Wrap in a do/catch that removes `itemDir` before rethrowing on the `copyItem` failure
path, e.g. `catch { try? FileManager.default.removeItem(at: itemDir); throw error }`. Low
priority — requires a mid-operation disk failure to manifest, but cheap to fix and keeps D-05's
"nothing lingers" guarantee honest under failure, not just the happy path.

### IN-03: Synchronous disk I/O called directly from `@MainActor` methods

**File:** `Islet/Shelf/ShelfCoordinator.swift:34-38, 43-50`

**Issue:** `ShelfCoordinator.remove`/`clear` call `ShelfFileStore.deleteSessionCopy` synchronously
from `@MainActor`-isolated methods. This is correct and safe today (no UI wired yet), but once
Phase 20 wires this coordinator to a live view, every remove/clear/app-quit action will block the
main/UI thread on `FileManager.removeItem` for however long that recursive delete takes. Noted
for awareness rather than as a blocking finding — no algorithmic/perf issue, just a
main-thread-I/O design point worth deciding on consciously in Phase 20 rather than inheriting
silently.

---

_Reviewed: 2026-07-09T18:54:53Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
