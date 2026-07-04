# Phase 9: Fullscreen-Enter Flash — Window/Space Architecture Retry - Pattern Map

**Mapped:** 2026-07-04
**Files analyzed:** 4 (1 new, 2 modified, 1 read-for-context/unmodified per research finding)
**Analogs found:** 4 / 4 (all in-repo — no external-package analogs needed)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/CGSSpace.swift` (NEW) | utility (private-symbol wrapper) | request-response (thin synchronous CGS calls, no async) | `Islet/Notch/FullscreenSpaceProbe.swift` | exact — same role (private `@_silgen_name` CGS binding wrapper), same file scope in the same directory |
| `Islet/Notch/NotchWindowController.swift` (MODIFIED — one-time Space-join call added) | controller (window/lifecycle glue) | event-driven (lifecycle hook, not a new arbiter path) | itself, `start()`/`positionAndShow()`/`deinit` (existing lifecycle hooks in the same file) | exact — the analog for "how to add a one-time lifecycle call" is the file's own existing patterns |
| `Islet/Notch/NotchPanel.swift` (READ ONLY — unchanged per research's layered-approach finding) | config/model (window config object) | N/A (static init-time config) | N/A — not modified | n/a (context only) |
| `IsletTests/NotchPanelTests.swift` (regression — must stay green, no edits expected) | test | request-response (sync XCTest assertions) | `IsletTests/FullscreenSpaceProbe`-adjacent tests (`FullscreenDetectorTests.swift`, `VisibilityDecisionTests.swift`) | exact — same `@MainActor` XCTestCase shape already covers the invariants this phase must not regress |

## Pattern Assignments

### `Islet/Notch/CGSSpace.swift` (NEW — utility, request-response)

**Analog:** `Islet/Notch/FullscreenSpaceProbe.swift` (full file, 85 lines — read in full, no re-read needed)

**Imports pattern** (`FullscreenSpaceProbe.swift` lines 1):
```swift
import CoreGraphics
```
Note: the new file's own class-based wrapper additionally needs `AppKit` (for `NSWindow`), matching the reference implementations in RESEARCH.md's Pattern 1 (`import AppKit`), not `CoreGraphics` alone — `FullscreenSpaceProbe.swift` only needs `CoreGraphics` because it has no `NSWindow` surface.

**`@_silgen_name` binding pattern** (`FullscreenSpaceProbe.swift` lines 22-32):
```swift
// CGSConnectionID is a C `int` → Int32 (ABI-compatible binding required by @_silgen_name).
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> Int32

@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray

// kCGSSpaceFullscreen — the managed-space "type" value for a fullscreen Space.
// A normal/user space is 0; a fullscreen space is 4. The DEBUG log below prints the
// observed type so on-device testing confirms the constant on this OS (Tahoe).
private let kCGSSpaceFullscreen = 4
```
**Apply this exact shape** to the new file's bindings, but per RESEARCH.md Pitfall 2, do NOT reuse `CGSMainConnectionID`'s `Int32` typealias for the new file's connection lookup — bind a separate, self-contained `_CGSDefaultConnection() -> UInt` in `CGSSpace.swift` (own `fileprivate` types), exactly as both shipping reference implementations do (verbatim source already captured in `09-RESEARCH.md` Pattern 1, lines 144-199 there). Keep the two files' connection-ID bindings independent — never pass one file's connection ID into the other file's functions.

**Doc-comment / rationale-header pattern** (`FullscreenSpaceProbe.swift` lines 3-20):
```swift
// ISL-05 (Q3 fix) — RUNTIME fullscreen detection via the private CoreGraphics
// "Managed Display Spaces" API (CGS / SkyLight). This is a THIN system-call wrapper
// (like NSScreen+Notch.swift), NOT a pure fixture-tested seam.
//
// WHY THIS EXISTS: ...
//
// THE FIX: ...
//
// The private symbols live in SkyLight and are re-exported through CoreGraphics.
// `@_silgen_name` binds them by symbol name at link time (no dlopen needed).
```
Mirror this convention in `CGSSpace.swift`: an ID-tagged header comment (this phase's equivalent tag would reference FS-01/Phase 9) explaining WHY a private-symbol Space wrapper exists and what technique is used, matching the project's established "explain private-API code inline" convention.

**Fail-safe design philosophy** (`FullscreenSpaceProbe.swift` lines 40-41, 49-51, 73-75):
```swift
/// FAIL-SAFE: any nil / parse failure / ambiguity returns `false` — we prefer showing
/// the island over wrongly hiding it.
...
guard let displays = raw as? [[String: Any]], !displays.isEmpty else {
    return false // parse failure / empty → fail-safe
}
...
guard let display = chosen, ... else {
    return false // missing keys / wrong types → fail-safe
}
```
The new `CGSSpace` wrapper should follow the same fail-safe-to-visible philosophy the RESEARCH.md `Established Patterns` section calls out: if Space creation/membership calls no-op or fail silently (private API, no error return), the panel must still show via the existing `orderFrontRegardless()` path — the new Space membership is an *additive* visibility mechanism, never a gate that can suppress showing.

**Core wrapper pattern to copy verbatim** — from `09-RESEARCH.md` Architecture Pattern 1 (already fetched and verified against two shipping repos: `Ebullioscopic/Atoll/DynamicIsland/private/CGSSpace.swift` and `TheBoredTeam/boring.notch/boringNotch/private/CGSSpace.swift`). Reproduced here for the planner's direct use so no second GitHub fetch is needed:
```swift
import AppKit

