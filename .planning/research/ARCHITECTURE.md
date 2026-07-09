# Architecture Research — Drag-and-Drop File Shelf Integration into Islet

**Domain:** Adding a session-only, drag-and-drop file shelf to an existing, shipped native macOS notch app with a proven single-arbiter (`IslandResolver`) + coordinator-extraction (`ActivityCoordinator`) architecture
**Researched:** 2026-07-09
**Confidence:** HIGH on integration points and existing-pattern extraction (verified by reading the real files: `NotchWindowController.swift`, `IslandResolver.swift`, `ActivityCoordinator.swift`, `DeviceCoordinator.swift`, `NotchPillView.swift`, `IslandPresentationState.swift`, `NotchInteractionState.swift`, `Islet.entitlements`); MEDIUM-HIGH on the `NSItemProvider` drag-in/out mechanics (corroborated by multiple independent sources, no official Apple sample matched exactly); LOW-MEDIUM on the exact "does the shelf show during a transient wings splash" behavior — that is a product call this doc flags rather than invents.

> Spot-check research, not green-field: this answers exactly where the file shelf plugs into an app that already has a proven "pure resolver decides content, a separate @Published axis rides underneath it, the view only renders" pattern (established for the Phase 18 song-change toast) and a proven "coordinator per activity domain" pattern (established for `DeviceCoordinator`, Phase 16) — and explains, with reasons grounded in the real code, why the shelf fits the FIRST pattern, not the second.

---

## The One Idea That Makes This Integration Make Sense

**The file shelf is not a competing activity — it never has a rank, never enters `TransientQueue`, and never gets its own `ActivityCoordinator`.** It is a second, independent `@Published` axis that `NotchPillView` renders *underneath* whatever `IslandResolver.resolve(...)` already decided, gated only on `interaction.isExpanded`. Islet already has exactly this shape shipped and working: the Phase 18 song-change toast (`NowPlayingState.songChangeToast`, `songChangeToastGate(...)` in `IslandResolver.swift:87-89`) is deliberately **not** threaded through `resolve(...)`/`IslandPresentation` — its own doc comment says so explicitly, and calls out that this diverges from that phase's own pre-execution research on purpose, "permitted by CONTEXT.md's discretion note." The shelf is the same shape again: a sibling `@Published` field the controller sets directly, rendered by the view as an extra row, never touching the resolver's ranking.

This one framing answers all four sub-questions in the prompt:

1. **No `ShelfCoordinator`.** `ActivityCoordinator` (`Islet/Notch/ActivityCoordinator.swift`) is deliberately narrow — its own header says it is "a deliberate first slice ... NOT pre-sketched for the future Charging/NowPlaying/Outfit coordinators," sized to exactly what `DeviceCoordinator` needs: reach-back into the shared `TransientQueue` (`queueHead`/`enqueue`/`updateHead`) plus reacting to a promotion event. The shelf needs **none** of that — it never enqueues, never competes for the head, never gets promoted/demoted. Giving it a `ShelfCoordinator` behind that protocol would be building the shape for a problem the shelf doesn't have.
2. **Plain `@Published` state is not just simpler, it is the *correct* fit** — mirroring `BasicOutfitState`/`NowPlayingState`/`IslandPresentationState`'s existing "plain published holder, no methods, no timers, no system frameworks" convention (`Islet/Notch/BasicOutfitState.swift` is the shortest, cleanest example of this).
3. **It is a modifier on the current visible content, not a competing activity** — see "Interaction with IslandResolver" below for exactly how and where it renders.
4. **Data model: a copy in an app-owned temp directory, addressed by a plain file `URL`** — not a security-scoped bookmark (irrelevant — Islet is un-sandboxed, confirmed below) and not raw `Data` (wasteful for drag-out, breaks `NSItemProvider(contentsOf:)`). See "Data Model & File Lifetime" below.

---

## Confirmed: Islet is NOT sandboxed

`Islet/Islet.entitlements` contains only `com.apple.security.cs.disable-library-validation`, `com.apple.developer.weatherkit`, and two `personal-information` keys (calendars, location) — **no `com.apple.security.app-sandbox` key at all**. This was already an architectural given (the private MediaRemote bridge + spawning `perl` rules out sandboxing entirely, per `CLAUDE.md`/`PROJECT.md`).

