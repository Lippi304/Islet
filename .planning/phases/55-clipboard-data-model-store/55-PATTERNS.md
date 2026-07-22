# Phase 55: Clipboard Data Model + Store - Pattern Map

**Mapped:** 2026-07-22
**Files analyzed:** 3 (2 source + 1 test)
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Clipboard/ClipboardItem.swift` | model (pure value type) | CRUD (passive shape) | `Islet/Shelf/ShelfItem.swift` | role-match (shape twin; new associated-value enum has no direct codebase analog — see "No Analog Found") |
| `Islet/Clipboard/ClipboardStore.swift` | store (pure reducer) | CRUD (append/evict/clear, in-memory) | `Islet/Shelf/ShelfLogic.swift` (shape) + `Islet/Notch/IslandResolver.swift` `TransientQueue` (cap/FIFO mechanics) | exact (composite of two precedents, both explicitly named in CONTEXT.md) |
| `IsletTests/ClipboardStoreTests.swift` | test | request-response (pure unit) | `IsletTests/ShelfLogicTests.swift` | exact |

## Pattern Assignments

### `Islet/Clipboard/ClipboardItem.swift` (model, CRUD/passive shape)

**Analog:** `Islet/Shelf/ShelfItem.swift` (full file, 16 lines)

**Full analog file:**
```swift
import Foundation

// Phase 19 / SHELF-08 — the PURE shelf item value. Like DeviceReading and
// PowerActivity, this is a plain Foundation-only struct — no AppKit, no
// Cocoa file APIs — so ShelfLogic's append/remove/dedupe rules are
// unit-tested in milliseconds. Plan 19-01 Task 2 (ShelfFileStore) provides
// the real FileManager copy/delete mechanics around this passive value;
// this file only defines its shape.
struct ShelfItem: Equatable {
    let id: UUID
    let originalURL: URL   // D-04: shelf never writes/moves/deletes this — read-only source
    var localURL: URL      // D-03: populated immediately on add (session-temp copy)
    let filename: String
    let addedAt: Date
}
```

**What to copy:** plain Foundation-only `struct`, `Equatable` conformance, `import Foundation` only (no AppKit), a doc comment naming the phase/decision IDs that shaped the shape, `let id: UUID` as first field.

**What NOT to copy:** `ShelfItem` has no `Kind`-style discrimination — it is flat fields only. `ClipboardItem` needs one new thing `ShelfItem` doesn't model: the `Kind` enum with associated values (`case text(String)`, `case image(Data)`). No existing file in this codebase demonstrates an associated-value enum — this is genuinely new ground (see "No Analog Found" below). Also add `Codable` conformance (`ShelfItem` doesn't have it, but RESEARCH.md Pitfall 3 recommends adding it now for Phase 56's persistence, and `Codable` synthesizes for free over `UUID`/`Date`/`String`/`Data`).

**Recommended shape (from RESEARCH.md, verified against Swift's automatic-synthesis guarantee):**
```swift
struct ClipboardItem: Equatable, Codable {
    let id: UUID
    var kind: Kind
    var timestamp: Date

    enum Kind: Equatable, Codable {
        case text(String)
        case image(Data)
    }
}
```

---

### `Islet/Clipboard/ClipboardStore.swift` (store, CRUD/in-memory reducer)

**Analog 1 (shape/API surface):** `Islet/Shelf/ShelfLogic.swift` (full file, 39 lines)

```swift
import Foundation

// Phase 19 / SHELF-08 — the shelf's append/remove/dedupe/clear rules as a PURE value
// type. Mirrors TransientQueue (Islet/Notch/IslandResolver.swift): a struct with
// mutating func operations, no AppKit, no FileManager, no Timer/clock inside — the
// controller (Plan 19-01 Task 3, ShelfCoordinator) is the one that performs the actual
// file copy/delete around calls into this type. D-06: append-only, oldest-first
// ordering. D-01/D-02: duplicate detection keyed on originalURL only, a silent no-op
// that leaves the existing item's position/addedAt untouched.
struct ShelfLogic: Equatable {
    private(set) var items: [ShelfItem] = []

    @discardableResult
    mutating func append(_ item: ShelfItem) -> Bool {
        guard !items.contains(where: { $0.originalURL == item.originalURL }) else { return false }
        items.append(item)
        return true
    }

    @discardableResult
    mutating func remove(id: UUID) -> ShelfItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        return items.remove(at: index)
    }

    @discardableResult
    mutating func clear() -> [ShelfItem] {
        let removed = items
        items.removeAll()
        return removed
    }
}
```

**What to copy:** `private(set) var items: [T] = []` storage, `@discardableResult mutating func` API shape, `Equatable` on the store struct itself, pure in-memory logic with zero I/O/AppKit imports, a doc comment stating what this file explicitly does NOT do (mirrors ShelfLogic's "no FileManager, no Timer" framing — adapt to "no NSPasteboard, no disk I/O").

**CRITICAL — what NOT to copy (this is the single most likely implementation mistake per RESEARCH.md Pitfall 1):** `ShelfLogic.append`'s dedupe branch (`guard !items.contains(where: ...) else { return false }`) silently no-ops on a duplicate and leaves the store untouched. CONTEXT.md D-02 explicitly requires the OPPOSITE for `ClipboardStore`: a duplicate (exact text match or byte-identical image `Data`) must move the *existing* entry to the top with a refreshed timestamp — never a silent no-op, never a second entry.

**Analog 2 (cap/FIFO eviction mechanics):** `Islet/Notch/IslandResolver.swift:287-303` (`TransientQueue`)

```swift
// Islet/Notch/IslandResolver.swift:287-303
struct TransientQueue {
    private(set) var head: ActiveTransient?
    private var pending: [ActiveTransient] = []
    let maxDepth = 2

