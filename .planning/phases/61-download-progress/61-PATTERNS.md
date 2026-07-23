# Phase 61: Download-Progress - Pattern Map

**Mapped:** 2026-07-23
**Files analyzed:** 6 new + 3 modified = 9
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/DownloadActivity.swift` (NEW) | model (pure enum + total mapping fn) | transform | `Islet/Notch/CapsLockActivity.swift` | exact |
| `Islet/Notch/DownloadMonitor.swift` (NEW) | service (system-glue monitor) | event-driven | `Islet/Notch/CapsLockMonitor.swift` | role-match (lifecycle skeleton), mechanism itself is net-new (FSEvents vs NSEvent) |
| `Islet/Notch/DownloadCoordinator.swift` (NEW) | service (coordinator, per-identity side table) | event-driven / CRUD-like (create/update/remove in-flight entries) | `Islet/Notch/DeviceCoordinator.swift` + `ActivityCoordinator.swift` | exact |
| `IsletTests/DownloadActivityTests.swift` (NEW) | test | transform | (mirror shape of) `IsletTests/CapsLockActivityTests.swift` if present, else `DeviceActivityTests.swift` | role-match |
| `IsletTests/DownloadCoordinatorTests.swift` (NEW) | test | event-driven | `IsletTests/DeviceCoordinatorTests.swift` | exact |
| `Islet/Notch/IslandResolver.swift` (MODIFIED) | model / pure resolver | request-response (pure reducer) | itself — extend existing `ActiveTransient`/`IslandPresentation`/`resolve(...)`/`isPersistent` patterns (Caps Lock's rank-5→6 shift is the direct precedent for inserting a new rank 5) | exact |
| `Islet/Notch/NotchWindowController.swift` (MODIFIED) | controller | event-driven | itself — extend existing `startCapsLockMonitor()`/`handleCapsLockChange(_:)`/`flushTransients`/`syncActivityModels`/`scheduleActivityDismiss` call sites | exact |
| `Islet/Notch/NotchPillView.swift` (MODIFIED) | component (SwiftUI view) | request-response (pure render) | itself — extend existing `capsLockWings(for:)`/`updateWings(for:)` and the presentation switch at line 940 | exact |
| `Islet/ActivitySettings.swift` | config | — | already done (Phase 59) — `downloadProgressKey` exists, in `defaultsToFalseKeys`; no changes needed this phase | n/a (read-only reference) |

## Pattern Assignments

### `Islet/Notch/DownloadActivity.swift` (model, transform)

**Analog:** `Islet/Notch/CapsLockActivity.swift` (full file, 22 lines)

**Full pattern to clone:**
```swift
import Foundation

// Phase 60 / CAPS-01 — the PURE caps-lock→presentation seam (Pattern 1).
//
// Like FocusActivity and OSDActivity, this is a plain value + a total mapping function
// importing ONLY Foundation — no AppKit/NSEvent. CapsLockMonitor.swift (system glue, a
// later Plan 60 wave) is the ONLY caller; it owns the real NSEvent-based caps-lock
// detection and lifts a Bool in here.

enum CapsLockActivity: Equatable {
    case on
    case off
}

func capsLockActivity(isOn: Bool) -> CapsLockActivity {
    isOn ? .on : .off
}
```

**Apply as:**
```swift
import Foundation

enum DownloadActivity: Equatable {
    case inProgress                  // D-09: generic label only, never the temp filename
    case done(filename: String)      // D-12: real final filename + checkmark
}

// Pattern 1 is a TOTAL pure mapping in the analog (Bool -> case); Download's own mapping
// function instead lives one layer down, inside DownloadCoordinator (path/suffix matching,
// D-08), since the "reading" here isn't a single Bool but a raw FSEvents path+flags tuple.
// This file itself only needs to stay the plain Foundation-only value type — no system
// framework import, no Monitor/Coordinator logic, mirroring the analog's own header comment.
```

**Note:** unlike `CapsLockActivity`'s `Bool -> Activity` total function living in this same pure file, Download's suffix-matching/create-vs-rename logic is untrusted-input-shaped and stateful (needs the per-file side table), so that logic belongs in `DownloadCoordinator.swift` (Pattern 2 below), not here. Keep this file to the two-case enum only.

---

### `Islet/Notch/DownloadMonitor.swift` (service, event-driven)

**Analog:** `Islet/Notch/CapsLockMonitor.swift` (full file, 105 lines) — lifecycle skeleton only; FSEvents mechanism itself has no in-codebase precedent (per RESEARCH.md).

**Lifecycle skeleton to clone** (lines 12-30, 49-56, 90-104):
```swift
@MainActor
final class CapsLockMonitor {
    private nonisolated(unsafe) var monitorToken: Any?
    private nonisolated(unsafe) var healthCheckTimer: Timer?
    private var lastCapsLockState: Bool?
    private let onChange: (Bool) -> Void

