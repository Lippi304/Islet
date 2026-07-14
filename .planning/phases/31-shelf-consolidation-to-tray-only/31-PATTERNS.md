# Phase 31: Shelf Consolidation to Tray-Only - Pattern Map

**Mapped:** 2026-07-14
**Files analyzed:** 1 (the only new artifact — a regression test; no new feature file, per D-01/D-02)
**Analogs found:** 1 exact behavioral precedent, 2 supporting test-style analogs

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `IsletTests/NotchPillViewTests.swift` (new) | test | transform (pure computed-property assertion) | `IsletTests/EqualizerBarsTests.swift` (access-level precedent) + `IsletTests/VisibilityDecisionTests.swift` (boolean-gate assertion style) | role-match, exact precedent for the access-level blocker |
| `Islet/Notch/NotchPillView.swift` (possible 1-line access-level edit) | component | n/a | same file, `EqualizerBars.makeProfiles()` precedent (lines 1607-1609) | exact |

## Critical Blocker Found: `shelfStripVisible` is `private`

`Islet/Notch/NotchPillView.swift:58`:
```swift
private var shelfStripVisible: Bool { false }
```

This codebase has **already hit and documented this exact problem** for a different property. `EqualizerBars.makeProfiles()` (same file, lines 1607-1609) carries this comment:

```swift
// internal (not private): EqualizerBarsTests.swift calls this directly to sanity-check
// the extracted factory — `private` is file-scoped and would not compile from another
// file even under @testable import.
static func makeProfiles() -> [(low: CGFloat, high: CGFloat, period: Double, phase: Double)] {
```

**Implication for the plan:** `@testable import Islet` does NOT expose `private` members across files — only `internal`/`public`. A regression test cannot reference `shelfStripVisible` at all unless its access level changes from `private` to (at minimum file-private-compatible) `internal`. This is a narrow, mechanical access-level bump — not the "implementation shape" change D-03 says to avoid (D-03 is about the hardcoded-`false` vs. inlining vs. removal *design*, not Swift access control). Recommend the plan include this one-line access change, mirroring the `makeProfiles()` precedent's comment style, e.g.:

```swift
// internal (not private): NotchPillViewTests.swift asserts this directly (Phase 31/TRAY-01
// regression lock) — `private` is file-scoped and would not compile from another file even
// under @testable import (see EqualizerBars.makeProfiles() for the same precedent).
var shelfStripVisible: Bool { false }
```

If the executor prefers zero source changes, the fallback is an indirect test asserting `shelfVisible: false` is what reaches `blobShape(...)` at all 5 call sites — but that requires ViewInspector-style rendering this codebase does not use elsewhere (see "No Analog Found" below). The direct-property route (mirroring `makeProfiles()`) is the established, lower-effort convention.

## Pattern Assignments

### `IsletTests/NotchPillViewTests.swift` (new file — does not currently exist)

**Primary analog:** `IsletTests/VisibilityDecisionTests.swift` (boolean-gate assertion style, XCTest, `@testable import Islet`, no setup/teardown needed for a pure value)

**Secondary analog:** `IsletTests/EqualizerBarsTests.swift` (precedent for testing a value pulled off a SwiftUI view type via `@testable import`, and for the private→internal access-level pattern above)

**File header + imports** (`IsletTests/VisibilityDecisionTests.swift` lines 1-2):
```swift
import XCTest
@testable import Islet
```

**Class + doc-comment convention** (`IsletTests/VisibilityDecisionTests.swift` lines 4-12, adapt requirement IDs):
```swift
// TRAY-01 / Phase 31: shelfStripVisible is the single shared gate that keeps the additive
// shelf-strip reveal OFF everywhere except the dedicated Tray view (which renders the shelf
// directly via its own shelfRow(_:) path, unaffected by this gate). Locks the shipped
// behavior from quick task 260714-3k6 so it can't silently regress.
final class NotchPillViewTests: XCTestCase {
```