public final class CGSSpace {
    private let identifier: CGSSpaceID
    private let createdByInit: Bool

    public var windows: Set<NSWindow> = [] {
        didSet {
            let remove = oldValue.subtracting(self.windows)
            let add = self.windows.subtracting(oldValue)
            CGSRemoveWindowsFromSpaces(_CGSDefaultConnection(),
                                       remove.map { $0.windowNumber } as NSArray,
                                       [self.identifier])
            CGSAddWindowsToSpaces(_CGSDefaultConnection(),
                                  add.map { $0.windowNumber } as NSArray,
                                  [self.identifier])
        }
    }

    /// Initialized `CGSSpace`s *MUST* be de-initialized upon app exit!
    public init(level: Int = 0) {
        let flag = 0x1 // this value MUST be 1, otherwise Finder decides to draw desktop icons
        self.identifier = CGSSpaceCreate(_CGSDefaultConnection(), flag, nil)
        CGSSpaceSetAbsoluteLevel(_CGSDefaultConnection(), self.identifier, level)
        CGSShowSpaces(_CGSDefaultConnection(), [self.identifier])
        self.createdByInit = true
    }

    deinit {
        CGSHideSpaces(_CGSDefaultConnection(), [self.identifier])
        if createdByInit { CGSSpaceDestroy(_CGSDefaultConnection(), self.identifier) }
    }
}

