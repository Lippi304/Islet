import Foundation

// Phase 64 (NOTES-03, D-14/D-17) — pure reducer mirroring
// Islet/Clipboard/ClipboardStore.swift's cap+FIFO-eviction discipline, minus the
// dedupe branch (append is a plain append per CONTEXT.md's discretion note), plus
// a new remove(id:) for per-row delete (D-17 — no analog in ClipboardStore).
struct QuickNotesStore: Equatable {
    private(set) var items: [QuickNote] = []
    let cap = 30   // D-14: matches ClipboardStore.cap exactly

    mutating func append(_ note: QuickNote) {
        items.append(note)
        if items.count > cap { items.removeFirst() }   // D-14: FIFO evict oldest past cap
    }

    // D-17: deletes only the matching entry, safe no-op if id isn't present.
    // No "Delete All" — deliberately not provided.
    mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    // Plan 64-08 (additional scope, user-approved) — bulk prune for vault-file
    // reconciliation on popover open: keeps only the ids AppDelegate determined are
    // still present in their own vault file, mirrors remove(id:)'s shape for a set.
    mutating func prune(keepingIDs idsToKeep: Set<UUID>) {
        items.removeAll { !idsToKeep.contains($0.id) }
    }
}