This matters directly for the shelf's data model: **security-scoped bookmarks solve a sandboxed app's problem** (persisting file-read permission across app relaunches when the sandbox would otherwise revoke it). Islet has full filesystem access as the logged-in user already, and the shelf is explicitly session-only (cleared on restart) — there is no permission boundary to persist across, and no reason to ever call `startAccessingSecurityScopedResource()`. Don't build that machinery; it would be solving a problem this app doesn't have.

---

## System Overview (current + proposed overlay)

```
┌──────────────────────────────────────────────────────────────────────────┐
│  NotchWindowController (the existing single arbiter, ~1170 lines)        │
│   existing: transientQueue, presentationState, interaction,              │
│             chargingState, nowPlayingState, outfitState, deviceCoordinator│
│   NEW: private let shelfState = ShelfState()          (plain holder,     │
│        mirrors nowPlayingState/outfitState — no monitor, no start/stop)  │
│   NEW: private let shelfImporter = ShelfFileImporter() (glue — NOT a     │
│        coordinator; see "Why not a coordinator" below)                   │
│   NEW: handleDrop(providers:) — called from the view's onDrop closure,  │
│        expands the island (reuses `.clicked` via nextState — same path  │
│        handleClick() already uses) if collapsed, then imports off-main  │
│   Untouched: IslandResolver.resolve(...), TransientQueue, ActivityCoordinator,│
│              DeviceCoordinator — the shelf never calls into any of these │
├──────────────────────────────────────────────────────────────────────────┤
│  NEW: Islet/Notch/Shelf*.swift  (mirrors the Notch/ pure-seam + thin-glue│
│  split already used for PowerActivity/PowerSourceMonitor,                │
│  NowPlayingPresentation/NowPlayingMonitor, DeviceActivity/DeviceCoordinator)│
│                                                                            │
│   ShelfItem.swift      — PURE value: id, originalURL, localURL, filename, │
│                          addedAt. Foundation-only, Equatable.             │
│   ShelfLogic.swift     — PURE total functions over [ShelfItem]: adding,   │
│                          removing(id:), clearing. Unit-tested in ms,      │
│                          mirrors PowerActivity/DeviceActivity's "pure     │
│                          seam first" discipline — no NSItemProvider here. │
│   ShelfState.swift     — @Published var items: [ShelfItem] = [].         │
│                          Mirrors BasicOutfitState exactly: no methods.    │
│   ShelfFileImporter.swift — GLUE: the ONLY file that imports UniformTypeIdentifiers│
│                          / touches NSItemProvider. Resolves a dropped     │
│                          NSItemProvider to a source URL, copies it to a   │
│                          private temp dir off the main thread, hands back │
│                          a ShelfItem via a completion closure on main.    │
│                          NOT behind a protocol (see "No protocol seam    │
│                          needed" below) — NSItemProvider is a stable,    │
│                          public Foundation/AppKit API, not a fragile      │
│                          private one like MediaRemote.                   │
├──────────────────────────────────────────────────────────────────────────┤
│  NotchPillView.swift                                                     │
│   NEW: @ObservedObject var shelf: ShelfState  (new required param,       │
│        mirrors outfit:/nowPlaying: — non-defaulted, always injected)     │
│   NEW: shelfRow view — appended BELOW the existing `switch presentation` │
│        content, `if !shelf.items.isEmpty` (SwiftUI removes its layout    │
│        space entirely when the condition is false — matches the "extra  │
│        area is transparent → invisible" Pattern 4 convention already     │
│        used for the expanded/wings panel union)                          │
│   NEW: .onDrop(...) on the collapsed-pill hot-zone view specifically     │
│        (see "The click-through / drag-in collision" pitfall below)       │
│   NEW: onDropFiles / onRemoveShelfItem / onClearShelf closures, mirroring│
│        the existing onClick/onTogglePlayPause/onNext/onPrevious plain-   │
│        closure convention exactly (view stays AppKit/UTType-free)        │
│   Untouched: the `switch presentation { }` block, IslandPresentation,   │
│              matchedGeometryEffect identity, all existing wing/blob shapes│
└──────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | New or existing |
|-----------|-----------------|------------------|
| `ShelfItem` | Pure value describing one dropped file (id, original + local URL, filename, timestamp) | NEW |
| `ShelfLogic` | Pure total functions: append, remove-by-id, clear-all over `[ShelfItem]` | NEW |
| `ShelfState` | `@Published var items: [ShelfItem]`, the view's data source | NEW |
| `ShelfFileImporter` | Resolves an `NSItemProvider` → copies the file into a private temp dir off-main → hands back a `ShelfItem` | NEW |
| `NotchWindowController` | Owns `shelfState`; wires drop-in (expand + import), per-item removal, clear-all, and temp-dir teardown into its existing spring/`updateVisibility()` discipline | MODIFIED |
| `NotchPillView` | Renders the shelf row underneath the resolver's verdict; hosts `.onDrop` on the hot-zone; renders per-item delete + far-right delete-all icons; hosts `.onDrag`/item-provider for drag-out | MODIFIED |
| `IslandResolver` / `IslandPresentation` / `TransientQueue` | Untouched — the shelf never participates in ranking | NOT TOUCHED |
| `ActivityCoordinator` / `DeviceCoordinator` | Untouched — no `ShelfCoordinator` is created; see rationale above | NOT TOUCHED |

---

## Why not a coordinator (elaborated)

`ActivityCoordinator`'s contract is exactly two methods: `handle(_ reading:)` and `activityPromoted()`. Both exist purely to let `DeviceCoordinator` reach back into the shared, value-type `TransientQueue` via six injected closures (`queueHead`, `enqueue`, `updateHead`, `presentTransientChange`, `renderPresentation`, `batteryForAddress` — see `DeviceCoordinator.swift:77-96`). A `ShelfCoordinator` conforming to that protocol would need to invent a `Reading` type and a meaningless `activityPromoted()` implementation, purely to satisfy a shape designed for queue-competing, rank-carrying activities. The shelf is neither — extracting a `ShelfCoordinator` "to follow the pattern" would be **pattern-matching the extraction shape, not the actual problem** the extraction solves (isolating stateful, TransientQueue-touching bookkeeping out of the controller). A plain `ShelfState` + `ShelfLogic` pure-function pair achieves the same testability (unit-test `ShelfLogic` in isolation, exactly as `PowerActivity`/`DeviceActivity`/`TrackSnapshot` are tested) without adopting a protocol built for a different problem.

## No protocol-isolation seam needed for `NSItemProvider`

Islet's other protocol seams (`NowPlayingService`, `LicenseService`) exist specifically because they wrap a **fragile external dependency**: a private framework that already broke once (MediaRemote on macOS 15.4) or a third-party HTTP API. `NSItemProvider` / `UTType.fileURL` is a public, stable, decade-old AppKit/Foundation API with no history of Apple revoking it and no third-party service behind it. Wrapping it in a protocol would add a seam with no corresponding fragility to protect against — skip it; `ShelfFileImporter` can be a plain concrete class.

---

## Interaction with IslandResolver: modifier, not competitor

`IslandPresentation` (`IslandResolver.swift:17-24`) stays exactly as-is — `idle`, `charging`, `device`, `nowPlayingWings`, `nowPlayingExpanded`, `expandedIdle`. The shelf is rendered by `NotchPillView.body` as **content appended after** the `switch presentation { ... }` block, inside the same outer `ZStack`/container, gated on a separate condition — not one more `case` in that switch.

**Recommended gate: `interaction.isExpanded && (presentation == .expandedIdle || presentation.isNowPlayingExpanded) && !shelf.items.isEmpty`** — i.e. the shelf only appends under the two genuinely-expanded, non-transient cases (`.expandedIdle`, `.nowPlayingExpanded`), matching the requirement text "appended below whatever else is showing **expanded**." This deliberately **excludes** the three collapsed "wings" cases (`.charging`, `.device`, `.nowPlayingWings`) — those are 32pt-tall flat strips with no vertical room for a shelf row, and D-04 in `resolve(...)` already establishes that a transient wins even over an expanded island, so a charging/device splash firing mid-expansion would otherwise need the shelf to disappear and reappear every ~3s, which would look broken. **This exclusion is a product decision, not a proven requirement** — flag it explicitly for `/gsd:discuss-phase` rather than treating it as settled; the requirement text is ambiguous about whether a file mid-drop during a charging splash should still show its shelf.

This is structurally identical to how the Phase 18 toast is gated: `songChangeToastGate(activeTransient:isExpanded:toastEnabled:)` is a **separate pure function**, deliberately not merged into `resolve(...)`, evaluated by the controller, and rendered by the view as an extra `VStack` row (`mediaWingsOrToast`'s `toastTextRow`) — read `IslandResolver.swift:74-89`'s own comment block for the precedent this shelf integration should copy almost verbatim, substituting "shelf non-empty" for "toast content present."

---

## Panel sizing: the real mechanical wrinkle

`NotchWindowController.positionAndShow(on:)` sizes the AppKit `NSPanel` **once, up front**, to `expandedNotchFrame(collapsed:expandedSize:).union(wingsFrame(...))` (`NotchWindowController.swift:592-599`) specifically so the SwiftUI spring morph never clips or triggers a mid-animation `panel.setFrame` (Pattern 4 / Pitfall 4, called out repeatedly in the file's comments). The Phase 18 toast avoided ever resizing the panel because its extra 32pt (`toastExtraHeight`) already fit inside the pre-existing headroom: `expandedSize.height` (144pt) is taller than the wings shape even with the toast row added (32 + 32 = 64pt), so the union frame already covered it.

**A shelf row does not automatically get this for free** — a horizontally-scrolling file strip needs real vertical space (icon + label + delete button, realistically ~56–72pt), and `expandedIsland`/`mediaExpanded`/`mediaUnavailable` are all sized via the shared `NotchPillView.expandedSize` constant (360×144) through the common `blobShape(...)` helper. Two options, and the second is the one to take:

- **Wrong:** bake the extra height directly into `NotchPillView.expandedSize`. This makes every existing blob (including `expandedIdle`/`mediaExpanded` with an empty shelf) visually taller, showing dead black space below the existing content whenever the shelf is empty — a visible regression to the 90%-of-the-time empty-shelf case.
- **Right (mirrors the toast precedent exactly):** reserve the headroom **only in the panel/window frame math**, not in the shared `expandedSize` constant used by every blob's `.frame(height:)`. Concretely: introduce `NotchPillView.shelfRowHeight` and change the value `NotchWindowController` feeds into `expandedNotchFrame(...)` to `expandedSize.height + shelfRowHeight` (an internal-to-the-controller constant, e.g. `panelExpandedSize`), while `blobShape(...)`'s own `.frame(height: Self.expandedSize.height)` stays untouched at 144pt as the *default*. Each blob-producing view that wants to host the shelf computes its **own** conditional total height the same way `mediaWingsOrToast` already does (`let height = Self.wingsSize.height + (toast != nil ? Self.toastExtraHeight : 0)`) — i.e. `let height = Self.expandedSize.height + (shelf.items.isEmpty ? 0 : Self.shelfRowHeight)`. The panel's pre-reserved (transparent) extra space absorbs the growth exactly like it already absorbs the toast row; no `panel.setFrame` call is ever needed for a shelf content change, preserving the existing "never resize for content changes" invariant.

---

## The click-through / drag-in collision — the one genuine open risk

`NotchWindowController` only makes the panel interactive (`panel.ignoresMouseEvents = false`) while `pointerInZone || interaction.isExpanded` (`syncClickThrough()`, `NotchWindowController.swift:696-699`); otherwise the **entire window ignores all mouse events**, including drag sessions, so a drag can pass straight through to whatever sits behind the notch. The existing pointer-hover detection that flips this flag in time for a *click* to land works because it rides a **global** `NSEvent.mouseMoved` monitor (`NSEvent.addGlobalMonitorForEvents`, line 299) — this observes copies of events delivered to *other* apps and does not require Islet's own window to be interactive to fire. **A file-drag session is not delivered through that global monitor** — OS drag-and-drop (`NSDraggingDestination`) is only routed to windows that are already registered as valid drop targets *at the moment the drag enters their frame*, which is exactly the chicken-and-egg problem `ignoresMouseEvents = true` creates.

Concretely: today, before any hover/click, the panel is non-interactive over the entire notch area; a file dragged over the collapsed pill in that state would currently **not** trigger `.onDrop`, because the window itself isn't accepting drag events yet. This directly conflicts with the requirement "Drag a file onto the collapsed pill → island auto-expands." Two known mitigation directions (do not treat either as decided — this needs its own research/spike before implementation):

1. Keep the small collapsed hot-zone rectangle **permanently drag-target-registered** (i.e. never gate drag acceptance behind the same `ignoresMouseEvents` toggle used for clicks) — e.g. by having the content view's `hitTest(_:)` return `nil` outside the visible pill (achieving click-pass-through via hit-testing) while leaving `ignoresMouseEvents` permanently `false` so `NSDraggingDestination` methods always fire. This is a bigger change to the existing click-through mechanism (currently a single window-level boolean, not a `hitTest` override) and needs on-device verification that it doesn't reintroduce accidental click-swallowing over the transparent panel margins.
2. Detect a system-wide drag session starting (there is no clean public API for this cross-app — `NSPasteboard.general.changeCount` polling around drag events is the closest common workaround, and it's inelegant) and pre-emptively flip `ignoresMouseEvents = false` for the drag's duration.

Flagging this prominently: **this is the single highest-uncertainty integration point in the whole feature** and should get its own `/gsd:discuss-phase` conversation and probably a tiny spike/prototype before the full shelf is built, exactly the kind of thing this research is supposed to surface rather than hand-wave past.

---

## Data Model & File Lifetime

**Recommended `ShelfItem`:**

```swift
struct ShelfItem: Identifiable, Equatable {
    let id: UUID
    let originalURL: URL   // informational only — where the user dragged it from
    let localURL: URL      // Islet's OWN copy — the only URL ever read from or dragged out
    let filename: String
    let addedAt: Date
}
```

**Why a copy, not a live reference to `originalURL`, and not a security-scoped bookmark:**

- **Robustness against the source disappearing.** The requirement explicitly asks "what happens if the source file is deleted/moved while sitting in the shelf" — answering that cleanly requires the shelf to hold something that does **not** depend on the original path continuing to exist. Copying once, at drop time, into an app-owned temp directory means the shelf's own file is authoritative for the rest of the session; a later deletion/move/rename of the original is simply irrelevant.
- **Drag-out needs a real, currently-valid file on disk.** `NSItemProvider(contentsOf: url)` (the standard, reliable mechanism for handing a file to Finder/another app via drag) requires `url` to point at an actual readable file for the duration of the drag. SwiftUI's file-promise-writer path is documented as unreliable/unsupported in practice (multiple independent sources agree the promise-based approach is the wrong tool here) — reading an existing file via `NSItemProvider(contentsOf:)` from the app's own temp copy sidesteps that whole problem category.
- **No sandbox, so no bookmark needed at all.** Security-scoped bookmarks solve "persist read access across a sandboxed relaunch." Islet is unsandboxed and the shelf is explicitly session-only (cleared on restart) — there is no permission boundary and no persistence requirement to bridge.
- **Not raw `Data` in memory.** Holding every dropped file as in-memory `Data` would (a) make `NSItemProvider(contentsOf:)` drag-out impossible without first writing it back to disk anyway, (b) balloon memory for an "unbounded capacity" shelf with large files (e.g. video), and (c) gives nothing a copy-to-temp-dir doesn't already give for free.

**Lifecycle:**

- **Copy location:** a private subdirectory under `FileManager.default.temporaryDirectory`, scoped per-launch (e.g. a UUID-named folder created once in `start()`), never Application Support or anywhere implying persistence intent.
- **Copy timing:** perform the actual file copy **off the main thread** (background `DispatchQueue` or `Task.detached`), then hop back to main to construct the `ShelfItem` and mutate `shelfState.items` inside the existing `withAnimation(.spring(...))` convention — mirrors how every other mutation in `NotchWindowController` is already disciplined, and matters concretely here because dropped files (e.g. videos) can be large enough that a synchronous copy would visibly hitch the UI thread.
- **Per-file removal:** delete that item's `localURL` copy from disk, then apply `ShelfLogic.removing(id:from:)`.
- **Delete-all:** delete every item's `localURL`, then `shelfState.items = []`.
- **App-quit / controller teardown:** best-effort `try? FileManager.default.removeItem(at: shelfTempDirectory)` in `deinit`, mirroring the file's existing owner-driven teardown discipline (`powerMonitor?.stop()`, `nowPlayingMonitor?.stop()`, etc.) — note the file's own known carried-over bug (`AppDelegate.quit()` calls `NSApp.terminate(nil)` without tearing down `NotchWindowController`, so `deinit` never runs on quit) means this cleanup currently would **not** run on quit either; either fix that pre-existing leak as part of this milestone or accept that macOS's own periodic temp-directory cleanup is the fallback (acceptable given these are always just copies, never the user's only copy of anything).
- **App-launch:** best-effort delete of any stale shelf temp directory left over from a previous crashed session, before creating a fresh one.

---

## Recommended Project Structure (new files)

```
Islet/Notch/
├── ShelfItem.swift            # pure value type (Foundation only)
├── ShelfLogic.swift           # pure functions: adding/removing/clearing over [ShelfItem]
├── ShelfState.swift           # ObservableObject, @Published var items: [ShelfItem]
├── ShelfFileImporter.swift    # glue: NSItemProvider → background copy → ShelfItem
IsletTests/
├── ShelfLogicTests.swift      # unit tests for the pure seam, written FIRST
```

No new top-level folder needed — this is exactly the same granularity as the existing `PowerActivity`/`PowerSourceMonitor`, `NowPlayingPresentation`/`NowPlayingMonitor`, `DeviceActivity`/`DeviceCoordinator` pure/glue pairs already living flat in `Islet/Notch/`.

---

## Build Order (matches this project's existing pure-seam-first convention)

This project has shipped every prior feature in the same order (`IslandResolver` before `NotchWindowController` wiring in Phase 6; `DeviceCoordinator` proven in isolation in Plan 16-01 *before* the controller was wired to it in Plan 16-02). Recommend the identical order here:

1. **Pure seam first, no system APIs at all:** `ShelfItem` + `ShelfLogic`, fully unit-tested (append/remove/clear, and whatever dedupe policy is chosen) with zero `NSItemProvider`/`FileManager` involvement — hand-built `ShelfItem`s in tests, exactly like `TrackSnapshot`/`PowerReading`/`DeviceReading` are hand-built in their own test suites.
2. **View, driven by hand-set preview state, no live drop yet:** add `shelf: ShelfState` to `NotchPillView`, the appended shelf row (icon/thumbnail + per-item trash + far-right delete-all), gated per the "Interaction with IslandResolver" section above, verified via `#Preview` blocks (mirroring the existing `#Preview("Charging Wings")` etc. convention) with a hand-populated `ShelfState`. Confirms panel-sizing math (the `shelfRowHeight` headroom question above) visually before any real drag exists.
3. **Drag-OUT glue** (simpler than drag-in — no click-through collision): wire `.onDrag`/`NSItemProvider(contentsOf:)` on each rendered shelf item so files can already be dragged to Finder from a manually-seeded shelf, and wire per-item/delete-all buttons to the controller closures.
4. **Drag-IN glue last, and treat the click-through collision as its own spike:** `ShelfFileImporter` (background copy) + the controller's `handleDrop(providers:)` (expand-if-collapsed + import) + resolving the `.onDrop`/`ignoresMouseEvents` interaction from the pitfall above — this is the step most likely to need on-device iteration, so sequencing it last means every other piece is already proven working before touching the riskiest part.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: `ShelfCoordinator` behind `ActivityCoordinator`
**What it would look like:** conforming a new type to `ActivityCoordinator`, inventing a `Reading` typealias and a no-op `activityPromoted()`.
**Why it's wrong:** copies the *shape* of an extraction that exists to manage `TransientQueue` reach-back and rank-competition — neither applies to the shelf. Adds a protocol conformance with unused/meaningless methods.
**Instead:** plain `ShelfState` (mirrors `BasicOutfitState`) + `ShelfLogic` pure functions.

