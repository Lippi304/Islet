# Phase 32: Tray Widening - Pattern Map

**Mapped:** 2026-07-14
**Files analyzed:** 4 (no new files — this phase modifies existing files only)
**Analogs found:** 4 / 4 (all analogs are IN the same files being modified — this is an "extend an existing extension point" phase, not a "copy a sibling file" phase)

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|----------------|------|-----------|-----------------|---------------|
| `Islet/Notch/NotchPillView.swift` — add `traySize`/`trayContentHeight` constants, `blobShape()` height ternary, `trayFullView`'s `blobShape` call, `body`'s outer `.frame()` branch | component (SwiftUI view) | request-response (state → render) | Same file's `onboardingCarousel`/`onboardingSize` precedent (lines 786-807, 330) | exact — literal same pattern, same file, prior phase already did this exact kind of change twice (shelf Phase 21, onboarding Phase 26) |
| `Islet/Notch/ShelfItemView.swift` — icon `.frame` 28→~40, caption `.frame(maxWidth:)` 44→larger | component (SwiftUI leaf view) | request-response | No prior analog needed — same file, direct constant edit | exact — trivial value change, no structural pattern to copy |
| `Islet/Notch/NotchWindowController.swift` — `positionAndShow()` panel-frame union member, `visibleContentZone()` branch | controller (AppKit window shell) | request-response (geometry computation) | Same file's `onboardingFrame`/`isOnboardingActive` precedent (lines 794-807, 962-982) | exact — literal same union-member / ternary-branch pattern used 3x already (wings, onboarding) |
| `IsletTests/NotchGeometryTests.swift` — new Tray-sized `expandedNotchFrame` centering test | test | request-response (pure function assertion) | `testExpandedNotchFrameCentersOnMidXAndPinsTop` (lines 117-133) | exact — same test, different `CGSize` fixture |

## Pattern Assignments

### `Islet/Notch/NotchPillView.swift` — new `traySize`/`trayContentHeight` constants

**Analog:** the file's own existing constants block

**Constants pattern** (`Islet/Notch/NotchPillView.swift` lines 200, 212, 258, 264, 274, 316, 330):
```swift
static let expandedSize = CGSize(width: 420, height: 144)
static let wingsSize = CGSize(width: 290, height: 32)
static let shelfRowHeight: CGFloat = 56
static let switcherRowHeight: CGFloat = 44
static let cameraClearance: CGFloat = 42
static let switcherContentHeight: CGFloat = 196
static let onboardingSize = CGSize(width: 420, height: 320)
```
Add `static let traySize = CGSize(width: <~840>, height: <n/a — width only used, height comes from trayContentHeight>)` or a plain `trayWidth`/`trayContentHeight` pair (research's Open Question 2 recommends ONE shared height constant, not empty/non-empty split, for D-05/D-08 simplicity) — follow this exact `static let` naming convention, not inline magic numbers (per CLAUDE.md code-quality rule and RESEARCH.md's explicit constraint).

---

### `Islet/Notch/NotchPillView.swift` — `blobShape()`'s height ternary (THE CRITICAL FIX)

**Analog:** the ternary itself, in place — this is a one-line edit, not a copy from elsewhere

**Current code** (`Islet/Notch/NotchPillView.swift` line 1100, inside `blobShape()` lines 1089-1127):
```swift
let baseHeight = showSwitcher ? Self.switcherContentHeight : (height ?? Self.expandedSize.height)
```
**Required change** (per RESEARCH.md Pattern 1 / Pitfall 1 — `showSwitcher: true` currently silently discards any `height:` override, and `trayFullView` MUST pass `showSwitcher: true` to render the switcher row):
```swift
let baseHeight = height ?? (showSwitcher ? Self.switcherContentHeight : Self.expandedSize.height)
```
This is the single highest-risk line in the phase — every other existing `showSwitcher: true` caller (Home/Calendar/Weather, none of which currently pass `height:`) is unaffected since they all still fall through to `switcherContentHeight` via the `??` fallback. Only `trayFullView`'s new `height:` argument activates the new branch.

---

### `Islet/Notch/NotchPillView.swift` — `trayFullView`'s `blobShape` call site

**Analog:** `onboardingCarousel(_:)` (lines 786-789) — the only other caller that overrides both `width:` and `height:`

