import XCTest
@testable import Islet

// Phase 6 / COORD-01: the PURE priority resolver + transient queue seam (the single
// arbiter, D-05). Like PowerActivity, DeviceActivity, and NowPlayingPresentation,
// resolve(...) and TransientQueue are total, framework-free values importing ONLY
// Foundation — no AppKit, no SwiftUI, no Timer/clock — so the riskiest coordination
// logic (D-02 rank Charging > Device > Now Playing, D-04 transient-over-expanded then
// yield to the highest-priority ambient, D-03 bounded de-duped sequential queue) is
// verified deterministically by an automated agent in milliseconds (RED→GREEN).
//
// The controller wiring (Plan 04, Wave 2) feeds the live @Published activities through
// this seam; settings toggles are applied BEFORE the resolver, never inside it.
final class IslandResolverTests: XCTestCase {

    // MARK: resolve(...) — D-02 rank ordering + D-04 transient-over-expanded

    func testChargingOutranksDeviceAndMedia() {
        // D-02 rank 1 + D-04: a charging transient wins even with media playing AND the
        // island user-expanded — the highest-priority transient always shows.
        let r = resolve(activeTransient: .charging(.charging(percent: 47)),
                        nowPlaying: .playing(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true)
        XCTAssertEqual(r, .charging(.charging(percent: 47)))
    }

    func testDeviceOutranksAmbientMedia() {
        // D-02 rank 2: a device transient beats ambient now-playing wings (not expanded).
        let r = resolve(activeTransient: .device(.connected(name: "AirPods Pro", glyph: .airpodsPro, battery: nil)),
                        nowPlaying: .playing(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: false)
        XCTAssertEqual(r, .device(.connected(name: "AirPods Pro", glyph: .airpodsPro, battery: nil)))
    }

    // Phase 20 / SHELF-09 regression coverage: the shelf strip NotchPillView composes into
    // expandedIsland/mediaExpanded/mediaUnavailable (D-02) is structurally ABSENT during a
    // Charging or Device splash, with ZERO new production code in IslandResolver.swift — a
    // standing transient always outranks the isExpanded branches (D-04), so the shelf-composing
    // branches are simply never reached while a transient is active. Proves RESEARCH.md's
    // "falls out for free" claim.
    func testShelfComposingBranchesUnreachableDuringTransient() {
        let charging = resolve(activeTransient: .charging(.charging(percent: 50)),
                                nowPlaying: .playing(title: "Song", artist: "Artist"),
                                nowPlayingHealthy: true,
                                hasPlayedSinceLaunch: true,
                                isExpanded: true)
        XCTAssertEqual(charging, .charging(.charging(percent: 50)))

        let device = resolve(activeTransient: .device(.connected(name: "AirPods Pro", glyph: .airpodsPro, battery: nil)),
                              nowPlaying: .none,
                              nowPlayingHealthy: true,
                              hasPlayedSinceLaunch: true,
                              isExpanded: true)
        XCTAssertEqual(device, .device(.connected(name: "AirPods Pro", glyph: .airpodsPro, battery: nil)))
    }

    // Phase 26 / ONBOARD-01/T-26-02: D-09's hardest precedence case -- a forced onboarding
    // session outranks EVERY other input, even a standing Charging transient over an
    // expanded, healthy, actively-playing island. onboardingStep is checked as the literal
    // first statement of resolve(...), before `switch activeTransient` is even reached, so no
    // combination of the other four parameters can ever bypass it.
    func testOnboardingOutranksEverything() {
        let r = resolve(activeTransient: .charging(.charging(percent: 47)),
                        nowPlaying: .playing(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true,
                        onboardingStep: .permissions)
        XCTAssertEqual(r, .onboarding(.permissions))
    }

    func testNoTransientWhilePlayingReturnsToWings() {
        // D-02 ambient yield (rank 3): with no transient and media playing, the resolver
        // yields to the now-playing wings — NOT idle.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .playing(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: false)
        XCTAssertEqual(r, .nowPlayingWings(.playing(title: "Song", artist: "Artist")))
    }

    func testNoTransientNoMediaIsIdle() {
        // No transient, nothing playing, collapsed → the static idle pill.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: false)
        XCTAssertEqual(r, .idle)
    }

    // MARK: resolve(...) — D-12 expanded health axis

    func testUnhealthyExpandedShowsUnavailable() {
        // D-12: expanded with an UNHEALTHY now-playing API → the "nicht verfügbar"
        // expanded state, regardless of the (stale) snapshot.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: false,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true)
        XCTAssertEqual(r, .nowPlayingExpanded(.none, healthy: false))
    }

    // MARK: nowPlayingHealthGate(...) — Finding 5 gap-closure regression coverage

    func testNowPlayingHealthGateForcesNeutralWhenDisabled() {
        // Regression: a disabled Now Playing must be forced NEUTRAL (true) regardless of a stale
        // `false` left over from before the toggle — never silently degraded to "nicht verfügbar"
        // for a feature the user turned off.
        XCTAssertTrue(nowPlayingHealthGate(enabled: false, isHealthy: false))
        // Enabled must still pass the real flag through unchanged.
        XCTAssertFalse(nowPlayingHealthGate(enabled: true, isHealthy: false))
    }

    // MARK: nowPlayingLaunchGate(...) / hasPlayedSinceLaunch — Phase 17 NOW-04 regression coverage

    func testNowPlayingLaunchGateForcesNoneWhenNotYetPlayed() {
        // D-01: a track that hasn't actually played since launch must be forced to .none for
        // the ambient gate, regardless of its real (paused) presentation.
        XCTAssertEqual(nowPlayingLaunchGate(hasPlayedSinceLaunch: false,
                                            nowPlaying: .paused(title: "Song", artist: "Artist")),
                       .none)
        // Once lifted, the real presentation passes through unchanged.
        XCTAssertEqual(nowPlayingLaunchGate(hasPlayedSinceLaunch: true,
                                            nowPlaying: .paused(title: "Song", artist: "Artist")),
                       .paused(title: "Song", artist: "Artist"))
    }

    func testGatedPausedNotExpandedIsIdle() {
        // D-01: gated (never played this session) + paused + not expanded → idle, no ambient glance.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .paused(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: false,
                        isExpanded: false)
        XCTAssertEqual(r, .idle)
    }

    func testGatedPausedExpandedStillShowsRealState() {
        // D-03: gated but manually expanded → the expanded branch is untouched by the gate,
        // the real paused state (title/artist/controls) still shows.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .paused(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: false,
                        isExpanded: true)
        XCTAssertEqual(r, .nowPlayingExpanded(.paused(title: "Song", artist: "Artist"), healthy: true))
    }

    func testGateLiftedPausedNotExpandedShowsWings() {
        // D-02: once the gate has been lifted, ambient paused shows normally — no re-arm.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .paused(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: false)
        XCTAssertEqual(r, .nowPlayingWings(.paused(title: "Song", artist: "Artist")))
    }

    // MARK: songChangeToastGate(...) — Phase 18 NOW-05/NOW-06 coverage

    func testSongChangeToastGateSuppressedByChargingTransient() {
        // D-02: a charging transient suppresses the toast entirely, no queueing.
        XCTAssertFalse(songChangeToastGate(activeTransient: charging, isExpanded: false, toastEnabled: true))
    }

    func testSongChangeToastGateSuppressedByDeviceTransient() {
        // D-02: a device transient suppresses the toast too.
        XCTAssertFalse(songChangeToastGate(activeTransient: device, isExpanded: false, toastEnabled: true))
    }

    func testSongChangeToastGateSuppressedWhenExpanded() {
        // D-04: a manually-expanded island suppresses the toast (the expanded card already
        // shows the live title/artist).
        XCTAssertFalse(songChangeToastGate(activeTransient: nil, isExpanded: true, toastEnabled: true))
    }

    func testSongChangeToastGateSuppressedWhenToggleOff() {
        // NOW-06: the toggle being off suppresses new toasts.
        XCTAssertFalse(songChangeToastGate(activeTransient: nil, isExpanded: false, toastEnabled: false))
    }

    func testSongChangeToastGateAllowsAmbientEnabled() {
        // The only condition under which a toast may show: no transient, not expanded, toggle on.
        XCTAssertTrue(songChangeToastGate(activeTransient: nil, isExpanded: false, toastEnabled: true))
    }

    func testExpandedHealthyNoMediaHasPlayedShowsLastPlayed() {
        // Phase 30 / HOME-02: expanded, healthy API, nothing playing now but something played
        // this session → the last-played state.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true)
        XCTAssertEqual(r, .homeLastPlayed)
    }

    func testExpandedHealthyNoMediaNeverPlayedShowsEmpty() {
        // Phase 30 / HOME-03: expanded, healthy API, nothing has played this session → the
        // explicit empty state.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: false,
                        isExpanded: true)
        XCTAssertEqual(r, .homeEmpty)
    }

