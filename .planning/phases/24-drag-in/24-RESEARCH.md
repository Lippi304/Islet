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

**Drop-interception fix (architecture gap, added post-Task-3 UAT, 2026-07-11)**
- **D-10:** Pursue **CGEventTap** first as the mechanism to stop the real OS drag session from reaching whatever's underneath (currently: Finder Desktop's default same-volume move). A tap's callback can swallow/modify an event before it propagates further (e.g., return NULL for the terminating `.leftMouseUp` so Finder's Desktop view never sees the drop complete). Rejected as the first choice: re-attempting a scoped `NSDraggingDestination` (the exact technique that silently failed to fire twice in Phase 22, root cause never identified — retrying without new insight is low-confidence) and the move-back mitigation (kept in reserve as the fallback, see D-14, not the primary approach).
- **D-11:** Request the new **Input Monitoring** permission lazily, at first real use — the first time the user actually drags a file toward the collapsed island — not upfront during app launch. Islet's onboarding flow (Phase 26) doesn't exist yet, so there's no natural home for an upfront pre-explanation screen this phase; matches the project's general lazy-permission-ask preference. `.planning/research/inspiration/notes.md` (Droppy reference) shows the target pre-explanation pattern (one-line reason before the system prompt) to mirror once Phase 26 exists, but that polish is explicitly Phase 26's problem, not this phase's.
- **D-12:** If the user denies (or never grants) Input Monitoring, drag-in silently falls back to today's behavior: the shelf still receives the file copy (already works), but the original file may still get relocated by the OS — no worse than the current known gap, no error dialog. Consistent with the codebase's existing silent-no-op precedent (D-07).
- **D-13:** CGEventTap is itself a brand-new, unproven-in-this-codebase mechanism — same risk category `DragApproachDetector` was in before this phase started. Cap validation at **2 on-device rounds** (mirrors D-05/D-06: one implementation attempt + one fix-and-retry round). If still unreliable after the cap, stop and apply D-14's fallback rather than a fourth architecture pivot or indefinite debugging (same discipline as D-08).
- **D-14:** If CGEventTap is abandoned after the capped rounds, ship with the **move-back mitigation** as the fallback: detect that the OS performed its default same-volume move and move the file back to its original location. Imperfect (heuristic, some edge-case risk — name collisions, timing races) but closes the data-loss risk without triggering a fourth full architecture pivot.
- **D-15:** The tap swallows the terminating drag event for **every** drag landing in the accept zone, regardless of source app or volume — not scoped to only the specific same-volume-move risk. Detecting volume/operation-type ahead of the drop completing is fragile and adds a new failure surface for marginal precision gain; simplest and most consistent behavior wins here.