    init(onChange: @escaping (Bool) -> Void) { self.onChange = onChange }

    func start() {
        guard monitorToken == nil else { return }
        guard Self.isAccessibilityTrusted else {
            armHealthCheck()
            return
        }
        install()
    }

    // ... install() does the actual NSEvent.addGlobalMonitorForEvents ...

    nonisolated func stop() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        if let token = monitorToken {
            NSEvent.removeMonitor(token)
            monitorToken = nil
        }
    }

    deinit {
        // Empty by design — the owning NotchWindowController's own @MainActor deinit calls
        // stop(), matching powerMonitor's documented ownership discipline.
    }
}
```

**Apply as:** same `@MainActor final class DownloadMonitor` shape — `init(onEvent:)`, idempotent `start()` guarding `streamRef == nil`, `nonisolated func stop()` tearing down the `FSEventStreamRef` (`FSEventStreamStop`/`Invalidate`/`Release`), empty `deinit` with the same ownership comment. No Accessibility gate needed (FSEvents on `~/Downloads` requires no special permission) — `start()` skips `CapsLockMonitor`'s `armHealthCheck()`/`isAccessibilityTrusted` branch entirely and goes straight to `install()`-equivalent stream creation. See RESEARCH.md Pattern 1 (`61-RESEARCH.md` lines 139-197) for the FSEventStreamCreate call itself — that C-API wiring has no codebase precedent and must be verified against a working sample per RESEARCH.md's own "Note" (Assumption A4).

**onEvent callback shape** (mirrors `onChange: (Bool) -> Void` above, widened to carry path+flags+fileID):
```swift
private let onEvent: (_ path: String, _ flags: FSEventStreamEventFlags, _ fileID: UInt64?) -> Void
```

---

### `Islet/Notch/DownloadCoordinator.swift` (service, event-driven / per-identity side table)

**Analog:** `Islet/Notch/DeviceCoordinator.swift` (full file, 262 lines) + `Islet/Notch/ActivityCoordinator.swift` (full file, 28 lines)

**Protocol to conform to** (`ActivityCoordinator.swift:17-28`, full text):
```swift
@MainActor
protocol ActivityCoordinator {
    associatedtype Reading

    func handle(_ reading: Reading)
    func activityPromoted()
}
```

**Per-identity side-table pattern** (`DeviceCoordinator.swift:61-73`, the `pendingDeviceBatteryPolls` precedent RESEARCH.md names directly):
```swift
// Gap-closure fix (WR-1 — battery-poll identity desync): address-keyed side data mirroring
// TransientQueue's own pending order for `.device` entries ONLY, so a device promoted to head
// LATER ... still gets its post-connect battery poll scheduled ... matched by DeviceActivity
// IDENTITY via matchPendingBatteryPoll, not by insertion order ... Capped at 2 to mirror
// TransientQueue.maxDepth.
private var pendingDeviceBatteryPolls: [PendingBatteryPoll] = []
```
```swift
// IslandResolver.swift:297-300 — the plain Equatable identity-keyed struct pattern
struct PendingBatteryPoll: Equatable {
    let address: String
    let activity: DeviceActivity
}
```

**Six reach-back closures instead of a stored `TransientQueue` reference** (`DeviceCoordinator.swift:75-96`, since `TransientQueue` is a value type):
```swift
private let queueHead: () -> ActiveTransient?
private let enqueue: (ActiveTransient) -> Bool
private let updateHead: (ActiveTransient) -> Void
private let presentTransientChange: () -> Void
private let renderPresentation: () -> Void
private let batteryForAddress: (String) -> Int?

init(queueHead: @escaping () -> ActiveTransient?,
     enqueue: @escaping (ActiveTransient) -> Bool,
     updateHead: @escaping (ActiveTransient) -> Void,
     presentTransientChange: @escaping () -> Void,
     renderPresentation: @escaping () -> Void,
     batteryForAddress: @escaping (String) -> Int?) { ... }
