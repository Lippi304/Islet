# Phase 70: File Tray Convert Button - Research

**Researched:** 2026-07-29
**Domain:** macOS/Swift image format conversion (ImageIO) + existing Quick Action Destination Picker (Phase 34) extension
**Confidence:** HIGH (codebase patterns, geometry math, existing seams) / MEDIUM (ImageIO API specifics, sourced via WebSearch cross-referenced against Apple Developer Forums, not a live Context7/official-docs fetch)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Choosing "Convert" does NOT convert immediately. It opens a second step inside the SAME picker card: the 4-button row (Drop/AirDrop/Mail/Convert) is replaced by a row of format tiles, same button style/size as today. No new card geometry/height — reuses the existing `quickActionPickerContentHeight`/card shape.
- **D-02:** Format tiles offered: **JPG, PNG, HEIC, TIFF** — full Finder "Convert Image" scope, not just JPG/PNG.
- **D-03 (carried forward from Phase 34's D-03):** One decision applies to the whole batch — if multiple images are dropped, the chosen format converts all of them in one action.
- **D-04:** After a format is chosen, the converted file(s) go through the exact same LANDING path the "Drop" button already uses — `ShelfCoordinator.append` / the session-copy directory convention `ShelfFileStore.makeSessionCopy` establishes — landing in the Tray as converted copies. No save dialog, no in-place overwrite of the original.
- **D-05:** Convert follows the existing D-09 (Phase 34) dim-never-hide pattern exactly: renders `enabled: false` (dimmed) whenever the pending drop contains ANY non-image file. Only enabled when literally every dropped item is an image — no partial-batch conversion.
- **D-06 (folded todo, MUST be closed this phase):** The existing `enabled:` dimming for AirDrop/Mail has no matching controller-side gate at the release-hit-test (`handleDragApproachEnd()` fires `handleQuickActionAirDrop()`/`handleQuickActionMail()` unconditionally regardless of `airDropAvailable`/`mailAvailable`). Convert is the FIRST real, sometimes-false `enabled` flag in this component — this phase MUST also fix the controller gate.

### Claude's Discretion

- Exact SF Symbol for the Convert button's icon and for each format tile (JPG/PNG/HEIC/TIFF), mirroring Drop/AirDrop/Mail's icon+label convention.
- Underlying image-conversion mechanism (`CGImageDestination`/ImageIO vs. `NSBitmapImageRep` vs. shelling out to `sips`) — technical choice for research/planning.
- How "is this an image" is detected (file extension check vs. `UTType.conforms(to: .image)`) — technical detail.
- Whether there's an explicit "back" affordance from the format-tile step to the original 4-button row, or whether releasing off-target during the format-tile step discards the pending drop entirely (mirroring Phase 34's D-13 "release off-target discards" rule) — treat entering the format-tile step as NOT yet a commit, only the format tap itself commits; pick whichever back/cancel behavior is simplest given D-13's existing precedent.
- Naming of the new image-conversion seam/service.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope. A "partial-batch conversion" alternative was considered but not chosen (not deferred, just rejected in favor of the simpler all-or-nothing enable rule).
</user_constraints>

<phase_requirements>
## Phase Requirements

No formal REQ-IDs are assigned to Phase 70 yet (REQUIREMENTS.md shows "Requirements: TBD" for this phase — it is a queued feature idea added directly to ROADMAP.md on 2026-07-29, ahead of formal requirements-doc traceability). The planner should treat CONTEXT.md's D-01..D-06 as the de facto acceptance criteria until/unless REQUIREMENTS.md is updated with real IDs (e.g. `CONVERT-01..0N`) in a later pass.
</phase_requirements>

## Summary

This phase extends the existing Phase 34 Quick Action Destination Picker (`Islet/Notch/NotchPillView.swift` + `Islet/Notch/NotchWindowController.swift`) with a 4th "Convert" button and a second-step format-tile row (JPG/PNG/HEIC/TIFF). All the surrounding machinery — the picker card, the button styling, the release-based hit-test dispatch, the hover-index tracking, and the session-copy-then-`ShelfCoordinator.append` landing mechanism — already exists and should be reused/extended, not rebuilt. The genuinely new work is: (1) an image-conversion seam using ImageIO (`CGImageSource`/`CGImageDestination`), (2) image-type detection via `UTType.conforms(to: .image)` reading `URL.resourceValues(forKeys: [.contentTypeKey])`, (3) a second hit-test/render stage for the format tiles inside the same card, and (4) the D-06 controller-gate bug fix that must ship in the same phase because Convert is the first real (sometimes-`false`) `enabled` flag this component has ever had.

The most important non-obvious finding: `computeQuickActionButtonFrames(card:)` in `Islet/Notch/DragDropSupport.swift` hardcodes a button count of 3 (`(0..<3).map`, `3 * chipWidth + 2 * gap`) — this function MUST be generalized to accept a button count, since it needs to compute 4 frames for the Drop/AirDrop/Mail/Convert row AND a separate N-frame computation for the format-tile row (N = 4 for JPG/PNG/HEIC/TIFF). Both rows fit the existing 650pt-wide card with no geometry change (4×130pt buttons + 3×16pt gaps = 568pt inside 602pt available content width).

