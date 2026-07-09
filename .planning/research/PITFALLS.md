# Pitfalls Research

**Domain:** Drag-and-drop file shelf added to an existing non-activating, click-through notch-overlay `NSPanel` (Islet/Notch, v1.3 "Notch Shelf")
**Researched:** 2026-07-09
**Confidence:** MEDIUM-HIGH (grounded in direct read of `NotchWindowController.swift`/`IslandResolver.swift`, Apple API docs, and TheBoringNotch's shipped shelf architecture; LOW-confidence items flagged individually)

## Critical Pitfalls

### Pitfall 1: `ignoresMouseEvents = true` silently blocks ALL drag-and-drop delivery, not just clicks

**What goes wrong:**
The panel already relies on `panel?.ignoresMouseEvents = !interactive` (`syncClickThrough()`, `NotchWindowController.swift:696-699`) to stay click-through everywhere except the hot-zone. Apple's own docs for `NSWindow.ignoresMouseEvents` state the window becomes "transparent to all mouse events" when true — this is not scoped to clicks. AppKit's drag-destination hit-testing (`draggingEntered`/`draggingUpdated`/`performDragOperation`) is routed through the exact same window-server mouse-event delivery path. A window that ignores mouse events is invisible to the drag machinery too: registering `registerForDraggedTypes(...)` on the hosted `NSHostingView` (or a `.onDrop` in the SwiftUI tree) has **zero effect** while `ignoresMouseEvents` is true, because the drag session never reaches the window at all.

**Why it happens:**
The existing hover architecture (Phase 2) was built for *clicks*, where "pass through everywhere except a tiny hot-zone" is exactly correct. Drag-and-drop looks like the same problem ("only react near the notch") but is a fundamentally different event path — it's easy to assume flipping the same flag on drag-enter will "just work" the way it does for hover, because the code already does that dance for `.mouseMoved`.

**How to avoid:**
Detect an in-flight drag session independently of the panel's own drag-destination callbacks (which can never fire while the panel is click-through) — mirror the project's existing pattern of a **global NSEvent monitor** (it already has one for `.mouseMoved` at `NotchWindowController.swift:299`) but add `.leftMouseDragged`, hit-test the pointer location against the (drag-specific, slightly larger) hot-zone, and — the moment the pointer enters — flip `ignoresMouseEvents = false` through the *same* `syncClickThrough()` single-writer function before AppKit's drag-destination determination needs it. Only once the window has stopped ignoring mouse events will `draggingEntered` on a `registerForDraggedTypes` view (or SwiftUI `.onDrop`) actually get called. Confirm the drag pasteboard is really a file drag (`NSPasteboard(name: .drag)` change count / `hasItemConformingToTypeIdentifier(.fileURL)`) before treating it as a shelf trigger, matching the technique TheBoringNotch's `DragDetector` and community write-ups use for exactly this scenario.

**Warning signs:**
Dragging a file over the collapsed pill does nothing at all — no expand, no hover cursor change, `.onDrop`'s `isTargeted` binding never flips true even though the pointer is visually over the notch.

**Phase to address:**
Pure-seam/model phase must define the drag-hit-test as a pure function (mirrors `nextState`/`handlePointer`'s existing hotZone math) BEFORE the view-wiring phase adds any `.onDrop`/`registerForDraggedTypes` call — wiring `.onDrop` first without the `ignoresMouseEvents` fix will look "done" in a simulator/preview but silently fail on the real panel.

---

### Pitfall 2: `.mouseMoved` stops firing during an active drag — the existing hover/grace-collapse state machine freezes mid-drag

**What goes wrong:**
AppKit does not deliver ordinary `.mouseMoved` events while a mouse button is held down and a drag is in progress — pointer motion during a drag arrives only as `.leftMouseDragged`. The existing `handlePointer(at:)` (fed exclusively by the `.mouseMoved` global monitor) therefore **freezes** the instant any drag starts, anywhere on screen — including a drag-out of a shelf file. Concretely: user starts dragging a file out of the expanded shelf toward Finder; `pointerInZone` was `true` at drag-start and never updates again because no more `.mouseMoved` events arrive; the pointer visually leaves `expandedZone` but `handleHoverExit()`/the grace-collapse timer is never scheduled, so **the island stays expanded and stuck** until the drag ends and a fresh `.mouseMoved` finally fires (or, if it un-sticks only after drop, is visually jarring). The inverse also breaks auto-expand-on-hover: a file dragged in from Finder generates `.leftMouseDragged`, not `.mouseMoved`, so the auto-expand logic (if wired only to the existing hover monitor) never triggers at all — the exact "false negative" the milestone is worried about.

**Why it happens:**
This is invisible in normal manual testing because a developer testing hover/click never has a mouse button held down; it only shows up once a real drag session (in or out) is exercised, which non-drag phases of this project never needed to consider.

**How to avoid:**
Add a **second** global monitor for `.leftMouseDragged` (and `.leftMouseUp` to detect drag-end) alongside the existing `.mouseMoved` one, and feed both into the same `pointerInZone`/zone-hit-test logic — during a drag, zone membership must be evaluated from `.leftMouseDragged` locations, not `.mouseMoved`. `.leftMouseUp` should force a final zone check so a drag that ends outside the zone properly triggers the grace-collapse instead of leaving the island open forever.

**Warning signs:**
Manually dragging a file out of the shelf and dropping it on the Desktop, then moving the mouse without touching it again — island stays expanded with no pointer inside it until the next stray `.mouseMoved`.

**Phase to address:**
View-wiring/gesture-integration phase, and must be covered by an explicit on-device UAT checklist item (this class of bug is not visible in unit tests, which can't simulate a real OS-level drag session) — flag prominently in that phase's plan, mirroring the project's own precedent of on-device-only checklists for OS-level interaction bugs (e.g. `02-HUMAN-UAT.md`, Phase 16's Bluetooth checklist).

---

### Pitfall 3: Auto-expand-on-drag false positives from a hot-zone sized/timed for clicks, not drags

**What goes wrong:**
The existing click hot-zone is the collapsed pill padded by only 6pt (`hotZonePadding`) — appropriate for a precise click, but too tight for a drag, where the visible drag-ghost cursor is offset from the actual drop point and users are imprecise while dragging. Reusing the click hot-zone as-is for drag detection causes frustrating false negatives (dragging visibly "at" the notch doesn't trigger expand). Conversely, naively widening the interactive region for *all* pointer/click purposes (not just drag) to fix this reintroduces false positives — e.g. a file dragged across the menu bar near, but not over, the notch (well within the wider menu-bar strip) would wrongly auto-expand the island.

**Why it happens:**
"Just make the hot-zone bigger" is the easy fix and works for the demo case (dragging straight at the notch) but breaks the "must not react to a drag that merely passes near the notch" requirement implied by the milestone question, because click precision and drag precision are different UX problems solved by the same one constant today.

**How to avoid:**
Use a **separate, slightly larger padding constant** for drag hit-testing than for click hit-testing (e.g. a `dragHotZonePadding` distinct from `hotZonePadding`), tuned on-device, not reused. Keep the click hot-zone untouched. Gate the auto-expand also on a short dwell (e.g. re-use the pattern of `handleHoverEnter`'s existing debounce feel) so a fast pass-through drag near the notch (menu bar traversal) doesn't trigger a flash-expand — only a drag that lingers in the zone for a beat should promote to expanded.

**Warning signs:**
On-device testing: drag a file in a straight line across the menu bar, passing near but not directly over the pill — island should NOT expand. Drag a file slowly toward the pill and stop over it — island SHOULD expand within a beat.

**Phase to address:**
Pure-seam/model phase (the padding/dwell constants and the hit-test function are pure and testable); view-wiring phase supplies the live dwell timer, mirroring `graceWorkItem`'s existing DispatchWorkItem idiom.

---

### Pitfall 4: Treating the shelf as another `IslandResolver`/`TransientQueue` case

**What goes wrong:**
`IslandResolver` is a deliberately narrow, rank-ordered arbiter (`Charging > Device > NowPlaying`) for **transient, mutually-exclusive** activities that take over the whole island. The milestone explicitly wants the shelf to be "appended below whatever else is showing expanded... whenever it has content" — i.e., an orthogonal overlay, not a competing case. Adding `.shelf(...)` as a new `IslandPresentation` case (or a new `ActiveTransient` case in `TransientQueue`) would be a natural-looking but wrong move: it would make the shelf mutually exclusive with Now Playing/expandedIdle instead of layered on top of them, and it would let a shelf item get silently evicted by `TransientQueue`'s `maxDepth = 2` bound/de-dup logic, which was built for flapping Bluetooth/charging events, not user-authored shelf content.

**Why it happens:**
`IslandResolver`/`TransientQueue` is the one existing "priority arbiter" in the codebase, so it's the obvious place to bolt on "one more thing that shows in the expanded island" — especially for a first-time-programmer codebase where "there's already a resolver, just add a case" looks like the DRY choice.

**How to avoid:**
Follow the project's own already-established precedent for exactly this shape of problem: the Phase 18 song-change toast is a **separate `@Published` field** (`nowPlayingState.songChangeToast`) composed *alongside* `resolve(...)`'s output, deliberately NOT threaded through `IslandResolver` (see `IslandResolver.swift:74-89`, `songChangeToastGate`). Model the shelf the same way: an independent `@Published var shelfItems: [ShelfItem]` observed directly by the expanded view, rendered as an additional strip whenever `!shelfItems.isEmpty && isExpanded`, entirely orthogonal to `IslandPresentation`. A pure `shelfVisibilityGate`-style helper (mirroring `songChangeToastGate`) can express any suppression rules (e.g., hide the shelf strip while a Charging/Device transient owns the island, matching D-04's "transient wins even over expanded") without touching `resolve(...)`'s switch statement.

**Warning signs:**
Any PR that adds a case to `IslandPresentation` or `ActiveTransient` for the shelf; any code path where dropping a 3rd file while 2 are "pending" in some queue silently drops the 3rd (that's `TransientQueue.maxDepth` leaking into a feature it was never designed for).

**Phase to address:**
Pure-seam/model phase — get the composition shape right before any view code exists, since retrofitting "orthogonal overlay" after building it as a resolver case is a structural rewrite, not a tweak.

---

### Pitfall 5: Holding dropped file references without sandboxing safety nets — stale, moved, or deleted URLs

**What goes wrong:**
A sandboxed app gets security-scoped bookmarks and (for many source apps) an automatic temporary local copy + cleanup "for free" from `NSItemProvider`'s in-place file APIs. This app is deliberately **not sandboxed** (existing MediaRemote-bridge constraint) — so there's no sandbox extension to keep a bookmark alive, but there's also no sandbox *forcing* awkward bookmark bookkeeping. The risk is the opposite direction: it's easy to just store a plain `URL` from the drop and assume it stays valid indefinitely in an in-memory, session-only array. Between drop and later drag-out (or Finder-icon repaint), the user can rename, move, or delete the source file (or eject the volume it lived on), leaving a dangling `URL` that crashes or silently no-ops when re-read.

**Why it happens:**
"Just no sandbox, so no bookmark ceremony" is correct but gets read as "so just keep the URL, nothing else to worry about" — the actual remaining risk (file moved/deleted after drop, while the reference is held in memory) is not a sandboxing problem and is easy to overlook precisely because sandboxing is the thing everyone associates with drag-and-drop file-permission bugs.

**How to avoid:**
- Treat every dropped item as `URL` + a **cached, generated-once thumbnail/icon** (see Pitfall 6) — never re-derive the icon lazily from the URL at render time, since the file may be gone by then.
- Before any drag-OUT of a shelf item, call `FileManager.default.fileExists(atPath:)` (or attempt `NSItemProvider(contentsOf:)` and catch failure) and gracefully drop the item from the shelf with a discreet removal if the source vanished, rather than propagating a crash or a broken drag.
- Prefer `loadItem(forTypeIdentifier: UTType.fileURL.identifier)` / `loadObject(ofClass: URL.self)` over `loadInPlaceFileRepresentation` where possible for files from apps that hand back a stable in-place URL (e.g. Finder); for sources that only offer a temporary in-place copy (some browsers/Mail), the temp file is deleted "immediately after the completion block returns" per Apple's docs — so the shelf must copy or retain a reference to that URL's *contents* (or reject browser-drag support) rather than hold the transient in-place URL past the block, or the shelf icon will point at a file that's already gone by the time the user tries to drag it back out.

**Warning signs:**
Drop a file, delete/rename it in Finder, then try to drag the shelf's icon back out — app crashes or produces a broken/empty drag instead of silently pruning the stale entry.

**Phase to address:**
Pure-seam/model phase defines the `ShelfItem` shape (URL + cached icon, no lazy re-derivation); view-wiring phase adds the `fileExists` guard at drag-out time and the graceful-prune UX.

---

### Pitfall 6: Unbounded shelf capacity + naive `NSItemProvider` loading balloons memory

**What goes wrong:**
The milestone deliberately wants unbounded capacity with horizontal scroll. If each dropped item's SwiftUI cell calls something like `Image(nsImage: NSImage(contentsOf: url)!)` directly in the view body, or the drop handler eagerly calls `loadDataRepresentation`/`loadObject` to pull the **full file bytes** into memory just to make a thumbnail, then a shelf holding a few dozen video files or RAW photos can retain hundreds of MB to GBs of live `Data`/`NSImage` full-resolution bitmaps for items that are mostly scrolled off-screen. SwiftUI re-invoking the view body on every state change (e.g. any resolver re-render, since the shelf sits inside the same view tree the priority-resolver churns) would repeat this expensive load and could visibly stutter or spike CPU/memory each render.

**Why it happens:**
The most obvious drop-handling code path (`loadDataRepresentation(forTypeIdentifier:) { data, error in ... }` → `NSImage(data: data)`) is exactly what most `.onDrop` tutorials show, because most demo apps only handle one or two items and never think about "unbounded, in-memory, re-rendered constantly."

**How to avoid:**
Generate a small, fixed-size icon/thumbnail **exactly once per drop** (`NSWorkspace.shared.icon(forFile:)` is cheap and doesn't require reading the file's data into your process at all — it's the simplest correct choice here, no QLThumbnailGenerator complexity needed for icons rather than true previews) and store only that small `NSImage` + the `URL` in the `ShelfItem` model — never store raw `Data`. Confirm SwiftUI doesn't re-run the icon generation on every render by keeping it as stored model state (set once at drop time), not computed in the view body.

**Warning signs:**
Memory ballooning when dropping several large files; visible frame-drop/re-render lag when an unrelated activity (charging splash, song-change toast) causes a resolver re-render while the shelf has many items.

**Phase to address:**
Pure-seam/model phase — the `ShelfItem` model's shape (icon generated once at construction, not derived in the view) is the load-bearing decision; flag as a code-review checklist item in the view-wiring phase.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|------------------|
| Skip the `.leftMouseDragged`/drag-pasteboard detection and just widen the click hot-zone permanently | Much less new code | Menu-bar false positives near the notch on every ordinary click too, not just drags | Never — the two hit-tests must stay independent |
| Use `loadInPlaceFileRepresentation`'s temp URL directly as the long-lived `ShelfItem.url` | Simplest possible drop handler | Silently dangling URL once the temp file is cleaned up by the system after the completion block returns | Never for shelf items meant to persist beyond the drop callback; fine only for one-shot, synchronous-use cases |
| Store raw file `Data` per shelf item for thumbnailing | Slightly simpler code than caching an `NSImage` | Unbounded memory growth exactly matching the deliberately-unbounded capacity requirement | Never — this is the one place "unbounded" and "naive" combine into a real bug |
| Add the shelf as a new `IslandResolver`/`TransientQueue` case | Reuses existing priority machinery | Shelf becomes mutually exclusive with Now Playing/idle instead of layered; shelf items can be silently evicted by `maxDepth` | Never |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|-------------------|
| `NSPanel.ignoresMouseEvents` + drag destination | Assuming `registerForDraggedTypes`/`.onDrop` "just works" once wired, regardless of the panel's click-through state | Flip `ignoresMouseEvents = false` (via the existing `syncClickThrough()` single-writer) the instant a drag enters the zone, using an independent drag-session detector, before relying on `draggingEntered` |
| SwiftUI `.onDrop` + existing hover/click gesture (`onTapGesture` on the pill) | Layering `.onDrop` directly on the same view that owns `onTapGesture`/hover styling without checking which gesture "wins" the hit-test | Test on-device that a drag-hover doesn't also fire a spurious click/haptic, and that clicking still works once a shelf item is present in the expanded view |
| `NSItemProvider` completion handlers | Mutating `@Published`/`ObservableObject` shelf state directly inside the (background-thread) completion block | Hop to `DispatchQueue.main.async` (or `@MainActor`) before touching `shelfItems`, mirroring the project's existing main-thread-hop discipline used for `NowPlayingMonitor`/`BluetoothMonitor` callbacks |
| Drag-out to Finder | Reaching for `NSFilePromiseProvider` (built for *generating new files on demand*) to re-expose an already-existing file | Use a plain `NSItemProvider(object: url as NSURL)` / `.onDrag` with the file's own URL — Finder already knows how to move/copy an existing file reference; `NSFilePromiseProvider` is unnecessary complexity for this use case |
| Global drag-session monitor | Assuming the monitor definitely fires without checking Accessibility permission state | Add the same DEBUG-only "first fire" probe log the codebase already uses for the `.mouseMoved` monitor (`didLogFirstHover`), so a silently-ungranted permission is diagnosable on-device rather than looking like "drag detection doesn't work" |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| Full-resolution `NSImage`/raw `Data` retained per shelf item | Memory climbs with each drop, doesn't shrink until items are removed | Generate a small fixed-size icon once via `NSWorkspace.shared.icon(forFile:)`, discard raw data immediately | Noticeable after roughly a dozen large (video/RAW) files; unbounded requirement makes this inevitable without the fix |
| Re-deriving the icon/thumbnail inside the SwiftUI view body | Stutter on every unrelated resolver re-render (charging splash, song toast) once the shelf has several items | Store the icon as model state set once at drop time, never computed in `body` | As soon as the shelf has more than a handful of items and any other activity fires while it's visible |
| Horizontal `ScrollView` rendering every item eagerly with no lazy container | Layout cost grows linearly with shelf size even for off-screen items | Use `LazyHStack` inside the horizontal `ScrollView`, not a plain `HStack` | Becomes visible once the shelf holds enough items to overflow the visible strip several times over (the "unbounded, scrolls" requirement guarantees this eventually) |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Reading beyond the exact dropped URL (e.g., walking the parent directory to build a "recent files" list) | Un-sandboxed apps performing programmatic access to protected folders (Desktop/Documents/Downloads) can still trigger unexpected TCC prompts on modern macOS, unlike the implicit grant a user's own physical drag/drop already carries | Only ever touch the exact URL(s) the user dragged in; never proactively enumerate sibling files or parent directories |
| Accepting non-file drag payloads (plain text, an image copied from Preview, a Safari link) as if they were file URLs | Force-unwrapping/force-casting an `NSItemProvider`'s payload to `URL` when the source never provided `public.file-url` crashes or silently corrupts the shelf | Explicitly filter with `hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)` before accepting a drop; ignore (or clearly reject) drags that aren't backed by a real file |
| Dropping the same file twice (or dragging a shelf item onto itself) | Duplicate entries in an "unbounded" list that the user then can't tell apart, one becomes stale after the other is deleted from Finder | De-dup on drop by resolved `URL` (or a stable identity), not by array append order |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-------------------|
| Auto-expand fires on any drag that merely passes near the notch (menu bar traversal) | Feels twitchy/broken, undermines the "polished, Alcove-quality" bar this project holds itself to | Separate, slightly larger drag-only hot-zone + a short dwell before promoting to expanded (Pitfall 3) |
| Island freezes expanded after a drag-out because `.mouseMoved` never resumes tracking mid-drag (Pitfall 2) | Looks like a genuine bug — an "always-on" island that won't collapse | Track pointer position via `.leftMouseDragged`/`.leftMouseUp` during any active drag, not just `.mouseMoved` |
| Collapsed pill gives no hint the shelf has content | User forgets files are staged in the shelf, "loses" a file they dropped earlier in the session | Small persistent indicator (dot/badge) on the collapsed pill when `!shelfItems.isEmpty`, consistent with the existing collapsed-glance conventions (equalizer wings, etc.) |
| Per-file delete icon and "delete all" icon both hit-testable inside a horizontally scrolling strip | Users may accidentally trigger "delete all" while trying to scroll past it, or accidentally delete a file while trying to drag it | Keep the destructive "delete all" visually and spatially distinct (far right, requires a deliberate tap) from the per-item drag/delete affordances, mirroring standard shelf-UI conventions (e.g. DynamicLake's DynaClip) |

## "Looks Done But Isn't" Checklist

- [ ] **Auto-expand-on-drag-hover:** Often "works" only in Xcode Previews/simulated drags — verify on a real Mac by dragging an actual Finder file toward the physical notch with the panel's `ignoresMouseEvents` fix in place (Pitfall 1), not just via a SwiftUI `.onDrop` added to the view tree.
- [ ] **Drag files back OUT to Finder:** Often demoed only by dragging within the same app window — verify dropping onto the real Finder/Desktop and onto another unrelated app (e.g. Mail, Preview) produces a normal move/copy, not a broken or empty drag.
- [ ] **Per-file delete + delete-all:** Often missing a check for "shelf becomes empty" — verify the shelf strip actually disappears from the expanded view (not just an empty horizontal scroller with a delete-all button still lingering) once the last file is removed.
- [ ] **Session-temporary, no persistence:** Often accidentally leaks into `UserDefaults`/`@AppStorage` (the project's own established persistence pattern for settings) if a developer reflexively reaches for the same tool used elsewhere in this codebase — verify a full Islet quit/relaunch, not just an app-restart-in-Xcode, actually clears the shelf.
- [ ] **Interaction with the priority resolver:** Often "looks done" if it only shows correctly when nothing else is active — verify the shelf strip's suppression/re-appearance while a Charging or Device transient interrupts the expanded view (Pitfall 4), and after the transient clears.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|-----------------|------------------|
| Shelf modeled as an `IslandResolver`/`TransientQueue` case (Pitfall 4) | MEDIUM | Extract the shelf into its own `@Published` field observed independently by the expanded view, following the Phase 18 toast precedent; delete the added enum case(s) and any `TransientQueue` coupling |
| `ignoresMouseEvents` drag-blocking discovered late (Pitfall 1) | LOW-MEDIUM | Add the second global `.leftMouseDragged` monitor and route its zone hit-test through the existing `syncClickThrough()`; no data-model rework needed since this is purely an AppKit event-wiring gap |
| Stuck-expanded-after-drag-out bug (Pitfall 2) found in UAT | LOW | Add `.leftMouseDragged`/`.leftMouseUp` tracking to `handlePointer`'s zone logic; localized fix to `NotchWindowController.swift` |
| Memory bloat from raw `Data` thumbnails (Pitfall 6) found late | MEDIUM | Swap the icon-generation call site to `NSWorkspace.shared.icon(forFile:)` and drop any retained `Data`; requires touching every place `ShelfItem` was constructed, but no architectural change |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|--------------------|----------------|
| `ignoresMouseEvents` blocks drag delivery entirely (1) | Pure-seam/model phase defines drag hit-test; view-wiring phase wires the global `.leftMouseDragged` monitor + `syncClickThrough()` extension | On-device: drag a real Finder file onto the physical notch and confirm `draggingEntered`/`.onDrop` actually fires |
| `.mouseMoved` freezes mid-drag, island stuck open (2) | View-wiring/gesture-integration phase | On-device: drag a shelf file out to Finder, drop it, move the mouse away without further clicks — island must collapse normally |
| Drag hot-zone false positives/negatives (3) | Pure-seam/model phase (constants + hit-test), tuned in view-wiring phase | On-device: drag across the menu bar near-but-not-over the notch (no expand) vs. directly at it (expands within a beat) |
| Shelf modeled as a resolver/queue case (4) | Pure-seam/model phase | Code review: `IslandPresentation`/`ActiveTransient`/`TransientQueue` unchanged by the shelf feature; shelf state is a separate `@Published` field |
| Stale/moved/deleted dropped-file URLs (5) | Pure-seam/model phase (ShelfItem shape); view-wiring phase (fileExists guard at drag-out) | On-device: drop a file, delete it in Finder, then try to drag the shelf icon back out — must prune gracefully, not crash |
| Unbounded capacity + naive full-data loading (6) | Pure-seam/model phase (icon-once-at-drop model shape) | Code review + on-device: drop 10+ large files, confirm memory stays flat and scrolling stays smooth (`LazyHStack`) |

## Sources

- Direct read of `Islet/Notch/NotchWindowController.swift` (hover/click/`ignoresMouseEvents`/hot-zone architecture) and `Islet/Notch/IslandResolver.swift` (`IslandResolver`, `TransientQueue`, song-change-toast precedent) — HIGH confidence, primary source.
- Apple Developer Documentation — [`NSWindow.ignoresMouseEvents`](https://developer.apple.com/documentation/appkit/nswindow/1419354-ignoresmouseevents) — HIGH confidence (official docs confirm "transparent to all mouse events").
- Apple Developer Documentation — [`NSItemProvider.loadInPlaceFileRepresentation`](https://developer.apple.com/documentation/foundation/nsitemprovider/2888335-loadinplacefilerepresentation) and community summary at [humancode.us "All about Item Providers"](https://humancode.us/2023/07/08/all-about-nsitemprovider) — MEDIUM-HIGH confidence (temp-file lifetime tied to the completion block).
- [Buckleyisms — "How to Actually Implement File Dragging From Your App on Mac"](https://buckleyisms.com/blog/how-to-actually-implement-file-dragging-from-your-app-on-mac/) — MEDIUM confidence, corroborates `NSFilePromiseProvider` vs. plain `NSItemProvider`/`.onDrag` distinction for existing-file drag-out.
- [DeepWiki — TheBoredTeam/boring.notch Shelf System](https://deepwiki.com/TheBoredTeam/boring.notch/3.6-shelf-system) — MEDIUM confidence (third-party summary of a comparable shipped notch-shelf feature; confirms accessibility-API/system-wide drag detection and security-scoped-bookmark handling as the real-world precedent for this exact feature).
- Community write-ups on `.leftMouseDragged` + drag-pasteboard change-count detection (e.g. [Medium — "Adding Drag-and-Drop Indicator in Your macOS App"](https://medium.com/@clyapp/adding-drag-and-drop-indicator-in-your-macos-app-33dc48c66216)) — MEDIUM confidence, single-source technique corroborated by TheBoringNotch's shipped precedent.
- [SwiftUI Lab — "Drag & Drop with SwiftUI"](https://swiftui-lab.com/drag-drop-with-swiftui/) and [Apple — `onDrop(of:isTargeted:perform:)`](https://developer.apple.com/documentation/swiftui/view/ondrop(of:istargeted:perform:)-7u51) — MEDIUM confidence, general `.onDrop`/`NSItemProvider`/`Transferable` API landscape and known "no visibility into a drag session unless you're the drop target" limitation.

---
*Pitfalls research for: drag-and-drop file shelf on a non-activating, click-through notch overlay panel (Islet v1.3)*
*Researched: 2026-07-09*
