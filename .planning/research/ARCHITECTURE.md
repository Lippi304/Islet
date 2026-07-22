# Architecture Research

**Domain:** macOS menu-bar clipboard history, integrating into an existing SwiftUI/AppKit notch app (Islet)
**Researched:** 2026-07-22
**Confidence:** HIGH (based on direct reading of Islet's own source — `AppDelegate.swift`, `Islet/Notch/*Monitor.swift`, `Islet/Notch/DragDropSupport.swift`, `Islet/Notch/NotchWindowController.swift`, `Islet/Shelf/ShelfFileStore.swift`, `Islet/Licensing/KeychainLicenseStore.swift`, `.planning/PROJECT.md` — not external/generic best practice)

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│  AppDelegate  (owns the status-bar world — NOT NotchWindowController) │
├──────────────────────────────────────────────────────────────────────┤
│  ┌────────────────┐   ┌───────────────────┐   ┌───────────────────┐  │
│  │  statusItem /   │   │  ClipboardMonitor │   │  notchController  │  │
│  │  menu (existing)│◄──┤  (NEW — system    │   │  (existing,       │  │
│  │  Settings/Check │   │  glue: Timer +    │   │  UNTOUCHED)        │  │
│  │  for Updates/   │   │  NSPasteboard     │   └───────────────────┘  │
│  │  Quit           │   │  .general poll)   │                          │
│  └────────▲────────┘   └─────────┬─────────┘                          │
│           │                      │ onChange(ClipboardItem)            │
│           │              ┌───────▼─────────┐                          │
│           │              │  ClipboardStore │  (NEW — pure reducer:    │
│           │              │  (in-memory      │  add/evict/clear/cap)  │
│           │              │  [ClipboardItem])│                          │
│           │              └───────┬─────────┘                          │
│           │                      │ persist/load                       │
│           │              ┌───────▼─────────┐                          │
│           └──────────────┤ ClipboardFileStore│ (NEW — real disk I/O: │
│         menuWillOpen()   │ Application Support│ JSON + image blobs)  │
│         rebuilds items   └───────────────────┘                        │
├──────────────────────────────────────────────────────────────────────┤
│  NotchWindowController / IslandResolver / TransientQueue              │
│  — completely UNTOUCHED. Zero coupling in either direction.           │
└──────────────────────────────────────────────────────────────────────┘
```

This is a **second, independent tree hanging off `AppDelegate`**, parallel to (not inside) the existing `notchController` tree. Islet already has exactly this shape once, informally: Phase 40's Sparkle `updaterController` and the update-dot `NSView` are owned and driven entirely by `AppDelegate`, never touching `NotchWindowController`/`IslandResolver`. Clipboard history is the second instance of that same "AppDelegate-owned side system" shape — not a new architectural category.

### Component Responsibilities

| Component | Responsibility | Typical Implementation (mirrors) |
|-----------|----------------|------------------------|
| `ClipboardItem` | Pure value type: id, kind (text/image), content, timestamp | `ShelfItem`, `PowerReading` — Foundation-only struct, `Equatable`/`Codable` |
| `ClipboardStore` | Pure in-memory reducer: append, evict-oldest-past-cap, clear-all, no I/O | `ShelfLogic` — pure, side-effect-free, unit-tested in isolation |
| `ClipboardFileStore` | The ONE place that touches `FileManager`/disk for clipboard data | `ShelfFileStore` — "the ONE place that performs real FileManager I/O", kept a standalone enum, not a method on the pure reducer |
| `ClipboardMonitor` | Thin system glue: `Timer`/`DispatchSourceTimer` polling `NSPasteboard.general.changeCount`, reading text/image content, filtering concealed/transient types, calling `onChange` | `PowerSourceMonitor`/`FocusModeMonitor`/`AudioOutputMonitor` — `@MainActor` class, `init(onChange:)`, idempotent `start()`, `nonisolated stop()` for deinit teardown |
| `AppDelegate` (modified) | Owns `clipboardMonitor` and `ClipboardStore` alongside existing `statusItem`; becomes (or adopts a small helper conforming to) `NSMenuDelegate` to rebuild the clipboard section on `menuWillOpen`/`menuNeedsUpdate`; adds "Delete All History" action | Existing `AppDelegate` already owns `notchController`, `updaterController` as sibling stored properties — clipboard follows the same pattern |

## Recommended Project Structure

```
Islet/
├── Clipboard/                      # NEW top-level folder, sibling to Notch/Shelf/Licensing
│   ├── ClipboardItem.swift         # pure model (text/image, id, timestamp, kind)
│   ├── ClipboardStore.swift        # pure reducer (add/evict/clear/cap) — Foundation only
│   ├── ClipboardFileStore.swift    # real FileManager I/O (Application Support JSON + image blobs)
│   └── ClipboardMonitor.swift      # THE ONE file that polls NSPasteboard.general
├── AppDelegate.swift                # MODIFIED — owns clipboardMonitor + store, rebuilds menu
```

### Structure Rationale

- **New top-level `Clipboard/` folder**, not nested under `Notch/`: this codebase's existing folder boundaries already track feature ownership, not layer (`Notch/` = notch-panel-owned subsystems, `Shelf/` = shelf-owned, `Licensing/` = license-owned). Clipboard is owned by `AppDelegate`/the status bar, never by `NotchWindowController` — putting `ClipboardMonitor.swift` inside `Islet/Notch/` alongside `PowerSourceMonitor.swift` would misrepresent who owns and starts it, even though the *class shape* mirrors those monitors closely.
- **Four files, not fewer**: this is the same file count Phase 19 (Shelf) used for an equivalent-complexity feature (`ShelfItem` + `ShelfLogic` + `ShelfFileStore`, three files) plus one extra file because clipboard needs a genuinely separate system-polling glue class that Shelf never needed (Shelf has no live external data source — it's purely user-drag-initiated). Do not add a fifth file for menu-building; see Pattern 3 below.

## Architectural Patterns

### Pattern 1: Monitor-as-isolation-seam, WITHOUT `IslandResolver` participation

**What:** `ClipboardMonitor` mirrors the established Monitor convention exactly at the *class* level — one file touching the one fragile/external API (`NSPasteboard.general`), `@MainActor`, constructor-injected `onChange` closure, idempotent `start()`, `nonisolated stop()` for deinit — but does NOT feed `IslandResolver`, `TransientQueue`, or any `NotchWindowController` presentation state.

**When to use:** Whenever a feature needs to isolate a single risky/external macOS API behind a testable seam, regardless of whether that feature's output ever reaches the notch UI. The Monitor pattern in this codebase is about *API isolation*, not about *being an Island activity* — those are two separate axes that happen to have always coincided until now.

**Is "no resolver participation" consistent with precedent?** Yes, with one caveat. It is consistent with the *isolation-seam* half of the pattern (every Monitor's job is "wrap one fragile system call, publish a callback, own start/stop lifecycle" — nothing in that contract requires the caller to be `NotchWindowController` or to funnel into `IslandResolver`). Precedent already shows partial versions of this: `AudioOutputMonitor` feeds a device-list UI, not an `IslandResolver` activity tier — its own header explicitly notes it is "DELIBERATELY independent" from other monitors' state. The caveat is ownership: every existing Monitor is constructed and started by `NotchWindowController` (`Islet/Notch/NotchWindowController.swift`), because every existing feature's consumer lives there. `ClipboardMonitor`'s consumer is `AppDelegate`, so `AppDelegate` must be the one that constructs it, calls `start()`, and tears it down on quit — a new *owner*, but not a new *shape*.

**Trade-offs:** Keeping the Monitor shape (rather than inventing something bespoke) buys immediate familiarity for a first-time-programmer codebase and a consistent testing story (fixture-injectable `onChange`), at the cost of `AppDelegate` picking up one more owned subsystem alongside `statusItem`/`updaterController` — acceptable; `AppDelegate` already owns 3 independent subsystems (notch controller, Sparkle updater, debug status item) with no shared coupling between them.

**Example (shape, not exact code):**
```swift
@MainActor
final class ClipboardMonitor {
    private nonisolated(unsafe) var timer: DispatchSourceTimer?
    private nonisolated(unsafe) var running = false
    private var lastChangeCount = NSPasteboard.general.changeCount
    private let onChange: (ClipboardItem) -> Void

    init(onChange: @escaping (ClipboardItem) -> Void) { self.onChange = onChange }

    func start() {
        guard !running else { return }
        running = true
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: 0.4, leeway: .milliseconds(100)) // CopyClip-class responsiveness
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        guard !pb.types.map(\.rawValue).contains(where: {
            $0 == "org.nspasteboard.ConcealedType" || $0 == "org.nspasteboard.TransientType"
        }) else { return }
        // classify text vs image, build a ClipboardItem, call onChange
    }

    nonisolated func stop() { timer?.cancel(); timer = nil; running = false }
    deinit { /* owner (AppDelegate) calls stop() explicitly, same discipline as every other Monitor */ }
}
```
No protocol seam (unlike `NowPlayingMonitor`'s `NowPlayingService` protocol) is needed here — the protocol treatment in this codebase is reserved for the one genuinely fragile *private* API (MediaRemote); `NSPasteboard` is a fully public, stable AppKit API, matching the plain-concrete-class shape of `PowerSourceMonitor`/`FocusModeMonitor`/`AudioOutputMonitor`, none of which have a protocol wrapper either.

### Pattern 2: Pure reducer + separate disk-I/O glue (mirrors Shelf, not Keychain)

**What:** Split "what the data looks like and how it changes" (`ClipboardItem` + `ClipboardStore`, pure Foundation, zero `FileManager`/`NSPasteboard` imports) from "how it touches disk" (`ClipboardFileStore`, the only file with real I/O) — exactly Phase 19's `ShelfItem`/`ShelfLogic` vs `ShelfFileStore` split, not Phase 10's `KeychainLicenseStore` shape (which conflates storage + logic in one file, acceptable there because it stores exactly one scalar license blob, not a growing/evicting collection).

**When to use:** Any time the data is a *collection with lifecycle rules* (cap, eviction, ordering) rather than a single persisted value — clipboard history (a capped, evicting list) is structurally the shelf's twin, not the license store's.

**Trade-offs:** One more file than the license-store shape, but `ClipboardStore`'s eviction-at-cap logic becomes independently unit-testable with zero disk fixtures, mirroring how `ShelfLogic` is tested without ever touching `NSTemporaryDirectory()`.

### Pattern 3: No new "menu builder" type — extend `AppDelegate` as `NSMenuDelegate`

**What:** Rather than inventing a `ClipboardMenuBuilder` class, `AppDelegate` adopts `NSMenuDelegate` and implements `menuNeedsUpdate(_:)` (or `menuWillOpen(_:)`) to remove and re-insert the clipboard `NSMenuItem`s above the existing Settings…/Check for Updates…/Quit block every time the menu is about to open. Any genuinely pure logic (which items to show, label truncation, `⌘0`–`⌘9` assignment) is extracted as small top-level functions taking `[ClipboardItem]` and returning plain data (e.g. `(title: String, key: String)` tuples) — mirroring `DragDropSupport.swift`'s existing convention of pure top-level functions (`fileURLs(from:)`, `shouldAcceptDrop`) sitting right next to the AppKit code that consumes them, rather than a full separate type.

**When to use:** When menu construction has some pure logic worth unit-testing (truncation, key assignment, ordering) but the actual `NSMenuItem`/`NSMenu` object graph is a thin, un-abstracted AppKit call site — matching how `AppDelegate.applicationDidFinishLaunching` already builds the existing static menu inline, and how Phase 40's debug menu (`setupDebugMenu()`) is a private `AppDelegate` method, not a separate builder class.

**Trade-offs:** Keeps `AppDelegate.swift` growing (it is already the largest "glue" file in the app by role, not LOC), but avoids a one-off abstraction for a menu that is rebuilt in exactly one place. If `AppDelegate` becomes unwieldy, this is a candidate for a later "Claude's Discretion" extraction — not a Phase-1 concern.

## Data Flow

### Capture Flow

```
User copies (⌘C in any app, or a password manager writes ConcealedType)
    ↓
