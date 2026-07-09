# Phase 20: Shelf View - Research

**Researched:** 2026-07-09
**Domain:** SwiftUI rendering of a horizontally-scrolling file strip inside an existing native macOS "Dynamic Island" overlay, wired to an already-shipped pure data model (Phase 19).
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Panel growth strategy
- **D-01:** The expanded island grows TALLER (dynamic height) only when the shelf has items — mirrors Phase 18's toast-row precedent (`mediaWingsOrToast`'s conditional height): one shape, height grows conditionally, never a fixed always-reserved band.
- **D-02:** The shelf row is appended under ALL expanded branches uniformly — `mediaExpanded`, `expandedIdle`, AND `mediaUnavailable` all get the same shelf strip when it has content. No special-casing any one branch.

### Delete-all confirmation
- **D-03:** SHELF-05's single trash icon clears the whole shelf instantly, no confirmation dialog. Consistent with SHELF-08's session-only premise (nothing precious is destroyed — only the shelf's own temp copies go, originals untouched) and the app's lightweight-utility feel.

### Missing-file-on-click
- **D-04:** If a shelf item's local session-copy is gone when clicked (SHELF-07), the click is a silent no-op — no error dialog, no crash, no auto-removal. The item stays in the shelf, inert, until the user removes it via its own trash icon.

### Shelf-area tap behavior
- **D-05:** Tapping empty space within the shelf strip (not on an item or its trash icon) collapses the island, same as every other non-button region of the expanded blob (Finding 15 precedent: only item-click and trash-click get their own scoped gesture; everything else falls through to the shared `onClick`).

### Claude's Discretion
- Exact file-type icon rendering mechanism (e.g. `NSWorkspace.shared.icon(forFile:)`) — not discussed, use the standard system API.
- Visual layout specifics (icon size, spacing, scroll indicator styling, exact height added per shelf row) — this phase has a UI hint; defer pixel-level decisions to the UI design contract (`/gsd:ui-phase 20`) rather than locking them here.
- Whether the shelf row's per-item trash icon uses the same Finding-15 scoped-gesture technique as the delete-all icon — implementation detail, follow the established pattern.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-------------------|
| SHELF-03 | Shelf strip is appended below whatever else is showing expanded (Now Playing, idle glance, etc.) whenever it has content, and scrolls horizontally with unbounded capacity | Pattern 1 (conditional-height blob extension), Pattern 2 (panel pre-reservation), Standard Stack's `ScrollView(.horizontal)`/`HStack`/`ForEach` entry |
| SHELF-04 | Each shelf item shows a file-type icon with its own small trash icon for individual removal | Pattern 3 (scoped trash-button gestures), `NSWorkspace.shared.icon(forFile:)` entry, `ShelfItemView` code example |
| SHELF-05 | A single "delete all" trash icon on the far right clears the entire shelf at once | Code Examples' `shelfRow` composition (far-right delete-all Button), Pitfall 2 (gesture scoping) |
| SHELF-07 | Clicking a shelf item opens it in its default application | `NSWorkspace.shared.open(URL)` entry, Pitfall 4 (missing-file guard for D-04), Validation Architecture's SHELF-07 test row |
| SHELF-09 | Shelf is suppressed while a Charging or Device wings splash is actively showing, reappearing once the splash dismisses | Architecture Diagram + D-05 tier mapping (structural suppression, no new resolver code), Validation Architecture's SHELF-09 test row (extend existing `IslandResolverTests.swift`) |
</phase_requirements>

## Summary

Phase 20 is almost entirely a **view + panel-sizing composition problem**, not a new-technology problem. Every primitive it needs already exists in AppKit/SwiftUI (no new packages) and every architectural precedent it needs already exists in this exact codebase: `mediaWingsOrToast`'s conditional-height blob (Phase 18) is the direct analog for D-01's shelf-row growth, and Finding 15's scoped-gesture discipline (used for the transport buttons) is the direct analog for the per-item/delete-all trash buttons.

The one genuinely new risk this phase introduces — and the one Phase 18's toast did **not** have to solve — is that the shelf row extends the **expanded blob**, which is already the *tallest* shape and therefore the one that defines the panel window's reserved height. Phase 18's toast grew the (shorter) wings shape and simply fit inside the panel space the expanded blob had already reserved; Phase 20's shelf row does not have that luxury. `NotchWindowController.positionAndShow` sizes the actual `NSPanel` from `NotchPillView.expandedSize` (a compile-time constant) **once**, and Pitfall 4 in this codebase explicitly says the panel must never resize live mid-animation. This means the panel must be pre-sized to include a new, permanently-reserved (but visually transparent-when-empty) shelf band — a new static constant, sized and unioned exactly like `expandedSize`/`wingsSize` already are — while the *visible* black `NotchShape` still only grows into that space conditionally (D-01, "never a fixed always-reserved band" refers to the paint, not the window).

`ShelfCoordinator`/`ShelfLogic`/`ShelfItem` (Phase 19) are locked as consume-only — CONTEXT.md's canonical refs explicitly say this phase "does not modify them." Neither type is `ObservableObject`. The established codebase convention (mirroring `nowPlayingState`/`presentationState`/`outfitState`) is a **separate `@Published` state model** the controller keeps in sync after every `ShelfCoordinator` mutation, which the view observes. This is the only architecturally consistent way to wire the shelf into `NotchPillView` without touching Phase 19's files.

**Primary recommendation:** Add one new `ShelfViewState: ObservableObject` (`@Published var items: [ShelfItem] = []`) owned + kept in sync by `NotchWindowController` around its existing `ShelfCoordinator`; extend `NotchPillView.blobShape` with an optional shelf-row slot and a new `shelfRowHeight` static constant that both the shape's conditional `.frame(height:)` *and* the controller's panel-sizing math read from the same single source of truth; render the row with `ScrollView(.horizontal) { HStack { ForEach(items, id: \.id) { ShelfItemView(...) } } }`, each item using `NSWorkspace.shared.icon(forFile:)` for its glyph and a Finding-15-scoped `Button` for its own trash icon, plus one more scoped `Button` for delete-all.

## Architectural Responsibility Map

This is a single-process native macOS app, not a multi-tier web app — the project's own established tiers (visible throughout `NotchPillView.swift`/`NotchWindowController.swift`/`IslandResolver.swift`) are used here instead of Browser/API/DB.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Shelf item persistence/dedupe/ordering | Data/IO (`ShelfLogic`/`ShelfCoordinator`, Phase 19, LOCKED) | — | Already shipped, pure value + IO wrapper; this phase must not modify it (CONTEXT.md canonical refs). |
| Shelf visibility gating vs. Charging/Device | Controller (`NotchWindowController` + `IslandResolver`'s existing switch) | View (`NotchPillView`) | Per D-05 code_context: falls out "for free" because `.charging`/`.device` are resolved *before* the expanded branches ever run — no new resolver logic, only composition choice in the view. |
| Shelf row rendering (icons, scroll, trash buttons) | View (SwiftUI, `NotchPillView`) | — | Pure render of whatever `ShelfViewState` publishes; no IO, no file decisions. |
| Panel/window height reservation for the shelf band | Controller (`NotchWindowController.positionAndShow` + `NotchGeometry`) | View (`NotchPillView.expandedSize`) | The window frame is AppKit's responsibility and must be sized once, up front (Pitfall 4) — the view only supplies the constant. |
| Click-to-open / delete actions | Controller (owns `ShelfCoordinator`, calls `NSWorkspace.shared.open`) | View (reports intent via closures) | Mirrors the existing `onClick`/`onTogglePlayPause` closure contract — the view is AppKit-free by convention. |
| File-type icon lookup | View or thin helper (`NSWorkspace.shared.icon(forFile:)`) | — | Read-only, side-effect-free AppKit call; safe to call directly from the view layer like `Image(nsImage:)` already does for artwork. |

## Standard Stack

### Core
No third-party packages are needed for this phase — everything is built-in AppKit/SwiftUI/Foundation, consistent with CLAUDE.md's "no third-party Bluetooth/power library... the surface you need is tiny" philosophy applied here to file icons/opening too.

| API | Availability | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `NSWorkspace.shared.icon(forFile:)` | macOS 10.6+, still present/undeprecated on macOS 14/15/26 SDKs [ASSUMED — could not confirm current deprecation status via a directly-fetched Apple doc page in this session; the *sibling* method `icon(forFileType:)` (String/HFS-code based) IS deprecated since macOS 12 in favor of `icon(forContentType:)`, but `icon(forFile:)` takes a full path and is a different, still-current method] | Returns an `NSImage` file-type/preview icon for a path | Simplest possible call for exactly this use case; used by the project's own cited reference app NotchDrop (`Lakr233/NotchDrop`, via its `workspacePreviewImage`/`url.snapshotPreview()` wrapper) [CITED: github.com/Lakr233/NotchDrop] |
| `NSWorkspace.shared.open(URL)` | macOS 10.6+ | Opens a file in its default application | Standard, one-line "open in default app" call; used identically by NotchDrop's `DropItemView.onTapGesture` [CITED: github.com/Lakr233/NotchDrop, `NotchDrop/TrayDrop+DropItemView.swift`] |
| `ScrollView(.horizontal) { HStack { ... } }` | SwiftUI (macOS 14 SDK) | Horizontally-scrolling unbounded-capacity strip | Exactly SHELF-03's requirement; no pagination/virtualization needed at this scale (session-only shelf, D-08) — SwiftUI's `HStack` inside `ScrollView` lazily is not required either, `LazyHStack` is available if item counts get large but plain `HStack` matches this project's existing `EqualizerBars`/`mediaExpanded` non-lazy convention |
| `.scrollIndicators(.never)` (or `.hidden`, macOS 14 SDK) | SwiftUI | Hides the horizontal scrollbar for a cleaner glance strip | Used by NotchDrop's own `TrayView` for the identical horizontal item strip [CITED: github.com/Lakr233/NotchDrop, `NotchDrop/TrayDrop+View.swift`] |

**Installation:** none — no new packages, no `project.yml` changes for dependencies.

**Version verification:** N/A — all APIs are OS-provided (macOS 14.0 deployment target per `project.yml`), not versioned packages. No `npm view`/`pip index`/`cargo search` applies.

## Package Legitimacy Audit

**Not applicable.** This phase adds zero third-party packages (Swift Package Manager or otherwise). All new code uses AppKit/SwiftUI/Foundation APIs already linked by the existing target. The Package Legitimacy Gate protocol is skipped per its own scope ("whenever this phase installs external packages").

## Architecture Patterns

### System Architecture Diagram

```
 ShelfCoordinator (Phase 19, LOCKED — data/IO, not modified this phase)
   append/remove/clear → real FileManager delete side effects
         │
         │  (controller keeps a published mirror in sync after
         │   every mutation — new in this phase)
         ▼
 ShelfViewState : ObservableObject          NotchWindowController (AppKit glue)
   @Published items: [ShelfItem]  ◄─────────  owns ShelfCoordinator + ShelfViewState
         │                                    handleShelfItemTap(id) → NSWorkspace.open (guarded by fileExists)
         │  (SwiftUI observes)                handleShelfItemDelete(id) → coordinator.remove(id) → resync
         ▼                                    handleShelfClearAll() → coordinator.clear() → resync
 NotchPillView (SwiftUI, existing switch over IslandPresentation)
   .nowPlayingExpanded / .expandedIdle / .mediaUnavailable
         │
         ▼
 blobShape(..., shelfItems: [ShelfItem]) — EXTENDED this phase
   height = expandedSize.height + (shelfItems.isEmpty ? 0 : shelfRowHeight)   ← D-01
   VStack(spacing: 0) {
     content()                         ← existing branch content, unchanged
     if !shelfItems.isEmpty { shelfRow(shelfItems) }   ← new, appended below
   }
         │
         ▼
 shelfRow: ScrollView(.horizontal) { HStack {
   ForEach(items, id: \.id) { ShelfItemView(item, onTap:, onDelete:) }   ← icon via NSWorkspace, own scoped Button
   deleteAllButton                                                       ← own scoped Button, far right
 } }

 .charging / .device cases  ──── never call blobShape at all ────►  shelf row structurally absent (SHELF-09,
                                                                       "falls out for free", no new gate needed)
```

### Recommended Project Structure

No new folders needed — this phase is additive to two existing files plus one new small view file, mirroring `BatteryIndicator.swift`'s "small reusable leaf view" precedent (explicitly named as the pattern to mirror in CONTEXT.md):

```
Islet/
├── Notch/
│   ├── NotchPillView.swift       # EXTEND: blobShape gets shelf-row slot + new shelfRowHeight constant
│   ├── NotchWindowController.swift  # EXTEND: owns ShelfCoordinator + new ShelfViewState, wires closures
│   └── ShelfItemView.swift       # NEW: one leaf view — icon + filename + own trash button (mirrors BatteryIndicator.swift's role)
├── Shelf/
│   ├── ShelfItem.swift           # Phase 19 — DO NOT MODIFY
│   ├── ShelfLogic.swift          # Phase 19 — DO NOT MODIFY
│   ├── ShelfCoordinator.swift    # Phase 19 — DO NOT MODIFY
│   ├── ShelfFileStore.swift      # Phase 19 — DO NOT MODIFY
│   └── ShelfViewState.swift      # NEW: the @Published mirror the view observes (mirrors NowPlayingState/BasicOutfitState's role)
```

### Pattern 1: Conditional-height blob extension (direct analog of `mediaWingsOrToast`)

**What:** Grow one shared `NotchShape`'s height only when optional content is present, composing it as a `VStack` under the primary content, exactly as Phase 18 did for the song-change toast — but this time the technique needs to be generalized into `blobShape` itself (per CONTEXT.md's Integration Points: "`blobShape` itself grows a shelf-aware height parameter rather than each caller re-deriving it independently") since D-02 requires the SAME behavior across all 3 callers (`mediaExpanded`, `expandedIdle`, `mediaUnavailable`).

**When to use:** Any time optional content must extend the SAME morphing shape without a second shape / cross-fade (D-07 no-cross-fade contract).

**Example:**
```swift
// Source: Islet/Notch/NotchPillView.swift lines 234-244 (blobShape, existing) +
// lines 314-334 (mediaWingsOrToast, existing conditional-height precedent this generalizes)
private func blobShape<Content: View>(topCornerRadius: CGFloat,
                                       bottomCornerRadius: CGFloat,
                                       alignment: Alignment = .center,
                                       shelfItems: [ShelfItem],
                                       @ViewBuilder content: () -> Content) -> some View {
    let hasShelf = !shelfItems.isEmpty
    let height = Self.expandedSize.height + (hasShelf ? Self.shelfRowHeight : 0)
    return NotchShape(topCornerRadius: topCornerRadius,
                       bottomCornerRadius: hasShelf ? 20 : bottomCornerRadius)
        .fill(Color.black)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.expandedSize.width, height: height)
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                // The ORIGINAL content keeps its own alignment inside its own fixed-height box —
                // unchanged visually from today.
                content()
                    .frame(width: Self.expandedSize.width, height: Self.expandedSize.height, alignment: alignment)
                if hasShelf {
                    shelfRow(shelfItems)
                        .transition(.opacity)   // mirrors toastTextRow's fade-in (D-08: no ambient clock, only the ambient spring the caller already runs)
                }
            }
        }
        .onTapGesture { onClick() }
}
```

### Pattern 2: Panel pre-reservation for a new tallest band (NEW risk this phase — Phase 18 did not need this)

**What:** The `NSPanel` window itself must be sized ONCE, up front, to include worst-case shelf height — never resized live (Pitfall 4, already documented in this codebase). Phase 18's toast fit inside the panel space the *expanded* frame already reserved (144pt tall vs. wings+toast's ~64pt) so no window change was needed. Phase 20's shelf extends the *expanded* frame itself — the tallest shape and the one panel sizing is currently based on — so this headroom does not already exist and must be added.

