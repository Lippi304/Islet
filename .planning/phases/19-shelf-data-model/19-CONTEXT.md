# Phase 19: Shelf Data Model - Context

**Gathered:** 2026-07-09
**Status:** Ready for planning

<domain>
## Phase Boundary

The shelf's core data and lifecycle contracts as pure, Foundation-only, unit-tested logic — no AppKit, no drag APIs. Establishes `ShelfItem` (id, originalURL, localURL, filename, addedAt) and `ShelfLogic` (append/remove/clear/dedupe) as an independent `@Published` axis with zero persistence, before any fragile drag/panel code is touched in later phases. Covers SHELF-08 (session-only, never persisted to disk).

Out of scope for this phase: any UI rendering (Phase 20), drag-out (Phase 21), drag-in (Phase 22).

</domain>

<decisions>
## Implementation Decisions

### Duplicate handling
- **D-01:** Two items are duplicates only if they share the same `originalURL` (source path). Different files that happen to share a filename are NOT duplicates.
- **D-02:** Dropping a duplicate is a silent no-op — the existing item stays exactly where it is (position and `addedAt` both unchanged). No re-add, no position refresh.

### Local copy strategy
- **D-03:** The shelf copies a dropped file's bytes into a session-temp location immediately on add (populates `localURL` right away), not lazily on first drag-out/open. Protects against the source being moved, deleted, or ejected before Phase 21 (drag-out) or Phase 20 (click-to-open) needs the bytes.
- **D-04:** The original file (at `originalURL`, wherever it lives) is never written to, moved, or deleted by the shelf — the shelf only ever reads from it to make its own copy.
- **D-05:** The shelf's own internal temp copy (`localURL`) IS deleted immediately whenever its item leaves the shelf — individual removal, delete-all, or app quit. Nothing lingers for the OS to clean up later; this is the literal enforcement mechanism behind SHELF-08's "never persisted."

### Shelf ordering
- **D-06:** New items append to the end of the shelf (oldest-first, left-to-right in drop order). Example: drop a.pdf, b.pdf, c.pdf → `[a.pdf, b.pdf, c.pdf]`.

### Claude's Discretion
- Exact temp directory location/naming scheme for the session-copy files (e.g. `NSTemporaryDirectory()` subfolder) — pick whatever is simplest to wire correctly and clean up.
- `ShelfItem.id` generation strategy (UUID vs URL-derived) — not discussed, standard `UUID` is the expected default.
- Where the new Swift files live in the project (a new `Islet/Shelf/` folder vs. alongside `Islet/Notch/`) — codebase has no shelf-specific folder yet; follow whatever matches existing conventions (see Code Context below).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements source
- `.planning/REQUIREMENTS.md` — SHELF-08 ("Shelf content is purely session-temporary — cleared on manual delete, app restart, or Mac restart; never persisted to disk")
- `.planning/ROADMAP.md` §"Phase 19: Shelf Data Model" — Goal, Depends on, Success Criteria (3 items)

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None directly reusable (this is a greenfield data model), but the project has an established "pure Foundation-only struct/enum + free functions" style to mirror exactly — see Established Patterns.

### Established Patterns
- **Pure-seam-first convention**: `Islet/Notch/IslandResolver.swift` (Phase 6) and `Islet/Notch/DeviceCoordinator.swift` + `Islet/Notch/ActivityCoordinator.swift` (Phase 16) both establish the pattern this phase should follow — `import Foundation` only, no AppKit/SwiftUI, so logic is unit-testable in milliseconds. `IslandResolver.swift`'s `TransientQueue` is a good direct analog for `ShelfLogic`: a `struct` with `mutating func` operations (`enqueue`, `advance`, `removeAll(where:)`) rather than a class.
- **Protocol-narrow extraction**: `ActivityCoordinator` (Phase 16) shows this project's convention of sizing a protocol to exactly what's needed today, not pre-sketching for future phases — relevant since Phase 19 explicitly should NOT reach into `IslandResolver`/`TransientQueue` (see D-06 note below).
- **Test naming**: `IsletTests/DeviceCoordinatorTests.swift`, `IsletTests/DeviceActivityTests.swift` — flat test files per source file, `{TypeName}Tests.swift`.

### Integration Points
- None yet — this phase deliberately produces an isolated model with no controller wiring. Phase 20 will be the first to consume `ShelfLogic`/`ShelfItem` from a view/controller.
- Confirmed via ROADMAP.md Success Criteria #3: the shelf must be its own independent `@Published` axis, never a case inside `IslandResolver`/`TransientQueue` — this phase's model shape alone should make that structurally obvious (e.g. `ShelfLogic` has no dependency on `IslandPresentation`/`ActiveTransient`).

</code_context>

<specifics>
## Specific Ideas

No specific UI/visual references for this phase — it's pure data model. See Phase 20 for shelf strip visual/interaction specifics.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 19-Shelf Data Model*
*Context gathered: 2026-07-09*
