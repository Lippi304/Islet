---
phase: 70-file-tray-convert-button
verified: 2026-07-30T02:00:00Z
status: passed
score: 12/12 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Drag an image onto the island, release on Convert to enter the format-tile stage, then walk away / switch to another app / do nothing for 5+ seconds without clicking anywhere in the picker card."
    expected: "After ~3 seconds (formatStageAbandonWindow), the island collapses and discards the pending drop on its own — it must NOT remain stuck expanded indefinitely."
    why_human: "This is the specific edge case CR-01 (code review, post-UAT) was found and fixed for. The fix is code-verified (bounded timer replaces an unconditional suppression) and the full automated suite passes with it in place, but the timed walk-away behavior needs to be observed on real hardware — this exact interaction was never re-run on-device after the fix landed."
    result: "passed — user confirmed \"approved\" on-device 2026-07-30, see 70-HUMAN-UAT.md"
---

# Phase 70: File Tray Convert Button Verification Report

**Phase Goal:** Users can convert one or more dropped images to JPG/PNG/HEIC/TIFF via a 4th
"Convert" button in the Quick Action Destination Picker (Drop/AirDrop/Mail/Convert), landing
the converted copies in the Tray via the exact same mechanism "Drop" already uses. Convert is
dimmed whenever the pending drop contains any non-image file. This phase also fixes a dormant
D-06 controller-gate bug: a release on a dimmed AirDrop/Mail/Convert chip previously still
fired its handler.
**Verified:** 2026-07-30
**Status:** human_needed
**Re-verification:** No — initial verification

## Requirement Traceability Precedent Check

