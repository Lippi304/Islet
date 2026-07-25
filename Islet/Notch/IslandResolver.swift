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

// Phase 41 / HUD-08 (D-06) — the ambient calendar-countdown activity. Foundation-only, no
// `title` field at all: the event title is NEVER shown on the collapsed pill, so this pure
// layer's data path structurally cannot leak it (T-41-01).
struct CalendarCountdownActivity: Equatable {
    let eventStart: Date
}

// Phase 59 / SETTINGS-04/05 (SC5) — Resolver-Priority Reference Table
//
// Documents the CURRENT precedence tiers exactly as implemented today, plus a reserved,
// rank-TBD slot for each of the 8 new v1.10 activities Phases 60-67 will build. This is a
// comment-only reference — zero new IslandPresentation/ActiveTransient cases are added by
// this phase. Ranks stay named comments (not raw ints), matching the enum cases' own
// trailing-comment convention below — new v1.10 cases slot in between existing named
// ranks in their own phase, never renumbered here.
//
// Tier 0 — onboarding forced-flow: `.onboarding` never pre-empted by anything else.
//
// Tier 1 — ActiveTransient queue (collapsed pill), ranked:
//   charging > device > meeting (collapsed-only, persistent, Phase 63) > focus (collapsed-only)
//   > osd (collapsed-only) > downloadProgress (collapsed-only, sub-state-persistent) > capsLock
//   (collapsed-only, Phase 60) > updateAvailable (collapsed-only, Phase 60) > timer (Phase 62,
//   sub-state-persistent, has its own expanded content)
//
// Tier 2 — isExpanded branch, ranked:
//   pendingDrop (quickActionPicker) > selectedView (calendarExpanded/weatherExpanded/
//   trayExpanded) > nowPlayingExpanded > home fallback (homeLastPlayed/homeEmpty)
//
// Tier 3 — non-expanded ambient, ranked:
//   calendarCountdown (always wins) > launch-gated nowPlayingWings > idle
//
// Reserved slots for the 8 new v1.10 activities (best-guess placement per
// 59-RESEARCH.md's Open Question 1 — each flagged below, unconfirmed):
//   - Caps Lock (Phase 60)          — LANDED (60-01): ActiveTransient tier, rank 5, collapsed-only (D-07)
//   - Update-available (Phase 60)   — LANDED (60-01): ActiveTransient tier, rank 6, collapsed-only (D-07), NOT persistent
//   - Download Progress (Phase 61)  — LANDED (61-01): ActiveTransient tier, rank 5, collapsed-only, sub-state-persistent per D-01/D-02/D-03
//   - Timer/Pomodoro (Phase 62)     — LANDED (62-01): ActiveTransient tier, rank 8, sub-state-persistent (D-02/D-13-equivalent), first transient with its OWN dedicated expanded presentation (.timerExpanded)
//   - Meeting HUD (Phase 63)        — LANDED (63-03): ActiveTransient tier, rank 3, collapsed-only (D-10), persistent (D-06). Rode Phase 62's already-generalized preempt() with ZERO changes to it.
//   - Quick Notes (Phase 64)        — likely no IslandPresentation case at all (menu-bar-only UI, never touches the pill) — rank TBD — confirm in that activity's own phase discussion
//   - Quick Actions bar (Phase 65)  — relationship unclear, possibly an always-visible strip rather than a presentation case — rank TBD — confirm in that activity's own phase discussion
//   - Menübar Overflow (Phase 66)   — likely no IslandPresentation case (menu-bar-only UI) — rank TBD — confirm in that activity's own phase discussion
//   - Coding Progress (Phase 67)    — likely ambient tier, same shape as Calendar Countdown — rank TBD — confirm in that activity's own phase discussion