**When to use:** Any time new content can make the ALREADY-tallest branch taller still.

**Example:**
```swift
// Source: Islet/Notch/NotchWindowController.swift lines 225-227 (existing `expandedSize` field) +
// lines 592-599 (existing expandedFrame/wingsFrame union math this must extend)
// NotchPillView.swift: add alongside toastExtraHeight —
static let shelfRowHeight: CGFloat = 56   // seed only; UI-SPEC (this phase's UI hint) tunes the real value

// NotchWindowController.positionAndShow — the panel must reserve the shelf band UNCONDITIONALLY
// (transparent when the shelf is empty), exactly like expandedSize's own 144pt is already an
// unconditional reservation the shorter branches (expandedIdle/mediaUnavailable) don't fully use:
let expandedFrame = expandedNotchFrame(
    collapsed: collapsedFrame,
    expandedSize: CGSize(width: expandedSize.width,
                          height: expandedSize.height + NotchPillView.shelfRowHeight))
```

**Why this is safe with D-01's "never a fixed always-reserved band":** D-01 governs the *visible black shape*, painted by `NotchShape`/`blobShape`'s own conditional `.frame(height:)` — that stays exactly as conditional as the toast precedent. Only the *invisible* window backing store grows unconditionally, which is precisely how `expandedSize`'s existing 144pt already works today for `expandedIdle` (which never fills all 144pt of visible content either).

