# Phase 70: File Tray Convert Button - Pattern Map

**Mapped:** 2026-07-29
**Files analyzed:** 6 (3 new, 3 modified; 2 test files also modified/added)
**Analogs found:** 6 / 6 (all files have a strong same-codebase analog — this phase is a pure extension of Phase 34's existing picker, so every new file mirrors an existing sibling)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|---------------|
| `Islet/Notch/ImageConversionService.swift` (NEW) | service (seam) | file-I/O / transform | `Islet/Notch/QuickActionSharingService.swift` | role-match (isolation-seam pattern; simpler — no delegate/async needed) |
| `Islet/Notch/DragDropSupport.swift` (MODIFIED) | utility | transform (pure geometry fn) | itself, `computeQuickActionButtonFrames(card:)` (same file, lines 68-81) | exact (generalize existing function in place) |
| `Islet/Notch/NotchPillView.swift` (MODIFIED) | component (SwiftUI view) | request-response (render) | itself, `quickActionButtonRow()`/`quickActionButton()` (same file, lines 2325-2357) + `quickActionPickerView()` (lines 2058-2075) | exact (add 4th button + 2nd-step sub-row using identical component) |
| `Islet/Notch/NotchWindowController.swift` (MODIFIED) | controller | event-driven (drag-release hit-test dispatch) | itself, `handleDragApproachEnd()` / `handleQuickActionDrop()` / `finishQuickActionSharing()` (same file, lines 1587-1715) | exact (add stage state + case 3 + 2nd-stage dispatch + D-06 gate fix) |
| `IsletTests/ImageConversionServiceTests.swift` (NEW) | test | CRUD-ish (real-I/O unit test, no mocking) | `IsletTests/QuickActionSharingServiceTests.swift` (structure) but content mirrors `ShelfFileStoreTests.swift`'s "exercise real FileManager I/O directly" convention | role-match |
| `IsletTests/DragDropSupportTests.swift` (MODIFIED) | test | transform (pure-function unit test) | itself (same file, lines 1-69) | exact |

## Pattern Assignments

### `Islet/Notch/ImageConversionService.swift` (NEW — service/seam, file-I/O transform)

**Analog:** `Islet/Notch/QuickActionSharingService.swift` (82 lines, full file read)

**Why this analog, and why to deviate from its shape:** `QuickActionSharingService` is this codebase's only prior "isolate the fragile/uncertain OS-integration call" seam. Its protocol/delegate/fake-injection machinery exists ONLY because `NSSharingService` is async and OS-UI-driven (needs a fake for CI). ImageIO conversion is synchronous, local, deterministic, no OS UI — copy the *seam isolation* idea (own file, `enum`/thin type, no logic bleeding into the controller) but do NOT copy the protocol+delegate+timeout machinery. Test it like `ShelfFileStoreTests.swift` tests real `FileManager` I/O directly (see Sources in RESEARCH.md), not like `QuickActionSharingServiceTests.swift`'s fake-injection.

**Seam-isolation shape to copy** (`QuickActionSharingService.swift` lines 58-64):
```swift
// The seam itself. `makeService` defaults to the real NSSharingService(named:) lookup so
// production call sites never pass anything — only tests substitute a fake.
final class QuickActionSharingService {
    private let makeService: (NSSharingService.Name) -> SharingServicePerforming?
    private var activeDelegate: QuickActionSharingDelegate?

    init(makeService: @escaping (NSSharingService.Name) -> SharingServicePerforming? = { NSSharingService(named: $0) }) {
        self.makeService = makeService
    }
```
→ `ImageConversionService` should be a plain `enum` namespace (no instance state needed — conversion is a pure function of `(sourceURL, format, destinationURL)`), simpler than the class above. See RESEARCH.md's Pattern 1 code example for the exact `enum ImageConversionService { static func convert(...) throws }` shape — that sketch is already codebase-fit and should be used near-verbatim.

**Error-as-typed-throw pattern to copy** (`QuickActionSharingService.swift` lines 69-73, the guard-else-return-early shape):
```swift
func share(_ urls: [URL], via name: NSSharingService.Name, onFinish: @escaping () -> Void) {
    guard let svc = makeService(name), svc.canPerform(withItems: urls) else {
        onFinish()
        return
    }
```
→ Mirror with `guard let source = CGImageSourceCreateWithURL(...) else { throw ImageConversionError.sourceUnreadable }` (typed `Error` enum, not a silent `onFinish`-style callback — this is synchronous so a `throws` function is the correct idiom here, not the async callback shape).

**Filename/path-safety pattern to copy** — from `ShelfFileStore.swift` lines 20-24 (V5 Input Validation, security-relevant, cross-reference RESEARCH.md's Security Domain section):
```swift
static func makeSessionCopy(of sourceURL: URL, id: UUID) throws -> URL {
    let filenameComponent = sourceURL.lastPathComponent
    guard filenameComponent != ".", filenameComponent != "..", !filenameComponent.isEmpty else {
        throw ShelfFileStoreError.invalidFilename
    }
```
→ Apply the identical guard to the NEW converted filename (`(item.filename as NSString).deletingPathExtension + "." + format.fileExtension`) before using it as a path component, per RESEARCH.md's V5/Tampering finding.

**Directory-staging convention to copy** (`ShelfFileStore.swift` lines 26-29):
```swift
let itemDir = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("IsletShelf", isDirectory: true)
    .appendingPathComponent(id.uuidString, isDirectory: true)
try FileManager.default.createDirectory(at: itemDir, withIntermediateDirectories: true)
```
→ Reuse this EXACT directory convention (`IsletShelf/<uuid>/`) for the converted file's destination — do not invent a new staging root (per D-04 / RESEARCH.md Pitfall 2).

---

### `Islet/Notch/DragDropSupport.swift` (MODIFIED — utility, pure geometry transform)

**Analog:** itself — `computeQuickActionButtonFrames(card:)` (lines 68-81, full file read, 81 lines total)

**Current hardcoded-3 signature to generalize:**
```swift
func computeQuickActionButtonFrames(card: CGRect) -> [CGRect] {
    let buttonRowHeight = NotchPillView.quickActionButtonRowHeight
    let gap: CGFloat = 16
    let chipWidth = NotchPillView.quickActionButtonWidth
    let totalContentWidth = 3 * chipWidth + 2 * gap
    let centeringInset = (card.width - totalContentWidth) / 2
    let rowRect = CGRect(x: card.minX + centeringInset,
                          y: card.maxY - NotchPillView.cameraClearance - buttonRowHeight,
                          width: totalContentWidth, height: buttonRowHeight)
    return (0..<3).map { i in
        CGRect(x: rowRect.minX + CGFloat(i) * (chipWidth + gap), y: rowRect.minY,
               width: chipWidth, height: rowRect.height)
    }
}
```
**Target shape** — add a `count: Int` parameter, replace both hardcoded `3`s (`3 * chipWidth + 2 * gap` → `CGFloat(count) * chipWidth + CGFloat(count - 1) * gap`, `(0..<3)` → `(0..<count)`). RESEARCH.md's Pattern 4 already contains the exact generalized function body — use it verbatim. Keep every other line (the `card.maxY - cameraClearance - buttonRowHeight` anchor, the centering formula) byte-identical; only the count is new. This function stays a free top-level function (not a method), matching this file's existing style for all 5 functions in it (`fileURLs`, `shouldAcceptDrop`, `isWithinDragAcceptRegion`, `isGenuineFileDrag`, `computeQuickActionButtonFrames`) — all pure, all directly `@testable import Islet`-testable, no class/struct wrapper.

**Call-site impact** (NotchWindowController.swift line 1446, must update both call sites once the format-tile stage exists):
```swift
quickActionButtonFrames = computeQuickActionButtonFrames(card: quickActionPickerFrame)
```
→ becomes `computeQuickActionButtonFrames(card: quickActionPickerFrame, count: 4)` for the main row, and a SECOND call with `count: 4` (JPG/PNG/HEIC/TIFF) computed fresh when the format-tile stage is entered (see NotchWindowController pattern below, Pitfall 4).

---

### `Islet/Notch/NotchPillView.swift` (MODIFIED — SwiftUI component, render-only)

**Analog:** itself — `quickActionButtonRow()` / `quickActionButton()` (lines 2320-2357) + `quickActionPickerView()` (lines 2050-2075), all read in full context

**Existing 3-button row to extend to 4 (lines 2325-2334):**
```swift
private func quickActionButtonRow() -> some View {
    HStack(spacing: 16) {
        quickActionButton(icon: "tray.and.arrow.down.fill", label: "Drop", enabled: true,
                           isHovered: presentationState.hoveredQuickActionButtonIndex == 0)
        quickActionButton(icon: "personalhotspot", label: "AirDrop", enabled: airDropAvailable,
                           isHovered: presentationState.hoveredQuickActionButtonIndex == 1)
        quickActionButton(icon: "envelope.fill", label: "Mail", enabled: mailAvailable,
                           isHovered: presentationState.hoveredQuickActionButtonIndex == 2)
    }
}
```
→ Add a 4th `quickActionButton(icon: "arrow.triangle.2.circlepath", label: "Convert", enabled: isConvertEnabled, isHovered: presentationState.hoveredQuickActionButtonIndex == 3)` call, same `HStack(spacing: 16)`. Per RESEARCH.md Pattern 3, `isConvertEnabled` must be computed inline from the bound `PendingDrop` payload at the render switch — NOT a new stored `var convertAvailable: Bool = true` mirroring `airDropAvailable`/`mailAvailable` (lines 423-424) verbatim, since those two are confirmed (grep) to be dead/never-wired from the controller (the exact D-06 bug class).

**Reusable button component — copy verbatim, zero changes needed** (lines 2341-2357):
```swift
private func quickActionButton(icon: String, label: String, enabled: Bool, isHovered: Bool) -> some View {
    VStack(spacing: 8) {
        Image(systemName: icon)
            .font(.system(size: 22))
            .frame(width: 22, height: 22)   // Pitfall 9 fix — fixed icon box, identical height across buttons
        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
    }
    .foregroundStyle(.white.opacity(enabled ? 1.0 : 0.3))   // D-09 disabled dim
    .frame(maxWidth: Self.quickActionButtonWidth)
    .padding(.vertical, 8)
    .background(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(enabled ? (isHovered ? 0.22 : 0.12) : 0.06))   // D-11 hover step
    )
    .scaleEffect(isHovered ? 1.04 : 1.0)   // D-11 slight scale
}
```
→ Reuse this SAME function for each format tile (JPG/PNG/HEIC/TIFF) too — per CONTEXT.md's Reusable Assets note, no new button component needed. Per RESEARCH.md Open Question 1, use a single shared icon (e.g. `photo`/`photo.fill`) across all 4 format tiles, differentiated only by `label`.

**Card/container shape to reuse unchanged** (`quickActionPickerView()`, lines 2058-2075):
```swift
private func quickActionPickerView() -> some View {
    blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
              width: Self.traySize.width, height: Self.quickActionPickerContentHeight,
              shelfItems: [], shelfVisible: false, showSwitcher: false) {
        quickActionButtonRow()
            .padding(.top, Self.cameraClearance)
            .padding(.horizontal, 24)
    }
}
```
→ Per D-01, no geometry/height change — `Self.quickActionPickerContentHeight` and `Self.traySize.width` stay exactly as-is. Per RESEARCH.md Pattern 3, this function needs to accept `PendingDrop` (bind it at the render switch, `case .quickActionPicker(let pendingDrop): quickActionPickerView(pendingDrop: pendingDrop)` at line 1115) so it can compute `isConvertEnabled` inline, and needs an internal branch for "is the format-tile stage showing" that swaps `quickActionButtonRow()` for a new `formatTileRow()` view using the identical `quickActionButton()` calls, `HStack(spacing: 16)`, `.padding(.top, Self.cameraClearance)`, `.padding(.horizontal, 24)` wrapper.

**Stale/dead pattern — do NOT copy:** `var airDropAvailable: Bool = true` / `var mailAvailable: Bool = true` (lines 423-424) — confirmed via grep to have zero call sites setting them from `NotchWindowController.swift`. This is the exact D-06 bug. Do not add a matching `var convertAvailable` stored property; compute fresh per-render instead (Pattern 3 above).

---

### `Islet/Notch/NotchWindowController.swift` (MODIFIED — controller, event-driven hit-test dispatch)

**Analog:** itself — `handleDragApproachEnd()` (lines 1587-1629) + `handleQuickActionDrop()` (lines 1662-1675) + `finishQuickActionSharing()` (lines 1681-1687), all read in full context

**Current hit-test dispatch to extend (add case 3) AND fix D-06's dormant gate** (lines 1605-1625):
```swift
let point = NSEvent.mouseLocation
if pendingDrop != nil {
    if let hit = quickActionButtonFrames.firstIndex(where: { $0.contains(point) }) {
        switch hit {
        case 0: handleQuickActionDrop()
        case 1: handleQuickActionAirDrop()
        case 2: handleQuickActionMail()
        default: break
        }
    } else {
        discardPendingDrop()
        dismissExpandedImmediately()
    }
    presentationState.hoveredQuickActionButtonIndex = nil
}
```
→ D-06 fix: add explicit guards before dispatching AirDrop/Mail (`case 1: if airDropAvailable { handleQuickActionAirDrop() }`, `case 2: if mailAvailable { handleQuickActionMail() }`) — currently these fire unconditionally regardless of the dimmed `enabled:` state. Add `case 3: if isConvertEnabled { enterConvertFormatStage() }` (or equivalent) — this MUST be gated from day one since Convert is the first real sometimes-false flag (RESEARCH.md Pitfall 3/D-06). Per RESEARCH.md Pitfall 4, this dispatch needs a stage discriminator (e.g. a new enum or `Bool` tracking "showing main row" vs. "showing format tiles") so a SECOND `switch hit` branch (0=JPG,1=PNG,2=HEIC,3=TIFF) is consulted instead when the format-tile stage is active, and `quickActionButtonFrames` must be recomputed for the CURRENT stage's geometry (not just once per `positionAndShow()`, line 1446) whenever the stage transitions.

**Drop's landing-and-close shape to mirror for `handleQuickActionConvert(to:)`** (lines 1662-1675):
```swift
private func handleQuickActionDrop() {
    for item in pendingDrop?.items ?? [] {
        shelfCoordinator.append(item)
    }
    resyncShelfViewState()
    viewSwitcherState.selectedView = .tray
    pendingDrop = nil
    dismissExpandedImmediately()
}
```
→ Full target shape already sketched in RESEARCH.md's Code Examples section ("Full conversion + landing flow") — mirrors this exact structure (`for item in pendingDrop.items`, `shelfCoordinator.append`, `resyncShelfViewState()`, `viewSwitcherState.selectedView = .tray`, `pendingDrop = nil`, `dismissExpandedImmediately()`), but with `ImageConversionService.convert(...)` producing the new `ShelfItem` per item before appending, and cleaning up the ORIGINAL (unconverted) session-temp copies afterward (mirrors `finishQuickActionSharing()`'s cleanup shape below, since those originals were never landed).

**Un-landed-item cleanup shape to mirror** (lines 1681-1687):
```swift
private func finishQuickActionSharing() {
    for item in pendingDrop?.items ?? [] {
        ShelfFileStore.deleteSessionCopy(at: item.localURL)
    }
    pendingDrop = nil
    dismissExpandedImmediately()
}
```
→ Reuse `ShelfFileStore.deleteSessionCopy(at:)` for the ORIGINAL (pre-conversion) session copies once the converted copies have landed — the originals were staged at drag-entry but never handed to `shelfCoordinator`, same situation AirDrop/Mail are in today.

**Off-target release / discard precedent** (D-13, lines 1614-1622, `discardPendingDrop()` at lines 1709-1715): reuse unchanged for the format-tile step's "release not on any tile" case, per CONTEXT.md's Claude's Discretion note and RESEARCH.md Open Question 3 — no new "back" affordance needed, mirror this exact discard-then-collapse pair.

---

## Shared Patterns

### Isolate-the-fragile-thing seam convention
**Source:** `Islet/Notch/QuickActionSharingService.swift` (whole file, esp. lines 3-10 header comment)
**Apply to:** `ImageConversionService.swift` (new)
Every OS-API-dependent call in this codebase gets its own small file (`NowPlayingMonitor`, `WeatherService`, `QuickActionSharingService`). ImageConversionService follows the same isolation instinct but should be simpler (`enum` namespace, no protocol/delegate) since conversion is synchronous/deterministic/no-OS-UI — see RESEARCH.md Pattern 1 for the full rationale and code sketch.

### Dim-never-hide + D-11 hover-scale (already built into `quickActionButton`)
**Source:** `Islet/Notch/NotchPillView.swift` lines 2341-2357
**Apply to:** Convert button + all 4 format tiles
No new component needed — `quickActionButton(icon:label:enabled:isHovered:)` already implements D-09 (opacity dim) and D-11 (hover fill-step + scale) exactly as required; call it with the new icon/label/enabled values, do not reimplement.

### Session-copy staging + `ShelfCoordinator.append` landing
**Source:** `Islet/Shelf/ShelfFileStore.swift` lines 20-35 (`makeSessionCopy` directory convention) + `Islet/Shelf/ShelfCoordinator.swift` lines 28-35 (`append`)
**Apply to:** `ImageConversionService`'s destination-path construction + `handleQuickActionConvert(to:)`'s landing call
D-04 requires the SAME staging convention (`IsletShelf/<uuid>/` under `NSTemporaryDirectory()`) and the SAME landing call (`shelfCoordinator.append(item)`) — but the actual bytes must be written by ImageIO, never by `FileManager.copyItem`/`makeSessionCopy` itself (RESEARCH.md Pitfall 2).

### Filename path-safety guard (V5 Input Validation / Tampering mitigation)
**Source:** `Islet/Shelf/ShelfFileStore.swift` lines 21-24
**Apply to:** `ImageConversionService`'s converted-filename construction
```swift
let filenameComponent = sourceURL.lastPathComponent
guard filenameComponent != ".", filenameComponent != "..", !filenameComponent.isEmpty else {
    throw ShelfFileStoreError.invalidFilename
}
```
Apply the identical `.`/`..`/empty guard to the derived converted filename before using it in a path.

### Controller-owns-hit-test / view-never-decides-selection
**Source:** `Islet/Notch/NotchWindowController.swift` lines 1605-1613 comment + `NotchPillView.swift` lines 2336-2337 comment
**Apply to:** Both the main-row Convert case and the new format-tile stage
"No `Button(action:)` wrapper — the view no longer decides selection, the controller's release hit-test does." The format-tile row must follow the same discipline: render-only, `isHovered` sourced from `presentationState.hoveredQuickActionButtonIndex`, actual dispatch happens in `handleDragApproachEnd()`.

### Discard-on-off-target-release (D-13)
**Source:** `Islet/Notch/NotchWindowController.swift` lines 1614-1622, `discardPendingDrop()` lines 1709-1715
**Apply to:** Format-tile stage's "released inside card but not on a tile" case
Reuse verbatim — release not on any recognized target discards the pending drop and force-collapses, no separate "back" code path needed.

## No Analog Found

None — every file in this phase's scope is either a same-shaped sibling of an existing file in the same directory (seam service, pure geometry helper, SwiftUI render function, controller dispatch) or a direct extension of an existing function. RESEARCH.md's own Architecture Patterns section already confirms every integration point was found via direct grep/read, not inferred.

## Metadata

**Analog search scope:** `Islet/Notch/`, `Islet/Shelf/`, `IsletTests/` (directories directly named in CONTEXT.md's Integration Points + RESEARCH.md's Recommended Project Structure)
**Files scanned:** `QuickActionSharingService.swift`, `DragDropSupport.swift`, `NotchPillView.swift`, `NotchWindowController.swift`, `ShelfCoordinator.swift`, `ShelfFileStore.swift`, `ShelfItem.swift`, `IslandPresentationState.swift`, `IslandResolver.swift` (grep only), `QuickActionSharingServiceTests.swift`, `DragDropSupportTests.swift`
**Pattern extraction date:** 2026-07-29
