# Phase 47: Audio Output Switcher — Pure Seam + Monitor - Pattern Map

**Mapped:** 2026-07-19
**Files analyzed:** 2 (both NEW)
**Analogs found:** 2 / 2

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Islet/Notch/AudioOutputPresentation.swift` | model / pure-transform | transform (CRUD-adjacent: list + sort) | `Islet/Notch/NowPlayingPresentation.swift` | exact (Pattern 1 pure-seam discipline) |
| `Islet/Notch/AudioOutputMonitor.swift` | service (system-glue monitor) | event-driven | `Islet/Notch/BluetoothMonitor.swift` (shape) + `Islet/Notch/VolumeReader.swift` (CoreAudio call style) | exact (ARCHITECTURE.md Pattern 2 names these two explicitly) |
| `IsletTests/AudioOutputPresentationTests.swift` | test | — | `IsletTests/OSDActivityTests.swift` / `IsletTests/NowPlayingPresentationTests.swift` | exact |

Note: no `AudioOutputProviding` protocol file is pre-decided — CONTEXT.md leaves it to Claude's discretion during planning/execution (see Shared Patterns below for why it's likely unnecessary).

## Pattern Assignments

### `Islet/Notch/AudioOutputPresentation.swift` (pure seam, transform)

**Analog:** `Islet/Notch/NowPlayingPresentation.swift` (also see `Islet/Notch/OSDActivity.swift` for the shorter sibling shape)

**File header / isolation-boundary comment convention** (`NowPlayingPresentation.swift:1-16`):
```swift
import Foundation

// Phase 4 / NOW-01 + NOW-03 — the PURE now-playing presentation seam (Pattern 1).
//
// Like NotchGeometry, NotchInteractionState, and PowerActivity, these are plain values
// + a total function importing ONLY Foundation — no MediaRemote, no AppKit, no NSImage,
// no Process here; that wiring lives in Plan 02. Tests build TrackSnapshot by hand, so the
// riskiest classification logic ... is unit-tested in milliseconds.
```
`AudioOutputPresentation.swift` must open with the equivalent framing: `import Foundation` ONLY (no CoreAudio/AppKit), and a comment stating this file has zero system-framework imports — `AudioOutputMonitor.swift` is the only place `AudioDeviceID`/CoreAudio types are touched. Per Pitfall 4, the pure seam's device identity type should be the CoreAudio UID `String`, not `AudioDeviceID` — keeps this file Foundation-only and dodges Pitfall 4 by construction.

**Plain-value struct pattern** (`NowPlayingPresentation.swift:22-37`, `TrackSnapshot`):
```swift
struct TrackSnapshot: Equatable {
    let bundleIdentifier: String?
    let isPlaying: Bool?
    let title: String?
    let artist: String?
    // ... more Optional fields with `var ... = nil` defaults for source compat
}
```
Mirror this for an `AudioOutputDevice` (or similarly named) `Equatable` struct: `let uid: String` (stable identity, Pitfall 4), `let name: String`, `let isDefault: Bool` (or derive "is default" externally per D-02's sort contract — decide in planning), plus whatever raw output-capability field (e.g. output channel count) the D-01 classification needs before it's filtered into the list. ARCHITECTURE.md's own sketch (`ARCHITECTURE.md:149-153`) uses `AudioDeviceID` as `id` — **do not copy that verbatim**; Pitfall 4 (`PITFALLS.md:75-92`) explicitly requires the pure seam to key by UID, not `AudioDeviceID`, so adapt the sketch to use the stable UID string as the identity/`Identifiable id`.

**Total pure mapping / sort function pattern** (`NowPlayingPresentation.swift:51-60`, `nowPlayingPresentation(from:)`):
```swift
// TOTAL pure mapping. nil snapshot == "no media" (D-11) → .none, never .unavailable.
func nowPlayingPresentation(from s: TrackSnapshot?) -> NowPlayingPresentation {
    guard let s,
          let bundle = s.bundleIdentifier, allowedBundleIDs.contains(bundle),
          let title = s.title, !title.isEmpty
    else { return .none }
    let artist = s.artist ?? ""
    return (s.isPlaying == true) ? .playing(title: title, artist: artist)
                                 : .paused(title: title, artist: artist)
}
```
Write the D-02 sort function in the same total, side-effect-free style: given a raw device list (+ which one is default), return the default pinned first and the rest alphabetically sorted by name (`localizedStandardCompare` or `<` per planner's choice — Swift's plain `<` is ASCII-only; prefer `localizedCaseInsensitiveCompare`/`localizedStandardCompare` for correct human name ordering, consistent with the "polished/native feel" project goal). This is the function `AudioOutputPresentationTests.swift` exercises directly with hand-built structs — no CoreAudio needed, exactly like `nowPlayingPresentation(from:)`'s test file.

**D-01 filter/classify function pattern** — no single existing function classifies "which of these entries counts," but `OSDActivity.swift`'s clamp-style total functions (`OSDActivity.swift:36-42`) are the closest "small total pure filter/normalize function" precedent:
```swift
func osdVolumeActivity(percent: Int, hardwareMuted: Bool) -> OSDActivity {
    .volume(percent: min(100, max(0, percent)), hardwareMuted: hardwareMuted)
}
```
Use this shape for the output-capable filter (D-01: classify AirPlay/aggregate/Multi-Output devices as output-capable via channel count, not just physical-hardware type) — a small total function taking the raw per-device facts (output channel count, device-kind flag if available) and returning a Bool/enum classification, unit-tested the same way `testVolumeClampsAboveRange` tests the clamp.

---

### `Islet/Notch/AudioOutputMonitor.swift` (service, event-driven)

**Analog 1 (event-driven shape):** `Islet/Notch/BluetoothMonitor.swift` — read in full above.

**Analog 2 (CoreAudio property-read/guarded-cast style):** `Islet/Notch/VolumeReader.swift` — read in full above.

**Class shape / idempotent start+stop pattern** (`BluetoothMonitor.swift:32-62`, `144-157`):
```swift
@MainActor
final class BluetoothMonitor: NSObject {
    private nonisolated(unsafe) var connectToken: IOBluetoothUserNotification?
    private nonisolated(unsafe) var disconnectTokens: [String: IOBluetoothUserNotification] = [:]
    private nonisolated(unsafe) var running = false
    private let onReading: (DeviceReading) -> Void

