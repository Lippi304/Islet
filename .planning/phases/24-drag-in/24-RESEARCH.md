# Phase 24: Drag-In - Research

**Researched:** 2026-07-11
**Domain:** Detecting an external (Finder/other-app) drag-and-drop session from a passive `NSEvent` global-monitor observer — NOT as a registered `NSDraggingDestination` — on a click-through, non-activating `NSPanel`, on the freshly reproven Phase 23 shell.
**Confidence:** MEDIUM (the core mechanism is a well-established, cross-verified real-world technique — but genuinely unproven ON THIS PROJECT's exact panel configuration, exactly like Phase 22's A1 was before its spike). This is why D-05/D-06's mandatory isolated spike remains the correct first step.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Approach sensitivity / feel**
- **D-01:** The island reacts wide/early — as soon as a drag enters a generously-sized top-of-screen accept zone, well before reaching the pill. Mirrors Phase 22's D-02b widened-zone philosophy and stays maximally forgiving against the Mission-Control edge trigger that killed drop completion in Phase 22's first attempt.
- **D-02:** The drag-accept zone reuses Phase 22's exact geometry: the existing reserved `expandedZone` (`panelFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)`, already computed in `positionAndShow()`) plus a landing margin below the physical top screen edge (D-02c). This geometry was never actually invalidated by Phase 22's failures — only the AppKit delivery mechanism (`NSDraggingDestination`) was. No redesign needed; the new `DragApproachDetector` targets the same accept region.
- **D-03:** Hot/targeted feedback stays single-stage: reuse the existing hover bounce/scale spring animation as-is (Phase 22 D-03/D-06). No new visual effect, no two-stage approach→accept escalation. Keeps this phase focused on proving the detection mechanism, not adding new UI polish.
- **D-04:** The island auto-expands immediately once a drag enters the widened accept zone, before the drop completes — shelf becomes visible while still dragging (Phase 22 D-01, reaffirmed, directly consistent with D-01 above).

**Validation strategy (given 2 prior on-device failures)**
- **D-05:** Build an isolated on-device spike FIRST — mirroring Phase 22-01's approach — to verify the `DragApproachDetector` global-monitor mechanism actually fires reliably, BEFORE building the full accept/shelf-landing logic on top of it. Do not build the complete feature in one pass.
- **D-06:** Budget up to 2 on-device validation rounds (one implementation attempt + one fix-and-retry round) before treating the mechanism itself as a blocker again — matches what Phase 22 actually did before the user pivoted architecturally. Do not debug indefinitely past this cap.

**Reliability bar / fallback plan**
- **D-07:** "Works reliably across repeated on-device trials" means: the common case must work consistently, and an occasional missed drop is acceptable IF it fails silently — no crash, no frozen hover/click-through state, no regression to ordinary pointer behavior. Not zero-defect, but never a broken state.
- **D-08:** If, after the capped 2 validation rounds (D-06), the mechanism is STILL not reliable — STOP execution and return to `/gsd:discuss-phase 24` with findings, rather than shipping something flaky or debugging indefinitely.

**Scope boundary (reaffirmed from Phase 22)**
- **D-09 (LOCKED, reconsidered and re-confirmed):** Drag-in is accepted ONLY while the island is collapsed, exactly as ROADMAP Success Criteria #1 states. Accepting drops while already expanded was explicitly raised and REJECTED as in-scope — deferred idea, not built here.

### Claude's Discretion
- Exact AppKit/Foundation mechanism for the `DragApproachDetector` (which `NSEvent` types to monitor, how to read the systemwide drag pasteboard to obtain file URLs without `NSDraggingDestination`) — resolved by this research below.
- How "an active drag session" is detected to gate the widened accept zone — must route through the SAME single arbiter that already owns `ignoresMouseEvents`/`syncClickThrough()` (project memory `cr01-clickthrough-or-defeat-gotcha`) — NOT a parallel flag.
- Multi-file/folder drag ordering into the shelf — follows Phase 19 D-06 (append in drop order), same as every other shelf-add path.
- Behavior when a drag carries non-file content (no file URL) — treat as a no-drop/reject, consistent with the shelf's file-only model.
- Behavior when drag-in is attempted while a Charging/Device splash is actively suppressing the shelf (SHELF-09) — default to the same silent-no-op precedent unless research surfaces a reason to special-case it.
- Exact margin value for the landing-below-top-edge accept condition (D-02c inherited from Phase 22) — measure against the reserved footprint's existing height.

