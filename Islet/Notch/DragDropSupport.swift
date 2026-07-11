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
