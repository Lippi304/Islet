# Phase 57: Pasteboard Monitor — Spike - Pattern Map

**Mapped:** 2026-07-22
**Files analyzed:** 3 (new) + 1 (modified) + 1 (new test/spike)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Clipboard/ClipboardMonitor.swift` (new) | service (system-glue monitor) | event-driven (timer poll + changeCount diff) | `Islet/Notch/FocusModeMonitor.swift` | exact (same `DispatchSourceTimer` poll shape, no notification API exists for either) |
| `Islet/AppDelegate.swift` (modified — add debug spike hooks + `accessBehavior` check) | controller (menu/glue) | request-response (menu action → spike call) | `Islet/AppDelegate.swift` lines 282-299 (Phase 56 `debugSpikeSeedClipboardData`/`debugSpikePrintClipboardReload`) | exact — this phase extends the same `#if DEBUG` block with new spike actions |
| `IsletTests/ClipboardMonitorManualSpike.swift` (new) | test (manual on-device spike, not a unit test) | event-driven | `IsletTests/AudioOutputMonitorManualSpike.swift` | exact |
| `Islet/Clipboard/ClipboardItem.swift`, `ClipboardStore.swift`, `ClipboardFileStore.swift` (existing, Phase 55/56 — read-only integration points) | model / service | CRUD | n/a — these ARE the analogs for Phase 58, untouched here | n/a |
| Drag-polling code in `Islet/Notch/NotchWindowController.swift` (lines 354, 1183-1198, 1216-1229, 1271-1278) | reference only — NOT copied wholesale, structural discipline only | event-driven (changeCount-gated poll) | itself | reference (see Shared Patterns) |

## Pattern Assignments

### `Islet/Clipboard/ClipboardMonitor.swift` (service, event-driven)

**Analog:** `Islet/Notch/FocusModeMonitor.swift` (full file, 97 lines — read in one pass, see excerpt below)