### Deferred Ideas (OUT OF SCOPE)
- **Accepting drag-in while the island is already expanded** — explicitly raised during discussion and rejected as in-scope for Phase 24 (D-09). If wanted, this is a new capability for a future phase/requirement.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SHELF-01 | User can drag a file, multiple files, or a folder onto the collapsed island — it auto-expands and the item(s) land in a shelf strip below the expanded view | `## Architecture Patterns` (Patterns 1-4: detection, edge-tracked auto-expand, geometry reuse, drop-inference-at-mouseUp), `## Code Examples`, `## Recommended Spike` |
| SHELF-02 | Drop target shows "hot"/targeted visual feedback while a file is being dragged over, before release | Pattern 2 (same hover-bounce spring, now gated by the detector's edge-tracked accept-region check) |
</phase_requirements>

## Summary

This phase replaces Phase 22's `NSDraggingDestination` registration (which mysteriously stopped firing `draggingEntered` on-device twice, root cause never identified) with a completely different mechanism: a passive `NSEvent` global-monitor observer that never registers the panel as a drop destination at all. Two independent, cross-verified web sources (a dedicated AppKit drag-indicator tutorial plus multiple corroborating summaries) describe exactly this technique as the standard way menu-bar/utility apps (the Dropzone/Yoink category) detect an external drag without being the formal drop target: **monitor `.leftMouseDragged` globally, and on each tick compare `NSPasteboard(name: .drag).changeCount` against a stored baseline — a change indicates a real drag-and-drop session (not just an arbitrary mouse drag, e.g. a window move or text selection, neither of which touches this pasteboard) began or is in progress.** File/folder URLs are then read directly off that same systemwide pasteboard via `readObjects(forClasses: [NSURL.self], options:)` — the identical API this codebase's own `DragDropSupport.swift` `fileURLs(from:)` already implements, reusable **as-is, zero signature change**, against `NSPasteboard(name: .drag)` instead of `sender.draggingPasteboard` `[MEDIUM: cross-verified via WebSearch, multiple independent summaries agreeing on the same NSPasteboard(name:.drag)+changeCount+.leftMouseDragged pattern]`.

**Why this is NOT a repeat of Phase 22's first empirical failure:** Phase 22's `draggingEntered` mystery was specific to AppKit's `NSDraggingDestination` delivery pathway (a Window-Server-mediated callback contract that inexplicably stopped firing despite a confirmed-working spike using the identical technique). Global `NSEvent` monitors are a completely different, older, simpler OS mechanism (`CGEventTap`-backed passive observation of events posted system-wide) that this exact codebase already uses successfully in production for two other purposes (`mouseMonitor` for `.mouseMoved` hover detection, shipped since Phase 2; `dragReleaseMonitor` for `.leftMouseUp`, shipped since Phase 21) — there is no `NSDraggingDestination` involved anywhere in the new design, so Phase 22's specific failure mode cannot recur by construction. This is architecturally why the user's pivot (route around the broken subsystem entirely, rather than keep debugging it) is well-founded.

**The one genuinely new empirical unknown (this phase's own A1-equivalent):** does `.leftMouseDragged`/`.leftMouseUp` reliably fire in Islet's global monitor for a drag session Finder — not Islet — initiates and owns? This project's own codebase comment (`endShelfItemDrag`, Phase 21) states the OPPOSITE-sounding claim: *"the .mouseMoved monitor doesn't fire during an OS drag session."* Read carefully, that finding is about Islet's OWN outbound drag (Islet is the drag SOURCE, so **Islet's own run loop** enters AppKit's modal `eventTracking` mode, which is documented to suppress ordinary event delivery on the thread running that loop `[CITED: developer.apple.com/documentation/foundation/runloop/mode/eventtracking, MEDIUM]`). For Phase 24's inbound case, **Finder is the drag source and owns the modal tracking loop on Finder's own process/run loop — Islet is a passive bystander whose own run loop never leaves default mode**, so nothing in the documented mechanism explains why a global monitor registered in Islet would stop receiving copies of system-wide `.leftMouseDragged`/`.leftMouseUp` events during someone else's drag. This reasoning is internally consistent and matches the real-world tooling precedent, but — per this project's own hard-won lesson from Phase 22 (a spike that "should have worked per Apple docs" empirically didn't) — it is NOT yet verified specifically on this project's exact panel/run-loop configuration. **This is exactly what D-05's mandatory spike must confirm before any production code is built.**

**Primary recommendation:** Sequence a ~30-45 minute on-device spike as the first task of the first wave (see `## Recommended Spike`) that adds two throwaway always-on global monitors (`.leftMouseDragged`, `.leftMouseUp`) logging `NSPasteboard(name: .drag).changeCount` deltas, extracted URLs via the EXISTING `fileURLs(from:)`, and final pointer location — confirmed against a real Finder-initiated drag toward the notch, starting from outside any hot-zone, exactly mirroring 22-01's own successful spike methodology. Only after this passes should the full `handleDragApproach…`/accept/shelf-landing logic (Pattern 3/4 below) be built.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| External drag-session detection (`NSEvent` global monitors + `NSPasteboard(name: .drag)` polling) | Browser/Client (AppKit, process-wide event observation) | — | No `NSDraggingDestination` registration anywhere; this is a passive systemwide observer, architecturally identical in tier to the existing `mouseMonitor`/`dragReleaseMonitor` |
| Accept-region geometry (`expandedZone` + landing-margin) | Client (`NotchWindowController`) | — | Pure reuse of Phase 22's already-computed, never-invalidated geometry (D-02) |
| Auto-expand / hot-feedback state mutation | Client (`NotchInteractionState` via `nextState(_, .dragEntered)`, already exists post-Phase-22-02) | — | Unchanged pure seam; only the AppKit-side trigger mechanism changes |
| Click-through / hit-test gating (`ignoresMouseEvents`) | Client (`NotchWindowController.syncClickThrough()`) | — | Orthogonal to this phase's detection mechanism (see Pattern 3) — global monitors bypass window hit-testing entirely, so the single arbiter is touched only at drag-end for pointer re-sync, never on the drop's critical path |
| File/folder URL extraction from the drag pasteboard | Client (`DragDropSupport.swift`, unchanged Phase 22 pure seam) | — | `fileURLs(from:)` already accepts any `NSPasteboard`, confirmed by its own existing tests using arbitrary named pasteboards |
| Landing dropped items into the shelf | Client (`ShelfCoordinator.append` + `ShelfFileStore` copy-in, Phase 19, unchanged) | — | This phase is purely a new caller |

There is no server/backend tier in this app — everything is local AppKit/SwiftUI process, consistent with every prior phase.

## Standard Stack

### Core
No new external dependencies. 100% first-party Apple frameworks, all already linked: `AppKit` (`NSEvent`, `NSPasteboard`, `NSPasteboard.Name.drag`), `Foundation` (`URL`).

| Framework | Purpose | Confidence |
|-----------|---------|------------|
| AppKit (`NSEvent.addGlobalMonitorForEvents(matching:handler:)`) | Passive systemwide event observation — already used twice in this codebase (`mouseMonitor`, `dragReleaseMonitor`) | HIGH — production-proven in this exact codebase |
| AppKit (`NSPasteboard(name: .drag)`, `changeCount`, `readObjects(forClasses:options:)`) | Reading dragged file/folder URLs from the systemwide drag pasteboard without being the drop destination | MEDIUM — mechanism cross-verified via WebSearch (multiple independent sources agree), not found stated in an official Apple doc page (fetch attempts on `developer.apple.com/documentation/appkit/nspasteboard/name/drag` returned 404/no-body during this research session) |

### Package Legitimacy Audit

**Not applicable — no external packages are introduced by this phase.** Every API is a first-party Apple framework already linked by the app. `slopcheck`/registry verification is out of scope per the gate's own external-package-only trigger.

## Architecture Patterns

### System Architecture Diagram

```
Finder / other app (drag source, owns its OWN modal drag-tracking run loop —
                     Islet's run loop is NEVER part of this loop, since Islet
                     is not a registered NSDraggingDestination in this design)
        │
        ▼  systemwide HID/WindowServer mouse events, observed via CGEventTap
        │  (independent of which run loop mode the SOURCE app is in)
        │
┌───────────────────────────────────────────────────────────────────────┐
│ NotchWindowController (NO changes to NotchPanel.swift — it stays a     │
│ zero-drag-code window shell, per 23-CONTEXT.md D-01)                   │
│                                                                          │
│  dragApproachMonitor: NSEvent.addGlobalMonitorForEvents([.leftMouseDragged])│
│    on each tick:                                                        │
│      • read NSPasteboard(name: .drag).changeCount                       │
│      • changed from stored baseline? -> a real drag-and-drop session    │
│        began (NOT an ordinary mouse drag/window-move/text-select --     │
│        those never touch this pasteboard)                               │
│      • fileURLs(from: NSPasteboard(name: .drag)) -- REUSED unchanged    │
│        from Phase 22's DragDropSupport.swift                            │
│      • recheck isWithinDragAcceptRegion(NSEvent.mouseLocation) on       │
│        EVERY tick (drag pasteboard changeCount is stable across many    │
│        ticks of the SAME drag -- geometry must be polled continuously,  │
│        there is no draggingUpdated equivalent)                          │
│      • edge-tracked (WR-01-style) isDragApproaching flag flips once ->  │
│        haptic + hover-bounce spring + nextState(_, .dragEntered)        │
│        (D-01/D-03/D-05/D-06, reusing the EXISTING .dragEntered pure     │
│        event from NotchInteractionState.swift, unchanged since 22-02)   │
│                                                                          │
│  dragEndMonitor: NSEvent.addGlobalMonitorForEvents([.leftMouseUp])      │
│    on each tick:                                                        │
│      • guard isDragApproaching else return (an ordinary click           │
│        elsewhere on the OS fires .leftMouseUp constantly -- this guard  │
│        makes it a harmless, idempotent no-op exactly like               │
│        endShelfItemDrag's own guard shape)                              │
│      • re-derive urls + pointer location; if shouldAcceptDrop(...) AND  │
│        isWithinDragAcceptRegion(...) -- append each URL as a ShelfItem  │
│        via the UNCHANGED Phase 19 ShelfCoordinator.append seam          │
│      • ALWAYS call handlePointer(at: NSEvent.mouseLocation) afterward   │
│        (Pitfall 3, carried forward from 22-RESEARCH -- .mouseMoved      │
│        tracking IS frozen while ANY drag session, inbound or outbound,  │
│        is in flight, so pointerInZone/lastPointerLocation must be       │
│        explicitly re-synced the instant the drag ends)                  │
└───────────────────────────────────────────────────────────────────────┘
        │
        ▼
ShelfCoordinator (Phase 19, unchanged) ──► ShelfViewState ──► NotchPillView shelf row (Phase 20, unchanged)
```

A reader can trace: Finder drag → systemwide event observed by Islet's own global monitors (no registration, no callback contract with the drag source) → `NSPasteboard(name: .drag)` polled for content → geometry-gated auto-expand reuses the exact `.dragEntered` pure transition already shipped in Phase 22-02 → drop is INFERRED at `.leftMouseUp` (not delivered via any AppKit drag-destination callback) → dropped URLs flow through the UNCHANGED Phase 19 `ShelfCoordinator.append` seam → the UNCHANGED Phase 20 shelf view re-renders.

### Recommended Project Structure

No new files required — fits entirely inside the existing `NotchWindowController.swift`, reusing `DragDropSupport.swift` and `NotchInteractionState.swift` unchanged:
```
Islet/Notch/
├── NotchPanel.swift              # UNCHANGED — stays a zero-drag-code window shell (23-CONTEXT.md D-01)
├── NotchWindowController.swift   # + dragApproachMonitor/dragEndMonitor properties (mirrors mouseMonitor/
│                                  #   dragReleaseMonitor's exact shape) + handleDragApproachTick/End methods
├── NotchInteractionState.swift   # UNCHANGED — .dragEntered event + nextState transitions already exist
│                                  #   (survived Phase 22-02, confirmed present in current codebase)
└── DragDropSupport.swift         # UNCHANGED — fileURLs(from:)/shouldAcceptDrop(isExpanded:urls:) reused
                                   #   as-is against NSPasteboard(name: .drag)
```

**Recommendation on the "DragApproachDetector" name (ROADMAP wording):** keep this as inline stored properties + private methods on `NotchWindowController`, exactly mirroring how `mouseMonitor`/`dragReleaseMonitor` are today — NOT a new extracted Swift type. The ROADMAP's naming refers to the *detection pattern*, not a mandated new class; this file has zero extracted monitor types today (Pitfall/anti-pattern: don't introduce the first one for a single call site — see Don't Hand-Roll below).

### Pattern 1: Detect a real external drag via `.leftMouseDragged` + `NSPasteboard(name: .drag)` changeCount, NOT `.mouseMoved`

**What:** Register an always-on global monitor for `.leftMouseDragged` (armed in `start()`, removed in `deinit`, mirroring `mouseMonitor`'s exact idiom). On every tick, compare `NSPasteboard(name: .drag).changeCount` against a stored baseline (seeded once at `start()`). A change means a genuine drag-and-drop session with real pasteboard content began — ordinary mouse drags that are NOT drag-and-drop operations (moving a window, a rubber-band selection, scrolling) never touch this pasteboard, so this is the correct semantic filter, not merely an optimization.

**Why not `.mouseMoved` (the existing `mouseMonitor`):** `.mouseMoved` only fires for the pointer moving with NO button held; a drag holds the button down, generating `.leftMouseDragged` instead. This is a different, additional monitor — `mouseMonitor` stays completely untouched.

**Example:**
```swift
// Source: cross-verified WebSearch pattern (Medium "Adding Drag-and-Drop Indicator in Your
// macOS App"; corroborated by multiple independent summaries of the same technique) — MEDIUM
// confidence, not an official Apple doc citation. Mirrors this codebase's own
// NSEvent.addGlobalMonitorForEvents(matching:) idiom (mouseMonitor, dragReleaseMonitor).
private var dragPasteboardChangeCount = NSPasteboard(name: .drag).changeCount
private var dragApproachMonitor: Any?

dragApproachMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
    self?.handleDragApproachTick()
}

private func handleDragApproachTick() {
    let pasteboard = NSPasteboard(name: .drag)
    if pasteboard.changeCount != dragPasteboardChangeCount {
        dragPasteboardChangeCount = pasteboard.changeCount
        // a NEW drag-and-drop session (not just any mouse drag) began or changed
    }
    // Geometry must be re-checked on EVERY tick, not just on a changeCount edge — see Pattern 2.
}
```

### Pattern 2: Edge-tracked auto-expand, polled continuously (no `draggingUpdated` equivalent exists)

**What:** Because there is no AppKit-delivered "drag is now hovering region X" callback in this design, `isWithinDragAcceptRegion(NSEvent.mouseLocation)` must be re-evaluated on every `.leftMouseDragged` tick — reusing the EXACT `expandedZone` + landing-margin geometry Phase 22's (aborted but architecturally sound) `22-03-PLAN.md` already designed:

```swift
// Source: this project's own 22-03-PLAN.md (D-02b/D-02c), unchanged geometry, re-derived here
// because dragLandingMaxY does not currently exist in the post-Phase-23 codebase (confirmed by
// this session's grep — Phase 23 deleted the entire Phase-22 drag scaffold, per 24-CONTEXT.md).
private var dragLandingMaxY: CGFloat?   // set alongside hotZone/expandedZone in positionAndShow,
                                          // cleared alongside them in updateVisibility's hide branch

private func isWithinDragAcceptRegion(_ location: CGPoint) -> Bool {
    guard let expandedZone, let dragLandingMaxY else { return false }
    return expandedZone.contains(location) && location.y <= dragLandingMaxY
}
```

An explicit boolean pin (`isDragApproaching`), edge-tracked exactly like `pointerInZone` (WR-01's own discipline), flips `true` exactly once per region-entry and drives the ONE-TIME auto-expand + hover-bounce (never re-fires on every tick while stationary):

```swift
private var isDragApproaching = false   // Phase 24 — mirrors pointerInZone's enter/exit edge shape

private func recheckDragAcceptRegion() {
    let point = NSEvent.mouseLocation
    let inside = !interaction.isExpanded && isWithinDragAcceptRegion(point)
    if inside && !isDragApproaching {
        isDragApproaching = true
        graceWorkItem?.cancel(); graceWorkItem = nil        // mirrors beginShelfItemDrag
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            interaction.phase = nextState(interaction.phase, .dragEntered)   // ALREADY EXISTS (22-02)
            renderPresentation()
        }
    } else if !inside && isDragApproaching {
        isDragApproaching = false   // pointer drifted back out mid-drag — let the normal grace timer resume
    }
}
```

### Pattern 3: `syncClickThrough()` stays completely untouched — the detector is orthogonal to click-through

**What:** Unlike Phase 22's `NSDraggingDestination` design (which needed `syncClickThrough()` called inside `handleDragEntered` so the panel could receive the eventual `performDragOperation` callback), **this design has no equivalent dependency.** Global event monitors observe copies of systemwide events regardless of `ignoresMouseEvents` — the flag governs only whether THIS app's OWN windows consume events targeted at them, which is irrelevant to a passive observer reading a systemwide pasteboard. The panel never needs to become click-interactive for the drop itself to be detected and accepted.

**What IS still needed:** at drag-end (`.leftMouseUp`, whether accepted or not), call `handlePointer(at: NSEvent.mouseLocation)` — this re-syncs `pointerInZone`/`lastPointerLocation`, which per Phase 21's own confirmed finding go STALE during ANY OS drag session (inbound or outbound) because `.mouseMoved` does not fire while a drag is in flight. `handlePointer(at:)` internally calls `syncClickThrough()` when appropriate, so ordinary post-drop click-through correctness is restored exactly the same way `endShelfItemDrag()` already does it for outbound drags.

**Why this satisfies CONTEXT.md's single-arbiter requirement:** the arbiter (`syncClickThrough()`) is not bypassed — it is simply not on this feature's critical path. It remains the SOLE writer of `ignoresMouseEvents`; the new `isDragApproaching` flag is read ONLY inside `handleHoverExit()`'s existing grace-collapse guard (mirroring `isDraggingShelfItem` exactly), never inside `syncClickThrough()` itself. Zero diff to `syncClickThrough()`'s body — same CR-01-safe pattern the (aborted, never-merged) `22-03-PLAN.md` already correctly designed for the old mechanism; only the AppKit registration/callback layer underneath it changes.

### Pattern 4: Drop completion is INFERRED at `.leftMouseUp`, not delivered via `performDragOperation`

**What:** There is no `NSDraggingDestination` in this design, so there is no AppKit-guaranteed "drag ended, here's the payload" callback. Drop acceptance must be inferred by combining three signals at the moment `.leftMouseUp` fires: (1) `isDragApproaching` was true (a real drag-and-drop session was tracked as being over the accept region), (2) the pointer is still within `isWithinDragAcceptRegion(...)` at release time, (3) `NSPasteboard(name: .drag)` still yields non-empty file URLs at that instant.

**Caveat (flag for the spike):** "the contents of the last drag are left indefinitely on the pasteboard by default unless an app explicitly clears it" — `NSPasteboard(name: .drag)` is a systemwide pasteboard that does NOT auto-clear after a drag ends `[MEDIUM: WebSearch, cross-referenced with Apple's general NSPasteboard persistence semantics]`. This is exactly why gating on `isDragApproaching` (armed only by a genuine `changeCount` delta while the pointer is in-region) is load-bearing, not cosmetic — reading the pasteboard's mere PRESENCE of a file URL, without the changeCount-driven session tracking, would falsely "detect" a drop from a completely unrelated earlier drag whose content is still sitting there.

```swift
private func handleDragApproachEnd() {
    guard isDragApproaching else { return }   // an ordinary click anywhere else on the OS fires
                                                // .leftMouseUp constantly — this guard is what makes
                                                // that a harmless idempotent no-op, mirroring
                                                // endShelfItemDrag's own guard shape exactly
    isDragApproaching = false
    let point = NSEvent.mouseLocation
    let pasteboard = NSPasteboard(name: .drag)
    let urls = fileURLs(from: pasteboard)      // UNCHANGED Phase 22 pure seam
    if shouldAcceptDrop(isExpanded: false, urls: urls), isWithinDragAcceptRegion(point) {
        for url in urls {
            let id = UUID()
            guard let localURL = try? ShelfFileStore.makeSessionCopy(of: url, id: id) else { continue }
            let item = ShelfItem(id: id, originalURL: url, localURL: localURL,
                                  filename: url.lastPathComponent, addedAt: Date())
            shelfCoordinator.append(item)
        }
        resyncShelfViewState()
    }
    handlePointer(at: NSEvent.mouseLocation)   // Pitfall 3 — re-sync frozen pointer tracking
}
```

### Anti-Patterns to Avoid
- **Registering `NotchPanel` as an `NSDraggingDestination` "just as a backup":** defeats the entire point of this phase's architectural pivot — the whole reason this mechanism exists is to route around the unexplained `draggingEntered` failure, not coexist with it.
- **Trusting `NSPasteboard(name: .drag)` presence alone as "a drop happened":** its content persists after the drag ends (see Pattern 4 caveat) — always gate on the `isDragApproaching` session-tracking flag, never on raw pasteboard content alone.
- **A second `ignoresMouseEvents` writer:** any new code that sets `panel?.ignoresMouseEvents` directly instead of going through `syncClickThrough()` reintroduces the CR-01 regression class — and per Pattern 3, this phase never needs to anyway.
- **Extracting a new `DragApproachDetector` Swift type for a single call site:** matches this file's existing zero-extracted-monitor-type convention (`mouseMonitor`/`dragReleaseMonitor` are both inline properties) — an unrequested abstraction the codebase doesn't otherwise use.
- **Recursing into a dropped folder's contents:** unchanged from Phase 22 — `fileURLs(from:)` already returns a folder's own URL as one item; never enumerate it.
- **Treating every `.leftMouseDragged`/`.leftMouseUp` tick as drag-related:** both fire for ANY mouse drag/click anywhere on the OS (window moves, text selection, ordinary clicks) — the `changeCount`/`isDragApproaching` gates are the load-bearing filters, not an incidental detail.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Detecting an external drag-and-drop session without being the destination | A custom `CGEventTap` / Accessibility-API-based drag observer | `NSEvent.addGlobalMonitorForEvents` (already proven twice in this codebase) + `NSPasteboard(name: .drag)` | `CGEventTap` requires the separate, heavier Input Monitoring privilege and no permission-prompt precedent exists in this app; `NSEvent` global monitors are the established, lighter-weight mechanism this codebase already ships with |
| Extracting file URLs from a drag pasteboard | New pasteboard-type parsing | `DragDropSupport.swift`'s existing `fileURLs(from:)` | Already built, tested, and confirmed to work against ANY named `NSPasteboard` (its own tests use arbitrary fresh pasteboards) — zero reason to duplicate |
| Copying the dropped file into session storage | New copy logic | `ShelfFileStore.makeSessionCopy(of:id:)` (Phase 19, unchanged) | Already built, tested, sole owner of the session-copy contract |
| Deduping a re-dropped file already in the shelf | New dedup logic | `ShelfCoordinator.append` → `ShelfLogic.append`'s existing dedup (Phase 19) | Already handles silent no-op on duplicate |
| A new "DragApproachDetector" abstraction type | A dedicated class/protocol wrapping the two monitors | Inline properties/methods on `NotchWindowController` | Matches this file's existing zero-extracted-monitor-type convention; a new type for one call site is an unrequested abstraction |

**Key insight:** this phase's ENTIRE novel surface is the detection layer (two global monitors + pasteboard polling + edge-tracked accept-region check). Everything downstream of "I have a list of dropped `URL`s" already exists from Phase 19/20/22-02 and must not be re-built — this is a smaller diff than Phase 22's own `22-03-PLAN.md`, because that plan's entire controller-side design (single-arbiter discipline, `expandedZone`/landing-margin geometry, edge detection, `.dragEntered` pure event) was already correct and simply needs to be re-triggered from a different detection source.

## Common Pitfalls

### Pitfall 1: Confusing the outbound-drag `.mouseMoved`-freeze finding with this phase's inbound mechanism
**What goes wrong:** Reading `endShelfItemDrag()`'s comment ("the .mouseMoved monitor doesn't fire during an OS drag session") and concluding global monitors are unreliable during ANY drag, including this phase's detection monitors.
**Why it happens:** That comment is about Islet's OWN outbound drag (Islet is the drag source, so Islet's OWN run loop enters AppKit's modal `eventTracking` mode). This phase's monitors observe an INBOUND drag Islet never initiates — Islet's run loop stays in default mode throughout, since Finder (not Islet) owns the modal tracking loop.
**How to avoid:** Keep this distinction explicit in code comments on the new monitors, so a future reader doesn't "fix" a non-bug by assuming the same freeze applies.
**Warning signs:** Confusion during code review about why this phase's monitors are expected to work when Phase 21's comment says otherwise.

### Pitfall 2: `NSPasteboard(name: .drag)` content persisting after the drag ends (Pattern 4's caveat, restated)
**What goes wrong:** A drop is falsely detected from a completely unrelated PRIOR drag's leftover pasteboard content.
**Why it happens:** The drag pasteboard is not auto-cleared by the OS once a drag concludes.
**How to avoid:** Gate every accept decision on the `isDragApproaching` session flag (armed only by a genuine `changeCount` delta observed while the pointer is in-region), never on raw pasteboard presence alone.
**Warning signs:** A drop appearing to "land" from a file the user dragged minutes earlier and released somewhere unrelated.

### Pitfall 3: Repeated auto-expand firing on every `.leftMouseDragged` tick
**What goes wrong:** `withAnimation`/`.dragEntered` fires repeatedly while the drag hovers stationary over the accept region.
**Why it happens:** `.leftMouseDragged` fires continuously (many ticks per second) during a drag — there is no discrete "entered" event like `draggingEntered` was.
**How to avoid:** Edge-track `isDragApproaching` exactly like `pointerInZone`'s existing WR-01 discipline (Pattern 2) — only the `false → true` transition fires the spring/haptic/state-transition.
**Warning signs:** Visual stutter/flicker of the expand spring while a file is held stationary over the region.

### Pitfall 4: `.leftMouseUp` firing for every ordinary click anywhere on the OS
**What goes wrong:** Without a guard, `handleDragApproachEnd()` runs its full accept-check logic on every single click across the entire system (not just drag releases), wasting cycles and risking a stray false accept if a stale `isDragApproaching`/pasteboard state ever desyncs.
**Why it happens:** `.leftMouseUp` is a generic mouse-button-release event, not drag-specific.
**How to avoid:** `guard isDragApproaching else { return }` as the very first line (Pattern 4) — mirrors `endShelfItemDrag()`'s own idempotent-guard shape exactly.
**Warning signs:** CPU/log noise on every click if the guard is missing or misplaced.

### Pitfall 5: An Escape-cancelled drag never producing a clean `.leftMouseUp` in the expected place
**What goes wrong:** If the user cancels a drag mid-flight (Escape key, or drags back to the source and releases), `isDragApproaching` may be left `true` with no accept ever completing correctly, or the accept-region re-check at release time may behave unpredictably relative to where the drag visually "was."
**Why it happens:** Without `NSDraggingDestination`'s AppKit-guaranteed termination callback contract (`draggingExited`/`performDragOperation`→`draggingEnded`, always exactly one), this design relies entirely on `.leftMouseUp` firing eventually — which it always does once the physical mouse button is released, but the SEMANTIC "was this a cancel or a real drop" is inferred purely from geometry, not delivered by AppKit.
**How to avoid:** This is an accepted residual risk under D-07's reliability bar ("an occasional missed drop is acceptable IF it fails silently... no frozen hover/click-through state"). `isDragApproaching` is always cleared unconditionally at the top of `handleDragApproachEnd()` before any accept logic runs, so even a geometrically-ambiguous cancel can never leave the pin stuck — worst case is a silently-rejected drop, never a stuck state. Recommend the spike (D-05) explicitly test an Escape-cancelled drag as one of its scenarios.
**Warning signs:** The island staying pinned/expanded after a cancelled drag with no file landing and no natural collapse.

### Pitfall 6: Treating a dropped folder as a container to enumerate
**What goes wrong / How to avoid:** Unchanged from Phase 22 — `fileURLs(from:)` already returns a folder's own URL as ONE item; REQUIREMENTS.md Out of Scope explicitly excludes folder spring-loading.
**Warning signs:** A dropped folder producing N shelf items instead of 1.

## Code Examples

See `## Architecture Patterns` Patterns 1-4 above for the full illustrative flow (detection tick → edge-tracked accept-region check → drop inference at `.leftMouseUp`). All code there is a recommended SHAPE for the planner to detail exactly — not verified on-device yet; that is D-05's job.

### Extracting file/folder URLs — REUSED UNCHANGED from Phase 22
```swift
// Islet/Notch/DragDropSupport.swift — already merged, zero changes needed for this phase
func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
    (pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]) ?? []
}
func shouldAcceptDrop(isExpanded: Bool, urls: [URL]) -> Bool {
    !isExpanded && !urls.isEmpty
}
```
Confirmed by `DragDropSupportTests.swift` (existing) to work against arbitrary named `NSPasteboard` instances — `NSPasteboard(name: .drag)` is just another named pasteboard from this function's point of view.

### The `.dragEntered` pure interaction event — ALREADY EXISTS (survived Phase 22-02, confirmed present)
```swift
// Islet/Notch/NotchInteractionState.swift (current, unmodified)
enum InteractionEvent: Equatable { case pointerEntered, pointerExited, clicked, graceElapsed, dragEntered }
// nextState handles: (.hovering, .dragEntered) -> .expanded, (.collapsed, .dragEntered) -> .expanded
```

## State of the Art

| Old Approach (Phase 22, abandoned) | Current Approach (this phase) | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `NSDraggingDestination` registration on `NotchPanel` (`registerForDraggedTypes`, `draggingEntered`/`performDragOperation`) | Passive `NSEvent` global-monitor observation of `.leftMouseDragged`/`.leftMouseUp` + `NSPasteboard(name: .drag)` polling | This phase (Phase 24), per the user's explicit architectural pivot after 2 unexplained on-device failures | No AppKit drag-destination callback contract is relied upon anywhere; drop completion is inferred, not delivered |
| `NSFilenamesPboardType` string-array pasteboard reading | `NSPasteboard.readObjects(forClasses: [NSURL.self], options:)` | Long-standing modern API, unchanged from Phase 22 | Still the correct approach, now applied to `.drag` instead of `sender.draggingPasteboard` |

**Deprecated/outdated:** None newly relevant to this phase — the underlying pasteboard-reading API is unchanged from Phase 22's already-verified findings.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `.leftMouseDragged`/`.leftMouseUp` global monitors registered in Islet fire reliably during an EXTERNAL (Finder-initiated) drag session, because Islet's own run loop never enters the modal `eventTracking` mode that only affects the drag SOURCE's process | Summary, Pattern 1 | HIGH — if wrong, this phase's entire mechanism cannot work and a THIRD architectural pivot would be needed; this is exactly why D-05's spike is the mandatory first step, mirroring Phase 22's own A1 |
| A2 | `NSPasteboard(name: .drag)` is populated with real content as soon as ANY app (not just the eventual destination) begins a drag session, and is readable by a non-destination, non-sandboxed app with no special entitlement | Summary, Pattern 1/4 | MEDIUM-HIGH — if the pasteboard is empty/inaccessible until a formal destination registers, the changeCount-based detection degrades to "detects that some drag started" without being able to read WHAT was dragged, breaking the auto-expand-with-content-preview design (though D-01's auto-expand itself doesn't strictly need file identity, only "a drag is happening") |
| A3 | The `.leftMouseDragged` global monitor does not require Accessibility/Input-Monitoring permission, consistent with `.mouseMoved` (already proven permission-free in this exact codebase since Phase 2) | Standard Stack | LOW-MEDIUM — official sources confirm ONLY keyboard events require Accessibility trust for `NSEvent` global monitors; mouse-button events are documented as not requiring it, and this project's own `mouseMonitor` (a different mouse-event type) already ships working with zero permission prompt |
| A4 | An Escape-cancelled or otherwise anomalous drag termination always still fires `.leftMouseUp` on the physical mouse-button release, even though AppKit's own drag session may have been logically cancelled before that | Pitfall 5 | MEDIUM — if some cancellation paths never fire `.leftMouseUp` at all (e.g., a drag terminated by the source app quitting mid-drag), `isDragApproaching` could theoretically stay stuck true until the NEXT `.leftMouseUp` anywhere, incorrectly gating that unrelated click's guard — low practical impact per D-07's silent-failure bar, but worth an explicit spike scenario |

## Open Questions (DEFERRED TO EXECUTION — resolved empirically by 24-01's spike)

1. **Does `.leftMouseDragged`/`.leftMouseUp` actually fire reliably in Islet's global monitor for a Finder-initiated drag, on THIS project's exact configuration?**
   - What we know: The technique is a well-established, cross-verified real-world pattern used by drag-utility menu-bar apps; the architectural reasoning (Islet's run loop never enters the drag source's modal tracking mode) is internally consistent and does NOT contradict this codebase's own opposite-looking finding for outbound drags (different mechanism — see Pitfall 1).
   - What's unclear: No official Apple documentation was found during this research session explicitly stating this behavior (docs pages for `NSPasteboard.Name.drag` and `addGlobalMonitorForEvents` returned no fetchable body content in this session — WebSearch snippets were the best available source). Phase 22's own history is a direct warning that "should work per general understanding" empirically didn't for the OLD mechanism on this exact panel.
   - Recommendation: D-05's spike resolves this empirically, exactly as 22-01 did for the old mechanism. Do not build production logic before it passes.

2. **Is `NSPasteboard(name: .drag)` readable mid-drag with zero timing race against the drag source's own eventual `concludeDragOperation` cleanup on the destination side?**
   - What we know: Since Islet is not a registered `NSDraggingDestination` in this design, no `concludeDragOperation` callback exists on Islet's side to race against at all — this specific race class from the old design does not apply here.
   - What's unclear: Whether there's a brief window at the very start of a drag (before the first `.leftMouseDragged` tick lands) where `changeCount` has already incremented but `readObjects` briefly returns stale/empty content, or vice versa.
   - Recommendation: The spike's logging should include the URL list on EVERY tick where a changeCount delta is observed, not just the first — if content ever fails to resolve immediately, this will be visible in the spike's console output.

## Environment Availability

No new external dependencies or services — same Xcode 16+/Swift 5-mode/macOS 14.0 deployment toolchain already in use for every prior phase. `[VERIFIED: project.yml, confirmed unchanged since Phase 22-RESEARCH.md]`

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / xcodebuild | Build gate | ✓ (existing project convention) | 16+ (Tahoe build machine: Xcode 26.6 per project memory `build-machine-macos26-toolchain`) | — |
| On-device manual run (Cmd-R) | The spike (drag delivery cannot be verified headlessly) | ✓ (developer's own Mac) | — | None — `xcodebuild test` hangs headlessly per project memory `xcodebuild-test-headless-hang`; this phase's core risk is fundamentally undeterminable without an interactive on-device session |

**Missing dependencies with no fallback:** None — all required tooling is already installed and used by every prior phase.

## Recommended Spike

Per D-05/D-06's explicit lock and mirroring Phase 22-01's own successful methodology exactly:

1. Add two throwaway always-on global monitors in `NotchWindowController.start()` (mirroring `mouseMonitor`'s exact registration shape): `.leftMouseDragged` and `.leftMouseUp`.
2. In the `.leftMouseDragged` handler: read `NSPasteboard(name: .drag).changeCount`; on any delta from a stored baseline, `NSLog` the delta plus `fileURLs(from: NSPasteboard(name: .drag))` (reusing the existing pure function unchanged) plus the current `NSEvent.mouseLocation`.
3. In the `.leftMouseUp` handler: `NSLog` the final pointer location plus whatever `fileURLs(from:)` returns at that instant, unconditionally (no `isDragApproaching` guard yet — this spike is purely observational).
4. Build and run on-device (Cmd-R — NOT `xcodebuild test`, per project memory `xcodebuild-test-headless-hang`).
5. With the pointer starting well OUTSIDE any hot-zone/expandedZone (mirroring 22-01's exact methodology to rule out any dependency on prior hover state), drag a single file from Finder toward the notch. Confirm in the console: (a) `.leftMouseDragged` ticks fire with a changed pasteboard count, (b) the correct file URL is logged, (c) `.leftMouseUp` fires with the correct final location and still-readable URL.
6. Repeat with: multiple files selected together, a folder, and — per Pitfall 5/Assumption A4 — a drag that is cancelled with Escape instead of dropped.
7. Record the empirical PASSED/FAILED verdict (and any surprising timing/content-availability findings from Open Question 2) in the phase's task notes/SUMMARY before writing the rest of the drag-in logic — exactly mirroring how `22-01-SUMMARY.md` recorded A1's resolution.

This spike is cheap (well under an hour, no permanent code committed if it fails) and resolves this phase's single largest risk — precisely the discipline D-05/D-06 lock in.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing `IsletTests` target) |
| Config file | `project.yml` (XcodeGen) — scheme `Islet`, test target already wired |
| Quick run command | `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` (BUILD gate only) |
| Full suite command | Manual Cmd-U in Xcode GUI — `xcodebuild test` hangs headlessly in this environment (project memory `xcodebuild-test-headless-hang`) |

**Critical caveat, unchanged from Phase 22:** the core SHELF-01/SHELF-02 behavior (does a drag actually get detected and land) is fundamentally **not unit-testable** — it requires a real Window Server drag session, which no XCTest harness exercises. Automated tests can only cover the PURE seams (URL extraction — already covered by `DragDropSupportTests.swift`; the edge-detection logic for one-shot auto-expand if extracted as a pure function; `isWithinDragAcceptRegion`'s geometry math if extracted as a pure function). The actual "does the drag get detected, does the drop land" question is exclusively a manual/on-device verification item, mirrored by the spike above.

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SHELF-01 | Dropped file/folder URLs become `ShelfItem`s in drop order, collapsed-only | unit (pure extraction/append logic) | `xcodebuild test -only-testing:IsletTests/DragDropSupportTests` (via Cmd-U) | ✅ `DragDropSupportTests.swift` exists and already covers `fileURLs(from:)`/`shouldAcceptDrop` |
| SHELF-01 | The drag is actually detected by the global monitors and the drop lands | manual-only | N/A — no automated harness can simulate a real OS drag session | ❌ Wave 0 gap — this is the spike itself, and the phase's own manual/human-UAT step |
| SHELF-02 | Hot/targeted feedback shows before release | manual-only (visual) + unit (edge-detection logic pure function, if extracted) | Manual Cmd-R visual check; a new unit test for `isWithinDragAcceptRegion`'s pure geometry math is recommended | ❌ Wave 0 gap — new pure-function test needed once the geometry helper exists |

### Sampling Rate
- **Per task commit:** `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` (build-only gate, matches every prior phase's convention)
- **Per wave merge:** Same build gate + manual Cmd-U for any new/changed pure-seam unit tests + a manual on-device drag verification pass
- **Phase gate:** Full manual on-device UAT (drag single file, multiple files, a folder, an Escape-cancel) before `/gsd:verify-work` — this phase cannot be verification-complete without human hands-on testing

### Wave 0 Gaps
- [ ] A pure-function unit test for `isWithinDragAcceptRegion(_:)`'s geometry math (expandedZone + landing-margin), testable without any real drag session — new for this phase, since `dragLandingMaxY` does not currently exist in the codebase
- [ ] The spike itself (no automated harness possible — manual on-device only)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | No auth surface in this app |
| V3 Session Management | No | N/A |
| V4 Access Control | No | Single-user local app |
| V5 Input Validation | Yes | Reject non-file-URL pasteboard payloads at the drop boundary (unchanged Phase 22 `shouldAcceptDrop` gate); only accept content `fileURLs(from:)` can resolve to real `URL`s |
| V6 Cryptography | No | No crypto surface introduced |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| Malicious/oversized drop payload (thousands of files in one drag) causing resource exhaustion | Denial of Service | Folder is NEVER enumerated (unchanged Phase 22 finding) — only the top-level URL is touched; unbounded shelf capacity is an already-accepted design decision (Phase 19/22-RESEARCH.md Security Domain) |
| Stale drag-pasteboard content falsely accepted as a new drop (Pitfall 2) | Spoofing / Tampering (of the app's own state, not a real external attacker) | The `isDragApproaching` session-tracking gate (armed only by a genuine `changeCount` delta observed while in-region) is the mitigation — never trust raw pasteboard presence alone |
| Dropped file path traversal / symlink pointing outside sandbox | Tampering | Not applicable — unchanged from Phase 22: this app is NOT sandboxed, and `ShelfFileStore.makeSessionCopy` already validates before any I/O; no new trust boundary introduced by switching detection mechanisms |
| A stuck `isDragApproaching` pin never releasing (island stuck expanded, violating Success Criterion #3) | Denial of Service (self, availability) | `handleDragApproachEnd()` unconditionally clears the flag before any accept logic runs (Pitfall 5) — a geometrically-ambiguous cancel can never leave the pin stuck, per D-07's silent-failure reliability bar |

## Sources

### Primary (HIGH confidence)
- This project's own `Islet/Notch/NotchWindowController.swift` (`mouseMonitor`, `dragReleaseMonitor`, `syncClickThrough()`, `endShelfItemDrag()`) — read in full this session, the direct architectural precedent for every pattern recommended above
- This project's own `.planning/phases/22-drag-in/22-03-PLAN.md` — the aborted-but-architecturally-sound controller-side design (single-arbiter discipline, `expandedZone`/landing-margin geometry, edge detection) this research recommends re-triggering from a new detection source
- This project's own `Islet/Notch/DragDropSupport.swift` + `IsletTests/DragDropSupportTests.swift` — confirmed to work against arbitrary named pasteboards, reusable as-is
- `developer.apple.com/documentation/foundation/runloop/mode/eventtracking` — confirms `eventTracking` is "the mode set when tracking events modally, such as a mouse-dragging loop," the basis for Pitfall 1's outbound-vs-inbound distinction `[CITED]`

### Secondary (MEDIUM confidence)
- WebSearch cross-referencing a dedicated AppKit drag-indicator technique article ("Adding Drag-and-Drop Indicator in Your macOS App," Medium) — direct fetch returned HTTP 410 (content removed since indexing), but the technique was corroborated across multiple independent WebSearch result summaries describing the identical `NSPasteboard(name: .drag)` + `changeCount` + `.leftMouseDragged`/`.leftMouseUp` pattern
- WebSearch on `addGlobalMonitorForEvents` Accessibility-permission scope — confirms keyboard events require Accessibility trust, mouse events documented separately (consistent with this project's own working `.mouseMoved` monitor)

### Tertiary (LOW confidence)
- `developer.apple.com/documentation/appkit/nspasteboard/name/drag` and `developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)` — direct WebFetch attempts on both returned no retrievable body content in this session (404 / title-only); listed for completeness, not usable as citation-quality sources this session

## Metadata

**Confidence breakdown:**
- Standard stack (APIs/mechanics): HIGH — every API used is already proven working in this exact codebase (`NSEvent.addGlobalMonitorForEvents`) or already implemented/tested (`fileURLs(from:)`)
- Architecture (detection mechanism, single-arbiter compatibility): MEDIUM — mechanically well-reasoned and cross-verified against real-world precedent, but the load-bearing runtime behavior (Assumption A1) is unverified on THIS project's exact configuration, by design — Phase 22's own history is the reason this is not claimed HIGH
- Pitfalls: MEDIUM-HIGH — Pitfalls 2-6 are derived directly from either this codebase's own established patterns or the cross-verified external technique's documented caveats; Pitfall 1/5 and Assumption A1/A4 are the genuinely unresolved items, by design

**Research date:** 2026-07-11
**Valid until:** 30 days (stable Apple framework APIs; the on-device spike result, once run, should be recorded permanently in the phase's task notes/SUMMARY rather than re-researched, exactly as 22-01-SUMMARY.md did)
