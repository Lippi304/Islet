# Phase 20: Shelf View - Pattern Map

**Mapped:** 2026-07-09
**Files analyzed:** 6 (2 new source, 2 modified source, 2 new/extended test)
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Shelf/ShelfViewState.swift` (NEW) | model/store (`ObservableObject` published mirror) | event-driven (mirrors coordinator mutations) | `Islet/Notch/NowPlayingState.swift` | exact |
| `Islet/Notch/ShelfItemView.swift` (NEW) | component (SwiftUI leaf view) | request-response (tap/delete closures) | `Islet/Notch/BatteryIndicator.swift` | role-match (leaf view); gesture-scoping shape matches `transportButton` in `NotchPillView.swift` |
| `Islet/Notch/NotchPillView.swift` (MODIFY — extend `blobShape`, add `shelfRow`, add `shelfRowHeight` constant) | component (SwiftUI view) | request-response / transform (conditional layout) | same file, `mediaWingsOrToast` (conditional-height precedent) + `blobShape` (shape skeleton) + `transportButton` (scoped gesture) | exact (self-referential extension) |
| `Islet/Notch/NotchWindowController.swift` (MODIFY — own `ShelfCoordinator`+`ShelfViewState`, wire tap/delete/clear-all handlers, extend panel-sizing union) | controller (AppKit glue) | event-driven / CRUD (owns coordinator, forwards intents) | same file, `deviceCoordinator` ownership + `handleClick`/`makeRootView` closure-forwarding pattern; `positionAndShow` panel-union math | exact (self-referential extension) |
| `IsletTests/ShelfViewStateTests.swift` (NEW) | test | CRUD (published-mirror sync assertions) | `IsletTests/ShelfCoordinatorTests.swift` | role-match (real-disk-IO fixture convention) |
| `IsletTests/IslandResolverTests.swift` (MODIFY — append SHELF-09 gating test) | test | request-response (pure function assertions) | same file, `testSongChangeToastGateSuppressedWhenExpanded` | exact |

**Locked, consume-only (Phase 19, do NOT modify):** `Islet/Shelf/ShelfItem.swift`, `Islet/Shelf/ShelfLogic.swift`, `Islet/Shelf/ShelfCoordinator.swift`, `Islet/Shelf/ShelfFileStore.swift`.

## Pattern Assignments

### `Islet/Shelf/ShelfViewState.swift` (NEW — model/store)

**Analog:** `Islet/Notch/NowPlayingState.swift` (entire file, 39 lines)

**Full pattern to mirror:**
```swift
// Islet/Notch/NowPlayingState.swift lines 1-38
import AppKit   // (ShelfViewState needs only `import Foundation` — no NSImage field)

final class NowPlayingState: ObservableObject {
    @Published var presentation: NowPlayingPresentation = .none
    @Published var artwork: NSImage?
    @Published var isHealthy: Bool = true
    @Published var hasPlayedSinceLaunch: Bool = false
    @Published var songChangeToast: TrackToast? = nil
    @Published var position: PlaybackPosition?
}
```

**Concrete shape for the new file** (per RESEARCH.md's own worked example, consistent with this analog's "plain published holder: no methods, no timers" doctrine):
```swift
import Foundation

