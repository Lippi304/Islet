# Phase 24: Drag-In - Pattern Map

**Mapped:** 2026-07-11
**Files analyzed:** 4 (all modified, zero new files)
**Analogs found:** 4 / 4 (all internal — same-file precedent, no external analog needed)

## File Classification

This phase adds NO new files (RESEARCH.md "Recommended Project Structure" — explicit decision, see Anti-Patterns). Everything is a modification to existing files, using existing patterns already proven in the SAME files as the direct analog.

| Modified File | Role | Data Flow | Closest Analog (same file, different section) | Match Quality |
|----------------|------|-----------|--------------------------------------------------|---------------|
| `Islet/Notch/NotchWindowController.swift` — new `dragApproachMonitor`/`dragEndMonitor` properties + `handleDragApproachTick()`/`handleDragApproachEnd()` methods | controller (AppKit window shell) | event-driven (global `NSEvent` monitor) | `dragReleaseMonitor` + `beginShelfItemDrag()`/`endShelfItemDrag()` (lines 219, 1268-1301) and `mouseMonitor` (line 208, 324-326) — same file, same class | exact (same idiom, same class, same author intent) |
| `Islet/Notch/NotchWindowController.swift` — new `isWithinDragAcceptRegion(_:)` + `dragLandingMaxY` geometry | controller (pure geometry helper) | request-response (pure function) | `visibleContentZone()` (lines 704-717) and `expandedZone`/`hotZone` computation in `positionAndShow()` (lines 601-667) | exact |
| `Islet/Notch/NotchWindowController.swift` — new `isDragApproaching` edge-tracked flag driving auto-expand | controller (state edge-detector) | event-driven | `pointerInZone` edge-tracking in `handlePointer(at:)` (lines 671-702) | exact |
| `Islet/Notch/DragDropSupport.swift` — NO code changes; called with a different `NSPasteboard` instance | utility (pure) | transform | itself — `fileURLs(from:)`/`shouldAcceptDrop(isExpanded:urls:)` (lines 10-19) — reused unchanged | exact, zero-diff reuse |

## Pattern Assignments

### `NotchWindowController.swift` — `dragApproachMonitor` (arm/disarm global monitor)

**Analog:** `mouseMonitor` (property line 208, armed in `start()` lines 320-326, disarmed in `deinit` line 1338)

**Property declaration pattern** (line 208):
```swift
private var mouseMonitor: Any?
```

**Arm pattern in `start()`** (lines 320-326):
```swift
// Pattern 1 (focus-safe core): a GLOBAL monitor observes COPIES of .mouseMoved
// events posted to OTHER apps — it never consumes them, never activates Islet, and
// its handler runs on the MAIN thread (safe to touch AppKit / @Published directly).
// We watch ONLY .mouseMoved (no keyboard mask) to minimise the privacy surface.
mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
    self?.handlePointer(at: NSEvent.mouseLocation)
}
```

**Disarm pattern in `deinit`** (line 1338):
```swift
if let m = mouseMonitor { NSEvent.removeMonitor(m) }
```

Apply this exact three-part shape (declare `Any?` property → arm in `start()` with a `[weak self]` closure calling a named handler → disarm in `deinit`) for both the new `dragApproachMonitor` (`.leftMouseDragged`) and `dragEndMonitor` (`.leftMouseUp`).

---

### `NotchWindowController.swift` — arm/disarm a monitor ONLY for the duration of a session (not always-on)

**Analog:** `dragReleaseMonitor` + `beginShelfItemDrag()`/`endShelfItemDrag()` (lines 211-219, 1265-1301)

**Session-scoped property block** (lines 211-219):
```swift
// Phase 21 / SHELF-06 / D-03 — the shelf-item drag pin: while true, handleHoverExit's
// graceWorkItem defers the collapse. Released via BOTH a best-effort early signal
// (dragReleaseMonitor, a .leftMouseUp global monitor mirroring mouseMonitor's .mouseMoved
// idiom, armed only for the duration of an active drag) AND a guaranteed 20s safety net
// (dragPinSafetyNetWorkItem) so the pin can never outlive a real drag gesture indefinitely.
private var isDraggingShelfItem = false
private var dragPinSafetyNetWorkItem: DispatchWorkItem?
private let dragPinSafetyNetDuration: TimeInterval = 20.0
private var dragReleaseMonitor: Any?
```