**Construction pattern for a `NotchPillView` instance** — copy the `#Preview` construction exactly (`Islet/Notch/NotchPillView.swift` lines 1846-1857), all 6 `@ObservedObject` state classes take plain no-arg (or defaulted) inits:
```swift
let state = NotchInteractionState()
let view = NotchPillView(interaction: state,
                          nowPlaying: NowPlayingState(),
                          presentationState: IslandPresentationState(.idle),
                          outfit: BasicOutfitState(),
                          shelfViewState: ShelfViewState(),
                          onboardingState: OnboardingViewState(),
                          viewSwitcherState: ViewSwitcherState(),
                          calendarViewState: CalendarViewState())
```

**Core assertion pattern** (mirrors `VisibilityDecisionTests` single-line `XCTAssert*` per test, e.g. lines 14-16):
```swift
func testShelfStripVisibleIsAlwaysFalse() {
    // TRAY-01: the shelf strip never reveals under Home/Calendar/Weather/Now-Playing —
    // only trayFullView renders shelf content, via its own separate shelfVisible: false path.
    XCTAssertFalse(view.shelfStripVisible,
                    "shelfStripVisible must stay false — the additive shelf-strip reveal is Tray-only (TRAY-01).")
}
```
(Requires the `private` → `internal` access bump described above; without it this line will not compile.)

**Alternative/supplementary assertion** — since `shelfStripVisible` is presently a hardcoded literal (`{ false }`, no branching), a single assertion fully covers it. Do not add parametrized/multiple-input tests the way `VisibilityDecisionTests` does for `shouldShow(...)` (that function has 4 boolean inputs and real branching; `shelfStripVisible` has none) — one test is proportionate here, more would be testing a constant.

---

## Shared Patterns

### Access-level-for-testability convention
**Source:** `Islet/Notch/NotchPillView.swift` lines 1607-1609 (`EqualizerBars.makeProfiles()`)
**Apply to:** `shelfStripVisible` if the plan chooses the direct-assertion route
```swift
// internal (not private): <TestFile>.swift calls this directly to sanity-check
// the extracted factory — `private` is file-scoped and would not compile from another
// file even under @testable import.
```

### XCTest + `@testable import Islet` convention (no third-party test framework in this codebase)
**Source:** `IsletTests/VisibilityDecisionTests.swift` lines 1-2, `IsletTests/NotchShapeTests.swift` lines 1-3
```swift
import XCTest
@testable import Islet
final class <Name>Tests: XCTestCase { ... }
```

### Doc-comment-above-class convention citing the requirement ID and phase/quick-task provenance
**Source:** `IsletTests/NotchShapeTests.swift` lines 5-8, `IsletTests/VisibilityDecisionTests.swift` lines 4-11
Every test file in this codebase opens with a comment naming the requirement ID (e.g. `ISL-01`, `TRAY-01`) and what real-world behavior it locks, not just what it asserts mechanically.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| Indirect/ViewInspector-style rendering assertion on `blobShape` call sites | test | transform | This codebase has no snapshot/ViewInspector test dependency anywhere in `IsletTests/` — every SwiftUI-adjacent test (`NotchShapeTests`, `EqualizerBarsTests`, `VisibilityDecisionTests`) tests a pure value/function pulled out of the view, never the rendered view tree. Recommend the planner stick to the direct-property-assertion route above rather than introduce a new test dependency for this single check. |

## Metadata

**Analog search scope:** `IsletTests/` (all 31 files), `Islet/Notch/NotchPillView.swift` (full read of relevant sections)
**Files scanned:** `NotchShapeTests.swift`, `VisibilityDecisionTests.swift`, `EqualizerBarsTests.swift`, `ShelfViewStateTests.swift`, `NotchPillView.swift` (lines 1-110, 440-500, 1580-1620, 1840-1990)
**Confirmed:** `IsletTests/NotchPillViewTests.swift` does not currently exist — it is a wholly new file, not an addition to an existing suite.
**Pattern extraction date:** 2026-07-14
