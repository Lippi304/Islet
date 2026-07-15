import AppKit

// Phase 22 / SHELF-01 / SHELF-02 — the two pure, AppKit-glue-free seams 22-RESEARCH.md's Wave 0
// flags as this phase's genuinely testable surface. 22-03 wires these into NotchPanel's forwarded
// drag callbacks; neither function here has any spatial/screen-coordinate component -- that's
// 22-03's separate isWithinDragAcceptRegion(_:) gate (D-02b/D-02c).

// Reduces a drop pasteboard to plain file URLs. A folder URL is returned as-is -- NEVER
// enumerated (REQUIREMENTS.md Out of Scope, Pitfall 4).
func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
    (pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]) ?? []
}

// D-04's collapsed-only accept gate, combined with the non-file/empty-payload rejection
// (CONTEXT.md Claude's Discretion) into one silent no-op gate, mirroring shouldOpenShelfItem's
// shape.
func shouldAcceptDrop(isExpanded: Bool, urls: [URL]) -> Bool {
    !isExpanded && !urls.isEmpty
}

// Phase 24 / SHELF-01 / SHELF-02 (D-02/D-02c) — the drag-landing accept-region gate. `zone` is
// the caller's `expandedZone` (D-02, Phase 22's exact geometry, reused unchanged); `maxY` is the
// caller's `dragLandingMaxY` (D-02c's new landing-margin boundary, keeping the accept region
// clear of the literal top screen edge / Mission Control trigger). Kept as a pure top-level
// function (not a method) so it is directly unit-testable via `@testable import Islet`, matching
// this file's existing `fileURLs`/`shouldAcceptDrop` convention.
func isWithinDragAcceptRegion(_ point: CGPoint, zone: CGRect?, maxY: CGFloat?) -> Bool {
    guard let zone, let maxY else { return false }
    return zone.contains(point) && point.y <= maxY
}

// Phase 34 (UAT revision, D-11/D-12) / 34-RESEARCH.md Pattern 3 — the Quick Action picker's
// per-button live drop-target geometry. Pure arithmetic, mirroring `expandedNotchFrame`/
// `topPinnedFrame`'s existing style (NotchGeometry.swift) rather than a GeometryReader/
// PreferenceKey round-trip: this codebase has zero existing PreferenceKey usage, and a round-trip
// would need to bridge SwiftUI's window-local `.global` space against AppKit's screen-space
// bottom-left/y-up convention every other geometry helper in this file already uses (Pitfall 7).
// `card` is the caller's already-computed `quickActionPickerFrame` (real screen-space when called
// from the controller); returns the 3 destination buttons' frames in that SAME coordinate space,
// left-to-right (index 0 = Drop, 1 = AirDrop, 2 = Mail), matching `quickActionButtonRow`'s
// `HStack(spacing: 16)` of 3 equal-flex chips.
func computeQuickActionButtonFrames(card: CGRect) -> [CGRect] {
    let horizontalInset: CGFloat = 16
    let buttonRowHeight: CGFloat = 59   // icon 22 + gap 8 + label ~13 + vPadding 2x8
    let bottomInset: CGFloat = 16
    let gap: CGFloat = 16
    // AppKit bottom-left/y-up: the row sits `bottomInset` ABOVE the card's bottom edge (card.minY).
    let rowRect = CGRect(x: card.minX + horizontalInset, y: card.minY + bottomInset,
                          width: card.width - 2 * horizontalInset, height: buttonRowHeight)
    let colWidth = (rowRect.width - 2 * gap) / 3
    return (0..<3).map { i in
        CGRect(x: rowRect.minX + CGFloat(i) * (colWidth + gap), y: rowRect.minY,
               width: colWidth, height: rowRect.height)
    }
}