**Begin (conditional arm)** (lines 1268-1283):
```swift
private func beginShelfItemDrag() {
    isDraggingShelfItem = true
    graceWorkItem?.cancel()
    graceWorkItem = nil

    dragPinSafetyNetWorkItem?.cancel()
    let safetyNet = DispatchWorkItem { [weak self] in self?.endShelfItemDrag() }
    dragPinSafetyNetWorkItem = safetyNet
    DispatchQueue.main.asyncAfter(deadline: .now() + dragPinSafetyNetDuration, execute: safetyNet)

    if dragReleaseMonitor == nil {
        dragReleaseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            self?.endShelfItemDrag()
        }
    }
}
```

**End (idempotent guard + teardown + re-sync)** (lines 1285-1301):
```swift
// Phase 21 / SHELF-06 / D-03 — idempotent (the safety net and the mouseUp monitor may both
// eventually fire, in either order; only the first call has any effect). Tears down the
// per-drag monitor (minimal always-on observation surface) and, only if the pointer is
// already outside the hot zone, re-invokes handleHoverExit() so the island resumes its
// normal grace-collapse countdown at the next natural transition (D-13-style).
private func endShelfItemDrag() {
    guard isDraggingShelfItem else { return }
    isDraggingShelfItem = false
    dragPinSafetyNetWorkItem?.cancel()
    dragPinSafetyNetWorkItem = nil
    if let m = dragReleaseMonitor { NSEvent.removeMonitor(m) }
    dragReleaseMonitor = nil
    // WR-01: pointerInZone is only kept fresh by the .mouseMoved monitor, which doesn't fire
    // during an OS drag session — re-sample the live pointer instead of trusting the frozen
    // flag, so a drag dropped outside the zone actually schedules the collapse.
    handlePointer(at: NSEvent.mouseLocation)
}
```

**Apply to:** `handleDragApproachEnd()` (RESEARCH Pattern 4) — this is the DIRECT template for the required `guard isDragApproaching else { return }` idempotent-guard shape (Pitfall 4) AND the mandatory `handlePointer(at: NSEvent.mouseLocation)` re-sync call at the end (Pitfall 3/WR-01 — the exact same staleness problem: `.mouseMoved` freezes during ANY drag session, inbound or outbound). RESEARCH.md's Pattern 4 code sample is already written to match this shape; the planner should cite these exact line numbers as the precedent, not just the RESEARCH.md sample.

---

### `NotchWindowController.swift` — edge-tracked boolean flag (enter/exit, not per-tick)

**Analog:** `pointerInZone` inside `handlePointer(at:)` (lines 226, 671-702)

**Declaration** (line 226):
```swift
// WR-01: the pointer-in-hot-zone edge, tracked from RAW geometry — NOT derived from
// `interaction.isHovering` (which is true for BOTH .hovering AND .expanded, so a
// re-entry while expanded would never read as an enter edge and never cancel the
// pending grace collapse, letting the island collapse out from under the pointer).
// Reset in updateVisibility's hide branch so it can't go stale across a hide/show cycle.
private var pointerInZone = false
```

**Edge-detect + one-shot side effect** (lines 671-702):
```swift
private func handlePointer(at point: CGPoint) {
    lastPointerLocation = point
    let activeZone = interaction.isExpanded ? (expandedZone ?? hotZone) : hotZone
    guard let zone = activeZone else { return }
    let inside = zone.contains(point)
    if inside && !pointerInZone {
        pointerInZone = true
        handleHoverEnter()          // cancels the pending grace collapse inside
    } else if !inside && pointerInZone {
        pointerInZone = false
        handleHoverExit()
    }
    if interaction.isExpanded {
        syncClickThrough()
    }
}
```

