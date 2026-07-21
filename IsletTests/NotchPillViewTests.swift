import XCTest
@testable import Islet

// TRAY-01 / Phase 31: shelfStripVisible is the single shared gate that keeps the additive
// shelf-strip reveal OFF everywhere except the dedicated Tray view (which renders the shelf
// directly via its own shelfRow(_:) path, unaffected by this gate). Locks the shipped
// behavior from quick task 260714-3k6 so it can't silently regress.
//
// @MainActor: NotchPillView's constructor args (e.g. BasicOutfitState) are @MainActor-isolated
// initializers — matches the same pattern in ShelfViewStateTests/ShelfCoordinatorTests.
@MainActor
final class NotchPillViewTests: XCTestCase {

    func testShelfStripVisibleIsAlwaysFalse() {
        let state = NotchInteractionState()
        state.phase = .collapsed
        let shelf = ShelfViewState()
        // Non-empty shelf: ShelfViewState.isVisible (!items.isEmpty) would be true here, so
        // this is the one case that can actually distinguish "shelfStripVisible is a hard-coded
        // false" from "false only because the shelf happens to be empty" — an empty shelf can't
        // catch a regression back to `shelfViewState.isVisible`.
        shelf.items = [ShelfItem(id: UUID(),
                                  originalURL: URL(fileURLWithPath: "/tmp/a.txt"),
                                  localURL: URL(fileURLWithPath: "/tmp/a.txt"),
                                  filename: "a.txt",
                                  addedAt: Date())]
        let view = NotchPillView(interaction: state,
                                  nowPlaying: NowPlayingState(),
                                  presentationState: IslandPresentationState(.idle),
                                  outfit: BasicOutfitState(),
                                  shelfViewState: shelf,
                                  onboardingState: OnboardingViewState(),
                                  viewSwitcherState: ViewSwitcherState(),
                                  calendarViewState: CalendarViewState())
        XCTAssertTrue(shelf.isVisible, "test setup sanity check — shelf must be non-empty")
        // TRAY-01: the shelf strip never reveals under Home/Calendar/Weather/Now-Playing —
        // only trayFullView renders shelf content, via its own separate shelfVisible: false path.
        XCTAssertFalse(view.shelfStripVisible,
                        "shelfStripVisible must stay false even with a non-empty shelf — the additive shelf-strip reveal is Tray-only (TRAY-01).")
    }

    // Phase 45 / SWITCH-01/SWITCH-02 — regression lock: tabWidth/tabHeight must reproduce
    // today's exact per-case width/height mapping (the 6 former per-case blobShape call
    // sites' own arguments) across all 7 switcher-row presentation states, so Task 2's
    // consolidation into one tabContentView call site cannot silently drift the geometry.
    func testTabWidthHeightMatchesKnownPerCaseValues() {
        func makeView(_ presentation: IslandPresentation) -> NotchPillView {
            let state = NotchInteractionState()
            state.phase = .expanded
            return NotchPillView(interaction: state,
                                  nowPlaying: NowPlayingState(),
                                  presentationState: IslandPresentationState(presentation),
                                  outfit: BasicOutfitState(),
                                  shelfViewState: ShelfViewState(),
                                  onboardingState: OnboardingViewState(),
                                  viewSwitcherState: ViewSwitcherState(),
                                  calendarViewState: CalendarViewState())
        }

        // Home / NowPlaying group — 420 x 170
        for presentation: IslandPresentation in [
            .homeEmpty,
            .homeLastPlayed,
            .nowPlayingExpanded(.playing(title: "t", artist: "a"), healthy: true),
            .nowPlayingExpanded(.none, healthy: false),
        ] {
            let view = makeView(presentation)
            XCTAssertEqual(view.tabWidth, 420, "\(presentation)")
            XCTAssertEqual(view.tabHeight, 170, "\(presentation)")
        }

        // Calendar — 472 x 220
        let calendarView = makeView(.calendarExpanded)
        XCTAssertEqual(calendarView.tabWidth, 472)
        XCTAssertEqual(calendarView.tabHeight, 220)

        // Tray — 650 x 117
        let trayView = makeView(.trayExpanded)
        XCTAssertEqual(trayView.tabWidth, 650)
        XCTAssertEqual(trayView.tabHeight, 117)

        // Weather — 420 x (290 medium / 410 large), both branches locked explicitly via
        // UserDefaults.standard (no store: override at NotchPillView.swift:100, per this
        // project's established @AppStorage-test-isolation precedent) so this test never
        // depends on whatever weatherStyle happens to be persisted on the machine running it.
        let defaults = UserDefaults.standard
        let key = ActivitySettings.weatherStyleKey
        let originalValue = defaults.string(forKey: key)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(ActivitySettings.WeatherStyle.medium.rawValue, forKey: key)
        let weatherMediumView = makeView(.weatherExpanded)
        XCTAssertEqual(weatherMediumView.tabWidth, 420)
        XCTAssertEqual(weatherMediumView.tabHeight, 290)

        defaults.set(ActivitySettings.WeatherStyle.large.rawValue, forKey: key)
        let weatherLargeView = makeView(.weatherExpanded)
        XCTAssertEqual(weatherLargeView.tabWidth, 420)
        XCTAssertEqual(weatherLargeView.tabHeight, 410)
    }