**Current `trayFullView`** (lines 738-751):
```swift
private var trayFullView: some View {
    blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top, shelfItems: [],
              shelfVisible: false, showSwitcher: true) {
        Group {
            if shelfViewState.items.isEmpty {
                trayEmptyState
            } else {
                shelfRow(shelfViewState.items)
            }
        }
        .padding(.top, Self.cameraClearance)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
```
**Onboarding precedent for adding width/height overrides** (lines 787-789):
```swift
blobShape(topCornerRadius: 24, bottomCornerRadius: 32,
          width: Self.onboardingSize.width, height: Self.onboardingSize.height, shelfItems: [],
          shelfVisible: false) {
```
Add `width: Self.traySize.width, height: Self.trayContentHeight` to `trayFullView`'s existing call (keep `showSwitcher: true`, `shelfItems: []`, `shelfVisible: false` unchanged — D-07 keeps the switcher row). Note onboarding omits `showSwitcher` entirely so its `height:` override was never at risk of the ternary trap above — Tray's combination (`showSwitcher: true` AND `height:` override) is new territory, which is exactly why the ternary fix above is mandatory, not optional.

---

### `Islet/Notch/NotchPillView.swift` — `body`'s outer `.frame()` branch (Pattern 2)

**Analog:** the existing `isOnboardingPresentation` branch (lines 47-50, 404-409)

**Existing `isOnboardingPresentation` computed var** (lines 47-50):
```swift
private var isOnboardingPresentation: Bool {
    if case .onboarding = presentation { return true }
    return false
}
```
**Existing outer frame** (lines 404-409):
```swift
.frame(width: isOnboardingPresentation ? Self.onboardingSize.width : Self.expandedSize.width,
       height: isOnboardingPresentation
           ? Self.onboardingSize.height
           : (showsSwitcherRow ? Self.switcherContentHeight : Self.expandedSize.height)
               + (showsSwitcherRow ? Self.switcherRowHeight : 0),
       alignment: .top)
```
Add a mirrored `private var isTrayPresentation: Bool { if case .trayExpanded = presentation { return true }; return false }` (matches `IslandPresentation.trayExpanded` case, `Islet/Notch/IslandResolver.swift` line 49), then extend both the `width:` ternary and the `switcherContentHeight` term to check `isTrayPresentation` first — same two-site pattern documented in the file's own comments (lines 381-403) as having already caused clipping bugs twice (Phase 21 shelf, Phase 26 onboarding round 1) when only one of `blobShape`/outer-frame was updated.

---

### `Islet/Notch/ShelfItemView.swift` — icon size + caption width

**Analog:** none needed — direct in-place constant edit, single shared leaf view (RESEARCH.md Assumption A1: global change is the locked reading of D-04, TRAY-01 currently keeps blast radius at zero on non-Tray tabs)

