# Phase 45: View Switcher Morph Fix - Pattern Map

**Mapped:** 2026-07-19
**Files analyzed:** 2 (1 modified source file, 1 modified test file — no new files this phase)
**Analogs found:** 2 / 2 (both analogs are internal to the same codebase, one of them in the SAME file being edited — this is a self-referential refactor, not new-capability code)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/NotchPillView.swift` (`presentationSwitch`, `blobShape`, `homeEmptyState`, `calendarFullView`, `weatherFullView`, `trayFullView`, `mediaExpanded`, `mediaUnavailable`) | component (SwiftUI view, render tier) | event-driven (state-driven re-render on `IslandPresentation` change) | Same file, `body`'s own outer `.frame(width:height:)` ternary at lines 888-895 | exact — this is the established in-file convention for "compute a value per case, don't branch the View" |
| `IsletTests/NotchPillViewTests.swift` (new width/height-mapping regression test) | test | request-response (pure property assertions on a directly-instantiated view) | `testShelfStripVisibleIsAlwaysFalse` (lines 14-40, same file) | exact — same `@MainActor` XCTest class, same direct-`NotchPillView`-instantiation + property-assertion pattern, same `private → internal` visibility-bump precedent |

No other files are created or modified by this phase (confirmed by RESEARCH.md's Architectural Responsibility Map: `NotchWindowController.swift`, `ViewSwitcherState.swift`, `IslandResolver.swift` are explicitly untouched — the three-site rule geometry and the tap-intent controller are already correct).

## Pattern Assignments

### `Islet/Notch/NotchPillView.swift` — `presentationSwitch` (component, event-driven)

**Analog:** the file's own outer `body` frame ternary (same file, lines 888-895) — this is the precedent the fix must replicate one level deeper.

**The bug site — `presentationSwitch`** (lines 774-816):
```swift
@ViewBuilder
private var presentationSwitch: some View {
    switch presentation {
    ...
    case .nowPlayingExpanded(let p, true):
        mediaExpanded(p, art: nowPlaying.artwork)                        // NOW-01/02 controls (healthy)
    case .nowPlayingExpanded(_, false):
        mediaUnavailable                                                 // D-12 "nicht verfügbar"
    case .homeLastPlayed:
        mediaExpanded(.paused(title: nowPlaying.lastKnownTrack?.title ?? "",
                               artist: nowPlaying.lastKnownTrack?.artist ?? ""),
                      art: nowPlaying.lastKnownTrack?.artwork)
    case .homeEmpty:
        homeEmptyState                                                   // Phase 30 / HOME-03
    case .calendarExpanded:
        calendarFullView                                                 // Phase 28 / CALVIEW-01
    case .weatherExpanded:
        weatherFullView                                                  // 28-04 round 4
    case .trayExpanded:
        trayFullView                                                     // 28-04 round 5
    ...
    }
}
```
Each of the 6 branches (`homeEmptyState`, `calendarFullView`, `weatherFullView`, `trayFullView`, and the two `mediaExpanded(...)` call variants + `mediaUnavailable`) independently calls `blobShape(...)` — that is the structural-identity break. `IslandResolver.swift:109-114`'s `showsSwitcherRow(for:)` confirms exactly these 6 cases (not 4) are in scope:
```swift
func showsSwitcherRow(for presentation: IslandPresentation) -> Bool {
    switch presentation {
    case .homeLastPlayed, .homeEmpty, .calendarExpanded, .weatherExpanded, .trayExpanded, .nowPlayingExpanded: return true
    default: return false
    }
}
```

**Core pattern to copy — "compute a value per case, don't branch the View"** (already proven at lines 888-895 of the SAME file):
```swift
.frame(width: isTrayPresentation ? Self.traySize.width : (isCalendarPresentation ? Self.calendarWidth : (isOnboardingPresentation ? Self.onboardingSize.width : Self.expandedSize.width)),
       height: isTrayPresentation
           ? Self.trayContentHeight + Self.switcherRowHeight
           : (isOnboardingPresentation
               ? Self.onboardingSize.height
               : (showsSwitcherRow ? Self.switcherContentHeight : Self.expandedSize.height)
                   + (showsSwitcherRow ? Self.switcherRowHeight : 0)),
       alignment: .top)