    func testExpandedHealthyPlayingShowsMediaControls() {
        // D-12: expanded, healthy API, media playing → the expanded media-controls view.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .playing(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true)
        XCTAssertEqual(r, .nowPlayingExpanded(.playing(title: "Song", artist: "Artist"), healthy: true))
    }

    // MARK: resolve(...) — Phase 28 / CALVIEW-01 selectedView precedence

    func testCalendarSelectedExpandedReturnsCalendarExpanded() {
        // No active transient, no now-playing, expanded + Calendar selected -> .calendarExpanded.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true,
                        selectedView: .calendar)
        XCTAssertEqual(r, .calendarExpanded)
    }

    func testCalendarSelectionOutranksMedia() {
        // 28-04 round 4 (precedence fix): an explicit Calendar selection now wins over
        // Now-Playing even while expanded -- the switcher must never be hijacked by media.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .playing(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true,
                        selectedView: .calendar)
        XCTAssertEqual(r, .calendarExpanded)
    }

    func testWeatherSelectionOutranksMedia() {
        // 28-04 round 4: same precedence fix, Weather side.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .playing(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true,
                        selectedView: .weather)
        XCTAssertEqual(r, .weatherExpanded)
    }

    func testWeatherSelectedExpandedReturnsWeatherExpanded() {
        // No active transient, no now-playing, expanded + Weather selected -> .weatherExpanded.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true,
                        selectedView: .weather)
        XCTAssertEqual(r, .weatherExpanded)
    }

    func testHomeSelectedWithMediaPlayingShowsNowPlayingExpanded() {
        // 28-04 round 4 "smart Home": explicit Home selection + media playing -> Now-Playing
        // still wins (unchanged behavior for Home specifically).
        let r = resolve(activeTransient: nil,
                        nowPlaying: .playing(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true,
                        selectedView: .home)
        XCTAssertEqual(r, .nowPlayingExpanded(.playing(title: "Song", artist: "Artist"), healthy: true))
    }

    func testHomeSelectedNoMediaHasPlayedShowsLastPlayed() {
        // Phase 30 / HOME-02: explicit Home selection + nothing playing now but something
        // played this session -> the last-played state.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true,
                        selectedView: .home)
        XCTAssertEqual(r, .homeLastPlayed)
    }

    func testHomeSelectedNoMediaNeverPlayedShowsEmpty() {
        // Phase 30 / HOME-03: explicit Home selection + nothing has played this session -> the
        // explicit empty state.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: false,
                        isExpanded: true,
                        selectedView: .home)
        XCTAssertEqual(r, .homeEmpty)
    }

    func testTransientOutranksCalendarSelection() {
        // D-04: a standing transient always outranks the calendar selection.
        let r = resolve(activeTransient: .charging(.charging(percent: 50)),
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true,
                        selectedView: .calendar)
        XCTAssertEqual(r, .charging(.charging(percent: 50)))
    }

    func testTraySelectedExpandedReturnsTrayExpanded() {
        // 28-04 round 5: Tray is now its OWN IslandPresentation case, at the same priority
        // tier as Calendar/Weather -- no active transient, no now-playing, expanded + Tray
        // selected -> .trayExpanded.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true,
                        selectedView: .tray)
        XCTAssertEqual(r, .trayExpanded)
    }

    func testTraySelectionOutranksMedia() {
        // 28-04 round 5: same precedence fix as Calendar/Weather -- an explicit Tray selection
        // wins over Now-Playing even while expanded.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .playing(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true,
                        selectedView: .tray)
        XCTAssertEqual(r, .trayExpanded)
    }

    func testTransientOutranksTraySelection() {
        // D-04: a standing transient always outranks the tray selection too.
        let r = resolve(activeTransient: .charging(.charging(percent: 50)),
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true,
                        selectedView: .tray)
        XCTAssertEqual(r, .charging(.charging(percent: 50)))
    }

    func testTraySelectedNotExpandedIsIdle() {
        // Collapsed island ignores selectedView entirely -> .idle.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: false,
                        selectedView: .tray)
        XCTAssertEqual(r, .idle)
    }

    func testCalendarSelectedNotExpandedIsIdle() {
        // Collapsed island ignores selectedView entirely -> .idle.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: false,
                        selectedView: .calendar)
        XCTAssertEqual(r, .idle)
    }

    func testOnboardingOutranksCalendarSelection() {
        // D-09: forced onboarding still outranks everything, including selectedView.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true,
                        selectedView: .calendar,
                        onboardingStep: .welcome)
        XCTAssertEqual(r, .onboarding(.welcome))
    }

    // MARK: resolve(...) — Phase 34 / TRAY-02 quickActionPicker precedence

    private let oneItemDrop = PendingDrop(items: [ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/tmp/a.txt"),
                                                             localURL: URL(fileURLWithPath: "/tmp/a.txt"),
                                                             filename: "a.txt", addedAt: Date())])

    func testPendingDropExpandedReturnsQuickActionPicker() {
        // TRAY-02: a pending drop takes over the picker even with no explicit tab selected
        // (selectedView left at default .home).
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true,
                        pendingDrop: oneItemDrop)
        XCTAssertEqual(r, .quickActionPicker(oneItemDrop))
    }

    func testPendingDropOutranksSelectedViewFullTakeover() {
        // D-01: full-takeover semantics -- an explicit Weather selection does NOT survive a
        // pending drop; the picker replaces whatever tab was showing regardless of which was
        // active.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true,
                        selectedView: .weather,
                        pendingDrop: oneItemDrop)
        XCTAssertEqual(r, .quickActionPicker(oneItemDrop))
    }

    func testChargingTransientOutranksPendingDrop() {
        // D-04: a standing transient always wins, even with a pending drop -- the EXISTING
        // transient-check-runs-first ordering, no new precedence code required (mirrors
        // testChargingOutranksDeviceAndMedia).
        let r = resolve(activeTransient: .charging(.charging(percent: 50)),
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true,
                        pendingDrop: oneItemDrop)
        XCTAssertEqual(r, .charging(.charging(percent: 50)))
    }

    func testPendingDropInertWhileNotExpanded() {
        // pendingDrop is inert while not expanded -- the controller only sets it once
        // auto-expand has already fired.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: false,
                        pendingDrop: oneItemDrop)
        XCTAssertEqual(r, .idle)
    }

    func testShowsSwitcherRowFalseForQuickActionPicker() {
        // UI-SPEC §1 (locked decision): the switcher never shows while the picker is
        // presented. Falls into the existing `default: return false` branch -- asserted
        // explicitly so a future refactor can't silently flip it.
        XCTAssertFalse(showsSwitcherRow(for: .quickActionPicker(oneItemDrop)))
    }

    // MARK: TransientQueue — D-03 bounded, de-duped, sequential coexistence

    private let charging = ActiveTransient.charging(.charging(percent: 50))
    private let device = ActiveTransient.device(.connected(name: "AirPods Pro", glyph: .airpodsPro, battery: nil))

    func testEnqueueIntoEmptyShowsImmediately() {
        // D-03: the first transient into an empty queue becomes the head and shows now.
        var q = TransientQueue()
        XCTAssertTrue(q.enqueue(charging))
        XCTAssertEqual(q.head, charging)
        XCTAssertEqual(q.pendingCount, 0)
    }

    func testEnqueueWhileShowingEnqueuesBehind() {
        // D-03: a second distinct transient while one is showing → enqueued behind
        // (returns false), the head is unchanged (no overlap).
        var q = TransientQueue()
        _ = q.enqueue(charging)
        XCTAssertFalse(q.enqueue(device))
        XCTAssertEqual(q.head, charging)
        XCTAssertEqual(q.pendingCount, 1)
    }

    func testQueueDedupsDuplicateHead() {
        // D-03 dedup: re-enqueuing the SAME transient as the head → no-op (false),
        // pending depth unchanged (never stacks the depth).
        var q = TransientQueue()
        _ = q.enqueue(charging)
        XCTAssertFalse(q.enqueue(charging))
        XCTAssertEqual(q.pendingCount, 0)
    }

    func testQueueDedupsAgainstPending() {
        // D-03 dedup: a transient already pending is not enqueued a second time.
        var q = TransientQueue()
        _ = q.enqueue(charging)        // head
        _ = q.enqueue(device)          // pending: [device]
        XCTAssertFalse(q.enqueue(device))
        XCTAssertEqual(q.pendingCount, 1)
    }

    func testAdvancePromotesPending() {
        // D-03 sequential: advance() promotes the next pending entry to head.
        var q = TransientQueue()
        _ = q.enqueue(charging)        // head = charging
        _ = q.enqueue(device)          // pending: [device]
        XCTAssertTrue(q.advance())
        XCTAssertEqual(q.head, device)
        XCTAssertEqual(q.pendingCount, 0)
    }

    func testAdvanceEmptyReturnsToAmbient() {
        // D-03: advancing with nothing pending clears the head → back to the ambient state.
        var q = TransientQueue()
        _ = q.enqueue(charging)
        XCTAssertTrue(q.advance())
        XCTAssertNil(q.head)
        XCTAssertEqual(q.pendingCount, 0)
    }

    // MARK: matchPendingBatteryPoll(...) — WR-1 gap-closure regression coverage

    func testMatchPendingBatteryPollFindsByIdentityNotFIFOPosition() {
        // WR-1: the match must be found by IDENTITY (the promoted device's DeviceActivity
        // payload), not by FIFO position — "B" is promoted while "A" is first in the list, so a
        // naive `.first` pop would wrongly return "A".
        let pollA = PendingBatteryPoll(address: "A",
                                        activity: .connected(name: "A", glyph: .generic, battery: nil))
        let pollB = PendingBatteryPoll(address: "B",
                                        activity: .connected(name: "B", glyph: .generic, battery: nil))
        let promoted = ActiveTransient.device(.connected(name: "B", glyph: .generic, battery: nil))
        let (match, remaining) = matchPendingBatteryPoll([pollA, pollB], promoted: promoted)
        XCTAssertEqual(match, pollB)
        XCTAssertEqual(remaining, [pollA])
    }

    func testMatchPendingBatteryPollNilPromotedReturnsUnchanged() {
        // No promoted transient at all → no match, pending list untouched.
        let pollA = PendingBatteryPoll(address: "A",
                                        activity: .connected(name: "A", glyph: .generic, battery: nil))
        let (match, remaining) = matchPendingBatteryPoll([pollA], promoted: nil)
        XCTAssertNil(match)
        XCTAssertEqual(remaining, [pollA])
    }

    func testMatchPendingBatteryPollChargingPromotedReturnsUnchanged() {
        // A charging transient promoted (not a device) → no match, pending list untouched.
        let pollA = PendingBatteryPoll(address: "A",
                                        activity: .connected(name: "A", glyph: .generic, battery: nil))
        let promoted = ActiveTransient.charging(.charging(percent: 50))
        let (match, remaining) = matchPendingBatteryPoll([pollA], promoted: promoted)
        XCTAssertNil(match)
        XCTAssertEqual(remaining, [pollA])
    }

    func testMatchPendingBatteryPollDisconnectedPromotedReturnsUnchanged() {
        // A .device(.disconnected) promotion never owes a battery poll → no match, unchanged.
        let pollA = PendingBatteryPoll(address: "A",
                                        activity: .connected(name: "A", glyph: .generic, battery: nil))
        let promoted = ActiveTransient.device(.disconnected(name: "A", glyph: .generic))
        let (match, remaining) = matchPendingBatteryPoll([pollA], promoted: promoted)
        XCTAssertNil(match)
        XCTAssertEqual(remaining, [pollA])
    }

    func testMatchPendingBatteryPollNoMatchingEntryReturnsUnchanged() {
        // Promoted device has no corresponding pending entry at all → no match, unchanged.
        let pollA = PendingBatteryPoll(address: "A",
                                        activity: .connected(name: "A", glyph: .generic, battery: nil))
        let promoted = ActiveTransient.device(.connected(name: "C", glyph: .generic, battery: nil))
        let (match, remaining) = matchPendingBatteryPoll([pollA], promoted: promoted)
        XCTAssertNil(match)
        XCTAssertEqual(remaining, [pollA])
    }

    // MARK: TransientQueue.removeAll(where:) — WR-2 head-unchanged invariant regression coverage

    func testRemoveAllLeavesUnrelatedHeadUnchanged() {
        // WR-2: when the predicate only matches entries in `pending` (never the head), `head` must
        // stay BYTE-FOR-BYTE unchanged — this is the invariant flushTransients' `oldHead` guard
        // depends on to skip an unnecessary dismiss-timer reset.
        var q = TransientQueue()
        _ = q.enqueue(device)          // head = device
        _ = q.enqueue(charging)        // pending: [charging]
        let oldHead = q.head
        q.removeAll(where: { if case .charging = $0 { return true }; return false })
        XCTAssertEqual(q.head, oldHead)   // unchanged — proves the WR-2 guard would read false (no re-arm)
        XCTAssertEqual(q.pendingCount, 0) // the pending charging entry WAS removed
    }

    func testRemoveAllMatchingHeadPromotesAndChangesHead() {
        // WR-2 counterpart: when the predicate DOES match the current head, `head` must change
        // (promote the next pending entry, or clear to nil) — proving the `oldHead` guard correctly
        // re-arms only when the head was actually touched.
        var q = TransientQueue()
        _ = q.enqueue(charging)        // head = charging
        _ = q.enqueue(device)          // pending: [device]
        let oldHead = q.head
        q.removeAll(where: { if case .charging = $0 { return true }; return false })
        XCTAssertNotEqual(q.head, oldHead)   // changed — promoted "device"
        XCTAssertEqual(q.head, device)
        XCTAssertEqual(q.pendingCount, 0)
    }

    func testQueueBoundedDropsOldestPending() {
        // D-03 bound (T-06-01): enqueuing 4 distinct transients after the head caps pending
        // at maxDepth (2), dropping the OLDEST pending; the head is never dropped.
        var q = TransientQueue()
        let a = ActiveTransient.charging(.charging(percent: 10))
        let b = ActiveTransient.charging(.charging(percent: 20))
        let c = ActiveTransient.charging(.charging(percent: 30))
        let d = ActiveTransient.charging(.charging(percent: 40))
        let e = ActiveTransient.charging(.charging(percent: 50))
        XCTAssertTrue(q.enqueue(a))     // head = a
        XCTAssertFalse(q.enqueue(b))    // pending: [b]
        XCTAssertFalse(q.enqueue(c))    // pending: [b, c]
        XCTAssertFalse(q.enqueue(d))    // pending: [c, d]  (b dropped — oldest)
        XCTAssertFalse(q.enqueue(e))    // pending: [d, e]  (c dropped — oldest)
        XCTAssertEqual(q.head, a)       // head never dropped
        XCTAssertEqual(q.pendingCount, 2)
        // The oldest survivors advance in FIFO order: d then e.
        _ = q.advance(); XCTAssertEqual(q.head, d)
        _ = q.advance(); XCTAssertEqual(q.head, e)
    }

    // MARK: Phase 38 / HUD-05 — Focus transient (collapsed-only, persistent, preemptible)

    func testFocusWinsWhenCollapsed() {
        // D-07: a Focus transient wins when the island is NOT expanded.
        let r = resolve(activeTransient: .focus(.on),
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: false)
        XCTAssertEqual(r, .focus(.on))
    }

    func testFocusFallsThroughWhenExpanded() {
        // D-07: a Focus transient does NOT win when the island IS expanded — it falls
        // through to whatever Home/Tray/Calendar/Weather would resolve to as if no
        // transient were active. Proven identical to what resolve(activeTransient: nil, ...)
        // would return with the same other arguments (homeEmpty here: nothing playing,
        // nothing played this session, Home selected).
        let r = resolve(activeTransient: .focus(.on),
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: false,
                        isExpanded: true,
                        selectedView: .home)
        XCTAssertEqual(r, .homeEmpty)
    }

    func testActiveTransientIsPersistentFlags() {
        // D-06: ActiveTransient.focus is marked persistent while every other case is not —
        // the seam the controller uses to skip the uniform 3s auto-dismiss.
        XCTAssertFalse(ActiveTransient.charging(.charging(percent: 50)).isPersistent)
        XCTAssertFalse(ActiveTransient.device(.connected(name: "AirPods Pro", glyph: .airpodsPro, battery: nil)).isPersistent)
        XCTAssertTrue(ActiveTransient.focus(.on).isPersistent)
    }

    func testPreemptPushesFocusToFrontOfPending() {
        // D-08: a Charging or Device transient immediately preempts an already-standing
        // Focus head instead of queuing behind it — the displaced Focus is pushed to the
        // FRONT of pending (not the back), so advance() promotes it right back once the
        // preempting transient elapses.
        var q = TransientQueue()
        _ = q.enqueue(.focus(.on))
        XCTAssertTrue(q.preempt(.charging(.charging(percent: 50))))
        XCTAssertEqual(q.head, .charging(.charging(percent: 50)))
        XCTAssertTrue(q.advance())
        XCTAssertEqual(q.head, .focus(.on))
    }
}