### Claude's Discretion
- Exact AppKit/Foundation mechanism for the `DragApproachDetector` (which `NSEvent` types to monitor, how to read the systemwide drag pasteboard to obtain file URLs without `NSDraggingDestination`) — resolved by this research below.
- How "an active drag session" is detected to gate the widened accept zone — must route through the SAME single arbiter that already owns `ignoresMouseEvents`/`syncClickThrough()` (project memory `cr01-clickthrough-or-defeat-gotcha`) — NOT a parallel flag.
- Multi-file/folder drag ordering into the shelf — follows Phase 19 D-06 (append in drop order), same as every other shelf-add path.
- Behavior when a drag carries non-file content (no file URL) — treat as a no-drop/reject, consistent with the shelf's file-only model.
- Behavior when drag-in is attempted while a Charging/Device splash is actively suppressing the shelf (SHELF-09) — default to the same silent-no-op precedent unless research surfaces a reason to special-case it.
- Exact margin value for the landing-below-top-edge accept condition (D-02c inherited from Phase 22) — measure against the reserved footprint's existing height.
- Exact CGEventTap event mask/tap location (`.cgSessionEventTap` vs `.cgAnnotatedSessionEventTap`, which event types to intercept beyond the terminating mouse-up) and how the Input Monitoring permission-check/prompt call is wired — not discussed with the user; research must validate whether swallowing a raw event actually prevents the Window Server's own drag-session completion (the STATE.md blocker note flags this as genuinely uncertain, not assumed to "just work"), same isolated-spike-first discipline as D-05 applied to this new mechanism.
- Exact detection method for the D-14 move-back fallback (only needed if D-13's cap is hit) — e.g., comparing the original source path's existence post-drop vs. searching the likely destination — deferred until/unless the fallback is actually triggered, not designed preemptively.

### Deferred Ideas (OUT OF SCOPE)
- **Accepting drag-in while the island is already expanded** — explicitly raised during discussion and rejected as in-scope for Phase 24 (D-09). If wanted, this is a new capability for a future phase/requirement.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SHELF-01 | User can drag a file, multiple files, or a folder onto the collapsed island — it auto-expands and the item(s) land in a shelf strip below the expanded view | `## Architecture Patterns` (Patterns 1-4: detection, edge-tracked auto-expand, geometry reuse, drop-inference-at-mouseUp), `## Code Examples`, `## Recommended Spike`, and `## CGEventTap Drop-Interception Research` below for the drop-interception fix |
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
| Drop-completion interception (swallowing the terminating raw HID event so Finder's Desktop never sees the drop) | Client (new `CGEventTap`-based type, see `## CGEventTap Drop-Interception Research` below) | — | Sits BELOW the AppKit/`NSEvent` layer — a session-level Core Graphics event tap, not a window-level or Application-level construct; genuinely new tier of intervention for this codebase |

There is no server/backend tier in this app — everything is local AppKit/SwiftUI process, consistent with every prior phase.

## Standard Stack

### Core
No new external dependencies. 100% first-party Apple frameworks, all already linked: `AppKit` (`NSEvent`, `NSPasteboard`, `NSPasteboard.Name.drag`), `Foundation` (`URL`).

| Framework | Purpose | Confidence |
|-----------|---------|------------|
| AppKit (`NSEvent.addGlobalMonitorForEvents(matching:handler:)`) | Passive systemwide event observation — already used twice in this codebase (`mouseMonitor`, `dragReleaseMonitor`) | HIGH — production-proven in this exact codebase |
| AppKit (`NSPasteboard(name: .drag)`, `changeCount`, `readObjects(forClasses:options:)`) | Reading dragged file/folder URLs from the systemwide drag pasteboard without being the drop destination | MEDIUM — mechanism cross-verified via WebSearch (multiple independent sources agree), not found stated in an official Apple doc page (fetch attempts on `developer.apple.com/documentation/appkit/nspasteboard/name/drag` returned 404/no-body during this research session) |
| Core Graphics (`CGEvent.tapCreate`, `CFMachPortCreateRunLoopSource`, `CFRunLoopAddSource`) | Session-level raw event tap to swallow the terminating `.leftMouseUp` before Finder's Desktop sees the drop complete | MEDIUM — mechanism and API shape are HIGH confidence (official Apple docs + multiple cross-verified code examples), but its EFFECT on an in-flight WindowServer drag session is genuinely unverified — see `## CGEventTap Drop-Interception Research` below |

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
│                                                                          │
│  [POST-TASK-3 ADDITION] DropInterceptTap (new type, see CGEventTap      │
│  section below): a CGEventTap at .cgSessionEventTap, tapping ONLY       │
│  .leftMouseUp, .defaultTap options — conditionally returns nil for      │
│  the SAME event dragEndMonitor above would accept, so the raw HID       │
│  event never reaches Finder's Desktop view underneath. Reads the SAME   │
│  isDragApproaching/expandedZone/dragLandingMaxY state (via a narrow     │
│  callback interface) to decide whether to swallow — never a second     │
│  parallel state machine.                                                │
└───────────────────────────────────────────────────────────────────────┘
        │
        ▼
ShelfCoordinator (Phase 19, unchanged) ──► ShelfViewState ──► NotchPillView shelf row (Phase 20, unchanged)
```

A reader can trace: Finder drag → systemwide event observed by Islet's own global monitors (no registration, no callback contract with the drag source) → `NSPasteboard(name: .drag)` polled for content → geometry-gated auto-expand reuses the exact `.dragEntered` pure transition already shipped in Phase 22-02 → at release, the NEW `DropInterceptTap` swallows the raw terminating event before Finder's Desktop ever sees it (if the accept region is armed) → drop is INFERRED at `.leftMouseUp` by Islet's own passive monitor (not delivered via any AppKit drag-destination callback) → dropped URLs flow through the UNCHANGED Phase 19 `ShelfCoordinator.append` seam → the UNCHANGED Phase 20 shelf view re-renders.

### Recommended Project Structure

No new files required for the detection layer — fits entirely inside the existing `NotchWindowController.swift`, reusing `DragDropSupport.swift` and `NotchInteractionState.swift` unchanged. **The post-Task-3 `DropInterceptTap` addition IS a new file** (see `## CGEventTap Drop-Interception Research` §5 below for the rationale):
```
Islet/Notch/
├── NotchPanel.swift              # UNCHANGED — stays a zero-drag-code window shell (23-CONTEXT.md D-01)
├── NotchWindowController.swift   # + dragApproachMonitor/dragEndMonitor properties (mirrors mouseMonitor/
│                                  #   dragReleaseMonitor's exact shape) + handleDragApproachTick/End methods
│                                  #   + owns one DropInterceptTap instance (post-Task-3 addition)
├── NotchInteractionState.swift   # UNCHANGED — .dragEntered event + nextState transitions already exist
│                                  #   (survived Phase 22-02, confirmed present in current codebase)
├── DragDropSupport.swift         # UNCHANGED — fileURLs(from:)/shouldAcceptDrop(isExpanded:urls:) reused
│                                  #   as-is against NSPasteboard(name: .drag)
└── DropInterceptTap.swift        # NEW (post-Task-3) — small standalone CGEventTap owning type; see below
```

**Recommendation on the "DragApproachDetector" name (ROADMAP wording):** keep this as inline stored properties + private methods on `NotchWindowController`, exactly mirroring how `mouseMonitor`/`dragReleaseMonitor` are today — NOT a new extracted Swift type. The ROADMAP's naming refers to the *detection pattern*, not a mandated new class; this file has zero extracted monitor types today (Pitfall/anti-pattern: don't introduce the first one for a single call site — see Don't Hand-Roll below). **This recommendation is unchanged for the detection layer.** The new `DropInterceptTap` type is a SEPARATE post-Task-3 concern with its own justification (see below) — it does not contradict this "no new types" conclusion, which was explicitly scoped to the original detection+shelf-landing work only (confirmed in `24-PATTERNS.md`'s own "Post-Task-3 addition" note).

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
| Detecting an external drag-and-drop session without being the destination | A custom `CGEventTap` / Accessibility-API-based drag observer | `NSEvent.addGlobalMonitorForEvents` (already proven twice in this codebase) + `NSPasteboard(name: .drag)` | `CGEventTap` requires the separate, heavier Input Monitoring/Accessibility privilege and no permission-prompt precedent exists in this app; `NSEvent` global monitors are the established, lighter-weight mechanism this codebase already ships with. **(Note: the Task-3 finding shows a `CGEventTap` IS still needed, but only for the narrow drop-interception fix, not for detection — detection stays on the `NSEvent` mechanism above.)** |
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

**Critical caveat, unchanged from Phase 22:** the core SHELF-01/SHELF-02 behavior (does a drag actually get detected and land) is fundamentally **not unit-testable** — it requires a real Window Server drag session, which no XCTest harness exercises. Automated tests can only cover the PURE seams (URL extraction — already covered by `DragDropSupportTests.swift`; the edge-detection logic for one-shot auto-expand if extracted as a pure function; `isWithinDragAcceptRegion`'s geometry math if extracted as a pure function). The actual "does the drag get detected, does the drop land" question is exclusively a manual/on-device verification item, mirrored by the spike above. **The post-Task-3 `CGEventTap` interception is likewise fundamentally not unit-testable** — swallowing a raw HID event's effect on the WindowServer's own drag-session bookkeeping can only be observed by a real on-device drag against real Finder, exactly as flagged in `## CGEventTap Drop-Interception Research` below.

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SHELF-01 | Dropped file/folder URLs become `ShelfItem`s in drop order, collapsed-only | unit (pure extraction/append logic) | `xcodebuild test -only-testing:IsletTests/DragDropSupportTests` (via Cmd-U) | ✅ `DragDropSupportTests.swift` exists and already covers `fileURLs(from:)`/`shouldAcceptDrop` |
| SHELF-01 | The drag is actually detected by the global monitors and the drop lands | manual-only | N/A — no automated harness can simulate a real OS drag session | ❌ Wave 0 gap — this is the spike itself, and the phase's own manual/human-UAT step |
| SHELF-01 | The dragged file is NOT relocated by Finder's own default same-volume move (post-Task-3 fix) | manual-only | N/A — requires a real Finder Desktop drop target and a real drag session | ❌ New Wave 0 gap — the `DropInterceptTap` on-device validation round(s) per D-13 |
| SHELF-02 | Hot/targeted feedback shows before release | manual-only (visual) + unit (edge-detection logic pure function, if extracted) | Manual Cmd-R visual check; a new unit test for `isWithinDragAcceptRegion`'s pure geometry math is recommended | ❌ Wave 0 gap — new pure-function test needed once the geometry helper exists |

### Sampling Rate
- **Per task commit:** `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` (build-only gate, matches every prior phase's convention)
- **Per wave merge:** Same build gate + manual Cmd-U for any new/changed pure-seam unit tests + a manual on-device drag verification pass
- **Phase gate:** Full manual on-device UAT (drag single file, multiple files, a folder, an Escape-cancel, AND — post-Task-3 — confirm the original file stays in its source location after a drop) before `/gsd:verify-work` — this phase cannot be verification-complete without human hands-on testing

### Wave 0 Gaps
- [ ] A pure-function unit test for `isWithinDragAcceptRegion(_:)`'s geometry math (expandedZone + landing-margin), testable without any real drag session — new for this phase, since `dragLandingMaxY` does not currently exist in the codebase
- [ ] The spike itself (no automated harness possible — manual on-device only)
- [ ] The post-Task-3 `DropInterceptTap` on-device validation round(s) — no automated harness possible (see `## CGEventTap Drop-Interception Research` below)

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
| A system-wide `CGEventTap` swallowing MORE than the single intended terminating event, breaking ordinary clicks/drags elsewhere on the OS (post-Task-3) | Denial of Service (self and system-wide UX, not a security compromise, but a severe usability regression) | See `## CGEventTap Drop-Interception Research` §2/Pitfalls below — the tap's callback must return `Unmanaged.passUnretained(event)` (pass through unmodified) for every event except the single specific `.leftMouseUp` landing inside the armed accept region; a health-check + graceful-disable path is required so a malfunctioning tap can never globally freeze mouse input |

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

---

## CGEventTap Drop-Interception Research (Post-Task-3 Addition)

**Researched:** 2026-07-11 (same session, added after Plan 24-02 Task 3's on-device UAT surfaced the drop-interception architecture gap — see `24-CONTEXT.md` D-10 through D-15 and `STATE.md` Blockers/Concerns)
**Domain:** Using a `CGEventTap` (a Core Graphics session-level raw-event tap, sitting BELOW the AppKit/`NSEvent` layer used by the rest of this phase) to swallow the terminating `.leftMouseUp` of an inbound Finder drag, so Finder's own Desktop window never sees the drop complete and never performs its default same-volume move.
**Confidence:** LOW-MEDIUM overall. The API mechanics (tap creation, run loop wiring, permission checks) are HIGH confidence — standard, well-documented Core Graphics APIs. **The one load-bearing question — does consuming the event actually stop the WindowServer's own internal drag-completion bookkeeping — could NOT be confirmed from official documentation or real-world precedent in this research session.** This is exactly the uncertainty CONTEXT.md flags, and it is NOT resolved here; it requires the D-13-capped on-device spike.

### 1. Does swallowing a raw event via CGEventTap actually prevent drag-session completion? (THE load-bearing question)

**Short answer: genuinely unverified, but there is a plausible (not proven) technical argument FOR it working, undercut by the fact that no real-world app appears to use this specific technique for this specific purpose — the established apps in this exact product category (Yoink, Dropzone) solve the problem a structurally DIFFERENT way that sidesteps the question entirely.**

**The architectural case FOR it working `[ASSUMED — reasoned from tap-location semantics, not confirmed by an authoritative source]`:**
A `CGEventTap` inserted with `.defaultTap` and placed with `.headInsertEventTap` sits at the very front of the WindowServer's own event-dispatch pipeline for that tap location — this is the literal purpose of the API: to let a client inspect and optionally cancel (`return nil`) an event BEFORE any downstream consumer (other apps, other taps, and in principle the WindowServer's own internal subsystems that are fed from the same event queue) receives it. If the WindowServer's drag-and-drop tracking state machine consumes its "has the button been released" signal from the same central event stream that feeds the tap, swallowing that event at the earliest available tap location should, in principle, prevent the drag machine from ever recording the release — precisely the mechanism this technique relies on for keyboard remapping tools like Karabiner-Elements (session-level, non-kext mode) and BetterTouchTool, both of which are widely used to intercept and altogether cancel raw input system-wide.

**Circumstantial evidence the tap DOES sit upstream of drag-tracking, not just app dispatch:** a BetterTouchTool community report (`community.folivora.ai`) describes a CGEventTap installed by that app causing an observable ~150-200ms delay at the START of every drag gesture system-wide, attributed to the tap's own event-filtering overhead `[MEDIUM: community forum report, not an Apple source, but a concrete field observation of a shipping app's tap interacting with the live drag-tracking pipeline]`. A delay is not the same as full prevention, but it demonstrates the tap sits in a position where it measurably affects the timing/delivery of the SAME drag-tracking machinery this phase needs to defeat — i.e., the tap is not merely a bystander copy-observer parallel to drag-tracking, it is upstream of it in the same pipeline. This is the strongest piece of evidence found this session, and it is still indirect.

**The case AGAINST assuming it works, or at least for treating it as unproven:**
1. **No real app in this exact category (Yoink, Dropzone, CleanShot X) appears to use this technique for this purpose.** WebSearch on all three found no technical description of a CGEventTap-based drop-interception mechanism. Yoink's actual documented mechanism is structurally different and much simpler: it fades in a REAL overlay window the instant any drag starts (detected via drag-session observation, likely similar `NSPasteboard(name:.drag)`-polling to this phase's own detection layer) and that overlay is a genuine `NSDraggingDestination` — so when the user drops onto Yoink's shelf, Yoink simply wins the OS's normal drop-target hit-test, the same way any two overlapping windows compete for a drop. **Yoink never needs to intercept or cancel an already-in-flight drop onto a DIFFERENT window (e.g., Finder's Desktop) — it avoids the problem by visually and functionally becoming the target instead.** This is a meaningfully different (and more conventional) architecture than D-10's approach, and its total absence from the research trail for "how do drag utilities solve this" is itself a signal: the CGEventTap-swallow technique for this specific purpose may be a novel approach without established precedent, not a known-working technique this research simply couldn't find better sources for.
2. **The Window Server's drag session may not be driven by the same raw-event queue a session-level tap observes.** Apple's own drag-and-drop implementation is old (predates CGEventTap, which arrived with Mac OS X 10.4/10.5-era APIs) and its internal plumbing is undocumented/private. It is plausible — and cannot be ruled out from this session's available sources — that the WindowServer's drag tracker is fed via a separate, lower-level mechanism (e.g. directly from the HID event stream or an internal Mach message dedicated to drag state, bypassing the `CGSession`-level tap-visible queue used for ordinary click dispatch) that a `.cgSessionEventTap`-located tap (the only location available to a non-root app — see §2) never sees at all. If so, consuming the copy delivered to the tap would have ZERO effect on the drag session's completion — the WindowServer would still internally believe the mouse button was released and would proceed to call `performDragOperation` on whatever real window is under the pointer, exactly as today.

**Verdict:** This is not a settled question. The technique is architecturally plausible and has one piece of indirect supporting field evidence (BTT's drag-start delay), but it has no confirmed working precedent for this exact use case, and the established real-world apps in this product category solve the underlying problem a different way that never required answering this question. **Treat this as the single highest-risk unknown in the entire drop-interception fix — exactly as CONTEXT.md's own framing states — and do not write the shelf-landing/move-back branch logic until the D-13-capped spike empirically confirms or refutes it.**

### 2. Correct tap configuration

**Tap location — `.cgSessionEventTap` is the only realistic choice for a normal (non-root) app `[VERIFIED: developer.apple.com/documentation/coregraphics/cgeventtaplocation — cross-referenced across multiple pages this session, HIGH confidence]`:**
- `.cghidEventTap` ("the point where HID system events enter the window server") is the EARLIEST possible interception point and would be the theoretically strongest choice for §1's question — but **Apple's own documentation states taps may only be placed at this location by a process running as the root user; for any other user, `CGEventTapCreate` returns `NULL`.** Islet runs as the logged-in user, never root, and there is no plan to change that (and doing so would be a drastic, unacceptable architecture change for a notarized consumer app). **This location is not available to this project — do not attempt it.**
- `.cgSessionEventTap` ("the point where HID system and remote-control events enter the current login session") is the practical earliest point available to a normal user-space app, and is what essentially every third-party remapping/monitoring tool (Hammerspoon, BetterTouchTool, Karabiner-Elements' non-kernel-extension mode) uses. **Recommended tap location for this fix.**
- `.cgAnnotatedSessionEventTap` ("the point where annotated events are delivered to your application," i.e. after accessibility annotation has already been applied, closer to per-app dispatch) is a LATER point in the pipeline than `.cgSessionEventTap` — if the WindowServer's own drag bookkeeping happens anywhere between the session tap and the annotated-session tap (plausible, unconfirmed), tapping here would be too late. **Do not use this location for the swallow; `.cgSessionEventTap` is strictly earlier and therefore strictly safer for this purpose.**

**Placement — `.headInsertEventTap`:** Places this tap at the head of the list of taps active at `.cgSessionEventTap` for this event type, so it is evaluated before any OTHER tap a different process might have installed at the same location (e.g., if the user also runs BetterTouchTool/Hammerspoon). `.tailAppendEventTap` would let other taps see (and potentially already act on) the event first, which only matters if multiple taps exist simultaneously — but `.headInsertEventTap` is the conventional, safer default with no downside for this project's single-tap use case `[CITED: developer.apple.com/documentation/coregraphics/cgeventtapplacement, HIGH]`.

**Options — `.defaultTap`, NOT `.listenOnly` (confirmed by the task brief and re-verified this session):** `.listenOnly` taps receive events for observation only; **any value the callback returns is ignored — the event always continues downstream unmodified.** Only `.defaultTap` allows the callback's return value (`nil` = swallow, or a modified/passed-through `Unmanaged<CGEvent>` = continue) to actually change what happens to the event. Since D-15 requires swallowing, `.defaultTap` is the only option that can work at all — this is settled, not in question.

**Event mask — recommend `.leftMouseUp` ONLY, not the full `leftMouseDown`→`leftMouseDragged`→`leftMouseUp` span, with an important caveat flagged for the spike:**
D-10/D-15 frame the fix as swallowing "the terminating event" specifically, and the existing `DragApproachDetector` (Plan 24-02, already shipped and on-device confirmed) already handles ALL of the approach/auto-expand/geometry detection via its own passive `NSEvent` global monitors on `.leftMouseDragged`/`.leftMouseUp` — the new tap does not need to duplicate that detection, only add the ability to CANCEL the one specific terminating event when `isDragApproaching` is true. A minimal mask (`CGEventMask(1 << CGEventType.leftMouseUp.rawValue)`) keeps the tap's footprint as small as possible, which matters for the pitfall below (interaction with Plan 24-02's own monitors). **Open question flagged for the spike, not resolved here:** if the WindowServer's drag-tracking state is latched in earlier during `.leftMouseDown`/`.leftMouseDragged` (e.g., it may decide "this is a same-volume move onto the Desktop" based on cumulative gesture state well before the final release, independent of whether the terminating mouse-up specifically is later consumed) then swallowing only `.leftMouseUp` might be provably insufficient — the spike must observe whether the file still gets relocated even with the mouse-up swallowed, which would indicate the drag's fate was already sealed earlier in the gesture and D-14's fallback is the only real option regardless of tap configuration.

### 3. Input Monitoring vs. Accessibility permission — an important correction to the task brief's framing

**This is a significant, load-bearing finding that should be surfaced to the planner and re-confirmed with the user before D-11's wording is locked into a plan.**

Multiple independent sources (Apple Developer Forums thread 122492, cross-referenced against a second forum thread and a GitHub issue discussing `CGEvent.tapCreate`) state that **the permission actually required depends on the tap's `options`, not just on using `CGEventTap` in general:**
- **`.listenOnly` taps → require Input Monitoring** (`kTCCServiceListenEvent`, checked/requested via `CGPreflightListenEventAccess()`/`CGRequestListenEventAccess()`, `NSInputMonitoringUsageDescription` shown in the system prompt).
- **`.defaultTap` taps (which this fix requires, per §2) → require Accessibility** (`kTCCServiceAccessibility`, checked via `AXIsProcessTrusted()`, requested/prompted via `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true] as CFDictionary)`). `[MEDIUM: two independent Apple Developer Forum threads state this explicitly and consistently; could not cross-verify against a current (2026) official Apple doc page in this session — flagged as an open item for the spike to confirm empirically on the actual Tahoe build machine, since TCC behavior has shifted across macOS versions before]`
- One of the same sources adds a practical simplification: **if the app already holds Accessibility trust, Input Monitoring is implicitly satisfied too** — Accessibility is described as the broader-scoped permission of the two for this purpose.

**Practical implication for D-11/D-12:** since D-15 requires `.defaultTap` (swallowing is impossible with `.listenOnly`), the permission this feature actually needs is most likely **Accessibility**, not Input Monitoring as D-11's current wording assumes. This means:
- The correct preflight check is `AXIsProcessTrusted()`, not `CGPreflightListenEventAccess()`/`IOHIDCheckAccess()`.
- The correct request call is `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true] as CFDictionary)`, not `CGRequestListenEventAccess()`.
- Accessibility's system prompt does **not** display a custom one-line `Info.plist` usage-description string the way Input Monitoring's does — the user is directed to System Settings → Privacy & Security → Accessibility to manually enable the checkbox, with no equivalent to `NSInputMonitoringUsageDescription`'s inline reason text. If an inline explanation is wanted (matching the Droppy reference pattern D-11 cites), it has to be Islet's OWN pre-explanation UI shown before calling the trust-check API, not a system-provided string.
- `NSInputMonitoringUsageDescription` may still be worth adding defensively (it is inert if unused, and some sources suggest Accessibility-trusted apps get Input Monitoring "for free" — meaning both TCC entries could plausibly show up in System Settings), but **`NSAccessibilityUsageDescription` is not a real Info.plist key for this API** (Accessibility's prompt is not gated by a custom description string the way camera/bluetooth/input-monitoring are) — do not invent one.

**Recommendation:** the planner should treat "which permission, exactly" as a task-level checkpoint to verify empirically during the spike (`AXIsProcessTrusted()` before tap creation; log whether the system shows an Accessibility prompt, an Input Monitoring prompt, both, or neither) rather than assume D-11's "Input Monitoring" wording is correct as written. This does not change D-11's underlying INTENT (ask lazily, at first real use) — only the specific API surface and prompt text involved.

**What happens if `CGEventTapCreate`/`CGEvent.tapCreate` returns `nil` (permission denied or otherwise refused):** confirmed straightforward and matches D-12's already-locked graceful-fallback framing — `tapCreate` simply returns `nil` (Optional), no exception/crash. The correct pattern is a `guard let tap = CGEvent.tapCreate(...) else { return }` at setup time: if `nil`, skip installing the run-loop source entirely and leave the feature disabled for that session — exactly the "tap creation fails, skip the tap, everything else still works" behavior D-12 describes. This part IS confirmed technically simple; the only real uncertainty is which permission API/prompt gates it (above) and the code-signing caveat below.

**Code-signing caveat specific to this project (worth flagging given this project's own prior Hardened-Runtime signing incident):** a 2026 field report (`danielraffel.me`) documents that CGEventTaps can become "functionally inert" (the tap object is created successfully, `tapCreate` does NOT return `nil`, but the callback silently never fires) after an app is re-signed and re-launched via Launch Services/Finder, theorized to be caused by TCC re-evaluating permission grants against a changed code identity. The article's own mitigation: **periodically call `CGEvent.tapIsEnabled(tap:)` (e.g. every few seconds) and reinstall the tap if it has silently gone inert** — "a non-nil tap is not a healthy tap." Given this project's own prior real incident with Hardened Runtime + re-signing breaking a different mechanism (embedded `MediaRemoteAdapter.framework`, project memory `release-library-validation-crash`, gated specifically behind `-configuration Release` builds), **this health-check pattern should be treated as a real, non-optional part of the implementation for this project specifically, not generic defensive paranoia** — test explicitly in a Release-configuration build, not just Debug, mirroring how the MediaRemoteAdapter issue only manifested in Release.

### 4. Run loop integration

Standard, well-documented, HIGH confidence — no project-specific uncertainty here:

```swift
// Source: cross-verified across multiple independent code examples (Medium/Gaitatzis article,
// several GitHub reference implementations) — consistent, HIGH confidence for the mechanics.
guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(1 << CGEventType.leftMouseUp.rawValue),
    callback: { proxy, type, event, userInfo in
        // `userInfo` carries an Unmanaged<DropInterceptTap> passed at tapCreate time
        // (this callback is a C function pointer, NOT a Swift closure capturing `self` —
        // context must be threaded through `userInfo`, a real difference from this codebase's
        // existing NSEvent-monitor closures, which DO capture [weak self] directly).
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let intercept = Unmanaged<DropInterceptTap>.fromOpaque(userInfo).takeUnretainedValue()
        return intercept.handle(type: type, event: event)
    },
    userInfo: Unmanaged.passUnretained(self).toOpaque()
) else {
    // D-12's graceful fallback — no tap, feature silently disabled for this session
    return
}
let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
```

**Main run loop, not a dedicated thread — same conclusion as the existing `NSEvent` monitors, and for the same underlying reason:** the callback needs to read/write `isDragApproaching`, `expandedZone`, `dragLandingMaxY` — the SAME `@MainActor`-adjacent AppKit state the existing `handleDragApproachTick`/`handleDragApproachEnd` already touch on the main run loop (per this codebase's existing Swift-5-language-mode, not-yet-strict-concurrency setup per `CLAUDE.md`). `CFRunLoopAddSource(CFRunLoopGetMain(), ..., .commonModes)` is the correct, conventional choice — using `.commonModes` (not just `.defaultMode`) matters so the tap keeps firing even while the run loop is in a modal/tracking mode for some OTHER reason (e.g., a menu is open), mirroring why AppKit's own event-tracking-mode considerations matter elsewhere in this research (Pitfall 1).

**One real difference from the existing `NSEvent.addGlobalMonitorForEvents` monitors worth flagging for the planner:** the CGEventTap callback is a C function pointer (or a capture-less Swift closure convertible to one), NOT a `[weak self]`-capturing closure like every existing monitor in this file. Context must be threaded through the `userInfo: UnsafeMutableRawPointer?` parameter using `Unmanaged<T>.passUnretained(self).toOpaque()` at creation and `Unmanaged<T>.fromOpaque(userInfo).takeUnretainedValue()` inside the callback. This is a meaningfully different, more manual-memory-management-flavored idiom than anything else in this file — direct supporting evidence for §5's recommendation to isolate this in its own small type rather than bolt it onto `NotchWindowController` inline.

### 5. New owning type — recommend a small standalone `DropInterceptTap`, breaking from this phase's own "no new types" convention, deliberately

**Recommendation: YES, a new small standalone type — e.g. `Islet/Notch/DropInterceptTap.swift` — owned by (held as a property on) `NotchWindowController`, not folded into it inline.** This deliberately departs from the rest of Phase 24's "no new files/types" convention (`24-PATTERNS.md`'s own stated bias, correctly applied to the `NSEvent`-based detection layer above), for reasons specific to THIS piece only:

1. **Genuinely different code shape.** As shown in §4, the tap's callback is a C-function-pointer-style callback threading context through `Unmanaged<T>`/`UnsafeMutableRawPointer`, not a `[weak self]` closure — a meaningfully different idiom from every other monitor in `NotchWindowController.swift`. Mixing manual-memory-management-flavored glue into the same file as the rest of the controller's ARC-managed, closure-capturing code is a legitimate readability/maintainability cost, not a stylistic preference.
2. **A materially larger, more failure-prone lifecycle than a one-line `NSEvent.addGlobalMonitorForEvents` call.** Per §3, this includes: a permission preflight/request step, `nil`-on-failure handling (D-12), run-loop-source add/remove, `tapEnable`/`tapDisable`, AND (per the code-signing caveat) an ongoing periodic `tapIsEnabled()` health check with reinstall-on-failure logic. This is enough independent moving state that it earns its own encapsulation boundary, the same way this project already isolates its OTHER highest-risk/most-likely-to-break external integration (`MediaRemoteAdapter`) behind a dedicated `NowPlayingService`-style seam per `CLAUDE.md`'s own explicit architecture note ("isolate all now-playing code behind one Swift protocol/service so swapping the implementation is a one-file change").
3. **Directly matches D-13's own risk framing and D-14's fallback path.** If the on-device spike (capped at 2 rounds per D-13) shows CGEventTap does NOT work (§1's uncertainty resolves negatively) and the team falls back to D-14's move-back mitigation instead, having this entire mechanism isolated in one file makes it a clean, low-risk DELETION (remove `DropInterceptTap.swift`, remove the one property/two calls in `NotchWindowController` that reference it) rather than an unpicking exercise scattered through the controller.
4. **Zero regression to the CR-01 single-arbiter discipline.** The new type should expose the narrowest possible interface back into `NotchWindowController` — e.g. a stored closure or weak delegate reference the controller supplies at construction time (`shouldSwallow: () -> Bool` reading the SAME `isDragApproaching`/`isWithinDragAcceptRegion(...)` state Plan 24-02 already introduced, not a second parallel flag) — and must NEVER itself touch `ignoresMouseEvents`/`syncClickThrough()`. It only decides whether to return `nil` or pass the event through; all shelf-landing/acceptance logic stays exactly where Plan 24-02 already put it (`handleDragApproachEnd()`).

**Design sketch (illustrative shape, not final code — planner to detail exactly):**
```swift
// Islet/Notch/DropInterceptTap.swift — NEW file, post-Task-3 addition
final class DropInterceptTap {
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let shouldSwallow: () -> Bool   // reads NotchWindowController's existing isDragApproaching +
                                              // isWithinDragAcceptRegion(NSEvent.mouseLocation) — no new state

