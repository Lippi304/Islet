# Phase 34: Quick Action Destination Picker - Pattern Map

**Mapped:** 2026-07-15
**Files analyzed:** 8 (4 modified, 4 new)
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/IslandResolver.swift` (modified — new `.quickActionPicker` case + `PendingDrop` model) | model + pure transform (app logic) | transform (pure reducer) | itself — existing `.trayExpanded`/`.weatherExpanded` cases + `DeviceActivity.swift`'s plain-value-struct convention | exact |
| `Islet/Notch/NotchWindowController.swift` (modified — pending-drop state, `handleDragApproachEnd()` branch, delegate cleanup, `positionAndShow`, `visibleContentZone`) | controller | event-driven | itself — `handleDragApproachEnd()`, `beginShelfItemDrag()`/`endShelfItemDrag()` (Phase 21 drag-pin), `positionAndShow`'s `trayFrame`/`weatherExpandedFrame` union members | exact |
| `Islet/Notch/NotchPillView.swift` (modified — new `quickActionPickerView`/`quickActionPreview`/`quickActionButtonRow`/`quickActionButton` + geometry constant) | component (SwiftUI view) | request-response (render) | itself — `trayFullView` (lines 994-1024), `chipButton` (1304-1317), `blobShape` (1362+) | exact |
| `Islet/Notch/QuickActionSharingService.swift` (NEW) | service (OS-integration seam) | event-driven (async delegate callback) | `Islet/Notch/NowPlayingMonitor.swift` ("isolate the fragile thing" seam) + `Islet/Notch/DeviceCoordinator.swift` (thin `@MainActor final class` wrapping OS IO around pure state) | role-match |
| `IsletTests/IslandResolverTests.swift` (modified — new precedence/branch tests) | test | transform | itself — `testChargingOutranksDeviceAndMedia`, `testCalendarSelectionOutranksMedia` | exact |
| `IsletTests/QuickActionSharingServiceTests.swift` (NEW) | test | event-driven (mocked OS boundary) | `IsletTests/LocationServiceTests.swift` (protocol + in-memory fake, call-count assertions) | exact |
| `IsletTests/ShelfCoordinatorTests.swift` or a small new glue test (picker→Drop→append+switch) | test | CRUD (file copy-in glue) | itself — `testRemoveDeletesSessionTempFileFromDisk` (real-disk-I/O fixture convention) | exact |
| `Islet/Shelf/ShelfCoordinator.swift` (UNCHANGED — reused verbatim for "Drop") | service (data/IO) | CRUD | itself — no modification needed, `append(_:)` already the exact primitive | n/a (reuse, not new) |

## Pattern Assignments

### `Islet/Notch/IslandResolver.swift` (model + pure transform)

**Analog:** the file's own existing cases (`.trayExpanded`, `.weatherExpanded`, `.charging`) and `Islet/Notch/DeviceActivity.swift`'s plain-Equatable-struct convention.

**IslandPresentation case pattern** (`IslandResolver.swift` lines 38-50):
```swift
enum IslandPresentation: Equatable {
    case onboarding(OnboardingStep)                        // Phase 26 D-09: highest priority
    case idle
    case charging(ChargingActivity)
    case device(DeviceActivity)
    ...
    case trayExpanded                                      // 28-04 round 5
    // NEW: case quickActionPicker(PendingDrop) — slots in as an `isExpanded` branch case,
    // same tier as .calendarExpanded/.weatherExpanded/.trayExpanded (per D-01, D-05 Pitfall 5
    // this payload must be fed IN from the controller, not stored inside the resolver's own
    // return value — resolve() is a fresh call every time).
}
```

**showsSwitcherRow single-source-of-truth pattern** (lines 66-71) — UI-SPEC's decision (switcher HIDDEN during the picker) is wired here, in the SAME shared function both `NotchPillView` and `NotchWindowController` already call — do not duplicate this list anywhere else:
```swift
func showsSwitcherRow(for presentation: IslandPresentation) -> Bool {
    switch presentation {
    case .homeLastPlayed, .homeEmpty, .calendarExpanded, .weatherExpanded, .trayExpanded, .nowPlayingExpanded: return true
    default: return false   // .quickActionPicker falls here — UI-SPEC §1 decision
    }
}
```

**resolve() branch-ordering pattern** (lines 74-115) — D-04 requires ZERO new precedence logic: the existing `switch activeTransient` block (lines 85-89) already runs BEFORE `isExpanded`, so a Charging/Device transient wins over the picker automatically, exactly like it wins over `.trayExpanded` today:
```swift
if let step = onboardingStep { return .onboarding(step) }
switch activeTransient {                              // D-04: transient wins even over expanded
case .charging(let a): return .charging(a)
case .device(let d):   return .device(d)
case nil: break
}
if isExpanded {
    if selectedView == .calendar { return .calendarExpanded }
    if selectedView == .weather { return .weatherExpanded }
    if selectedView == .tray { return .trayExpanded }
    // NEW: if pendingDrop present (passed in as a param, per D-05/Pitfall 5), return
    // .quickActionPicker(pendingDrop) here, at the SAME tier, checked before Now-Playing.
    ...
}
```

**PendingDrop plain-value-struct pattern** (mirrors `Islet/Notch/DeviceActivity.swift` lines 1-20 — `struct DeviceReading: Equatable`, Foundation-only, no AppKit/SwiftUI):
```swift
import Foundation
// PendingDrop — the file(s) already copied in via ShelfFileStore.makeSessionCopy, awaiting
// a destination choice. Plain Equatable value so IslandResolverTests can construct it by hand
// (mirrors DeviceReading's "tests build it by hand" convention).
struct PendingDrop: Equatable {
    let items: [ShelfItem]   // already-copied-in files (D-03: one batch, one decision)
}
```

---

### `Islet/Notch/NotchWindowController.swift` (controller, event-driven)

**Analog:** the file's own `handleDragApproachEnd()` (drop-site branch point), Phase 21's `beginShelfItemDrag()`/`endShelfItemDrag()` (hold-state-open-across-async-decision precedent), and `positionAndShow`'s `trayFrame`/`weatherExpandedFrame` union members.

**Current unconditional-stage pattern to BRANCH** (lines 931-954):
```swift
private func handleDragApproachEnd() {
    guard isDragApproaching else { return }
    isDragApproaching = false

    let point = NSEvent.mouseLocation
    let pasteboard = NSPasteboard(name: .drag)
    let urls = fileURLs(from: pasteboard)
    if shouldAcceptDrop(isExpanded: false, urls: urls),
       isWithinDragAcceptRegion(point, zone: expandedZone, maxY: dragLandingMaxY) {
        for url in urls {
            let id = UUID()
            guard let localURL = try? ShelfFileStore.makeSessionCopy(of: url, id: id) else { continue }
            let item = ShelfItem(id: id, originalURL: url, localURL: localURL, filename: url.lastPathComponent, addedAt: Date())
            shelfCoordinator.append(item)   // <- NEW: gate this behind the picker instead;
                                             //    reuse makeSessionCopy verbatim (unchanged),
                                             //    but store items as PendingDrop + show picker
                                             //    instead of calling append() immediately.
        }
        resyncShelfViewState()
    }
    handlePointer(at: NSEvent.mouseLocation)
}
```

**Hold-state-open-across-async-decision precedent (D-05 pending-drop survival)** — Phase 21 drag-pin pattern, `beginShelfItemDrag`/`endShelfItemDrag` (lines 1781-1814): best-effort monitor + guaranteed safety-net timeout, idempotent teardown. `QuickActionSharingService`'s delegate-based completion (see below) mirrors this same "best-effort callback + bounded timeout" shape, and the controller's `deinit` teardown convention (lines 1841-1870, e.g. `dragPinSafetyNetWorkItem?.cancel()`) is the analog for cleaning up any pending-drop/sharing-delegate state on controller teardown.

**positionAndShow panel-frame-union pattern (geometry three-site rule, site 2 of 3)** (lines 810-844) — add a `quickActionPickerFrame` member exactly like `trayFrame`/`weatherExpandedFrame`:
```swift
let trayFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                   expandedSize: CGSize(width: NotchPillView.traySize.width,
                                                         height: NotchPillView.trayContentHeight + NotchPillView.switcherRowHeight))
let weatherExpandedFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                               expandedSize: CGSize(width: expandedSize.width,
                                                                     height: NotchPillView.weatherLargeContentHeight + NotchPillView.switcherRowHeight))
// NEW: let quickActionPickerFrame = expandedNotchFrame(collapsed: collapsedFrame,
//     expandedSize: CGSize(width: expandedSize.width, height: NotchPillView.quickActionPickerContentHeight))
//     -- NO switcherRowHeight addend (UI-SPEC: showSwitcher: false for this case).
let panelFrame = expandedFrame.union(wings).union(onboardingFrame).union(trayFrame).union(weatherExpandedFrame)
    // NEW: .union(quickActionPickerFrame)
```

**visibleContentZone() branch pattern (geometry three-site rule, site 3 of 3)** (lines 999-1043) — add a branch mirroring the `.trayExpanded`/`.weatherExpanded` branches, checked at the same tier:
```swift
if isOnboardingActive {
    contentSize = NotchPillView.onboardingSize
} else if case .trayExpanded = presentationState.presentation {
    contentSize = CGSize(width: NotchPillView.traySize.width, height: NotchPillView.trayContentHeight + switcherHeight)
} else if case .weatherExpanded = presentationState.presentation {
    ...
}
// NEW: else if case .quickActionPicker = presentationState.presentation {
//     contentSize = CGSize(width: expandedSize.width, height: NotchPillView.quickActionPickerContentHeight)
//     // no switcherHeight addend — showsSwitcherRow returns false for this case
// }
else {
    contentSize = CGSize(width: expandedSize.width, ...)
}
```
**Mandatory validation** (RESEARCH.md Pitfall 4 / UI-SPEC §6): all three sites above MUST land in the SAME commit, then verified via an on-device hover→expand→move-down click-through trace — this project's own repeated CR-01/CR-02 failure mode.

---

### `Islet/Notch/NotchPillView.swift` (component, request-response render)

**Analog:** `trayFullView` (lines 994-1024), `chipButton` (1304-1317), `blobShape` (1362+).

**New content-height constant pattern** (mirrors `traySize`/`weatherLargeContentHeight` at lines 356-401):
```swift
static let quickActionPickerContentHeight: CGFloat = 188   // UI-SPEC's worked math
```

**View-call-shape pattern to copy verbatim** (mirrors `trayFullView`, lines 994-1024 — UI-SPEC §3 already gives the literal target shape):
```swift
private func quickActionPickerView(_ pending: PendingDrop) -> some View {
    blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
              height: Self.quickActionPickerContentHeight, shelfItems: [],
              shelfVisible: false, showSwitcher: false) {
        VStack(spacing: 16) {
            quickActionPreview(pending)
            quickActionButtonRow(pending)
        }
        .padding(.top, Self.cameraClearance)
    }
}
```

**chipButton style pattern to reuse for the 3 destination buttons** (lines 1304-1317 — same `RoundedRectangle` + `Color.white.opacity(0.12)` chrome, same `.buttonStyle(.plain)`):
```swift
private func chipButton(_ label: String, fontSize: CGFloat = 14, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(label)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.12)))
    }
    .buttonStyle(.plain)
}
```
UI-SPEC's `quickActionButton` (34-UI-SPEC.md lines 149-167) is the concrete adaptation of this exact chip convention for an icon+label vertical layout with a `.disabled(!enabled)` D-09 fallback state — copy that block directly, it is already fully worked out.

**switch-statement wiring pattern** (`body`, lines 421-454) — add the new case at the same level as every other presentation:
```swift
case .trayExpanded:
    trayFullView
