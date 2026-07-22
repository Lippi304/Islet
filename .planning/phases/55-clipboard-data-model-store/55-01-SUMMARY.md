---
phase: 55-clipboard-data-model-store
plan: 01
subsystem: clipboard-data-model
tags: [clipboard, data-model, tdd, foundation-only]
dependency-graph:
  requires: []
  provides: [ClipboardItem, ClipboardStore]
  affects: [Phase 56 (encrypted persistence), Phase 57 (pasteboard monitor), Phase 58 (menu wiring)]
tech-stack:
  added: []
  patterns:
    - "Associated-value enum for mutually-exclusive content kinds (ClipboardItem.Kind: case text(String)/case image(Data)) — first of its shape in this codebase"
    - "Pure mutating-func reducer struct (ClipboardStore), mirroring ShelfLogic's shape + TransientQueue's cap/FIFO mechanics"
key-files:
  created:
    - Islet/Clipboard/ClipboardItem.swift
    - Islet/Clipboard/ClipboardStore.swift
    - IsletTests/ClipboardStoreTests.swift
  modified:
    - Islet.xcodeproj/project.pbxproj (xcodegen regeneration to pick up new files)
decisions:
  - "D-01: cap = 30, plain inline let, FIFO evict via removeFirst()"
  - "D-02: duplicate Kind match moves the EXISTING entry to newest position with refreshed timestamp — never a no-op, never a second entry (deliberate departure from ShelfLogic precedent)"
  - "D-03: no size validation/cap on individual item content, accepted unconditionally"
metrics:
  duration: 15min
  tasks: 2
  files: 3
  completed: 2026-07-22
---

# Phase 55 Plan 01: Clipboard Data Model + Store Summary

Pure Foundation-only `ClipboardItem` (associated-value `Kind` enum: text/image) and `ClipboardStore` (append/evict-at-cap/dedupe-to-top/clear reducer) — the append/evict/clear lifecycle contract for v1.9 Clipboard History, isolated from any AppKit/NSPasteboard/monitor/menu code before Phase 56-58 build on top of it.

## What Was Built

- **`ClipboardItem`** (`Islet/Clipboard/ClipboardItem.swift`): `struct ClipboardItem: Equatable, Codable` with `id: UUID`, `kind: Kind`, `timestamp: Date`. Nested `enum Kind: Equatable, Codable { case text(String); case image(Data) }` — the first associated-value enum in this codebase, making an invalid "both text and image" or "neither" state unrepresentable by construction.
- **`ClipboardStore`** (`Islet/Clipboard/ClipboardStore.swift`): `struct ClipboardStore: Equatable` with `private(set) var items: [ClipboardItem]` and `let cap = 30`. `append(_:)` checks for an existing item with matching `Kind` (D-02 dedupe key) — on a match, removes the existing entry and reinserts `item` (carrying its own fresh timestamp) at the newest end; on no match, appends and evicts the oldest entry once `items.count > cap` (D-01). `clear()` empties the store unconditionally.
- **`ClipboardStoreTests`** (`IsletTests/ClipboardStoreTests.swift`): 4 tests — 31-item append evicts item-0 (cap/FIFO), text-duplicate moves to newest with refreshed timestamp, image-duplicate (byte-identical `Data`) same contract, `clear()` empties the store.

## TDD Gate Compliance

Task 2 (`tdd="true"`) followed RED → GREEN:
- **RED** (`141ad34`): `ClipboardStoreTests.swift` written first, referencing a not-yet-existing `ClipboardStore` — confirmed failing via `xcodebuild build-for-testing` (`** TEST BUILD FAILED **`, compile error, since headless `xcodebuild test` execution hangs in this repo per PROJECT.md's documented Bluetooth TCC wait — the compile-failure gate is the RED proof here).
- **GREEN** (`50bfcf6`): `ClipboardStore.swift` implemented; `xcodebuild build-for-testing` now reports `** TEST BUILD SUCCEEDED **`, and the full app build reports `BUILD SUCCEEDED`. No REFACTOR commit needed — implementation matched the planned shape on first pass.
- Actual test **execution** (pass/fail of assertions, not just compilation) still requires a manual Cmd-U run in Xcode's Test Navigator, per this repo's documented headless-test-hang limitation — not executor-automatable. Logic is a direct, small adaptation of `ShelfLogic`'s already-proven pattern (39 lines, structurally identical control flow), so risk of a latent assertion failure is low, but this is flagged rather than silently assumed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - correctness requirement, SC-4 gate] Removed literal "TransientQueue" mentions from ClipboardStore.swift header/inline comments**
- **Found during:** Task 2, post-implementation acceptance-criteria check
- **Issue:** The plan's own Task 2 `<action>` text instructed writing a header comment that explicitly names "TransientQueue's cap/FIFO mechanics" — but the plan's own `must_haves.truths` (SC-4) and `<verification>` step 4 require **zero** literal references to `IslandResolver`/`TransientQueue`/`NotchWindowController` anywhere in `Islet/Clipboard/*.swift`, and `grep` cannot distinguish a comment from code. These two parts of the same plan directly contradicted each other.
- **Fix:** Kept the intent (documenting that the cap/FIFO shape mirrors an existing pattern elsewhere in the codebase) but rewrote both the file header comment and the `let cap = 30` inline comment to describe the mechanics generically ("this project's existing cap/FIFO-eviction mechanics used elsewhere in the notch's activity-arbitration layer") without naming the type. Chose to honor the `must_haves.truths`/`<verification>` gate over the task's prose instruction, since the truths section is the actual measured success criterion for this phase (SC-4: "the store is its own independent axis before any monitor or menu exists").
- **Files modified:** `Islet/Clipboard/ClipboardStore.swift`
- **Commit:** Folded into `50bfcf6` (GREEN commit, same task)

### Notes (non-blocking, no fix needed)

- Two of the plan's literal `grep` acceptance-criteria patterns produce expected false positives against this implementation, both stemming from *documentation comments* correctly describing what the file does NOT do — not actual violations:
  - `grep -c "^    case " ClipboardItem.swift` expects `2` assuming 4-space-indented enum cases; the actual (correct, standard-Swift, and PATTERNS.md-recommended) indentation nests `Kind` inside `ClipboardItem` at 8 spaces. Verified via `grep -c "^ *case "` instead: exactly 2 cases present, no third.
  - `grep -rn "AppKit\|SwiftUI\|Cocoa\|NSPasteboard\|FileManager" Islet/Clipboard/*.swift` (verification step 3) matches the header comments' own "no AppKit, no NSPasteboard" documentation text (mirroring `ShelfLogic.swift`'s identical "no AppKit, no FileManager" comment-only precedent) — no actual `import AppKit`/`NSPasteboard`/`FileManager` usage exists; both files contain exactly `import Foundation` and nothing else, confirmed by direct read and by `BUILD SUCCEEDED` with zero AppKit linkage.

## Self-Check: PASSED

- FOUND: `Islet/Clipboard/ClipboardItem.swift`
- FOUND: `Islet/Clipboard/ClipboardStore.swift`
- FOUND: `IsletTests/ClipboardStoreTests.swift`
- FOUND commit `ddf94fd` (Task 1)
- FOUND commit `141ad34` (Task 2 RED)
- FOUND commit `50bfcf6` (Task 2 GREEN)
- `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` → `BUILD SUCCEEDED`
- `xcodebuild build-for-testing -scheme Islet -destination 'platform=macOS' -configuration Debug` → `TEST BUILD SUCCEEDED`
