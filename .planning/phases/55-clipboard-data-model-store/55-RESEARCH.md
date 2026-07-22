# Phase 55: Clipboard Data Model + Store - Research

**Researched:** 2026-07-22
**Domain:** Pure Foundation-only Swift value types + reducer (no AppKit, no NSPasteboard, no I/O)
**Confidence:** HIGH

## Summary

Phase 55 has no open technical questions — it is a direct structural twin of an already-shipped pattern in this exact codebase (Phase 19's `ShelfItem`/`ShelfLogic`), and the milestone-level research (`.planning/research/ARCHITECTURE.md`, `SUMMARY.md`) already specified `ClipboardItem`/`ClipboardStore`'s shape, file location, and component boundaries before this phase-level research even began. The only genuinely new ground is the `Kind` enum's associated-value shape (`case text(String)` / `case image(Data)`) — this codebase has three no-payload kind-discrimination enums (`QuickAddKind`, `OSDKeyKind`, `PermissionKind`) but zero precedent for an associated-value enum, so Swift's standard idiom (not a codebase-specific one) is the applicable guidance there.

Two codebase precedents combine to fully determine this phase's design: `TransientQueue` (`Islet/Notch/IslandResolver.swift:287-303`) supplies the cap/FIFO-eviction mechanics (`let maxDepth` instance constant, `removeFirst()` on overflow), and `ShelfItem`/`ShelfLogic` (`Islet/Shelf/ShelfItem.swift`, `Islet/Shelf/ShelfLogic.swift`) supplies the pure-value-type-plus-pure-reducer file split, the `@discardableResult mutating func` API shape, and the `XCTest`-based, flat-directory (`IsletTests/`) test convention. CONTEXT.md's D-02 (move-to-top-on-duplicate, not silent no-op) is this phase's one deliberate departure from the Shelf precedent, and is the only place a plan-checker/verifier should look for a "did they just copy ShelfLogic verbatim" mistake.

**Primary recommendation:** Build `ClipboardItem` (struct, `Equatable`, `Codable`-ready) and `ClipboardStore` (struct, pure `mutating func`s, no I/O) in a new `Islet/Clipboard/` folder, mirroring `Islet/Shelf/`'s two-file split exactly, with `ClipboardStore.cap = 30` as a plain inline `let` (mirrors `TransientQueue.maxDepth`) and FIFO eviction via `removeFirst()`. Test in `IsletTests/ClipboardItemTests.swift` + `IsletTests/ClipboardStoreTests.swift` (or one combined file — see Open Questions) using plain `XCTestCase`, no fixtures, one `var store = ClipboardStore()` per test.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Clipboard item identity/shape (`ClipboardItem`) | Pure Model (Foundation-only value type) | — | No UI, no system API, no persistence in this phase — a plain data shape, same tier as `ShelfItem`/`PowerReading` |
| Append/evict-at-cap/clear lifecycle (`ClipboardStore`) | Pure Model (Foundation-only reducer) | — | Zero I/O, zero AppKit — same tier as `ShelfLogic`/`TransientQueue`, deliberately isolated from any system-glue tier per CONTEXT.md D-04's "independent axis" success criterion |
| Live pasteboard capture (out of scope, Phase 57) | System Glue (`ClipboardMonitor`, future) | — | Explicitly NOT this phase — `ClipboardStore` must have zero awareness this will exist |
| Encrypted disk persistence (out of scope, Phase 56) | Storage (`ClipboardFileStore`, future) | — | Explicitly NOT this phase — mirrors `ShelfFileStore`'s separation from `ShelfLogic` |
| Menu UI / click-to-restore (out of scope, Phase 58) | Browser/Client-equivalent (`AppDelegate`+`NSMenu`, future) | — | Explicitly NOT this phase |

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01 (Cap):** `ClipboardStore` cap = **30 items**, implemented as a plain inline `let` constant on `ClipboardStore` itself — mirroring `TransientQueue.maxDepth`'s style (`Islet/Notch/IslandResolver.swift:290`), NOT a shared/global constants file, NOT configurable. Eviction is FIFO: appending past the cap drops the oldest entry (`removeFirst()`-style), matching `TransientQueue`'s pattern (`IslandResolver.swift:287-303`).
- **D-02 (Duplicate handling):** Re-copying content already in the store (exact text match, or byte-identical image `Data`) moves the *existing* entry to the top with a refreshed timestamp — does NOT create a duplicate entry, does NOT silently no-op. Deliberate departure from Shelf's `append()` (`ShelfLogic.swift:10-39`), which dedupes on `originalURL` and silently no-ops without reordering. Matches standard clipboard-manager behavior (e.g. Maccy). Equality check mechanics (exact string compare for text, byte compare for image `Data`) are Claude's implementation call.
- **D-03 (Oversized content):** No size cap or truncation on individual items in Phase 55/56 — `ClipboardStore.append` accepts content of any size unconditionally. Revisit only if it becomes a real problem in practice — not a hypothetical to design around now.

### Claude's Discretion

- Internal storage representation of `ClipboardItem.content` for the text/image kind split (e.g. `enum Kind { case text(String); case image(Data) }` shape, associated-value design) — no existing kind-discrimination enum with associated values exists in this codebase, so this is new ground; Claude designs the shape during planning. See Pattern 1 below for the recommended shape.
- Internal list ordering direction (append-at-end vs prepend-at-front) as long as the observable contract holds: newest item retrievable first, oldest evicted first at cap.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope. (3 candidate todos were matcher false-positives on generic keyword overlap, unrelated UI-domain issues — not folded in.)

## Project Constraints (from CLAUDE.md)

- **Swift 5 language mode** (not Swift 6 strict concurrency) — project-wide `SWIFT_VERSION: "5.0"` in `project.yml`. Do not introduce `actor`/`Sendable`-heavy patterns; plain structs and free functions are the norm and sufficient here since this phase has zero concurrency surface.
- **macOS 15.0 deployment target floor** — irrelevant to this phase's pure-Foundation code (no OS-version-gated APIs used), but keep in mind for `Codable`/`Data`/`UUID`/`Date` usage, all of which are long-stable.
- **GSD workflow enforcement**: file edits happen only inside a GSD command context (already satisfied — this is `/gsd:plan-phase` → execute-phase flow).
- No project skills exist (`.claude/skills/`, `.agents/skills/` both absent) — no additional conventions beyond the codebase precedents below.

## Standard Stack

### Core

No new dependencies. This phase uses only Swift standard library + `Foundation` (`UUID`, `Date`, `Data`, `Equatable`, `Codable`).

| Type/API | Source | Purpose | Why Standard |
|----------|--------|---------|---------------|
| `struct` value types | Swift stdlib | `ClipboardItem`, `ClipboardStore` shape | Matches every existing pure-model precedent in this codebase (`ShelfItem`, `TransientQueue`, `PowerReading`) `[VERIFIED: codebase grep]` |
| `UUID`, `Date`, `Data` | Foundation | Item identity, timestamp, image bytes | Already used identically in `ShelfItem` (`id: UUID`, `addedAt: Date`) `[VERIFIED: Islet/Shelf/ShelfItem.swift]` |
| `Equatable` conformance | Swift stdlib | Enables direct `XCTAssertEqual` on items/arrays in tests | `ShelfItem`/`ShelfLogic` both conform, tested this way in `ShelfLogicTests.swift` `[VERIFIED: codebase grep]` |
| `Codable` conformance (recommended, not required by this phase's success criteria) | Foundation | Future-proofs for Phase 56's JSON persistence without a later type change | `.planning/research/ARCHITECTURE.md:45` recommends it explicitly for `ClipboardItem` `[CITED: .planning/research/ARCHITECTURE.md]` |

### Supporting

None — no supporting libraries needed for pure value types.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Plain `[ClipboardItem]` array + FIFO `removeFirst()` | A ring buffer / deque data structure | Unnecessary — cap is only 30 items, `removeFirst()` on a 30-element `Array` is O(n) but n=30 is immaterial; `TransientQueue` already uses the same plain-array approach at a smaller scale and this codebase has no precedent for a custom collection type here |
| One combined `Kind` enum with associated values | Two separate optional properties (`text: String?`, `imageData: Data?`) | Rejected — optionals allow an invalid "both nil" or "both set" state; an associated-value enum makes the invalid state unrepresentable, which is the entire point of D-04's "no partial-state possibility" success criterion |

**Installation:** None — zero new dependencies, nothing to add to `project.yml`'s `packages:` block.

**Version verification:** N/A — no external package versions to verify; this phase uses only Swift/Foundation, which ship with the Xcode 16+ toolchain already pinned in `project.yml`.

## Package Legitimacy Audit

Not applicable — this phase installs no external packages (zero new dependencies, Foundation-only). Skipped per the Package Legitimacy Gate protocol's scope (applies only when installing packages).

## Architecture Patterns

### System Architecture Diagram

```
                    (Phase 55 boundary — everything below is pure, in-memory, synchronous)

  caller (future: ClipboardMonitor,        ┌─────────────────────────┐
  Phase 57 — does NOT exist yet, and       │      ClipboardStore     │
  ClipboardStore has ZERO awareness of it) │  (pure reducer struct)  │
                    │                       │  private(set) items: [ClipboardItem]
                    │  append(ClipboardItem)│  let cap = 30            │
                    ├──────────────────────►│                          │
                    │                       │  append(_:) — D-02:      │
                    │                       │    dup match (text exact │
                    │                       │    / image byte-equal)   │
                    │                       │    → move to top,        │
                    │                       │    refresh timestamp;    │
                    │                       │    else → insert new,    │
                    │                       │    evict oldest if       │
                    │                       │    count > cap (FIFO)    │
                    │                       │                          │
                    │  clear()              │  clear() — empties       │
                    ├──────────────────────►│    items in one call     │
                    │                       └─────────────────────────┘
                    │                                    │
                    │  reads current [ClipboardItem]      │ contains
                    │◄────────────────────────────────────┘
                                                           ▼
                                              ┌─────────────────────────┐
                                              │      ClipboardItem      │
                                              │   (pure value struct)   │
                                              │  id: UUID                │
                                              │  kind: Kind (text/image) │
                                              │  timestamp: Date         │
                                              └─────────────────────────┘

  No arrows leave this box toward NSPasteboard, FileManager, IslandResolver,
  TransientQueue, or NotchWindowController — that isolation is itself the
  phase's success criterion #4, verifiable by reading imports alone.
```

### Recommended Project Structure

```
Islet/
└── Clipboard/                      # NEW top-level folder, sibling to Notch/Shelf/Licensing
    ├── ClipboardItem.swift         # pure model: id, kind (text/image), timestamp
    └── ClipboardStore.swift        # pure reducer: append (with D-02 dedupe-and-move-to-top),
                                     # evict-at-cap, clear — Foundation only, zero I/O

IsletTests/
├── ClipboardItemTests.swift        # Equatable/Kind-construction coverage (if warranted — see Open Questions)
└── ClipboardStoreTests.swift       # append/evict-at-cap/dedupe-move-to-top/clear coverage
```

Rationale for `Islet/Clipboard/` (not nested under `Islet/Notch/`): confirmed directly by `.planning/research/ARCHITECTURE.md:65` — this codebase's folder boundaries track feature *ownership*, not layer (`Notch/` = notch-panel-owned, `Shelf/` = shelf-owned). Clipboard will ultimately be owned by `AppDelegate` (Phase 58), never `NotchWindowController` — a new top-level folder is the correct, already-decided placement, not something this phase needs to re-derive. `[CITED: .planning/research/ARCHITECTURE.md]`

### Pattern 1: Associated-value `Kind` enum (new ground for this codebase)

**What:** A two-case enum with associated values, discriminating text vs. image content while making "has both" or "has neither" unrepresentable.
**When to use:** Whenever a value can be exactly one of N shapes and each shape carries different payload data — the canonical use case for a Swift enum with associated values (this is standard Swift, not codebase-specific; the three existing kind enums in this codebase — `QuickAddKind`, `OSDKeyKind`, `PermissionKind` — all happen to be no-payload because none of their use cases needed a payload, not because of an aversion to the pattern).
**Example:**
```swift
// Islet/Clipboard/ClipboardItem.swift
import Foundation

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
`Equatable`/`Codable` synthesis works automatically for enums with associated values as long as every associated value's type also conforms (`String` and `Data` both do) — no manual `Equatable`/`Codable` implementation is needed. `[VERIFIED: Swift language guarantee — automatic synthesis for enums with all-Equatable/Codable associated values, standard since Swift 4.1]`

### Pattern 2: Cap + FIFO eviction (direct codebase precedent — mirror, don't reinvent)

**What:** A plain inline `let cap = 30` on the reducer struct itself, with `removeFirst()` eviction when the collection exceeds it.
**When to use:** Exactly this phase — CONTEXT.md D-01 explicitly names `TransientQueue.maxDepth` as the pattern to mirror.
**Example (source pattern, from the actual codebase):**
```swift
// Source: Islet/Notch/IslandResolver.swift:287-303 (TransientQueue — direct precedent)
struct TransientQueue {
    private(set) var head: ActiveTransient?
    private var pending: [ActiveTransient] = []
    let maxDepth = 2

    mutating func enqueue(_ t: ActiveTransient) -> Bool {
        if head == nil { head = t; return true }
        if head == t || pending.contains(t) { return false }
        pending.append(t)
        if pending.count > maxDepth { pending.removeFirst() }   // drop oldest on overflow
        return false
    }
}
```
Adapt directly for `ClipboardStore`: `let cap = 30`, and after a genuine new-item append, `if items.count > cap { items.removeFirst() }`.

### Pattern 3: Pure value type + pure reducer, two-file split (direct codebase precedent)

**What:** One file for the passive data shape (`ClipboardItem`), one file for the mutating operations over a collection of it (`ClipboardStore`) — no I/O in either.
**When to use:** Exactly this phase — CONTEXT.md explicitly names `ShelfItem`/`ShelfLogic` as the closest precedent to mirror (minus D-02's dedupe-behavior departure).
**Example (source pattern, from the actual codebase):**
```swift
// Source: Islet/Shelf/ShelfLogic.swift:10-39
struct ShelfLogic: Equatable {
    private(set) var items: [ShelfItem] = []

    @discardableResult
    mutating func append(_ item: ShelfItem) -> Bool {
        guard !items.contains(where: { $0.originalURL == item.originalURL }) else { return false }
        items.append(item)
        return true
    }

    @discardableResult
    mutating func clear() -> [ShelfItem] {
        let removed = items
        items.removeAll()
        return removed
    }
}
```
`ClipboardStore.append(_:)` differs at exactly the dedupe branch (D-02: move-to-top-with-refreshed-timestamp instead of silent no-op) — everything else about the shape (private(set) items, @discardableResult mutating func, Equatable) carries over unchanged.

### Anti-Patterns to Avoid

- **Copying `ShelfLogic`'s dedupe branch verbatim:** `ShelfLogic.append` returns `false` and leaves the store untouched on a duplicate. CONTEXT.md D-02 explicitly requires the opposite behavior for `ClipboardStore` — moving the existing item to the top with a refreshed timestamp. This is the single most likely mistake a plan/implementation could make by over-pattern-matching on the Shelf precedent.
- **Optional-pair content representation** (`text: String?`, `image: Data?` as two separate properties instead of one `Kind` enum): allows invalid states (both set, both nil) that D-04's "no partial-state possibility" success criterion is explicitly designed to rule out.
- **Reaching for `NSPasteboard`, `FileManager`, or any AppKit import anywhere in `Islet/Clipboard/ClipboardItem.swift` or `ClipboardStore.swift`:** this phase's entire point (mirrored from Phase 19's precedent) is that these two files compile and test with zero platform dependency. A stray `import AppKit` or `FileManager` call is itself a build-time-detectable violation of success criterion #1/#4.
- **A shared/global cap constants file:** CONTEXT.md D-01 explicitly rejects this — the cap lives as a plain inline `let` on `ClipboardStore` itself, matching `TransientQueue.maxDepth`'s style, not `DeviceCoordinator.swift:72`'s comment-only convention.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Equality/hashing for the struct | Custom `==` operator | Swift's automatic `Equatable` synthesis | Every field (`UUID`, `Kind` enum of `String`/`Data`, `Date`) already conforms; synthesis is free and less error-prone than a hand-written comparison |
| JSON (de)serialization scaffolding | Custom `init(from:)`/`encode(to:)` | Swift's automatic `Codable` synthesis | Same reasoning — no custom coding keys or transformation needed since every field is directly `Codable` |
| A bounded collection / ring buffer type | Custom `BoundedArray<T>` generic | Plain `[ClipboardItem]` + a `count > cap` check | `TransientQueue` already proves this is sufficient at this scale (30 items); a generic bounded-collection abstraction would be unrequested complexity for a single, non-reused use site |

**Key insight:** Everything this phase needs is either free (Swift's `Equatable`/`Codable` synthesis) or already has a proven, directly-adaptable precedent in this exact codebase (`TransientQueue` for cap/FIFO, `ShelfLogic` for the pure-reducer shape). There is no legitimate reason to write anything more sophisticated than what's shown in the Code Examples section below.

## Common Pitfalls

### Pitfall 1: Copying Shelf's silent-no-op dedupe instead of implementing D-02's move-to-top

**What goes wrong:** A plan or implementation pattern-matches too literally on "ShelfLogic is the precedent to mirror" and reproduces its exact dedupe branch (`guard !items.contains(...) else { return false }`), silently no-opping on a re-copy instead of moving the existing item to the top with a refreshed timestamp.
**Why it happens:** CONTEXT.md explicitly names ShelfLogic as the shape precedent, and it's easy to over-generalize "mirror Shelf" to include its dedupe semantics too, when CONTEXT.md D-02 explicitly calls this out as the one deliberate departure.
**How to avoid:** Write the D-02 dedupe-and-reorder test FIRST (TDD), and have the planner cite D-02 explicitly in the relevant task's must-haves/truths (per this project's own Decision Coverage Gate convention seen in Phase 30/34's STATE.md history).
**Warning signs:** A test asserting `XCTAssertFalse(store.append(dupe))` (Shelf's contract) instead of one asserting the dupe item moved to index 0/end with an updated timestamp and the original entry's position no longer exists.

### Pitfall 2: Representing content as two optional properties instead of an enum

**What goes wrong:** `ClipboardItem` gets `text: String?` and `imageData: Data?` properties instead of one `Kind` enum, allowing a constructed value where both are nil or both are set — undermining D-04's "no partial-state possibility" success criterion.
**Why it happens:** No existing associated-value enum precedent in this codebase might tempt a "match what already exists" instinct toward the simpler-looking optional-pair shape, especially since all three existing kind enums (`QuickAddKind`, `OSDKeyKind`, `PermissionKind`) are no-payload and don't demonstrate the associated-value pattern directly.
**How to avoid:** Use the associated-value enum shape from Pattern 1 above — it is standard Swift, well-documented, and directly satisfies the "no partial-state possibility" requirement by construction (the type system, not a runtime check, prevents the invalid state).
**Warning signs:** Any `ClipboardItem` initializer or property list with more than one optional payload field.

### Pitfall 3: Forgetting `Codable` and having to retrofit it in Phase 56

**What goes wrong:** `ClipboardItem`/`Kind` ship without `Codable` conformance (not required by this phase's own success criteria, which only mention unit-testability), and Phase 56's persistence work then needs a breaking type change or a parallel DTO type.
**Why it happens:** This phase's ROADMAP success criteria don't literally require `Codable` — it's easy to treat it as out of scope.
**How to avoid:** Add `Codable` conformance now (it's free via automatic synthesis, costs nothing, and is explicitly recommended by `.planning/research/ARCHITECTURE.md:45`) even though Phase 55 itself never encodes/decodes anything.
**Warning signs:** Phase 56 planning discovering `ClipboardItem` needs restructuring to support `JSONEncoder`.

### Pitfall 4: Byte-comparing image `Data` where large images make `==` expensive in a hot loop

**What goes wrong:** D-02's dedupe check does a full `Data == Data` comparison against every existing item's image bytes on every append; for large images and a 30-item cap this is not actually a performance problem at this scale, but a plan/implementation might over-engineer a hash-based fast-path pre-emptively.
**Why it happens:** Premature optimization instinct when "compare Data objects" sounds expensive.
**How to avoid:** Just use `Data`'s built-in `==` (byte-for-byte, already optimized in the stdlib/Foundation bridging layer) — CONTEXT.md itself says equality-check mechanics are "not discussed further, no ambiguity the user cared about here," and 30 items × reasonable image sizes is not a scale where this matters. Don't hand-roll a hash pre-check; it's unrequested complexity for a phase that explicitly has zero performance requirement.
**Warning signs:** Any custom hashing/digest logic appearing in `ClipboardStore.append` beyond a plain `==` comparison.

## Code Examples

Verified patterns from this codebase's own source (not external docs — this phase has zero external dependency surface):

### ClipboardItem (pure model)
```swift
// Islet/Clipboard/ClipboardItem.swift
// Mirrors Islet/Shelf/ShelfItem.swift's role: the passive, pure value.
import Foundation

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

### ClipboardStore (pure reducer — append with D-02 dedupe/move-to-top, evict-at-cap, clear)
```swift
// Islet/Clipboard/ClipboardStore.swift
// Mirrors Islet/Shelf/ShelfLogic.swift's role, with the cap/FIFO shape of
// TransientQueue (Islet/Notch/IslandResolver.swift:287-303). D-02: unlike
// ShelfLogic's silent-no-op dedupe, a duplicate here moves the EXISTING
// entry to the top with a refreshed timestamp.
import Foundation

struct ClipboardStore: Equatable {
    private(set) var items: [ClipboardItem] = []
    let cap = 30   // D-01: plain inline let, mirrors TransientQueue.maxDepth — not configurable, not shared

    // D-02: exact text match, or byte-identical image Data, counts as a duplicate.
    // A duplicate moves to the top with `item`'s (fresh) timestamp instead of being
    // appended as a new entry. A genuinely new item is appended, evicting the oldest
    // entry (FIFO) if the cap is exceeded.
    mutating func append(_ item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.kind == item.kind }) {
            items.remove(at: index)
            items.append(item)   // reinsert at the "newest" end with the refreshed timestamp
            return
        }
        items.append(item)
        if items.count > cap { items.removeFirst() }   // D-01: FIFO evict oldest past cap
    }

    // D-04: removes every item in a single call — provably empty by construction.
    mutating func clear() {
        items.removeAll()
    }
}
```
Note: "newest at the end" vs "newest at the front" is Claude's Discretion per CONTEXT.md — the example above appends at the end and evicts via `removeFirst()`; a prepend-at-front + `removeLast()` variant is equally valid as long as the observable contract (newest-first-retrievable, oldest-evicted-first) holds. Whichever direction is chosen, `Kind: Equatable` makes the `$0.kind == item.kind` dedupe check for D-02 work automatically for both text and image cases.

### Test shape (mirrors ShelfLogicTests.swift / IslandResolverTests.swift's TransientQueue section)
```swift
// Source pattern: IsletTests/ShelfLogicTests.swift (structure) +
// IsletTests/IslandResolverTests.swift:598 testQueueBoundedDropsOldestPending (cap-eviction style)
import XCTest
@testable import Islet

final class ClipboardStoreTests: XCTestCase {
    func testAppendEvictsOldestPastCap() {
        var store = ClipboardStore()
        for i in 0..<31 {
            store.append(ClipboardItem(id: UUID(), kind: .text("item-\(i)"), timestamp: Date()))
        }
        XCTAssertEqual(store.items.count, 30)
        XCTAssertFalse(store.items.contains { if case .text("item-0") = $0.kind { return true }; return false })
    }

    func testAppendDuplicateTextMovesToTopWithRefreshedTimestamp() {
        // D-02 regression coverage — the departure from ShelfLogic's silent no-op.
    }

    func testClearEmptiesStore() {
        var store = ClipboardStore()
        store.append(ClipboardItem(id: UUID(), kind: .text("a"), timestamp: Date()))
        store.clear()
        XCTAssertTrue(store.items.isEmpty)
    }
}
```

## State of the Art

Not applicable — this phase has no external ecosystem to track (pure Swift/Foundation value types). No deprecated/outdated APIs are in play.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Codable` conformance should be added now even though not required by this phase's own success criteria | Standard Stack, Pitfall 3 | Low — if the planner disagrees and defers `Codable` to Phase 56, that's a valid alternative; the only cost is a possibly-needed type touch-up in Phase 56 planning, not a redo of Phase 55's core logic |
| A2 | 30-item cap with `Data ==` byte comparison is performance-adequate with no hash pre-check needed | Pitfall 4 | Low — this is a reasoned inference from scale (30 items, no perf requirement stated anywhere in CONTEXT.md/ROADMAP.md), not verified via benchmark; if a future phase discovers real jank, a hash-based fast path is a cheap, isolated follow-up that doesn't touch the public `ClipboardStore` API |

## Open Questions

1. **One test file or two for `ClipboardItem`/`ClipboardStore`?**
   - What we know: `ShelfItem` (the pure model) has no dedicated `ShelfItemTests.swift` in this codebase — only `ShelfLogicTests.swift` exists, implicitly exercising `ShelfItem` construction as part of testing `ShelfLogic`.
   - What's unclear: Whether `ClipboardItem`'s `Kind` enum (new associated-value territory) warrants its own small test file for enum-equality/construction edge cases, or whether folding that coverage into `ClipboardStoreTests.swift` (mirroring the Shelf precedent exactly) is sufficient.
   - Recommendation: Default to the Shelf precedent (one test file, `ClipboardStoreTests.swift`, covering both types) unless the planner judges the `Kind` enum's Equatable-synthesis behavior needs isolated regression coverage — this is a low-stakes structural choice, not a design decision.

## Environment Availability

Skipped — this phase has no external dependencies (Xcode/Swift toolchain already required and verified project-wide; zero new tools, services, or packages).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (bundled with Xcode 16+) — confirmed via `import XCTest` in every existing test file, zero `import Testing` (Swift Testing) usage anywhere in `IsletTests/` `[VERIFIED: codebase grep, 39 test files]` |
| Config file | `project.yml`'s `IsletTests` target (lines ~197-228) — `TEST_HOST`/`BUNDLE_LOADER` point at the built `Islet.app` binary, `@testable import Islet` used throughout |
| Quick run command | `xcodebuild test -project Islet.xcodeproj -scheme Islet -only-testing:IsletTests/ClipboardStoreTests` |
| Full suite command | `xcodebuild test -project Islet.xcodeproj -scheme Islet` |

### Phase Requirements → Test Map

This phase carries no formal REQ-ID (infrastructure phase). Its 4 ROADMAP success criteria map to tests as follows:

| Success Criterion | Behavior | Test Type | Automated Command | File Exists? |
|--------------------|----------|-----------|-------------------|-------------|
| SC-1 (pure types, unit-tested) | `ClipboardItem`/`ClipboardStore` exist, no AppKit/NSPasteboard imports | unit | `xcodebuild test ... -only-testing:IsletTests/ClipboardStoreTests` + build-log import grep | ❌ Wave 0 — new files |
| SC-2 (cap + FIFO eviction) | Appending past 30 items evicts the oldest | unit | `testAppendEvictsOldestPastCap` | ❌ Wave 0 |
| SC-3 (clear empties store) | `clear()` removes every item in one call | unit | `testClearEmptiesStore` | ❌ Wave 0 |
| SC-4 (independent axis) | Zero imports of `IslandResolver`/`TransientQueue`/`NotchWindowController` in `Islet/Clipboard/*.swift` | static check | `grep -L "IslandResolver\|TransientQueue\|NotchWindowController" Islet/Clipboard/*.swift` (expect all files listed, i.e. none contain the forbidden strings) | ❌ Wave 0 |
| D-02 (dedupe-and-move-to-top) | Re-adding identical text/image content moves existing entry to top, refreshes timestamp | unit | `testAppendDuplicateTextMovesToTopWithRefreshedTimestamp` / equivalent image test | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `xcodebuild test -project Islet.xcodeproj -scheme Islet -only-testing:IsletTests/ClipboardStoreTests` (seconds — pure in-memory logic, no device/UI dependency)
- **Per wave merge:** `xcodebuild test -project Islet.xcodeproj -scheme Islet` (full suite — cheap here since this phase adds no slow/on-device tests)
- **Phase gate:** Full suite green before `/gsd:verify-work` — no on-device UAT checkpoint needed for this phase (no UI surface exists yet; mirrors Phase 19's Plan 1 which also had no UAT gate, only Plan 2's UI phase did)

### Wave 0 Gaps

- [ ] `IsletTests/ClipboardStoreTests.swift` — covers SC-1/2/3/4 and D-02 (new file)
- [ ] `Islet/Clipboard/ClipboardItem.swift` — new source file (not a test gap, but a prerequisite Wave 0 needs to create before the test file can compile)
- [ ] `Islet/Clipboard/ClipboardStore.swift` — new source file, same as above
- [ ] No new shared fixtures/conftest-equivalent needed — this codebase's test convention (per `ShelfLogicTests.swift`) is a fresh `var store = ClipboardStore()` per test method, no `setUp()`/shared state

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No auth surface in this phase |
| V3 Session Management | No | No session concept in this phase |
| V4 Access Control | No | No access-control surface — pure in-memory data |
| V5 Input Validation | Minimal | `ClipboardStore.append` accepts content of any size/shape unconditionally per CONTEXT.md D-03 (explicit, user-approved decision — not an oversight); the `Kind` enum's type-safety is itself the only "validation" this phase performs (an invalid text-and-image-simultaneously state is unrepresentable by construction) |
| V6 Cryptography | No | Explicitly out of scope — PRIV-02 (encryption at rest) is Phase 56's responsibility, not this phase's; `ClipboardStore` never touches disk |

### Known Threat Patterns for this phase's stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Sensitive clipboard content (passwords, secrets) captured into memory | Information Disclosure | Out of scope for this phase — PRIV-01 (excluding `org.nspasteboard.ConcealedType`/`TransientType`) is Phase 57's `ClipboardMonitor` responsibility; `ClipboardStore` has no awareness of where its input comes from and cannot itself distinguish sensitive from non-sensitive content. Flag for the Phase 57 planner, not addressed here. |
| Unbounded memory growth from unlimited item size (D-03) | Denial of Service (self-inflicted, low severity) | Explicitly accepted risk per CONTEXT.md D-03 — "revisit only if this becomes a real problem in practice," not designed around speculatively in this phase |

## Sources

### Primary (HIGH confidence)
- Islet's own codebase, read directly: `Islet/Notch/IslandResolver.swift` (TransientQueue, lines 287-303), `Islet/Shelf/ShelfItem.swift`, `Islet/Shelf/ShelfLogic.swift`, `Islet/Shelf/ShelfFileStore.swift`, `Islet/PermissionStatus.swift` (PermissionKind), `Islet/Notch/OSDInterceptor.swift` (OSDKeyKind), `Islet/Calendar/CalendarViewState.swift` (QuickAddKind), `IsletTests/ShelfLogicTests.swift`, `IsletTests/IslandResolverTests.swift`, `project.yml` (IsletTests target config, Swift 5 language mode, macOS 15.0 deployment target)
- `.planning/research/ARCHITECTURE.md`, `.planning/research/SUMMARY.md` — milestone-level (v1.9) research already directly specifying `ClipboardItem`/`ClipboardStore`'s shape, file location, and component boundaries, based on the same codebase-reading approach
- `.planning/phases/55-clipboard-data-model-store/55-CONTEXT.md` — locked decisions D-01/D-02/D-03, discretion areas
- `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/ROADMAP.md` (Phase 55 section) — project requirement/decision history

### Secondary (MEDIUM confidence)
- None needed — this phase's entire technical surface is directly verifiable from the codebase itself; no external library/API research was required.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero external dependencies, entirely Swift stdlib/Foundation, directly verified against the project's own toolchain config
- Architecture: HIGH — based on direct reading of this exact codebase's shipped precedent (`ShelfItem`/`ShelfLogic`/`TransientQueue`) plus already-completed milestone-level research that independently arrived at the same file/folder shape
- Pitfalls: HIGH — D-02's departure from Shelf's dedupe behavior is the one genuine trap, directly named in CONTEXT.md itself, not inferred

**Research date:** 2026-07-22
**Valid until:** Not time-sensitive — pure Swift/Foundation patterns with zero external dependency; this research does not go stale on a normal 30-day research-freshness clock, since nothing here depends on a library version or an external API's current behavior.
