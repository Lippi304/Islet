---
phase: 70-file-tray-convert-button
plan: 01
subsystem: ui
tags: [imageio, uniformtypeidentifiers, swift, xctest, geometry]

# Dependency graph
requires: []
provides:
  - "ImageConversionService.swift: ImageFormat enum (jpg/png/heic/tiff), convert(_:to:destinationURL:) via CGImageSource/CGImageDestination, isImageFile(_:) via UTType + ImageIO-sniff fallback"
  - "DragDropSupport.swift: computeQuickActionButtonFrames(card:count:) generalized signature (any button count, not just 3)"
  - "IslandPresentationState.isShowingConvertFormats: controller-write/view-read stage flag, defaults false"
affects: [70-02-file-tray-convert-button, 70-03-file-tray-convert-button, 70-04-file-tray-convert-button]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Local/synchronous/no-OS-UI file transforms get a plain enum-namespace seam (no protocol/delegate/mock machinery), tested directly against real fixture bytes — contrast with QuickActionSharingService's async-OS-UI seam, which does need a fake-injection protocol"
    - "Image-type detection: LaunchServices resourceValues(.contentTypeKey) alone is extension-database-driven, not content-sniffing — for genuine content-based detection independent of filename, fall back to ImageIO's CGImageSourceGetType, which does read magic bytes"

key-files:
  created:
    - Islet/Notch/ImageConversionService.swift
    - IsletTests/ImageConversionServiceTests.swift
  modified:
    - Islet/Notch/DragDropSupport.swift
    - IsletTests/DragDropSupportTests.swift
    - IsletTests/DragApproachGeometryTests.swift
    - Islet/Notch/IslandPresentationState.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "isImageFile(_:) uses resourceValues(.contentTypeKey) as primary check, falling back to CGImageSourceGetType header-byte sniffing for extensionless files — live-verified via a standalone swift script that plain resourceValues reports a generic 'public.data' type for an extensionless real-PNG fixture, which would have made D-05's own required test case fail"
  - "NotchWindowController.swift's stale 1-arg computeQuickActionButtonFrames(card:) call site (line 1446) deliberately left broken, exactly as the plan specifies — Plan 70-03 owns closing this gap by wiring the real 4-button/format-tile geometry"

patterns-established:
  - "computeQuickActionButtonFrames(card:count:) generalized in place: every constant/formula except the button-count literals stayed byte-identical, confirmed via a standalone geometry replica script matching the production formula's output to 3 decimal places"

requirements-completed: [D-02, D-05]

# Metrics
duration: 25min
completed: 2026-07-29
---

# Phase 70 Plan 01: Image Conversion Seam + Button-Count Geometry + Stage Flag Summary

**ImageIO-based JPG/PNG/HEIC/TIFF conversion seam with content-sniffing image detection, a generalized N-button Quick Action row geometry function, and the Convert-formats stage flag — the three foundational pieces every later Phase 70 plan builds on.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-07-29T16:00:00Z (approx.)
- **Completed:** 2026-07-29T16:09:00Z
- **Tasks:** 3/3 completed
- **Files modified:** 7 (2 created, 5 modified)

## Accomplishments
- `ImageConversionService.swift` — real ImageIO re-encode (`CGImageSource`/`CGImageDestination`) for all 4 target formats, proven via round-trip re-read of the converted file's own UTI, not a byte-copy-with-lied-extension
- `isImageFile(_:)` — genuinely content-based image detection, correctly classifying an extensionless file by its actual bytes (not just its declared/extension-derived type)
- `computeQuickActionButtonFrames(card:count:)` — generalized from hardcoded-3 to any button count, zero-regression proven for the existing count-3 case
- `IslandPresentationState.isShowingConvertFormats` — the controller-write/view-read contract Plans 70-02 and 70-03 both depend on

## Task Commits

Each task was committed atomically:

1. **Task 1: ImageConversionService.swift — ImageIO conversion + UTType image detection** - `1c60099` (feat)
2. **Task 2: Generalize computeQuickActionButtonFrames(card:count:)** - `42c4eca` (feat)
3. **Task 3: IslandPresentationState.isShowingConvertFormats stage flag** - `f643e85` (feat)

_TDD tasks 1 and 2 each landed as a single commit (test file + implementation together) rather than separate RED/GREEN commits — matching this project's existing convention for tdd="true" tasks that aren't run through the strict per-gate commit sequence._

## Files Created/Modified
- `Islet/Notch/ImageConversionService.swift` - ImageFormat enum, ImageConversionError, ImageConversionService.convert/isImageFile
- `IsletTests/ImageConversionServiceTests.swift` - real-fixture round-trip tests (all 4 formats), missing-source error test, image-detection test
- `Islet/Notch/DragDropSupport.swift` - computeQuickActionButtonFrames(card:count:) generalized in place
- `IsletTests/DragDropSupportTests.swift` - count-3 regression test + count-4 spacing/non-overlap test
- `IsletTests/DragApproachGeometryTests.swift` - 8 pre-existing call sites updated to pass `count: 3` (Rule 3 fix, see Deviations)
- `Islet/Notch/IslandPresentationState.swift` - `isShowingConvertFormats: Bool = false` added near `hoveredQuickActionButtonIndex`
- `Islet.xcodeproj/project.pbxproj` - registered `ImageConversionService.swift` (Islet target) and `ImageConversionServiceTests.swift` (IsletTests target) in both PBXFileReference/PBXBuildFile tables, group children, and Sources build phases