    init(onReading: @escaping (DeviceReading) -> Void) {
        self.onReading = onReading
        super.init()
    }

    func start() {
        guard !running else { return }   // Pitfall 5: idempotent — never double-register.
        running = true
        connectToken = IOBluetoothDevice.register(forConnectNotifications: self,
                                                  selector: #selector(connected(_:device:)))
    }
    // ...
    nonisolated func stop() {
        connectToken?.unregister()
        connectToken = nil
        disconnectTokens.values.forEach { $0.unregister() }
        disconnectTokens.removeAll()
        running = false
    }
}
```
`AudioOutputMonitor` must copy this structure verbatim, substituting IOBluetooth registration for CoreAudio listener registration:
- `@MainActor final class AudioOutputMonitor: NSObject` (NSObject not strictly required for CoreAudio block-based listeners, but keep the pattern consistent unless the block form makes it unnecessary — block-based `AudioObjectAddPropertyListenerBlock` doesn't need `@objc`/`NSObject`, so a plain `@MainActor final class` is fine here and slightly simpler than BluetoothMonitor's NSObject requirement).
- `private nonisolated(unsafe) var running = false` — idempotent `start()` guard (PITFALLS.md Pitfall 5's "code-review checklist" framing implies this is expected, mirroring Pitfall 5 in BluetoothMonitor).
- A stored listener-block reference (CoreAudio's `AudioObjectAddPropertyListenerBlock` doesn't return a token object like IOBluetooth does — retain the block itself, or use `AudioObjectAddPropertyListener` C-callback form with `self` as client data) so `stop()` can call the matching `AudioObjectRemovePropertyListenerBlock`/`RemovePropertyListener` — this is this project's equivalent of BluetoothMonitor's token retention (Pitfall 4's retention discipline generalized).
- `nonisolated func stop()` for the same reason BluetoothMonitor's is nonisolated: `NotchWindowController`'s nonisolated deinit must be able to call it.

**Off-main callback hop pattern** (`BluetoothMonitor.swift:64-94`, comment block `64-81`):
```swift
@objc private func connected(_ n: IOBluetoothUserNotification, device: IOBluetoothDevice) {
    // CRITICAL: IOBluetooth delivers this @objc selector on its OWN dispatch queue
    // ... MUST hop to main ourselves before touching the retained-token dict or calling
    // onReading ...
    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        // ...
        self.emit(device, connected: true)
    }
}
```
PITFALLS.md Pitfall 5 (`PITFALLS.md:95-111`) explicitly names this exact hop as mandatory for `AudioObjectAddPropertyListenerBlock` callbacks too — CoreAudio callbacks fire on a CoreAudio-internal dispatch queue, not main. Every listener block body in `AudioOutputMonitor` must open with `DispatchQueue.main.async { [weak self] in ... }` before touching any stored state or calling the `onDevicesChanged`/`onDefaultChanged` closure — copy the comment style too (name the specific pitfall being guarded against), matching this codebase's established self-documentation convention.

**Guarded CoreAudio property-read pattern** (`VolumeReader.swift:14-24`, `defaultOutputDeviceID()`):
```swift
private func defaultOutputDeviceID() -> AudioDeviceID? {
    var deviceID = AudioDeviceID(0)
    var deviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var outputAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &outputAddr, 0, nil, &deviceIDSize, &deviceID) == noErr
    else { return nil }
    return deviceID
}
```
This is the exact "safe default, never force-unwrap" discipline (declared in `VolumeReader.swift`'s own header, lines 4-7) `AudioOutputMonitor`'s device enumeration must follow for every CoreAudio call:
- Zero-initialize the out-var, compute the size, build the `AudioObjectPropertyAddress`, guard the `== noErr` return, `return nil`/safe-default on any failure — never force-unwrap a `Get`/`SetPropertyData` result.
- Reuse `AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)` for the device-list enumeration (get the size first via a `0`-sized probe call, then allocate an `[AudioDeviceID]` array of the right count — standard CoreAudio "get size, then get data" two-call idiom, same shape as the fixed-size reads above just with a dynamic-size first call).
- Reuse the identical property-address literal style for `kAudioHardwarePropertyDefaultOutputDevice` reads (`VolumeReader.swift:17-20`) verbatim — do not re-derive it, per `Islet/Notch/VolumeReader.swift`'s "reused UNCHANGED for volume reads" framing in CONTEXT.md's canonical_refs.
- For the UID resolution required by Pitfall 4, add a `kAudioDevicePropertyDeviceUID` guarded read (same guarded pattern, `CFString`-typed out-var) and a `kAudioHardwarePropertyTranslateUIDToDevice` guarded call for the reverse lookup (UID → current `AudioDeviceID`) immediately before any CoreAudio call that needs the live ID — this re-resolution-per-call is the concrete mechanic Pitfall 4 prescribes (`PITFALLS.md:84`).

**Output-capability filter pattern** — no analog exists yet in this codebase (this is genuinely new logic); STACK.md and PITFALLS.md both specify the exact API: filter `kAudioHardwarePropertyDevices` results to those with `kAudioDevicePropertyStreams`/output channel count > 0 under `kAudioObjectPropertyScopeOutput` (`STACK.md:30`, `PITFALLS.md:125`) before ever constructing an `AudioOutputDevice` — this filtering is glue-layer (belongs in `AudioOutputMonitor.swift`, feeding already-filtered raw facts into the pure seam's classify function), not something to bolt onto the pure seam itself.

**What NOT to do (Anti-Pattern 3, `ARCHITECTURE.md:245-251` referenced via CONTEXT.md):** do not add any function to `VolumeReader.swift` for this phase — `readSystemVolume()`/`adjustSystemVolume()`/`toggleSystemMute()` stay untouched and are reused as-is once a device is selected (Phase 48 concern, not this phase's).

**What NOT to do (Pitfall 6):** do not read `BluetoothMonitor`'s state to build/filter the CoreAudio device list, and do not feed CoreAudio device-list changes into `BluetoothMonitor`. The two monitors are independent event sources; any reconciliation (e.g., matching "this AirPods CoreAudio device" to "this AirPods BluetoothMonitor entry" by name) is Phase 48's display-layer concern, not this phase's.

---

### `IsletTests/AudioOutputPresentationTests.swift` (test)

**Analog:** `IsletTests/OSDActivityTests.swift` (short, clamp-style) and `IsletTests/NowPlayingPresentationTests.swift` (classification/filter-style)

**Header + hand-built-value test pattern** (`OSDActivityTests.swift:1-15`):
```swift
import XCTest
@testable import Islet

