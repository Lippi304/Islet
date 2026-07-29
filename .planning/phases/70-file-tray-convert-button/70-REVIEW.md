---
phase: 70-file-tray-convert-button
reviewed: 2026-07-30T01:30:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - Islet/Notch/DragDropSupport.swift
  - Islet/Notch/ImageConversionService.swift
  - Islet/Notch/IslandPresentationState.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/Shelf/ShelfLogic.swift
  - IsletTests/DragApproachGeometryTests.swift
  - IsletTests/DragDropSupportTests.swift
  - IsletTests/ImageConversionServiceTests.swift
  - IsletTests/ShelfLogicTests.swift
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
status: issues_found
---

# Phase 70: Code Review Report

**Reviewed:** 2026-07-30T01:30:00Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Reviewed the File Tray Convert Button implementation (ImageIO conversion seam, 2-stage
Quick Action picker, and the `NotchWindowController` glue that drives it). The three bugs
the task description called out as already found/fixed via on-device UAT — the click
landing on the app's own window needing `handleClick()` dispatch instead of
`handleDragApproachEnd()`'s global monitor, the hover-exit grace timer discarding a
pending drop mid-repositioning, and the `syncClickThrough()` stuck-click-through state —
were all verified present and correctly fixed in the current code (`bde503e`, `59748db`).

Cross-referencing the diff against `70-UI-SPEC.md` and `70-04-SUMMARY.md` also confirmed
that the documented "no error toast, skip-and-continue" behavior for a failed per-item
conversion is an intentional, spec'd product decision (`70-UI-SPEC.md` line 95) — not a
defect, so it is not flagged below despite initially looking like a silent-failure gap.

One new, previously-undiscovered functional defect was found in the same interaction area
the task flagged for scrutiny: the fix for "hover-exit auto-discarding a pending drop
mid-interaction" over-corrects by suppressing the grace-collapse for the *entire* lifetime
of the format-tile stage, not just the brief pointer-travel window it was meant to cover —
this can leave the island permanently stuck expanded. Two further code-quality issues
(dead/duplicated dispatch code, an orphaned-temp-directory leak on conversion failure) and
one stale test comment round out the findings. `ShelfLogic`'s new compound `(originalURL,
filename)` dedup key was traced through both the Drop and Convert call sites and found
correct — no issue found there.

## Critical Issues

### CR-01: Hover-exit grace-collapse is permanently suppressed for the whole format-tile stage, not just the pointer-travel window — island can get stuck expanded

**File:** `Islet/Notch/NotchWindowController.swift:2158-2167` (guard at line 2167), interacting with `Islet/Notch/NotchWindowController.swift:1652-1654`

**Issue:**
`handleHoverExit()`'s grace-collapse closure contains:
```swift
guard !self.presentationState.isShowingConvertFormats else { return }
```
The comment above it explains the *intended* scope of this fix: the pointer briefly
leaving `visibleContentZone()` while moving from the Convert chip's old position toward a
format tile shouldn't trigger the existing "grace-collapse discards a showing picker"
behavior. `70-04-SUMMARY.md`'s own key-decision note frames the fix the same way ("...the
format-tile stage requires the pointer to travel across the card without an active OS drag
pinning it in place").

However, the guard as written doesn't scope the suppression to that transient window at
all — it disables grace-collapse for the *entire* duration `isShowingConvertFormats` stays
`true`, which can be indefinite. Once a user drags a file onto Convert (setting
`isShowingConvertFormats = true` in `handleDragApproachEnd`, line 1652-1654), the only way
to ever leave that stage again is an explicit follow-up click landing inside the picker
card (handled by `handleClick()`, lines 2227-2249) or the drag-release D-13 off-target
branch (which can't fire here — see WR-01 below). If the user instead abandons the
interaction without clicking anywhere in the card — switches to another app, clicks
elsewhere on the desktop, walks away — nothing ever re-arms the grace-collapse for this
presentation. The island stays visibly expanded, showing the JPG/PNG/HEIC/TIFF tiles,
indefinitely. This also holds across screen/fullscreen visibility cycles:
`updateVisibility()`'s hide branch (line 1327-1339) clears `hotZone`/`expandedZone`/
`pointerInZone` but never touches `pendingDrop` or `isShowingConvertFormats`, so the stuck
picker reappears exactly as left when the panel becomes visible again.

Every other transient/expanded presentation in this file (Charging, Device, media,
Tray, the *main* Quick Action row) either auto-collapses via the grace timer or is
guaranteed a terminating `.leftMouseUp` because it's driven by a continuous OS drag. The
format-tile stage is the one exception that has no bounded, walk-away-safe path back to
`.collapsed` — a real regression against the app's established "hover away to dismiss"
contract for exactly the class of "stuck expanded" bug this phase's own UAT already found
and fixed once (the click-through stuck state, CR-01 in `70-04-SUMMARY.md`).

**Fix:** Scope the suppression to the actual travel window instead of the whole stage —
e.g., re-arm a short, bounded "abandon" timeout specific to this stage instead of an
unconditional `return`:
```swift
// Only defer the grace-collapse while the pointer is still plausibly moving toward a
// tile; a stage that's been open with no plausible progress for longer than one grace
// window should collapse+discard like everything else instead of hanging forever.
guard !self.presentationState.isShowingConvertFormats
   || self.formatStageEnteredAt.map({ Date().timeIntervalSince($0) < self.graceDelay * 2 }) == true