## Decisions Made
- `isImageFile` needed a real fallback beyond the plan's literal `resourceValues(.contentTypeKey)`-only sketch — live-tested and confirmed the LaunchServices-backed lookup does NOT content-sniff extensionless files, so it was extended with an ImageIO-sniff fallback (see Deviations).
- Left `NotchWindowController.swift`'s stale call site untouched exactly as the plan instructs — verified via `xcodebuild build` that its missing-argument error is the ONLY compile error at this point, matching the plan's own documented escalation check.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `isImageFile` needed an ImageIO-sniff fallback for extensionless files**
- **Found during:** Task 1 (writing `testIsImageFileDetection`)
- **Issue:** The plan's exact interface sketch (`resourceValues(forKeys: [.contentTypeKey])` → `.conforms(to: .image)`) failed the plan's own required test case: an extensionless file whose real bytes are a valid PNG was classified as `public.data` (not an image), because macOS's `resourceValues(.contentTypeKey)` resolves type from the LaunchServices extension database, not by sniffing file content. Confirmed via a standalone `swift` script comparing both a normal `.png` and an extensionless copy of the same bytes.
- **Fix:** `isImageFile` now checks `resourceValues(.contentTypeKey)` first (fast path for the common case); if that doesn't conform to `.image`, it falls back to `CGImageSourceCreateWithURL` + `CGImageSourceGetType`, which DOES read magic bytes regardless of extension. Both `.conforms(to: .image)` sites are documented inline.
- **Files modified:** `Islet/Notch/ImageConversionService.swift`
- **Verification:** `testIsImageFileDetection` (image / plain-text / extensionless-image cases) passes; standalone `swift` script re-confirmed the exact before/after behavior difference.
- **Committed in:** `1c60099` (Task 1 commit)
- **Note:** this changes the Task 1 acceptance criterion "`grep -c '\.conforms(to: \.image)'` returns 1" to 2 — an accepted, necessary deviation for correctness; the `resourceValues(forKeys:.*contentTypeKey` key-link pattern the plan's frontmatter documents is still present and correct.

**2. [Rule 3 - Blocking] Updated `DragApproachGeometryTests.swift`'s 8 pre-existing call sites**
- **Found during:** Task 2 (attempting to verify `DragDropSupportTests` via `xcodebuild test`)
- **Issue:** The plan anticipated exactly one stale 1-arg call site remaining after the signature generalization (`NotchWindowController.swift:1446`, deliberately deferred to Plan 70-03). In fact, `IsletTests/DragApproachGeometryTests.swift` — an existing test file not mentioned in this plan's `files_modified` — had 8 additional call sites to the old 1-arg `computeQuickActionButtonFrames(card:)`, which would leave the entire `IsletTests` target unable to compile.
- **Fix:** All 8 call sites updated to pass `count: 3`, preserving their exact existing test semantics (all exercise the production 3-button Drop/AirDrop/Mail row) with zero behavior change.
- **Files modified:** `IsletTests/DragApproachGeometryTests.swift`
- **Verification:** Confirmed via `xcodebuild build` that `NotchWindowController.swift:1446` remains the sole compile error project-wide after this fix (i.e., this fix didn't introduce or hide any other error).
- **Committed in:** `42c4eca` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 bug fix, 1 blocking-compile fix)
**Impact on plan:** Both were necessary for correctness/buildability. No scope creep — neither touches Plan 70-02/70-03's actual UI/controller wiring work.

## Issues Encountered

**Known, plan-documented build state (not a regression):** as designed by the plan (Task 2's action explicitly says "Do NOT touch this function's call site in NotchWindowController.swift... that update belongs to Plan 70-03"), a full `xcodebuild build -scheme Islet -configuration Debug` currently FAILS with exactly one error:

```
Islet/Notch/NotchWindowController.swift:1446:94: error: missing argument for parameter 'count' in call
```

This was verified after each of Task 2 and Task 3 to confirm it stays the ONLY compile error (no other regression hiding behind it). Per the plan's own `<verification>` section, this matches its documented escalation condition ("if the build in fact fails here, escalate: Plan 70-03 must land before any other work resumes") — this is expected, not a defect in this plan's own 3 tasks. **The project will not build cleanly, and the full XCTest suite will not run, until Plan 70-03 updates that call site.** Task 1's and Task 2's own new tests were verified independently: `ImageConversionServiceTests` via a scoped `xcodebuild test` run (before Task 2's change broke the whole-target build), and `DragDropSupportTests`'s two new geometry tests via a standalone `swift` script replicating the exact production formula (values matched to 3 decimal places).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `ImageConversionService`, the generalized `computeQuickActionButtonFrames(card:count:)`, and `isShowingConvertFormats` are all ready for Plan 70-02 (UI: format-tile row, Convert button) and Plan 70-03 (controller wiring, including the deferred `NotchWindowController.swift:1446` call-site fix).
- **Blocker for any subsequent test/build verification:** the project will not build or run tests until Plan 70-03's call-site update lands — this is expected per the plan, not a new blocker, but the next plan executor must address it before any other verification can succeed.

---
*Phase: 70-file-tray-convert-button*
*Completed: 2026-07-29*

## Self-Check: PASSED

All created/modified files confirmed present on disk; all 4 task/plan commits (`1c60099`, `42c4eca`, `f643e85`, `574a9e2`) confirmed in git log.
