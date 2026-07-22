# Phase 55: Clipboard Data Model + Store - Context

**Gathered:** 2026-07-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Pure, Foundation-only `ClipboardItem` value type and `ClipboardStore` (append/evict-at-cap/clear) — no AppKit, no `NSPasteboard`, no disk I/O, no encryption. Fully unit-tested in isolation before Phase 56 (persistence), Phase 57 (live pasteboard monitor), and Phase 58 (menu wiring) touch it. No formal REQ-ID — infrastructure phase, mirrors this project's own pure-seam-first precedent (Phase 19 Shelf, Phase 47 Audio Output monitor seam).

</domain>

<decisions>
## Implementation Decisions

### Cap
- **D-01:** `ClipboardStore` cap = **30 items** (the upper bound of PROJECT.md/ROADMAP.md's stated "~20-30" range). Implemented as a plain inline `let` constant on `ClipboardStore` itself — mirroring `TransientQueue.maxDepth`'s style (`Islet/Notch/IslandResolver.swift:290`), not a shared/global constants file, not configurable.
- Eviction is FIFO: appending past the cap drops the oldest entry (`removeFirst()`-style), matching `TransientQueue`'s pattern at `IslandResolver.swift:287-303`.

### Duplicate handling
- **D-02:** Re-copying content that's already in the store (exact text match, or byte-identical image `Data`) moves the *existing* entry to the top with a refreshed timestamp — it does not create a duplicate entry, and does not silently no-op. This is a deliberate departure from Shelf's current `append()` behavior (`Islet/Shelf/ShelfLogic.swift:10-39`), which dedupes on `originalURL` and silently no-ops without reordering. Matches standard clipboard-manager behavior (e.g. Maccy).
- Equality check mechanics (exact string compare for text, byte compare for image `Data`) are Claude's implementation call — not discussed further, no ambiguity the user cared about here.

### Oversized content
- **D-03:** No size cap or truncation on individual items in Phase 55/56 — `ClipboardStore.append` accepts content of any size unconditionally. Rationale (user's explicit choice): simplest logic, no existing precedent in the codebase for per-item size limits, and Phase 56 encrypts/persists everything regardless of size. Revisit only if this becomes a real problem in practice (e.g. huge screenshots causing disk/memory issues) — not a hypothetical to design around now.

### Claude's Discretion
- Internal storage representation of `ClipboardItem.content` for the text/image kind split (e.g. `enum Kind { case text(String); case image(Data) }` shape, associated-value design) — no existing kind-discrimination enum with associated values exists in this codebase (closest analogs — `QuickAddKind`, `OSDKeyKind`, `PermissionKind` — are all no-payload enums), so this is new ground; Claude designs the shape during planning.
- Internal list ordering direction (append-at-end vs prepend-at-front) as long as the observable contract holds: newest item is retrievable first, oldest is evicted first at cap.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & Requirements
- `.planning/ROADMAP.md` §"Phase 55: Clipboard Data Model + Store" (lines 953-965) — goal, success criteria, explicit precedent citations (ShelfItem/ShelfLogic, IslandResolver)
- `.planning/PROJECT.md` §"Milestone In Progress (Parallel): v1.9 (Clipboard History)" (lines 115-132) — target features, CopyClip reference behavior, cap range, persistence-across-reboot requirement
- `.planning/REQUIREMENTS.md` §"v1.9 Requirements — Clipboard History" (lines 74-89) — CLIP-01..05, PRIV-01/02 (none formally scoped to Phase 55, but shape what Phase 56/57/58 will need from this phase's model)

No external ADRs/specs beyond the project's own planning docs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None directly reusable (no existing pasteboard/clipboard code) — this phase establishes new ground.

### Established Patterns
- **Cap/evict-at-cap precedent:** `TransientQueue` (`Islet/Notch/IslandResolver.swift:287-303`) — `let maxDepth = 2` plain instance constant, FIFO `removeFirst()` on overflow. This is the actual pattern to mirror for `ClipboardStore`'s cap logic (NOT `ShelfLogic`, which has no cap at all).
- **Value-type/dedupe/clear shape precedent:** `ShelfItem`/`ShelfLogic` (`Islet/Shelf/ShelfItem.swift:9-15`, `Islet/Shelf/ShelfLogic.swift:10-39`) — pure struct + `append`/`remove`/`clear` mutating functions, unit-tested via `IsletTests/ShelfLogicTests.swift`. Note: Shelf's dedupe-on-URL + silent no-op behavior is explicitly NOT what Phase 55 should do (see D-02).
- **No kind-discrimination enum with associated values exists yet** in this codebase — `QuickAddKind`, `OSDKeyKind`, `PermissionKind` are all no-payload enums. `ClipboardItem`'s text/image kind split will be the first associated-value enum of this shape.
- **No shared cap-constant convention** — caps are plain inline `let` properties on the type itself (`TransientQueue.maxDepth`), referenced elsewhere only via comments (`DeviceCoordinator.swift:72`), never a global/config value.

### Integration Points
- None yet — Phase 55 is deliberately decoupled from `IslandResolver`/`TransientQueue`/`NotchWindowController` (confirmed by design, per ROADMAP success criterion #4). Phase 56 will add `ClipboardFileStore` (mirroring `ShelfFileStore`'s hardened delete-path-validation pattern, `Islet/Shelf/ShelfFileStore.swift:49-56`, but rooted under Application Support rather than `NSTemporaryDirectory()`). Phase 57 will feed live pasteboard captures into this store. Phase 58 wires it into the existing status-item menu.

</code_context>

<specifics>
## Specific Ideas

No specific UI/visual references discussed — this phase has no UI surface. CopyClip reference behavior (from milestone-level discussion) applies to Phase 58, not this phase.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

### Reviewed Todos (not folded)
- `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md`, `2026-07-19-calendar-month-grid-polish.md`, `2026-07-19-island-briefly-disappears-during-click-through.md` — matched by the todo/phase matcher (keyword overlap on generic terms like "state"/"controller"/"phase") but all are UI-domain issues (Quick Action, Calendar, click-through) unrelated to a pure Foundation-only data model phase. Not presented to the user individually — judged as false positives from keyword-only matching, no genuine connection to Phase 55's scope.

</deferred>

---

*Phase: 55-Clipboard Data Model + Store*
*Context gathered: 2026-07-22*
