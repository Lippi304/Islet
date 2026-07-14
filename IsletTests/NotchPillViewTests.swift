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
        let view = NotchPillView(interaction: state,
                                  nowPlaying: NowPlayingState(),
                                  presentationState: IslandPresentationState(.idle),
                                  outfit: BasicOutfitState(),
                                  shelfViewState: ShelfViewState(),
                                  onboardingState: OnboardingViewState(),
                                  viewSwitcherState: ViewSwitcherState(),
                                  calendarViewState: CalendarViewState())
        // TRAY-01: the shelf strip never reveals under Home/Calendar/Weather/Now-Playing —
        // only trayFullView renders shelf content, via its own separate shelfVisible: false path.
        XCTAssertFalse(view.shelfStripVisible,
                        "shelfStripVisible must stay false — the additive shelf-strip reveal is Tray-only (TRAY-01).")
    }
}
