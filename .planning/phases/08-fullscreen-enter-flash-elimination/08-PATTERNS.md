# Phase 8: Fullscreen-Enter Flash Elimination - Pattern Map

**Mapped:** 2026-07-04
**Files analyzed:** 5 (3 modified source files, 2 extended test files — no new files, per RESEARCH.md "Recommended file changes (no new files)")
**Analogs found:** 5 / 5 — this phase modifies existing files in-place; the "analog" for each is the established convention ALREADY PRESENT in that same file (or its sibling in the same subsystem), not a different subsystem.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|---------------|
| `Islet/Notch/FullscreenSpaceProbe.swift` (+CGS bindings) | utility (thin system-call wrapper) | event-driven (private-symbol binding, not polling) | itself — existing `CGSMainConnectionID`/`CGSCopyManagedDisplaySpaces` `@_silgen_name` bindings in the same file | exact (same file, same pattern, additive) |
| `Islet/Notch/FullscreenDetector.swift` (+`pendingFullscreenTransition` param, conditional on Wave-0 finding) | utility (pure predicate) | transform (pure boolean function) | itself — existing `shouldShow(hasTarget:hideInFullscreen:isFullscreen:)` | exact (same file, additive parameter) |
| `Islet/Notch/NotchWindowController.swift` (+2 CGS observers, +teardown, +bounded flag/timer) | controller (AppKit glue / event-driven state owner) | event-driven | itself — existing `spaceObserver`/`appActivateObserver` registration (`start()` L255-263) + existing one-shot `DispatchWorkItem` idiom (`deviceBatteryWork`, L791-819) + existing `deinit` teardown (L1039-1069) | exact (same file, same controller, additive observers) |
| `IsletTests/FullscreenDetectorTests.swift` (extend, only if flag lands) | test | transform (pure-function unit test) | itself — existing fixture-based `XCTestCase` pattern | exact |
| `IsletTests/VisibilityDecisionTests.swift` (extend, only if flag lands) | test | transform (pure-function unit test) | itself — existing `shouldShow(...)` boolean-matrix tests | exact |

## Pattern Assignments

### `Islet/Notch/FullscreenSpaceProbe.swift` (utility, event-driven private-symbol binding)

**Analog:** the file's own existing `CGSMainConnectionID`/`CGSCopyManagedDisplaySpaces` bindings (lines 1-32)