### Pattern 3: Scoped trash-button gestures (Finding 15 precedent, extended per-item)

**What:** Every tappable region that must NOT trigger the ancestor `onClick` (collapse/expand toggle) gets its OWN `.onTapGesture`/`Button`, scoped to sit OUTSIDE the ancestor gesture's region, never nested under a single shared ancestor `.onTapGesture`. This codebase's Finding 15 (06-10) already established and tested this discipline for the transport buttons; D-05 (this phase) explicitly re-applies the same precedent to shelf-item taps ("only item-click and trash-click get their own scoped gesture; everything else falls through to the shared `onClick`").

**When to use:** Any Button/tap target living inside a view that also has an ancestor `.onTapGesture`.

**Example:**
```swift
// Source: pattern generalized from Islet/Notch/NotchPillView.swift lines 622-632 (transportButton,
// existing) + NotchDrop's DropItemView.swift .overlay { ... .onTapGesture { tvm.delete(item.id) } }
// [CITED: github.com/Lakr233/NotchDrop, TrayDrop+DropItemView.swift] — confirms the same
// "delete icon gets its own onTapGesture in a sibling/overlay region, never nested under the
// item's own open-on-tap gesture" shape independently, in the closest available reference app.
struct ShelfItemView: View {
    let item: ShelfItem
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.localURL.path))
                .resizable()
                .frame(width: 32, height: 32)
            // D-04-adjacent (T-07-xx style bound): filename is untrusted external data (the
            // original file's name), same discipline as calendar title / now-playing metadata.
            Text(item.filename)
                .font(.system(size: 9))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 44)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }             // D-04: click-to-open, its OWN scoped gesture
        .overlay(alignment: .topTrailing) {
            Button(action: onDelete) {         // Finding 15 / D-05: sibling Button, own gesture region
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
    }
}
```