// Phase 39 / HUD-03/HUD-04: the PURE volume/brightness→presentation seam. Like
// FocusActivityTests and PowerActivityTests, osdVolumeActivity(...)/osdBrightnessActivity(...)
// are total, framework-free functions ... so the mapping ... is verified deterministically
// by an automated agent in milliseconds.
final class OSDActivityTests: XCTestCase {
    func testVolumeMapsInRange() {
        XCTAssertEqual(osdVolumeActivity(percent: 50, hardwareMuted: false),
                        .volume(percent: 50, hardwareMuted: false))
    }
    // ...
}
```
And the allowlist/classification style from `NowPlayingPresentationTests.swift:16-35` (`testAllowlistFiltersBundleID`) — hand-build 3-5 `AudioOutputDevice`/raw-fact structs per test, assert on the sorted-list output and the D-01 classification, one test per Success-Criterion-relevant behavior (default-pinned-first, alphabetical remainder, output-capability filter, AirPlay/aggregate inclusion). No CoreAudio import in the test file, matching both analogs.

---

## Shared Patterns

### Off-main dispatch hop (mandatory, Pitfall 5)
**Source:** `Islet/Notch/BluetoothMonitor.swift:64-94`, `Islet/Notch/PowerSourceMonitor.swift` (same discipline, not re-read here — already cited as the precedent in both files' comments)
**Apply to:** every CoreAudio listener callback in `AudioOutputMonitor.swift`
```swift
DispatchQueue.main.async { [weak self] in
    guard let self else { return }
    // touch stored state / call the closure here, never before this line
}
```

### Guarded CoreAudio call discipline ("safe default, never force-unwrap")
**Source:** `Islet/Notch/VolumeReader.swift:14-24` (`defaultOutputDeviceID()`)
**Apply to:** every `AudioObjectGetPropertyData`/`AudioObjectSetPropertyData`/`AudioObjectHasProperty` call in `AudioOutputMonitor.swift`
```swift
guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &out) == noErr
else { return nil /* or safe default */ }
```

### Stable-identity keying (Pitfall 4, mandatory)
**Source:** `Islet/Notch/BluetoothMonitor.swift:41-43` (`disconnectTokens: [String: IOBluetoothUserNotification]` keyed by `device.addressString`)
**Apply to:** `AudioOutputPresentation.swift`'s device struct (`id`/identity = CoreAudio UID string) AND any dictionary `AudioOutputMonitor.swift` keeps internally — never key by raw `AudioDeviceID`.

### Idempotent start() / full-teardown stop()
**Source:** `Islet/Notch/BluetoothMonitor.swift:55-62`, `144-157`
**Apply to:** `AudioOutputMonitor.start()`/`stop()` — `running` guard on start, remove every registered listener in stop, `nonisolated func stop()` so a nonisolated deinit (owner-driven teardown, matching `NotchWindowController`'s existing convention) can call it.

### Pure-seam / system-glue file split ("one fragile surface, one file")
**Source:** file headers of `Islet/Notch/NowPlayingPresentation.swift:1-16`, `Islet/Notch/OSDActivity.swift:1-13`
**Apply to:** `AudioOutputPresentation.swift` (Foundation-only, zero CoreAudio import) vs `AudioOutputMonitor.swift` (all CoreAudio/system glue) — never mix the two, never add device-list logic to `VolumeReader.swift` (Anti-Pattern 3).

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| Output-capability classification logic (D-01: channel-count-under-output-scope filter, incl. AirPlay/aggregate device kinds) | pure function | transform | No existing pure seam in this codebase classifies device *kind* — closest precedent is `OSDActivity`'s clamp-style total function shape (structurally similar, semantically new). Genuinely new logic per D-01; STACK.md/PITFALLS.md specify the exact CoreAudio properties to read (glue layer), the classification predicate itself must be authored fresh. |

## Metadata

**Analog search scope:** `Islet/Notch/` (all monitor/presentation/reader files), `IsletTests/` (presentation-seam test files)
**Files scanned:** `BluetoothMonitor.swift`, `VolumeReader.swift`, `NowPlayingPresentation.swift`, `OSDActivity.swift`, `OSDActivityTests.swift`, `NowPlayingPresentationTests.swift`, plus `.planning/research/STACK.md` §2, `PITFALLS.md` Pitfalls 4-8, `ARCHITECTURE.md` Pattern 2 / Anti-Pattern 3
**Pattern extraction date:** 2026-07-19