**Apply to:** `isDragApproaching` (RESEARCH Pattern 2's `recheckDragAcceptRegion()`) — same enter/exit edge shape, called from `handleDragApproachTick()` on every `.leftMouseDragged` tick instead of `.mouseMoved`. Reset `false→true` fires the ONE-TIME haptic + spring + `.dragEntered` transition (Pitfall 3 in RESEARCH — repeated firing on every tick is the bug this shape prevents).

---

### `NotchWindowController.swift` — hover-enter one-shot side effect (haptic + spring + `nextState`)

**Analog:** `handleHoverEnter()` (lines 719-754)

```swift
private func handleHoverEnter() {
    #if DEBUG
    if !didLogFirstHover {
        didLogFirstHover = true
        print("hover tick — global mouse monitor fired (A1 probe)") // never logs the location
    }
    #endif
    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    graceWorkItem?.cancel()
    graceWorkItem = nil
    dismissWorkItem?.cancel()
    mediaDismissWorkItem?.cancel()
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        interaction.phase = nextState(interaction.phase, .pointerEntered)
    }
    syncClickThrough()
}
```

**Apply to:** the `isDragApproaching` `false→true` branch in RESEARCH Pattern 2 — same haptic call, same `withAnimation(.spring(response: springResponse, dampingFraction: springDamping))` wrapper, same `nextState(interaction.phase, .dragEntered)` shape (just a different `InteractionEvent` case, already defined). `renderPresentation()` is called inside the spring per RESEARCH Pattern 2's sample — mirrors `handleHoverExit`'s own `renderPresentation()` call at line 803, not `handleHoverEnter`'s (which has no activity-presentation implication). Reuse `springResponse`/`springDamping` constants (lines 264-265) — do not introduce new spring tuning constants for this phase (out of scope, Phase 25 already owns spring retuning).

---

### `NotchWindowController.swift` — geometry helper (pure, `CGRect`-based, computed alongside `positionAndShow()`)

**Analog:** `visibleContentZone()` (lines 704-717) + `expandedZone`/`hotZone` computation inside `positionAndShow()` (lines 601-667)

**Existing accept-zone geometry, already computed** (lines 643-647):
```swift
// The hot-zone is the COLLAPSED pill (padded), in the same global bottom-left coords.
hotZone = collapsedFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
// While expanded, the WHOLE expanded island (the panel union, padded) keeps it open so
// the pointer can reach the transport controls without tripping the grace-collapse.
expandedZone = panelFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
```

**Pure-function shape to mirror** (lines 704-717, `visibleContentZone()`):
```swift
private func visibleContentZone() -> CGRect? {
    guard let hotZone else { return nil }
    let collapsedFrame = hotZone.insetBy(dx: hotZonePadding, dy: hotZonePadding)
    let shelfHeight = shelfViewState.items.isEmpty ? 0 : NotchPillView.shelfRowHeight
    let visibleFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                          expandedSize: CGSize(width: expandedSize.width,
                                                                height: expandedSize.height + shelfHeight))
    return visibleFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
}
```

**Apply to:** `isWithinDragAcceptRegion(_:)` (RESEARCH Pattern 2) — same `guard let ... else { return false/nil }` optional-unwrap shape, reuses `expandedZone` directly (D-02, no new geometry needed for the zone itself), adds ONE new stored property `dragLandingMaxY: CGFloat?` (set alongside `hotZone`/`expandedZone` in `positionAndShow()`, cleared alongside them in `updateVisibility()`'s hide branch — grep confirms `expandedZone = nil` at line 590, the exact clear-site to mirror). This is the ONE genuinely new piece of state this phase introduces to `positionAndShow()`.

---

### `Islet/Notch/DragDropSupport.swift` — REUSED VERBATIM, zero changes

**Analog:** the file itself (lines 1-19)

```swift
import AppKit

func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
    (pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]) ?? []
}

func shouldAcceptDrop(isExpanded: Bool, urls: [URL]) -> Bool {
    !isExpanded && !urls.isEmpty
}
```

**Apply to:** call `fileURLs(from: NSPasteboard(name: .drag))` and `shouldAcceptDrop(isExpanded: false, urls: urls)` directly from the new `handleDragApproachEnd()` / `handleDragApproachTick()` — confirmed by `DragDropSupportTests.swift` to work against ANY named `NSPasteboard`, not just a drop-session's `sender.draggingPasteboard`. Do not add an overload or wrapper.

---

### `Islet/Notch/NotchWindowController.swift` — landing a dropped URL into the shelf

**Analog:** `seedDebugShelfItems()` (lines 1307-1325, `#if DEBUG` only) — the only existing call site in this file that goes `URL → ShelfFileStore.makeSessionCopy(of:id:) → ShelfItem(...) → shelfCoordinator.append(item) → resyncShelfViewState()`.

```swift
let id = UUID()
guard let localURL = try? ShelfFileStore.makeSessionCopy(of: source, id: id) else { continue }
let item = ShelfItem(id: id, originalURL: source, localURL: localURL, filename: seed.name, addedAt: Date())
shelfCoordinator.append(item)
// ...
resyncShelfViewState(animated: false)
```

**Apply to:** `handleDragApproachEnd()`'s accept branch — same four-step sequence, looped over `urls` in drop order (CONTEXT.md Claude's Discretion, Phase 19 D-06 append-order). `guard let ... else { continue }` on a per-URL copy failure is the existing silent-no-op precedent (D-07) — one bad file in a multi-file drag must not abort the rest. Call `resyncShelfViewState()` (animated, default `true` — this is a live user-facing drop, not a debug seed) once after the loop, mirroring `handleShelfClearAll()` (line 1260-1263) and the other real (non-debug) shelf-mutation call sites which all call `resyncShelfViewState()` with no `animated:` override.

## Shared Patterns

### Global-monitor arm/disarm lifecycle
**Source:** `NotchWindowController.swift` — `mouseMonitor` (208, 324-326, 1338) and `dragReleaseMonitor` (219, 1278-1279, 1295-1296, 1344)
**Apply to:** both new monitors — declare as `private var ... : Any?`, arm in `start()`, remove in `deinit` (and, for the session-scoped `dragEndMonitor`, also remove it inside `handleDragApproachEnd()` itself once the session concludes, mirroring `dragReleaseMonitor`'s teardown in `endShelfItemDrag()`).
```swift
if let m = mouseMonitor { NSEvent.removeMonitor(m) }
```

### Single-arbiter click-through — DO NOT TOUCH
**Source:** `NotchWindowController.swift` `syncClickThrough()` (lines 756-784)
**Apply to:** Nothing in this phase's new code should write `panel?.ignoresMouseEvents` directly. Per RESEARCH Pattern 3 and CR-01 project memory, the new monitors are pure observers; `handlePointer(at:)` (already called from `handleDragApproachEnd()`'s mandatory Pitfall-3 re-sync) is the ONLY path that reaches `syncClickThrough()`, and that is by reuse, not new logic.
```swift
private func syncClickThrough() {
    let interactive: Bool
    if interaction.isExpanded {
        interactive = visibleContentZone()?.contains(lastPointerLocation) ?? false
    } else {
        interactive = pointerInZone
    }
    panel?.ignoresMouseEvents = !interactive
}
```

### Silent no-op on rejected/missing input
**Source:** `ShelfFileStore.makeSessionCopy` (`try?` callers), `ShelfCoordinator.append` (rejects duplicates by deleting the orphaned copy), `DragDropSupport.shouldAcceptDrop`
**Apply to:** every branch of `handleDragApproachTick()`/`handleDragApproachEnd()` — no `URL` resolves → no-op; `shouldAcceptDrop` false → no-op; a single file's copy fails mid-loop → skip that file only (D-07's reliability bar, never a crash or stuck state).