    var pendingCount: Int { pending.count }

    mutating func enqueue(_ t: ActiveTransient) -> Bool {
        if head == nil { head = t; return true }
        if head == t || pending.contains(t) { return false }   // D-03 dedup (head + pending)
        pending.append(t)
        if pending.count > maxDepth { pending.removeFirst() }   // D-03 bound (drop oldest pending)
        return false
    }
}
```

**What to copy:** `let maxDepth = 2` → adapt to `let cap = 30` — a plain inline instance constant on the struct itself (CONTEXT.md D-01 explicitly names this exact line as the pattern to mirror, NOT a shared/global constants file). The overflow-drop line `if pending.count > maxDepth { pending.removeFirst() }` → adapt directly to `if items.count > cap { items.removeFirst() }`.

**Composite recommended shape (from RESEARCH.md, combining both analogs + D-02's departure):**
```swift
struct ClipboardStore: Equatable {
    private(set) var items: [ClipboardItem] = []
    let cap = 30   // D-01: plain inline let, mirrors TransientQueue.maxDepth — not configurable, not shared

    // D-02: exact text match, or byte-identical image Data, counts as a duplicate.
    // A duplicate moves to the top with `item`'s (fresh) timestamp instead of being
    // appended as a new entry.
    mutating func append(_ item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.kind == item.kind }) {
            items.remove(at: index)
            items.append(item)   // reinsert at the "newest" end with the refreshed timestamp
            return
        }
        items.append(item)
        if items.count > cap { items.removeFirst() }   // D-01: FIFO evict oldest past cap
    }

    mutating func clear() {
        items.removeAll()
    }
}
```

**Error handling / validation:** None — per CONTEXT.md D-03, `append` accepts content of any size unconditionally, no validation, no error type, no throwing. This mirrors both analogs (`ShelfLogic` and `TransientQueue` are also non-throwing, no validation).

---

### `IsletTests/ClipboardStoreTests.swift` (test, request-response/pure unit)

**Analog:** `IsletTests/ShelfLogicTests.swift` (full file, 93 lines)

**Imports pattern** (lines 1-2):
```swift
import XCTest
@testable import Islet
```

**File-level doc comment convention** (lines 4-7):
```swift
// Phase 19 / SHELF-08 — regression coverage for ShelfLogic's PURE append/remove/clear/
// dedupe rules. Mirrors IslandResolverTests.swift's TransientQueue section: one test
// method per behavior, a fresh `var logic = ShelfLogic()` per test, no shared fixture,
// no setUp/tearDown, no mocking framework.
```

**Core test pattern** (lines 10-26, `testAppendAddsToEndInDropOrder`):
```swift
func testAppendAddsToEndInDropOrder() {
    var logic = ShelfLogic()
    let a = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/a.pdf"),
                       localURL: URL(fileURLWithPath: "/tmp/a.pdf"), filename: "a.pdf",
                       addedAt: Date(timeIntervalSinceReferenceDate: 0))
    // ... more fixtures inline, no shared setUp
    XCTAssertTrue(logic.append(a))
    XCTAssertEqual(logic.items.map(\.filename), ["a.pdf", "b.pdf", "c.pdf"])
}
```

**Dedupe test pattern to ADAPT (not copy verbatim — behavior differs)** (lines 28-40, `testAppendDuplicateOriginalURLIsSilentNoOp`):
```swift
func testAppendDuplicateOriginalURLIsSilentNoOp() {
    var logic = ShelfLogic()
    let original = ShelfItem(/* ... */)
    let dupe = ShelfItem(/* same originalURL */)
    XCTAssertTrue(logic.append(original))
    XCTAssertFalse(logic.append(dupe))
    XCTAssertEqual(logic.items, [original])   // unchanged — dupe never entered
}
```
**Do not port this assertion shape.** `ClipboardStore`'s equivalent test must assert the OPPOSITE contract per D-02: the duplicate causes the existing item to move to the top (or end, per chosen ordering direction) with a refreshed timestamp — write an assertion like `XCTAssertEqual(store.items.last?.timestamp, dupe.timestamp)` and `XCTAssertEqual(store.items.count, <unchanged count>)`, never `XCTAssertFalse`.

**Clear test pattern** (lines 77-91, `testClearEmptiesAndReturnsAllItemsInOrder`):
```swift
func testClearEmptiesAndReturnsAllItemsInOrder() {
    var logic = ShelfLogic()
    // ... append a, b
    let removed = logic.clear()
    XCTAssertEqual(removed, [a, b])
    XCTAssertTrue(logic.items.isEmpty)
}
```
Note: RESEARCH.md's recommended `ClipboardStore.clear()` signature is `mutating func clear()` (no return value) rather than `ShelfLogic.clear()`'s `-> [ShelfItem]` return — adapt the test to just assert `store.items.isEmpty` post-call, no `removed` capture needed.

**Cap/FIFO eviction test — secondary analog:** `IsletTests/IslandResolverTests.swift:598` `testQueueBoundedDropsOldestPending` (`TransientQueue`'s cap-eviction test) — same structural idea as `testAppendEvictsOldestPastCap` in RESEARCH.md's Code Examples section: append past the bound, assert count caps and the oldest entry is gone.

**Test file structure to copy:** flat `IsletTests/` directory (no subfolders), one `XCTestCase` subclass, one test method per behavior, fresh instance per test (`var store = ClipboardStore()`), no `setUp()`/`tearDown()`, no shared fixtures/mocking framework, `@testable import Islet`.

---

## Shared Patterns

### Pure value type / zero I/O discipline
**Source:** `Islet/Shelf/ShelfItem.swift`, `Islet/Shelf/ShelfLogic.swift`, `Islet/Notch/IslandResolver.swift` `TransientQueue`
**Apply to:** both `ClipboardItem.swift` and `ClipboardStore.swift`
- `import Foundation` only — no `import AppKit`, no `NSPasteboard`, no `FileManager` calls anywhere in either file. This is build-time-verifiable (a stray import is itself a violation) and is explicitly SC-4/SC-1 of this phase.
- No `Timer`/clock/async inside the store — all mutation happens synchronously via `mutating func` calls driven by an external caller (future `ClipboardMonitor` in Phase 57, out of scope here).

### Inline cap constant (not shared/global)
**Source:** `Islet/Notch/IslandResolver.swift:290` (`let maxDepth = 2`)
**Apply to:** `ClipboardStore.swift`
```swift
let cap = 30   // plain inline let, mirrors TransientQueue.maxDepth — not configurable, not shared
```
Do not create a global/shared constants file for this value — CONTEXT.md D-01 explicitly rejects that (the only existing convention for referencing a cap elsewhere is a comment, e.g. `DeviceCoordinator.swift:72`, never a shared value import).

### `@discardableResult mutating func` API shape
**Source:** `Islet/Shelf/ShelfLogic.swift:16-21, 25-29, 33-38`
**Apply to:** `ClipboardStore.swift` methods that return a meaningful value (if any are added beyond `append`/`clear`)
```swift
@discardableResult
mutating func append(_ item: ShelfItem) -> Bool { /* ... */ }
```
Note: RESEARCH.md's recommended `ClipboardStore.append`/`clear` signatures are `Void`-returning (no `@discardableResult` needed) — only apply this pattern if the chosen `ClipboardStore` API surface ends up returning a value.

### Flat pure-unit test convention
**Source:** `IsletTests/ShelfLogicTests.swift` (whole file)
**Apply to:** `IsletTests/ClipboardStoreTests.swift`
- `import XCTest` + `@testable import Islet`, no other imports.
- One `final class XTests: XCTestCase`, flat in `IsletTests/` (no nested folders).
- Fresh `var store = ClipboardStore()` per test method — no `setUp()`/`tearDown()`, no shared fixture, no mocking framework.
- Inline fixture construction per test (build `ClipboardItem` values directly in the test body, not via a factory helper).

## No Analog Found

| File/Element | Role | Data Flow | Reason |
|---------------|------|-----------|--------|
| `ClipboardItem.Kind` enum (associated-value discrimination) | model (sub-type) | N/A | No existing associated-value enum exists in this codebase. The three closest kind-discrimination enums — `QuickAddKind`, `OSDKeyKind`, `PermissionKind` — are all no-payload enums (pure `case a, case b` shape), structurally different from what `Kind` needs (`case text(String)`, `case image(Data)`). RESEARCH.md's Pattern 1 supplies standard-Swift guidance instead (automatic `Equatable`/`Codable` synthesis works unchanged for associated-value enums when every payload type conforms). Planner should use RESEARCH.md's Pattern 1 code example directly rather than search for a codebase precedent that doesn't exist. |

## Metadata

**Analog search scope:** `Islet/Shelf/`, `Islet/Notch/IslandResolver.swift`, `IsletTests/ShelfLogicTests.swift`, `IsletTests/IslandResolverTests.swift` (cited, not re-read — RESEARCH.md already pinpoints `testQueueBoundedDropsOldestPending` at line 598), plus a targeted check for existing associated-value enums (none found; `QuickAddKind`/`OSDKeyKind`/`PermissionKind` confirmed no-payload per RESEARCH.md's own prior grep).
**Files scanned:** 5 read directly (`ShelfItem.swift`, `ShelfLogic.swift`, `ShelfLogicTests.swift`, `IslandResolver.swift` lines 270-334, plus CONTEXT.md/RESEARCH.md as source-of-truth for file list and prior codebase grep results)
**Pattern extraction date:** 2026-07-22