This phase's frontmatter states D-01..D-06 are "not tracked in REQUIREMENTS.md — queued
feature phase, no formal IDs assigned yet." Checked whether this precedent actually holds
elsewhere in the codebase (not just asserted): confirmed via `.planning/ROADMAP.md` that
**Phase 16** ("D-01, D-02, D-03 — source: 16-CONTEXT.md locked decisions — no formal
REQUIREMENTS.md IDs exist for this phase") and **Phase 67.1** ("D-01..D-14 — source:
67.1-CONTEXT.md locked decisions — no formal REQUIREMENTS.md IDs exist for this inserted
phase, same precedent as Phase 16") both use the identical CONTEXT.md-sourced,
REQUIREMENTS.md-absent decision-ID pattern and both phases shipped successfully under it.
This is an established, repeated project convention, not a one-off gap. **Not treated as a
gap.** (Note: the prompt's reference to "Phase 69's precedent" does not exist as executed
work — Phase 69 is still `[To be planned]`, 0 plans, in ROADMAP.md. The actual, real
precedent is Phase 16 / Phase 67.1, confirmed above.)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Converting a real image to JPG/PNG/HEIC/TIFF produces an actually re-encoded file, not a renamed byte copy (D-02) | ✓ VERIFIED | `ImageConversionService.convert` uses `CGImageSourceCreateWithURL`/`CGImageDestinationCreateWithURL`/`CGImageDestinationAddImageFromSource`/`CGImageDestinationFinalize` (real ImageIO transcode). `grep -c NSBitmapImageRep` = 0. `ImageConversionServiceTests.testConvertsSourceToEachFormatProducesRealReencode` passes (re-reads the converted file's own UTI to prove real re-encode) |
| 2 | A file is classified as 'image' by actual declared UTType/content, not filename extension (D-05) | ✓ VERIFIED | `isImageFile` checks `resourceValues(.contentTypeKey).conforms(to: .image)` then falls back to `CGImageSourceGetType` header-byte sniff for extensionless files. `testIsImageFileDetection` passes |
| 3 | `computeQuickActionButtonFrames(card:count:)` count-3 produces byte-identical geometry to the old hardcoded-3 behavior | ✓ VERIFIED | Signature generalized in place (`Islet/Notch/DragDropSupport.swift:68`); `DragDropSupportTests.testComputeQuickActionButtonFramesCountThreeMatchesOldHardcodedBehavior` and count-4 spacing test both pass |
| 4 | A 4th "Convert" chip renders in the main Quick Action row using the same `quickActionButton` component (D-01) | ✓ VERIFIED | `NotchPillView.swift:2358` — `quickActionButton(icon: "arrow.triangle.2.circlepath", label: "Convert", ...)` inside the same `HStack` as Drop/AirDrop/Mail |
| 5 | Convert renders dimmed whenever the pending drop has ANY non-image item, computed fresh every render from `PendingDrop.items` — never a stored Bool (D-05, sync-gap avoidance) | ✓ VERIFIED | `NotchPillView.swift:2359` — `enabled: pendingDrop.items.allSatisfy { ImageConversionService.isImageFile($0.originalURL) }` computed inline. `grep -c "var convertAvailable"` = 0 |
| 6 | When `isShowingConvertFormats` is true, the SAME card shows 4 format tiles (JPG/PNG/HEIC/TIFF) instead of the main row, no card resize (D-01) | ✓ VERIFIED | `formatTileRow()` (`NotchPillView.swift:2090`) iterates `ImageFormat.allCases`; `quickActionPickerView` branches via `Group { if presentationState.isShowingConvertFormats { formatTileRow() } else { quickActionButtonRow(...) } }` inside the unchanged `blobShape` call — no new geometry constants added |
| 7 | Releasing on a DIMMED/disabled button never dispatches its handler, for ALL 4 main-row buttons (D-06 gate fix) | ✓ VERIFIED | `handleDragApproachEnd()`'s switch: `case 1: if airDropAvailable { ... }`, `case 2: if mailAvailable { ... }`, `case 3: if isConvertEnabled { ... }` — all 3 sometimes-false-capable buttons gated (`NotchWindowController.swift:1652-1662`) |
| 8 | Releasing on the enabled Convert chip opens the format-tile stage WITHOUT converting or dismissing anything yet (D-01, not a commit) | ✓ VERIFIED | `case 3: if isConvertEnabled { presentationState.isShowingConvertFormats = true; formatStageEnteredAt = ... }` — no `discardPendingDrop()`/`dismissExpandedImmediately()` call in this branch |
| 9 | Releasing on a format tile converts every item in the batch to the chosen format and lands successes in Tray via `shelfCoordinator.append`, same mechanism Drop uses (D-03/D-04) | ✓ VERIFIED | `handleQuickActionConvert(to:)` (`NotchWindowController.swift:1778`) loops `pendingDrop.items`, calls `ImageConversionService.convert(item.localURL, ...)`, then `shelfCoordinator.append(convertedItem)`. On-device confirmed in 70-04-SUMMARY.md after fixing the `originalURL`→`localURL` bug (`bde503e`) |
| 10 | Releasing inside the card but not on a format tile, during the format stage, discards the pending drop and force-collapses (D-13 precedent) | ✓ VERIFIED | `handleClick()`'s `isShowingConvertFormats` branch (`NotchWindowController.swift:2249-2253`): miss-tile path calls `discardPendingDrop()` + `dismissExpandedImmediately()`, mirroring the main row's off-target rule. (Dispatched from `handleClick()`, not `handleDragApproachEnd()`, per the on-device-discovered dispatch-mechanism fix — confirmed correct and the only reachable path per WR-01's review finding) |
| 11 | Full XCTest suite is green (excluding documented pre-existing failures) | ✓ VERIFIED (independently re-run) | Ran `xcodebuild test -scheme Islet -destination 'platform=macOS'` myself: 582 tests, 7 failures — all 7 are the documented pre-existing baseline (4x `LicenseStateTests`, 3x `SettingsViewTests`), zero new failures, zero failures in any Phase-70 file (`ImageConversionServiceTests`, `DragDropSupportTests`, `ShelfLogicTests` all 100% green) |
| 12 | On real hardware: image-only drop enables Convert, mixed batch dims it, tapping Convert shows tiles without converting, tapping a tile converts+lands, dimmed chips never fire (D-01..D-06) | ✓ VERIFIED (on-device, human-approved) | 70-04-SUMMARY.md documents the on-device UAT checkpoint (`checkpoint:human-verify`, gate: blocking) ran through 5 real bug-fix iterations (wrong source URL, wrong click-dispatch mechanism, hover-exit auto-discard, ShelfLogic dedup false-positive, stuck click-through) and the user gave final "approved" on the full 8-step checklist |

**Score:** 12/12 truths verified

### Post-UAT Code Review Fix — Scope Note

A subsequent code review (`70-REVIEW.md`, 2026-07-30) found one **critical** issue after the
on-device UAT approval: `CR-01` — the hover-exit grace-collapse suppression for the
format-tile stage was unconditional (`guard !isShowingConvertFormats else { return }`)
instead of bounded to the brief pointer-travel window it was meant to cover, meaning a user
who abandoned the picker mid-format-stage (switched apps, walked away) without ever clicking
would leave the island stuck expanded indefinitely.

Verified the fix (commit `341fb96`) is correctly applied in the current codebase:
`formatStageEnteredAt`/`formatStageAbandonWindow` (3.0s) now bound the suppression
(`NotchWindowController.swift:2192-2196`), so an abandoned format stage self-heals via the
normal collapse+discard path after 3 seconds. Also verified `WR-01` (dead duplicated
dispatch branch removed), `WR-02` (orphaned temp-directory cleanup on both failure paths),
and `IN-01` (stale test comment corrected) are all present in the diff exactly as the review
recommended.

**This CR-01 fix changes an edge-case walk-away timeout, not any of the 8 happy-path steps
the on-device UAT already exercised and the user approved.** It has NOT been separately
re-confirmed on real hardware (no second on-device UAT round was run after this fix landed).
The fix is: (a) logically sound and matches the review's own recommended shape, (b) confirmed
compiling and not regressing any of the 582 automated tests I re-ran myself. Flagging this as
a human-verification item below rather than either silently accepting it as fully proven or
blocking the phase on it, since the happy path (the actual phase goal) is fully verified and
this is additive robustness on an edge case outside the original UAT script.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/ImageConversionService.swift` | ImageFormat enum, convert(), isImageFile() | ✓ VERIFIED | 92 lines, real ImageIO calls, exports match plan interface exactly |
| `IsletTests/ImageConversionServiceTests.swift` | Real-fixture round-trip coverage | ✓ VERIFIED | 3 test methods, all pass, exercise real fixture bytes |
| `Islet/Notch/DragDropSupport.swift` | `computeQuickActionButtonFrames(card:count:)` | ✓ VERIFIED | Generalized in place, old 1-arg signature count = 0 |
| `Islet/Notch/IslandPresentationState.swift` | `isShowingConvertFormats` flag | ✓ VERIFIED | `@Published var isShowingConvertFormats: Bool = false` present |
| `Islet/Notch/NotchPillView.swift` | Convert chip, formatTileRow(), stage branch | ✓ VERIFIED | All three present and wired |
| `Islet/Notch/NotchWindowController.swift` | D-06 gate, handleQuickActionConvert, stage resets | ✓ VERIFIED | All present; CR-01/WR-01/WR-02 review fixes also verified in current code |
| `Islet/Shelf/ShelfLogic.swift` | Compound `(originalURL, filename)` dedup key | ✓ VERIFIED | Confirmed via code + 2 passing regression tests |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `ImageConversionService.convert` | `CGImageDestinationCreateWithURL`/`Finalize` | ImageIO | ✓ WIRED | Confirmed by grep + passing round-trip tests |
| `ImageConversionService.isImageFile` | `UTType.conforms(to: .image)` | `resourceValues(.contentTypeKey)` + ImageIO sniff fallback | ✓ WIRED | Confirmed by grep + passing detection test |
| `quickActionButtonRow` | `ImageConversionService.isImageFile` | `pendingDrop.items.allSatisfy` | ✓ WIRED | `NotchPillView.swift:2359` |
| `quickActionPickerView` | `presentationState.isShowingConvertFormats` | `Group{if/else}` | ✓ WIRED | `NotchPillView.swift:2066` |
| `handleDragApproachEnd()` | D-06 enabled gates | `if airDropAvailable`/`if mailAvailable`/`if isConvertEnabled` | ✓ WIRED | `NotchWindowController.swift:1652-1662` |
| `handleQuickActionConvert(to:)` | `ImageConversionService.convert` | per-item conversion | ✓ WIRED | `NotchWindowController.swift:1799` |
| `handleQuickActionConvert(to:)` | `shelfCoordinator.append` | landing call | ✓ WIRED | Same call `handleQuickActionDrop()` uses |
| Format-tile pick (2nd gesture) | `handleQuickActionConvert(to:)` | `handleClick()` (SwiftUI `onTapGesture`), not `handleDragApproachEnd` | ✓ WIRED | Discovered via on-device UAT that this is the ONLY mechanism that observes the second, drag-free click; correctly implemented |

### Behavioral Spot-Checks / Test Execution

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Debug build | `xcodebuild build -scheme Islet -configuration Debug` | BUILD SUCCEEDED | ✓ PASS |
| Release build | `xcodebuild build -scheme Islet -configuration Release` | BUILD SUCCEEDED | ✓ PASS |
| Full test suite (independently re-run, not trusting SUMMARY claims) | `xcodebuild test -scheme Islet -destination 'platform=macOS'` | 582 tests, 7 failures — 4x LicenseStateTests, 3x SettingsViewTests (all pre-existing, none in Phase-70 files) | ✓ PASS |
| Phase-70-specific suites | (subset of above run) | `ImageConversionServiceTests` 3/3, `DragDropSupportTests` all pass, `ShelfLogicTests` 7/7 incl. 2 new dedup regression tests | ✓ PASS |
| Debt-marker scan | `grep -n "TBD\|FIXME\|XXX"` on all 6 modified files | 0 matches | ✓ PASS |

### Requirements Coverage

| Requirement | Source | Description | Status | Evidence |
|-------------|--------|-------------|--------|----------|
| D-01 | 70-CONTEXT.md | Convert opens 2nd step in same card, not immediate conversion | ✓ SATISFIED | Truths #6, #8 |
| D-02 | 70-CONTEXT.md | JPG/PNG/HEIC/TIFF format tiles offered | ✓ SATISFIED | Truth #1, `ImageFormat.allCases` |
| D-03 | 70-CONTEXT.md | One decision converts the whole batch | ✓ SATISFIED | Truth #9 — loop over `pendingDrop.items` |
| D-04 | 70-CONTEXT.md | Converted files land via the same Drop mechanism | ✓ SATISFIED | Truth #9 — `shelfCoordinator.append` |
| D-05 | 70-CONTEXT.md | Dim-never-hide, enabled only if every item is an image | ✓ SATISFIED | Truths #2, #5 |
| D-06 | 70-CONTEXT.md | Controller-side gate fix for dimmed buttons | ✓ SATISFIED | Truth #7 |

No orphaned requirements — all 6 IDs declared in plan frontmatter map to verified evidence above. REQUIREMENTS.md traceability gap is expected and precedented (see note above), not a defect.

### Anti-Patterns Found

None found in any of the 6 files modified this phase (`ImageConversionService.swift`,
`DragDropSupport.swift`, `IslandPresentationState.swift`, `NotchPillView.swift`,
`NotchWindowController.swift`, `ShelfLogic.swift`). No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/
`PLACEHOLDER` markers, no empty stub returns, no hardcoded-empty rendering paths.

### Human Verification Required

### 1. On-device re-confirmation of CR-01's bounded abandon-timeout fix

**Test:** Drag an image onto the island, release on Convert to enter the format-tile stage,
then walk away / switch to another app / do nothing for 5+ seconds without clicking
anywhere in the picker card.
**Expected:** After ~3 seconds (`formatStageAbandonWindow`), the island should
collapse+discard the pending drop on its own, exactly like the existing main-row grace-collapse
behavior — it must NOT remain stuck expanded indefinitely.
**Why human:** This is the specific edge case CR-01 was found and fixed for, after the
original 8-step on-device UAT checklist was already approved. The fix is code-verified (bounded
timer replaces an unconditional suppression, confirmed present in the current diff) and the
full automated suite passes with it in place, but the actual timed walk-away behavior needs a
stopwatch-and-observe on real hardware — this exact interaction was never re-run on-device
after the fix landed.

### Gaps Summary

No gaps. All 12 derived must-haves (merged from all 4 plans' frontmatter + the roadmap goal)
are verified in the current codebase — not just claimed in SUMMARY.md. Independent re-execution
of the full build and test suite confirms the SUMMARY's "582 tests, 7 pre-existing failures, 0
new" claim exactly. The one open item is a narrow, additive-robustness edge case (CR-01's timed
abandon-window) that was fixed after UAT approval and is code-verified but not yet re-confirmed
on real hardware — routed to human verification rather than treated as a blocker, since it does
not affect any of the phase's actual delivered capability (converting images and landing them
in Tray, which is fully proven end-to-end on-device).

---

_Verified: 2026-07-30_
_Verifier: Claude (gsd-verifier)_
