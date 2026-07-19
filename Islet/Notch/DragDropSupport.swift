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

// Phase 43 / DRAG-01 (D-01/D-02) — the genuine-external-file-drag gate. `NSPasteboard(name: .drag)`
// is a persistent, system-wide named pasteboard whose content stays whatever was last written by
// ANY real OS-level drag anywhere on the system until a NEW drag session overwrites it -- so
// "genuine" requires BOTH a changeCount delta since the current gesture's own baseline (proving
// THIS gesture actually wrote it, not a stale leftover from an earlier unrelated drag or an
// ordinary click's incidental .leftMouseDragged wobble) AND non-empty file URLs (excluding
// non-file drags -- a Finder window move, a text/URL/image drag -- per D-01). Takes plain value
// types (`Int`, `[URL]`), not a live `NSPasteboard`, mirroring `isWithinDragAcceptRegion`'s
// `CGPoint`/`CGRect?` signature style so it stays directly unit-testable via `@testable import Islet`.
func isGenuineFileDrag(currentChangeCount: Int, gestureBaselineChangeCount: Int, urls: [URL]) -> Bool {
    currentChangeCount != gestureBaselineChangeCount && !urls.isEmpty
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
// `HStack(spacing: 16)` of 3 fixed-width (`NotchPillView.quickActionButtonWidth`) chips.
//
// Phase 44 UAT gap-closure (round 2) — this function's original bottom-anchored y (`card.minY +
// bottomInset`) only matched the SwiftUI-rendered row (which is anchored from the TOP via
// `.padding(.top, cameraClearance)`) by coincidence: the old 117pt-tall card happened to satisfy
// cameraClearance(42) + buttonRowHeight(59) + bottomInset(16) == 117, so a bottom-up formula and
// a top-down layout landed on the same pixels. Plan 44-01 grew the card to 189pt without touching
// that identity, so the ~72pt of new headroom went entirely into the GAP between the (still
// bottom-anchored) hit-test zone and the (still top-anchored) visual buttons — hover registered
// well below where the buttons actually rendered. Now anchored from `card.maxY` (the card's top
// edge, nearest the notch) via the SAME `NotchPillView.cameraClearance` constant the SwiftUI view
// pads by, so hit-test and render can never drift apart again regardless of card height.
// Horizontal layout mirrors quickActionButton's fixed `quickActionButtonWidth` (no longer flex-
// fill), centered in the card exactly as `.frame(alignment: .top)` centers the HStack in SwiftUI.
func computeQuickActionButtonFrames(card: CGRect) -> [CGRect] {
    let buttonRowHeight: CGFloat = 59   // icon 22 + gap 8 + label ~13 + vPadding 2x8
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