### Anti-Pattern 2: Threading the shelf through `IslandPresentation`/`resolve(...)`
**What it would look like:** adding a `.shelf([ShelfItem])` case or wrapping every existing case with shelf data.
**Why it's wrong:** the shelf is orthogonal to *which* activity is showing, not a rank in the same competition — this would force every existing `IslandPresentation` case to also carry shelf data, bloating the enum the resolver's tests already cover, for a concern that has nothing to do with priority arbitration.
**Instead:** a separate `@Published` field the view appends underneath the switch, exactly like the Phase 18 toast.

### Anti-Pattern 3: Referencing `originalURL` directly instead of copying
**What it would look like:** storing only the dropped `URL` and reading from it whenever the shelf renders/drags-out.
**Why it's wrong:** breaks the moment the source file is renamed, moved, or deleted while sitting in the shelf (explicitly one of this feature's required behaviors to get right); also fights `NSItemProvider(contentsOf:)`'s expectation of a stable, app-controlled file for drag-out.
**Instead:** copy once at drop time into an app-owned temp directory; the shelf's own copy is authoritative.

### Anti-Pattern 4: Baking shelf headroom into the shared `expandedSize` constant
**What it would look like:** changing `NotchPillView.expandedSize` itself to include shelf height.
**Why it's wrong:** every blob shape using `expandedSize` (idle glance, media expanded, unavailable) becomes visibly taller with dead black space even when the shelf is empty (the common case).
**Instead:** reserve extra panel-frame headroom separately (controller-side constant), keep each blob view's own conditional height computation local, mirroring `mediaWingsOrToast`'s existing `height = wingsSize.height + (toast != nil ? toastExtraHeight : 0)` pattern.