### Anti-Patterns to Avoid

- **One ancestor `.onTapGesture` wrapping the whole shelf row (icons + trash buttons):** This is exactly the Finding-15 trap — SwiftUI's gesture-resolution priority between an ancestor `TapGesture` and descendant `Button`s is not guaranteed, and the CONTEXT.md D-05 decision explicitly calls out this precedent.
- **Introducing a second `NotchShape`/blob for the shelf row:** Violates D-07 (single shared morph, no cross-fade) — the shelf row must be composed INSIDE the same `blobShape` call, not a sibling shape.
- **Resizing the `NSPanel` live when the shelf gains its first item / loses its last item:** Violates this codebase's own documented Pitfall 4 ("resizing mid-activity would race the morph + hot-zone math"). Reserve the panel space unconditionally up front instead (Pattern 2 above).
- **Modifying `ShelfItem`/`ShelfLogic`/`ShelfCoordinator`/`ShelfFileStore`:** Explicitly out of scope — CONTEXT.md's canonical refs lock these as consume-only for this phase.
- **Adding a resolver-level suppression case for Charging/Device:** Unnecessary — SHELF-09 gating already falls out structurally because `.charging`/`.device` never reach the `blobShape`-calling branches (see D-05 code_context and the Architecture Diagram above).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| File-type icon rendering | A custom UTType→SF-Symbol mapping table | `NSWorkspace.shared.icon(forFile:)` | One AppKit call returns the exact icon Finder itself uses for that file, including custom app icons for known extensions — a hand-rolled mapping would need constant maintenance and never match Finder's real icon set. |
| Opening a file in its default app | `Process`/shell-out to `open <path>` | `NSWorkspace.shared.open(URL)` | Native, synchronous, no subprocess spawn, no shell-escaping risk (avoids a command-injection-shaped surface entirely for what is, after all, a `localURL` derived from Phase 19's already-validated copy). |
| Horizontal unbounded-capacity scroll strip | A custom paging/carousel control | `ScrollView(.horizontal) { HStack { ForEach ... } }` | SwiftUI's native scroll view already does exactly this; NotchDrop's own reference shelf uses the identical composition [CITED: github.com/Lakr233/NotchDrop]. |

**Key insight:** Every piece of this phase's UI surface has a direct, current, one-line AppKit/SwiftUI equivalent — the risk in this phase is entirely in *composition* (panel sizing, gesture scoping, state wiring), not in missing tooling.

## Common Pitfalls

### Pitfall 1: Panel height reservation forgotten (see Pattern 2)
**What goes wrong:** The shelf row renders correctly in isolation but gets visually clipped at the bottom of the panel window, or the whole app appears to silently do nothing when items are added.
**Why it happens:** `NotchPillView.expandedSize`/`NotchWindowController`'s `expandedSize` field is a compile-time constant read once at `positionAndShow` time; unlike the toast (which fit under the existing ceiling), the shelf genuinely needs MORE panel height than today's `expandedSize` reserves.
**How to avoid:** Add the new `shelfRowHeight` constant to BOTH the view's outer `.frame(height:)` (the ZStack container in `NotchPillView.body`) and the controller's `expandedNotchFrame`/panel-union math, from the SAME single source of truth (Pattern 2).
**Warning signs:** Shelf row visible in `#Preview` (which doesn't go through `NotchWindowController`'s panel math) but clipped/invisible on-device.

### Pitfall 2: Gesture ambiguity between the per-item tap, the trash button, and the ancestor collapse tap
**What goes wrong:** Tapping a shelf item's trash icon also (or instead) collapses the island, or opens the file.
**Why it happens:** Exactly Finding 15's documented trap — an ancestor `.onTapGesture` sitting above a descendant `Button`'s gesture-recognition region.
**How to avoid:** Follow Pattern 3 exactly: item-open and trash-delete each get their OWN `.onTapGesture`/`Button`, and neither the shelf row's container `HStack` nor the outer `blobShape` gets a redundant ancestor gesture layered on top of them.
**Warning signs:** On-device taps feel "sticky" or trigger two effects at once (this exact symptom is why Finding 15 was originally discovered in this codebase, per the transport-button precedent).

### Pitfall 3: `ShelfCoordinator`/`ShelfLogic` mutated directly instead of going through a published mirror
**What goes wrong:** The view never re-renders when an item is added/removed, because neither `ShelfLogic` (a plain `struct`) nor `ShelfCoordinator` (a plain `@MainActor final class`, not `ObservableObject`) is observable by SwiftUI.
**Why it happens:** It's tempting to just pass `ShelfCoordinator` straight into the view and read `coordinator.logic.items`, but SwiftUI has no way to know when that mutates.
**How to avoid:** Introduce `ShelfViewState: ObservableObject` (new file, not a modification to any Phase 19 file) and have the controller call `shelfViewState.items = shelfCoordinator.logic.items` immediately after every `append`/`remove`/`clear` call, mirroring exactly how `presentationState.presentation = currentPresentation()` is re-assigned after every resolver-affecting mutation today.
**Warning signs:** Shelf row never appears at all despite hand-seeded items existing in `ShelfCoordinator.logic.items` (confirmed via a debugger/print), or items don't disappear from the strip after their trash icon is tapped even though the file is genuinely deleted from disk.

### Pitfall 4: `NSWorkspace.shared.open` on a missing file shows an unexpected system dialog
**What goes wrong:** D-04 requires a "silent no-op, no error dialog" when a shelf item's local copy is gone — but `NSWorkspace.shared.open(URL)`'s behavior for a non-existent path is not clearly documented and was not independently confirmed in this research session (see Assumptions Log).
**Why it happens:** Different AppKit open APIs (`open(URL)` vs. the newer `open(_:configuration:completionHandler:)`) have historically had inconsistent failure-path behavior across macOS versions, and Apple's docs page for the simple form does not spell out the missing-file case.
**How to avoid:** Do NOT rely on `NSWorkspace`'s own failure handling for D-04. Guard explicitly and deterministically BEFORE calling `open`:
```swift
// Islet/Notch/NotchWindowController.swift — new handler
private func handleShelfItemTap(_ item: ShelfItem) {
    guard FileManager.default.fileExists(atPath: item.localURL.path) else { return }  // D-04: silent no-op
    NSWorkspace.shared.open(item.localURL)
}
```
**Warning signs:** An unexpected "The file couldn't be opened" system alert on-device UAT when clicking a shelf item whose local copy has been externally removed.

### Pitfall 5: No mechanism to hand-seed shelf state for on-device verification
**What goes wrong:** The phase's own goal says "With hand-seeded shelf state" (real drag-in is Phase 22's scope) — without an explicit, deliberate seeding mechanism, there is no way to visually verify SHELF-03/04/05/07/09 on-device before Phase 22 ships.
**Why it happens:** `ShelfItem.localURL` must point at a REAL file on disk (for the icon lookup and click-to-open to behave realistically) — a fabricated/fake URL would make icon lookup return a generic blank icon and click-to-open silently no-op every time (masking real bugs, not proving anything).
**How to avoid:** Add a `#if DEBUG`-gated seeding path that calls the REAL `ShelfFileStore.makeSessionCopy(of:id:)` + `ShelfCoordinator.append(_:)` against a few real, small sample files (e.g. paths under the user's own Desktop/Documents chosen at dev time, or a couple of files bundled as test fixtures) — not fake `ShelfItem` structs with synthetic URLs. This is a decision for the planner to make explicit as its own task (e.g., a DEBUG-only Settings button or a `start()`-time seed call), since neither CONTEXT.md nor Phase 19 specifies the mechanism.
**Warning signs:** On-device testing shows a generic/blank icon for every shelf item, or every click-to-open silently does nothing — both are the symptom of a fake (never-materialized) `localURL`, not necessarily a real D-04 bug.

## Code Examples

### Shelf row composition (icons + per-item trash + delete-all)
```swift
// Pattern derived from NotchDrop's TrayView (ScrollView/HStack/ForEach shape)
// [CITED: github.com/Lakr233/NotchDrop, NotchDrop/TrayDrop+View.swift] + this codebase's own
// Finding-15 scoped-gesture discipline (NotchPillView.swift transportButton precedent).
private func shelfRow(_ items: [ShelfItem]) -> some View {
    ScrollView(.horizontal) {
        HStack(spacing: 10) {
            ForEach(items, id: \.id) { item in
                ShelfItemView(
                    item: item,
                    onTap: { onShelfItemTap(item) },
                    onDelete: { onShelfItemDelete(item.id) }
                )
            }
            Button(action: onShelfClearAll) {           // SHELF-05: far-right delete-all
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
    .scrollIndicators(.never)
    .frame(height: Self.shelfRowHeight)
}
```

### `ShelfViewState` — the published mirror (new file, does not touch Phase 19 files)
```swift
// Source: pattern mirrors NowPlayingState / BasicOutfitState's existing ownership contract —
// a small @Published carrier the controller writes and the view only observes.
import Foundation

final class ShelfViewState: ObservableObject {
    @Published var items: [ShelfItem] = []
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `NSWorkspace.icon(forFileType:)` (HFS 4-char type / extension string) | `NSWorkspace.icon(forContentType:)` (`UTType`-based) | Deprecated macOS 12.0 [CITED: developer.apple.com/documentation/appkit/nsworkspace-deprecated-symbols] | Irrelevant to this phase — `icon(forFile:)` (full-path based, what this phase uses) is a *different* method from `icon(forFileType:)` and was not found to be deprecated in this session's research. |

**Deprecated/outdated:** None found that affects this phase's chosen APIs.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `NSWorkspace.shared.icon(forFile:)` remains fully current (non-deprecated) on macOS 14/15/26 SDKs | Standard Stack, Pattern 3 | Low — even if soft-deprecated, it almost certainly still functions (Apple rarely removes AppKit APIs outright); worst case is a build-warning the planner should route through `checkpoint:human-verify` on first Xcode build. |
| A2 | `NSWorkspace.shared.open(URL)` never shows a system alert for a missing file, silently returning `false` | Pitfall 4 | Medium — mitigated by explicitly recommending a `FileManager.fileExists` guard BEFORE calling `open`, so D-04's "no error dialog" contract does not actually depend on this assumption being true. |
| A3 | A seeded `shelfRowHeight` of ~56pt is a reasonable starting value | Pattern 2 | Low — explicitly flagged as "seed only," this phase has `UI hint: yes` per ROADMAP.md, so `/gsd:ui-phase 20` is expected to tune the real value; CONTEXT.md's Claude's-Discretion section already defers exact height to the UI-SPEC. |

**If empty:** N/A — see table above; all three should be spot-checked, none blocks planning.

## Open Questions

1. **Hand-seed mechanism for on-device verification (Pitfall 5)**
   - What we know: the phase goal explicitly says "hand-seeded shelf state"; real drag-in is out of scope until Phase 22.
   - What's unclear: whether the planner wants a permanent `#if DEBUG` seed hook, a throwaway one-off manual test harness, or a Settings-panel "add test item" button.
   - Recommendation: make this an explicit planned task (not an incidental side effect of another task), using `ShelfFileStore.makeSessionCopy` + `ShelfCoordinator.append` against real sample files so the icon/open/delete UAT is realistic.

2. **Exact shelf row visual sizing (icon size, spacing, row height, scroll-indicator styling)**
   - What we know: CONTEXT.md explicitly defers this to `/gsd:ui-phase 20` (UI hint: yes in ROADMAP.md).
   - What's unclear: nothing blocking — this is a deliberate, already-acknowledged deferral, not a research gap.
   - Recommendation: planner should sequence a UI-SPEC step before/alongside the implementation plan, per this project's established `/gsd:ui-phase` convention (seen for Phase 18).

## Environment Availability

Skipped — this phase has no external dependencies beyond the existing Xcode/macOS SDK toolchain already verified working for this project (per project memory: build machine is Tahoe/Xcode 26.6/Swift 6.3.3, Swift 5 language mode). No new packages, no new system frameworks beyond AppKit/SwiftUI/Foundation, which are already linked.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing, `IsletTests/` target) |
| Config file | `project.yml` (XcodeGen-generated `.xcodeproj`, no separate XCTest config) |
| Quick run command | `xcodebuild build-for-testing -scheme Islet -configuration Debug` (compiles the test target — does NOT execute; see below) |
| Full suite command | Manual **Cmd-U in Xcode** — per project memory `xcodebuild-test-headless-hang`, `xcodebuild test` hangs because the tests host the full `Islet.app`, which boots the real `NSPanel`/MediaRemote/IOBluetooth stack headlessly. This is a pre-existing, documented constraint, not new to this phase. |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SHELF-03 | Shelf row appears/scrolls with unbounded items when expanded + non-empty | manual (SwiftUI view, no pure logic to extract) | — (visual, Cmd-U / on-device) | N/A — view-level |
| SHELF-04 | Per-item trash removes just that item | unit (`ShelfViewState` sync after `ShelfCoordinator.remove`) | `xcodebuild build-for-testing` then Cmd-U `ShelfViewStateTests` | ❌ Wave 0 |
| SHELF-05 | Delete-all clears every item | unit (`ShelfViewState` sync after `ShelfCoordinator.clear`) | same as above | ❌ Wave 0 |
| SHELF-07 | Click-to-open opens file; missing-file click is a silent no-op (D-04) | unit (extract the `fileExists`-guarded open decision as a small pure/testable helper, mirroring `songChangeToastGate`'s "pure gate, controller applies it" shape) | Cmd-U `NotchWindowControllerTests`-style file (new) | ❌ Wave 0 |
| SHELF-09 | Shelf hidden during Charging/Device splash | Likely already covered structurally — recommend one `IslandResolverTests`-style assertion confirming the shelf-composing branches (`mediaExpanded`/`expandedIdle`/`mediaUnavailable`) are never reached while `activeTransient != nil`, reusing the EXISTING `resolve(...)` pure function (no new resolver code needed) | Cmd-U, extend existing `IslandResolverTests.swift` | ✅ (existing file, needs new test case only) |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet -configuration Debug` (build gate only, per project memory — `xcodebuild test` is not viable headlessly for this project)
- **Per wave merge:** Manual Cmd-U in Xcode GUI (per project memory: give the user exact Xcode instructions, not terminal commands, for this step — `feedback-xcode-gui-not-terminal`)
- **Phase gate:** Full manual Cmd-U pass + on-device UAT (drag-free, hand-seeded per Pitfall 5) before `/gsd:verify-work 20`

### Wave 0 Gaps
- [ ] `IsletTests/ShelfViewStateTests.swift` — new file, covers SHELF-04/SHELF-05 (published-mirror sync after coordinator mutations)
- [ ] A small pure helper + its test (e.g. in `IsletTests/NotchWindowControllerTests.swift` or similar, if such a file doesn't already exist — check before creating) covering SHELF-07's fileExists-guard decision
- [ ] One new test case appended to existing `IsletTests/IslandResolverTests.swift` for SHELF-09 (no new resolver production code required — see table above)
- [ ] Framework install: none — `IsletTests` target already exists and builds

## Security Domain

`security_enforcement` is absent from `.planning/config.json`'s `workflow` block → treated as enabled per protocol default.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | Single-user local macOS app, no auth surface touched by this phase. |
| V3 Session Management | No | N/A. |
| V4 Access Control | No | N/A — no privilege boundary introduced. |
| V5 Input Validation | Yes | `item.filename` is untrusted external data (the original dropped file's name) — MUST use `.lineLimit(1)` + `.truncationMode` when rendered, mirroring the EXISTING project-wide convention already applied to calendar titles and now-playing metadata (`T-14-06`/`T-04-09`-style mitigation, see `NotchPillView.swift`'s `calendarColumn`/title rendering). Path validation for `localURL` is already handled upstream by Phase 19's `ShelfFileStore` (locked, not re-validated here). |
| V6 Cryptography | No | N/A — no crypto surface. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|-----------------------|
| Unbounded/malicious filename rendered without truncation, breaking layout or (less likely on macOS/SwiftUI, but still hygienic) enabling a rendering-injection-shaped issue | Tampering (of the visual surface) | `.lineLimit(1)` + `.truncationMode(.middle or .tail)` on the filename Text, exactly as this codebase already does for calendar/now-playing metadata (see Pattern 3's code example). |
| Command-injection-shaped surface if a naive implementation shells out to `open <path>` instead of using the native API | Tampering / Elevation of Privilege | Use `NSWorkspace.shared.open(URL)` (native, typed, no shell) — never `Process`/shell-out (see Don't Hand-Roll). |
| Opening a `localURL` that has been swapped/relocated outside the shelf's own temp root between add and click | Tampering | Not a new risk this phase introduces — `ShelfFileStore.deleteSessionCopy`'s existing CR-01 guard (`itemDir.path.hasPrefix(shelfRoot.path)`) already confines all shelf-owned paths to `IsletShelf/` under `NSTemporaryDirectory()`; this phase only READS `localURL`, it never constructs or mutates it. |

## Sources

### Primary (HIGH confidence)
- Direct reads of `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/IslandResolver.swift`, `Islet/Notch/NotchGeometry.swift`, `Islet/Notch/BatteryIndicator.swift`, `Islet/Shelf/ShelfItem.swift`, `Islet/Shelf/ShelfLogic.swift`, `Islet/Shelf/ShelfCoordinator.swift`, `Islet/Shelf/ShelfFileStore.swift`, `IsletTests/ShelfCoordinatorTests.swift`, `project.yml` — all read in full this session.
- `.planning/phases/20-shelf-view/20-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/ROADMAP.md` (Phase 20 section), `.planning/config.json`.

### Secondary (MEDIUM confidence)
- `github.com/Lakr233/NotchDrop` — `NotchDrop/TrayDrop+DropItemView.swift`, `NotchDrop/TrayDrop+View.swift`, `NotchDrop/TrayDrop+DropItem.swift`, `NotchDrop/TrayDrop.swift` fetched directly via `gh api` in this session — confirms `ScrollView(.horizontal)`/`HStack`/`ForEach` shelf composition, `NSWorkspace.shared.open(url)` for click-to-open, and a sibling-`.overlay`-scoped delete gesture, in the exact reference app this project's own CLAUDE.md already cites.
- `developer.apple.com/documentation/appkit/nsworkspace-deprecated-symbols` (WebSearch summary) — confirms `icon(forFileType:)` deprecated in favor of `icon(forContentType:)`; did not directly confirm `icon(forFile:)`'s own status (see Assumptions Log A1).

### Tertiary (LOW confidence)
- WebSearch results on `NSWorkspace.shared.open(URL)`'s missing-file behavior were inconclusive (see Pitfall 4 / Assumption A2) — mitigated by recommending an explicit `fileExists` guard rather than depending on the unconfirmed claim.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every API is a well-established, long-lived AppKit/SwiftUI primitive with a directly-cited reference-app usage example.
- Architecture: HIGH — every pattern is derived directly from this codebase's own existing, tested precedents (Phase 18's conditional-height blob, Finding 15's scoped gestures, the `*State`/coordinator ownership split), not external speculation.
- Pitfalls: HIGH — Pitfalls 1-3 and 5 are derived from direct code-reading of this exact codebase's constraints (Pitfall 4 doc comments, Finding 15, CONTEXT.md's locked-files note, the phase's own "hand-seeded" wording); Pitfall 4 (NSWorkspace missing-file behavior) is MEDIUM, explicitly flagged and mitigated with a deterministic guard rather than left as an open risk.

**Research date:** 2026-07-09
**Valid until:** 30 days (stable native macOS APIs; the only fast-moving risk is A1's icon-API deprecation status, worth a quick recheck if this research is reused after an Xcode/macOS SDK bump).
