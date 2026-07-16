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

    // Phase 37 / HUD-07 (D-02/D-03) — a GROSS per-session drop counter, deliberately
    // distinct from `logic.items.count` (the current NET shelf size). Every successful
    // append increments it; remove()/clear() never decrement it — a later delete during
    // the same session must not make the drop-session summary chip under-report what the
    // user actually dropped. `resetSession()` below is the sole entry point that may zero
    // it, so the count only clears at the moment a caller (Plan 03's
    // `NotchWindowController`, at Tray-selected collapse) actually claims it.
    private(set) var sessionFilesSaved: Int = 0

    // The caller already produced item.localURL via ShelfFileStore.makeSessionCopy
    // per D-03's contract before calling this, so the copy-in already happened
    // before an item exists. WR-01: when logic.append rejects a duplicate
    // (D-01/D-02), that just-made session-temp copy would otherwise never be
    // cleaned up by any other code path — delete it here so a rejected append
    // never orphans a file on disk (closes the gap in T-19-03's mitigation).
    @discardableResult
    func append(_ item: ShelfItem) -> Bool {
        let added = logic.append(item)
        if added {
            sessionFilesSaved += 1
        } else {
            ShelfFileStore.deleteSessionCopy(at: item.localURL)
        }
        return added
    }

    // Phase 37 / HUD-07 (D-02/D-03) — the atomic read-and-zero contract: captures the
    // current gross count, resets it to 0, and returns the captured value in one call so
    // no caller can observe a torn state between "read" and "clear". This is the ONLY
    // method that may reset `sessionFilesSaved` — Plan 03's `NotchWindowController` calls
    // this exactly once, at Tray-selected collapse, to claim the count for the chip.
    @discardableResult
    func resetSession() -> Int {
        let claimed = sessionFilesSaved
        sessionFilesSaved = 0
        return claimed
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

    // Phase 21 follow-up (UAT feedback) — items whose backing file was deleted
    // externally (e.g. from Finder, outside the app) are otherwise stuck inert in
    // the shelf until manually trashed. Called on hover-enter so stale items are
    // gone before the user sees them, not just after a failed drag attempt.
    // Routes through remove(id:) so cleanup stays the single, tested code path.
    @discardableResult
    func pruneMissingFiles() -> [ShelfItem] {
        let missing = logic.items.filter { !FileManager.default.fileExists(atPath: $0.localURL.path) }
        for item in missing {
            remove(id: item.id)
        }
        return missing
    }
}