// NEW: case .quickActionPicker(let pending): quickActionPickerView(pending)
```

**Preview block D-02 reuse (NOT `ShelfItemView` itself)** — per UI-SPEC §4, do not reuse `ShelfItemView` with no-op closures (its `.onDrag` would offer a drag source for a file not yet staged). Build a lightweight twin matching `ShelfItemView.swift`'s exact visual convention (`Islet/Notch/ShelfItemView.swift` lines 13-24):
```swift
VStack(spacing: 2) {   // ShelfItemView's own gap — UI-SPEC uses 4pt for the standalone preview
    Image(nsImage: NSWorkspace.shared.icon(forFile: item.localURL.path))
        .resizable()
        .frame(width: 40, height: 40)
    Text(item.filename)
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.middle)   // V5 mitigation — same untrusted-filename discipline
}
```

---

### `Islet/Notch/QuickActionSharingService.swift` (NEW — service, event-driven)

**Analog:** `Islet/Notch/NowPlayingMonitor.swift` header (lines 1-16, "isolate the fragile thing" doctrine — CLAUDE.md's own mandate for MediaRemote applies identically here per RESEARCH.md's Established Patterns) + `Islet/Notch/DeviceCoordinator.swift`'s `@MainActor final class` + closure-injected-init shape (lines 18-96) for a thin class wrapping real OS IO around otherwise-pure state.

**Seam-isolation doc-comment convention to mirror**:
```swift
// Phase 34 / TRAY-04 — the THIN NSSharingService glue. Mirrors NowPlayingMonitor.swift's
// discipline: quarantine the one genuinely fragile/uncertain OS-integration call (RESEARCH.md's
// "isolate the fragile/uncertain thing behind its own seam") so a future macOS change is a
// one-file fix, not a ripple through the picker's SwiftUI view code.
```

**Concrete implementation** (RESEARCH.md Code Examples, lines 206-224 — already a full working sketch, copy directly):
```swift
final class QuickActionSharingService {
    private var activeDelegate: QuickActionSharingDelegate?