final class ShelfViewState: ObservableObject {
    @Published var items: [ShelfItem] = []
}
```

**Ownership contract to copy:** the controller is the ONLY writer (mirrors `nowPlayingState.presentation = p` assignments in `NotchWindowController.swift`, e.g. line 1008); the view only reads via `@ObservedObject`. Every `ShelfCoordinator.append/remove/clear` call in the controller must be followed by `shelfViewState.items = shelfCoordinator.logic.items` (Pitfall 3 in RESEARCH.md) — same discipline as `renderPresentation()` re-syncing `presentationState.presentation` after every resolver-affecting mutation (`NotchWindowController.swift` lines 476-478).

---

### `Islet/Notch/ShelfItemView.swift` (NEW — component)

**Analog 1 (leaf-view structure):** `Islet/Notch/BatteryIndicator.swift` (entire file, 62 lines) — a small, self-contained, reusable SwiftUI `View` struct taking plain value parameters (`level: Int`, `accent: Color`) and rendering itself with no external state, no AppKit. `ShelfItemView` should have the same shape: `let item: ShelfItem`, plain closures `onTap`/`onDelete`, no `@ObservedObject`.

**Analog 2 (scoped-gesture discipline — Finding 15):** `Islet/Notch/NotchPillView.swift` lines 622-632 (`transportButton`):
```swift
private func transportButton(_ systemName: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
    }
    .buttonStyle(.plain)
}
```
And the ancestor-gesture-avoidance comment at `NotchPillView.swift` lines 164-174 (Finding 15 fix) — the transport buttons sit in a region with NO ancestor `.onTapGesture` above them; `mediaExpanded`'s tap-to-toggle is scoped ONLY to the non-button top row (line 599, `.onTapGesture { onClick() }` attached to the `HStack` containing art/title/bars, never to the enclosing `VStack`).

**Concrete shape to build** (RESEARCH.md's own worked code example, directly usable):
```swift
struct ShelfItemView: View {
    let item: ShelfItem
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 2) {                                    // icon-gap: 2px per UI-SPEC
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.localURL.path))
                .resizable()
                .frame(width: 28, height: 28)                    // UI-SPEC: reuses transportButton's 28x28
            Text(item.filename)                                  // untrusted external data (V5)
                .font(.system(size: 9))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 44)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }                                // D-04: own scoped gesture, click-to-open
        .overlay(alignment: .topTrailing) {
            Button(action: onDelete) {                            // Finding 15 / D-05: sibling Button
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .accessibilityLabel(...)  // UI-SPEC Copywriting: "Open {filename}" / "Remove {filename}"
    }
}
```

**Error handling / missing-file guard (D-04):** NOT this view's job — the guard lives in the controller (see NotchWindowController.swift assignment below), per the existing convention that views stay AppKit-free and only report intent (`onClick`/`onTogglePlayPause` etc. in `NotchPillView.swift` lines 60-75).

---

### `Islet/Notch/NotchPillView.swift` (MODIFY — `blobShape` extension, `shelfRow`, constants)

**Analog (conditional-height blob, direct precedent):** `mediaWingsOrToast`, lines 314-334:
```swift
@ViewBuilder
private func mediaWingsOrToast(_ p: NowPlayingPresentation) -> some View {
    let toast = nowPlaying.songChangeToast
    let height = Self.wingsSize.height + (toast != nil ? Self.toastExtraHeight : 0)
    NotchShape(topCornerRadius: 6, bottomCornerRadius: toast != nil ? 16 : 6)
        .fill(Color.black)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.wingsSize.width, height: height)
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                mediaWingsRow(p, art: nowPlaying.artwork)
                if let toast {
                    toastTextRow(toast)
                        .transition(.opacity)
                }
            }
        }
        .onTapGesture { onClick() }
}
```

**Analog (the shape to extend):** `blobShape`, lines 234-244 (current signature, before this phase's shelf-aware extension):
```swift
private func blobShape<Content: View>(topCornerRadius: CGFloat,
                                       bottomCornerRadius: CGFloat,
                                       alignment: Alignment = .center,
                                       @ViewBuilder content: () -> Content) -> some View {
    NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
        .fill(Color.black)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.expandedSize.width, height: Self.expandedSize.height)
        .overlay(alignment: alignment) { content() }
        .onTapGesture { onClick() }
}
```
RESEARCH.md's Pattern 1 already works out the exact generalized replacement (add a `shelfItems: [ShelfItem]` parameter, compute `hasShelf`/`height`, wrap `content()` + conditional `shelfRow(shelfItems)` in a `VStack`) — copy that generalized version verbatim as the starting point, then wire the THREE existing callers (`expandedIsland` line 205-220, `mediaExpanded` line 573, `mediaUnavailable` line 638-645) to pass their shelf items through per D-02 (uniform across all three).

**Constants to add (co-located, same convention as `expandedSize`/`wingsSize`/`toastExtraHeight`):** lines 90-128 show the existing convention (`static let` with a long explanatory comment walking through the height math) — `shelfRowHeight` must follow the SAME format, and UI-SPEC.md already fixes its value at `56pt`.

**Row composition (new `shelfRow` helper) — RESEARCH.md's worked example, directly usable:**
```swift
private func shelfRow(_ items: [ShelfItem]) -> some View {
    ScrollView(.horizontal) {
        HStack(spacing: 10) {                                    // item-gap: 10px per UI-SPEC
            ForEach(items, id: \.id) { item in
                ShelfItemView(item: item,
                              onTap: { onShelfItemTap(item) },
                              onDelete: { onShelfItemDelete(item.id) })
            }
            Button(action: onShelfClearAll) {                     // SHELF-05: far-right delete-all
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)                                 // row-padding: 16px per UI-SPEC
    }
    .scrollIndicators(.never)
    .frame(height: Self.shelfRowHeight)
}
```
New closures (`onShelfItemTap`, `onShelfItemDelete`, `onShelfClearAll`) must be added to `NotchPillView`'s parameter list mirroring the EXISTING convention at lines 60-75 (`onClick`/`onTogglePlayPause`/`onNext`/`onPrevious` — all plain closures, all defaulted to no-ops so `#Preview`s keep compiling without a controller).

**Gesture-scoping warning to copy verbatim (Pitfall 2 in RESEARCH.md, Finding 15 in this file):** neither the shelf `HStack` nor `blobShape`'s own `.onTapGesture { onClick() }` (line 243) may sit as an ancestor above `ShelfItemView`'s `Button`s — the existing per-branch scoping comment at lines 164-174 is the citation to extend.

---

### `Islet/Notch/NotchWindowController.swift` (MODIFY — owns `ShelfCoordinator` + `ShelfViewState`, panel sizing, handlers)

**Analog (state-model ownership + injection into the view):** lines 85-98 (`presentationState`, `outfitState` declarations) and lines 856-868 (`makeRootView`):
```swift
// NotchWindowController.swift lines 856-868
private func makeRootView(accentIndex: Int) -> some View {
    NotchPillView(interaction: interaction,
                  nowPlaying: nowPlayingState,
                  presentationState: presentationState,
                  outfit: outfitState,
                  onClick: { [weak self] in self?.handleClick() },
                  onTogglePlayPause: { [weak self] in self?.nowPlayingMonitor?.togglePlayPause() },
                  onNext: { [weak self] in self?.nowPlayingMonitor?.nextTrack() },
                  onPrevious: { [weak self] in self?.nowPlayingMonitor?.previousTrack() })
        .environment(\.activityAccent, ActivitySettings.accent(for: accentIndex))
}
```
Add `shelfViewState: shelfViewState`, `onShelfItemTap: { [weak self] item in self?.handleShelfItemTap(item) }`, `onShelfItemDelete: { [weak self] id in self?.handleShelfItemDelete(id) }`, `onShelfClearAll: { [weak self] in self?.handleShelfClearAll() }` the same way.

**New properties to add** (mirroring the `let nowPlayingState = NowPlayingState()` declaration at line 139, and the `private let chargingState = ChargingActivityState()` at line 80):
```swift
private let shelfCoordinator = ShelfCoordinator()
let shelfViewState = ShelfViewState()
```

**Analog (missing-file guard, D-04 / Pitfall 4):** RESEARCH.md's own worked snippet — a deterministic guard BEFORE the AppKit call, mirroring this file's existing "never trust the framework's own failure path, guard explicitly" discipline (e.g. `licenseState.isEntitled` gating, `activityEnabled(_:)` gating):
```swift
private func handleShelfItemTap(_ item: ShelfItem) {
    guard FileManager.default.fileExists(atPath: item.localURL.path) else { return }  // D-04: silent no-op
    NSWorkspace.shared.open(item.localURL)
}

private func handleShelfItemDelete(_ id: UUID) {
    shelfCoordinator.remove(id: id)
    shelfViewState.items = shelfCoordinator.logic.items    // Pitfall 3: re-sync the published mirror
}

private func handleShelfClearAll() {
    shelfCoordinator.clear()
    shelfViewState.items = shelfCoordinator.logic.items
}
```

**Analog (panel pre-reservation, NEW risk this phase — Pattern 2 in RESEARCH.md):** `positionAndShow`, lines 589-599:
```swift
// NotchWindowController.swift lines 592, 598-599 (existing)
let expandedFrame = expandedNotchFrame(collapsed: collapsedFrame, expandedSize: expandedSize)
let wings = wingsFrame(collapsed: collapsedFrame, wingsSize: wingsSize)
let panelFrame = expandedFrame.union(wings)
```
Must become (per RESEARCH.md Pattern 2 — the panel reserves the shelf band UNCONDITIONALLY, transparent when empty, same principle as `expandedSize`'s own always-reserved 144pt):
```swift
let expandedFrame = expandedNotchFrame(
    collapsed: collapsedFrame,
    expandedSize: CGSize(width: expandedSize.width,
                          height: expandedSize.height + NotchPillView.shelfRowHeight))
```
Source of truth for `NotchGeometry.expandedNotchFrame`/`wingsFrame`: `Islet/Notch/NotchGeometry.swift` lines 68-83 (both are thin wrappers around `topPinnedFrame`, pure/testable, no changes needed to this file itself — only the `CGSize` fed into `expandedNotchFrame` from the controller changes).

**Analog (SHELF-09 "falls out for free" — no new resolver code):** `Islet/Notch/IslandResolver.swift`'s `resolve(...)` (lines 34-54) already returns `.charging`/`.device` BEFORE ever reaching `.nowPlayingExpanded`/`.expandedIdle` — the controller composes the shelf row only inside `blobShape`'s three callers, which the `.charging(let a): wings(for: a)` / `.device(let d): deviceWings(for: d)` branches in `NotchPillView.body` (lines 145-148) never invoke. No controller-side gating code is needed beyond NOT passing shelf items into `wings`/`deviceWings`.

**Analog (deinit teardown convention, if the shelf coordinator ever needs cleanup):** lines 1122-1166 show the deinit's owner-driven teardown discipline (`powerMonitor.stop()`, `bluetoothMonitor?.stop()`, etc.) — `ShelfCoordinator` currently needs no explicit teardown (no live OS registration), so no deinit addition is expected, but if a future app-quit hook calls `shelfCoordinator.clear()` (per `ShelfCoordinator.swift`'s own header comment), this is the site to wire it.

---

### `IsletTests/ShelfViewStateTests.swift` (NEW — test)

**Analog:** `IsletTests/ShelfCoordinatorTests.swift` (entire file, 100 lines) — real-disk-IO fixture convention:
```swift
// IsletTests/ShelfCoordinatorTests.swift lines 10-25
@MainActor
final class ShelfCoordinatorTests: XCTestCase {
    private var fixturesDir: URL!

    override func setUp() {
        super.setUp()
        fixturesDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ShelfCoordinatorTestsFixtures-\(UUID())", isDirectory: true)
        try? FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fixturesDir)
        fixturesDir = nil
        super.tearDown()
    }

    private func makeRealItem(named name: String) throws -> ShelfItem {
        let source = fixturesDir.appendingPathComponent(name)
        try Data("bytes-\(name)".utf8).write(to: source)
        let id = UUID()
        let localURL = try ShelfFileStore.makeSessionCopy(of: source, id: id)
        return ShelfItem(id: id, originalURL: source, localURL: localURL, filename: name, addedAt: Date())
    }
    // ... tests call coordinator.append/remove/clear and assert FileManager.default.fileExists
}
```
`ShelfViewStateTests` should reuse the SAME `fixturesDir`/`makeRealItem` fixture (real files, not fabricated URLs — Pitfall 5 in RESEARCH.md) but assert on `ShelfViewState.items` staying in sync after each `ShelfCoordinator` mutation is applied through the same resync call the controller uses (`shelfViewState.items = shelfCoordinator.logic.items`), covering SHELF-04/SHELF-05.

**Also test the D-04 guard as a small pure decision** (mirrors `IslandResolverTests.swift`'s style of testing pure gates directly, e.g. `testNowPlayingHealthGateForcesNeutralWhenDisabled` at lines 75-82) — if the planner extracts the fileExists-guard into a tiny pure/testable helper (e.g. `shouldOpenShelfItem(fileExists:) -> Bool`), test it the same direct-assertion way, no XCTest fixture needed for the pure half.

---

### `IsletTests/IslandResolverTests.swift` (MODIFY — append one test)

**Analog (style to copy exactly):** `testSongChangeToastGateSuppressedWhenExpanded`, lines 141-145:
```swift
func testSongChangeToastGateSuppressedWhenExpanded() {
    // D-04: a manually-expanded island suppresses the toast (the expanded card already
    // shows the live title/artist).
    XCTAssertFalse(songChangeToastGate(activeTransient: nil, isExpanded: true, toastEnabled: true))
}
```
For SHELF-09, add an assertion confirming `resolve(...)` returns `.charging`/`.device` (never `.nowPlayingExpanded`/`.expandedIdle`/`.nowPlayingWings`) whenever `activeTransient` is non-nil, reusing `testChargingOutranksDeviceAndMedia` (lines 18-27) and `testDeviceOutranksAmbientMedia` (lines 29-37) as the direct structural proof that the shelf-composing branches are unreachable while a transient is active — no new production code in `IslandResolver.swift` itself (SHELF-09 "falls out for free").

## Shared Patterns

### Published-mirror state ownership
**Source:** `Islet/Notch/NowPlayingState.swift` (whole file) + `NotchWindowController.swift` lines 476-478 (`renderPresentation()`)
**Apply to:** `ShelfViewState.swift` (new) and every `ShelfCoordinator` mutation site in `NotchWindowController.swift`.
```swift
final class NowPlayingState: ObservableObject {
    @Published var presentation: NowPlayingPresentation = .none
    // ...
}
// controller:
private func renderPresentation() {
    presentationState.presentation = currentPresentation()
}
```

### Scoped tap-gesture discipline (Finding 15)
**Source:** `Islet/Notch/NotchPillView.swift` lines 164-174 (comment) + lines 622-632 (`transportButton`)
**Apply to:** `ShelfItemView.swift` (item-open + trash Button) and the delete-all Button in `NotchPillView.swift`'s new `shelfRow`.
```swift
Button(action: action) {
    Image(systemName: systemName)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 28, height: 28)
}
.buttonStyle(.plain)
```

### Conditional-height single-shape morph (no cross-fade, D-07)
**Source:** `Islet/Notch/NotchPillView.swift` lines 314-334 (`mediaWingsOrToast`)
**Apply to:** `blobShape`'s shelf-aware extension — one `NotchShape`, height grows conditionally, content composed in a `VStack` with `.transition(.opacity)` on the new conditional row.

### Panel pre-reservation, never a live resize
**Source:** `Islet/Notch/NotchWindowController.swift` lines 589-599 (`positionAndShow`) + `Islet/Notch/NotchGeometry.swift` lines 68-83 (`expandedNotchFrame`/`wingsFrame`)
**Apply to:** the controller's shelf-band height addition to `expandedFrame`'s `CGSize` — computed ONCE at `positionAndShow` time, from the SAME `NotchPillView.shelfRowHeight` constant the view's conditional paint reads.

### Missing-resource guard before an AppKit side-effecting call
**Source:** RESEARCH.md Pitfall 4's worked example, consistent with this file's existing "guard explicitly, never trust the framework" convention (e.g. `activityEnabled(_:)`, `licenseState.isEntitled`)
**Apply to:** `handleShelfItemTap` in `NotchWindowController.swift` — `guard FileManager.default.fileExists(...) else { return }` before `NSWorkspace.shared.open(...)`.

## No Analog Found

None — every file in this phase has at least a role-match analog already in the codebase; the two source files are additive to two ALREADY existing files whose exact extension points (`blobShape`, `positionAndShow`, `makeRootView`) are directly cited above.

## Metadata

**Analog search scope:** `Islet/Notch/`, `Islet/Shelf/`, `IsletTests/` (full directory listing enumerated; no framework-level search needed — every analog lives in these three directories).
**Files scanned (read in full or targeted range):** `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/BatteryIndicator.swift`, `Islet/Notch/NowPlayingState.swift`, `Islet/Notch/NotchGeometry.swift`, `Islet/Notch/IslandResolver.swift`, `Islet/Shelf/ShelfCoordinator.swift`, `Islet/Shelf/ShelfItem.swift`, `IsletTests/IslandResolverTests.swift`, `IsletTests/ShelfCoordinatorTests.swift`.
**Pattern extraction date:** 2026-07-09
