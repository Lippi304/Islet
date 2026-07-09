import Foundation

// Phase 19 / SHELF-08 — the PURE shelf item value. Like DeviceReading and
// PowerActivity, this is a plain Foundation-only struct — no AppKit, no
// Cocoa file APIs — so ShelfLogic's append/remove/dedupe rules are
// unit-tested in milliseconds. Plan 19-01 Task 2 (ShelfFileStore) provides
// the real FileManager copy/delete mechanics around this passive value;
// this file only defines its shape.
struct ShelfItem: Equatable {
    let id: UUID
    let originalURL: URL   // D-04: shelf never writes/moves/deletes this — read-only source
    var localURL: URL      // D-03: populated immediately on add (session-temp copy)
    let filename: String
    let addedAt: Date
}