ClipboardMonitor's Timer tick reads NSPasteboard.general.changeCount
    ↓ (only on a genuine delta — mirrors DragDropSupport's isGenuineFileDrag delta-gate discipline)
ClipboardMonitor checks pb.types for org.nspasteboard.ConcealedType / TransientType → drop silently if present
    ↓
ClipboardMonitor builds a ClipboardItem (text or image), calls onChange(item)
    ↓
AppDelegate hands the item to ClipboardStore.add(item) — pure: appends, evicts oldest past the ~20-30 cap
    ↓
AppDelegate calls ClipboardFileStore.save(items) — persists to Application Support (debounced/async off the poll path)
```

### Menu-Open / Click-Back Flow

```
User clicks the status-bar icon
    ↓
NSMenuDelegate.menuNeedsUpdate(_:) fires (AppDelegate)
    ↓
AppDelegate reads ClipboardStore's current items, rebuilds the clipboard NSMenuItems above the static block
    ↓
User clicks a clip → its action sets NSPasteboard.general (setString/writeObjects), NOT auto-paste
    ↓
IMPORTANT: this write bumps NSPasteboard.general.changeCount again — ClipboardMonitor's own
click-back write must be excluded from re-capture (see Anti-Pattern 3), or the app will
immediately re-add its own click-back write as a "new" clip.
```

### Launch Flow

```
applicationDidFinishLaunching (existing)
    ↓
ClipboardFileStore.load() → seeds ClipboardStore's in-memory list from Application Support (survives relaunch + reboot)
    ↓
ClipboardMonitor(onChange: ...).start() — begins polling from the CURRENT changeCount baseline,
    seeded at init (NOT count 0), so nothing already on the pasteboard before launch is captured as new
```

## Storage Location — New Convention Needed

Islet currently has exactly **two** storage precedents, and **neither fits** clipboard history:

| Existing precedent | What it stores | Why it doesn't fit clipboard history |
|---|---|---|
| **Keychain** (`KeychainLicenseStore.swift`) | Trial start date, license validation cache — tiny scalar values, deliberately tamper-resistant | Wrong shape (Keychain is for small secrets/scalars, not a growing list of arbitrary text/image blobs) and wrong intent (Keychain's whole point here is surviving `defaults delete`/reinstall — clipboard history has no such tamper-resistance requirement) |
| **`NSTemporaryDirectory()/IsletShelf/<uuid>/`** (`ShelfFileStore.swift`) | Session-only dropped files | Explicitly, deliberately non-persistent by design (PROJECT.md v1.9 goal calls out persistence across relaunch/reboot as "an explicit, deliberate difference" from the Shelf) — using temp storage would be actively wrong here |

**No existing Application Support / cache directory usage exists anywhere in the codebase** (confirmed: zero hits for `applicationSupportDirectory` across `Islet/`). This is genuinely new territory, not a gap in research.

**Recommendation:** `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent(Bundle.main.bundleIdentifier ?? "Islet").appendingPathComponent("ClipboardHistory", isDirectory: true)` — the standard Apple-sanctioned location for app-owned persistent data that isn't a system secret and isn't disposable, following the exact same "create the directory lazily, one dedicated subfolder" shape `ShelfFileStore` already uses for its temp root, just rooted at Application Support instead of `NSTemporaryDirectory()`. Store a small JSON index (array of `ClipboardItem` metadata + text content inline) plus per-item image blobs written to `<uuid>.png` files alongside it — mirroring `ShelfFileStore`'s per-item-UUID-subfolder pattern, adapted from "session temp copy of a dropped file" to "persisted copy of an image clip."

## Scaling Considerations

| Scale | Approach |
|---|---|
| ~20-30 items (the spec'd cap) | Flat JSON index + loose image files is trivially sufficient — no database needed |
| If the cap were later raised to hundreds/thousands | Would be the trigger to reconsider (rewriting one JSON index file on every eviction stops being cheap) — explicitly NOT a v1.9 concern given the locked ~20-30 cap |
| Image size growth (very large screenshots copied) | Not addressed by REQUIREMENTS.md — worth a phase-planning question (downscale/compress before persisting?) rather than assumed; out of scope for this architecture note |

## Anti-Patterns to Avoid

### Anti-Pattern 1: Routing clipboard state through `IslandResolver`/`TransientQueue`

**What people might do:** Since every other Monitor's output eventually reaches `IslandResolver`, it would be tempting to add a `.clipboard` case "for consistency."
**Why it's wrong:** The user has explicitly, already decided clipboard history is status-bar-menu-only, not an Island/notch view (locked in PROJECT.md — not to be re-litigated). Threading it through `IslandResolver` would violate that decision and needlessly couple two independent UI surfaces (status-bar `NSMenu` vs. the notch `NSPanel`) that this codebase has otherwise always kept cleanly separate.
**Do this instead:** `ClipboardMonitor` → `ClipboardStore` → `AppDelegate`'s menu rebuild, full stop. Zero import of `IslandResolver.swift`, `TransientQueue.swift`, or `NotchWindowController.swift` anywhere in the clipboard code path.

### Anti-Pattern 2: A single shared pasteboard-poller for both drag-detection and clipboard history

**What people might do:** Notice both features "poll a pasteboard's `changeCount`" and try to unify them into one shared poller class to avoid "two pollers."
**Why it's wrong:** They poll two *different* `NSPasteboard` instances that are unrelated at the API level. There is no `DragApproachDetector` class in this codebase (the question's premise names one, but it doesn't exist as a separate type) — the equivalent logic is inline in `NotchWindowController.swift`'s `handleDragApproachTick()`/`recheckDragAcceptRegion(currentChangeCount:)`, plus pure helpers in `Islet/Notch/DragDropSupport.swift` (`fileURLs(from:)`, `isGenuineFileDrag(...)`). That existing code reads `NSPasteboard(name: .drag)` — the OS's dedicated, ephemeral drag-session pasteboard — NOT `NSPasteboard.general` (the ordinary copy/paste clipboard clipboard history needs). These have independent `changeCount` sequences and independent trigger cadences: the drag-tick code only runs while a `.leftMouseDragged` global `NSEvent` monitor is actively firing (i.e., only during a live OS drag gesture), while the clipboard poller must run continuously in the background regardless of mouse activity (a `⌘C` in another app has no mouse-drag component at all). Unifying them would force a background-always-running timer to also drive drag detection (wasteful and architecturally backwards) or force drag-only ticking onto clipboard capture (would miss the vast majority of real copies). **There is no actual race, conflict, or duplicated work risk between the two today** — they don't touch the same object.
**Do this instead:** Two independent, differently-triggered pollers, exactly as the question's premise assumed needed reconciling — but they don't. `ClipboardMonitor` gets its own `DispatchSourceTimer` (mirroring `FocusModeMonitor`'s shape, but at a much shorter interval — sub-second, matching CopyClip-class responsiveness — vs. Focus's deliberate 2.5s), fully independent of `NotchWindowController`'s drag-tick lifecycle. The one thing worth carrying over from the drag detection code is the *pattern*, not a shared instance: cache the last-seen `changeCount`, only do real work (read pasteboard contents, classify, persist) on an actual delta — the same discipline `isGenuineFileDrag`'s delta-gate already proves out in this codebase.

### Anti-Pattern 3: Re-capturing the app's own click-to-copy-back write as a new history item

**What people might do:** Naively poll `changeCount` and treat every delta as "the user copied something new," including the delta the app itself just caused by writing the clicked item back onto `NSPasteboard.general`.
**Why it's wrong:** Would cause every click-back to immediately re-insert itself as a duplicate "most recent" entry, corrupting ordering and burning one eviction slot per click.
**Do this instead:** When `AppDelegate` writes a clip back onto the pasteboard, update `ClipboardMonitor`'s cached `lastChangeCount` synchronously to the post-write value (a setter the monitor exposes, or simply re-reading `changeCount` immediately after the write) before the next poll tick — a small, deliberate seam, not a race condition to leave to chance.

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `ClipboardMonitor` ↔ `AppDelegate` | Constructor-injected `onChange: (ClipboardItem) -> Void` closure, called on main (mirrors every existing Monitor's `onChange` contract) | `AppDelegate`, not `NotchWindowController`, is the owner — the one real shape deviation from precedent |
| `ClipboardStore` ↔ `ClipboardFileStore` | `ClipboardStore` is pure/in-memory; `AppDelegate` (or a small coordinator) explicitly calls `ClipboardFileStore.save(...)`/`.load()` around store mutations — mirrors how `ShelfCoordinator` sits between `ShelfLogic` and `ShelfFileStore` rather than either touching the other directly | Keep `ClipboardStore` unaware that persistence exists at all, same as `ShelfLogic` |
| `AppDelegate` ↔ existing `statusItem`/`menu` | `NSMenuDelegate.menuNeedsUpdate(_:)` inserts/removes clipboard `NSMenuItem`s above the existing Settings…/Check for Updates…/Quit block on every open | The existing menu-construction code (the `menu.addItem(...)` calls in `applicationDidFinishLaunching`) is the one place genuinely touched/extended, not replaced |
| `ClipboardMonitor`/`ClipboardStore`/`ClipboardFileStore` ↔ `NotchWindowController`/`IslandResolver`/`TransientQueue` | **None.** Zero imports, zero shared state, zero calls in either direction | Explicit, locked user decision — see Anti-Pattern 1 |
| `ClipboardMonitor` ↔ `NotchWindowController`'s existing drag-tick polling code | **None — independent `NSPasteboard` instances, independent timers.** See Anti-Pattern 2 | Correcting a reasonable but incorrect premise: no shared-poller work is needed |

## Build Order

Mirrors this project's own repeated "pure seam(s) first, system glue second, assembly/UI last" sequencing — Phase 19→20→21 (Shelf: data model → view → drag-out), Phase 47→48 (Audio Output: pure seam → live glue+UI wiring), Phase 38's internal 01→05 ordering (spike the risky API path before building the full monitor), and Phase 4's `NowPlayingPresentation` (pure)-before-`NowPlayingMonitor` (glue)-before-view ordering.

1. **`ClipboardItem` + `ClipboardStore`** — pure Foundation, zero AppKit/`NSPasteboard`/`FileManager` imports. Unit-test cap-eviction, ordering, clear-all exhaustively. Zero risk, no device/system dependency, can be fully verified before anything else exists — exactly Phase 19's `ShelfItem`/`ShelfLogic` role.
2. **`ClipboardFileStore`** — real Application Support I/O (JSON index + image blobs), still fully unit-testable against an injectable root URL (learn from `ShelfFileStore`'s one gap: it hardcodes `NSTemporaryDirectory()` directly, making it harder to redirect in tests — worth injecting the root URL as a parameter here from the start so tests never touch the real `~/Library/Application Support/`). No live pasteboard involved yet.
3. **`ClipboardMonitor`** — the one genuinely risky, on-device-only-verifiable seam: `NSPasteboard.general` polling cadence, concealed/transient-type exclusion, text-vs-image classification, the click-back re-capture guard (Anti-Pattern 3). Verify standalone via a console-log/manual on-device check (copy various content types, including from a password manager if available, confirm exclusion) BEFORE any menu UI exists — mirrors Phase 38's spike-the-API-path-first approach for `INFocusStatusCenter`, and Phase 22-01's "spike the risky mechanism before building the full feature around it" precedent.
4. **`AppDelegate` menu wiring** — `NSMenuDelegate` dynamic rebuild, click-to-copy-back (with the changeCount guard from step 3), "Delete All History" action, `⌘0`–`⌘9` quick-select. Last, because it's pure assembly of the three already-proven pieces, and because menu rendering/shortcut behavior is itself only meaningfully verifiable on-device (matching this project's consistent "UI/wiring is the on-device-only step, done last" pattern).

This ordering isolates the one real integration risk (item 3: does `org.nspasteboard.ConcealedType`/`TransientType` filtering actually work against a real password manager, does image-vs-text classification handle real-world pasteboard content correctly) into its own phase, so a spike/iteration there — like Phase 22's drag-in isolation — cannot block or destabilize the already-proven pure model/persistence work from phases 1-2.

## Sources

- Direct source read: `Islet/AppDelegate.swift`, `Islet/Notch/PowerSourceMonitor.swift`, `Islet/Notch/FocusModeMonitor.swift`, `Islet/Notch/AudioOutputMonitor.swift`, `Islet/Notch/NowPlayingMonitor.swift`, `Islet/Notch/DragDropSupport.swift`, `Islet/Notch/NotchWindowController.swift`, `Islet/Shelf/ShelfFileStore.swift`, `Islet/Licensing/KeychainLicenseStore.swift`, `Islet/ActivitySettings.swift` — all HIGH confidence, verified by reading actual code, not summarized from memory
- `.planning/PROJECT.md` — milestone goal, locked decisions (status-bar-only, persistence-across-reboot, concealed/transient exclusion), Key Decisions table (pure-seam-first precedent across Phases 15/19/22-01/24-01/38-01/39-01/47)
- [NSPasteboard.org — Identifying and Handling Transient or Special Data on the Clipboard](https://nspasteboard.org/) — confirms `org.nspasteboard.TransientType` (never record/display) and `org.nspasteboard.ConcealedType` (sensitive, password-manager convention) semantics, MEDIUM-HIGH confidence (community-authored de facto standard, not an Apple API, but the exact convention PROJECT.md already names)

---
*Architecture research for: macOS clipboard-history menu-bar feature integration into Islet*
*Researched: 2026-07-22*