    // MARK: - Phase 52 / SWITCH-03/04 — orderedSlotIcons + SelectedView(rawValue:)

    func testOrderedSlotIconsDefaultMatchesTodaysPillOrder() {
        // SWITCH-04 default: Home+Tray left, Calendar+Weather right — byte-identical to
        // today's switcherRow order.
        XCTAssertEqual(
            orderedSlotIcons(leftOuter: .home, leftInner: .tray, rightInner: .calendar, rightOuter: .weather),
            [.home, .tray, .calendar, .weather]
        )
    }

    func testOrderedSlotIconsAllowsDuplicateSlotAssignments() {
        // Duplicates are allowed, no validation (Claude's Discretion).
        XCTAssertEqual(
            orderedSlotIcons(leftOuter: .weather, leftInner: .weather, rightInner: .home, rightOuter: .tray),
            [.weather, .weather, .home, .tray]
        )
    }

    func testSelectedViewRawValueRoundTripsAndCorruptedValueFallsBackToNil() {
        XCTAssertEqual(SelectedView(rawValue: "home"), .home)
        XCTAssertNil(SelectedView(rawValue: "corrupted"))
    }

    // MARK: - Phase 52 / SWITCH-03/04 Task 1 — data-driven switcherRow (orderedSlotViews)

    private func makeSlotView(_ presentation: IslandPresentation = .homeEmpty) -> NotchPillView {
        let state = NotchInteractionState()
        state.phase = .expanded
        return NotchPillView(interaction: state,
                              nowPlaying: NowPlayingState(),
                              presentationState: IslandPresentationState(presentation),
                              outfit: BasicOutfitState(),
                              shelfViewState: ShelfViewState(),
                              onboardingState: OnboardingViewState(),
                              viewSwitcherState: ViewSwitcherState(),
                              calendarViewState: CalendarViewState())
    }

    func testOrderedSlotViewsDefaultsToTodaysPillOrder() {
        // Fresh view, no UserDefaults overrides — must byte-match today's hardcoded
        // switcherRow order (SWITCH-04 default, zero regression).
        XCTAssertEqual(makeSlotView().orderedSlotViews, [.home, .tray, .calendar, .weather])
    }

    func testOrderedSlotViewsReflectsUserDefaultsOverride() {
        let defaults = UserDefaults.standard
        let keys = [ActivitySettings.switcherSlotLeftOuterKey,
                    ActivitySettings.switcherSlotLeftInnerKey,
                    ActivitySettings.switcherSlotRightInnerKey,
                    ActivitySettings.switcherSlotRightOuterKey]
        let originalValues = keys.map { defaults.string(forKey: $0) }
        defer {
            for (key, original) in zip(keys, originalValues) {
                if let original {
                    defaults.set(original, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        defaults.set(SelectedView.weather.rawValue, forKey: ActivitySettings.switcherSlotLeftOuterKey)
        defaults.set(SelectedView.calendar.rawValue, forKey: ActivitySettings.switcherSlotLeftInnerKey)
        defaults.set(SelectedView.tray.rawValue, forKey: ActivitySettings.switcherSlotRightInnerKey)
        defaults.set(SelectedView.home.rawValue, forKey: ActivitySettings.switcherSlotRightOuterKey)

        XCTAssertEqual(makeSlotView().orderedSlotViews, [.weather, .calendar, .tray, .home])
    }
}