---

## Integration Points (concrete file/line references)

| Integration point | File | Change |
|---|---|---|
| New pure value | `Islet/Notch/ShelfItem.swift` | NEW file |
| New pure logic | `Islet/Notch/ShelfLogic.swift` | NEW file, unit-tested first |
| New published state | `Islet/Notch/ShelfState.swift` | NEW file, mirrors `BasicOutfitState.swift` |
| New glue (drag-in resolution + temp copy) | `Islet/Notch/ShelfFileImporter.swift` | NEW file |
| Controller owns shelf state | `NotchWindowController.swift` (near line 93, alongside `outfitState`) | ADD `private let shelfState = ShelfState()` |
| Controller wires drop-in | `NotchWindowController.swift` (near `handleClick()`, line 744) | ADD `handleDrop(providers:)` reusing `nextState(interaction.phase, .clicked)` for the auto-expand |
| Controller wires teardown | `NotchWindowController.swift` `deinit` (line 1122) | ADD best-effort shelf-temp-dir removal |
| View receives shelf state | `NotchPillView.swift` (near line 51, alongside `outfit`) | ADD `@ObservedObject var shelf: ShelfState` (non-defaulted) |
| View renders shelf row | `NotchPillView.swift` `body` (after line 159's `switch`) | ADD conditional row, gated per "Interaction with IslandResolver" |
| View accepts drops | `NotchPillView.swift` `collapsedIsland` (line 181) + expanded blob shapes | ADD `.onDrop(of: [.fileURL], ...)`, subject to the click-through pitfall above |
| Panel sizing | `NotchWindowController.swift` `positionAndShow` (line 592) | Feed `expandedSize.height + shelfRowHeight` into `expandedNotchFrame(...)` instead of the raw constant |
| `IslandResolver.swift` | — | **NOT TOUCHED** |
| `ActivityCoordinator.swift` / `DeviceCoordinator.swift` | — | **NOT TOUCHED** |

---

## Sources

- Direct reads of the real Islet codebase (HIGH confidence — these are facts about this project, not general claims): `NotchWindowController.swift`, `IslandResolver.swift`, `ActivityCoordinator.swift`, `DeviceCoordinator.swift`, `NotchPillView.swift`, `IslandPresentationState.swift`, `NotchInteractionState.swift`, `BasicOutfitState.swift`, `NowPlayingPresentation.swift`, `Islet.entitlements`, `.planning/PROJECT.md`.
- [SwiftUI on macOS: Drag and drop, and more — The Eclectic Light Company](https://eclecticlight.co/2024/05/21/swiftui-on-macos-drag-and-drop-and-more/) — MEDIUM, corroborates `onDrop`/`NSItemProvider`/`public.file-url` mechanics on macOS.
- [Implementing drag and drop with the SwiftUI modifiers — Create with Swift](https://www.createwithswift.com/implementing-drag-and-drop-with-the-swiftui-modifiers/) — MEDIUM, corroborates `.onDrag`/`.onDrop` API shape.
- [SwiftUI drag & drop does not support file promises — Wade Tregaskis](https://wadetregaskis.com/swiftui-drag-drop-does-not-support-file-promises/) — MEDIUM-HIGH, directly informs the recommendation to drag out an existing real file (`NSItemProvider(contentsOf:)`) rather than attempt a file-promise-writer approach in SwiftUI.
- [NSItemProvider — Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsitemprovider) — HIGH (official), confirms the general contract for conveying files during drag-and-drop.
- Apple's documented behavior that a window with `ignoresMouseEvents == true` ignores all mouse-related events including drag sessions is drawn from general AppKit `NSWindow` documentation knowledge (MEDIUM confidence, not independently re-verified against a fetched doc page this session) — flagged as the basis for the click-through/drag-in pitfall above and explicitly called out as needing on-device/spike verification before implementation, not treated as settled fact.

---
*Architecture research for: Islet v1.3 "Notch Shelf" milestone*
*Researched: 2026-07-09*