// What the island renders. The expanded media health (D-12) rides on the
// nowPlayingExpanded case's `healthy:` flag, kept orthogonal to the .none vs playing
// snapshot — see NowPlayingPresentation.swift's header for why D-11 ≠ D-12.
enum IslandPresentation: Equatable {
    case onboarding(OnboardingStep)                        // Phase 26 D-09: highest priority -- forced flow, never pre-empted
    case idle                                              // collapsed, nothing to show
    case charging(ChargingActivity)                        // D-02 rank 1 transient
    case device(DeviceActivity)                            // D-02 rank 2 transient
    case meeting(MeetingActivity)                          // Phase 63 / MEET-01/MEET-02: rank 3 transient, collapsed-only ALWAYS (D-10), persistent (D-06 -- a live call never self-elapses)
    case focus(FocusActivity)                              // Phase 38 / HUD-05: rank 4 transient, collapsed-only (D-07)
    case osd(OSDActivity)                                  // Phase 39 / HUD-03/HUD-04: rank 5 transient, collapsed-only (D-11), NOT persistent (self-elapses via D-10's own 1.5s timer, unlike Focus)
    case downloadProgress(DownloadActivity)                // Phase 61 / DL-01/DL-02: rank 6 transient, collapsed-only (D-03), sub-state-persistent (D-02/D-13 -- see isPersistent below)
    case capsLock(CapsLockActivity)                        // Phase 60 / CAPS-01: rank 7 transient, collapsed-only (D-07)
    case updateAvailable(UpdateActivity)                   // Phase 60 / UPDATE-01: rank 8 transient, collapsed-only (D-07), NOT persistent
    case timer(TimerActivity)                              // Phase 62 / TIMER-01..04: rank 9 transient, sub-state-persistent (SC5)
    case timerExpanded(TimerActivity)                      // Phase 62 / TIMER-01..04: dedicated expanded controls (Pattern 4) -- no fallthrough, unlike every other transient
    case nowPlayingWings(NowPlayingPresentation)           // D-02 rank 3 ambient (collapsed glance)
    case calendarCountdown(CalendarCountdownActivity)      // Phase 41 / HUD-08: ambient tier, D-01 always wins over nowPlayingWings
    case nowPlayingExpanded(NowPlayingPresentation, healthy: Bool) // D-12 expanded media / "nicht verfügbar"
    case homeLastPlayed                                    // Phase 30 / HOME-02: Home, nothing playing now, but something played this session
    case homeEmpty                                         // Phase 30 / HOME-03: Home, nothing has played this session
    case calendarExpanded                                  // Phase 28 / CALVIEW-01: month grid + day list
    case weatherExpanded                                   // 28-04 round 4: current-conditions full view
    case trayExpanded                                      // 28-04 round 5: dedicated files-only Tray view
    case timerSetup                                        // Phase 62-04 UAT revision (item 6): the Timer tab's idle duration/mode picker -- reachable only while no Timer transient is active (a running/paused Timer always wins via the activeTransient switch below)
    case quickActionPicker(PendingDrop)                     // Phase 34 / TRAY-02: full-takeover destination picker
}

// The transient currently owning the island (the queue's head). Charging and device are
// the two transient kinds; now-playing is ambient, never a transient.
enum ActiveTransient: Equatable {
    case charging(ChargingActivity)
    case device(DeviceActivity)
    case meeting(MeetingActivity)                          // Phase 63 / MEET-01/MEET-02: rank 3 transient, collapsed-only ALWAYS (D-10), persistent (D-06)
    case focus(FocusActivity)
    case osd(OSDActivity)                                  // Phase 39 / HUD-03/HUD-04: rank 5 transient, collapsed-only (D-11), NOT persistent (self-elapses via D-10's own 1.5s timer, unlike Focus)
    case downloadProgress(DownloadActivity)                // Phase 61 / DL-01/DL-02: rank 6 transient, collapsed-only (D-03), sub-state-persistent (D-02/D-13 -- see isPersistent below)
    case capsLock(CapsLockActivity)                        // Phase 60 / CAPS-01: rank 7 transient, collapsed-only (D-07)
    case updateAvailable(UpdateActivity)                   // Phase 60 / UPDATE-01: rank 8 transient, collapsed-only (D-07), NOT persistent
    case timer(TimerActivity)                              // Phase 62 / TIMER-01..04: rank 9 transient, sub-state-persistent (SC5)
}