```
This is the exact technique the fix must replicate one level deeper (inside `presentationSwitch`, for `blobShape`'s `width:`/`height:` args): a plain ternary/ `switch` returning a `CGFloat` value, evaluated OUTSIDE any `@ViewBuilder`, so the View tree itself never branches on it.

**The shared render primitive — `blobShape`** (lines 1884-1943), the single call site the fix must converge on:
```swift
private func blobShape<Content: View>(topCornerRadius: CGFloat,
                                       bottomCornerRadius: CGFloat,
                                       alignment: Alignment = .center,
                                       width: CGFloat? = nil,
                                       height: CGFloat? = nil,
                                       shelfItems: [ShelfItem],
                                       shelfVisible: Bool,
                                       showSwitcher: Bool = false,
                                       @ViewBuilder content: () -> Content) -> some View {
    let baseWidth = width ?? Self.expandedSize.width
    let baseHeight = height ?? (showSwitcher ? Self.switcherContentHeight : Self.expandedSize.height)
    let totalHeight = baseHeight
        + (showSwitcher ? Self.switcherRowHeight : 0)
        + (hasShelf ? Self.shelfRowHeight : 0)
    let shape = NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
    return shape
        .fill(islandFill)
        .matchedGeometryEffect(id: "island", in: ns)   // MUST precede .frame — see Error Handling below
        .frame(width: baseWidth, height: totalHeight)
        .overlay(liquidGlassEffectLayer(shape: shape, size: CGSize(width: baseWidth, height: totalHeight), parameters: .expanded))
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                content()
                    .frame(width: baseWidth, height: baseHeight, alignment: alignment)
                if showSwitcher {
                    switcherRow
                }
                if hasShelf {
                    shelfRow(shelfItems)
                        .transition(.opacity)
                }
            }
            .frame(width: baseWidth, height: totalHeight, alignment: .top)
            .clipShape(shape)
        }
        .onTapGesture { onClick() }
}
```

**The 6 existing per-case `blobShape` call sites to consolidate** (each currently owns its OWN call — this is what must collapse to ONE):
```swift
// homeEmptyState (line 965):
blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
          height: Self.homeContentHeight, shelfItems: shelfViewState.items,
          shelfVisible: shelfStripVisible, showSwitcher: true) { /* home-empty content */ }

// calendarFullView (line 1020):
blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top, width: Self.calendarWidth,
          shelfItems: shelfViewState.items,
          shelfVisible: shelfStripVisible, showSwitcher: true) { /* month grid + day list */ }

// weatherFullView (line 1213):
blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
          height: weatherStyle == .large ? Self.weatherLargeContentHeight : Self.weatherMediumContentHeight,
          shelfItems: shelfViewState.items,
          shelfVisible: shelfStripVisible, showSwitcher: true) { /* weather content */ }

// trayFullView (line 1433):
blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
          width: Self.traySize.width, height: Self.trayContentHeight, shelfItems: [],
          shelfVisible: false, showSwitcher: true) { /* tray content */ }

// mediaExpanded(_:art:) (line 2787):
blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
          height: Self.homeContentHeight, shelfItems: shelfViewState.items,
          shelfVisible: shelfStripVisible, showSwitcher: true) { /* now-playing controls */ }

// mediaUnavailable (line ~2887): same shape, own call site (not read in full — mirrors mediaExpanded's signature per RESEARCH.md)
```
All 6 share IDENTICAL `topCornerRadius: 24`, `bottomCornerRadius: 32`, `alignment: .top`, and `showSwitcher: true` — confirming RESEARCH.md's claim that only `width`/`height`/content genuinely vary. `trayFullView` is the one call that also overrides `shelfItems`/`shelfVisible` to `[]`/`false` (already-hardcoded per Phase 31 `shelfStripVisible`, so this is not a real per-case variance once that gate is accounted for).

**Error handling / ordering convention (must not be disturbed)** (lines 1908-1913, in-file doc comment):
```swift
// Bugfix (island-expand-diagonal-bounce, 2026-07-15 round 3) — CORRECTED order:
// `.matchedGeometryEffect` must precede `.frame` (the effect is itself implemented
// via an internal frame+offset; a local `.frame` placed before it overrides the
// effect's own size interpolation).
.matchedGeometryEffect(id: "island", in: ns)
.frame(width: baseWidth, height: totalHeight)
```
This ordering is internal to `blobShape` and is untouched by the fix — the fix only changes WHERE `blobShape` is called from (1 site vs. 6), never its own internals.

**Controller-side spring wiring (already correct — reuse verbatim, do not re-tune per D-02)** — `Islet/Notch/NotchWindowController.swift:1605-1619`, `springResponse`/`springDamping` at lines 392-393:
```swift
private func handleSwitcherSelect(_ view: SelectedView) {
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        viewSwitcherState.selectedView = view
        if view == .calendar {
            calendarViewState.selectedDay = Date()
            calendarViewState.visibleMonth = Date()
            calendarViewState.monthEvents = nil
        }
        renderPresentation()
    }
    syncClickThrough()
    if view == .calendar {
        refreshCalendarMonth()
    }
}
// springResponse: Double = 0.6, springDamping: Double = 0.62
```

---

### `IsletTests/NotchPillViewTests.swift` (test, request-response)

**Analog:** `testShelfStripVisibleIsAlwaysFalse` (lines 14-40, same file).

**Imports pattern** (lines 1-2):
```swift
import XCTest
@testable import Islet
```

**Test class + instantiation pattern** (lines 11-31):
```swift
@MainActor
final class NotchPillViewTests: XCTestCase {