The second most important finding: D-04's "exact same path... `ShelfFileStore.makeSessionCopy`'s session-copy mechanism" cannot mean literally calling `makeSessionCopy` for the converted output, because that function performs a byte-for-byte `FileManager.copyItem` with zero transformation — it physically cannot produce a re-encoded image. The correct reading is: reuse the same *staging convention* (a fresh `NSTemporaryDirectory()/IsletShelf/<uuid>/<filename>` location) and the same *landing mechanism* (`ShelfItem` + `shelfCoordinator.append`), but the new image-conversion service must write the transformed bytes itself via ImageIO, then hand the resulting `ShelfItem` to `shelfCoordinator.append` exactly as `handleQuickActionDrop()` does today.

**Primary recommendation:** Use `CGImageSource`/`CGImageDestination` (ImageIO) for conversion — never `NSBitmapImageRep` (cannot write HEIC) or shelling out to `sips` (adds process-spawn overhead/parsing fragility for zero benefit over a 6-line native API call, violates this project's own "no dependency/shell-out for a small native surface" precedent used for the audio-output switcher). Use `UTType.conforms(to: .image)` (already imported in this codebase, `SettingsView.swift`) for image detection, not file-extension matching. Detect the "is this an image" question and the conversion-writer both live in one new seam file, `Islet/Notch/ImageConversionService.swift`, mirroring `QuickActionSharingService.swift`'s exact isolation convention.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Convert button + format-tile UI (icons, labels, dim state, hover) | Frontend/App UI (`NotchPillView.swift`, SwiftUI) | — | Pure render layer, mirrors existing `quickActionButtonRow()`/`quickActionButton()` |
| Release-point hit-test dispatch (which button/tile was released on) + D-06 enabled-gate fix | App Controller (`NotchWindowController.swift`, AppKit) | — | Same tier that already owns `handleDragApproachEnd()`; hit-test math is screen-space AppKit geometry, not a SwiftUI concern |
| Image-type detection (`UTType.conforms(to: .image)`) | App Controller or new seam | — | Cheap, synchronous, local — no reason to push into a separate process/service |
| Image format conversion (ImageIO read/write) | New seam (`ImageConversionService.swift`) | — | Isolates the one genuinely OS-API-dependent call, per this project's established "isolate the fragile/uncertain thing" convention (`QuickActionSharingService`, `NowPlayingMonitor`, `WeatherService` precedent) |
| Converted-file staging (temp dir write) | New seam (writes into `IsletShelf/<uuid>/` convention) | Filesystem | Mirrors `ShelfFileStore`'s existing directory convention without literally reusing its copy-only function |
| Landing converted file into Tray | `ShelfCoordinator.append` (existing, unchanged) | — | D-04 requires reusing this exact mechanism; zero new code needed here |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ImageIO (`CGImageSource`/`CGImageDestination`) | System framework, macOS 15.0+ (project's deployment target) | Read source image, write converted image in target format | Apple's own native image-transcoding API; only API surface that can write HEIC (confirmed: `NSBitmapImageRep` cannot — see Common Pitfalls) [MEDIUM: WebSearch cross-referenced against Apple Developer Forums] |
| UniformTypeIdentifiers (`UTType`) | System framework, macOS 11+ | Detect "is this file an image" via `UTType.conforms(to: .image)`; provide format UTIs (`.jpeg`, `.png`, `.heic`, `.tiff`) for the destination writer | Already imported in this codebase (`Islet/SettingsView.swift:3`) — zero new dependency; the type-based check is correct regardless of file extension, the extension-based check is not (a `.jpg`-named file could be a renamed PNG) [VERIFIED: codebase grep] |

No third-party packages are needed or recommended for this phase — everything is a system framework already linked into the target (AppKit/Foundation/ImageIO/UniformTypeIdentifiers ship with every macOS SDK; no `Package.swift`/SPM entry required).

### Supporting

None beyond the above — this phase's only "supporting" concern is the existing `ShelfCoordinator`/`ShelfFileStore` seam, which is unchanged (D-04).

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `CGImageDestination` (ImageIO) | `NSBitmapImageRep.representation(using:properties:)` | Cannot write HEIC at all (`NSBitmapImageRep.FileType` enum has no `.heic` case) — immediately disqualifying given D-02 requires HEIC. Also loses direct source-to-destination metadata copy (`CGImageDestinationAddImageFromSource`) that ImageIO offers. |
| `CGImageDestination` (ImageIO) | Shell out to `/usr/bin/sips` via `Process` | `sips` supports all 4 formats (it's what Finder's own "Convert Image" menu almost certainly wraps), but: process-spawn overhead per file, stdout/stderr parsing for error detection instead of a typed `Bool`/throw, and this project has an explicit precedent of avoiding shell-outs/third-party wrappers in favor of small native API calls (v1.7 `SimplyCoreAudio` rejection, "no dependency for a tiny native surface"). No benefit over ImageIO justifies the extra fragility. |

**Installation:** None — no `npm install`/`pip install`/SPM package additions. All APIs used (`ImageIO`, `UniformTypeIdentifiers`, `AppKit`, `Foundation`) are already linked system frameworks.

**Version verification:** N/A (system frameworks, not versioned packages) — availability confirmed against the project's own `MACOSX_DEPLOYMENT_TARGET: "15.0"` (project.yml), well past ImageIO's HEIC-writing floor of macOS 10.13 and UniformTypeIdentifiers' introduction in macOS 11.

## Package Legitimacy Audit

**Not applicable — this phase installs zero external packages.** Every API used (`ImageIO`, `UniformTypeIdentifiers`, `CoreGraphics`, `AppKit`, `Foundation`) is a first-party Apple system framework already linked into the `Islet` target; there is nothing to run `slopcheck`/`npm view`/`pip index` against. If a future revision of this phase considers a third-party image library, re-run the Package Legitimacy Gate at that time.

## Architecture Patterns

### System Architecture Diagram

```
[External file drag] --> DragApproachDetector / recheckDragAcceptRegion()
                              |
                              v
                 pendingDrop populated (ShelfItem[] via ShelfFileStore.makeSessionCopy)
                              |
                              v
                 quickActionPickerView() renders Drop/AirDrop/Mail/Convert row
                              |
              (release point hit-tested by handleDragApproachEnd(),
               computeQuickActionButtonFrames(card:count:) generalized to 4 buttons)
                              |
              +---------------+----------------+----------------+
              |               |                |                |
           Drop            AirDrop            Mail           Convert (NEW)
        (existing,       (existing,        (existing,      opens 2nd step:
       unchanged)      unchanged)         unchanged)     format-tile row
                                                                 |
                                                    (same card, format tiles
                                                     JPG/PNG/HEIC/TIFF,
                                                     own hit-test frames)
                                                                 |
                                                          format tapped
                                                                 |
                                                                 v
                                              ImageConversionService (NEW seam)
                                          UTType.conforms(to:.image) gate already
                                          passed at button-enable time; here:
                                          CGImageSourceCreateWithURL(original)
                                                --> CGImageDestinationCreateWithURL
                                                    (new IsletShelf/<uuid>/ path,
                                                     target UTType)
                                                --> CGImageDestinationAddImageFromSource
                                                --> CGImageDestinationFinalize
                                                                 |
                                                                 v
                                          ShelfItem(localURL: converted path)
                                                                 |
                                                                 v
                                    shelfCoordinator.append(item)  <-- SAME call
                                    Drop already makes (D-04) -- Tray shows result
```

### Recommended Project Structure

No new folders — one new file alongside the existing seam it mirrors:

```
Islet/Notch/
├── QuickActionSharingService.swift    # existing — AirDrop/Mail seam (Phase 34)
├── ImageConversionService.swift       # NEW — mirrors the file above's isolation convention
├── DragDropSupport.swift              # existing — generalize computeQuickActionButtonFrames(card:count:)
├── NotchPillView.swift                # extend quickActionButtonRow() + add format-tile row view
└── NotchWindowController.swift        # extend handleDragApproachEnd() + add handleQuickActionConvert()/format dispatch + fix D-06 gate
```

### Pattern 1: Image-conversion seam mirrors `QuickActionSharingService`'s isolation shape — but does NOT need the same protocol-mock/delegate machinery

**What:** `QuickActionSharingService` wraps `NSSharingService` behind a `SharingServicePerforming` protocol specifically because AirDrop/Mail are asynchronous, OS-UI-driven, and need a fake substitute in tests (no real share sheet in CI). Image conversion via ImageIO is synchronous, local, involves zero OS UI/permission prompts, and is deterministic — it does not need a protocol/delegate/fake-injection pattern. It can be tested directly against small real fixture images (mirrors `ShelfFileStoreTests.swift`'s own precedent of exercising real `FileManager` I/O directly rather than mocking it).

**When to use:** Any local, synchronous, no-OS-UI file transform — conversion, resizing, etc.

**Example:**
```swift
// Source: composed from ImageIO API surface [MEDIUM: WebSearch cross-referenced,
// Apple Developer Forums thread 87111 + 693106; not a live Context7/official-docs fetch]
import ImageIO
import UniformTypeIdentifiers

enum ImageFormat: CaseIterable {
    case jpg, png, heic, tiff

    var utType: UTType {
        switch self {
        case .jpg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        case .tiff: return .tiff
        }
    }

    var fileExtension: String {
        switch self {
        case .jpg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .tiff: return "tiff"
        }
    }

    var label: String {
        switch self {
        case .jpg: return "JPG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        case .tiff: return "TIFF"
        }
    }
}

enum ImageConversionError: Error { case sourceUnreadable, destinationCreationFailed, writeFailed }

enum ImageConversionService {
    // Reads sourceURL, writes a NEW file at destinationURL in the target format.
    // AddImageFromSource (not AddImage) copies the image + its metadata directly from
    // the source, avoiding a separate decode-to-CGImage round trip.
    static func convert(_ sourceURL: URL, to format: ImageFormat, destinationURL: URL) throws {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw ImageConversionError.sourceUnreadable
        }
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL, format.utType.identifier as CFString, 1, nil
        ) else {
            throw ImageConversionError.destinationCreationFailed
        }
        CGImageDestinationAddImageFromSource(destination, source, 0, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageConversionError.writeFailed
        }
    }
}
```

### Pattern 2: Image-type detection via `UTType`, not file extension

**What:** Read the file's actual declared content type from the filesystem/URL resource values, not its extension.
**When to use:** Gating Convert's `enabled` state (D-05) — must correctly classify a renamed or extensionless file.
**Example:**
```swift
// Source: composed from Apple's resourceValues(forKeys:) + UTType.conforms(to:) pattern
// [MEDIUM: WebSearch, cross-referenced against SerialCoder.dev tutorial + Apple Developer Forums thread 698316]
import UniformTypeIdentifiers

func isImageFile(_ url: URL) -> Bool {
    guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
        return false
    }
    return type.conforms(to: .image)
}
```
This should run against `ShelfItem.originalURL` (or `localURL` — same bytes, already copied) for every item in `pendingDrop.items`; Convert's `enabled` state is `pendingDrop.items.allSatisfy { isImageFile($0.originalURL) }`.

### Pattern 3: Derive Convert's `enabled` state from the already-available `PendingDrop` payload — do NOT thread a new stored `Bool` the way `airDropAvailable`/`mailAvailable` were

**What:** `IslandPresentation.quickActionPicker(PendingDrop)` already carries the full `PendingDrop` (with all `ShelfItem`s) as an associated value into the view layer — but the current render-switch statement (`NotchPillView.swift:1115`, `case .quickActionPicker:`) discards it (`case .quickActionPicker:` with no binding), and `quickActionPickerView()` takes no parameter.

**Why this matters:** Grepping the controller confirms `airDropAvailable`/`mailAvailable` (`NotchPillView.swift:423-424`, default `true`) are **never set from `NotchWindowController.swift`** — there is no `airDropAvailable: ...` call site anywhere in the controller. This is exactly the folded-todo bug (D-06): a stored flag that's supposed to be wired from the controller but silently never was, because nothing forces the two sides to stay in sync. Convert's "all items are images" state changes on *every new drop* (unlike AirDrop/Mail's device-capability flags, which are static for a session) — reusing the same "controller writes a stored Bool the view reads" pattern reproduces the identical sync-gap bug class Phase 70 is already being asked to fix for D-06, just for a brand-new flag this time.

**Recommendation:** Bind the payload at the render switch (`case .quickActionPicker(let pendingDrop): quickActionPickerView(pendingDrop: pendingDrop)`) and compute `isConvertEnabled` fresh, inline, every render, directly from `pendingDrop.items` — no new stored/threaded Bool, no possible drift.

### Pattern 4: Generalize `computeQuickActionButtonFrames(card:)` to accept a button count

**What:** `Islet/Notch/DragDropSupport.swift:68-81` hardcodes `3` in two places (`(0..<3).map`, `3 * chipWidth + 2 * gap`). This function is called once per `positionAndShow()` (`NotchWindowController.swift:1446`) and its output (`quickActionButtonFrames: [CGRect]`) is hit-tested by index in `handleDragApproachEnd()`'s `switch hit { case 0...2: ... }`.
**When to use:** This phase needs it twice — once for the 4-button main row (Drop/AirDrop/Mail/Convert), once for the 4-tile format row (JPG/PNG/HEIC/TIFF) when the format step is showing.
**Example:**
```swift
// Source: generalized from Islet/Notch/DragDropSupport.swift:68-81 (existing project code)
func computeQuickActionButtonFrames(card: CGRect, count: Int) -> [CGRect] {
    let buttonRowHeight = NotchPillView.quickActionButtonRowHeight
    let gap: CGFloat = 16
    let chipWidth = NotchPillView.quickActionButtonWidth
    let totalContentWidth = CGFloat(count) * chipWidth + CGFloat(count - 1) * gap
    let centeringInset = (card.width - totalContentWidth) / 2
    let rowRect = CGRect(x: card.minX + centeringInset,
                          y: card.maxY - NotchPillView.cameraClearance - buttonRowHeight,
                          width: totalContentWidth, height: buttonRowHeight)
    return (0..<count).map { i in
        CGRect(x: rowRect.minX + CGFloat(i) * (chipWidth + gap), y: rowRect.minY,
               width: chipWidth, height: rowRect.height)
    }
}
```
Geometry check (D-04/CONTEXT.md Established Patterns, confirmed by re-derivation): 4 × 130pt + 3 × 16pt = 568pt, comfortably inside the 602pt available content width (650pt card − 2×24pt horizontal padding) — no card resize needed for either the 4-button row or the 4-tile format row.

### Anti-Patterns to Avoid

- **Reusing `ShelfFileStore.makeSessionCopy` literally for the converted output:** It performs `FileManager.copyItem` — an unmodified byte copy. It cannot write a different image format. Write the converted bytes via `ImageConversionService` into a fresh `IsletShelf/<uuid>/<newFilename>` path (mirroring the directory convention, not the function body), then construct the `ShelfItem` from that path.
- **File-extension-based image detection:** A dropped file named `photo.jpg.txt` or an extensionless temp file would be misclassified. Use `UTType.conforms(to: .image)` against the actual declared content type.
- **Threading a new stored `Bool` (`convertAvailable`) through the controller the same way `airDropAvailable`/`mailAvailable` were threaded:** confirmed dead/never-wired in this codebase today (see Pattern 3) — reproduces the exact bug class D-06 already requires fixing, for a new flag this time.
- **Shelling out to `sips` via `Process`:** works, but against this project's own established "no shell-out/third-party wrapper for a small native API surface" convention (see Alternatives Considered), and harder to unit test (parsing CLI stdout vs. a typed throw).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Image format re-encoding (JPG/PNG/HEIC/TIFF) | A custom pixel-buffer encoder, or a hand-rolled HEIC/TIFF writer | `CGImageDestination` (ImageIO) | HEIC/TIFF encoding is genuinely complex (codec-level); ImageIO already ships a correct, Apple-maintained encoder for all 4 target formats on every supported macOS version |
| "Is this an image" detection | Extension allowlist (`.jpg`, `.png`, `.heic`, `.tiff`, `.gif`, ...) that will always be one format behind | `UTType.conforms(to: .image)` | The UTI graph already knows every image type the OS knows about (including future formats), and correctly classifies content by declared type, not by filename convention |

**Key insight:** Both of this phase's genuinely new technical surfaces (format conversion, image detection) already have a first-party, zero-dependency, already-available-in-target API — there is no library gap to fill and no reason to introduce one.

## Common Pitfalls

### Pitfall 1: `NSBitmapImageRep` silently cannot write HEIC
**What goes wrong:** A developer instinctively reaches for `NSBitmapImageRep(data:)?.representation(using: .heic, properties: [:])` because it's the more commonly-known AppKit image API (already used elsewhere for simple JPEG/PNG export) — but `NSBitmapImageRep.FileType` has no `.heic` case at all; this fails to compile, not just fails at runtime.
**Why it happens:** `NSBitmapImageRep` predates HEIC's 2017 introduction and Apple never extended its `FileType` enum to cover it; ImageIO's UTI-string-based API (`CGImageDestinationCreateWithURL`) was extended instead, since it takes an open-ended type-identifier string rather than a fixed enum.
**How to avoid:** Use `CGImageDestination` for all 4 formats uniformly (D-02 requires HEIC specifically) — do not special-case HEIC through a different code path than JPG/PNG/TIFF.
**Warning signs:** A compile error on `.heic` as an `NSBitmapImageRep.FileType` case, or a design that has "3 formats via NSBitmapImageRep + 1 format (HEIC) via something else."

### Pitfall 2: Reading `D-04`'s "exact same path" too literally
**What goes wrong:** Implementing Convert by calling `ShelfFileStore.makeSessionCopy(of: originalURL, id: newID)` for the *converted* output — this compiles and "works" in the sense that a file lands in the Tray, but it is silently the ORIGINAL unconverted bytes with a lied-about extension, not an actually re-encoded image.
**Why it happens:** D-04's wording ("the exact same path... `ShelfFileStore.makeSessionCopy`'s session-copy mechanism") reads as "call that exact function" if not cross-checked against what the function actually does (a `FileManager.copyItem`, zero transformation).
**How to avoid:** Read D-04 as constraining the *landing* mechanism (`ShelfItem` + `shelfCoordinator.append`, same temp-directory convention) — the actual byte transformation is new code in `ImageConversionService`, which must be a real conversion, not a copy.
**Warning signs:** A "converted" HEIC file that Finder still opens as a JPEG, or a diff that never touches `ImageIO`/`CGImageDestination` at all.

### Pitfall 3: Reproducing the D-06 sync-gap bug for a brand-new flag
**What goes wrong:** Implementing Convert's `enabled` state as a new stored `Bool` (e.g. `var convertAvailable: Bool = false` on `NotchPillView`) that the controller is supposed to set on every `pendingDrop` change — exactly mirroring `airDropAvailable`/`mailAvailable`'s shape, which are confirmed (via grep) to never actually be set by the controller anywhere.
**Why it happens:** Copy-paste of an existing, seemingly-established pattern in the same file, without checking whether that pattern is actually wired end-to-end today.
**How to avoid:** Bind `PendingDrop` directly at the render switch and compute `isConvertEnabled` inline every render (Pattern 3 above) — there is no controller-to-view state to drift out of sync.
**Warning signs:** A new `var` on `NotchPillView` with a default value and no corresponding `NotchWindowController` call site that sets it.

### Pitfall 4: Format-tile step reusing button-row hit-test indices without resetting `quickActionButtonFrames`
**What goes wrong:** If the format-tile step's frames are appended to (rather than replacing) `quickActionButtonFrames` after Convert is chosen, or if the switch in `handleDragApproachEnd()` isn't re-staged for the second step, a release on a format tile could be hit-tested against the FIRST step's index mapping (0=Drop, 1=AirDrop, 2=Mail, 3=Convert) instead of the format-tile mapping (0=JPG, 1=PNG, 2=HEIC, 3=TIFF) — silently triggering the wrong action (e.g. tapping "PNG" actually re-firing `handleQuickActionAirDrop()`).
**Why it happens:** The existing single-stage design (`handleDragApproachEnd()`'s one `switch hit { case 0...2 }`) has no precedent for a second stage within the same card; this phase is the first to need one.
**How to avoid:** Introduce explicit controller-side state for "which stage of the picker is showing" (e.g. an enum or `Bool isShowingConvertFormats`), recompute `quickActionButtonFrames` for the CURRENT stage's geometry on every stage transition (not just once per `positionAndShow()`), and make the hit-test switch branch on stage first, index second.
**Warning signs:** Only one `computeQuickActionButtonFrames` call site remains after this phase, or the format-tile taps sometimes trigger AirDrop/Mail instead of a conversion.

## Code Examples

### Full conversion + landing flow (controller-side sketch)
```swift
// Source: composed from this codebase's existing handleQuickActionDrop() shape
// (Islet/Notch/NotchWindowController.swift:1662-1675) + new ImageConversionService
private func handleQuickActionConvert(to format: ImageFormat) {
    guard let pendingDrop else { return }
    for item in pendingDrop.items {
        let id = UUID()
        let itemDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("IsletShelf", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        guard (try? FileManager.default.createDirectory(at: itemDir, withIntermediateDirectories: true)) != nil else { continue }
        let newFilename = (item.filename as NSString).deletingPathExtension + "." + format.fileExtension
        let destinationURL = itemDir.appendingPathComponent(newFilename)
        guard (try? ImageConversionService.convert(item.originalURL, to: format, destinationURL: destinationURL)) != nil else { continue }
        let convertedItem = ShelfItem(id: id, originalURL: item.originalURL, localURL: destinationURL,
                                      filename: newFilename, addedAt: Date())
        shelfCoordinator.append(convertedItem)   // D-04: same landing call Drop already uses
    }
    // Clean up the ORIGINAL pending session-temp copies -- they were never landed, mirrors
    // finishQuickActionSharing()'s cleanup shape for AirDrop/Mail's un-landed items.
    for item in pendingDrop.items {
        ShelfFileStore.deleteSessionCopy(at: item.localURL)
    }
    resyncShelfViewState()
    viewSwitcherState.selectedView = .tray
    self.pendingDrop = nil
    dismissExpandedImmediately()
}
```
Note: this sketch is illustrative of the shape (mirrors `handleQuickActionDrop()`/`finishQuickActionSharing()`'s exact structure) — the planner should decide exact error-handling behavior for a per-item conversion failure (skip-and-continue vs. abort-the-batch), which is not specified by CONTEXT.md.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Extension-based file-type sniffing | UTI/`UTType`-based type introspection | macOS 11 (2020), `UniformTypeIdentifiers` framework supersedes the older `kUTType*`/Core Services UTI C API | Already the modern, Apple-recommended approach; this codebase already imports the framework (`SettingsView.swift`) |
| JPEG-only or JPEG/PNG-only "convert image" tools | HEIC as Apple's default capture/storage format since iOS 11/macOS 10.13 | 2017 | D-02's inclusion of HEIC is correctly scoped to match Finder's own modern "Convert Image" menu, not a legacy JPEG/PNG-only tool |

**Deprecated/outdated:** None directly relevant — ImageIO's `CGImageSource`/`CGImageDestination` C API has been stable since macOS 10.4 and remains Apple's current recommended path for this exact use case (no successor API has superseded it).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `CGImageDestinationCreateWithURL` + `CGImageDestinationAddImageFromSource` + `CGImageDestinationFinalize` is the correct, idiomatic ImageIO call sequence for lossless-metadata-preserving format conversion, and `CGImageDestinationCopyTypeIdentifiers()` can be used to confirm HEIC-writing support at runtime | Code Examples, Pattern 1 | If the exact call sequence is subtly wrong (e.g. wrong argument order, missing an options dict some formats require), Task-level implementation may need a short spike/on-device verification before trusting this sketch verbatim — cross-referenced against 2+ Apple Developer Forums threads (87111, 693106) but not confirmed via a live Context7 or official-docs fetch this session |
| A2 | `NSBitmapImageRep.FileType` has no `.heic` case and therefore cannot write HEIC at all | Pitfall 1, Standard Stack | Low risk — this is long-standing, widely-corroborated Apple API behavior (HEIC postdates `NSBitmapImageRep`'s fixed enum), but was not independently re-verified against a current Apple header/docs fetch this session |
| A3 | `UTType.heic`, `.jpeg`, `.png`, `.tiff` are the correct built-in static `UTType` members to reference (rather than needing a custom `UTType(filenameExtension:)` construction) | Pattern 1 | Low risk — these are long-standing Apple system-declared UTIs; if any are missing on the exact SDK version this project builds against, a fallback via `UTType(mimeType:)` or `UTType(filenameExtension:)` would be needed instead |
| A4 | Finder's own "Convert Image" right-click menu is implemented via `sips` or an equivalent ImageIO-based path (used only as supporting rationale for rejecting a `sips` shell-out, not as a load-bearing technical claim) | Alternatives Considered | None — this is flavor/rationale text, not a claim the implementation depends on |

## Open Questions

1. **Exact SF Symbol choices for Convert + the 4 format tiles**
   - What we know: Convert's icon should mirror the reference screenshot's "circular refresh-arrows" concept — `arrow.triangle.2.circlepath` is the closest standard SF Symbol match. There is no per-format-specific SF Symbol (JPG/PNG/HEIC/TIFF are file-format labels, not conceptual icons the SF Symbols catalog has dedicated glyphs for).
   - What's unclear: Whether the format tiles should each show a distinct icon (forcing an artificial/inaccurate choice) or a single shared generic image icon (e.g. `photo`) with only the label text differentiating them.
   - Recommendation: Use a single shared icon (e.g. `photo` or `photo.fill`) across all 4 format tiles, differentiated only by label text (JPG/PNG/HEIC/TIFF) — this is explicitly left to Claude's discretion per CONTEXT.md and avoids inventing a false visual distinction between formats.

2. **Per-item conversion failure handling within a batch**
   - What we know: D-03 says one decision (format choice) applies to the whole batch; nothing in CONTEXT.md specifies what happens if one image in a multi-file batch fails to convert (e.g. corrupt source, unreadable file).
   - What's unclear: Skip-and-continue (land the successes, silently drop the failure) vs. abort-the-whole-batch vs. show an error state.
   - Recommendation: Skip-and-continue with a `Logger` warning (mirrors this project's general error-tolerance style for local file operations elsewhere, e.g. `ShelfFileStore.deleteSessionCopy`'s `try?` idempotent-no-op stance) — but this should be confirmed with the user during planning/discuss if not already implicitly acceptable.

3. **Back/cancel affordance from the format-tile step**
   - What we know: CONTEXT.md explicitly defers this to Claude's discretion, suggesting "whichever is simplest given D-13's existing precedent" (release off-target discards the pending drop entirely).
   - What's unclear: Whether an explicit "back" button/gesture is worth the added UI complexity for a first version.
   - Recommendation: No explicit back affordance — mirror D-13 exactly: releasing anywhere in the card but not on a format tile discards the pending drop (same behavior as the existing first-step "released inside picker card but not on a button" case). Simplest, reuses existing logic paths (`discardPendingDrop()` + `dismissExpandedImmediately()`) verbatim.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| ImageIO framework | Image conversion | Yes (system framework) | Bundled with macOS 15.0+ SDK (project's `MACOSX_DEPLOYMENT_TARGET`) | None needed |
| UniformTypeIdentifiers framework | Image-type detection | Yes (system framework, already imported in `SettingsView.swift`) | Bundled since macOS 11 | None needed |
| App Sandbox / entitlements | Reading dropped-file image data, writing converted copies to `NSTemporaryDirectory()` | N/A — app is explicitly NOT sandboxed (`ENABLE_APP_SANDBOX: NO` in `project.yml:123`, confirmed) | — | None needed; no new entitlement required for this phase |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None — this phase has zero unmet external dependencies.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest |
| Config file | none — plain `xcodebuild test -scheme Islet` (project.yml:196, 215) |
| Quick run command | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/ImageConversionServiceTests` |
| Full suite command | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |

### Phase Requirements → Test Map

No formal REQ-IDs exist for this phase yet (see Phase Requirements above); mapping instead to CONTEXT.md's D-01..D-06 decisions.

| Decision | Behavior | Test Type | Automated Command | File Exists? |
|----------|----------|-----------|-------------------|-------------|
| D-02 | Converts a real JPEG fixture to PNG/HEIC/TIFF and back, verifying the output UTI matches | unit | `xcodebuild test ... -only-testing:IsletTests/ImageConversionServiceTests/testConvertsJPEGToEachFormat` | Wave 0 (new file) |
| Pattern 2 (image detection) | `isImageFile` correctly classifies a real image fixture true, a `.txt` fixture false, an extensionless-but-image-content fixture true | unit | `-only-testing:IsletTests/ImageConversionServiceTests/testIsImageFileDetection` | Wave 0 (new file) |
| Pattern 4 (geometry) | `computeQuickActionButtonFrames(card:count:4)` produces 4 correctly-spaced, non-overlapping frames fitting inside `card` | unit | `-only-testing:IsletTests/DragDropSupportTests/testComputeQuickActionButtonFramesGeneralizedCount` | Wave 0 (extend existing `DragDropSupportTests.swift`) |
| D-06 (controller gate fix) | A release-hit-test on a `enabled: false` button index does NOT dispatch its handler | unit or manual grep-based structural check | mirrors this project's own precedent (e.g. Phase 67.1's grep-based structural-invariant checks) — a direct XCTest against `handleDragApproachEnd()` would need `@testable import Islet` + a constructed controller instance; if that's impractical, a grep-based check confirming the `enabled`/`airDropAvailable`/`mailAvailable`/`convertEnabled` flags are read inside the hit-test switch is an acceptable Wave-0-documented fallback | Wave 0 (new test or documented grep check) |
| D-05 (mixed-batch disable) | `pendingDrop.items.allSatisfy { isImageFile($0.originalURL) }` correctly returns `false` for a mixed image+non-image batch | unit | `-only-testing:IsletTests/ImageConversionServiceTests/testMixedBatchDisablesConvert` | Wave 0 (new file) |

### Sampling Rate

- **Per task commit:** `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/ImageConversionServiceTests -only-testing:IsletTests/DragDropSupportTests`
- **Per wave merge:** full suite (`xcodebuild test -scheme Islet -destination 'platform=macOS'`)
- **Phase gate:** Full suite green before `/gsd:verify-work`, plus an on-device checkpoint (this phase touches real drag-and-release interaction, matching Phase 34's own precedent of needing on-device UAT for the picker's release-based hit-test behavior)

### Wave 0 Gaps

- [ ] `IsletTests/ImageConversionServiceTests.swift` — new file, covers D-02/D-05/Pattern-2 image-detection and conversion-correctness tests. Use small real fixture images (a few KB PNG/JPEG) committed to `IsletTests/Fixtures/` or generated in-memory via `CGContext` at test time — mirrors `ShelfFileStoreTests.swift`'s convention of exercising real I/O directly, no mocking framework.
- [ ] Extend `IsletTests/DragDropSupportTests.swift` — add coverage for the generalized `computeQuickActionButtonFrames(card:count:)` signature (Pattern 4).
- [ ] Framework install: none — XCTest is already wired via the existing `Islet` scheme.

## Security Domain

### Applicable ASVS Categories

This is a local, single-user, non-networked desktop feature — most ASVS web/API categories do not apply. The relevant categories:

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | N/A — no auth surface |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A — single local user |
| V5 Input Validation | Yes | Reuse `ShelfFileStore.makeSessionCopy`'s existing filename-validation precedent (rejects `.`/`..`/empty last-path-component before any disk I/O) for the NEW converted-file destination path construction — the converted filename is derived from `item.filename` (already validated when the original was staged), but the derived `(name).deletingPathExtension + "." + format.fileExtension` construction should still be defensively checked for emptiness before use as a path component |
| V6 Cryptography | No | N/A — no encryption/hashing involved |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| Malformed/malicious image file causing a crash or memory-safety issue during decode | Denial of Service | ImageIO's `CGImageSourceCreateWithURL` returns `nil` (not a crash) on unreadable/malformed input — guard against `nil` (already reflected in the Code Examples sketch's `guard let source = ... else { throw }`); never force-unwrap |
| Path traversal via a crafted filename component during converted-file destination construction | Tampering | Mirror `ShelfFileStore.makeSessionCopy`'s existing guard (reject `.`/`..`/empty component) applied to the NEW converted filename before constructing the destination `URL` |

## Sources

### Primary (HIGH confidence)
- Codebase grep/read (this session): `Islet/Notch/QuickActionSharingService.swift`, `Islet/Notch/DragDropSupport.swift`, `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/IslandResolver.swift`, `Islet/Notch/IslandPresentationState.swift`, `Islet/Shelf/ShelfFileStore.swift`, `Islet/Shelf/ShelfCoordinator.swift`, `Islet/Shelf/ShelfItem.swift`, `IsletTests/DragDropSupportTests.swift`, `IsletTests/QuickActionSharingServiceTests.swift`, `project.yml`, `.planning/phases/70-file-tray-convert-button/70-CONTEXT.md`, `.planning/todos/pending/2026-07-19-quick-action-disabled-state-has-no-controller-gate.md`

### Secondary (MEDIUM confidence)
- Apple Developer Forums thread 87111 ("Writing CGImage to HEIC fails with...") — CGImageDestination HEIC-writing patterns
- Apple Developer Forums thread 693106 ("Cannot save HEIC sequence image with...") — `CGImageDestinationCopyTypeIdentifiers()` HEIC-support-check pattern
- Apple Developer Forums thread 698316 — `resourceValues(forKeys: [.contentTypeKey])` + `UTType.conforms(to:)` pattern
- SerialCoder.dev — "Getting Local File's Type Identifier From URL in iOS & macOS Apps"

### Tertiary (LOW confidence)
- None retained — all findings above were cross-referenced across at least 2 sources before inclusion.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — ImageIO/UniformTypeIdentifiers are the only credible options and the codebase already imports `UniformTypeIdentifiers`; no alternative library candidates exist worth debating
- Architecture: HIGH — every integration point (button row, hit-test dispatch, session-copy/append landing, hover-index) is existing, read, and grepped code in this session, not inferred
- ImageIO API call sequence specifics: MEDIUM — cross-referenced across multiple Apple Developer Forums threads but not confirmed via a live Context7 fetch or a direct official ImageIO documentation page render this session (the one official-docs WebFetch attempt for `CGImageDestination` did not return genuine page content)
- Pitfalls: HIGH for the codebase-derived pitfalls (Pitfall 2, 3, 4 — all confirmed via direct grep/read), MEDIUM for the ImageIO-specific pitfall (Pitfall 1 — well-corroborated but not independently re-verified against a current Apple header this session)

**Research date:** 2026-07-29
**Valid until:** ~60 days (ImageIO/UniformTypeIdentifiers are extremely stable, slow-moving system frameworks; the codebase-specific findings should be re-verified if Phase 34's picker code is touched by any other phase before Phase 70 executes)
