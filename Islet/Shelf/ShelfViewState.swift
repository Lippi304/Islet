import Foundation

// Phase 20 / SHELF-03 — the SEPARATE @Published view-layer mirror of ShelfCoordinator.logic.items,
// mirroring NowPlayingState's ownership contract exactly: a plain published holder, no methods, no
// timers. Plan 20-02's NotchWindowController owns the real ShelfCoordinator and is the ONLY writer —
// it sets `.items` directly after every ShelfCoordinator mutation (append/remove/clear).
final class ShelfViewState: ObservableObject {
    @Published var items: [ShelfItem] = []
}

// Phase 20 / SHELF-04 / D-04 — the missing-file-click gate as an explicit, testable pure seam,
// mirroring songChangeToastGate/nowPlayingHealthGate in Islet/Notch/IslandResolver.swift. Plan
// 20-02's NotchWindowController.handleShelfItemTap calls this before NSWorkspace.shared.open.
func shouldOpenShelfItem(fileExists: Bool) -> Bool { fileExists }

// Phase 21 / SHELF-06 / D-02 — the missing-file-drag gate, identical shape to
// shouldOpenShelfItem. ShelfItemView's .onDrag closure calls this before constructing
// NSItemProvider(contentsOf:); a vanished backing file is a silent no-op drag.
func shouldBeginShelfItemDrag(fileExists: Bool) -> Bool { fileExists }
