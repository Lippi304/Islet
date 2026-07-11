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
    case onboarding(OnboardingStep)                        // Phase 26 D-09: highest priority -- forced flow, never pre-empted
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
             hasPlayedSinceLaunch: Bool,
             isExpanded: Bool,
             onboardingStep: OnboardingStep? = nil) -> IslandPresentation {
    // Phase 26 D-09: forced flow -- a forced onboarding session is never pre-empted by any
    // transient or expanded state. Checked at the single arbiter, as the literal first
    // statement, rather than as a scattered guard duplicated across call sites (T-26-02).
    if let step = onboardingStep { return .onboarding(step) }
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
    // Phase 17 / NOW-04 — D-01/D-03: the launch gate applies ONLY to this ambient branch; the
    // isExpanded branch above is untouched, so a manual expand always reveals the real state.
    let ambient = nowPlayingLaunchGate(hasPlayedSinceLaunch: hasPlayedSinceLaunch, nowPlaying: nowPlaying)
    if ambient != .none { return .nowPlayingWings(ambient) }   // D-02 ambient yield (rank 3)
    return .idle
}

// Gap-closure fix (Finding 5) — TOTAL pure helper: a disabled Now Playing must be INVISIBLE to
// the resolver, not silently degraded to "nicht verfügbar" (D-12) for a feature the user turned
// off. When disabled, forces a neutral/healthy `true` regardless of the (possibly stale) real
// flag; when enabled, passes the real flag through unchanged.
func nowPlayingHealthGate(enabled: Bool, isHealthy: Bool) -> Bool {
    enabled ? isHealthy : true
}

// Phase 17 / NOW-04 — D-01/D-02: a track that hasn't actually played (isPlaying == true) since
// Islet launched must not auto-show the ambient wings glance. TOTAL pure helper mirroring
// nowPlayingHealthGate's shape: when the gate hasn't been lifted yet, force .none for the
// AMBIENT (non-expanded) presentation only; the raw presentation passes through unchanged once
// hasPlayed is true. Never applied to the expanded branch (D-03) — resolve(...) only calls this
// from its non-expanded path.
func nowPlayingLaunchGate(hasPlayedSinceLaunch: Bool, nowPlaying: NowPlayingPresentation) -> NowPlayingPresentation {
    hasPlayedSinceLaunch ? nowPlaying : .none
}

// Phase 18 / NOW-05/NOW-06 (D-02/D-04) — the song-change toast's suppression gate. TOTAL
// pure standalone function, deliberately NOT threaded through resolve(...) or
// IslandPresentation — the toast is a separate @Published field the controller (Plan 02)
// sets only when this gate returns true, so D-02's "skipped entirely, not queued, not shown
// afterward" falls out for free (no ActiveTransient/TransientQueue participation at all, per
// this file's own TransientQueue doc comment on FIFO/dedup semantics being the wrong shape
// for this requirement). This deliberately diverges from 18-RESEARCH.md's Architectural
// Responsibility Map (which assigns toast suppression to resolve(...)) and its Anti-Pattern
// warning against splitting ranking logic between controller and resolver — permitted by
// CONTEXT.md's discretion note, safe because this gate's two inputs are read from the exact
// same live state resolve(...) itself consumes (transientQueue.head, interaction.isExpanded),
// so the two can never disagree; see 18-01-PLAN.md's <objective> "Deviation from
// RESEARCH.md" section for the full rationale.
func songChangeToastGate(activeTransient: ActiveTransient?, isExpanded: Bool, toastEnabled: Bool) -> Bool {
    activeTransient == nil && !isExpanded && toastEnabled
}

// Gap-closure fix (WR-1) — the address-keyed side data for a device's post-connect battery
// poll. Controller-owned "address-keyed side table, pure enum stays address-free" discipline
// (mirrors NotchWindowController's own `deviceLastShown: [String: TimeInterval]` convention):
// `activity` carries the SAME DeviceActivity payload that was enqueued into TransientQueue for
// this device, so matchPendingBatteryPoll can find the right entry by IDENTITY, not by FIFO
// position (see below).
struct PendingBatteryPoll: Equatable {
    let address: String
    let activity: DeviceActivity
}

// Gap-closure fix (WR-1) — TOTAL pure helper: triggerDeviceBatteryRefreshIfPromoted() must match
// the ACTUALLY-promoted device's identity (its DeviceActivity payload), not trust FIFO position.
// The old address-only FIFO's `.first` pop could desync from TransientQueue's own pending
// list — a disconnect transient for a DIFFERENT device can evict the queue's corresponding pending
// entry via maxDepth without ever touching the FIFO (disconnects are never appended to it), so the
// FIFO head could point at the wrong device once one was promoted. Matching by `.activity ==`
// instead of position closes that gap: only a `.device(.connected)` promotion can ever consume an
// entry, and only the entry whose payload the promoted head equals.
func matchPendingBatteryPoll(_ pending: [PendingBatteryPoll],
                              promoted: ActiveTransient?) -> (match: PendingBatteryPoll?, remaining: [PendingBatteryPoll]) {
    guard case .device(let activity)? = promoted, case .connected = activity else {
        return (nil, pending)
    }
    guard let index = pending.firstIndex(where: { $0.activity == activity }) else {
        return (nil, pending)
    }
    var remaining = pending
    let match = remaining.remove(at: index)
    return (match, remaining)
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
