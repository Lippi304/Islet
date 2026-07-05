---
phase: quick-260705-l4i
plan: 01
subsystem: notch-island
status: complete
tags: [D-01, idle-merge, geometry, swiftui]
requires:
  - NotchGeometry.notchSize (existing pure measurement seam)
  - NotchWindowController.positionAndShow (existing resolve/show site)
provides:
  - collapsedNotchSize (@Published measured notch size on NotchInteractionState)
  - data-driven collapsed pill frame (measured size, static 200x38 fallback)
affects:
  - Islet/Notch/NotchPillView.swift (collapsedIsland .frame)
tech-stack:
  added: []
  patterns: [nil-propagating-geometry-fallback, fudge-split-window-vs-visible-pill]
key-files:
  created: []
  modified:
    - Islet/Notch/NotchInteractionState.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift
decisions:
  - "Visible pill uses widthFudge: 0 (exact cutout); the window/hot-zone keeps widthFudge: 4 for seamless morph coverage + pointer target."
  - "200x38 constant retained as the documented nil/non-notch fallback, not deleted."
metrics:
  duration: pending
  completed: pending-human-verify
---

# Quick 260705-l4i: Idle Notch Merges With Hardware Summary

Data-drives the collapsed idle island's frame from the app's already-measured notch size (unfudged width + safe-area height) instead of the hardcoded `CGSize(200, 38)`, so a RELEASE build's black pill disappears into the physical notch (D-01), with the 200x38 constant kept as the nil/non-notch fallback.

## Status

**code-complete-release-verify-deferred** — Task 1 (code) is complete, the Debug build gate passed, and the change is merged into `gsd-new-project-setup` (merge commit `52ee074`).

Task 2 (on-device Release visual verify) is **DONE** — confirmed by the user on-device on 2026-07-05 ("klappt wieder") once the Release build could launch (via quick 260705-mzj signing fix). The idle island merges with the hardware notch and expands on hover in the Release build.

Original blocker context: the first verification attempt surfaced a **pre-existing, unrelated Release-launch crash** — the embedded `MediaRemoteAdapter.framework` fails Library Validation under Hardened Runtime on macOS 26/27 (`dyld: ... different Team IDs`; ad-hoc signed app + ad-hoc third-party framework, no entitlements file). This blocks EVERY Release build, independent of this geometry change (which only reached Release via this merge). Release verification of the idle merge will be done together with the signing fix, tracked as a separate quick task. Decision by user (2026-07-05): merge now, verify in Release after the signing fix.

## What Changed

**Task 1 — Thread the measured (unfudged) notch size into the collapsed pill** (commit `20c69cb`)

1. `NotchInteractionState.swift`
   - Added `import CoreGraphics` (file previously imported Foundation only; needed for `CGSize` under the build machine's toolchain — confirmed by the build gate).
   - Added `@Published var collapsedNotchSize: CGSize?` (defaults nil → view uses fallback), with a comment documenting the nil = not-measured / non-notch contract. No new model, no constructor param, no changes to the 8 DEBUG `#Previews`.

2. `NotchWindowController.swift`
   - Inside `positionAndShow(on:)`, after the existing `guard let collapsedFrame = notchFrame(..., widthFudge: 4)`, publish `interaction.collapsedNotchSize = notchSize(..., widthFudge: 0)` — the exact cutout macOS reports, so the black pill covers the cutout and not the lit pixels beside it.
   - The existing `notchFrame(..., widthFudge: 4)` window / hot-zone math is UNCHANGED — only the visible pill uses the unfudged size. A comment explains the fudge split.

3. `NotchPillView.swift`
   - `collapsedIsland` now reads `let size = interaction.collapsedNotchSize ?? Self.collapsedSize` and frames on `size.width` / `size.height` (was `Self.collapsedSize.*`). Property changed to a `return`-style computed body to introduce the local.
   - Updated the `static let collapsedSize` doc comment to state it is now the FALLBACK seed (external / non-notch display / nil geometry / previews).

## Preserved As-Is (per plan constraints)

- DEBUG `collapsedFill` (`red.opacity(0.6)` DEBUG / black RELEASE) and `devOffset` (8pt DEBUG / 0 RELEASE) — the on-device calibration aids — untouched.
- `NotchShape` corner radii, `expandedSize`, `wingsSize`, and all window/frame math — untouched.

## Verification

- **Build gate (automated):** `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` → **BUILD SUCCEEDED**. `xcodebuild test` deliberately NOT run (headless test hosting hangs in this repo — project memory).
- **On-device Release (Task 2 checkpoint):** PENDING — blocking human-verify. The black-on-black merge is only observable in a RELEASE build (DEBUG shows the red tint + 8pt offset by design).

## Flag for On-Device Review (no code change made)

`NotchShape` default radii (top 6 / bottom 14) were tuned for the 38pt-tall pill. At the measured ~32pt height the bottom radius is a larger fraction of the height. Not scaled in this task — the human should note during Release verification whether the collapsed corners look right; a radius tune would be a one-line follow-up if needed.

## Deviations from Plan

None — plan executed exactly as written (Tasks 1 edits applied surgically; build gate passed).

## Known Stubs

None.

## Self-Check: PASSED

- Files modified exist: NotchInteractionState.swift, NotchWindowController.swift, NotchPillView.swift (all committed in `20c69cb`).
- `collapsedNotchSize` present on NotchInteractionState, assigned once in positionAndShow via `notchSize(widthFudge: 0)`, read with `?? Self.collapsedSize` in collapsedIsland.
- Commit `20c69cb` exists in git log on branch worktree-agent-a61c2b38cb730ccd3.