// CGS private symbol bindings — @_silgen_name, no dlopen (mirrors FullscreenSpaceProbe.swift)
fileprivate typealias CGSConnectionID = UInt      // NOTE: UInt, not Int32 — see Common Pitfalls
fileprivate typealias CGSSpaceID = UInt64
@_silgen_name("_CGSDefaultConnection")
fileprivate func _CGSDefaultConnection() -> CGSConnectionID
@_silgen_name("CGSSpaceCreate")
fileprivate func CGSSpaceCreate(_ cid: CGSConnectionID, _ unknown: Int, _ options: NSDictionary?) -> CGSSpaceID
@_silgen_name("CGSSpaceDestroy")
fileprivate func CGSSpaceDestroy(_ cid: CGSConnectionID, _ space: CGSSpaceID)
@_silgen_name("CGSSpaceSetAbsoluteLevel")
fileprivate func CGSSpaceSetAbsoluteLevel(_ cid: CGSConnectionID, _ space: CGSSpaceID, _ level: Int)
@_silgen_name("CGSAddWindowsToSpaces")
fileprivate func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)
@_silgen_name("CGSRemoveWindowsFromSpaces")
fileprivate func CGSRemoveWindowsFromSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)
@_silgen_name("CGSHideSpaces")
fileprivate func CGSHideSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)
@_silgen_name("CGSShowSpaces")
fileprivate func CGSShowSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)
```
**Do not deviate** from this exact shape (magic `flag = 0x1`, `nil` options, `didSet`-diffed `windows` set) — RESEARCH.md's "Don't Hand-Roll" section documents that re-deriving this from the (differently-shaped) public `NUIKit/CGSInternal` header produces a subtly wrong signature that previously broke Finder desktop-icon rendering upstream.

A `NotchSpaceManager` singleton (`static let shared`, owning one `CGSSpace(level: 2147483647)`) is optional per RESEARCH.md — for this app's single-panel case the wrapper can be owned directly by `NotchWindowController` instead. Left to the planner.

---

### `Islet/Notch/NotchWindowController.swift` (MODIFIED — controller, event-driven lifecycle hook)

**Analog:** the file's own existing lifecycle hooks (`start()` lines 234-303, `positionAndShow()` lines 445-485, `deinit` lines 1039-1069) — this is a same-file addition, not a cross-file port.

**Where the one-time Space-join call goes** — `positionAndShow()` panel-creation branch (lines 471-480):
```swift
let panel = self.panel ?? NotchPanel(contentRect: panelFrame)
if self.panel == nil {
    // Phase 6 / D-11 — host the view with the persisted accent injected on the
    // `\.activityAccent` Environment value (read by the 3 lively leaf elements). The view
    // observes presentationState (the resolver's verdict) for the single-arbiter render.
    let index = UserDefaults.standard.integer(forKey: ActivitySettings.accentIndexKey)
    appliedAccentIndex = index
    panel.contentView = NSHostingView(rootView: makeRootView(accentIndex: index))
    self.panel = panel
}
```
This `if self.panel == nil` branch is the ONE place the panel is constructed exactly once per controller lifetime — per RESEARCH.md's Anti-Patterns section ("Re-syncing Space membership on every `updateVisibility()` call" is explicitly called out as wrong), the new `notchSpace.windows.insert(panel)` call belongs INSIDE this same `if self.panel == nil` block, immediately after `self.panel = panel`, NOT inside `updateVisibility()` and NOT re-run on every show/hide cycle.

**Teardown analog** — `deinit` (lines 1039-1069), specifically the owner-driven-stop discipline already used for `powerMonitor`/`bluetoothMonitor`/`nowPlayingMonitor`:
```swift
if let powerMonitor { powerMonitor.stop() }
...
bluetoothMonitor?.stop()
...
nowPlayingMonitor?.stop()
mediaDismissWorkItem?.cancel()
```
Mirror this exact "each owned resource gets one teardown call, colocated with its sibling teardowns" convention: the new Space wrapper's `.windows.remove(panel)` (or simply letting the singleton's own `deinit` run at process exit, per RESEARCH.md Assumption A2) should be added to this same `deinit` block if the planner chooses controller-owned (non-singleton) lifetime; skip this only if the wrapper is a process-lifetime singleton per Pattern 2, in which case its own `deinit` never runs until process exit anyway (documented, accepted low-severity risk — see Shared Patterns below).

**What must NOT change** — `updateVisibility()` (lines 414-441) is the single show/hide arbiter (Pattern 7) and per the phase's CONTEXT.md/RESEARCH.md must remain untouched by this phase's Space-membership logic:
```swift
private func updateVisibility() {
    let descriptors = NSScreen.screens.map { $0.descriptor }
    let target = selectTargetScreen(from: descriptors)
    let fullscreen = isBuiltinDisplayInFullscreenSpace(builtinUUID: currentBuiltin()?.uuid)

    if shouldShow(hasTarget: target != nil,
                  hideInFullscreen: hideInFullscreen,
                  isFullscreen: fullscreen),
       let target {
        positionAndShow(on: target)
    } else {
        panel?.orderOut(nil)
        ...
    }
}
```
Do not add a second show/hide path or a parallel Space-add/remove call inside this function's branches — the Space-join happens exactly once, upstream of every `updateVisibility()` call, inside `positionAndShow`'s panel-creation guard.

---

### `Islet/Notch/NotchPanel.swift` (UNCHANGED — read for context only)

**Analog/context:** `NotchPanel.swift` lines 32 (`collectionBehavior`) and lines 34-36 (`canBecomeKey`/`canBecomeMain`):
```swift
collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary] // ISL-02: all Spaces, above fullscreen-aux
```
```swift
override var canBecomeKey: Bool { false }
override var canBecomeMain: Bool { false }
```
Per RESEARCH.md's Summary finding #2 and Pattern 3 (no reference implementation removes `.canJoinAllSpaces`), this line is NOT touched by the recommended (layered) implementation of Candidate C — read this file only to confirm the invariant `testPanelJoinsAllSpacesAboveFullscreenAux` continues to test is truly unaffected. If the planner later attempts the "replace, not layer" variant as a separate follow-up experiment (RESEARCH.md Open Question 2), this line and its test become live edit targets at that time — not in this phase's primary attempt.

---

### `IsletTests/NotchPanelTests.swift` (regression — must stay green, no edits expected)

**Analog:** the file itself (58 lines, read in full) — this file IS the regression fixture, not something to port a pattern from.

**The exact invariant this phase must not break** (lines 38-44):
```swift
func testPanelJoinsAllSpacesAboveFullscreenAux() {
    let panel = makePanel()
    XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces),
                  "ISL-02: the island must be visible across all Spaces.")
    XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary),
                  "ISL-02: the island must sit above fullscreen-auxiliary content.")
}
```
Per the layered-approach recommendation (RESEARCH.md Anti-Patterns / Open Question 2), this test needs ZERO changes for the primary Candidate C attempt. It only needs rewriting if the "replace, not layer" variant is separately attempted later.

**Focus-safety invariant that must also be independently re-verified on-device** (lines 25-29, D-04 per CONTEXT.md):
```swift
func testPanelNeverBecomesKeyOrMain() {
    let panel = makePanel()
    XCTAssertFalse(panel.canBecomeKey, "A non-activating overlay must never take key focus (D-07).")
    XCTAssertFalse(panel.canBecomeMain, "A non-activating overlay must never become main (D-07).")
}
```
This unit test alone is not sufficient per CONTEXT.md D-03 — the planner's tasks should still schedule an on-device UAT pass since the CGSSpace mechanism, though additive, changes window/Space plumbing this invariant depends on transitively.

**Test file skeleton pattern to copy IF a new `CGSSpaceTests.swift` is added** (structure only, from lines 1-17):
```swift
import XCTest
import AppKit
@testable import Islet

