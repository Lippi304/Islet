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

    // Phase 40 / HUD-06 (D-05/D-06) — truth-table for the update-available badge's pure
    // visibility gate, mirroring this codebase's per-boolean-branch test convention
    // (FocusActivityTests, OSDActivityTests, PowerActivityTests).
    func testShouldShowUpdateBadgeWhenAvailableAndCollapsed() {
        XCTAssertTrue(shouldShowUpdateBadge(updateAvailable: true, isExpanded: false))
    }

    func testShouldShowUpdateBadgeHiddenWhenExpanded() {
        XCTAssertFalse(shouldShowUpdateBadge(updateAvailable: true, isExpanded: true),
                        "the badge must never render in any expanded view (D-06)")
    }

    func testShouldShowUpdateBadgeHiddenWhenNoUpdateAndCollapsed() {
        XCTAssertFalse(shouldShowUpdateBadge(updateAvailable: false, isExpanded: false))
    }

    func testShouldShowUpdateBadgeHiddenWhenNoUpdateAndExpanded() {
        XCTAssertFalse(shouldShowUpdateBadge(updateAvailable: false, isExpanded: true))
    }
}
