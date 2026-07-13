import Foundation

// Phase 20 / SHELF-03 — the SEPARATE @Published view-layer mirror of ShelfCoordinator.logic.items,
// mirroring NowPlayingState's ownership contract exactly: a plain published holder, no methods, no
// timers. Plan 20-02's NotchWindowController owns the real ShelfCoordinator and is the ONLY writer —
// it sets `.items` directly after every ShelfCoordinator mutation (append/remove/clear).
final class ShelfViewState: ObservableObject {
    @Published var items: [ShelfItem] = []

    // Phase 28 / CALVIEW-04, Pitfall 3 (CR-01 click-through regression class) — `isVisible` is
    // the ONE source of truth every shelf-visibility check must read (blobShape, the body's
    // outer .frame, and NotchWindowController's visibleContentZone()) — never patch one call
    // site with an inline check while leaving siblings on a different one (see project memory
    // cr01-clickthrough-or-defeat-gotcha).
    // 28-04 round 5 — `forcedByTray` (28-03/28-04's "select Tray -> force-reveal the additive
    // shelf strip under Home" reconciliation) is removed: Tray is now its OWN
    // `IslandPresentation` case (`.trayExpanded`, IslandResolver.swift), rendered as a
    // dedicated files-only view, so no OTHER presentation's additive shelf strip ever needs
    // force-revealing on Tray selection anymore. Phase 24's auto-reveal-on-drop (the reason
    // this type exists at all) is unaffected — it only ever depended on `!items.isEmpty`.
    var isVisible: Bool { !items.isEmpty }
}

// Phase 20 / SHELF-04 / D-04 — the missing-file-click gate as an explicit, testable pure seam,
// mirroring songChangeToastGate/nowPlayingHealthGate in Islet/Notch/IslandResolver.swift. Plan
// 20-02's NotchWindowController.handleShelfItemTap calls this before NSWorkspace.shared.open.
func shouldOpenShelfItem(fileExists: Bool) -> Bool { fileExists }

// Phase 21 / SHELF-06 / D-02 — the missing-file-drag gate, identical shape to
// shouldOpenShelfItem. ShelfItemView's .onDrag closure calls this before constructing
// NSItemProvider(contentsOf:); a vanished backing file is a silent no-op drag.
func shouldBeginShelfItemDrag(fileExists: Bool) -> Bool { fileExists }
