# Phase 21: Drag-Out - Research

**Researched:** 2026-07-10
**Domain:** AppKit/SwiftUI outbound drag-and-drop (macOS 14+), integrated with a custom non-activating `NSPanel` hover/grace-collapse system
**Confidence:** MEDIUM — the file-payload mechanism is HIGH confidence (multiple corroborating sources + a directly-relevant prior-art codebase read in full); the drag-lifecycle (pin-open/release) mechanism is MEDIUM/LOW confidence because **no prior art solves this exact problem** (see Summary) and the definitive SwiftUI API for it does not exist below macOS 26.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** The shelf item stays in the shelf after a successful drag-out (copy semantics, not move). The shelf never auto-removes items on its own — only manual delete (per-item or delete-all), app restart, or Mac restart remove items (SHELF-08). User can drag the same item out repeatedly, or remove it manually via its own trash icon.
- **D-02:** If a shelf item's local session-copy has vanished when the user starts a drag (ROADMAP Success Criteria #2), the drag is a silent no-op — nothing drops, no crash, no error dialog. The item stays in the shelf, inert, until the user removes it via its own trash icon. Directly mirrors Phase 20's D-04 (missing-file-on-click) for consistency across click and drag.
- **D-03:** Starting a shelf-item drag pins the island open — suppresses the hover-out grace-collapse timer for the duration of the drag gesture (drag-start to drag-end/drag-cancel), so the panel cannot collapse mid-drag and orphan the gesture (the pointer necessarily leaves the panel's hot-zone once dragging toward Finder/another app). Normal hover/grace-collapse logic resumes immediately once the drag ends.
- **D-04:** Use the default system drag preview (the file's own icon, as `NSItemProvider`/`onDrag` renders it out of the box) — matches what Finder shows for the same file, needs no custom rendering. No UI-SPEC hint was flagged for this phase in ROADMAP.md.

### Claude's Discretion

- Exact SwiftUI/AppKit mechanism for initiating the drag (`.onDrag { NSItemProvider(...) }` vs. lower-level `NSDraggingSource`) — not discussed; use the standard SwiftUI-first approach consistent with "no private API."
- How drag-start/drag-end is detected to drive D-03's pin-open/resume — implementation detail for the planner/researcher to resolve against `NotchWindowController`'s existing `pointerInZone`/grace-timer machinery.
- Exact wording/behavior of "drag-cancel" (e.g., ESC during drag, or dropping back inside the shelf itself) for D-03's resume — treat as equivalent to drag-end unless research surfaces a reason not to.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SHELF-06 | User can drag a shelf item back out to Finder or any other app | Standard Stack (`.onDrag` + `NSItemProvider(contentsOf:)`), Code Examples, Common Pitfalls (FileRepresentation bug, drag-lifecycle gap), Architecture Patterns (pin/release integration into `NotchWindowController`) |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

| Directive | Source | How this research honors it |
|-----------|--------|------------------------------|
| SwiftUI first; AppKit only for the window shell/system hooks, kept small | Technology Stack doc | Recommends `.onDrag` (pure SwiftUI) over a custom `NSViewRepresentable`+`NSDraggingSource` for drag initiation — the lower-level AppKit path is documented as a rejected alternative specifically because it adds AppKit surface area for comparatively little payoff |
| First-time-programmer builder skill — avoid unnecessary complexity | Constraints | The safety-net-timer approach for D-03 reuses the codebase's own existing `DispatchWorkItem` idiom (4 prior uses) instead of introducing a new NSDraggingSource state machine |
| Swift 5 language mode (not strict Swift 6 concurrency) at this stage | Technology Stack doc | `.onDrag`'s closure and any `[weak self]` reach-back closures in the recommended pattern follow the exact same style already used throughout `NotchWindowController.swift` — no new `Sendable`/actor-isolation surface introduced |
| No App Store distribution; app is un-sandboxed | Constraints / What NOT to Use | Un-sandboxed means no security-scoped bookmark ceremony is needed to read/drag `item.localURL` — a sandboxed app would need extra entitlement handling this project does not have to deal with |
| No unrequested abstractions / minimal surface changes | Global CLAUDE.md ("Keine Abkürzungen", code-quality section) | Recommends modifying only `ShelfItemView.swift` and `NotchWindowController.swift`; explicitly rejects wrapping `ShelfItem` in a new `Transferable` conformance as unnecessary for this phase |

## Summary

Dragging an **existing file already on disk** out of a SwiftUI view to Finder is a well-trodden, well-documented case — this is NOT the "file promise" problem (generating content lazily at drop time), which is genuinely hard/unsupported in SwiftUI. Because `ShelfItem.localURL` already points to a real file, the simplest correct mechanism is `.onDrag { NSItemProvider(contentsOf: item.localURL) }`, mirroring the exact convenience initializer Apple ships for "drag a file that's already on my disk." This is simpler and safer than SwiftUI's newer `.draggable(_:)`/`Transferable` path, which is documented to have a real bug on macOS 13/14 (`FileRepresentation` silently failing against Finder unless paired with a `ProxyRepresentation` fallback) — sidestepping `Transferable` entirely avoids that bug.

The genuinely hard part of this phase is **not** the file payload — it is D-03 (pin the island open for the duration of the drag, release cleanly after). SwiftUI's `.onDrag` closure fires exactly once, synchronously, at drag-start (a natural "drag began" hook), but **SwiftUI provides no drag-end/drag-cancelled callback on macOS 14 through macOS 25** (the modern replacement, `onDragSessionUpdated(_:)`, requires macOS 26 — confirmed via WebSearch of Apple's own SwiftUI-updates page and WWDC25 session notes, far above this project's macOS 14.0 deployment target). The lower-level, Apple-documented, macOS-14-compatible way to get a **guaranteed** end-of-drag callback is `NSDraggingSource.draggingSession(_:endedAt:operation:)`, which fires on both successful drop and cancellation — but wiring that requires a small custom `NSView` (via `NSViewRepresentable`), a materially bigger lift than a one-line `.onDrag`.

This project's own referenced prior art (`Lakr233/NotchDrop`, cited by name in this project's own tech-stack doc as the shelf's inspiration) was read in full for this research and **does not solve this problem at all** — its notch window activates the app on open (`NSApp.activate(ignoringOtherApps: true)`) and closes on click-outside, a fundamentally different (and simpler) interaction model than this project's non-activating, hover/grace-collapse `NSPanel`. There is no reusable pattern to copy from it for D-03.

**Primary recommendation:** Use `.onDrag { NSItemProvider(contentsOf:) }` for the drag mechanism (satisfies D-04's "default preview" for free, avoids the `Transferable`/`FileRepresentation` bug entirely, and its closure doubles as the drag-start hook). For D-03, do NOT rely on any single "drag ended" signal being 100% reliable pre-macOS 26 — pin the island open the instant `.onDrag` fires, and release the pin via a **bounded self-clearing safety-net timer**, mirroring the exact `DispatchWorkItem` one-shot idiom already used four times in `NotchWindowController.swift` (`dismissWorkItem`, `graceWorkItem`, `mediaDismissWorkItem`, `toastDismissWorkItem`). This guarantees success criterion #3 ("must not get stuck open") by construction, regardless of whether any best-effort early-release signal (e.g. a global `.leftMouseUp` monitor, matching the existing Pattern-1 global-monitor convention) actually fires. Do NOT touch `syncClickThrough()`'s expanded branch to accommodate the drag — the CR-01 precedent shows that is the wrong integration point; the pin only needs to suppress the grace-collapse **transition**, not the click-through hit-test.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Drag payload construction (file URL → `NSItemProvider`) | Browser/Client-equivalent (SwiftUI view layer) | — | `ShelfItemView` already owns rendering the item; constructing the provider from `item.localURL` is a pure, local, synchronous view-layer concern, no controller round-trip needed |
| Missing-file check before drag starts | View layer (pure gate function) | Controller (owns `FileManager` call) | Mirrors Phase 20's `shouldOpenShelfItem(fileExists:)` split exactly: a pure boolean gate + the actual `FileManager.default.fileExists` I/O call kept at the call site, not buried in the view |
| Drag-lifecycle state (isDragging pin flag + safety-net timer) | Controller (`NotchWindowController`) | — | The grace-collapse timer, `pointerInZone`, and all hover/expand state already live exclusively in `NotchWindowController` (single-arbiter convention) — a new drag-pin flag must live alongside them, not in a separate state machine |
| Island open/collapse decision during drag | Controller (`NotchWindowController`) | — | Same single-arbiter reason: `handleHoverExit`'s `graceWorkItem` is the ONE place collapse is decided; the drag pin must gate that decision in place, not introduce a second collapse path |
| Item persistence after drag (stays in shelf) | Data/Storage (`ShelfCoordinator`/`ShelfLogic`) | — | D-01: drag-out never calls `remove`/`clear` — no change to this tier at all this phase |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `SwiftUI.onDrag(_:)` | Ships with macOS 14+ SDK (Xcode 16+) | Marks `ShelfItemView` as an outbound drag source, returns the `NSItemProvider` | The lightest-weight, officially supported SwiftUI hook for "make this view draggable"; its closure fires synchronously at drag-start, doubling as the D-03 pin-open trigger — no extra plumbing needed [CITED: developer.apple.com/documentation/swiftui/view/ondrag(_:), corroborated via WebSearch across swiftui-lab.com and Eclectic Light Co.] |
| `NSItemProvider(contentsOf:)` | Foundation, ships with macOS SDK | Wraps an **existing on-disk file URL** as the drag payload, auto-registering the file's real UTI (not just a URL string) so Finder/other apps treat it as the actual file | This is the convenience initializer Apple ships specifically for "I already have a file on disk, drag it out" — distinct from the harder "file promise" (generate-content-at-drop-time) problem this project does NOT have. [ASSUMED — exact registration behavior recalled from training knowledge, not re-fetched from the Apple doc page directly (WebFetch of the doc page 404'd this session); the simpler sibling `NSItemProvider(object: url as NSURL)` WAS corroborated live via WebSearch this session, so that is the MEDIUM-confidence fallback if `contentsOf:` behaves unexpectedly on-device] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `FileManager.default.fileExists(atPath:)` | Foundation | Just-in-time existence check on `item.localURL` before constructing the drag payload | Called synchronously inside the `.onDrag` closure, mirroring Phase 20's `shouldOpenShelfItem(fileExists:)` gate pattern exactly (see Don't Hand-Roll) |
| `DispatchWorkItem` + `DispatchQueue.main.asyncAfter` | Foundation/Dispatch | The D-03 safety-net auto-release timer for the drag pin | Matches the codebase's own established one-shot-timer idiom (4 existing uses in `NotchWindowController.swift`) — no new dependency, no polling |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `.onDrag` + `NSItemProvider(contentsOf:)` | `.draggable(_:)` + custom `Transferable`/`FileRepresentation` | `.draggable` is the "modern" SwiftUI API and would be reasonable for greenfield code, but (a) it requires wrapping `ShelfItem` in a custom `Transferable` type (more code than a one-line `NSItemProvider`), and (b) `FileRepresentation`-only conformances are **documented broken against Finder on macOS 13/14** unless a `ProxyRepresentation` fallback is added — an extra gotcha `.onDrag` sidesteps entirely by not touching `Transferable` at all. [MEDIUM confidence — corroborated by two independent sources: nonstrict.eu (with FB13454434 filed against Apple) and swiftwithmajid.com] |
| `.onDrag` for drag initiation | Custom `NSView` + `NSDraggingSource` via `NSViewRepresentable`, called from `mouseDown` | This is the ONLY Apple-documented way to get a **guaranteed** `draggingSession(_:endedAt:operation:)` callback pre-macOS 26 [ASSUMED — training knowledge, WebFetch of the official doc page could not be verified live this session, flagged in Assumptions Log]. Rejected as the PRIMARY mechanism because it must coexist with `ShelfItemView`'s existing `.onTapGesture` (open) and `Button` (delete) — SwiftUI's own gesture-disambiguation between tap and drag (built into `.onDrag`) would have to be hand-rolled again for a custom `mouseDown`-based `NSView`, adding real regression risk to the Finding-15 scoped-gesture precedent for comparatively little payoff, since a bounded safety-net timer already satisfies the actual hard requirement (success criterion #3) without a guaranteed end signal. Worth revisiting only if the safety-net approach proves unacceptable on-device (e.g., pin visibly outlives real drags by an uncomfortable margin). |
| Best-effort global mouseUp monitor for early pin-release | Nothing (rely on safety-net timer alone) | Adding a `.leftMouseUp` case to the EXISTING global `NSEvent.addGlobalMonitorForEvents` monitor (Pattern 1) is cheap and architecturally consistent, but it is **unverified** whether a global monitor reliably observes the mouseUp that ends an active OS-level drag session over another app's window (Finder) — the Drag Manager may route that event through a separate mechanism. Recommended as a best-effort *nice-to-have* layered on top of the safety-net timer, never as the sole release mechanism. |

**Installation:** No new dependencies — `SwiftUI`, `AppKit`, and `Foundation` are already linked.

**Version verification:** `.onDrag`, `NSItemProvider(contentsOf:)`, and `NSDraggingSource` are all long-stable AppKit/SwiftUI APIs shipping since well before macOS 14 — no package registry version to check (first-party framework APIs, not SPM/CocoaPods packages).

## Package Legitimacy Audit

Not applicable — this phase introduces zero new external packages (no SPM/CocoaPods/npm dependencies). All APIs used (`SwiftUI`, `AppKit`, `Foundation`) are first-party Apple frameworks already linked into the `Islet` target.

## Architecture Patterns

### System Architecture Diagram

```
User hovers/clicks shelf item
        │
        ▼
ShelfItemView (drag source, unchanged siblings: .onTapGesture "open", Button "delete")
        │  .onDrag { closure fires synchronously at drag-start }
        ▼
   fileExists check (FileManager, mirrors shouldOpenShelfItem gate)
        │
   ┌────┴─────┐
   │           │
 exists     missing
   │           │
   ▼           ▼
NSItemProvider   NSItemProvider() (empty — D-02 no-op drag,
(contentsOf:      nothing to drop, no crash)
 item.localURL)
   │
   ▼
NotchWindowController.beginShelfItemDrag()
   │  sets isDraggingShelfItem = true
   │  cancels/does NOT schedule grace-collapse
   │  arms a bounded safety-net DispatchWorkItem
   ▼
AppKit Drag Manager takes over (system-level, outside app control)
   │  pointer leaves expandedZone → handleHoverExit() still fires
   │  normally (pointerInZone tracking unaffected) but the grace
   │  work item's closure checks isDraggingShelfItem and skips
   │  collapsing while true
   ▼
User drops on Finder (or cancels / drops back on shelf)
   │
   ▼
NotchWindowController.endShelfItemDrag()  ← best-effort early signal
   (OR the safety-net timer fires as the guaranteed fallback)
   │  sets isDraggingShelfItem = false
   │  re-runs the normal hover-exit-grace-scheduling logic if the
   │  pointer is still outside the zone (mirrors D-13's
   │  pendingLockoutHide "reapply at next natural transition")
   ▼
Island resumes normal hover/grace-collapse behavior (success criterion #3)
```

### Recommended Project Structure
No new files needed — this phase modifies existing files only:
```
Islet/
├── Notch/
│   ├── ShelfItemView.swift        # add .onDrag alongside existing onTapGesture/Button
│   └── NotchWindowController.swift # add isDraggingShelfItem flag + pin/release logic
└── Shelf/
    └── ShelfViewState.swift        # add a pure gate fn mirroring shouldOpenShelfItem
```

### Pattern 1: Missing-file gate mirrors Phase 20's precedent exactly
**What:** A pure, testable boolean function decides whether a drag/open should proceed, called by the controller/view with a freshly-checked `fileExists` boolean — never re-implementing the check inline.
**When to use:** Any place a shelf item's `localURL` is about to be handed to the OS (open, drag).
**Example:**
```swift
// Islet/Shelf/ShelfViewState.swift — existing SHELF-04 precedent, Phase 20:
func shouldOpenShelfItem(fileExists: Bool) -> Bool { fileExists }

// Phase 21 addition, same shape, same file:
func shouldBeginShelfItemDrag(fileExists: Bool) -> Bool { fileExists }
```
```swift
// Islet/Notch/ShelfItemView.swift — call site
.onDrag {
    let exists = FileManager.default.fileExists(atPath: item.localURL.path)
    guard shouldBeginShelfItemDrag(fileExists: exists) else {
        return NSItemProvider()   // D-02: empty provider, no representations to fulfill
    }
    onDragStarted()   // NEW closure param — see Pattern 2, drives the controller pin
    return NSItemProvider(contentsOf: item.localURL) ?? NSItemProvider()
}
```

### Pattern 2: Drag pin/release mirrors the existing `pendingLockoutHide` deferred-reapply idiom (D-13)
**What:** `NotchWindowController` already has exactly this shape of problem solved once before — Phase 10's `pendingLockoutHide` defers a hide decision while the user is mid-interaction, then re-applies it "at the next natural transition." D-03 is the same pattern in reverse: defer a *collapse* decision while a drag is in flight, then re-apply it once the drag ends.
**When to use:** Wiring `isDraggingShelfItem` into `handleHoverExit`'s `graceWorkItem`.
**Example:**
```swift
// New stored property, alongside pointerInZone/graceWorkItem:
private var isDraggingShelfItem = false
private var dragPinSafetyNetWorkItem: DispatchWorkItem?
private let dragPinSafetyNetDuration: TimeInterval = 20.0  // generous ceiling for any real drag gesture

// Called from ShelfItemView's onDragStarted closure (reach-back, mirrors onShelfItemTap wiring):
private func beginShelfItemDrag() {
    isDraggingShelfItem = true
    graceWorkItem?.cancel()   // a pending collapse from an earlier hover-exit must not fire mid-drag
    graceWorkItem = nil
    dragPinSafetyNetWorkItem?.cancel()
    let safetyNet = DispatchWorkItem { [weak self] in self?.endShelfItemDrag() }
    dragPinSafetyNetWorkItem = safetyNet
    DispatchQueue.main.asyncAfter(deadline: .now() + dragPinSafetyNetDuration, execute: safetyNet)
}

// Called on a best-effort early-release signal AND as the safety-net's own fallback body:
private func endShelfItemDrag() {
    guard isDraggingShelfItem else { return }   // idempotent — safety-net + early signal may both fire
    isDraggingShelfItem = false
    dragPinSafetyNetWorkItem?.cancel()
    dragPinSafetyNetWorkItem = nil
    // D-13-style reapply: if the pointer is already back outside the zone, the drag-end
    // is itself the "natural transition" — re-run the exact grace-scheduling handleHoverExit
    // already does, so the island still eventually collapses like any ordinary hover-exit.
    if !pointerInZone {
        handleHoverExit()
    }
}

// Inside handleHoverExit's existing graceWorkItem body, add ONE guard at the top:
let work = DispatchWorkItem { [weak self] in
    guard let self else { return }
    guard !self.isDraggingShelfItem else { return }   // D-03: drag in flight, defer collapse
    // ...unchanged existing collapse logic...
}
```
**Anti-pattern this avoids:** Do NOT add `isDraggingShelfItem` (or anything derived from it) into `syncClickThrough()`'s expanded branch. The CR-01 precedent (project memory `cr01-clickthrough-or-defeat-gotcha`) is specifically about that function's expanded branch needing to stay **pure** `visibleContentZone()` with no OR'd-in conditions — this phase's pin is about the collapse **timer**, not the click-through hit-test, and must not touch that function at all.

### Anti-Patterns to Avoid
- **Polling for drag state:** Do not add a recurring `Timer` to check "is a drag still active" — every existing dismiss/collapse mechanism in this file is a one-shot `DispatchWorkItem` (idle CPU ~0% between events); the safety-net timer must follow the same idiom.
- **A second collapse/visibility code path:** `updateVisibility()` is documented as "the ONE visibility decision and the SOLE show/hide site" — the drag pin must gate the EXISTING `graceWorkItem`/`handleHoverExit` path, never introduce a parallel one.
- **Wrapping `ShelfItem` in a custom `Transferable` "just because it's modern":** adds a `FileRepresentation`+`ProxyRepresentation` dance to work around a real macOS 13/14 bug, for zero benefit over `NSItemProvider(contentsOf:)` in this specific "file already on disk" case.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Representing a local file for outbound drag | A custom `NSPasteboardWriting`/UTI-registration wrapper | `NSItemProvider(contentsOf:)` | Apple's convenience initializer already does correct UTI registration for an on-disk file; hand-rolling risks missing a representation some receiving apps require |
| Default drag preview image | Custom `NSImage` snapshot rendering | The provider AppKit builds automatically from `.onDrag`'s `NSItemProvider` | D-04 explicitly wants the default system look — free with `.onDrag`, extra work with a hand-built preview |
| Missing-file gating | An inline `if FileManager...` scattered at each call site | The single pure `shouldBeginShelfItemDrag(fileExists:)` function (mirrors `shouldOpenShelfItem`) | Keeps the same testable, code-reviewable pattern Phase 20 already established and is verified by `ShelfViewStateTests.swift`'s convention |

**Key insight:** Everything about the FILE PAYLOAD side of this phase is "use the boring, decades-old API for the boring, already-solved case" — the only place genuine engineering judgment is needed is the drag-LIFECYCLE side (D-03), where the codebase's own established deferred-reapply pattern (D-13) is the right tool, not a new abstraction.

## Common Pitfalls

### Pitfall 1: Reaching for `.draggable(_:)`/`Transferable` and hitting the FileRepresentation bug
**What goes wrong:** A shelf item drags fine within the app's own dev testing but silently fails to drop onto Finder (or Slack, or other apps) — nothing happens, no error.
**Why it happens:** `Transferable`'s `FileRepresentation` alone is documented broken against Finder on macOS 13 and 14 (Apple feedback FB13454434) unless paired with a `ProxyRepresentation` fallback that hands over the raw URL.
**How to avoid:** Skip `Transferable` entirely for this phase — use `.onDrag` + `NSItemProvider(contentsOf:)`, which does not go through this code path at all.
**Warning signs:** Drag preview renders and drag "feels" like it's working, but the drop silently produces nothing on the Finder side.

### Pitfall 2: Assuming SwiftUI gives you a drag-end callback
**What goes wrong:** Code is written expecting `.onDrag`'s closure (or some sibling modifier) to fire again when the drag completes, so the pin-release logic never runs, and the island stays pinned open indefinitely — directly violating success criterion #3.
**Why it happens:** iOS/newer-SwiftUI muscle memory from `DropDelegate`'s rich callback set, or confusing `.onDrag` with the macOS-26-only `onDragSessionUpdated(_:)`.
**How to avoid:** Treat "no drag-end signal exists pre-macOS 26" as a hard constraint; design the safety-net timer as the PRIMARY guarantee, not a backstop for a mechanism you haven't actually verified.
**Warning signs:** A `TODO: verify this fires on drop` comment near an assumed drag-end callback; a demo where dragging out of the shelf leaves the panel visibly stuck open past the normal grace delay.

### Pitfall 3: OR-ing drag state into `syncClickThrough()`
**What goes wrong:** Someone "helpfully" adds `|| isDraggingShelfItem` into `syncClickThrough()`'s expanded-branch interactivity check to "keep things interactive during a drag," reintroducing the exact class of bug CR-01 fixed (the reserved-but-invisible shelf band starts swallowing clicks it shouldn't).
**Why it happens:** It looks like the natural place to "keep the panel interactive" during a drag, since it's already the single arbiter of `ignoresMouseEvents`.
**How to avoid:** D-03's pin is about the **grace-collapse timer**, not click-through. `ignoresMouseEvents` should keep behaving exactly as it does today, uninfluenced by drag state — the pointer being far from the panel (over Finder) SHOULD correctly compute as non-interactive; that's fine, because the drag itself is already tracked by the OS, not by this panel's own hit-testing.
**Warning signs:** Any diff that touches `syncClickThrough()` at all in this phase — that function should have ZERO changes; grep for "isDraggingShelfItem" appearing anywhere near `visibleContentZone()`/`syncClickThrough()` should be empty.

