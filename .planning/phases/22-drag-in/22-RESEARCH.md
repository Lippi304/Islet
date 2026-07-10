# Phase 22: Drag-In - Research

**Researched:** 2026-07-10
**Domain:** AppKit drag-and-drop destination delivery through a click-through, non-activating `NSPanel`; SwiftUI `.onDrop` composition; hover/collapse state-machine coexistence with an OS drag session.
**Confidence:** MEDIUM (architecture/APIs) / LOW-MEDIUM (the one load-bearing question: does `ignoresMouseEvents` block drag delivery) — this is why a spike is the mandatory first task.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01 (Auto-expand timing):** The island expands immediately on drag-ENTER (as soon as a dragged file touches the collapsed pill's drop zone) — not only after the drop completes. The user sees the shelf open before releasing, mirroring macOS Dock spring-loading. The drop then lands into the now-visible expanded/shelf view.
- **D-02 (Drop-zone hit area):** The drag-in drop zone is the SAME hot-zone geometry already used for hover/click (`pointerInZone` / the existing hit-test rect in `NotchWindowController`) — no separate, larger padded zone just for dragging. Reuses the existing single-arbiter hit-test convention rather than introducing a second zone concept.
- **D-03 (Hot/targeted visual feedback, SHELF-02):** Use the existing hover bounce/scale-up spring animation (D-01 from Phase 2 — hover gives an affordance via a spring scale, never auto-expands on its own) as the drag-hot feedback. No new visual effect (no glow, no accent-color flash) — drag-hover reuses the same affordance the pointer-hover state already produces.
- **D-04 (Drop scope boundary):** Drag-in is accepted ONLY while the island is collapsed, exactly as ROADMAP Success Criteria #1 states ("onto the collapsed island pill"). Dropping while the island is already expanded (showing Now Playing, idle glance, or an already-open shelf) is explicitly OUT of scope for this phase — no drop-destination registration needed for the expanded state. If a future need arises, it's a new phase/requirement.

### Claude's Discretion
- Exact AppKit mechanism for registering the panel/view as a drag destination (`NSDraggingDestination` conformance point — view vs. panel, `registerForDraggedTypes`) — not discussed; planner/researcher resolves against the existing single-arbiter click-through convention.
- How drag-enter/drag-exit is detected to drive D-01's auto-expand and D-03's bounce feedback (e.g., `draggingEntered`/`draggingExited` vs. a new SwiftUI `.onDrop` modifier with `isTargeted`) — implementation detail.
- Behavior when a drag carries non-file `NSItemProvider` content (e.g., dragged text/image data with no file URL) — treat as a no-drop/reject, consistent with the shelf's file-only model; exact rejection mechanism is an implementation detail.
- Behavior when a drag-in is attempted while a Charging/Device splash is actively suppressing the shelf (SHELF-09) — not discussed in depth; default to the same silent-no-op precedent already established for other edge cases (Phase 19 D-02, Phase 20 D-04, Phase 21 D-02) unless research surfaces a reason to special-case it.
- Multi-file/folder drag ordering into the shelf (which item appended first) — follows Phase 19 D-06 (append in drop order), same as any other addition path.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope. (Accepting drops while already expanded was explicitly considered and locked OUT of scope, D-04 — not deferred as a future idea, just not built here unless a future phase adds it.)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-------------------|
| SHELF-01 | User can drag a file, multiple files, or a folder onto the collapsed island — it auto-expands and the item(s) land in a shelf strip below the expanded view | `## Architecture Patterns` (Patterns 1-3, registration + auto-expand wiring), `## Code Examples` (URL extraction → `ShelfItem` construction via existing `ShelfCoordinator.append`), `## Recommended Spike` (must verify delivery works before implementation) |
| SHELF-02 | Drop target shows "hot"/targeted visual feedback while a file is being dragged over, before release | `## Architecture Patterns` Pattern 1 (`draggingEntered`/`draggingUpdated`) and Pattern 2 (SwiftUI `isTargeted` binding), reusing D-03's existing hover-bounce spring per CONTEXT.md lock |
</phase_requirements>

## Summary

This phase adds AppKit's drag-destination side (`NSDraggingDestination`) to a codebase that today only has a drag *source* (Phase 21's `.onDrag` on `ShelfItemView`). The collapsed island is a fully click-through `NSPanel` (`ignoresMouseEvents` starts `true`, flipped by the single arbiter `syncClickThrough()` only inside the hot-zone) — and the single open technical question is whether AppKit/the Window Server's drag-delivery pathway is gated by that same flag, or is a wholly separate pathway (as multiple independent sources describe) that ignores it.

