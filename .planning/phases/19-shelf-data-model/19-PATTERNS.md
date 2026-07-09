# Phase 19: Shelf Data Model - Pattern Map

**Mapped:** 2026-07-09
**Files analyzed:** 3 (2 source, 1 test; ShelfItem + ShelfLogic ship in one file per RESEARCH-less small-phase convention, or split — see discretion note below)
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|---------------|
| `Islet/Shelf/ShelfItem.swift` (or `Islet/Notch/ShelfItem.swift`) | model | CRUD (value struct) | `Islet/Notch/DeviceActivity.swift` (`DeviceReading` struct, lines 21-31) | role-match |
| `Islet/Shelf/ShelfLogic.swift` (or `Islet/Notch/ShelfLogic.swift`) | model / service (pure reducer) | CRUD (append/remove/clear/dedupe) | `Islet/Notch/IslandResolver.swift` (`TransientQueue` struct, lines 129-180) | exact |
| `IsletTests/ShelfLogicTests.swift` | test | CRUD | `IsletTests/IslandResolverTests.swift` (TransientQueue section, lines 177-341) | exact |

No `ShelfItemTests.swift` is separately implied — `DeviceActivityTests.swift` shows plain-struct construction is normally tested inline within the logic test file when the struct itself has no non-trivial functions (see D-01/D-02 dedupe-by-`originalURL` logic, which lives on `ShelfLogic`, not `ShelfItem`). If `ShelfItem` grows a non-trivial computed property or init validation later, split out `ShelfItemTests.swift` then — not needed for this phase's flat model.

**Where files live:** CONTEXT.md leaves this to discretion. No `Islet/Shelf/` folder exists yet; `Islet/Notch/` is the established home for cross-cutting pure-Foundation models (`DeviceActivity.swift`, `IslandResolver.swift`) even though they're not literally about the notch window. Given the shelf is its own independent `@Published` axis (explicitly NOT part of `IslandPresentation`/`TransientQueue`), creating a new `Islet/Shelf/` folder is the better structural signal — it is auto-globbed by `project.yml`'s `path: Islet` (no `project.yml` edit needed, confirmed lines 37-38) and keeps the "shelf is orthogonal to the island" boundary visible in the file tree, mirroring how `Calendar/`, `Weather/`, `Location/` each got their own top-level folder once they became a distinct axis.

## Pattern Assignments

### `Islet/Shelf/ShelfItem.swift` (model, CRUD)

**Analog:** `Islet/Notch/DeviceActivity.swift` lines 1-31 (header comment convention + `DeviceReading` struct)

**Imports pattern** (line 1):
```swift
import Foundation
```
No AppKit/SwiftUI — matches D-nothing here, just the project-wide pure-seam convention CONTEXT.md calls out explicitly.

**Header comment convention** (mirror `DeviceActivity.swift` lines 3-17 style — phase/requirement tag, framework-purity rationale, one paragraph on WHY untrusted/derived fields are shaped the way they are):
```swift
// Phase 19 / SHELF-08 — the PURE shelf item value. Like DeviceReading and
// PowerActivity, this is a plain Foundation-only struct — no AppKit, no
// Cocoa file APIs — so ShelfLogic's append/remove/dedupe rules are
// unit-tested in milliseconds. Plan NN wires the real drag-and-drop /
// FileManager copy (D-03) around this value; this file only defines its shape.
```