### Pitfall 4: `NSItemProvider()` empty-provider behavior for the missing-file no-op is unverified
**What goes wrong:** Returning an empty `NSItemProvider()` (no registered representations) from `.onDrag` for D-02's no-op case might still show a brief phantom drag-ghost image before evaporating on release, or (less likely but unverified) might behave unexpectedly on some macOS version.
**Why it happens:** This specific "return an empty provider to suppress a drag" pattern is not extensively documented; most `.onDrag` examples assume a always-successful payload.
**How to avoid:** Verify on-device early in execution (cheap, ~1 minute manual check): delete a shelf item's backing temp file out from under the app, then attempt to drag it — confirm no crash and nothing lands on Finder, regardless of whether a faint ghost image briefly appears.
**Warning signs:** N/A until on-device verification — flag as an execution-time checkpoint, not a planning blocker.

## Runtime State Inventory

Not applicable — this is a greenfield additive phase (new drag capability), not a rename/refactor/migration. No stored data, service config, OS-registered state, secrets, or build artifacts are touched.

## Code Examples

### Full `ShelfItemView.swift` drag wiring (illustrative — planner should verify exact diff against current file)
```swift
// Source: synthesized from Apple's NSItemProvider(contentsOf:) convenience initializer
// and the existing Finding-15 scoped-gesture precedent already in this file.
struct ShelfItemView: View {
    let item: ShelfItem
    let onTap: () -> Void
    let onDelete: () -> Void
    let onDragStarted: () -> Void   // NEW — reach-back to NotchWindowController.beginShelfItemDrag()

    var body: some View {
        VStack(spacing: 2) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.localURL.path))
                .resizable()
                .frame(width: 28, height: 28)
            Text(item.filename)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 44)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onDrag {
            let exists = FileManager.default.fileExists(atPath: item.localURL.path)
            guard shouldBeginShelfItemDrag(fileExists: exists) else {
                return NSItemProvider()   // D-02 silent no-op
            }
            onDragStarted()
            return NSItemProvider(contentsOf: item.localURL) ?? NSItemProvider()
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(item.filename)")
        }
        .accessibilityLabel("Open \(item.filename)")
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `.onDrag` + `NSItemProvider` (this phase's recommendation) | `.draggable(_:)` + `Transferable` | macOS 13 (WWDC22) introduced `Transferable`; not a full replacement — `.onDrag` remains fully supported and is the better fit for existing-file-on-disk drags | `.draggable` is Apple's forward direction long-term, but for this project's specific case (existing file, macOS 14 floor, avoid the documented FileRepresentation bug) `.onDrag` is currently the more correct choice, not a legacy fallback |
| No drag-lifecycle callback in SwiftUI | `onDragSessionUpdated(_:)` gives explicit `.active`/`.ended(operation)`/`dataTransferCompleted` phases | macOS 26 / WWDC25 | Directly solves D-03's exact problem — but requires macOS 26, far above this project's macOS 14.0 deployment target, so unusable for v1 |

**Deprecated/outdated:** Nothing in this phase's recommended stack is deprecated; `NSItemProvider` and `.onDrag` remain fully current and supported on macOS 14–26.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `NSItemProvider(contentsOf:)` auto-registers the file's real UTI (not just `public.file-url`) so more receiving apps accept it, beyond just Finder | Standard Stack / Core | If wrong, falls back to `NSItemProvider(object: url as NSURL)` (the MEDIUM-confidence, WebSearch-corroborated sibling) — low risk, one-line swap, both were designed for exactly this use case |
| A2 | `NSDraggingSource.draggingSession(_:endedAt:operation:)` is guaranteed called on both successful drop AND cancellation | Alternatives Considered | Only matters if the safety-net-timer approach is later rejected in favor of the NSDraggingSource path; if this guarantee is weaker than assumed, that path would need its OWN safety-net anyway, so risk is low regardless |
| A3 | Drag sessions can originate and complete successfully from a `.nonactivatingPanel`/`.statusBar`-level, `canBecomeKey == false` window without requiring window activation | Common Pitfalls (implied), Open Questions | **HIGH risk if wrong** — this is the foundational assumption the entire phase rests on; SHELF-06 would need a materially different window architecture if drag sessions require activation. Recommend an early, cheap on-device spike (drag any shelf item onto the Desktop, confirm the file lands) before building out the full pin/release machinery, mirroring the project's own established convention for this class of risk (see STATE.md's Phase 22 spike precedent) |
| A4 | A global `NSEvent` monitor (matching this project's existing Pattern 1 `.mouseMoved` convention) reliably observes the `.leftMouseUp` that ends an active OS drag session over another app's window (Finder) | Alternatives Considered | Low risk — this is explicitly recommended only as a best-effort *early-release* nicety layered on top of the safety-net timer, never as the sole release mechanism; if it never fires, the safety-net timer alone still satisfies success criterion #3 |
| A5 | Returning an empty `NSItemProvider()` from `.onDrag` produces a clean no-op drop (D-02) rather than a crash or unexpected visual artifact | Common Pitfalls (Pitfall 4) | Low-medium risk — flagged as a cheap on-device verification item, not a planning blocker; worst case is a cosmetic issue (a phantom drag ghost), not a crash |

## Open Questions

1. **Does a drag session survive `ignoresMouseEvents` flipping to `true` on the source panel mid-drag?**
   - What we know: Once `handleHoverExit()` fires (pointer left `expandedZone` heading toward Finder), `syncClickThrough()` will compute the panel as non-interactive and set `ignoresMouseEvents = true`, exactly as it does today for any ordinary hover-exit.
   - What's unclear: Whether the OS-level Drag Manager, which already took over tracking the in-flight drag, is unaffected by the SOURCE window subsequently becoming non-interactive to NEW mouse events (my expectation, based on how drag sessions are generally decoupled from window hit-testing once started, but unverified against this project's specific panel setup).
   - Recommendation: Fold this into the same on-device spike as A3 — drag a shelf item slowly toward the Desktop and confirm the drag preview/ghost continues to track the pointer and the drop still succeeds even after the panel visually would have "lost" interactivity.

2. **Exact visual behavior of the "empty provider" no-op drag (D-02, Pitfall 4)?**
   - What we know: `.onDrag` requires returning SOME `NSItemProvider`; there is no "cancel the drag before it starts" API in SwiftUI's `.onDrag`.
   - What's unclear: Whether an empty provider suppresses the drag gesture from visually starting at all, or lets a ghost image appear that then evaporates with nothing to drop.
   - Recommendation: Either outcome satisfies D-02's actual requirement ("nothing drops, no crash, no error dialog") — treat this as a nice-to-verify polish item, not a blocker.

## Environment Availability

Not applicable — this phase has no external tool/service/runtime dependencies beyond the Xcode toolchain already verified working in prior phases (see Phase 20's own environment audit; nothing changed since).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing, `IsletTests/` target) |
| Config file | none — see Wave 0 |
| Quick run command | `xcodebuild build-for-testing -scheme Islet -configuration Debug` (compiles the test target — does NOT execute; see project memory `xcodebuild-test-headless-hang`) |
| Full suite command | Manual **Cmd-U in Xcode** — `xcodebuild test` hangs headlessly because tests host the full `Islet.app`, which boots the real `NSPanel`/MediaRemote/IOBluetooth stack. Pre-existing, documented constraint, not new to this phase. |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SHELF-06 (D-02) | `shouldBeginShelfItemDrag(fileExists:)` returns false when file missing, true otherwise | unit | `xcodebuild build-for-testing` then Cmd-U `ShelfViewStateTests` | ❌ Wave 0 (new test case to add to existing `ShelfViewStateTests.swift`) |
| SHELF-06 (D-01) | A successful drag-out never calls `ShelfCoordinator.remove`/`clear` — item still present after drag | unit (behavioral assertion — no coordinator mutation call in the drag path) | Code-review-verifiable (grep for absence of `.remove(`/`.clear(` in the onDrag closure) + Cmd-U regression of existing `ShelfCoordinatorTests` (unchanged, proves no accidental mutation) | ✅ existing |
| SHELF-06 (D-03) | Drag-start suppresses grace-collapse; drag-end (or safety-net) resumes it | manual-only — this is a live hover/timer/pointer-position integration behavior inside `NotchWindowController`, not practically unit-testable without a real `NSEvent`/panel harness (mirrors how the existing hover/grace-collapse system itself has no automated test, per Phase 2/6/9's own precedent) | manual on-device: drag a shelf item slowly, confirm panel stays open throughout, then confirm it returns to normal hover behavior within the grace delay after the drop | N/A (manual) |
| SHELF-06 (Success Criterion #1) | Real file lands on Finder desktop after drag-out | manual-only — requires an actual Finder drop target | manual on-device: drag a shelf item to Desktop, confirm the file appears | N/A (manual) |
| SHELF-06 (Success Criterion #2) | Missing backing file → graceful no-op, no crash | manual-only (see Pitfall 4) | manual on-device: delete the item's temp file externally, attempt drag, confirm no crash/no drop | N/A (manual) |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet -configuration Debug` (build gate only — matches Phase 20's established constraint)
- **Per wave merge:** Manual Cmd-U full suite + the 3 manual on-device checks above (D-03, Criterion #1, Criterion #2)
- **Phase gate:** All 3 manual checks confirmed + Cmd-U green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] Add `testShouldBeginShelfItemDrag` cases to `IsletTests/ShelfViewStateTests.swift` (mirrors the existing `shouldOpenShelfItem` test already in that file's convention)
- [ ] No new test framework/config needed — `IsletTests` target already exists and builds

*(Everything else in this phase — the drag-lifecycle pin/release behavior and both ROADMAP success criteria involving Finder/missing-file — is inherently manual-only, consistent with how this project has already treated its hover/grace-collapse and click-through systems since Phase 2.)*

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | No auth surface in this phase |
| V3 Session Management | No | No session/session-token concept |
| V4 Access Control | No | Single-user local app, no access-control boundary crossed |
| V5 Input Validation | Yes (reused, not new) | `ShelfFileStore`'s existing `filenameComponent != "..".` path-traversal guard (T-19-01) already protects `localURL`'s construction; this phase only ever READS `item.localURL` (never constructs a new path from untrusted input), so no new validation surface is introduced |
| V6 Cryptography | No | No crypto/secrets touched |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| A crafted/mutated `ShelfItem.localURL` pointing outside the shelf's temp sandbox being dragged out, exposing an arbitrary file | Information Disclosure | Not a NEW risk this phase introduces — `localURL` is only ever set by `ShelfFileStore.makeSessionCopy` (already validated, T-19-01) at item-creation time (Phase 19); this phase does not construct or accept any new URL, only reads the existing field. No new mitigation needed, but the planner should NOT add any code path that lets `.onDrag` be handed a URL other than `item.localURL` as-stored. |
| Symlink/TOCTOU between the `fileExists` check and `NSItemProvider(contentsOf:)` reading the file | Tampering | Low-severity/local-only: this is a single-user local session-temp file under `NSTemporaryDirectory()/IsletShelf/<uuid>/`, not a shared/multi-user path; a TOCTOU race here has no privilege-escalation implication in this app's threat model. No new mitigation needed beyond what already exists. |

## Sources

### Primary (HIGH confidence)
- Direct read of `Lakr233/NotchDrop` source (this project's own cited prior art): `TrayDrop+DropItemView.swift`, `TrayDrop+DropItem.swift`, `Ext+FileProvider.swift`, `NotchViewModel.swift`, `NotchViewModel+Events.swift` — confirmed their `.draggable(item)` + `Transferable`/`FileRepresentation` approach, and confirmed their window model (`NSApp.activate` on open) does NOT solve this project's D-03 problem
- Codebase read: `Islet/Notch/NotchWindowController.swift` (full 1315-line file, hover/grace-collapse/click-through machinery), `Islet/Notch/ShelfItemView.swift`, `Islet/Notch/NotchPillView.swift` (shelf row integration), `Islet/Shelf/ShelfItem.swift`, `Islet/Shelf/ShelfCoordinator.swift`, `Islet/Shelf/ShelfFileStore.swift`, `Islet/Shelf/ShelfViewState.swift`, `IsletTests/ShelfViewStateTests.swift`

### Secondary (MEDIUM confidence)
- [Apple SwiftUI updates page + WWDC25 "What's new in SwiftUI" session notes](https://developer.apple.com/documentation/updates/swiftui) — `onDragSessionUpdated(_:)` requires macOS 26.0, confirmed via WebSearch cross-referencing wwdcnotes.com and blakecrosley.com
- [Transferable drag & drop with only a FileRepresentation not working on macOS | Nonstrict](https://nonstrict.eu/blog/2023/transferable-drag-drop-fails-with-only-FileRepresentation/) — the macOS 13/14 `FileRepresentation` bug and `ProxyRepresentation` workaround, with Apple feedback ID FB13454434
- [SwiftUI on macOS: Drag and drop, and more – The Eclectic Light Company](https://eclecticlight.co/2024/05/21/swiftui-on-macos-drag-and-drop-and-more/) — confirms SwiftUI has no file-promise support and the "write to a location, let the receiver move it" limitation
- [Drag & Drop with SwiftUI - The SwiftUI Lab](https://swiftui-lab.com/drag-drop-with-swiftui/) — `.onDrag { NSItemProvider(object: url as NSURL) }` as the documented simplest form for existing local files
- [SwiftUI drag & drop does not support file promises – Wade Tregaskis](https://wadetregaskis.com/swiftui-drag-drop-does-not-support-file-promises/) — confirms `NSFilePromiseProvider` is unsupported in SwiftUI (relevant only if this project ever needed generate-at-drop-time content, which it does not — files already exist on disk)

### Tertiary (LOW confidence)
- Training-knowledge recall of `NSItemProvider(contentsOf:)`'s exact UTI-registration behavior and `NSDraggingSource.draggingSession(_:endedAt:operation:)`'s guaranteed-call semantics — WebFetch of the specific Apple documentation pages returned a 404 / no-content-access this session (see Assumptions Log A1, A2); both are longstanding, stable, well-known AppKit APIs, but were NOT independently re-verified against a live authoritative source in this research session

## Metadata

**Confidence breakdown:**
- Standard stack (file payload mechanism): HIGH — corroborated by prior-art source read + multiple independent WebSearch sources agreeing
- Architecture (drag-lifecycle pin/release): MEDIUM — grounded in the codebase's own established `pendingLockoutHide` pattern (HIGH confidence that pattern exists and works), but the actual drag-end detection reliability is genuinely unverified pre-execution (see Open Questions, Assumptions A3/A4)
- Pitfalls: MEDIUM-HIGH — the FileRepresentation bug and the SwiftUI drag-end-callback gap are both cross-verified findings, not speculation

**Research date:** 2026-07-10
**Valid until:** 30 days (stable first-party Apple APIs; the one fast-moving item, `onDragSessionUpdated`'s macOS 26 requirement, only affects a future milestone if the deployment target is ever raised)