**Imports pattern** (line 1):
```swift
import CoreGraphics
```
No new import needed — `CGSRegisterNotifyProc`/`CGSRemoveNotifyProc` resolve through this same `CoreGraphics` re-export per RESEARCH.md on-device confirmation (no linker changes, unlike Candidate B's `SLSManagedDisplayIsAnimating`).

**`@_silgen_name` binding pattern** (lines 22-27):
```swift
// CGSConnectionID is a C `int` → Int32 (ABI-compatible binding required by @_silgen_name).
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> Int32

@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray
```
Copy this EXACT declaration style for the two new bindings (`CGSRegisterNotifyProc`, `CGSRemoveNotifyProc`) and the `CGSNotifyProc` C-callback typealias — RESEARCH.md's "Code Examples" section gives the exact signatures to add here:
```swift
private let kCGSClientEnterFullscreen: UInt32 = 106
private let kCGSClientExitFullscreen: UInt32 = 107

typealias CGSNotifyProc = @convention(c) (UInt32, UnsafeMutableRawPointer?, Int, UnsafeMutableRawPointer?) -> Void

@_silgen_name("CGSRegisterNotifyProc") @discardableResult
func CGSRegisterNotifyProc(_ proc: CGSNotifyProc?, _ type: UInt32, _ userData: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("CGSRemoveNotifyProc") @discardableResult
func CGSRemoveNotifyProc(_ proc: CGSNotifyProc?, _ type: UInt32, _ userData: UnsafeMutableRawPointer?) -> Int32
```

**Fail-safe philosophy to preserve** (lines 40-41, 74-75, 84):
```swift
// FAIL-SAFE: any nil / parse failure / ambiguity returns `false` — we prefer showing
// the island over wrongly hiding it.
...
guard let display = chosen, ... else {
    return false // missing keys / wrong types → fail-safe
}
```
Any new code in this file (or the bounded-flag logic it feeds in the controller) must keep this "ambiguous → show, don't wrongly hide" bias — this is the file's single most load-bearing convention and is explicitly called out in 08-CONTEXT.md's "Established Patterns."

**DEBUG-only diagnostic logging pattern** (lines 77-82):
```swift
#if DEBUG
// Confirm the constant on-device: ...
print("[ISL-05] builtin current-space type = \(type)")
#endif
```
Use this exact `#if DEBUG ... print("[TAG] ...") ... #endif` idiom for the Wave-0 timing probe RESEARCH.md specifies (tag suggestion: `[FS-01 probe]`, matching RESEARCH.md's own example).

---

### `Islet/Notch/FullscreenDetector.swift` (utility, pure predicate — conditional change)

**Analog:** the file's own `shouldShow(...)` function (lines 25-31)

**Current signature and doc-comment convention** (lines 25-31):
```swift
// ISL-05 / Pattern 7 — the ONE visibility decision. Every "should the pill be
// visible right now?" input (clamshell/target from Phase 1, fullscreen from
// Phase 2) converges here. hideInFullscreen is the single gating flag (D-10):
// default true ships the hide; a future Phase-6 settings toggle flips it.
func shouldShow(hasTarget: Bool, hideInFullscreen: Bool, isFullscreen: Bool) -> Bool {
    hasTarget && !(hideInFullscreen && isFullscreen)
}
```
IF (and only if) the Wave-0 probe shows the CGS space-type has not yet flipped when event 106 fires, extend to (RESEARCH.md "Integration Point"):
```swift
func shouldShow(hasTarget: Bool, hideInFullscreen: Bool, isFullscreen: Bool, pendingFullscreenTransition: Bool) -> Bool {
    hasTarget && !(hideInFullscreen && (isFullscreen || pendingFullscreenTransition))
}
```
Keep it a pure function with no AppKit/state dependency — this is the single explicitly-permitted exception to "FullscreenDetector.swift stays untouched" (08-CONTEXT.md canonical_refs). Update every call site (`NotchWindowController.updateVisibility()` L425-427) and every test call site in the same commit if this path is taken.

---

### `Islet/Notch/NotchWindowController.swift` (controller, event-driven — observer + bounded-timer additions)

**Analog 1 — observer registration:** existing `spaceObserver`/`appActivateObserver` wiring (`start()`, lines 249-263)

**Imports pattern** (lines 1-2):
```swift
import AppKit
import SwiftUI
```
No new import — `CGSRegisterNotifyProc` resolves via `FullscreenSpaceProbe.swift`'s existing `import CoreGraphics`, visible module-wide within the `Islet` target.

**Existing observer registration to mirror** (lines 249-263):
```swift
// Pattern 6 (ISL-05): fullscreen enter/exit and Space switches feed the SAME single
// visibility decision. activeSpaceDidChange fires when an app takes/leaves its
// fullscreen Space; didActivateApplication catches fullscreen-video / QuickLook kinds
// that may not migrate Spaces (A6). NSWorkspace notifications already arrive on the
// main queue settled, so no next-run-loop hop is needed here (updateVisibility is
// idempotent regardless). Removed from the workspace center in deinit.
let wc = NSWorkspace.shared.notificationCenter
spaceObserver = wc.addObserver(
    forName: NSWorkspace.activeSpaceDidChangeNotification,
    object: nil, queue: .main
) { [weak self] _ in self?.updateVisibility() }
appActivateObserver = wc.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification,
    object: nil, queue: .main
) { [weak self] _ in self?.updateVisibility() }
```
New CGS registration follows the same "register in `start()`, store a token/context as a stored property, tear down in `deinit`" shape, but per RESEARCH.md's Pitfall 1, the CGS callback is a raw C function pointer with NO main-thread guarantee (unlike this `queue: .main` NSWorkspace pattern) — MUST `DispatchQueue.main.async` before touching `self`:
```swift
private let fullscreenTransitionCallback: CGSNotifyProc = { type, _, _, userData in
    guard let userData else { return }
    let controller = Unmanaged<NotchWindowController>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async { controller.handleFullscreenTransitionEvent(type: type) }
}
private lazy var selfContext = Unmanaged.passUnretained(self).toOpaque()

// in start():
CGSRegisterNotifyProc(fullscreenTransitionCallback, kCGSClientEnterFullscreen, selfContext)
CGSRegisterNotifyProc(fullscreenTransitionCallback, kCGSClientExitFullscreen, selfContext)
```

**Analog 2 — bounded one-shot `DispatchWorkItem` idiom** (only needed if the `pendingFullscreenTransition` design is required): `scheduleDeviceBatteryRefresh` (lines 791-819)
```swift
private func scheduleDeviceBatteryRefresh(address: String, attempt: Int = 0) {
    pollingAddress = address
    deviceBatteryWork?.cancel()
    guard attempt < 6 else { return }
    let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        guard self.pollingAddress == address else { return }
        ...
    }
    deviceBatteryWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
}
```
Mirror this EXACT "cancel-previous, create fresh `DispatchWorkItem`, store as a property, schedule via `asyncAfter`" shape for the bounded safety-timeout that clears `pendingFullscreenTransition` (Pitfall 3 in RESEARCH.md — an unbounded flag with no clear path permanently hides the island). The `graceWorkItem`/`dismissWorkItem` properties (declared lines 163-166, 186) are the same one-shot family and can also be referenced as precedent in code comments.

**Core visibility arbiter to feed, NOT bypass** (lines 407-440, Pattern 7):
```swift
// Pattern 7 (ISL-05) — the ONE visibility decision and the SOLE show/hide site. ...
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
        panel?.orderOut(nil)   // The ONLY hide call in the file (single path).
        hotZone = nil
        expandedZone = nil
        pointerInZone = false
    }
}
```
The new `handleFullscreenTransitionEvent(type:)` method must ONLY set/clear the `pendingFullscreenTransition` flag (if built) and then call `updateVisibility()` — it must NEVER call `panel?.orderOut`/`positionAndShow` directly (that would create the second show/hide path Pitfall/Pattern 7 explicitly forbids). If `shouldShow` gains the new parameter, the `updateVisibility()` call site above must pass it through.

**deinit teardown pattern to extend** (lines 1039-1069):
```swift
deinit {
    // The screen-parameters observer lives on the DEFAULT center; the two fullscreen
    // observers live on NSWorkspace's OWN center — removing a workspace observer from the
    // default center is a silent no-op leak, so each is removed from its respective center.
    if let o = observer { NotificationCenter.default.removeObserver(o) }
    let wc = NSWorkspace.shared.notificationCenter
    if let o = spaceObserver { wc.removeObserver(o) }
    if let o = appActivateObserver { wc.removeObserver(o) }
    ...
    graceWorkItem?.cancel()
    ...
    deviceBatteryWork?.cancel()
    ...
}
```
Add `CGSRemoveNotifyProc(fullscreenTransitionCallback, kCGSClientEnterFullscreen, selfContext)` / `...ExitFullscreen...` teardown here, using the EXACT same proc/type/userData triple used at registration (Security Domain note in RESEARCH.md: "must be called in deinit with the exact same proc/type/userData triple used at registration — mirror the existing mouseMonitor/powerMonitor/nowPlayingMonitor teardown discipline"), plus `.cancel()` the new bounded timeout `DispatchWorkItem` alongside `graceWorkItem?.cancel()`/`deviceBatteryWork?.cancel()`.

---

### `IsletTests/FullscreenDetectorTests.swift` and `IsletTests/VisibilityDecisionTests.swift` (test, transform — conditional extension)

**Analog:** the files' own existing fixture/boolean-matrix test style

**`FullscreenDetectorTests.swift` fixture pattern** (lines 12-53):
```swift
final class FullscreenDetectorTests: XCTestCase {
    private func notchedBuiltin() -> ScreenDescriptor { ... }
    private func collapsedBuiltin() -> ScreenDescriptor { ... }

    func testNotchedBuiltinIsNotFullscreen() {
        XCTAssertFalse(isTrueFullscreen(builtin: notchedBuiltin()))
    }
    ...
}
```
Not directly extended by this phase unless a new pure predicate is added alongside `isTrueFullscreen` — RESEARCH.md's test map targets `VisibilityDecisionTests.swift` primarily for the new `pendingFullscreenTransition` boolean-matrix cases.

**`VisibilityDecisionTests.swift` boolean-matrix pattern** (lines 9-40):
```swift
final class VisibilityDecisionTests: XCTestCase {
    func testTargetPresentNotFullscreenShows() {
        XCTAssertTrue(shouldShow(hasTarget: true, hideInFullscreen: true, isFullscreen: false))
    }
    func testTargetPresentFullscreenWithHideFlagHides() {
        XCTAssertFalse(shouldShow(hasTarget: true, hideInFullscreen: true, isFullscreen: true))
    }
    ...
}
```
If `pendingFullscreenTransition` is added to `shouldShow(...)`, extend EVERY existing test call site with the new parameter (compile-breaking otherwise) AND add new cases exercising the new axis, e.g.:
```swift
func testPendingTransitionAloneHidesLikeFullscreen() {
    XCTAssertFalse(shouldShow(hasTarget: true, hideInFullscreen: true, isFullscreen: false, pendingFullscreenTransition: true))
}
func testPendingTransitionIgnoredWhenHideFlagOff() {
    XCTAssertTrue(shouldShow(hasTarget: true, hideInFullscreen: false, isFullscreen: false, pendingFullscreenTransition: true))
}
```
Mirror the existing one-assertion-per-test, descriptive-`test`-name-as-documentation style exactly.

---

## Shared Patterns

### Pattern 7 — single `updateVisibility()` show/hide arbiter
**Source:** `Islet/Notch/NotchWindowController.swift` lines 407-440
**Apply to:** the new CGS observer handler (`handleFullscreenTransitionEvent(type:)`) — it must set/clear state and call `updateVisibility()`, NEVER call `panel?.orderOut`/`positionAndShow` itself. This is the single most important cross-cutting constraint of the phase (explicitly named in both 08-CONTEXT.md canonical_refs and RESEARCH.md's Anti-Patterns section).

### Fail-safe-to-visible philosophy
**Source:** `Islet/Notch/FullscreenSpaceProbe.swift` lines 40-41, 74-75, 84
**Apply to:** any new proactive signal or bounded-timeout design — ambiguity/failure/timeout must resolve to "show" (never permanently hide), per 08-CONTEXT.md's "Established Patterns" and RESEARCH.md Pitfall 3.

### `@_silgen_name` private-symbol binding (same risk tier, D-01/D-02 ceiling)
**Source:** `Islet/Notch/FullscreenSpaceProbe.swift` lines 22-27
**Apply to:** `FullscreenSpaceProbe.swift`'s new `CGSRegisterNotifyProc`/`CGSRemoveNotifyProc` bindings — copy the declaration style (top-level `@_silgen_name`-annotated global func, ABI-correct primitive types) exactly; do not `dlopen` or introduce any new framework beyond the already-accepted CGS/SkyLight tier.

### One-shot, cancel-and-replace `DispatchWorkItem` (no recurring timers)
**Source:** `Islet/Notch/NotchWindowController.swift` lines 791-819 (`scheduleDeviceBatteryRefresh`/`deviceBatteryWork`), same family as `graceWorkItem` (line 186) and `dismissWorkItem` (line 166)
**Apply to:** the bounded safety-timeout that clears `pendingFullscreenTransition` (if the flag design is needed) — "cancel previous, create fresh work item, store as property, schedule via `asyncAfter`, cancel again in `deinit`."

### Observer/resource teardown in `deinit`, matched to the exact registration
**Source:** `Islet/Notch/NotchWindowController.swift` lines 1039-1069
**Apply to:** the new CGS notify-proc teardown (`CGSRemoveNotifyProc` with the identical proc/type/userData triple used at registration) and the new bounded-timer `.cancel()` — add alongside the existing `spaceObserver`/`appActivateObserver`/`deviceBatteryWork` teardown lines, same file, same `deinit`.

### DEBUG-only diagnostic print, gated `#if DEBUG`
**Source:** `Islet/Notch/FullscreenSpaceProbe.swift` lines 77-82
**Apply to:** the Wave-0 on-device timing probe RESEARCH.md specifies — never ships a `print` in release builds.

## No Analog Found

None — every file this phase touches already exists and already contains the exact convention needed (this is a targeted extension of three files, not new-subsystem work). RESEARCH.md's "Recommended file changes (no new files)" table confirms no new source file is created.

## Metadata

**Analog search scope:** `Islet/Notch/` (5 existing files read in full or targeted-section), `IsletTests/` (2 existing test files read in full), `project.yml` (grepped for `SWIFT_VERSION`/`ENABLE_APP_SANDBOX`/linker settings — confirms Candidate A needs zero config changes, Candidate B would need `FRAMEWORK_SEARCH_PATHS`/`OTHER_LDFLAGS` additions if ever pursued).
**Files scanned:** `FullscreenSpaceProbe.swift`, `FullscreenDetector.swift`, `NotchWindowController.swift` (imports/properties/`start()`/`updateVisibility()`/`scheduleDeviceBatteryRefresh`/`deinit` sections), `FullscreenDetectorTests.swift`, `VisibilityDecisionTests.swift`, `project.yml`.
**Pattern extraction date:** 2026-07-04