### `withAnimation(.spring(response:dampingFraction:))` at every phase mutation
**Source:** `handleHoverEnter()` (747-749), `handleHoverExit()`'s work item (799-804) — the ISL-04/D-07 spring constants (`springResponse = 0.6`, `springDamping = 0.62`, lines 264-265)
**Apply to:** the `nextState(interaction.phase, .dragEntered)` mutation inside the new `isDragApproaching` enter-edge branch. Do not introduce new spring constants.

## No Analog Found

None — every piece of this phase's required code has a direct, same-file, same-class precedent. This is expected: RESEARCH.md's own "Recommended Project Structure" and "Don't Hand-Roll" sections explicitly conclude no new files, no new types, and no new external technique are needed — this phase is a new detection SOURCE feeding entirely existing sinks (`.dragEntered`, `ShelfCoordinator.append`, `syncClickThrough()`).

## Metadata

**Analog search scope:** `Islet/Notch/` (`NotchWindowController.swift`, `NotchPanel.swift`, `DragDropSupport.swift`, `NotchInteractionState.swift`), `Islet/Shelf/` (`ShelfCoordinator.swift`, `ShelfFileStore.swift`), `IsletTests/DragDropSupportTests.swift`
**Files scanned:** 6 source + 1 test file (all read in full except `NotchWindowController.swift`, which was grepped then read via 4 non-overlapping targeted ranges: 200-330, 595-725, 725-825, 1260-1360)
**Pattern extraction date:** 2026-07-11