// Phase 38 / HUD-05 (D-06) — the seam Plan 38-05's controller wiring reads to decide
// whether to arm the uniform 3s auto-dismiss timer. Focus never self-elapses (there is
// no natural "done" moment the way a charging/device splash settles after ~3s), so it
// stays standing until the underlying Focus state itself turns off; every other
// transient dismisses on the shared timer as before.
// .osd is deliberately excluded from isPersistent so it self-elapses (D-10's own 1.5s timer),
// unlike Focus.
extension ActiveTransient {
    var isPersistent: Bool {
        if case .focus = self { return true }
        // Phase 61 / DL-01/DL-02 (D-02/D-13): sub-state split — .inProgress never
        // self-elapses while a download is in flight; .done is NOT matched here, so it
        // falls through to `return false` and self-elapses via the shared ~3s timer.
        if case .downloadProgress(.inProgress) = self { return true }
        // Phase 62 / TIMER-01..04 (SC5): a running/paused Timer never self-elapses while it
        // is live, mirroring the DownloadProgress sub-state split above.
        if case .timer(let t) = self, t.isRunningOrPaused { return true }
        // Phase 63 / MEET-01 (D-06): a live meeting call never self-elapses — there is no
        // natural "done" moment the way a charging/device splash settles after ~3s; it stands
        // until MeetingMonitor reports the call actually ended. Same unconditional shape as
        // .focus above (no sub-state split — `isMuted` never affects persistence).
        if case .meeting = self { return true }
        return false
    }
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
    case .homeLastPlayed, .homeEmpty, .calendarExpanded, .weatherExpanded, .trayExpanded, .nowPlayingExpanded, .timerSetup: return true
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
             pendingDrop: PendingDrop? = nil,
             calendarCountdown: CalendarCountdownActivity? = nil) -> IslandPresentation {
    // Phase 26 D-09: forced flow -- a forced onboarding session is never pre-empted by any
    // transient or expanded state. Checked at the single arbiter, as the literal first
    // statement, rather than as a scattered guard duplicated across call sites (T-26-02).
    if let step = onboardingStep { return .onboarding(step) }
    switch activeTransient {                              // D-04: transient wins even over expanded
    case .charging(let a): return .charging(a)           // D-02 rank 1
    case .device(let d):   return .device(d)             // D-02 rank 2
    case .meeting(let m) where !isExpanded: return .meeting(m) // Phase 63 / MEET-01/MEET-02 rank 3, collapsed-only (D-10)
    case .meeting: break                                  // expanded -- falls through to the isExpanded branch below, unmodified. D-10 locks Meeting to collapsed-only ALWAYS: it deliberately gets NO dedicated expanded counterpart the way Timer has .timerExpanded, so this is the plain `break` arm every other collapsed-only transient uses.
    case .focus(let f) where !isExpanded: return .focus(f) // Phase 38 / HUD-05 rank 4, collapsed-only (D-07)
    case .focus: break                                    // expanded -- falls through to the isExpanded branch below, unmodified
    case .osd(let o) where !isExpanded: return .osd(o)    // Phase 39 / HUD-03/HUD-04 rank 5, collapsed-only (D-11)
    case .osd: break                                      // expanded -- falls through to the isExpanded branch below, unmodified
    case .downloadProgress(let d) where !isExpanded: return .downloadProgress(d) // Phase 61 / DL-01/DL-02 rank 6, collapsed-only (D-03)
    case .downloadProgress: break                         // expanded -- falls through to the isExpanded branch below, unmodified
    case .capsLock(let c) where !isExpanded: return .capsLock(c) // Phase 60 / CAPS-01 rank 7, collapsed-only (D-07)
    case .capsLock: break                                 // expanded -- falls through to the isExpanded branch below, unmodified
    case .updateAvailable(let u) where !isExpanded: return .updateAvailable(u) // Phase 60 / UPDATE-01 rank 8, collapsed-only (D-07)
    case .updateAvailable: break                          // expanded -- falls through to the isExpanded branch below, unmodified
    case .timer(let t) where !isExpanded: return .timer(t) // Phase 62 / TIMER-01..04 rank 9, collapsed pill
    case .timer(let t): return .timerExpanded(t)          // Pattern 4 -- dedicated expanded controls, NOT a fallthrough, unlike every other transient above
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
        // Phase 62-04 UAT design revision (item 6) — Timer joins the same tier as
        // Calendar/Weather/Tray. Only reached while NO Timer transient is active: the
        // activeTransient switch above already returned .timer/.timerExpanded first
        // whenever a session is running/paused (D-04, transient wins even over expanded).
        if selectedView == .timer { return .timerSetup }
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
    // Phase 41 / HUD-08 (D-01): a present countdown always wins over ambient now-playing wings
    // — checked FIRST in this branch, before nowPlayingLaunchGate, the ONLY place this
    // priority rule may be expressed (Pitfall 3: never a suppression flag in a monitor or the
    // view layer).
    if let countdown = calendarCountdown { return .calendarCountdown(countdown) }
    // Phase 17 / NOW-04 — D-01/D-03: the launch gate applies ONLY to this ambient branch; the
    // isExpanded branch above is untouched, so a manual expand always reveals the real state.
    let ambient = nowPlayingLaunchGate(hasPlayedSinceLaunch: hasPlayedSinceLaunch, nowPlaying: nowPlaying)
    if ambient != .none { return .nowPlayingWings(ambient) }   // D-02 ambient yield (rank 3)
    return .idle
}

// Phase 42 / DUAL-01 (D-01/D-02/D-03/D-04/D-10) — the secondary activity shown as a small
// bubble alongside the primary pill when two top-priority activities are live at once.
// Foundation-only, mirrors nowPlayingHealthGate/nowPlayingLaunchGate's "small pure helper"
// shape immediately below. Deliberately takes `primary` (resolve()'s own already-computed
// verdict) rather than re-deriving activeTransient/isExpanded itself — D-10 (a standing
// transient suppresses the secondary) and D-04 (isExpanded suppresses it) both fall out for
// free from primary's own shape (resolve() only ever returns .calendarCountdown from its
// ambient/collapsed, no-transient branch), per 42-RESEARCH.md Pitfall 1's warning against two
// independent computations of the same live facts drifting out of sync.
enum SecondaryActivity: Equatable {
    case nowPlaying(NowPlayingPresentation)
}

// Gap-closure fix (42-VERIFICATION.md gap #1, D-03) — the pairing rule expressed as a literal
// small ORDERED TABLE walked generically, not an if/else chain, per D-03's own wording. Scoped
// to exactly the 1 pairing that exists today (Countdown primary -> Now-Playing secondary,
// covering the 2 activity kinds D-03 names) — deliberately NOT a generic priority-resolution
// engine; a future 3rd ambient activity extends this array with one more row, no resolver
// surgery required (D-03's own "extend the table later" instruction).
private struct SecondaryPairing {
    let primaryMatches: (IslandPresentation) -> Bool
    let secondary: (NowPlayingPresentation) -> SecondaryActivity?
}

private let secondaryPairings: [SecondaryPairing] = [
    SecondaryPairing(
        primaryMatches: { if case .calendarCountdown = $0 { return true } else { return false } },
        secondary: { nowPlaying in nowPlaying != .none ? .nowPlaying(nowPlaying) : nil }
    )
]

func resolveSecondary(primary: IslandPresentation, nowPlaying: NowPlayingPresentation) -> SecondaryActivity? {
    guard let pairing = secondaryPairings.first(where: { $0.primaryMatches(primary) }) else { return nil }
    return pairing.secondary(nowPlaying)
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

    // Phase 38 / HUD-05 (D-08) — a Charging or Device transient must immediately preempt
    // an already-standing Focus head rather than queue behind it: since Focus never
    // self-elapses (isPersistent, D-06), queuing via plain enqueue(_:) would leave
    // Charging/Device waiting indefinitely behind a splash that never yields on its own.
    // Additive: does not modify enqueue(_:) itself. When the head is NOT Focus, behaves
    // exactly like enqueue(_:) (no special-casing needed). When it IS Focus, `t` takes
    // over the head immediately and the displaced Focus is reinserted at the FRONT of
    // `pending` (not appended to the back) so the very next advance() resumes it.
    // Phase 62 / TIMER-01..04 (SC5) — GENERALIZED beyond the original hardcoded `.focus`
    // check: any persistent head (Focus, standing Download-in-progress, or a running/paused
    // Timer) is now preempted, not just Focus. This closes a latent bug found during Phase
    // 62 research: a standing `.downloadProgress(.inProgress)` head is also `isPersistent`
    // (never self-elapses) but the old focus-only guard let a Charging/Device transient
    // queue behind it via plain enqueue(_:) instead of preempting immediately —
    // see `testPreemptNowGeneralizedForDownloadProgressHead` for the regression this closes.
    mutating func preempt(_ t: ActiveTransient) -> Bool {
        guard let currentHead = head, currentHead.isPersistent else { return enqueue(t) }
        head = t
        pending.insert(currentHead, at: 0)
        return true
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
        case (.osd, .osd): head = t   // Phase 39 D-09/D-12: same-activity scrub refresh AND Volume<->Brightness instant replace
        case (.downloadProgress, .downloadProgress): head = t   // Phase 61 D-02/D-13: transitions a never-self-elapsing .inProgress head directly to .done(filename:)
        case (.timer, .timer): head = t   // Phase 62 TIMER-01..04: in-place refresh (e.g. running -> paused) without re-arming the dismiss timer
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
