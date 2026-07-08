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