    init(shouldSwallow: @escaping () -> Bool) { self.shouldSwallow = shouldSwallow }

    func start() {
        guard AXIsProcessTrusted() else { return }   // D-12 — no prompt yet at construction time;
                                                       // caller decides WHEN to request (lazy, D-11)
        // ... tapCreate/CFMachPortCreateRunLoopSource/CFRunLoopAddSource per §4 ...
    }

    func stop() {
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let machPort { CGEvent.tapEnable(tap: machPort, enable: false) }
        machPort = nil
        runLoopSource = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .leftMouseUp, shouldSwallow() else { return Unmanaged.passUnretained(event) }
        return nil   // swallow — Finder's Desktop (or whatever's underneath) never sees this mouseUp
    }
}
```

**A critical integration risk this design sketch surfaces, worth its own Pitfall entry below:** since `handle(...)` returns `nil` (fully suppressing the event) whenever `shouldSwallow()` is true, and Islet's OWN existing `dragEndMonitor` (`NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp])`, Plan 24-02) is ALSO just a downstream consumer of that same event stream — it is genuinely unclear whether Islet's own passive monitor would still fire for an event Islet's own tap just suppressed. See Pitfall A below; this materially affects the planner's wiring design (whether shelf-landing must be triggered directly from inside `DropInterceptTap.handle(...)` rather than relying on the separate, pre-existing `dragEndMonitor` path).

### 6. Failure/fallback path (D-14) — move-back mitigation, brief per CONTEXT.md's explicit deferral

Per CONTEXT.md's own instruction, this is deliberately NOT designed in full here — only the general shape and known risks, so a future planner isn't starting from zero if D-13's cap is hit.

**General approach:** `handleDragApproachEnd()` already captures the accepted `urls: [URL]` (the ORIGINAL source URLs, read from `NSPasteboard(name: .drag)`) before the shelf copy is made. After the drop, schedule a short delayed check (e.g. `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3-0.5)`, tuned empirically) that calls `FileManager.default.fileExists(atPath: originalURL.path)` for each accepted URL. If the original no longer exists at its source path, assume Finder performed its default same-volume move to the Desktop (the specific, confirmed failure mode from Task 3's UAT) and attempt `FileManager.default.moveItem(at: presumedDesktopURL, to: originalURL)` where `presumedDesktopURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").appendingPathComponent(originalURL.lastPathComponent)`.