**Current code** (`Islet/Notch/ShelfItemView.swift` lines 13-24):
```swift
var body: some View {
    VStack(spacing: 2) {   // UI-SPEC icon-gap
        Image(nsImage: NSWorkspace.shared.icon(forFile: item.localURL.path))
            .resizable()
            .frame(width: 28, height: 28)   // matches transportButton's 28x28 touch size
        Text(item.filename)
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)   // V5 mitigation (T-20-01): item.filename is untrusted
            .frame(maxWidth: 44)
    }
```
Change `28, height: 28` → `~40, height: 40` (D-04 target) and `maxWidth: 44` → a wider value proportioned to the larger icon (Claude's discretion per CONTEXT.md). Keep `.lineLimit(1)`/`.truncationMode(.middle)` unchanged (T-20-01 security mitigation for untrusted `item.filename` — do not touch).

---

### `Islet/Notch/NotchWindowController.swift` — `positionAndShow()` panel-frame union

**Analog:** `onboardingFrame` union member (lines 803-807), same pattern `wings` used before it

**Current code** (lines 794-807):
```swift
let expandedFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                       expandedSize: CGSize(width: expandedSize.width,
                                                             height: NotchPillView.switcherContentHeight + NotchPillView.shelfRowHeight + NotchPillView.switcherRowHeight))

let wings = wingsFrame(collapsed: collapsedFrame, wingsSize: wingsSize)
let onboardingFrame = expandedNotchFrame(collapsed: collapsedFrame, expandedSize: NotchPillView.onboardingSize)
let panelFrame = expandedFrame.union(wings).union(onboardingFrame)
```
Add a fourth union member, following the `onboardingFrame` precedent exactly:
```swift
let trayFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                    expandedSize: CGSize(width: NotchPillView.traySize.width,
                                                          height: NotchPillView.trayContentHeight + NotchPillView.switcherRowHeight))
let panelFrame = expandedFrame.union(wings).union(onboardingFrame).union(trayFrame)
```
This is the load-bearing AppKit step (RESEARCH.md Pitfall 2) — SwiftUI Previews will render 840pt content correctly with no panel, but the real on-screen `NSPanel` clips to the old union without this. `expandedNotchFrame`/`topPinnedFrame` (`Islet/Notch/NotchGeometry.swift` lines 62-74) both center on `collapsed.midX` automatically — no separate centering math needed for the wider Tray frame.

---

### `Islet/Notch/NotchWindowController.swift` — `visibleContentZone()` branch (CR-01 discipline)

**Analog:** `isOnboardingActive` branch in the same function (lines 976-979)

**Current code** (lines 962-982):
```swift
private func visibleContentZone() -> CGRect? {
    guard let hotZone else { return nil }
    let collapsedFrame = hotZone.insetBy(dx: hotZonePadding, dy: hotZonePadding)
    let switcherRowShowing = showsSwitcherRow(for: presentationState.presentation)
    let switcherHeight = switcherRowShowing ? NotchPillView.switcherRowHeight : 0
    let contentSize: CGSize = isOnboardingActive
        ? NotchPillView.onboardingSize
        : CGSize(width: expandedSize.width,
                 height: (switcherRowShowing ? NotchPillView.switcherContentHeight : expandedSize.height) + switcherHeight)
    let visibleFrame = expandedNotchFrame(collapsed: collapsedFrame, expandedSize: contentSize)
    return visibleFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
}
```
Add a third branch checking `presentationState.presentation` directly (no new stored bool needed — `isOnboardingActive` is a stored bool only because onboarding is a forced multi-step flow tracked outside the resolver; Tray's active-ness is fully derivable from the existing enum):
```swift
let contentSize: CGSize
if isOnboardingActive {
    contentSize = NotchPillView.onboardingSize
} else if case .trayExpanded = presentationState.presentation {
    contentSize = CGSize(width: NotchPillView.traySize.width,
                          height: NotchPillView.trayContentHeight + switcherHeight)
} else {
    contentSize = CGSize(width: expandedSize.width,
                          height: (switcherRowShowing ? NotchPillView.switcherContentHeight : expandedSize.height) + switcherHeight)
}
```
**This must land in the same commit/task as the `blobShape`/`positionAndShow` changes above** — per CR-01 discipline (project memory `cr01-clickthrough-or-defeat-gotcha`), a size change here that's not mirrored in `visibleContentZone()` breaks click-through (RESEARCH.md Pitfall 3). Must be followed by the mandatory on-device hover→expand→move-down trace before this is considered verified — no unit test substitutes for this (see Validation section below).

---

### `IsletTests/NotchGeometryTests.swift` — Tray-sized centering test

**Analog:** `testExpandedNotchFrameCentersOnMidXAndPinsTop` (lines 117-133)

**Current test** (lines 117-133):
```swift
func testExpandedNotchFrameCentersOnMidXAndPinsTop() {
    // collapsed pill at origin-screen: x 610, y 944, 292x38 (== notchFrame output).
    // expandedSize 360x72. The expanded frame stays centered on the collapsed
    // midX (756) and pinned to the same top edge (maxY 982, bottom-left origin):
    //   x = 756 - 180 = 576, y = 982 - 72 = 910.
    let collapsed = CGRect(x: 610, y: 944, width: 292, height: 38)
    let expandedSize = CGSize(width: 360, height: 72)
    let frame = expandedNotchFrame(collapsed: collapsed, expandedSize: expandedSize)
    XCTAssertEqual(frame.midX, collapsed.midX, accuracy: 0.0001)
    XCTAssertEqual(frame.midX, 756, accuracy: 0.0001)
    XCTAssertEqual(frame.maxY, collapsed.maxY, accuracy: 0.0001)
    XCTAssertEqual(frame.maxY, 982, accuracy: 0.0001)
    XCTAssertEqual(frame.origin.x, 576, accuracy: 0.0001)
    XCTAssertEqual(frame.origin.y, 910, accuracy: 0.0001)
    XCTAssertEqual(frame.width, 360, accuracy: 0.0001)
    XCTAssertEqual(frame.height, 72, accuracy: 0.0001)
}
```
Copy this exact structure with a wider `expandedSize` (e.g. `CGSize(width: 840, height: <trayContentHeight>)`) to prove `expandedNotchFrame` still centers correctly on `collapsed.midX` at Tray's new size — `expandedNotchFrame`/`topPinnedFrame` (`Islet/Notch/NotchGeometry.swift` lines 62-74) are pure functions, so this is the only automatable unit-test surface for this phase (per RESEARCH.md Validation Architecture — `blobShape`'s internal ternary and `visibleContentZone()`'s click-through math are not independently unit-testable in this codebase without ViewInspector, which is not a dependency and should not be added — manual on-device trace substitutes for both, per established project precedent).

---

## Shared Patterns

### Named size constants (not inline magic numbers)
**Source:** `Islet/Notch/NotchPillView.swift` lines 200-330 (`expandedSize`, `wingsSize`, `shelfRowHeight`, `switcherRowHeight`, `switcherContentHeight`, `onboardingSize`)
**Apply to:** the new `traySize`/`trayContentHeight` constant(s) — `static let` on `NotchPillView`, referenced from both `NotchPillView.swift` and `NotchWindowController.swift` (cross-file references to `NotchPillView.xxx` are the established convention, e.g. `NotchPillView.switcherContentHeight` used throughout `NotchWindowController.swift`).

### Two-site geometry sync (SwiftUI render + AppKit panel/hit-test) — CR-01 discipline
**Source:** `Islet/Notch/NotchPillView.swift` (`blobShape`, outer `body` `.frame()`) + `Islet/Notch/NotchWindowController.swift` (`positionAndShow()`, `visibleContentZone()`) — 4 independently-maintained copies of "what size is this presentation" that must all agree.
**Apply to:** every one of the 4 code locations above — this project's own documented regression history (Phase 21 shelf, Phase 26 onboarding round 1 clipping; CR-01/CR-02 click-through desyncs) shows that touching only 1-2 of these 4 always produces a visible bug. All 4 changes belong in the same task/commit, not spread across separate tasks, per RESEARCH.md's explicit warning.

### `showsSwitcherRow(for:)` — single shared source of truth
**Source:** `Islet/Notch/IslandResolver.swift` lines 66-71
```swift
func showsSwitcherRow(for presentation: IslandPresentation) -> Bool {
    switch presentation {
    case .homeLastPlayed, .homeEmpty, .calendarExpanded, .weatherExpanded, .trayExpanded, .nowPlayingExpanded: return true
    default: return false
    }
}
```
**Apply to:** no change needed here — `.trayExpanded` is already included (added in Phase 28-04 round 5). Both `NotchPillView.body` and `NotchWindowController.visibleContentZone()` already call this shared function rather than hand-duplicating the case list (WR-01 fix, the exact CR-01 regression class this phase must avoid reintroducing elsewhere).

## No Analog Found

None — every file this phase touches already contains the exact extension-point pattern needed (optional `width:`/`height:` override params, union-member panel reservation, ternary-branch click-through zone), each already used 2-3 times by prior phases (shelf Phase 20/21, switcher row Phase 28, onboarding Phase 26). This phase is purely "add one more branch/member to 4 existing patterns," not new pattern invention.

## Metadata

**Analog search scope:** `Islet/Notch/` (4 files: `NotchPillView.swift`, `NotchWindowController.swift`, `ShelfItemView.swift`, `NotchGeometry.swift`), `IsletTests/` (2 files: `NotchGeometryTests.swift`, `NotchPillViewTests.swift` referenced but not modified), `Islet/Notch/IslandResolver.swift` (referenced, not modified)
**Files scanned:** 6 read directly (line-referenced excerpts above), all analogs found within the same 3 files being modified — no cross-directory search needed since RESEARCH.md had already identified exact line numbers for every extension point
**Pattern extraction date:** 2026-07-14
