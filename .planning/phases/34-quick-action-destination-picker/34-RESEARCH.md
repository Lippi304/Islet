# Phase 34: Quick Action Destination Picker - Research

**Researched:** 2026-07-15 (original spike) — **revised 2026-07-15 (revision 2, post-UAT)**
**Domain:** AppKit sharing services (`NSSharingService`) from a non-key `NSPanel`; live per-target hit-testing during a raw `NSEvent`-monitor-based drag polling loop (no `NSDraggingDestination`); SwiftUI presentation-state integration in Islet's existing `IslandResolver`/`NotchWindowController` architecture
**Confidence:** HIGH (both the original AirDrop/Mail spike question AND the new drag-target hit-testing question are answered from this project's own current source, read directly — not inferred)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Picker takeover & trigger**
- **D-01:** The picker is a full-takeover presentation — its own `IslandResolver`/`IslandPresentation` case, replacing whatever tab was showing (Home/Weather/Calendar/Tray), the same shape as the existing Charging/Device wings splash but interactive instead of auto-dismissing. Not an overlay/sheet layered on top of the current tab. *(Still true — unchanged by the UAT revision.)*
- **D-02 (SUPERSEDED by D-14):** ~~The picker shows a small preview of what's being dropped~~ — removed per on-device UAT feedback. See D-14.
- **D-03:** A multi-file drop (several files dragged in at once) gets ONE picker and ONE destination decision for the whole batch — not one picker per file.

**UAT Revision — real drag targets (2026-07-15)**
- **D-10 (supersedes D-01's trigger timing):** The picker must appear at the exact same edge that already auto-expands the island today — `recheckDragAcceptRegion()`'s `.dragEntered` transition (geometry-inside, collapsed-origin) — not only after `.leftMouseUp`/release. `pendingDrop` must be populated (from the already-available `NSPasteboard(name: .drag)` contents) at the SAME moment the auto-expand fires, so `IslandResolver.resolve()` has something to show instead of falling through to Now Playing/whatever else is active. No added hover delay before showing it.
- **D-11 (new):** The button currently under the pointer during the drag highlights (brighter fill and/or slight scale) before release — real drop-target visual feedback. Requires live per-button hit-testing during the raw `NSEvent`-monitor-based drag polling loop (there is no `draggingUpdated` equivalent today). Research must find how to get each button's live frame in global screen coordinates back to `NotchWindowController` (e.g. a `GeometryReader`/`PreferenceKey` pipeline, mirroring how `visibleContentZone()` already exposes computed geometry back to the controller for click-through, but for 3 live sub-rects instead of one static zone).
- **D-12 (supersedes D-01's click-based framing):** Releasing the mouse while over a specific button (Drop/AirDrop/Mail) selects that destination — drag-and-release-on-target, not drag-then-click-after. The existing `handleQuickActionDrop/AirDrop/Mail` handlers (already built, unchanged) are just invoked from the new per-button release detection instead of from `Button(action:)` taps.
- **D-13:** Releasing anywhere in the picker NOT over one of the 3 buttons discards the pending file(s) — same rule as D-07, no safety net, no default destination.
- **D-13b:** Dragging the pointer back out of the island's geometry entirely before releasing collapses the picker with no destination chosen — this is the existing `!geometryInside && isDragApproaching` exit condition in `recheckDragAcceptRegion()` and "needs no change, just confirmation it still applies once D-10 moves `pendingDrop` earlier."
  - **RESEARCH FINDING: this assumption is FALSE as stated — see Pitfall 6.** The exit condition as it exists today only clears `isDragApproaching`; it does not clear `pendingDrop`. Once D-10 moves `pendingDrop`-population to the `dragEntered` edge, this exit branch MUST also call `discardPendingDrop()` (+ `renderPresentation()`) or the picker never actually goes away and a session-copy leaks on disk. Flagging this back to the user/planner as a correction, not silently patching it in without saying so.
- **D-14 (supersedes D-02):** The file preview (icon + filename, or file-count + generic icon) is removed entirely. The picker shows ONLY the 3 destination buttons — for both single-file and multi-file drops alike.
- **D-15:** With the preview gone, the card shrinks vertically. `quickActionPickerContentHeight` gets a new, smaller value (camera clearance + button row only — see Pattern 3 for the worked recompute). The CR-01 geometry three-site rule applies again in full.

**Visual polish (flagged directly during UAT, implementation detail)**
- "Drop" button renders at a slightly different height than "AirDrop"/"Mail" (SF Symbol intrinsic-size mismatch at the same `.font(.system(size: 22))`) — needs a fixed icon frame so all 3 buttons render at identical height.
- AirDrop's icon (`personalhotspot`) may need a closer visual match to the system AirDrop glyph — Claude's discretion.

**Precedence & pending-drop lifecycle**
- **D-04:** A Charging/Device transient interrupts the picker exactly like it interrupts every other expanded presentation today (existing D-04 rule in `IslandResolver.swift`).
- **D-05:** The pending drop survives the interruption — held in controller-owned state, picker auto-resumes with the same file(s) once the transient's `TransientQueue` drains.

**No-choice / cancel behavior**
- **D-06:** The user can dismiss the picker without choosing a destination via the existing hover-away grace-collapse mechanism.
- **D-07:** If dismissed without a choice, the dropped file(s) are simply discarded — no silent auto-default to "Drop."

**AirDrop/Mail — non-key-panel risk & fallback**
- **D-08:** `NotchPanel` is permanently non-activating/non-key (ISL-03). If the spike finds AirDrop/Mail's share sheet only appears from a momentarily key/focused window, a narrowly-scoped exception is acceptable: key for the instant of invoking that one action, then revert immediately. NOT a general focus-behavior change.
- **D-09:** If the spike finds no working approach at all, the phase still ships: Drop (TRAY-03) ships on schedule (no such risk), AirDrop/Mail (TRAY-04) appear as visibly disabled buttons rather than blocking the whole phase.

### Claude's Discretion
- Exact visual treatment of the disabled-button state for AirDrop/Mail if D-09's fallback is needed.
- Exact SF Symbols for the Drop/AirDrop/Mail buttons — no specific icons locked; match the spirit of Droppy's icon+label buttons.
- Where the pending-drop state lives in code (already resolved by the original spike: controller-owned, see Pitfall 5) — implementation shape, not a product decision.
- Naming of the new `IslandPresentation`/resolver case for the picker (already resolved: `.quickActionPicker(PendingDrop)`).
- Whether the picker reuses `ShelfCoordinator.append`'s session-copy mechanism directly for "Drop" — already resolved: yes, reused verbatim.

### Deferred Ideas (OUT OF SCOPE)
None new — discussion stayed within phase scope. Already-known deferral (not re-litigated): "Open Tray After Drop" convenience setting for the picker's "Drop" outcome — Droppy-precedented, explicitly not in this milestone's ask.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-------------------|
| TRAY-02 | Dropping a file (from any tab) shows a Droppy-style Quick Action destination picker: Drop / AirDrop / Mail | Pattern 4 (D-10 pasteboard-read-at-dragEntered timing) + existing `.quickActionPicker` resolver case (unchanged, already tested) — the picker now shows DURING the drag, not after release |
| TRAY-03 | Choosing "Drop" stages the file into the Tray and switches the view to Tray | Pattern 5 (D-12 release-on-target routing calls the existing, unchanged `handleQuickActionDrop()`) |
| TRAY-04 | Choosing "AirDrop"/"Mail" invokes `NSSharingService`; Mail.app-only attachment support documented | Original Pattern 1/2 (non-key-panel spike, still HIGH confidence, unchanged) + Pattern 5 (release-on-target routing calls the existing, unchanged `handleQuickActionAirDrop()`/`handleQuickActionMail()`) |
</phase_requirements>

## Summary

**This is a revision-2 research pass.** The original research (below, preserved) answered the phase's one originally-flagged unknown — whether `NSSharingService` AirDrop/Mail invocation works from Islet's permanently non-key `NotchPanel` — with HIGH confidence, verified against a shipping app's real source. That finding is **unchanged and still valid**; nothing in the UAT revision touches AirDrop/Mail's actual invocation mechanism, only the trigger timing and hit-testing that decides WHEN each handler fires.

On-device UAT (34-02-SUMMARY.md) rejected the click-based interaction Plan 34-02 built and asked for real drag targets instead: the 3-button picker must appear DURING the drag (at the same `.dragEntered` edge that already auto-expands the island today), the button under the pointer must highlight live, and releasing over a button selects that destination directly — no intermediate click. This introduces one genuinely new technical question this project has not solved before: **how does a raw `NSEvent`-monitor-based drag polling loop (this project's `DragApproachDetector` architecture — there is no `NSDraggingDestination`/`draggingUpdated`) get each of 3 SwiftUI buttons' live frame in global screen coordinates, cheaply, every tick?**

The answer, verified by reading this project's own `NotchGeometry.swift`/`NotchWindowController.swift` directly: **no GeometryReader/PreferenceKey pipeline is needed at all.** The picker's card frame is already computed 100% analytically in the controller (`positionAndShow`'s `quickActionPickerFrame`, via the same `expandedNotchFrame` pure function every other presentation's frame reservation uses) — it does not wait for SwiftUI to render and report back. The 3 buttons inside that card are a fixed-width `HStack(spacing: 16)` of 3 equal-flex chips (`.frame(maxWidth: .infinity)` each) inside known, constant padding — so their rects are equally computable by pure arithmetic from the SAME already-known card frame, with zero dependency on SwiftUI's actual render pass. This is a strictly simpler, lower-risk answer than introducing this codebase's first-ever `PreferenceKey` publishing pattern (which also carries a real SwiftUI/AppKit coordinate-space conversion gotcha — see Pitfall 7) for a value that a `GeometryReader` round-trip would tell you no more accurately than direct computation already does, because the layout is fully static per drop of the card's own dimensions.

**Primary recommendation:** Compute `quickActionButtonFrames: [CGRect]` (3 global-coordinate rects) analytically inside `positionAndShow()`, right alongside the existing `quickActionPickerFrame`, `expandedZone`, and `dragLandingMaxY` computations (Pattern 3). Move `pendingDrop` population from `handleDragApproachEnd()` (release) to the `dragEntered` arm edge inside `recheckDragAcceptRegion()` (Pattern 4, D-10) — and add the one companion fix D-13b's text implies but doesn't state: the SAME function's exit branch must now call `discardPendingDrop()` too (Pitfall 6), or the picker never actually goes away once entered. Drive D-11's live highlight from a single published `Int?` index, updated only on change (Pitfall 8, cheap). Route D-12's release-on-target selection from inside the existing `handleDragApproachEnd()` — already this project's one intercept point for a real drop release, via `DropInterceptTap` — by hit-testing `NSEvent.mouseLocation` against the 3 stored rects (Pattern 5).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Picker presentation (3 buttons, no preview per D-14) | Frontend (SwiftUI, `NotchPillView`) | — | Pure view, follows existing per-presentation view pattern (`trayFullView`, `weatherFullContent`) |
| Picker precedence / lifecycle state | App logic (`IslandResolver`, pure) | Controller (`NotchWindowController`) | `IslandResolver.resolve()` is the single pure arbiter (D-04/D-05); the controller owns the actual pending-drop mutable state and timers — unchanged by this revision |
| Live per-button hit-testing (D-11/D-12) | Controller (`NotchWindowController`) | — | **NEW for this revision.** Pure analytical geometry (`quickActionButtonFrames`), computed once per `positionAndShow()`, hit-tested against `NSEvent.mouseLocation` on every existing `.leftMouseDragged`/`.leftMouseUp` tick — no SwiftUI round-trip, no new view-to-controller channel |
| Drag-hover highlight rendering (D-11) | Frontend (SwiftUI) | Controller (publishes the index) | Controller determines WHICH button is hovered (pure geometry); the view only reads a published `Int?` and applies the highlight style — same "controller computes, view renders" split as every other presentation |
| "Drop" destination file copy-in | Data/IO (`ShelfCoordinator`/`ShelfFileStore`) | — | Reused verbatim, only the CALL-SITE timing moves earlier (D-10) |
| AirDrop/Mail invocation | OS integration (`NSSharingService`, AppKit) | — | Unchanged by this revision — see original Pattern 1/2 below |
| Sharing completion / pending-state cleanup | Controller (`NotchWindowController`) via delegate callback | — | Unchanged by this revision |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AppKit `NSSharingService` | Ships with macOS SDK (10.8+, stable API) | AirDrop + Mail-compose-with-attachment invocation | Unchanged — see original Pattern 1/2 |
| SwiftUI (existing) | Ships with macOS SDK | Picker view (3 buttons, no preview per D-14) | Matches every other presentation in `NotchPillView.swift` |
| AppKit `NSEvent` global monitors (`.leftMouseDragged`, `.leftMouseUp`) + `CGEvent.tapCreate` (`DropInterceptTap`) | Ships with macOS SDK | This project's existing drag-detection primitives — the mechanism D-11/D-12's hit-testing rides on | Already fully built (Phase 24); this revision adds NO new monitor, just more logic inside the existing tick/end handlers |

No new third-party packages are needed for this phase or this revision — 100% Apple-framework surface, plus this project's own existing pure-geometry helpers (`expandedNotchFrame`, `isWithinDragAcceptRegion`).

### Supporting
None beyond what's already in the project.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Direct `NSSharingService(named:).perform(withItems:)` | `NSSharingServicePicker` | Already ruled out (REQUIREMENTS.md Out of Scope) — unchanged |
| **Analytical per-button frame computation in the controller** | **`GeometryReader` + `PreferenceKey` publishing pipeline from `NotchPillView` up to `NotchWindowController`** | This is the CONTEXT.md-suggested "e.g." approach, investigated and NOT recommended here. It would be this codebase's first-ever `PreferenceKey` usage (grep confirms zero existing uses — the two existing `GeometryReader`s in `NotchPillView.swift`, lines 943/2122, only read `geo.size` LOCALLY for a progress bar / temperature bar, never publish geometry upward). It also carries a real coordinate-space conversion cost: SwiftUI's `.global` coordinate space inside an `NSHostingView`-hosted view is relative to the HOSTING WINDOW's top-left origin (y-down), not AppKit's screen-space bottom-left origin (y-up) that `NSEvent.mouseLocation`/`expandedZone`/`hotZone` all already use throughout this file — every existing geometry helper in `NotchGeometry.swift` carries an explicit comment about this exact BOTTOM-LEFT-origin/y-up convention (Pitfall 1 in `notchFrame`'s own doc comment: "AppKit windows use a BOTTOM-LEFT origin with y increasing upward... (Pitfall 1)"). A `PreferenceKey` pipeline would need a NEW screen-space conversion step (`panel.convertToScreen` + a y-flip) on every publish, is subject to SwiftUI's own layout-then-preference-propagation timing lag (button frames would be "as of the last render," not truly synchronous with the polling tick), and buys no more accuracy than direct computation because the layout (equal-flex `HStack`) is fully deterministic from constants already known to the controller. See Pitfall 7. |
| Delegate + timeout-fallback pending-state cleanup | Blocking/synchronous wait for share completion | Unchanged — see original |

**Version verification:** No packages to verify (Swift-native API + this project's own existing pure functions).

## Package Legitimacy Audit

Not applicable — this phase installs no external packages. All code (original + this revision) uses AppKit/SwiftUI already linked into the project, plus this project's own existing `NotchGeometry.swift`/`DragDropSupport.swift` pure functions.

## Architecture Patterns

### System Architecture Diagram (revision 2 — drag-target flow)

```
File drag enters the island's accept region (dragEntered edge)
        │
        ▼
recheckDragAcceptRegion()                       [existing, ~line 920]
        │  existing: arms isDragApproaching, auto-expands via .dragEntered transition
        │  NEW (D-10, Pattern 4): reads NSPasteboard(name: .drag) HERE (not at release),
        │       session-copies file(s) (ShelfFileStore.makeSessionCopy, UNCHANGED mechanism,
        │       just called one edge earlier), sets pendingDrop — this is what makes
        │       IslandResolver.resolve() return .quickActionPicker on THIS render, not after release
        ▼
IslandResolver.resolve(...)                     [pure arbiter, UNCHANGED logic]
        │  if let pendingDrop { return .quickActionPicker(pendingDrop) }  — inside isExpanded branch
        ▼
NotchPillView.quickActionPickerView             [SwiftUI render, D-14: buttons only, no preview]
        │  reads a published hoveredQuickActionButtonIndex: Int? to highlight (D-11)
        ▼
   ┌─────────────────── while still dragging (button held) ───────────────────┐
   │  every .leftMouseDragged tick → handleDragApproachTick()                  │
   │    → recheckDragAcceptRegion() (existing auto-expand/exit tracking)       │
   │    → NEW: hit-test NSEvent.mouseLocation against quickActionButtonFrames  │
   │       (Pattern 3, pure arithmetic) → publish hoveredQuickActionButtonIndex│
   │       ONLY on change (Pitfall 8)                                         │
   └────────────────────────────────────────────────────────────────────────┘
        │  pointer exits the accept geometry before release (D-13b)
        ▼
   isDragApproaching = false AND (NEW, Pitfall 6) discardPendingDrop() +
   renderPresentation() — picker actually disappears, session-copy cleaned up
        │
        │  OR: .leftMouseUp fires (real release)
        ▼
DropInterceptTap.handle() → onIntercept() → handleDragApproachEnd()  [existing intercept point]
        │  NEW (D-12, Pattern 5): if pendingDrop != nil, hit-test release point against
        │  quickActionButtonFrames:
        │    - index 0 (Drop)    → handleQuickActionDrop()     [UNCHANGED handler]
        │    - index 1 (AirDrop) → handleQuickActionAirDrop()  [UNCHANGED handler]
        │    - index 2 (Mail)    → handleQuickActionMail()     [UNCHANGED handler]
        │    - no match (D-13)   → discardPendingDrop()
        ▼
   (same downstream flow as the original spike's diagram, unchanged — see below)
```

### Original System Architecture Diagram (AirDrop/Mail invocation — unchanged, preserved)

```
File dropped on notch (any tab)
        │
        ▼
NotchWindowController.handleDragApproachEnd()   [existing, ~line 951]
        │  today: unconditionally copies file(s) in + shelfCoordinator.append()
        │  NEW: copies file(s) in (unchanged — reuse verbatim), stores as
        │       "pending drop" state, sets selectedView/isExpanded to show picker
        ▼
IslandResolver.resolve(...)                     [pure arbiter]
        │  NEW presentation case: .quickActionPicker(pendingDrop)
        │  D-04 unchanged: charging/device transient still wins unconditionally
        ▼
NotchPillView                                   [SwiftUI render]
        │  NEW case renders: (revision 2, D-14: buttons only, no file preview)
        │                     3 buttons: Drop / AirDrop / Mail
        ▼
   ┌────┴─────────────┬──────────────────────┐
   │                   │                      │
   ▼                   ▼                      ▼
"Drop" selected   "AirDrop" selected     "Mail" selected
(release-on-target, D-12, revision 2 — was tap-to-select in the original spike)
   │                   │                      │
   ▼                   ▼                      ▼
ShelfCoordinator   QuickActionSharing     QuickActionSharing
.append(item)      Service (isolated seam) Service (isolated seam)
   │               .share(urls, via: .sendViaAirDrop)
   ▼                   │                      │
switch to Tray     NSSharingService(named: .sendViaAirDrop / .composeEmail)
                       .perform(withItems: urls)
                        │
                        ▼
                   delegate callback (didShareItems / didFailToShareItems)
                   or timeout fallback (mirrors Phase 21 drag-pin's
                   20s-safety-net precedent, shorter interval)
                        │
                        ▼
                   clear pending-drop state → resolver falls back to
                   whatever presentation was active before the drop
```

### Recommended Project Structure
No new files/folders — same flat `Islet/Notch/` and `Islet/Shelf/` layout as the original spike. This revision touches ONLY:
```
Islet/
├── Notch/
│   ├── NotchWindowController.swift # recheckDragAcceptRegion() (D-10 pasteboard-read moves here,
│   │                                #   D-13b discardPendingDrop() companion fix), handleDragApproachEnd()
│   │                                #   (D-12 release-routing), positionAndShow() (NEW
│   │                                #   quickActionButtonFrames computation, D-15 height recompute),
│   │                                #   handleDragApproachTick() (NEW hover-index publish, D-11)
│   └── NotchPillView.swift         # quickActionPickerView (D-14: drop the preview subview call),
│                                    #   quickActionButtonRow/quickActionButton (D-11 highlight styling,
│                                    #   icon-height fix), quickActionPickerContentHeight (D-15 new value)
└── (Shelf/, IslandResolver.swift, QuickActionSharingService.swift — UNCHANGED, reused verbatim)
```

### Pattern 3 (NEW): Analytical per-button live global frames — no GeometryReader/PreferenceKey needed
**What:** Compute the 3 buttons' global-screen-coordinate rects with pure arithmetic from already-known constants, mirroring `NotchGeometry.swift`'s own `expandedNotchFrame`/`topPinnedFrame` pattern, instead of round-tripping through SwiftUI's layout system.
**When to use:** D-11 (live hover highlight) and D-12 (release-on-target routing) — both need "is `NSEvent.mouseLocation` inside button N's frame?" answered synchronously, every tick, with no dependency on SwiftUI having rendered a frame yet.
**Why this is safe (and not a hack):** The button row is a fixed-width `HStack(spacing: 16)` of 3 chips, each `.frame(maxWidth: .infinity)` (34-UI-SPEC.md §5) inside a card of KNOWN, CONSTANT width (`expandedSize.width`, 420pt, unchanged per D-15) and KNOWN, CONSTANT padding (16pt horizontal inset). SwiftUI's layout algorithm gives 3 equal-flexibility children exactly equal widths deterministically — there is no dynamic content (no text reflow, no Dynamic Type variance considered in this project, no image aspect-ratio dependency) that could make the REAL rendered rects differ from the computed ones. The existing `quickActionPickerFrame` reservation in `positionAndShow()` already computes this SAME card's global frame this same way for panel-frame reservation — this pattern only extends that one call site's existing math one level deeper (card → 3 columns), not a new technique.
```swift
// Source: derived from this project's OWN NotchGeometry.swift (expandedNotchFrame/topPinnedFrame)
// and NotchWindowController.swift's existing positionAndShow() quickActionPickerFrame computation
// (both read directly, 2026-07-15). Compute once per positionAndShow() call, store as an ivar
// (mirrors expandedZone/dragLandingMaxY's own "computed once per resolve, read every tick" shape).
private func computeQuickActionButtonFrames(collapsed: CGRect) -> [CGRect] {
    let cardWidth = expandedSize.width                                    // 420pt, D-15: unchanged
    let cardHeight = NotchPillView.quickActionPickerContentHeight         // NEW value, see D-15 recompute below
    let card = expandedNotchFrame(collapsed: collapsed,
                                   expandedSize: CGSize(width: cardWidth, height: cardHeight))
    let horizontalInset: CGFloat = 16                                     // 34-UI-SPEC.md md token
    let buttonRowHeight: CGFloat = 59                                     // icon 22 + gap 8 + label ~13 + 2×8 vPad
    let bottomInset: CGFloat = 16                                         // D-15 worked-math term
    // AppKit bottom-left/y-up: the row sits `bottomInset` ABOVE the card's bottom edge (card.minY).
    let rowY = card.minY + bottomInset
    let rowRect = CGRect(x: card.minX + horizontalInset, y: rowY,
                          width: card.width - 2 * horizontalInset, height: buttonRowHeight)
    let gap: CGFloat = 16
    let colWidth = (rowRect.width - 2 * gap) / 3
    return (0..<3).map { i in
        CGRect(x: rowRect.minX + CGFloat(i) * (colWidth + gap), y: rowRect.minY,
               width: colWidth, height: rowRect.height)
    }
}
```
Call this from `positionAndShow()` right next to `quickActionPickerFrame`'s own computation, store the result in a new `private var quickActionButtonFrames: [CGRect] = []` ivar (same lifecycle discipline as `expandedZone`/`dragLandingMaxY`: recomputed every `positionAndShow()`, so display/resolution changes stay in sync automatically).

### Pattern 4 (NEW): D-10 — populate `pendingDrop` at the `dragEntered` edge, not at release
**What:** Move the pasteboard read + session-copy + `pendingDrop` assignment from `handleDragApproachEnd()` (today, on `.leftMouseUp`) to the rising-edge arm block inside `recheckDragAcceptRegion()` (the SAME block that already fires `interaction.phase = nextState(interaction.phase, .dragEntered)` and the auto-expand haptic).
**When to use:** This is D-10's literal requirement — the picker must be visible DURING the drag, and `IslandResolver.resolve()` only shows `.quickActionPicker` when `pendingDrop != nil`.
**Verified pasteboard timing (HIGH confidence — Apple API contract, not a guess):** `NSPasteboard(name: .drag)` is the exact same pasteboard `NSDraggingInfo.draggingPasteboard` exposes to a real `NSDraggingDestination`, and Apple's own `draggingUpdated(_:)` pattern reads file identity from it live, mid-drag, for real-time preview/highlight decisions — this is standard, well-established AppKit behavior, not something specific to Islet's workaround architecture. This project's OWN code already reads `pasteboard.changeCount` on every `.leftMouseDragged` tick (`handleDragApproachTick()`, pre-existing) specifically because the pasteboard IS live and readable throughout the drag session, not just at drop.
```swift
// Source: this project's own recheckDragAcceptRegion() (NotchWindowController.swift ~line 920),
// extended per D-10. Read directly 2026-07-15.
private func recheckDragAcceptRegion() {
    let point = NSEvent.mouseLocation
    let geometryInside = isWithinDragAcceptRegion(point, zone: expandedZone, maxY: dragLandingMaxY)
    if geometryInside && !isDragApproaching && !interaction.isExpanded {
        isDragApproaching = true
        graceWorkItem?.cancel()
        graceWorkItem = nil
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            interaction.phase = nextState(interaction.phase, .dragEntered)
            // Phase 34 UAT revision (D-10) — populate pendingDrop HERE, same edge as the
            // auto-expand, not at release (handleDragApproachEnd). The session-copy MECHANISM
            // itself is UNCHANGED (ShelfFileStore.makeSessionCopy) — only the call-site moved.
            let urls = fileURLs(from: NSPasteboard(name: .drag))
            if !urls.isEmpty {
                var items: [ShelfItem] = []
                for url in urls {
                    let id = UUID()
                    guard let localURL = try? ShelfFileStore.makeSessionCopy(of: url, id: id) else { continue }
                    items.append(ShelfItem(id: id, originalURL: url, localURL: localURL,
                                            filename: url.lastPathComponent, addedAt: Date()))
                }
                if !items.isEmpty { pendingDrop = PendingDrop(items: items) }
            }
            renderPresentation()
        }
        if dropInterceptTap == nil {
            dropInterceptTap = DropInterceptTap(
                shouldSwallow: { [weak self] in self?.isDragApproaching ?? false },
                onIntercept: { [weak self] in self?.handleDragApproachEnd() }
            )
        }
        dropInterceptTap?.start()
    } else if !geometryInside && isDragApproaching {
        isDragApproaching = false
        // Phase 34 UAT revision (D-13b, Pitfall 6) — MUST discard here too now that pendingDrop
        // lives from dragEntered through release; see Pitfall 6 for why this is a real fix,
        // not just "confirmation no change is needed."
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            discardPendingDrop()
            renderPresentation()
        }
    }
}
```
`handleDragApproachEnd()` no longer needs to build `pendingDrop` from scratch — see Pattern 5 for what it does instead.

### Pattern 5 (NEW): D-12 — release-on-target routing inside the existing intercept point
**What:** `handleDragApproachEnd()` — already this project's ONE real intercept point for a genuine drop release (invoked either via `dropInterceptTap`'s `onIntercept` at the `CGEvent` tap level, or via the `dragEndMonitor` `.leftMouseUp` fallback if Accessibility permission isn't granted) — hit-tests the release point against `quickActionButtonFrames` and calls the corresponding UNCHANGED handler directly, replacing the `Button(action:)` taps Plan 34-02 built.
**When to use:** Every real drop release while `pendingDrop != nil` (i.e., the picker is showing).
```swift
// Source: this project's own handleDragApproachEnd() (NotchWindowController.swift ~line 951),
// extended per D-12/D-13. Read directly 2026-07-15.
private func handleDragApproachEnd() {
    guard isDragApproaching else { return }
    isDragApproaching = false
    let point = NSEvent.mouseLocation

    // Phase 34 UAT revision (D-12/D-13) — a picker is already showing (pendingDrop was set at
    // dragEntered, Pattern 4). Route by WHICH button the release point falls in; the handlers
    // themselves are the SAME unchanged handleQuickActionDrop/AirDrop/Mail from the original spike.
    if pendingDrop != nil {
        if let hit = quickActionButtonFrames.firstIndex(where: { $0.contains(point) }) {
            switch hit {
            case 0: handleQuickActionDrop()
            case 1: handleQuickActionAirDrop()
            case 2: handleQuickActionMail()
            default: break
            }
        } else {
            discardPendingDrop()  // D-13: released inside the picker card but not on a button
            withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                renderPresentation()
            }
        }
        hoveredQuickActionButtonIndex = nil
        handlePointer(at: NSEvent.mouseLocation)  // Pitfall 3 resync, unchanged
        return
    }

    // Existing non-picker path (first-ever drag-enter before D-10's pasteboard read can run,
    // or a drag that never entered accept geometry) — unchanged from the original spike.
    let pasteboard = NSPasteboard(name: .drag)
    let urls = fileURLs(from: pasteboard)
    if shouldAcceptDrop(isExpanded: false, urls: urls),
       isWithinDragAcceptRegion(point, zone: expandedZone, maxY: dragLandingMaxY) {
        // ... (should be unreachable in practice once D-10 always populates pendingDrop at
        // dragEntered — kept only as a defensive fallback; flag to planner whether this branch
        // is provably dead code once D-10 ships, or worth keeping as a safety net.)
    }
    handlePointer(at: NSEvent.mouseLocation)
}
```
**Open question this pattern surfaces:** once D-10 always populates `pendingDrop` at the `dragEntered` edge, is the ORIGINAL drop-to-shelf fallback branch inside `handleDragApproachEnd()` ever still reachable? See Open Questions.

### Pattern 1 (original spike, unchanged): Direct NSSharingService invocation from a non-key panel
**What:** Call `NSSharingService(named:).perform(withItems:)` directly — no window activation, no key-window toggling.
**When to use:** Both AirDrop and Mail-compose-with-attachment, exactly as D-08/D-09 scope them.
**Evidence:** `TheBoredTeam/boring.notch` (`boringNotch/components/Shelf/Services/QuickShareService.swift`, read via `gh api repos/TheBoredTeam/boring.notch/contents/...`) calls this from a window with `override var canBecomeKey: Bool { false }` and `INFOPLIST_KEY_LSUIElement = YES` — architecturally identical to Islet's own `NotchPanel.swift`. No `makeKey`, `NSApp.activate`, or `orderFrontRegardless` call appears anywhere near their sharing code.
```swift
// Source: pattern verified against TheBoredTeam/boring.notch (MIT-licensed reference app),
// QuickShareService.swift, live-read via `gh api repos/TheBoredTeam/boring.notch/contents/...`
if let svc = NSSharingService(named: .sendViaAirDrop), svc.canPerform(withItems: urls) {
    svc.delegate = sharingDelegate   // see Pattern 2 — needed for completion, NOT for the call to work
    svc.perform(withItems: urls)     // no window activation of any kind
}
```

### Pattern 2 (original spike, unchanged): Delegate + timeout fallback for pending-state cleanup
**What:** `NSSharingServiceDelegate` conformance to know when sharing finished, backed by a short timeout (mirrors Phase 21's `dragPinSafetyNetDuration` precedent).
```swift
// Source: pattern adapted from TheBoredTeam/boring.notch models/SharingStateManager.swift
final class QuickActionSharingDelegate: NSObject, NSSharingServiceDelegate {
    private let onFinish: () -> Void
    private var finished = false
    private var timeoutWorkItem: DispatchWorkItem?

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init()
        let timeout = DispatchWorkItem { [weak self] in self?.finish() }
        timeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: timeout)
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) { finish() }
    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) { finish() }

    private func finish() {
        guard !finished else { return }
        finished = true
        timeoutWorkItem?.cancel()
        onFinish()
    }
}
```
Already implemented and build-green as `QuickActionSharingService`/its tests (34-02-SUMMARY.md) — unchanged by this revision.

### Anti-Patterns to Avoid
- **Building a `GeometryReader`+`PreferenceKey` pipeline for button geometry.** See Alternatives Considered / Pitfall 7 — this codebase has zero precedent for it, it introduces a real coordinate-space conversion this project's own geometry code has repeatedly documented as a pitfall class (`notchFrame`'s own "Pitfall 1" comment), and it buys no accuracy the analytical approach doesn't already have for this specific, fully-deterministic 3-equal-column layout.
- **Assuming D-13b "needs no change."** See Pitfall 6 — it needs exactly one new line (`discardPendingDrop()`) in an already-identified location; skipping it leaves a session-copy leak and a picker that never dismisses on drag-out.
- **Recomputing `quickActionButtonFrames` on every `.leftMouseDragged` tick.** Compute once per `positionAndShow()` (mirrors `expandedZone`/`dragLandingMaxY`'s existing lifecycle) — hit-testing against the stored rects on every tick is cheap; recomputing the rects themselves on every tick is wasted work for a value that only changes on resolution/display change.
- **Forcing the panel key before spiking the direct AirDrop/Mail call:** unchanged from the original spike — D-08's exception is deliberately narrow, not a default.
- **Routing "Drop" through anything other than the existing `ShelfCoordinator.append`/`ShelfFileStore.makeSessionCopy`:** unchanged — no reason to add an intermediate step.
- **Building a general focus-behavior toggle on `NotchPanel`:** unchanged.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| **Live drag-target hit-testing (NEW, this revision)** | A `GeometryReader`+`PreferenceKey` publishing pipeline from `NotchPillView` up to the controller | Pure analytical `CGRect` computation in the controller (Pattern 3), mirroring `NotchGeometry.swift`'s existing `expandedNotchFrame`/`topPinnedFrame` | The layout is fully deterministic from constants the controller already owns (`expandedSize.width`, fixed padding, 3 equal-flex columns) — no SwiftUI round-trip needed, and it avoids this codebase's first-ever coordinate-space conversion between SwiftUI `.global` (window-local, y-down) and AppKit screen space (y-up) that a real `PreferenceKey` pipeline would require |
| AirDrop device picker UI | A custom device-discovery/AirDrop UI | `NSSharingService(named: .sendViaAirDrop)` | Unchanged — see original |
| Mail compose window | A custom compose sheet | `NSSharingService(named: .composeEmail)` | Unchanged — see original |
| Share-completion timing | Polling/guessing when the user is "done" | `NSSharingServiceDelegate` callbacks + a bounded timeout fallback | Unchanged — see original |

**Key insight:** The new drag-target unknown looked like it might need genuinely new SwiftUI infrastructure (a `PreferenceKey` pipeline, this codebase's first). It doesn't — the controller already has everything it needs to compute the answer itself, the same way it already computes every other presentation's click-through geometry. The AirDrop/Mail OS-integration surface remains, as before, two enum-constant lookups and one method call.

## Common Pitfalls

### Pitfall 6 (NEW, most important finding of this revision): D-13b's exit branch does not actually clear `pendingDrop`
**What goes wrong:** `recheckDragAcceptRegion()`'s exit condition (`!geometryInside && isDragApproaching`) today only sets `isDragApproaching = false`. It does not touch `pendingDrop`, does not call `discardPendingDrop()`, and does not call `renderPresentation()`. Once D-10 moves `pendingDrop` population to the `dragEntered` arm edge, this means: dragging the pointer back out of the accept geometry before releasing leaves `pendingDrop` set, `interaction.isExpanded` stays `true` (nothing in this branch touches `interaction.phase`), and `IslandResolver.resolve()`'s `if let pendingDrop { return .quickActionPicker(pendingDrop) }` branch (inside `if isExpanded`) keeps firing — **the picker never actually disappears**, contradicting D-13b's literal requirement ("collapses the picker with no destination chosen"). Worse: if the user re-enters the accept region a second time without ever releasing, the arm block runs again and OVERWRITES `pendingDrop` with a fresh `PendingDrop` — the FIRST session-copied temp file (`ShelfFileStore.makeSessionCopy`'s output) is never deleted by anything, since only `discardPendingDrop()`/`finishQuickActionSharing()`/`handleQuickActionDrop()` ever call `ShelfFileStore.deleteSessionCopy(at:)`, and none of them run on this path. This is a real disk-leak, not just a visual glitch.
**Why it happens:** D-13b's own CONTEXT.md text says this exit condition "needs no change, just confirmation" — that claim was written BEFORE D-10 moved `pendingDrop`'s lifetime earlier; it was true of the PRE-revision code (where `pendingDrop` was only ever set at release, so there was nothing to clean up on an early exit) and is no longer true once D-10 lands.
**How to avoid:** Add `discardPendingDrop()` + `renderPresentation()` (wrapped in the same `withAnimation` spring every other state transition in this file uses) to the exit branch, exactly as shown in Pattern 4's code example. This is a small, contained fix — one call, one existing function, no new state.
**Warning signs:** Drag a file into the accept region (picker shows), drag the pointer back out WITHOUT releasing, observe whether the picker actually reverts to the previous presentation. If it stays showing, this fix is missing. Also check `/tmp/.../IsletShelf/` (or wherever `ShelfFileStore`'s session-copy directory lands) for orphaned UUID-named directories after a few enter/exit-without-release cycles.

### Pitfall 7 (NEW): SwiftUI `.global` coordinate space is window-local, not screen-global — the reason the analytical approach was chosen over `GeometryReader`
**What goes wrong:** If a future need DOES require reading real SwiftUI-rendered geometry (e.g. if Pattern 3's determinism assumption ever breaks — see Open Questions), a naive `geo.frame(in: .global)` inside a `GeometryReader` hosted via `NSHostingView` does NOT return AppKit screen coordinates. SwiftUI's `.global` coordinate space is relative to the ENCLOSING WINDOW's origin (top-left, y DOWN), not the screen (bottom-left, y UP) that `NSEvent.mouseLocation`, `hotZone`, `expandedZone`, and every other geometry value in `NotchWindowController.swift` uses.
**Why it happens:** This is a general SwiftUI/AppKit interop gotcha, not specific to this project — but this project's OWN `NotchGeometry.swift` has hit and documented the AppKit-side half of this exact class of mismatch already (`notchFrame`'s own doc comment: "AppKit windows use a BOTTOM-LEFT origin with y increasing upward... (Pitfall 1)").
**How to avoid:** The recommended approach (Pattern 3) sidesteps this entirely — it never asks SwiftUI for a rendered rect, so there's no conversion to get wrong. If a future change genuinely needs real rendered geometry, the conversion must go through `panel.convertToScreen(_:)` (from window-local) plus an explicit y-flip against `NSScreen`'s frame — flag this to the planner as a real cost if the `PreferenceKey` alternative is ever revisited.
**Warning signs:** Hit-testing that's consistently off by the panel's height or flipped vertically is the signature symptom of skipping this conversion.

### Pitfall 8 (NEW): D-11's live highlight must publish only on change, not every tick
**What goes wrong:** `handleDragApproachTick()` fires on every `.leftMouseDragged` event — potentially dozens of times per second during a real drag. If the hover-index computation writes to a `@Published`/observable property unconditionally on every tick (even when the hovered button hasn't changed), SwiftUI re-renders the picker view dozens of times per second for no visual change — real, avoidable CPU/battery cost during every drag-hover.
**Why it happens:** It's the naive/obvious way to wire "compute this every tick, show it in the view."
**How to avoid:** Mirror this project's OWN existing convention for exactly this shape of problem — `handleDragApproachTick()`'s pre-existing `dragPasteboardChangeCount` tracking already does "read something on every tick, but only ACT when the value actually changed." Apply the same guard: `let hit = quickActionButtonFrames.firstIndex { $0.contains(point) }; if hit != hoveredQuickActionButtonIndex { hoveredQuickActionButtonIndex = hit }`.
**Warning signs:** Visible frame-rate stutter or elevated CPU specifically during a drag-hover over the picker (not during an ordinary drag elsewhere) is the signature of this being missed.

### Pitfall 9 (NEW, restates a UAT-flagged visual bug for the planner's Wave 0 scope): icon-height mismatch across SF Symbols at the same point size
**What goes wrong:** `tray.and.arrow.down.fill` (Drop) renders at a visibly different intrinsic height than `personalhotspot` (AirDrop) / `envelope.fill` (Mail) at the identical `.font(.system(size: 22))` — SF Symbols' bounding boxes are not uniform across glyphs even at the same point size, so 3 buttons built the same way don't end up pixel-identical in height.
**Why it happens:** This is an SF Symbols characteristic, not a bug in this project's code — some symbols have taller/shorter natural glyph bounds than others at a given rendering size.
**How to avoid:** Give the icon a FIXED frame (e.g. `.frame(height: 22)` or a slightly taller fixed box, centered) INSIDE `quickActionButton`'s `Image(systemName:)` call, so all 3 icons occupy identical layout space regardless of each glyph's own natural bounds — the fix UAT itself already named ("a fixed icon frame").
**Warning signs:** Visual side-by-side comparison of the 3 buttons shows one (or more) sitting at a different vertical position/height than its siblings.

### Pitfall 1 (original spike, unchanged): `NotchPanel`'s `orderFrontRegardless()`-only show cycle vs. boring.notch's `BoringNotchSkyLightWindow`
**What goes wrong:** Islet's `NotchPanel` is shown via `panel.orderFrontRegardless()` only, `level = .statusBar`. Boring.notch's window class name hints it may use private `SkyLight`/`CGSSetWindowLevel` APIs for a higher window level. Worth explicitly confirming during the spike that Islet's own `.statusBar`-level, non-key panel behaves the same.
**How to avoid:** The phase's spike task should be a minimal, throwaway on-device test before committing to the full picker UI build. **Status: this spike has NOT yet been completed on-device** — 34-02's checkpoint reached step 1 but the user's report focused entirely on the drag-hover/interaction-model bug (Pitfall now moot, since the whole trigger mechanism is being rebuilt) rather than confirming whether AirDrop/Mail actually invoked successfully. Re-run this spike as part of the gap-closure plan's own first on-device checkpoint, now using the NEW release-on-target trigger (Pattern 5) rather than the old click handler.
**Warning signs:** AirDrop/Mail silently does nothing when released on that button (no error, no window).

### Pitfall 2 (original spike, unchanged): `canPerform(withItems:)` returning false for non-file items
Unchanged — see original text. Still applies identically once invocation is triggered by release-on-target instead of a tap.

### Pitfall 3 (original spike, unchanged): Mail attachment support is Mail.app-only
Unchanged — already documented, accepted, out of scope for a fix.

### Pitfall 4 (original spike, unchanged, re-emphasized for D-15): CR-01 click-through regression
**What goes wrong:** A new/resized `IslandPresentation` case that isn't mirrored correctly in `visibleContentZone()`/`positionAndShow`'s panel-frame union causes dead-zone clicks or click-swallowing. **D-15's height change makes this apply AGAIN, freshly** — `quickActionPickerContentHeight` shrinks from 188 to a new value (Pattern 3's worked math: 117), so all three sites (`blobShape`'s height override, `positionAndShow`'s `quickActionPickerFrame` union member, `visibleContentZone()`'s `.quickActionPicker` branch) must be updated together, in the SAME commit, exactly as the original build already did once for the 188pt value — this is not new wiring, just a value change that must land in 3 places, not 1.
**How to avoid:** Update the constant in `NotchPillView.swift`, verify `positionAndShow` and `visibleContentZone()` both reference `NotchPillView.quickActionPickerContentHeight` (not a hardcoded duplicate — confirmed true in the current source, both already read the shared constant) so a single edit propagates correctly. Still requires the mandatory on-device hover→expand→move-down click-through trace.

### Pitfall 5 (original spike, unchanged): Picker's pending-drop state surviving a Charging/Device transient interruption (D-05)
Unchanged — already correctly implemented (controller-owned `pendingDrop`, fed into `resolve(...)` fresh each call). Confirmed still correct reading the current source: `pendingDrop` lives on `NotchWindowController` (line ~118), threaded into every `currentPresentation()`/`resolve(...)` call.

## Code Examples

### D-15 worked height recompute (new `quickActionPickerContentHeight` value)
```swift
// Phase 34 UAT revision (D-15) — same worked-math-comment convention as the original 188pt
// constant (34-UI-SPEC.md §2). With the preview (D-02) and its 16pt section gap removed
// entirely (D-14), only cameraClearance + the button row + a bottom inset remain:
//   cameraClearance(42) + buttonChip(icon 22 + gap 8 + label ~13 + vPadding 2×8 ≈ 59) + bottomInset(16) = 117
static let quickActionPickerContentHeight: CGFloat = 117
```
Treat 117pt as a starting value to confirm/tune on first on-device build — same convention as every prior phase's own geometry number (34-UI-SPEC.md's own stated precedent: "Tray took 3 rounds, Weather took 6").

### D-11 highlight rendering (view side — reads the published index, does not compute it)
```swift
// Source: composed for this revision, following NotchPillView's existing "controller computes,
// view renders" split (e.g. presentationState itself).
private func quickActionButton(icon: String, label: String, enabled: Bool,
                                isHovered: Bool, action: @escaping () -> Void) -> some View {
    VStack(spacing: 8) {
        Image(systemName: icon)
            .font(.system(size: 22))
            .frame(height: 22)   // Pitfall 9 fix — fixed icon box, all 3 buttons render identical height
        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
    }
    .foregroundStyle(.white.opacity(enabled ? 1.0 : 0.3))
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            // D-11: brighter fill under the live pointer during the drag
            .fill(Color.white.opacity(enabled ? (isHovered ? 0.22 : 0.12) : 0.06))
    )
    .scaleEffect(isHovered ? 1.04 : 1.0)   // D-11: slight scale, matches this project's
                                            // existing hover-scale convention (NotchPillView.swift:564)
}
```
Note: this button is no longer wrapped in a real `Button(action:)` for the drag-release path (D-12 routes selection from the controller's release hit-test, Pattern 5) — but keeping a tappable fallback (e.g. an ordinary click still selecting the destination) is a reasonable UX safety net for a user who prefers click-after-hover; left as a planner/executor decision, not locked by this research.

### Full AirDrop/Mail request flow (original spike, unchanged)
```swift
// Source: composed from Apple's NSSharingService docs + boring.notch's verified usage pattern
final class QuickActionSharingService {
    private var activeDelegate: QuickActionSharingDelegate?

    func share(_ urls: [URL], via name: NSSharingService.Name, onFinish: @escaping () -> Void) {
        guard let svc = NSSharingService(named: name), svc.canPerform(withItems: urls) else {
            onFinish()
            return
        }
        let delegate = QuickActionSharingDelegate(onFinish: { [weak self] in
            self?.activeDelegate = nil
            onFinish()
        })
        activeDelegate = delegate
        svc.delegate = delegate
        svc.perform(withItems: urls)
    }
}
```
Already implemented, build-green, unchanged by this revision.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `NSSharingServicePicker` for arbitrary destination choice | Direct `NSSharingService(named:).perform(withItems:)` | Not a recent API change — this project's own Out-of-Scope decision | Unchanged |
| Click-based picker (tap a button after the drop lands, Plan 34-02's original build) | Drag-and-release-on-target (this revision, D-12) | 2026-07-15, on-device UAT | Matches the user's own stated mental model ("man zieht die Dateien... und das was man machen will, da zieht man die Dateien halt hin") and the Droppy/iOS-share-sheet-style drop-target convention this feature is explicitly modeled on |

**Deprecated/outdated:** Nothing in the `NSSharingService` API surface is deprecated. The click-based `Button(action:)` picker Plan 34-02 built is functionally superseded by this revision's release-on-target model, but its underlying handlers (`handleQuickActionDrop/AirDrop/Mail`) remain current and reused verbatim.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 (original) | Islet's `NotchPanel` (`.statusBar` level) will behave identically to boring.notch's window regarding `NSSharingService` from a non-key panel | Pitfall 1, Summary | **Still unverified on-device** (see Pitfall 1 status note) — the phase's required spike must still run, now gated behind the NEW release-on-target trigger rather than the old click handler |
| A2 (original) | The recommended timeout duration for the sharing-completion fallback is left as "tune during on-device UAT," not a locked value | Pattern 2 | Low risk, explicitly flagged as tunable |
| A3 (NEW) | The button row's HStack with 3 equal-`.frame(maxWidth: .infinity)` children lays out EXACTLY as computed (no SwiftUI layout-pass rounding/pixel-snapping drift from the analytical arithmetic) | Pattern 3 | If SwiftUI's actual pixel-snapped layout diverges from the pure-math columns by more than a few px, hit-testing near a button's edge could feel slightly "off" from the visible highlight — low risk given the ~118pt column width leaves generous margin, but worth confirming on the same on-device trace CR-01 already requires |
| A4 (NEW) | `buttonRowHeight` (59pt: icon 22 + gap 8 + label ~13 + 2×8 padding) accurately reflects the REAL rendered height of `quickActionButton` once Pitfall 9's fixed icon frame is applied | Pattern 3, D-15 | If the real rendered height differs, `quickActionButtonFrames`' Y-range would be off by the same delta — same on-device trace catches this; low risk since this height formula matches 34-UI-SPEC.md's own pre-existing worked math for the identical chip shape |
| A5 (NEW) | The original click-based `handleDragApproachEnd()` fallback branch (drop-to-shelf without a picker) becomes unreachable once D-10 always populates `pendingDrop` at `dragEntered` | Pattern 5 | If some drag path exists where `dragEntered` never fires but `.leftMouseUp` still does (e.g. a very fast flick-drop), this fallback branch might still matter — flagged as an Open Question, not asserted either way |

**If this table is empty:** N/A — see rows above; A1/A2 carried over from the original spike (A1 status updated to reflect the spike is STILL pending), A3–A5 are new to this revision.

## Open Questions

1. **(Carried over, still open) Does Islet's exact `NotchPanel` actually invoke AirDrop/Mail successfully with zero key-window changes?**
   - What we know: A real shipping app with an architecturally identical non-key panel does this successfully with no workaround.
   - What's unclear: Whether Islet's own specific window level/Space configuration introduces any difference boring.notch's setup doesn't share.
   - Recommendation: Unchanged — this is the phase's required first on-device spike, now to be re-run against the NEW release-on-target trigger (Pattern 5) instead of the superseded click handler.

2. **(NEW) Is the original drop-to-shelf fallback branch inside `handleDragApproachEnd()` still reachable once D-10 ships?**
   - What we know: D-10 populates `pendingDrop` at the SAME `dragEntered` edge that already exists today and already always fires before any possible release (the auto-expand and the drop-accept-region check share the same `geometryInside` gate).
   - What's unclear: Whether there's any edge case (extremely fast drag, a drag that somehow reaches `.leftMouseUp` without a prior `.leftMouseDragged` tick ever calling `recheckDragAcceptRegion()`) where the fallback path is still exercised.
   - Recommendation: Keep the fallback branch as a defensive no-op for now (cheap insurance), but flag it in the plan for the executor to note whether it's ever actually hit during on-device testing — remove in a later cleanup pass if confirmed dead.

3. **(NEW) Interaction between D-13b's picker-specific discard and the broader hover/`expandedZone` keep-open mechanics.**
   - What we know: `recheckDragAcceptRegion()`'s exit condition uses `expandedZone` (the broader padded PANEL union across ALL presentations), while the picker's own accept/button geometry is narrower. Discarding `pendingDrop` on this exit (Pitfall 6 fix) correctly makes the RESOLVER stop returning `.quickActionPicker`, but `interaction.isExpanded`/the general hover-keep-open state is a SEPARATE mechanism (driven by `handlePointer`/`pointerInZone`, which tracks `.mouseMoved` events — largely inert during an actual OS drag since drags generate `.leftMouseDragged`, not `.mouseMoved`).
   - What's unclear: Exactly what the island visually shows for the brief window between "pointer exits picker geometry, still mid-drag" and "drag ends" — likely whatever `resolve()` falls back to next (Now Playing / Home, per the pre-Phase-34 baseline drag-hover behavior), which is probably fine and arguably matches the ORIGINAL (pre-Phase-34) drag-hover UX the UAT-flagged bug report was implicitly comparing against for the "wrong presentation" symptom — but this needs an explicit on-device trace to confirm the transition feels clean, not jarring.
   - Recommendation: Add this exact sequence (drag in → picker shows → drag pointer out without releasing → observe fallback presentation → re-enter → confirm picker resumes cleanly) as one of the gap-closure plan's own on-device checkpoint steps, alongside the existing CR-01 trace and the AirDrop/Mail spike re-run.

4. **(Carried over) Exact timeout value for the sharing-completion fallback.**
   - Unchanged from the original spike — left as a planner/executor tuning decision.

## Environment Availability

Not applicable — no external tools/services/runtimes beyond what's already linked into this Xcode project. No new SPM dependency, no CLI tool, no service to probe. (Unchanged from original spike.)

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest, `IsletTests` target (XcodeGen `project.yml`) |
| Config file | `project.yml` — shared `Islet` scheme |
| Quick run command | `xcodebuild build -scheme Islet -destination 'platform=macOS'` (build-only gate — `xcodebuild test` hangs headless in this project) |
| Full suite command | Manual Cmd-U in Xcode (NOT `xcodebuild test`) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRAY-02 | Picker shows DURING the drag (dragEntered edge), not after release | unit (pure `recheckDragAcceptRegion` logic is currently entangled with AppKit/NSEvent — likely needs the analytical `computeQuickActionButtonFrames`/geometry math extracted as a pure top-level function in `NotchGeometry.swift` or `DragDropSupport.swift`, mirroring `isWithinDragAcceptRegion`'s own existing pattern, so it's unit-testable) + manual on-device | `xcodebuild build -scheme Islet`; new pure-function unit test if extracted | ❌ Wave 0 — recommend extracting `quickActionButtonFrames(card:)` as a standalone pure function purely so it can be unit-tested the same way `isWithinDragAcceptRegion`/`expandedNotchFrame` already are, rather than burying the math inline in `positionAndShow()` |
| TRAY-03 | Release-on-"Drop" stages the file and switches to Tray | unit (`handleQuickActionDrop()` itself already covered conceptually by existing `ShelfCoordinatorTests.swift`) + manual on-device (the NEW release-on-target trigger path itself) | `xcodebuild build -scheme Islet`; manual Cmd-U | ⚠️ Partial — underlying `append`/`makeSessionCopy` covered; the NEW hit-test-routing glue needs its own pure-function unit test (see TRAY-02 row) |
| TRAY-04 | Release-on-"AirDrop"/"Mail" invokes `NSSharingService` | unit (`QuickActionSharingServiceTests.swift` already exists, unchanged) + manual on-device (real OS hand-off, the still-pending spike from Open Question 1) | `xcodebuild build -scheme Islet`; manual Cmd-U for the mockable-seam unit test; real hand-off is manual-only | ✅ Existing `QuickActionSharingServiceTests.swift` covers the seam; the NEW release-on-target routing to it needs the same pure-function unit test as above |
| D-13b/Pitfall 6 | Dragging out before release discards `pendingDrop` and cleans up the session-copy | unit (if `discardPendingDrop()`'s call is threaded through a testable seam) + manual on-device (check no orphaned temp dirs after an enter/exit-without-release cycle) | `xcodebuild build -scheme Islet`; manual Cmd-U + manual filesystem check | ❌ Wave 0 |
| D-11 | Button under pointer highlights live during the drag | manual on-device only — this is a pure rendering/feel check, not automatable | manual Cmd-U + on-device drag trace | N/A — manual by nature |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet -destination 'platform=macOS'`
- **Per wave merge:** Manual Cmd-U in Xcode (full `IsletTests` suite)
- **Phase gate:** Full suite green (manual Cmd-U) before `/gsd:verify-work`, PLUS the mandatory on-device CR-01 hover→expand→move-down trace (now against the D-15 SMALLER card height), PLUS a real on-device AirDrop/Mail hand-off trial (Open Question 1, still pending from the original spike), PLUS the NEW drag-in/drag-out/re-entry trace from Open Question 3

### Wave 0 Gaps
- [ ] Extract `computeQuickActionButtonFrames`/the button-column math as a standalone PURE function (mirrors `isWithinDragAcceptRegion`/`expandedNotchFrame`'s existing testable-seam convention) so TRAY-02/03/04's new hit-testing logic gets real unit coverage, not just manual on-device verification
- [ ] `IslandResolverTests.swift` — NO new coverage needed here; `resolve()`'s own pure logic for `.quickActionPicker`/`pendingDrop` precedence is UNCHANGED by this revision and already covered (`testPendingDropExpandedReturnsQuickActionPicker`, `testPendingDropOutranksSelectedViewFullTakeover`, `testChargingTransientOutranksPendingDrop`, `testPendingDropInertWhileNotExpanded` — all confirmed present and still valid)
- [ ] New test(s) for the Pitfall 6 fix — confirm `discardPendingDrop()` is actually called from the exit branch (could be a controller-level integration test, or verified purely via the manual on-device filesystem check if a unit seam isn't practical)
- [ ] Framework install: none — `IsletTests` target and `Islet` scheme already exist and are wired

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | no | N/A |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A — local-only, single-user desktop utility |
| V5 Input Validation | yes | Unchanged from original spike — `ShelfItemView`'s existing filename truncation convention. **Note (D-14):** the file preview this convention protected is now REMOVED from the picker UI entirely, so this control is moot for the picker's own rendering (nothing displays the untrusted filename anymore) — it still applies wherever `ShelfItemView` itself renders (Tray, after "Drop" is chosen), unchanged |
| V6 Cryptography | no | N/A |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| Dropped file with a path/URL that no longer exists by the time a destination is chosen (race between drag-enter session-copy and eventual release — WIDENED window now that D-10 copies-in earlier, at drag-enter, rather than at release) | Denial of Service (local, UX-level) | `try?` around `ShelfFileStore.makeSessionCopy` already fails gracefully (skips that item); `canPerform(withItems:)`/`NSSharingServiceDelegate` failure paths handle the AirDrop/Mail side. **New consideration:** since the copy now happens earlier (drag-enter, not release), the window during which the SOURCE file could be deleted/moved by its origin app BEFORE the copy runs is actually SHORTER (copy happens sooner), which is a net safety improvement, not a regression |
| Orphaned session-copy temp files from an incomplete drag (Pitfall 6) | Denial of Service (local disk usage, not a security boundary but a real resource leak) | The Pitfall 6 fix (`discardPendingDrop()` on drag-exit) is the mitigation — without it, repeated enter/exit-without-release cycles accumulate orphaned temp directories under `NSTemporaryDirectory()/IsletShelf/` indefinitely |

This phase's security profile remains minimal — no network surface, no credentials. This revision's one new consideration (the session-copy leak from Pitfall 6) is a resource-hygiene issue, not a security vulnerability, but is worth the planner explicitly gating behind a verification step given it's an on-disk leak that would otherwise be silent.

## Sources

### Primary (HIGH confidence)
- **This project's own current source, read directly 2026-07-15 (revision 2):** `Islet/Notch/NotchWindowController.swift` (`recheckDragAcceptRegion`, `handleDragApproachTick`, `handleDragApproachEnd`, `positionAndShow`, `visibleContentZone`, `handleHoverExit`, `handleClick`, `discardPendingDrop`, `pendingDrop` ivar declaration), `Islet/Notch/NotchGeometry.swift` (`expandedNotchFrame`, `topPinnedFrame`, `notchFrame` — including its own documented AppKit-coordinate-space pitfall), `Islet/Notch/DragDropSupport.swift` (`fileURLs`, `shouldAcceptDrop`, `isWithinDragAcceptRegion`), `Islet/Notch/DropInterceptTap.swift` (the real `.leftMouseUp` intercept mechanism, its own documented event-relocation pitfall), `Islet/Notch/NotchPillView.swift` (`quickActionPickerView`, `quickActionButtonRow`, `quickActionButton`, confirmed zero existing `PreferenceKey` usage, both existing `GeometryReader` uses confirmed LOCAL-only), `Islet/Notch/IslandResolver.swift` (`PendingDrop`, `resolve()`, `showsSwitcherRow`), `IsletTests/IslandResolverTests.swift` (confirmed existing `.quickActionPicker`/`pendingDrop` test coverage still valid, unchanged)
- `TheBoredTeam/boring.notch` GitHub repository (original spike, unchanged) — see below
- Apple AppKit SDK header `NSSharingService.h` (original spike, unchanged)
- Apple's documented `NSDraggingInfo.draggingPasteboard`/`draggingUpdated(_:)` contract (general AppKit API knowledge, HIGH confidence — this is standard, long-stable AppKit behavior: the drag pasteboard is live and readable throughout a drag session, not just at drop; corroborated indirectly by this project's own pre-existing `dragPasteboardChangeCount` polling on every tick, which only makes sense if the pasteboard IS live mid-drag)

### Secondary (MEDIUM confidence)
- `faichou.com/posts/air-share-with-swift/` (original spike, unchanged)
- Bugzilla #1491683 (original spike, unchanged)

### Tertiary (LOW confidence)
- None used as load-bearing claims in either the original spike or this revision.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pure Apple-framework API + this project's own existing pure functions, no ambiguity
- Architecture (drag-target hit-testing, this revision): HIGH — the analytical approach is derived directly from this project's own current, working source (`expandedNotchFrame`/`positionAndShow`'s existing pattern), not a novel untested technique
- Architecture (resolver/controller integration, original spike): HIGH — unchanged, directly read this project's own current source
- Core AirDrop/Mail spike question (original): HIGH — verified against a real shipping app's source, but **the actual on-device confirmation is still pending** (see Pitfall 1 status, Open Question 1) — this is a confidence-of-the-RESEARCH distinction, not a confidence-of-the-OUTCOME distinction
- Pitfalls: HIGH for Pitfall 6 (directly traced through this project's own current control flow, not inferred) and Pitfalls 7-9 (standard, well-documented SwiftUI/AppKit/SF-Symbols characteristics); MEDIUM for the exact `buttonRowHeight`/timing tuning values (flagged as Assumptions A3/A4, expected to need on-device confirmation like every other geometry constant in this project)

**Research date:** 2026-07-15 (original), revised 2026-07-15 (revision 2, same day — post-UAT)
**Valid until:** 30 days (stable Apple API surface; the drag-target architecture is entirely this project's own code, not subject to external API drift — re-verify sooner only if a macOS update changes `NSEvent`/`CGEvent` tap behavior, which this project has not observed historically)