```

**Apply as:** `DownloadCoordinator` needs a smaller closure set (no `batteryForAddress`-equivalent) — likely `queueHead`, `enqueue`, `presentTransientChange`, `renderPresentation`, plus possibly `updateHead` if the done-splash ever needs an in-place scrub (it doesn't per D-12/D-13 — done is a fresh enqueue, not a scrub). Side table shape:
```swift
private struct InFlightDownload: Equatable {
    let tempPath: String
    let fileID: UInt64?
    let startedAt: Date
}
private var inFlightDownloads: [String: InFlightDownload] = [:]   // keyed by tempPath — mirrors pendingDeviceBatteryPolls' address-keyed discipline
```

**`activityPromoted()` conformance shape** (`DeviceCoordinator.swift:222-227`):
```swift
func activityPromoted() {
    let (match, remaining) = matchPendingBatteryPoll(pendingDeviceBatteryPolls, promoted: queueHead())
    pendingDeviceBatteryPolls = remaining
    guard let match else { return }
    scheduleDeviceBatteryRefresh(address: match.address)
}
```
Download's `activityPromoted()` is likely a near no-op (D-05's "older download still fires independently later" is resolved by RESEARCH.md's Open Question 1 recommendation: plain `enqueue`, not a promoted-side-effect chain like the battery poll) — but the protocol conformance method must still exist; confirm shape with the planner per Open Question 1.

**`handle(_:)` two-arity split for testability** (`DeviceCoordinator.swift:130-132`, exact pattern to copy for deterministic unit tests):
```swift
func handle(_ reading: DeviceReading) {
    handle(reading, now: Date().timeIntervalSinceReferenceDate)
}
func handle(_ reading: DeviceReading, now: TimeInterval) { ... }
```

---

### `Islet/Notch/IslandResolver.swift` (MODIFIED — model / pure resolver)

**Analog:** itself — the exact rank-insertion precedent Phase 60 already set for Caps Lock/Update (this phase repeats the same shape one rank higher).

**`ActiveTransient`/`IslandPresentation` case insertion** (`IslandResolver.swift:95-124`):
```swift
enum IslandPresentation: Equatable {
    ...
    case osd(OSDActivity)                                  // rank 4 transient, collapsed-only
    case capsLock(CapsLockActivity)                        // rank 5 -> SHIFTS to 6 this phase
    case updateAvailable(UpdateActivity)                   // rank 6 -> SHIFTS to 7 this phase
    ...
}
enum ActiveTransient: Equatable {
    case charging(ChargingActivity)
    case device(DeviceActivity)
    case focus(FocusActivity)
    case osd(OSDActivity)
    case capsLock(CapsLockActivity)
    case updateAvailable(UpdateActivity)
}
```
Apply as: insert `case downloadProgress(DownloadActivity)` into both enums immediately after `.osd` (rank 4) and before `.capsLock`, which shifts to rank 6; `.updateAvailable` shifts to rank 7. Update every trailing rank comment (D-01).

**`resolve(...)` switch-arm insertion** (`IslandResolver.swift:168-180`, exact per-case shape to copy):
```swift
case .osd(let o) where !isExpanded: return .osd(o)    // rank 4, collapsed-only (D-11)
case .osd: break                                      // expanded -- falls through unmodified
case .capsLock(let c) where !isExpanded: return .capsLock(c) // rank 5, collapsed-only (D-07)
case .capsLock: break
```
Apply as: insert a `case .downloadProgress(let d) where !isExpanded: return .downloadProgress(d)` / `case .downloadProgress: break` pair between the `.osd` and `.capsLock` arms (D-03: collapsed-only, matches this exact fallthrough shape).

**`isPersistent` sub-state-aware match** (RESEARCH.md's own Pitfall 4 code example, extending `IslandResolver.swift:133-137`):
```swift
extension ActiveTransient {
    var isPersistent: Bool {
        if case .focus = self { return true }
        if case .downloadProgress(.inProgress) = self { return true }   // D-02: never self-elapses while downloading
        return false                                                     // .downloadProgress(.done) falls through -> self-elapses per D-13
    }
}
```

**`TransientQueue`** (`IslandResolver.swift:329-397`) — reuse verbatim, no changes needed: `enqueue`/`preempt`/`advance`/`updateHead`/`removeAll(where:)` are all category-generic already. Per RESEARCH.md Open Question 1, use plain `enqueue` (not `preempt`) for the download's own transient unless the planner decides otherwise — matches how Device/Focus already queue behind Charging without preempting.

---

### `Islet/Notch/NotchWindowController.swift` (MODIFIED — controller)

**Analog:** itself — `startCapsLockMonitor()`/`handleCapsLockChange(_:)`/`flushTransients(.capsLock)`/`syncActivityModels()` call sites (lines 754-759, 2134-2145, 2445-2451, 2526-2546, 2332).

**Monitor start/stop wiring** (`NotchWindowController.swift:754-759`, exact shape):
```swift
private func startCapsLockMonitor() {
    guard capsLockMonitor == nil else { return }
    let monitor = CapsLockMonitor { [weak self] isOn in self?.handleCapsLockChange(isOn) }
    capsLockMonitor = monitor
    monitor.start()
}
```

**Settings-toggle reconciliation** (`NotchWindowController.swift:2445-2451`, exact shape — the toggle-on/off block every activity follows):
```swift
if activityEnabled(ActivitySettings.capsLockKey) {
    startCapsLockMonitor()
} else if capsLockMonitor != nil {
    capsLockMonitor?.stop(); capsLockMonitor = nil
    flushTransients(.capsLock)
}
```
Apply as identical block using `ActivitySettings.downloadProgressKey` and a new `downloadMonitor`/`downloadCoordinator` pair. Note: since Download needs a coordinator (stateful side table), also call its `reset()`-equivalent on stop, mirroring the Device block (`NotchWindowController.swift:2430-2434`):
```swift
} else if bluetoothMonitor != nil {
    bluetoothMonitor?.stop(); bluetoothMonitor = nil
    deviceCoordinator.reset()
    flushTransients(.device)
}
```

**Handler shape** (`NotchWindowController.swift:2134-2145`, `handleCapsLockChange` — note D-05/D-06's per-file identity need means Download's own handler routes through `downloadCoordinator.handle(_:)` instead of inlining `enqueue`/`preempt` directly, matching the Device precedent's coordinator-delegation shape rather than Caps Lock's inline shape):
```swift
private func handleCapsLockChange(_ isOn: Bool) {
    let activity = capsLockActivity(isOn: isOn)
    let changed: Bool
    if case .focus = transientQueue.head {
        changed = transientQueue.preempt(.capsLock(activity))
    } else {
        changed = transientQueue.enqueue(.capsLock(activity))
    }
    if changed {
        presentTransientChange()
    }
}
```

**`syncActivityModels()` per-category clear** (`NotchWindowController.swift:2326-2336`, exhaustive switch — must add a `.downloadProgress` arm, compiler-enforced):
```swift
private func syncActivityModels() {
    switch transientQueue.head {
    case .charging: break
    case .device:   chargingState.activity = nil
    case .focus:    chargingState.activity = nil
    case .osd:      chargingState.activity = nil
    case .capsLock: chargingState.activity = nil
    case .updateAvailable: chargingState.activity = nil
    case nil:       chargingState.activity = nil
    }
}
```
Apply as: add `case .downloadProgress: chargingState.activity = nil` (Download has no separate `@Published` state model to sync — its state lives in the coordinator's side table + the resolver's `IslandPresentation`, mirroring Focus/OSD/CapsLock's "no model" comment, not Charging/Device's "has a model" comment).

**`TransientCategory`/`flushTransients` exhaustive switch** (`NotchWindowController.swift:2526-2546`) — add `.downloadProgress` case to both the enum and the `matches` switch; in the category-specific cleanup switch, mirror `.device`'s branch (clears the coordinator's side table too):
```swift
private enum TransientCategory { case charging, device, focus, osd, capsLock, updateAvailable }
// ... add downloadProgress to the enum and to the (t, category) tuple-match list ...
case .device:
    deviceCoordinator.clearPendingBatteryPolls()   // mirror: downloadCoordinator.clearInFlight() or similar