**Core struct pattern** (mirror `DeviceReading`'s flat `let` fields + trailing `Equatable`):
```swift
struct ShelfItem: Equatable {
    let id: UUID
    let originalURL: URL     // D-04: shelf never writes/moves/deletes this — read-only source
    var localURL: URL        // D-03: populated immediately on add (session-temp copy)
    let filename: String
    let addedAt: Date
}
```
`id` uses plain `UUID` (CONTEXT.md discretion note explicitly names this as the expected default — `DeviceReading` has no `id` field to copy from since transients are compared by full-value `Equatable`, not identity; `ShelfItem` needs identity because duplicate `filename`s with different `originalURL` must coexist as distinct items — D-01).

**Note:** No existing FileManager/`NSTemporaryDirectory()` copy-on-add code exists anywhere in the codebase to copy a pattern from (grep confirmed zero hits). D-03's temp-copy mechanics and D-05's delete-on-removal are genuinely new — flagged under "No Analog Found" below. `ShelfItem` itself stays a passive value; the copy/delete side effects belong on whatever owns `ShelfLogic` in a later phase (Phase 20+), consistent with `TransientQueue` being side-effect-free and DeviceCoordinator owning the IO.

---

### `Islet/Shelf/ShelfLogic.swift` (model/service, CRUD)

**Analog:** `Islet/Notch/IslandResolver.swift` lines 123-180 (`TransientQueue` struct — direct structural analog named in CONTEXT.md)

**Imports pattern** (line 1 of `IslandResolver.swift`):
```swift
import Foundation
```

**Header comment convention** (mirror lines 123-128 — cites the requirement/decision IDs, states the "no Timer/clock inside" purity constraint, and who calls the mutating methods):
```swift
// Phase 19 / SHELF-08 — the shelf's append/remove/dedupe/clear rules as a PURE value
// type. Mirrors TransientQueue: a struct with mutating func operations, no AppKit, no
// FileManager, no Timer/clock inside — the controller (a later phase) is the one that
// performs the actual file copy/delete around calls into this type. D-06: append-only,
// oldest-first ordering. D-01/D-02: duplicate detection keyed on originalURL only, a
// silent no-op that leaves the existing item's position/addedAt untouched.
```

**Core CRUD pattern — struct + `private(set) var` + `mutating func`** (mirror `TransientQueue` lines 129-153 shape exactly):
```swift
struct ShelfLogic: Equatable {
    private(set) var items: [ShelfItem] = []

    // D-06: append-only, oldest-first. D-01/D-02: a duplicate originalURL is a silent
    // no-op — returns false, the existing item's position and addedAt are untouched.
    // Returns true iff `item` was actually appended.
    @discardableResult
    mutating func append(_ item: ShelfItem) -> Bool {
        guard !items.contains(where: { $0.originalURL == item.originalURL }) else { return false }
        items.append(item)
        return true
    }

    // Removes the item with the given id, if present. Returns the removed item (D-05's
    // caller uses this to know which localURL to delete) or nil if no match.
    @discardableResult
    mutating func remove(id: UUID) -> ShelfItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        return items.remove(at: index)
    }

    // Clears every item. Returns the removed items (D-05's caller deletes each localURL).
    @discardableResult
    mutating func clear() -> [ShelfItem] {
        let removed = items
        items.removeAll()
        return removed
    }
}
```
This mirrors `TransientQueue`'s exact idiom: `private(set) var` exposed state, no stored closures, no Combine — the struct is a pure reducer; a later phase's controller supplies the `@Published var shelfLogic: ShelfLogic` wrapper (mirrors how `NotchWindowController` owns `var transientQueue = TransientQueue()` today) and performs the `FileManager` copy/delete side effects around these calls, exactly as `DeviceCoordinator` performs IOBluetooth/battery IO around `TransientQueue`'s pure calls.

**Error handling pattern:** None needed — every operation here is TOTAL (mirrors `TransientQueue.advance()`/`removeAll(where:)`, which never throw; `IslandResolver.swift`'s functions are likewise all total, no `throws`, no optionals-as-errors beyond plain `nil` returns for "no match").

**Validation pattern:** Equality-based dedup only (`$0.originalURL == item.originalURL`), same shape as `TransientQueue.enqueue`'s `if head == t || pending.contains(t)` dedup check (line 141) — no separate validation layer.

---

### `IsletTests/ShelfLogicTests.swift` (test)

**Analog:** `IsletTests/IslandResolverTests.swift` lines 1-14 (header) + lines 177-341 (`TransientQueue` test section — one `func test...` per behavior, `var q = TransientQueue()` local instance per test, no shared fixture/setUp)

**Imports pattern** (lines 1-2):
```swift
import XCTest
@testable import Islet
```

**Header comment convention** (mirror lines 1-14 — states purity rationale, no fakes/mocking framework, no shared fixture):
```swift
import XCTest
@testable import Islet

// Phase 19 / SHELF-08 — regression coverage for ShelfLogic's PURE append/remove/clear/
// dedupe rules. Mirrors IslandResolverTests.swift's TransientQueue section: one test
// method per behavior, a fresh `var logic = ShelfLogic()` per test, no shared fixture,
// no setUp/tearDown, no mocking framework.
final class ShelfLogicTests: XCTestCase {
```

**Core test pattern** (mirror the `TransientQueue` test shape at lines 182-235, e.g. `testEnqueueIntoEmptyShowsImmediately`/`testQueueDedupsDuplicateHead`):
```swift
func testAppendAddsToEndInDropOrder() {
    // D-06: new items append to the end, oldest-first.
    var logic = ShelfLogic()
    let a = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/a.pdf"),
                       localURL: URL(fileURLWithPath: "/tmp/a.pdf"), filename: "a.pdf", addedAt: Date())
    let b = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/b.pdf"),
                       localURL: URL(fileURLWithPath: "/tmp/b.pdf"), filename: "b.pdf", addedAt: Date())
    XCTAssertTrue(logic.append(a))
    XCTAssertTrue(logic.append(b))
    XCTAssertEqual(logic.items.map(\.filename), ["a.pdf", "b.pdf"])
}

func testAppendDuplicateOriginalURLIsSilentNoOp() {
    // D-01/D-02: same originalURL → no-op, existing item's position/addedAt untouched.
    var logic = ShelfLogic()
    let original = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/a.pdf"),
                              localURL: URL(fileURLWithPath: "/tmp/a.pdf"), filename: "a.pdf",
                              addedAt: Date(timeIntervalSinceReferenceDate: 0))
    let dupe = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/a.pdf"),
                          localURL: URL(fileURLWithPath: "/tmp/a-copy.pdf"), filename: "a.pdf",
                          addedAt: Date(timeIntervalSinceReferenceDate: 999))
    XCTAssertTrue(logic.append(original))
    XCTAssertFalse(logic.append(dupe))
    XCTAssertEqual(logic.items, [original])   // unchanged — dupe never entered
}
```
Structurally identical to `testEnqueueIntoEmptyShowsImmediately` (fresh value, call mutating method, assert both the return value AND the resulting state) and `testQueueDedupsDuplicateHead` (dedup returns false, state unchanged).

**Error handling / validation in tests:** None — mirrors `IslandResolverTests.swift` throughout: plain `XCTAssertEqual`/`XCTAssertTrue`/`XCTAssertFalse`, no expectations/async needed since `ShelfLogic` has no Dispatch/timer surface (unlike `DeviceCoordinatorTests.swift`'s `XCTestExpectation` usage, which is only needed there because of `DispatchQueue.main.asyncAfter` — not applicable to this phase's pure struct).

---

## Shared Patterns

### Pure-Foundation-only seam
**Source:** `Islet/Notch/IslandResolver.swift` line 1, `Islet/Notch/DeviceActivity.swift` line 1, `Islet/Notch/ActivityCoordinator.swift` line 1
**Apply to:** Both `ShelfItem.swift` and `ShelfLogic.swift`
```swift
import Foundation
```
No `AppKit`, no `SwiftUI`, no `Cocoa`. This is the single most load-bearing convention for this phase — CONTEXT.md explicitly calls it out as mandatory, and every existing model file in this codebase (`DeviceActivity`, `IslandResolver`, `PowerActivity`, `NowPlayingPresentation`) enforces it so the type stays unit-testable in milliseconds without booting AppKit/a window.

### Struct + `mutating func`, never a class
**Source:** `Islet/Notch/IslandResolver.swift` `TransientQueue` (lines 129-180)
**Apply to:** `ShelfLogic.swift`
Value semantics, `private(set) var` for read-only external state, `mutating func` for each operation. A later phase's `@MainActor` controller (mirrors `DeviceCoordinator`, `@MainActor final class`) will own a `@Published var shelfLogic: ShelfLogic = ShelfLogic()` and call these mutating methods — but that wiring is explicitly out of scope for Phase 19 (see CONTEXT.md `<domain>` "Out of scope").

### Flat test-per-behavior, no shared fixture
**Source:** `IsletTests/IslandResolverTests.swift` lines 1-14, `IsletTests/DeviceActivityTests.swift` lines 1-15
**Apply to:** `IsletTests/ShelfLogicTests.swift`
One `XCTestCase` subclass named `{TypeName}Tests`, one `func test<Behavior>()` per rule, each test constructs its own fresh value inline (`var logic = ShelfLogic()`) — no `setUp()`/`tearDown()`, no shared instance var, no mocking framework.

## No Analog Found

| File/Concern | Role | Data Flow | Reason |
|------|------|-----------|--------|
| Session-temp file copy mechanics (D-03: copy dropped file's bytes into `NSTemporaryDirectory()` subfolder on add) | utility (file I/O) | file-I/O | Zero existing `FileManager`/`NSTemporaryDirectory()` usage anywhere in `Islet/` (grep confirmed). This is genuinely new file-I/O territory with no in-repo precedent to copy from — CONTEXT.md's own discretion note ("pick whatever is simplest to wire correctly and clean up") acknowledges this. Note this mechanic is likely NOT part of Phase 19 proper per the `<domain>` boundary ("zero persistence" pure-model phase) — `ShelfItem.localURL` is just a field; the actual `FileManager.copyItem` call belongs to whichever later phase wires drag-in (Phase 22) or an earlier plan within this phase if CONTEXT.md's D-03 is judged in-scope now. Flag for the planner to resolve scope explicitly in PLAN.md. |
| Delete-on-removal (D-05: `localURL` deleted on remove/clear/quit) | utility (file I/O) | event-driven | Same reasoning as above — no existing delete-temp-file precedent in the codebase. Also likely belongs with whichever plan actually performs the FileManager copy (same file, symmetric operation), not with the pure `ShelfLogic.remove`/`clear` methods themselves (which only need to return the removed `ShelfItem`(s) so a caller can act on `localURL`). |

## Metadata

**Analog search scope:** `Islet/Notch/`, `IsletTests/` (grep across all of `Islet/` for UUID/Identifiable/FileManager/NSTemporaryDirectory usage; directory listing of `Islet/` top-level folders for the folder-placement decision)
**Files scanned:** `Islet/Notch/IslandResolver.swift`, `Islet/Notch/DeviceCoordinator.swift`, `Islet/Notch/ActivityCoordinator.swift`, `Islet/Notch/DeviceActivity.swift`, `IsletTests/DeviceCoordinatorTests.swift`, `IsletTests/DeviceActivityTests.swift`, `IsletTests/IslandResolverTests.swift`, `project.yml`
**Pattern extraction date:** 2026-07-09