    func testShelfStripVisibleIsAlwaysFalse() {
        let state = NotchInteractionState()
        state.phase = .collapsed
        let shelf = ShelfViewState()
        shelf.items = [ShelfItem(id: UUID(),
                                  originalURL: URL(fileURLWithPath: "/tmp/a.txt"),
                                  localURL: URL(fileURLWithPath: "/tmp/a.txt"),
                                  filename: "a.txt",
                                  addedAt: Date())]
        let view = NotchPillView(interaction: state,
                                  nowPlaying: NowPlayingState(),
                                  presentationState: IslandPresentationState(.idle),
                                  outfit: BasicOutfitState(),
                                  shelfViewState: shelf,
                                  ...)
        XCTAssertFalse(view.shelfStripVisible,
                        "shelfStripVisible must stay false even with a non-empty shelf — the additive shelf-strip reveal is Tray-only (TRAY-01).")
    }
}
```
For the new width/height-mapping regression test (RESEARCH.md Wave 0 gap), follow this exact shape: instantiate `NotchPillView` directly with `IslandPresentationState(<case>)` set to each of the 6 in-scope `IslandPresentation` cases, then assert the new `tabWidth`/`tabHeight` (or equivalent) computed property equals the known pre-refactor constant for that case. This mirrors the `private → internal` visibility-bump precedent already used for `shelfStripVisible` (and `EqualizerBars.makeProfiles()`) — bump visibility for testability only, no behavior change.

## Shared Patterns

### Single-call-site geometry hoisting (the fix itself)
**Source:** `Islet/Notch/NotchPillView.swift:888-895` (existing, proven in-file precedent)
**Apply to:** The new `presentationSwitch` restructuring — compute `tabWidth`/`tabHeight` as plain `CGFloat` properties/switches evaluated OUTSIDE the `@ViewBuilder`, call `blobShape` exactly once, and put only the genuinely-different content in an inner content-only switch passed as `blobShape`'s trailing closure.

### matchedGeometryEffect-before-frame ordering
**Source:** `Islet/Notch/NotchPillView.swift:1908-1913` (`blobShape` internals)
**Apply to:** No new call sites need this rule applied directly (it lives inside `blobShape`, called once post-fix) — but any executor tempted to inline a `.frame` before `blobShape`'s own `.matchedGeometryEffect` at the new unified call site must not.

### `showsSwitcherRow` as the authoritative case list
**Source:** `Islet/Notch/IslandResolver.swift:109-114`
**Apply to:** Confirms the unification must cover exactly 6 `IslandPresentation` cases (`.homeLastPlayed`, `.homeEmpty`, `.calendarExpanded`, `.weatherExpanded`, `.trayExpanded`, `.nowPlayingExpanded` — both healthy/unhealthy), not 4 visual tabs — Pitfall 2 in RESEARCH.md.

## No Analog Found

None. This phase modifies no files without an in-codebase precedent — it is a pure internal refactor of code whose own prior revisions (Phases 28, 30, 31, 32) already establish every pattern needed.

## Metadata

**Analog search scope:** `Islet/Notch/NotchPillView.swift` (full presentationSwitch/blobShape/switcherRow/6-call-site region), `Islet/Notch/NotchWindowController.swift` (spring wiring, confirmed unchanged), `Islet/Notch/IslandResolver.swift` (`showsSwitcherRow`), `IsletTests/NotchPillViewTests.swift` (existing test precedent)
**Files scanned:** 4
**Pattern extraction date:** 2026-07-19