Apple's official documentation confirms the *mechanics* cleanly: `registerForDraggedTypes(_:)` is declared directly on `NSWindow` (not only `NSView`), and registering a window "automatically makes it a candidate destination object for a dragging session" with `NSWindow` providing a default forwarding implementation of `NSDraggingDestination` methods to its delegate `[VERIFIED: developer.apple.com]`. This means `NotchPanel` itself — or a delegate/subclass override on it — is a fully supported, documented registration point; no `NSHostingView`-level plumbing is required for the AppKit-native path. Independently, community/forum discussion consistently describes drag-and-drop target determination as happening **inside the Window Server**, a separate pathway from the app's own `NSEvent` mouse dispatch used for `mouseDown`/`mouseMoved` `[CITED: forums.macrumors.com, MEDIUM]` — this is the basis for the (unverified) hypothesis that `ignoresMouseEvents` (which this codebase's own comments describe as governing exactly that `NSEvent` dispatch pathway) does not gate drag delivery. No source found during this research explicitly states the interaction one way or the other for `ignoresMouseEvents` specifically — this remains the genuine unknown the project's own CONTEXT.md flags, and it must be resolved empirically, first, before the rest of the phase is built.

**Primary recommendation:** Sequence a ~30-60 minute on-device spike as Task 1 of Wave 1 (see `## Recommended Spike`) that builds the minimal reproduction — register `NotchPanel` for `.fileURL` dragged types, implement the four core `NSDraggingDestination` methods directly on the panel subclass, and manually drag a Finder file onto the collapsed pill with `ignoresMouseEvents = true` — before writing any of the D-01/D-02/D-03/D-04 production behavior. If the spike shows drag delivery is blocked, the fallback architecture (documented below under `## Open Questions` / Fallback) is to widen the interactive hot-zone permanently while collapsed (a locked-decision change, needs a return to `/gsd:discuss-phase`) or to flip `ignoresMouseEvents = false` unconditionally while the drag session is suspected active (detectable via a global `.leftMouseDragged`/pasteboard-changeCount poll, mirroring Phase 21's `dragReleaseMonitor` pattern) — both are contingency notes for the planner, not this phase's locked design.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Drag-destination registration (`registerForDraggedTypes`) | Browser/Client (AppKit window layer) | — | `NotchPanel` is the app's only window; registration is a window-level AppKit call, no server/network tier exists in this app |
| Drag-enter/exit detection → auto-expand (D-01) + hot feedback (D-03) | Browser/Client (AppKit `NSDraggingDestination` or SwiftUI `.onDrop` `isTargeted`) | Client (SwiftUI `NotchInteractionState`) | Detection is AppKit/SwiftUI event delivery; the resulting state mutation (phase → expanded, bounce) already lives in `NotchWindowController`/`NotchInteractionState` per the single-arbiter convention |
| Click-through / hit-test gating during a drag | Browser/Client (`NotchWindowController.syncClickThrough()`) | — | Must route through the existing single arbiter, never a parallel flag (CR-01 gotcha) |
| Multi-file/folder URL extraction from a drop payload | Browser/Client (`NSDraggingInfo`/`NSItemProvider`) | — | Pure decode step, no persistence involved |
| Landing dropped items into the shelf | Client (`ShelfCoordinator.append` + `ShelfFileStore` copy-in) | — | Already-shipped Phase 19 seam; this phase is purely a new caller of it |
| Session-only staging storage | Database/Storage (in-memory `ShelfLogic` + temp-dir session copies) | — | Unchanged from Phase 19; out of scope here |

There is no server/backend tier in this app — everything above is local AppKit/SwiftUI process, consistent with every prior phase.

## Standard Stack

### Core
No new external dependencies. This phase is 100% Apple-framework: `AppKit` (`NSDraggingDestination`, `NSDraggingInfo`, `NSPasteboard`) and optionally `SwiftUI` (`.onDrop(of:isTargeted:perform:)`). `[VERIFIED: developer.apple.com]`

| Framework | Purpose | Confidence |
|-----------|---------|------------|
| AppKit (`NSDraggingDestination`, `registerForDraggedTypes(_:)`) | Window/view-level drag-destination registration and event callbacks | HIGH — confirmed via official docs fetch |
| AppKit (`NSDraggingInfo`, `NSPasteboard`) | Extracting dropped file/folder URLs | HIGH — confirmed via official docs fetch |
| SwiftUI (`View.onDrop(of:isTargeted:perform:)`) | SwiftUI-level alternative drop-destination modifier, `isTargeted` binding for hot-feedback | HIGH — confirmed via official docs fetch |
| Foundation (`NSItemProvider`, `UTType`) | Content-type declaration for the drop registration (e.g. `.fileURL`, `.folder`) | HIGH — same family already used by Phase 21's `NSItemProvider(contentsOf:)` |

### Package Legitimacy Audit

**Not applicable — no external packages are introduced by this phase.** Every API used is a first-party Apple framework already linked by the app (AppKit/SwiftUI/Foundation). `slopcheck`/registry verification is skipped per the gate's own scope (external package installs only).

## Architecture Patterns

### System Architecture Diagram

```
Finder / other app (drag source)
        │  drag session begins (Window Server owns targeting)
        ▼
┌───────────────────────────────────────────────────────────┐
│ NotchPanel (NSPanel, .borderless/.nonactivatingPanel)      │
│  registerForDraggedTypes([.fileURL])  ◄── Task 1 (new)     │
│                                                             │
│  draggingEntered(_:) ───► NotchWindowController            │
│                             .handleDragEntered()            │
│                               • withAnimation: auto-expand   │
│                                 (D-01, reuses handleClick's   │
│                                  .clicked-equivalent path)    │
│                               • hover-bounce feedback (D-03,  │
│                                  reuses handleHoverEnter's     │
│                                  spring)                       │
│                               • pins island open (mirrors      │
│                                  isDraggingShelfItem, D-03      │
│                                  of Ph.21, but for INBOUND)     │
│                                                                  │
│  draggingExited(_:) ───► handleDragExited()                     │
│                             • unpins if drop never completed     │
│                             • re-samples pointer, resumes grace   │
│                               timer if pointer now outside          │
│                                                                       │
│  performDragOperation(_:) ─► handleDragPerform(draggingInfo)           │
│                                • pasteboard.readObjects(                │
│                                    forClasses:[NSURL.self])              │
│                                • one URL per dropped item                │
│                                  (folder = ONE URL, no recursion)          │
│                                • for each URL: ShelfCoordinator.append(    │
│                                    ShelfItem(originalURL:, localURL:       │
│                                    via ShelfFileStore.makeSessionCopy))     │
│                                • resyncShelfViewState()                     │
└───────────────────────────────────────────────────────────┘
        │
        ▼
ShelfCoordinator (Phase 19, unchanged) ──► ShelfViewState ──► NotchPillView shelf row (Phase 20, unchanged)
```

A reader can trace: Finder drag → Window Server delivers to the registered `NotchPanel` → controller callbacks mutate the SAME `NotchInteractionState`/`syncClickThrough()` arbiter every other interaction path uses → dropped URLs flow through the UNCHANGED Phase 19 `ShelfCoordinator.append` seam → the UNCHANGED Phase 20 shelf view re-renders.

### Recommended Project Structure

No new files strictly required — this fits entirely inside the existing two files:
```
Islet/Notch/
├── NotchPanel.swift             # + registerForDraggedTypes call in init; + NSDraggingDestination
│                                 #   method overrides (or a delegate, see Pattern 1 below)
└── NotchWindowController.swift  # + handleDragEntered/Exited/Perform, routed through
                                  #   syncClickThrough() and resyncShelfViewState() exactly
                                  #   like every other mutation path in this file
```
If the planner prefers not to put `NSDraggingDestination` methods directly on the `NSPanel` subclass (keeping `NotchPanel.swift` a pure "window shell" file, matching its existing header comment convention), an `NSObject`-conforming private delegate class inside `NotchWindowController.swift` is the alternative — `NSWindow`'s default implementation forwards each `NSDraggingDestination` message "to the delegate if the delegate responds to the selector" `[VERIFIED: developer.apple.com/documentation/appkit/nswindow/registerfordraggedtypes(_:)]`.

### Pattern 1: Register the drag destination directly on `NotchPanel`, not the hosting view

**What:** Call `registerForDraggedTypes([.fileURL])` inside `NotchPanel.init`, and either (a) override `draggingEntered(_:)`/`draggingUpdated(_:)`/`draggingExited(_:)`/`performDragOperation(_:)` directly as `NSPanel` subclass overrides, or (b) implement them on a delegate object.

**When to use:** This project already has exactly one AppKit window (`NotchPanel`) and one controller (`NotchWindowController`) that owns all interaction state — registering at the window level (not the `NSHostingView` content view) keeps drag-destination bookkeeping in the same place `ignoresMouseEvents`, `pointerInZone`, and every other interaction flag already lives, avoiding a second parallel authority.

**Why not the `NSHostingView`:** SwiftUI's own `.onDrop` modifier (Pattern 2 below) already handles the content-view-level registration if the planner chooses the SwiftUI-first path instead. Manually calling `registerForDraggedTypes` on the `NSHostingView` in addition to using `.onDrop` would double-register and is not the documented pattern for either approach — pick ONE (AppKit-direct on the panel, OR SwiftUI `.onDrop` on the pill view), never both.

**Example (AppKit-direct, subclass override):**
```swift
// Source: developer.apple.com/documentation/appkit/nswindow/registerfordraggedtypes(_:)
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(/* ... existing config ... */)
        // ... existing setup ...
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // delegate out to the controller via a closure/weak-delegate reference —
        // do NOT duplicate NotchWindowController's state here (single-arbiter rule)
        return onDraggingEntered?(sender) ?? []
    }
    // draggingUpdated / draggingExited / performDragOperation follow the same
    // thin-forwarding-to-controller shape.
}
```

### Pattern 2: SwiftUI `.onDrop(of:isTargeted:perform:)` as the alternative entry point

**What:** Attach `.onDrop(of: [.fileURL, .folder], isTargeted: $isDropTargeted) { providers in ... }` to the collapsed pill's SwiftUI view (`NotchPillView.collapsedIsland`), matching D-02's "reuse the existing hot-zone geometry" decision since the modifier attaches to the SAME view that already defines the collapsed pill's frame.

**When to use:** If the on-device spike shows the AppKit-direct registration on `NotchPanel` does NOT reliably receive drags while `ignoresMouseEvents = true` (e.g. because SwiftUI's own content-view registration happens to compose differently with the window flag than a window-level `registerForDraggedTypes` call does — this exact difference is untested and is part of what the spike must determine), try this path as the second spike variant before concluding the whole approach is blocked.

**Caveats confirmed from official docs `[VERIFIED: developer.apple.com/documentation/swiftui/view/ondrop(of:istargeted:perform:)]`:**
- `perform` receives `[NSItemProvider]`; you MUST start loading their contents synchronously within the closure's scope (loading may *finish* later, but must *start* there) — "the drop receiver can access the dropped payload only before this closure returns."
- `isTargeted` binding flips `true`/`false` automatically on enter/exit of the view's frame — this can directly drive D-01 (auto-expand) and D-03 (hover-bounce reuse) without any manual `draggingEntered`/`draggingExited` bookkeeping, IF this path is chosen.
- The drop destination is exactly the view's frame/size — this naturally satisfies D-02 (reuse existing collapsed-pill hot-zone geometry) since attaching `.onDrop` to `collapsedIsland` scopes the target to that exact frame, no extra hit-test math needed.
- A newer alternative `dropDestination(for:isEnabled:action:)` (Transferable-based) exists but is unnecessary complexity here — `onDrop` + manual `NSItemProvider`/pasteboard reading is the established pattern this codebase already partially uses (Phase 21's `NSItemProvider(contentsOf:)` on the source side).

### Pattern 3: Route ALL new drag state through `syncClickThrough()`, never a parallel flag

**What:** Any new "is a drag currently hovering the collapsed pill" bookkeeping (needed to drive D-01's auto-expand exactly once per drag-enter, not on every `draggingUpdated` tick) must be read by/write through the same places `pointerInZone`/`interaction.phase` already are — mirroring Phase 21's `isDraggingShelfItem` flag, which is checked inside `handleHoverExit()`'s existing grace-collapse work item rather than introducing a second collapse-suppression mechanism.

**Why:** This is the CR-01 gotcha (project memory `cr01-clickthrough-or-defeat-gotcha`): `syncClickThrough()` is the ONE place deciding `ignoresMouseEvents`; a prior regression came from OR-ing a broader zone into the expanded branch instead of routing through the same narrow check. The equivalent risk here is adding a `isDragHovering` flag that independently sets `ignoresMouseEvents = false` somewhere else, which could defeat click-through when a drag is merely *near* (not over) the pill, or leave it stuck interactive after a drag ends without going through `handleDragExited` → `syncClickThrough()`.

### Anti-Patterns to Avoid
- **Registering drag types on both the `NSHostingView` AND the `NotchPanel` window:** picks two different, undocumented-together entry points for the same drop; choose ONE (Pattern 1 or Pattern 2).
- **A second `ignoresMouseEvents` writer:** any drag-related code that sets `panel?.ignoresMouseEvents` directly instead of going through `syncClickThrough()` reintroduces exactly the CR-01 regression class.
- **Recursing into a dropped folder's contents:** REQUIREMENTS.md Out of Scope explicitly excludes folder spring-loading — a dropped folder is ONE `ShelfItem` with the folder's own URL, never enumerated.
- **Treating `draggingUpdated(_:)` ticks as new "enters":** `wantsPeriodicDraggingUpdates()`/`draggingUpdated(_:)` fire repeatedly while the drag hovers; only the FIRST `draggingEntered(_:)` call (or the `isTargeted` binding's `false→true` edge in the SwiftUI path) should trigger the one-time auto-expand — an edge-detected flag (mirroring `pointerInZone`'s own enter/exit edge tracking, WR-01) is the correct shape, not a naive "expand on every callback."

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Detecting drop-target hover for visual feedback | A custom global mouse-position poll during drags | `NSDraggingDestination.draggingEntered/draggingExited` (or SwiftUI `isTargeted`) | Both are the OS-native, event-driven signal for exactly this; a poll would duplicate what the Window Server already computes and delivers |
| Extracting file URLs from a drop, incl. multi-file/folder | Manual pasteboard type-string parsing | `NSDraggingInfo.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]` | Official, documented, handles multi-item and folder URLs uniformly `[VERIFIED: developer.apple.com/documentation/appkit/nsdragginginfo]` |
| Copying the dropped file into session storage | New copy logic in this phase | `ShelfFileStore.makeSessionCopy(of:id:)` (Phase 19, unchanged) | Already built, tested, and the sole owner of the session-copy contract (D-03 of Phase 19) |
| Deduping a re-dropped file already in the shelf | New dedup logic in this phase | `ShelfCoordinator.append` → `ShelfLogic.append`'s existing `originalURL` dedup (Phase 19 D-01/D-02) | Already handles silent no-op on duplicate; this phase just needs to call `append`, not reimplement the check |

**Key insight:** This phase's ENTIRE novel surface is the drag-destination registration/callback wiring and the auto-expand/hot-feedback UI reaction. Everything downstream of "I have a list of dropped `URL`s" already exists from Phase 19/20 and must not be re-built.

## Common Pitfalls

### Pitfall 1: `ignoresMouseEvents = true` silently swallowing the drop (THE core risk)
**What goes wrong:** The panel never receives `draggingEntered`/`performDragOperation` while collapsed and click-through, because the Window Server's drag-target hit-test may consult the same "this window/region ignores events" attribute used for ordinary mouse clicks.
**Why it happens:** `ignoresMouseEvents` and drag-delivery are both, ultimately, forms of "does this window participate in pointer-target hit-testing" — whether AppKit implements them via the same underlying flag or two independent ones is exactly the undocumented gap this research could not close with certainty.
**How to avoid:** Spike FIRST (see `## Recommended Spike`). Do not write D-01/D-02/D-03/D-04 production code before the spike passes.
**Warning signs:** `draggingEntered` never fires in the spike when dragging over the pill with `ignoresMouseEvents = true` and the pointer NOT already inside the hot-zone (a drag that starts with the pointer already hovering, which already flipped `ignoresMouseEvents = false` per the existing hover logic, would misleadingly "work" and mask this — the spike must test starting the drag from OUTSIDE the hot-zone, dragging IN, exactly as a real Finder-to-pill drag would happen).

### Pitfall 2: Auto-expand firing repeatedly during a single hover-drag
**What goes wrong:** `draggingUpdated(_:)` (or a naive `isTargeted` observer) fires on every pixel of pointer movement while hovering; if the auto-expand call isn't edge-detected, `withAnimation` fires repeatedly or the phase machine re-enters `.expanded` redundantly.
**Why it happens:** Same class of bug the codebase already solved once for plain hover via `pointerInZone`'s explicit enter/exit edge tracking (WR-01 comment: "NOT derived from `interaction.isHovering`... a re-entry while expanded would never read as an enter edge").
**How to avoid:** Track an explicit `isDragHovering` (or reuse `pointerInZone`'s edge-tracking shape) so the expand transition fires exactly once per drag-enter.
**Warning signs:** Visual stutter/flicker of the expand spring while a file is held stationary over the pill.

### Pitfall 3: Drag session freezing `.mouseMoved` tracking, corrupting `pointerInZone`
**What goes wrong:** During an active OS drag (both inbound file-drag and Phase 21's existing outbound shelf-item drag), the global `.mouseMoved` monitor does not fire — confirmed already by this codebase's own Phase 21 comment: *"`pointerInZone` is only kept fresh by the .mouseMoved monitor, which doesn't fire during an OS drag session — re-sample the live pointer instead of trusting the frozen flag"* (see `endShelfItemDrag()`). The same freeze applies to an INBOUND drag-in session.
**Why it happens:** AppKit's drag-and-drop event pump takes over the run loop's event-delivery mode; ordinary global monitors for `.mouseMoved` are known not to fire during a modal drag tracking loop.
**How to avoid:** On drag-end (`performDragOperation`/`draggingEnded`/`concludeDragOperation`, and the SwiftUI `isTargeted` binding's `true→false` edge), explicitly call `handlePointer(at: NSEvent.mouseLocation)` to re-sample the pointer — mirroring `endShelfItemDrag()`'s exact existing fix — rather than trusting whatever `pointerInZone` last held before the drag began.
**Warning signs:** The island stays expanded/hovering indefinitely after a drag-in completes with the pointer actually outside the zone, or collapses immediately even though the pointer is still hovering — either symptom means the post-drag re-sample step was skipped.

### Pitfall 4: Treating a dropped folder as a container to enumerate
**What goes wrong:** Reading `NSDraggingInfo`'s pasteboard with `NSFilenamesPboardType`-style recursive enumeration, or manually calling `FileManager.contentsOfDirectory` on a dropped folder URL.
**Why it happens:** Natural instinct when handling "multiple files or a folder" is to normalize folders into their contents.
**How to avoid:** REQUIREMENTS.md Out of Scope is explicit: "Folder spring-loading (auto-navigating into dropped folder contents) — Folders are just one shelf item, not a container to browse." `pasteboard.readObjects(forClasses: [NSURL.self])` already returns the folder's own URL as a single item — do nothing further with it.
**Warning signs:** A dropped folder producing N shelf items instead of 1.

### Pitfall 5: Accepting a drop while expanded (violates locked D-04)
**What goes wrong:** Registering drag types broadly (e.g., on the full expanded panel frame) instead of scoping acceptance to only the collapsed state, per D-04's explicit lock ("Drag-in is accepted ONLY while the island is collapsed").
**Why it happens:** It may seem more "complete" to also accept a drop while the shelf is already open.
**How to avoid:** Gate `performDragOperation`'s accept-and-append logic (or the `.onDrop` `perform` closure's actual append call) on `!interaction.isExpanded`, returning `false`/rejecting the operation otherwise — even though the panel stays registered for dragged types at all times (registration itself is cheap and window-level; the BEHAVIORAL gate belongs in the callback body, mirroring how `syncClickThrough()` already branches on `interaction.isExpanded`).
**Warning signs:** Dropping a file while Now Playing/shelf is already expanded silently succeeds instead of no-op.

## Code Examples

### Extracting file/folder URLs from a drop (multi-file + folder)
```swift
// Source: developer.apple.com/documentation/appkit/nsdragginginfo
func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let pasteboard = sender.draggingPasteboard
    guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
          !urls.isEmpty else { return false }
    // Each URL — including a single folder URL — becomes exactly ONE ShelfItem,
    // in drop order (Phase 19 D-06), via the UNCHANGED ShelfCoordinator.append seam.
    for url in urls {
        let id = UUID()
        guard let localURL = try? ShelfFileStore.makeSessionCopy(of: url, id: id) else { continue }
        let item = ShelfItem(id: id, originalURL: url, localURL: localURL,
                              filename: url.lastPathComponent, addedAt: Date())
        shelfCoordinator.append(item)
    }
    resyncShelfViewState()
    return true
}
```

### SwiftUI alternative — `.onDrop` with `isTargeted` driving D-01/D-03
```swift
// Source: developer.apple.com/documentation/swiftui/view/ondrop(of:istargeted:perform:)
collapsedIsland
    .onDrop(of: [.fileURL, .folder], isTargeted: Binding(
        get: { isDragHovering },
        set: { entered in
            guard entered != isDragHovering else { return }   // Pitfall 2 — edge-detect
            isDragHovering = entered
            if entered { onDragEntered() } else { onDragExited() }   // reuses D-01/D-03 hooks
        }
    )) { providers in
        onDragPerform(providers)   // extracts URLs via loadFileRepresentation, mirrors above
        return true
    }
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Raw AppKit `NSDraggingDestination` only | SwiftUI `.onDrop`/`dropDestination(for:)` available as a higher-level alternative | SwiftUI's `.onDrop` has existed since iOS 13/macOS 10.15; `dropDestination(for:)` (Transferable-based) is a newer (macOS 13+) addition | This phase can choose either layer; both are current and supported, not a deprecated-vs-new split |
| `NSFilenamesPboardType` string-array pasteboard reading | `NSPasteboard.readObjects(forClasses: [NSURL.self], options:)` | Long-standing modern API (pre-dates this project) | Already the correct modern approach; no legacy API risk here |

**Deprecated/outdated:** `namesOfPromisedFilesDropped(atDestination:)` on `NSDraggingInfo` is documented as deprecated `[VERIFIED: developer.apple.com]` — not relevant here since this phase deals with real (non-promised) file URLs.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ignoresMouseEvents = true` does NOT block AppKit `NSDraggingDestination` delivery (drag targeting is a separate Window-Server pathway from ordinary mouse-event dispatch) | Summary, Pitfall 1 | HIGH — if wrong, the entire collapsed-pill drag-in design as locked in CONTEXT.md (D-02: reuse the existing hot-zone, no separate always-interactive zone) cannot work as-is; would require either an always-interactive drop zone (contradicts the click-through design) or a different detection mechanism entirely. This is exactly why the spike is mandatory before further planning/execution. |
| A2 | SwiftUI's `.onDrop` composes correctly (fires reliably) on a view hosted inside an `NSHostingView` whose owning `NSPanel` has `ignoresMouseEvents` toggling at runtime | Pattern 2 | MEDIUM — if the SwiftUI path behaves differently than the raw AppKit path, the planner needs the spike to test BOTH variants, not assume one implies the other |
| A3 | The Window-Server-level drag-targeting-is-separate-from-mouse-dispatch claim generalizes to this project's specific `.borderless`/`.nonactivatingPanel`/`.statusBar`-level panel configuration | Summary | MEDIUM — the cited forum source discusses ordinary windows, not a non-activating status-level panel; an atypical window configuration could behave differently |

## Open Questions

1. **Does drag delivery survive `ignoresMouseEvents = true` on THIS project's exact panel configuration?**
   - What we know: Official docs confirm `registerForDraggedTypes` is a supported NSWindow-level call, independent of any mention of `ignoresMouseEvents`. Community sources describe drag targeting as Window-Server-owned, separate from mouse-event dispatch.
   - What's unclear: No source directly states the interaction between `ignoresMouseEvents` specifically and drag delivery. This project's panel is also `.nonactivatingPanel` + `.statusBar` level + never-key — an atypical combination not found addressed in any source during this research.
   - Recommendation: Spike first (below), before any other Wave 1 task.
   - **Resolution status (revision iteration 1):** Deliberately left unresolved at planning time --
     resolves via 22-01's on-device spike task (22-01-PLAN.md Task 2). Record the empirical
     PASSED/FAILED verdict in `22-01-SUMMARY.md` once executed; do not re-research this question,
     per this file's own "Valid until" note.
   - **RESOLVED (on-device, 22-01-SUMMARY.md):** CONFIRMED YES -- `draggingEntered` fired reliably
     for a drag started outside the hot zone, on this project's exact `.borderless` /
     `.nonactivatingPanel` / `.statusBar`-level / `ignoresMouseEvents == true` panel. A1's core
     technical claim holds; Pitfall 1 (event swallowing) does NOT occur. A **new, separate**
     follow-on problem was discovered in the same test (drop never completes because the drag path
     crosses macOS's own top-edge Mission Control trigger before reaching the hot zone) -- see Open
     Question 4 below. This is a hot-zone geometry issue, not an A1/Pitfall-1 recurrence.

2. **If the spike shows drag delivery IS blocked while collapsed and click-through — what's the fallback?**
   - What we know: The current design (D-02) deliberately reuses the small hot-zone geometry, relying on click-through being irrelevant to drag delivery.
   - What's unclear: Whether the fix would be (a) making the collapsed pill always drag-destination-interactive regardless of `ignoresMouseEvents` (if AppKit permits registering for drops even while a window ignores ordinary mouse events — untested), or (b) needing a wider always-on invisible drop-catcher region, which would be a CONTEXT.md decision change requiring a return to `/gsd:discuss-phase`.
   - Recommendation: If the spike fails, STOP and re-discuss D-02 with the user rather than silently widening scope — this is a locked decision, not implementation discretion.
   - **RESOLVED (moot):** The spike did NOT show drag delivery blocked (A1 confirmed YES, Question 1
     above) — this question's own premise never triggered. What DID come up instead was the
     related-but-distinct Question 4 below (delivery works, but the small hot-zone is a bad drag
     target geometrically). See Question 4 and `22-CONTEXT.md`'s Hot-Zone/Mission-Control Fallback
     (D-02b/D-02c/D-05/D-06/D-07), implemented in the replanned `22-03-PLAN.md`.

3. **Does a folder's URL alone (without enumerating contents) render sensibly as a shelf item (icon, name) in the existing Phase 20 `ShelfItemView`?**
   - What we know: `ShelfItem` already stores an arbitrary `URL`/`localURL`; Phase 20's file-type icon lookup presumably uses `NSWorkspace.shared.icon(forFile:)` or similar, which does return a folder icon for directory URLs.
   - What's unclear: Whether `ShelfFileStore.makeSessionCopy` (built for individual files) correctly copies an entire folder tree (e.g., via `FileManager.copyItem` which does support directories) — not verified in this research pass; the planner should have a task confirm/test this against the existing `ShelfFileStoreTests.swift`.
   - Recommendation: Add a unit test for a folder-URL session-copy round-trip in Wave 0/1 gap-closure.
   - **Resolution status (revision iteration 1):** Resolved by 22-02-PLAN.md Task 2 --
     `testMakeSessionCopyHandlesDirectoryURL` in `IsletTests/ShelfFileStoreTests.swift` confirms
     `ShelfFileStore.makeSessionCopy` correctly round-trips a directory tree, with zero production
     code change.

4. **NEW (raised by 22-01's on-device spike, 22-01-SUMMARY.md): the hot zone is too small and too close to the physical screen top edge to be a reliable drag target.**
   - What we know: `draggingEntered` fires correctly (A1 confirmed) when the drag actually reaches the hot zone. But the hot zone is sized/positioned for mouse hover/click (D-02's "reuse the existing hot-zone" locked decision), not for a drag session -- on-device, the user's cursor crosses into macOS's own top-edge Mission Control (F3) trigger zone before it reaches the small hot zone, and Mission Control interrupts the drag before `performDragOperation` can ever fire.
   - What's unclear: Whether the fix is (a) a wider always-interactive drop zone active only during an in-flight drag session (detected via `draggingEntered`/system drag-session notifications), (b) an earlier/more forgiving auto-expand trigger during drag-hover specifically (distinct from D-01's click hover timing), or (c) some combination, and how any of these stay clear of the Mission Control trigger geometry.
   - Recommendation: Not implementation discretion -- D-02 (hot-zone reuse) is a locked CONTEXT.md decision that this finding contradicts in practice. Return to `/gsd:discuss-phase 22` to decide the fallback before 22-02/22-03 proceed. This is the same escalation path Open Question 2 above already anticipated for an A1 failure, applied here to a partial/practical failure instead.
   - **RESOLVED (`/gsd:discuss-phase 22` re-run, 2026-07-10):** D-02 is superseded by D-02b
     (drag-accept reuses the existing `expandedZone` rect, not the tiny `hotZone`) + D-02c (an
     explicit landing-margin below the physical top edge via the new `dragLandingMaxY` property) +
     D-05/D-06 (the same wider region also drives the auto-expand and hover-bounce feedback
     triggers) + D-07 (ordinary, non-drag hover/click hot-zone behavior is completely unchanged).
     See `22-CONTEXT.md`'s "Hot-Zone/Mission-Control Fallback" subsection and the replanned
     `22-03-PLAN.md` (`isWithinDragAcceptRegion(_:)`) for the implemented resolution.

## Recommended Spike

Per the project's own established convention (isolating the highest-uncertainty integration point, as already done by sequencing this phase last) and per CONTEXT.md's explicit call for an on-device spike: the planner should sequence, as **the very first task of the very first wave**, a throwaway/minimal reproduction:

1. Add `registerForDraggedTypes([.fileURL])` to `NotchPanel.init` (temporary, can be folded into the real Task 1 if it passes).
2. Implement bare-minimum overrides: `draggingEntered` (return `.copy`, `NSLog`/breakpoint), `performDragOperation` (return `true`, `NSLog` the dropped URL).
3. Build and run on-device (per project memory `xcodebuild-test-headless-hang` — this MUST be a real interactive run, not `xcodebuild test`; use Debug build + Cmd-R or the existing on-device verification convention).
4. With the pointer starting OUTSIDE the hot-zone (so `ignoresMouseEvents` is confirmed `true` at drag-start), drag a file from Finder onto the collapsed pill and observe whether `draggingEntered`/`performDragOperation` fire.
5. Repeat with the SwiftUI `.onDrop` variant attached to `collapsedIsland` if the AppKit-direct path fails, to check Open Question 2's two variants independently.
6. Record the empirical result in the phase's PLAN.md/task notes before writing the rest of the drag-in logic — this determines which of Pattern 1 or Pattern 2 (or the fallback) the rest of the phase is built on.

This spike is cheap (under an hour, no permanent code committed if it fails) and eliminates the single largest risk of building the wrong architecture for the rest of the phase.

## Environment Availability

No new external dependencies or services — same Xcode 16+/Swift 5-mode/macOS 14.0 deployment toolchain already in use for every prior phase (confirmed via `project.yml`: `MACOSX_DEPLOYMENT_TARGET: "14.0"` in all four targets). `[VERIFIED: project.yml]`

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / xcodebuild | Build gate | ✓ (existing project convention) | 16+ (Tahoe build machine: Xcode 26.6 per project memory) | — |
| On-device manual run (Cmd-R) | The spike (drag delivery cannot be verified headlessly) | ✓ (developer's own Mac) | — | None — `xcodebuild test` hangs headlessly per project memory `xcodebuild-test-headless-hang`; this phase's core risk is fundamentally undeterminable without an interactive on-device session |

**Missing dependencies with no fallback:** None — all required tooling is already installed and used by every prior phase.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing `IsletTests` target) |
| Config file | `project.yml` (XcodeGen) — scheme `Islet`, test target already wired |
| Quick run command | `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` (BUILD gate only — see caveat below) |
| Full suite command | Manual Cmd-U in Xcode GUI — **`xcodebuild test` hangs in this environment** (project memory `xcodebuild-test-headless-hang`: a Bluetooth TCC-authorization wait in `BluetoothMonitor`/`IOBluetoothCoreBluetoothCoordinator` blocks any full `Islet.app` boot non-interactively) |

**Critical caveat for this phase specifically:** the core SHELF-01/SHELF-02 behavior (does a drag actually reach the panel) is fundamentally **not unit-testable** — it requires the real Window Server drag-delivery pathway, which no XCTest harness exercises. Automated tests in this phase can only cover the PURE seams (URL extraction from a mock `NSDraggingInfo`, the edge-detection logic for one-shot auto-expand, folder-vs-file `ShelfItem` construction) — the actual "does the drop arrive" question is exclusively a manual/on-device verification item, mirrored by the spike above.

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SHELF-01 | Dropped file/folder URLs become `ShelfItem`s in drop order, collapsed-only | unit (pure extraction/append logic) | `xcodebuild test -only-testing:IsletTests/ShelfLogicTests` (via Cmd-U; do not run headlessly) | ✅ `ShelfLogicTests.swift`, `ShelfViewStateTests.swift` exist and cover the append/dedup seam already; new tests needed for the drag-in-specific URL-extraction helper |
| SHELF-01 | Drag actually reaches the click-through panel and lands the drop | manual-only | N/A — no automated harness can simulate a real OS drag session | ❌ Wave 0 gap — this is the spike itself, and the phase's own manual/human-UAT step |
| SHELF-02 | Hot/targeted feedback shows before release | manual-only (visual) + unit (edge-detection logic pure function) | Manual Cmd-R visual check; unit test for the one-shot enter/exit edge-detect helper if extracted as a pure function (mirrors `pointerInZone`'s WR-01 pattern) | ❌ Wave 0 gap — new pure-function test needed once the edge-detect helper exists |

### Sampling Rate
- **Per task commit:** `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` (build-only gate, matches every prior phase's established convention)
- **Per wave merge:** Same build gate + manual Cmd-U for any new/changed pure-seam unit tests + a manual on-device drag verification pass
- **Phase gate:** Full manual on-device UAT (drag single file, multiple files, a folder, from outside the hot-zone) before `/gsd:verify-work` — this phase cannot be verification-complete without human hands-on testing, unlike most prior phases

### Wave 0 Gaps
- [ ] A pure-function unit test for URL extraction from a drop payload (e.g., a fake `[URL]` → `[ShelfItem]` mapping helper, testable without a real `NSDraggingInfo`)
- [ ] A pure-function unit test for the one-shot drag-enter/exit edge detection (mirrors `pointerInZone`'s existing untested-but-implicit edge logic — Phase 22 should make this an explicit, testable pure seam per the project's established pure-seam-first convention)
- [ ] Folder round-trip test in `ShelfFileStoreTests.swift` confirming `makeSessionCopy` handles a directory URL (Open Question 3) — not yet covered by existing tests (file-only fixtures observed)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | No auth surface in this app |
| V3 Session Management | No | N/A |
| V4 Access Control | No | Single-user local app |
| V5 Input Validation | Yes | Reject non-file-URL `NSItemProvider`/pasteboard payloads at the drop boundary (Claude's Discretion item in CONTEXT.md — treat as no-op, consistent with shelf's file-only model); only accept `.fileURL`/`.folder` UTType-declared content, never arbitrary pasteboard string/data types |
| V6 Cryptography | No | No crypto surface introduced |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| Malicious/oversized drop payload (e.g., thousands of files, or a symlink loop inside a dropped folder) causing resource exhaustion | Denial of Service | Folder is NEVER enumerated (Out of Scope, Pitfall 4) — the app only ever calls `FileManager.copyItem`/reads the top-level URL, never recurses; unbounded shelf capacity is already an accepted decision (REQUIREMENTS.md Out of Scope: "Fixed low item cap... Unbounded scroll chosen instead") so no new cap is needed here, but a pathological multi-thousand-file single drop is an accepted, documented risk consistent with existing shelf design, not a new gap this phase introduces |
| Dropped file path traversal / symlink pointing outside sandbox | Tampering | Not applicable — this app is NOT sandboxed (per CLAUDE.md: "Ship un-sandboxed... App sandboxing incompatible with the MediaRemote bridge"), and `ShelfFileStore.makeSessionCopy` already only reads/copies the exact URL the OS handed it via the pasteboard (the OS itself resolved the drag source's file identity) — no new trust boundary is crossed by this phase beyond what Phase 19/21 already accepted |

## Sources

### Primary (HIGH confidence)
- `developer.apple.com/documentation/appkit/nswindow/registerfordraggedtypes(_:)` — confirms `NSWindow`-level registration, default delegate-forwarding behavior for `NSDraggingDestination` methods
- `developer.apple.com/documentation/appkit/nsdraggingdestination` — full protocol method list (`draggingEntered`, `draggingUpdated`, `draggingExited`, `prepareForDragOperation`, `performDragOperation`, `concludeDragOperation`, `wantsPeriodicDraggingUpdates`)
- `developer.apple.com/documentation/appkit/nsdragginginfo` — `draggingPasteboard`, `enumerateDraggingItems`, and the `readObjects(forClasses: [NSURL.self])` pattern for multi-file/folder URL extraction
- `developer.apple.com/documentation/swiftui/view/ondrop(of:istargeted:perform:)` — full declaration, `isTargeted` binding semantics, `NSItemProvider` loading-must-start-synchronously caveat
- `developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents` — confirmed abstract ("transparent to mouse events"); no explicit statement about drag-and-drop interaction found

### Secondary (MEDIUM confidence)
- `forums.macrumors.com/threads/cocoa-nsview-subview-blocking-drag-drop.1147942` — describes drag-and-drop target determination as happening entirely within the Window Server, separate from the app's own mouse-event dispatch (supports, but does not conclusively prove, the hypothesis that `ignoresMouseEvents` doesn't gate drag delivery)
- Electron `setIgnoreMouseEvents` community discussion (electronjs.org docs, GitHub issues #26718/#23863) — analogous overlay-window click-through + drag-and-drop interaction reports from a different (Chromium/AppKit-bridged) stack; window-level configuration (e.g. floating level) was reported to matter for drag/drop on overlay windows, but no direct `ignoresMouseEvents`-blocks-drops confirmation found

### Tertiary (LOW confidence)
- `developer.apple.com/forums/thread/737584` — a transparent/click-through window thread; confirmed to NOT discuss drag-and-drop at all (checked and ruled out, not a source for this question)
- `fileside.app/blog/2019-04-22_fixing-drag-and-drop` — Electron drag-and-drop cosmetic-issue post; confirmed NOT relevant to the `ignoresMouseEvents` question (checked and ruled out)

## Metadata

**Confidence breakdown:**
- Standard stack (APIs/mechanics): HIGH — all confirmed via official Apple documentation fetches
- Architecture (registration point, patterns): MEDIUM — mechanically correct per docs, but the load-bearing runtime behavior (Pitfall 1 / Assumption A1) is unverified
- Pitfalls: MEDIUM-HIGH — Pitfalls 2-5 are derived directly from this codebase's own established, tested patterns (WR-01, CR-01, Phase 21's `isDraggingShelfItem`); Pitfall 1 is the one genuinely unresolved item, by design

**Research date:** 2026-07-10
**Valid until:** 30 days (stable Apple framework APIs; the on-device spike result, once run, should be recorded permanently in the phase's task notes/SUMMARY rather than re-researched)
