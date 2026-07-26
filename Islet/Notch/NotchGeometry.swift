import CoreGraphics

// ISL-01 — pure notch geometry.
//
// These three functions take plain numbers (no live NSScreen), so the math is
// fully unit-testable. Plan 02 builds the NSScreen-backed wiring that feeds real
// `safeAreaInsets.top` / `auxiliaryTop{Left,Right}Area.width` values into them.

// A screen "has a notch" only when the system reports a non-zero top safe-area
// inset AND both auxiliary top areas exist (the two strips beside the notch).
// One strip alone (incomplete data) is NOT treated as a notch.
func hasNotch(safeAreaTop: CGFloat, auxLeftWidth: CGFloat?, auxRightWidth: CGFloat?) -> Bool {
    safeAreaTop > 0 && auxLeftWidth != nil && auxRightWidth != nil
}

// Notch width = full screen width minus the two side strips. We add a small
// `widthFudge` (default 4) so the pill overlaps the hardware edges with no seam.
// Notch height = the top safe-area inset (NOT the menu-bar height — they differ).
// Returns nil when the screen has no notch — OR when the computed width is not
// positive. `hasNotch` only guarantees a non-zero safe-area top and both aux
// widths being present; it does NOT guarantee `left + right < screenWidth`. On
// malformed / transitional NSScreen data (mid display reconfiguration, the exact
// window where didChangeScreenParameters can fire), the side strips could
// momentarily sum to ≥ screenWidth, yielding a zero/negative width. Fail safe to
// nil there — same nil-propagating contract as notchFrame, so the panel simply
// isn't repositioned that frame rather than fed a degenerate NSRect.
func notchSize(screenWidth: CGFloat,
               safeAreaTop: CGFloat,
               auxLeftWidth: CGFloat?,
               auxRightWidth: CGFloat?,
               widthFudge: CGFloat = 4) -> CGSize? {
    guard hasNotch(safeAreaTop: safeAreaTop, auxLeftWidth: auxLeftWidth, auxRightWidth: auxRightWidth),
          let left = auxLeftWidth, let right = auxRightWidth else { return nil }
    let width = screenWidth - left - right + widthFudge
    guard width > 0 else { return nil }
    return CGSize(width: width, height: safeAreaTop)
}

// AppKit windows use a BOTTOM-LEFT origin with y increasing upward, so the TOP
// edge of the screen is `frame.maxY` (Pitfall 1). We center horizontally on the
// screen's midX and pin the pill flush to that top edge: y = maxY - notchHeight.
// Works for any screen origin (e.g. a built-in display placed to the right in the
// arrangement) because everything is relative to the passed-in screenFrame.
// Returns nil when the screen has no notch.
func notchFrame(screenFrame: CGRect,
                safeAreaTop: CGFloat,
                auxLeftWidth: CGFloat?,
                auxRightWidth: CGFloat?,
                widthFudge: CGFloat = 4) -> CGRect? {
    guard let size = notchSize(screenWidth: screenFrame.width,
                               safeAreaTop: safeAreaTop,
                               auxLeftWidth: auxLeftWidth,
                               auxRightWidth: auxRightWidth,
                               widthFudge: widthFudge) else { return nil }
    let x = screenFrame.midX - size.width / 2
    let y = screenFrame.maxY - size.height
    return CGRect(x: x, y: y, width: size.width, height: size.height)
}

// Phase 52 / SWITCH-04 (RESEARCH.md Pitfall 2) — the real camera-cutout width the top-edge
// switcher row must reserve as its center Color.clear spacer. Reuses notchSize(...)'s own
// verified formula — NEVER auxLeftWidth + auxRightWidth (that sums the two strips beside the
// notch, not the notch itself). Falls back to 0 (never nil/crash) on a missing-notch input.
func topEdgeCutoutGap(screenWidth: CGFloat,
                      safeAreaTop: CGFloat,
                      auxLeftWidth: CGFloat?,
                      auxRightWidth: CGFloat?,
                      widthFudge: CGFloat = 4) -> CGFloat {
    notchSize(screenWidth: screenWidth,
             safeAreaTop: safeAreaTop,
             auxLeftWidth: auxLeftWidth,
             auxRightWidth: auxRightWidth,
             widthFudge: widthFudge)?.width ?? 0
}

// Phase 15 architecture audit item 1 — the shared body of expandedNotchFrame/wingsFrame
// (both centered on the collapsed pill's midX, pinned to the top edge / AppKit maxY).
private func topPinnedFrame(collapsed: CGRect, size: CGSize) -> CGRect {
    let x = collapsed.midX - size.width / 2
    let y = collapsed.maxY - size.height
    return CGRect(x: x, y: y, width: size.width, height: size.height)
}

// ISL-04 — the EXPANDED island frame. Same contract as notchFrame: centered on the
// collapsed pill's midX and pinned to the top edge (AppKit bottom-left origin, so the
// top edge is maxY). The panel is sized to THIS up front (Plan 02) so the SwiftUI spring
// can morph the content without the window clipping or jumping mid-animation.
func expandedNotchFrame(collapsed: CGRect, expandedSize: CGSize) -> CGRect {
    topPinnedFrame(collapsed: collapsed, size: expandedSize)
}

// CHG-01 — the WINGS frame (sideways/Alcove layout, D-01). Same contract as
// expandedNotchFrame: centered on the collapsed pill's midX and pinned to the top
// edge (AppKit bottom-left origin, so the top edge is maxY). The panel is sized to
// the UNION of this and expandedNotchFrame up front (Pattern 4) so neither the
// Phase-2 downward expand nor the Phase-3 sideways wings is ever resized mid-animation.
func wingsFrame(collapsed: CGRect, wingsSize: CGSize) -> CGRect {
    topPinnedFrame(collapsed: collapsed, size: wingsSize)
}

// Phase 67.1 / D-06 — resolution-aware auto-scale factor. `screenWidthPoints` is the
// scaled-resolution width in POINTS (not physical screen diagonal, not raw pixels —
// D-05), so a user running a denser scaled resolution on the same physical hardware
// gets a proportionally larger factor. `baseline` (default 1470pt) is the locked
// reference point where the factor reads as an untouched 1.0 (today's shipped sizing).
// Guards non-positive inputs and returns the safe identity 1.0 rather than dividing by
// zero or producing a negative/undefined scale — mirrors this file's existing
// guard-return-safe-default convention (see topEdgeCutoutGap above).
func islandAutoScaleFactor(screenWidthPoints: CGFloat, baseline: CGFloat = 1470) -> CGFloat {
    guard baseline > 0, screenWidthPoints > 0 else { return 1.0 }
    return screenWidthPoints / baseline
}

// Phase 67.1 / D-04/D-07/D-08 — resolves the final island scale from the auto factor
// above plus a user-controlled manual offset. ADDITIVE, never multiplicative (D-07/D-08):
// the offset shifts the auto value by a flat amount rather than scaling it, so the same
// manual adjustment feels consistent regardless of the current auto factor. `range`
// (default 0.8...1.5, D-04) is the single shared clamp every consumer routes through —
// no call site clamps independently (T-67.1-01).
func resolvedIslandScale(auto: CGFloat, manualOffset: CGFloat, range: ClosedRange<CGFloat> = 0.8...1.5) -> CGFloat {
    min(max(auto + manualOffset, range.lowerBound), range.upperBound)
}