else {
    self.presentationState.isShowingConvertFormats = false
    self.discardPendingDrop()
}
```
(or equivalent: track a stamped "entered format stage at" time and only suppress the very
first grace-collapse tick after entry, falling through to the normal collapse+discard path
on any subsequent one). The exact mechanism is a design choice, but *some* bounded
walk-away path back to collapsed must exist for this stage.

## Warnings

### WR-01: Dead, duplicated format-tile dispatch code in `handleDragApproachEnd`

**File:** `Islet/Notch/NotchWindowController.swift:1633-1641`

**Issue:** `handleDragApproachEnd()` contains:
```swift
if let hit = quickActionButtonFrames.firstIndex(where: { $0.contains(point) }) {
    if presentationState.isShowingConvertFormats {
        if ImageFormat.allCases.indices.contains(hit) {
            handleQuickActionConvert(to: ImageFormat.allCases[hit])
        }
    } else {
        ...
```
This entire `isShowingConvertFormats` branch is unreachable in production. The function's
own comment two lines above it (line 1626-1631) states the reason:
`handleDragApproachEnd()` only ever runs on a *real* OS file-drag release
(`guard isDragApproaching else { return }`, line 1615), and the format-tile stage's pick is
confirmed on-device to be an ordinary in-app click that never reaches this global-monitor
callback at all — that's why an entirely separate, and correct, copy of this same
hit-test/dispatch logic had to be added to `handleClick()` (lines 2227-2238). Additionally,
by the time `isShowingConvertFormats` is `true`, `interaction.isExpanded` is also `true`,
which blocks `recheckDragAcceptRegion`'s arm condition (`!interaction.isExpanded`, line
1555) from ever setting `isDragApproaching = true` again — so a *second* genuine external
drag can't even arm while this stage is showing, closing off the last theoretical path to
this code.

Keeping a dead copy of the dispatch logic side-by-side with the live one in `handleClick()`
is a maintenance hazard: a future change to `handleQuickActionConvert`'s call site (e.g.
adding a guard, changing the hit-test) only needs to be made in one of the two places to
compile and pass on-device testing, silently leaving the other permanently stale — exactly
the kind of drift this codebase's own extensive "single source of truth" commenting
convention elsewhere tries to prevent.

**Fix:** Delete the dead `if presentationState.isShowingConvertFormats { ... }` branch from
`handleDragApproachEnd` (lines 1635-1640), leaving only the `else` branch's main-row
dispatch — it can never legitimately run given the guards already in place, and the
comment already explains why the real dispatch lives elsewhere.

### WR-02: Orphaned temp directory left behind when a per-item Convert attempt fails after directory creation

**File:** `Islet/Notch/NotchWindowController.swift:1771-1789`

**Issue:** In `handleQuickActionConvert(to:)`, `itemDir` is created via `FileManager.
default.createDirectory` *before* the `baseName` validation and the actual
`ImageConversionService.convert` call:
```swift
guard (try? FileManager.default.createDirectory(at: itemDir, withIntermediateDirectories: true)) != nil else { continue }
let baseName = (item.filename as NSString).deletingPathExtension
guard !baseName.isEmpty, baseName != ".", baseName != ".." else { continue }
...
guard (try? ImageConversionService.convert(item.localURL, to: format, destinationURL: destinationURL)) != nil else { continue }
```
Both `continue` paths after directory creation (invalid `baseName`, or a failed
`convert()` call — e.g. a corrupt/unreadable source that passed `isImageFile`'s cheap
sniff check but fails to actually decode) leave the freshly-created, now-empty `itemDir`
on disk with nothing ever tracking or cleaning it up: no `ShelfItem` is created for a
skipped item, so `ShelfCoordinator`'s delete paths (`remove`/`clear`/rejected-`append`)
never see this directory's `localURL` and can never reclaim it. Every failed conversion in
this batch leaks one `tmp/IsletShelf/<uuid>/` directory permanently.

**Fix:** Clean up on the failure paths, mirroring the discipline `ShelfCoordinator.append`
already uses for a rejected append:
```swift
guard !baseName.isEmpty, baseName != ".", baseName != ".." else {
    try? FileManager.default.removeItem(at: itemDir)
    continue
}
...
guard (try? ImageConversionService.convert(item.localURL, to: format, destinationURL: destinationURL)) != nil else {
    try? FileManager.default.removeItem(at: itemDir)
    continue
}
```

## Info

### IN-01: Stale test comment contradicts the dedup key it documents

**File:** `IsletTests/ShelfLogicTests.swift:42-44`

**Issue:** `testAppendSameFilenameDifferentOriginalURLBothCoexist`'s comment reads:
```swift
// D-01: dedupe key is originalURL only, never filename — two files named the same
// but sourced from different paths both remain in the shelf.
```
This is left over from before the Phase 70 fix and is now inaccurate: `ShelfLogic.append`'s
dedup key is the *compound* `(originalURL, filename)` pair (see `ShelfLogic.swift:24-27`
and the adjacent test `testAppendSameOriginalURLAndFilenameStillRejectsDuplicate`, which
correctly documents the compound key). The test's assertions are still valid coverage —
different `originalURL` never dedupes regardless of key composition — but the comment
actively misleads a future reader about what's actually being guaranteed here.

**Fix:** Update the comment, e.g.: "the dedup key includes filename, but originalURL alone
already differs here, so these are never considered duplicates regardless."

---

_Reviewed: 2026-07-30T01:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
