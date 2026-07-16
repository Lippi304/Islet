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
//
// 28-04 round 4 (on-device UAT, user-confirmed scope expansion) — PRECEDENCE FIX: the
// original 28-03/28-04 `isExpanded` branch checked Now-Playing BEFORE `selectedView`, so once
// `nowPlaying != .none` (true even while merely PAUSED, not just actively playing) Calendar/
// Weather became permanently unreachable via the switcher -- "clicking Calendar shows
// nothing" / "navigation disappears during music". Explicit switcher selection (Calendar,
// Weather) is now checked BEFORE Now-Playing; Now-Playing only wins when `selectedView ==
// .home` -- the user-confirmed "smart Home" reversal of the earlier locked idle-default
// decision (28-CONTEXT.md D-01/D-02 addendum): Home shows Now-Playing when something is
// playing, and falls back to the idle glance otherwise.
//
// 28-04 round 5 (on-device UAT, user-reported UX gap) — Tray becomes its OWN resolver case
// (`.trayExpanded`), checked at the SAME priority tier as Calendar/Weather (before
// Now-Playing). This supersedes the earlier D-02 reconciliation (round 4 and prior), under
// which Tray had deliberately NO resolver case and instead force-revealed the additive shelf
// strip under whichever OTHER presentation was active (`ShelfViewState.forcedByTray`). Users
// wanted explicit Tray selection to show a DEDICATED, focused files-only view (mirroring
// Calendar/Weather), not "Home plus a shelf strip" -- see 28-CONTEXT.md's round-5 addendum.
// Phase 24's auto-reveal-on-drop (files appearing under Home/Calendar/Weather/NowPlaying when
// dropped there) is UNCHANGED -- it never depended on `forcedByTray`, only on
// `ShelfViewState.isVisible`'s `!items.isEmpty` half, so it coexists correctly with this fix.

// Phase 34 / TRAY-02 — the pending drop payload the Quick Action Destination Picker
// renders. Plain Foundation-only value type (mirrors DeviceActivity's "tests build it by
// hand" convention). Two things worth knowing before touching this:
// (1) D-03 — one batch, one decision: `items` holds EVERY file from a single multi-file
//     drop, never split across multiple pickers.
// (2) Pitfall 5 (34-RESEARCH.md) — this payload is fed IN by the controller on every
//     resolve() call, never stored inside IslandPresentation's own case as persistent
//     state — IslandPresentation is a fresh Equatable value with no memory across calls.
//     The CONTROLLER (Plan 02, NotchWindowController) is the one that persists this
//     across a Charging/Device transient interruption (D-05), mirroring TransientQueue's
//     own head/pending split where the controller (not the pure resolver) owns state
//     across time.
struct PendingDrop: Equatable {
    let items: [ShelfItem]
}

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
    case homeLastPlayed                                    // Phase 30 / HOME-02: Home, nothing playing now, but something played this session
    case homeEmpty                                         // Phase 30 / HOME-03: Home, nothing has played this session
    case calendarExpanded                                  // Phase 28 / CALVIEW-01: month grid + day list
    case weatherExpanded                                   // 28-04 round 4: current-conditions full view
    case trayExpanded                                      // 28-04 round 5: dedicated files-only Tray view
    case quickActionPicker(PendingDrop)                     // Phase 34 / TRAY-02: full-takeover destination picker
}

// The transient currently owning the island (the queue's head). Charging and device are
// the two transient kinds; now-playing is ambient, never a transient.
enum ActiveTransient: Equatable {
    case charging(ChargingActivity)
    case device(DeviceActivity)
}

// WR-01 fix (28-REVIEW.md) — the SINGLE shared definition of which IslandPresentation cases
// show the switcher row. Both NotchPillView (rendering) and NotchWindowController (panel/
// click-through geometry) used to maintain their own hand-duplicated copy of this exact case
// list, each with a comment noting it "mirrors" the other — nothing enforced that agreement, and
// CR-01/CR-02 in the same review demonstrated exactly this failure mode (a case added to one
// switch and forgotten in the other silently desyncs render vs. click-through geometry). Both
// call sites now reference this one function instead.
func showsSwitcherRow(for presentation: IslandPresentation) -> Bool {
    switch presentation {
    case .homeLastPlayed, .homeEmpty, .calendarExpanded, .weatherExpanded, .trayExpanded, .nowPlayingExpanded: return true
    default: return false
    }
}

// TOTAL pure reducer. The single ranking authority (D-05).
func resolve(activeTransient: ActiveTransient?,
             nowPlaying: NowPlayingPresentation,
             nowPlayingHealthy: Bool,
             hasPlayedSinceLaunch: Bool,
             isExpanded: Bool,
             selectedView: SelectedView = .home,
             onboardingStep: OnboardingStep? = nil,
             pendingDrop: PendingDrop? = nil) -> IslandPresentation {
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
        // Phase 34 / TRAY-02 (D-01, D-04) — a pending drop takes over the ENTIRE expanded
        // branch, checked before selectedView, full-takeover semantics: "replacing whatever
        // tab was showing... regardless of which tab was active" (34-UI-SPEC.md §1). A
        // standing Charging/Device transient still wins (the switch above already returned),
        // so this is inert while a transient owns the head -- D-05, the controller resumes
        // feeding pendingDrop back in once the transient clears.
        if let pendingDrop { return .quickActionPicker(pendingDrop) }
        // Phase 28 / CALVIEW-01, 28-04 round 4/5 — Calendar/Weather/Tray each get their own
        // resolver branch, checked BEFORE Now-Playing (round 4 precedence fix, see this file's
        // header comment) so an explicit switcher selection is never hijacked by media
        // playback. Tray joined this tier in round 5 (see header comment) -- it no longer
        // relies on ShelfViewState.forcedByTray to force-reveal a strip under another case.
        if selectedView == .calendar { return .calendarExpanded }
        if selectedView == .weather { return .weatherExpanded }
        if selectedView == .tray { return .trayExpanded }
        // Home (default) — the "smart Home" behavior (round 4, user-confirmed): Now-Playing
        // wins over the idle glance when present, exactly like before this fix; the only
        // change is that this branch is no longer reached for an explicit Calendar/Weather
        // selection.
        if !nowPlayingHealthy { return .nowPlayingExpanded(nowPlaying, healthy: false) } // D-12
        if nowPlaying != .none { return .nowPlayingExpanded(nowPlaying, healthy: true) }
        // Phase 30 / HOME-02/HOME-03 — Home's no-media sub-states, gated on whether ANYTHING
        // has played this session (replaces the old unconditional .expandedIdle fallback).
        if hasPlayedSinceLaunch { return .homeLastPlayed }
        return .homeEmpty
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