---

## Post-Task-3 Addition: DropInterceptTap Pattern Guidance

**Added:** 2026-07-11 (post-Task-3 UAT architecture gap — see `24-CONTEXT.md` D-10 through D-15, `24-RESEARCH.md` `## CGEventTap Drop-Interception Research`)
**Scope:** This section covers ONLY the new `DropInterceptTap` mechanism. It does not modify or supersede any pattern above — the `DragApproachDetector` global-monitor patterns (Patterns 1-4, already implemented and on-device confirmed through Task 2) remain valid and unchanged.

### 1. Confirmed: zero CGEventTap/CFMachPort/permission-check precedent in this codebase

Searched the full `Islet/` tree (`grep -rn "IOBluetooth\|AXIsProcessTrusted\|CGEventTap\|register(forConnectNotifications"`) — no hits for `CGEventTap`, `CFMachPort`, `CGEvent.tapCreate`, `AXIsProcessTrusted`, or any TCC preflight/request call anywhere. Confirmed: **this is a genuinely novel mechanism for this codebase**, exactly as `24-CONTEXT.md`'s "Post-Task-3 addition" note and `24-RESEARCH.md` §5 both state.

The closest available analogs are all **different-tier** matches (a permission-gated OS-notification wrapper, not an event tap):
- `Islet/Notch/BluetoothMonitor.swift` — a permission-adjacent (`NSBluetoothAlwaysUsageDescription`-gated), small owning class with OS-token retention + `start()`/`stop()` lifecycle. Closest **lifecycle-shape** analog.
- `Islet/Notch/NotchWindowController.swift` `powerMonitor`/`nowPlayingMonitor`/`bluetoothMonitor` — the established "small owning type held as an optional property, constructed+started conditionally in `start()`, torn down in `deinit`" convention. Closest **ownership/wiring** analog.
- No existing analog at all for: a C-function-pointer callback (`CGEventTapCreate`'s `callback:` parameter), `Unmanaged<T>`/`UnsafeMutableRawPointer` context-threading, `CFMachPort`/`CFRunLoopSource` run-loop wiring, or any `AXIsProcessTrusted`/TCC preflight-request call. These are addressed as "No Analog Found" in §5 below.

### 2. Recommended file/type structure for `DropInterceptTap`

**New file:** `Islet/Notch/DropInterceptTap.swift` — matches `24-RESEARCH.md` §5's explicit recommendation and this project's existing one-integration-per-file convention (`BluetoothMonitor.swift`, `PowerSourceMonitor.swift`, `NowPlayingMonitor.swift` are each a single external-integration wrapper in their own file inside `Islet/Notch/`).

**What it owns** (mirrors `BluetoothMonitor`'s token-retention shape, applied to Core Graphics primitives instead of `IOBluetoothUserNotification`):
```swift
final class DropInterceptTap {
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let shouldSwallow: () -> Bool   // reads NotchWindowController's EXISTING isDragApproaching +
                                              // isWithinDragAcceptRegion(...) — no new parallel state (CR-01 discipline)
}
```
This is the exact same shape as `BluetoothMonitor`'s `connectToken`/`disconnectTokens` (retained OS handles, released in `stop()`) — just Core Graphics types instead of IOBluetooth types. `24-RESEARCH.md`'s own design sketch (§5) already follows this shape; treat it as the concrete target, not merely illustrative.

**Where it lives / how it's owned:** as a plain optional property on `NotchWindowController`, constructed and `start()`-called from `NotchWindowController.start()`, torn down in `deinit` — same three-site wiring `bluetoothMonitor` uses (declare optional property near line 118 → construct+start conditionally near line 385 → `stop()` in deinit near line 1474). Do NOT fold the tap's callback logic inline into `NotchWindowController` itself — `24-RESEARCH.md` §5 point 1 is explicit that the C-function-pointer/`Unmanaged` idiom is a real readability cost that should stay isolated in its own file, unlike the `dragApproachMonitor`/`dragEndMonitor` additions (which DO stay inline per the original Pattern Map above, since those use the same `[weak self]`-closure idiom as every other monitor in the file).

### 3. Closest lifecycle analog to mirror (arm/disarm shape)

**Primary analog: `BluetoothMonitor.swift` (whole file, 157 lines) — closest available match**, despite being IOBluetooth rather than CGEventTap:
- `start()` is idempotent (`guard !running else { return }`, line 56) — mirror this for `DropInterceptTap.start()`, guarding on `machPort == nil`.
- `stop()` unregisters every retained OS handle and nils the properties (lines 150-156) — mirror exactly: `CFRunLoopRemoveSource` + `CGEvent.tapEnable(tap:enable:false)` + nil both properties.
- Owner-driven teardown from the controller's `deinit`, `nonisolated func stop()` so it's callable from a nonisolated deinit context (line 150) — `DropInterceptTap.stop()` should be `nonisolated` for the same reason, mirroring `bluetoothMonitor?.stop()` at line 1474.
- Off-main delivery hop: `BluetoothMonitor`'s `connected(_:device:)`/`disconnected(_:device:)` explicitly `DispatchQueue.main.async` because IOBluetooth calls back on its own queue (lines 71, 86). **`DropInterceptTap`'s situation is different and arguably simpler** — per `24-RESEARCH.md` §4, the tap's run-loop source is added to `CFRunLoopGetMain()`, so the C callback already fires on the main run loop; no explicit hop is needed. Do not copy the `DispatchQueue.main.async` wrapping — it's a BluetoothMonitor-specific requirement that doesn't apply here.

**Secondary analog: `NotchWindowController`'s own `dragReleaseMonitor`/`beginShelfItemDrag()`/`endShelfItemDrag()` (Pattern Map above, lines 211-219, 1265-1301)** — for the narrow-interface discipline: `DropInterceptTap` should take a single injected closure (`shouldSwallow: () -> Bool`) exactly the way the controller already threads `isDraggingShelfItem`/`isDragApproaching` state through closures rather than exposing raw state — this is the SAME CR-01 single-arbiter discipline already enforced above, extended to the new type.

**What is NOT a match and should not be forced:** the exact three-part "declare `Any?` → arm via `NSEvent.addGlobalMonitorForEvents([weak self] closure) → disarm via `NSEvent.removeMonitor`" shape used for `mouseMonitor`/`dragApproachMonitor`/`dragEndMonitor` does not apply to `DropInterceptTap` — `CGEventTapCreate`'s callback is a capture-less C function pointer, not an escaping Swift closure, so context must be threaded via `Unmanaged<DropInterceptTap>.passUnretained(self).toOpaque()` / `.fromOpaque(userInfo).takeUnretainedValue()` instead (per `24-RESEARCH.md` §4, and confirmed as genuinely new by the codebase search in §1 above).

### 4. `project.yml`/Info.plist entry for the new permission

**Exact existing analog** — `project.yml`, `targets.Islet.settings.base`, the `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription` line:
```yaml
INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription: "Islet zeigt eine kurze Mitteilung in der Notch, wenn ein Bluetooth-Gerät wie deine AirPods verbunden oder getrennt wird."
```
This is the exact `INFOPLIST_KEY_*` XcodeGen convention (a build setting, not a hand-edited `Info.plist` — `GENERATE_INFOPLIST_FILE: YES` synthesizes it) already used for four other usage-description keys in the same settings block (`NSBluetoothAlwaysUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSCalendarsUsageDescription`, `NSCalendarsFullAccessUsageDescription`).

**Important correction the planner MUST apply — do NOT add `NSInputMonitoringUsageDescription` as the primary key:** `24-RESEARCH.md` §3 (Assumption A6) found that a `.defaultTap` (required by D-15's swallow requirement — `.listenOnly` cannot swallow) is gated by **Accessibility** (`AXIsProcessTrusted()`), not Input Monitoring. Critically, **Accessibility's system prompt has no equivalent custom `Info.plist` usage-description string** — there is no `NSAccessibilityUsageDescription` key; the user is sent to System Settings → Privacy & Security → Accessibility with no inline reason text the way Bluetooth/Location/Calendar get one. So:
- **Do not invent `INFOPLIST_KEY_NSAccessibilityUsageDescription`** — it is not a real key, do not add it to `project.yml`.
- **Optionally, defensively, add `INFOPLIST_KEY_NSInputMonitoringUsageDescription`** (inert if unused, per RESEARCH.md's own hedge that Accessibility-trusted apps may get Input Monitoring "for free") using the exact same `INFOPLIST_KEY_*` line shape as the Bluetooth key above — this is a genuine "Claude's Discretion" item RESEARCH.md leaves for the D-13-capped spike to resolve empirically (log whether the system shows an Accessibility prompt, an Input Monitoring prompt, both, or neither, before locking this in).
- **No new `.entitlements` file entry is needed** — unlike `com.apple.security.cs.disable-library-validation` (`Islet/Islet.entitlements`, added for the embedded `MediaRemoteAdapter.framework` under Hardened Runtime), Accessibility/Input-Monitoring TCC grants are OS-level privacy permissions, not code-signing entitlements — there is no entitlements-file analog to extend here, only the `INFOPLIST_KEY_*` build-setting pattern above (and, if the spike confirms it's needed, an `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true] as CFDictionary)` call site inside `DropInterceptTap.start()`, gated lazily per D-11, not at app launch).

### 5. No Analog Found

The following are genuinely novel to this codebase — no existing pattern to copy, flagged explicitly per `24-RESEARCH.md`'s own framing so the planner does not force-fit an ill-suited analog:

| Novel element | Why no analog exists | RESEARCH.md reference |
|---|---|---|
| C-function-pointer callback shape (`CGEventTapCreate`'s `callback:` parameter, `Unmanaged<T>`/`UnsafeMutableRawPointer` context-threading via `userInfo`) | Every existing callback/monitor in this codebase (`mouseMonitor`, `dragReleaseMonitor`, `BluetoothMonitor`'s `@objc` selectors, `NowPlayingMonitor`'s closures) uses either an escaping `[weak self]` Swift closure or an `@objc` selector — neither requires manual `Unmanaged` memory management. This is a materially different, lower-level idiom. | §4, §5 point 1 |
| Health-check / graceful-disable requirement for a malfunctioning tap (`CGEvent.tapIsEnabled(tap:)` polled periodically, reinstall-on-failure) | No existing monitor in this codebase can silently "go inert while still holding a live-looking handle" the way a re-signed/re-launched tap reportedly can (§3's code-signing caveat, `danielraffel.me` field report) — `BluetoothMonitor`/`PowerSourceMonitor`/`NowPlayingMonitor` either fire or don't from the moment of registration, with no analogous "quietly stopped working after the fact" failure mode requiring an ongoing liveness poll. This must be built from scratch, explicitly tested in a `-configuration Release` build (mirroring the project's own prior `release-library-validation-crash` incident, which also only manifested in Release). | §3 (code-signing caveat), Pitfall C |
| Whether Islet's own pre-existing `dragEndMonitor` (`NSEvent` global monitor, Plan 24-02) still fires for an event `DropInterceptTap` has already swallowed (`nil`-returned) | No prior feature in this codebase has ever needed two independent consumers of the same OS event where one can fully suppress it for the other — this is a new integration-risk shape entirely (RESEARCH.md Pitfall A / Assumption A7), unverifiable except by the D-13-capped on-device spike logging both consumers on the same test drag. | Pitfall A, Assumption A7 |
| The core load-bearing question itself — does consuming `.leftMouseUp` at `.cgSessionEventTap` actually prevent the WindowServer's internal drag-completion bookkeeping | Explicitly unconfirmed by RESEARCH.md (§1, Assumption A5, "LOW-MEDIUM confidence... could NOT be confirmed from official documentation or real-world precedent") — no established app in this product category (Yoink, Dropzone, CleanShot X) appears to use this technique for this purpose; they sidestep the question by becoming a real `NSDraggingDestination` overlay instead. Nothing in this codebase can serve as a pattern for this because it's an open empirical question, not a coding-style one. | §1, Assumption A5, A8 |

## PATTERN MAPPING COMPLETE
