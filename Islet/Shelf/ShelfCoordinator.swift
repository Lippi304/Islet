import Foundation

// Phase 19 / SHELF-08 (D-05) — the thin class that owns ShelfFileStore's real
// FileManager delete side effect around ShelfLogic's pure remove/clear (mirrors
// DeviceCoordinator owning IOBluetooth/battery IO around TransientQueue's pure calls,
// per 19-PATTERNS.md's "Struct + mutating func, never a class" shared pattern note).
// This is what closes D-05/SHELF-08 fully within Phase 19 — a later phase's controller
// (Phase 20, out of scope here) only needs to call append/remove/clear on the
// ShelfCoordinator instance it owns (including from an eventual app-quit hook calling
// clear()), because the actual deletion mechanism is already correct and tested here,
// not a hook a later phase might forget to wire. Stays AppKit-free like
// ShelfItem/ShelfLogic/ShelfFileStore — this is a data/IO seam, not UI.
//
// ShelfCoordinator OWNS its ShelfLogic directly (no reach-back closures) — unlike
// DeviceCoordinator, which reaches into a TransientQueue owned elsewhere because
// multiple coordinators share one queue, there is no other owner of a ShelfLogic
// instance to share here.
@MainActor
final class ShelfCoordinator {
    private(set) var logic = ShelfLogic()

    // The caller already produced item.localURL via ShelfFileStore.makeSessionCopy
    // per D-03's contract before calling this, so the copy-in already happened
    // before an item exists. WR-01: when logic.append rejects a duplicate
    // (D-01/D-02), that just-made session-temp copy would otherwise never be
    // cleaned up by any other code path — delete it here so a rejected append
    // never orphans a file on disk (closes the gap in T-19-03's mitigation).
    @discardableResult
    func append(_ item: ShelfItem) -> Bool {
        let added = logic.append(item)
        if !added {
            ShelfFileStore.deleteSessionCopy(at: item.localURL)
        }
        return added
    }

    // D-05: the real deletion happens here, the instant an item actually leaves the
    // shelf; a non-existent id short-circuits on logic.remove returning nil before any
    // FileManager call is attempted.
    @discardableResult
    func remove(id: UUID) -> ShelfItem? {
        guard let removed = logic.remove(id: id) else { return nil }
        ShelfFileStore.deleteSessionCopy(at: removed.localURL)
        return removed
    }

    // D-05: covers delete-all AND is the exact same method a future app-quit hook
    // calls, so quit-time cleanup is correct by construction, not a separate code path
    // to get wrong later.
    @discardableResult
    func clear() -> [ShelfItem] {
        let removed = logic.clear()
        for item in removed {
            ShelfFileStore.deleteSessionCopy(at: item.localURL)
        }
        return removed
    }
}