@MainActor
final class NotchPanelTests: XCTestCase {
    private func makePanel() -> NotchPanel {
        NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 32))
    }
    ...
}
```
If the planner decides a dedicated unit test for `CGSSpace`'s Swift-level behavior (not the private-symbol calls themselves, which are unit-untestable — see RESEARCH.md's Test Map) is worth adding — e.g. verifying the `windows` `Set` diffing logic in isolation with a stub — mirror this exact `@MainActor final class ... XCTestCase` shape, matching the two sibling files `FullscreenDetectorTests.swift` and `VisibilityDecisionTests.swift` already in `IsletTests/`.

---

## Shared Patterns

### `@_silgen_name` private-symbol binding (cross-cutting: `FullscreenSpaceProbe.swift` + new `CGSSpace.swift`)
**Source:** `Islet/Notch/FullscreenSpaceProbe.swift` lines 22-32
**Apply to:** `Islet/Notch/CGSSpace.swift` (all 7 new symbol bindings + the connection lookup)
- Both files use link-time `@_silgen_name` binding against symbols re-exported through `CoreGraphics`/`SkyLight` — no `dlopen`, no new SPM dependency.
- **Do NOT share/unify the connection-ID binding** between the two files (RESEARCH.md Pitfall 2) — `FullscreenSpaceProbe.swift` keeps its existing `CGSMainConnectionID() -> Int32`; `CGSSpace.swift` gets its own independent `_CGSDefaultConnection() -> UInt`. This is a deliberate divergence, not an oversight to "fix" by unifying.

### Single show/hide arbiter (Pattern 7)
**Source:** `Islet/Notch/NotchWindowController.swift:414` (`updateVisibility()`)
**Apply to:** any new code touching panel visibility — the new Space-join call is NOT a new arbiter; it is a one-time side effect inside `positionAndShow`'s panel-creation branch, upstream of `updateVisibility()`'s repeated calls.

### Fail-safe-to-visible philosophy
**Source:** `Islet/Notch/FullscreenSpaceProbe.swift` lines 40-41, 49-51, 73-75
**Apply to:** `CGSSpace.swift` — any ambiguity/failure in the new private-symbol calls must never cause the panel to be wrongly hidden; the existing `orderFrontRegardless()`/`orderOut(nil)` path in `updateVisibility()`/`positionAndShow()` remains the sole visibility gate, so a no-op Space-join at worst reproduces today's flash, never a stronger regression (silent permanent-hide).

### Documented private-API rationale-header comments
**Source:** `Islet/Notch/FullscreenSpaceProbe.swift` lines 3-20
**Apply to:** `CGSSpace.swift` header — same convention (WHY this exists, THE FIX summary, symbol/framework provenance) used throughout this codebase's private-API files.

### Owner-driven resource teardown in `deinit`
**Source:** `Islet/Notch/NotchWindowController.swift` lines 1039-1069 (`powerMonitor.stop()`, `bluetoothMonitor?.stop()`, `nowPlayingMonitor?.stop()`)
**Apply to:** the new Space wrapper's teardown, if controller-owned rather than a process-lifetime singleton.

## No Analog Found

None. All 4 files have an in-repo analog; the one genuinely new mechanism (the `CGSSpace` class body itself) has its exact source already verified against two independent shipping open-source implementations in `09-RESEARCH.md` (Architecture Pattern 1), so no further codebase search was needed — RESEARCH.md's fetched code IS the analog for the class body, while `FullscreenSpaceProbe.swift` is the analog for this project's specific `@_silgen_name` file-organization convention.

## Metadata

**Analog search scope:** `Islet/Notch/` (all `.swift` files), `IsletTests/` (test files referenced in RESEARCH.md's Test Map: `NotchPanelTests.swift`, `FullscreenDetectorTests.swift`, `VisibilityDecisionTests.swift`)
**Files scanned:** `Islet/Notch/CGSSpace.swift` (does not yet exist — confirmed via directory read), `Islet/Notch/NotchWindowController.swift` (1070 lines, read via 3 targeted non-overlapping ranges: 1-45, 234-313, 414-494, 556-600, 1030-1070), `Islet/Notch/NotchPanel.swift` (37 lines, read in full), `Islet/Notch/FullscreenSpaceProbe.swift` (85 lines, read in full), `IsletTests/NotchPanelTests.swift` (58 lines, read in full)
**Pattern extraction date:** 2026-07-04
