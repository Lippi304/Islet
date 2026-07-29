---
phase: 70
slug: file-tray-convert-button
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-29
---

# Phase 70 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest |
| **Config file** | none — plain `xcodebuild test -scheme Islet` (project.yml:196, 215) |
| **Quick run command** | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/ImageConversionServiceTests -only-testing:IsletTests/DragDropSupportTests` |
| **Full suite command** | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |
| **Estimated runtime** | ~60 seconds (quick), ~5 minutes (full) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/ImageConversionServiceTests -only-testing:IsletTests/DragDropSupportTests`
- **After every plan wave:** Run `xcodebuild test -scheme Islet -destination 'platform=macOS'`
- **Before `/gsd-verify-work`:** Full suite must be green, plus an on-device checkpoint (this phase touches real drag-and-release interaction, matching Phase 34's own precedent of needing on-device UAT for the picker's release-based hit-test behavior)
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 70-01-TBD | TBD | 0 | D-02 | — | Converts a real JPEG fixture to PNG/HEIC/TIFF and back, output UTI matches | unit | `-only-testing:IsletTests/ImageConversionServiceTests/testConvertsJPEGToEachFormat` | ❌ W0 | ⬜ pending |
| 70-01-TBD | TBD | 0 | Pattern 2 (image detection) | — | `isImageFile` classifies image true, `.txt` false, extensionless-image true | unit | `-only-testing:IsletTests/ImageConversionServiceTests/testIsImageFileDetection` | ❌ W0 | ⬜ pending |
| 70-01-TBD | TBD | 0 | Pattern 4 (geometry) | — | `computeQuickActionButtonFrames(card:count:4)` produces 4 correctly-spaced, non-overlapping frames | unit | `-only-testing:IsletTests/DragDropSupportTests/testComputeQuickActionButtonFramesGeneralizedCount` | ❌ W0 (extend existing file) | ⬜ pending |
| 70-01-TBD | TBD | 0 | D-06 (controller gate fix) | — | Release-hit-test on `enabled: false` button index does NOT dispatch its handler | unit or grep-based structural check | mirrors project's grep-based structural-invariant precedent (e.g. Phase 67.1); direct XCTest needs `@testable import Islet` + constructed controller instance | ❌ W0 | ⬜ pending |
| 70-01-TBD | TBD | 0 | D-05 (mixed-batch disable) | — | `pendingDrop.items.allSatisfy { isImageFile(...) }` returns false for mixed image+non-image batch | unit | `-only-testing:IsletTests/ImageConversionServiceTests/testMixedBatchDisablesConvert` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/ImageConversionServiceTests.swift` — new file, covers D-02/D-05/Pattern-2 image-detection and conversion-correctness tests. Use small real fixture images (a few KB PNG/JPEG) committed to `IsletTests/Fixtures/` or generated in-memory via `CGContext` at test time — mirrors `ShelfFileStoreTests.swift`'s convention of exercising real I/O directly, no mocking framework.
- [ ] Extend `IsletTests/DragDropSupportTests.swift` — add coverage for the generalized `computeQuickActionButtonFrames(card:count:)` signature (Pattern 4).
- [ ] Framework install: none — XCTest is already wired via the existing `Islet` scheme.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real drag-and-release interaction through the 2-step picker (Convert → format tile → landing in Tray) | D-01, D-04 | Drag/release gestures and on-screen hit-testing aren't practically covered by XCTest in this codebase (matches Phase 34's own precedent) | On-device: drop an image, tap Convert, tap a format tile, confirm converted file lands in Tray with correct format/extension |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
