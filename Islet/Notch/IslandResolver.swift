import Foundation

// Phase 6 / COORD-01 — the PURE priority resolver: the SINGLE arbiter (D-05) that
// replaces the scattered per-pair if-ordering. Like PowerActivity, DeviceActivity, and
// NowPlayingPresentation, this imports ONLY Foundation — no AppKit, no SwiftUI, no
// IOBluetooth, no Timer/clock — so the ranking + queue logic is unit-tested in
// milliseconds. Plan 04 (Wave 2) feeds the live @Published activities through here;
// settings toggles are applied BEFORE the resolver, never inside it.
//
// D-02: rank Charging > Device > Now Playing. D-04: a transient briefly wins even over a
// user-expanded island, then yields to the highest-priority ambient state. D-12: the
// expanded view branches on the orthogonal now-playing health axis (healthy vs blocked).

// What the island renders. The expanded media health (D-12) rides on the
// nowPlayingExpanded case's `healthy:` flag, kept orthogonal to the .none vs playing
// snapshot — see NowPlayingPresentation.swift's header for why D-11 ≠ D-12.
enum IslandPresentation: Equatable {
    case idle                                              // collapsed, nothing to show
    case charging(ChargingActivity)                        // D-02 rank 1 transient
    case device(DeviceActivity)                            // D-02 rank 2 transient
    case nowPlayingWings(NowPlayingPresentation)           // D-02 rank 3 ambient (collapsed glance)
    case nowPlayingExpanded(NowPlayingPresentation, healthy: Bool) // D-12 expanded media / "nicht verfügbar"
    case expandedIdle                                      // expanded, healthy, nothing playing (date/time)
}

// The transient currently owning the island (the queue's head). Charging and device are
// the two transient kinds; now-playing is ambient, never a transient.
enum ActiveTransient: Equatable {
    case charging(ChargingActivity)
    case device(DeviceActivity)
}

// TOTAL pure reducer. The single ranking authority (D-05).
func resolve(activeTransient: ActiveTransient?,
             nowPlaying: NowPlayingPresentation,
             nowPlayingHealthy: Bool,
             isExpanded: Bool) -> IslandPresentation {
    switch activeTransient {                              // D-04: transient wins even over expanded
    case .charging(let a): return .charging(a)           // D-02 rank 1
    case .device(let d):   return .device(d)             // D-02 rank 2
    case nil: break
    }
    if isExpanded {
        if !nowPlayingHealthy { return .nowPlayingExpanded(nowPlaying, healthy: false) } // D-12
        if nowPlaying != .none { return .nowPlayingExpanded(nowPlaying, healthy: true) }
        return .expandedIdle
    }
    if nowPlaying != .none { return .nowPlayingWings(nowPlaying) }   // D-02 ambient yield (rank 3)
    return .idle
}

// D-03 — the bounded, de-duped, SEQUENTIAL transient queue. When two transients collide
// (e.g. plug in the charger while AirPods connect), the first shows, then the second —
// they never overlap. Pure value: `advance()` is called by the controller (Plan 04) when
// the current splash's ~3s elapses; there is NO Timer/clock inside (Pitfall: no-polling,
// keeps the queue deterministically testable). The depth is bounded and duplicates are
// dropped so a flapping device can never back the queue up (T-06-01).
struct TransientQueue {
    private(set) var head: ActiveTransient?
    private var pending: [ActiveTransient] = []
    let maxDepth = 2

    // Read-only depth accessor so tests assert the bound/dedup without exposing `pending`.
    var pendingCount: Int { pending.count }

    // Returns true iff `t` becomes the head NOW (show immediately); false if it was
    // enqueued behind the current head, de-duped, or dropped on overflow.
    mutating func enqueue(_ t: ActiveTransient) -> Bool {
        if head == nil { head = t; return true }
        if head == t || pending.contains(t) { return false }   // D-03 dedup (head + pending)
        pending.append(t)
        if pending.count > maxDepth { pending.removeFirst() }   // D-03 bound (drop oldest pending)
        return false
    }

    // Promote the next pending transient to head; if none, clear head (back to ambient).
    // Returns true always (a state change occurred). Called when the current splash elapses.
    mutating func advance() -> Bool {
        guard !pending.isEmpty else { head = nil; return true } // back to ambient
        head = pending.removeFirst()
        return true
    }

    // In-place refresh of the standing head WITHOUT re-arming the dismiss or touching `pending`.
    // Used for a charging % tick (Pitfall 4): the splash already stands and its ~3s timer keeps
    // running; only the displayed value changes. No-op unless the new transient is the SAME
    // category as the current head (a different category must go through enqueue, not replace
    // the head out from under its running timer). The bounded/de-duped pending list is untouched.
    mutating func updateHead(_ t: ActiveTransient) {
        guard let h = head else { return }
        switch (h, t) {
        case (.charging, .charging): head = t
        case (.device, .device):     head = t
        default: break   // different category — ignore (use enqueue)
        }
    }

    // Remove EVERY transient matching `predicate` from both the head and the pending list. Used
    // when an activity is toggled off live (Phase 6 D-09 / Pitfall 3): the disabled category's
    // standing splash AND any queued copy must vanish at once. If the head matched, the next
    // surviving pending entry (if any) is promoted; otherwise the head clears (back to ambient).
    // The pending list keeps its order minus the matches.
    mutating func removeAll(where predicate: (ActiveTransient) -> Bool) {
        pending.removeAll(where: predicate)
        if let h = head, predicate(h) {
            head = pending.isEmpty ? nil : pending.removeFirst()
        }
    }
}