**Known edge-case risks (flagged, not resolved):**
- **Name collisions:** if a file with the same name already existed on the Desktop before the drop, Finder's own move operation would have auto-renamed the just-moved file (e.g. "photo 2.jpg"), breaking the naive `lastPathComponent`-based guess entirely — the move-back would either silently fail (source doesn't exist at the guessed path) or, worse, move back the WRONG (pre-existing) file.
- **Timing races:** the delay between "our drop-acceptance logic runs" and "Finder's own async move operation actually completes on disk" is unmeasured and may vary (multi-file drags, slow/network volumes, Time Machine or Spotlight indexing contention); too short a delay produces a false "still exists" read before Finder's move actually lands; too long a delay risks the user visibly seeing (and reacting to) the file briefly vanish from its original location before Islet moves it back.
- **Multi-file/folder drags amplify both risks independently per item** — a partial success (some files moved back correctly, others not, due to independent collisions/timing per file) is a plausible, messy outcome that would need its own defined behavior (silent partial success per D-07's precedent, most likely, but not decided here).
- **This mitigation is inherently reactive/heuristic**, not a real interception — it cannot prevent the brief moment where the file is genuinely absent from its original location, which may itself be user-visible or trigger OTHER Finder/Spotlight side effects (e.g., a `.fileprovider` sync, an open Finder window's UI briefly showing the file gone) that this research has not investigated, consistent with CONTEXT.md's explicit instruction to defer this design.

### Pitfalls (post-Task-3 addition)

#### Pitfall A: The tap swallowing an event may ALSO prevent Islet's own passive `NSEvent` monitor from seeing it
**What goes wrong:** `DropInterceptTap.handle(...)` returns `nil` for the terminating `.leftMouseUp` to stop Finder's Desktop from seeing it — but Islet's OWN `dragEndMonitor` (the pre-existing `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp])` from Plan 24-02, which triggers `handleDragApproachEnd()` and lands the file in the shelf) may ALSO be a downstream consumer of the same now-suppressed event, and may simply never fire for that specific mouse-up either.
**Why it happens:** `NSEvent`'s global-monitor API is itself understood to be implemented on top of the same session-level event-tap infrastructure `CGEventTap` exposes directly — if that is accurate, an event fully consumed (`nil`-returned) by a `.defaultTap` positioned with `.headInsertEventTap` would never reach ANY later observer in the same pipeline, including Islet's own separate monitor, regardless of which process registered it.
**How to avoid:** Do not assume the existing `dragEndMonitor`/`handleDragApproachEnd()` path will still fire for a swallowed event. The safer design is to trigger the EXISTING shelf-landing logic (`handleDragApproachEnd()`, unchanged from Plan 24-02) directly from INSIDE `DropInterceptTap.handle(...)`'s swallow branch (via the same narrow callback-injection pattern used for `shouldSwallow`), rather than relying on two independent consumers of the same event to both fire correctly. This must be explicitly verified in the spike — log from BOTH the tap callback and the existing `dragEndMonitor` closure on the same test drag, and confirm empirically whether both fire, only the tap does, or (worst case) neither does reliably.
**Warning signs:** Files "disappearing" from the drag entirely — no relocation to Desktop (the tap worked!) but ALSO nothing lands in the shelf (the existing detection monitor never got its copy of the now-consumed event).

#### Pitfall B: Over-broad event mask silently breaking ordinary system-wide clicks or drags
**What goes wrong:** If the tap's mask or `shouldSwallow()` guard is even slightly too broad (e.g., a bug that makes `shouldSwallow()` return `true` outside the intended narrow window), EVERY `.leftMouseUp` system-wide gets swallowed — meaning every click anywhere on the Mac stops registering its release, a severe, system-wide usability regression far worse than anything the existing `NSEvent`-only detection layer could ever cause (since NSEvent global monitors can only OBSERVE, never consume).
**Why it happens:** This is the first mechanism in this codebase with the theoretical power to break input SYSTEM-WIDE, not just within Islet's own window — a materially higher blast radius than anything else in this file.
**How to avoid:** `shouldSwallow()` must be as narrow as technically possible — gate on BOTH `isDragApproaching` (already edge-tracked, cleared unconditionally per Pitfall 4/5 in the main research above) AND a fresh `isWithinDragAcceptRegion(NSEvent.mouseLocation)` recheck at the moment of the callback itself (not a stale value), exactly mirroring `handleDragApproachEnd()`'s own existing double-check. Recommend the spike explicitly test "click and drag normally in other apps (Safari, TextEdit, Finder windows) while Islet is running with the tap installed" as its own pass/fail scenario, not just the notch-specific drag tests.
**Warning signs:** Any report (including from the developer's own daily use) of clicks anywhere on the system "not registering" or requiring an extra click, while Islet is running.

#### Pitfall C: A silently-disabled tap gives a false sense of security (the code-signing race, §3)
**What goes wrong:** After a Release build re-sign/re-launch cycle, the tap may install successfully (`tapCreate` returns non-`nil`) but never actually fire — silently regressing to today's known bug (file relocated to Desktop) with NO error surfaced anywhere, and no indication anything is wrong short of noticing the relocation bug is back.
**Why it happens:** Documented field behavior (§3) — TCC's identity-based re-evaluation after re-signing can leave a tap "functionally inert" without `tapCreate`/`tapIsEnabled` reporting a problem at creation time.
**How to avoid:** Implement the periodic `CGEvent.tapIsEnabled(tap:)` health check with reinstall-on-failure from the start (not as a later hardening pass) — treat it as core to this feature's correctness for THIS project specifically, given the project's own prior real Release-only signing incident (project memory `release-library-validation-crash`). Explicitly test in a `-configuration Release` build, not just Debug, mirroring how that prior incident only manifested in Release.
**Warning signs:** The relocation bug reappearing intermittently, especially after a fresh Release build/re-launch, with no other code change to explain it.

### Assumptions Log (post-Task-3 addition)

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A5 | Consuming (`nil`-returning) the terminating `.leftMouseUp` at `.cgSessionEventTap`/`.defaultTap`/`.headInsertEventTap` prevents the WindowServer's own internal drag-session completion logic from running, stopping Finder's Desktop from performing its default same-volume move | §1 (THE load-bearing question) | HIGH — if wrong, D-10's entire chosen mechanism cannot work regardless of how correctly everything else (permissions, run loop, mask) is implemented; this is exactly why D-13 caps validation at 2 on-device rounds before falling back to D-14, and why this research explicitly does NOT claim this works |
| A6 | `.defaultTap` requires Accessibility permission (`AXIsProcessTrusted`), not Input Monitoring (`CGPreflightListenEventAccess`), contradicting D-11's "Input Monitoring" framing | §3 | MEDIUM — if wrong (i.e., if current macOS actually gates `.defaultTap` mouse-event taps via Input Monitoring same as `.listenOnly`), the permission-check code the planner writes based on this finding would check/request the wrong TCC service, causing the tap to silently never activate even with correct code otherwise — must be empirically confirmed in the spike, not assumed from this research alone |
| A7 | Islet's own pre-existing `dragEndMonitor` (`NSEvent` global monitor) will still fire for a `.leftMouseUp` that `DropInterceptTap`'s own tap has consumed (`nil`-returned) in the same process | Pitfall A | HIGH — if Islet's own detection monitor stops firing for a self-consumed event, the shelf-landing logic (already shipped, Plan 24-02) would silently stop working for exactly the case this fix is meant to enable, trading one bug (file relocated) for another (nothing lands in the shelf at all) — must be verified directly in the spike by logging from both consumers on the same test drag |
| A8 | No existing macOS utility in the drag/shelf category (Yoink, Dropzone, CleanShot X, or the Droppy reference app) uses a CGEventTap-based swallow-the-terminating-event technique for this exact purpose — they solve the underlying problem by becoming a real `NSDraggingDestination` overlay instead | §1 | LOW — does not block implementation (this research doesn't need precedent to proceed with the spike per D-10's explicit choice), but if this assumption is wrong and such a precedent exists and could be found, it would meaningfully upgrade §1's confidence from unverified to precedented; worth a follow-up search if the spike's first round is ambiguous |

