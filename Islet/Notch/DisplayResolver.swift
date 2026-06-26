import CoreGraphics

// ISL-06 — pure display selection.
//
// A live-NSScreen-free snapshot of one display. The AppKit-facing wiring in
// Plan 02 builds these from real NSScreen objects; tests build them by hand.
struct ScreenDescriptor: Equatable {
    let uuid: String?
    let frame: CGRect
    let safeAreaTop: CGFloat
    let auxLeftWidth: CGFloat?
    let auxRightWidth: CGFloat?
    let isBuiltin: Bool
}

extension ScreenDescriptor {
    // Reuses the pure has-notch rule from NotchGeometry. The fully-labeled call
    // `hasNotch(safeAreaTop:auxLeftWidth:auxRightWidth:)` unambiguously resolves to
    // the free function (this property takes no arguments), so there is no shadowing.
    var hasNotch: Bool {
        Islet.hasNotch(safeAreaTop: safeAreaTop,
                       auxLeftWidth: auxLeftWidth,
                       auxRightWidth: auxRightWidth)
    }
}

// The Phase-1 target is the ONE built-in, notched display — or nil.
// CRITICAL: select by PROPERTY (isBuiltin && hasNotch), never by array index or
// size — indices reorder on plug/unplug and would land on the wrong display
// (Pitfall 2). nil means clamshell / external-only / non-notch Mac → the panel hides.
//
// FORWARD NOTE (CONTEXT.md Deferred Idea): this is intentionally single-built-in
// for v1 — do NOT build external-monitor support here. But because it takes a
// descriptor LIST as input, a future "also show on an external monitor" policy is a
// non-breaking extension (change the filter / return type, not the call signature),
// so a later phase can EXTEND this seam rather than refactor it. No Phase-1 behavior
// change — recorded intent only.
func selectTargetScreen(from screens: [ScreenDescriptor]) -> ScreenDescriptor? {
    screens.first { $0.isBuiltin && $0.hasNotch }
}