```

**`scheduleActivityDismiss()` per-category duration** (`NotchWindowController.swift:2315-2319`, exact shape to extend for D-13's ~3s done-state timing — NOTE: this function's blanket `!head.isPersistent` guard at line 2291 already handles D-02's "in-progress never dismisses" via the `isPersistent` extension above; only the done-state's specific duration constant needs adding here, matching Charging/Device's shared `activityDuration` default, so NO new branch is actually needed unless Claude's Discretion picks a duration different from the shared 3.0s):
```swift
let duration: TimeInterval = {
    if case .capsLock = head { return capsLockActivityDuration }
    if case .osd = head { return osdActivityDuration }
    return activityDuration     // <- D-13's ~3s already matches this shared default, no new branch needed
}()
```

---

### `Islet/Notch/NotchPillView.swift` (MODIFIED — component)

**Analog:** `capsLockWings(for:)` (lines 2879-2914) for the fixed camera-block-clearance math with a text label; `updateWings(for:)` (lines 2926-2958+) for the icon+label-left / compact-element-right layout shape most similar to spinner (in-progress) / checkmark+filename (done).

**Presentation switch insertion point** (`NotchPillView.swift:939-941`, exact shape):
```swift
case .osd(let activity): osdWings(for: activity)                    // rank 4 transient
case .capsLock(let activity): capsLockWings(for: activity)          // rank 5 -> shifts to 6
case .updateAvailable(let activity): updateWings(for: activity)     // rank 6 -> shifts to 7
```
Apply as: insert `case .downloadProgress(let activity): downloadWings(for: activity)` between `.osd` and `.capsLock`.

**Fixed camera-block-clearance layout math** (`NotchPillView.swift:2879-2914`, `capsLockWings(for:)` full body — the exact math pattern, since Download (like Caps Lock) has real content on both flanks that must clear the physical camera cutout):
```swift
private func capsLockWings(for activity: CapsLockActivity) -> some View {
    let rawNotchHalfWidth = (interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width) / 2
    let margin: CGFloat = 65
    let notchHalfWidth = rawNotchHalfWidth + margin
    let cameraBlockWidth = notchHalfWidth * 2
    let iconLeadingPad: CGFloat = 12
    let iconWidth: CGFloat = 20
    let trailingPad: CGFloat = 12
    let textWidth: CGFloat = 110
    let leftWidth = iconLeadingPad + iconWidth + cameraBlockWidth / 2
    let totalWidth = iconLeadingPad + iconWidth + cameraBlockWidth + textWidth + trailingPad
    let rightWidth = totalWidth - leftWidth
    assert(cameraBlockWidth > 0, "... must be positive")
    assert(rightWidth < 325 && leftWidth < 325, "... must stay inside the ~325pt safe panel-frame budget")
    return wingsShape(leftWidth: leftWidth, rightWidth: rightWidth) {
        HStack(spacing: 0) {
            Color.clear.frame(width: iconLeadingPad)
            Image(systemName: "capslock.fill")
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: iconWidth, height: Self.wingsSize.height, alignment: .center)
            Color.clear.frame(width: cameraBlockWidth)   // EXPLICIT fixed-width camera block
            Text(activity == .on ? "Caps Lock On" : "Caps Lock Off")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: textWidth, alignment: .leading)
            Color.clear.frame(width: trailingPad)
        }
    }
}
```

**Apply as** `downloadWings(for:)` per `61-UI-SPEC.md`'s locked Icon & Layout Contract:
- In-progress: leading `Image(systemName: "arrow.down.circle")` (13pt semibold, hierarchical, white, 20pt frame) + `Text("Downloading…")` (12pt semibold rounded, white, `.lineLimit(1)`, fixed ~100pt) on the left flank; trailing `ProgressView().controlSize(.small).tint(.white)` (~20pt frame) on the right flank — replaces `capsLockWings`' single-flank text-only layout with a two-flank split (label left of camera block, spinner right of it), closer in shape to `updateWings`' icon+label-left / pill-right split.
- Done: leading `Image(systemName: "checkmark.circle.fill")` (13pt semibold, hierarchical, **green** — the one accent use per UI-SPEC) + `Text(finalFilename)` (`.lineLimit(1)`, `.truncationMode(.middle)`, fixed max ~140pt).
- No `onTap` override (D-11) — omit the `onTap:` param to `wingsShape(...)` entirely (defaults to `nil`), same as `capsLockWings` (unlike `updateWings`, which is the one call site passing a non-nil override).
- Reuse the same `assert(cameraBlockWidth > 0, ...)` / `assert(rightWidth < 325 && leftWidth < 325, ...)` sanity-check pattern verbatim — flagged by code review WR-02 on both prior wings, applies identically here.

**`wingsShape(...)` shared wrapper** (`NotchPillView.swift:2310-2360`, signature only — call, don't modify):
```swift
private func wingsShape<Content: View>(
    leftWidth: CGFloat = Self.wingsSize.width / 2,
    rightWidth: CGFloat = Self.wingsSize.width / 2,
    onTap: (() -> Void)? = nil,
    @ViewBuilder content: () -> Content
) -> some View
```

---

## Shared Patterns

### Monitor lifecycle (start/stop/nonisolated deinit)
**Source:** `Islet/Notch/CapsLockMonitor.swift:12-104` (also `FocusModeMonitor.swift`, `PowerSourceMonitor.swift`)
**Apply to:** `DownloadMonitor.swift`
```swift
@MainActor
final class DownloadMonitor {
    private nonisolated(unsafe) var streamRef: FSEventStreamRef?
    private let onEvent: (String, FSEventStreamEventFlags, UInt64?) -> Void
    init(onEvent: @escaping (String, FSEventStreamEventFlags, UInt64?) -> Void) { self.onEvent = onEvent }
    func start() { guard streamRef == nil else { return }; /* FSEventStreamCreate + Start */ }
    nonisolated func stop() { /* Stop + Invalidate + Release */ }
    deinit { /* empty — owner's deinit calls stop() */ }
}
```

### Coordinator / per-identity side table + ActivityCoordinator conformance
**Source:** `Islet/Notch/DeviceCoordinator.swift` (whole file), `Islet/Notch/ActivityCoordinator.swift` (whole file)
**Apply to:** `DownloadCoordinator.swift`
```swift
@MainActor
final class DownloadCoordinator: ActivityCoordinator {
    typealias Reading = /* raw FSEvents path+flags+fileID tuple, or a small struct wrapping it */
    private var inFlightDownloads: [String: InFlightDownload] = [:]
    private let queueHead: () -> ActiveTransient?
    private let enqueue: (ActiveTransient) -> Bool
    private let presentTransientChange: () -> Void
    // init(...) with closures, mirroring DeviceCoordinator's 6-closure init
    func handle(_ reading: Reading) { /* suffix match D-08, create/rename correlation, enqueue */ }
    func activityPromoted() { /* likely near-no-op per Open Question 1 recommendation */ }
}
```

### Controller wiring triplet (start monitor / handle event / settings toggle reconciliation)
**Source:** `Islet/Notch/NotchWindowController.swift:754-759, 2134-2145, 2445-2451`
**Apply to:** `NotchWindowController.swift`'s new Download section — copy the exact 3-part shape (idempotent `startXMonitor()`, `handleXChange(_:)` that enqueues/preempts and calls `presentTransientChange()`, and the `if activityEnabled(key) { start... } else if monitor != nil { stop...; flushTransients(.x) }` toggle block).

### Exhaustive-switch discipline for new ActiveTransient case
**Source:** `Islet/Notch/NotchWindowController.swift:2326-2336` (`syncActivityModels`), `2526-2546` (`TransientCategory`/`flushTransients`), `Islet/Notch/IslandResolver.swift:133-137` (`isPersistent`), `168-180` (`resolve` switch)
**Apply to:** every exhaustive switch over `ActiveTransient`/`IslandPresentation`/`TransientCategory` — the compiler enforces completeness, so each of these 4 switches needs one new arm for `.downloadProgress`. Cross-check by attempting a build after adding the case to the two enums — the compiler will list every switch requiring an update.

### Untrusted-filename rendering (V5 input validation)
**Source:** `61-RESEARCH.md` Security Domain section, cross-referenced with `DeviceActivity.swift`'s existing `name` handling pattern
**Apply to:** `downloadWings(for:)`'s done-state `Text(finalFilename)` — render via plain `Text` with `.lineLimit(1)` + `.truncationMode(.middle)` (already locked in `61-UI-SPEC.md`); never interpolate the raw filename into a format string, shell command, or path-construction call.

## No Analog Found

None — every file in this phase has a direct, concrete precedent in the codebase (RESEARCH.md's own conclusion: "Every piece of this phase that looks novel... already has a solved, tested precedent"). The only genuinely unprecedented surface is the `FSEventStreamCreate` C-API call itself inside `DownloadMonitor.swift` — RESEARCH.md flags this explicitly (Assumption A4) as illustrative, not copy-paste-ready, and recommends verifying the exact `@convention(c)`/`Unmanaged` bridging against a working external sample during implementation rather than treating the RESEARCH.md sketch as gospel.

## Metadata

**Analog search scope:** `Islet/Notch/` (all `.swift` files read/greped: `DeviceCoordinator.swift`, `IslandResolver.swift`, `NotchPillView.swift`, `NotchWindowController.swift`, `CapsLockMonitor.swift`, `CapsLockActivity.swift`, `ActivityCoordinator.swift`, `ChargingActivityState.swift`, `DeviceActivity.swift`), `Islet/ActivitySettings.swift`
**Files scanned:** 10 (read in full or targeted ranges) + 2 grep sweeps across `NotchWindowController.swift`/`NotchPillView.swift`
**Pattern extraction date:** 2026-07-23