**Why this analog over `PowerSourceMonitor`/`AudioOutputMonitor`:** `PowerSourceMonitor` and `AudioOutputMonitor` are event-driven via real OS notification/callback sources (IOKit run-loop source, CoreAudio property-listener block) — no polling clock exists for either. `ClipboardMonitor`, like `FocusModeMonitor`, has **no notification API available at all** (`NSPasteboard` has never had one) and must poll on a `DispatchSourceTimer`. `FocusModeMonitor` is therefore the closer structural twin: same `@MainActor` class shape, same `nonisolated(unsafe) var timer: DispatchSourceTimer?`, same idempotent `running` guard, same `init(onChange:)` + `start()` + `nonisolated stop()` + empty `deinit` (owner-driven teardown) shape. Swap the interval from Focus's 2.5s to this phase's ~500ms (Maccy's proven default per PITFALLS.md), and swap the single `INFocusStatusCenter` read for `NSPasteboard.general.changeCount` diff + concealed/transient-type filter + classify.

**Full file to mirror** (`Islet/Notch/FocusModeMonitor.swift:29-97`):
```swift
@MainActor
final class FocusModeMonitor {
    // nonisolated(unsafe) so stop() can run from the owner's nonisolated deinit —
    // mirrors PowerSourceMonitor.runLoopSource / BluetoothMonitor's tokens exactly.
    private nonisolated(unsafe) var timer: DispatchSourceTimer?
    // Idempotent start() guard (mirrors BluetoothMonitor.running) — a re-entrant
    // start() can't double-schedule the timer.
    private nonisolated(unsafe) var running = false
    private let onChange: (Bool) -> Void

    init(onChange: @escaping (Bool) -> Void) { self.onChange = onChange }

    func start() {
        guard !running else { return }   // idempotent — never double-schedule.
        running = true
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: 2.5, leeway: .milliseconds(500))
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    private func poll() {
        guard INFocusStatusCenter.default.authorizationStatus == .authorized else { return }
        guard let isFocused = INFocusStatusCenter.default.focusStatus.isFocused else { return }
        onChange(isFocused)
    }

    nonisolated func stop() {
        timer?.cancel()
        timer = nil
        running = false
    }

    deinit {
        // owner (e.g. AppDelegate) is @MainActor and calls stop() explicitly on teardown —
        // deinit can't be @MainActor in Swift 5 mode, so it does NOT call stop() here.
    }
}
```

**changeCount-diff gate to copy instead of Focus's single-flag read** — from `Islet/Notch/NotchWindowController.swift:1183-1198` (the drag-polling precedent CONTEXT.md/PITFALLS.md explicitly point to for "same main-thread, changeCount-gated discipline"):
```swift
// NotchWindowController.swift:1183-1185 — cheap gate-first shape
private func handleDragApproachTick() {
    let count = NSPasteboard(name: .drag).changeCount
    recheckDragAcceptRegion(currentChangeCount: count)
    ...
}
```
For `ClipboardMonitor.poll()`, the equivalent shape is: read `NSPasteboard.general.changeCount` first; compare against a stored `lastChangeCount`; only if different, read `.types` for the `org.nspasteboard.ConcealedType`/`TransientType` check, then classify text/image and call `onChange`. This mirrors `AudioOutputMonitor`'s and `FocusModeMonitor`'s "cheap check first, expensive work gated behind it" discipline as well — do not decode pasteboard content unconditionally on every tick (PITFALLS.md Pitfall 2).

**Self-capture guard reference (D-decision: marker-type approach per CONTEXT.md Claude's Discretion)** — no existing marker-pasteboard-type code exists in this codebase (genuinely new ground per RESEARCH.md); PITFALLS.md Pitfall 1 names the exact mechanism to implement (a private UTI, e.g. `com.islet.clipboardhistory.restored`, checked in `poll()`'s ingestion step, written by the future click-to-restore call in Phase 58). No in-repo analog for this specific piece — treat as new code following PITFALLS.md's spec directly.

---

### `Islet/AppDelegate.swift` — DEBUG spike-hook additions (controller/glue, request-response)

**Analog:** `Islet/AppDelegate.swift` lines 223-300 (Phase 56's own `setupDebugMenu()` + `debugSpikeSeedClipboardData()`/`debugSpikePrintClipboardReload()`) — this phase adds to the SAME `#if DEBUG` block, not a new file.

**Exact pattern to extend** (`Islet/AppDelegate.swift:242-245, 282-299`):
```swift
debugMenu.addItem(withTitle: "Spike: Seed Clipboard Test Data",
                  action: #selector(debugSpikeSeedClipboardData), keyEquivalent: "")
debugMenu.addItem(withTitle: "Spike: Print Clipboard Reload Result",
                  action: #selector(debugSpikePrintClipboardReload), keyEquivalent: "")
for item in debugMenu.items { item.target = self }
debugStatusItem.menu = debugMenu

// Phase 56 spike hooks — see 56-02-SUMMARY.md for the on-device verdict.
@objc private func debugSpikeSeedClipboardData() {
    let items: [ClipboardItem] = [ ... ]
    try? ClipboardFileStore.save(items, root: ClipboardFileStore.storageRoot(), key: KeychainClipboardKeyStore().readOrCreateKey())
    print("[Spike-Clipboard] seeded \(items.count) items to \(ClipboardFileStore.storageRoot().path)")
}
```
Phase 57 mirrors this exact `@objc private func debugSpike...()` naming/wiring shape (per CONTEXT.md's "Claude's Discretion" note) for: (a) starting/stopping `ClipboardMonitor` against a throwaway in-memory sink — NOT `ClipboardFileStore`/`ClipboardStore` (D-09); (b) a hook that writes a simulated `org.nspasteboard.ConcealedType`-tagged `NSPasteboardItem` to `NSPasteboard.general` (D-08); (c) a hook exercising the `NSPasteboard.general.accessBehavior` check + one-time-gate + placeholder `NSAlert`/console message (D-07). All four `#if DEBUG`-gated, zero Release footprint, matching the existing pattern's verified absence from Release builds (per RESEARCH.md/Phase 49-01 precedent).

---

### `IsletTests/ClipboardMonitorManualSpike.swift` (new, test — manual on-device spike)

**Analog:** `IsletTests/AudioOutputMonitorManualSpike.swift` (full file, 42 lines)

**Pattern to copy verbatim in shape** (`IsletTests/AudioOutputMonitorManualSpike.swift:1-41`):
```swift
import XCTest
@testable import Islet

// MANUAL SPIKE — DO NOT RUN VIA `xcodebuild test` (the full Islet.app test host hangs
// headless — this project's established xcodebuild-test-headless-hang precedent). Run via
// Xcode Cmd-U for THIS single test method only, then read the Xcode console and follow the
// on-device verification steps in the phase's PLAN.md.
final class AudioOutputMonitorManualSpike: XCTestCase {
    @MainActor
    func testManualDeviceEnumerationAndSwitch() {
        var monitor: AudioOutputMonitor!
        monitor = AudioOutputMonitor(onDevicesChanged: { devices in
            devices.forEach { device in
                print("[AudioOutputSpike] ...")
            }
        })
        monitor.start()
        RunLoop.current.run(until: Date().addingTimeInterval(15))
        // ... window for developer manual interaction ...
        monitor.stop()
        XCTAssertTrue(true, "manual spike — see console output ... for the real pass/fail criteria")
    }
}
```
For `ClipboardMonitorManualSpike`: construct `ClipboardMonitor(onChange:)` with a closure that prints classified items to console (throwaway sink, no `ClipboardStore`/`ClipboardFileStore` writes, per D-09), `start()`, `RunLoop.current.run(until:)` windows for the developer to manually copy text/images/a simulated concealed item during on-device verification (SC#1-SC#4), `stop()`, and an always-green `XCTAssertTrue(true, ...)` — the real pass/fail is the human-read console output plus the phase's on-device checkpoint, exactly as this analog's own comment states.

---

## Shared Patterns

### Monitor lifecycle (start/stop/idempotency/ownership)
**Source:** `Islet/Notch/FocusModeMonitor.swift` (poll shape), `Islet/Notch/PowerSourceMonitor.swift` (init/stop/deinit comment convention)
**Apply to:** `ClipboardMonitor.swift`
```swift
@MainActor
final class XMonitor {
    private nonisolated(unsafe) var timer: DispatchSourceTimer?
    private nonisolated(unsafe) var running = false
    private let onChange: (T) -> Void
    init(onChange: @escaping (T) -> Void) { self.onChange = onChange }
    func start() { guard !running else { return }; running = true; /* schedule timer */ }
    nonisolated func stop() { timer?.cancel(); timer = nil; running = false }
    deinit { /* owner calls stop() explicitly; deinit can't be @MainActor in Swift 5 mode */ }
}
```
**Deviation for this phase:** the owner is `AppDelegate`, not `NotchWindowController` (every existing Monitor is owned/started by `NotchWindowController` — see `NotchWindowController.swift:680,689,712,716-730,784-790` for `monitor.start()` call sites, and `2316-2359`/`2763-2781` for the `?.stop()` teardown sites). This is the one deliberate ownership deviation ARCHITECTURE.md flags — same shape, new owner.

### changeCount-gated cheap-check-first discipline
**Source:** `Islet/Notch/NotchWindowController.swift:1183-1185` (`handleDragApproachTick`/`recheckDragAcceptRegion`), `Islet/Notch/DragDropSupport.swift:41-43` (`isGenuineFileDrag`)
**Apply to:** `ClipboardMonitor.poll()`
```swift
private func handleDragApproachTick() {
    let count = NSPasteboard(name: .drag).changeCount
    recheckDragAcceptRegion(currentChangeCount: count)
}
// isGenuineFileDrag(currentChangeCount:gestureBaselineChangeCount:urls:) — pure top-level
// function, directly unit-testable, called only after the cheap count comparison already gated entry.
```
Do NOT read `.types`/`.data(forType:)` unless `changeCount` actually changed — this is the exact discipline PITFALLS.md Pitfall 2 requires and the one already proven correct in this codebase for the `.drag` pasteboard. `ClipboardMonitor` uses its own independent `lastChangeCount` against `NSPasteboard.general` — no shared state with `dragPasteboardChangeCount` (Anti-Pattern 2 in ARCHITECTURE.md: these are two different pasteboards, do not unify the pollers).

### DEBUG-only spike hook + debug-menu forwarding
**Source:** `Islet/AppDelegate.swift:223-300` (Phase 56's `setupDebugMenu()` + `debugSpikeSeedClipboardData()`/`debugSpikePrintClipboardReload()`), `.planning/phases/56-encrypted-persistence/56-02-PLAN.md`/`56-02-SUMMARY.md`
**Apply to:** all of this phase's on-device verification (D-09)
```swift
debugMenu.addItem(withTitle: "Spike: <name>", action: #selector(debugSpike<Name>), keyEquivalent: "")
...
@objc private func debugSpike<Name>() {
    // throwaway sink only — never ClipboardStore/ClipboardFileStore per D-09
    print("[Spike-Clipboard] ...")
}
```
All spike methods stay inside the existing `#if DEBUG ... #endif` block (`AppDelegate.swift:223-300`), guaranteeing zero Release-build footprint (verified precedent: Phase 49-01's build-log grep).

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| Self-capture marker-type write/check (`com.islet.clipboardhistory.restored`-style `NSPasteboardItem` type) | utility (within `ClipboardMonitor`) | event-driven | No existing marker-pasteboard-type code anywhere in the codebase (confirmed by RESEARCH.md) — PITFALLS.md Pitfall 1 (Maccy's `.fromMaccy` pattern) is the only reference; implement per that spec directly, no in-repo structural precedent to copy from |
| `org.nspasteboard.ConcealedType`/`TransientType` string-type filtering | utility (within `ClipboardMonitor`) | transform | Genuinely new ground per RESEARCH.md ("No existing `org.nspasteboard.*` marker-type handling") — implement the `pb.types.map(\.rawValue).contains(...)` check per ARCHITECTURE.md's Pattern 1 code sketch (lines 105-107 of that doc), not from an in-repo analog |
| `NSPasteboard.general.accessBehavior` runtime check + one-time explanation (D-07) | utility/UX | event-driven | No existing permission-prompt precedent for pasteboard specifically; nearest conceptual sibling (Focus/Bluetooth permission-status handling in `FocusModeMonitor.isAuthorized`/`ActivitySettings.focusPermissionStatusHint`) is a DIFFERENT permission API shape (`INFocusStatusCenter.authorizationStatus` vs. `NSPasteboard.accessBehavior`) — same UX posture, no code to copy verbatim |

## Metadata

**Analog search scope:** `Islet/Notch/*Monitor.swift`, `Islet/Notch/NotchWindowController.swift` (drag-polling sections), `Islet/Notch/DragDropSupport.swift`, `Islet/Clipboard/*.swift` (Phase 55/56 existing), `Islet/AppDelegate.swift` (DEBUG block), `IsletTests/*ManualSpike.swift`
**Files scanned:** 12 (5 monitors, 1 controller, 1 drag-support, 3 existing Clipboard files, 1 AppDelegate, 1 manual-spike test)
**Pattern extraction date:** 2026-07-22