    func share(_ urls: [URL], via name: NSSharingService.Name, onFinish: @escaping () -> Void) {
        guard let svc = NSSharingService(named: name), svc.canPerform(withItems: urls) else {
            onFinish()   // Pitfall 2 — never a silent no-op
            return
        }
        let delegate = QuickActionSharingDelegate(onFinish: { [weak self] in
            self?.activeDelegate = nil
            onFinish()
        })
        activeDelegate = delegate   // NSSharingService does not retain its delegate
        svc.delegate = delegate
        svc.perform(withItems: urls)   // NO window activation — verified against boring.notch
    }
}
```

**Delegate + timeout-fallback pattern** (RESEARCH.md Pattern 2, lines 128-153 — mirrors this project's own `dragPinSafetyNetDuration`/`DispatchWorkItem` idiom from `NotchWindowController.swift` lines 235-249, 1786-1789):
```swift
final class QuickActionSharingDelegate: NSObject, NSSharingServiceDelegate {
    private let onFinish: () -> Void
    private var finished = false
    private var timeoutWorkItem: DispatchWorkItem?

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init()
        let timeout = DispatchWorkItem { [weak self] in self?.finish() }
        timeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: timeout)  // tune on UAT
    }
    func sharingService(_ s: NSSharingService, didShareItems items: [Any]) { finish() }
    func sharingService(_ s: NSSharingService, didFailToShareItems items: [Any], error: Error) { finish() }
    private func finish() {
        guard !finished else { return }
        finished = true
        timeoutWorkItem?.cancel()
        onFinish()
    }
}
```
**Anti-pattern to avoid:** no `makeKey()`/`NSApp.activate()`/`orderFrontRegardless()` call anywhere near this — D-08's key-window exception is NOT needed by default (RESEARCH.md's verified boring.notch precedent); only add it if the phase's own on-device spike proves the direct call silently no-ops.

---

## Shared Patterns

### Geometry three-site rule (mandatory, cross-cutting)
**Source:** `NotchPillView.swift` `blobShape()`'s `height:` param (line 1362+) + `NotchWindowController.swift` `positionAndShow`'s frame-union (lines 810-844) + `visibleContentZone()`'s branch (lines 999-1043).
**Apply to:** every file touching the new `.quickActionPicker` presentation — all three sites must change in the SAME commit or the CR-01/CR-02 click-through regression (dead-zone clicks or click-swallowing) recurs, per this project's own repeatedly-documented failure mode (Phase 32/33 comments, RESEARCH.md Pitfall 4, UI-SPEC §6).

### Single pure resolver as the ONE arbiter (COORD-01)
**Source:** `IslandResolver.swift` header comment (lines 1-33) and `resolve()` (lines 74-115).
**Apply to:** `IslandResolver.swift`'s new case/branch and `NotchWindowController.swift`'s controller-owned pending-drop state. The resolver stays a pure function of controller-provided inputs (D-05, RESEARCH.md Pitfall 5) — the controller, not the resolver, owns the `PendingDrop` payload across time (mirrors `TransientQueue`'s own head/pending split, `IslandResolver.swift` lines 190-241).

### Hold-state-open-across-async-decision (Phase 21 drag-pin precedent)
**Source:** `NotchWindowController.swift` `beginShelfItemDrag()`/`endShelfItemDrag()` (lines 1781-1814) — best-effort `.leftMouseUp` monitor + guaranteed `DispatchWorkItem` timeout, idempotent teardown, `deinit` cancellation (lines 1856-1860).
**Apply to:** `QuickActionSharingService`'s delegate+timeout completion pattern (same best-effort-callback + guaranteed-fallback shape) and the controller's own pending-drop lifecycle across a Charging/Device transient interruption (D-05).

### Reuse `ShelfCoordinator.append`/`ShelfFileStore.makeSessionCopy` verbatim
**Source:** `Islet/Shelf/ShelfCoordinator.swift` (`append`, lines 28-35) and the existing call site `NotchWindowController.swift` lines 943-948.
**Apply to:** the picker's "Drop" destination — routes through the EXACT same file-copy-in mechanism already at `handleDragApproachEnd()`; the picker only gates WHEN `append` is called, not HOW (RESEARCH.md Anti-Pattern, explicitly called out).

### V5 untrusted-filename display convention
**Source:** `Islet/Notch/ShelfItemView.swift` lines 18-23 (`.lineLimit(1)`, `.truncationMode(.middle)`, `.frame(maxWidth:)`, `T-20-01` comment).
**Apply to:** the picker's new preview block (single-file and multi-file) — reuse this exact convention rather than building new unguarded text display (UI-SPEC Typography section, RESEARCH.md Security Domain V5 row).

### Test style: pure-resolver precedence assertions
**Source:** `IsletTests/IslandResolverTests.swift` `testChargingOutranksDeviceAndMedia`/`testCalendarSelectionOutranksMedia` (lines 18-27, 239+) — construct inputs by hand, call `resolve(...)` directly, assert on the returned `IslandPresentation` case.
**Apply to:** new `.quickActionPicker` precedence tests (TRAY-02, D-04/D-05) in the same file.

### Test style: protocol-mock for an OS-boundary seam
**Source:** `IsletTests/LocationServiceTests.swift` (`FakeLocationService: LocationService`, call-count + captured-completion assertions, lines 9-24).
**Apply to:** `QuickActionSharingServiceTests.swift` — inject a fake/mockable `NSSharingService`-performing closure so `canPerform`/`perform` call counts are testable without triggering the real OS UI in CI (RESEARCH.md Validation Architecture, Wave 0 Gaps).

### Test style: real-disk-I/O fixture for file-copy-in glue
**Source:** `IsletTests/ShelfCoordinatorTests.swift` `setUp`/`tearDown` (real throwaway fixture dir) + `testRemoveDeletesSessionTempFileFromDisk` (lines 8-42).
**Apply to:** the new "picker Drop → append + view switch" glue test (TRAY-03's new-glue half; `append`/`makeSessionCopy` primitives already covered, only the new wiring needs a test).

## No Analog Found

None. Every file this phase touches has a strong, directly-comparable existing analog in this codebase (this project has repeated the "new full-takeover presentation case" shape 4+ times already: Onboarding, Calendar, Weather, Tray).

## Metadata

**Analog search scope:** `Islet/Notch/`, `Islet/Shelf/`, `IsletTests/`
**Files scanned:** `IslandResolver.swift`, `NotchWindowController.swift`, `NotchPillView.swift`, `ShelfCoordinator.swift`, `ShelfItemView.swift`, `DeviceActivity.swift`, `DeviceCoordinator.swift`, `NowPlayingMonitor.swift`, `IslandResolverTests.swift`, `LocationServiceTests.swift`, `ShelfCoordinatorTests.swift`
**Pattern extraction date:** 2026-07-15
